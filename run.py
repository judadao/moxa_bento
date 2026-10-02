#!/usr/bin/env python3
"""Launch Godot and its local integration on Windows or Linux."""
import argparse
import os
from pathlib import Path
import shutil
import subprocess
import sys
import threading

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
    if os.name == "nt":
        folder = Path(os.environ.get("LOCALAPPDATA", Path.home() / "AppData/Local")) / "BentoBuddy"
    else:
        folder = Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local/share")) / "bento-buddy"
    folder.mkdir(parents=True, exist_ok=True, mode=0o700)
    # OS-managed lock is automatically released after a crash; no stale lock cleanup needed.
    lock = (folder / "instance.lock").open("a+b")
    try:
        if os.name == "nt":
            import msvcrt
            lock.write(b"0")
            lock.flush()
            lock.seek(0)
            msvcrt.locking(lock.fileno(), msvcrt.LK_NBLCK, 1)
        else:
            import fcntl
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except OSError:
        parser.error("便當小夜班已經在執行。")
    stop = threading.Event()
    worker = None
    if not args.demo:
        try:
            import playwright.sync_api  # noqa: F401
        except ImportError:
            parser.error("請先執行 setup-linux.sh 或 setup-windows.bat 安裝訂餐連線工具。")
        from companion.bridge import atomic_json, run
        atomic_json(folder / "state.json", {"status": "loading", "message": "正在連線訂餐網站…"})
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
