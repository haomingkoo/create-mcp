# create-mcp

A Claude Code skill for the full MCP development lifecycle. Start with an idea, end with a published server that AI clients can actually discover and use.

![Japan in Seasons — built and audited with create-mcp](assets/japan-seasons-result.png)

---

## What's an MCP?

MCP (Model Context Protocol) is an open standard that lets AI clients like Claude, Cursor, and Windsurf call real APIs and data sources. Instead of the AI working only from what it was trained on, it can call your live APIs, query your database, or pull real-time data on demand.

The protocol is picking up quickly. Anthropic, OpenAI, Google DeepMind, and dozens of developer tools now support it. Developers are publishing MCP servers for GitHub, Jira, Stripe, internal databases, public APIs — anything an AI agent might need to call.

If you have data or a service that would be more useful with AI access, an MCP server is how you expose it.

---

## The problem with building MCPs

The protocol itself isn't complicated. What's annoying is everything around it.

Getting a tool description right matters more than it looks. AI clients use descriptions to decide which tool to call and when. A vague or missing description means the client either skips your tool or calls it wrong. The same goes for parameter descriptions, server instructions, caching, error handling — every dimension affects how useful the server actually is, and how well it ranks on directories like Smithery.

Most developers ship something that works locally and then wonder why nobody finds it.

---

## What this skill does

`create-mcp` is a Claude Code skill — a markdown file that gives Claude a structured workflow when you run `/create-mcp`. Claude reads the skill and follows the workflow, asking the right questions, making decisions, and doing the work.

Two paths, auto-detected:

**Starting from scratch** — Claude asks about your data source, the natural questions users would ask, auth requirements, and whether it runs locally or hosted. From those answers it designs the tool structure, proposes it for your review, then scaffolds production-ready TypeScript. It builds in caching, error handling, and all 10 quality dimensions from the start.

**Already have an MCP** — Claude reads your `src/index.ts`, scores every dimension, fixes everything in one pass, and reports what changed and what Smithery impact to expect.

Either way, the skill ends with the publish checklist: version bump, npm publish, and where to submit for discovery.

---

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/haomingkoo/create-mcp/main/install.sh | sh
```

Or manually:

```bash
mkdir -p ~/.claude/skills/create-mcp
curl -o ~/.claude/skills/create-mcp/skill.md \
  https://raw.githubusercontent.com/haomingkoo/create-mcp/main/skill.md
```

Restart Claude Code. Run `/create-mcp` in any session.

---

## The workflow

```
New MCP:      Gather → Design → Build → Audit → Publish
Existing MCP:                   Audit → Fix   → Publish
```

Claude detects which path applies from the project directory.

---

## What gets built and audited

These are the 10 dimensions the skill enforces. Each one affects whether AI clients use your tools correctly, and whether users find your server.

| Dimension | Why it matters |
|---|---|
| Tool descriptions | AI clients read these to decide what to call. Vague descriptions get skipped or misused. Must start with a verb, max 2 sentences, state what to call next. |
| Parameter descriptions | Without these, the AI guesses what to pass. Every input needs a `.describe()`. |
| Annotations | `readOnlyHint` and `idempotentHint` tell clients whether it's safe to retry. Missing these reduces trust scores. |
| Tool titles | Human-readable name per the MCP 2025-06-18 spec. Displayed in client UIs. |
| Server instructions | The "system prompt" for AI clients. Tells them tool call order and what NOT to use the server for. Without this, clients improvise. |
| Static data | Data loaded on every tool call slows everything down. Load at startup. |
| Caching | Live API calls without caching mean a new upstream request every time Claude calls a tool. 1–6h TTL for most data. |
| Error handling | Tools that throw exceptions crash the client session. Every handler needs a try/catch that returns `isError: true`. |
| package.json | Smithery and other directories index description, keywords, homepage, repository. Missing fields drop your score. |
| README | Copy-pasteable install snippet, tools table, hosted endpoint if applicable. |

---

## Getting your MCP discovered

After publishing to npm, submit to these directories. Most take under 5 minutes.

**Smithery — hosted servers (runs on a URL):**

```bash
npx @smithery/cli mcp publish \
  "https://your-domain.com/mcp" \
  -n your-github-username/your-repo \
  --config-schema "$(cat smithery.remote-config.json)"
```

**Smithery — stdio servers (installed via npx):** Add Server at smithery.ai → paste GitHub URL → trigger scan.

| Directory | URL | What you need |
|---|---|---|
| mcp.so | mcp.so/submit | GitHub URL + npx config JSON |
| Glama | glama.ai/mcp/servers | GitHub URL only |
| PulseMCP | pulsemcp.com | GitHub URL + description |
| awesome-mcp-servers | Fork punkpeye/awesome-mcp-servers, add one line | `🤖🤖🤖` in PR title |

The skill's publish checklist walks through each one.

**Smithery scoring reference:**

| Category | Points |
|---|---|
| Tool descriptions | 12 |
| Parameter descriptions | 11 |
| Annotations | 7 |
| Tool names | 5 |
| Server capabilities | 10 |
| Server metadata | 30 |
| Configuration UX | 25 |

**100/100 is achievable.** The "Tool names" sub-score (5pt) rewards a navigable hierarchy using dot notation — `domain.action` format (e.g. `sakura.forecast`, `koyo.spots`, `fruit.farms`). Every tool sharing the same `get_` prefix caps you at 3/5 regardless of how descriptive the names are. Switch to dot notation and the score jumps to 5/5.

---

## Real result

[japan-seasons-mcp](https://github.com/haomingkoo/japan-seasons-mcp) was built and audited with this skill. It's a live Japan seasonal travel data server: cherry blossoms, autumn leaves, fruit picking, festivals, weather. 12 tools, 1,700+ GPS-tagged locations, real-time JMC forecast data.

Smithery score: **100/100**. Every dimension maxed, including the elusive "Tool names: 5/5" — achieved with dot notation naming (`sakura.forecast`, `koyo.spots`, `fruit.farms`, etc.).

Live at [seasons.kooexperience.com](https://seasons.kooexperience.com) and on npm as `japan-seasons-mcp`.

---

## Requirements

- [Claude Code](https://claude.ai/code)
- Node.js 18+ (for TypeScript scaffolding)
- `@modelcontextprotocol/sdk` (installed automatically in new projects)

---

## License

MIT · Built by [Haoming Koo](https://kooexperience.com)
