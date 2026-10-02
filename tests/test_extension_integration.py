"""Real MV3 extension + native host, with a synthetic signed-in FoodCourt site.

Run on :90 with BENTO_EXTENSION_TEST=1 and requirements-dev.txt installed.
No real account, cookies, or network orders are used.
"""
from datetime import datetime, timedelta
import importlib.util
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import os
from pathlib import Path
import threading
import time
import ssl
import subprocess
import unittest
import tempfile

from companion.bridge import atomic_json, run
from companion.native import EXTENSION_ID
from companion.orders import TAIPEI
from register_native_host import install
from test_orders import meal, page

ROOT = Path(__file__).resolve().parents[1]
HOME = 'https://foodcourt.moxa.com/foodCourt/staff/home.action?request_locale=zh_TW'
ENABLED = os.environ.get('BENTO_EXTENSION_TEST') == '1' and importlib.util.find_spec('playwright') is not None


@unittest.skipUnless(ENABLED, 'opt-in real extension test: BENTO_EXTENSION_TEST=1')
class ExtensionIntegrationTest(unittest.TestCase):
    def test_existing_session_native_sync_expiry_and_stop(self):
        from playwright.sync_api import sync_playwright
        with tempfile.TemporaryDirectory(prefix='bento-extension-') as directory:
            folder = Path(directory)
            config = folder / 'config'
            data = folder / 'data/bento-buddy'
            data.mkdir(parents=True)
            install(ROOT, config, folder / 'native-host')
            stop = threading.Event()
            worker = threading.Thread(target=run, args=(data, stop))
            today = datetime.now(TAIPEI).date()
            days = [(today + timedelta(days=i)).isoformat() for i in range(14)]
            html = page([meal(today.isoformat())], options=days)
            requests = []
            # Extension-created navigations can precede Playwright's route
            # attachment. Resolve the real hostname to an isolated HTTPS fixture
            # instead, so even that first request can never reach the live site.
            certificate, key = folder / 'cert.pem', folder / 'key.pem'
            subprocess.run(['openssl', 'req', '-x509', '-newkey', 'rsa:2048', '-nodes',
                            '-keyout', str(key), '-out', str(certificate), '-days', '1',
                            '-subj', '/CN=foodcourt.moxa.com'], check=True, capture_output=True)
            class FixtureHandler(BaseHTTPRequestHandler):
                def do_GET(self):
                    signed_in = 'bento_fixture=signed-in' in self.headers.get('Cookie', '')
                    requests.append({'method': 'GET', 'signed_in': signed_in})
                    body = (html if signed_in else '<h1>Sign in</h1>').encode('utf-8')
                    self.send_response(200)
                    self.send_header('Content-Type', 'text/html; charset=utf-8')
                    self.send_header('Content-Length', str(len(body)))
                    self.end_headers()
                    self.wfile.write(body)
                def log_message(self, *_):
                    pass
            server = ThreadingHTTPServer(('127.0.0.1', 0), FixtureHandler)
            tls = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
            tls.load_cert_chain(certificate, key)
            server.socket = tls.wrap_socket(server.socket, server_side=True)
            threading.Thread(target=server.serve_forever, daemon=True).start()
            self.addCleanup(server.server_close)
            self.addCleanup(server.shutdown)
            env = {**os.environ, 'DISPLAY': ':90', 'XDG_CONFIG_HOME': str(config),
                   'XDG_DATA_HOME': str(folder / 'data'), 'LIBGL_ALWAYS_SOFTWARE': '1'}
            with sync_playwright() as pw:
                context = pw.chromium.launch_persistent_context(
                    str(config / 'chromium'), channel='chromium', headless=False, env=env,
                    args=[f'--disable-extensions-except={ROOT / "extension"}', f'--load-extension={ROOT / "extension"}',
                          '--ignore-certificate-errors', '--no-proxy-server',
                          f'--host-resolver-rules=MAP foodcourt.moxa.com 127.0.0.1:{server.server_port}, MAP * ~NOTFOUND'])
                try:
                    cookie = {'name': 'bento_fixture', 'value': 'signed-in', 'domain': 'foodcourt.moxa.com', 'path': '/', 'secure': True}
                    context.add_cookies([cookie])
                    existing = context.pages[0]
                    existing.goto(HOME)
                    popup = context.new_page()
                    popup.goto(f'chrome-extension://{EXTENSION_ID}/popup.html')
                    worker.start()

                    def wait_state(expected):
                        deadline = time.monotonic() + 25
                        observed = {}
                        while time.monotonic() < deadline:
                            try:
                                observed = json.loads((data / 'state.json').read_text())
                            except (OSError, ValueError):
                                pass
                            if observed.get('status') == expected:
                                return observed
                            popup.wait_for_timeout(100)
                        self.fail(f'Expected {expected}, got {observed}; requests={requests}; popup={popup.locator("body").inner_text()}')

                    state = wait_state('ok')
                    self.assertEqual(state['today_lunch'][0]['content'], '測試餐 * 1')
                    self.assertEqual(state['today_lunch'][0]['location'], '總部')
                    self.assertGreaterEqual(len(requests), 2)  # initial page + fresh same-origin fetch
                    self.assertTrue(all(request['method'] == 'GET' for request in requests))
                    self.assertFalse((data / 'auth.json').exists())
                    self.assertFalse((data / 'browser-profile').exists())
                    self.assertEqual(len([p for p in context.pages if p.url.startswith(HOME)]), 1)
                    screenshots = ROOT / 'output/playwright'
                    screenshots.mkdir(parents=True, exist_ok=True)
                    popup.screenshot(path=str(screenshots / 'extension-popup.png'))

                    context.clear_cookies()
                    popup.get_by_role('button', name='立即同步午餐').click()
                    wait_state('login_required')
                    context.add_cookies([cookie])
                    popup.get_by_role('button', name='立即同步午餐').click()
                    wait_state('ok')

                    # With no existing FoodCourt tab, open one in this browser
                    # and synchronize automatically once the content script loads.
                    existing.close()
                    atomic_json(data / 'state.json', {'status': 'waiting_for_new_tab'})
                    popup.get_by_role('button', name='立即同步午餐').click()
                    wait_state('ok')
                    self.assertEqual(len([p for p in context.pages if p.url.startswith(HOME)]), 1)

                    stop.set()
                    worker.join(timeout=5)
                    popup.wait_for_timeout(2500)
                    count = len(requests)
                    popup.get_by_role('button', name='立即同步午餐').click()
                    popup.wait_for_timeout(500)
                    self.assertEqual(len(requests), count, 'Closing the pet must stop fetching orders')
                    self.assertIn('尚未啟動', popup.locator('#status').inner_text())
                finally:
                    stop.set()
                    if worker.is_alive():
                        worker.join(timeout=5)
                    context.close()


if __name__ == '__main__':
    unittest.main()
