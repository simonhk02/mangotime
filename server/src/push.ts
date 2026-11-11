// APNs 推送：device 註冊 + outbox 事件 → 推送俾行事曆其他成員
// JWT ES256 簽名（jose），HTTP/2 POST 去 api.push.apple.com
// Env：APNS_KEY_BASE64（.p8 內容 base64）/ APNS_KEY_ID / APNS_TEAM_ID / APNS_BUNDLE_ID / APNS_SANDBOX
import type { FastifyInstance, FastifyReply, FastifyRequest } from "fastify";
import type { PrismaClient, User } from "@prisma/client";
import { userFromRequest } from "./auth.js";
import { SignJWT, importPKCS8 } from "jose";
import http2 from "node:http2";

function apnsConfig() {
  const keyB64 = process.env.APNS_KEY_BASE64;
  const keyId = process.env.APNS_KEY_ID;
  const teamId = process.env.APNS_TEAM_ID;
  const bundleId = process.env.APNS_BUNDLE_ID ?? "com.mangotime.app";
  const sandbox = process.env.APNS_SANDBOX === "1";
  if (!keyB64 || !keyId || !teamId) return null;
  return { keyB64, keyId, teamId, bundleId, host: sandbox ? "api.sandbox.push.apple.com" : "api.push.apple.com" };
}

let cachedJwt: { token: string; iat: number } | null = null;

async function apnsJwt(cfg: NonNullable<ReturnType<typeof apnsConfig>>): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  if (cachedJwt && now - cachedJwt.iat < 3000) return cachedJwt.token; // Apple 上限 1 粒鐘，50 分鐘 refresh
  const key = await importPKCS8(Buffer.from(cfg.keyB64, "base64").toString("utf8"), "ES256");
  const token = await new SignJWT({ iss: cfg.teamId, iat: now })
    .setProtectedHeader({ alg: "ES256", kid: cfg.keyId })
    .sign(key);
  cachedJwt = { token, iat: now };
  return token;
}

// sender 可以俾 test override（唔好真打 APNs）
export type PushSender = (host: string, jwt: string, topic: string, deviceToken: string, payload: object) => Promise<{ status: number; reason?: string }>;
let sender: PushSender = http2Send;

export function setPushSender(s: PushSender) { sender = s; }

async function http2Send(host: string, jwt: string, topic: string, deviceToken: string, payload: object) {
  return new Promise<{ status: number; reason?: string }>((resolve) => {
    const client = http2.connect(`https://${host}`);
    client.on("error", () => { resolve({ status: 0, reason: "connect_error" }); });
    const req = client.request({
      ":method": "POST",
      ":path": `/3/device/${deviceToken}`,
      "authorization": `bearer ${jwt}`,
      "apns-topic": topic,
      "apns-push-type": "alert",
      "content-type": "application/json",
    });
    let body = "";
    req.on("data", (c: Buffer) => { body += c.toString(); });
    req.on("end", () => {
      client.close();
      let reason: string | undefined;
      try { reason = JSON.parse(body).reason; } catch { /* empty body = 200 */ }
      resolve({ status: 200, reason });
    });
    req.end(JSON.stringify(payload));
  });
}

// 事件 → 推送文案（同 activity feed 嘅用字一致）
export function pushText(type: string, payload: Record<string, unknown>, actorName: string): { title: string; body: string } | null {
  // events.ts 嘅 payload 係 { event: {...} }；memo/todo 用 title 喺頂層
  const ev = payload.event as { title?: string } | undefined;
  const t = String(ev?.title ?? payload.eventTitle ?? payload.title ?? payload.memoTitle ?? payload.listTitle ?? "");
  switch (type) {
    case "event.created": return { title: "新活動", body: `${actorName} 新增咗「${t}」` };
    case "event.updated": return { title: "活動更新", body: `${actorName} 改咗「${t}」` };
    case "event.deleted": return { title: "活動刪除", body: `${actorName} 刪除咗「${t}」` };
    case "event.comment_created": return { title: `「${t}」新留言`, body: `${actorName}：${String(payload.body ?? "").slice(0, 80)}` };
    case "memo.created": return { title: "新備忘錄", body: `${actorName} 寫咗「${t}」` };
    case "todo.list_created": return { title: "新待辦清單", body: `${actorName} 開咗「${t}」` };
    case "photo.uploaded": return { title: "新相片", body: `${actorName} 上傳咗相片` };
    case "calendar.invite_accepted": return { title: "新成員", body: `${actorName} 加入咗行事曆` };
    default: return null;
  }
}

