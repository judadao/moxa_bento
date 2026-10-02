#!/usr/bin/env python3
"""Start the helper from Godot, and stop it when that Godot process exits."""
import argparse
from pathlib import Path
import threading

from companion.bridge import atomic_json, run
from companion.runtime import lock_instance, parent_alive


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--data-dir", type=Path, required=True)
    parser.add_argument("--parent-pid", type=int, required=True)
    args = parser.parse_args()
    try:
        lock = lock_instance(args.data_dir)
    except OSError:
        # Another launcher already owns the helper; use its existing state file.
        return
    stop = threading.Event()
    state_file = args.data_dir / "state.json"
    def watch_parent():
        while not stop.wait(1):
            if not parent_alive(args.parent_pid):
                stop.set()
    watcher = threading.Thread(target=watch_parent, daemon=True)
    watcher.start()
    try:
        atomic_json(state_file, {"status": "loading", "message": "正在等待原本瀏覽器的訂餐資料…"})
        run(args.data_dir, stop)
    except ImportError:
        atomic_json(state_file, {"status": "error", "message": "缺少查詢套件，請先執行 setup-windows.bat 或 setup-linux.sh。"})
    except Exception as exc:
        atomic_json(state_file, {"status": "error", "message": "查詢工具啟動失敗，請重新執行安裝腳本。", "error_type": type(exc).__name__})
    finally:
        stop.set()
        lock.close()


if __name__ == "__main__":
    main()
