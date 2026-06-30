const state = {
  items: [],
  categories: [],
  authMode: "login",
  auth: null,
  stream: null,
  scanTimer: null,
  photoStream: null,
  capturedPhotos: [],
  phoneSession: null,
  phonePollTimer: null,
  phonePhotoCursor: 0,
  settings: {
    photoDeviceId: "",
    scannerDeviceId: ""
  }
};

const els = {
  authView: document.querySelector("#authView"),
  appView: document.querySelector("#appView"),
  authForm: document.querySelector("#authForm"),
  authTitle: document.querySelector("#authTitle"),
  authMessage: document.querySelector("#authMessage"),
  authEmail: document.querySelector("#authEmail"),
  authPassword: document.querySelector("#authPassword"),
  authName: document.querySelector("#authName"),
  authOrganization: document.querySelector("#authOrganization"),
  authOrganizationType: document.querySelector("#authOrganizationType"),
  signupFields: document.querySelector("#signupFields"),
  authSubmitBtn: document.querySelector("#authSubmitBtn"),
  toggleAuthModeBtn: document.querySelector("#toggleAuthModeBtn"),
  accountBar: document.querySelector("#accountBar"),
  accountEmail: document.querySelector("#accountEmail"),
  signOutBtn: document.querySelector("#signOutBtn"),
  stats: document.querySelector(".stats"),
  form: document.querySelector("#itemForm"),
  clearFormBtn: document.querySelector("#clearFormBtn"),
  category: document.querySelector("#category"),
  subcategory: document.querySelector("#subcategory"),
  photos: document.querySelector("#photos"),
  connectPhoneBtn: document.querySelector("#connectPhoneBtn"),
  openPhotoPickerBtn: document.querySelector("#openPhotoPickerBtn"),
  classifyPhotoBtn: document.querySelector("#classifyPhotoBtn"),
  aiSuggestNote: document.querySelector("#aiSuggestNote"),
  openLiveCameraBtn: document.querySelector("#openLiveCameraBtn"),
  photoPreview: document.querySelector("#photoPreview"),
  cameraDialog: document.querySelector("#cameraDialog"),
  photoVideo: document.querySelector("#photoVideo"),
  photoCameraEmpty: document.querySelector("#photoCameraEmpty"),
  capturePhotoBtn: document.querySelector("#capturePhotoBtn"),
  closeCameraBtn: document.querySelector("#closeCameraBtn"),
  inventoryList: document.querySelector("#inventoryList"),
  template: document.querySelector("#itemTemplate"),
  searchInput: document.querySelector("#searchInput"),
  statusFilter: document.querySelector("#statusFilter"),
  printVisibleBtn: document.querySelector("#printVisibleBtn"),
  availableCount: document.querySelector("#availableCount"),
  checkedOutCount: document.querySelector("#checkedOutCount"),
  startScanBtn: document.querySelector("#startScanBtn"),
  stopScanBtn: document.querySelector("#stopScanBtn"),
  scannerVideo: document.querySelector("#scannerVideo"),
  scannerEmpty: document.querySelector("#scannerEmpty"),
  scannerStatus: document.querySelector("#scannerStatus"),
  manualId: document.querySelector("#manualId"),
  manualCheckoutBtn: document.querySelector("#manualCheckoutBtn"),
  refreshCamerasBtn: document.querySelector("#refreshCamerasBtn"),
  photoCameraSelect: document.querySelector("#photoCameraSelect"),
  dialogPhotoCameraSelect: document.querySelector("#dialogPhotoCameraSelect"),
  scannerCameraSelect: document.querySelector("#scannerCameraSelect"),
  connectPhotoCameraBtn: document.querySelector("#connectPhotoCameraBtn"),
  connectScannerCameraBtn: document.querySelector("#connectScannerCameraBtn"),
  dialogRefreshCamerasBtn: document.querySelector("#dialogRefreshCamerasBtn"),
  dialogConnectPhotoCameraBtn: document.querySelector("#dialogConnectPhotoCameraBtn"),
  phoneDialog: document.querySelector("#phoneDialog"),
  closePhoneDialogBtn: document.querySelector("#closePhoneDialogBtn"),
  phoneConnectStatus: document.querySelector("#phoneConnectStatus"),
  cameraQrCode: document.querySelector("#cameraQrCode"),
  phoneConnectUrl: document.querySelector("#phoneConnectUrl"),
  openCameraDeviceLinkBtn: document.querySelector("#openCameraDeviceLinkBtn"),
  copyPhoneLinkBtn: document.querySelector("#copyPhoneLinkBtn"),
  refreshPhoneSessionBtn: document.querySelector("#refreshPhoneSessionBtn"),
  cameraSettingsNote: document.querySelector("#cameraSettingsNote")
};

