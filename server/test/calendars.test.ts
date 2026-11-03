// Task 1.2 — Calendar CRUD tests (membership scoping + role rules + outbox events).
import { test, before, after } from "node:test";
import assert from "node:assert/strict";
import { execSync } from "node:child_process";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const TEST_DB = `/tmp/mangotime-test-cal-${process.pid}.db`;
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

async function register(email: string, name: string) {
  const res = await app.inject({
    method: "POST",
    url: "/v1/auth/register",
    payload: { email, password: "password123", displayName: name },
  });
  assert.equal(res.statusCode, 201);
  return res.json().token as string;
}

let alice = "";
let bob = "";
let calId = "";

test("setup: two users", async () => {
  alice = await register("alice@example.com", "Alice");
  bob = await register("bob@example.com", "Bob");
});

test("create calendar → creator membership + outbox event", async () => {
  const res = await app.inject({
    method: "POST",
    url: "/v1/calendars",
    headers: { authorization: `Bearer ${alice}` },
    payload: { name: "家庭日曆" },
  });
  assert.equal(res.statusCode, 201);
  const cal = res.json().calendar;
  assert.equal(cal.name, "家庭日曆");
  assert.equal(cal.myRole, "creator");
  assert.equal(cal.memberCount, 1);
  calId = cal.id;
});

test("create without auth → 401; without name → 400", async () => {
  const noAuth = await app.inject({ method: "POST", url: "/v1/calendars", payload: { name: "X" } });
  assert.equal(noAuth.statusCode, 401);
  const noName = await app.inject({
    method: "POST",
    url: "/v1/calendars",
    headers: { authorization: `Bearer ${alice}` },
    payload: {},
  });
  assert.equal(noName.statusCode, 400);
});

test("list: alice sees it, bob does not (multi-tenant)", async () => {
  const a = await app.inject({ method: "GET", url: "/v1/calendars", headers: { authorization: `Bearer ${alice}` } });
  assert.equal(a.json().calendars.length, 1);
  const b = await app.inject({ method: "GET", url: "/v1/calendars", headers: { authorization: `Bearer ${bob}` } });
  assert.equal(b.json().calendars.length, 0);
});

test("non-member read → 404 (existence not leaked)", async () => {
  const res = await app.inject({ method: "GET", url: `/v1/calendars/${calId}`, headers: { authorization: `Bearer ${bob}` } });
  assert.equal(res.statusCode, 404);
});

test("rename by creator works; by non-member → 404", async () => {
  const ok = await app.inject({
    method: "PATCH",
    url: `/v1/calendars/${calId}`,
    headers: { authorization: `Bearer ${alice}` },
    payload: { name: "家庭+工作", coverImageUrl: "https://example.com/cover.png" },
  });
  assert.equal(ok.statusCode, 200);
  assert.equal(ok.json().calendar.name, "家庭+工作");
  const bad = await app.inject({
    method: "PATCH",
    url: `/v1/calendars/${calId}`,
    headers: { authorization: `Bearer ${bob}` },
    payload: { name: "hack" },
  });
  assert.equal(bad.statusCode, 404);
});

test("delete by creator → 204 and list empty", async () => {
  const res = await app.inject({ method: "DELETE", url: `/v1/calendars/${calId}`, headers: { authorization: `Bearer ${alice}` } });
  assert.equal(res.statusCode, 204);
  const list = await app.inject({ method: "GET", url: "/v1/calendars", headers: { authorization: `Bearer ${alice}` } });
  assert.equal(list.json().calendars.length, 0);
});

test("outbox captured calendar.created/updated/deleted", async () => {
  // read via prisma directly (test-only introspection)
  const { PrismaClient } = await import("@prisma/client");
  const prisma = new PrismaClient({ datasources: { db: { url: `file:${TEST_DB}` } } });
  const events = await prisma.outboxEvent.findMany({ orderBy: { createdAt: "asc" } });
  await prisma.$disconnect();
  assert.deepEqual(events.map((e) => e.type), ["calendar.created", "calendar.updated", "calendar.deleted"]);
});
