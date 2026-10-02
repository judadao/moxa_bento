const HOST = "com.moxa_bento.buddy";
const HOME = "https://foodcourt.moxa.com/foodCourt/staff/home.action?request_locale=zh_TW";
const HOME_PATTERN = "https://foodcourt.moxa.com/foodCourt/staff/home*";
let port = null;
let desktopActive = false;
let syncing = null;
let lastSync = 0;
let busyInAnotherBrowser = false;

async function status(code, checkedAt = null) {
  await chrome.storage.local.set({status: code, checkedAt});
  await chrome.action.setBadgeText({text: code === "ok" ? "" : "!"});
  await chrome.action.setBadgeBackgroundColor({color: "#526078"});
}

function connect() {
  if (port) return;
  busyInAnotherBrowser = false;
  port = chrome.runtime.connectNative(HOST);
  port.onMessage.addListener(message => {
    if (message.type === "desktop") {
      desktopActive = message.active === true;
      if (message.action === "login" && desktopActive) {
        openOrders(true).catch(() => status("network"));
      } else if (message.action === "refresh" && desktopActive) {
        syncOrders().catch(() => status("network"));
      } else if (!desktopActive) {
        status("desktop_closed");
      }
    } else if (message.type === "result") {
      busyInAnotherBrowser = message.status === "another_browser";
      status(message.status, message.checked_at);
    }
  });
  port.onDisconnect.addListener(() => {
    // Consume runtime.lastError without logging private page URLs or credentials.
    void chrome.runtime.lastError;
    port = null;
    desktopActive = false;
    status(busyInAnotherBrowser ? "another_browser" : "host_missing");
  });
}

async function openOrders(active = false) {
  const tabs = await chrome.tabs.query({url: HOME_PATTERN});
  if (tabs.length) {
    const tab = tabs[0];
    if (active) return chrome.tabs.update(tab.id, {active: true, url: HOME});
    return tab;
  }
  return chrome.tabs.create({url: HOME, active});
}

function sendError(code) {
  if (port) port.postMessage({type: "error", code});
  return status(code);
}

function waitForPage(tabId) {
  return new Promise((resolve, reject) => {
    const finish = (tab, error) => {
      clearTimeout(timeout);
      chrome.tabs.onUpdated.removeListener(updated);
      chrome.tabs.onRemoved.removeListener(removed);
      if (error) reject(error);
      else resolve(tab);
    };
    const updated = (id, change, tab) => {
      if (id === tabId && change.status === "complete" && !tab.pendingUrl && tab.url !== "about:blank") finish(tab);
    };
    const removed = id => { if (id === tabId) finish(null, new Error("Tab closed")); };
    const timeout = setTimeout(() => finish(null, new Error("Page timeout")), 30000);
    chrome.tabs.onUpdated.addListener(updated);
    chrome.tabs.onRemoved.addListener(removed);
    // Register listeners before checking, so a fast load cannot lose its event.
    chrome.tabs.get(tabId).then(tab => {
      // tabs.create can briefly return a complete about:blank before navigation.
      if (tab.status === "complete" && !tab.pendingUrl && tab.url?.startsWith("https://foodcourt.moxa.com/foodCourt/staff/home")) finish(tab);
    }).catch(error => finish(null, error));
  });
}

async function syncOrders() {
  if (syncing) return syncing;
  if (!port) connect();
  if (!desktopActive) return status("desktop_closed");
  syncing = (async () => {
    await status("syncing");
    const opened = await openOrders(false);
    const tab = await waitForPage(opened.id);
    if (!tab.url?.startsWith("https://foodcourt.moxa.com/foodCourt/staff/home")) return sendError("login_required");
    let result;
    try {
      result = await chrome.tabs.sendMessage(tab.id, {type: "READ_ORDERS"});
    } catch {
      // Covers tabs that were already open when the extension was installed.
      await chrome.scripting.executeScript({target: {tabId: tab.id}, files: ["content.js"]});
      result = await chrome.tabs.sendMessage(tab.id, {type: "READ_ORDERS"});
    }
    if (!desktopActive || !port) return;
    if (result?.error) return sendError(result.error);
    if (!result?.data || JSON.stringify(result.data).length > 200000) return sendError("page_changed");
    port.postMessage({type: "snapshot", data: result.data});
    lastSync = Date.now();
  })().catch(() => sendError("network")).finally(() => { syncing = null; });
  return syncing;
}

chrome.runtime.onMessage.addListener((message, sender, respond) => {
  if (sender.id !== chrome.runtime.id) return;
  if (message.type === "page_ready") {
    // A webpage/content script cannot issue native-host commands or arbitrary payloads.
    if (sender.frameId !== 0 || !sender.url?.startsWith("https://foodcourt.moxa.com/foodCourt/staff/home")) return;
    if (desktopActive) syncOrders();
    return;
  }
  // Only our own popup can ask for manual refresh/open actions.
  if (sender.url !== chrome.runtime.getURL("popup.html")) return;
  if (message.type === "refresh") syncOrders().then(() => respond({ok: true}));
  else if (message.type === "open") openOrders(true).then(() => respond({ok: true}));
  else return;
  return true;
});

chrome.alarms.onAlarm.addListener(alarm => {
  if (alarm.name !== "bento-check") return;
  connect();
  if (desktopActive && Date.now() - lastSync >= 300000) syncOrders();
});
chrome.runtime.onInstalled.addListener(() => connect());
chrome.runtime.onStartup.addListener(() => connect());
chrome.alarms.create("bento-check", {periodInMinutes: 1});
connect();
