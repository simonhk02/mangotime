// Task 2.6 tests：notices 只計其他成員嘅動作
import { test, before, after } from "node:test";
import assert from "node:assert/strict";
import { execSync } from "node:child_process";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const TEST_DB = `/tmp/mangotime-test-notice-${process.pid}.db`;
process.env.DATABASE_URL = `file:${TEST_DB}`;
process.env.NODE_ENV = "test";

const serverDir = path.resolve(__dirname, "..");
execSync("npx prisma db push --skip-generate", { cwd: serverDir, env: { ...process.env }, stdio: "pipe" });

const { buildApp } = await import("../src/app.js");
let app: Awaited<ReturnType<typeof buildApp>>;
let ownerToken = "";
let friendToken = "";
let calendarId = "";

before(async () => {
  app = await buildApp();
  const r1 = await app.inject({ method: "POST", url: "/v1/auth/register", payload: { email: "n1@n.hk", password: "password123", displayName: "阿文" } });
  ownerToken = r1.json().token;
  const r2 = await app.inject({ method: "POST", url: "/v1/auth/register", payload: { email: "n2@n.hk", password: "password123", displayName: "老婆" } });
  friendToken = r2.json().token;
  const c = await app.inject({
    method: "POST", url: "/v1/calendars",
    headers: { authorization: `Bearer ${ownerToken}` },
    payload: { name: "家庭日曆" },
  });
  calendarId = c.json().calendar.id;
  // owner 開邀請 → friend 加入 → friend 開活動
  const inv = await app.inject({
    method: "POST", url: `/v1/calendars/${calendarId}/invites`,
    headers: { authorization: `Bearer ${ownerToken}` },
  });
  await app.inject({
    method: "POST", url: `/v1/invites/${inv.json().invite.code}/accept`,
    headers: { authorization: `Bearer ${friendToken}` },
  });
  await app.inject({
    method: "POST", url: `/v1/calendars/${calendarId}/events`,
    headers: { authorization: `Bearer ${friendToken}` },
    payload: { title: "屋企人飯局", startsAt: "2026-11-18T19:00:00+08:00" },
  });
});

after(async () => { await app.close(); });

test("owner 嘅 notices 見到老婆加入 + 開活動；唔見到自己嘅動作", async () => {
  const r = await app.inject({
    method: "GET", url: "/v1/notices",
    headers: { authorization: `Bearer ${ownerToken}` },
  });
  assert.equal(r.statusCode, 200);
  const notices = r.json().notices;
  const texts = notices.map((n: { text: string }) => n.text);
  assert.ok(texts.some((t: string) => t.includes("加入咗")), JSON.stringify(texts));
  assert.ok(texts.some((t: string) => t.includes("屋企人飯局")), JSON.stringify(texts));
  assert.ok(!texts.some((t: string) => t.includes("邀請連結")), "自己開嘅 invite 唔應該出現");
  assert.ok(notices.every((n: { actorName: string }) => n.actorName === "老婆"));
});

test("未登入 401", async () => {
  const r = await app.inject({ method: "GET", url: "/v1/notices" });
  assert.equal(r.statusCode, 401);
});
