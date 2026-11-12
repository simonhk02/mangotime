// 服務電郵：Resend API（免 SMTP）——有新公告就 email 全體用戶
import type { PrismaClient } from "@prisma/client";

const RESEND_KEY = process.env.RESEND_API_KEY ?? "";
const FROM = process.env.MAIL_FROM ?? "MangoTime <hello@mangotime.149-28-154-219.sslip.io>";

let sender: ((to: string, subject: string, text: string) => Promise<boolean>) | null = null;
export function setEmailSender(f: typeof sender) { sender = f; }

export async function sendEmail(to: string, subject: string, text: string): Promise<boolean> {
  if (sender) return sender(to, subject, text);
  if (!RESEND_KEY) return false;
  try {
    const res = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: { Authorization: `Bearer ${RESEND_KEY}`, "Content-Type": "application/json" },
      body: JSON.stringify({ from: FROM, to: [to], subject, text }),
    });
    return res.ok;
  } catch { return false; }
}

/** 客服表單 → email 俾 admin（references: TimeTree 詢問頁） */
export async function sendSupportEmail(fromEmail: string, category: string, body: string, device: string) {
  const admin = (process.env.ADMIN_EMAILS ?? "simonhk02@gmail.com").split(",")[0];
  return sendEmail(admin, `[MangoTime 客服] ${category}`, `由: ${fromEmail}\n裝置: ${device}\n\n${body}`);
}

/** 公告 → 全體用戶 email（notices.ts 開公告嗰陣叫） */
export async function broadcastNoticeEmail(prisma: PrismaClient, title: string, body: string) {
  const users = await prisma.user.findMany({ select: { email: true } });
  let sent = 0;
  for (const u of users) {
    if (await sendEmail(u.email, `[MangoTime] ${title}`, body)) sent++;
  }
  return sent;
}
