// Task 4.1 — API keys（agent 用長期 key）：開/列/刪。auth 接兩種：session token 或 mt_ API key
import type { FastifyInstance, FastifyReply, FastifyRequest } from "fastify";
import type { PrismaClient, User } from "@prisma/client";
import { userFromRequest } from "./auth.js";
import { createHash, randomBytes } from "node:crypto";

async function requireUser(prisma: PrismaClient, req: FastifyRequest, reply: FastifyReply): Promise<User | null> {
  const user = await userFromRequest(prisma, req);
  if (!user) {
    await reply.code(401).send({ error: "unauthorized" });
    return null;
  }
  return user;
}

export function hashApiKey(key: string) {
  return createHash("sha256").update(key).digest("hex");
}

export function registerApiKeyRoutes(app: FastifyInstance, prisma: PrismaClient) {
  // 開 key（只喺開嗰刻返一次全文）
  app.post("/v1/apikeys", async (req, reply) => {
    const user = await requireUser(prisma, req, reply);
    if (!user) return;
    const body = (req.body ?? {}) as { name?: string };
    const name = body.name?.trim() || "agent";
    const key = `mt_${randomBytes(24).toString("base64url")}`;
    const rec = await prisma.apiKey.create({
      data: { userId: user.id, name, keyHash: hashApiKey(key), prefix: key.slice(0, 11) },
    });
    return reply.code(201).send({
      apiKey: { id: rec.id, name: rec.name, prefix: rec.prefix, createdAt: rec.createdAt },
      key, // ⚠️ 只此一次
    });
  });

  // 列出（淨係 prefix，冇真 key）
  app.get("/v1/apikeys", async (req, reply) => {
    const user = await requireUser(prisma, req, reply);
    if (!user) return;
    const keys = await prisma.apiKey.findMany({
      where: { userId: user.id, revokedAt: null },
      orderBy: { createdAt: "desc" },
    });
    return reply.send({
      apiKeys: keys.map((k) => ({
        id: k.id, name: k.name, prefix: k.prefix, createdAt: k.createdAt, lastUsedAt: k.lastUsedAt,
      })),
    });
  });

  // 廢除
  app.delete("/v1/apikeys/:id", async (req, reply) => {
    const user = await requireUser(prisma, req, reply);
    if (!user) return;
    const { id } = req.params as { id: string };
    const key = await prisma.apiKey.findUnique({ where: { id } });
    if (!key || key.userId !== user.id) return reply.code(404).send({ error: "not found" });
    await prisma.apiKey.update({ where: { id }, data: { revokedAt: new Date() } });
    return reply.code(204).send();
  });
}
