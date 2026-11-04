// Task 5.1 — External calendar sync：訂閱 .ics URL（Google Calendar 秘密連結、Apple 發佈日曆等）
// 做法：fetch ics → parse VEVENT → cache 喺 DB（15 分鐘 TTL）→ list events 時 merge 埋（唯讀）
import type { FastifyInstance, FastifyReply, FastifyRequest } from "fastify";
import type { PrismaClient, User } from "@prisma/client";
import { userFromRequest } from "./auth.js";

async function requireUser(prisma: PrismaClient, req: FastifyRequest, reply: FastifyReply): Promise<User | null> {
  const user = await userFromRequest(prisma, req);
  if (!user) {
    await reply.code(401).send({ error: "unauthorized" });
    return null;
  }
  return user;
}

async function requireMember(prisma: PrismaClient, calendarId: string, userId: string) {
  return prisma.calendarMember.findUnique({
    where: { calendarId_userId: { calendarId, userId } },
  });
}

// ---- 迷你 iCal parser（夠用版：VEVENT SUMMARY/DTSTART/DTEND/RRULE 簡化）----
export type IcsEvent = {
  uid: string;
  title: string;
  startsAt: Date;
  endsAt: Date | null;
  allDay: boolean;
  repeatRule: string; // none|daily|weekly|monthly|yearly
};

function unfold(text: string): string[] {
  // RFC 5545: 長行用 \r\n + 空格/TAB 續行
  return text.replace(/\r\n[ \t]/g, "").replace(/\n[ \t]/g, "").split(/\r?\n/);
}

function parseIcsDate(v: string, params: string): { date: Date; allDay: boolean } | null {
  // 格式：20261119T190000 / 20261119T190000Z / 20261119 (VALUE=DATE)
  const isDateOnly = params.includes("VALUE=DATE") || /^\d{8}$/.test(v);
  const m = v.match(/^(\d{4})(\d{2})(\d{2})(?:T(\d{2})(\d{2})(\d{2})(Z?))?/);
  if (!m) return null;
  const [, y, mo, d, h = "0", mi = "0", se = "0", z] = m;
  if (isDateOnly) {
    return { date: new Date(Number(y), Number(mo) - 1, Number(d)), allDay: true };
  }
  if (z === "Z") {
    return { date: new Date(Date.UTC(Number(y), Number(mo) - 1, Number(d), Number(h), Number(mi), Number(se))), allDay: false };
  }
  // 冇 Z = floating local time——當香港時間（常見情況）
  return { date: new Date(Date.UTC(Number(y), Number(mo) - 1, Number(d), Number(h) - 8, Number(mi), Number(se))), allDay: false };
}

export function parseIcs(text: string): IcsEvent[] {
  const lines = unfold(text);
  const events: IcsEvent[] = [];
  let cur: Partial<IcsEvent> | null = null;
  for (const line of lines) {
    if (line === "BEGIN:VEVENT") { cur = {}; continue; }
    if (line === "END:VEVENT") {
      if (cur?.title && cur.startsAt) {
        events.push({
          uid: cur.uid ?? Math.random().toString(36).slice(2),
          title: cur.title,
          startsAt: cur.startsAt,
          endsAt: cur.endsAt ?? null,
          allDay: cur.allDay ?? false,
          repeatRule: cur.repeatRule ?? "none",
        });
      }
      cur = null;
      continue;
    }
    if (!cur) continue;
    const colon = line.indexOf(":");
    if (colon < 0) continue;
    const left = line.slice(0, colon);
    const value = line.slice(colon + 1);
    const [prop, params = ""] = left.split(";");
    const v = value.replace(/\\,/g, ",").replace(/\\n/g, "\n").replace(/\\;/g, ";");
    switch (prop) {
      case "UID": cur.uid = v; break;
      case "SUMMARY": cur.title = v; break;
      case "DTSTART": {
        const p = parseIcsDate(v, params);
        if (p) { cur.startsAt = p.date; cur.allDay = p.allDay; }
        break;
      }
      case "DTEND": {
        const p = parseIcsDate(v, params);
        if (p) cur.endsAt = p.date;
        break;
      }
      case "RRULE": {
        const freq = v.match(/FREQ=(DAILY|WEEKLY|MONTHLY|YEARLY)/i);
        if (freq) cur.repeatRule = freq[1].toLowerCase();
        break;
      }
    }
  }
  return events;
}

