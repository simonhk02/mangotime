// Task 5.2 — Public Calendar：開/關公開唯讀 link + 冇帳號都睇到嘅公開讀取
import type { FastifyInstance, FastifyReply, FastifyRequest } from "fastify";
import type { PrismaClient, User } from "@prisma/client";
import { userFromRequest } from "./auth.js";
import { randomBytes } from "node:crypto";

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

export function registerPublicRoutes(app: FastifyInstance, prisma: PrismaClient) {
  // 開公開 link（成員先有；已有就返同一個）
  app.post("/v1/calendars/:id/public", async (req, reply) => {
    const user = await requireUser(prisma, req, reply);
    if (!user) return;
    const { id } = req.params as { id: string };
    if (!(await requireMember(prisma, id, user.id))) return reply.code(404).send({ error: "calendar not found" });
    const cal = await prisma.calendar.findUnique({ where: { id } });
    if (!cal) return reply.code(404).send({ error: "calendar not found" });
    if (cal.publicSlug) return reply.send({ publicSlug: cal.publicSlug });
    const slug = randomBytes(10).toString("base64url");
    await prisma.calendar.update({ where: { id }, data: { publicSlug: slug } });
    await prisma.outboxEvent.create({
      data: { type: "calendar.public_enabled", aggregateId: id, payload: JSON.stringify({ actorId: user.id }) },
    });
    return reply.code(201).send({ publicSlug: slug });
  });

  // 關公開 link
  app.delete("/v1/calendars/:id/public", async (req, reply) => {
    const user = await requireUser(prisma, req, reply);
    if (!user) return;
    const { id } = req.params as { id: string };
    if (!(await requireMember(prisma, id, user.id))) return reply.code(404).send({ error: "calendar not found" });
    await prisma.calendar.update({ where: { id }, data: { publicSlug: null } });
    return reply.code(204).send();
  });

  // 公開讀取（唔使 auth）：基本資料
  app.get("/v1/public/:slug", async (req, reply) => {
    const { slug } = req.params as { slug: string };
    const cal = await prisma.calendar.findUnique({ where: { publicSlug: slug } });
    if (!cal) return reply.code(404).send({ error: "not found" });
    return reply.send({ calendar: { name: cal.name } });
  });

  // 公開讀取：活動（sanitize：唔返 creatorId/成員資料）
  app.get("/v1/public/:slug/events", async (req, reply) => {
    const { slug } = req.params as { slug: string };
    const cal = await prisma.calendar.findUnique({ where: { publicSlug: slug } });
    if (!cal) return reply.code(404).send({ error: "not found" });
    const { from, to } = req.query as { from?: string; to?: string };
    const events = await prisma.event.findMany({
      where: {
        calendarId: cal.id,
        ...(from ? { startsAt: { gte: new Date(from) } } : {}),
        ...(to ? { startsAt: { lte: new Date(to) } } : {}),
      },
      orderBy: { startsAt: "asc" },
      take: 200,
    });
    return reply.send({
      events: events.map((e) => ({
        id: e.id,
        title: e.title,
        startsAt: e.startsAt,
        endsAt: e.endsAt,
        allDay: e.allDay,
        repeatRule: e.repeatRule,
        labelColor: e.labelColor,
        location: e.location,
      })),
    });
  });
}
