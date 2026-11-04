// Task 2.1 — Event comments（活動留言）
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

async function emitEvent(prisma: PrismaClient, type: string, aggregateId: string, payload: object) {
  await prisma.outboxEvent.create({ data: { type, aggregateId, payload: JSON.stringify(payload) } });
}

// 活動存在 + 我係行事曆成員先掂得
async function eventForMember(prisma: PrismaClient, eventId: string, userId: string) {
  const event = await prisma.event.findUnique({ where: { id: eventId } });
  if (!event) return null;
  const member = await prisma.calendarMember.findUnique({
    where: { calendarId_userId: { calendarId: event.calendarId, userId } },
  });
  return member ? event : null;
}

function publicComment(c: { id: string; body: string; createdAt: Date; author: { displayName: string; avatarUrl: string | null } }, authorId: string) {
  return {
    id: c.id,
    body: c.body,
    createdAt: c.createdAt,
    authorId,
    authorName: c.author.displayName,
    authorAvatar: c.author.avatarUrl,
  };
}

export function registerCommentRoutes(app: FastifyInstance, prisma: PrismaClient) {
  // 列出留言（時間升序）
  app.get("/v1/events/:id/comments", async (req, reply) => {
    const user = await requireUser(prisma, req, reply);
    if (!user) return;
    const { id } = req.params as { id: string };
    const event = await eventForMember(prisma, id, user.id);
    if (!event) return reply.code(404).send({ error: "event not found" });
    const comments = await prisma.comment.findMany({
      where: { eventId: id },
      include: { author: { select: { displayName: true, avatarUrl: true } } },
      orderBy: { createdAt: "asc" },
    });
    return reply.send({ comments: comments.map((c) => publicComment(c, c.authorId)) });
  });

  // 留言
  app.post("/v1/events/:id/comments", async (req, reply) => {
    const user = await requireUser(prisma, req, reply);
    if (!user) return;
    const { id } = req.params as { id: string };
    const body = (req.body ?? {}) as { body?: string };
    if (!body.body?.trim()) return reply.code(400).send({ error: "body is required" });
    if (body.body.length > 2000) return reply.code(400).send({ error: "body too long" });
    const event = await eventForMember(prisma, id, user.id);
    if (!event) return reply.code(404).send({ error: "event not found" });

    const comment = await prisma.comment.create({
      data: { eventId: id, authorId: user.id, body: body.body.trim() },
      include: { author: { select: { displayName: true, avatarUrl: true } } },
    });
    await emitEvent(prisma, "event.comment_created", event.calendarId, {
      eventId: id, commentId: comment.id, actorId: user.id,
    });
    return reply.code(201).send({ comment: publicComment(comment, user.id) });
  });

  // 刪自己嘅留言
  app.delete("/v1/comments/:id", async (req, reply) => {
    const user = await requireUser(prisma, req, reply);
    if (!user) return;
    const { id } = req.params as { id: string };
    const comment = await prisma.comment.findUnique({ where: { id } });
    if (!comment) return reply.code(404).send({ error: "comment not found" });
    if (comment.authorId !== user.id) return reply.code(403).send({ error: "not your comment" });
    await prisma.comment.delete({ where: { id } });
    return reply.code(204).send();
  });
}
