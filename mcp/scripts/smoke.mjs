// Stdio smoke test for the MangoTime MCP server.
// Spawns dist/index.js, performs the MCP handshake, lists tools and calls `ping`.
// Requires the API server to be running (default http://localhost:8787) for a healthy ping.
import { spawn } from "node:child_process";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const serverPath = path.resolve(__dirname, "..", "dist", "index.js");

const child = spawn(process.execPath, [serverPath], {
  stdio: ["pipe", "pipe", "inherit"],
});

let buffer = "";
const pending = new Map();
let msgId = 0;

child.stdout.on("data", (chunk) => {
  buffer += chunk.toString("utf8");
  let idx;
  while ((idx = buffer.indexOf("\n")) >= 0) {
    const line = buffer.slice(0, idx).trim();
    buffer = buffer.slice(idx + 1);
    if (!line) continue;
    let msg;
    try {
      msg = JSON.parse(line);
    } catch {
      continue; // not JSON — ignore
    }
    if (msg.id !== undefined && pending.has(msg.id)) {
      pending.get(msg.id)(msg);
      pending.delete(msg.id);
    }
  }
});

function request(method, params) {
  const id = ++msgId;
  return new Promise((resolve, reject) => {
    const timer = setTimeout(
      () => reject(new Error(`timeout waiting for ${method}`)),
      15000,
    );
    pending.set(id, (msg) => {
      clearTimeout(timer);
      resolve(msg);
    });
    child.stdin.write(JSON.stringify({ jsonrpc: "2.0", id, method, params }) + "\n");
  });
}

function notify(method) {
  child.stdin.write(JSON.stringify({ jsonrpc: "2.0", method }) + "\n");
}

function fail(msg) {
  console.error(`SMOKE TEST FAIL: ${msg}`);
  child.kill();
  process.exit(1);
}

try {
  const init = await request("initialize", {
    protocolVersion: "2025-06-18",
    capabilities: {},
    clientInfo: { name: "mangotime-smoke-test", version: "0.0.0" },
  });
  if (init.error) fail(`initialize error: ${JSON.stringify(init.error)}`);
  console.log(
    `initialize -> server=${init.result.serverInfo.name} v${init.result.serverInfo.version} protocol=${init.result.protocolVersion}`,
  );

  notify("notifications/initialized");

  const tools = await request("tools/list", {});
  if (tools.error) fail(`tools/list error: ${JSON.stringify(tools.error)}`);
  const names = (tools.result.tools ?? []).map((t) => t.name);
  console.log(`tools/list -> [${names.join(", ")}]`);
  if (!names.includes("ping")) fail("ping tool not advertised");

  const call = await request("tools/call", { name: "ping", arguments: {} });
  if (call.error) fail(`tools/call error: ${JSON.stringify(call.error)}`);
  const text = call.result.content?.[0]?.text ?? "(no text content)";
  console.log(`tools/call ping ->\n${text}`);
  if (call.result.isError) fail("ping tool returned isError (is the API server up?)");
  if (!/"ok"\s*:\s*true/.test(text)) fail("ping response did not contain ok:true");

  // 有 token 先行 E2E：list → create → list → activity
  if (process.env.MANGOTIME_TOKEN) {
    const cals = await request("tools/call", { name: "list_calendars", arguments: {} });
    const calList = JSON.parse(cals.result.content[0].text).calendars ?? [];
    if (calList.length === 0) fail("no calendars visible with MANGOTIME_TOKEN");
    const calId = calList[0].id;
    console.log(`list_calendars -> ${calList.map((c) => c.name).join(", ")}`);

    const ev = await request("tools/call", {
      name: "create_event",
      arguments: {
        calendarId: calId,
        title: `MCP smoke ${new Date().toISOString().slice(11, 19)}`,
        startsAt: new Date(Date.now() + 86400000).toISOString(),
      },
    });
    const created = JSON.parse(ev.result.content[0].text).event;
    if (!created?.id) fail("create_event returned no id");
    console.log(`create_event -> ${created.title} (${created.id})`);

    const events = await request("tools/call", {
      name: "list_events",
      arguments: {
        calendarId: calId,
        from: new Date(Date.now() - 86400000).toISOString(),
        to: new Date(Date.now() + 3 * 86400000).toISOString(),
      },
    });
    const evList = JSON.parse(events.result.content[0].text).events ?? [];
    if (!evList.some((e) => e.id === created.id)) fail("created event not in list_events");
    console.log(`list_events -> ${evList.length} events incl. new one`);

    const act = await request("tools/call", { name: "list_activity", arguments: { calendarId: calId } });
    const items = JSON.parse(act.result.content[0].text).items ?? [];
    if (items.length === 0) fail("activity feed empty after create_event");
    console.log(`list_activity -> ${items.length} items, latest: ${items[0].actorName} ${items[0].text}`);

    // 清場：刪返個 smoke event
    await request("tools/call", { name: "delete_event", arguments: { eventId: created.id } });
    console.log("delete_event -> cleaned up");
  } else {
    console.log("(no MANGOTIME_TOKEN — skip E2E, handshake only)");
  }

  console.log("SMOKE TEST PASS");
  child.kill();
  process.exit(0);
} catch (err) {
  fail(err instanceof Error ? err.message : String(err));
}
