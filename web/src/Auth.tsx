import { useEffect, useRef, useState } from "react";
import { api, setToken, type User } from "./api";

type Props = { onAuthed: (user: User) => void };

// Google Identity Services（web client id 喺 Google Cloud Console 開咗）
const GOOGLE_WEB_CLIENT_ID = "289476107711-6c218rrsl6fi331a06epvplcel0umeto.apps.googleusercontent.com";

declare global {
  interface Window {
    google?: {
      accounts: {
        id: {
          initialize: (opts: { client_id: string; callback: (r: { credential: string }) => void }) => void;
          renderButton: (el: HTMLElement, opts: Record<string, unknown>) => void;
        };
      };
    };
  }
}

export default function Auth({ onAuthed }: Props) {
  const [mode, setMode] = useState<"login" | "register">("login");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [displayName, setDisplayName] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const googleBtn = useRef<HTMLDivElement>(null);

  useEffect(() => {
    // 動態 load Google Identity Services
    if (document.getElementById("gsi-script")) return;
    const script = document.createElement("script");
    script.id = "gsi-script";
    script.src = "https://accounts.google.com/gsi/client";
    script.async = true;
    script.onload = () => {
      window.google?.accounts.id.initialize({
        client_id: GOOGLE_WEB_CLIENT_ID,
        callback: async (r) => {
          try {
            const res = await fetch("https://mangotime-api.149-28-154-219.sslip.io/v1/auth/google", {
              method: "POST",
              headers: { "content-type": "application/json" },
              body: JSON.stringify({ idToken: r.credential }),
            });
            if (!res.ok) throw new Error("Google 登入失敗");
            const data = await res.json();
            setToken(data.token);
            onAuthed(data.user);
          } catch (err) {
            setError(err instanceof Error ? err.message : String(err));
          }
        },
      });
      if (googleBtn.current) {
        window.google?.accounts.id.renderButton(googleBtn.current, { theme: "outline", size: "large", width: 280 });
      }
    };
    document.head.appendChild(script);
  }, [onAuthed]);

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    setBusy(true);
    try {
      const res =
        mode === "login"
          ? await api.login(email.trim(), password)
          : await api.register(email.trim(), password, displayName.trim());
      setToken(res.token);
      onAuthed(res.user);
    } catch (err) {
      setError(err instanceof Error ? err.message : String(err));
    } finally {
      setBusy(false);
    }
  }

  return (
    <section className="auth">
      <h2>{mode === "login" ? "登入" : "註冊"} MangoTime</h2>
      <form onSubmit={submit}>
        {mode === "register" && (
          <label>
            顯示名稱
            <input
              value={displayName}
              onChange={(e) => setDisplayName(e.target.value)}
              required
              autoComplete="name"
            />
          </label>
        )}
        <label>
          電郵
          <input
            type="email"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            required
            autoComplete="email"
          />
        </label>
        <label>
          密碼{mode === "register" && "（最少 8 位）"}
          <input
            type="password"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            required
            minLength={mode === "register" ? 8 : undefined}
            autoComplete={mode === "login" ? "current-password" : "new-password"}
          />
        </label>
        {error && <p className="error">{error}</p>}
        <button type="submit" disabled={busy}>
          {busy ? "…" : mode === "login" ? "登入" : "建立帳號"}
        </button>
      </form>
      <div style={{ margin: "14px 0", textAlign: "center" }}>
        <p style={{ fontSize: 12, color: "#8a94a1", margin: "0 0 8px" }}>或</p>
        <div ref={googleBtn} style={{ display: "flex", justifyContent: "center" }} />
      </div>
      <p className="switch">
        {mode === "login" ? (
          <>未有帳號？<button type="button" onClick={() => setMode("register")}>註冊</button></>
        ) : (
          <>已有帳號？<button type="button" onClick={() => setMode("login")}>登入</button></>
        )}
      </p>
    </section>
  );
}
