// RSVP — 參加/取消參加活動（TimeTree「參加行程」對應）
import type { FastifyInstance, FastifyReply, FastifyRequest } from "fastify";
import type { PrismaClient, User } from "@prisma/client";
import { userFromRequest } from "./auth.js";
import { emitEvent } from "./events.js";

async function requireUser(prisma: PrismaClient, req: FastifyRequest, reply: FastifyReply): Promise<User | null> {
  const user = await userFromRequest(prisma, req);
  if (!user) {
    await reply.code(401).send({ error: "unauthorized" });
    return null;
  }
  return user;
}

export function registerRsvpRoutes(app: FastifyInstance, prisma: PrismaClient) {
  // POST /v1/events/:id/rsvp — { status: "going" | "declined" }
  app.post("/v1/events/:id/rsvp", async (req, reply) => {
    const user = await requireUser(prisma, req, reply);
    if (!user) return;
    const { id } = req.params as { id: string };
    const { status } = (req.body ?? {}) as { status?: string };
    if (status !== "going" && status !== "declined") {
      return reply.code(400).send({ error: "status must be going|declined" });
    }
    const ev = await prisma.event.findUnique({ where: { id } });
    if (!ev) return reply.code(404).send({ error: "event not found" });
    const member = await prisma.calendarMember.findUnique({
      where: { calendarId_userId: { calendarId: ev.calendarId, userId: user.id } },
    });
    if (!member) return reply.code(403).send({ error: "not a member" });
    const rsvp = await prisma.eventParticipant.upsert({
      where: { eventId_userId: { eventId: id, userId: user.id } },
      update: { status },
      create: { eventId: id, userId: user.id, status },
    });
    await emitEvent(prisma, "event.rsvp", ev.calendarId, {
      eventId: id, userId: user.id, status, displayName: user.displayName, title: ev.title,
    });
    return { ok: true, status: rsvp.status };
  });

  // DELETE /v1/events/:id/rsvp — 收回表態
  app.delete("/v1/events/:id/rsvp", async (req, reply) => {
    const user = await requireUser(prisma, req, reply);
    if (!user) return;
    const { id } = req.params as { id: string };
    await prisma.eventParticipant.deleteMany({ where: { eventId: id, userId: user.id } });
    return { ok: true };
  });
}
