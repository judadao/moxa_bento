import base64
from datetime import datetime
import hashlib
import io
import json
from pathlib import Path
import struct
import tempfile
import unittest
from companion.native import EXTENSION_ID, MAX_MESSAGE, read_message, write_message, snapshot_from_browser
from companion.orders import HEADERS, TAIPEI
from register_native_host import install

ROOT = Path(__file__).resolve().parents[1]

def payload():
    today = datetime.now(TAIPEI).date().isoformat()
    return {'source_url': 'https://foodcourt.moxa.com/foodCourt/staff/home.action', 'logged_in': True,
            'dates': [{'value': today, 'text': today}], 'headers': list(HEADERS),
            'rows': [[today, '便當屋-午餐', '測試便當 * 1', '自費:100', '總部', '']]}

class NativeTest(unittest.TestCase):
    def test_unicode_frame_roundtrip(self):
        stream = io.BytesIO()
        write_message(stream, {'message': '星期三午餐'})
        stream.seek(0)
        self.assertEqual(read_message(stream), {'message': '星期三午餐'})
        self.assertIsNone(read_message(stream))

    def test_bounded_and_truncated_messages(self):
        for data in [b'xx', struct.pack('=I', MAX_MESSAGE + 1), struct.pack('=I', 5) + b'{}', struct.pack('=I', 2) + b'[]']:
            with self.assertRaises(ValueError):
                read_message(io.BytesIO(data))

    def test_browser_snapshot_includes_today_lunch(self):
        state = snapshot_from_browser(payload())
        self.assertEqual(state['status'], 'ok')
        self.assertEqual(state['today_lunch'][0]['content'], '測試便當 * 1')

    def test_unknown_origin_and_schema_are_rejected(self):
        for change in [{'source_url': 'https://evil.example/foodCourt/staff/home'}, {'source_url': 'https://foodcourt.moxa.com.evil.example/foodCourt/staff/home'}, {'logged_in': False}, {'rows': [['broken']]}, {'rows': [['x'] * 6] * 257}, {'headers': ['other'] * 6}]:
            with self.assertRaises(ValueError):
                snapshot_from_browser({**payload(), **change})

    def test_order_content_is_escaped_not_interpreted_as_markup(self):
        data = payload()
        data['rows'][0][2] = '<script>meal</script> & rice'
        state = snapshot_from_browser(data)
        self.assertEqual(state['today_lunch'][0]['content'], '<script>meal</script> & rice')

    def test_extension_id_matches_public_key(self):
        manifest = json.loads((ROOT / 'extension/manifest.json').read_text())
        digest = hashlib.sha256(base64.b64decode(manifest['key'])).hexdigest()[:32]
        self.assertEqual(''.join(chr(97 + int(c, 16)) for c in digest), EXTENSION_ID)
        self.assertNotIn('cookies', manifest['permissions'])
        self.assertEqual(manifest['host_permissions'], ['https://foodcourt.moxa.com/*'])

    @unittest.skipIf(__import__('os').name == 'nt', 'Linux registration layout')
    def test_registration_is_user_scoped_and_origin_restricted(self):
        with tempfile.TemporaryDirectory() as directory:
            folder = Path(directory)
            (folder / '.venv/bin').mkdir(parents=True)
            (folder / '.venv/bin/python').touch()
            path = install(folder, folder / 'config', folder / 'host')
            manifest = json.loads(path.read_text())
            self.assertEqual(manifest['allowed_origins'], [f'chrome-extension://{EXTENSION_ID}/'])
            for browser in ['google-chrome', 'microsoft-edge', 'chromium']:
                self.assertTrue((folder / 'config' / browser / 'NativeMessagingHosts' / path.name).exists())
