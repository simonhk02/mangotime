import { useState } from "react";
import { api, setToken, type User } from "./api";

type Props = { onAuthed: (user: User) => void };

export default function Auth({ onAuthed }: Props) {
  const [mode, setMode] = useState<"login" | "register">("login");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [displayName, setDisplayName] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

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
