// Task 1.4 — Event CRUD, membership-scoped via parent calendar.
import type { FastifyInstance, FastifyRequest, FastifyReply } from "fastify";
import type { PrismaClient, Event } from "@prisma/client";
import { userFromRequest } from "./auth.js";

async function requireUser(prisma: PrismaClient, req: FastifyRequest, reply: FastifyReply) {
  const user = await userFromRequest(prisma, req);
  if (!user) {
    await reply.code(401).send({ error: "unauthorized" });
    return null;
  }
  return user;
}

async function requireCalendarMember(prisma: PrismaClient, calendarId: string, userId: string, reply: FastifyReply) {
  const member = await prisma.calendarMember.findUnique({
    where: { calendarId_userId: { calendarId, userId } },
  });
  if (!member) {
    await reply.code(404).send({ error: "calendar not found" });
    return null;
  }
  return member;
}

const REPEAT_RULES = new Set(["none", "daily", "weekly", "monthly", "yearly"]);

type ParticipantRow = { userId: string; status: string; user?: { displayName: string | null } };

export function publicEvent(e: Event & { participants?: ParticipantRow[] }) {
  const base: Record<string, unknown> = {
    id: e.id, calendarId: e.calendarId, title: e.title, allDay: e.allDay,
    startsAt: e.startsAt, endsAt: e.endsAt, repeatRule: e.repeatRule, remindMin: e.remindMin,
    labelColor: e.labelColor, note: e.note, url: e.url, location: e.location,
    creatorId: e.creatorId, createdAt: e.createdAt, updatedAt: e.updatedAt,
  };
  if (e.participants) {
    base.participants = e.participants.map((p) => ({
      userId: p.userId, status: p.status, displayName: p.user?.displayName ?? null,
    }));
    base.goingCount = e.participants.filter((p) => p.status === "going").length;
  }
  return base;
}

const PARTICIPANT_INCLUDE = { participants: { include: { user: { select: { displayName: true } } } } };

type EventInput = {
  title?: string; allDay?: boolean; startsAt?: string; endsAt?: string | null;
  repeatRule?: string; remindMin?: number | null; labelColor?: string | null;
  note?: string | null; url?: string | null; location?: string | null;
};

function parseEventInput(body: EventInput, reply: FastifyReply): { data?: Record<string, unknown>; err?: string } {
  const data: Record<string, unknown> = {};
  if (body.title !== undefined) {
    if (!body.title.trim()) return { err: "title cannot be empty" };
    data.title = body.title.trim();
  }
  if (body.allDay !== undefined) data.allDay = Boolean(body.allDay);
  if (body.startsAt !== undefined) {
    const d = new Date(body.startsAt);
    if (isNaN(d.getTime())) return { err: "startsAt must be an ISO datetime" };
    data.startsAt = d;
  }
  if (body.endsAt !== undefined) {
    if (body.endsAt === null) data.endsAt = null;
    else {
      const d = new Date(body.endsAt);
      if (isNaN(d.getTime())) return { err: "endsAt must be an ISO datetime" };
      data.endsAt = d;
    }
  }
  if (body.repeatRule !== undefined) {
    if (!REPEAT_RULES.has(body.repeatRule)) return { err: `repeatRule must be one of ${[...REPEAT_RULES].join(", ")}` };
    data.repeatRule = body.repeatRule;
  }
  if (body.remindMin !== undefined) data.remindMin = body.remindMin;
  if (body.labelColor !== undefined) data.labelColor = body.labelColor;
  if (body.note !== undefined) data.note = body.note;
  if (body.url !== undefined) data.url = body.url;
  if (body.location !== undefined) data.location = body.location;
  return { data };
}

export async function emitEvent(prisma: PrismaClient, type: string, aggregateId: string, payload: object) {
  await prisma.outboxEvent.create({ data: { type, aggregateId, payload: JSON.stringify(payload) } });
}

