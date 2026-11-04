// Task 2.4 — Album（相簿）：base64 上傳 → /data/uploads → cuid 公開 URL
import type { FastifyInstance, FastifyReply, FastifyRequest } from "fastify";
import type { PrismaClient, User } from "@prisma/client";
import { userFromRequest } from "./auth.js";
import { randomBytes } from "node:crypto";
import { mkdirSync, createReadStream, existsSync, unlinkSync } from "node:fs";
import path from "node:path";

const UPLOAD_DIR = process.env.UPLOAD_DIR ?? path.resolve(process.cwd(), "data/uploads");
const MAX_BYTES = 8 * 1024 * 1024; // 8MB 原圖上限
const MIME_EXT: Record<string, string> = {
  "image/jpeg": "jpg",
  "image/png": "png",
  "image/webp": "webp",
  "image/heic": "heic",
};

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

async function emitEvent(prisma: PrismaClient, type: string, aggregateId: string, payload: object) {
  await prisma.outboxEvent.create({ data: { type, aggregateId, payload: JSON.stringify(payload) } });
}

function publicPhoto(p: { id: string; uploaderId: string; mimeType: string; size: number; createdAt: Date }, uploaderName: string) {
  return {
    id: p.id,
    url: `/v1/files/${p.id}`,
    mimeType: p.mimeType,
    size: p.size,
    createdAt: p.createdAt,
    uploaderId: p.uploaderId,
    uploaderName,
  };
}

export function registerPhotoRoutes(app: FastifyInstance, prisma: PrismaClient) {
  mkdirSync(UPLOAD_DIR, { recursive: true });

  // 列出相片（最新排先）
  app.get("/v1/calendars/:id/photos", async (req, reply) => {
    const user = await requireUser(prisma, req, reply);
    if (!user) return;
    const { id } = req.params as { id: string };
    if (!(await requireMember(prisma, id, user.id))) return reply.code(404).send({ error: "calendar not found" });
    const photos = await prisma.photo.findMany({
      where: { calendarId: id },
      include: { uploader: { select: { displayName: true } } },
      orderBy: { createdAt: "desc" },
      take: 200,
    });
    return reply.send({ photos: photos.map((p) => publicPhoto(p, p.uploader.displayName)) });
  });

  // 上傳（base64 JSON：{ data, mimeType }）
  app.post("/v1/calendars/:id/photos", async (req, reply) => {
    const user = await requireUser(prisma, req, reply);
    if (!user) return;
    const { id } = req.params as { id: string };
    if (!(await requireMember(prisma, id, user.id))) return reply.code(404).send({ error: "calendar not found" });
    const body = (req.body ?? {}) as { data?: string; mimeType?: string };
    if (!body.data || !body.mimeType) return reply.code(400).send({ error: "data and mimeType are required" });
    const ext = MIME_EXT[body.mimeType];
    if (!ext) return reply.code(400).send({ error: "unsupported mimeType" });

    let buf: Buffer;
    try {
      buf = Buffer.from(body.data, "base64");
    } catch {
      return reply.code(400).send({ error: "bad base64" });
    }
    if (buf.length === 0) return reply.code(400).send({ error: "empty file" });
    if (buf.length > MAX_BYTES) return reply.code(413).send({ error: "file too large" });

    const filename = `${randomBytes(16).toString("hex")}.${ext}`;
    const photo = await prisma.photo.create({
      data: { calendarId: id, uploaderId: user.id, filename, mimeType: body.mimeType, size: buf.length },
      include: { uploader: { select: { displayName: true } } },
    });
    const { writeFileSync } = await import("node:fs");
    writeFileSync(path.join(UPLOAD_DIR, filename), buf);
    await emitEvent(prisma, "photo.uploaded", id, { photoId: photo.id, actorId: user.id });
    return reply.code(201).send({ photo: publicPhoto(photo, photo.uploader.displayName) });
  });

  // 攞相（cuid id 先估到——家庭 app 尺度 OK）
  app.get("/v1/files/:id", async (req, reply) => {
    const { id } = req.params as { id: string };
    const photo = await prisma.photo.findUnique({ where: { id } });
    if (!photo) return reply.code(404).send({ error: "not found" });
    const file = path.join(UPLOAD_DIR, photo.filename);
    if (!existsSync(file)) return reply.code(404).send({ error: "file missing" });
    reply.header("content-type", photo.mimeType);
    reply.header("cache-control", "public, max-age=31536000, immutable");
    return reply.send(createReadStream(file));
  });

  // 刪相（上傳者本人）
  app.delete("/v1/photos/:id", async (req, reply) => {
    const user = await requireUser(prisma, req, reply);
    if (!user) return;
    const { id } = req.params as { id: string };
    const photo = await prisma.photo.findUnique({ where: { id } });
    if (!photo) return reply.code(404).send({ error: "not found" });
    if (photo.uploaderId !== user.id) return reply.code(403).send({ error: "not your photo" });
    await prisma.photo.delete({ where: { id } });
    const file = path.join(UPLOAD_DIR, photo.filename);
    if (existsSync(file)) unlinkSync(file);
    return reply.code(204).send();
  });
}
