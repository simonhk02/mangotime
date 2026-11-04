// Task 2.4 tests：photo 上傳/列出/攞檔/刪除 + 權限
import { test, before, after } from "node:test";
import assert from "node:assert/strict";
import { execSync } from "node:child_process";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const TEST_DB = `/tmp/mangotime-test-photo-${process.pid}.db`;
process.env.DATABASE_URL = `file:${TEST_DB}`;
process.env.NODE_ENV = "test";
process.env.UPLOAD_DIR = `/tmp/mangotime-test-uploads-${process.pid}`;

const serverDir = path.resolve(__dirname, "..");
execSync("npx prisma db push --skip-generate", { cwd: serverDir, env: { ...process.env }, stdio: "pipe" });

const { buildApp } = await import("../src/app.js");
let app: Awaited<ReturnType<typeof buildApp>>;
let token = "";
let strangerToken = "";
let calendarId = "";
let photoId = "";

// 1x1 紅色 PNG
const PNG_B64 = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==";

before(async () => {
  app = await buildApp();
  const r = await app.inject({ method: "POST", url: "/v1/auth/register", payload: { email: "p@p.hk", password: "password123", displayName: "阿文" } });
  token = r.json().token;
  const r2 = await app.inject({ method: "POST", url: "/v1/auth/register", payload: { email: "z@p.hk", password: "password123", displayName: "外人" } });
  strangerToken = r2.json().token;
  const c = await app.inject({
    method: "POST", url: "/v1/calendars",
    headers: { authorization: `Bearer ${token}` },
    payload: { name: "家庭日曆" },
  });
  calendarId = c.json().calendar.id;
});

after(async () => { await app.close(); });

test("上傳 PNG → list 見到 → 攞檔 content-type 啱", async () => {
  const r = await app.inject({
    method: "POST", url: `/v1/calendars/${calendarId}/photos`,
    headers: { authorization: `Bearer ${token}` },
    payload: { data: PNG_B64, mimeType: "image/png" },
  });
  assert.equal(r.statusCode, 201);
  photoId = r.json().photo.id;
  assert.equal(r.json().photo.uploaderName, "阿文");

  const list = await app.inject({
    method: "GET", url: `/v1/calendars/${calendarId}/photos`,
    headers: { authorization: `Bearer ${token}` },
  });
  assert.equal(list.json().photos.length, 1);

  const file = await app.inject({ method: "GET", url: `/v1/files/${photoId}` });
  assert.equal(file.statusCode, 200);
  assert.equal(file.headers["content-type"], "image/png");
  assert.ok(file.rawPayload.length > 50);
});

test("壞 mimeType 400；非成員 404；人哋張相唔准刪", async () => {
  const bad = await app.inject({
    method: "POST", url: `/v1/calendars/${calendarId}/photos`,
    headers: { authorization: `Bearer ${token}` },
    payload: { data: PNG_B64, mimeType: "image/gif" },
  });
  assert.equal(bad.statusCode, 400);

  const stranger = await app.inject({
    method: "GET", url: `/v1/calendars/${calendarId}/photos`,
    headers: { authorization: `Bearer ${strangerToken}` },
  });
  assert.equal(stranger.statusCode, 404);

  const notMine = await app.inject({
    method: "DELETE", url: `/v1/photos/${photoId}`,
    headers: { authorization: `Bearer ${strangerToken}` },
  });
  assert.equal(notMine.statusCode, 403);

  const mine = await app.inject({
    method: "DELETE", url: `/v1/photos/${photoId}`,
    headers: { authorization: `Bearer ${token}` },
  });
  assert.equal(mine.statusCode, 204);
});