export function registerEventRoutes(app: FastifyInstance, prisma: PrismaClient) {
  // Create event in a calendar.
  app.post("/v1/calendars/:id/events", async (req, reply) => {
    const user = await requireUser(prisma, req, reply);
    if (!user) return;
    const { id: calendarId } = req.params as { id: string };
    if (!(await requireCalendarMember(prisma, calendarId, user.id, reply))) return;
    const body = (req.body ?? {}) as EventInput;
    if (!body.title?.trim()) return reply.code(400).send({ error: "title is required" });
    if (!body.startsAt) return reply.code(400).send({ error: "startsAt is required" });
    const { data, err } = parseEventInput(body, reply);
    if (err) return reply.code(400).send({ error: err });
    if (!data) return reply.code(400).send({ error: "nothing to create" });
    if (data.endsAt && data.startsAt && (data.endsAt as Date) < (data.startsAt as Date)) {
      return reply.code(400).send({ error: "endsAt must be after startsAt" });
    }
    const event = await prisma.event.create({
      data: { ...(data as object), calendarId, creatorId: user.id } as never,
    });
    await emitEvent(prisma, "event.created", event.calendarId, { event: publicEvent(event), actorId: user.id });
    return reply.code(201).send({ event: publicEvent(event) });
  });

  // List events in a calendar, optional range filter: ?from=&to= (ISO).
  app.get("/v1/calendars/:id/events", async (req, reply) => {
    const user = await requireUser(prisma, req, reply);
    if (!user) return;
    const { id: calendarId } = req.params as { id: string };
    if (!(await requireCalendarMember(prisma, calendarId, user.id, reply))) return;
    const { from, to } = req.query as { from?: string; to?: string };
    const where: { calendarId: string; startsAt?: { gte?: Date; lte?: Date } } = { calendarId };
    if (from) {
      const d = new Date(from);
      if (isNaN(d.getTime())) return reply.code(400).send({ error: "from must be ISO datetime" });
      where.startsAt = { ...where.startsAt, gte: d };
    }
    if (to) {
      const d = new Date(to);
      if (isNaN(d.getTime())) return reply.code(400).send({ error: "to must be ISO datetime" });
      where.startsAt = { ...where.startsAt, lte: d };
    }
    const events = await prisma.event.findMany({ where, include: PARTICIPANT_INCLUDE, orderBy: { startsAt: "asc" } });
    return { events: events.map(publicEvent) };
  });

  // Update event (any member can edit — TimeTree behaviour).
  app.patch("/v1/events/:id", async (req, reply) => {
    const user = await requireUser(prisma, req, reply);
    if (!user) return;
    const { id } = req.params as { id: string };
    const existing = await prisma.event.findUnique({ where: { id } });
    if (!existing) return reply.code(404).send({ error: "event not found" });
    if (!(await requireCalendarMember(prisma, existing.calendarId, user.id, reply))) return;
    const { data, err } = parseEventInput((req.body ?? {}) as EventInput, reply);
    if (err) return reply.code(400).send({ error: err });
    if (!data || Object.keys(data).length === 0) return reply.code(400).send({ error: "nothing to update" });
    const startsAt = (data.startsAt as Date) ?? existing.startsAt;
    const endsAt = ("endsAt" in data ? (data.endsAt as Date | null) : existing.endsAt) ?? null;
    if (endsAt && endsAt < startsAt) return reply.code(400).send({ error: "endsAt must be after startsAt" });
    const event = await prisma.event.update({ where: { id }, data });
    await emitEvent(prisma, "event.updated", existing.calendarId, { event: publicEvent(event), actorId: user.id });
    return { event: publicEvent(event) };
  });

  // Search events by title/location/note (case-insensitive contains)
  app.get("/v1/calendars/:id/events/search", async (req, reply) => {
    const user = await requireUser(prisma, req, reply);
    if (!user) return;
    const { id } = req.params as { id: string };
    if (!(await requireCalendarMember(prisma, id, user.id, reply))) return;
    const { q } = req.query as { q?: string };
    if (!q?.trim()) return reply.code(400).send({ error: "q is required" });
    const kw = q.trim();
    const events = await prisma.event.findMany({
      where: {
        calendarId: id,
        OR: [
          { title: { contains: kw } },
          { location: { contains: kw } },
          { note: { contains: kw } },
        ],
      },
      include: PARTICIPANT_INCLUDE,
      orderBy: { startsAt: "asc" },
      take: 50,
    });
    return reply.send({ events: events.map(publicEvent) });
  });

  // Delete event (creator of the event OR calendar creator).
  app.delete("/v1/events/:id", async (req, reply) => {
    const user = await requireUser(prisma, req, reply);
    if (!user) return;
    const { id } = req.params as { id: string };
    const existing = await prisma.event.findUnique({ where: { id } });
    if (!existing) return reply.code(404).send({ error: "event not found" });
    const member = await requireCalendarMember(prisma, existing.calendarId, user.id, reply);
    if (!member) return;
    const calendar = await prisma.calendar.findUnique({ where: { id: existing.calendarId } });
    if (existing.creatorId !== user.id && calendar?.creatorId !== user.id) {
      return reply.code(403).send({ error: "only the event creator or calendar creator can delete" });
    }
    await prisma.event.delete({ where: { id } });
    await emitEvent(prisma, "event.deleted", existing.calendarId, { eventId: id, actorId: user.id });
    return reply.code(204).send();
  });
}
