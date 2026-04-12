---
name: create-mcp
description: >
  Full MCP development lifecycle skill — from idea to 100/100 on Smithery.
  Use this skill whenever the user wants to create, build, scaffold, audit, improve, or publish
  an MCP (Model Context Protocol) server. Also triggers on: "mcp quality", "smithery score",
  "build mcp", "new mcp", "audit mcp", "/create-mcp". Covers both creating from scratch and
  improving an existing server. Guides through tool design (dot notation naming), TypeScript
  scaffolding, all 10 Smithery quality dimensions, npm publish, and directory submission.
  Always use this skill for any MCP-related task — do not wing it without the skill.
---

A Claude Code skill for the full MCP development lifecycle — from idea to 100/100 on Smithery.

Detects automatically whether you're starting fresh or auditing an existing server.

---

## Auto-detect: which path?

Before doing anything, check the current directory:
- `src/index.ts` or `index.js` exists and registers tools → **AUDIT PATH**
- `package.json` has `@modelcontextprotocol/sdk` → **AUDIT PATH**
- Otherwise → **CREATE PATH**

---

## CREATE PATH — New MCP from scratch

### Phase 1: Requirements Gathering

Ask these questions one group at a time:

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

From the answers, produce a **tool list** with dot notation names:

- **Format:** `domain.action` — e.g. `crypto.price`, `user.search`, `order.create`
- **Grouping:** 2–6 tools per domain prefix, max 2 levels deep
- **Why this matters:** Smithery scores "Tool names" on navigable tree structure. Uniform `get_*` prefixes cap at 3/5. Dot notation achieves 5/5 and is one of the two final unlocks for 100/100.

For each tool, specify: one-line purpose, required vs optional parameters, dependencies (must call A before B).

Also plan **1–2 prompts** that cover common full workflows (e.g. a "plan cherry blossom trip" prompt that chains forecast → best dates → spots).

Present the design and get user confirmation before writing code.

---

### Phase 3: Build

Read `references/typescript-boilerplate.md` now — it has the complete templates for `package.json`, `tsconfig.json`, `src/lib/cache.ts`, `src/lib/fetch.ts`, and `src/index.ts`.

Scaffold this structure:

```
src/
  index.ts              — McpServer, registerTool, registerPrompt
  lib/
    cache.ts            — getOrFetch with TTL constants
    fetch.ts            — safeFetch with timeout
    [domain].ts         — data fetching per domain
package.json            — all metadata fields (see boilerplate)
tsconfig.json
smithery.yaml           — stdio servers (see references/smithery-config.md)
smithery.remote-config.json  — hosted servers (see references/smithery-config.md)
README.md
```

Key things to get right in every build:
- Tool annotations on every tool: `READONLY`, `READONLY_EXTERNAL` (for API calls), `WRITE`, `DESTRUCTIVE`
- Server `instructions` field — acts as the AI client's routing guide
- All live API calls wrapped in `getOrFetch()` with the right TTL constant
- All handlers wrapped in try/catch returning `isError: true` (never throw)
- Static data (files, hardcoded lists) loaded at module level, never inside handlers
- Every parameter has `.describe()` AND `.meta({ title })`
- **API key handling**: if using `required: []` in smithery.yaml (key is optional), the server must handle a missing key gracefully — don't call `process.exit(1)` when the key is absent. Instead, let the handler return `isError: true` with a helpful message. If the server truly cannot function without the key, either set `required: ["apiKey"]` or ensure the `commandFunction` always passes the env var so it's always present when Smithery runs it.

See `references/smithery-config.md` for smithery.yaml and smithery.remote-config.json templates.

For a plain-language explanation of stdio vs HTTP transports and references, see `references/deployment-guide.md`.

---

## AUDIT PATH — Existing MCP

### Step 1: Map the server

Read `src/index.ts`. Build a table:

| Tool name | Has title? | Description verb-first? | All params have .describe() + .meta()? | Annotations set? | Dot notation? |
|---|---|---|---|---|---|

Also check: prompts registered? cache.ts present? static data inside vs outside handlers?

### Step 2: Score every dimension

Read `references/smithery-config.md` for the full scoring table and score ladder.

