import { useEffect, useState } from "react";
import { api, getToken, setToken, type User } from "./api";
import Auth from "./Auth";

type State =
  | { status: "loading" }
  | { status: "anon" }
  | { status: "authed"; user: User };

export default function App() {
  const [state, setState] = useState<State>({ status: "loading" });

  useEffect(() => {
    if (!getToken()) {
      setState({ status: "anon" });
      return;
    }
    api
      .me()
      .then(({ user }) => setState({ status: "authed", user }))
      .catch(() => {
        setToken(null);
        setState({ status: "anon" });
      });
  }, []);

  async function logout() {
    try {
      await api.logout();
    } catch {
      /* token may already be dead — fine */
    }
    setToken(null);
    setState({ status: "anon" });
  }

  return (
    <main className="shell">
      <h1>MangoTime</h1>
      <p className="tagline">Shared calendars with an API, webhooks and MCP built in.</p>

      {state.status === "loading" && <p>載入中…</p>}

      {state.status === "anon" && (
        <Auth onAuthed={(user) => setState({ status: "authed", user })} />
      )}

      {state.status === "authed" && (
        <section className="profile">
          <h2>你好，{state.user.displayName}</h2>
          {state.user.avatarUrl && (
            <img className="avatar" src={state.user.avatarUrl} alt="" width={64} height={64} />
          )}
          <p className="muted">{state.user.email}</p>
          <button onClick={logout}>登出</button>
        </section>
      )}
    </main>
  );
}
