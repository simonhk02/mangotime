// Task 1.3 tests：invite link 開/攞/接受 + members list + 權限
import { test, before, after } from "node:test";
import assert from "node:assert/strict";
import { execSync } from "node:child_process";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const TEST_DB = `/tmp/mangotime-test-inv-${process.pid}.db`;
process.env.DATABASE_URL = `file:${TEST_DB}`;
process.env.NODE_ENV = "test";

const serverDir = path.resolve(__dirname, "..");
execSync("npx prisma db push --skip-generate", { cwd: serverDir, env: { ...process.env }, stdio: "pipe" });

const { buildApp } = await import("../src/app.js");
let app: Awaited<ReturnType<typeof buildApp>>;
let ownerToken = "";
let friendToken = "";
let calendarId = "";
let code = "";

before(async () => {
  app = await buildApp();
  const r1 = await app.inject({ method: "POST", url: "/v1/auth/register", payload: { email: "owner@test.hk", password: "password123", displayName: "阿主" } });
  ownerToken = r1.json().token;
  const r2 = await app.inject({ method: "POST", url: "/v1/auth/register", payload: { email: "friend@test.hk", password: "password123", displayName: "朋友" } });
  friendToken = r2.json().token;
  const c = await app.inject({
    method: "POST", url: "/v1/calendars",
    headers: { authorization: `Bearer ${ownerToken}` },
    payload: { name: "家庭日曆" },
  });
  calendarId = c.json().calendar.id;
});

after(async () => { await app.close(); });

test("未登入開唔到 invite", async () => {
  const r = await app.inject({ method: "POST", url: `/v1/calendars/${calendarId}/invites` });
  assert.equal(r.statusCode, 401);
});

test("owner 開 invite 得 code；再開返同一條", async () => {
  const r = await app.inject({
    method: "POST", url: `/v1/calendars/${calendarId}/invites`,
    headers: { authorization: `Bearer ${ownerToken}` },
  });
  assert.equal(r.statusCode, 201);
  code = r.json().invite.code;
  assert.ok(code.length >= 8);

  const r2 = await app.inject({
    method: "POST", url: `/v1/calendars/${calendarId}/invites`,
    headers: { authorization: `Bearer ${ownerToken}` },
  });
  assert.equal(r2.statusCode, 200);
  assert.equal(r2.json().invite.code, code);
});

test("預覽 invite（唔使登入）見到日曆名 + 人數", async () => {
  const r = await app.inject({ method: "GET", url: `/v1/invites/${code}` });
  assert.equal(r.statusCode, 200);
  assert.equal(r.json().invite.calendarName, "家庭日曆");
  assert.equal(r.json().invite.memberCount, 1);
});

test("非成員唔准開 invite（404 唔洩存在）", async () => {
  const r = await app.inject({
    method: "POST", url: `/v1/calendars/${calendarId}/invites`,
    headers: { authorization: `Bearer ${friendToken}` },
  });
  assert.equal(r.statusCode, 404);
});

test("friend 接受 invite → 成為成員，list 見到兩個", async () => {
  const r = await app.inject({
    method: "POST", url: `/v1/invites/${code}/accept`,
    headers: { authorization: `Bearer ${friendToken}` },
  });
  assert.equal(r.statusCode, 200);
  assert.equal(r.json().alreadyMember, false);

  const again = await app.inject({
    method: "POST", url: `/v1/invites/${code}/accept`,
    headers: { authorization: `Bearer ${friendToken}` },
  });
  assert.equal(again.json().alreadyMember, true);

  const list = await app.inject({
    method: "GET", url: `/v1/calendars/${calendarId}/members`,
    headers: { authorization: `Bearer ${ownerToken}` },
  });
  const members = list.json().members;
  assert.equal(members.length, 2);
  assert.equal(members[0].role, "creator");
  assert.equal(members[1].role, "member");
  assert.equal(members[1].displayName, "朋友");
});

test("friend 而家睇到個行事曆（membership-scoped list）", async () => {
  const r = await app.inject({
    method: "GET", url: "/v1/calendars",
    headers: { authorization: `Bearer ${friendToken}` },
  });
  assert.equal(r.json().calendars.length, 1);
  assert.equal(r.json().calendars[0].name, "家庭日曆");
});

test("member 唔准移除人；creator 移除得", async () => {
  const members = (await app.inject({
    method: "GET", url: `/v1/calendars/${calendarId}/members`,
    headers: { authorization: `Bearer ${ownerToken}` },
  })).json().members;
  const friendId = members[1].userId;

  const byMember = await app.inject({
    method: "DELETE", url: `/v1/calendars/${calendarId}/members/${friendId}`,
    headers: { authorization: `Bearer ${friendToken}` },
  });
  assert.equal(byMember.statusCode, 403);

  const byOwner = await app.inject({
    method: "DELETE", url: `/v1/calendars/${calendarId}/members/${friendId}`,
    headers: { authorization: `Bearer ${ownerToken}` },
  });
  assert.equal(byOwner.statusCode, 204);
});

test("假 code 404", async () => {
  const r = await app.inject({ method: "GET", url: "/v1/invites/NOPE1234" });
  assert.equal(r.statusCode, 404);
});
