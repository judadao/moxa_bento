import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

from companion.runtime import lock_instance, parent_alive


class RuntimeTest(unittest.TestCase):
    def test_parent_exit_is_detected(self):
        self.assertTrue(parent_alive(os.getpid()))
        child = subprocess.Popen([sys.executable, '-c', 'pass'])
        child.wait(timeout=10)
        self.assertFalse(parent_alive(child.pid))

    def test_launcher_and_direct_godot_cannot_both_own_helper(self):
        with tempfile.TemporaryDirectory() as directory:
            folder = Path(directory)
            first = lock_instance(folder)
            try:
                code = 'from pathlib import Path; from companion.runtime import lock_instance; import sys; lock_instance(Path(sys.argv[1]))'
                result = subprocess.run([sys.executable, '-c', code, directory], capture_output=True)
                self.assertNotEqual(result.returncode, 0)
            finally:
                first.close()
            reopened = lock_instance(folder)
            reopened.close()


if __name__ == '__main__':
    unittest.main()
