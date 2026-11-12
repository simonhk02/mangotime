// Task 2.6 — Notices（通知）：其他成員喺我嘅行事曆做嘅動作（唔計自己）
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

function summarize(type: string, payload: Record<string, unknown>): string {
  const event = payload.event as { title?: string } | undefined;
  switch (type) {
    case "calendar.member_joined": return "加入咗你嘅行事曆";
    case "calendar.invite_created": return "開咗邀請連結";
    case "event.created": return `新增咗「${event?.title ?? "活動"}」`;
    case "event.updated": return `改咗「${event?.title ?? "活動"}」`;
    case "event.deleted": return "刪除咗一個活動";
    case "event.comment_created": return "喺活動留咗言";
    case "memo.created": return "新增咗備忘錄";
    case "memo.updated": return "改咗備忘錄";
    case "memo.comment_created": return "喺備忘錄留咗言";
    case "todo.list_created": return "開咗待辦清單";
    case "todo.item_done": return "完成咗一項待辦";
    case "photo.uploaded": return "上傳咗相片";
    case "notice.announce": return String((payload as any).title ?? "公告");
    case "event.rsvp": {
      const st = (payload as any).status;
      return st === "going" ? "話會參加一個活動" : "話唔去一個活動";
    }
    default: return "";
  }
}

export function registerNoticeRoutes(app: FastifyInstance, prisma: PrismaClient) {
  // 我嘅通知：我所有行事曆入面，其他人嘅動作（最新 30 條）
  app.get("/v1/notices", async (req, reply) => {
    const user = await requireUser(prisma, req, reply);
    if (!user) return;
    const memberships = await prisma.calendarMember.findMany({
      where: { userId: user.id },
      select: { calendarId: true },
    });
    const calIds = memberships.map((m) => m.calendarId);
    if (calIds.length === 0) return reply.send({ notices: [] });

    const events = await prisma.outboxEvent.findMany({
      where: { OR: [{ aggregateId: { in: calIds } }, { aggregateId: "global" }] },
      orderBy: { createdAt: "desc" },
      take: 80,
    });
    const actorIds = [...new Set(events.map((e) => {
      try { return (JSON.parse(e.payload) as { actorId?: string }).actorId; } catch { return undefined; }
    }).filter((x): x is string => Boolean(x)))];
    const actors = await prisma.user.findMany({
      where: { id: { in: actorIds } },
      select: { id: true, displayName: true, avatarUrl: true },
    });
    const actorMap = new Map(actors.map((a) => [a.id, a]));

    const notices = [];
    for (const e of events) {
      let payload: Record<string, unknown> = {};
      try { payload = JSON.parse(e.payload) as Record<string, unknown>; } catch { continue; }
      const actorId = payload.actorId as string | undefined;
      if (!actorId || actorId === user.id) continue; // 唔計自己嘅動作
      const text = summarize(e.type, payload);
      if (!text) continue;
      notices.push({
        id: e.id,
        calendarId: e.aggregateId,
        actorName: actorMap.get(actorId)?.displayName ?? "有人",
        text,
        createdAt: e.createdAt,
      });
      if (notices.length >= 30) break;
    }
    return reply.send({ notices });
  });

  // 官方公告（淨係管理員 email 出得）→ outbox global + email 全體
  app.post("/v1/admin/announce", async (req, reply) => {
    const user = await requireUser(prisma, req, reply);
    if (!user) return;
    const adminEmails = (process.env.ADMIN_EMAILS ?? "simonhk02@gmail.com").split(",");
    if (!adminEmails.includes(user.email)) return reply.code(403).send({ error: "admin only" });
    const { title, body } = (req.body ?? {}) as { title?: string; body?: string };
    if (!title?.trim()) return reply.code(400).send({ error: "title required" });
    await prisma.outboxEvent.create({
      data: { type: "notice.announce", aggregateId: "global", payload: JSON.stringify({ title, body: body ?? "", actorId: user.id }) },
    });
    const { broadcastNoticeEmail } = await import("./email.js");
    const sent = await broadcastNoticeEmail(prisma, title.trim(), body ?? "");
    return reply.code(201).send({ ok: true, emailed: sent });
  });
}
