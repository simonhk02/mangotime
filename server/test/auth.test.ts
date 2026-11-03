// Task 1.1 Auth — full-flow API tests against a throwaway SQLite DB.
import { test, before, after } from "node:test";
import assert from "node:assert/strict";
import { execSync } from "node:child_process";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const TEST_DB = `/tmp/mangotime-test-${process.pid}.db`;
process.env.DATABASE_URL = `file:${TEST_DB}`;
process.env.NODE_ENV = "test";

const serverDir = path.resolve(__dirname, "..");
execSync("npx prisma db push --skip-generate", { cwd: serverDir, env: { ...process.env }, stdio: "pipe" });

const { buildApp } = await import("../src/app.js");
const app = await buildApp();

let token = "";

before(async () => {
  await app.ready();
});
after(async () => {
  await app.close();
});

test("register: creates user and returns token", async () => {
  const res = await app.inject({
    method: "POST",
    url: "/v1/auth/register",
    payload: { email: "Simon@Example.com", password: "supersecret1", displayName: "Simon" },
  });
  assert.equal(res.statusCode, 201);
  const body = res.json();
  assert.equal(body.user.email, "simon@example.com"); // lowercased
  assert.equal(body.user.displayName, "Simon");
  assert.ok(body.token.length >= 32);
  assert.ok(!("passwordHash" in body.user));
  token = body.token;
});

test("register: duplicate email → 409", async () => {
  const res = await app.inject({
    method: "POST",
    url: "/v1/auth/register",
    payload: { email: "simon@example.com", password: "whatever99", displayName: "Dup" },
  });
  assert.equal(res.statusCode, 409);
});

test("register: short password → 400", async () => {
  const res = await app.inject({
    method: "POST",
    url: "/v1/auth/register",
    payload: { email: "a@b.co", password: "short", displayName: "X" },
  });
  assert.equal(res.statusCode, 400);
});

test("login: wrong password → 401", async () => {
  const res = await app.inject({
    method: "POST",
    url: "/v1/auth/login",
    payload: { email: "simon@example.com", password: "wrongpassword" },
  });
  assert.equal(res.statusCode, 401);
});

test("login: success returns fresh token", async () => {
  const res = await app.inject({
    method: "POST",
    url: "/v1/auth/login",
    payload: { email: "simon@example.com", password: "supersecret1" },
  });
  assert.equal(res.statusCode, 200);
  assert.ok(res.json().token);
});

test("GET /v1/me with token → profile; without → 401", async () => {
  const ok = await app.inject({ method: "GET", url: "/v1/me", headers: { authorization: `Bearer ${token}` } });
  assert.equal(ok.statusCode, 200);
  assert.equal(ok.json().user.displayName, "Simon");
  const no = await app.inject({ method: "GET", url: "/v1/me" });
  assert.equal(no.statusCode, 401);
});

test("PATCH /v1/me updates displayName and avatarUrl", async () => {
  const res = await app.inject({
    method: "PATCH",
    url: "/v1/me",
    headers: { authorization: `Bearer ${token}` },
    payload: { displayName: "Simon Lai", avatarUrl: "https://example.com/a.png" },
  });
  assert.equal(res.statusCode, 200);
  assert.equal(res.json().user.displayName, "Simon Lai");
  assert.equal(res.json().user.avatarUrl, "https://example.com/a.png");
});

test("logout invalidates the token", async () => {
  const out = await app.inject({ method: "POST", url: "/v1/auth/logout", headers: { authorization: `Bearer ${token}` } });
  assert.equal(out.statusCode, 204);
  const after = await app.inject({ method: "GET", url: "/v1/me", headers: { authorization: `Bearer ${token}` } });
  assert.equal(after.statusCode, 401);
});