async function requireUser(prisma: PrismaClient, req: FastifyRequest, reply: FastifyReply): Promise<User | null> {
  const user = await userFromRequest(prisma, req);
  if (!user) {
    await reply.code(401).send({ error: "unauthorized" });
    return null;
  }
  return user;
}

export function registerPushRoutes(app: FastifyInstance, prisma: PrismaClient) {
  // 註冊 device token（iOS 開 app 就叫）
  app.post("/v1/devices", async (req, reply) => {
    const user = await requireUser(prisma, req, reply);
    if (!user) return;
    const { token, platform } = (req.body ?? {}) as { token?: string; platform?: string };
    if (!token || token.length < 16) return reply.code(400).send({ error: "token required" });
    await prisma.device.upsert({
      where: { token },
      update: { userId: user.id, platform: platform ?? "ios" },
      create: { token, userId: user.id, platform: platform ?? "ios" },
    });
    return reply.code(201).send({ ok: true });
  });

  // 登出/刪除
  app.delete("/v1/devices/:token", async (req, reply) => {
    const user = await requireUser(prisma, req, reply);
    if (!user) return;
    const { token } = req.params as { token: string };
    await prisma.device.deleteMany({ where: { token, userId: user.id } });
    return reply.code(204).send();
  });
}

// 直接推畀單一用戶（digest 用）
export async function sendPushToUser(prisma: PrismaClient, userId: string, title: string, body: string) {
  const cfg = apnsConfig();
  if (!cfg) return;
  const devices = await prisma.device.findMany({ where: { userId } });
  if (devices.length === 0) return;
  const jwt = await apnsJwt(cfg);
  const aps = { aps: { alert: { title, body }, sound: "default" } };
  for (const d of devices) {
    const res = await sender(cfg.host, jwt, cfg.bundleId, d.token, aps);
    if (res.reason === "BadDeviceToken" || res.reason === "Unregistered") {
      await prisma.device.delete({ where: { id: d.id } }).catch(() => {});
    }
  }
}

// dispatcher：俾 app.ts 嘅 outbox loop 叫
export async function dispatchPush(prisma: PrismaClient, type: string, aggregateId: string, payload: Record<string, unknown>) {
  const cfg = apnsConfig();
  if (!cfg) return; // 未設定 APNs key 就靜靜雞 skip
  const actorId = String(payload.actorId ?? "");
  const actor = actorId ? await prisma.user.findUnique({ where: { id: actorId } }) : null;
  const text = pushText(type, payload, actor?.displayName ?? "有成員");
  if (!text) return;

  // 行事曆成員（除咗 actor 自己、閂咗通知嗰啲）嘅所有 device
  const members = await prisma.calendarMember.findMany({ where: { calendarId: aggregateId, userId: { not: actorId }, notify: true } });
  if (members.length === 0) return;
  const devices = await prisma.device.findMany({ where: { userId: { in: members.map((m) => m.userId) } } });
  if (devices.length === 0) return;

  const jwt = await apnsJwt(cfg);
  const aps = { aps: { alert: { title: text.title, body: text.body }, sound: "default" } };
  for (const d of devices) {
    const res = await sender(cfg.host, jwt, cfg.bundleId, d.token, aps);
    if (res.reason === "BadDeviceToken" || res.reason === "Unregistered") {
      await prisma.device.delete({ where: { id: d.id } }).catch(() => {});
    }
  }
}
