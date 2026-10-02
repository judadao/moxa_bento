"""Desktop lifecycle only; the browser extension owns all website access."""
import json
import os
from pathlib import Path
import tempfile
import time
import uuid


def atomic_json(path, data):
    path = Path(path)
    with tempfile.NamedTemporaryFile(mode="w", encoding="utf-8", dir=path.parent, delete=False) as file:
        json.dump(data, file, ensure_ascii=False)
        temp = file.name
    try:
        os.replace(temp, path)
    finally:
        if os.path.exists(temp):
            os.unlink(temp)


def read_json(path):
    try:
        value = json.loads(Path(path).read_text(encoding="utf-8"))
        return value if isinstance(value, dict) else {}
    except (OSError, ValueError):
        return {}


def desktop_active(folder):
    data = read_json(Path(folder) / "desktop.json")
    return time.time() - data.get("updated_at", 0) < 15


def run(folder, stop):
    folder = Path(folder)
    state_file = folder / "state.json"
    atomic_json(state_file, {"status": "extension_waiting", "message": "請在已登入訂餐網站的 Chrome／Edge 載入便當同步擴充功能。"})
    atomic_json(folder / "command.json", {"id": uuid.uuid4().hex, "action": "refresh"})
    was_connected = False
    try:
        while not stop.is_set():
            atomic_json(folder / "desktop.json", {"updated_at": time.time(), "pid": os.getpid()})
            connected = time.time() - read_json(folder / "extension.json").get("updated_at", 0) < 15
            if was_connected and not connected:
                atomic_json(state_file, {"status": "extension_waiting", "message": "瀏覽器連線已中斷。請開啟已安裝擴充功能的 Chrome／Edge。"})
            was_connected = connected
            stop.wait(2)
    finally:
        atomic_json(folder / "desktop.json", {"updated_at": 0})
