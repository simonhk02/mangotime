import { useEffect, useState } from "react";
import { api, type CalComment, type CalEvent } from "./api";

const LABELS: Record<string, string> = {
  "bright-orange": "#f97316", emerald: "#10b981", blue: "#3b82f6", red: "#ef4444", purple: "#8b5cf6",
};

export default function EventDetail({
  ev, onClose, onChanged,
}: {
  ev: CalEvent;
  onClose: () => void;
  onChanged: () => void;
}) {
  const [comments, setComments] = useState<CalComment[]>([]);
  const [draft, setDraft] = useState("");
  const [editing, setEditing] = useState(false);
  const [title, setTitle] = useState(ev.title);
  const [location, setLocation] = useState(ev.location ?? "");
  const [note, setNote] = useState(ev.note ?? "");

  const load = () => api.listComments(ev.id).then((r) => setComments(r.comments)).catch(() => {});
  useEffect(() => { load(); }, [ev.id]);

  const start = new Date(ev.startsAt);
  const timeStr = ev.allDay
    ? `${start.getMonth() + 1}月${start.getDate()}日 全日`
    : `${start.getMonth() + 1}月${start.getDate()}日 ${String(start.getHours()).padStart(2, "0")}:${String(start.getMinutes()).padStart(2, "0")}`;

  return (
    <div className="tt-modal-back" onClick={onClose}>
      <div className="tt-modal" onClick={(e) => e.stopPropagation()}>
        <div className="tt-modal-head">
          <span className="tt-dot" style={{ background: LABELS[ev.labelColor ?? "bright-orange"] ?? LABELS["bright-orange"] }} />
          {editing ? (
            <input value={title} onChange={(e) => setTitle(e.target.value)} style={{ flex: 1, fontSize: 16, fontWeight: 700 }} />
          ) : (
            <h3 style={{ margin: 0, flex: 1 }}>{ev.title}</h3>
          )}
          <button onClick={onClose} className="tt-x">×</button>
        </div>
        <div className="tt-row">🕐 {timeStr}</div>
        {editing ? (
          <>
            <input placeholder="地點" value={location} onChange={(e) => setLocation(e.target.value)} style={{ width: "100%", marginTop: 6 }} />
            <textarea placeholder="備註" value={note} onChange={(e) => setNote(e.target.value)} style={{ width: "100%", marginTop: 6, minHeight: 60 }} />
          </>
        ) : (
          <>
            {ev.location && <div className="tt-row">📍 {ev.location}</div>}
            {ev.note && <div className="tt-row">📝 {ev.note}</div>}
          </>
        )}
        {ev.repeatRule !== "none" && <div className="tt-row">🔁 {ev.repeatRule}</div>}
        {(ev as any).goingCount != null && <div className="tt-row">👥 {(ev as any).goingCount} 人參加</div>}

        <div className="tt-modal-actions">
          {editing ? (
            <button
              className="primary"
              onClick={async () => {
                await api.updateEvent(ev.id, { title, location: location || null, note: note || null } as any);
                setEditing(false);
                onChanged();
              }}
            >保存</button>
          ) : (
            <button onClick={() => setEditing(true)}>編輯</button>
          )}
          <button
            className="danger"
            onClick={async () => {
              if (!confirm("刪除呢個活動？")) return;
              await api.deleteEvent(ev.id);
              onChanged();
              onClose();
            }}
          >刪除</button>
          <button onClick={async () => { await api.setRsvp(ev.id, "going"); onChanged(); }}>參加 ✓</button>
        </div>

        <div className="tt-comments">
          <div className="tt-comments-title">留言（{comments.length}）</div>
          {comments.map((c) => (
            <div key={c.id} className="tt-comment">
              <b>{c.authorName}</b>
              <span>{c.body}</span>
            </div>
          ))}
          <form
            onSubmit={async (e) => {
              e.preventDefault();
              if (!draft.trim()) return;
              await api.postComment(ev.id, draft.trim());
              setDraft("");
              load();
            }}
          >
            <input placeholder="寫留言…" value={draft} onChange={(e) => setDraft(e.target.value)} />
            <button type="submit" className="primary">送出</button>
          </form>
        </div>
      </div>
    </div>
  );
}
