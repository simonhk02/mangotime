// Task 5.4 tests：event attachment 上傳/列表/攞檔/刪除 + 權限
import { test, before, after } from "node:test";
import assert from "node:assert/strict";
import { execSync } from "node:child_process";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { mkdtempSync } from "node:fs";
import os from "node:os";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const TEST_DB = `/tmp/mangotime-test-att-${process.pid}.db`;
process.env.DATABASE_URL = `file:${TEST_DB}`;
process.env.NODE_ENV = "test";
process.env.UPLOAD_DIR = mkdtempSync(path.join(os.tmpdir(), "mt-att-"));

const serverDir = path.resolve(__dirname, "..");
execSync("npx prisma db push --skip-generate", { cwd: serverDir, env: { ...process.env }, stdio: "pipe" });

const { buildApp } = await import("../src/app.js");
let app: Awaited<ReturnType<typeof buildApp>>;
let token = "";
let eventId = "";

// 1x1 紅色 PNG
const PNG = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==";

before(async () => {
  app = await buildApp();
  const r = await app.inject({ method: "POST", url: "/v1/auth/register", payload: { email: "att@a.hk", password: "password123", displayName: "阿儀" } });
  token = r.json().token;
  const c = await app.inject({
    method: "POST", url: "/v1/calendars",
    headers: { authorization: `Bearer ${token}` },
    payload: { name: "附件曆" },
  });
  const e = await app.inject({
    method: "POST", url: `/v1/calendars/${c.json().calendar.id}/events`,
    headers: { authorization: `Bearer ${token}` },
    payload: { title: "BBQ", startsAt: "2026-11-20T18:00:00+08:00" },
  });
  eventId = e.json().event.id;
});

after(async () => { await app.close(); });

test("上傳 PNG 附件 → list → 攞檔 byte 相同", async () => {
  const up = await app.inject({
    method: "POST", url: `/v1/events/${eventId}/attachments`,
    headers: { authorization: `Bearer ${token}` },
    payload: { data: PNG, mimeType: "image/png" },
  });
  assert.equal(up.statusCode, 201);
  const att = up.json().attachment;
  assert.equal(att.mimeType, "image/png");

  const list = await app.inject({
    method: "GET", url: `/v1/events/${eventId}/attachments`,
    headers: { authorization: `Bearer ${token}` },
  });
  assert.equal(list.json().attachments.length, 1);

  const file = await app.inject({ method: "GET", url: `/v1/attachments/${att.id}/file` });
  assert.equal(file.statusCode, 200);
  assert.equal(file.headers["content-type"], "image/png");
  assert.equal(Buffer.from(file.rawPayload).toString("base64"), PNG);

  const del = await app.inject({
    method: "DELETE", url: `/v1/attachments/${att.id}`,
    headers: { authorization: `Bearer ${token}` },
  });
  assert.equal(del.statusCode, 204);
  const gone = await app.inject({ method: "GET", url: `/v1/attachments/${att.id}/file` });
  assert.equal(gone.statusCode, 404);
});

test("權限：非成員上傳 404；bad mimeType 400", async () => {
  const r2 = await app.inject({ method: "POST", url: "/v1/auth/register", payload: { email: "out@o.hk", password: "password123", displayName: "外人" } });
  const t2 = r2.json().token;
  const up = await app.inject({
    method: "POST", url: `/v1/events/${eventId}/attachments`,
    headers: { authorization: `Bearer ${t2}` },
    payload: { data: PNG, mimeType: "image/png" },
  });
  assert.equal(up.statusCode, 404);

  const bad = await app.inject({
    method: "POST", url: `/v1/events/${eventId}/attachments`,
    headers: { authorization: `Bearer ${token}` },
    payload: { data: PNG, mimeType: "application/exe" },
  });
  assert.equal(bad.statusCode, 400);
});
