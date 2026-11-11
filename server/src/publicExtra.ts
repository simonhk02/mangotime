// 公開平台：目錄（store）+ 按讚 + 抄入自己曆
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

export function registerPublicExtraRoutes(app: FastifyInstance, prisma: PrismaClient) {
  // 公開曆目錄：GET /v1/public-directory（免 auth 都睇得，但帶 auth 會標我 like 咗邊啲）
  app.get("/v1/public-directory", async (req, reply) => {
    const cals = await prisma.calendar.findMany({
      where: { publicSlug: { not: null } },
      include: { _count: { select: { events: true, members: true } } },
      orderBy: { createdAt: "desc" },
      take: 100,
    });
    const user = await userFromRequest(prisma, req);
    const myLikes = user
      ? new Set((await prisma.publicLike.findMany({ where: { userId: user.id } })).map((l) => l.publicSlug))
      : new Set<string>();
    const likeCounts = await prisma.publicLike.groupBy({ by: ["publicSlug"], _count: true });
    const countMap = new Map(likeCounts.map((l) => [l.publicSlug, l._count]));
    return reply.send({
      calendars: cals.map((c) => ({
        slug: c.publicSlug,
        name: c.name,
        coverImageUrl: c.coverImageUrl,
        eventCount: c._count.events,
        memberCount: c._count.members,
        likeCount: countMap.get(c.publicSlug!) ?? 0,
        liked: myLikes.has(c.publicSlug!),
      })),
    });
  });

  // 按讚：POST /v1/public/:slug/like（要登入）
  app.post("/v1/public/:slug/like", async (req, reply) => {
    const user = await requireUser(prisma, req, reply);
    if (!user) return;
    const { slug } = req.params as { slug: string };
    const cal = await prisma.calendar.findUnique({ where: { publicSlug: slug } });
    if (!cal) return reply.code(404).send({ error: "not found" });
    await prisma.publicLike.upsert({
      where: { publicSlug_userId: { publicSlug: slug, userId: user.id } },
      update: {},
      create: { publicSlug: slug, userId: user.id },
    });
    return reply.send({ ok: true });
  });

  app.delete("/v1/public/:slug/like", async (req, reply) => {
    const user = await requireUser(prisma, req, reply);
    if (!user) return;
    const { slug } = req.params as { slug: string };
    await prisma.publicLike.deleteMany({ where: { publicSlug: slug, userId: user.id } });
    return reply.send({ ok: true });
  });

  // 我按讚嘅公開活動：GET /v1/me/likes
  app.get("/v1/me/likes", async (req, reply) => {
    const user = await requireUser(prisma, req, reply);
    if (!user) return;
    const likes = await prisma.publicLike.findMany({ where: { userId: user.id }, orderBy: { createdAt: "desc" } });
    const cals = await prisma.calendar.findMany({ where: { publicSlug: { in: likes.map((l) => l.publicSlug) } } });
    const nameMap = new Map(cals.map((c) => [c.publicSlug, c.name]));
    return reply.send({ likes: likes.map((l) => ({ slug: l.publicSlug, name: nameMap.get(l.publicSlug) ?? l.publicSlug, likedAt: l.createdAt })) });
  });

  // 一撳抄入自己曆：POST /v1/public/:slug/copy → 開個新曆抄晒啲活動
  app.post("/v1/public/:slug/copy", async (req, reply) => {
    const user = await requireUser(prisma, req, reply);
    if (!user) return;
    const { slug } = req.params as { slug: string };
    const src = await prisma.calendar.findUnique({ where: { publicSlug: slug }, include: { events: true } });
    if (!src) return reply.code(404).send({ error: "not found" });
    const copy = await prisma.calendar.create({
      data: {
        name: `${src.name}（副本）`,
        coverImageUrl: src.coverImageUrl,
        creatorId: user.id,
        members: { create: { userId: user.id, role: "creator" } },
      },
    });
    if (src.events.length > 0) {
      await prisma.event.createMany({
        data: src.events.map((e) => ({
          calendarId: copy.id,
          title: e.title,
          allDay: e.allDay,
          startsAt: e.startsAt,
          endsAt: e.endsAt,
          repeatRule: e.repeatRule,
          remindMin: e.remindMin,
          labelColor: e.labelColor,
          note: e.note,
          url: e.url,
          location: e.location,
          creatorId: user.id,
        })),
      });
    }
    return reply.code(201).send({ calendarId: copy.id, eventCount: src.events.length });
  });
}
