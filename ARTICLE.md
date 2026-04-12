# I built a Claude Code skill that takes you from idea to published MCP in one session

---

## What's an MCP and why should you care?

MCP (Model Context Protocol) is an open standard that lets AI clients call real APIs. When you're working in Claude, Cursor, or Windsurf, the AI normally only knows what's in its training data or what you paste into the chat. MCP changes that.

With an MCP server, the AI can call your actual data. Live, on demand.

Developers are already publishing servers for GitHub, Jira, Stripe, internal databases, weather APIs, sports scores — anything useful that an AI agent might want to query. Anthropic, OpenAI, Google DeepMind, and most of the major coding tools now support the protocol.

If you have an API or data source, an MCP server is how you give AI clients access to it.

---

## The problem with building them

The protocol itself isn't complicated. A basic MCP server is maybe 50 lines of TypeScript. What's tedious is building one that actually works well with AI clients and gets discovered.

Here's what most developers miss:

**Tool descriptions matter more than you think.** AI clients use them to decide which tool to call. "Returns weather data" means the client might call your weather tool when it shouldn't, or skip it when it should. The description needs to start with a verb, say what the data is, and tell the client what to call next.

**Missing annotations hurt you.** `readOnlyHint`, `idempotentHint` — these tell clients whether it's safe to retry a tool call. Skip them and you're leaving the client to guess.

**No server instructions means the AI improvises.** When you create an MCP server, you can pass an `instructions` field that acts as a routing guide for AI clients: call this tool first, use this other one for follow-up, don't use this server for X. Without it, the client works it out from descriptions alone.

**Discovery requires work after publishing.** Smithery, mcp.so, Glama, PulseMCP — there are several directories where people find MCP servers. Most developers publish to npm and stop there.

I hit all of these problems while building [japan-seasons-mcp](https://github.com/haomingkoo/japan-seasons-mcp), a live Japan seasonal travel data server with 12 tools, 1,700+ GPS-tagged spots, and real-time JMC forecast data. Fixing each issue manually took longer than building the initial server.

---

## What I built

[`create-mcp`](https://github.com/haomingkoo/create-mcp) is a Claude Code skill — a markdown file that gives Claude a structured workflow when you run `/create-mcp`. Claude reads the skill, detects where you are in the process, and follows the right path.

**Starting from scratch:**

Claude asks about your data source, what questions users would naturally ask it, whether it needs auth, and whether it runs locally or on a server. From those answers it proposes a tool structure for review, then builds the full server with all 10 quality dimensions built in from the start. Not as an afterthought.

**Already have a server:**

Claude reads your code, scores every dimension, fixes everything in one pass, and reports what changed. The report looks like this:

```
Fixed:
- Tool descriptions: 5 of 8 tools had missing or noun-first descriptions
- Annotations: readOnlyHint missing on all tools
- Server instructions: none present — added tool routing guide
- package.json: homepage and repository fields missing

Estimated Smithery impact: ~72 → ~95
```

**Ready to ship:**

The skill ends with the full publish checklist: version bump, `npm run build && npm publish`, Smithery CLI command, and the four other directories worth submitting to.

---

## The 10 dimensions it enforces

| Dimension | Why it matters |
|---|---|
| Tool descriptions | AI clients use these to route calls. Vague = misused or skipped. |
| Parameter descriptions | Without `.describe()`, the AI guesses what to pass. |
| Annotations | Tells clients whether it's safe to retry a call. |
| Tool titles | Human-readable name shown in client UIs (MCP 2025-06-18 spec). |
| Server instructions | Routing guide for the AI — call order, what NOT to use it for. |
| Static data | Load once at startup, not on every tool call. |
| Caching | One cache miss per TTL window, not one upstream request per tool call. |
| Error handling | Tools that throw exceptions crash the client. Return `isError: true` instead. |
| package.json | Smithery indexes description, keywords, homepage. Missing fields drop your score. |
| README | Copy-pasteable install, tools table, hosted endpoint. |

---

## Getting discovered

After you publish, submit to these directories. Each one takes a few minutes and gets your server in front of developers actively looking for MCPs to add to their workflows.

**Smithery** — the main one. For hosted HTTP servers, the CLI makes it straightforward:

```bash
npx @smithery/cli mcp publish \
  "https://your-domain.com/mcp" \
  -n your-github-username/your-repo \
  --config-schema "$(cat smithery.remote-config.json)"
```

For stdio servers (installed via npx), go to smithery.ai → Add Server → paste your GitHub URL.

**mcp.so** — submit at mcp.so/submit with your GitHub URL and a config JSON block.

**Glama** — GitHub URL only at glama.ai/mcp/servers.

**PulseMCP** — GitHub URL + description at pulsemcp.com.

**awesome-mcp-servers** — fork [punkpeye/awesome-mcp-servers](https://github.com/punkpeye/awesome-mcp-servers), add one line to the README, open a PR with `🤖🤖🤖` in the title.

---

## The result

japan-seasons-mcp ended up at **98/100 on Smithery** with every auditable dimension maxed. It's live at [seasons.kooexperience.com](https://seasons.kooexperience.com), indexed on all five directories, and available as `npx japan-seasons-mcp` for local use or as a hosted HTTP endpoint.

The 2 missing points are from an opaque "Tool names" rubric that doesn't move regardless of what you change. 98 is the practical ceiling.

---

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/haomingkoo/create-mcp/main/install.sh | sh
```

Then in any Claude Code session:

```
/create-mcp
```

GitHub: [haomingkoo/create-mcp](https://github.com/haomingkoo/create-mcp)

---

*Built by [Haoming Koo](https://kooexperience.com)*
