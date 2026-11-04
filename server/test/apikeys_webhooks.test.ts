// Task 4.1 + 4.2 tests：API key auth + webhook 訂閱/派遞（HMAC 簽名）
import { test, before, after } from "node:test";
import assert from "node:assert/strict";
import { execSync } from "node:child_process";
import { createServer, type Server } from "node:http";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const TEST_DB = `/tmp/mangotime-test-wh-${process.pid}.db`;
process.env.DATABASE_URL = `file:${TEST_DB}`;
process.env.NODE_ENV = "test";

const serverDir = path.resolve(__dirname, "..");
execSync("npx prisma db push --skip-generate", { cwd: serverDir, env: { ...process.env }, stdio: "pipe" });

const { buildApp } = await import("../src/app.js");
const { dispatchOnce, verifySignature } = await import("../src/webhooks.js");
const { PrismaClient } = await import("@prisma/client");

let app: Awaited<ReturnType<typeof buildApp>>;
let prisma: InstanceType<typeof PrismaClient>;
let token = "";
let calendarId = "";
let apiKey = "";
let receiver: Server;
let received: { headers: Record<string, string | string[] | undefined>; body: string }[] = [];
let secret = "";

before(async () => {
  app = await buildApp();
  prisma = new PrismaClient();
  const r = await app.inject({ method: "POST", url: "/v1/auth/register", payload: { email: "w@w.hk", password: "password123", displayName: "阿文" } });
  token = r.json().token;
  const c = await app.inject({
    method: "POST", url: "/v1/calendars",
    headers: { authorization: `Bearer ${token}` },
    payload: { name: "家庭日曆" },
  });
  calendarId = c.json().calendar.id;

  // 本地 webhook receiver
  receiver = createServer((req, res) => {
    let body = "";
    req.on("data", (c) => (body += c));
    req.on("end", () => {
      received.push({ headers: req.headers as Record<string, string | string[] | undefined>, body });
      res.writeHead(200).end("ok");
    });
  });
  await new Promise<void>((resolve) => receiver.listen(0, resolve));
});

after(async () => {
  await app.close();
  receiver.close();
  await prisma.$disconnect();
});

test("開 API key → 用 key 攞 /v1/me 通（唔使 session）", async () => {
  const r = await app.inject({
    method: "POST", url: "/v1/apikeys",
    headers: { authorization: `Bearer ${token}` },
    payload: { name: "uat-agent" },
  });
  assert.equal(r.statusCode, 201);
  apiKey = r.json().key;
  assert.ok(apiKey.startsWith("mt_"));
  assert.ok(r.json().apiKey.prefix.length < apiKey.length, "prefix 唔應該係全文");

  const me = await app.inject({
    method: "GET", url: "/v1/me",
    headers: { authorization: `Bearer ${apiKey}` },
  });
  assert.equal(me.statusCode, 200);
  assert.equal(me.json().user.email, "w@w.hk");

  // list 唔洩全文
  const list = await app.inject({
    method: "GET", url: "/v1/apikeys",
    headers: { authorization: `Bearer ${token}` },
  });
  assert.equal(list.json().apiKeys[0].name, "uat-agent");
  assert.equal(list.json().apiKeys[0].key, undefined);
});

test("訂閱 webhook → 郁嘢 → receiver 收到 + 簽名啱", async () => {
  const port = (receiver.address() as { port: number }).port;
  const sub = await app.inject({
    method: "POST", url: `/v1/calendars/${calendarId}/webhooks`,
    headers: { authorization: `Bearer ${apiKey}` },
    payload: { url: `http://127.0.0.1:${port}/hook` },
  });
  assert.equal(sub.statusCode, 201); // localhost 例外俾 http
  secret = sub.json().webhook.secret;

  // 郁嘢：開個活動
  await app.inject({
    method: "POST", url: `/v1/calendars/${calendarId}/events`,
    headers: { authorization: `Bearer ${apiKey}` },
    payload: { title: "Webhook 測試", startsAt: "2026-11-20T19:00:00+08:00" },
  });

  // 手動派遞（正式由 dispatcher 做）
  await dispatchOnce(prisma);

  assert.ok(received.length >= 1, "receiver 應該收到");
  const last = received[received.length - 1];
  const payload = JSON.parse(last.body);
  assert.equal(payload.type, "event.created");
  assert.equal(payload.payload.event.title, "Webhook 測試");
  assert.equal(typeof last.headers["x-mangotime-signature"], "string");
  assert.ok(verifySignature(secret, last.body, last.headers["x-mangotime-signature"] as string), "HMAC 簽名要啱");
});

test("廢除 key → 用返就 401", async () => {
  const list = await app.inject({
    method: "GET", url: "/v1/apikeys",
    headers: { authorization: `Bearer ${token}` },
  });
  const id = list.json().apiKeys[0].id;
  const del = await app.inject({
    method: "DELETE", url: `/v1/apikeys/${id}`,
    headers: { authorization: `Bearer ${token}` },
  });
  assert.equal(del.statusCode, 204);

  const me = await app.inject({
    method: "GET", url: "/v1/me",
    headers: { authorization: `Bearer ${apiKey}` },
  });
  assert.equal(me.statusCode, 401);
});
