// MangoTime iOS 原型 — 對照 TimeTree iPhone app（docs/reference-timetree/）。
// 全部畫面 static mock，可撳行，唔掂後台。底部 tab bar：行事曆/最新動態/＋/通知/其他。
import { useMemo, useState } from "react";
import { lunarShort } from "./lunar";

type Screen =
  | "splash" | "month" | "weekly" | "create" | "eventDetail" | "noteEdit" | "memos" | "memosEmpty" | "memoDetail"
  | "todos" | "album" | "feed" | "notices" | "other" | "profile" | "calendarList"
  | "members" | "invite" | "settings" | "displaySettings" | "filterSettings" | "displayCalendar"
  | "notifSettings" | "noticeBoard" | "noticeDetail" | "search" | "premium" | "premiumDetail" | "login"
  | "helpHome" | "helpCategory" | "helpArticle" | "faq" | "contact" | "userGuide" | "monthPicker";

const C = {
  orange: "#ff7043", green: "#10b981", blue: "#3b82f6", red: "#ef4444", purple: "#a855f7",
  ink: "#1a2332", soft: "#8a94a1", line: "#e4e7ec", bg: "#f7f8fa",
};

const MOCK_EVENTS: { id: string; title: string; day: number; color: string; loc: string; time: string; attach?: number }[] = [
  { id: "1", title: "屋企人飯局", day: 18, color: C.green, loc: "酒樓", time: "19:00–22:00" },
  { id: "2", title: "珠海兩日一夜", day: 18, color: C.blue, loc: "珠海", time: "全日", attach: 2 },
  { id: "3", title: "打邊爐", day: 19, color: C.red, loc: "屋企", time: "19:30–23:00" },
  { id: "4", title: "網球", day: 20, color: C.orange, loc: "", time: "08:00–10:00" },
  { id: "5", title: "阿女家長日", day: 24, color: C.purple, loc: "學校", time: "14:00–16:00" },
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
const LABELS = [
  { name: "Bright Orange", color: C.orange }, { name: "Emerald Green", color: C.green },
  { name: "Blue", color: C.blue }, { name: "Red", color: C.red }, { name: "Purple", color: C.purple },
];
const WD = ["週日", "週一", "週二", "週三", "週四", "週五", "週六"];

// 幫助中心資料（對照 IMG_4703–4728）
const HELP_CATS = [
  { icon: "🌱", name: "給初次使用者", arts: ["想知道共享日曆的各功能（應用程序版）", "行程未被共享", "希望定期收到通知"] },
  { icon: "👤", name: "帳戶管理", arts: ["想要註冊帳號", "因變更機型而希望繼承數據", "登入帳戶並使用現有資料", "想要從所有裝置登出", "我要刪除帳號／退出服務"] },
  { icon: "📝", name: "創建/編輯事件", arts: ["想從圖片建立行程（掃描圖片）", "複製/刪除/編輯計劃", "輕鬆登錄行程", "每週〇曜日的行程登錄方法（重複設定）"] },
  { icon: "📅", name: "關於日曆", arts: ["希望以時間單位顯示預定（垂直顯示）", "希望減少通知頻率（每天一次彙總通知）", "我想更改顏色"] },
  { icon: "⚙️", name: "各種應用程序設置", arts: ["通知不到", "我想更改語言", "想了解通知的種類與頻率", "希望自動輸入標題"] },
  { icon: "🛠", name: "實際使用", arts: ["想要新增或刪除相簿中的照片", "搜尋行程", "我要登錄或查看備忘錄"] },
  { icon: "🔗", name: "將TimeTree與其他日曆一起使用", arts: ["想使用其他日曆（例如 Google 日曆）"] },
  { icon: "🩹", name: "解決問題", arts: ["小工具未顯示行程", "顯示錯誤", "行事消失", "無法查看"] },
  { icon: "💬", name: "其他話題", arts: ["關於聯絡客服的方法", "關於支援版本（OS/應用程式）"] },
  { icon: "🌍", name: "關於公開行事曆［管理員］", arts: ["［管理者］取得公開行事曆中活動的二維碼並刊載於印刷品"] },
];

const ARTICLE_BODY: Record<string, string[]> = {
  "小工具未顯示行程": ["請確認以下內容", "iOS / Android：確認行事曆已開啟同步", "確認小工具揀咗正確行事曆", "重新開機後再試"],
  "因變更機型而希望繼承數據": ["為您介紹更換智能手機機型所需的步驟。", "1. 舊機：確認已註冊帳號並登入", "2. 新機：安裝 MangoTime 並登入同一帳號", "3. 資料會自動同步"],
  "登入帳戶並使用現有資料": ["iOS / Android：喺登入頁輸入已註冊嘅電郵同密碼，即可沿用現有行事曆資料。"],
  "每週〇曜日的行程登錄方法（重複設定）": ["新增活動 →「重複」→ 揀「每週」→ 揀星期幾。可以隨時單次修改或整個系列修改。"],
  "想使用其他日曆（例如 Google 日曆）": ["設定 →「外部日曆」→ 連結 Google 帳戶。Google 日曆嘅行程會以唯讀方式顯示。"],
  "行程未被共享": ["1. 行程登錄者登錄在「其他行事曆」上", "解決方法：請對方確認行程所屬行事曆，並確認你已加入該行事曆。"],
  "我要刪除帳號／退出服務": ["帳號刪除、退出操作後將無法復原。退出操作後的資料將被完全刪除。"],
  "搜尋行程": ["在『主行事曆』中，您加入的所有共享行事曆都將納入搜尋範圍。指定參加者或標籤可篩選。"],
  "我要登錄或查看備忘錄": ["可作為簡單備忘錄、購物清單、想去的地方清單、待辦事項等使用。每條備忘錄都可以留言。"],
  "想要新增或刪除相簿中的照片": ["相簿 → ＋上傳；長按照片可刪除。上傳檔案屬 Premium 功能。"],
};

export default function ProtoApp() {
  const [screen, setScreen] = useState<Screen>("splash");
  const [toast, setToast] = useState("");
  const [openEventId, setOpenEventId] = useState<string | null>(null);
  const [openMemoId, setOpenMemoId] = useState<string | null>(null);
  const [showLabelPicker, setShowLabelPicker] = useState(false);
  const [lunarOn, setLunarOn] = useState(true);
  const [weekStart, setWeekStart] = useState(1); // 0=週日 1=週一
  const [settingsTab, setSettingsTab] = useState<"設定" | "支援">("設定");
  const [feedTab, setFeedTab] = useState<"行程" | "相簿">("行程");
  const [helpCat, setHelpCat] = useState(HELP_CATS[0]);
  const [article, setArticle] = useState("");
  const [upsell, setUpsell] = useState(false); // Premium 上傳檔案彈窗
  const [photoPerm, setPhotoPerm] = useState(false); // 相片權限彈窗
  const [calPicker, setCalPicker] = useState<string[]>(["家庭日曆"]);

  const today = new Date();
  const cells = useMemo(() => {
    const first = new Date(today.getFullYear(), today.getMonth(), 1);
    const off = (first.getDay() - weekStart + 7) % 7;
    const dim = new Date(today.getFullYear(), today.getMonth() + 1, 0).getDate();
    const prev = new Date(today.getFullYear(), today.getMonth(), 0).getDate();
    const list: { date: Date; other: boolean }[] = [];
    for (let i = off - 1; i >= 0; i--) list.push({ date: new Date(today.getFullYear(), today.getMonth() - 1, prev - i), other: true });
    for (let d = 1; d <= dim; d++) list.push({ date: new Date(today.getFullYear(), today.getMonth(), d), other: false });
    let n = 1;
    while (list.length % 7 !== 0) list.push({ date: new Date(today.getFullYear(), today.getMonth() + 1, n++), other: true });
    return list;
  }, [weekStart]);

  const weekdays = useMemo(() => Array.from({ length: 7 }, (_, i) => WD[(weekStart + i) % 7]), [weekStart]);

  function note(msg: string) {
    setToast(msg);
    setTimeout(() => setToast(""), 1800);
  }

  function openEvent(id: string) {
    setOpenEventId(id);
    setScreen("eventDetail");
  }

  const ev = MOCK_EVENTS.find((e) => e.id === openEventId) ?? MOCK_EVENTS[0];
  const memo = MOCK_MEMOS.find((m) => m.id === openMemoId) ?? MOCK_MEMOS[0];
  const evDate = new Date(2026, 10, ev.day);

  // ---------- 共用件 ----------
  const StatusBar = () => (
    <div className="m-status"><span>9:41</span><span>📶 📶 🔋</span></div>
  );

  const NavBar = ({ title, left, right }: { title: string; left?: React.ReactNode; right?: React.ReactNode }) => (
    <div className="m-nav">
      <div className="m-navside">{left}</div>
      <b>{title}</b>
      <div className="m-navside right">{right}</div>
    </div>
  );

  const Row = ({ label, value, onClick, toggle }: { label: string; value?: React.ReactNode; onClick?: () => void; toggle?: boolean }) => (
    <div className="m-row" onClick={onClick}>
      <span>{label}</span>
      {toggle !== undefined ? <span className={`m-switch${toggle ? " on" : ""}`} /> : <span className="m-val">{value}</span>}
    </div>
  );

  const Chat = ({ msgs }: { msgs: { who: string; text: string; me?: boolean }[] }) => (
    <div className="m-chat">
      <div className="m-chathead">留言</div>
      {msgs.map((m, i) => (
        <div key={i} className={`m-msg${m.me ? " me" : ""}`}><b>{m.who}</b>：{m.text}</div>
      ))}
      <div className="m-chatbar">
        <input placeholder="留言…" />
        <button onClick={() => note("貼相（mock）")}>📷</button>
        <button className="m-send" onClick={() => note("已送出（mock）")}>送出</button>
      </div>
    </div>
  );

  const Sheet = ({ title, onBack, backText, right, children }: {
    title: string; onBack: () => void; backText?: string; right?: React.ReactNode; children: React.ReactNode;
  }) => (
    <div className="m-sheet">
      <NavBar title={title} left={<button className="m-back" onClick={onBack}>{backText ?? "‹"}</button>} right={right} />
      <div className="m-scroll">{children}</div>
    </div>
  );

  const Tabs = () => (
    <nav className="m-tabs">
      <button className={screen === "month" || screen === "weekly" || screen === "eventDetail" ? "on" : ""} onClick={() => setScreen("month")}>
        📅<span>行事曆</span>
      </button>
      <button className={screen === "feed" ? "on" : ""} onClick={() => setScreen("feed")}>
        📰<span>最新動態</span>
      </button>
      <button className="m-plus" onClick={() => setScreen("create")}>＋</button>
      <button className={screen === "notices" ? "on" : ""} onClick={() => setScreen("notices")}>
        🔔<span>通知</span>
      </button>
      <button className={screen === "other" || screen === "settings" || screen === "premium" || screen === "profile" || screen === "displaySettings" || screen === "filterSettings" || screen === "notifSettings" || screen === "noticeBoard" || screen === "calendarList" ? "on" : ""} onClick={() => setScreen("other")}>
        ☰<span>其他</span>
      </button>
    </nav>
  );

  // ---------- 畫面 ----------
  const MonthView = (
    <>
      <NavBar
        title={`${today.getFullYear()}年${today.getMonth() + 1}月 ～`}
        left={<button className="m-back" onClick={() => setScreen("calendarList")}>家庭日曆 ▾</button>}
        right={<>
          <button className="m-icon" onClick={() => setScreen("search")}>🔍</button>
          <button className="m-icon" onClick={() => setScreen("monthPicker")}>▾</button>
        </>
        }
      />
      <div className="m-prembar" onClick={() => setScreen("premiumDetail")}>
        ⭐ MangoTime Premium　<span>無廣告・上傳檔案 ›</span>
      </div>
      <div className="m-seg">
        <button className={screen === "month" ? "on" : ""} onClick={() => setScreen("month")}>月曆</button>
        <button className={screen === "weekly" ? "on" : ""} onClick={() => setScreen("weekly")}>週曆</button>
      </div>
      {screen === "month" && (
        <div className="m-grid">
          {weekdays.map((w) => <div key={w} className="m-wd">{w}</div>)}
          {cells.map((c, i) => (
            <div
              key={i}
              className={`m-cell${c.other ? " other" : ""}${!c.other && c.date.getDate() === today.getDate() ? " today" : ""}`}
              onClick={() => openEvent(MOCK_EVENTS.find((e) => !c.other && e.day === c.date.getDate())?.id ?? "1")}
            >
              <div className="m-dayrow">
                <span className="m-day">{c.date.getDate()}</span>
                {lunarOn && <span className="m-lunar">{lunarShort(c.date)}</span>}
              </div>
              {MOCK_EVENTS.filter((e) => !c.other && e.day === c.date.getDate()).map((e) => (
                <div key={e.id} className="m-event" style={{ background: e.color }}>{e.title}{e.attach ? ` 📎${e.attach}` : ""}</div>
              ))}
            </div>
          ))}
        </div>
      )}
      {screen === "weekly" && (
        <div className="m-week">
          {cells.filter((c) => {
            const t0 = new Date(today.getFullYear(), today.getMonth(), today.getDate());
            const ws = new Date(t0); ws.setDate(t0.getDate() - ((t0.getDay() - weekStart + 7) % 7));
            const we = new Date(ws); we.setDate(ws.getDate() + 6);
            return c.date >= ws && c.date <= we;
          }).map((c, i) => (
            <div key={i} className="m-wcol" onClick={() => openEvent(MOCK_EVENTS.find((e) => e.day === c.date.getDate() && !c.other)?.id ?? "1")}>
              <div className="m-wd">{WD[c.date.getDay()]} {c.date.getDate()}</div>
              {MOCK_EVENTS.filter((e) => e.day === c.date.getDate() && !c.other).map((e) => (
                <div key={e.id} className="m-event" style={{ background: e.color }}>{e.title}</div>
              ))}
            </div>
          ))}
        </div>
      )}
    </>
  );

  const inApp = screen !== "login";

  return (
    <div className="m-stage">
      <style>{PROTO_CSS}</style>
      <div className="m-phone">
        {toast && <div className="m-toast">{toast}</div>}
        <StatusBar />

        {screen === "splash" && (
          <div className="m-splash" onClick={() => setScreen("login")}>
            <div className="m-logo">🥭</div>
            <h1>MangoTime</h1>
            <p>一齊夾時間</p>
            <div className="m-sub">撳任何地方開始 ›</div>
          </div>
        )}

        {screen === "login" && (
          <div className="m-login">
            <h1>MangoTime</h1>
            <p>一齊夾時間，一家人一個曆</p>
            <input placeholder="電郵" />
            <input placeholder="密碼" type="password" />
            <button className="m-cta" onClick={() => setScreen("month")}>登入</button>
            <button className="m-ghost" onClick={() => setScreen("month")}>未有帳號？註冊</button>
            <div className="m-or">或</div>
            <button className="m-ghost">🍎 使用 Apple 登入</button>
            <button className="m-ghost">G 使用 Google 登入</button>
          </div>
        )}

        {(screen === "month" || screen === "weekly") && inApp && MonthView}

        {screen === "calendarList" && (
          <Sheet title="行事曆清單" onBack={() => setScreen("month")} right={<button className="m-icon" onClick={() => note("新增行事曆（mock）")}>＋</button>}>
            <div className="m-seg">
              <button className="on">全部</button><button>共享</button><button>公開</button>
            </div>
            <div className="m-calcard on">
              <span className="m-dot" style={{ background: C.orange }} />
              <div><b>家庭日曆</b><div className="m-sub">行事曆（5）· 👥 3</div></div>
              <span className="m-solo">◎</span>
            </div>
            <div className="m-calcard" onClick={() => note("工作行事曆（mock）")}>
              <span className="m-dot" style={{ background: C.blue }} />
              <div><b>工作</b><div className="m-sub">行事曆（2）· 👥 2</div></div>
            </div>
            <div className="m-calcard" onClick={() => note("公開行事曆（mock）")}>
              <span className="m-dot" style={{ background: C.green }} />
              <div><b>香港公眾假期</b><div className="m-sub">公開 · 訂閱中</div></div>
            </div>
            <button className="m-cta light">＋ 新增行事曆</button>
          </Sheet>
        )}

        {screen === "create" && (
          <Sheet title="新增活動" onBack={() => setScreen("month")} backText="×" right={<button className="m-cta sm" onClick={() => { note("已保存（mock）"); setScreen("month"); }}>保存</button>}>
            <input className="m-title" placeholder="標題（必填）" defaultValue="打邊爐" />
            <Row label="📅 行事曆" value="家庭日曆 ›" onClick={() => note("揀行事曆（mock）")} />
            <Row label="📄 儲存為備忘錄" toggle={false} onClick={() => note("Memo 功能（mock）")} />
            <Row label="🏷 標籤" value={<><i className="m-dot" style={{ background: C.orange }} /> Bright Orange ›</>} onClick={() => setShowLabelPicker(!showLabelPicker)} />
            {showLabelPicker && (
              <div className="m-labels">
                {LABELS.map((l) => (
                  <div key={l.name} className="m-row" onClick={() => { setShowLabelPicker(false); note(`已揀 ${l.name}`); }}>
                    <span><i className="m-dot" style={{ background: l.color }} /> {l.name}</span>
                  </div>
                ))}
              </div>
            )}
            <Row label="🕐 日期" value="11月19日（週四）›" onClick={() => note("日期選擇器（mock）")} />
            <Row label="全日" toggle={false} onClick={() => note("切換全日")} />
            <Row label="時間" value="19:30 – 23:00 ›" onClick={() => note("時間選擇器（mock）")} />
            <Row label="🔁 重複" value="唔重複 ›" onClick={() => note("重複選項（mock）")} />
            <Row label="👥 成員" value="全部成員 ›" onClick={() => note("揀成員（mock）")} />
            <Row label="📍 地點" value="未填" onClick={() => note("地點輸入（mock）")} />
            <Row label="🔗 網址" value="未填" onClick={() => note("網址輸入（mock）")} />
            <Row label="🗒 備註" value="未填" onClick={() => setScreen("noteEdit")} />
            <Row label="☑ 待辦清單" value="＋ 新增清單" onClick={() => setScreen("todos")} />
          </Sheet>
        )}

        {screen === "noteEdit" && (
          <Sheet title="備註" onBack={() => setScreen("create")} right={<button className="m-cta sm" onClick={() => { note("已保存（mock）"); setScreen("create"); }}>保存</button>}>
            <textarea className="m-note" defaultValue={"記得買沙茶醬、出前一丁\n青菜兩款"} rows={8} />
            <Row label="📎 上傳檔案" value="＋" onClick={() => note("上傳檔案（mock）")} />
          </Sheet>
        )}

        {screen === "eventDetail" && (
          <Sheet title={ev.title} onBack={() => setScreen("month")} right={<button className="m-icon" onClick={() => note("編輯（mock）")}>編輯</button>}>
            <Row label="🕐" value={`11月${ev.day}日（週${["日","一","二","三","四","五","六"][evDate.getDay()]}）${ev.time}`} />
            <Row label="🏷 標籤" value={<><i className="m-dot" style={{ background: ev.color }} /> Bright Orange</>} />
            {ev.loc && <Row label="📍 地點" value={ev.loc} />}
            <Row label="👥 成員" value="全部成員" />
            <Chat msgs={[{ who: "老婆", text: "買緊嘢食，要乜？" }, { who: "我", text: "沙茶醬幫手攞支", me: true }]} />
            <button className="m-danger" onClick={() => { note("已刪除（mock）"); setScreen("month"); }}>刪除活動</button>
          </Sheet>
        )}

        {screen === "feed" && (
          <>
            <NavBar title="最新動態" left={<button className="m-back" onClick={() => setScreen("calendarList")}>家庭日曆 ▾</button>} />
            <div className="m-seg">
              <button className={feedTab === "行程" ? "on" : ""} onClick={() => setFeedTab("行程")}>行程</button>
              <button className={feedTab === "相簿" ? "on" : ""} onClick={() => setFeedTab("相簿")}>相簿</button>
            </div>
            <div className="m-scroll">
              {feedTab === "行程" && (
                <>
                  <div className="m-feedcard" onClick={() => openEvent("1")}>
                    <div className="m-feedphoto">🍖</div>
                    <div className="m-feedinfo">
                      <b>（A房）BBQ 15人 17:00-23:00</b>
                      <div className="m-sub">10月25日 週日 下午7:00</div>
                      <div className="m-feedmeta"><span className="m-avatar sm" style={{ background: C.orange }}>文</span> 阿文 新增咗呢個行程</div>
                    </div>
                  </div>
                  <div className="m-feed"><span className="m-avatar" style={{ background: C.green }}>婆</span><div><b>老婆</b> 改咗「屋企人飯局」時間<div className="m-sub">2 小時前</div></div></div>
                  <div className="m-feed"><span className="m-avatar" style={{ background: C.blue }}>女</span><div><b>阿女</b> 喺相簿上傳咗 3 張相<div className="m-sub">昨日</div></div></div>
                </>
              )}
              {feedTab === "相簿" && (
                <div className="m-empty">
                  <div style={{ fontSize: 40 }}>🖼</div>
                  <b>無最新動態</b>
                  <p className="m-sub">呢個行事曆仲未有相簿更新。</p>
                  <button className="m-cta light" onClick={() => setScreen("album")}>去相簿 ›</button>
                </div>
              )}
            </div>
          </>
        )}

        {screen === "notices" && (
          <>
            <NavBar title="通知" />
            <div className="m-scroll">
              <div className="m-feed"><span>🔔</span><div>聽日 19:00「屋企人飯局」<div className="m-sub">提醒</div></div></div>
              <div className="m-feed"><span>👥</span><div>阿女接受咗你嘅邀請<div className="m-sub">昨日</div></div></div>
            </div>
          </>
        )}

        {screen === "other" && (
          <>
            <NavBar title="其他" />
            <div className="m-scroll">
              <div className="m-profile" onClick={() => setScreen("profile")}>
                <span className="m-avatar lg" style={{ background: C.orange }}>文</span>
                <div><b>阿文</b><div className="m-sub">simonhk02@gmail.com</div></div>
              </div>
              <div className="m-premium" onClick={() => setScreen("premium")}>⭐ MangoTime Premium<span className="m-sub"> 無廣告 · 上傳檔案 · 更多標籤色 ›</span></div>
              <Row label="📅 行事曆清單" value="›" onClick={() => setScreen("calendarList")} />
              <Row label="📝 備忘錄" value="›" onClick={() => setScreen("memos")} />
              <Row label="✅ 待辦清單" value="›" onClick={() => setScreen("todos")} />
              <Row label="🖼 相簿" value="›" onClick={() => setScreen("album")} />
              <Row label="👥 成員" value="›" onClick={() => setScreen("members")} />
              <Row label="⚙ App 設定" value="›" onClick={() => setScreen("settings")} />
              <Row label="📢 公告" value="›" onClick={() => setScreen("noticeBoard")} />
              <Row label="❓ 使用説明" value="›" onClick={() => note("幫助中心（mock）")} />
            </div>
          </>
        )}

        {screen === "profile" && (
          <Sheet title="個人檔案" onBack={() => setScreen("other")}>
            <div className="m-profile center">
              <span className="m-avatar xl" style={{ background: C.orange }}>文</span>
              <b>阿文</b>
              <div className="m-sub">simonhk02@gmail.com</div>
            </div>
            <Row label="名稱" value="阿文 ›" onClick={() => note("改名（mock）")} />
            <Row label="電郵" value="simonhk02@gmail.com" />
            <Row label="連結帳戶" value="Google · Apple ›" onClick={() => note("連結帳戶（mock）")} />
            <button className="m-danger" onClick={() => setScreen("login")}>登出</button>
          </Sheet>
        )}

        {screen === "memos" && (
          <Sheet title="備忘錄" onBack={() => setScreen("other")} right={<button className="m-icon" onClick={() => note("新增備忘錄（mock）")}>＋</button>}>
            {MOCK_MEMOS.map((m) => (
              <div key={m.id} className="m-card" onClick={() => { setOpenMemoId(m.id); setScreen("memoDetail"); }}>
                <i className="m-dot" style={{ background: m.color }} />
                <div><b>{m.title}</b><div className="m-sub">{m.body}</div></div>
              </div>
            ))}
          </Sheet>
        )}

        {screen === "memoDetail" && (
          <Sheet title={memo.title} onBack={() => setScreen("memos")} right={<button className="m-icon" onClick={() => note("編輯（mock）")}>編輯</button>}>
            <Row label="🏷 標籤" value={<><i className="m-dot" style={{ background: memo.color }} /> 備忘錄</>} />
            <Row label="🗒 內容" value={memo.body} />
            <Chat msgs={[{ who: "阿女", text: "貓糧要無穀物嗰隻吖" }]} />
          </Sheet>
        )}

        {screen === "todos" && (
          <Sheet title="待辦清單" onBack={() => setScreen("other")} right={<button className="m-icon" onClick={() => note("新增清單（mock）")}>＋</button>}>
            <div className="m-sub" style={{ padding: "4px 0 8px" }}>1/2 已完成</div>
            {MOCK_TODOS.map((t) => (
              <div key={t.id} className="m-card" onClick={() => note("切換完成")}>
                <span className={`m-check${t.done ? " done" : ""}`}>{t.done ? "✓" : ""}</span>
                <span style={{ textDecoration: t.done ? "line-through" : "none" }}>{t.text}</span>
              </div>
            ))}
          </Sheet>
        )}

        {screen === "album" && (
          <Sheet title="相簿" onBack={() => setScreen("feed")} right={<button className="m-icon" onClick={() => note("上傳（mock）")}>＋</button>}>
            <div className="m-photos">
              {MOCK_PHOTOS.map((p, i) => <div key={i} className="m-photo" onClick={() => note("相片詳情（mock）")}>{p}</div>)}
            </div>
          </Sheet>
        )}

        {screen === "members" && (
          <Sheet title="成員（3）" onBack={() => setScreen("other")}>
            {MOCK_MEMBERS.map((m) => (
              <div key={m.name} className="m-card">
                <span className="m-avatar" style={{ background: m.color }}>{m.name[0]}</span>
                <div><b>{m.name}</b><div className="m-sub">{m.role}</div></div>
              </div>
            ))}
            <button className="m-cta light" onClick={() => setScreen("invite")}>＋ 邀請成員</button>
          </Sheet>
        )}

        {screen === "invite" && (
          <Sheet title="邀請成員" onBack={() => setScreen("members")}>
            <p className="m-sub">任何人撳呢條連結就入到「家庭日曆」：</p>
            <div className="m-invitelink">
              <code>mangotime.app/join/FAM-8X3K</code>
              <button className="m-cta sm" onClick={() => note("已複製連結（mock）")}>複製</button>
            </div>
            <div className="m-qr">▦▦▦<br />▦ QR ▦<br />▦▦▦</div>
            <p className="m-sub" style={{ textAlign: "center" }}>或者俾佢掃 QR code</p>
            <button className="m-cta light" onClick={() => note("WhatsApp 分享（mock）")}>經 WhatsApp 送出</button>
          </Sheet>
        )}

        {screen === "settings" && (
          <Sheet title="App 設定" onBack={() => setScreen("other")}>
            <Row label="🖥 顯示設定" value="›" onClick={() => setScreen("displaySettings")} />
            <Row label="🔔 通知設定" value="›" onClick={() => setScreen("notifSettings")} />
            <Row label="🌐 語言" value="中文 ›" onClick={() => note("語言（mock）")} />
            <Row label="🗓 節日" value="香港 ›" onClick={() => note("節日（mock）")} />
            <Row label="🔍 篩選設定" value="›" onClick={() => setScreen("filterSettings")} />
          </Sheet>
        )}

        {screen === "displaySettings" && (
          <Sheet title="顯示設定" onBack={() => setScreen("settings")}>
            <Row label="一週嘅開始" value={weekStart === 1 ? "週一 ›" : "週日 ›"} onClick={() => setWeekStart(weekStart === 1 ? 0 : 1)} />
            <Row label="農曆顯示" toggle={lunarOn} onClick={() => setLunarOn(!lunarOn)} />
            <Row label="第幾週" toggle={false} onClick={() => note("切換第幾週")} />
            <Row label="節日" value="香港 ›" onClick={() => note("節日（mock）")} />
            <Row label="24 小時制" toggle={true} onClick={() => note("切換24小時制")} />
          </Sheet>
        )}

        {screen === "notifSettings" && (
          <Sheet title="通知設定" onBack={() => setScreen("settings")}>
            <Row label="邀請" toggle={true} onClick={() => note("切換")} />
            <Row label="新活動" toggle={true} onClick={() => note("切換")} />
            <Row label="留言" toggle={true} onClick={() => note("切換")} />
            <Row label="活動開始前" value="1 小時前 ›" onClick={() => note("提醒時間（mock）")} />
            <Row label="每日通知時間" value="09:00 ›" onClick={() => note("通知時間（mock）")} />
          </Sheet>
        )}

        {screen === "filterSettings" && (
          <Sheet title="篩選設定" onBack={() => setScreen("settings")}>
            <div className="m-sub" style={{ paddingBottom: 8 }}>指定行程參加者或標籤，即可篩選。</div>
            <Row label="👥 參加者" value="全部 ›" onClick={() => note("揀參加者")} />
            <Row label="🏷 標籤" value="全部 ›" onClick={() => note("揀標籤")} />
            <button className="m-cta light" onClick={() => note("已套用（mock）")}>套用</button>
          </Sheet>
        )}

        {screen === "noticeBoard" && (
          <Sheet title="公告" onBack={() => setScreen("other")}>
            <div className="m-card"><b>v1.0 上線 🎉</b><div className="m-sub">MangoTime 正式推出！而家有 MCP、Webhook、API。</div></div>
            <div className="m-card"><b>相片權限更新</b><div className="m-sub">上傳相簿前請允許相片存取。</div></div>
          </Sheet>
        )}

        {screen === "search" && (
          <Sheet title="搜尋活動" onBack={() => setScreen("month")}>
            <input className="m-title" placeholder="關鍵字…" autoFocus />
            <div className="m-sub" style={{ padding: "8px 0" }}>指定行程參加者或標籤，即可篩選。</div>
            <div className="m-feed"><span className="m-dot" style={{ background: C.red }} /><div><b>打邊爐</b><div className="m-sub">11月19日（週四）19:30</div></div></div>
            <div className="m-feed"><span className="m-dot" style={{ background: C.green }} /><div><b>屋企人飯局</b><div className="m-sub">11月18日（週三）19:00</div></div></div>
          </Sheet>
        )}

        {screen === "premium" && (
          <Sheet title="MangoTime Premium" onBack={() => setScreen("other")}>
            <div className="m-premiumbox">
              <div style={{ fontSize: 40 }}>⭐</div>
              <b>月付 HK$23</b>
              <div className="m-sub">無廣告 · 上傳檔案 · 更多標籤色</div>
              <button className="m-cta" onClick={() => note("收費唔係而家嘅事 😄")}>免費使用 1 個月</button>
            </div>
          </Sheet>
        )}

        {["month", "weekly", "feed", "notices", "other"].includes(screen) && <Tabs />}
      </div>
    </div>
  );
}

const PROTO_CSS = `
.m-stage { min-height: 100vh; background: #0f1115; display: grid; place-items: center; padding: 16px; }
.m-phone { width: 390px; height: 844px; background: #fff; border-radius: 40px; border: 10px solid #1c1f26; overflow: hidden; display: flex; flex-direction: column; position: relative; box-shadow: 0 20px 60px #0008; }
.m-status { display: flex; justify-content: space-between; padding: 10px 22px 4px; font-size: 13px; font-weight: 600; background: #fff; }
.m-toast { position: absolute; top: 44px; left: 50%; transform: translateX(-50%); background: #1a2332; color: #fff; padding: 6px 14px; border-radius: 8px; font-size: 12.5px; z-index: 60; white-space: nowrap; }

/* nav */
.m-nav { display: flex; align-items: center; justify-content: space-between; padding: 8px 14px 10px; background: #fff; border-bottom: 1px solid #f0f2f5; min-height: 44px; }
.m-nav b { font-size: 16.5px; }
.m-navside { min-width: 70px; display: flex; gap: 6px; align-items: center; }
.m-navside.right { justify-content: flex-end; }
.m-back { border: none; background: none; color: #ff7043; font-size: 15px; font-weight: 600; cursor: pointer; padding: 0; }
.m-icon { border: none; background: none; font-size: 15px; cursor: pointer; color: #ff7043; }

/* tabs */
.m-tabs { display: grid; grid-template-columns: repeat(5, 1fr); background: #fff; border-top: 1px solid #f0f2f5; padding: 6px 0 14px; }
.m-tabs button { border: none; background: none; display: flex; flex-direction: column; align-items: center; gap: 2px; font-size: 20px; color: #8a94a1; cursor: pointer; }
.m-tabs button span { font-size: 10px; }
.m-tabs button.on { color: #ff7043; }
.m-plus { width: 48px; height: 48px; border-radius: 50%; background: #ff7043; color: #fff !important; font-size: 26px !important; margin: -20px auto 0; display: grid !important; place-items: center; box-shadow: 0 4px 12px #ff704366; }

/* 月曆 */
.m-seg { display: flex; gap: 0; background: #f0f2f5; border-radius: 8px; margin: 8px 14px; padding: 2px; }
.m-seg button { flex: 1; border: none; background: none; padding: 5px 0; border-radius: 6px; font-size: 13px; font-weight: 600; color: #8a94a1; cursor: pointer; }
.m-seg button.on { background: #fff; color: #1a2332; box-shadow: 0 1px 3px #0002; }
.m-grid { display: grid; grid-template-columns: repeat(7, 1fr); gap: 1px; background: #f0f2f5; flex: 1; overflow: auto; }
.m-wd { background: #fff; text-align: center; font-size: 11px; font-weight: 600; padding: 5px 0; color: #8a94a1; }
.m-cell { background: #fff; min-height: 68px; padding: 3px 2px; }
.m-cell.other { background: #fafbfc; opacity: 0.4; }
.m-cell.today { outline: 2px solid #ff7043; outline-offset: -2px; }
.m-dayrow { display: flex; align-items: baseline; justify-content: center; gap: 3px; }
.m-day { font-weight: 650; font-size: 13px; }
.m-lunar { font-size: 8px; color: #a3acb9; }
.m-event { color: #fff; font-size: 9px; padding: 1px 3px; border-radius: 3px; margin-top: 1px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }

/* 週曆 */
.m-week { display: grid; grid-template-columns: repeat(7, 1fr); gap: 4px; padding: 0 6px; flex: 1; }
.m-wcol { background: #fff; border: 1px solid #f0f2f5; border-radius: 8px; min-height: 200px; padding: 4px; }
.m-wcol .m-wd { font-size: 10px; }

/* sheet / scroll */
.m-sheet { display: flex; flex-direction: column; flex: 1; background: #fff; overflow: hidden; }
.m-scroll { flex: 1; overflow: auto; padding: 0 14px 20px; }
.m-title { width: 100%; border: none; border-bottom: 1px solid #e4e7ec; font-size: 17px; font-weight: 600; padding: 12px 0 10px; margin-bottom: 4px; }
.m-note { width: 100%; border: 1px solid #e4e7ec; border-radius: 10px; padding: 12px; font-size: 15px; font-family: inherit; margin-top: 8px; }

/* rows & cards */
.m-row { display: flex; justify-content: space-between; align-items: center; padding: 12px 0; border-bottom: 1px solid #f5f6f8; font-size: 14.5px; cursor: pointer; }
.m-val { color: #8a94a1; display: flex; align-items: center; gap: 5px; font-size: 13.5px; }
.m-dot { width: 10px; height: 10px; border-radius: 50%; display: inline-block; font-style: normal; }
.m-switch { width: 44px; height: 26px; border-radius: 13px; background: #e4e7ec; position: relative; display: inline-block; transition: background 0.15s; }
.m-switch::after { content: ""; position: absolute; left: 2px; top: 2px; width: 22px; height: 22px; border-radius: 50%; background: #fff; box-shadow: 0 1px 3px #0003; }
.m-switch.on { background: #10b981; }
.m-switch.on::after { left: auto; right: 2px; }
.m-card { display: flex; gap: 10px; align-items: center; padding: 12px 0; border-bottom: 1px solid #f5f6f8; font-size: 14.5px; cursor: pointer; }
.m-sub { font-size: 12px; color: #8a94a1; }
.m-labels { background: #f7f8fa; border-radius: 10px; margin: 4px 0 8px; padding: 4px 10px; }

/* chat */
.m-chat { margin-top: 14px; border-top: 1px solid #f0f2f5; padding-top: 12px; }
.m-chathead { font-size: 13px; color: #8a94a1; margin-bottom: 8px; }
.m-msg { background: #f0f2f5; border-radius: 12px; padding: 8px 12px; margin-bottom: 8px; font-size: 14px; }
.m-msg.me { background: #fff3ee; }
.m-chatbar { display: flex; gap: 6px; margin-top: 10px; }
.m-chatbar input { flex: 1; border: 1px solid #e4e7ec; border-radius: 20px; padding: 8px 12px; font-size: 14px; }
.m-chatbar button { border: none; background: none; font-size: 18px; cursor: pointer; }
.m-send { color: #ff7043; font-weight: 600; font-size: 14px !important; }

/* 其他頁 */
.m-profile { display: flex; gap: 12px; align-items: center; padding: 14px 0; cursor: pointer; }
.m-profile.center { flex-direction: column; text-align: center; }
.m-avatar { width: 36px; height: 36px; border-radius: 50%; color: #fff; display: grid; place-items: center; font-weight: 700; font-size: 14px; }
.m-avatar.lg { width: 52px; height: 52px; font-size: 20px; }
.m-avatar.xl { width: 72px; height: 72px; font-size: 28px; }
.m-premium { background: linear-gradient(90deg, #fff3ee, #ffe9e0); border: 1px solid #ffd9cc; border-radius: 12px; padding: 12px 14px; margin: 6px 0 10px; font-size: 14px; cursor: pointer; }
.m-premiumbox { display: flex; flex-direction: column; align-items: center; gap: 8px; padding: 24px 0; }
.m-feed { display: flex; gap: 10px; align-items: center; padding: 12px 0; border-bottom: 1px solid #f5f6f8; font-size: 14px; }
.m-photos { display: grid; grid-template-columns: repeat(3, 1fr); gap: 6px; padding-top: 8px; }
.m-photo { aspect-ratio: 1; background: #f0f2f5; border-radius: 10px; display: grid; place-items: center; font-size: 32px; cursor: pointer; }
.m-invitelink { display: flex; gap: 8px; align-items: center; background: #f7f8fa; border: 1px solid #e4e7ec; border-radius: 10px; padding: 10px 12px; margin-top: 8px; }
.m-invitelink code { flex: 1; font-size: 12.5px; }
.m-qr { text-align: center; font-size: 20px; letter-spacing: 4px; margin: 16px 0 4px; }

/* buttons */
.m-cta { background: #ff7043; color: #fff; border: none; border-radius: 10px; padding: 12px; font-weight: 700; font-size: 15px; cursor: pointer; width: 100%; }
.m-cta.sm { width: auto; padding: 6px 14px; font-size: 13.5px; border-radius: 8px; }
.m-cta.light { background: #fff3ee; color: #ff7043; margin-top: 10px; }
.m-ghost { background: #fff; border: 1px solid #e4e7ec; border-radius: 10px; padding: 11px; font-size: 14.5px; cursor: pointer; width: 100%; }
.m-danger { margin-top: 16px; width: 100%; border: 1px solid #ef4444; color: #ef4444; background: none; border-radius: 10px; padding: 11px; cursor: pointer; font-weight: 600; }

/* login */
.m-login { flex: 1; display: flex; flex-direction: column; justify-content: center; gap: 12px; padding: 0 32px; }
.m-login h1 { margin: 0; font-size: 30px; }
.m-login p { margin: 0 0 10px; color: #8a94a1; font-size: 14px; }
.m-login input { padding: 13px; border: 1px solid #e4e7ec; border-radius: 10px; font-size: 15px; }
.m-or { text-align: center; color: #a3acb9; font-size: 12px; }
`;
