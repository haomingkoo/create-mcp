---
name: create-mcp
description: >
  Full MCP development lifecycle skill — from idea to production-ready MCP.
  Use this skill whenever the user wants to create, build, scaffold, audit, improve, or publish
  an MCP (Model Context Protocol) server. Also triggers on: "mcp quality", "smithery score",
  "build mcp", "new mcp", "audit mcp", "/create-mcp". Covers both creating from scratch and
  improving an existing server. Guides through client-compatible tool design, TypeScript
  scaffolding, all 10 Smithery quality dimensions, AI-search visibility, ChatGPT app/connector
  setup, MCPB packaging, npm publish, hosted deploy verification, and directory submission.
  Always use this skill for any MCP-related task — do not wing it without the skill.
---

A Claude Code skill for the full MCP development lifecycle — from idea to production-ready server.

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
- Should non-MCP users find useful answers through ChatGPT Search, Google AI Mode, Perplexity, or web search?
- Does ChatGPT need this as an app/connector, or is web citation enough?

**Auth and access:**
- Does it need API keys or credentials?
- Is it read-only, or does it create/modify things?

**Scale:**
- How frequently will tools be called?
- Does live data change hourly, daily, or rarely?

---

### Phase 2: Design

**Primitive decision.** Before listing tools, route each planned capability through
`references/primitives-guide.md`'s "Which primitive?" table: side effects/writes/computation
→ tool (default); static read-only dataset → resource; parameterized hierarchical read →
resource template; recurring multi-tool workflow → prompt. Tools-only is a valid answer —
don't force resources or prompts onto a server that doesn't need them.

From the answers, produce a **tool list** with client-compatible names:

- **Default format:** `domain_action` — e.g. `crypto_price`, `user_search`, `order_create`
- **Avoid:** vague `get_*` names when the domain/action can be clearer
- **Only use dot notation** (`domain.action`) if the target clients are verified to support it reliably
- **Tradeoff:** Smithery may score dotted names higher, but client execution reliability wins. A 98/100 score with Claude-compatible tool names is better than 100/100 with names the target client cannot call.

For each tool, specify: one-line purpose, required vs optional parameters, dependencies (must call A before B).

Also plan **1–2 prompts** that cover common full workflows (e.g. a "plan cherry blossom trip" prompt that chains forecast → best dates → spots).

If the server is hosted and exposes public/current data, also produce a **discovery surface plan**:
- MCP endpoint: `/mcp`
- AI-search page(s): topic HTML plus plain text/Markdown for high-intent queries
- JSON API(s) when useful for deterministic citations
- `/llms.txt`, `/sitemap.xml`, `/robots.txt`, and `/health`
- ChatGPT app/connector metadata: name, operational description, connector URL
- A single source-of-truth config for site URLs, MCP endpoint, connector metadata, example locations, timing guidance, and common output copy. Frontend pages, MCP instructions, text endpoints, README snippets, and registry metadata must read from or be checked against that source.

State the boundary explicitly: ChatGPT web chat/search may cite pages, but it cannot call arbitrary MCP tools unless the MCP endpoint is connected as an app/connector or the environment is an MCP client.

Present the design and get user confirmation before writing code.

---

### Phase 3: Build

Read `references/typescript-boilerplate.md` now — it has the complete templates for `package.json`, `tsconfig.json`, `src/lib/cache.ts`, `src/lib/fetch.ts`, and `src/index.ts`.

Also read `references/discovery-guide.md` when any of these are true:
- hosted HTTP server
- public/current data
- user asks about ChatGPT, AI search, SEO, discoverability, adoption, or "why nobody uses my MCP"
- local stdio server targets nontechnical Claude Desktop users

Scaffold this structure:

```
src/
  index.ts              — McpServer, registerTool, registerPrompt
  lib/
    site-config.ts      — single source of truth for URLs, connector metadata, examples, and shared copy
    cache.ts            — getOrFetch with TTL constants
    fetch.ts            — safeFetch with timeout
    [domain].ts         — data fetching per domain
package.json            — all metadata fields (see boilerplate)
tsconfig.json
smithery.yaml           — stdio servers (see references/smithery-config.md)
smithery.remote-config.json  — hosted servers (see references/smithery-config.md)
server.json             — official registry metadata when publishing publicly
public/                 — only for hosted HTTP servers with web/AI-search surfaces
README.md
```

