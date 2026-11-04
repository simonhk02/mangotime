import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";

const SERVER_URL = process.env.MANGOTIME_SERVER_URL ?? "https://mangotime-api.149-28-154-219.sslip.io";
const TOKEN = process.env.MANGOTIME_TOKEN ?? ""; // session token 或 mt_ API key

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

const server = new McpServer({ name: "mangotime", version: "0.2.0" });

server.registerTool(
  "ping",
  { description: "Ping the MangoTime API server (GET /health). Check reachability before doing real work." },
  async () => {
    try {
      const res = await fetch(`${SERVER_URL}/health`);
      const body = await res.text();
      let parsed: unknown = body;
      try { parsed = JSON.parse(body); } catch { /* 保持原文 */ }
      return ok({ status: res.status, health: parsed });
    } catch (err) {
      return fail(err);
    }
  },
);

// --- Calendars ---
server.registerTool("list_calendars", {
  description: "List MangoTime calendars the current token can see (id, name, memberCount, myRole).",
}, async () => {
  try { return ok(await api("GET", "/v1/calendars")); } catch (err) { return fail(err); }
});

server.registerTool("create_calendar", {
  description: "Create a new MangoTime calendar. Returns the created calendar with its id.",
  inputSchema: { name: z.string().describe("Calendar name") },
}, async ({ name }) => {
  try { return ok(await api("POST", "/v1/calendars", { name })); } catch (err) { return fail(err); }
});

// --- Events ---
server.registerTool("list_events", {
  description: "List events in a calendar within a date range (ISO 8601). Returns full event objects.",
  inputSchema: {
    calendarId: z.string(),
    from: z.string().describe("ISO 8601 start, e.g. 2026-11-01T00:00:00+08:00"),
    to: z.string().describe("ISO 8601 end"),
  },
}, async ({ calendarId, from, to }) => {
  try { return ok(await api("GET", `/v1/calendars/${calendarId}/events?from=${encodeURIComponent(from)}&to=${encodeURIComponent(to)}`)); } catch (err) { return fail(err); }
});

server.registerTool("create_event", {
  description: "Create an event. labelColor: bright-orange|emerald|blue|red|amber|purple. repeatRule: none|daily|weekly|monthly|yearly.",
  inputSchema: {
    calendarId: z.string(),
    title: z.string(),
    startsAt: z.string().describe("ISO 8601"),
    endsAt: z.string().optional(),
    allDay: z.boolean().optional(),
    repeatRule: z.enum(["none", "daily", "weekly", "monthly", "yearly"]).optional(),
    labelColor: z.string().optional(),
    location: z.string().optional(),
    url: z.string().optional(),
    note: z.string().optional(),
  },
}, async ({ calendarId, ...body }) => {
  try { return ok(await api("POST", `/v1/calendars/${calendarId}/events`, body)); } catch (err) { return fail(err); }
});

server.registerTool("update_event", {
  description: "Update an event. Only supplied fields are changed.",
  inputSchema: {
    eventId: z.string(),
    title: z.string().optional(),
    startsAt: z.string().optional(),
    endsAt: z.string().optional(),
    allDay: z.boolean().optional(),
    repeatRule: z.enum(["none", "daily", "weekly", "monthly", "yearly"]).optional(),
    labelColor: z.string().optional(),
    location: z.string().optional(),
    note: z.string().optional(),
  },
}, async ({ eventId, ...body }) => {
  try { return ok(await api("PATCH", `/v1/events/${eventId}`, body)); } catch (err) { return fail(err); }
});

server.registerTool("delete_event", {
  description: "Delete an event (creator of the event or calendar creator only).",
  inputSchema: { eventId: z.string() },
}, async ({ eventId }) => {
  try { await api("DELETE", `/v1/events/${eventId}`); return ok({ deleted: true, eventId }); } catch (err) { return fail(err); }
});

// --- Comments ---
server.registerTool("list_comments", {
  description: "List comments on an event.",
  inputSchema: { eventId: z.string() },
}, async ({ eventId }) => {
  try { return ok(await api("GET", `/v1/events/${eventId}/comments`)); } catch (err) { return fail(err); }
});

server.registerTool("post_comment", {
  description: "Post a comment on an event.",
  inputSchema: { eventId: z.string(), body: z.string() },
}, async ({ eventId, body }) => {
  try { return ok(await api("POST", `/v1/events/${eventId}/comments`, { body })); } catch (err) { return fail(err); }
});

