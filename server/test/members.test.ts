// 成員指定 + 成員顏色 + 釘選 + 刪除成員（batch A）
import { test, before, after } from "node:test";
import assert from "node:assert/strict";
import { execSync } from "node:child_process";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const TEST_DB = `/tmp/mangotime-test-mem-${process.pid}.db`;
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

test("成員指定：create 帶 memberIds → list 見到；update 換人；空陣列=全部成員", async () => {
  const t1 = await signup("mem1@test.com", "阿一");
  const t2 = await signup("mem2@test.com", "阿二");
  const cal = await app.inject({ method: "POST", url: "/v1/calendars", headers: { authorization: `Bearer ${t1}` }, payload: { name: "M" } });
  const calId = cal.json().calendar.id;
  const invite = await app.inject({ method: "POST", url: `/v1/calendars/${calId}/invites`, headers: { authorization: `Bearer ${t1}` } });
  await app.inject({ method: "POST", url: `/v1/invites/${invite.json().invite.code}/accept`, headers: { authorization: `Bearer ${t2}` } });
  // 阿二嘅 userId
  const members = await app.inject({ method: "GET", url: `/v1/calendars/${calId}/members`, headers: { authorization: `Bearer ${t1}` } });
  const uid2 = members.json().members.find((m: any) => m.displayName === "阿二").userId;

  // 開活動指定阿二
  const ev = await app.inject({ method: "POST", url: `/v1/calendars/${calId}/events`, headers: { authorization: `Bearer ${t1}` }, payload: { title: "指定活動", startsAt: "2026-11-20T10:00:00Z", memberIds: [uid2] } });
  assert.equal(ev.statusCode, 201);
  assert.deepEqual(ev.json().event.memberIds, [uid2]);

  // list 帶 memberIds
  const list = await app.inject({ method: "GET", url: `/v1/calendars/${calId}/events?from=2026-11-01T00:00:00Z&to=2026-11-30T00:00:00Z`, headers: { authorization: `Bearer ${t1}` } });
  const found = list.json().events.find((e: any) => e.id === ev.json().event.id);
  assert.deepEqual(found.memberIds, [uid2]);

  // update 換返全部成員（空陣列）
  const up = await app.inject({ method: "PATCH", url: `/v1/events/${ev.json().event.id}`, headers: { authorization: `Bearer ${t1}` }, payload: { memberIds: [] } });
  assert.equal(up.statusCode, 200);
  assert.deepEqual(up.json().event.memberIds, []);
});

test("釘選：pinned 開關", async () => {
  const t1 = await signup("pin1@test.com", "P");
  const cal = await app.inject({ method: "POST", url: "/v1/calendars", headers: { authorization: `Bearer ${t1}` }, payload: { name: "P" } });
  const ev = await app.inject({ method: "POST", url: `/v1/calendars/${cal.json().calendar.id}/events`, headers: { authorization: `Bearer ${t1}` }, payload: { title: "釘", startsAt: "2026-11-20T10:00:00Z", pinned: true } });
  assert.equal(ev.json().event.pinned, true);
  const up = await app.inject({ method: "PATCH", url: `/v1/events/${ev.json().event.id}`, headers: { authorization: `Bearer ${t1}` }, payload: { pinned: false } });
  assert.equal(up.json().event.pinned, false);
});

test("成員顏色：自己改自己；list 露出 color", async () => {
  const t1 = await signup("col1@test.com", "C1");
  const cal = await app.inject({ method: "POST", url: "/v1/calendars", headers: { authorization: `Bearer ${t1}` }, payload: { name: "C" } });
  const calId = cal.json().calendar.id;
  const members = await app.inject({ method: "GET", url: `/v1/calendars/${calId}/members`, headers: { authorization: `Bearer ${t1}` } });
  const uid = members.json().members[0].userId;
  const r = await app.inject({ method: "PATCH", url: `/v1/calendars/${calId}/members/${uid}/color`, headers: { authorization: `Bearer ${t1}` }, payload: { color: "emerald" } });
  assert.equal(r.statusCode, 200);
  const m2 = await app.inject({ method: "GET", url: `/v1/calendars/${calId}/members`, headers: { authorization: `Bearer ${t1}` } });
  assert.equal(m2.json().members[0].color, "emerald");
});

test("刪除成員：creator 可以踢人；自己踢自己 400", async () => {
  const t1 = await signup("kick1@test.com", "K1");
  const t2 = await signup("kick2@test.com", "K2");
  const cal = await app.inject({ method: "POST", url: "/v1/calendars", headers: { authorization: `Bearer ${t1}` }, payload: { name: "K" } });
  const calId = cal.json().calendar.id;
  const invite = await app.inject({ method: "POST", url: `/v1/calendars/${calId}/invites`, headers: { authorization: `Bearer ${t1}` } });
  await app.inject({ method: "POST", url: `/v1/invites/${invite.json().invite.code}/accept`, headers: { authorization: `Bearer ${t2}` } });
  const members = await app.inject({ method: "GET", url: `/v1/calendars/${calId}/members`, headers: { authorization: `Bearer ${t1}` } });
  const uid2 = members.json().members.find((m: any) => m.displayName === "K2").userId;
  const del = await app.inject({ method: "DELETE", url: `/v1/calendars/${calId}/members/${uid2}`, headers: { authorization: `Bearer ${t1}` } });
  assert.equal(del.statusCode, 204);
  const after2 = await app.inject({ method: "GET", url: `/v1/calendars/${calId}/members`, headers: { authorization: `Bearer ${t1}` } });
  assert.equal(after2.json().members.length, 1);
  // 踢自己（用返自己 id）
  const me = await app.inject({ method: "GET", url: `/v1/calendars/${calId}/members`, headers: { authorization: `Bearer ${t1}` } });
  const uid1 = me.json().members[0].userId;
  const selfDel = await app.inject({ method: "DELETE", url: `/v1/calendars/${calId}/members/${uid1}`, headers: { authorization: `Bearer ${t1}` } });
  assert.equal(selfDel.statusCode, 400);
});