const settingsKey = "vizventoryCameraSettings";
const authKey = "vizventoryAuth";

const defaultCategories = [
  { name: "Clothing", subcategories: ["Tops", "Bottoms", "Dresses", "Outerwear", "Shoes", "Accessories", "Bags", "Jewelry", "Kids", "Other Clothing"] },
  { name: "Equipment", subcategories: ["Office Equipment", "Medical Equipment", "Audio/Visual", "Field Equipment", "Other Equipment"] },
  { name: "Tool", subcategories: ["Hand Tools", "Power Tools", "Tool Sets", "Measuring Tools"] },
  { name: "Electronics", subcategories: ["Computers", "Phones/Tablets", "Cameras", "Cables/Adapters"] },
  { name: "Furniture", subcategories: ["Desk/Table", "Chair/Seating", "Shelf/Storage"] },
  { name: "Supply", subcategories: ["Office Supplies", "Cleaning Supplies", "Packaging Supplies"] },
  { name: "Document", subcategories: ["Forms", "Manuals", "Records"] },
  { name: "Artwork", subcategories: [] },
  { name: "Part", subcategories: [] },
  { name: "Container", subcategories: ["Box", "Bin/Tote", "Case"] },
  { name: "Miscellaneous", subcategories: ["Unsorted", "Unknown", "Oddball", "Mixed Lot"] },
  { name: "Other", subcategories: [] }
];

const code39 = {
  "0": "101001101101",
  "1": "110100101011",
  "2": "101100101011",
  "3": "110110010101",
  "4": "101001101011",
  "5": "110100110101",
  "6": "101100110101",
  "7": "101001011011",
  "8": "110100101101",
  "9": "101100101101",
  A: "110101001011",
  B: "101101001011",
  C: "110110100101",
  D: "101011001011",
  E: "110101100101",
  F: "101101100101",
  G: "101010011011",
  H: "110101001101",
  I: "101101001101",
  J: "101011001101",
  K: "110101010011",
  L: "101101010011",
  M: "110110101001",
  N: "101011010011",
  O: "110101101001",
  P: "101101101001",
  Q: "101010110011",
  R: "110101011001",
  S: "101101011001",
  T: "101011011001",
  U: "110010101011",
  V: "100110101011",
  W: "110011010101",
  X: "100101101011",
  Y: "110010110101",
  Z: "100110110101",
  "-": "100101011011",
  ".": "110010101101",
  " ": "100110101101",
  "$": "100100100101",
  "/": "100100101001",
  "+": "100101001001",
  "%": "101001001001",
  "*": "100101101101"
};

function escapeHtml(value) {
  return String(value || "").replace(/[&<>"']/g, (char) => ({
    "&": "&amp;",
    "<": "&lt;",
    ">": "&gt;",
    "\"": "&quot;",
    "'": "&#039;"
  })[char]);
}

async function api(path, options = {}) {
  const headers = {
    "Content-Type": "application/json",
    ...(options.headers || {})
  };
  if (state.auth?.accessToken) headers.Authorization = `Bearer ${state.auth.accessToken}`;
  if (state.auth?.organizationId) headers["X-Vizventory-Organization-Id"] = state.auth.organizationId;
  const response = await fetch(path, {
    ...options,
    headers
  });
  const data = await response.json();
  if (!response.ok) {
    if (response.status === 401) showAuth("Please sign in again.");
    throw new Error(data.error || "Something went wrong");
  }
  return data;
}

function loadStoredAuth() {
  try {
    return JSON.parse(localStorage.getItem(authKey) || "null");
  } catch {
    return null;
  }
}

function saveAuth(auth) {
  state.auth = auth;
  localStorage.setItem(authKey, JSON.stringify(auth));
}

function clearAuth() {
  state.auth = null;
  localStorage.removeItem(authKey);
}

