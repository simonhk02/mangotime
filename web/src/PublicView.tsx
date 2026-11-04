// 公開唯讀月曆頁：/public/:slug（唔使登入）
import { useEffect, useMemo, useState } from "react";
import { lunarShort } from "./lunar";

const API = "https://mangotime-api.149-28-154-219.sslip.io";
const COLORS: Record<string, string> = {
  "bright-orange": "#ff7043", emerald: "#10b981", blue: "#3b82f6", red: "#ef4444",
  amber: "#f59e0b", purple: "#a855f7",
};

type PubEvent = {
  id: string;
  title: string;
  startsAt: string;
  endsAt: string | null;
  allDay: boolean;
  repeatRule: string;
  labelColor: string | null;
  location: string | null;
};

export default function PublicView({ slug }: { slug: string }) {
  const [name, setName] = useState("");
  const [events, setEvents] = useState<PubEvent[]>([]);
  const [error, setError] = useState<string | null>(null);
  const today = new Date();
  const WD = ["週日", "週一", "週二", "週三", "週四", "週五", "週六"];

  useEffect(() => {
    (async () => {
      try {
        const info = await fetch(`${API}/v1/public/${slug}`).then((r) => r.json());
        setName(info.calendar.name);
        const from = new Date(today.getFullYear(), today.getMonth(), 1).toISOString();
        const to = new Date(today.getFullYear(), today.getMonth() + 1, 0, 23, 59, 59).toISOString();
        const ev = await fetch(`${API}/v1/public/${slug}/events?from=${from}&to=${to}`).then((r) => r.json());
        setEvents(ev.events);
      } catch {
        setError("呢個公開行事曆搵唔到（可能已經關閉咗）。");
      }
    })();
  }, [slug]);

  const cells = useMemo(() => {
    const first = new Date(today.getFullYear(), today.getMonth(), 1);
    const off = first.getDay();
    const dim = new Date(today.getFullYear(), today.getMonth() + 1, 0).getDate();
    const prev = new Date(today.getFullYear(), today.getMonth(), 0).getDate();
    const list: { date: Date; other: boolean }[] = [];
    for (let i = off - 1; i >= 0; i--) list.push({ date: new Date(today.getFullYear(), today.getMonth() - 1, prev - i), other: true });
    for (let d = 1; d <= dim; d++) list.push({ date: new Date(today.getFullYear(), today.getMonth(), d), other: false });
    let n = 1;
    while (list.length % 7 !== 0) list.push({ date: new Date(today.getFullYear(), today.getMonth() + 1, n++), other: true });
    return list;
  }, []);

  function eventsFor(day: Date) {
    return events.filter((e) => {
      const s = new Date(e.startsAt);
      const same = s.getFullYear() === day.getFullYear() && s.getMonth() === day.getMonth() && s.getDate() === day.getDate();
      if (same) return true;
      if (e.repeatRule !== "none" && s <= day) {
        if (e.repeatRule === "daily") return true;
        if (e.repeatRule === "weekly") return s.getDay() === day.getDay();
        if (e.repeatRule === "monthly") return s.getDate() === day.getDate();
        if (e.repeatRule === "yearly") return s.getDate() === day.getDate() && s.getMonth() === day.getMonth();
      }
      return false;
    });
  }

  if (error) {
    return (
      <div className="pub-center">
        <div className="pub-logo">🥭</div>
        <p>{error}</p>
      </div>
    );
  }

  return (
    <div className="pub-wrap">
      <header className="pub-head">
        <div className="pub-logo">🥭</div>
        <div>
          <h1>{name}</h1>
          <p className="pub-sub">MangoTime 公開行事曆 · 唯讀</p>
        </div>
      </header>
      <div className="pub-grid">
        {WD.map((w) => <div key={w} className="pub-wd">{w}</div>)}
        {cells.map((c, i) => {
          const isToday = !c.other && c.date.getDate() === today.getDate() && c.date.getMonth() === today.getMonth();
          return (
            <div key={i} className={`pub-cell${c.other ? " other" : ""}${isToday ? " today" : ""}`}>
              <div className="pub-dayrow">
                <span className="pub-day">{c.date.getDate()}</span>
                <span className="pub-lunar">{lunarShort(c.date)}</span>
              </div>
              {eventsFor(c.date).map((e) => (
                <div key={e.id} className="pub-event" style={{ background: COLORS[e.labelColor ?? "bright-orange"] }}>
                  {e.title}
                </div>
              ))}
            </div>
          );
        })}
      </div>
      <footer className="pub-foot">Powered by MangoTime — 一齊夾時間</footer>
      <style>{`
        .pub-wrap { max-width: 860px; margin: 0 auto; padding: 16px; font-family: system-ui; }
        .pub-center { min-height: 60vh; display: grid; place-items: center; text-align: center; font-family: system-ui; }
        .pub-logo { font-size: 40px; }
        .pub-head { display: flex; gap: 12px; align-items: center; padding-bottom: 14px; }
        .pub-head h1 { margin: 0; font-size: 22px; }
        .pub-sub { margin: 0; font-size: 12px; color: #8a94a1; }
        .pub-grid { display: grid; grid-template-columns: repeat(7, 1fr); gap: 1px; background: #e4e7ec; border: 1px solid #e4e7ec; border-radius: 10px; overflow: hidden; }
        .pub-wd { background: #fff; text-align: center; font-size: 11px; font-weight: 600; padding: 6px 0; color: #8a94a1; }
        .pub-cell { background: #fff; min-height: 84px; padding: 4px; }
        .pub-cell.other { opacity: 0.4; background: #fafbfc; }
        .pub-cell.today { outline: 2px solid #ff7043; outline-offset: -2px; }
        .pub-dayrow { display: flex; align-items: baseline; gap: 4px; }
        .pub-day { font-size: 13px; font-weight: 650; }
        .pub-lunar { font-size: 8px; color: #a3acb9; }
        .pub-event { color: #fff; font-size: 10px; padding: 1px 5px; border-radius: 3px; margin-top: 2px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
        .pub-foot { text-align: center; font-size: 11px; color: #a3acb9; padding: 16px 0; }
      `}</style>
    </div>
  );
}
