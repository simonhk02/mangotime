import { useEffect, useState } from "react";

type HealthState =
  | { status: "loading" }
  | { status: "ok"; version: string }
  | { status: "error"; message: string };

export default function App() {
  const [health, setHealth] = useState<HealthState>({ status: "loading" });

  useEffect(() => {
    // Vite dev proxy rewrites /api/* -> http://localhost:8787/*
    fetch("/api/health")
      .then(async (res) => {
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        const body = (await res.json()) as { ok: boolean; version: string };
        setHealth({ status: "ok", version: body.version });
      })
      .catch((err: unknown) =>
        setHealth({
          status: "error",
          message: err instanceof Error ? err.message : String(err),
        }),
      );
  }, []);

  return (
    <main className="shell">
      <h1>MangoTime</h1>
      <p className="tagline">Shared calendars with an API, webhooks and MCP built in.</p>
      <section className="health">
        <h2>Server health</h2>
        {health.status === "loading" && <p>Checking /api/health…</p>}
        {health.status === "ok" && (
          <p>
            <span className="dot ok" /> ok — server v{health.version}
          </p>
        )}
        {health.status === "error" && (
          <p>
            <span className="dot err" /> unreachable: {health.message}
          </p>
        )}
      </section>
    </main>
  );
}