function setAuthMode(mode) {
  state.authMode = mode;
  const signup = mode === "signup";
  els.authTitle.textContent = signup ? "Create your Vizventory account" : "Sign in to Vizventory";
  els.authSubmitBtn.textContent = signup ? "Create Account" : "Sign In";
  els.toggleAuthModeBtn.textContent = signup ? "I Already Have an Account" : "Create Account";
  els.signupFields.hidden = !signup;
  els.authPassword.autocomplete = signup ? "new-password" : "current-password";
  els.authMessage.textContent = signup
    ? "Create an account and your own inventory workspace."
    : "Use your Vizventory account to manage your inventory.";
}

function authModeFromLocation() {
  const params = new URLSearchParams(window.location.search);
  return params.get("register") === "1" || params.get("mode") === "register" ? "signup" : "login";
}

function showAuth(message = "") {
  clearAuth();
  els.appView.hidden = true;
  els.authView.hidden = false;
  els.accountBar.hidden = true;
  els.stats.hidden = false;
  if (message) els.authMessage.textContent = message;
}

function showApp() {
  els.authView.hidden = true;
  els.appView.hidden = false;
  els.accountBar.hidden = false;
  els.accountEmail.textContent = state.auth?.email || "";
}

async function authenticate(event) {
  event.preventDefault();
  const signup = state.authMode === "signup";
  els.authSubmitBtn.disabled = true;
  els.authMessage.textContent = signup ? "Creating account..." : "Signing in...";
  try {
    const data = await api(signup ? "/api/auth/signup" : "/api/auth/login", {
      method: "POST",
      body: JSON.stringify({
        email: els.authEmail.value,
        password: els.authPassword.value,
        fullName: els.authName.value,
        organizationName: els.authOrganization.value,
        organizationType: els.authOrganizationType.value
      })
    });
    if (!data.accessToken) {
      setAuthMode("login");
      els.authMessage.textContent = "Account created. Check your email if Supabase asks for confirmation, then sign in.";
      return;
    }
    saveAuth({
      accessToken: data.accessToken,
      refreshToken: data.refreshToken,
      organizationId: data.organizationId,
      email: data.user?.email || els.authEmail.value
    });
    showApp();
    await loadCategories();
    await loadItems();
  } catch (error) {
    els.authMessage.textContent = error.message;
  } finally {
    els.authSubmitBtn.disabled = false;
  }
}

async function restoreSession() {
  const stored = loadStoredAuth();
  if (!stored?.accessToken) {
    showAuth();
    return;
  }
  state.auth = stored;
  try {
    const data = await api("/api/auth/me");
    saveAuth({
      ...stored,
      organizationId: data.organizationId,
      email: data.user?.email || stored.email
    });
    showApp();
    await loadCategories();
    await loadItems();
  } catch {
    showAuth("Please sign in to continue.");
  }
}

function fileToDataUrl(file) {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = () => resolve(reader.result);
    reader.onerror = reject;
    reader.readAsDataURL(file);
  });
}

function renderPhotoPreview() {
  const filePreviews = [...els.photos.files].map((file, index) => ({
    id: `file-${index}`,
    name: file.name,
    url: URL.createObjectURL(file),
    removable: false
  }));
  const cameraPreviews = state.capturedPhotos.map((url, index) => ({
    id: `captured-${index}`,
    name: `Captured photo ${index + 1}`,
    url,
    removable: true,
    index
  }));

  els.photoPreview.innerHTML = "";
  [...filePreviews, ...cameraPreviews].forEach((photo) => {
    const figure = document.createElement("figure");
    figure.innerHTML = `<img src="${photo.url}" alt="${escapeHtml(photo.name)}">`;
    if (photo.removable) {
      const button = document.createElement("button");
      button.type = "button";
      button.textContent = "Remove";
      button.addEventListener("click", () => {
        state.capturedPhotos.splice(photo.index, 1);
        renderPhotoPreview();
      });
      figure.appendChild(button);
    }
    els.photoPreview.appendChild(figure);
  });
}

function bestPhoneUrl(data) {
  return data.phoneUrls?.[0] || data.localUrl || "";
}

async function pollPhonePhotos() {
  if (!state.phoneSession) return;
  const data = await api(`/api/phone-photos?session=${encodeURIComponent(state.phoneSession.sessionId)}&after=${state.phonePhotoCursor}`);
  state.phonePhotoCursor = data.next;
  if (data.photos.length) {
    data.photos.forEach((photo) => state.capturedPhotos.push(photo.photoData));
    renderPhotoPreview();
    els.phoneConnectStatus.textContent = `${data.photos.length} photo${data.photos.length === 1 ? "" : "s"} received from camera device.`;
  }
}

