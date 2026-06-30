const fs = require("fs");
const path = require("path");
const crypto = require("crypto");
const os = require("os");
const QRCode = require("qrcode");

const ROOT = path.join(__dirname, "..", "..");
const DATA_DIR = process.env.NETLIFY ? path.join(os.tmpdir(), "vizventory-data") : path.join(ROOT, "data");
const PHOTO_DIR = path.join(DATA_DIR, "photos");
const DB_FILE = path.join(DATA_DIR, "inventory.json");
const phoneSessions = new Map();
let latestPhoneSessionId = "";

const BASE_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "Content-Type",
  "Access-Control-Allow-Methods": "GET, POST, PUT, OPTIONS"
};

function json(statusCode, body, headers = {}) {
  return {
    statusCode,
    headers: {
      ...BASE_HEADERS,
      "Content-Type": "application/json; charset=utf-8",
      "Cache-Control": "no-store",
      ...headers
    },
    body: JSON.stringify(body)
  };
}

function binary(statusCode, body, contentType) {
  return {
    statusCode,
    isBase64Encoded: true,
    headers: {
      ...BASE_HEADERS,
      "Content-Type": contentType,
      "Cache-Control": "no-store"
    },
    body: body.toString("base64")
  };
}

function parseBody(event) {
  if (!event.body) return {};
  const raw = event.isBase64Encoded ? Buffer.from(event.body, "base64").toString("utf8") : event.body;
  return JSON.parse(raw || "{}");
}