Key things to get right in every build:
- Tool annotations on every tool: `READONLY`, `READONLY_EXTERNAL` (for API calls), `WRITE`, `DESTRUCTIVE`
- Server `instructions` field — acts as the AI client's routing guide
- All live API calls wrapped in `getOrFetch()` with the right TTL constant
- All handlers wrapped in try/catch returning `isError: true` (never throw)
- Static data (files, hardcoded lists) loaded at module level, never inside handlers
- Every parameter has `.describe()` AND `.meta({ title })`
- For hosted public data, provide crawlable pages/APIs for AI search in addition to `/mcp`
- For ChatGPT, document app/connector setup; do not imply normal ChatGPT web chat can run MCP tools
- For local stdio servers aimed at nontechnical users, add MCPB packaging guidance
- Single source of truth: do not hardcode URLs, connector metadata, example cities, timing guidance, or "what tool next" copy separately in frontend and backend. Put them in a shared config/module and render frontend/static pages from tokens or validate them with a build-time check.
- **API key handling**: if using `required: []` in smithery.yaml (key is optional), the server must handle a missing key gracefully — don't call `process.exit(1)` when the key is absent. Instead, let the handler return `isError: true` with a helpful message. If the server truly cannot function without the key, either set `required: ["apiKey"]` or ensure the `commandFunction` always passes the env var so it's always present when Smithery runs it.

See `references/smithery-config.md` for smithery.yaml and smithery.remote-config.json templates.

For a plain-language explanation of stdio vs HTTP transports and references, see `references/deployment-guide.md`.

For discoverability, ChatGPT connector setup, AI-search pages, MCPB bundles, and publish/deploy verification, see `references/discovery-guide.md`.

---

## AUDIT PATH — Existing MCP

### Step 1: Map the server

Read `src/index.ts`. Build a table:

| Tool name | Has title? | Description verb-first? | All params have .describe() + .meta()? | Annotations set? | Client-safe? |
|---|---|---|---|---|---|

Also build a resources table (see `references/primitives-guide.md` for the build patterns):

| Resource name | URI scheme | mimeType declared? | Should this be a resource (vs. a tool)? |
|---|---|---|---|

Enumerate every registered resource. Check each JSON/binary resource declares an explicit
`mimeType` in both the registration metadata and its `contents[]` entries — Python FastMCP
silently defaults to `text/plain` when it's missing. Flag any zero-arg/default-branch tool
that returns a static dataset as a should-be-a-resource candidate.

Resource templates are enumerated separately from static resources, via
`resources/templates/list`, not folded into the resources table above:

| Template name | URI template | List enumerable? | Param names match URI vars? | Completion registered? |
|---|---|---|---|---|

For each template: confirm every destructured read-callback parameter (TypeScript) or
function parameter (Python) matches a `{variable}` in the URI template exactly. A
mismatch is silently `undefined` in TypeScript and a `ValueError` at import time in Python
FastMCP. Confirm `completions` appears in the server's declared capabilities whenever any
`complete`/`completable()` callback exists anywhere in the server (template or prompt),
and is absent when none do; see `references/primitives-guide.md` for why this can
silently drift even though the SDK usually auto-detects it. Flag any template with a
free-text (non-enumerable) parameter that has no completion callback as a UX gap: the
client has no way to help the user fill it in.

Also build a prompts table (see `references/primitives-guide.md`'s Workflow prompts
section for the sparseness principle and the build patterns):

| Prompt name | Args | Workflow it encodes | Quality (per PROMPT QUALITY checklist) |
|---|---|---|---|

For each registered prompt:
- **Single-call check.** If the prompt's messages resolve to exactly one tool call with
  the prompt's arguments passed straight through and no chaining across multiple tools,
  flag it as a should-be-a-tool candidate, the same judgment call as a should-be-a-resource
  zero-arg tool. The fix is to convert it to a tool (better description, better defaults)
  or remove it, not to keep it registered as a workflow prompt.
