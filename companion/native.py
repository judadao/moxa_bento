"""Chrome/Edge native messaging protocol and strict order-data validation."""
import html
import json
from pathlib import Path
import struct
import threading
import time
from urllib.parse import urlparse

from companion.bridge import atomic_json, desktop_active, read_json
from companion.orders import snapshot

HOST = "com.moxa_bento.buddy"
EXTENSION_ID = "ljoghkimjdcdpkpefnkjcicgecegphbj"
MAX_MESSAGE = 256 * 1024
ERRORS = {
    "login_required": "請在原本的瀏覽器登入 Moxa 訂餐網站，完成後會自動同步。",
    "network": "訂餐頁面無法讀取，請在原本的瀏覽器確認登入與網路。",
    "page_changed": "訂餐網站欄位無法辨識，暫時無法確認午餐。",
    "page_loading": "正在原本的瀏覽器開啟訂餐頁面…",
}


def read_exact(stream, size):
    chunks = bytearray()
    while len(chunks) < size:
        chunk = stream.read(size - len(chunks))
        if not chunk:
            if not chunks:
                return None
            raise ValueError("Truncated native message")
        chunks.extend(chunk)
    return bytes(chunks)


def read_message(stream):
    header = read_exact(stream, 4)
    if header is None:
        return None
    size, = struct.unpack("=I", header)
    if not 0 < size <= MAX_MESSAGE:
        raise ValueError("Invalid native message length")
    body = read_exact(stream, size)
    if body is None:
        raise ValueError("Missing native message body")
    value = json.loads(body.decode("utf-8"))
    if not isinstance(value, dict):
        raise ValueError("Expected an object")
    return value


def write_message(stream, value):
    body = json.dumps(value, ensure_ascii=False).encode("utf-8")
    stream.write(struct.pack("=I", len(body)) + body)
    stream.flush()


def text(value, maximum=2048):
    if not isinstance(value, str) or len(value) > maximum:
        raise ValueError("Invalid text field")
    return html.escape(value, quote=True)


def snapshot_from_browser(payload):
    source = urlparse(payload.get("source_url", ""))
    if source.scheme != "https" or source.netloc != "foodcourt.moxa.com" or not source.path.startswith("/foodCourt/staff/home"):
        raise ValueError("Unsupported source")
    if payload.get("logged_in") is not True:
        raise ValueError("Not authenticated")
    dates, headers, rows = (payload.get(key) for key in ("dates", "headers", "rows"))
    if not isinstance(dates, list) or not 1 <= len(dates) <= 64:
        raise ValueError("Invalid date picker")
    if not isinstance(headers, list) or len(headers) != 6:
        raise ValueError("Invalid headers")
    if not isinstance(rows, list) or len(rows) > 256:
        raise ValueError("Invalid rows")
    markup = '<button id="btnLogout"></button><select id="targetDay">'
    for item in dates:
        if not isinstance(item, dict):
            raise ValueError("Invalid date")
        markup += '<option value="' + text(item.get("value"), 32) + '">' + text(item.get("text"), 80) + '</option>'
    markup += '</select><table><tr>' + ''.join('<td>' + text(h, 80) + '</td>' for h in headers) + '</tr>'
    for row in rows:
        if not isinstance(row, list) or len(row) not in (1, 6):
            raise ValueError("Invalid order row")
        markup += '<tr>' + ''.join('<td>' + text(cell) + '</td>' for cell in row) + '</tr>'
    return snapshot(markup + '</table>')


def serve(folder, incoming, outgoing):
    folder = Path(folder)
    stopped = threading.Event()
    output_lock = threading.Lock()

    def send(value):
        with output_lock:
            write_message(outgoing, value)

    def watch_desktop():
        last_id = None
        previous_active = None
        while not stopped.is_set():
            active = desktop_active(folder)
            atomic_json(folder / "extension.json", {"updated_at": time.time()})
            command = read_json(folder / "command.json")
            event = {"type": "desktop", "active": active}
            if active and command.get("id") != last_id:
                last_id = command.get("id")
                event["action"] = command.get("action") if command.get("action") in ("login", "refresh") else "refresh"
            elif active and previous_active is not True:
                event["action"] = "refresh"
            try:
                send(event)
            except (OSError, ValueError):
                stopped.set()
                break
            previous_active = active
            stopped.wait(2)

    watcher = threading.Thread(target=watch_desktop, daemon=True)
    watcher.start()
    try:
        while not stopped.is_set():
            message = read_message(incoming)
            if message is None:
                break
            if message.get("type") == "snapshot":
                try:
                    data = snapshot_from_browser(message.get("data", {}))
                except (ValueError, TypeError, AttributeError, KeyError):
                    data = {"status": "unknown", "message": ERRORS["page_changed"]}
                atomic_json(folder / "state.json", data)
                send({"type": "result", "status": data["status"], "checked_at": data.get("checked_at")})
            elif message.get("type") == "error" and message.get("code") in ERRORS:
                code = message["code"]
                atomic_json(folder / "state.json", {"status": "login_required" if code == "login_required" else "unknown", "message": ERRORS[code]})
                send({"type": "result", "status": code})
    finally:
        stopped.set()
        watcher.join(timeout=3)
        atomic_json(folder / "extension.json", {"updated_at": 0})
