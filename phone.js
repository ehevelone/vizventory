const params = new URLSearchParams(window.location.search);
const sessionId = params.get("session") || "";

const els = {
  status: document.querySelector("#phoneStatus"),
  input: document.querySelector("#phonePhotoInput"),
  preview: document.querySelector("#phonePreview"),
  sendBtn: document.querySelector("#sendPhonePhotoBtn"),
  chooseAnotherBtn: document.querySelector("#chooseAnotherPhonePhotoBtn")
};

let selectedPhoto = "";

function fileToDataUrl(file) {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = () => resolve(reader.result);
    reader.onerror = reject;
    reader.readAsDataURL(file);
  });
}

function setStatus(message) {
  els.status.textContent = message;
}

els.input.addEventListener("change", async () => {
  const file = els.input.files[0];
  if (!file) return;
  selectedPhoto = await fileToDataUrl(file);
  els.preview.innerHTML = `<img src="${selectedPhoto}" alt="Selected inventory item">`;
  setStatus("Picture ready. Send it to the desktop when it looks good.");
});

els.chooseAnotherBtn.addEventListener("click", () => els.input.click());

els.sendBtn.addEventListener("click", async () => {
  if (!sessionId) {
    setStatus("Missing camera session. Open the link from the desktop again.");
    return;
  }
  if (!selectedPhoto) {
    els.input.click();
    return;
  }

  setStatus("Sending picture...");
  const response = await fetch("/api/phone-photos", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ sessionId, photoData: selectedPhoto })
  });
  const data = await response.json();
  if (!response.ok) {
    setStatus(data.error || "Could not send picture.");
    return;
  }

  selectedPhoto = "";
  els.input.value = "";
  els.preview.innerHTML = "";
  setStatus(`Sent to desktop. Total sent this session: ${data.count}.`);
});

if (!sessionId) {
  setStatus("Missing camera session. Open this from the desktop Connect Camera Device button.");
}
