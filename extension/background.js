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

// KGet is a network download manager -- it can't "download" a URL that's
// already local (or embedded in the page), so don't hand it these schemes.
// file: shows up when saving a page you navigated to directly (Ctrl+S on a
// file:// URL is still a "download" as far as chrome.downloads is
// concerned), and KGet's addTransfer rejects it with a confusing
// "protocol is not supported" dialog if we try.
const UNSUPPORTED_SCHEMES = ["blob:", "data:", "file:", "filesystem:"];

function isCapturableUrl(url) {
  return !UNSUPPORTED_SCHEMES.some((scheme) => url.startsWith(scheme));
}

function sendToKGet(url, filename) {
  chrome.runtime.sendNativeMessage(
    NATIVE_HOST,
    { action: "addTransfer", url, filename: filename || null },
    (response) => {
      if (chrome.runtime.lastError) {
        console.error("[kget-capture] native host error:", chrome.runtime.lastError.message);
        return;
      }
      if (!response || !response.ok) {
        console.error("[kget-capture] KGet reported failure:", response && response.error);
      }
    }
  );
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

// Downloads started from the context menu, tracked so captureDownload()
// still resolves/forwards their real filename even when auto-capture is
// toggled off -- a right-click "Download with KGet" should always work.
const pendingContextMenuDownloads = new Set();

chrome.contextMenus.onClicked.addListener((info) => {
  if (info.menuItemId !== MENU_ID) return;
  const url = info.linkUrl || info.srcUrl;
  if (!url) return;
  if (!isCapturableUrl(url)) {
    console.warn("[kget-capture] cannot hand a local/embedded URL to KGet:", url);
    return;
  }
  // Route through chrome.downloads instead of sending the raw URL straight
  // to KGet -- this reuses onDeterminingFilename/captureDownload below to
  // get Chrome's real resolved filename (Content-Disposition, etc.) instead
  // of leaving KGet to guess one from the bare URL, which drops query
  // strings and gets opaque/signed URLs wrong.
  chrome.downloads.download({ url }, (downloadId) => {
    if (chrome.runtime.lastError || downloadId === undefined) {
      console.error(
        "[kget-capture] couldn't start download to resolve filename, falling back to raw URL:",
        chrome.runtime.lastError && chrome.runtime.lastError.message
      );
      sendToKGet(url, null);
      return;
    }
    pendingContextMenuDownloads.add(downloadId);
  });
});

// onDeterminingFilename (rather than onCreated) fires once Chrome has
// already resolved the real filename (from Content-Disposition or the URL),
// which is exactly what we need to hand KGet the correct name instead of an
// opaque URL path segment.
chrome.downloads.onDeterminingFilename.addListener((item, suggest) => {
  // We're about to cancel this download regardless, so Chrome's own choice
  // doesn't matter -- just let it proceed so the event resolves promptly.
  suggest();
  captureDownload(item);
});

async function captureDownload(item) {
  const isContextMenuCapture = pendingContextMenuDownloads.delete(item.id);
  const { autoCaptureEnabled } = await chrome.storage.local.get({ autoCaptureEnabled: true });
  if (!autoCaptureEnabled && !isContextMenuCapture) return;

  const url = item.finalUrl || item.url;
  if (!isCapturableUrl(url)) {
    console.warn("[kget-capture] cannot hand a local/embedded URL to KGet, letting Chrome handle it:", url);
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

  const filename = item.filename ? item.filename.split(/[\\/]/).pop() : null;
  sendToKGet(url, filename);
}

chrome.storage.onChanged.addListener((changes, area) => {
  if (area === "local" && "autoCaptureEnabled" in changes) {
    updateBadge(changes.autoCaptureEnabled.newValue);
  }
});

refreshBadge();
