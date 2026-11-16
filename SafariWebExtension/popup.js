const DEFAULTS = {
  enabled: true,
  thresholdMinutes: 5,
  watchedDomains: ["youtube.com", "instagram.com", "reddit.com", "tiktok.com"]
};

const enabledInput = document.getElementById("enabled");
const thresholdInput = document.getElementById("threshold");
const domainsInput = document.getElementById("domains");
const saveButton = document.getElementById("save");
const status = document.getElementById("status");

function showStatus(message, isError = false) {
  status.textContent = message;
  status.classList.toggle("error", isError);
}

function normalizeDomains(value) {
  const domains = value.split(/[\n,]+/).map(domain => domain.trim().toLowerCase().replace(/^www\./, ""));
  const unique = [...new Set(domains.filter(Boolean))];
  const valid = unique.filter(domain => /^(?=.{1,253}$)(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z]{2,63}$/.test(domain));
  return {domains: valid, invalid: unique.filter(domain => !valid.includes(domain))};
}

async function loadSettings() {
  try {
    const settings = {...DEFAULTS, ...await browser.storage.local.get(DEFAULTS)};
    enabledInput.checked = Boolean(settings.enabled);
    thresholdInput.value = String(settings.thresholdMinutes);
    domainsInput.value = settings.watchedDomains.join("\n");
  } catch (error) {
    showStatus(`Couldn’t load settings: ${error.message}`, true);
  }
}

saveButton.addEventListener("click", async () => {
  const {domains, invalid} = normalizeDomains(domainsInput.value);
  if (invalid.length) {
    showStatus(`Check these domain names: ${invalid.join(", ")}`, true);
    return;
  }
  if (!domains.length) {
    showStatus("Add at least one watched domain.", true);
    return;
  }

  saveButton.disabled = true;
  try {
    await browser.storage.local.set({
      enabled: enabledInput.checked,
      thresholdMinutes: Number(thresholdInput.value),
      watchedDomains: domains
    });
    showStatus("Settings saved.");
  } catch (error) {
    showStatus(`Couldn’t save settings: ${error.message}`, true);
  } finally {
    saveButton.disabled = false;
  }
});

loadSettings();
