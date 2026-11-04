// Task 2.5 tests：activity feed 反映真動作 + actor 名 + 權限
import { test, before, after } from "node:test";
import assert from "node:assert/strict";
import { execSync } from "node:child_process";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const TEST_DB = `/tmp/mangotime-test-act-${process.pid}.db`;
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
  const r = await app.inject({ method: "POST", url: "/v1/auth/register", payload: { email: "a@a.hk", password: "password123", displayName: "阿文" } });
  token = r.json().token;
  const r2 = await app.inject({ method: "POST", url: "/v1/auth/register", payload: { email: "b@a.hk", password: "password123", displayName: "外人" } });
  strangerToken = r2.json().token;
  const c = await app.inject({
    method: "POST", url: "/v1/calendars",
    headers: { authorization: `Bearer ${token}` },
    payload: { name: "家庭日曆" },
  });
  calendarId = c.json().calendar.id;
  // 做幾個動作：開活動 + 留言 + 開備忘錄
  const e = await app.inject({
    method: "POST", url: `/v1/calendars/${calendarId}/events`,
    headers: { authorization: `Bearer ${token}` },
    payload: { title: "打邊爐", startsAt: "2026-11-19T19:30:00+08:00" },
  });
  await app.inject({
    method: "POST", url: `/v1/events/${e.json().event.id}/comments`,
    headers: { authorization: `Bearer ${token}` },
    payload: { body: "要乜？" },
  });
  await app.inject({
    method: "POST", url: `/v1/calendars/${calendarId}/memos`,
    headers: { authorization: `Bearer ${token}` },
    payload: { title: "買嘢清單" },
  });
});

after(async () => { await app.close(); });

test("feed 見到全部動作，倒序，有 actor 名", async () => {
  const r = await app.inject({
    method: "GET", url: `/v1/calendars/${calendarId}/activity`,
    headers: { authorization: `Bearer ${token}` },
  });
  assert.equal(r.statusCode, 200);
  const items = r.json().items;
  assert.ok(items.length >= 4, `expected >=4 items, got ${items.length}`);
  const types = items.map((i: { type: string }) => i.type);
  assert.ok(types.includes("event.created"));
  assert.ok(types.includes("event.comment_created"));
  assert.ok(types.includes("memo.created"));
  // 最新排先
  assert.equal(items[0].type, "memo.created");
  // actor 名
  assert.equal(items[0].actorName, "阿文");
  // event.created 有標題
  const ev = items.find((i: { type: string }) => i.type === "event.created");
  assert.ok(ev.text.includes("打邊爐"), `expected title in text: ${ev.text}`);
});

test("非成員 404", async () => {
  const r = await app.inject({
    method: "GET", url: `/v1/calendars/${calendarId}/activity`,
    headers: { authorization: `Bearer ${strangerToken}` },
  });
  assert.equal(r.statusCode, 404);
});
