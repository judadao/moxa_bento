# 便當小夜班 · Bento Buddy

用 Godot 製作的透明桌面精靈：熬夜工程師、電腦、咖啡與靜態像素畫。Windows / Linux 共用同一份程式。

![桌面精靈展示，非真實訂單](docs/preview.png)

## 開始使用

需要 **Python 3.10+**。原始碼版另需 **Godot 4.4+ 標準版**（不用 .NET）；發行資料夾若已有 `bin/bento-buddy` 或 `bin/bento-buddy.exe`，不需要另裝 Godot。

### Windows

1. 安裝 Python（[官方下載](https://www.python.org/downloads/)）及 [Godot](https://godotengine.org/download/windows/)。
2. 執行 `setup-windows.bat`，安裝本機查詢工具及 Chromium。
3. 若用原始碼版，把 Godot 加到 PATH，或在命令提示字元設定：

   ```bat
   set "GODOT_BIN=C:\Tools\Godot\Godot.exe"
   start-windows.bat
   ```

   有 `bin` 的發行資料夾直接執行 `start-windows.bat`。
4. 啟動就會自動嘗試沿用登入狀態；需要登入時會自動開啟專用瀏覽器，Windows 優先使用已安裝的 Edge。公司 SSO 若能自動完成，就不需要操作；第一次選帳號、輸入密碼或 MFA 仍由你完成。登入成功會關閉登入視窗並開始檢查，之後啟動優先在背景直接使用已保存的登入狀態。

### Linux

```bash
./setup-linux.sh
./start-linux.sh
```

Godot 不在 PATH 時：`GODOT_BIN=/完整路徑/godot ./start-linux.sh`。
若系統缺少 venv，先安裝發行版的 `python3-venv`。Chromium 若提示缺少系統套件，依 Playwright 的提示執行 `.venv/bin/python -m playwright install-deps chromium`。

透明、置頂及指定視窗位置需要桌面環境支援。Linux 建議 X11 + compositor；Wayland 的置頂／定位／點擊穿透限制因桌面環境而異。必要時可用 `GODOT_BIN` 指向以 `--display-driver x11` 執行 Godot 的 wrapper。Linux 實際測試環境為 Godot 4.7.1 / X11；Windows 尚待實機驗證。

### 只看造型，不連線

```bash
godot --path . -- --demo
# 或在安裝後：
./start-linux.sh --demo
# Windows：start-windows.bat --demo
```

展示模式固定用範例資料，明確標示「非真實訂單」。在 Godot 編輯器直接 F6/F5 也可以看造型，但需用上述啟動腳本才能啟用網站查詢。

## 怎麼提醒

登入跳轉流程：啟動 → 訂餐首頁 → Microsoft 公司 SSO（需要時）→ 自動回到訂餐頁 → 精靈讀取預約並關閉登入視窗。不需要複製網址、Cookie 或手動按「登入完成」。

- 預設檢查本週週一～週五，可切換下週；週別會記住。
- 日期以 **台北時間 UTC+8** 計算，只看「午餐」，任一地點的有效午餐預約都算已訂。晚餐不算。
- 每 5 分鐘讀取 FoodCourt 首頁的「已預約清單」及可預約日期；不會替你下單、修改或取消。
- 尚未登入／登入過期時會自動開啟登入瀏覽器。若取消或驗證未完成，不會一直重開視窗，可按「登入」重試。
- 日期在網站的可預約選單內、尚未過期、又沒有午餐預約時，顯示「要訂便當了喔！星期 X 還沒訂」。多天會一併列出。
- 日期沒列在網站上時顯示「待確認」，不會自行假設是漏訂或假日。請假／不用訂餐日尚無個別排除設定。
- 登入失效、網路錯誤、網站格式改變、跨日或資料超過 15 分鐘，都不以舊資料發出漏訂提醒。
- 「30 分鐘後提醒」會隱藏對話；時間到且仍確認漏訂時再出現。相同資料不會每 5 分鐘一直彈。

## 操作

| 操作 | 效果 |
| --- | --- |
| 拖曳工程師 | 移動桌面精靈 |
| 右鍵工程師 | 顯示／隱藏對話 |
| 雙擊工程師／去訂便當 | 用預設瀏覽器開啟訂餐系統 |
| 登入 | 手動重試自動登入 |
| 檢查 | 立即重新讀取預約清單 |
| × | 關閉精靈及查詢工具 |
| Tab / Shift+Tab / Enter | 導覽並操作對話框按鈕 |

目前需手動啟動，未安裝開機自啟或系統服務。關閉精靈後就不會提醒。

## 本機資料

不儲存密碼；登入 Cookies／瀏覽器設定只放在使用者的本機資料夾，不會進專案 Git。不要分享該資料夾。

- Windows：`%LOCALAPPDATA%\BentoBuddy`
- Linux：`${XDG_DATA_HOME:-~/.local/share}/bento-buddy`

`state.json` 只存日期、已訂／未訂狀態和查詢時間；`auth.json` 與 `browser-profile/` 儲存登入工作階段。登出／清除本機登入：先關閉精靈，再移除 `auth.json` 及 `browser-profile/`。程式不會讀取日常 Chrome 的個人設定檔；即使原本瀏覽器已登入，精靈的專用設定檔第一次仍可能需要驗證。自動登入不會繞過公司 MFA 或存取限制。

UI 偏好另存於 Godot 的 `user://settings.cfg`。目前不包含跨裝置同步。

## 開發與驗證

```bash
python3 -m unittest discover -s tests -v
godot --headless --editor --path . --import --quit
godot --headless --path . --script tests/ui_smoke.gd
godot --path . -- --demo --capture   # output/preview.png，需要圖形環境
```

`companion/orders.py` 依實際觀察到的 FoodCourt 欄位解析；測試資料是合成餐點。登入後的背景自動查詢仍須在使用者完成精靈專用登入後驗證，公司 SSO 原則可能限制自動化瀏覽器。

安裝與 Godot 版本相同的官方 Export Templates 後，執行 `python3 scripts/build.py`，產生 `build/linux` 及 `build/windows`。發行時分享整個資料夾；`bin` 只有精靈視窗，網站功能仍需 Python 啟動器與 setup。Windows 圖示與程式簽章尚未配置。

## 檔案

- `scripts/main.gd`：透明視窗、對話、狀態顯示、稍後提醒。
- `scripts/pixel_engineer.gd`：原創靜態像素角色，以 Godot 方格繪圖，不需外部圖片服務。
- `companion/bridge.py`：專用 Chromium 登入、唯讀查詢、本機檔案 IPC。
- `companion/orders.py`：日期、週別與預約解析。
- `run.py`：跨平台啟動、單一執行個體及生命週期管理。

字體是 Noto Sans CJK TC 的子集，授權見 `assets/fonts/LICENSE.txt`。修改文案後可安裝 `fonttools`，執行 `scripts/subset_font.py /path/to/NotoSansCJK-Regular.ttc` 重新產生字形。