function stopPhonePolling() {
  window.clearInterval(state.phonePollTimer);
  state.phonePollTimer = null;
}

async function startPhoneSession() {
  stopPhonePolling();
  els.phoneConnectStatus.textContent = "Starting camera device session...";
  els.cameraQrCode.innerHTML = `<span class="settings-note">Creating QR...</span>`;
  els.phoneConnectUrl.value = "";
  els.openCameraDeviceLinkBtn.href = "#";
  if (!els.phoneDialog.open) els.phoneDialog.showModal();

  let data;
  try {
    data = await api("/api/phone-session", { method: "POST", body: "{}" });
  } catch (error) {
    els.cameraQrCode.innerHTML = `<span class="settings-note" style="color:#a5413f">Could not start session: ${error.message}. Is the server running?</span>`;
    els.phoneConnectStatus.textContent = "Session failed. Restart the server and try again.";
    return;
  }

  state.phoneSession = data;
  state.phonePhotoCursor = 0;
  const cameraDeviceUrl = bestPhoneUrl(data);
  els.phoneConnectUrl.value = cameraDeviceUrl;
  els.openCameraDeviceLinkBtn.href = cameraDeviceUrl;

  els.cameraQrCode.innerHTML = `<span class="settings-note">Loading QR...</span>`;
  try {
    const qrResp = await fetch(`/api/qr?text=${encodeURIComponent(cameraDeviceUrl)}`);
    if (!qrResp.ok) {
      const errText = await qrResp.text();
      els.cameraQrCode.innerHTML = `<span class="settings-note" style="color:#a5413f">QR error (${qrResp.status}): ${errText}</span>`;
    } else {
      const blob = await qrResp.blob();
      const objectUrl = URL.createObjectURL(blob);
      const img = new Image();
      img.alt = "Scan to connect camera device";
      img.src = objectUrl;
      els.cameraQrCode.innerHTML = "";
      els.cameraQrCode.appendChild(img);
    }
  } catch (qrError) {
    els.cameraQrCode.innerHTML = `<span class="settings-note" style="color:#a5413f">QR fetch failed: ${qrError.message}. Open link: <a href="${cameraDeviceUrl}" target="_blank" rel="noopener">${cameraDeviceUrl}</a></span>`;
  }

  els.phoneConnectStatus.textContent = `Scan this QR with the camera device, or use pairing code ${data.sessionId}.`;
  state.phonePollTimer = window.setInterval(() => pollPhonePhotos().catch(() => {}), 1500);
}

function loadCameraSettings() {
  try {
    state.settings = {
      ...state.settings,
      ...JSON.parse(localStorage.getItem(settingsKey) || "{}")
    };
  } catch {
    state.settings = { photoDeviceId: "", scannerDeviceId: "" };
  }
}

function saveCameraSettings() {
  localStorage.setItem(settingsKey, JSON.stringify(state.settings));
}

function setCameraOptions(select, devices, selectedDeviceId) {
  const defaultText = [els.photoCameraSelect, els.dialogPhotoCameraSelect].includes(select)
    ? "Default rear camera"
    : "Default scan camera";
  select.innerHTML = `<option value="">${defaultText}</option>`;
  devices.forEach((device, index) => {
    const option = document.createElement("option");
    option.value = device.deviceId;
    option.textContent = device.label || `Camera ${index + 1}`;
    select.appendChild(option);
  });
  select.value = [...select.options].some((option) => option.value === selectedDeviceId) ? selectedDeviceId : "";
}

async function refreshCameraDevices() {
  if (!navigator.mediaDevices?.enumerateDevices) {
    els.cameraSettingsNote.textContent = "This browser cannot list cameras. The default camera will still be used when possible.";
    return;
  }

  const devices = await navigator.mediaDevices.enumerateDevices();
  const cameras = devices.filter((device) => device.kind === "videoinput");
  setCameraOptions(els.photoCameraSelect, cameras, state.settings.photoDeviceId);
  setCameraOptions(els.dialogPhotoCameraSelect, cameras, state.settings.photoDeviceId);
  setCameraOptions(els.scannerCameraSelect, cameras, state.settings.scannerDeviceId);

  if (cameras.length) {
    els.cameraSettingsNote.textContent = cameras.some((camera) => camera.label)
      ? "Camera choices are ready."
      : "Start a camera once if names are hidden, then refresh this list.";
  } else {
    els.cameraSettingsNote.textContent = "No camera devices found yet. Plug one in or pair a phone/tablet.";
  }
}

