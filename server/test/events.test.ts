// Task 1.4 — Event CRUD tests.
import { test, before, after } from "node:test";
import assert from "node:assert/strict";
import { execSync } from "node:child_process";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const TEST_DB = `/tmp/mangotime-test-ev-${process.pid}.db`;
process.env.DATABASE_URL = `file:${TEST_DB}`;
process.env.NODE_ENV = "test";

const serverDir = path.resolve(__dirname, "..");
execSync("npx prisma db push --skip-generate", { cwd: serverDir, env: { ...process.env }, stdio: "pipe" });

const { buildApp } = await import("../src/app.js");
const app = await buildApp();

before(async () => {
  await app.ready();
});
after(async () => {
  await app.close();
});

let token = "";
let outsider = "";
let calId = "";
let eventId = "";

test("setup: user + calendar", async () => {
  const reg = await app.inject({
    method: "POST",
    url: "/v1/auth/register",
    payload: { email: "cal@example.com", password: "password123", displayName: "Cal" },
  });
  token = reg.json().token;
  const out = await app.inject({
    method: "POST",
    url: "/v1/auth/register",
    payload: { email: "out@example.com", password: "password123", displayName: "Out" },
  });
  outsider = out.json().token;
  const cal = await app.inject({
    method: "POST",
    url: "/v1/calendars",
    headers: { authorization: `Bearer ${token}` },
    payload: { name: "測試日曆" },
  });
  calId = cal.json().calendar.id;
});

test("create event: full fields", async () => {
  const res = await app.inject({
    method: "POST",
    url: `/v1/calendars/${calId}/events`,
    headers: { authorization: `Bearer ${token}` },
    payload: {
      title: "打邊爐",
      startsAt: "2026-11-18T19:00:00+08:00",
      endsAt: "2026-11-18T21:00:00+08:00",
      repeatRule: "weekly",
      labelColor: "emerald",
      location: "珠海",
      note: "記得帶酒",
    },
  });
  assert.equal(res.statusCode, 201);
  const e = res.json().event;
  assert.equal(e.title, "打邊爐");
  assert.equal(e.repeatRule, "weekly");
  eventId = e.id;
});

test("create event: missing title/startsAt → 400; bad repeat → 400; ends before start → 400", async () => {
  const base = { url: `/v1/calendars/${calId}/events`, headers: { authorization: `Bearer ${token}` } };
  assert.equal((await app.inject({ method: "POST", ...base, payload: { startsAt: "2026-11-18T19:00:00+08:00" } })).statusCode, 400);
  assert.equal((await app.inject({ method: "POST", ...base, payload: { title: "x" } })).statusCode, 400);
  assert.equal((await app.inject({ method: "POST", ...base, payload: { title: "x", startsAt: "2026-11-18T19:00:00+08:00", repeatRule: "hourly" } })).statusCode, 400);
  assert.equal((await app.inject({ method: "POST", ...base, payload: { title: "x", startsAt: "2026-11-18T21:00:00+08:00", endsAt: "2026-11-18T19:00:00+08:00" } })).statusCode, 400);
});

test("list events with range filter", async () => {
  const all = await app.inject({ method: "GET", url: `/v1/calendars/${calId}/events`, headers: { authorization: `Bearer ${token}` } });
  assert.equal(all.json().events.length, 1);
  const nov = await app.inject({
    method: "GET",
    url: `/v1/calendars/${calId}/events?from=2026-11-01T00:00:00%2B08:00&to=2026-11-30T23:59:59%2B08:00`,
    headers: { authorization: `Bearer ${token}` },
  });
  assert.equal(nov.json().events.length, 1);
  const dec = await app.inject({
    method: "GET",
    url: `/v1/calendars/${calId}/events?from=2026-12-01T00:00:00%2B08:00&to=2026-12-31T23:59:59%2B08:00`,
    headers: { authorization: `Bearer ${token}` },
  });
  assert.equal(dec.json().events.length, 0);
});

test("outsider cannot read/create (404 not leaked)", async () => {
  const list = await app.inject({ method: "GET", url: `/v1/calendars/${calId}/events`, headers: { authorization: `Bearer ${outsider}` } });
  assert.equal(list.statusCode, 404);
  const create = await app.inject({
    method: "POST",
    url: `/v1/calendars/${calId}/events`,
    headers: { authorization: `Bearer ${outsider}` },
    payload: { title: "hack", startsAt: "2026-11-19T10:00:00+08:00" },
  });
  assert.equal(create.statusCode, 404);
});

test("update event (member can edit)", async () => {
  const res = await app.inject({
    method: "PATCH",
    url: `/v1/events/${eventId}`,
    headers: { authorization: `Bearer ${token}` },
    payload: { title: "打邊爐（改期）", labelColor: "red" },
  });
  assert.equal(res.statusCode, 200);
  assert.equal(res.json().event.title, "打邊爐（改期）");
});

test("delete: event creator can; after delete list empty", async () => {
  const res = await app.inject({ method: "DELETE", url: `/v1/events/${eventId}`, headers: { authorization: `Bearer ${token}` } });
  assert.equal(res.statusCode, 204);
  const list = await app.inject({ method: "GET", url: `/v1/calendars/${calId}/events`, headers: { authorization: `Bearer ${token}` } });
  assert.equal(list.json().events.length, 0);
});

test("outbox has event.created/updated/deleted", async () => {
  const { PrismaClient } = await import("@prisma/client");
  const prisma = new PrismaClient({ datasources: { db: { url: `file:${TEST_DB}` } } });
  const events = await prisma.outboxEvent.findMany({ where: { type: { startsWith: "event." } } });
  await prisma.$disconnect();
  assert.deepEqual(events.map((e) => e.type), ["event.created", "event.updated", "event.deleted"]);
});
