// Social auth tests：本地 JWKS server 扮 Apple/Google，jose 真簽名真驗簽
import { test, before, after } from "node:test";
import assert from "node:assert/strict";
import { execSync } from "node:child_process";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { generateKeyPair, SignJWT, exportJWK } from "jose";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const TEST_DB = `/tmp/mangotime-test-social-${process.pid}.db`;
process.env.DATABASE_URL = `file:${TEST_DB}`;
process.env.NODE_ENV = "test";

const serverDir = path.resolve(__dirname, "..");
execSync("npx prisma db push --skip-generate", { cwd: serverDir, env: { ...process.env }, stdio: "pipe" });

// 唔使起 http server（node --test 底下 listen 會 hang）：直接將 JWKS JSON 俾 createLocalJWKSet
const kp = await generateKeyPair("RS256");
const privateKey = kp.privateKey;
const pub = await exportJWK(kp.publicKey);
pub.kid = "testkey"; pub.alg = "RS256"; pub.use = "sig";
process.env.JWKS_JSON_OVERRIDE = JSON.stringify({ keys: [pub] });
process.env.APPLE_CLIENT_ID = "com.mangotime.app";
process.env.GOOGLE_CLIENT_ID = "";

const { buildApp } = await import("../src/app.js");

let app: Awaited<ReturnType<typeof buildApp>>;

before(async () => {
  app = await buildApp();
});

after(async () => { await app.close(); });

async function appleToken(sub: string, email?: string) {
  let jwt = new SignJWT({ ...(email ? { email } : {}) })
    .setProtectedHeader({ alg: "RS256", kid: "testkey" })
    .setIssuer("https://appleid.apple.com")
    .setAudience("com.mangotime.app")
    .setSubject(sub)
    .setIssuedAt()
    .setExpirationTime("5m");
  return jwt.sign(privateKey);
}

async function googleToken(sub: string, email: string, name?: string, aud?: string) {
  let jwt = new SignJWT({ email, ...(name ? { name } : {}) })
    .setProtectedHeader({ alg: "RS256", kid: "testkey" })
    .setIssuer("https://accounts.google.com")
    .setSubject(sub)
    .setIssuedAt()
    .setExpirationTime("5m");
  if (aud) jwt = jwt.setAudience(aud);
  return jwt.sign(privateKey);
}

test("Apple 首次登入開新帳；同一 sub 再登入返同一個 user", async () => {
  const t1 = await appleToken("apple-sub-001", "simon@icloud.com");
  const r1 = await app.inject({ method: "POST", url: "/v1/auth/apple", payload: { idToken: t1, displayName: "Simon" } });
  assert.equal(r1.statusCode, 200);
  const userId = r1.json().user.id;
  assert.equal(r1.json().user.email, "simon@icloud.com");
  assert.ok(r1.json().token);

  const t2 = await appleToken("apple-sub-001"); // Apple 第二次唔再俾 email
  const r2 = await app.inject({ method: "POST", url: "/v1/auth/apple", payload: { idToken: t2 } });
  assert.equal(r2.statusCode, 200);
  assert.equal(r2.json().user.id, userId, "同一 sub 要返同一個 user");
});

test("同 email 嘅 Google 登入 link 去現有帳（唔會開新 user）", async () => {
  // 先用 email+密碼註冊
  const reg = await app.inject({ method: "POST", url: "/v1/auth/register", payload: { email: "link@l.hk", password: "password123", displayName: "阿力" } });
  const existingId = reg.json().user.id;

  const g = await googleToken("google-sub-9", "link@l.hk", "阿力");
  const r = await app.inject({ method: "POST", url: "/v1/auth/google", payload: { idToken: g } });
  assert.equal(r.statusCode, 200);
  assert.equal(r.json().user.id, existingId, "email 對到要 link 返舊帳");

  // 舊密碼仍然用到
  const login = await app.inject({ method: "POST", url: "/v1/auth/login", payload: { email: "link@l.hk", password: "password123" } });
  assert.equal(login.statusCode, 200);
});

test("假 token 401", async () => {
  const bad = await app.inject({ method: "POST", url: "/v1/auth/apple", payload: { idToken: "not.a.jwt" } });
  assert.equal(bad.statusCode, 401);
  const bad2 = await app.inject({ method: "POST", url: "/v1/auth/google", payload: { idToken: "not.a.jwt" } });
  assert.equal(bad2.statusCode, 401);
});

test("Google audience 檢查：aud 啱先過", async () => {
  process.env.GOOGLE_CLIENT_ID = "id-a,id-b";
  const good = await googleToken("gsub-aud", "aud@a.hk", undefined, "id-b");
  const r1 = await app.inject({ method: "POST", url: "/v1/auth/google", payload: { idToken: good } });
  assert.equal(r1.statusCode, 200);

  const wrongAud = await googleToken("gsub-aud2", "aud2@a.hk", undefined, "id-other");
  const r2 = await app.inject({ method: "POST", url: "/v1/auth/google", payload: { idToken: wrongAud } });
  assert.equal(r2.statusCode, 401);
  process.env.GOOGLE_CLIENT_ID = "";
});
