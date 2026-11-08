// Task 1.2 — Calendar CRUD. Every route is membership-scoped (multi-tenant from day 1).
// Role rules: create = any authed user; rename/cover/delete = creator only.
// Every mutation writes an OutboxEvent (calendar.*) — webhook dispatcher lands in 4.2.
import type { FastifyInstance, FastifyRequest, FastifyReply } from "fastify";
import type { PrismaClient, Calendar } from "@prisma/client";
import { userFromRequest } from "./auth.js";

type Ctx = { prisma: PrismaClient; req: FastifyRequest; reply: FastifyReply };

async function requireUser({ prisma, req, reply }: Ctx) {
  const user = await userFromRequest(prisma, req);
  if (!user) {
    await reply.code(401).send({ error: "unauthorized" });
    return null;
  }
  return user;
}

async function requireMembership(prisma: PrismaClient, calendarId: string, userId: string, reply: FastifyReply) {
  const member = await prisma.calendarMember.findUnique({
    where: { calendarId_userId: { calendarId, userId } },
    include: { calendar: true },
  });
  if (!member) {
    // 404 (not 403) — don't leak existence to non-members
    await reply.code(404).send({ error: "calendar not found" });
    return null;
  }
  return member;
}

function publicCalendar(c: Calendar & { members?: { userId: string; role: string }[] }, myRole?: string) {
  return {
    id: c.id,
    name: c.name,
    coverImageUrl: c.coverImageUrl,
    publicSlug: c.publicSlug,
    creatorId: c.creatorId,
    createdAt: c.createdAt,
    memberCount: c.members?.length,
    myRole,
  };
}

async function emitEvent(prisma: PrismaClient, type: string, aggregateId: string, payload: object) {
  await prisma.outboxEvent.create({
    data: { type, aggregateId, payload: JSON.stringify(payload) },
  });
}

export function registerCalendarRoutes(app: FastifyInstance, prisma: PrismaClient) {
  // Create calendar — creator membership auto-created.
  app.post("/v1/calendars", async (req, reply) => {
    const user = await requireUser({ prisma, req, reply });
    if (!user) return;
    const body = (req.body ?? {}) as { name?: string; coverImageUrl?: string };
    if (!body.name?.trim()) return reply.code(400).send({ error: "name is required" });
    const calendar = await prisma.calendar.create({
      data: {
        name: body.name.trim(),
        coverImageUrl: body.coverImageUrl ?? null,
        creatorId: user.id,
        members: { create: { userId: user.id, role: "creator" } },
      },
      include: { members: true },
    });
    await emitEvent(prisma, "calendar.created", calendar.id, { calendar: publicCalendar(calendar, "creator"), actorId: user.id });
    return reply.code(201).send({ calendar: publicCalendar(calendar, "creator") });
  });

  // List calendars I'm a member of.
  app.get("/v1/calendars", async (req, reply) => {
    const user = await requireUser({ prisma, req, reply });
    if (!user) return;
    const memberships = await prisma.calendarMember.findMany({
      where: { userId: user.id },
      include: { calendar: { include: { members: true } } },
      orderBy: { createdAt: "asc" },
    });
    return {
      calendars: memberships.map((m) => publicCalendar(m.calendar, m.role)),
    };
  });

  // Get one calendar (members only).
  app.get("/v1/calendars/:id", async (req, reply) => {
    const user = await requireUser({ prisma, req, reply });
    if (!user) return;
    const { id } = req.params as { id: string };
    const member = await requireMembership(prisma, id, user.id, reply);
    if (!member) return;
    return { calendar: publicCalendar(member.calendar, member.role) };
  });

  // Rename / change cover (creator only).
  app.patch("/v1/calendars/:id", async (req, reply) => {
    const user = await requireUser({ prisma, req, reply });
    if (!user) return;
    const { id } = req.params as { id: string };
    const member = await requireMembership(prisma, id, user.id, reply);
    if (!member) return;
    if (member.role !== "creator") return reply.code(403).send({ error: "only the creator can edit calendar settings" });
    const body = (req.body ?? {}) as { name?: string; coverImageUrl?: string | null };
    const data: { name?: string; coverImageUrl?: string | null } = {};
    if (body.name !== undefined) {
      if (!body.name.trim()) return reply.code(400).send({ error: "name cannot be empty" });
      data.name = body.name.trim();
    }
    if (body.coverImageUrl !== undefined) data.coverImageUrl = body.coverImageUrl;
    if (Object.keys(data).length === 0) return reply.code(400).send({ error: "nothing to update" });
    const calendar = await prisma.calendar.update({ where: { id }, data, include: { members: true } });
    await emitEvent(prisma, "calendar.updated", id, { calendar: publicCalendar(calendar, "creator"), actorId: user.id });
    return { calendar: publicCalendar(calendar, "creator") };
  });

  // Delete calendar (creator only).
  app.delete("/v1/calendars/:id", async (req, reply) => {
    const user = await requireUser({ prisma, req, reply });
    if (!user) return;
    const { id } = req.params as { id: string };
    const member = await requireMembership(prisma, id, user.id, reply);
    if (!member) return;
    if (member.role !== "creator") return reply.code(403).send({ error: "only the creator can delete the calendar" });
    await prisma.calendar.delete({ where: { id } });
    await emitEvent(prisma, "calendar.deleted", id, { calendarId: id, actorId: user.id });
    return reply.code(204).send();
  });
}
