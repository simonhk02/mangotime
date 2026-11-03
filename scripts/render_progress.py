#!/usr/bin/env python3
"""Render MangoTime PROGRESS.md into a mobile-friendly static HTML dashboard.
Stdlib only. Usage: render_progress.py <progress_md> <out_html>

Design language: TimeTree-inspired — light, airy, rounded white cards,
soft green primary, pastel status chips, phase-grouped, mobile-first."""
import sys, html, datetime, re, zoneinfo

STATUS_ORDER = {"done": 0, "review": 1, "doing": 2, "todo": 3}

def classify(status):
    if "✅" in status: return "done", "✅ 完成"
    if "🟨" in status: return "review", "🟨 待驗收"
    if "🟦" in status: return "doing", "🟦 進行中"
    return "todo", "⬜ 未開始"

def main(md_path, out_path):
    raw = open(md_path, encoding="utf-8").read()
    rows = []
    for line in raw.splitlines():
        line = line.strip()
        if not line.startswith("|"):
            continue
        cells = [c.strip() for c in line.strip("|").split("|")]
        if not cells or all(set(c) <= set("-: ") for c in cells):
            continue
        if cells[0] in ("ID", "id"):
            continue
        rows.append(cells)

    now = datetime.datetime.now(zoneinfo.ZoneInfo("Asia/Hong_Kong"))

    items = []
    for r in rows:
        rid, feat, status = r[0], r[1], r[2]
        note = r[3] if len(r) > 3 else ""
        date = r[4] if len(r) > 4 else ""
        cls, label = classify(status)
        major = rid.split(".")[0] if "." in rid else rid
        items.append(dict(rid=rid, feat=feat, cls=cls, label=label,
                          note=note, date=date, phase=major))

    total = len(items)
    done = sum(1 for i in items if i["cls"] == "done")
    doing = sum(1 for i in items if i["cls"] == "doing")
    review = sum(1 for i in items if i["cls"] == "review")
    pct = round(done / total * 100) if total else 0

    # Group by phase, keeping first-seen order
    phases = []
    for i in items:
        if i["phase"] not in phases:
            phases.append(i["phase"])

    sections = []
    for ph in phases:
        group = [i for i in items if i["phase"] == ph]
        gdone = sum(1 for i in group if i["cls"] == "done")
        cards = []
        for i in group:
            meta = []
            if i["note"]:
                meta.append(f'<div class="note">{html.escape(i["note"])}</div>')
            if i["date"]:
                meta.append(f'<div class="date">📅 {html.escape(i["date"])}</div>')
            cards.append(
                f'<div class="card {i["cls"]}">'
                f'<div class="card-head"><span class="rid">{html.escape(i["rid"])}</span>'
                f'<span class="chip {i["cls"]}">{html.escape(i["label"])}</span></div>'
                f'<div class="feat">{html.escape(i["feat"])}</div>'
                + "".join(meta)
                + "</div>"
            )
        sections.append(
            f'<div class="phase"><div class="phase-head">'
            f'<span class="phase-title">Phase {html.escape(ph)}</span>'
            f'<span class="phase-count">{gdone}/{len(group)}</span></div>'
            + "".join(cards)
            + "</div>"
        )

    page = f"""<!doctype html><html lang="zh-HK"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover">
<meta name="robots" content="noindex,nofollow">
<title>MangoTime 進度表</title><style>
:root{{
  --green:#35a06f; --green-dark:#26825a; --green-soft:#e6f5ee;
  --blue:#3b82d6; --blue-soft:#e8f1fc;
  --amber:#c98a12; --amber-soft:#fdf3e0;
  --gray:#8a8f98; --gray-soft:#f0f1f3;
  --ink:#24292f; --ink-2:#6a707a; --line:#eceee9; --bg:#f6f7f4;
}}
*{{box-sizing:border-box}}
body{{background:var(--bg);color:var(--ink);margin:0;
  font-family:-apple-system,BlinkMacSystemFont,'PingFang HK','PingFang SC','Segoe UI',sans-serif;
  -webkit-font-smoothing:antialiased}}
.wrap{{max-width:640px;margin:0 auto;padding:0 16px 40px}}

.appbar{{background:linear-gradient(135deg,var(--green) 0%,#4db98a 100%);color:#fff;
  padding:calc(14px + env(safe-area-inset-top)) 16px 18px;margin:0 0 18px}}
.appbar .wrap{{padding-bottom:0}}
.appbar h1{{font-size:21px;margin:0;letter-spacing:.3px;display:flex;align-items:center;gap:8px}}
.appbar .sub{{font-size:12.5px;opacity:.88;margin-top:4px}}

.hero{{background:#fff;border-radius:16px;padding:16px 18px;margin-bottom:22px;
  box-shadow:0 1px 2px rgba(30,40,35,.06),0 4px 14px rgba(30,40,35,.05)}}
.hero .pct-row{{display:flex;align-items:baseline;justify-content:space-between;margin-bottom:10px}}
.hero .pct{{font-size:30px;font-weight:700;color:var(--green-dark)}}
.hero .pct small{{font-size:14px;font-weight:500;color:var(--ink-2);margin-left:4px}}
.bar{{height:10px;background:var(--gray-soft);border-radius:999px;overflow:hidden}}
.bar>div{{height:100%;background:linear-gradient(90deg,var(--green),#5cc495);border-radius:999px;
  transition:width .4s ease}}
.counts{{display:flex;gap:8px;flex-wrap:wrap;margin-top:12px}}
.count{{font-size:12.5px;padding:4px 11px;border-radius:999px;font-weight:600}}
.count.done{{background:var(--green-soft);color:var(--green-dark)}}
.count.doing{{background:var(--blue-soft);color:var(--blue)}}
.count.review{{background:var(--amber-soft);color:var(--amber)}}
.count.total{{background:var(--gray-soft);color:var(--ink-2)}}

.phase{{margin-bottom:22px}}
.phase-head{{display:flex;justify-content:space-between;align-items:center;
  margin:0 2px 10px}}
.phase-title{{font-size:13px;font-weight:700;color:var(--ink-2);
  text-transform:uppercase;letter-spacing:.08em}}
.phase-count{{font-size:12.5px;color:var(--gray);font-weight:600}}

.card{{background:#fff;border-radius:14px;padding:13px 15px;margin-bottom:10px;
  box-shadow:0 1px 2px rgba(30,40,35,.05),0 3px 10px rgba(30,40,35,.04);
  border-left:4px solid var(--gray-soft)}}
.card.done{{border-left-color:var(--green)}}
.card.doing{{border-left-color:var(--blue)}}
.card.review{{border-left-color:var(--amber)}}
.card.todo{{opacity:.72}}
.card-head{{display:flex;justify-content:space-between;align-items:center;gap:8px}}
.rid{{font-size:12.5px;font-weight:700;color:var(--gray);font-variant-numeric:tabular-nums}}
.chip{{font-size:11.5px;font-weight:600;padding:3px 10px;border-radius:999px;white-space:nowrap}}
.chip.done{{background:var(--green-soft);color:var(--green-dark)}}
.chip.doing{{background:var(--blue-soft);color:var(--blue)}}
.chip.review{{background:var(--amber-soft);color:var(--amber)}}
.chip.todo{{background:var(--gray-soft);color:var(--gray)}}
.feat{{font-size:15.5px;font-weight:600;margin:7px 0 1px;line-height:1.35}}
.note{{color:var(--ink-2);font-size:12.5px;margin-top:5px;line-height:1.45}}
.date{{color:var(--gray);font-size:12px;margin-top:5px}}

.footer{{text-align:center;color:var(--gray);font-size:11.5px;margin-top:6px}}
</style></head><body>
<div class="appbar"><div class="wrap">
  <h1>🥭 MangoTime 進度表</h1>
  <div class="sub">更新：{now.strftime('%Y-%m-%d %H:%M')} HKT</div>
</div></div>
<div class="wrap">
  <div class="hero">
    <div class="pct-row"><span class="pct">{pct}<small>% 完成</small></span>
      <span class="count total">共 {total} 項</span></div>
    <div class="bar"><div style="width:{pct}%"></div></div>
    <div class="counts">
      <span class="count done">✅ {done} 完成</span>
      <span class="count doing">🟦 {doing} 進行中</span>
      <span class="count review">🟨 {review} 待驗收</span>
    </div>
  </div>
  {''.join(sections)}
  <div class="footer">⬜ 未開始 ｜ 🟦 進行中 ｜ 🟨 待驗收 ｜ ✅ 完成</div>
</div>
</body></html>"""
    open(out_path, "w", encoding="utf-8").write(page)
    print(f"rendered {total} rows ({done} done, {doing} doing, {review} review, {pct}%) -> {out_path}")

if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
