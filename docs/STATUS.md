# 2026-10-02 開發檢查點（沿用原本瀏覽器登入）

已將專用 Playwright 瀏覽器改成 Chrome／Edge MV3 擴充功能 + Python Native Messaging。擴充功能從同一瀏覽器的 FoodCourt 頁面做唯讀查詢，只傳必要訂餐欄位；不讀取或保存 Cookie、密碼，不再建立另一套登入 profile。既有分頁不會因背景查詢而重新整理；沒有分頁時自動開啟首頁。精靈「網站／去訂便當」也會使用這個瀏覽器。

執行時僅需 Python 標準函式庫；`setup-linux.sh`／`setup-windows.bat` 註冊目前使用者的本機通道。Linux 本機已執行 `register_native_host.py`。**實際使用仍需在常用瀏覽器手動載入 `extension/` 一次**，固定 ID `ljoghkimjdcdpkpefnkjcicgecegphbj`。瀏覽器和精靈必須在同一台電腦，載入方式見 README。公司網站真實訂單同步、Windows 本機通道尚待實機驗證，沒有宣稱已驗證。

主要變更：`extension/`、`companion/native.py`、`native_host.py`、`register_native_host.py`、`companion/bridge.py`、安裝／啟動／打包腳本、Godot 網站按鈕與字體、README，以及原生通道和瀏覽器整合測試。原來的角色、氣泡、提醒與退出功能保留。

驗證命令：`BENTO_EXTENSION_TEST=1 BENTO_TEST_DISPLAY=:90 DISPLAY=:90 .venv/bin/python -m unittest discover -s tests -v`，**26 個測試全部通過（10.350 秒）**。整合測試用真實 Chromium 擴充功能及 native host，網站、登入 Cookie 與餐點全是隔離的合成資料；覆蓋沿用登入、今日餐點、登入失效／恢復、新分頁自動同步、關閉精靈停止查詢。測試 log：`output/final-tests-90.log`。Godot UI smoke 在 :90 通過，JS syntax checks 通過。

測試以本機 HTTPS fixture 與 Chromium hostname 映射攔住所有 FoodCourt 請求，也停用其他外部 DNS；避免擴充功能開分頁時第一個導覽早於 Playwright route 攔截。憑證與測試 Cookie 只用於暫存的隔離測試 profile。

保留 tmux session：`bento-xvfb-90`，可用 `tmux attach -t bento-xvfb-90` 檢視。完整測試執行於 `bento-final-tests-90-r3`，完成即離開。下一步：使用者載入擴充功能後，核對真實本週午餐與今日餐點；Windows 實機檢查註冊與同步。沒有匯出可執行發行檔。

## 歷史：氣泡互動與直接啟動修正

使用者截圖確認原先「撈不到資料」是直接開 Godot，沒有啟動 Python 查詢工具。已修正：F5 / 直接執行 Godot 自動啟動 `bridge_runner.py`，使用相同本機資料夾與鎖；Godot 結束時 helper 跟著停止。已用真實 Godot → Python 子程序 → 狀態檔整合測試驗證（網路層用合成 fixture）。

新增點人物開選單、今日餐點／取餐地點氣泡、每週漏訂氣泡、15/30/60 分鐘提醒設定、11:00 午餐通知開關、工程師／長髮女生／短髮女生、自訂 PNG 保存。右上角 × 和選單「結束精靈」均退出；「知道了」只收起氣泡。

本次最新驗證：20 個 Python 測試、Godot UI smoke 全部通過。依使用者要求，圖形互動測試在虛擬螢幕 **:90（1280×800，Xvfb / llvmpipe）** 執行，透過 Godot 輸入事件實際點選人物、選單、女生角色、退出按鈕，並驗證 PNG 匯入。兩種退出方式均成功。六個畫面的氣泡邊界均在人物上方。

保留的 tmux session：`bento-xvfb-90`（虛擬 X server），可用 `tmux attach -t bento-xvfb-90` 檢視；測試程序已結束。測試輸出及隔離設定位於 `output/display90-*.log`、`output/test90-data/`。`docs/preview.png`、`docs/menu.png` 和兩張女生角色預覽已更新，均為範例訂單。

仍待使用者完成精靈專用瀏覽器的公司 SSO 後驗證真實背景訂單同步；既有 Chrome 已登入不等於專用瀏覽器已登入。Windows 仍待實機驗證。

## 初版紀錄

已完成 Godot 靜態像素桌面精靈、透明置頂視窗、繁中對話、週一至週五午餐漏訂判斷、本週／下週切換、30 分鐘稍後提醒、Windows/Linux 啟動腳本與匯出設定。

自動登入：啟動先讀本機工作階段；未登入時自動開專用瀏覽器，從 FoodCourt 首頁依網站導向 Microsoft SSO，返回首頁後自動同步。已登入時在背景查詢；取消登入不會反覆彈窗。Windows 優先使用已安裝 Edge，Linux 優先已安裝 Edge/Chrome，否則使用安裝腳本提供的 Chromium。

驗證結果：

- `python3 -m unittest discover -s tests -v`：15 個測試通過（日期/午餐/格式異常、背景登入、自動開啟登入、保存工作階段、取消不重開）。登入生命週期測試使用模擬瀏覽器。
- `godot --headless --path . --script tests/ui_smoke.gd`：漏訂、全部已訂、稍後提醒/恢復、過期及未登入狀態通過。
- Godot 4.7.1 / Linux X11 圖形環境實際渲染確認，截圖 `docs/preview.png`。
- 已在使用者登入的 FoodCourt 頁面核對 `#targetDay` 及 `.booked` 表格結構；未讀取或複製該瀏覽器的登入資料。
- 真實未登入查詢確認會被導向 Microsoft SSO；專用瀏覽器登入成功後的真實自動查詢仍待使用者完成登入驗證。
- Windows runtime 尚未實機驗證。未產出 Windows/Linux 發行執行檔；專案可用 Godot + Python 啟動，匯出需另裝匹配版本的官方 templates。

本次安裝、預覽及下載曾使用 `bento-*` tmux sessions，完成後沒有需要保留的背景工作。中止了大型 export templates 下載，暫存位於已忽略的 `output/`。本機 `.aws` 空檔不是本次專案內容，未加入版本控制。

下一步：在 Windows 與 Linux 以啟動腳本開啟，完成專用瀏覽器第一次 SSO（若要求），驗證目前預約、下週漏訂、MFA/登入逾期、不同桌面環境置頂/拖曳效果；需要發行檔時安裝 Export Templates 後執行 `python3 scripts/build.py`。