function videoConstraints(deviceId) {
  if (deviceId) {
    return { deviceId: { exact: deviceId } };
  }
  return { facingMode: "environment" };
}

async function loadItems() {
  const data = await api("/api/items");
  state.items = data.items;
  render();
}

function setCategoryOptions(categories) {
  state.categories = categories;
  els.category.innerHTML = `<option value="">Select</option>${categories
    .map((category) => `<option>${escapeHtml(category.name)}</option>`)
    .join("")}`;
  renderSubcategoryOptions();
}

function renderSubcategoryOptions(selectedValue = "") {
  const category = state.categories.find((entry) => entry.name === els.category.value);
  const subcategories = category?.subcategories || [];
  els.subcategory.disabled = !subcategories.length;
  els.subcategory.innerHTML = `<option value="">${subcategories.length ? "Select" : "None"}</option>${subcategories
    .map((name) => `<option>${escapeHtml(name)}</option>`)
    .join("")}`;
  if (selectedValue && subcategories.includes(selectedValue)) {
    els.subcategory.value = selectedValue;
  }
}

async function loadCategories() {
  try {
    const data = await api("/api/categories");
    setCategoryOptions(data.categories?.length ? data.categories : defaultCategories);
  } catch {
    setCategoryOptions(defaultCategories);
  }
}

function renderBarcode(svg, rawValue) {
  const value = `*${String(rawValue).toUpperCase()}*`;
  const moduleWidth = 2;
  const height = 70;
  let x = 0;
  svg.innerHTML = "";

  for (const char of value) {
    const pattern = code39[char];
    if (!pattern) continue;
    [...pattern].forEach((bit) => {
      if (bit === "1") {
        const rect = document.createElementNS("http://www.w3.org/2000/svg", "rect");
        rect.setAttribute("x", x);
        rect.setAttribute("y", 0);
        rect.setAttribute("width", moduleWidth);
        rect.setAttribute("height", height);
        rect.setAttribute("fill", "#111");
        svg.appendChild(rect);
      }
      x += moduleWidth;
    });
    x += moduleWidth;
  }

  svg.setAttribute("viewBox", `0 0 ${x} ${height}`);
}

function itemMatches(item) {
  const status = els.statusFilter.value;
  const query = els.searchInput.value.trim().toLowerCase();
  const itemStatus = item.status === "Donated" ? "Checked Out" : item.status;
  if (status !== "All" && itemStatus !== status) return false;
  if (!query) return true;
  return [
    item.id,
    item.title,
    item.category,
    item.subcategory,
    item.size,
    item.color,
    item.condition,
    item.location,
    item.notes,
    ...(item.tags || [])
  ].some((value) => String(value || "").toLowerCase().includes(query));
}

function render() {
  els.availableCount.textContent = state.items.filter((item) => item.status === "Available").length;
  els.checkedOutCount.textContent = state.items.filter((item) => item.status === "Checked Out" || item.status === "Donated").length;
  els.inventoryList.innerHTML = "";

  const visibleItems = state.items.filter(itemMatches);
  if (!visibleItems.length) {
    els.inventoryList.innerHTML = `<p class="item-notes">No items match the current view.</p>`;
    return;
  }

  visibleItems.forEach((item) => {
    const node = els.template.content.firstElementChild.cloneNode(true);
    const displayStatus = item.status === "Donated" ? "Checked Out" : item.status;
    node.classList.toggle("is-checked-out", displayStatus === "Checked Out");
    node.querySelector(".item-photo").src = item.photos?.[0] || "";
    node.querySelector(".item-photo").alt = item.title;
    node.querySelector("h3").textContent = item.title;
    node.querySelector(".item-meta").textContent = [
      item.category,
      item.subcategory,
      item.size && `Size ${item.size}`,
      item.color,
      item.condition,
      item.location && `Location ${item.location}`
    ].filter(Boolean).join(" | ");
    node.querySelector(".item-status").textContent = displayStatus;
    node.querySelector(".item-notes").textContent = item.notes || "No notes";
    node.querySelector(".item-id").textContent = item.id;
    node.querySelector(".tag-row").innerHTML = (item.tags || [])
      .map((tag) => `<span>${escapeHtml(tag)}</span>`)
      .join("");
    renderBarcode(node.querySelector(".barcode"), item.id);

    node.querySelector(".print-btn").addEventListener("click", () => printLabel(item));
    node.querySelector(".checkout-btn").addEventListener("click", () => checkoutItem(item.id));
    els.inventoryList.appendChild(node);
  });
}

