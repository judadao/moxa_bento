"""A dedicated browser profile, file IPC, and a five-minute read-only poll."""
import json
import os
from pathlib import Path
import shutil
import time
from urllib.parse import urlparse

from companion.orders import snapshot, UnrecognizedPage

HOME = "https://foodcourt.moxa.com/foodCourt/staff/home.action?request_locale=zh_TW"


def installed_browser_channel():
    """Prefer the system browser for company SSO; never use its personal profile."""
    if os.name == "nt":
        for base in ("PROGRAMFILES(X86)", "PROGRAMFILES", "LOCALAPPDATA"):
            folder = os.environ.get(base)
            if folder and (Path(folder) / "Microsoft/Edge/Application/msedge.exe").exists():
                return "msedge"
    if shutil.which("microsoft-edge"):
        return "msedge"
    if shutil.which("google-chrome") or shutil.which("google-chrome-stable"):
        return "chrome"
    return None


def atomic_json(path, data):
    temp = path.with_suffix(".tmp")
    temp.write_text(json.dumps(data, ensure_ascii=False), encoding="utf-8")
    os.replace(temp, path)


def read_command(folder):
    try:
        return json.loads((folder / "command.json").read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return {}


def run(folder, stop):
    from playwright.sync_api import sync_playwright
    folder = Path(folder)
    profile = folder / "browser-profile"
    state_file = folder / "state.json"
    auth_file = folder / "auth.json"
    last_command = read_command(folder).get("id")

    def publish(status, message):
        atomic_json(state_file, {"status": status, "message": message, "updated_at": time.time()})

    with sync_playwright() as pw:
        context = None
        visible = False
        next_check = 0.0
        login_deadline = 0.0
        auto_login_pending = False
        auto_login_attempted = False

        def open_context(headless):
            browser_context = pw.chromium.launch_persistent_context(
                str(profile), headless=headless, locale="zh-TW",
                viewport={"width": 1100, "height": 800},
                chromium_sandbox=True,
                channel=installed_browser_channel(),
            )
            # Chromium may discard session cookies when it closes. Explicitly restore
            # the dedicated app session; never read the user's normal browser profile.
            if auth_file.exists():
                try:
                    auth = json.loads(auth_file.read_text(encoding="utf-8"))
                    browser_context.add_cookies(auth.get("cookies", []))
                except (OSError, ValueError):
                    pass
            return browser_context

        try:
            while not stop.is_set():
                command = read_command(folder)
                action = None
                if command.get("id") != last_command:
                    last_command = command.get("id")
                    action = command.get("action")
                if auto_login_pending:
                    action = "login"
                    auto_login_pending = False
                try:
                    if action == "login":
                        auto_login_attempted = True
                        if context:
                            context.close()
                        context = open_context(False)
                        visible = True
                        login_deadline = time.monotonic() + 600
                        page = context.pages[0] if context.pages else context.new_page()
                        publish("login", "正在跳轉公司登入；完成驗證後會自動返回訂餐頁並同步。")
                        page.goto(HOME, wait_until="domcontentloaded", timeout=30000)
                    if visible:
                        # Read only the known FoodCourt page. Never type credentials or click order buttons.
                        pages = [p for p in context.pages if urlparse(p.url).hostname == "foodcourt.moxa.com"]
                        if pages and pages[0].locator("#btnLogout").count():
                            pages[0].wait_for_load_state("load", timeout=15000)
                            atomic_json(state_file, snapshot(pages[0].content()))
                            atomic_json(auth_file, context.storage_state())
                            if os.name != "nt":
                                auth_file.chmod(0o600)
                            context.close()
                            context = None
                            visible = False
                            next_check = 0
                        elif not context.pages or time.monotonic() > login_deadline:
                            context.close()
                            context = None
                            visible = False
                            publish("login_required", "登入尚未完成，請再按「登入」。")
                            next_check = time.monotonic() + 300
                        else:
                            context.pages[0].wait_for_timeout(500)
                            continue
                    if action == "refresh":
                        next_check = 0
                    if time.monotonic() >= next_check:
                        if context is None:
                            context = open_context(True)
                        response = context.request.get(HOME, timeout=30000)
                        if urlparse(response.url).hostname != "foodcourt.moxa.com":
                            if not auto_login_attempted:
                                publish("login", "正在開啟瀏覽器，自動連接公司登入…")
                                auto_login_pending = True
                            else:
                                publish("login_required", "登入尚未完成，請按「登入」重試。")
                        elif response.status != 200:
                            publish("error", "訂餐網站暫時無法回應，五分鐘後再試。")
                        else:
                            atomic_json(state_file, snapshot(response.text()))
                            auto_login_attempted = False
                            atomic_json(auth_file, context.storage_state())
                            if os.name != "nt":
                                auth_file.chmod(0o600)
                        next_check = time.monotonic() + 300
                except UnrecognizedPage as exc:
                    if "請先登入" in str(exc) and not auto_login_attempted:
                        auto_login_pending = True
                        publish("login", "正在開啟瀏覽器，自動連接公司登入…")
                    else:
                        publish("unknown", str(exc))
                    next_check = time.monotonic() + 300
                except Exception:
                    # Do not leak cookies, SSO URLs, or page content into logs/state files.
                    publish("error", "無法連線或瀏覽器已關閉。請檢查網路，或重新登入。")
                    if context:
                        try:
                            context.close()
                        except Exception:
                            pass
                    context = None
                    visible = False
                    next_check = time.monotonic() + 300
                stop.wait(0.5)
        finally:
            if context:
                context.close()