// --- Memos ---
server.registerTool("list_memos", {
  description: "List memos in a calendar.",
  inputSchema: { calendarId: z.string() },
}, async ({ calendarId }) => {
  try { return ok(await api("GET", `/v1/calendars/${calendarId}/memos`)); } catch (err) { return fail(err); }
});

server.registerTool("create_memo", {
  description: "Create a memo (note / shopping list).",
  inputSchema: { calendarId: z.string(), title: z.string(), body: z.string().optional(), labelColor: z.string().optional() },
}, async ({ calendarId, ...body }) => {
  try { return ok(await api("POST", `/v1/calendars/${calendarId}/memos`, body)); } catch (err) { return fail(err); }
});

// --- Todos ---
server.registerTool("list_todos", {
  description: "List todo lists (with items) in a calendar.",
  inputSchema: { calendarId: z.string() },
}, async ({ calendarId }) => {
  try { return ok(await api("GET", `/v1/calendars/${calendarId}/todos`)); } catch (err) { return fail(err); }
});

server.registerTool("create_todo_list", {
  description: "Create a todo list.",
  inputSchema: { calendarId: z.string(), title: z.string() },
}, async ({ calendarId, title }) => {
  try { return ok(await api("POST", `/v1/calendars/${calendarId}/todos`, { title })); } catch (err) { return fail(err); }
});

server.registerTool("add_todo_item", {
  description: "Add an item to a todo list.",
  inputSchema: { listId: z.string(), text: z.string() },
}, async ({ listId, text }) => {
  try { return ok(await api("POST", `/v1/todos/${listId}/items`, { text })); } catch (err) { return fail(err); }
});

server.registerTool("toggle_todo_item", {
  description: "Mark a todo item done/undone.",
  inputSchema: { itemId: z.string(), done: z.boolean() },
}, async ({ itemId, done }) => {
  try { return ok(await api("PATCH", `/v1/todo-items/${itemId}`, { done })); } catch (err) { return fail(err); }
});

// --- Members & invites ---
server.registerTool("create_invite", {
  description: "Create (or get existing) invite link for a calendar. Returns the share code.",
  inputSchema: { calendarId: z.string() },
}, async ({ calendarId }) => {
  try { return ok(await api("POST", `/v1/calendars/${calendarId}/invites`)); } catch (err) { return fail(err); }
});

server.registerTool("list_members", {
  description: "List members of a calendar.",
  inputSchema: { calendarId: z.string() },
}, async ({ calendarId }) => {
  try { return ok(await api("GET", `/v1/calendars/${calendarId}/members`)); } catch (err) { return fail(err); }
});

// --- Activity / notices ---
server.registerTool("list_activity", {
  description: "Recent activity feed of a calendar (who did what, latest 50).",
  inputSchema: { calendarId: z.string() },
}, async ({ calendarId }) => {
  try { return ok(await api("GET", `/v1/calendars/${calendarId}/activity`)); } catch (err) { return fail(err); }
});

server.registerTool("list_notices", {
  description: "My notices: actions by other members across all my calendars (latest 30).",
}, async () => {
  try { return ok(await api("GET", "/v1/notices")); } catch (err) { return fail(err); }
});

// --- Webhooks ---
server.registerTool("create_webhook", {
  description: "Subscribe a webhook URL to a calendar. Every change POSTs there with HMAC signature (x-mangotime-signature).",
  inputSchema: { calendarId: z.string(), url: z.string().describe("https URL") },
}, async ({ calendarId, url }) => {
  try { return ok(await api("POST", `/v1/calendars/${calendarId}/webhooks`, { url })); } catch (err) { return fail(err); }
});

server.registerTool("list_webhooks", {
  description: "List webhook subscriptions of a calendar.",
  inputSchema: { calendarId: z.string() },
}, async ({ calendarId }) => {
  try { return ok(await api("GET", `/v1/calendars/${calendarId}/webhooks`)); } catch (err) { return fail(err); }
});

const transport = new StdioServerTransport();
await server.connect(transport);
// Log to stderr only — stdout is the JSON-RPC channel.
console.error(`mangotime-mcp up on stdio (server: ${SERVER_URL})`);