function formDataToObject() {
  return {
    title: document.querySelector("#title").value,
    category: document.querySelector("#category").value,
    subcategory: document.querySelector("#subcategory").value,
    size: document.querySelector("#size").value,
    color: document.querySelector("#color").value,
    condition: document.querySelector("#condition").value,
    location: document.querySelector("#location").value,
    tags: document.querySelector("#tags").value,
    notes: document.querySelector("#notes").value
  };
}

function setFormValue(selector, value) {
  const field = document.querySelector(selector);
  if (field && value) field.value = value;
}

function ensureOption(select, value) {
  if (!select || !value) return;
  const exists = [...select.options].some((option) => option.value === value);
  if (!exists) select.appendChild(new Option(value, value));
}

function applySuggestion(suggestion) {
  setFormValue("#title", suggestion.title);
  ensureOption(els.category, suggestion.category);
  setFormValue("#category", suggestion.category);
  renderSubcategoryOptions(suggestion.subcategory);
  ensureOption(els.subcategory, suggestion.subcategory);
  setFormValue("#subcategory", suggestion.subcategory);
  setFormValue("#size", suggestion.size);
  setFormValue("#color", suggestion.color);
  setFormValue("#condition", suggestion.condition);
  setFormValue("#tags", Array.isArray(suggestion.tags) ? suggestion.tags.join(", ") : suggestion.tags);
  setFormValue("#notes", suggestion.notes || suggestion.description);
}

async function getCurrentPhotoData() {
  if (state.capturedPhotos.length) return state.capturedPhotos[0];
  const file = els.photos.files?.[0];
  return file ? fileToDataUrl(file) : "";
}

async function classifyCurrentPhoto() {
  const photoData = await getCurrentPhotoData();
  if (!photoData) {
    els.aiSuggestNote.textContent = "Choose or take a picture first.";
    return;
  }

  els.classifyPhotoBtn.disabled = true;
  els.aiSuggestNote.textContent = "Reading photo...";
  try {
    const data = await api("/api/classify-photo", {
      method: "POST",
      body: JSON.stringify({ photoData })
    });
    applySuggestion(data.suggestion || {});
    els.aiSuggestNote.textContent = "AI filled in the item details. Review them, then save.";
  } catch (error) {
    els.aiSuggestNote.textContent = error.message;
  } finally {
    els.classifyPhotoBtn.disabled = false;
  }
}

async function saveItem(event) {
  event.preventDefault();
  const photoData = await Promise.all([...els.photos.files].map(fileToDataUrl));
  const data = await api("/api/items", {
    method: "POST",
    body: JSON.stringify({ ...formDataToObject(), photoData: [...photoData, ...state.capturedPhotos] })
  });
  state.items.unshift(data.item);
  els.form.reset();
  state.capturedPhotos = [];
  renderPhotoPreview();
  render();
}

async function checkoutItem(id) {
  const cleanId = String(id || "").trim().toUpperCase();
  if (!cleanId) return;
  const data = await api(`/api/items/${encodeURIComponent(cleanId)}/checkout`, {
    method: "POST",
    body: JSON.stringify({ note: "Checked out from inventory keeper" })
  });
  state.items = state.items.map((item) => item.id === data.item.id ? data.item : item);
  els.manualId.value = "";
  render();
}

function printLabel(item) {
  printLabels([item]);
}

function labelMarkup(item) {
  return `
    <div class="avery-label">
      <strong>${escapeHtml(item.id)}</strong>
      <svg class="barcode" role="img"></svg>
      <span>${escapeHtml(item.title)}</span>
      <span>${escapeHtml([item.category, item.subcategory, item.size, item.color].filter(Boolean).join(" | "))}</span>
    </div>
  `;
}

function printLabels(items) {
  if (!items.length) return;
  const sheet = document.createElement("div");
  sheet.className = "label-sheet avery-5160";
  sheet.innerHTML = items.slice(0, 30).map(labelMarkup).join("");
  document.body.appendChild(sheet);
  [...sheet.querySelectorAll(".barcode")].forEach((svg, index) => renderBarcode(svg, items[index].id));
  window.print();
  sheet.remove();
}

function printVisibleLabels() {
  printLabels(state.items.filter(itemMatches));
}

