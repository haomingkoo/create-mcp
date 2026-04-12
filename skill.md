# create-mcp

A Claude Code skill for the full MCP development lifecycle — from idea to 100/100 on Smithery.

Detects automatically whether you're starting fresh or auditing an existing server.

## When to Run
- User says "create mcp", "build mcp", "new mcp", "audit mcp", "improve mcp", "mcp quality", "smithery score"
- `/create-mcp`

---

## Auto-detect: which path?

Before doing anything, check the current directory:
- `src/index.ts` or `index.js` exists and registers tools → **Audit path**
- `package.json` has `@modelcontextprotocol/sdk` → **Audit path**
- Otherwise → **Create path**

---

## CREATE PATH — New MCP from scratch

### Phase 1: Requirements Gathering

Ask these questions one group at a time — do not dump them all at once:

**What it does:**
- What data or service does this MCP expose?
- What are the 3 most natural questions a user would ask it?
- Is the data live (API calls) or static (files, hardcoded)?

**Who uses it:**
- Which MCP client? (Claude Desktop, Claude Code, Cursor, Windsurf, all)
- Will it run locally (stdio) or be hosted (HTTP)?

**Auth and access:**
- Does it need API keys or credentials?
- Is it read-only, or does it create/modify things?

**Scale:**
- How frequently will tools be called?
- Does live data change hourly, daily, or rarely?

---

### Phase 2: Design

From the answers, produce:

**Tool list** — name every tool with:
- **Dot notation `domain.action` format** — e.g. `sakura.forecast`, `user.search`, `order.create`
- Group related tools under the same domain prefix (`sakura.*`, `koyo.*`, `fruit.*`)
- Aim for 2–6 tools per domain, max 2 levels deep
- One-line purpose
- Required vs optional parameters
- Dependencies (must call tool A before tool B)

> **Why dot notation?** Smithery scores "Tool names" on navigable tree structure. Uniform `get_*` prefixes cap at 3/5. Dot notation (`domain.action`) achieves 5/5 and 100/100.

**Prompts list** — plan 1–2 prompts that cover common full workflows:
- A prompt wraps a multi-tool workflow into one user-facing action
- Example: a "plan cherry blossom trip" prompt that calls forecast → best dates → spots in sequence

**Architecture decisions:**
- Transport: stdio for local, StreamableHTTP for hosted
- Caching TTL per tool (see TTL reference below)
- Static data: load at startup, never per-call

Present the design and get user confirmation before writing any code.

---

### Phase 3: Build

Scaffold a complete, production-ready MCP server.

#### File structure

```
src/
  index.ts          — McpServer setup, tool + prompt registration
  lib/
    cache.ts        — TTL cache
    fetch.ts        — safeFetch with timeout + error handling
    [domain].ts     — data fetching per domain
package.json
tsconfig.json
smithery.yaml       — for stdio servers
smithery.remote-config.json  — for hosted servers
README.md
```

#### package.json

```json
{
  "name": "your-mcp-name",
  "version": "0.1.0",
  "description": "One clear sentence: what it does, what data source, key differentiator.",
  "keywords": ["mcp", "domain-specific", "keyword"],
  "author": "Your Name",
  "license": "MIT",
  "homepage": "https://github.com/user/repo",
  "repository": { "type": "git", "url": "https://github.com/user/repo.git" },
  "type": "module",
  "bin": { "your-mcp-name": "dist/index.js" },
  "files": ["dist"],
  "scripts": {
    "build": "tsc && chmod +x dist/index.js",
    "start": "node dist/index.js",
    "dev": "tsc --watch"
  },
  "dependencies": {
    "@modelcontextprotocol/sdk": "^1.0.0",
    "zod": "^3.22.0"
  },
  "devDependencies": {
    "typescript": "^5.0.0"
  }
}
```

#### tsconfig.json

```json
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "NodeNext",
    "moduleResolution": "NodeNext",
    "outDir": "dist",
    "rootDir": "src",
    "strict": true,
    "esModuleInterop": true
  },
  "include": ["src"]
}
```

#### src/lib/fetch.ts

```typescript
export async function safeFetch(url: string, options?: RequestInit, timeoutMs = 10000): Promise<Response> {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  try {
    const res = await fetch(url, { ...options, signal: controller.signal });
    if (!res.ok) throw new Error(`HTTP ${res.status}: ${res.statusText}`);
    return res;
  } finally {
    clearTimeout(timer);
  }
}
```

#### src/lib/cache.ts