Quick checklist:
- [ ] Tool names use `domain.action` dot notation (5pt — final unlock for 100/100)
- [ ] Tool descriptions: verb-first, ≤2 sentences, states next tool (12pt)
- [ ] All params have `.describe()` + `.meta({ title })` (11pt)
- [ ] All tools have annotations (`readOnlyHint` minimum; `openWorldHint` for APIs) (7pt)
- [ ] At least 1 prompt registered for a real workflow (5pt)
- [ ] Resources: auto-awarded, no action needed (5pt)
- [ ] package.json: `description`, `keywords`, `author`, `license`, `homepage`, `repository` (10pt)
- [ ] smithery.yaml or smithery.remote-config.json with `required: []` (25pt)
- [ ] Smithery UI: icon + display name + server description (20pt — manual)

### Step 3: Fix everything in one pass

Priority order (highest score impact first):

1. Tool names → dot notation
2. Tool descriptions → verb-first, 2 sentences, call-next
3. Parameter descriptions → `.describe()` + `.meta({ title })` on every input
4. Annotations → READONLY / READONLY_EXTERNAL / WRITE / DESTRUCTIVE
5. Prompts → register 1–2 for main workflows
6. Server instructions → add `instructions` to McpServer if missing
7. Static data → move any per-call file reads to module level
8. Caching → wrap all live API calls in `getOrFetch()`
9. Error handling → wrap all handlers in try/catch returning `isError: true`
10. package.json → all metadata fields
11. smithery.yaml / smithery.remote-config.json → add configSchema with `required: []`
12. README → clear first paragraph, install snippet, tools table

See `references/typescript-boilerplate.md` for correct code patterns.

**Audit output requirement — generate these files** (write the actual content, don't just list what needs to change):
- `package.json` — all fields filled with real project values; no placeholder text for `homepage`, `repository`, or `author`
- `smithery.yaml` (stdio) or `smithery.remote-config.json` (hosted HTTP) — use templates from `references/smithery-config.md`

The audit is only complete when both files exist on disk. A score report without the generated files misses ~35pt of the total.

### Step 4: Report

```
Fixed:
- Tool names: renamed to dot notation (domain.action) → +5pt
- Tool descriptions: rewrote X/N that were noun-first or over 2 sentences → est. +Xpt
- Annotations: added READONLY to all N tools, READONLY_EXTERNAL on N with API calls → +7pt
- Parameter descriptions: added .describe() + .meta() to N parameters → +11pt
- Prompts: added [workflow_name] prompt → +5pt
- package.json: added homepage, repository, expanded keywords
- smithery.yaml: added configSchema with required: []

Manual action needed in Smithery UI:
- Upload server icon → +7pt
- Set display name → +3pt
- Set server description in Smithery settings → +10pt

Estimated impact: ~XX → ~YY (code) → ~100 (code + Smithery UI)
```

---

## PUBLISH PATH

Run after Create or Audit is complete.

### Pre-publish checklist

- [ ] Version bumped in `package.json`
- [ ] `npm run build` passes with no errors
- [ ] README has: what it does, install snippet, tools table, hosted endpoint if applicable
- [ ] `smithery.yaml` or `smithery.remote-config.json` exists

### Publish

```bash
npm run build && npm publish --otp=YOUR_OTP
```

### Smithery — hosted servers

```bash
npx @smithery/cli mcp publish \
  "https://YOUR_DOMAIN/mcp" \
  -n YOUR_GITHUB_USERNAME/YOUR_REPO_NAME \
  --config-schema "$(cat smithery.remote-config.json)"
```

### Smithery — stdio servers

Push to GitHub → smithery.ai → Add Server → paste GitHub URL → trigger scan.

### Complete Smithery UI metadata (20pt)

After indexing: smithery.ai → your server → Settings
- Upload icon (PNG, 256×256) → **+7pt**
- Set display name → **+3pt**
- Set server description (1–2 sentences) → **+10pt**

These 20 points require manual action in the UI. No code change earns them.

### Other directories

| Directory | URL | What you need |
|---|---|---|
| mcp.so | mcp.so/submit | GitHub URL + npx config JSON |
| Glama | glama.ai/mcp/servers | GitHub URL only |
| PulseMCP | pulsemcp.com | GitHub URL + description |
| awesome-mcp-servers | Fork punkpeye/awesome-mcp-servers, add one line | `🤖🤖🤖` in PR title |
