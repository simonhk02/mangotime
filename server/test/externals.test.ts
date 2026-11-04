// Task 5.1 tests：external calendar 訂閱 + ics parse + merge
import { test, before, after } from "node:test";
import assert from "node:assert/strict";
import { execSync } from "node:child_process";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const TEST_DB = `/tmp/mangotime-test-ext-${process.pid}.db`;
process.env.DATABASE_URL = `file:${TEST_DB}`;
process.env.NODE_ENV = "test";

const serverDir = path.resolve(__dirname, "..");
execSync("npx prisma db push --skip-generate", { cwd: serverDir, env: { ...process.env }, stdio: "pipe" });

const { buildApp } = await import("../src/app.js");
const { parseIcs } = await import("../src/externals.js");

let app: Awaited<ReturnType<typeof buildApp>>;
let token = "";
let calendarId = "";

const SAMPLE_ICS = `BEGIN:VCALENDAR
VERSION:2.0
PRODID:-//Test//EN
BEGIN:VEVENT
UID:evt-1
SUMMARY:阿女家長日
DTSTART;VALUE=DATE:20261124
DTEND;VALUE=DATE:20261125
END:VEVENT
BEGIN:VEVENT
UID:evt-2
SUMMARY:每週網球
DTSTART:20261120T080000Z
DTEND:20261120T100000Z
RRULE:FREQ=WEEKLY
END:VEVENT
END:VCALENDAR`;

before(async () => {
  app = await buildApp();
  const r = await app.inject({ method: "POST", url: "/v1/auth/register", payload: { email: "ext@e.hk", password: "password123", displayName: "阿姐" } });
  token = r.json().token;
  const c = await app.inject({
    method: "POST", url: "/v1/calendars",
    headers: { authorization: `Bearer ${token}` },
    payload: { name: "家庭日曆" },
  });
  calendarId = c.json().calendar.id;
});

after(async () => { await app.close(); });

test("parseIcs：全日 + 定時 + 每週重複", () => {
  const events = parseIcs(SAMPLE_ICS);
  assert.equal(events.length, 2);
  assert.equal(events[0].title, "阿女家長日");
  assert.equal(events[0].allDay, true);
  assert.equal(events[1].repeatRule, "weekly");
  assert.equal(events[1].allDay, false);
});

test("訂閱（data: URL）→ 活動攞到 → 取消訂閱", async () => {
  const dataUrl = "data:text/calendar;base64," + Buffer.from(SAMPLE_ICS).toString("base64");
  const sub = await app.inject({
    method: "POST", url: `/v1/calendars/${calendarId}/externals`,
    headers: { authorization: `Bearer ${token}` },
    payload: { url: dataUrl, name: "學校校曆" },
  });
  assert.equal(sub.statusCode, 201);
  const ext = sub.json().external;
  assert.equal(ext.eventCount, 2);

  const list = await app.inject({
    method: "GET", url: `/v1/calendars/${calendarId}/externals`,
    headers: { authorization: `Bearer ${token}` },
  });
  assert.equal(list.json().externals.length, 1);

  const evs = await app.inject({
    method: "GET", url: `/v1/calendars/${calendarId}/externals/events`,
    headers: { authorization: `Bearer ${token}` },
  });
  const titles = evs.json().events.map((e: { title: string }) => e.title);
  assert.ok(titles.includes("阿女家長日"));
  assert.ok(titles.includes("每週網球"));

  const del = await app.inject({
    method: "DELETE", url: `/v1/externals/${ext.id}`,
    headers: { authorization: `Bearer ${token}` },
  });
  assert.equal(del.statusCode, 204);
});

test("壞 URL 400", async () => {
  const bad = await app.inject({
    method: "POST", url: `/v1/calendars/${calendarId}/externals`,
    headers: { authorization: `Bearer ${token}` },
    payload: { url: "notaurl" },
  });
  assert.equal(bad.statusCode, 400);
});
