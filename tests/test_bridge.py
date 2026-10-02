"""The desktop must never launch a separate login browser."""
import json
from pathlib import Path
import tempfile
import unittest
from companion.bridge import desktop_active, run

class Stop:
    stopped = False
    def is_set(self):
        return self.stopped
    def wait(self, _):
        self.stopped = True

class BridgeTest(unittest.TestCase):
    def test_start_requests_browser_sync_and_stop_clears_lifecycle(self):
        with tempfile.TemporaryDirectory() as directory:
            folder = Path(directory)
            run(folder, Stop())
            self.assertEqual(json.loads((folder / 'command.json').read_text())['action'], 'refresh')
            self.assertEqual(json.loads((folder / 'state.json').read_text())['status'], 'extension_waiting')
            self.assertFalse(desktop_active(folder))
            self.assertFalse((folder / 'auth.json').exists())
            self.assertFalse((folder / 'browser-profile').exists())
