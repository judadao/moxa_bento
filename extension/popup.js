const labels = {
  ok: "已同步到桌面精靈。會每 5 分鐘更新。",
  syncing: "正在讀取你已登入的訂餐頁面…",
  host_missing: "本機同步工具未連接。請先執行新版 setup 安裝腳本，再重新載入擴充功能。",
  desktop_closed: "桌面精靈尚未啟動，目前不會自動讀取訂餐資料。",
  another_browser: "另一個 Chrome／Edge 已連接精靈，請只在一個瀏覽器啟用此擴充功能。",
  login_required: "原本的網站登入已過期，請開啟訂餐頁面重新驗證。",
  network: "頁面讀取失敗。請開啟訂餐頁面確認登入與網路。",
  page_changed: "訂餐網站欄位有變動，暫時無法確認訂單。",
  unknown: "無法辨識訂餐資料，暫停漏訂判斷。",
  page_loading: "正在原本的瀏覽器載入訂餐頁面…"
};
async function render() {
  const data = await chrome.storage.local.get(["status", "checkedAt"]);
  document.getElementById("status").textContent = labels[data.status] || "正在連接本機精靈…";
  document.getElementById("checked").textContent = data.checkedAt ? "上次同步：" + new Date(data.checkedAt).toLocaleTimeString("zh-TW", {timeZone: "Asia/Taipei"}) : "";
}
for (const type of ["refresh", "open"]) {
  document.getElementById(type).addEventListener("click", () => chrome.runtime.sendMessage({type}).then(render).catch(() => {
    document.getElementById("status").textContent = "連線失敗，請重新載入擴充功能。";
  }));
}
chrome.storage.onChanged.addListener(render);
render();
