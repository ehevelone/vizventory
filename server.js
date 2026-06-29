const http = require("http");
const fs = require("fs");
const path = require("path");
const crypto = require("crypto");
const os = require("os");
const QRCode = require("qrcode");

loadEnvFile();

const PORT = process.env.PORT || 4173;
const ROOT = __dirname;
const PUBLIC_DIR = path.join(ROOT, "public");
const DATA_DIR = path.join(ROOT, "data");
const PHOTO_DIR = path.join(DATA_DIR, "photos");
const DB_FILE = path.join(DATA_DIR, "inventory.json");
const phoneSessions = new Map();
let latestPhoneSessionId = "";

const MIME_TYPES = {
  ".html": "text/html; charset=utf-8",
  ".css": "text/css; charset=utf-8",
  ".js": "text/javascript; charset=utf-8",
  ".json": "application/json; charset=utf-8",
  ".png": "image/png",
  ".jpg": "image/jpeg",
  ".jpeg": "image/jpeg",
  ".webp": "image/webp",
  ".svg": "image/svg+xml; charset=utf-8"
};

function loadEnvFile() {
  const envPath = path.join(__dirname, ".env");
  if (!fs.existsSync(envPath)) return;

  const lines = fs.readFileSync(envPath, "utf8").split(/\r?\n/);
  for (const line of lines) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith("#")) continue;
    const separator = trimmed.indexOf("=");
    if (separator === -1) continue;
    const key = trimmed.slice(0, separator).trim();
    let value = trimmed.slice(separator + 1).trim();
    if ((value.startsWith("\"") && value.endsWith("\"")) || (value.startsWith("'") && value.endsWith("'"))) {
      value = value.slice(1, -1);
    }
    if (key && process.env[key] === undefined) process.env[key] = value;
  }
}

function ensureDataStore() {
  fs.mkdirSync(PHOTO_DIR, { recursive: true });
  if (!fs.existsSync(DB_FILE)) {
    fs.writeFileSync(DB_FILE, JSON.stringify({ items: [] }, null, 2));
  }
}

function readDb() {
  ensureDataStore();
  return JSON.parse(fs.readFileSync(DB_FILE, "utf8"));
}

function writeDb(db) {
  ensureDataStore();
  fs.writeFileSync(DB_FILE, JSON.stringify(db, null, 2));
}

function sendJson(res, status, body) {
  const payload = JSON.stringify(body);
  res.writeHead(status, {
    "Content-Type": "application/json; charset=utf-8",
    "Content-Length": Buffer.byteLength(payload)
  });
  res.end(payload);
}

function getLanAddresses() {
  return Object.values(os.networkInterfaces())
    .flat()
    .filter((entry) => entry && entry.family === "IPv4" && !entry.internal)
    .map((entry) => entry.address);
}

function readBody(req) {
  return new Promise((resolve, reject) => {
    let body = "";
    req.on("data", (chunk) => {
      body += chunk;
      if (body.length > 25 * 1024 * 1024) {
        req.destroy();
        reject(new Error("Request too large"));
      }
    });
    req.on("end", () => resolve(body));
    req.on("error", reject);
  });
}

function nextInventoryId(items) {
  const year = new Date().getFullYear();
  const prefix = `VIZ-${year}-`;
  const max = items.reduce((highest, item) => {
    if (!item.id || !item.id.startsWith(prefix)) return highest;
    const number = Number(item.id.slice(prefix.length));
    return Number.isFinite(number) ? Math.max(highest, number) : highest;
  }, 0);
  return `${prefix}${String(max + 1).padStart(5, "0")}`;
}

function savePhoto(dataUrl, itemId, index) {
  const match = /^data:(image\/(?:png|jpe?g|webp));base64,(.+)$/i.exec(dataUrl || "");
  if (!match) return null;

  const ext = match[1].includes("png") ? "png" : match[1].includes("webp") ? "webp" : "jpg";
  const filename = `${itemId}-${index + 1}-${crypto.randomBytes(4).toString("hex")}.${ext}`;
  const target = path.join(PHOTO_DIR, filename);
  fs.writeFileSync(target, Buffer.from(match[2], "base64"));
  return `/photos/${filename}`;
}

