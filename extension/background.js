const NATIVE_HOST = "com.kget_capture.host";
const MENU_ID = "kget-capture-download";

function updateBadge(enabled) {
  chrome.action.setBadgeText({ text: enabled ? "ON" : "OFF" });
  chrome.action.setBadgeBackgroundColor({ color: enabled ? "#2e7d32" : "#9e9e9e" });
}

async function refreshBadge() {
  const { autoCaptureEnabled } = await chrome.storage.local.get({ autoCaptureEnabled: true });
  updateBadge(autoCaptureEnabled);
}

function sendToKGet(url) {
  chrome.runtime.sendNativeMessage(NATIVE_HOST, { action: "addTransfer", url }, (response) => {
    if (chrome.runtime.lastError) {
      console.error("[kget-capture] native host error:", chrome.runtime.lastError.message);
      return;
    }
    if (!response || !response.ok) {
      console.error("[kget-capture] KGet reported failure:", response && response.error);
    }
  });
}

chrome.runtime.onInstalled.addListener(async (details) => {
  chrome.contextMenus.create({
    id: MENU_ID,
    title: "Download with KGet",
    contexts: ["link", "image", "video", "audio"],
  });

  if (details.reason === "install") {
    await chrome.storage.local.set({ autoCaptureEnabled: true });
  }
  refreshBadge();
});

chrome.contextMenus.onClicked.addListener((info) => {
  if (info.menuItemId !== MENU_ID) return;
  const url = info.linkUrl || info.srcUrl;
  if (!url) return;
  sendToKGet(url);
});

chrome.downloads.onCreated.addListener(async (item) => {
  const { autoCaptureEnabled } = await chrome.storage.local.get({ autoCaptureEnabled: true });
  if (!autoCaptureEnabled) return;

  const url = item.finalUrl || item.url;
  if (url.startsWith("blob:") || url.startsWith("data:")) {
    console.warn("[kget-capture] cannot redirect blob:/data: URL, letting Chrome handle it:", url);
    return;
  }

  try {
    await chrome.downloads.cancel(item.id);
    // erase() only clears the history entry -- it does NOT delete the
    // partial file Chrome already wrote to disk. removeFile() does that.
    await chrome.downloads.removeFile(item.id);
  } catch (e) {
    // Expected if Chrome finished the download before cancel() landed, or
    // hadn't written any bytes yet -- not worth surfacing to the user.
  }
  try {
    await chrome.downloads.erase({ id: item.id });
  } catch (e) {
    console.error("[kget-capture] failed to erase Chrome download entry:", e);
  }
  sendToKGet(url);
});

chrome.storage.onChanged.addListener((changes, area) => {
  if (area === "local" && "autoCaptureEnabled" in changes) {
    updateBadge(changes.autoCaptureEnabled.newValue);
  }
});

refreshBadge();
