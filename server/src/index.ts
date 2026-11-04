import { buildApp } from "./app.js";
import { startWebhookDispatcher } from "./webhooks.js";
import { PrismaClient } from "@prisma/client";

const PORT = Number(process.env.PORT ?? 8787);
const HOST = process.env.HOST ?? "0.0.0.0";

const prisma = new PrismaClient();
const app = await buildApp(prisma);

const shutdown = async (signal: string) => {
  app.log.info({ signal }, "shutting down");
  await app.close();
  process.exit(0);
};
process.on("SIGINT", () => void shutdown("SIGINT"));
process.on("SIGTERM", () => void shutdown("SIGTERM"));

try {
  await app.listen({ port: PORT, host: HOST });
  startWebhookDispatcher(prisma);
  app.log.info("webhook dispatcher running");
} catch (err) {
  app.log.error(err);
  process.exit(1);
}