async function startScanner() {
  if (!("BarcodeDetector" in window)) {
    els.scannerStatus.textContent = "Manual";
    els.scannerEmpty.textContent = "Barcode scanning unavailable in this browser. Type the item ID below.";
    return;
  }

  const detector = new BarcodeDetector({ formats: ["code_39", "code_128", "qr_code"] });
  if (!state.stream) {
    await connectScannerCamera();
  }
  els.scannerStatus.textContent = "Scanning";
  refreshCameraDevices().catch(() => {});

  state.scanTimer = window.setInterval(async () => {
    try {
      const codes = await detector.detect(els.scannerVideo);
      if (codes.length) {
        const value = codes[0].rawValue.trim().toUpperCase();
        stopScanner();
        await checkoutItem(value);
      }
    } catch {
      stopScanner();
      els.scannerStatus.textContent = "Manual";
    }
  }, 700);
}

async function connectScannerCamera() {
  stopScanner("Connected");
  state.stream = await navigator.mediaDevices.getUserMedia({
    video: videoConstraints(state.settings.scannerDeviceId),
    audio: false
  });
  els.scannerVideo.srcObject = state.stream;
  els.scannerEmpty.hidden = true;
  await els.scannerVideo.play();
  els.scannerStatus.textContent = "Connected";
  els.cameraSettingsNote.textContent = "Scan camera connected.";
  refreshCameraDevices().catch(() => {});
}

function stopScanner(nextStatus = "Ready") {
  window.clearInterval(state.scanTimer);
  state.scanTimer = null;
  if (state.stream) {
    state.stream.getTracks().forEach((track) => track.stop());
    state.stream = null;
  }
  els.scannerVideo.srcObject = null;
  els.scannerEmpty.hidden = false;
  els.scannerEmpty.textContent = "Camera scan or type the item ID below";
  els.scannerStatus.textContent = nextStatus;
}

async function openLiveCamera() {
  closeLiveCamera();
  if (!els.cameraDialog.open) els.cameraDialog.showModal();
  state.photoStream = await navigator.mediaDevices.getUserMedia({
    video: videoConstraints(state.settings.photoDeviceId),
    audio: false
  });
  els.photoVideo.srcObject = state.photoStream;
  els.photoCameraEmpty.hidden = true;
  await els.photoVideo.play();
  els.cameraSettingsNote.textContent = "Photo camera connected.";
  refreshCameraDevices().catch(() => {});
}

function closeLiveCamera() {
  if (state.photoStream) {
    state.photoStream.getTracks().forEach((track) => track.stop());
    state.photoStream = null;
  }
  els.photoVideo.srcObject = null;
  els.photoCameraEmpty.hidden = false;
  if (els.cameraDialog.open) els.cameraDialog.close();
}

function showCameraDialog() {
  if (!els.cameraDialog.open) els.cameraDialog.showModal();
  els.dialogPhotoCameraSelect.value = state.settings.photoDeviceId;
  refreshCameraDevices().catch(() => {
    els.cameraSettingsNote.textContent = "Camera list will appear after browser permission is granted.";
  });
}

function capturePhoto() {
  const canvas = document.createElement("canvas");
  const width = els.photoVideo.videoWidth || 1280;
  const height = els.photoVideo.videoHeight || 960;
  canvas.width = width;
  canvas.height = height;
  canvas.getContext("2d").drawImage(els.photoVideo, 0, 0, width, height);
  state.capturedPhotos.push(canvas.toDataURL("image/jpeg", 0.82));
  renderPhotoPreview();
}

