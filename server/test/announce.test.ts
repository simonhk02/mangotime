// 官方公告 + 服務電郵
import { test, before, after } from "node:test";
import assert from "node:assert/strict";
import { execSync } from "node:child_process";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
process.env.DATABASE_URL = `file:/tmp/mangotime-test-ann-${process.pid}.db`;
process.env.NODE_ENV = "test";
execSync("npx prisma db push --skip-generate", { cwd: path.resolve(__dirname, ".."), env: { ...process.env }, stdio: "pipe" });

const { buildApp } = await import("../src/app.js");
const { setEmailSender } = await import("../src/email.js");
const app = await buildApp();

let sent: { to: string; subject: string }[] = [];

before(async () => {
  await app.ready();
  sent = [];
  setEmailSender(async (to, subject) => { sent.push({ to, subject }); return true; });
});
after(async () => { await app.close(); setEmailSender(null); });

test("公告：admin 出公告 → 全部人通知見到 + email 全體；非 admin 403", async () => {
  const admin = await app.inject({ method: "POST", url: "/v1/auth/register", payload: { email: "simonhk02@gmail.com", password: "password123", displayName: "Admin" } });
  const user = await app.inject({ method: "POST", url: "/v1/auth/register", payload: { email: "user@test.com", password: "password123", displayName: "U" } });
  // 非 admin 403
  const nope = await app.inject({ method: "POST", url: "/v1/admin/announce", headers: { authorization: `Bearer ${user.json().token}` }, payload: { title: "X" } });
  assert.equal(nope.statusCode, 403);
  // admin 出公告
  const ok = await app.inject({ method: "POST", url: "/v1/admin/announce", headers: { authorization: `Bearer ${admin.json().token}` }, payload: { title: "MangoTime v1.1 上線", body: "新功能：公開曆商店" } });
  assert.equal(ok.statusCode, 201);
  assert.equal(ok.json().emailed, 2);
  assert.equal(sent.length, 2);
  // 用戶需要至少一個行事曆先有通知——開一個
  await app.inject({ method: "POST", url: "/v1/calendars", headers: { authorization: `Bearer ${user.json().token}` }, payload: { name: "U" } });
  const list = await app.inject({ method: "GET", url: "/v1/notices", headers: { authorization: `Bearer ${user.json().token}` } });
  assert.ok(list.json().notices.some((n: any) => n.text.includes("v1.1")), "公告應該喺通知出現");
});
