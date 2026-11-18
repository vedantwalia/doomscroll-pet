// Safari Web Extension background script.
// The cat approaches shortly before the selected visit limit. The user decides
// whether to keep browsing or close the active tab when the limit is reached.
const DEFAULTS = {
  enabled: true,
  thresholdMinutes: 5,
  watchedDomains: ["instagram.com", "reddit.com"]
};
const LEGACY_DEFAULTS = ["youtube.com", "instagram.com", "reddit.com", "tiktok.com"];
const APPROACH_SECONDS = 30;

let activeTabId = null;
let activeDomain = null;
let visitStartedAt = Date.now();
let warnedForVisit = false;
let pendingWarningTabId = null;
let approachSentForVisit = false;

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
async function sendNativeEvent(type, domain, tabId, thresholdMinutes) {
  try {
    await browser.runtime.sendNativeMessage({
      type,
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
    if (approachSentForVisit || warnedForVisit) {
      await sendNativeEvent("doomscroll.hide", activeDomain, activeTabId, null);
    }
    activeTabId = tab?.id ?? null;
    activeDomain = domain;
    visitStartedAt = Date.now();
    warnedForVisit = false;
    pendingWarningTabId = null;
    approachSentForVisit = false;
  }

  const cfg = await getSettings();
  if (!cfg.enabled || !matches(activeDomain, cfg.watchedDomains)) {
    if (approachSentForVisit || warnedForVisit) {
      await sendNativeEvent("doomscroll.hide", activeDomain, activeTabId, null);
      approachSentForVisit = false;
    }
    return;
  }
  if (warnedForVisit) return;

  const thresholdSeconds = Number(cfg.thresholdMinutes || 5) * 60;
  const elapsedSeconds = (Date.now() - visitStartedAt) / 1000;
  const remainingSeconds = thresholdSeconds - elapsedSeconds;
  if (remainingSeconds > APPROACH_SECONDS && approachSentForVisit) {
    await sendNativeEvent("doomscroll.hide", activeDomain, activeTabId, null);
    approachSentForVisit = false;
  }
  if (remainingSeconds <= APPROACH_SECONDS && remainingSeconds > 0 && !approachSentForVisit) {
    approachSentForVisit = true;
    await sendNativeEvent("doomscroll.approach", activeDomain, activeTabId, cfg.thresholdMinutes);
  }

  if (remainingSeconds <= 0 && !warnedForVisit) {
    warnedForVisit = true;
    pendingWarningTabId = activeTabId;
    await sendNativeEvent("doomscroll.warning", activeDomain, activeTabId, cfg.thresholdMinutes);
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
browser.storage.onChanged.addListener((_changes, areaName) => {
  if (areaName === "local") inspectActiveTab();
});
browser.runtime.onStartup.addListener(inspectActiveTab);
browser.runtime.onInstalled.addListener(async (details) => {
  const saved = await browser.storage.local.get(null);
  const savedDomains = Array.isArray(saved.watchedDomains) ? saved.watchedDomains : null;
  const isOldDefault = savedDomains && savedDomains.length === LEGACY_DEFAULTS.length
    && LEGACY_DEFAULTS.every(domain => savedDomains.includes(domain));
  const watchedDomains = !savedDomains || (details.reason === "update" && isOldDefault)
    ? DEFAULTS.watchedDomains
    : savedDomains;
  await browser.storage.local.set({...DEFAULTS, ...saved, watchedDomains});
  inspectActiveTab();
});
// Messages sent by SFSafariApplication.dispatchMessage arrive on the native
// messaging port. A runtime.onMessage listener does not receive this channel.
const nativeAppPort = browser.runtime.connectNative("com.vedantwalia.DoomscrollPet");
nativeAppPort.onMessage.addListener(message => {
  // The host's dispatchMessage name is a channel name; its userInfo dictionary
  // becomes the message payload. Accept `name` as well for older host builds.
  const action = message?.action || message?.name;
  const tabId = Number(message?.tabId ?? message?.userInfo?.tabId);

  // Validate the pending tab ID before removing anything.
  if (action === "doomscroll.confirm-close") {
    if (Number.isInteger(tabId) && tabId === pendingWarningTabId) {
      browser.tabs.remove(tabId).catch(error => console.warn("Doomscroll Pet could not close the tab:", error));
      pendingWarningTabId = null;
    }
  }
  if (action === "doomscroll.dismiss") {
    pendingWarningTabId = null;
  }
});
