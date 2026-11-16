// Safari Web Extension background script.
// Five minutes on a watched active tab triggers a warning in the Mac app.
// Closing is never automatic: the user must press "Close tab" in the pet UI.
const DEFAULTS = {
  enabled: true,
  thresholdMinutes: 5,
  watchedDomains: ["youtube.com", "instagram.com", "reddit.com", "tiktok.com"]
};

let activeTabId = null;
let activeDomain = null;
let visitStartedAt = Date.now();
let warnedForVisit = false;
let pendingWarningTabId = null;

function domainOf(url) {
  try { return new URL(url).hostname.replace(/^www\./, "").toLowerCase(); }
  catch { return null; }
}
function matches(domain, domains) {
  return !!domain && domains.some(d => domain === d || domain.endsWith("." + d));
}
async function getSettings() {
  const saved = await browser.storage.local.get(DEFAULTS);
  return {...DEFAULTS, ...saved};
}
async function sendWarning(domain, tabId, thresholdMinutes) {
  try {
    await browser.runtime.sendNativeMessage({
      type: "doomscroll.warning",
      domain, tabId, thresholdMinutes
    });
  } catch (e) {
    console.warn("Doomscroll Pet app is unavailable:", e);
  }
}
async function inspectActiveTab() {
  const [tab] = await browser.tabs.query({active: true, lastFocusedWindow: true});
  const domain = tab ? domainOf(tab.url || "") : null;
  if (!tab || tab.id !== activeTabId || domain !== activeDomain) {
    activeTabId = tab?.id ?? null;
    activeDomain = domain;
    visitStartedAt = Date.now();
    warnedForVisit = false;
    pendingWarningTabId = null;
  }

  const cfg = await getSettings();
  if (!cfg.enabled || !matches(activeDomain, cfg.watchedDomains) || warnedForVisit) return;

  if ((Date.now() - visitStartedAt) / 60000 >= Number(cfg.thresholdMinutes || 5)) {
    warnedForVisit = true;
    pendingWarningTabId = activeTabId;
    await sendWarning(activeDomain, activeTabId, cfg.thresholdMinutes);
  }
}

browser.alarms.create("doomscroll-check", {periodInMinutes: 0.5});
browser.alarms.onAlarm.addListener(a => {
  if (a.name === "doomscroll-check") inspectActiveTab();
});
browser.tabs.onActivated.addListener(inspectActiveTab);
browser.tabs.onUpdated.addListener((id, change) => {
  if (id === activeTabId && (change.url || change.status === "complete")) inspectActiveTab();
});
browser.runtime.onStartup.addListener(inspectActiveTab);
browser.runtime.onInstalled.addListener(async () => {
  const saved = await browser.storage.local.get(null);
  await browser.storage.local.set({...DEFAULTS, ...saved});
  inspectActiveTab();
});

// The containing app sends this message only after the user explicitly chooses
// "Close tab". We validate the pending tab ID before removing it.
browser.runtime.onMessage.addListener((message, _sender, sendResponse) => {
  if (message?.name === "doomscroll.confirm-close") {
    const requestedId = Number(message.tabId);
    if (Number.isInteger(requestedId) && requestedId === pendingWarningTabId) {
      browser.tabs.remove(requestedId).then(() => sendResponse({ok: true}))
        .catch(error => sendResponse({ok: false, error: String(error)}));
      pendingWarningTabId = null;
      return true;
    }
  }
  if (message?.name === "doomscroll.dismiss") {
    pendingWarningTabId = null;
    sendResponse({ok: true});
  }
});

// Messages dispatched by the containing macOS app arrive in the extension runtime.
browser.runtime.onMessage.addListener((message, _sender, sendResponse) => {
  if (message?.name === "doomscroll.confirm-close") {
    const id = Number(message.tabId);
    if (Number.isInteger(id) && id === pendingWarningTabId) {
      browser.tabs.remove(id).then(() => sendResponse({ok: true}))
        .catch(error => sendResponse({ok: false, error: String(error)}));
      pendingWarningTabId = null;
      return true;
    }
  }
  if (message?.name === "doomscroll.dismiss") {
    pendingWarningTabId = null;
    sendResponse({ok: true});
  }
});
