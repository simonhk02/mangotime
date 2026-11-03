import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";

const SERVER_URL = process.env.MANGOTIME_SERVER_URL ?? "http://localhost:8787";

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

const transport = new StdioServerTransport();
await server.connect(transport);
// Log to stderr only — stdout is the JSON-RPC channel.
console.error(`mangotime-mcp up on stdio (server: ${SERVER_URL})`);
