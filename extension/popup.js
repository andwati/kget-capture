const NATIVE_HOST = "com.kget_capture.host";
const INSTALL_COMMAND =
  "curl -fsSL https://raw.githubusercontent.com/andwati/kget-capture/main/install-remote.sh | bash";

const setupPanel = document.getElementById("setup-needed");
const readyPanel = document.getElementById("ready");
const checkbox = document.getElementById("auto-capture-toggle");
const statusLine = document.getElementById("status-line");
const copyFeedback = document.getElementById("copy-feedback");

function renderStatus(enabled) {
  statusLine.textContent = `Auto-capture: ${enabled ? "ON" : "OFF"}`;
}

function showReady() {
  setupPanel.hidden = true;
  readyPanel.hidden = false;
  chrome.storage.local.get({ autoCaptureEnabled: true }).then(({ autoCaptureEnabled }) => {
    checkbox.checked = autoCaptureEnabled;
    renderStatus(autoCaptureEnabled);
  });
}

function showSetupNeeded() {
  document.getElementById("setup-command").textContent = INSTALL_COMMAND;
  readyPanel.hidden = true;
  setupPanel.hidden = false;
}

// The native host is only reachable once install.sh (or install-remote.sh)
// has registered it -- sendNativeMessage fails with a lastError like
// "Specified native messaging host not found" until then, which is exactly
// the signal we want to gate the rest of the popup on.
function checkNativeHost() {
  chrome.runtime.sendNativeMessage(NATIVE_HOST, { action: "ping" }, () => {
    if (chrome.runtime.lastError) {
      showSetupNeeded();
    } else {
      showReady();
    }
  });
}

checkNativeHost();

document.getElementById("recheck-setup").addEventListener("click", checkNativeHost);

document.getElementById("copy-command").addEventListener("click", async () => {
  try {
    await navigator.clipboard.writeText(INSTALL_COMMAND);
    copyFeedback.textContent = "Copied to clipboard.";
  } catch (e) {
    copyFeedback.textContent = "Couldn't copy -- select and copy the command manually.";
  }
  setTimeout(() => {
    copyFeedback.textContent = "";
  }, 2000);
});

checkbox.addEventListener("change", () => {
  chrome.storage.local.set({ autoCaptureEnabled: checkbox.checked });
  renderStatus(checkbox.checked);
});

document.getElementById("open-download-settings").addEventListener("click", () => {
  chrome.tabs.create({ url: "chrome://settings/downloads" });
});