```typescript
interface CacheEntry<T> { data: T; expires: number; }
const store = new Map<string, CacheEntry<unknown>>();

export const TTL = {
  WEATHER:   30 * 60 * 1000,   // 30 min — live conditions
  FORECAST:   4 * 60 * 60 * 1000,   // 4 h — daily forecasts
  DAILY:      6 * 60 * 60 * 1000,   // 6 h — data updated daily
  STATIC:  365 * 24 * 60 * 60 * 1000, // 1 year — never changes
};

export async function getOrFetch<T>(key: string, ttlMs: number, fn: () => Promise<T>): Promise<T> {
  const hit = store.get(key);
  if (hit && Date.now() < hit.expires) return hit.data as T;
  const data = await fn();
  store.set(key, { data, expires: Date.now() + ttlMs });
  return data;
}
```

#### src/index.ts — complete server template

```typescript
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";
import type { ToolAnnotations } from "@modelcontextprotocol/sdk/types.js";
import { getOrFetch, TTL } from "./lib/cache.js";
import { safeFetch } from "./lib/fetch.js";
import { readFileSync } from "fs";
import { resolve } from "path";

// ── Annotation constants ──
const READONLY: ToolAnnotations = { readOnlyHint: true, idempotentHint: true };
const READONLY_EXTERNAL: ToolAnnotations = { readOnlyHint: true, idempotentHint: true, openWorldHint: true };
const WRITE: ToolAnnotations = { readOnlyHint: false, idempotentHint: false };
const DESTRUCTIVE: ToolAnnotations = { readOnlyHint: false, destructiveHint: true };

// ── Static data — load once at startup, never inside handlers ──
function loadStaticJSON(filename: string) {
  const p = resolve(process.cwd(), "data", filename);
  try { return JSON.parse(readFileSync(p, "utf-8")); }
  catch { return null; }
}
const STATIC = {
  items: loadStaticJSON("items.json"),
};

// ── Server ──
const server = new McpServer(
  { name: "your-mcp-name", version: "0.1.0" },
  {
    instructions: `[Server name]. [One sentence: what it covers and data source].

Tool usage guide:
- Start with [domain.overview] for the big picture
- Use [domain.search] when the user gives specific criteria  
- Call [domain.detail] only after narrowing down with search
- [weather.forecast] last — check when conditions affect timing

All tools are read-only. No auth required.`
  }
);

// ── Tools ──
server.registerTool(
  "domain.overview",  // dot notation: domain.action
  {
    title: "Overview of Domain Items",   // human-readable, shown in Claude UI
    description: "Get a summary of all [items] with current status. Use this first before narrowing to specific items. Call domain.detail next for a single item.",
    inputSchema: {
      filter: z.string().optional().describe("Optional filter by category. Accepted values: 'all', 'active', 'pending'. Defaults to 'all'.").meta({ title: "Category Filter" }),
    },
    annotations: READONLY_EXTERNAL,  // READONLY_EXTERNAL if calling an API, READONLY if static
  },
  async ({ filter }) => {
    try {
      const data = await getOrFetch(`overview:${filter ?? "all"}`, TTL.FORECAST, () =>
        safeFetch(`https://api.example.com/items?filter=${filter ?? "all"}`).then(r => r.json())
      );
      return { content: [{ type: "text", text: JSON.stringify(data) }] };
    } catch (err) {
      return {
        isError: true,
        content: [{ type: "text", text: `Failed to load overview: ${err instanceof Error ? err.message : String(err)}. Try domain.search with a specific query instead.` }]
      };
    }
  }
);

// ── Prompts — register 1–2 for the most common full workflows ──
server.registerPrompt(
  "plan_full_workflow",
  {
    name: "plan_full_workflow",
    description: "Guide the user through the complete [domain] workflow: overview → search → detail.",
    argsSchema: {
      user_goal: z.string().describe("What the user wants to accomplish, e.g. 'find the best X for Y'"),
    },
  },
  ({ user_goal }) => ({
    messages: [{
      role: "user",
      content: {
        type: "text",
        text: `Help me with: ${user_goal}. Use domain.overview to get started, then domain.search to narrow down, then domain.detail for specifics.`,
      },
    }],
  })
);

// ── Transport ──
const transport = new StdioServerTransport();
await server.connect(transport);
```

---

### Tool description rules (enforced on every tool)

**Bad:**
> `"This tool provides information about items"`

**Good:**
> `"Get live status for all [items] in the system. Filter by category. Call domain.search next to narrow results by date or region."`

Rules:
- Start with an action verb: Get, List, Search, Find, Create
- Name the resource specifically ("cherry blossom bloom percentages", not "seasonal data")
- State the call-next tool if there's a natural follow-up
- State what NOT to use it for if there's overlap with another tool
- Max 2 sentences — agents don't read long descriptions

**Parameter descriptions:**
```typescript
city: z.string()
  .describe("City name such as 'Tokyo', 'Kyoto', 'Osaka', or 'Sapporo'. Partial case-insensitive matching is accepted.")
  .meta({ title: "City Name" }),  // .meta({ title }) sets display name in Claude UI
