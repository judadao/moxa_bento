#!/usr/bin/env python3
"""Launch Godot and its local integration on Windows or Linux."""
import argparse
import os
from pathlib import Path
import shutil
import subprocess
import sys
import threading

from companion.runtime import data_directory, lock_instance

ROOT = Path(__file__).resolve().parent


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--demo", action="store_true", help="Offline preview; no real order data")
    parser.add_argument("--godot", help="Path to the Godot 4.4+ executable")
    args = parser.parse_args()
    packaged = ROOT / "bin" / ("bento-buddy.exe" if os.name == "nt" else "bento-buddy")
    executable = args.godot or (str(packaged) if packaged.exists() else None) or os.environ.get("GODOT_BIN") or shutil.which("godot") or shutil.which("godot4")
    if not executable:
        parser.error("找不到 Godot。請安裝 Godot 4.4+ 並設定 GODOT_BIN，或使用 --godot 指定執行檔。")
    folder = data_directory()
    # OS-managed lock is automatically released after a crash; no stale lock cleanup needed.
    try:
        lock = lock_instance(folder)
    except OSError:
        parser.error("便當小夜班已經在執行。")
    stop = threading.Event()
    worker = None
    if not args.demo:
        from companion.bridge import atomic_json, run
        atomic_json(folder / "state.json", {"status": "loading", "message": "正在連接瀏覽器擴充功能…"})
        def bridge_worker():
            try:
                run(folder, stop)
            except Exception:
                atomic_json(folder / "state.json", {"status": "error", "message": "連線工具無法啟動，請重新執行安裝腳本。"})
        worker = threading.Thread(target=bridge_worker, daemon=True)
        worker.start()
    command = [executable]
    if Path(executable).resolve() != packaged.resolve():
        command += ["--path", str(ROOT)]
    command += ["--", "--data-dir=" + str(folder)]
    if args.demo:
        command.append("--demo")
    try:
        return subprocess.call(command)
    finally:
        stop.set()
        if worker:
            worker.join(timeout=35)
        lock.close()


if __name__ == "__main__":
    sys.exit(main())
