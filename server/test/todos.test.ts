// Task 2.3 tests：todo list CRUD + item toggle + 權限
import { test, before, after } from "node:test";
import assert from "node:assert/strict";
import { execSync } from "node:child_process";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const TEST_DB = `/tmp/mangotime-test-todo-${process.pid}.db`;
process.env.DATABASE_URL = `file:${TEST_DB}`;
process.env.NODE_ENV = "test";

const serverDir = path.resolve(__dirname, "..");
execSync("npx prisma db push --skip-generate", { cwd: serverDir, env: { ...process.env }, stdio: "pipe" });

const { buildApp } = await import("../src/app.js");
let app: Awaited<ReturnType<typeof buildApp>>;
let token = "";
let strangerToken = "";
let calendarId = "";
let listId = "";
let itemId = "";

before(async () => {
  app = await buildApp();
  const r = await app.inject({ method: "POST", url: "/v1/auth/register", payload: { email: "t@t.hk", password: "password123", displayName: "阿文" } });
  token = r.json().token;
  const r2 = await app.inject({ method: "POST", url: "/v1/auth/register", payload: { email: "y@t.hk", password: "password123", displayName: "外人" } });
  strangerToken = r2.json().token;
  const c = await app.inject({
    method: "POST", url: "/v1/calendars",
    headers: { authorization: `Bearer ${token}` },
    payload: { name: "家庭日曆" },
  });
  calendarId = c.json().calendar.id;
});

after(async () => { await app.close(); });

test("開清單 → 加兩個 item → list 顯示 0/2", async () => {
  const r = await app.inject({
    method: "POST", url: `/v1/calendars/${calendarId}/todos`,
    headers: { authorization: `Bearer ${token}` },
    payload: { title: "打邊爐準備" },
  });
  assert.equal(r.statusCode, 201);
  listId = r.json().list.id;

  for (const text of ["訂酒樓", "買沙茶醬"]) {
    const i = await app.inject({
      method: "POST", url: `/v1/todos/${listId}/items`,
      headers: { authorization: `Bearer ${token}` },
      payload: { text },
    });
    assert.equal(i.statusCode, 201);
    if (text === "訂酒樓") itemId = i.json().item.id;
  }

  const list = await app.inject({
    method: "GET", url: `/v1/calendars/${calendarId}/todos`,
    headers: { authorization: `Bearer ${token}` },
  });
  assert.equal(list.json().lists.length, 1);
  assert.equal(list.json().lists[0].total, 2);
  assert.equal(list.json().lists[0].done, 0);
});

test("toggle done → 1/2 → 再 toggle 返 0/2", async () => {
  const on = await app.inject({
    method: "PATCH", url: `/v1/todo-items/${itemId}`,
    headers: { authorization: `Bearer ${token}` },
    payload: { done: true },
  });
  assert.equal(on.json().item.done, true);

  const list = await app.inject({
    method: "GET", url: `/v1/calendars/${calendarId}/todos`,
    headers: { authorization: `Bearer ${token}` },
  });
  assert.equal(list.json().lists[0].done, 1);

  const off = await app.inject({
    method: "PATCH", url: `/v1/todo-items/${itemId}`,
    headers: { authorization: `Bearer ${token}` },
    payload: { done: false },
  });
  assert.equal(off.json().item.done, false);
});

test("非成員 404；冇標題 400", async () => {
  const stranger = await app.inject({
    method: "GET", url: `/v1/calendars/${calendarId}/todos`,
    headers: { authorization: `Bearer ${strangerToken}` },
  });
  assert.equal(stranger.statusCode, 404);

  const noTitle = await app.inject({
    method: "POST", url: `/v1/calendars/${calendarId}/todos`,
    headers: { authorization: `Bearer ${token}` },
    payload: {},
  });
  assert.equal(noTitle.statusCode, 400);
});

test("刪 item + 刪清單", async () => {
  const delItem = await app.inject({
    method: "DELETE", url: `/v1/todo-items/${itemId}`,
    headers: { authorization: `Bearer ${token}` },
  });
  assert.equal(delItem.statusCode, 204);

  const delList = await app.inject({
    method: "DELETE", url: `/v1/todos/${listId}`,
    headers: { authorization: `Bearer ${token}` },
  });
  assert.equal(delList.statusCode, 204);
});