```
Every parameter needs both `.describe()` and `.meta({ title })`.

---

### smithery.yaml (stdio servers)

```yaml
startCommand:
  type: stdio
  configSchema:
    type: object
    properties:
      apiKey:
        type: string
        title: "API Key"
        description: "Your API key from example.com/settings"
    required: []
  commandFunction: |-
    (config) => ({
      command: "npx",
      args: ["your-mcp-name"],
      env: config.apiKey ? { API_KEY: config.apiKey } : {}
    })
```

If the server has no auth or config, use:
```yaml
startCommand:
  type: stdio
  configSchema:
    type: object
    properties: {}
    required: []
  commandFunction: |-
    (config) => ({ command: "npx", args: ["your-mcp-name"] })
```

### smithery.remote-config.json (hosted HTTP servers)

```json
{
  "type": "object",
  "properties": {
    "apiKey": {
      "type": "string",
      "title": "API Key",
      "description": "Optional API key for authenticated endpoints"
    }
  },
  "required": []
}
```

If no config needed: `{ "type": "object", "properties": {}, "required": [] }`

---

## AUDIT PATH — Existing MCP

### Step 1: Map the server

Read `src/index.ts`. Build a table:

| Tool name | Has title? | Description verb-first? | All params have .describe()? | Annotations set? | Dot notation? |
|---|---|---|---|---|---|

Also check:
- Are any prompts registered?
- Is there a `cache.ts` or equivalent?
- Is static data loaded at startup or inside handlers?

### Step 2: Score every dimension

| Dimension | Points | Check |
|---|---|---|
| Tool descriptions | 12pt | Verb-first, ≤2 sentences, states next tool |
| Parameter descriptions | 11pt | Every input has `.describe()` and `.meta({ title })` |
| Annotations | 7pt | `readOnlyHint` on all tools; `openWorldHint` for external APIs |
| **Tool names** | **5pt** | **Dot notation `domain.action` — NOT `get_*` snake_case** |
| Prompts | 5pt | At least 1 prompt registered covering a real workflow |
| Resources | 5pt | **Awarded automatically — no action needed** |
| Server metadata | 30pt | Description + homepage in package.json; icon + display name set in Smithery UI |
| Config UX | 25pt | `smithery.yaml` with `configSchema` (stdio) or `smithery.remote-config.json` (hosted); **make config optional, not required** |
| Server instructions | — | `instructions` field in McpServer options |
| Static data | — | Loaded at startup, not per-call |
| Caching | — | All live API calls cached with correct TTL |
| Error handling | — | All handlers return `isError: true`, never throw |
| README | — | Clear first paragraph, copy-pasteable install, tools table |

**Score ladder (approximate):**
- ~60: tool descriptions exist but noun-first, no annotations, missing package.json fields
- ~75: descriptions fixed, annotations added, package.json complete
- ~85: server instructions added, parameter descriptions complete
- ~90: prompts registered, caching and error handling clean
- ~95: README polished, smithery.yaml with configSchema
- ~98: all code dimensions maxed, server metadata set in Smithery UI
- **100: dot notation tool names**

### Step 3: Fix everything

Apply all fixes in one pass. Do not ask for confirmation per fix — do it all, then report.

Priority order (highest score impact first):
1. Tool names → dot notation (5pt, also unlocks the ceiling)
2. Tool descriptions → verb-first, 2 sentences, call-next (12pt)
3. Parameter descriptions → `.describe()` + `.meta({ title })` on every input (11pt)
4. Annotations → `READONLY` / `READONLY_EXTERNAL` / `WRITE` / `DESTRUCTIVE` on all tools (7pt)
5. Prompts → register 1–2 for main workflows (5pt)
6. Server instructions → add `instructions` to McpServer if missing
7. Static data → move any per-call file reads to module level
8. Caching → wrap all live API calls in `getOrFetch()`
9. Error handling → wrap all handlers in try/catch returning `isError: true`
10. package.json → description, keywords, author, license, homepage, repository
11. smithery.yaml / smithery.remote-config.json → add configSchema
12. README → clear first paragraph, install snippet, tools table

### Step 4: Flag what requires manual action

Some score points require action in the Smithery UI, not code:
- **Icon** (7pt of Server Metadata) — upload at smithery.ai → Settings → Icon
- **Display name** (3pt) — set at smithery.ai → Settings → Display Name
- **Server description** (10pt) — set at smithery.ai → Settings (separate from package.json description)

Remind the user to complete these after pushing code.

### Step 5: Report

```
Fixed:
- Tool names: renamed to dot notation (sakura.forecast, koyo.spots, etc.) → +5pt
- Tool descriptions: rewrote 8/12 that were noun-first or over 2 sentences → +est. 4pt
- Annotations: added READONLY to all 12 tools, READONLY_EXTERNAL on 4 with API calls → +7pt
- Parameter descriptions: added .describe() + .meta() to 24 parameters across 12 tools → +11pt
- Prompts: added plan_trip and explore_by_date prompts → +5pt
- package.json: added homepage, repository, expanded keywords → est. score recovery
- smithery.yaml: added configSchema block → +25pt (Config UX)

