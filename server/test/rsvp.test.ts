// RSVP — 參加/取消參加活動
import { test, before, after } from "node:test";
import assert from "node:assert/strict";
import { execSync } from "node:child_process";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const TEST_DB = `/tmp/mangotime-test-rsvp-${process.pid}.db`;
process.env.DATABASE_URL = `file:${TEST_DB}`;
process.env.NODE_ENV = "test";

const serverDir = path.resolve(__dirname, "..");
execSync("npx prisma db push --skip-generate", { cwd: serverDir, env: { ...process.env }, stdio: "pipe" });

const { buildApp } = await import("../src/app.js");
const app = await buildApp();

before(async () => { await app.ready(); });
after(async () => { await app.close(); });

async function signup(email: string, name: string): Promise<string> {
  const res = await app.inject({ method: "POST", url: "/v1/auth/register", payload: { email, password: "password123", displayName: name } });
  assert.equal(res.statusCode, 201);
  return res.json().token;
}

test("RSVP：成員表態/修改/收回，list 帶 participants + goingCount", async () => {
  const t1 = await signup("rsvp1@test.com", "阿一");
  const t2 = await signup("rsvp2@test.com", "阿二");
  const cal = await app.inject({ method: "POST", url: "/v1/calendars", headers: { authorization: `Bearer ${t1}` }, payload: { name: "RSVP 曆" } });
  const calId = cal.json().calendar.id;
  const invite = await app.inject({ method: "POST", url: `/v1/calendars/${calId}/invites`, headers: { authorization: `Bearer ${t1}` } });
  const acc = await app.inject({ method: "POST", url: `/v1/invites/${invite.json().invite.code}/accept`, headers: { authorization: `Bearer ${t2}` } });
  assert.equal(acc.statusCode, 200);
  const ev = await app.inject({ method: "POST", url: `/v1/calendars/${calId}/events`, headers: { authorization: `Bearer ${t1}` }, payload: { title: "BBQ", startsAt: "2026-11-20T10:00:00Z" } });
  const eventId = ev.json().event.id;

  const r1 = await app.inject({ method: "POST", url: `/v1/events/${eventId}/rsvp`, headers: { authorization: `Bearer ${t2}` }, payload: { status: "going" } });
  assert.equal(r1.statusCode, 200);
  assert.equal(r1.json().status, "going");
  await app.inject({ method: "POST", url: `/v1/events/${eventId}/rsvp`, headers: { authorization: `Bearer ${t1}` }, payload: { status: "going" } });

  const list = await app.inject({ method: "GET", url: `/v1/calendars/${calId}/events?from=2026-11-01T00:00:00Z&to=2026-11-30T00:00:00Z`, headers: { authorization: `Bearer ${t1}` } });
  const found = list.json().events.find((e: any) => e.id === eventId);
  assert.equal(found.goingCount, 2);
  assert.equal(found.participants.length, 2);

  await app.inject({ method: "POST", url: `/v1/events/${eventId}/rsvp`, headers: { authorization: `Bearer ${t2}` }, payload: { status: "declined" } });
  const list2 = await app.inject({ method: "GET", url: `/v1/calendars/${calId}/events?from=2026-11-01T00:00:00Z&to=2026-11-30T00:00:00Z`, headers: { authorization: `Bearer ${t1}` } });
  assert.equal(list2.json().events.find((e: any) => e.id === eventId).goingCount, 1);

  await app.inject({ method: "DELETE", url: `/v1/events/${eventId}/rsvp`, headers: { authorization: `Bearer ${t2}` } });
  const list3 = await app.inject({ method: "GET", url: `/v1/calendars/${calId}/events?from=2026-11-01T00:00:00Z&to=2026-11-30T00:00:00Z`, headers: { authorization: `Bearer ${t1}` } });
  assert.equal(list3.json().events.find((e: any) => e.id === eventId).participants.length, 1);
});

test("RSVP：非成員 403；壞 status 400", async () => {
  const t1 = await signup("rsvp3@test.com", "阿三");
  const tOut = await signup("rsvp4@test.com", "外人");
  const cal = await app.inject({ method: "POST", url: "/v1/calendars", headers: { authorization: `Bearer ${t1}` }, payload: { name: "X" } });
  const ev = await app.inject({ method: "POST", url: `/v1/calendars/${cal.json().calendar.id}/events`, headers: { authorization: `Bearer ${t1}` }, payload: { title: "Y", startsAt: "2026-11-21T10:00:00Z" } });
  const eventId = ev.json().event.id;
  const bad = await app.inject({ method: "POST", url: `/v1/events/${eventId}/rsvp`, headers: { authorization: `Bearer ${t1}` }, payload: { status: "maybe" } });
  assert.equal(bad.statusCode, 400);
  const nope = await app.inject({ method: "POST", url: `/v1/events/${eventId}/rsvp`, headers: { authorization: `Bearer ${tOut}` }, payload: { status: "going" } });
  assert.equal(nope.statusCode, 403);
});
