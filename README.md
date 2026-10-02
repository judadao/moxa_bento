# 便當小夜班 · Bento Buddy

用 Godot 製作的「異世界社畜同事」：盔甲騎士／金髮女騎士坐在現代辦公桌後，工作時看左側電腦，聊天時轉正看你。RPG 逐字氣泡、可布置的獨立物件，以及每天 9 點截止前的午餐提醒。Windows / Linux 共用同一份程式。

![桌面精靈展示，非真實訂單](docs/preview.png)

## 開始使用

需要 **Python 3.10+**。原始碼版另需 **Godot 4.4+ 標準版**（不用 .NET）；發行資料夾若已有 `bin/bento-buddy` 或 `bin/bento-buddy.exe`，不需要另裝 Godot。

### Windows

1. 安裝 Python（[官方下載](https://www.python.org/downloads/)）及 [Godot](https://godotengine.org/download/windows/)。
2. 執行新版 `setup-windows.bat`，註冊本機同步工具。**從舊版升級也要重跑一次**；不再下載另一套 Chromium。
3. 若用原始碼版，把 Godot 加到 PATH，或在命令提示字元設定：

   ```bat
   set "GODOT_BIN=C:\Tools\Godot\Godot.exe"
   start-windows.bat
   ```

   有 `bin` 的發行資料夾直接執行 `start-windows.bat`。
4. 在你平常已登入訂餐系統的 Chrome／Edge，依下節載入擴充功能。精靈會直接沿用該瀏覽器的登入，不再另外開登入瀏覽器。

### 載入擴充功能（Windows / Linux 都只做一次）

1. 在平常使用的瀏覽器開啟 `chrome://extensions` 或 `edge://extensions`。
2. 開啟「開發人員模式」，按「載入未封裝項目／載入解壓縮」。
3. 選取本專案的 **`extension` 資料夾**（不是整個專案根目錄）。
4. 開啟桌面精靈。擴充功能會讀取既有的訂餐分頁；若沒有分頁，會在**這個瀏覽器**開啟訂餐首頁。你原本已登入就能直接讀取。
5. 點擴充功能圖示，可以看到「已同步到桌面精靈」與同步時間，也能立即同步。

擴充功能固定 ID：`ljoghkimjdcdpkpefnkjcicgecegphbj`。只在一個常用瀏覽器啟用即可。公司若禁止自行安裝擴充功能，需要由 IT 核准此擴充功能；程式不會更改公司瀏覽器政策。

瀏覽器和精靈必須在**同一台電腦**，這是本機同步，不是遠端連線。專案搬到另一個路徑後要重跑 setup；更新擴充功能程式後，在擴充功能管理頁按重新載入。

若沒有同步，先點擴充功能圖示看狀態：「本機同步工具未連接」請重跑 setup 並重新載入擴充功能；「桌面精靈尚未啟動」請啟動精靈；登入過期則按「開啟訂餐頁面」，在原本瀏覽器完成公司登入，回到訂餐首頁後會自動同步。

### Linux

```bash
./setup-linux.sh
# 在 Chrome/Edge 依上節載入 extension 資料夾
./start-linux.sh
```

Godot 不在 PATH 時：`GODOT_BIN=/完整路徑/godot ./start-linux.sh`。
若系統缺少 venv，先安裝發行版的 `python3-venv`。執行時只用 Python 標準函式庫，不需要 Playwright 或額外瀏覽器。

透明、置頂及指定視窗位置需要桌面環境支援。Linux 建議 X11 + compositor；Wayland 的置頂／定位／點擊穿透限制因桌面環境而異。必要時可用 `GODOT_BIN` 指向以 `--display-driver x11` 執行 Godot 的 wrapper。Linux 實際測試環境為 Godot 4.7.1 / X11；Windows 尚待實機驗證。

### 只看造型，不連線

```bash
godot --path . -- --demo
# 或在安裝後：
./start-linux.sh --demo
# Windows：start-windows.bat --demo
```

展示模式固定用範例資料，人物名稱旁會標示「範例」，不寫入你的偏好配置。安裝腳本執行過一次後，在 Godot 編輯器直接執行主場景（F6/F5），或開啟發行資料夾中的執行檔，也會自動啟動背景查詢，不必另外執行啟動腳本。關閉 Godot 後查詢工具會自動結束。

## 怎麼提醒

資料流程：已登入的 Chrome／Edge → 訂餐頁面唯讀查詢 → 擴充功能 → Native Messaging → 本機精靈。

- 週一～週五，預設在台北時間 **08:00、08:30、08:50** 提醒本週尚未訂的午餐；可選只在 08:30 提醒一次，或關閉。
- **當天 09:00 截止**，09:00 起不再催訂當天。手動查看週表會顯示「已截止」，對話改成關心你中午找東西吃。未來日期仍可手動查看。
- 時段中途啟動會補當前那一次提醒，同一時段不重複催；提醒記錄保存，重新啟動也不重複。07:59 前、09:00 後、週末不發出自動催訂。
- 「嗯，知道了」：文字未說完時先完整顯示；說完後再按會收起，安靜 10 分鐘。
- 每 5 分鐘同步網站；只有新鮮資料才能提醒。未登入、讀取失敗、跨日或超過 15 分鐘都不算漏訂，不使用舊資料催你。
- 只有網站可預約日期中、尚未訂午餐的日期才算漏訂；未開放日期顯示「待確認」，晚餐不算午餐。請假／不用餐日尚無個別排除設定。
- 預設每天 11:00 告訴你今天吃什麼；11:00～13:59 啟動會補一次。只報網站實際餐點及取餐地點，不編造菜單。
- 操作選單／設定／布置時不會被通知打斷；結束操作後若仍在提醒時段，才補提醒。

例句：「早啊，今天便當還沒訂喔。記得 9 點前訂，我先幫你顧著。」

## 操作與布置

| 操作 | 效果 |
| --- | --- |
| 點人物 | 說話中先補完文字，之後開啟聊天選單 |
| 點對話文字 | 立即顯示整句，不用等逐字播放 |
| 拖曳場景 | 移動整個桌面精靈 |
| 右鍵人物 | 收起對話；隱藏時打開選單 |
| 今天吃什麼 | 今天實際餐點及取餐地點 |
| 看看這週 | 本週／下週五個工作日的簡潔清單 |
| 提醒設定 | 早晨時段、午餐通知、語速、減少動態、同步及網站 |
| 換位同事 | 亞修（盔甲騎士）、莉亞（金髮女騎士）、自訂 PNG |
| 布置辦公桌 | 選物件，拖曳／方向按鈕移動、縮放、色調、隱藏、替換、還原 |
| 去訂便當 | 在連接擴充功能的同一個瀏覽器開啟網站 |
| 右上角 × | 結束精靈及背景查詢 |
| Tab / Shift+Tab / Enter | 鍵盤操作按鈕與選單 |

角色各有 **8 幀工作動畫 + 8 幀轉頭／聊天動作**。桌、椅、螢幕、鍵盤、桌燈、咖啡、盆栽、窗景分別為 **4 幀**獨立圖層。動畫基準點已對齊，桌腳、椅子與物件底部保持穩定。左側電腦冷光與右側桌燈暖光由 Godot shader 依物件位置計算；隱藏光源也會關閉相應光照。

人物身體與桌子正面朝向使用者；工作時看畫面左側，說話時轉正。這是分層 2D 像素場景，採冷暖光與夜景層次。素材由內建 image_gen 依提供的參考生成，再在 Godot 中配置、對齊與照明；不是手繪或完整商業 HD-2D 3D 渲染管線。美術規格及完整 prompts 見 `assets/atelier/ART_DIRECTION.md`、`assets/atelier/prompts.json`。

每個物件都可匯入透明 PNG，環境物件也支援 **2 × 2 四幀 PNG**。自訂圖片限 10 MB、4096 × 4096；會保存應用程式副本。角色、語速、提醒設定、物件位置與替換圖片都會記住。「減少動態」會暫停場景動畫，仍可使用逐字對話。

目前手動啟動，沒有新增開機自啟或系統服務。關閉精靈後不提醒。

## 本機資料

登入完全由原本的瀏覽器管理。擴充功能沒有 Cookie 權限，不會讀取或複製 Cookie、密碼及其他網站資料。網站讀取權限只限 `https://foodcourt.moxa.com/*`，不會按預約、修改或取消；傳給精靈的內容只有日期、已預約清單必要欄位與餐點資料。

- Windows：`%LOCALAPPDATA%\BentoBuddy`
- Linux：`${XDG_DATA_HOME:-~/.local/share}/bento-buddy`

`state.json` 儲存日期、已訂／未訂狀態、今天的餐點與取餐地點，以及查詢時間。`desktop.json`／`extension.json` 是本機連線狀態，`native-host/` 是瀏覽器本機通道設定。精靈關閉後，擴充功能停止定期查詢訂餐；本機通道會留待下次開啟精靈。

新版不使用、不建立 `auth.json` 或 `browser-profile/`。舊版曾產生的這兩個項目可以在關閉舊版後自行刪除，不會影響原本 Chrome／Edge 的登入。

解除安裝：在瀏覽器移除此擴充功能。若也要清除本機註冊，Linux 移除 `~/.config/{google-chrome,chromium,microsoft-edge}/NativeMessagingHosts/com.moxa_bento.buddy.json`；Windows 移除目前使用者的 `Software\Google\Chrome\NativeMessagingHosts\com.moxa_bento.buddy` 與 `Software\Microsoft\Edge\NativeMessagingHosts\com.moxa_bento.buddy` 登錄機碼，再移除上述應用程式資料夾。

UI 偏好另存於 Godot 的 `user://settings.cfg`。目前不包含跨裝置同步。

## 開發與驗證

```bash
python3 -m unittest discover -s tests -v
godot --headless --editor --path . --import --quit
godot --headless --path . --script tests/ui_smoke.gd
godot --path . -- --demo --capture   # output/preview.png，需要圖形環境
# 已啟動虛擬螢幕 :90 時：
DISPLAY=:90 godot --display-driver x11 --path . --script tests/preview_views.gd
DISPLAY=:90 XDG_DATA_HOME="$PWD/output/test90-data" godot --display-driver x11 --path . --script tests/interaction.gd
BENTO_TEST_DISPLAY=:90 python3 -m unittest discover -s tests -p 'test_godot_bootstrap.py' -v
# 開發用真實擴充功能測試（需 OpenSSL；本機 HTTPS 合成訂單）：
.venv/bin/pip install -r requirements-dev.txt
.venv/bin/python -m playwright install chromium
BENTO_EXTENSION_TEST=1 DISPLAY=:90 .venv/bin/python -m unittest discover -s tests -p 'test_extension_integration.py' -v
```

完整圖形與提醒驗證：啟動 :90 後執行 `./scripts/verify_desktop.sh`。

`companion/orders.py` 依實際觀察到的 FoodCourt 欄位解析；測試資料是合成餐點。真實訂單驗證需在使用者平常已登入的瀏覽器載入擴充功能；Windows 原生通道尚待實機驗證。

安裝與 Godot 版本相同的官方 Export Templates 後，執行 `python3 scripts/build.py`，產生 `build/linux` 及 `build/windows`。發行時分享整個資料夾；執行檔會自動啟動旁邊的 `bridge_runner.py`，網站功能仍需先執行 setup 註冊本機通道，並載入瀏覽器擴充功能。Windows 圖示與程式簽章尚未配置。

## 檔案

- `scripts/main.gd`：透明視窗、對話、狀態顯示、稍後提醒。
- `scripts/atelier.gd`：獨立物件、逐幀動畫、工作／聊天轉向、配置與光源。
- `scripts/reminder_policy.gd`：台北時間、9 點截止與早晨時段判斷。
- `assets/atelier/`：透明角色／物件動畫素材、對齊量測與生成 prompts。
- `extension/`：Chrome／Edge 擴充功能，沿用原本登入進行唯讀查詢。
- `companion/bridge.py`：精靈生命週期、連線狀態與本機檔案 IPC。
- `native_host.py`、`companion/native.py`：瀏覽器與精靈的 Native Messaging 通道。
- `register_native_host.py`：目前使用者的跨平台通道註冊，不需管理員權限。
- `companion/orders.py`：日期、週別與預約解析。
- `run.py`：跨平台啟動、單一執行個體及生命週期管理。
- `bridge_runner.py`：Godot 直接啟動時使用的背景查詢入口，會跟隨 Godot 結束。

字體是 Noto Sans CJK TC 的子集，授權見 `assets/fonts/LICENSE.txt`。修改文案後可安裝 `fonttools`，執行 `scripts/subset_font.py /path/to/NotoSansCJK-Regular.ttc` 重新產生字形。
