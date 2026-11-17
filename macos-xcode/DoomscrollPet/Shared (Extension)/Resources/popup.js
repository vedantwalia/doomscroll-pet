const DEFAULTS = {
  enabled: true,
  thresholdMinutes: 5,
  watchedDomains: ["instagram.com", "reddit.com"]
};

const enabledInput = document.getElementById("enabled");
const thresholdInput = document.getElementById("threshold");
const siteInput = document.getElementById("site-input");
const addSiteButton = document.getElementById("add-site");
const siteList = document.getElementById("site-list");
const saveButton = document.getElementById("save");
const status = document.getElementById("status");
let watchedDomains = [...DEFAULTS.watchedDomains];

function showStatus(message, isError = false) {
  status.textContent = message;
  status.classList.toggle("error", isError);
}

function normalizeDomain(value) {
  const raw = value.trim();
  if (!raw) throw new Error("Enter a website domain.");
  let url;
  try { url = new URL(raw.includes("://") ? raw : `https://${raw}`); }
  catch { throw new Error("Enter a valid website, such as reddit.com."); }
  if (!["http:", "https:"].includes(url.protocol) || url.username || url.password) {
    throw new Error("Use a regular http or https website address.");
  }
  const domain = url.hostname.toLowerCase().replace(/^www\./, "");
  if (!/^(?=.{1,253}$)(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z]{2,63}$/.test(domain)) {
    throw new Error("Enter a valid website domain, such as reddit.com.");
  }
  return domain;
}

function originsFor(domain) {
  return [`*://${domain}/*`, `*://*.${domain}/*`];
}

function renderSites() {
  siteList.replaceChildren();
  for (const domain of watchedDomains) {
    const item = document.createElement("li");
    const label = document.createElement("span");
    label.textContent = domain;
    const remove = document.createElement("button");
    remove.type = "button";
    remove.className = "remove";
    remove.textContent = "Remove";
    remove.setAttribute("aria-label", `Remove ${domain}`);
    remove.addEventListener("click", () => {
      watchedDomains = watchedDomains.filter(item => item !== domain);
      renderSites();
    });
    item.append(label, remove);
    siteList.append(item);
  }
}

async function loadSettings() {
  try {
    const settings = {...DEFAULTS, ...await browser.storage.local.get(DEFAULTS)};
    enabledInput.checked = Boolean(settings.enabled);
    thresholdInput.value = String(settings.thresholdMinutes);
    watchedDomains = [...new Set((settings.watchedDomains || DEFAULTS.watchedDomains).map(normalizeDomain))];
    renderSites();
  } catch (error) {
    showStatus(`Couldn’t load settings: ${error.message}`, true);
  }
}

addSiteButton.addEventListener("click", async () => {
  let domain;
  try { domain = normalizeDomain(siteInput.value); }
  catch (error) { showStatus(error.message, true); return; }
  if (watchedDomains.includes(domain)) {
    showStatus(`${domain} is already on your list.`, true);
    return;
  }

  addSiteButton.disabled = true;
  try {
    const granted = await browser.permissions.request({origins: originsFor(domain)});
    if (!granted) {
      showStatus(`Safari access wasn’t granted, so ${domain} wasn’t added.`, true);
      return;
    }
    watchedDomains.push(domain);
    siteInput.value = "";
    renderSites();
    showStatus(`Added ${domain}.`);
  } catch (error) {
    showStatus(`Couldn’t request Safari access: ${error.message}`, true);
  } finally {
    addSiteButton.disabled = false;
  }
});

siteInput.addEventListener("keydown", event => {
  if (event.key === "Enter") addSiteButton.click();
});

saveButton.addEventListener("click", async () => {
  if (!watchedDomains.length) {
    showStatus("Keep at least one website on your list.", true);
    return;
  }
  saveButton.disabled = true;
  try {
    const origins = watchedDomains.flatMap(originsFor);
    const granted = await browser.permissions.request({origins});
    await browser.storage.local.set({
      enabled: enabledInput.checked,
      thresholdMinutes: Number(thresholdInput.value),
      watchedDomains
    });
    showStatus(granted ? "Settings saved." : "Saved. Allow Safari access for a listed site before monitoring it.", !granted);
  } catch (error) {
    showStatus(`Couldn’t save settings: ${error.message}`, true);
  } finally {
    saveButton.disabled = false;
  }
});

loadSettings();
