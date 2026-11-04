// Task 3.2 tests：event search
import { test, before, after } from "node:test";
import assert from "node:assert/strict";
import { execSync } from "node:child_process";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const TEST_DB = `/tmp/mangotime-test-search-${process.pid}.db`;
process.env.DATABASE_URL = `file:${TEST_DB}`;
process.env.NODE_ENV = "test";

const serverDir = path.resolve(__dirname, "..");
execSync("npx prisma db push --skip-generate", { cwd: serverDir, env: { ...process.env }, stdio: "pipe" });

const { buildApp } = await import("../src/app.js");
let app: Awaited<ReturnType<typeof buildApp>>;
let token = "";
let strangerToken = "";
let calendarId = "";

before(async () => {
  app = await buildApp();
  const r = await app.inject({ method: "POST", url: "/v1/auth/register", payload: { email: "s1@s.hk", password: "password123", displayName: "阿文" } });
  token = r.json().token;
  const r2 = await app.inject({ method: "POST", url: "/v1/auth/register", payload: { email: "s2@s.hk", password: "password123", displayName: "外人" } });
  strangerToken = r2.json().token;
  const c = await app.inject({
    method: "POST", url: "/v1/calendars",
    headers: { authorization: `Bearer ${token}` },
    payload: { name: "家庭日曆" },
  });
  calendarId = c.json().calendar.id;
  for (const [title, loc] of [["打邊爐", "屋企"], ["屋企人飯局", "酒樓"], ["網球", ""]] as const) {
    await app.inject({
      method: "POST", url: `/v1/calendars/${calendarId}/events`,
      headers: { authorization: `Bearer ${token}` },
      payload: { title, location: loc, startsAt: "2026-11-20T19:00:00+08:00" },
    });
  }
});

after(async () => { await app.close(); });

test("搜『打邊爐』中 1 個；搜『屋企』中 2 個（title+location）", async () => {
  const r1 = await app.inject({
    method: "GET", url: `/v1/calendars/${calendarId}/events/search?q=${encodeURIComponent("打邊爐")}`,
    headers: { authorization: `Bearer ${token}` },
  });
  assert.equal(r1.json().events.length, 1);

  const r2 = await app.inject({
    method: "GET", url: `/v1/calendars/${calendarId}/events/search?q=${encodeURIComponent("屋企")}`,
    headers: { authorization: `Bearer ${token}` },
  });
  assert.equal(r2.json().events.length, 2);
});

test("冇 q 400；非成員 404；唔中返空", async () => {
  const noQ = await app.inject({
    method: "GET", url: `/v1/calendars/${calendarId}/events/search`,
    headers: { authorization: `Bearer ${token}` },
  });
  assert.equal(noQ.statusCode, 400);

  const stranger = await app.inject({
    method: "GET", url: `/v1/calendars/${calendarId}/events/search?q=x`,
    headers: { authorization: `Bearer ${strangerToken}` },
  });
  assert.equal(stranger.statusCode, 404);

  const miss = await app.inject({
    method: "GET", url: `/v1/calendars/${calendarId}/events/search?q=${encodeURIComponent("唔存在")}`,
    headers: { authorization: `Bearer ${token}` },
  });
  assert.equal(miss.json().events.length, 0);
});
