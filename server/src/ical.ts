// Task 5.5 — iCal import/export：匯出 .ics（分享/搬屋用）+ 匯入 .ics（由其他日曆搬入）
import type { FastifyInstance, FastifyReply, FastifyRequest } from "fastify";
import type { PrismaClient, User } from "@prisma/client";
import { userFromRequest } from "./auth.js";
import { parseIcs } from "./externals.js";

async function requireUser(prisma: PrismaClient, req: FastifyRequest, reply: FastifyReply): Promise<User | null> {
  const user = await userFromRequest(prisma, req);
  if (!user) {
    await reply.code(401).send({ error: "unauthorized" });
    return null;
  }
  return user;
}

function icsEscape(s: string): string {
  return s.replace(/\\/g, "\\\\").replace(/;/g, "\\;").replace(/,/g, "\\,").replace(/\n/g, "\\n");
}

function icsDate(d: Date, allDay: boolean): string {
  if (allDay) {
    return `${d.getUTCFullYear()}${String(d.getUTCMonth() + 1).padStart(2, "0")}${String(d.getUTCDate()).padStart(2, "0")}`;
  }
  return d.toISOString().replace(/[-:]/g, "").replace(/\.\d{3}/, "");
}

export function registerIcalRoutes(app: FastifyInstance, prisma: PrismaClient) {
  // 匯出：成個行事曆嘅活動 → .ics 檔
  app.get("/v1/calendars/:id/export.ics", async (req, reply) => {
    const user = await requireUser(prisma, req, reply);
    if (!user) return;
    const { id } = req.params as { id: string };
    const member = await prisma.calendarMember.findUnique({
      where: { calendarId_userId: { calendarId: id, userId: user.id } },
    });
    if (!member) return reply.code(404).send({ error: "calendar not found" });
    const cal = await prisma.calendar.findUnique({ where: { id } });
    const events = await prisma.event.findMany({ where: { calendarId: id }, orderBy: { startsAt: "asc" } });

    const lines = [
      "BEGIN:VCALENDAR",
      "VERSION:2.0",
      "PRODID:-//MangoTime//ZH-HK",
      `X-WR-CALNAME:${icsEscape(cal?.name ?? "MangoTime")}`,
    ];
    for (const e of events) {
      lines.push("BEGIN:VEVENT");
      lines.push(`UID:${e.id}@mangotime`);
      lines.push(`SUMMARY:${icsEscape(e.title)}`);
      if (e.allDay) {
        lines.push(`DTSTART;VALUE=DATE:${icsDate(e.startsAt, true)}`);
        if (e.endsAt) lines.push(`DTEND;VALUE=DATE:${icsDate(e.endsAt, true)}`);
      } else {
        lines.push(`DTSTART:${icsDate(e.startsAt, false)}`);
        if (e.endsAt) lines.push(`DTEND:${icsDate(e.endsAt, false)}`);
      }
      if (e.repeatRule && e.repeatRule !== "none") lines.push(`RRULE:FREQ=${e.repeatRule.toUpperCase()}`);
      if (e.location) lines.push(`LOCATION:${icsEscape(e.location)}`);
      if (e.note) lines.push(`DESCRIPTION:${icsEscape(e.note)}`);
      lines.push("END:VEVENT");
    }
    lines.push("END:VCALENDAR");
    reply.header("content-type", "text/calendar; charset=utf-8");
    reply.header("content-disposition", `attachment; filename="mangotime-${id}.ics"`);
    return reply.send(lines.join("\r\n"));
  });

  // 匯入：貼 .ics 內容 → 逐個開活動
  app.post("/v1/calendars/:id/import", async (req, reply) => {
    const user = await requireUser(prisma, req, reply);
    if (!user) return;
    const { id } = req.params as { id: string };
    const member = await prisma.calendarMember.findUnique({
      where: { calendarId_userId: { calendarId: id, userId: user.id } },
    });
    if (!member) return reply.code(404).send({ error: "calendar not found" });
    const body = (req.body ?? {}) as { ics?: string };
    if (!body.ics || !body.ics.includes("BEGIN:VCALENDAR")) return reply.code(400).send({ error: "ics content required" });
    const events = parseIcs(body.ics);
    if (events.length === 0) return reply.code(400).send({ error: "no events found in ics" });
    let created = 0;
    for (const ev of events.slice(0, 500)) {
      await prisma.event.create({
        data: {
          calendarId: id,
          creatorId: user.id,
          title: ev.title,
          startsAt: ev.startsAt,
          endsAt: ev.endsAt,
          allDay: ev.allDay,
          repeatRule: ev.repeatRule,
        },
      });
      created++;
    }
    await prisma.outboxEvent.create({
      data: { type: "calendar.ics_imported", aggregateId: id, payload: JSON.stringify({ actorId: user.id, count: created }) },
    });
    return reply.code(201).send({ imported: created });
  });
}