els.authForm.addEventListener("submit", authenticate);
els.toggleAuthModeBtn.addEventListener("click", () => setAuthMode(state.authMode === "login" ? "signup" : "login"));
els.signOutBtn.addEventListener("click", () => {
  clearAuth();
  state.items = [];
  state.categories = [];
  state.capturedPhotos = [];
  els.form.reset();
  els.availableCount.textContent = "0";
  els.checkedOutCount.textContent = "0";
  els.inventoryList.innerHTML = "";
  renderPhotoPreview();
  render();
  setAuthMode("login");
  showAuth("Signed out.");
});
els.form.addEventListener("submit", saveItem);
els.clearFormBtn.addEventListener("click", () => {
  els.form.reset();
  state.capturedPhotos = [];
  renderPhotoPreview();
});
els.photos.addEventListener("change", renderPhotoPreview);
els.category.addEventListener("change", () => renderSubcategoryOptions());
els.connectPhoneBtn.addEventListener("click", () => startPhoneSession().catch((error) => {
  els.phoneConnectStatus.textContent = error.message;
}));
els.openPhotoPickerBtn.addEventListener("click", () => els.photos.click());
els.classifyPhotoBtn.addEventListener("click", classifyCurrentPhoto);
els.openLiveCameraBtn?.addEventListener("click", showCameraDialog);
els.capturePhotoBtn.addEventListener("click", capturePhoto);
els.closeCameraBtn.addEventListener("click", closeLiveCamera);
els.cameraDialog.addEventListener("close", closeLiveCamera);
els.closePhoneDialogBtn.addEventListener("click", () => {
  stopPhonePolling();
  if (els.phoneDialog.open) els.phoneDialog.close();
});
els.refreshPhoneSessionBtn.addEventListener("click", () => startPhoneSession().catch((error) => {
  els.phoneConnectStatus.textContent = error.message;
}));
els.copyPhoneLinkBtn.addEventListener("click", async () => {
  const value = els.phoneConnectUrl.value;
  if (!value) return;
  try {
    await navigator.clipboard.writeText(value);
    els.phoneConnectStatus.textContent = "Camera device link copied.";
  } catch {
    els.phoneConnectUrl.select();
    els.phoneConnectStatus.textContent = "Select and copy the camera device link.";
  }
});
els.searchInput.addEventListener("input", render);
els.statusFilter.addEventListener("change", render);
els.printVisibleBtn.addEventListener("click", printVisibleLabels);
els.manualCheckoutBtn.addEventListener("click", () => checkoutItem(els.manualId.value));
els.refreshCamerasBtn.addEventListener("click", () => refreshCameraDevices().catch((error) => {
  els.cameraSettingsNote.textContent = error.message;
}));
els.connectPhotoCameraBtn?.addEventListener("click", () => openLiveCamera().catch((error) => {
  els.cameraSettingsNote.textContent = `${error.message}. Try another photo camera or choose a photo instead.`;
}));
els.connectScannerCameraBtn?.addEventListener("click", () => connectScannerCamera().catch((error) => {
  els.scannerStatus.textContent = "Manual";
  els.scannerEmpty.hidden = false;
  els.scannerEmpty.textContent = `${error.message}. Type the item ID below.`;
  els.cameraSettingsNote.textContent = "Could not connect the scan camera.";
}));
els.photoCameraSelect.addEventListener("change", () => {
  state.settings.photoDeviceId = els.photoCameraSelect.value;
  els.dialogPhotoCameraSelect.value = state.settings.photoDeviceId;
  saveCameraSettings();
  els.cameraSettingsNote.textContent = "Photo camera selected.";
});
els.dialogRefreshCamerasBtn.addEventListener("click", () => refreshCameraDevices().catch((error) => {
  els.cameraSettingsNote.textContent = error.message;
}));
els.dialogConnectPhotoCameraBtn?.addEventListener("click", () => openLiveCamera().catch((error) => {
  els.photoCameraEmpty.hidden = false;
  els.photoCameraEmpty.textContent = `${error.message}. Choose another camera or choose a photo.`;
}));
els.dialogPhotoCameraSelect.addEventListener("change", () => {
  state.settings.photoDeviceId = els.dialogPhotoCameraSelect.value;
  els.photoCameraSelect.value = state.settings.photoDeviceId;
  saveCameraSettings();
  els.photoCameraEmpty.textContent = "Camera selected.";
});
els.scannerCameraSelect.addEventListener("change", () => {
  state.settings.scannerDeviceId = els.scannerCameraSelect.value;
  saveCameraSettings();
  els.cameraSettingsNote.textContent = "Scan camera selected. Tap Start Scan when ready.";
});
els.startScanBtn.addEventListener("click", () => startScanner().catch((error) => {
  els.scannerStatus.textContent = "Manual";
  els.scannerEmpty.hidden = false;
  els.scannerEmpty.textContent = `${error.message}. Type the item ID below.`;
}));
els.stopScanBtn.addEventListener("click", stopScanner);

loadCameraSettings();
refreshCameraDevices().catch(() => {
  els.cameraSettingsNote.textContent = "Camera list will appear after browser permission is granted.";
});
setAuthMode(authModeFromLocation());
restoreSession().catch((error) => {
  els.inventoryList.innerHTML = `<p class="item-notes">${escapeHtml(error.message)}</p>`;
});
