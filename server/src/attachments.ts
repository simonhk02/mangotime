// Task 5.4 — Event attachments（活動附件：相/PDF 釘落活動，儲存同 photos 共用 /data/uploads）
import type { FastifyInstance, FastifyReply, FastifyRequest } from "fastify";
import type { PrismaClient, User } from "@prisma/client";
import { userFromRequest } from "./auth.js";
import { randomBytes } from "node:crypto";
import { mkdirSync, createReadStream, existsSync, unlinkSync, writeFileSync } from "node:fs";
import path from "node:path";

const UPLOAD_DIR = process.env.UPLOAD_DIR ?? path.resolve(process.cwd(), "data/uploads");
const MAX_BYTES = 8 * 1024 * 1024;
const MIME_EXT: Record<string, string> = {
  "image/jpeg": "jpg", "image/png": "png", "image/webp": "webp", "image/heic": "heic",
  "application/pdf": "pdf",
};

async function requireUser(prisma: PrismaClient, req: FastifyRequest, reply: FastifyReply): Promise<User | null> {
  const user = await userFromRequest(prisma, req);
  if (!user) {
    await reply.code(401).send({ error: "unauthorized" });
    return null;
  }
  return user;
}

async function eventForMember(prisma: PrismaClient, eventId: string, userId: string) {
  const event = await prisma.event.findUnique({ where: { id: eventId } });
  if (!event) return null;
  const member = await prisma.calendarMember.findUnique({
    where: { calendarId_userId: { calendarId: event.calendarId, userId } },
  });
  return member ? event : null;
}

async function emitEvent(prisma: PrismaClient, type: string, aggregateId: string, payload: object) {
  await prisma.outboxEvent.create({ data: { type, aggregateId, payload: JSON.stringify(payload) } });
}

export function registerAttachmentRoutes(app: FastifyInstance, prisma: PrismaClient) {
  mkdirSync(UPLOAD_DIR, { recursive: true });

  // 列出活動附件
  app.get("/v1/events/:id/attachments", async (req, reply) => {
    const user = await requireUser(prisma, req, reply);
    if (!user) return;
    const { id } = req.params as { id: string };
    if (!(await eventForMember(prisma, id, user.id))) return reply.code(404).send({ error: "event not found" });
    const atts = await prisma.attachment.findMany({
      where: { eventId: id },
      include: { uploader: { select: { displayName: true } } },
      orderBy: { createdAt: "asc" },
    });
    return reply.send({
      attachments: atts.map((a) => ({
        id: a.id, url: `/v1/attachments/${a.id}/file`, mimeType: a.mimeType, size: a.size,
        uploaderId: a.uploaderId, uploaderName: a.uploader.displayName, createdAt: a.createdAt,
      })),
    });
  });

  // 上傳附件（base64）
  app.post("/v1/events/:id/attachments", async (req, reply) => {
    const user = await requireUser(prisma, req, reply);
    if (!user) return;
    const { id } = req.params as { id: string };
    const event = await eventForMember(prisma, id, user.id);
    if (!event) return reply.code(404).send({ error: "event not found" });
    const body = (req.body ?? {}) as { data?: string; mimeType?: string };
    if (!body.data || !body.mimeType) return reply.code(400).send({ error: "data and mimeType are required" });
    const ext = MIME_EXT[body.mimeType];
    if (!ext) return reply.code(400).send({ error: "unsupported mimeType" });
    let buf: Buffer;
    try { buf = Buffer.from(body.data, "base64"); } catch { return reply.code(400).send({ error: "bad base64" }); }
    if (buf.length === 0) return reply.code(400).send({ error: "empty file" });
    if (buf.length > MAX_BYTES) return reply.code(413).send({ error: "file too large" });

    const filename = `${randomBytes(16).toString("hex")}.${ext}`;
    const att = await prisma.attachment.create({
      data: { eventId: id, uploaderId: user.id, filename, mimeType: body.mimeType, size: buf.length },
      include: { uploader: { select: { displayName: true } } },
    });
    writeFileSync(path.join(UPLOAD_DIR, filename), buf);
    await emitEvent(prisma, "event.attachment_added", event.calendarId, { eventId: id, attachmentId: att.id, actorId: user.id });
    return reply.code(201).send({
      attachment: {
        id: att.id, url: `/v1/attachments/${att.id}/file`, mimeType: att.mimeType, size: att.size,
        uploaderId: att.uploaderId, uploaderName: att.uploader.displayName, createdAt: att.createdAt,
      },
    });
  });

  // 攞附件檔（cuid 先估到）
  app.get("/v1/attachments/:id/file", async (req, reply) => {
    const { id } = req.params as { id: string };
    const att = await prisma.attachment.findUnique({ where: { id } });
    if (!att) return reply.code(404).send({ error: "not found" });
    const file = path.join(UPLOAD_DIR, att.filename);
    if (!existsSync(file)) return reply.code(404).send({ error: "file missing" });
    reply.header("content-type", att.mimeType);
    reply.header("cache-control", "public, max-age=31536000, immutable");
    return reply.send(createReadStream(file));
  });

  // 刪（上傳者本人）
  app.delete("/v1/attachments/:id", async (req, reply) => {
    const user = await requireUser(prisma, req, reply);
    if (!user) return;
    const { id } = req.params as { id: string };
    const att = await prisma.attachment.findUnique({ where: { id } });
    if (!att) return reply.code(404).send({ error: "not found" });
    if (att.uploaderId !== user.id) return reply.code(403).send({ error: "not your attachment" });
    await prisma.attachment.delete({ where: { id } });
    const file = path.join(UPLOAD_DIR, att.filename);
    if (existsSync(file)) unlinkSync(file);
    return reply.code(204).send();
  });
}