function routePath(event) {
  const rawPath = event.path || "";
  const marker = "/.netlify/functions/api";
  if (rawPath.startsWith(marker)) {
    const routed = rawPath.slice(marker.length);
    return `/api${routed || ""}`;
  }
  return rawPath.startsWith("/api/") ? rawPath : `/api${rawPath}`;
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
  return `/api/photos/${filename}`;
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
    const error = new Error("AI needs an OpenAI API key before it can describe photos.");
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

exports.handler = async (event) => {
  try {
    const method = event.httpMethod;
    if (method === "OPTIONS") {
      return { statusCode: 204, headers: BASE_HEADERS, body: "" };
    }

    const pathname = routePath(event);
    const params = event.queryStringParameters || {};
    const db = readDb();

    const photoMatch = /^\/api\/photos\/([^/]+)$/.exec(pathname);
    if (photoMatch && method === "GET") {
      const filename = path.basename(decodeURIComponent(photoMatch[1]));
      const target = path.join(PHOTO_DIR, filename);
      if (!target.startsWith(PHOTO_DIR) || !fs.existsSync(target)) {
        return json(404, { error: "Photo not found" });
      }
      const ext = path.extname(filename).toLowerCase();
      const contentType = ext === ".png" ? "image/png" : ext === ".webp" ? "image/webp" : "image/jpeg";
      return binary(200, fs.readFileSync(target), contentType);
    }

    if (method === "GET" && pathname === "/api/qr") {
      const text = String(params.text || "");
      if (!text) return json(400, { error: "QR text is required" });
      const png = await QRCode.toBuffer(text, {
        errorCorrectionLevel: "M",
        margin: 3,
        scale: 8,
        type: "png"
      });
      return binary(200, png, "image/png");
    }

    if (method === "POST" && pathname === "/api/phone-session") {
      const sessionId = crypto.randomBytes(4).toString("hex");
      latestPhoneSessionId = sessionId;
      phoneSessions.set(sessionId, { photos: [], createdAt: Date.now() });
      const host = event.headers.host || "";
      return json(201, {
        sessionId,
        localUrl: `https://${host}/c/${sessionId}`,
        phoneUrls: [`https://${host}/c/${sessionId}`]
      });
    }

    if (method === "GET" && pathname === "/api/phone-session/current") {
      if (!latestPhoneSessionId || !phoneSessions.has(latestPhoneSessionId)) {
        return json(404, { error: "No active camera device session" });
      }
      return json(200, { sessionId: latestPhoneSessionId });
    }

    if (method === "POST" && pathname === "/api/phone-photos") {
      const input = parseBody(event);
      const session = phoneSessions.get(String(input.sessionId || ""));
      if (!session) return json(404, { error: "Phone session not found" });
      if (!/^data:image\/(?:png|jpe?g|webp);base64,/i.test(input.photoData || "")) {
        return json(400, { error: "Photo is missing or invalid" });
      }
      session.photos.push({
        id: crypto.randomBytes(6).toString("hex"),
        photoData: input.photoData,
        at: new Date().toISOString()
      });
      return json(201, { ok: true, count: session.photos.length });
    }

    if (method === "GET" && pathname === "/api/phone-photos") {
      const sessionId = String(params.session || "");
      const after = Number(params.after || 0);
      const session = phoneSessions.get(sessionId);
      if (!session) return json(404, { error: "Phone session not found" });
      return json(200, {
        photos: session.photos.slice(Number.isFinite(after) ? after : 0),
        next: session.photos.length
      });
    }

    if (method === "GET" && pathname === "/api/items") {
      return json(200, { items: db.items });
    }

    if (method === "POST" && pathname === "/api/classify-photo") {
      const input = parseBody(event);
      const suggestion = await classifyPhoto(input.photoData);
      return json(200, { suggestion });
    }

    const itemGetMatch = /^\/api\/items\/([^/]+)$/.exec(pathname);
    if (itemGetMatch && method === "GET") {
      const id = decodeURIComponent(itemGetMatch[1]);
      const item = db.items.find((entry) => entry.id === id);
      if (!item) return json(404, { error: "Item not found" });
      return json(200, { item });
    }

    if (method === "POST" && pathname === "/api/items") {
      const input = parseBody(event);
      const id = nextInventoryId(db.items);
      const photoUrls = (input.photoData || [])
        .map((photo, index) => savePhoto(photo, id, index))
        .filter(Boolean);
      const item = normalizeItem({ ...input, photos: photoUrls }, null, id);
      db.items.unshift(item);
      writeDb(db);
      return json(201, { item });
    }

    const itemMatch = /^\/api\/items\/([^/]+)$/.exec(pathname);
    if (itemMatch && method === "PUT") {
      const id = decodeURIComponent(itemMatch[1]);
      const index = db.items.findIndex((item) => item.id === id);
      if (index === -1) return json(404, { error: "Item not found" });

      const input = parseBody(event);
      const extraPhotos = (input.photoData || [])
        .map((photo, photoIndex) => savePhoto(photo, id, db.items[index].photos.length + photoIndex))
        .filter(Boolean);
      const photos = [...db.items[index].photos, ...extraPhotos];
      db.items[index] = normalizeItem({ ...input, photos }, db.items[index], id);
      writeDb(db);
      return json(200, { item: db.items[index] });
    }

    const checkoutMatch = /^\/api\/items\/([^/]+)\/checkout$/.exec(pathname);
    if (checkoutMatch && method === "POST") {
      const id = decodeURIComponent(checkoutMatch[1]);
      const item = db.items.find((entry) => entry.id === id);
      if (!item) return json(404, { error: "Item not found" });

      const input = parseBody(event);
      item.status = "Checked Out";
      item.updatedAt = new Date().toISOString();
      item.history = item.history || [];
      item.history.unshift({
        status: "Checked Out",
        at: item.updatedAt,
        note: String(input.note || "Scanned out").trim()
      });
      writeDb(db);
      return json(200, { item });
    }

    const statusMatch = /^\/api\/items\/([^/]+)\/status$/.exec(pathname);
    if (statusMatch && method === "POST") {
      const id = decodeURIComponent(statusMatch[1]);
      const item = db.items.find((entry) => entry.id === id);
      if (!item) return json(404, { error: "Item not found" });

      const input = parseBody(event);
      const status = ["Available", "Checked Out", "Removed"].includes(input.status) ? input.status : "";
      if (!status) return json(400, { error: "Invalid status" });

      item.status = status;
      item.updatedAt = new Date().toISOString();
      item.history = item.history || [];
      item.history.unshift({
        status,
        at: item.updatedAt,
        note: String(input.note || `Marked ${status}`).trim()
      });
      writeDb(db);
      return json(200, { item });
    }

    return json(404, { error: "Not found" });
  } catch (error) {
    return json(error.status || 500, { error: error.message || "Request failed" });
  }
};
