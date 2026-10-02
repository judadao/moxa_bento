"""Real Godot → Python helper startup, file IPC, and parent-exit shutdown.

The fixture replaces only the network bridge so no sign-in UI is opened by tests.
"""
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import time
import unittest

ROOT = Path(__file__).resolve().parents[1]
GODOT = shutil.which('godot') or shutil.which('godot4')


@unittest.skipUnless(GODOT and os.name != 'nt', 'requires Linux Godot for process integration test')
class DirectGodotStartupTest(unittest.TestCase):
    def test_direct_scene_starts_bridge_and_reads_state(self):
        with tempfile.TemporaryDirectory(prefix='bento-boot-') as directory:
            folder = Path(directory)
            app = folder / 'app'
            app.mkdir()
            for name in ['project.godot', 'main.tscn', 'bridge_runner.py']:
                shutil.copy2(ROOT / name, app / name)
            shutil.copytree(ROOT / 'scripts', app / 'scripts')
            shutil.copytree(ROOT / 'assets', app / 'assets')
            (app / '.venv/bin').mkdir(parents=True)
            (app / '.venv/.gdignore').touch()
            (app / '.venv/bin/python').symlink_to(sys.executable)
            (app / 'companion').mkdir()
            for name in ['runtime.py', '__init__.py', '.gdignore']:
                shutil.copy2(ROOT / 'companion' / name, app / 'companion' / name)
            (app / 'companion/bridge.py').write_text('''
import json, os
from pathlib import Path
def atomic_json(path, data):
    tmp = path.with_suffix('.tmp')
    tmp.write_text(json.dumps(data))
    os.replace(tmp, path)
def run(folder, stop):
    atomic_json(Path(folder)/'state.json', {'status':'fixture', 'message':'DIRECT_BOOT_OK'})
    stop.wait(15)
    (Path(folder)/'stopped').touch()
''')
            (app / 'check.gd').write_text('''extends SceneTree
func _initialize() -> void:
    check.call_deferred()
func check() -> void:
    var app = load("res://main.tscn").instantiate()
    root.add_child(app)
    for i in range(30):
        await create_timer(0.1).timeout
        app._poll()
        if app.detail.text == "DIRECT_BOOT_OK":
            print("DIRECT_BOOT_OK")
            quit(0)
            return
    push_error("Direct startup did not load helper state")
    quit(1)
''')
            env = {**os.environ, 'XDG_DATA_HOME': str(folder / 'data')}
            imported = subprocess.run([GODOT, '--headless', '--editor', '--path', str(app), '--import', '--quit'], env=env, capture_output=True, text=True, timeout=30)
            self.assertEqual(imported.returncode, 0, imported.stderr)
            display_args = ['--display-driver', 'x11'] if os.environ.get('BENTO_TEST_DISPLAY') else ['--headless']
            if os.environ.get('BENTO_TEST_DISPLAY'):
                env['DISPLAY'] = os.environ['BENTO_TEST_DISPLAY']
                env['LIBGL_ALWAYS_SOFTWARE'] = '1'
            try:
                result = subprocess.run([GODOT, *display_args, '--path', str(app), '--script', 'check.gd'], env=env, capture_output=True, text=True, timeout=15)
            except subprocess.TimeoutExpired as exc:
                self.fail(str(exc.stdout) + str(exc.stderr))
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertIn('DIRECT_BOOT_OK', result.stdout)
            stopped = folder / 'data/bento-buddy/stopped'
            for _ in range(50):
                if stopped.exists():
                    break
                time.sleep(.1)
            self.assertTrue(stopped.exists(), 'Helper did not stop when Godot closed')


if __name__ == '__main__':
    unittest.main()
