import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";

const SERVER_URL = process.env.MANGOTIME_SERVER_URL ?? "http://localhost:8787";
const TOKEN = process.env.MANGOTIME_TOKEN ?? "";

async function api(method: string, path: string, body?: unknown) {
  const headers: Record<string, string> = { "Content-Type": "application/json" };
  if (TOKEN) headers["Authorization"] = `Bearer ${TOKEN}`;
  const res = await fetch(`${SERVER_URL}${path}`, {
    method,
    headers,
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  const text = await res.text();
  if (!res.ok) throw new Error(`HTTP ${res.status}: ${text}`);
  return text ? JSON.parse(text) : {};
}

function ok(data: unknown) {
  return { content: [{ type: "text" as const, text: JSON.stringify(data, null, 2) }] };
}
function fail(err: unknown) {
  return {
    content: [{ type: "text" as const, text: err instanceof Error ? err.message : String(err) }],
    isError: true as const,
  };
}

const server = new McpServer({ name: "mangotime", version: "0.1.0" });

server.registerTool(
  "ping",
  {
    description:
      "Ping the MangoTime API server (GET /health) and return its status. " +
      "Useful to check whether the server is reachable before doing real work.",
  },
  async () => {
    try {
      const res = await fetch(`${SERVER_URL}/health`);
      const body = await res.text();
      return {
        content: [
          {
            type: "text" as const,
            text: `GET ${SERVER_URL}/health -> HTTP ${res.status}\n${body}`,
          },
        ],
      };
    } catch (err) {
      return {
        content: [
          {
            type: "text" as const,
            text: `Failed to reach ${SERVER_URL}/health: ${err instanceof Error ? err.message : String(err)}`,
          },
        ],
        isError: true,
      };
    }
  },
);

// --- Task 1.2: calendar tools ---
server.registerTool(
  "list_calendars",
  { description: "List MangoTime calendars the current token can see (name, id, memberCount, myRole)." },
  async () => {
    try {
      return ok(await api("GET", "/v1/calendars"));
    } catch (err) {
      return fail(err);
    }
  },
);

server.registerTool(
  "create_calendar",
  {
    description: "Create a new MangoTime calendar. Returns the created calendar with its id.",
    inputSchema: { name: z.string().describe("Calendar name") },
  },
  async ({ name }) => {
    try {
      return ok(await api("POST", "/v1/calendars", { name }));
    } catch (err) {
      return fail(err);
    }
  },
);

const transport = new StdioServerTransport();
await server.connect(transport);
// Log to stderr only — stdout is the JSON-RPC channel.
console.error(`mangotime-mcp up on stdio (server: ${SERVER_URL})`);
