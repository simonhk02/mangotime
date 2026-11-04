// Task 1.1 — Auth: email+password register/login/logout + profile (/v1/me).
// Session token: 32-byte random hex, stored as sha256 hash, 30-day expiry.
import type { FastifyInstance, FastifyRequest } from "fastify";
import type { PrismaClient, User } from "@prisma/client";
import { createHash, randomBytes } from "node:crypto";
import { hashPassword, verifyPassword } from "./password.js";

const SESSION_DAYS = 30;
const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

function tokenHash(token: string): string {
  return createHash("sha256").update(token).digest("hex");
}

export function publicUser(u: User) {
  return { id: u.id, email: u.email, displayName: u.displayName, avatarUrl: u.avatarUrl, createdAt: u.createdAt };
}

/** Resolve Bearer token → User or null. */
export async function userFromRequest(prisma: PrismaClient, req: FastifyRequest): Promise<User | null> {
  const header = req.headers.authorization ?? "";
  const m = header.match(/^Bearer\s+(.+)$/i);
  if (!m) return null;
  const raw = m[1].trim();
  // mt_ 開頭 = API key（agent 用）；否則係 session token
  if (raw.startsWith("mt_")) {
    const { createHash } = await import("node:crypto");
    const keyHash = createHash("sha256").update(raw).digest("hex");
    const key = await prisma.apiKey.findUnique({ where: { keyHash }, include: { user: true } });
    if (!key || key.revokedAt) return null;
    await prisma.apiKey.update({ where: { id: key.id }, data: { lastUsedAt: new Date() } }).catch(() => {});
    return key.user;
  }
  const session = await prisma.session.findUnique({
    where: { tokenHash: tokenHash(raw) },
    include: { user: true },
  });
  if (!session) return null;
  if (session.expiresAt < new Date()) {
    await prisma.session.delete({ where: { id: session.id } }).catch(() => {});
    return null;
  }
  return session.user;
}

export async function issueSession(prisma: PrismaClient, userId: string): Promise<string> {
  const token = randomBytes(32).toString("hex");
  const expiresAt = new Date(Date.now() + SESSION_DAYS * 24 * 3600 * 1000);
  await prisma.session.create({ data: { tokenHash: tokenHash(token), userId, expiresAt } });
  return token;
}

export function registerAuthRoutes(app: FastifyInstance, prisma: PrismaClient) {
  app.post("/v1/auth/register", async (req, reply) => {
    const body = (req.body ?? {}) as { email?: string; password?: string; displayName?: string };
    const email = body.email?.trim().toLowerCase();
    const { password, displayName } = body;
    if (!email || !EMAIL_RE.test(email)) return reply.code(400).send({ error: "invalid email" });
    if (!password || password.length < 8) return reply.code(400).send({ error: "password must be at least 8 characters" });
    if (!displayName || !displayName.trim()) return reply.code(400).send({ error: "displayName is required" });
    const existing = await prisma.user.findUnique({ where: { email } });
    if (existing) return reply.code(409).send({ error: "email already registered" });
    const user = await prisma.user.create({
      data: { email, displayName: displayName.trim(), passwordHash: await hashPassword(password) },
    });
    const token = await issueSession(prisma, user.id);
    return reply.code(201).send({ user: publicUser(user), token });
  });

  app.post("/v1/auth/login", async (req, reply) => {
    const body = (req.body ?? {}) as { email?: string; password?: string };
    const email = body.email?.trim().toLowerCase();
    if (!email || !body.password) return reply.code(400).send({ error: "email and password required" });
    const user = await prisma.user.findUnique({ where: { email } });
    if (!user || !user.passwordHash || !(await verifyPassword(body.password, user.passwordHash))) {
      return reply.code(401).send({ error: "invalid email or password" });
    }
    const token = await issueSession(prisma, user.id);
    return { user: publicUser(user), token };
  });

  app.post("/v1/auth/logout", async (req, reply) => {
    const header = req.headers.authorization ?? "";
    const m = header.match(/^Bearer\s+(.+)$/i);
    if (m) await prisma.session.deleteMany({ where: { tokenHash: tokenHash(m[1].trim()) } });
    return reply.code(204).send();
  });

  app.get("/v1/me", async (req, reply) => {
    const user = await userFromRequest(prisma, req);
    if (!user) return reply.code(401).send({ error: "unauthorized" });
    return { user: publicUser(user) };
  });

  app.patch("/v1/me", async (req, reply) => {
    const user = await userFromRequest(prisma, req);
    if (!user) return reply.code(401).send({ error: "unauthorized" });
    const body = (req.body ?? {}) as { displayName?: string; avatarUrl?: string | null };
    const data: { displayName?: string; avatarUrl?: string | null } = {};
    if (body.displayName !== undefined) {
      if (!body.displayName.trim()) return reply.code(400).send({ error: "displayName cannot be empty" });
      data.displayName = body.displayName.trim();
    }
    if (body.avatarUrl !== undefined) data.avatarUrl = body.avatarUrl;
    if (Object.keys(data).length === 0) return reply.code(400).send({ error: "nothing to update" });
    const updated = await prisma.user.update({ where: { id: user.id }, data });
    return { user: publicUser(updated) };
  });
}
