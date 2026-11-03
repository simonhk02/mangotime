# MangoTime

Shared-calendar app (TimeTree-style) with a public REST API, webhooks and an MCP server built in.

Monorepo layout:

| Dir       | What                                             |
| --------- | ------------------------------------------------ |
| `server/` | API server — TypeScript, Fastify, Prisma, SQLite (WAL) |
| `web/`    | Web app — React + Vite + TypeScript              |
| `ios/`    | iOS app — SwiftUI (separate workstream)          |
| `mcp/`    | MCP server (stdio) for agent access              |
| `docs/`   | Specs: architecture, feature inventory, tasks    |

## Quickstart

Requires Node.js 22+ and npm.

### 1. API server (`server/`, port 8787)

```sh
cd server
npm install
cp .env.example .env        # PORT=8787, DATABASE_URL -> data/mangotime.db
npx prisma migrate dev      # creates data/mangotime.db + User table (first run: name it e.g. "init")
npm run dev                 # watch mode
# or: npm run build && npm start
```

Endpoints:

- `GET http://localhost:8787/health` → `{ "ok": true, "version": "0.1.0" }`
- `GET http://localhost:8787/v1/ping` → `{ "pong": true }`
- `GET http://localhost:8787/docs` → the OpenAPI v0 spec (`server/openapi.yaml`)

### 2. Web app (`web/`, port 5173)

```sh
cd web
npm install
npm run dev                 # http://localhost:5173
```

The dev server proxies `/api/*` → `http://localhost:8787/*`, so the page shows live
server health. Production build: `npm run build` (typecheck + Vite bundle to `web/dist/`).

### 3. MCP server (`mcp/`)

```sh
cd mcp
npm install
npm run build
npm run smoke               # stdio smoke test: handshake, tools/list, call ping
```

Run it with any MCP client over stdio:

```sh
node mcp/dist/index.js      # env: MANGOTIME_SERVER_URL (default http://localhost:8787)
```

Tools: `ping` — calls the API server's `/health` and returns the result.

## Repo rules

- `docs/` and `PROGRESS.md` are PM-managed; code agents must not modify them.
- SQLite DB lives at `server/data/mangotime.db` (git-ignored).
- Never commit `.env`; use `.env.example` as the template.
