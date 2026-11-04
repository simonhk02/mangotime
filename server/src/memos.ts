// Task 2.2 — Memo（備忘錄）CRUD + 留言
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

async function memoForMember(prisma: PrismaClient, memoId: string, userId: string) {
  const memo = await prisma.memo.findUnique({ where: { id: memoId } });
  if (!memo) return null;
  const member = await requireMember(prisma, memo.calendarId, userId);
  return member ? memo : null;
}

async function emitEvent(prisma: PrismaClient, type: string, aggregateId: string, payload: object) {
  await prisma.outboxEvent.create({ data: { type, aggregateId, payload: JSON.stringify(payload) } });
}

function publicMemo(m: { id: string; calendarId: string; title: string; body: string; labelColor: string | null; creatorId: string; updatedAt: Date }, commentCount?: number) {
  return {
    id: m.id,
    calendarId: m.calendarId,
    title: m.title,
    body: m.body,
    labelColor: m.labelColor,
    creatorId: m.creatorId,
    updatedAt: m.updatedAt,
    ...(commentCount !== undefined ? { commentCount } : {}),
  };
}

const MEMO_COLORS = new Set(["bright-orange", "emerald", "blue", "red", "amber", "purple"]);

export function registerMemoRoutes(app: FastifyInstance, prisma: PrismaClient) {
  // 列出行事曆嘅備忘錄（最新更新排先）
  app.get("/v1/calendars/:id/memos", async (req, reply) => {
    const user = await requireUser(prisma, req, reply);
    if (!user) return;
    const { id } = req.params as { id: string };
    if (!(await requireMember(prisma, id, user.id))) return reply.code(404).send({ error: "calendar not found" });
    const memos = await prisma.memo.findMany({
      where: { calendarId: id },
      orderBy: { updatedAt: "desc" },
      include: { _count: { select: { comments: true } } },
    });
    return reply.send({ memos: memos.map((m) => publicMemo(m, m._count.comments)) });
  });

  // 開備忘錄
  app.post("/v1/calendars/:id/memos", async (req, reply) => {
    const user = await requireUser(prisma, req, reply);
    if (!user) return;
    const { id } = req.params as { id: string };
    if (!(await requireMember(prisma, id, user.id))) return reply.code(404).send({ error: "calendar not found" });
    const body = (req.body ?? {}) as { title?: string; body?: string; labelColor?: string };
    if (!body.title?.trim()) return reply.code(400).send({ error: "title is required" });
    if (body.labelColor && !MEMO_COLORS.has(body.labelColor)) return reply.code(400).send({ error: "bad labelColor" });
    const memo = await prisma.memo.create({
      data: {
        calendarId: id,
        title: body.title.trim(),
        body: body.body?.trim() ?? "",
        labelColor: body.labelColor ?? "bright-orange",
        creatorId: user.id,
      },
    });
    await emitEvent(prisma, "memo.created", id, { memoId: memo.id, actorId: user.id });
    return reply.code(201).send({ memo: publicMemo(memo, 0) });
  });

  // 改備忘錄
  app.patch("/v1/memos/:id", async (req, reply) => {
    const user = await requireUser(prisma, req, reply);
    if (!user) return;
    const { id } = req.params as { id: string };
    const memo = await memoForMember(prisma, id, user.id);
    if (!memo) return reply.code(404).send({ error: "memo not found" });
    const body = (req.body ?? {}) as { title?: string; body?: string; labelColor?: string };
    if (body.labelColor && !MEMO_COLORS.has(body.labelColor)) return reply.code(400).send({ error: "bad labelColor" });
    const updated = await prisma.memo.update({
      where: { id },
      data: {
        ...(body.title?.trim() ? { title: body.title.trim() } : {}),
        ...(body.body !== undefined ? { body: body.body } : {}),
        ...(body.labelColor ? { labelColor: body.labelColor } : {}),
      },
    });
    await emitEvent(prisma, "memo.updated", memo.calendarId, { memoId: id, actorId: user.id });
    return reply.send({ memo: publicMemo(updated) });
  });

  // 刪備忘錄
  app.delete("/v1/memos/:id", async (req, reply) => {
    const user = await requireUser(prisma, req, reply);
    if (!user) return;
    const { id } = req.params as { id: string };
    const memo = await memoForMember(prisma, id, user.id);
    if (!memo) return reply.code(404).send({ error: "memo not found" });
    await prisma.memo.delete({ where: { id } });
    await emitEvent(prisma, "memo.deleted", memo.calendarId, { memoId: id, actorId: user.id });
    return reply.code(204).send();
  });

  // 備忘錄留言（同 event comment 一樣玩法）
  app.get("/v1/memos/:id/comments", async (req, reply) => {
    const user = await requireUser(prisma, req, reply);
    if (!user) return;
    const { id } = req.params as { id: string };
    if (!(await memoForMember(prisma, id, user.id))) return reply.code(404).send({ error: "memo not found" });
    const comments = await prisma.memoComment.findMany({
      where: { memoId: id },
      include: { author: { select: { displayName: true, avatarUrl: true } } },
      orderBy: { createdAt: "asc" },
    });
    return reply.send({
      comments: comments.map((c) => ({
        id: c.id, body: c.body, createdAt: c.createdAt,
        authorId: c.authorId, authorName: c.author.displayName, authorAvatar: c.author.avatarUrl,
      })),
    });
  });

  app.post("/v1/memos/:id/comments", async (req, reply) => {
    const user = await requireUser(prisma, req, reply);
    if (!user) return;
    const { id } = req.params as { id: string };
    const memo = await memoForMember(prisma, id, user.id);
    if (!memo) return reply.code(404).send({ error: "memo not found" });
    const body = (req.body ?? {}) as { body?: string };
    if (!body.body?.trim()) return reply.code(400).send({ error: "body is required" });
    const comment = await prisma.memoComment.create({
      data: { memoId: id, authorId: user.id, body: body.body.trim() },
      include: { author: { select: { displayName: true, avatarUrl: true } } },
    });
    await emitEvent(prisma, "memo.comment_created", memo.calendarId, { memoId: id, commentId: comment.id, actorId: user.id });
    return reply.code(201).send({
      comment: {
        id: comment.id, body: comment.body, createdAt: comment.createdAt,
        authorId: user.id, authorName: comment.author.displayName, authorAvatar: comment.author.avatarUrl,
      },
    });
  });
}
