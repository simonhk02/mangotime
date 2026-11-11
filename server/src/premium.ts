// Premium 訂閱：App Store Server API 驗證 transactionId → 記 premiumUntil
import type { FastifyInstance, FastifyReply, FastifyRequest } from "fastify";
import type { PrismaClient, User } from "@prisma/client";
import { userFromRequest } from "./auth.js";
import { SignJWT, importPKCS8 } from "jose";

// App Store Server API 用同一條 ASC key（ES256）
const KEY_ID = process.env.APPSTORE_KEY_ID ?? "";
const ISSUER_ID = process.env.APPSTORE_ISSUER_ID ?? "";
const KEY_BASE64 = process.env.APPSTORE_KEY_BASE64 ?? "";
const BUNDLE_ID = process.env.APPSTORE_BUNDLE_ID ?? "com.mangotime.app";

type TxInfo = { transactionId: string; productId: string; expiresDate?: number; bundleId?: string; revocationDate?: number };

// 可注入（test 用）
let fetchTx: ((txId: string, sandbox: boolean) => Promise<TxInfo | null>) | null = null;
export function setTransactionFetcher(f: typeof fetchTx) { fetchTx = f; }

async function appleJwt(): Promise<string | null> {
  if (!KEY_ID || !ISSUER_ID || !KEY_BASE64) return null;
  const pk = await importPKCS8(Buffer.from(KEY_BASE64, "base64").toString("utf8"), "ES256");
  return await new SignJWT({ bid: BUNDLE_ID })
    .setProtectedHeader({ alg: "ES256", kid: KEY_ID, typ: "JWT" })
    .setIssuer(ISSUER_ID)
    .setAudience("appstoreconnect-v1")
    .setIssuedAt()
    .setExpirationTime("10m")
    .sign(pk);
}

/** 解 Apple 返嚟嘅 signedTransactionInfo JWS payload（TLS 直達 Apple，唔使再驗簽） */
function decodeJwsPayload(jws: string): Record<string, unknown> | null {
  const parts = jws.split(".");
  if (parts.length !== 3) return null;
  try {
    return JSON.parse(Buffer.from(parts[1], "base64url").toString("utf8"));
  } catch { return null; }
}

async function fetchTransaction(txId: string, sandbox: boolean): Promise<TxInfo | null> {
  const jwt = await appleJwt();
  if (!jwt) return null;
  const host = sandbox ? "https://api-sandbox.storekit.apple.com" : "https://api.storekit.apple.com";
  const res = await fetch(`${host}/inApps/v1/transactions/${txId}`, {
    headers: { Authorization: `Bearer ${jwt}` },
  });
  if (!res.ok) return null;
  const body = (await res.json()) as { signedTransactionInfo?: string };
  if (!body.signedTransactionInfo) return null;
  const info = decodeJwsPayload(body.signedTransactionInfo);
  if (!info) return null;
  return {
    transactionId: String(info.transactionId ?? txId),
    productId: String(info.productId ?? ""),
    expiresDate: typeof info.expiresDate === "number" ? info.expiresDate : undefined,
    bundleId: info.bundleId as string | undefined,
    revocationDate: typeof info.revocationDate === "number" ? info.revocationDate : undefined,
  };
}

async function requireUser(prisma: PrismaClient, req: FastifyRequest, reply: FastifyReply): Promise<User | null> {
  const user = await userFromRequest(prisma, req);
  if (!user) {
    await reply.code(401).send({ error: "unauthorized" });
    return null;
  }
  return user;
}

export function isPremium(user: { premiumUntil: Date | null }): boolean {
  return !!user.premiumUntil && user.premiumUntil.getTime() > Date.now();
}

export function registerPremiumRoutes(app: FastifyInstance, prisma: PrismaClient) {
  // 驗證 + 開通：POST /v1/premium/verify { transactionId, sandbox? }
  app.post("/v1/premium/verify", async (req, reply) => {
    const user = await requireUser(prisma, req, reply);
    if (!user) return;
    const { transactionId, sandbox } = (req.body ?? {}) as { transactionId?: string; sandbox?: boolean };
    if (!transactionId) return reply.code(400).send({ error: "transactionId required" });
    const fetcher = fetchTx ?? fetchTransaction;
    const tx = await fetcher(transactionId, sandbox === true);
    if (!tx) return reply.code(502).send({ error: "apple verification failed" });
    if (tx.bundleId && tx.bundleId !== BUNDLE_ID) return reply.code(400).send({ error: "wrong bundle" });
    if (tx.revocationDate) return reply.code(400).send({ error: "transaction refunded" });
    const until = tx.expiresDate ? new Date(tx.expiresDate) : new Date(Date.now() + 30 * 24 * 3600 * 1000);
    await prisma.user.update({ where: { id: user.id }, data: { premiumUntil: until } });
    return reply.send({ ok: true, premiumUntil: until });
  });

  // 狀態：GET /v1/premium → { premium, premiumUntil }
  app.get("/v1/premium", async (req, reply) => {
    const user = await requireUser(prisma, req, reply);
    if (!user) return;
    const fresh = await prisma.user.findUniqueOrThrow({ where: { id: user.id } });
    return reply.send({ premium: isPremium(fresh), premiumUntil: fresh.premiumUntil });
  });
}
