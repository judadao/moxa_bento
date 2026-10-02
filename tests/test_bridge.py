"""Exercise the automatic sign-in lifecycle without network or real credentials."""
import json
from pathlib import Path
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch

from companion.bridge import HOME, run
from test_orders import page, meal

HTML = page([meal('2026-10-02')])


class Stop:
    def __init__(self):
        self.stopped = False
        self.iterations = 0

    def is_set(self):
        return self.stopped

    def wait(self, _):
        self.iterations += 1
        if self.iterations >= 8:
            self.stopped = True


class FakeBrowser:
    def __init__(self, stop, saved=False, cancel=False):
        self.stop = stop
        self.saved = saved
        self.cancel = cancel
        self.launches = []
        self.contexts = []
        self.destinations = []

    def launch_persistent_context(self, _, headless, **kwargs):
        self.launches.append(headless)
        context = FakeContext(self, headless)
        self.contexts.append(context)
        return context


class FakeContext:
    def __init__(self, owner, headless):
        self.owner = owner
        self.headless = headless
        self.pages = [FakePage(self)]
        self.request = self
        self.cookies = []
        self.closed = False

    def get(self, *args, **kwargs):
        if self.owner.saved:
            self.owner.stop.stopped = True
            return SimpleNamespace(url='https://foodcourt.moxa.com/foodCourt/staff/home.action', status=200, text=lambda: HTML)
        return SimpleNamespace(url='https://login.microsoftonline.com/signin', status=200)

    def add_cookies(self, cookies):
        self.cookies = cookies
        self.owner.saved = bool(cookies)

    def storage_state(self):
        return {"cookies": [{"name": "fixture", "value": "synthetic", "domain": "foodcourt.moxa.com", "path": "/"}], "origins": []}

    def close(self):
        self.closed = True


class FakePage:
    url = 'https://foodcourt.moxa.com/foodCourt/staff/home.action'

    def __init__(self, context):
        self.context = context

    def goto(self, url, **kwargs):
        self.context.owner.destinations.append(url)
        if self.context.owner.cancel:
            self.context.pages = []

    def locator(self, _):
        return SimpleNamespace(count=lambda: 1)

    def wait_for_load_state(self, *args, **kwargs):
        pass

    def content(self):
        return HTML


class FakePlaywright:
    def __init__(self, browser):
        self.chromium = browser

    def __enter__(self):
        return self

    def __exit__(self, *args):
        pass


class AutomaticLoginTest(unittest.TestCase):
    def exercise(self, saved=False, cancel=False):
        stop = Stop()
        browser = FakeBrowser(stop, saved=saved, cancel=cancel)
        fake_api = SimpleNamespace(sync_playwright=lambda: FakePlaywright(browser))
        with tempfile.TemporaryDirectory() as directory:
            with patch.dict('sys.modules', {'playwright.sync_api': fake_api}):
                run(directory, stop)
            state = json.loads((Path(directory) / 'state.json').read_text())
            auth_saved = (Path(directory) / 'auth.json').exists()
        self.assertTrue(all(c.closed for c in browser.contexts))
        return browser, state, auth_saved

    def test_first_run_automatically_opens_login_and_saves_session(self):
        browser, state, auth = self.exercise()
        self.assertEqual(browser.launches, [True, False, True])
        self.assertEqual(browser.destinations, [HOME])
        self.assertEqual(state['status'], 'ok')
        self.assertTrue(auth)
        self.assertTrue(browser.contexts[-1].cookies)

    def test_saved_session_stays_in_background(self):
        browser, state, _ = self.exercise(saved=True)
        self.assertEqual(browser.launches, [True])
        self.assertEqual(state['status'], 'ok')

    def test_cancelled_login_does_not_open_repeated_windows(self):
        browser, state, auth = self.exercise(cancel=True)
        self.assertEqual(browser.launches, [True, False])
        self.assertEqual(state['status'], 'login_required')
        self.assertFalse(auth)


if __name__ == '__main__':
    unittest.main()
