// 今日行程 digest（TimeTree「今日行程」）：每分鐘掃一次，到咗用戶自選時間（預設 08:00）就推送
import type { PrismaClient } from "@prisma/client";
import { sendPushToUser } from "./push.js";

let timer: ReturnType<typeof setInterval> | null = null;
let sender: ((prisma: PrismaClient, userId: string, title: string, body: string) => Promise<void>) | null = null;

export function setDigestSender(fn: typeof sender) { sender = fn; }

export function startDigestLoop(prisma: PrismaClient) {
  if (timer) return;
  let lastRunKey = ""; // "YYYY-MM-DD HH:MM" 防同一分鐘重複派
  timer = setInterval(async () => {
    const now = new Date();
    // HKT（UTC+8）——MVP 單一時區，之後先做 per-user tz
    const hkt = new Date(now.getTime() + 8 * 3600 * 1000);
    const hhmm = `${String(hkt.getUTCHours()).padStart(2, "0")}:${String(hkt.getUTCMinutes()).padStart(2, "0")}`;
    const dayKey = hkt.toISOString().slice(0, 10);
    const runKey = `${dayKey} ${hhmm}`;
    if (runKey === lastRunKey) return;

    // 搵出 digestTime == hhmm（或冇設定而 hhmm == 08:00）嘅用戶
    const users = await prisma.user.findMany({
      where: hhmm === "08:00" ? { OR: [{ digestTime: hhmm }, { digestTime: null }] } : { digestTime: hhmm },
    });
    if (users.length === 0) return;
    lastRunKey = runKey;

    const dayStart = new Date(`${dayKey}T00:00:00+08:00`);
    const dayEnd = new Date(`${dayKey}T23:59:59+08:00`);

    for (const u of users) {
      try {
        const memberships = await prisma.calendarMember.findMany({ where: { userId: u.id }, select: { calendarId: true } });
        if (memberships.length === 0) continue;
        const events = await prisma.event.findMany({
          where: {
            calendarId: { in: memberships.map((m) => m.calendarId) },
            startsAt: { gte: dayStart, lte: dayEnd },
          },
          orderBy: { startsAt: "asc" },
          take: 5,
        });
        // 外部日曆（.ics 訂閱）今日有活動都提（攞 cache）
        let extCount = 0;
        try {
          const { getExternalEventsForCalendars } = await import("./externals.js");
          const ext = await getExternalEventsForCalendars(prisma, memberships.map((m) => m.calendarId));
          extCount = ext.filter((e) => {
            const d0 = new Date(e.startsAt as unknown as string);
            return d0 >= dayStart && d0 <= dayEnd;
          }).length;
        } catch { /* 外曆掛咗唔影響 digest */ }
        const send = sender ?? (async (p, userId, title, body) => { await sendPushToUser(p, userId, title, body); });
        if (events.length === 0 && extCount === 0) {
          await send(prisma, u.id, "MangoTime", "今日冇行程，好好抖下 ☀️");
        } else if (events.length === 0) {
          await send(prisma, u.id, "今日行程", `今日有 ${extCount} 個外曆活動`);
        } else {
          const first = events[0];
          const time = first.allDay ? "全日" : first.startsAt.toISOString().slice(11, 16);
          const more = events.length > 1 ? ` 等 ${events.length} 個活動` : "";
          const extNote = extCount > 0 ? `（另有 ${extCount} 個外曆活動）` : "";
          await send(prisma, u.id, "今日行程", `${time} ${first.title}${more}${extNote}`);
        }
      } catch (e) {
        console.error("[digest] user", u.id, e);
      }
    }
  }, 30 * 1000); // 30s 掃一次（per-minute granularity 夠用）
}

export function stopDigestLoop() {
  if (timer) { clearInterval(timer); timer = null; }
}
