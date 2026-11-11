// Premium 訂閱驗證
import { test, before, after } from "node:test";
import assert from "node:assert/strict";
import { execSync } from "node:child_process";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const TEST_DB = `/tmp/mangotime-test-prem-${process.pid}.db`;
process.env.DATABASE_URL = `file:${TEST_DB}`;
process.env.NODE_ENV = "test";

const serverDir = path.resolve(__dirname, "..");
execSync("npx prisma db push --skip-generate", { cwd: serverDir, env: { ...process.env }, stdio: "pipe" });

const { buildApp } = await import("../src/app.js");
const { setTransactionFetcher } = await import("../src/premium.js");
const app = await buildApp();

before(async () => { await app.ready(); });
after(async () => { await app.close(); setTransactionFetcher(null); });

async function signup(email: string): Promise<string> {
  const res = await app.inject({ method: "POST", url: "/v1/auth/register", payload: { email, password: "password123", displayName: "P" } });
  return res.json().token;
}

test("verify：正 transaction → premiumUntil 落 DB；refunded 400", async () => {
  const t = await signup("prem1@test.com");
  const future = Date.now() + 30 * 24 * 3600 * 1000;
  setTransactionFetcher(async () => ({ transactionId: "tx1", productId: "com.mangotime.premium.monthly", expiresDate: future, bundleId: "com.mangotime.app" }));
  const v = await app.inject({ method: "POST", url: "/v1/premium/verify", headers: { authorization: `Bearer ${t}` }, payload: { transactionId: "tx1" } });
  assert.equal(v.statusCode, 200);
  const st = await app.inject({ method: "GET", url: "/v1/premium", headers: { authorization: `Bearer ${t}` } });
  assert.equal(st.json().premium, true);
  // me 都露
  const me = await app.inject({ method: "GET", url: "/v1/me", headers: { authorization: `Bearer ${t}` } });
  assert.ok(me.json().user.premiumUntil);

  // refunded
  const t2 = await signup("prem2@test.com");
  setTransactionFetcher(async () => ({ transactionId: "tx2", productId: "x", revocationDate: Date.now(), bundleId: "com.mangotime.app" }));
  const v2 = await app.inject({ method: "POST", url: "/v1/premium/verify", headers: { authorization: `Bearer ${t2}` }, payload: { transactionId: "tx2" } });
  assert.equal(v2.statusCode, 400);

  // apple 掛咗
  const t3 = await signup("prem3@test.com");
  setTransactionFetcher(async () => null);
  const v3 = await app.inject({ method: "POST", url: "/v1/premium/verify", headers: { authorization: `Bearer ${t3}` }, payload: { transactionId: "tx3" } });
  assert.equal(v3.statusCode, 502);
});
