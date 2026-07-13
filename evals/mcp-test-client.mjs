#!/usr/bin/env node
// Minimal raw JSON-RPC (newline-delimited) stdio test client for MCP servers.
// Spawns `command args...` in `cwd`, replays `steps` against its stdin/stdout,
// then checks `assertions` against the collected responses.
//
// Usage: node mcp-test-client.mjs <spec.json>
//
// Spec shape (see evals/specs/*.json for real examples):
//   {
//     "command": "npx", "args": ["tsx", "server.ts"], "cwd": "../files",
//     "timeoutMs": 5000,
//     "steps": [
//       { "id": "init", "method": "initialize", "params": {...} },
//       { "id": "initialized", "notify": "notifications/initialized" },
//       { "id": "tools", "method": "tools/list" },
//       { "id": "read", "method": "resources/read", "params": { "uri": "{{tools.result.resources.0.uri}}" } }
//     ],
//     "assertions": [
//       { "desc": "...", "step": "tools", "path": "result.tools", "type": "includesField", "field": "name", "value": "x" },
//       { "desc": "...", "step": "init", "path": "result.capabilities.completions", "type": "notExists" },
//       { "desc": "...", "step": "tools", "path": "result.tools.0.name", "type": "equals", "value": "x" }
//     ]
//   }
//
// Exit codes: 0 all assertions passed, 1 an assertion failed, 2 usage/spawn/timeout error.

import { spawn } from "node:child_process";
import { readFileSync } from "node:fs";
import { createInterface } from "node:readline";
import { resolve as resolvePath, dirname } from "node:path";

const specPath = process.argv[2];
if (!specPath) {
  console.error("usage: mcp-test-client.mjs <spec.json>");
  process.exit(2);
}
const spec = JSON.parse(readFileSync(specPath, "utf-8"));
const cwd = resolvePath(dirname(specPath), spec.cwd ?? ".");

const child = spawn(spec.command, spec.args ?? [], { cwd, stdio: ["pipe", "pipe", "inherit"] });
child.on("error", (err) => {
  console.error(`FATAL: failed to spawn "${spec.command}": ${err.message}`);
  process.exit(2);
});

const pending = new Map();
child.on("exit", (code, signal) => {
  for (const res of pending.values()) res({ error: { code: -1, message: `server exited early (code=${code} signal=${signal})` } });
  pending.clear();
});

const rl = createInterface({ input: child.stdout });
rl.on("line", (line) => {
  if (!line.trim()) return;
  let msg;
  try { msg = JSON.parse(line); } catch { return; } // ignore non-JSON-RPC stdout noise
  if (msg.id !== undefined && pending.has(msg.id)) {
    pending.get(msg.id)(msg);
    pending.delete(msg.id);
  }
});

// A string param of the form "{{stepId.path}}" is replaced with that earlier step's
// response value at that path (via `get`, defined below), so later steps can act on
// values only known at runtime (e.g. a resource URI discovered via resources/list).
function substitute(value) {
  if (typeof value === "string") {
    const m = value.match(/^\{\{(\w+)\.(.+)\}\}$/);
    return m ? get(responses[m[1]], m[2]) : value;
  }
  if (Array.isArray(value)) return value.map(substitute);
  if (value && typeof value === "object") return Object.fromEntries(Object.entries(value).map(([k, v]) => [k, substitute(v)]));
  return value;
}

let nextId = 1;
function request(method, params) {
  return new Promise((res) => {
    const id = nextId++;
    pending.set(id, res);
    child.stdin.write(JSON.stringify({ jsonrpc: "2.0", id, method, params: params ?? {} }) + "\n");
  });
}
function notify(method, params) {
  child.stdin.write(JSON.stringify({ jsonrpc: "2.0", method, params: params ?? {} }) + "\n");
}
function withTimeout(promise, ms, label) {
  return Promise.race([
    promise,
    new Promise((_, reject) => setTimeout(() => reject(new Error(`timed out waiting for step "${label}"`)), ms)),
  ]);
}

const responses = {};
try {
  for (const step of spec.steps) {
    const params = substitute(step.params);
    if (step.notify) {
      notify(step.notify, params);
      continue;
    }
    responses[step.id] = await withTimeout(request(step.method, params), spec.timeoutMs ?? 5000, step.id);
  }
} catch (err) {
  console.error(`FATAL: ${err.message}`);
  child.kill();
  process.exit(2);
}
child.kill();

function get(obj, path) {
  return path.split(".").reduce((cur, key) => (cur == null ? undefined : cur[key]), obj);
}

let failed = 0;
for (const a of spec.assertions) {
  const value = get(responses[a.step], a.path);
  let ok;
  if (a.type === "equals") ok = value === a.value;
  else if (a.type === "notExists") ok = value === undefined;
  else if (a.type === "exists") ok = value !== undefined;
  else if (a.type === "includesField") ok = Array.isArray(value) && value.some((el) => el?.[a.field] === a.value);
  else {
    console.error(`FATAL: unknown assertion type "${a.type}"`);
    process.exit(2);
  }

  if (ok) {
    console.log(`PASS  ${a.desc}`);
  } else {
    failed++;
    const expected = a.type === "includesField" ? `array containing {${a.field}: ${JSON.stringify(a.value)}}` : JSON.stringify(a.value);
    console.log(`FAIL  ${a.desc}`);
    console.log(`      step "${a.step}" path "${a.path}": expected ${expected}, got ${JSON.stringify(value)}`);
  }
}

console.log(`\n${spec.assertions.length - failed}/${spec.assertions.length} assertions passed`);
process.exit(failed ? 1 : 0);
