# create-mcp

A Claude Code skill for the full MCP development lifecycle — from idea to production-ready server.

Detects automatically whether you're starting fresh or auditing an existing server.

## When to Run
- User says "create mcp", "build mcp", "new mcp", "audit mcp", "improve mcp", "mcp quality", "smithery score"
- `/create-mcp`

---

## Auto-detect: which path?

Before doing anything, check for an existing MCP:
- If `src/index.ts` (or `index.js`) exists and registers tools → **Audit path**
- If `package.json` has `@modelcontextprotocol/sdk` → **Audit path**
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
- Snake_case name starting with a verb (`get_`, `search_`, `create_`, `list_`)
- One-line purpose
- Required vs optional parameters
- Dependencies (must call tool A before tool B)

**Architecture decisions:**
- Transport: stdio for local, StreamableHTTP for hosted
- Caching: TTL per tool based on data freshness
- Static data: load at startup, never per-call

Present the design and get confirmation before writing any code.

---

### Phase 3: Build

Scaffold a complete, production-ready MCP server:

**File structure:**
```
src/
  index.ts          — McpServer setup, tool registration
  lib/
    cache.ts        — TTL cache with getOrFetch()
    fetch.ts        — safeFetch with timeout + error handling
    [domain].ts     — data fetching per domain
package.json
tsconfig.json
README.md
```

**Every tool must have:**
- Description starting with a verb, max 2 sentences, states what to call next
- Parameter descriptions on every input
- Correct annotations (READONLY / WRITE / DESTRUCTIVE)
- Try/catch returning `{ isError: true, content: [...] }` — never throw

**McpServer must have:**
- `instructions` field: tool routing guide, call order, what NOT to use it for
- Correct `name` and `version` matching package.json

**package.json must have:**
- `description`, `keywords` (include "mcp"), `author`, `license`
- `homepage`, `repository`
- `bin` field if stdio transport

**Static data:**
```typescript
// Load once at startup — never inside tool handlers
const DATA = {
  items: loadStaticJSON("data.json"),
};
```

**Live data cache pattern:**
```typescript
const READONLY: ToolAnnotations = { readOnlyHint: true, idempotentHint: true };

server.registerTool("get_something", {
  title: "Human Readable Title",
  description: "Get [resource] for [use case]. Call [other_tool] first for [context].",
  inputSchema: { query: z.string().describe("...") },
  annotations: READONLY,
}, async ({ query }) => {
  try {
    const data = await cache.getOrFetch(`key:${query}`, TTL.FORECAST, () => fetchData(query));
    return { content: [{ type: "text", text: JSON.stringify(data) }] };
  } catch (err) {
    return { isError: true, content: [{ type: "text", text: `Failed: ${err instanceof Error ? err.message : String(err)}. Try [alternative].` }] };
  }
});
```

---

## AUDIT PATH — Existing MCP

### Step 1: Map the server

Read `src/index.ts`. List every tool with:
- Name
- Has description? Starts with verb?
- Has parameter descriptions?
- Has annotations?
- Has title?

### Step 2: Score against all dimensions

| Dimension | Check |
|---|---|
| **Tool descriptions** | Verb-first, ≤2 sentences, states what to call next |
| **Parameter descriptions** | Every input has `.describe()` |
| **Annotations** | `readOnlyHint` set on all tools |
| **Tool titles** | `title` field set (MCP 2025-06-18 spec) |
| **Server instructions** | `instructions` in McpServer options, covers tool routing |
| **Static data** | Loaded at startup, not per-call |
| **Caching** | All live API calls cached with appropriate TTL |
| **Error handling** | All handlers have try/catch, return `isError` not throw |
| **package.json** | description, keywords, author, license, homepage, repository |
| **README** | First paragraph clear, copy-pasteable install snippet, tools listed |

### Step 3: Fix everything

Apply all fixes in one pass. Don't ask for confirmation per fix — do it all, then report.

### Step 4: Report

```
Fixed:
- [what changed] → [why / which dimension]

Remaining (manual action needed):
- [anything that can't be automated]

Estimated Smithery impact:
- Before: ~X/100
- After: ~Y/100
```

---

## PUBLISH PATH — after Create or Audit

Run this after build or audit is complete.

### Checklist before publishing

- [ ] Version bumped in `package.json`, `server.json` (if exists), and any hardcoded version strings
- [ ] `npm run build` passes with no errors
- [ ] README has: what it does, install snippet, tools table, hosted endpoint (if any)
- [ ] `smithery.yaml` exists with `startCommand` and `configSchema` (if the server has connection preferences)

### npm publish

```bash
npm run build && npm publish
```

### Smithery

1. Go to smithery.ai → Add Server → paste GitHub URL
2. Fill in connection settings with your defaults
3. Trigger a scan and verify score

### Other directories

| Directory | URL | What you need |
|---|---|---|
| mcp.so | mcp.so/submit | GitHub URL + npx config JSON |
| Glama | glama.ai/mcp/servers | GitHub URL only |
| PulseMCP | pulsemcp.com | GitHub URL + description |
| awesome-mcp-servers | PR to punkpeye/awesome-mcp-servers | One line in README, `🤖🤖🤖` in PR title |

---

## Smithery scoring reference

| Category | Points | Key requirements |
|---|---|---|
| Tool descriptions | 12pt | Verb-first, concise, mentions dependencies |
| Parameter descriptions | 11pt | `.describe()` on every parameter |
| Annotations | 7pt | `readOnlyHint` minimum on all tools |
| Tool names | 5pt | Snake_case, action verbs, distinct |
| Server capabilities | 10pt | Prompts registered (5pt bonus) |
| Server metadata | 30pt | Description, homepage, icon, display name |
| Configuration UX | 25pt | `configSchema` in smithery.yaml |

Total: 100pt. Common ceiling at 98 — "Tool names" rubric is partially opaque.
