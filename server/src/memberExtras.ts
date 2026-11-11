// Batch D — 封面圖上傳 + 最後查看 + 生日
import type { FastifyInstance, FastifyReply, FastifyRequest } from "fastify";
import type { PrismaClient, User } from "@prisma/client";
import { userFromRequest } from "./auth.js";
import { randomBytes } from "node:crypto";
import { mkdirSync, writeFileSync, existsSync, createReadStream } from "node:fs";
import path from "node:path";

const UPLOAD_DIR = process.env.UPLOAD_DIR ?? path.resolve(process.cwd(), "data/uploads");
const MAX_BYTES = 8 * 1024 * 1024;

async function requireUser(prisma: PrismaClient, req: FastifyRequest, reply: FastifyReply): Promise<User | null> {
  const user = await userFromRequest(prisma, req);
  if (!user) {
    await reply.code(401).send({ error: "unauthorized" });
    return null;
  }
  return user;
}

export function registerMemberExtraRoutes(app: FastifyInstance, prisma: PrismaClient) {
  // 封面圖檔案：GET /v1/covers/:name（public read——封面本身就要公開）
  app.get("/v1/covers/:name", async (req, reply) => {
    const { name } = req.params as { name: string };
    if (!/^cover_[a-f0-9]+\.(jpg|png|webp|heic)$/.test(name)) return reply.code(404).send({ error: "not found" });
    const file = path.join(UPLOAD_DIR, name);
    if (!existsSync(file)) return reply.code(404).send({ error: "file missing" });
    const ext = name.split(".").pop();
    reply.header("content-type", ext === "png" ? "image/png" : ext === "webp" ? "image/webp" : "image/jpeg");
    reply.header("cache-control", "public, max-age=86400");
    return reply.send(createReadStream(file));
  });

  // 封面圖：POST /v1/calendars/:id/cover { data: base64, mimeType }
  app.post("/v1/calendars/:id/cover", async (req, reply) => {
    const user = await requireUser(prisma, req, reply);
    if (!user) return;
    const { id } = req.params as { id: string };
    const member = await prisma.calendarMember.findUnique({ where: { calendarId_userId: { calendarId: id, userId: user.id } } });
    if (!member) return reply.code(404).send({ error: "calendar not found" });
    const { data, mimeType } = (req.body ?? {}) as { data?: string; mimeType?: string };
    if (!data || !mimeType || !/^image\/(jpeg|png|webp|heic)$/.test(mimeType)) {
      return reply.code(400).send({ error: "data + image mimeType required" });
    }
    const buf = Buffer.from(data, "base64");
    if (buf.length > MAX_BYTES) return reply.code(400).send({ error: "file too large" });
    mkdirSync(UPLOAD_DIR, { recursive: true });
    const ext = mimeType === "image/png" ? "png" : mimeType === "image/webp" ? "webp" : mimeType === "image/heic" ? "heic" : "jpg";
    const fname = `cover_${randomBytes(8).toString("hex")}.${ext}`;
    writeFileSync(path.join(UPLOAD_DIR, fname), buf);
    const url = `/v1/covers/${fname}`;
    await prisma.calendar.update({ where: { id }, data: { coverImageUrl: url } });
    return reply.send({ ok: true, coverImageUrl: url });
  });

  // 「查看過」：POST /v1/calendars/:id/seen → 更新自己 lastSeenAt
  app.post("/v1/calendars/:id/seen", async (req, reply) => {
    const user = await requireUser(prisma, req, reply);
    if (!user) return;
    const { id } = req.params as { id: string };
    await prisma.calendarMember.updateMany({
      where: { calendarId: id, userId: user.id },
      data: { lastSeenAt: new Date() },
    });
    return reply.send({ ok: true });
  });

  // 成員生日：GET /v1/calendars/:id/birthdays → [{ userId, displayName, birthdate }]
  app.get("/v1/calendars/:id/birthdays", async (req, reply) => {
    const user = await requireUser(prisma, req, reply);
    if (!user) return;
    const { id } = req.params as { id: string };
    const member = await prisma.calendarMember.findUnique({ where: { calendarId_userId: { calendarId: id, userId: user.id } } });
    if (!member) return reply.code(404).send({ error: "calendar not found" });
    const members = await prisma.calendarMember.findMany({
      where: { calendarId: id },
      include: { user: { select: { id: true, displayName: true, birthdate: true } } },
    });
    return reply.send({
      birthdays: members.filter((m) => m.user.birthdate).map((m) => ({
        userId: m.userId, displayName: m.user.displayName, birthdate: m.user.birthdate,
      })),
    });
  });
}