function getResponseText(data) {
  if (typeof data.output_text === "string") return data.output_text;
  return (data.output || [])
    .flatMap((entry) => entry.content || [])
    .map((part) => part.text || "")
    .filter(Boolean)
    .join("\n");
}

function parseJsonFromText(text) {
  const clean = String(text || "").trim().replace(/^```(?:json)?\s*/i, "").replace(/\s*```$/i, "");
  try {
    return JSON.parse(clean);
  } catch {
    const match = clean.match(/\{[\s\S]*\}/);
    if (!match) throw new Error("AI did not return item details");
    return JSON.parse(match[0]);
  }
}

function normalizeAiSuggestion(raw) {
  const tags = Array.isArray(raw.tags) ? raw.tags : String(raw.tags || "").split(",");
  return {
    title: String(raw.title || raw.itemName || "").trim(),
    category: String(raw.category || "").trim(),
    size: String(raw.size || raw.model || "").trim(),
    color: String(raw.color || raw.finish || "").trim(),
    condition: String(raw.condition || "Good").trim(),
    tags: tags.map((tag) => String(tag).trim()).filter(Boolean).slice(0, 8),
    description: String(raw.description || "").trim(),
    notes: String(raw.notes || raw.description || "").trim()
  };
}

async function classifyPhoto(photoData) {
  const apiKey = process.env.OPENAI_API_KEY;
  if (!apiKey) {
    const error = new Error("AI needs an OpenAI API key in .env before it can describe photos.");
    error.status = 501;
    throw error;
  }
  if (!/^data:image\/(?:png|jpe?g|webp);base64,/i.test(photoData || "")) {
    const error = new Error("Choose or take a photo first.");
    error.status = 400;
    throw error;
  }

  const model = process.env.OPENAI_MODEL || "gpt-4o-mini";
  const response = await fetch("https://api.openai.com/v1/responses", {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${apiKey}`,
      "Content-Type": "application/json"
    },
    body: JSON.stringify({
      model,
      input: [{
        role: "user",
        content: [
          {
            type: "input_text",
            text: [
              "Identify the inventory item in this photo.",
              "Return only JSON with these fields:",
              "title, category, size, color, condition, tags, description, notes.",
              "Use short practical wording. If unsure, make the best useful guess and mention uncertainty in notes.",
              "Categories should be broad inventory categories such as Equipment, Tool, Electronics, Furniture, Supply, Document, Artwork, Part, Container, or Other."
            ].join(" ")
          },
          { type: "input_image", image_url: photoData }
        ]
      }]
    })
  });

  const data = await response.json().catch(() => ({}));
  if (!response.ok) {
    const error = new Error(data.error?.message || "AI could not read the photo.");
    error.status = response.status;
    throw error;
  }

  return normalizeAiSuggestion(parseJsonFromText(getResponseText(data)));
}

function normalizeItem(input, existing, id) {
  const now = new Date().toISOString();
  const status = input.status === "Donated" ? "Checked Out" : input.status;
  return {
    id,
    title: String(input.title || "").trim() || "Inventory item",
    category: String(input.category || "").trim(),
    size: String(input.size || "").trim(),
    color: String(input.color || "").trim(),
    condition: String(input.condition || "").trim(),
    location: String(input.location || "").trim(),
    notes: String(input.notes || "").trim(),
    tags: String(input.tags || "")
      .split(",")
      .map((tag) => tag.trim())
      .filter(Boolean),
    status: status === "Checked Out" || status === "Removed" ? status : "Available",
    photos: Array.isArray(input.photos) ? input.photos : existing?.photos || [],
    history: existing?.history || [{ status: "Available", at: now, note: "Item added" }],
    createdAt: existing?.createdAt || now,
    updatedAt: now
  };
}

async function handleApi(req, res) {
  const url = new URL(req.url, `http://${req.headers.host}`);
  const db = readDb();

  if (req.method === "GET" && url.pathname === "/api/qr") {
    const text = String(url.searchParams.get("text") || "");
    if (!text) return sendJson(res, 400, { error: "QR text is required" });
    const png = await QRCode.toBuffer(text, {
      errorCorrectionLevel: "M",
      margin: 3,
      scale: 8,
      type: "png"
    });
    res.writeHead(200, {
      "Content-Type": "image/png",
      "Content-Length": png.length,
      "Cache-Control": "no-store"
    });
    res.end(png);
    return;
  }

  if (req.method === "POST" && url.pathname === "/api/phone-session") {
    const sessionId = crypto.randomBytes(4).toString("hex");
    latestPhoneSessionId = sessionId;
    phoneSessions.set(sessionId, { photos: [], createdAt: Date.now() });
    const hostPort = req.headers.host.split(":")[1] || PORT;
    const phoneUrls = getLanAddresses().map((address) => `http://${address}:${hostPort}/c/${sessionId}`);
    return sendJson(res, 201, {
      sessionId,
      localUrl: `http://${req.headers.host}/c/${sessionId}`,
      phoneUrls
    });
  }

  if (req.method === "GET" && url.pathname === "/api/phone-session/current") {
    if (!latestPhoneSessionId || !phoneSessions.has(latestPhoneSessionId)) {
      return sendJson(res, 404, { error: "No active camera device session" });
    }
    return sendJson(res, 200, { sessionId: latestPhoneSessionId });
  }

  if (req.method === "POST" && url.pathname === "/api/phone-photos") {
    const input = JSON.parse(await readBody(req) || "{}");
    const session = phoneSessions.get(String(input.sessionId || ""));
    if (!session) return sendJson(res, 404, { error: "Phone session not found" });
    if (!/^data:image\/(?:png|jpe?g|webp);base64,/i.test(input.photoData || "")) {
      return sendJson(res, 400, { error: "Photo is missing or invalid" });
    }
    session.photos.push({
      id: crypto.randomBytes(6).toString("hex"),
      photoData: input.photoData,
      at: new Date().toISOString()
    });
    return sendJson(res, 201, { ok: true, count: session.photos.length });
  }

  if (req.method === "GET" && url.pathname === "/api/phone-photos") {
    const sessionId = String(url.searchParams.get("session") || "");
    const after = Number(url.searchParams.get("after") || 0);
    const session = phoneSessions.get(sessionId);
    if (!session) return sendJson(res, 404, { error: "Phone session not found" });
    return sendJson(res, 200, {
      photos: session.photos.slice(Number.isFinite(after) ? after : 0),
      next: session.photos.length
    });
  }

  if (req.method === "GET" && url.pathname === "/api/items") {
    return sendJson(res, 200, { items: db.items });
  }

  if (req.method === "POST" && url.pathname === "/api/classify-photo") {
    try {
      const input = JSON.parse(await readBody(req) || "{}");
      const suggestion = await classifyPhoto(input.photoData);
      return sendJson(res, 200, { suggestion });
    } catch (error) {
      return sendJson(res, error.status || 500, { error: error.message || "AI classification failed" });
    }
  }

  const itemGetMatch = /^\/api\/items\/([^/]+)$/.exec(url.pathname);
  if (itemGetMatch && req.method === "GET") {
    const id = decodeURIComponent(itemGetMatch[1]);
    const item = db.items.find((entry) => entry.id === id);
    if (!item) return sendJson(res, 404, { error: "Item not found" });
    return sendJson(res, 200, { item });
  }

  if (req.method === "POST" && url.pathname === "/api/items") {
    const input = JSON.parse(await readBody(req) || "{}");
    const id = nextInventoryId(db.items);
    const photoUrls = (input.photoData || [])
      .map((photo, index) => savePhoto(photo, id, index))
      .filter(Boolean);
    const item = normalizeItem({ ...input, photos: photoUrls }, null, id);
    db.items.unshift(item);
    writeDb(db);
    return sendJson(res, 201, { item });
  }

  const itemMatch = /^\/api\/items\/([^/]+)$/.exec(url.pathname);
  if (itemMatch && req.method === "PUT") {
    const id = decodeURIComponent(itemMatch[1]);
    const index = db.items.findIndex((item) => item.id === id);
    if (index === -1) return sendJson(res, 404, { error: "Item not found" });

    const input = JSON.parse(await readBody(req) || "{}");
    const extraPhotos = (input.photoData || [])
      .map((photo, photoIndex) => savePhoto(photo, id, db.items[index].photos.length + photoIndex))
      .filter(Boolean);
    const photos = [...db.items[index].photos, ...extraPhotos];
    db.items[index] = normalizeItem({ ...input, photos }, db.items[index], id);
    writeDb(db);
    return sendJson(res, 200, { item: db.items[index] });
  }

  const checkoutMatch = /^\/api\/items\/([^/]+)\/checkout$/.exec(url.pathname);
  if (checkoutMatch && req.method === "POST") {
    const id = decodeURIComponent(checkoutMatch[1]);
    const item = db.items.find((entry) => entry.id === id);
    if (!item) return sendJson(res, 404, { error: "Item not found" });

    const input = JSON.parse(await readBody(req) || "{}");
    item.status = "Checked Out";
    item.updatedAt = new Date().toISOString();
    item.history = item.history || [];
    item.history.unshift({
      status: "Checked Out",
      at: item.updatedAt,
      note: String(input.note || "Scanned out").trim()
    });
    writeDb(db);
    return sendJson(res, 200, { item });
  }

  const statusMatch = /^\/api\/items\/([^/]+)\/status$/.exec(url.pathname);
  if (statusMatch && req.method === "POST") {
    const id = decodeURIComponent(statusMatch[1]);
    const item = db.items.find((entry) => entry.id === id);
    if (!item) return sendJson(res, 404, { error: "Item not found" });

    const input = JSON.parse(await readBody(req) || "{}");
    const status = ["Available", "Checked Out", "Removed"].includes(input.status) ? input.status : "";
    if (!status) return sendJson(res, 400, { error: "Invalid status" });

    item.status = status;
    item.updatedAt = new Date().toISOString();
    item.history = item.history || [];
    item.history.unshift({
      status,
      at: item.updatedAt,
      note: String(input.note || `Marked ${status}`).trim()
    });
    writeDb(db);
    return sendJson(res, 200, { item });
  }

  return sendJson(res, 404, { error: "Not found" });
}

function serveStatic(req, res) {
  const url = new URL(req.url, `http://${req.headers.host}`);
  const cameraPairMatch = /^\/c\/([a-f0-9]+)$/i.exec(url.pathname);
  if (cameraPairMatch) {
    res.writeHead(302, {
      Location: `/phone.html?session=${encodeURIComponent(cameraPairMatch[1])}`
    });
    res.end();
    return;
  }

  const pathname = url.pathname === "/" ? "/index.html" : decodeURIComponent(url.pathname);
  const baseDir = pathname.startsWith("/photos/") ? DATA_DIR : PUBLIC_DIR;
  const filePath = path.normalize(path.join(baseDir, pathname));

  if (!filePath.startsWith(baseDir)) {
    res.writeHead(403);
    res.end("Forbidden");
    return;
  }

  fs.readFile(filePath, (error, data) => {
    if (error) {
      res.writeHead(404);
      res.end("Not found");
      return;
    }
    res.writeHead(200, {
      "Content-Type": MIME_TYPES[path.extname(filePath)] || "application/octet-stream",
      "Cache-Control": "no-store"
    });
    res.end(data);
  });
}

ensureDataStore();

http.createServer((req, res) => {
  if (req.url.startsWith("/api/")) {
    handleApi(req, res).catch((error) => sendJson(res, 500, { error: error.message }));
    return;
  }
  serveStatic(req, res);
}).listen(PORT, () => {
  console.log(`Vizventory local inventory is running at http://localhost:${PORT}`);
});
