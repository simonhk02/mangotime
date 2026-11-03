import { useCallback, useEffect, useState } from "react";
import { api, getToken, setToken, type User } from "./api";
import Auth from "./Auth";
import TimeTreeLayout from "./TimeTreeLayout";
import type { Calendar } from "./api";

type State =
  | { status: "loading" }
  | { status: "anon" }
  | { status: "authed"; user: User };

export default function App() {
  const [state, setState] = useState<State>({ status: "loading" });
  const [calendars, setCalendars] = useState<Calendar[]>([]);

  const loadCalendars = useCallback(() => {
    api.listCalendars().then((r) => setCalendars(r.calendars)).catch(() => {});
  }, []);

  useEffect(() => {
    if (!getToken()) {
      setState({ status: "anon" });
      return;
    }
    api
      .me()
      .then(({ user }) => {
        setState({ status: "authed", user });
        loadCalendars();
      })
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
        <section className="tt-shell">
          <div className="tt-userbar">
            <span>你好，{state.user.displayName}</span>
            <button onClick={logout}>登出</button>
          </div>
          {calendars.length === 0 ? (
            <section className="calendars">
              <h2>開始：開你第一個行事曆</h2>
              <form
                className="create-cal"
                onSubmit={async (e) => {
                  e.preventDefault();
                  const input = (e.target as HTMLFormElement).querySelector("input");
                  const name = input?.value.trim();
                  if (!name) return;
                  await api.createCalendar(name);
                  if (input) input.value = "";
                  loadCalendars();
                }}
              >
                <input placeholder="行事曆名稱（例如：家庭）" />
                <button type="submit" className="primary">建立</button>
              </form>
            </section>
          ) : (
            <TimeTreeLayout calendars={calendars} onCalendarsChanged={loadCalendars} />
          )}
        </section>
      )}
    </main>
  );
}
