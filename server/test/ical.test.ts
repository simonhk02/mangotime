// Task 5.5 tests：export 出嚟嘅 ics 可以 import 返入去（round-trip）
import { test, before, after } from "node:test";
import assert from "node:assert/strict";
import { execSync } from "node:child_process";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const TEST_DB = `/tmp/mangotime-test-ical-${process.pid}.db`;
process.env.DATABASE_URL = `file:${TEST_DB}`;
process.env.NODE_ENV = "test";

const serverDir = path.resolve(__dirname, "..");
execSync("npx prisma db push --skip-generate", { cwd: serverDir, env: { ...process.env }, stdio: "pipe" });

const { buildApp } = await import("../src/app.js");
let app: Awaited<ReturnType<typeof buildApp>>;
let token = "";
let calA = "";

before(async () => {
  app = await buildApp();
  const r = await app.inject({ method: "POST", url: "/v1/auth/register", payload: { email: "ical@i.hk", password: "password123", displayName: "阿怡" } });
  token = r.json().token;
  const c = await app.inject({
    method: "POST", url: "/v1/calendars",
    headers: { authorization: `Bearer ${token}` },
    payload: { name: "搬屋曆" },
  });
  calA = c.json().calendar.id;
  await app.inject({
    method: "POST", url: `/v1/calendars/${calA}/events`,
    headers: { authorization: `Bearer ${token}` },
    payload: { title: "打邊爐, 記住", startsAt: "2026-11-19T19:30:00.000Z", location: "屋企", note: "帶酒\n兩枝" },
  });
  await app.inject({
    method: "POST", url: `/v1/calendars/${calA}/events`,
    headers: { authorization: `Bearer ${token}` },
    payload: { title: "家長日", startsAt: "2026-11-24T00:00:00.000Z", allDay: true, repeatRule: "yearly" },
  });
});

after(async () => { await app.close(); });

test("export → 標準 ics 格式（escape 咗逗號換行）", async () => {
  const r = await app.inject({
    method: "GET", url: `/v1/calendars/${calA}/export.ics`,
    headers: { authorization: `Bearer ${token}` },
  });
  assert.equal(r.statusCode, 200);
  assert.equal(r.headers["content-type"], "text/calendar; charset=utf-8");
  const body = r.body;
  assert.ok(body.includes("BEGIN:VCALENDAR"));
  assert.ok(body.includes("X-WR-CALNAME:搬屋曆"));
  assert.ok(body.includes("SUMMARY:打邊爐\\, 記住"), "逗號要 escape");
  assert.ok(body.includes("DESCRIPTION:帶酒\\n兩枝"), "換行要 escape");
  assert.ok(body.includes("DTSTART;VALUE=DATE:20261124"), "全日用 DATE 格式");
  assert.ok(body.includes("RRULE:FREQ=YEARLY"));
});

test("round-trip：export 出嚟 import 入新曆，活動數目同內容啱", async () => {
  const exp = await app.inject({
    method: "GET", url: `/v1/calendars/${calA}/export.ics`,
    headers: { authorization: `Bearer ${token}` },
  });
  const c2 = await app.inject({
    method: "POST", url: "/v1/calendars",
    headers: { authorization: `Bearer ${token}` },
    payload: { name: "新曆" },
  });
  const calB = c2.json().calendar.id;
  const imp = await app.inject({
    method: "POST", url: `/v1/calendars/${calB}/import`,
    headers: { authorization: `Bearer ${token}` },
    payload: { ics: exp.body },
  });
  assert.equal(imp.statusCode, 201);
  assert.equal(imp.json().imported, 2);

  const evs = await app.inject({
    method: "GET", url: `/v1/calendars/${calB}/events`,
    headers: { authorization: `Bearer ${token}` },
  });
  const titles = evs.json().events.map((e: { title: string }) => e.title).sort();
  assert.deepEqual(titles, ["家長日", "打邊爐, 記住"].sort());
});

test("import 垃圾 → 400", async () => {
  const r = await app.inject({
    method: "POST", url: `/v1/calendars/${calA}/import`,
    headers: { authorization: `Bearer ${token}` },
    payload: { ics: "hello world" },
  });
  assert.equal(r.statusCode, 400);
});
