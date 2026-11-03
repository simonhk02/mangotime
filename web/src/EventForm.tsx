import { useState } from "react";
import { api, type Calendar } from "./api";

// 標籤顏色 — 對照 TimeTree（預設 Bright Orange）
const LABELS: { key: string; name: string; color: string }[] = [
  { key: "bright-orange", name: "Bright Orange", color: "#ff7043" },
  { key: "emerald", name: "Emerald Green", color: "#10b981" },
  { key: "blue", name: "Blue", color: "#3b82f6" },
  { key: "red", name: "Red", color: "#ef4444" },
  { key: "purple", name: "Purple", color: "#a855f7" },
];

export default function EventForm({
  calendar,
  calendars,
  defaultDate,
  onPickCalendar,
  onClose,
  onCreated,
}: {
  calendar: Calendar;
  calendars: Calendar[];
  defaultDate: Date;
  onPickCalendar: (c: Calendar) => void;
  onClose: () => void;
  onCreated: () => void;
}) {
  const [title, setTitle] = useState("");
  const [calId, setCalId] = useState(calendar.id);
  const [saveAsMemo, setSaveAsMemo] = useState(false);
  const [labelColor, setLabelColor] = useState("bright-orange");
  const [showLabels, setShowLabels] = useState(false);
  const [date, setDate] = useState(defaultDate.toISOString().slice(0, 10));
  const [time, setTime] = useState("19:00");
  const [allDay, setAllDay] = useState(false);
  const [repeatRule, setRepeatRule] = useState("none");
  const [location, setLocation] = useState("");
  const [url, setUrl] = useState("");
  const [note, setNote] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  const label = LABELS.find((l) => l.key === labelColor) ?? LABELS[0];

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    if (!title.trim()) return;
    setBusy(true);
    setError(null);
    try {
      const startsAt = allDay ? `${date}T00:00:00` : `${date}T${time}:00`;
      await api.createEvent(calId, {
        title: title.trim(),
        startsAt: new Date(startsAt).toISOString(),
        allDay,
        repeatRule,
        labelColor,
        location: location.trim() || null,
        url: url.trim() || null,
        note: note.trim() || null,
      });
      onCreated();
    } catch (err) {
      setError(err instanceof Error ? err.message : String(err));
      setBusy(false);
    }
  }

  return (
    <div className="modal-backdrop" onClick={onClose}>
      <div className="modal tt-form" onClick={(e) => e.stopPropagation()}>
        <div className="tt-form-head">
          <button className="tt-x" onClick={onClose}>×</button>
          <strong>新增活動</strong>
          <button className="primary" onClick={submit} disabled={busy || !title.trim()}>
            {busy ? "…" : "保存"}
          </button>
        </div>
        <form onSubmit={submit}>
          <input
            className="tt-title"
            placeholder="標題（必填）"
            value={title}
            onChange={(e) => setTitle(e.target.value)}
            autoFocus
          />
          <label className="tt-row">
            <span>📅 行事曆</span>
            <select
              value={calId}
              onChange={(e) => {
                setCalId(e.target.value);
                const c = calendars.find((x) => x.id === e.target.value);
                if (c) onPickCalendar(c);
              }}
            >
              {calendars.map((c) => (
                <option key={c.id} value={c.id}>{c.name}</option>
              ))}
            </select>
          </label>
          <label className="tt-row">
            <span>📄 儲存為備忘錄</span>
            <input type="checkbox" checked={saveAsMemo} onChange={(e) => setSaveAsMemo(e.target.checked)} disabled title="Memo 功能 2.2 開" />
          </label>
          <div className="tt-row">
            <span>🏷 標籤</span>
            <button type="button" className="tt-labelpick" onClick={() => setShowLabels(!showLabels)}>
              <span className="tt-dot" style={{ background: label.color }} /> {label.name} ›
            </button>
          </div>
          {showLabels && (
            <div className="tt-labels">
              {LABELS.map((l) => (
                <button
                  key={l.key}
                  type="button"
                  className={l.key === labelColor ? "on" : ""}
                  onClick={() => {
                    setLabelColor(l.key);
                    setShowLabels(false);
                  }}
                >
                  <span className="tt-dot" style={{ background: l.color }} /> {l.name}
                </button>
              ))}
            </div>
          )}
          <label className="tt-row">
            <span>🕐 日期</span>
            <input type="date" value={date} onChange={(e) => setDate(e.target.value)} required />
          </label>
          <label className="tt-row">
            <span>全日</span>
            <input type="checkbox" checked={allDay} onChange={(e) => setAllDay(e.target.checked)} />
          </label>
          {!allDay && (
            <label className="tt-row">
              <span>時間</span>
              <input type="time" value={time} onChange={(e) => setTime(e.target.value)} />
            </label>
          )}
          <label className="tt-row">
            <span>🔁 重複</span>
            <select value={repeatRule} onChange={(e) => setRepeatRule(e.target.value)}>
              <option value="none">唔重複</option>
              <option value="daily">每日</option>
              <option value="weekly">每週</option>
              <option value="monthly">每月</option>
              <option value="yearly">每年</option>
            </select>
          </label>
          <label className="tt-row">
            <span>📍 地點</span>
            <input value={location} onChange={(e) => setLocation(e.target.value)} />
          </label>
          <label className="tt-row">
            <span>🔗 網址</span>
            <input value={url} onChange={(e) => setUrl(e.target.value)} inputMode="url" />
          </label>
          <label className="tt-row">
            <span>🗒 備註</span>
            <input value={note} onChange={(e) => setNote(e.target.value)} />
          </label>
          {error && <p className="error">{error}</p>}
        </form>
      </div>
    </div>
  );
}
