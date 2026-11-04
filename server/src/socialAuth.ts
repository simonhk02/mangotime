// Task 1.1+ — Social auth：Apple / Google 登入
// Apple：iOS SignInWithAppleButton 俾 identityToken（JWT），server 用 Apple JWKS 驗簽
// Google：web/iOS 攞 idToken，server 用 Google JWKS 驗簽
// 兩者共通：email 對到現有用戶就 link；冇就開新帳（social 帳冇密碼，之後可 set）
import type { FastifyInstance, FastifyReply, FastifyRequest } from "fastify";
import type { PrismaClient, User } from "@prisma/client";
import { createRemoteJWKSet, createLocalJWKSet, jwtVerify } from "jose";
import { issueSession } from "./auth.js";

// JWKS URL 每次 request 先讀（俾 test 喺 before() set env）
// Test 環境注意：本機 node --test 底下 listen() 會 hang，所以 test 用 JWKS_JSON_OVERRIDE 直出 keyset，唔使起 http server
function appleJwks() { return process.env.APPLE_JWKS_URL ?? "https://appleid.apple.com/auth/keys"; }
function googleJwks() { return process.env.GOOGLE_JWKS_URL ?? "https://www.googleapis.com/oauth2/v3/certs"; }
function appleAud() { return process.env.APPLE_CLIENT_ID ?? "com.mangotime.app"; }
function googleAud() { return process.env.GOOGLE_CLIENT_ID ?? ""; }

function jwksFor(urlFn: () => string) {
  const override = process.env.JWKS_JSON_OVERRIDE;
  if (override) return createLocalJWKSet(JSON.parse(override));
  return createRemoteJWKSet(new URL(urlFn()));
}

async function verifyApple(idToken: string): Promise<{ sub: string; email?: string } | null> {
  try {
    const jwks = jwksFor(appleJwks);
    const { payload } = await jwtVerify(idToken, jwks, { issuer: "https://appleid.apple.com", audience: appleAud() });
    return { sub: payload.sub as string, email: payload.email as string | undefined };
  } catch {
    return null;
  }
}

async function verifyGoogle(idToken: string): Promise<{ sub: string; email?: string; name?: string } | null> {
  try {
    const jwks = jwksFor(googleJwks);
    const aud = googleAud();
    const { payload } = await jwtVerify(idToken, jwks, {
      issuer: ["https://accounts.google.com", "accounts.google.com"],
      ...(aud ? { audience: aud } : {}),
    });
    return { sub: payload.sub as string, email: payload.email as string | undefined, name: payload.name as string | undefined };
  } catch {
    return null;
  }
}

async function loginSocial(
  prisma: PrismaClient,
  reply: FastifyReply,
  provider: "apple" | "google",
  providerSub: string,
  email: string | undefined,
  name: string | undefined,
) {
  // 1. 已有 link → 直接入
  const existing = await prisma.socialAccount.findUnique({
    where: { provider_providerSub: { provider, providerSub } },
    include: { user: true },
  });
  let user: User;
  if (existing) {
    user = existing.user;
  } else if (email) {
    // 2. email 對到現有帳 → link（同 TimeTree 一樣，一個人唔會因為轉咗登入方式就開新帳）
    const byEmail = await prisma.user.findUnique({ where: { email: email.toLowerCase() } });
    if (byEmail) {
      await prisma.socialAccount.create({ data: { provider, providerSub, userId: byEmail.id, email } });
      user = byEmail;
    } else {
      user = await prisma.user.create({
        data: { email: email.toLowerCase(), displayName: name ?? email.split("@")[0], passwordHash: null },
      });
      await prisma.socialAccount.create({ data: { provider, providerSub, userId: user.id, email } });
    }
  } else {
    // 3. Apple hide-my-email 第一次先俾 email；之後冇 email 都開到（用 sub）
    const placeholder = `${provider}-${providerSub.slice(0, 12)}@social.mangotime.local`;
    user = await prisma.user.create({ data: { email: placeholder, displayName: name ?? "MangoTime 用戶", passwordHash: null } });
    await prisma.socialAccount.create({ data: { provider, providerSub, userId: user.id, email: null } });
  }
  const token = await issueSession(prisma, user.id);
  return reply.send({ user: { id: user.id, email: user.email, displayName: user.displayName }, token });
}

export function registerSocialAuthRoutes(app: FastifyInstance, prisma: PrismaClient) {
  app.post("/v1/auth/apple", async (req: FastifyRequest, reply: FastifyReply) => {
    const { idToken, displayName } = (req.body ?? {}) as { idToken?: string; displayName?: string };
    if (!idToken) return reply.code(400).send({ error: "idToken is required" });
    const verified = await verifyApple(idToken);
    if (!verified) return reply.code(401).send({ error: "invalid apple token" });
    return loginSocial(prisma, reply, "apple", verified.sub, verified.email, displayName ?? verified.email?.split("@")[0]);
  });

  app.post("/v1/auth/google", async (req: FastifyRequest, reply: FastifyReply) => {
    const { idToken } = (req.body ?? {}) as { idToken?: string };
    if (!idToken) return reply.code(400).send({ error: "idToken is required" });
    const verified = await verifyGoogle(idToken);
    if (!verified) return reply.code(401).send({ error: "invalid google token" });
    return loginSocial(prisma, reply, "google", verified.sub, verified.email, verified.name);
  });
}