- **Description quality check.** A vague or undescribed prompt (missing `description`, or
  one that doesn't state the workflow and when to use it) gets a concrete rewrite
  suggestion, exactly like a weak tool description does in the tools table above, not just
  a "needs a better description" note.
- **Naming symmetry check.** Compare prompt names against the domain's tool names: a
  `verb_noun` prompt in one domain (`plan_sakura_trip`) with no symmetric prompt in a
  structurally identical sibling domain (no `plan_koyo_trip`) is a coverage gap worth
  flagging. Any dot in a prompt name is the same Claude-portability bug as a dotted tool
  name (see the tool naming check above); flag it the same way.

Also check: cache.ts present? static data inside vs outside handlers?

If it is hosted/public, also check: `/health`, `/llms.txt`, `/sitemap.xml`, AI-search topic/text pages, JSON APIs, `search`/`fetch` compatibility, and README language separating web search from MCP tool execution.

Also check for duplicated or drifting copy between frontend, backend, README, and registry files. Canonical URLs, MCP endpoint, ChatGPT connector metadata, example prompts, location examples, seasonal timing guidance, and next-tool instructions should come from one config/module or be enforced by a build-time validation script.

### Step 2: Score every dimension

Read `references/smithery-config.md` for the full scoring table and score ladder.

Quick checklist:
- [ ] Tool names are specific, stable, and compatible with target clients; use `domain_action` unless dotted names are verified safe
- [ ] Tool descriptions: verb-first, ≤2 sentences, states next tool; every param has `.describe()` + `.meta({ title })` (25pt)
- [ ] All tools have annotations (`readOnlyHint` minimum; `openWorldHint` for APIs) (20pt)
- [ ] 3-5 workflow prompts registered, each covering a real multi-tool workflow, scored
      against the PROMPT QUALITY checklist in `references/primitives-guide.md` (15pt)
- [ ] Resources: not a Smithery scoring category — no code-earnable points either way; affects Glama discoverability facets only (see references/smithery-config.md)
- [ ] smithery.yaml or smithery.remote-config.json with `required: []` (15pt; 10pt if any field required)
- [ ] icon.svg at repo root (10pt)
- [ ] README: what it does, install, tools, usage (15pt)
- [ ] package.json: `description`, `keywords`, `author`, `license`, `homepage`, `repository` (feeds README/discovery quality)
- [ ] Hosted public-data servers expose crawlable AI-search pages/APIs and do not rely on MCP alone for ChatGPT Search users
- [ ] ChatGPT docs explain app/connector setup instead of implying arbitrary MCP execution in normal chat
- [ ] Shared metadata/copy source exists and build checks prevent frontend/backend drift

### Step 3: Fix everything in one pass

Priority order (highest score impact first):

1. Tool names → specific client-compatible names
2. Tool descriptions → verb-first, 2 sentences, call-next
3. Parameter descriptions → `.describe()` + `.meta({ title })` on every input
4. Annotations → READONLY / READONLY_EXTERNAL / WRITE / DESTRUCTIVE
5. Prompts → register 3-5 for main workflows; convert single-call prompts to tools
   instead of padding the count
6. Server instructions → add `instructions` to McpServer if missing
7. Static data → move any per-call file reads to module level
8. Caching → wrap all live API calls in `getOrFetch()`
9. Error handling → wrap all handlers in try/catch returning `isError: true`
10. package.json → all metadata fields
11. smithery.yaml / smithery.remote-config.json → add configSchema with `required: []`
12. Discovery surfaces → add `/health`, `/llms.txt`, sitemap, robots, text/JSON pages, ChatGPT connector metadata when hosted/public
13. Centralization → add shared config and build-time copy/metadata checks before polishing UI copy
14. MCPB → add bundle guidance for local stdio servers targeting Claude Desktop users
15. README → clear first paragraph, install snippet, tools table, AI-search vs MCP distinction

See `references/typescript-boilerplate.md` for correct code patterns.
See `references/discovery-guide.md` for public-data adoption patterns.

**Audit output requirement — generate these files** (write the actual content, don't just list what needs to change):
- `package.json` — all fields filled with real project values; no placeholder text for `homepage`, `repository`, or `author`
- `smithery.yaml` (stdio) or `smithery.remote-config.json` (hosted HTTP) — use templates from `references/smithery-config.md`

The audit is only complete when both files exist on disk. A score report without the generated files misses ~35pt of the total.

### Step 4: Report

```
Fixed:
- Tool names: renamed vague/get-prefixed tools to specific client-compatible names
- Tool descriptions: rewrote X/N that were noun-first or over 2 sentences → est. +Xpt
- Annotations: added READONLY to all N tools, READONLY_EXTERNAL on N with API calls → +7pt
- Parameter descriptions: added .describe() + .meta() to N parameters → +11pt
- Prompts: added [workflow_name] prompt → +5pt
- package.json: added homepage, repository, expanded keywords
- smithery.yaml: added configSchema with required: []
- Discovery: added AI-search pages/APIs and clarified that web search cannot execute MCP tools
- ChatGPT: added app/connector metadata and current setup guidance

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
- [ ] `npm view <package> version` checked; local version is not already published
- [ ] `npm outdated --json` checked for stale dependencies
- [ ] `npm run build` passes with no errors
- [ ] Centralized-copy/site-config validation passes when the server has frontend or public pages
- [ ] `npm pack --dry-run` shows the intended files
- [ ] README has: what it does, install snippet, tools table, hosted endpoint if applicable
- [ ] `smithery.yaml` or `smithery.remote-config.json` exists
- [ ] hosted server deploy is planned separately from npm publish

### Publish

```bash
npm run build && npm publish --otp=YOUR_OTP
```

npm versions are immutable. If publish fails with "previously published versions", run `npm version patch --no-git-tag-version`, sync registry metadata such as `server.json`, rebuild, and publish again.

After publishing a hosted server, push/deploy the app and verify production:

```bash
curl https://YOUR_DOMAIN/health
curl -I https://YOUR_DOMAIN/your-ai-search-page.txt
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
