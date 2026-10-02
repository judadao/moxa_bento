# 2026-10-02 開發檢查點

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
