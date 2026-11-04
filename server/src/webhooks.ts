// Task 4.2 — Webhook 訂閱 + dispatcher（outbox → POST 訂閱 URL，HMAC 簽名）
import type { FastifyInstance, FastifyReply, FastifyRequest } from "fastify";
import type { PrismaClient, User } from "@prisma/client";
import { userFromRequest } from "./auth.js";
import { createHmac, randomBytes, timingSafeEqual } from "node:crypto";

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

export function registerWebhookRoutes(app: FastifyInstance, prisma: PrismaClient) {
  // 訂閱 webhook
  app.post("/v1/calendars/:id/webhooks", async (req, reply) => {
    const user = await requireUser(prisma, req, reply);
    if (!user) return;
    const { id } = req.params as { id: string };
    if (!(await requireMember(prisma, id, user.id))) return reply.code(404).send({ error: "calendar not found" });
    const body = (req.body ?? {}) as { url?: string };
    const u = body.url ?? "";
    const isLocal = u.startsWith("http://127.0.0.1") || u.startsWith("http://localhost");
    if (!u.startsWith("https://") && !isLocal) return reply.code(400).send({ error: "https url required" });
    const wh = await prisma.webhook.create({
      data: { calendarId: id, url: u, secret: randomBytes(16).toString("hex") },
    });
    return reply.code(201).send({ webhook: { id: wh.id, url: wh.url, secret: wh.secret, active: wh.active } });
  });

  // 列出
  app.get("/v1/calendars/:id/webhooks", async (req, reply) => {
    const user = await requireUser(prisma, req, reply);
    if (!user) return;
    const { id } = req.params as { id: string };
    if (!(await requireMember(prisma, id, user.id))) return reply.code(404).send({ error: "calendar not found" });
    const hooks = await prisma.webhook.findMany({ where: { calendarId: id }, orderBy: { createdAt: "asc" } });
    return reply.send({ webhooks: hooks.map((h) => ({ id: h.id, url: h.url, active: h.active, createdAt: h.createdAt })) });
  });

  // 刪
  app.delete("/v1/webhooks/:id", async (req, reply) => {
    const user = await requireUser(prisma, req, reply);
    if (!user) return;
    const { id } = req.params as { id: string };
    const wh = await prisma.webhook.findUnique({ where: { id } });
    if (!wh) return reply.code(404).send({ error: "not found" });
    if (!(await requireMember(prisma, wh.calendarId, user.id))) return reply.code(404).send({ error: "not found" });
    await prisma.webhook.delete({ where: { id } });
    return reply.code(204).send();
  });
}

// ---- Dispatcher：每 INTERVAL_MS 掃未派遞 outbox event → POST 晒有關 webhook ----
const INTERVAL_MS = Number(process.env.WEBHOOK_INTERVAL_MS ?? 10_000);

export function startWebhookDispatcher(prisma: PrismaClient) {
  const timer = setInterval(() => void dispatchOnce(prisma), INTERVAL_MS);
  timer.unref();
  return timer;
}

export async function dispatchOnce(prisma: PrismaClient) {
  const pending = await prisma.outboxEvent.findMany({
    where: { deliveredAt: null },
    orderBy: { createdAt: "asc" },
    take: 50,
  });
  for (const ev of pending) {
    const hooks = await prisma.webhook.findMany({
      where: { calendarId: ev.aggregateId, active: true },
    });
    for (const h of hooks) {
      const body = JSON.stringify({
        id: ev.id,
        type: ev.type,
        calendarId: ev.aggregateId,
        payload: JSON.parse(ev.payload),
        createdAt: ev.createdAt,
      });
      const sig = createHmac("sha256", h.secret).update(body).digest("hex");
      try {
        const res = await fetch(h.url, {
          method: "POST",
          headers: {
            "content-type": "application/json",
            "x-mangotime-signature": `sha256=${sig}`,
            "x-mangotime-event": ev.type,
          },
          body,
          signal: AbortSignal.timeout(10_000),
        });
        if (!res.ok) console.warn(`webhook ${h.id} → ${res.status}`);
      } catch (err) {
        console.warn(`webhook ${h.id} failed:`, err instanceof Error ? err.message : err);
      }
    }
    // 冇訂閱都照標 delivered（唔好積住）
    await prisma.outboxEvent.update({ where: { id: ev.id }, data: { deliveredAt: new Date() } });
  }
}

// 俾 receiver 驗簽用
export function verifySignature(secret: string, body: string, header: string) {
  const expect = `sha256=${createHmac("sha256", secret).update(body).digest("hex")}`;
  const a = Buffer.from(expect);
  const b = Buffer.from(header);
  return a.length === b.length && timingSafeEqual(a, b);
}
