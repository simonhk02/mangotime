// Task 5.2 tests：public calendar 開/關/公開讀取（sanitize）
import { test, before, after } from "node:test";
import assert from "node:assert/strict";
import { execSync } from "node:child_process";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const TEST_DB = `/tmp/mangotime-test-pub-${process.pid}.db`;
process.env.DATABASE_URL = `file:${TEST_DB}`;
process.env.NODE_ENV = "test";

const serverDir = path.resolve(__dirname, "..");
execSync("npx prisma db push --skip-generate", { cwd: serverDir, env: { ...process.env }, stdio: "pipe" });

const { buildApp } = await import("../src/app.js");
let app: Awaited<ReturnType<typeof buildApp>>;
let token = "";
let calendarId = "";
let slug = "";

before(async () => {
  app = await buildApp();
  const r = await app.inject({ method: "POST", url: "/v1/auth/register", payload: { email: "pub@p.hk", password: "password123", displayName: "阿文" } });
  token = r.json().token;
  const c = await app.inject({
    method: "POST", url: "/v1/calendars",
    headers: { authorization: `Bearer ${token}` },
    payload: { name: "屋企時間表" },
  });
  calendarId = c.json().calendar.id;
  await app.inject({
    method: "POST", url: `/v1/calendars/${calendarId}/events`,
    headers: { authorization: `Bearer ${token}` },
    payload: { title: "打邊爐", startsAt: "2026-11-19T19:30:00+08:00", labelColor: "red" },
  });
});

after(async () => { await app.close(); });

test("開公開 link → 唔使 auth 都讀到名+活動（sanitize 冇 creatorId）", async () => {
  const r = await app.inject({
    method: "POST", url: `/v1/calendars/${calendarId}/public`,
    headers: { authorization: `Bearer ${token}` },
  });
  assert.equal(r.statusCode, 201);
  slug = r.json().publicSlug;
  assert.ok(slug.length >= 10);

  const info = await app.inject({ method: "GET", url: `/v1/public/${slug}` });
  assert.equal(info.json().calendar.name, "屋企時間表");

  const events = await app.inject({ method: "GET", url: `/v1/public/${slug}/events` });
  assert.equal(events.json().events.length, 1);
  assert.equal(events.json().events[0].title, "打邊爐");
  assert.equal(events.json().events[0].creatorId, undefined, "唔應該洩 creatorId");
});

test("再開返同一個 slug；假 slug 404；關咗就 404", async () => {
  const again = await app.inject({
    method: "POST", url: `/v1/calendars/${calendarId}/public`,
    headers: { authorization: `Bearer ${token}` },
  });
  assert.equal(again.json().publicSlug, slug);

  const bad = await app.inject({ method: "GET", url: "/v1/public/nope-nope" });
  assert.equal(bad.statusCode, 404);

  const off = await app.inject({
    method: "DELETE", url: `/v1/calendars/${calendarId}/public`,
    headers: { authorization: `Bearer ${token}` },
  });
  assert.equal(off.statusCode, 204);
  const gone = await app.inject({ method: "GET", url: `/v1/public/${slug}` });
  assert.equal(gone.statusCode, 404);
});
