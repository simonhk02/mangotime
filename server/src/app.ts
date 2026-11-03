import Fastify, { type FastifyInstance } from "fastify";
import { readFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { PrismaClient } from "@prisma/client";
import { registerAuthRoutes } from "./auth.js";
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

  const app = Fastify({ logger: process.env.NODE_ENV !== "test" });

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
  registerCalendarRoutes(app, db);
  registerEventRoutes(app, db);

  app.addHook("onClose", async () => {
    await db.$disconnect();
  });

  return app;
}
