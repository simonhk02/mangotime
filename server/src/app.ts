import Fastify, { type FastifyInstance } from "fastify";
import { readFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { PrismaClient } from "@prisma/client";
import { registerAuthRoutes } from "./auth.js";
import { registerInviteRoutes } from "./invites.js";
import { registerCommentRoutes } from "./comments.js";
import { registerMemoRoutes } from "./memos.js";
import { registerTodoRoutes } from "./todos.js";
import { registerPhotoRoutes } from "./photos.js";
import { registerActivityRoutes } from "./activity.js";
import { registerNoticeRoutes } from "./notices.js";
import { registerApiKeyRoutes } from "./apikeys.js";
import { registerWebhookRoutes } from "./webhooks.js";
import { registerCalendarRoutes } from "./calendars.js";
import { registerEventRoutes } from "./events.js";

const VERSION = "0.1.0";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
// Works from both src/ (tsx dev) and dist/ (node start): the yaml sits at server/openapi.yaml
const OPENAPI_PATH = path.resolve(__dirname, "..", "openapi.yaml");

export async function buildApp(prisma?: PrismaClient): Promise<FastifyInstance> {
  const db = prisma ?? new PrismaClient();
  // SQLite in WAL mode for concurrent readers (per docs/ARCHITECTURE.md)
  await db.$queryRawUnsafe("PRAGMA journal_mode=WAL;");
  const openapiYaml = await readFile(OPENAPI_PATH, "utf8");

  const app = Fastify({
    logger: process.env.NODE_ENV !== "test",
    bodyLimit: 16 * 1024 * 1024, // 16MB：base64 相片上傳（原圖 8MB 上限）
  });

  app.get("/health", async () => ({ ok: true, version: VERSION }));
  app.get("/v1/ping", async () => ({ pong: true }));

  // Serve the hand-written OpenAPI spec. text/plain so browsers render it.
  app.get("/docs", async (_req, reply) => {
    reply.type("text/plain; charset=utf-8").send(openapiYaml);
  });
  app.get("/openapi.yaml", async (_req, reply) => {
    reply.type("text/plain; charset=utf-8").send(openapiYaml);
  });

  registerAuthRoutes(app, db);
  registerInviteRoutes(app, db);
  registerCommentRoutes(app, db);
  registerMemoRoutes(app, db);
  registerTodoRoutes(app, db);
  registerPhotoRoutes(app, db);
  registerActivityRoutes(app, db);
  registerNoticeRoutes(app, db);
  registerApiKeyRoutes(app, db);
  registerWebhookRoutes(app, db);
  registerCalendarRoutes(app, db);
  registerEventRoutes(app, db);

  app.addHook("onClose", async () => {
    await db.$disconnect();
  });

  return app;
}
