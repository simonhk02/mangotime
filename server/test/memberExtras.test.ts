// Batch D — 封面圖/最後查看/生日
import { test, before, after } from "node:test";
import assert from "node:assert/strict";
import { execSync } from "node:child_process";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const TEST_DB = `/tmp/mangotime-test-mx-${process.pid}.db`;
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

test("封面圖：上傳 → calendar 有 coverImageUrl → /v1/covers/:name 攞到", async () => {
  const t1 = await signup("cov1@test.com", "C");
  const cal = await app.inject({ method: "POST", url: "/v1/calendars", headers: { authorization: `Bearer ${t1}` }, payload: { name: "C" } });
  const calId = cal.json().calendar.id;
  const png = Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]).toString("base64");
  const up = await app.inject({ method: "POST", url: `/v1/calendars/${calId}/cover`, headers: { authorization: `Bearer ${t1}` }, payload: { data: png, mimeType: "image/png" } });
  assert.equal(up.statusCode, 200);
  const url = up.json().coverImageUrl;
  assert.match(url, /^\/v1\/covers\/cover_[a-f0-9]+\.png$/);
  const got = await app.inject({ method: "GET", url });
  assert.equal(got.statusCode, 200);
  assert.equal(got.headers["content-type"], "image/png");
  // list calendars 見到 coverImageUrl
  const list = await app.inject({ method: "GET", url: "/v1/calendars", headers: { authorization: `Bearer ${t1}` } });
  assert.equal(list.json().calendars[0].coverImageUrl, url);
});

test("最後查看：POST seen → member list 有 lastSeenAt", async () => {
  const t1 = await signup("seen1@test.com", "S");
  const cal = await app.inject({ method: "POST", url: "/v1/calendars", headers: { authorization: `Bearer ${t1}` }, payload: { name: "S" } });
  const calId = cal.json().calendar.id;
  const before2 = await app.inject({ method: "GET", url: `/v1/calendars/${calId}/members`, headers: { authorization: `Bearer ${t1}` } });
  assert.equal(before2.json().members[0].lastSeenAt, null);
  await app.inject({ method: "POST", url: `/v1/calendars/${calId}/seen`, headers: { authorization: `Bearer ${t1}` } });
  const after2 = await app.inject({ method: "GET", url: `/v1/calendars/${calId}/members`, headers: { authorization: `Bearer ${t1}` } });
  assert.ok(after2.json().members[0].lastSeenAt, "lastSeenAt 應該有值");
});

test("生日：PATCH /v1/me set MM-dd → birthdays endpoint 露出", async () => {
  const t1 = await signup("bday1@test.com", "阿壽");
  const cal = await app.inject({ method: "POST", url: "/v1/calendars", headers: { authorization: `Bearer ${t1}` }, payload: { name: "B" } });
  const calId = cal.json().calendar.id;
  const bad = await app.inject({ method: "PATCH", url: "/v1/me", headers: { authorization: `Bearer ${t1}` }, payload: { birthdate: "11月9日" } });
  assert.equal(bad.statusCode, 400);
  const ok = await app.inject({ method: "PATCH", url: "/v1/me", headers: { authorization: `Bearer ${t1}` }, payload: { birthdate: "11-09" } });
  assert.equal(ok.statusCode, 200);
  assert.equal(ok.json().user.birthdate, "11-09");
  const bd = await app.inject({ method: "GET", url: `/v1/calendars/${calId}/birthdays`, headers: { authorization: `Bearer ${t1}` } });
  assert.equal(bd.json().birthdays.length, 1);
  assert.equal(bd.json().birthdays[0].birthdate, "11-09");
});

test("兒童/寵物帳戶：開 → 列 → 生日入埋 birthdays → 刪", async () => {
  const t1 = await signup("kid1@test.com", "爸");
  const cal = await app.inject({ method: "POST", url: "/v1/calendars", headers: { authorization: `Bearer ${t1}` }, payload: { name: "K" } });
  const calId = cal.json().calendar.id;
  const add = await app.inject({ method: "POST", url: `/v1/calendars/${calId}/children`, headers: { authorization: `Bearer ${t1}` }, payload: { name: "細路", birthdate: "03-15" } });
  assert.equal(add.statusCode, 201);
  const childId = add.json().child.id;
  const list = await app.inject({ method: "GET", url: `/v1/calendars/${calId}/children`, headers: { authorization: `Bearer ${t1}` } });
  assert.equal(list.json().children.length, 1);
  const bd = await app.inject({ method: "GET", url: `/v1/calendars/${calId}/birthdays`, headers: { authorization: `Bearer ${t1}` } });
  assert.ok(bd.json().birthdays.some((b: any) => b.displayName === "細路" && b.birthdate === "03-15"));
  const del = await app.inject({ method: "DELETE", url: `/v1/calendars/${calId}/children/${childId}`, headers: { authorization: `Bearer ${t1}` } });
  assert.equal(del.statusCode, 204);
});
