// APNs push tests：device 註冊 + outbox 觸發 dispatchPush（mock sender 收料）
import { test, before, after } from "node:test";
import assert from "node:assert/strict";
import { execSync } from "node:child_process";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const TEST_DB = `/tmp/mangotime-test-push-${process.pid}.db`;
process.env.DATABASE_URL = `file:${TEST_DB}`;
process.env.NODE_ENV = "test";
process.env.WEBHOOK_INTERVAL_MS = "80"; // dispatcher 快轉

const serverDir = path.resolve(__dirname, "..");
execSync("npx prisma db push --skip-generate", { cwd: serverDir, env: { ...process.env }, stdio: "pipe" });

// 假 APNs key（test 唔會真簽成功，但 dispatcher 用 mock sender，JWT 簽名會 fail——所以要真 key 先會行到 sender……
// 做法：APNS_KEY_BASE64 俾個真 EC key（test 自己 generate）
import { generateKeyPair, exportPKCS8 } from "jose";
const kp = await generateKeyPair("ES256", { extractable: true });
process.env.APNS_KEY_BASE64 = Buffer.from(await exportPKCS8(kp.privateKey)).toString("base64");
process.env.APNS_KEY_ID = "TESTKEYID";
process.env.APNS_TEAM_ID = "TESTTEAM";

const { buildApp } = await import("../src/app.js");
const { setPushSender } = await import("../src/push.js");
const { dispatchOnce } = await import("../src/webhooks.js");
const { PrismaClient } = await import("@prisma/client");
const prisma = new PrismaClient();

let app: Awaited<ReturnType<typeof buildApp>>;
let tokenA = "";
let tokenB = "";
let calendarId = "";
const sent: Array<{ deviceToken: string; payload: unknown }> = [];

before(async () => {
  setPushSender(async (_host, _jwt, _topic, deviceToken, payload) => {
    sent.push({ deviceToken, payload });
    return { status: 200 };
  });
  app = await buildApp();
  const ra = await app.inject({ method: "POST", url: "/v1/auth/register", payload: { email: "pa@p.hk", password: "password123", displayName: "阿本" } });
  tokenA = ra.json().token;
  const rb = await app.inject({ method: "POST", url: "/v1/auth/register", payload: { email: "pb@p.hk", password: "password123", displayName: "阿包" } });
  tokenB = rb.json().token;
  const c = await app.inject({
    method: "POST", url: "/v1/calendars",
    headers: { authorization: `Bearer ${tokenA}` },
    payload: { name: "推送曆" },
  });
  calendarId = c.json().calendar.id;
  // 阿包加入（經 invite）
  const inv = await app.inject({
    method: "POST", url: `/v1/calendars/${calendarId}/invites`,
    headers: { authorization: `Bearer ${tokenA}` },
  });
  await app.inject({
    method: "POST", url: `/v1/invites/${inv.json().invite.code}/accept`,
    headers: { authorization: `Bearer ${tokenB}` },
  });
});

after(async () => { await app.close(); });

test("device 註冊 + 重複註冊唔會爆", async () => {
  const r1 = await app.inject({
    method: "POST", url: "/v1/devices",
    headers: { authorization: `Bearer ${tokenB}` },
    payload: { token: "b".repeat(64) },
  });
  assert.equal(r1.statusCode, 201);
  const r2 = await app.inject({
    method: "POST", url: "/v1/devices",
    headers: { authorization: `Bearer ${tokenB}` },
    payload: { token: "b".repeat(64) },
  });
  assert.equal(r2.statusCode, 201);
  const bad = await app.inject({
    method: "POST", url: "/v1/devices",
    headers: { authorization: `Bearer ${tokenB}` },
    payload: { token: "short" },
  });
  assert.equal(bad.statusCode, 400);
});

test("阿本開活動 → 推送去阿包部機（阿本自己唔收）", async () => {
  sent.length = 0;
  await app.inject({
    method: "POST", url: `/v1/calendars/${calendarId}/events`,
    headers: { authorization: `Bearer ${tokenA}` },
    payload: { title: "打邊爐", startsAt: "2026-11-19T19:30:00+08:00" },
  });
  // test 冇起 dispatcher timer（佢喺 index.ts）——直接行一次
  await dispatchOnce(prisma);
  assert.equal(sent.length, 1, `應該派 1 個推送，實際 ${sent.length}`);
  assert.equal(sent[0].deviceToken, "b".repeat(64));
  const aps = (sent[0].payload as { aps: { alert: { title: string; body: string } } }).aps;
  assert.equal(aps.alert.title, "新活動");
  assert.ok(aps.alert.body.includes("打邊爐"));
  assert.ok(aps.alert.body.includes("阿本"));
});