const CACHE_TTL_MS = 15 * 60 * 1000;

async function fetchExternal(prisma: PrismaClient, ext: { id: string; url: string }) {
  try {
    const res = await fetch(ext.url, { signal: AbortSignal.timeout(15000) });
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    const text = await res.text();
    const events = parseIcs(text);
    await prisma.externalCalendar.update({
      where: { id: ext.id },
      data: { cachedEvents: JSON.stringify(events), lastFetchedAt: new Date(), lastError: null },
    });
    return events;
  } catch (err) {
    await prisma.externalCalendar.update({
      where: { id: ext.id },
      data: { lastError: String(err), lastFetchedAt: new Date() },
    });
    return null;
  }
}

export function registerExternalRoutes(app: FastifyInstance, prisma: PrismaClient) {
  // 訂閱
  app.post("/v1/calendars/:id/externals", async (req, reply) => {
    const user = await requireUser(prisma, req, reply);
    if (!user) return;
    const { id } = req.params as { id: string };
    if (!(await requireMember(prisma, id, user.id))) return reply.code(404).send({ error: "calendar not found" });
    const { url, name } = (req.body ?? {}) as { url?: string; name?: string };
    // test 環境俾 data: URL（本機 node --test listen() 會 hang，唔可以起 http server）
    const isTest = process.env.NODE_ENV === "test";
    if (!url || !(/^https?:\/\//.test(url) || (isTest && url.startsWith("data:")))) {
      return reply.code(400).send({ error: "valid url required" });
    }
    const ext = await prisma.externalCalendar.create({
      data: { calendarId: id, url, name: name ?? new URL(url).hostname },
    });
    // 立即 fetch 一次
    const events = await fetchExternal(prisma, ext);
    return reply.code(201).send({
      external: { id: ext.id, url: ext.url, name: ext.name, eventCount: events?.length ?? 0, lastError: events ? null : "fetch failed" },
    });
  });

  // 列出訂閱
  app.get("/v1/calendars/:id/externals", async (req, reply) => {
    const user = await requireUser(prisma, req, reply);
    if (!user) return;
    const { id } = req.params as { id: string };
    if (!(await requireMember(prisma, id, user.id))) return reply.code(404).send({ error: "calendar not found" });
    const exts = await prisma.externalCalendar.findMany({ where: { calendarId: id } });
    return reply.send({
      externals: exts.map((e) => ({
        id: e.id, url: e.url, name: e.name,
        lastFetchedAt: e.lastFetchedAt, lastError: e.lastError,
      })),
    });
  });

  // 取消訂閱
  app.delete("/v1/externals/:extId", async (req, reply) => {
    const user = await requireUser(prisma, req, reply);
    if (!user) return;
    const { extId } = req.params as { extId: string };
    const ext = await prisma.externalCalendar.findUnique({ where: { id: extId } });
    if (!ext) return reply.code(404).send({ error: "not found" });
    if (!(await requireMember(prisma, ext.calendarId, user.id))) return reply.code(404).send({ error: "not found" });
    await prisma.externalCalendar.delete({ where: { id: extId } });
    return reply.code(204).send();
  });

  // 攞外部活動（cache 過期就重 fetch）
  app.get("/v1/calendars/:id/externals/events", async (req, reply) => {
    const user = await requireUser(prisma, req, reply);
    if (!user) return;
    const { id } = req.params as { id: string };
    if (!(await requireMember(prisma, id, user.id))) return reply.code(404).send({ error: "calendar not found" });
    const exts = await prisma.externalCalendar.findMany({ where: { calendarId: id } });
    const out: Array<IcsEvent & { sourceName: string; externalId: string }> = [];
    for (const ext of exts) {
      let events: IcsEvent[] = [];
      const stale = !ext.lastFetchedAt || Date.now() - ext.lastFetchedAt.getTime() > CACHE_TTL_MS;
      if (stale) {
        events = (await fetchExternal(prisma, ext)) ?? [];
      } else {
        events = JSON.parse(ext.cachedEvents ?? "[]");
      }
      for (const e of events) out.push({ ...e, sourceName: ext.name, externalId: ext.id });
    }
    return reply.send({ events: out });
  });
}
