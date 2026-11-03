import { useCallback, useEffect, useState } from "react";
import { api, type Calendar } from "./api";

export default function CalendarList() {
  const [calendars, setCalendars] = useState<Calendar[]>([]);
  const [newName, setNewName] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  const refresh = useCallback(async () => {
    try {
      const res = await api.listCalendars();
      setCalendars(res.calendars);
    } catch (err) {
      setError(err instanceof Error ? err.message : String(err));
    }
  }, []);

  useEffect(() => {
    void refresh();
  }, [refresh]);

  async function create(e: React.FormEvent) {
    e.preventDefault();
    if (!newName.trim()) return;
    setBusy(true);
    setError(null);
    try {
      await api.createCalendar(newName.trim());
      setNewName("");
      await refresh();
    } catch (err) {
      setError(err instanceof Error ? err.message : String(err));
    } finally {
      setBusy(false);
    }
  }

  async function rename(cal: Calendar) {
    const name = window.prompt("改日曆名稱", cal.name);
    if (!name?.trim() || name.trim() === cal.name) return;
    try {
      await api.renameCalendar(cal.id, name.trim());
      await refresh();
    } catch (err) {
      setError(err instanceof Error ? err.message : String(err));
    }
  }

  async function remove(cal: Calendar) {
    if (!window.confirm(`確定刪除「${cal.name}」？呢個動作唔可以還原。`)) return;
    try {
      await api.deleteCalendar(cal.id);
      await refresh();
    } catch (err) {
      setError(err instanceof Error ? err.message : String(err));
    }
  }

  return (
    <section className="calendars">
      <h2>我嘅日曆</h2>
      <form onSubmit={create} className="create-cal">
        <input
          placeholder="新日曆名稱…"
          value={newName}
          onChange={(e) => setNewName(e.target.value)}
        />
        <button type="submit" disabled={busy || !newName.trim()}>
          建立
        </button>
      </form>
      {error && <p className="error">{error}</p>}
      {calendars.length === 0 && <p className="muted">仲未有日曆，開一個啦。</p>}
      <ul>
        {calendars.map((cal) => (
          <li key={cal.id}>
            <span className="cal-name">{cal.name}</span>
            <span className="muted">
              {cal.memberCount ?? 1} 位成員{cal.myRole === "creator" && " · 我係建立者"}
            </span>
            {cal.myRole === "creator" && (
              <span className="actions">
                <button onClick={() => void rename(cal)}>改名</button>
                <button className="danger" onClick={() => void remove(cal)}>
                  刪除
                </button>
              </span>
            )}
          </li>
        ))}
      </ul>
    </section>
  );
}
