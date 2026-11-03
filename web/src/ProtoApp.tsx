// MangoTime 原型模式 — 全部畫面 static mock，可撳行，唔駛後台。
// 對照 Simon 嘅 TimeTree 參考圖（docs/reference-timetree/）。
import { useMemo, useState } from "react";
import { lunarShort } from "./lunar";

type Screen =
  | "month" | "weekly" | "create" | "eventDetail" | "memos" | "memoDetail" | "todos" | "album"
  | "activity" | "notices" | "members" | "invite" | "settings" | "displaySettings" | "search" | "premium" | "login";

const C = {
  orange: "#ff7043", green: "#10b981", blue: "#3b82f6", red: "#ef4444", purple: "#a855f7",
  ink: "#1a2332", soft: "#8a94a1", line: "#e4e7ec", bg: "#f7f8fa",
};

const MOCK_EVENTS = [
  { id: "1", title: "屋企人飯局", day: 18, color: C.green, loc: "酒樓" },
  { id: "2", title: "珠海兩日一夜", day: 18, color: C.blue, loc: "珠海" },
  { id: "3", title: "打邊爐", day: 19, color: C.red, loc: "屋企" },
  { id: "4", title: "網球", day: 20, color: C.orange, loc: "" },
  { id: "5", title: "阿女家長日", day: 24, color: C.purple, loc: "學校" },
];
const MOCK_MEMOS = [
  { id: "m1", title: "買嘢清單", body: "紙巾、洗衣液、貓糧", color: C.orange },
  { id: "m2", title: "想食嘅餐廳", body: "沙田新開嗰間拉麵", color: C.blue },
];
const MOCK_TODOS = [
  { id: "t1", text: "訂酒樓", done: true },
  { id: "t2", text: "問埋舅父得唔得閒", done: false },
];
const MOCK_MEMBERS = [
  { name: "阿文（我）", role: "建立者", color: C.orange },
  { name: "老婆", role: "成員", color: C.green },
  { name: "阿女", role: "成員", color: C.blue },
];
const MOCK_PHOTOS = ["🍲", "🏖", "🎾", "🎂", "🐱", "🌊", "🍜", "🎁", "🏸"];

function Day({ d, lunar, today, other, events, onNew, onOpen }: {
  d: number; lunar: string; today?: boolean; other?: boolean;
  events: typeof MOCK_EVENTS; onNew: () => void; onOpen: (id: string) => void;
}) {
  return (
    <div className={`p-cell${today ? " today" : ""}${other ? " other" : ""}`} onDoubleClick={onNew}>
      <div className="p-dayrow">
        <span className="p-day">{d}</span>
        <span className="p-lunar">{lunar}</span>
      </div>
      {events.map((e) => (
        <div key={e.id} className="p-event" style={{ background: e.color }} onClick={() => onOpen(e.id)}>{e.title}</div>
      ))}
    </div>
  );
}

