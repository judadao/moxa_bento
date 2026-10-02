// Runs only on the FoodCourt homepage, inside Chrome's isolated extension world.
// No credentials, cookies, order buttons, or other sites are read or modified.
(() => {
  if (globalThis.bentoBuddyInstalled) return;
  globalThis.bentoBuddyInstalled = true;
  const HOME = "https://foodcourt.moxa.com/foodCourt/staff/home.action?request_locale=zh_TW";
  const HEADERS = ["用餐日期", "餐別", "訂餐內容", "費用方式", "地點", "操作"];
  const normalize = value => value.replace(/\s+/g, " ").trim();

  function extract(doc) {
    if (!doc.querySelector("#btnLogout")) return {error: "login_required"};
    const picker = doc.querySelector("select#targetDay");
    const tables = [...doc.querySelectorAll("table")].filter(table => {
      const first = table.querySelector("tr");
      return first && JSON.stringify([...first.cells].map(cell => normalize(cell.textContent))) === JSON.stringify(HEADERS);
    });
    if (!picker || tables.length !== 1) return {error: "page_changed"};
    const rows = [...tables[0].rows];
    function cellText(cell) {
      const clone = cell.cloneNode(true);
      clone.querySelectorAll("script,style,input,button").forEach(node => node.remove());
      clone.querySelectorAll("br").forEach(node => node.replaceWith(" / "));
      return normalize(clone.textContent);
    }
    return {data: {
      source_url: HOME, logged_in: true,
      dates: [...picker.options].map(option => ({value: option.value, text: normalize(option.textContent)})),
      headers: HEADERS,
      rows: rows.slice(1).map(row => [...row.cells].map(cellText))
    }};
  }

  async function readOrders() {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 20000);
    try {
      // A same-origin request uses the currently signed-in browser session.
      // It does not reload the user's tab or interrupt an in-progress order form.
      const response = await fetch(HOME, {credentials: "same-origin", cache: "no-store", signal: controller.signal});
      if ([401, 403].includes(response.status) || new URL(response.url).origin !== location.origin) return {error: "login_required"};
      if (!response.ok) return {error: "network"};
      const body = await response.text();
      if (body.length > 2 * 1024 * 1024) return {error: "page_changed"};
      return extract(new DOMParser().parseFromString(body, "text/html"));
    } catch {
      // Cross-origin SSO redirects may be blocked by CORS, just like a network error.
      return {error: "network"};
    } finally {
      clearTimeout(timeout);
    }
  }

  chrome.runtime.onMessage.addListener((message, sender, respond) => {
    if (sender.id !== chrome.runtime.id || message.type !== "READ_ORDERS") return;
    readOrders().then(respond).catch(() => respond({error: "network"}));
    return true;
  });
  chrome.runtime.sendMessage({type: "page_ready"}).catch(() => {});
})();