Manual action needed in Smithery UI:
- Upload server icon → +7pt
- Set display name → +3pt
- Set server description in Smithery settings → +10pt

Estimated impact:
- Before: ~62/100
- After (code): ~85/100
- After (code + Smithery UI): ~100/100
```

---

## PUBLISH PATH

Run after Create or Audit is complete.

### Pre-publish checklist

- [ ] Version bumped in `package.json`, `server.json` if exists, any hardcoded version strings
- [ ] `npm run build` passes with no errors
- [ ] README has: what it does, install snippet, tools table, hosted endpoint if applicable
- [ ] `smithery.yaml` or `smithery.remote-config.json` exists

### npm publish

```bash
npm run build && npm publish --otp=YOUR_OTP
```

### Smithery — hosted HTTP servers

```bash
npx @smithery/cli mcp publish \
  "https://YOUR_DOMAIN/mcp" \
  -n YOUR_GITHUB_USERNAME/YOUR_REPO_NAME \
  --config-schema "$(cat smithery.remote-config.json)"
```

### Smithery — stdio servers

1. Push to GitHub
2. smithery.ai → Add Server → paste GitHub URL
3. Trigger scan, verify score

### Complete the Smithery UI metadata (worth 20pt)

After the server is indexed:
1. smithery.ai → your server → Settings
2. Upload an icon (PNG, ideally 256×256) → **+7pt**
3. Set display name (human-readable, not the npm slug) → **+3pt**
4. Set server description (1–2 sentences, different from package.json) → **+10pt**

These 20 points are only available through the UI. No code change will earn them.

### Other directories

| Directory | URL | What you need |
|---|---|---|
| mcp.so | mcp.so/submit | GitHub URL + npx config JSON |
| Glama | glama.ai/mcp/servers | GitHub URL only |
| PulseMCP | pulsemcp.com | GitHub URL + description |
| awesome-mcp-servers | Fork punkpeye/awesome-mcp-servers, add one line | `🤖🤖🤖` in PR title |

---

## Smithery scoring reference

| Category | Points | How to earn it |
|---|---|---|
| Tool descriptions | 12pt | Verb-first, ≤2 sentences, states next tool |
| Parameter descriptions | 11pt | `.describe()` + `.meta({ title })` on every param |
| Annotations | 7pt | `readOnlyHint` minimum; `openWorldHint` for APIs |
| Tool names | 5pt | Dot notation `domain.action` — NOT `get_*` |
| Prompts | 5pt | Register ≥1 prompt for a real workflow |
| Resources | 5pt | Awarded automatically — no action needed |
| Server description | 10pt | Set in Smithery UI (not just package.json) |
| Homepage | 10pt | Set in package.json `homepage` field |
| Icon | 7pt | Upload in Smithery UI |
| Display name | 3pt | Set in Smithery UI |
| Config schema | 10pt | `smithery.yaml` with `configSchema` block |
| Optional config | 15pt | Config schema with optional (not required) fields |

**Total: 100pt**

### The dot notation rule

Smithery's exact criteria (from the score tooltip): *"Measures how well tool names form a navigable tree using dot-notation (e.g., admin.tools.list). Scores higher when hierarchy depth matches the ideal for the number of tools — flat lists of many tools and unnecessarily deep nesting both reduce the score."*

Uniform `get_*` caps at 3/5 regardless of how descriptive the names are. Use `domain.action`:

```
sakura.forecast    koyo.forecast    weather.forecast
sakura.spots       koyo.spots       flowers.spots
sakura.best_dates  koyo.best_dates  fruit.seasons
                   kawazu.forecast  fruit.farms
                                    festivals.list
```

2–6 tools per namespace, max 2 levels deep. This is what moves Tool names from 3/5 to 5/5 and unlocks 100/100.
