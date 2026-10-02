# 便當小夜班 · Bento Buddy

用 Godot 製作的透明桌面精靈：主動用對話氣泡提醒本週漏訂午餐、告訴你今天吃什麼。點人物可以查詢、設定或換角色。Windows / Linux 共用同一份程式。

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

展示模式固定用範例資料，明確標示「非真實訂單」。安裝腳本執行過一次後，在 Godot 編輯器直接執行主場景（F6/F5），或開啟發行資料夾中的執行檔，也會自動啟動背景查詢，不必另外執行啟動腳本。關閉 Godot 後查詢工具會自動結束。

## 怎麼提醒

資料流程：已登入的 Chrome／Edge → 訂餐頁面的唯讀查詢 → 擴充功能 → Native Messaging → 本機精靈。不需要複製網址、Cookie 或重新登入一份帳號。

- 預設檢查本週週一～週五，可切換下週；週別會記住。
- 日期以 **台北時間 UTC+8** 計算，只看「午餐」，任一地點的有效午餐預約都算已訂。晚餐不算。
- 每 5 分鐘讀取 FoodCourt 首頁的「已預約清單」及可預約日期；不會替你下單、修改或取消。
- 瀏覽器原本的登入失效時，按「網站」到同一個瀏覽器驗證即可。不會跳出另一套獨立瀏覽器。瀏覽器關閉／擴充功能斷線會顯示尚未連接，停止用舊資料提醒。
- 日期在網站的可預約選單內、尚未過期、又沒有午餐預約時，顯示「要訂便當了喔！星期 X 午餐還沒訂」。多天會一併列出。
- 日期沒列在網站上時顯示「待確認」，不會自行假設是漏訂或假日。請假／不用訂餐日尚無個別排除設定。
- 登入失效、網路錯誤、網站格式改變、跨日或資料超過 15 分鐘，都不以舊資料發出漏訂提醒。
- 啟動取得資料時會先彈出氣泡，包含本週漏訂日與今天的餐點／取餐地點。
- 預設每天台北時間 11:00 提醒今天午餐（11:00～13:59 開啟或重新連線時補提醒一次）。設定可關閉。
- 自動氣泡約 25 秒收起；按「知道了」也能收起。仍漏訂時預設 30 分鐘後再提醒，設定可改成 15／30／60 分鐘或關閉漏訂提醒。
- 正在操作選單或設定時不會被通知切走；今天沒有確認的預約，就不會編造菜單。

## 操作

| 操作 | 效果 |
| --- | --- |
| 點人物 | 出現「想要我幫你做什麼？」選單 |
| 拖曳人物 | 移動桌面精靈 |
| 右鍵人物／知道了 | 收起氣泡；隱藏時右鍵會打開選單 |
| 今天吃什麼 | 顯示今日已訂午餐內容與取餐地點 |
| 這週漏訂哪天 | 顯示所選週別的週一～週五狀態 |
| 提醒設定 | 通知開關、提醒間隔、本週／下週、網站及立即檢查 |
| 更換人物 | 阿夜（工程師）、小紫（長髮女生）、小栗（短髮女生）或自訂 PNG |
| 去訂便當 | 在已連接擴充功能的瀏覽器開啟訂餐系統 |
| ×／結束精靈 | 關閉精靈及查詢工具 |
| Tab / Shift+Tab / Enter | 導覽並操作對話框按鈕 |

目前需手動啟動，未安裝開機自啟或系統服務。關閉精靈後就不會提醒。

自訂人物接受 10 MB、4096 × 4096 以內的 PNG，建議使用透明背景。圖片會複製到 Godot 的 `user://custom_pet.png`，原圖搬走也不影響角色。人物、通知開關與間隔都會保存。

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

`companion/orders.py` 依實際觀察到的 FoodCourt 欄位解析；測試資料是合成餐點。真實訂單驗證需在使用者平常已登入的瀏覽器載入擴充功能；Windows 原生通道尚待實機驗證。

安裝與 Godot 版本相同的官方 Export Templates 後，執行 `python3 scripts/build.py`，產生 `build/linux` 及 `build/windows`。發行時分享整個資料夾；執行檔會自動啟動旁邊的 `bridge_runner.py`，網站功能仍需先執行 setup 註冊本機通道，並載入瀏覽器擴充功能。Windows 圖示與程式簽章尚未配置。

## 檔案

- `scripts/main.gd`：透明視窗、對話、狀態顯示、稍後提醒。
- `scripts/pixel_engineer.gd`：原創靜態像素角色，以 Godot 方格繪圖，不需外部圖片服務。
- `extension/`：Chrome／Edge 擴充功能，沿用原本登入進行唯讀查詢。
- `companion/bridge.py`：精靈生命週期、連線狀態與本機檔案 IPC。
- `native_host.py`、`companion/native.py`：瀏覽器與精靈的 Native Messaging 通道。
- `register_native_host.py`：目前使用者的跨平台通道註冊，不需管理員權限。
- `companion/orders.py`：日期、週別與預約解析。
- `run.py`：跨平台啟動、單一執行個體及生命週期管理。
- `bridge_runner.py`：Godot 直接啟動時使用的背景查詢入口，會跟隨 Godot 結束。

字體是 Noto Sans CJK TC 的子集，授權見 `assets/fonts/LICENSE.txt`。修改文案後可安裝 `fonttools`，執行 `scripts/subset_font.py /path/to/NotoSansCJK-Regular.ttc` 重新產生字形。
