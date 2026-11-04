// Task 2.5 — Activity feed（最新動態）：讀 OutboxEvent → 人話 feed
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

function summarize(type: string, payload: Record<string, unknown>): { icon: string; text: string } {
  const event = payload.event as { title?: string } | undefined;
  switch (type) {
    case "calendar.created": return { icon: "📅", text: "建立咗行事曆" };
    case "calendar.renamed": return { icon: "📅", text: "改咗行事曆名" };
    case "calendar.member_joined": return { icon: "👥", text: "加入咗行事曆" };
    case "calendar.member_removed": return { icon: "👥", text: "移除咗一位成員" };
    case "calendar.invite_created": return { icon: "🔗", text: "開咗邀請連結" };
    case "event.created": return { icon: "🗓", text: `新增咗「${event?.title ?? "活動"}」` };
    case "event.updated": return { icon: "🗓", text: `改咗「${event?.title ?? "活動"}」` };
    case "event.deleted": return { icon: "🗑", text: "刪除咗一個活動" };
    case "event.comment_created": return { icon: "💬", text: "喺活動留咗言" };
    case "memo.created": return { icon: "📝", text: "新增咗備忘錄" };
    case "memo.updated": return { icon: "📝", text: "改咗備忘錄" };
    case "memo.deleted": return { icon: "🗑", text: "刪除咗備忘錄" };
    case "memo.comment_created": return { icon: "💬", text: "喺備忘錄留咗言" };
    case "todo.list_created": return { icon: "✅", text: "開咗待辦清單" };
    case "todo.list_deleted": return { icon: "🗑", text: "刪除咗待辦清單" };
    case "todo.item_created": return { icon: "✅", text: "加咗一項待辦" };
    case "todo.item_done": return { icon: "☑️", text: "完成咗一項待辦" };
    case "todo.item_undone": return { icon: "◻️", text: "重開咗一項待辦" };
    case "photo.uploaded": return { icon: "🖼", text: "上傳咗相片" };
    default: return { icon: "•", text: type };
  }
}

export function registerActivityRoutes(app: FastifyInstance, prisma: PrismaClient) {
  // 最新動態（outbox 最新 50 條，連 actor 名）
  app.get("/v1/calendars/:id/activity", async (req, reply) => {
    const user = await requireUser(prisma, req, reply);
    if (!user) return;
    const { id } = req.params as { id: string };
    const member = await prisma.calendarMember.findUnique({
      where: { calendarId_userId: { calendarId: id, userId: user.id } },
    });
    if (!member) return reply.code(404).send({ error: "calendar not found" });

    const events = await prisma.outboxEvent.findMany({
      where: { aggregateId: id },
      orderBy: { createdAt: "desc" },
      take: 50,
    });
    const actorIds = [...new Set(events.map((e) => {
      try { return (JSON.parse(e.payload) as { actorId?: string }).actorId; } catch { return undefined; }
    }).filter((x): x is string => Boolean(x)))];
    const actors = await prisma.user.findMany({
      where: { id: { in: actorIds } },
      select: { id: true, displayName: true, avatarUrl: true },
    });
    const actorMap = new Map(actors.map((a) => [a.id, a]));

    return reply.send({
      items: events.map((e) => {
        let payload: Record<string, unknown> = {};
        try { payload = JSON.parse(e.payload) as Record<string, unknown>; } catch { /* ignore */ }
        const actorId = payload.actorId as string | undefined;
        const actor = actorId ? actorMap.get(actorId) : undefined;
        const s = summarize(e.type, payload);
        return {
          id: e.id,
          type: e.type,
          icon: s.icon,
          text: s.text,
          actorId: actorId ?? null,
          actorName: actor?.displayName ?? "有人",
          actorAvatar: actor?.avatarUrl ?? null,
          createdAt: e.createdAt,
        };
      }),
    });
  });
}
