// Task 5.3 — Event Scan：影相/海報 → AI（Kimi vision）抽日期 → 建議活動（唔係直開，俾用戶確認）
import type { FastifyInstance, FastifyReply, FastifyRequest } from "fastify";
import type { PrismaClient, User } from "@prisma/client";
import { userFromRequest } from "./auth.js";

const SCAN_MODEL = process.env.SCAN_MODEL ?? "kimi-k3";
const SCAN_API_URL = process.env.SCAN_API_URL ?? "https://api.kimi.com/coding/v1/chat/completions";
const MAX_BYTES = 6 * 1024 * 1024;

const PROMPT = `你係一個日曆助手。呢張圖片係一張海報/通告/時間表/對話截圖。
請抽出入面所有「活動」資料，用 JSON array 回答（唔好加任何其他文字）：
[{"title":"活動名","date":"2026-11-19","time":"19:30","location":"地點或null","note":"補充或null"}]
規則：
- date 一定要 YYYY-MM-DD；圖入面冇年份就當而家最近嘅嗰日
- time 係 24 小時 HH:MM；冇時間就 null
- 抽唔到任何活動就答 []
- 標題用繁體中文（香港用語）`;

export type ScannedEvent = {
  title: string;
  date: string;
  time: string | null;
  location: string | null;
  note: string | null;
};

export function validateScanned(raw: unknown): ScannedEvent[] {
  if (!Array.isArray(raw)) return [];
  const out: ScannedEvent[] = [];
  for (const item of raw.slice(0, 20)) {
    if (typeof item !== "object" || item === null) continue;
    const o = item as Record<string, unknown>;
    if (typeof o.title !== "string" || !o.title.trim()) continue;
    if (typeof o.date !== "string" || !/^\d{4}-\d{2}-\d{2}$/.test(o.date)) continue;
    out.push({
      title: o.title.trim().slice(0, 80),
      date: o.date,
      time: typeof o.time === "string" && /^\d{2}:\d{2}$/.test(o.time) ? o.time : null,
      location: typeof o.location === "string" && o.location.trim() ? o.location.trim().slice(0, 120) : null,
      note: typeof o.note === "string" && o.note.trim() ? o.note.trim().slice(0, 200) : null,
    });
  }
  return out;
}

async function requireUser(prisma: PrismaClient, req: FastifyRequest, reply: FastifyReply): Promise<User | null> {
  const user = await userFromRequest(prisma, req);
  if (!user) {
    await reply.code(401).send({ error: "unauthorized" });
    return null;
  }
  return user;
}

export function registerScanRoutes(app: FastifyInstance, prisma: PrismaClient) {
  app.post("/v1/calendars/:id/scan", async (req, reply) => {
    const user = await requireUser(prisma, req, reply);
    if (!user) return;
    const { id } = req.params as { id: string };
    const member = await prisma.calendarMember.findUnique({
      where: { calendarId_userId: { calendarId: id, userId: user.id } },
    });
    if (!member) return reply.code(404).send({ error: "calendar not found" });

    const apiKey = process.env.SCAN_API_KEY;
    if (!apiKey) return reply.code(501).send({ error: "scan not configured" });

    const body = (req.body ?? {}) as { data?: string; mimeType?: string };
    if (!body.data) return reply.code(400).send({ error: "data required" });
    const mime = body.mimeType ?? "image/jpeg";
    if (!/^image\/(jpeg|png|webp)$/.test(mime)) return reply.code(400).send({ error: "image only" });
    const bytes = Buffer.from(body.data, "base64");
    if (bytes.length > MAX_BYTES) return reply.code(413).send({ error: "image too large" });

    // 叫 vision model
    const llmRes = await fetch(SCAN_API_URL, {
      method: "POST",
      headers: { "content-type": "application/json", authorization: `Bearer ${apiKey}` },
      body: JSON.stringify({
        model: SCAN_MODEL,
        messages: [{
          role: "user",
          content: [
            { type: "text", text: PROMPT },
            { type: "image_url", image_url: { url: `data:${mime};base64,${body.data}` } },
          ],
        }],
      }),
      signal: AbortSignal.timeout(45000),
    });
    if (!llmRes.ok) return reply.code(502).send({ error: "vision api error" });
    const llmJson = await llmRes.json() as { choices?: { message?: { content?: string } }[] };
    const content = llmJson.choices?.[0]?.message?.content ?? "";
    // LLM 成日包 ```json fence——剝走
    const cleaned = content.replace(/```json\s*/g, "").replace(/```/g, "").trim();
    let parsed: unknown = [];
    try { parsed = JSON.parse(cleaned); } catch { /* 格式衰咗當冇 */ }
    const events = validateScanned(parsed);
    await prisma.outboxEvent.create({
      data: { type: "calendar.scan", aggregateId: id, payload: JSON.stringify({ actorId: user.id, found: events.length }) },
    });
    return reply.send({ events });
  });
}
