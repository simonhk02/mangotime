import { useCallback, useEffect, useMemo, useState } from "react";
import EventDetail from "./EventDetail";
import { api, type CalEvent, type Calendar } from "./api";
import EventForm from "./EventForm";
import { lunarShort } from "./lunar";

const WEEKDAYS = ["週日", "週一", "週二", "週三", "週四", "週五", "週六"]; // TimeTree：週日開頭
const COLORS: Record<string, string> = {
  "bright-orange": "#ff7043", emerald: "#10b981", blue: "#3b82f6", red: "#ef4444",
  amber: "#f59e0b", purple: "#a855f7",
};

function sameDay(a: Date, b: Date) {
  return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate();
}

export default function TimeTreeLayout({
  calendars,
  onCalendarsChanged,
}: {
  calendars: Calendar[];
  onCalendarsChanged: () => void;
}) {
  const today = new Date();
  const [cursor, setCursor] = useState(new Date(today.getFullYear(), today.getMonth(), 1));
  const [events, setEvents] = useState<CalEvent[]>([]);
  const [showForm, setShowForm] = useState(false);
  const [selected, setSelected] = useState<CalEvent | null>(null);
  const [searchQ, setSearchQ] = useState("");
  const [formDate, setFormDate] = useState<Date>(today);
  const [activeCal, setActiveCal] = useState<Calendar | null>(calendars[0] ?? null);
  const [hiddenIds, setHiddenIds] = useState<Set<string>>(new Set());
  const [soloId, setSoloId] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!activeCal && calendars[0]) setActiveCal(calendars[0]);
  }, [calendars, activeCal]);

  const visibleIds = useMemo(() => {
    if (soloId) return new Set([soloId]);
    return new Set(calendars.filter((c) => !hiddenIds.has(c.id)).map((c) => c.id));
  }, [calendars, hiddenIds, soloId]);

  const refresh = useCallback(async () => {
    const from = new Date(cursor.getFullYear(), cursor.getMonth(), 1);
    const to = new Date(cursor.getFullYear(), cursor.getMonth() + 1, 0, 23, 59, 59);
    try {
      const all: CalEvent[] = [];
      for (const cal of calendars) {
        if (!visibleIds.has(cal.id)) continue;
        const res = await api.listEvents(cal.id, from.toISOString(), to.toISOString());
        all.push(...res.events);
      }
      setEvents(all);
      setError(null);
    } catch (err) {
      setError(err instanceof Error ? err.message : String(err));
    }
  }, [calendars, cursor, visibleIds]);

  useEffect(() => {
    void refresh();
  }, [refresh]);

  const cells = useMemo(() => {
    const first = new Date(cursor.getFullYear(), cursor.getMonth(), 1);
    const startOffset = first.getDay(); // Sunday-first
    const daysInMonth = new Date(cursor.getFullYear(), cursor.getMonth() + 1, 0).getDate();
    const prevDays = new Date(cursor.getFullYear(), cursor.getMonth(), 0).getDate();
    const list: { date: Date; inMonth: boolean }[] = [];
    for (let i = startOffset - 1; i >= 0; i--) {
      list.push({ date: new Date(cursor.getFullYear(), cursor.getMonth() - 1, prevDays - i), inMonth: false });
    }
    for (let d = 1; d <= daysInMonth; d++) list.push({ date: new Date(cursor.getFullYear(), cursor.getMonth(), d), inMonth: true });
    let next = 1;
    while (list.length % 7 !== 0) list.push({ date: new Date(cursor.getFullYear(), cursor.getMonth() + 1, next++), inMonth: false });
    return list;
  }, [cursor]);

  function eventsFor(day: Date) {
    return events.filter((e) => {
      if (searchQ.trim()) {
        const q = searchQ.trim();
        if (!e.title.includes(q) && !(e.location ?? "").includes(q) && !(e.note ?? "").includes(q)) return false;
      }
      if (!visibleIds.has(e.calendarId)) return false;
      const s = new Date(e.startsAt);
      if (sameDay(s, day)) return true;
      if (e.repeatRule !== "none" && s <= day) {
        if (e.repeatRule === "daily") return true;
        if (e.repeatRule === "weekly") return s.getDay() === day.getDay();
        if (e.repeatRule === "monthly") return s.getDate() === day.getDate();
        if (e.repeatRule === "yearly") return s.getDate() === day.getDate() && s.getMonth() === day.getMonth();
      }
      return false;
    });
  }

  function toggleHidden(id: string) {
    setSoloId(null);
    setHiddenIds((prev) => {
      const next = new Set(prev);
      if (next.has(id)) next.delete(id);
      else next.add(id);
      return next;
    });
  }

  async function addCalendar() {
    const name = window.prompt("新行事曆名稱");
    if (!name?.trim()) return;
    try {
      await api.createCalendar(name.trim());
      onCalendarsChanged();
    } catch (err) {
      setError(String(err));
    }
  }

  return (
    <div className="tt">
      {/* 頂欄 */}
      <header className="tt-top">
        <button className="tt-create" onClick={() => { setFormDate(today); setShowForm(true); }}>＋ 新增活動</button>
        <div className="tt-nav">
          <button onClick={() => setCursor(new Date(cursor.getFullYear(), cursor.getMonth() - 1, 1))}>◀</button>
          <strong>{cursor.getFullYear()}年{cursor.getMonth() + 1}月</strong>
          <button onClick={() => setCursor(new Date(cursor.getFullYear(), cursor.getMonth() + 1, 1))}>▶</button>
          <button className="tt-today" onClick={() => setCursor(new Date(today.getFullYear(), today.getMonth(), 1))}>今日</button>
          <input
            className="tt-search"
            placeholder="搜尋活動…"
            value={searchQ}
            onChange={(e) => setSearchQ(e.target.value)}
          />
        </div>
        <div className="tt-topright">
          <button className="on">月曆</button>
          <button disabled title="Weekly view 之後做">週曆</button>
          <button disabled title="Phase 3.2">🔍</button>
          <button disabled title="設定（之後做）">⚙</button>
        </div>
      </header>

      <div className="tt-body">
        {/* 左側欄：行事曆清單 */}
        <aside className="tt-left">
          <div className="tt-calhead">
            <span>行事曆清單</span>
            <span className="tt-count">行事曆（{calendars.length}）</span>
          </div>
          <div className="tt-tabs"><span className="on">全部</span></div>
          {calendars.map((cal) => {
            const visible = visibleIds.has(cal.id);
            return (
              <div key={cal.id} className={`tt-calcard${visible ? "" : " off"}`}>
                <button
                  className="tt-calname"
                  onClick={() => {
                    setActiveCal(cal);
                    toggleHidden(cal.id);
                  }}
                  title="撳＝顯示/隱藏"
                >
                  <span className="tt-dot" />
                  {cal.name}
                </button>
                <button
                  className={`tt-solo${soloId === cal.id ? " on" : ""}`}
                  title="獨睇呢個"
                  onClick={() => setSoloId(soloId === cal.id ? null : cal.id)}
                >
                  ◎
                </button>
              </div>
            );
          })}
          <button className="tt-addcal" onClick={() => void addCalendar()}>＋ 新增行事曆</button>
        </aside>

        {/* 中間：月曆格 */}
        <main className="tt-main">
          {error && <p className="error">{error}</p>}
          <div className="tt-grid">
            {WEEKDAYS.map((w) => (
              <div key={w} className="tt-weekday">{w}</div>
            ))}
            {cells.map((cell, i) => (
              <div
                key={i}
                className={`tt-cell${cell.inMonth ? "" : " other"}${sameDay(cell.date, today) ? " today" : ""}`}
                onDoubleClick={() => {
                  if (!activeCal) return;
                  setFormDate(cell.date);
                  setShowForm(true);
                }}
                title="雙擊新增活動"
              >
                <div className="tt-dayrow">
                  <span className="tt-day">{cell.date.getDate()}</span>
                  <span className="tt-lunar">{lunarShort(cell.date)}</span>
                </div>
                {eventsFor(cell.date).map((e) => (
                  <div
                    key={e.id}
                    className="tt-event"
                    style={{ background: COLORS[e.labelColor ?? "bright-orange"] ?? COLORS["bright-orange"] }}
                    onClick={() => setSelected(e)}
                    title="撳開詳情"
                  >
                    {e.title}
                  </div>
                ))}
              </div>
            ))}
          </div>
        </main>

        {/* 右邊直欄 */}
        <aside className="tt-right">
          <button disabled title="備忘錄（2.2 做）">📝</button>
          <button disabled title="相簿（2.4 做）">🖼</button>
          <button disabled title="成員（1.3 做）">👥</button>
          <button disabled title="最新動態（2.5 做）">📰</button>
          <button disabled title="通知（2.6 做）">🔔</button>
          <button disabled title="行事曆設定（之後做）">⚙</button>
        </aside>
      </div>

      {showForm && activeCal && (
        <EventForm
          calendar={activeCal}
          defaultDate={formDate}
          calendars={calendars}
          onPickCalendar={(c) => setActiveCal(c)}
          onClose={() => setShowForm(false)}
          onCreated={() => {
            setShowForm(false);
            void refresh();
          }}
        />
      )}
      {selected && (
        <EventDetail
          ev={selected}
          onClose={() => setSelected(null)}
          onChanged={() => { setSelected(null); void refresh(); }}
        />
      )}
    </div>
  );
}