import Fastify from "fastify";
import { readFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { PrismaClient } from "@prisma/client";

const VERSION = "0.1.0";
const PORT = Number(process.env.PORT ?? 8787);
const HOST = process.env.HOST ?? "0.0.0.0";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
// Works from both src/ (tsx dev) and dist/ (node start): the yaml sits at server/openapi.yaml
const OPENAPI_PATH = path.resolve(__dirname, "..", "openapi.yaml");

const prisma = new PrismaClient();

// SQLite in WAL mode for concurrent readers (per docs/ARCHITECTURE.md)
await prisma.$queryRawUnsafe("PRAGMA journal_mode=WAL;");

const openapiYaml = await readFile(OPENAPI_PATH, "utf8");

const app = Fastify({ logger: true });

app.get("/health", async () => ({ ok: true, version: VERSION }));

app.get("/v1/ping", async () => ({ pong: true }));

// Serve the hand-written OpenAPI v0 skeleton. text/plain so browsers render it.
app.get("/docs", async (_req, reply) => {
  reply.type("text/plain; charset=utf-8").send(openapiYaml);
});

// Also expose the raw spec at its canonical path.
app.get("/openapi.yaml", async (_req, reply) => {
  reply.type("text/plain; charset=utf-8").send(openapiYaml);
});

const shutdown = async (signal: string) => {
  app.log.info({ signal }, "shutting down");
  await app.close();
  await prisma.$disconnect();
  process.exit(0);
};
process.on("SIGINT", () => void shutdown("SIGINT"));
process.on("SIGTERM", () => void shutdown("SIGTERM"));

try {
  await app.listen({ port: PORT, host: HOST });
} catch (err) {
  app.log.error(err);
  await prisma.$disconnect();
  process.exit(1);
}
