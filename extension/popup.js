const checkbox = document.getElementById("auto-capture-toggle");
const statusLine = document.getElementById("status-line");

function renderStatus(enabled) {
  statusLine.textContent = `Auto-capture: ${enabled ? "ON" : "OFF"}`;
}

chrome.storage.local.get({ autoCaptureEnabled: true }).then(({ autoCaptureEnabled }) => {
  checkbox.checked = autoCaptureEnabled;
  renderStatus(autoCaptureEnabled);
});

checkbox.addEventListener("change", () => {
  chrome.storage.local.set({ autoCaptureEnabled: checkbox.checked });
  renderStatus(checkbox.checked);
});
