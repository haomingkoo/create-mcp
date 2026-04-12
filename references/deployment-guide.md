# MCP Deployment Guide — stdio vs HTTP

Read this when the user asks "will this run locally or be hosted?" or when deciding which transport to use.

---

## The short answer

| | **stdio** | **HTTP (SSE/Streamable)** |
|---|---|---|
| Runs | On the user's machine | On a server (Railway, Fly.io, etc.) |
| Started by | Claude Desktop / Claude Code spawns a subprocess | Already running, Claude connects over HTTPS |
| Config file | `smithery.yaml` | `smithery.remote-config.json` |
| Best for | Local tools, private data, no server cost | Shared data, always-on, multi-user |
| Auth | API key via `smithery.yaml` commandFunction env | API key via remote config schema |
| Examples | File system access, local databases, dev tools | Weather APIs, public data, SaaS integrations |

---

## stdio — detailed

The client (Claude Desktop, Claude Code) **spawns** the MCP server as a child process each session. Communication happens over stdin/stdout. The server process lives and dies with the session.

```
User's machine
┌─────────────────────────────┐
│  Claude Desktop             │
│  ├─ spawns: npx weather-mcp │◄── reads smithery.yaml commandFunction
│  └─ stdin/stdout pipe ──────┼──► MCP server process
└─────────────────────────────┘
```

**When to choose stdio:**
- The tool accesses local resources (files, databases, localhost services)
- You want zero hosting cost
- The tool is developer-facing (IDE integrations, git tools, build tools)
- You don't want to maintain a server

**SDK setup:**
```typescript
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";

const transport = new StdioServerTransport();
await server.connect(transport);
```

**smithery.yaml for stdio:**
```yaml
startCommand:
  type: stdio
  configSchema:
    type: object
    properties:
      apiKey:
        type: string
        title: "API Key"
        description: "Your key from example.com"
    required: []
  commandFunction: |-
    (config) => ({
      command: "npx",
      args: ["your-package-name"],
      env: config.apiKey ? { API_KEY: config.apiKey } : {}
    })
```

---

## HTTP (Streamable HTTP / SSE) — detailed

The server runs permanently at a URL. Claude connects to it over HTTPS. Multiple users can share one server instance.

```
User's machine          Your server (Railway/Fly.io)
┌───────────────┐       ┌──────────────────────────┐
│  Claude       │──────►│  MCP HTTP server         │
│  (any client) │◄──────│  https://your-app/mcp    │
└───────────────┘  HTTPS└──────────────────────────┘
```

**When to choose HTTP:**
- The data is public and doesn't vary by user (weather, crypto prices, travel info)
- You want one deployment shared by everyone
- The server needs to stay warm (persistent cache, background jobs)
- You're building a SaaS MCP product

**SDK setup:**
```typescript
import { StreamableHTTPServerTransport } from "@modelcontextprotocol/sdk/server/streamableHttp.js";
// or the older SSE transport — check the SDK version
```

**smithery.remote-config.json for hosted HTTP:**
```json
{ "type": "object", "properties": {}, "required": [] }
```

---

## Hosting options for HTTP servers

| Platform | Free tier | Best for | Notes |
|---|---|---|---|
| **Railway** | $5 credit/mo | Always-on hobby projects | Auto-deploys from GitHub, sleeps on free tier |
| **Fly.io** | 3 shared-cpu VMs | Low-latency global | More config, more control |
| **Render** | Static + 1 web service | Simple REST-style MCPs | Spins down after 15min inactivity (free) |
| **Cloudflare Workers** | 100k req/day free | Edge-deployed, global | Stateless only — no persistent cache |
| **Vercel** | Generous free tier | Serverless functions | Cold starts; no long-lived connections |

For most MCP servers: **Railway** is the best starting point. Push to GitHub → connect Railway → done.

---

## Further reading

### MCP specification and protocol
- **MCP official docs** — modelcontextprotocol.io — the canonical spec for transports, tool schemas, and lifecycle
- **MCP TypeScript SDK** — github.com/modelcontextprotocol/typescript-sdk — reference implementation with transport examples
- **MCP specification (GitHub)** — github.com/modelcontextprotocol/specification — the raw protocol spec if you need to go deep

### Tool use and AI agent design (academic / research)
- **Toolformer** (Schick et al., 2023) — the paper that established self-supervised tool-use for LLMs; foundational for understanding why good tool descriptions matter. arxiv.org/abs/2302.04761
- **ReAct: Synergizing Reasoning and Acting in Language Models** (Yao et al., 2023) — the interleaved reasoning + tool-calling pattern that most MCP clients follow. arxiv.org/abs/2210.03629
- **ToolBench / ToolLLM** (Qin et al., 2023) — large-scale benchmark of 16k APIs; shows how API documentation quality directly affects agent success rate. arxiv.org/abs/2307.16789
- **Gorilla: Large Language Model Connected with Massive APIs** (Patil et al., 2023) — demonstrates LLMs hallucinate API calls when docs are absent; reinforces why every param needs .describe(). arxiv.org/abs/2305.15334

### Practical / industry writing
- **Building MCP Servers the Right Way** — Smithery blog posts on scoring dimensions (smithery.ai/blog)
- **The Function Calling Guide** — OpenAI's practical guide on tool schemas; concepts apply directly to MCP tool definitions (platform.openai.com/docs/guides/function-calling)
- **Anthropic's tool use documentation** — docs.anthropic.com/en/docs/tool-use — how Claude processes tool descriptions and why verb-first matters

### Transport protocol background
- **Server-Sent Events (SSE) spec** — the underlying push mechanism for the HTTP transport (html.spec.whatwg.org/multipage/server-sent-events.html)
- **JSON-RPC 2.0 spec** — MCP messages are JSON-RPC; this is the message framing layer (www.jsonrpc.org/specification)
