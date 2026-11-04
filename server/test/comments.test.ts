// Task 2.1 tests：event comments 列出/留言/刪除 + 權限
import { test, before, after } from "node:test";
import assert from "node:assert/strict";
import { execSync } from "node:child_process";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const TEST_DB = `/tmp/mangotime-test-cmt-${process.pid}.db`;
process.env.DATABASE_URL = `file:${TEST_DB}`;
process.env.NODE_ENV = "test";

const serverDir = path.resolve(__dirname, "..");
execSync("npx prisma db push --skip-generate", { cwd: serverDir, env: { ...process.env }, stdio: "pipe" });

const { buildApp } = await import("../src/app.js");
let app: Awaited<ReturnType<typeof buildApp>>;
let ownerToken = "";
let strangerToken = "";
let calendarId = "";
let eventId = "";
let commentId = "";

before(async () => {
  app = await buildApp();
  const r1 = await app.inject({ method: "POST", url: "/v1/auth/register", payload: { email: "o@c.hk", password: "password123", displayName: "阿文" } });
  ownerToken = r1.json().token;
  const r2 = await app.inject({ method: "POST", url: "/v1/auth/register", payload: { email: "s@c.hk", password: "password123", displayName: "外人" } });
  strangerToken = r2.json().token;
  const c = await app.inject({
    method: "POST", url: "/v1/calendars",
    headers: { authorization: `Bearer ${ownerToken}` },
    payload: { name: "家庭日曆" },
  });
  calendarId = c.json().calendar.id;
  const e = await app.inject({
    method: "POST", url: `/v1/calendars/${calendarId}/events`,
    headers: { authorization: `Bearer ${ownerToken}` },
    payload: { title: "打邊爐", startsAt: "2026-11-19T19:30:00+08:00" },
  });
  eventId = e.json().event.id;
});

after(async () => { await app.close(); });

test("留言 → 列出見到作者名", async () => {
  const r = await app.inject({
    method: "POST", url: `/v1/events/${eventId}/comments`,
    headers: { authorization: `Bearer ${ownerToken}` },
    payload: { body: "買緊嘢食，要乜？" },
  });
  assert.equal(r.statusCode, 201);
  commentId = r.json().comment.id;
  assert.equal(r.json().comment.authorName, "阿文");

  const list = await app.inject({
    method: "GET", url: `/v1/events/${eventId}/comments`,
    headers: { authorization: `Bearer ${ownerToken}` },
  });
  assert.equal(list.json().comments.length, 1);
  assert.equal(list.json().comments[0].body, "買緊嘢食，要乜？");
});

test("空留言 400；非成員 404", async () => {
  const empty = await app.inject({
    method: "POST", url: `/v1/events/${eventId}/comments`,
    headers: { authorization: `Bearer ${ownerToken}` },
    payload: { body: "   " },
  });
  assert.equal(empty.statusCode, 400);

  const stranger = await app.inject({
    method: "POST", url: `/v1/events/${eventId}/comments`,
    headers: { authorization: `Bearer ${strangerToken}` },
    payload: { body: "hi" },
  });
  assert.equal(stranger.statusCode, 404);

  const strangerList = await app.inject({
    method: "GET", url: `/v1/events/${eventId}/comments`,
    headers: { authorization: `Bearer ${strangerToken}` },
  });
  assert.equal(strangerList.statusCode, 404);
});

test("人哋嘅留言唔准刪；自己嘅刪得", async () => {
  const notMine = await app.inject({
    method: "DELETE", url: `/v1/comments/${commentId}`,
    headers: { authorization: `Bearer ${strangerToken}` },
  });
  assert.equal(notMine.statusCode, 403);

  const mine = await app.inject({
    method: "DELETE", url: `/v1/comments/${commentId}`,
    headers: { authorization: `Bearer ${ownerToken}` },
  });
  assert.equal(mine.statusCode, 204);

  const list = await app.inject({
    method: "GET", url: `/v1/events/${eventId}/comments`,
    headers: { authorization: `Bearer ${ownerToken}` },
  });
  assert.equal(list.json().comments.length, 0);
});
