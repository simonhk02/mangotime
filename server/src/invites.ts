// Task 1.3 — Members & invite：邀請連結開/攞/接受，成員列表/移除
import type { FastifyInstance, FastifyReply, FastifyRequest } from "fastify";
import { randomBytes } from "node:crypto";
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

function inviteCode() {
  return randomBytes(8).toString("base64url").toUpperCase(); // e.g. 9X3KQ2AB-C1
}

async function requireMember(prisma: PrismaClient, calendarId: string, userId: string) {
  return prisma.calendarMember.findUnique({
    where: { calendarId_userId: { calendarId, userId } },
  });
}

async function emitEvent(prisma: PrismaClient, type: string, aggregateId: string, payload: object) {
  await prisma.outboxEvent.create({
    data: { type, aggregateId, payload: JSON.stringify(payload) },
  });
}

export function registerInviteRoutes(app: FastifyInstance, prisma: PrismaClient) {
  // 開/攞行事曆嘅邀請連結（成員先有；已有有效連結就回同一條）
  app.post("/v1/calendars/:id/invites", async (req, reply) => {
    const user = await requireUser(prisma, req, reply);
    if (!user) return;
    const { id } = req.params as { id: string };
    const member = await requireMember(prisma, id, user.id);
    if (!member) return reply.code(404).send({ error: "calendar not found" });

    const existing = await prisma.invite.findFirst({ where: { calendarId: id, revokedAt: null } });
    if (existing) return reply.send({ invite: { code: existing.code, createdAt: existing.createdAt } });

    const invite = await prisma.invite.create({
      data: { calendarId: id, code: inviteCode(), creatorId: user.id },
    });
    await emitEvent(prisma, "calendar.invite_created", id, { code: invite.code, actorId: user.id });
    return reply.code(201).send({ invite: { code: invite.code, createdAt: invite.createdAt } });
  });

  // 預覽邀請（唔使登入）
  app.get("/v1/invites/:code", async (req, reply) => {
    const { code } = req.params as { code: string };
    const invite = await prisma.invite.findUnique({
      where: { code },
      include: { calendar: { include: { members: true } } },
    });
    if (!invite || invite.revokedAt) return reply.code(404).send({ error: "invite not found" });
    return reply.send({
      invite: {
        code: invite.code,
        calendarName: invite.calendar.name,
        memberCount: invite.calendar.members.length,
      },
    });
  });

  // 接受邀請（要登入）→ 成為成員
  app.post("/v1/invites/:code/accept", async (req, reply) => {
    const user = await requireUser(prisma, req, reply);
    if (!user) return;
    const { code } = req.params as { code: string };
    const invite = await prisma.invite.findUnique({ where: { code } });
    if (!invite || invite.revokedAt) return reply.code(404).send({ error: "invite not found" });

    const already = await prisma.calendarMember.findUnique({
      where: { calendarId_userId: { calendarId: invite.calendarId, userId: user.id } },
    });
    if (already) return reply.send({ calendarId: invite.calendarId, alreadyMember: true });

    await prisma.calendarMember.create({
      data: { calendarId: invite.calendarId, userId: user.id, role: "member" },
    });
    await emitEvent(prisma, "calendar.member_joined", invite.calendarId, { code, actorId: user.id });
    return reply.send({ calendarId: invite.calendarId, alreadyMember: false });
  });

  // 成員列表
  app.get("/v1/calendars/:id/members", async (req, reply) => {
    const user = await requireUser(prisma, req, reply);
    if (!user) return;
    const { id } = req.params as { id: string };
    const member = await requireMember(prisma, id, user.id);
    if (!member) return reply.code(404).send({ error: "calendar not found" });
    const members = await prisma.calendarMember.findMany({
      where: { calendarId: id },
      include: { user: { select: { id: true, displayName: true, email: true, avatarUrl: true } } },
      orderBy: { createdAt: "asc" },
    });
    return reply.send({
      members: members.map((m) => ({
        userId: m.userId,
        role: m.role,
        displayName: m.user.displayName,
        email: m.user.email,
        avatarUrl: m.user.avatarUrl,
      })),
    });
  });

  // 移除成員（creator 專用；唔可以移除自己）
  app.delete("/v1/calendars/:id/members/:userId", async (req, reply) => {
    const user = await requireUser(prisma, req, reply);
    if (!user) return;
    const { id, userId } = req.params as { id: string; userId: string };
    const me = await requireMember(prisma, id, user.id);
    if (!me) return reply.code(404).send({ error: "calendar not found" });
    if (me.role !== "creator") return reply.code(403).send({ error: "creator only" });
    if (userId === user.id) return reply.code(400).send({ error: "cannot remove yourself" });
    await prisma.calendarMember.deleteMany({ where: { calendarId: id, userId } });
    await emitEvent(prisma, "calendar.member_removed", id, { userId, actorId: user.id });
    return reply.code(204).send();
  });
}
