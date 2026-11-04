// Task 5.3 tests：scan endpoint——override global fetch 扮 vision API
import { test, before, after } from "node:test";
import assert from "node:assert/strict";
import { execSync } from "node:child_process";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const TEST_DB = `/tmp/mangotime-test-scan-${process.pid}.db`;
process.env.DATABASE_URL = `file:${TEST_DB}`;
process.env.NODE_ENV = "test";
process.env.SCAN_API_KEY = "test-scan-key";

const serverDir = path.resolve(__dirname, "..");
execSync("npx prisma db push --skip-generate", { cwd: serverDir, env: { ...process.env }, stdio: "pipe" });

const { buildApp } = await import("../src/app.js");
const { validateScanned } = await import("../src/scan.js");

let app: Awaited<ReturnType<typeof buildApp>>;
let token = "";
let calendarId = "";
const realFetch = globalThis.fetch;

const PNG = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==";

before(async () => {
  app = await buildApp();
  const r = await app.inject({ method: "POST", url: "/v1/auth/register", payload: { email: "scan@s.hk", password: "password123", displayName: "阿雪" } });
  token = r.json().token;
  const c = await app.inject({
    method: "POST", url: "/v1/calendars",
    headers: { authorization: `Bearer ${token}` },
    payload: { name: "掃描曆" },
  });
  calendarId = c.json().calendar.id;
});

after(async () => { globalThis.fetch = realFetch; await app.close(); });

function mockLlm(content: string) {
  globalThis.fetch = (async () => new Response(JSON.stringify({
    choices: [{ message: { content } }],
  }), { status: 200, headers: { "content-type": "application/json" } })) as typeof fetch;
}

test("validateScanned：壞資料過濾", () => {
  assert.deepEqual(validateScanned("junk"), []);
  assert.deepEqual(validateScanned([{ title: "冇日期" }]), []);
  assert.equal(validateScanned([{ title: "打邊爐", date: "2026-11-19", time: "19:30", location: "屋企", note: null }])[0].title, "打邊爐");
});

test("scan：LLM 答 fence 包住嘅 JSON 都 parse 到", async () => {
  mockLlm("```json\n[{\"title\":\"家長日\",\"date\":\"2026-11-24\",\"time\":\"14:00\",\"location\":\"學校\",\"note\":null}]\n```");
  const r = await app.inject({
    method: "POST", url: `/v1/calendars/${calendarId}/scan`,
    headers: { authorization: `Bearer ${token}` },
    payload: { data: PNG, mimeType: "image/png" },
  });
  assert.equal(r.statusCode, 200);
  const events = r.json().events;
  assert.equal(events.length, 1);
  assert.equal(events[0].title, "家長日");
  assert.equal(events[0].time, "14:00");
});

test("scan：LLM 答唔到 → 空陣列；冇相 → 400", async () => {
  mockLlm("[]");
  const r = await app.inject({
    method: "POST", url: `/v1/calendars/${calendarId}/scan`,
    headers: { authorization: `Bearer ${token}` },
    payload: { data: PNG, mimeType: "image/png" },
  });
  assert.deepEqual(r.json().events, []);

  const empty = await app.inject({
    method: "POST", url: `/v1/calendars/${calendarId}/scan`,
    headers: { authorization: `Bearer ${token}` },
    payload: {},
  });
  assert.equal(empty.statusCode, 400);
});
