// 公開平台：目錄 + 按讚 + 抄入自己曆
import { test, before, after } from "node:test";
import assert from "node:assert/strict";
import { execSync } from "node:child_process";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const TEST_DB = `/tmp/mangotime-test-pub-${process.pid}.db`;
process.env.DATABASE_URL = `file:${TEST_DB}`;
process.env.NODE_ENV = "test";

const serverDir = path.resolve(__dirname, "..");
execSync("npx prisma db push --skip-generate", { cwd: serverDir, env: { ...process.env }, stdio: "pipe" });

const { buildApp } = await import("../src/app.js");
const app = await buildApp();

before(async () => { await app.ready(); });
after(async () => { await app.close(); });

async function signup(email: string, name: string): Promise<string> {
  const res = await app.inject({ method: "POST", url: "/v1/auth/register", payload: { email, password: "password123", displayName: name } });
  assert.equal(res.statusCode, 201);
  return res.json().token;
}

test("公開平台全鏈：開公開連結 → 目錄見到 → 按讚 → my likes → 抄入自己曆", async () => {
  const t1 = await signup("pub1@test.com", "版主");
  const t2 = await signup("pub2@test.com", "路人");
  const cal = await app.inject({ method: "POST", url: "/v1/calendars", headers: { authorization: `Bearer ${t1}` }, payload: { name: "香港行山團" } });
  const calId = cal.json().calendar.id;
  await app.inject({ method: "POST", url: `/v1/calendars/${calId}/events`, headers: { authorization: `Bearer ${t1}` }, payload: { title: "龍脊行山", startsAt: "2026-11-22T09:00:00+08:00" } });
  // 開公開
  const pub = await app.inject({ method: "POST", url: `/v1/calendars/${calId}/public`, headers: { authorization: `Bearer ${t1}` } });
  assert.equal(pub.statusCode, 201);
  const slug = pub.json().publicSlug ?? pub.json().slug;

  // 目錄（路人睇）
  const dir = await app.inject({ method: "GET", url: "/v1/public-directory", headers: { authorization: `Bearer ${t2}` } });
  assert.equal(dir.statusCode, 200);
  const entry = dir.json().calendars.find((c: any) => c.slug === slug);
  assert.ok(entry, "目錄應該見到");
  assert.equal(entry.eventCount, 1);
  assert.equal(entry.liked, false);

  // 按讚
  const like = await app.inject({ method: "POST", url: `/v1/public/${slug}/like`, headers: { authorization: `Bearer ${t2}` } });
  assert.equal(like.statusCode, 200);
  const dir2 = await app.inject({ method: "GET", url: "/v1/public-directory", headers: { authorization: `Bearer ${t2}` } });
  const entry2 = dir2.json().calendars.find((c: any) => c.slug === slug);
  assert.equal(entry2.likeCount, 1);
  assert.equal(entry2.liked, true);

  // my likes
  const likes = await app.inject({ method: "GET", url: "/v1/me/likes", headers: { authorization: `Bearer ${t2}` } });
  assert.equal(likes.json().likes.length, 1);
  assert.equal(likes.json().likes[0].name, "香港行山團");

  // 抄入自己曆
  const copy = await app.inject({ method: "POST", url: `/v1/public/${slug}/copy`, headers: { authorization: `Bearer ${t2}` } });
  assert.equal(copy.statusCode, 201);
  assert.equal(copy.json().eventCount, 1);
  const myCals = await app.inject({ method: "GET", url: "/v1/calendars", headers: { authorization: `Bearer ${t2}` } });
  assert.ok(myCals.json().calendars.some((c: any) => c.name === "香港行山團（副本）"));
  // 副本真係有活動
  const evs = await app.inject({ method: "GET", url: `/v1/calendars/${copy.json().calendarId}/events?from=2026-11-01T00:00:00Z&to=2026-11-30T23:59:59Z`, headers: { authorization: `Bearer ${t2}` } });
  assert.equal(evs.json().events[0].title, "龍脊行山");

  // 收回讚
  await app.inject({ method: "DELETE", url: `/v1/public/${slug}/like`, headers: { authorization: `Bearer ${t2}` } });
  const dir3 = await app.inject({ method: "GET", url: "/v1/public-directory", headers: { authorization: `Bearer ${t2}` } });
  assert.equal(dir3.json().calendars.find((c: any) => c.slug === slug).likeCount, 0);
});

test("管理者：stats + noindex（目錄踢走）+ 批次登錄", async () => {
  const t1 = await signup("adm1@test.com", "Admin");
  const cal = await app.inject({ method: "POST", url: "/v1/calendars", headers: { authorization: `Bearer ${t1}` }, payload: { name: "Admin 曆" } });
  const calId = cal.json().calendar.id;
  const pub = await app.inject({ method: "POST", url: `/v1/calendars/${calId}/public`, headers: { authorization: `Bearer ${t1}` } });
  const slug = pub.json().publicSlug ?? pub.json().slug;

  // 批次登錄 3 個活動
  const bulk = await app.inject({ method: "POST", url: `/v1/calendars/${calId}/events/bulk`, headers: { authorization: `Bearer ${t1}` }, payload: { events: [
    { title: "A", startsAt: "2026-11-20T10:00:00Z" },
    { title: "B", startsAt: "2026-11-21T10:00:00Z", allDay: true, location: "屋企" },
    { title: "C", startsAt: "2026-11-22T10:00:00Z" },
  ] } });
  assert.equal(bulk.statusCode, 201);
  assert.equal(bulk.json().created, 3);
  // 超 100 要 400
  const tooMany = await app.inject({ method: "POST", url: `/v1/calendars/${calId}/events/bulk`, headers: { authorization: `Bearer ${t1}` }, payload: { events: Array(101).fill({ title: "x", startsAt: "2026-11-20T10:00:00Z" }) } });
  assert.equal(tooMany.statusCode, 400);

  // stats
  const st = await app.inject({ method: "GET", url: `/v1/calendars/${calId}/public/stats`, headers: { authorization: `Bearer ${t1}` } });
  assert.equal(st.json().eventCount, 3);
  assert.equal(st.json().noindex, false);

  // noindex 開 → 目錄冇咗
  const ni = await app.inject({ method: "PATCH", url: `/v1/calendars/${calId}/public/noindex`, headers: { authorization: `Bearer ${t1}` }, payload: { noindex: true } });
  assert.equal(ni.statusCode, 200);
  const dir = await app.inject({ method: "GET", url: "/v1/public-directory" });
  assert.ok(!dir.json().calendars.some((c: any) => c.slug === slug), "noindex 曆唔應該喺目錄出現");
});
