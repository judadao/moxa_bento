#!/usr/bin/env python3
"""Launched by Chrome/Edge. stdout is reserved for framed native messages."""
import os
import sys

from companion.native import EXTENSION_ID, serve, write_message
from companion.runtime import data_directory, lock_instance


def main():
    if len(sys.argv) < 2 or sys.argv[1] != f"chrome-extension://{EXTENSION_ID}/":
        return 1
    if os.name == "nt":
        import msvcrt
        msvcrt.setmode(sys.stdin.fileno(), os.O_BINARY)
        msvcrt.setmode(sys.stdout.fileno(), os.O_BINARY)
    folder = data_directory()
    try:
        lock = lock_instance(folder / "native-connection")
    except OSError:
        write_message(sys.stdout.buffer, {"type": "result", "status": "another_browser"})
        return 1
    try:
        serve(folder, sys.stdin.buffer, sys.stdout.buffer)
    except (OSError, ValueError):
        return 1
    finally:
        lock.close()
    return 0


if __name__ == "__main__":
    sys.exit(main())