export default function ProtoApp() {
  const [screen, setScreen] = useState<Screen>("month");
  const [toast, setToast] = useState("");
  const [openEventId, setOpenEventId] = useState<string | null>(null);
  const [openMemoId, setOpenMemoId] = useState<string | null>(null);

  const today = new Date();
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

  function note(msg: string) {
    setToast(msg);
    setTimeout(() => setToast(""), 1800);
  }

  const Rail = () => (
    <aside className="p-rail">
      {([
        ["📝", "備忘錄", "memos"], ["✅", "待辦", "todos"], ["🖼", "相簿", "album"],
        ["👥", "成員", "members"], ["📰", "最新動態", "activity"], ["🔔", "通知", "notices"], ["⚙", "設定", "settings"],
      ] as const).map(([icon, label, target]) => (
        <button key={target} className={screen === target ? "on" : ""} title={label} onClick={() => setScreen(target as Screen)}>{icon}</button>
      ))}
    </aside>
  );

  const Sidebar = () => (
    <aside className="p-side">
      <div className="p-sidehead">行事曆清單</div>
      <div className="p-tabs"><span className="on">全部</span><span>共享</span><span>公開</span></div>
      <div className="p-cal on">
        <span className="p-dot" style={{ background: C.orange }} />
        <div><b>家庭日曆</b><div className="p-sub">👥 3</div></div>
        <span className="p-solo" title="獨睇">◎</span>
      </div>
      <div className="p-cal" onClick={() => note("工作行事曆（mock）")}>
        <span className="p-dot" style={{ background: C.blue }} />
        <div><b>工作</b><div className="p-sub">👥 2</div></div>
      </div>
      <button className="p-addcal" onClick={() => note("新增行事曆（mock）")}>＋ 新增行事曆</button>
    </aside>
  );

  const Topbar = () => (
    <header className="p-top">
      <button className="p-create" onClick={() => setScreen("create")}>＋ 新增活動</button>
      <div className="p-nav">
        <button>◀</button>
        <b>{today.getFullYear()}年{today.getMonth() + 1}月</b>
        <button>▶</button>
        <button className="p-today">今日</button>
      </div>
      <div className="p-topright">
        <button className="on">月曆</button>
        <button onClick={() => setScreen("weekly")}>週曆</button>
        <button onClick={() => setScreen("search")}>🔍</button>
        <button onClick={() => setScreen("settings")}>⚙</button>
      </div>
    </header>
  );

  return (
    <div className="p-wrap">
      <style>{PROTO_CSS}</style>
      {toast && <div className="p-toast">{toast}</div>}

      {screen === "login" ? (
        <div className="p-login">
          <h1>MangoTime</h1>
          <p>一齊夾時間，一家人一個曆</p>
          <input placeholder="電郵" />
          <input placeholder="密碼" type="password" />
          <button className="p-create" onClick={() => setScreen("month")}>登入</button>
          <button className="p-link" onClick={() => setScreen("month")}>未有帳號？註冊</button>
        </div>
      ) : (
        <>
          <Topbar />
          <div className="p-body">
            <Sidebar />
            <main className="p-main">
              {screen === "month" && (
                <div className="p-grid">
                  {["週日","週一","週二","週三","週四","週五","週六"].map((w) => (
                    <div key={w} className="p-wd">{w}</div>
                  ))}
                  {cells.map((c, i) => (
                    <Day
                      key={i}
                      d={c.date.getDate()}
                      lunar={lunarShort(c.date)}
                      other={c.other}
                      today={!c.other && c.date.getDate() === today.getDate()}
                      events={MOCK_EVENTS.filter((e) => !c.other && e.day === c.date.getDate())}
                      onNew={() => setScreen("create")}
                      onOpen={(id) => { setOpenEventId(id); setScreen("eventDetail"); }}
                    />
                  ))}
                </div>
              )}

              {screen === "weekly" && (
                <div className="p-week">
                  {cells.filter((c) => {
                    const t0 = new Date(today.getFullYear(), today.getMonth(), today.getDate());
                    const ws = new Date(t0); ws.setDate(t0.getDate() - t0.getDay());
                    const we = new Date(ws); we.setDate(ws.getDate() + 6);
                    return c.date >= ws && c.date <= we;
                  }).map((c, i) => (
                    <div key={i} className="p-wcol">
                      <div className="p-wd">{["週日","週一","週二","週三","週四","週五","週六"][c.date.getDay()]} {c.date.getDate()}</div>
                      {MOCK_EVENTS.filter((e) => e.day === c.date.getDate() && !c.other).map((e) => (
                        <div key={e.id} className="p-event" style={{ background: e.color }} onClick={() => { setOpenEventId(e.id); setScreen("eventDetail"); }}>{e.title}</div>
                      ))}
                    </div>
                  ))}
                </div>
              )}

              {screen === "create" && (
                <div className="p-sheet">
                  <div className="p-sheethead">
                    <button onClick={() => setScreen("month")}>×</button>
                    <b>新增活動</b>
                    <button className="p-create" onClick={() => { note("已保存（mock）"); setScreen("month"); }}>保存</button>
                  </div>
                  <input className="p-title" placeholder="標題（必填）" defaultValue="打邊爐" />
                  <div className="p-row"><span>📅 行事曆</span><span>家庭日曆 ›</span></div>
                  <div className="p-row"><span>📄 儲存為備忘錄</span><span className="p-switch off" /></div>
                  <div className="p-row" onClick={() => note("揀標籤色")}><span>🏷 標籤</span><span><i className="p-dot" style={{ background: C.orange }} /> Bright Orange ›</span></div>
                  <div className="p-row"><span>🕐 11月19日（週四）</span><span>19:30 ›</span></div>
                  <div className="p-row"><span>全日</span><span className="p-switch off" /></div>
                  <div className="p-row"><span>🔁 重複</span><span>唔重複 ›</span></div>
                  <div className="p-row"><span>👥 成員</span><span>全部成員 ›</span></div>
                  <div className="p-row"><span>📍 地點</span><input placeholder="未填" /></div>
                  <div className="p-row"><span>🔗 網址</span><input placeholder="未填" /></div>
                  <div className="p-row"><span>🗒 備註</span><input placeholder="未填" /></div>
                  <div className="p-row"><span>☑ 待辦清單</span><span>＋ 新增清單</span></div>
                </div>
              )}

              {screen === "eventDetail" && (() => {
                const ev = MOCK_EVENTS.find((e) => e.id === openEventId) ?? MOCK_EVENTS[0];
                return (
                  <div className="p-sheet">
                    <div className="p-sheethead">
                      <button onClick={() => setScreen("month")}>‹</button>
                      <b>{ev.title}</b>
                      <button className="p-link" onClick={() => note("編輯（mock）")}>編輯</button>
                    </div>
                    <div className="p-row"><span>🕐 11月{ev.day}日（週{["日","一","二","三","四","五","六"][new Date(2026, 10, ev.day).getDay()]}）</span><span>19:00–23:00</span></div>
                    <div className="p-row"><span>🏷 標籤</span><span><i className="p-dot" style={{ background: ev.color }} /> Bright Orange</span></div>
                    {ev.loc && <div className="p-row"><span>📍 地點</span><span>{ev.loc}</span></div>}
                    <div className="p-row"><span>👥 成員</span><span>全部成員</span></div>
                    <div className="p-chat">
                      <div className="p-sub" style={{ marginBottom: 6 }}>留言</div>
                      <div className="p-msg"><b>老婆</b>：買緊嘢食，要乜？</div>
                      <div className="p-msg me"><b>我</b>：沙茶醬幫手攞支</div>
                      <div className="p-chatbar">
                        <input placeholder="留言…" />
                        <button onClick={() => note("貼相（mock）")}>📷</button>
                        <button className="p-create" onClick={() => note("已送出（mock）")}>送出</button>
                      </div>
                    </div>
                    <button className="p-danger" onClick={() => { note("已刪除（mock）"); setScreen("month"); }}>刪除活動</button>
                  </div>
                );
              })()}

              {screen === "memos" && (
                <div className="p-pane">
                  <h3>備忘錄</h3>
                  {MOCK_MEMOS.map((m) => (
                    <div key={m.id} className="p-card" style={{ cursor: "pointer" }} onClick={() => { setOpenMemoId(m.id); setScreen("memoDetail"); }}>
                      <i className="p-dot" style={{ background: m.color }} />
                      <div><b>{m.title}</b><div className="p-sub">{m.body}</div></div>
                    </div>
                  ))}
                  <button className="p-addcal">＋ 新增備忘錄</button>
                </div>
              )}

              {screen === "memoDetail" && (() => {
                const m = MOCK_MEMOS.find((x) => x.id === openMemoId) ?? MOCK_MEMOS[0];
                return (
                  <div className="p-sheet">
                    <div className="p-sheethead">
                      <button onClick={() => setScreen("memos")}>‹</button>
                      <b>{m.title}</b>
                      <button className="p-link" onClick={() => note("編輯（mock）")}>編輯</button>
                    </div>
                    <div className="p-row"><span>🏷 標籤</span><span><i className="p-dot" style={{ background: m.color }} /> 備忘錄</span></div>
                    <div className="p-row"><span>🗒 內容</span><span>{m.body}</span></div>
                    <div className="p-chat">
                      <div className="p-sub" style={{ marginBottom: 6 }}>留言</div>
                      <div className="p-msg"><b>阿女</b>：貓糧要無穀物嗰隻吖</div>
                      <div className="p-chatbar">
                        <input placeholder="留言…" />
                        <button className="p-create" onClick={() => note("已送出（mock）")}>送出</button>
                      </div>
                    </div>
                  </div>
                );
              })()}

              {screen === "todos" && (
                <div className="p-pane">
                  <h3>待辦清單 <span className="p-sub">1/2 已完成</span></h3>
                  {MOCK_TODOS.map((t) => (
                    <div key={t.id} className="p-card">
                      <span className={`p-check${t.done ? " done" : ""}`}>{t.done ? "✓" : ""}</span>
                      <span style={{ textDecoration: t.done ? "line-through" : "none" }}>{t.text}</span>
                    </div>
                  ))}
                  <button className="p-addcal">＋ 新增清單</button>
                </div>
              )}

              {screen === "album" && (
                <div className="p-pane">
                  <h3>相簿</h3>
                  <div className="p-photos">
                    {MOCK_PHOTOS.map((p, i) => <div key={i} className="p-photo">{p}</div>)}
                    <button className="p-photo add">＋</button>
                  </div>
                </div>
              )}

              {screen === "activity" && (
                <div className="p-pane">
                  <div className="p-tabs"><span className="on">行程</span><span>相簿</span></div>
                  <div className="p-card"><b>阿文</b> 新增咗「打邊爐」<div className="p-sub">10 分鐘前</div></div>
                  <div className="p-card"><b>老婆</b> 改咗「屋企人飯局」時間<div className="p-sub">2 小時前</div></div>
                  <div className="p-card"><b>阿女</b> 喺相簿上傳咗 3 張相<div className="p-sub">昨日</div></div>
                </div>
              )}

              {screen === "notices" && (
                <div className="p-pane">
                  <h3>通知</h3>
                  <div className="p-card">🔔 聽日 19:00「屋企人飯局」<div className="p-sub">提醒</div></div>
                  <div className="p-card">👥 阿女接受咗你嘅邀請<div className="p-sub">昨日</div></div>
                </div>
              )}

              {screen === "members" && (
                <div className="p-pane">
                  <h3>成員（3）</h3>
                  {MOCK_MEMBERS.map((m) => (
                    <div key={m.name} className="p-card">
                      <span className="p-avatar" style={{ background: m.color }}>{m.name[0]}</span>
                      <div><b>{m.name}</b><div className="p-sub">{m.role}</div></div>
                    </div>
                  ))}
                  <button className="p-addcal" onClick={() => setScreen("invite")}>＋ 邀請成員（連結）</button>
                </div>
              )}

              {screen === "invite" && (
                <div className="p-pane">
                  <h3>邀請成員</h3>
                  <p className="p-sub">任何人撳呢條連結就入到「家庭日曆」：</p>
                  <div className="p-invitelink">
                    <code>mangotime.app/join/FAM-8X3K</code>
                    <button className="p-create" onClick={() => note("已複製連結（mock）")}>複製</button>
                  </div>
                  <div className="p-qr">▦▦▦<br/>▦ QR ▦<br/>▦▦▦</div>
                  <p className="p-sub">或者俾佢掃 QR code</p>
                  <button className="p-link" onClick={() => note("WhatsApp 分享（mock）")}>經 WhatsApp 送出 ›</button>
                </div>
              )}

              {screen === "settings" && (
                <div className="p-pane">
                  <h3>App 設定</h3>
                  <div className="p-row" onClick={() => setScreen("displaySettings")}><span>🖥 顯示設定</span><span>›</span></div>
                  {["語言：中文","節日：香港","通知時間：09:00"].map((s) => (
                    <div key={s} className="p-row"><span>{s.split("：")[0]}</span><span>{s.split("：")[1]} ›</span></div>
                  ))}
                  <div className="p-row" onClick={() => setScreen("premium")}><span>⭐ TimeTree Premium</span><span>›</span></div>
                </div>
              )}

              {screen === "displaySettings" && (
                <div className="p-pane">
                  <div className="p-sheethead">
                    <button onClick={() => setScreen("settings")}>‹</button>
                    <b>顯示設定</b>
                    <span />
                  </div>
                  <div className="p-row"><span>一週嘅開始</span><span>週一 ›</span></div>
                  <div className="p-row"><span>第幾週</span><span className="p-switch off" /></div>
                  <div className="p-row"><span>農曆顯示</span><span className="p-switch on" /></div>
                  <div className="p-row"><span>節日</span><span>香港 ›</span></div>
                  <div className="p-row"><span>24 小時制</span><span className="p-switch on" /></div>
                </div>
              )}

              {screen === "search" && (
                <div className="p-pane">
                  <h3>🔍 搜尋活動</h3>
                  <input className="p-title" placeholder="關鍵字…" />
                  <p className="p-sub">指定行程參加者或標籤，即可篩選。搜尋結果將顯示於此。</p>
                </div>
              )}

              {screen === "premium" && (
                <div className="p-pane">
                  <h3>⭐ MangoTime Premium</h3>
                  <div className="p-card"><b>月付 HK$23</b><div className="p-sub">無廣告 · 上傳檔案 · 更多標籤色</div></div>
                  <button className="p-create" onClick={() => note("收費唔係而家嘅事 😄")}>免費使用 1 個月</button>
                </div>
              )}
            </main>
            <Rail />
          </div>
        </>
      )}
    </div>
  );
}

