// Task 2.2 tests：memo CRUD + 留言 + 權限
import { test, before, after } from "node:test";
import assert from "node:assert/strict";
import { execSync } from "node:child_process";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const TEST_DB = `/tmp/mangotime-test-memo-${process.pid}.db`;
process.env.DATABASE_URL = `file:${TEST_DB}`;
process.env.NODE_ENV = "test";

const serverDir = path.resolve(__dirname, "..");
execSync("npx prisma db push --skip-generate", { cwd: serverDir, env: { ...process.env }, stdio: "pipe" });

const { buildApp } = await import("../src/app.js");
let app: Awaited<ReturnType<typeof buildApp>>;
let token = "";
let strangerToken = "";
let calendarId = "";
let memoId = "";

before(async () => {
  app = await buildApp();
  const r = await app.inject({ method: "POST", url: "/v1/auth/register", payload: { email: "m@m.hk", password: "password123", displayName: "阿文" } });
  token = r.json().token;
  const r2 = await app.inject({ method: "POST", url: "/v1/auth/register", payload: { email: "x@m.hk", password: "password123", displayName: "外人" } });
  strangerToken = r2.json().token;
  const c = await app.inject({
    method: "POST", url: "/v1/calendars",
    headers: { authorization: `Bearer ${token}` },
    payload: { name: "家庭日曆" },
  });
  calendarId = c.json().calendar.id;
});

after(async () => { await app.close(); });

test("開 memo → list 見到 → commentCount 0", async () => {
  const r = await app.inject({
    method: "POST", url: `/v1/calendars/${calendarId}/memos`,
    headers: { authorization: `Bearer ${token}` },
    payload: { title: "買嘢清單", body: "紙巾、洗衣液", labelColor: "emerald" },
  });
  assert.equal(r.statusCode, 201);
  memoId = r.json().memo.id;

  const list = await app.inject({
    method: "GET", url: `/v1/calendars/${calendarId}/memos`,
    headers: { authorization: `Bearer ${token}` },
  });
  assert.equal(list.json().memos.length, 1);
  assert.equal(list.json().memos[0].title, "買嘢清單");
  assert.equal(list.json().memos[0].commentCount, 0);
});

test("冇標題 400；衰色 400；非成員 404", async () => {
  const noTitle = await app.inject({
    method: "POST", url: `/v1/calendars/${calendarId}/memos`,
    headers: { authorization: `Bearer ${token}` },
    payload: { title: " " },
  });
  assert.equal(noTitle.statusCode, 400);

  const badColor = await app.inject({
    method: "POST", url: `/v1/calendars/${calendarId}/memos`,
    headers: { authorization: `Bearer ${token}` },
    payload: { title: "x", labelColor: "pink" },
  });
  assert.equal(badColor.statusCode, 400);

  const stranger = await app.inject({
    method: "GET", url: `/v1/calendars/${calendarId}/memos`,
    headers: { authorization: `Bearer ${strangerToken}` },
  });
  assert.equal(stranger.statusCode, 404);
});

test("改 memo → 留言 → count 1 → 刪 memo", async () => {
  const patch = await app.inject({
    method: "PATCH", url: `/v1/memos/${memoId}`,
    headers: { authorization: `Bearer ${token}` },
    payload: { body: "紙巾、洗衣液、貓糧" },
  });
  assert.equal(patch.json().memo.body, "紙巾、洗衣液、貓糧");

  const c = await app.inject({
    method: "POST", url: `/v1/memos/${memoId}/comments`,
    headers: { authorization: `Bearer ${token}` },
    payload: { body: "貓糧要無穀物嗰隻吖" },
  });
  assert.equal(c.statusCode, 201);

  const list = await app.inject({
    method: "GET", url: `/v1/calendars/${calendarId}/memos`,
    headers: { authorization: `Bearer ${token}` },
  });
  assert.equal(list.json().memos[0].commentCount, 1);

  const del = await app.inject({
    method: "DELETE", url: `/v1/memos/${memoId}`,
    headers: { authorization: `Bearer ${token}` },
  });
  assert.equal(del.statusCode, 204);
});