const PROTO_CSS = `
.p-wrap { font-family: system-ui, sans-serif; color: #1a2332; background: #f7f8fa; min-height: 100vh; position: relative; }
.p-toast { position: fixed; top: 12px; left: 50%; transform: translateX(-50%); background: #1a2332; color: #fff; padding: 6px 14px; border-radius: 8px; font-size: 13px; z-index: 50; }
.p-top { display: flex; align-items: center; gap: 12px; padding: 8px 14px; background: #fff; border-bottom: 1px solid #e4e7ec; }
.p-create { background: #ff7043; color: #fff; border: none; border-radius: 8px; padding: 7px 14px; font-weight: 600; cursor: pointer; }
.p-nav { display: flex; align-items: center; gap: 6px; }
.p-nav b { min-width: 110px; text-align: center; }
.p-nav button, .p-topright button, .p-today { border: 1px solid #e4e7ec; background: #fff; border-radius: 7px; padding: 5px 10px; cursor: pointer; }
.p-topright { margin-left: auto; display: flex; gap: 6px; }
.p-topright .on { background: #1a2332; color: #fff; }
.p-body { display: grid; grid-template-columns: 230px 1fr 54px; min-height: calc(100vh - 52px); }
.p-side { border-right: 1px solid #e4e7ec; background: #fff; padding: 12px; }
.p-sidehead { font-weight: 700; font-size: 14px; }
.p-tabs { display: flex; gap: 12px; font-size: 12.5px; margin: 8px 0; color: #8a94a1; }
.p-tabs .on { color: #ff7043; font-weight: 700; border-bottom: 2px solid #ff7043; }
.p-cal { display: flex; align-items: center; gap: 8px; padding: 8px 6px; border-radius: 8px; cursor: pointer; }
.p-cal.on { background: #fff3ee; }
.p-dot { width: 10px; height: 10px; border-radius: 50%; display: inline-block; flex: none; font-style: normal; }
.p-sub { font-size: 11.5px; color: #8a94a1; }
.p-solo { margin-left: auto; color: #ff7043; }
.p-addcal { width: 100%; margin-top: 8px; border: 1px dashed #e4e7ec; color: #ff7043; background: none; border-radius: 8px; padding: 8px; font-weight: 600; cursor: pointer; }
.p-main { padding: 10px 14px; overflow: auto; }
.p-grid { display: grid; grid-template-columns: repeat(7, 1fr); gap: 1px; background: #e4e7ec; border: 1px solid #e4e7ec; border-radius: 8px; overflow: hidden; }
.p-wd { background: #fff; text-align: center; font-size: 12px; font-weight: 600; padding: 6px 0; color: #8a94a1; }
.p-cell { background: #fff; min-height: 84px; padding: 4px 5px; }
.p-cell.other { background: #fafbfc; opacity: 0.45; }
.p-cell.today { outline: 2px solid #ff7043; outline-offset: -2px; }
.p-dayrow { display: flex; align-items: baseline; gap: 5px; }
.p-day { font-weight: 650; font-size: 14px; }
.p-lunar { font-size: 9.5px; color: #a3acb9; }
.p-event { color: #fff; font-size: 11px; padding: 1px 6px; border-radius: 4px; margin-top: 2px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.p-rail { border-left: 1px solid #e4e7ec; background: #fff; display: flex; flex-direction: column; align-items: center; padding-top: 12px; gap: 10px; }
.p-rail button { border: none; background: none; font-size: 19px; opacity: 0.55; cursor: pointer; padding: 6px; border-radius: 8px; }
.p-rail button.on { opacity: 1; background: #fff3ee; }
.p-sheet { max-width: 480px; margin: 14px auto; background: #fff; border: 1px solid #e4e7ec; border-radius: 12px; padding: 14px 16px; }
.p-sheethead { display: flex; justify-content: space-between; align-items: center; margin-bottom: 8px; }
.p-sheethead button { border: none; background: none; font-size: 20px; cursor: pointer; }
.p-title { width: 100%; border: none; border-bottom: 1px solid #e4e7ec; font-size: 16px; font-weight: 600; padding: 8px 0; margin-bottom: 6px; }
.p-row { display: flex; justify-content: space-between; align-items: center; padding: 9px 0; border-bottom: 1px solid #f0f2f5; font-size: 14px; }
.p-row input { border: none; text-align: right; color: #8a94a1; }
.p-switch { width: 38px; height: 22px; border-radius: 11px; background: #e4e7ec; position: relative; display: inline-block; }
.p-switch.off::after { content: ""; position: absolute; left: 2px; top: 2px; width: 18px; height: 18px; border-radius: 50%; background: #fff; }
.p-pane { max-width: 560px; margin: 16px auto; background: #fff; border: 1px solid #e4e7ec; border-radius: 12px; padding: 16px 18px; }
.p-pane h3 { margin-top: 0; }
.p-card { display: flex; gap: 10px; align-items: center; padding: 10px 4px; border-bottom: 1px solid #f0f2f5; font-size: 14px; }
.p-avatar { width: 34px; height: 34px; border-radius: 50%; color: #fff; display: grid; place-items: center; font-weight: 700; }
.p-check { width: 20px; height: 20px; border: 2px solid #e4e7ec; border-radius: 6px; display: inline-grid; place-items: center; color: #fff; font-size: 12px; }
.p-check.done { background: #10b981; border-color: #10b981; }
.p-photos { display: grid; grid-template-columns: repeat(3, 1fr); gap: 8px; }
.p-photo { aspect-ratio: 1; background: #f0f2f5; border-radius: 10px; display: grid; place-items: center; font-size: 34px; }
.p-photo.add { font-size: 24px; color: #ff7043; cursor: pointer; border: 1px dashed #e4e7ec; background: #fff; }
.p-login { max-width: 320px; margin: 12vh auto; background: #fff; padding: 28px; border-radius: 14px; border: 1px solid #e4e7ec; display: grid; gap: 10px; text-align: center; }
.p-login input { padding: 10px; border: 1px solid #e4e7ec; border-radius: 8px; }
.p-link { border: none; background: none; color: #ff7043; cursor: pointer; }
.p-week { display: grid; grid-template-columns: repeat(7, 1fr); gap: 8px; }
.p-wcol { background: #fff; border: 1px solid #e4e7ec; border-radius: 10px; min-height: 300px; padding: 8px; }
.p-wcol .p-wd { margin-bottom: 6px; }
.p-chat { margin-top: 12px; border-top: 1px solid #f0f2f5; padding-top: 10px; }
.p-msg { background: #f0f2f5; border-radius: 10px; padding: 7px 10px; margin-bottom: 6px; font-size: 13.5px; }
.p-msg.me { background: #fff3ee; }
.p-chatbar { display: flex; gap: 6px; margin-top: 8px; }
.p-chatbar input { flex: 1; border: 1px solid #e4e7ec; border-radius: 8px; padding: 8px; }
.p-danger { margin-top: 14px; width: 100%; border: 1px solid #ef4444; color: #ef4444; background: none; border-radius: 8px; padding: 9px; cursor: pointer; }
.p-invitelink { display: flex; gap: 8px; align-items: center; background: #f7f8fa; border: 1px solid #e4e7ec; border-radius: 8px; padding: 10px 12px; }
.p-invitelink code { flex: 1; font-size: 13px; }
.p-qr { text-align: center; font-size: 22px; letter-spacing: 4px; color: #1a2332; margin: 14px 0 4px; }
.p-switch.on { background: #10b981; }
.p-switch.on::after { left: auto; right: 2px; }
`;
