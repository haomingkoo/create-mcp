# create-mcp

A Claude Code skill for the full MCP development lifecycle — from idea to production-ready server.

```bash
# Install
curl -fsSL https://raw.githubusercontent.com/haomingkoo/create-mcp/main/install.sh | sh

# Or manually
mkdir -p ~/.claude/skills/create-mcp
curl -o ~/.claude/skills/create-mcp/skill.md \
  https://raw.githubusercontent.com/haomingkoo/create-mcp/main/skill.md
```

Then in any Claude Code session:

```
/create-mcp
```

---

## What it does

`create-mcp` detects where you are in the MCP lifecycle and guides you through the right steps:

**Starting fresh?** It walks you through requirements, designs your tool structure, and scaffolds production-ready code.

**Already have an MCP?** It audits every dimension — descriptions, annotations, caching, error handling — and fixes everything in one pass.

**Ready to ship?** It handles versioning, npm publish, Smithery submission, and the other MCP directories.

---

## The lifecycle

```
New MCP:      Gather → Design → Build → Audit → Publish
Existing MCP:                   Audit → Fix   → Publish
```

Claude detects which path applies automatically.

---

## What gets audited / built

| Dimension | What it checks |
|---|---|
| Tool descriptions | Verb-first, ≤2 sentences, states what to call next |
| Parameter descriptions | Every input has a `.describe()` |
| Annotations | `readOnlyHint`, `idempotentHint` on all tools |
| Tool titles | `title` field set (MCP 2025-06-18 spec) |
| Server instructions | `instructions` in McpServer options — tool routing guide for AI clients |
| Static data | Loaded at startup, not on every tool call |
| Caching | Live API calls cached with TTL appropriate to data freshness |
| Error handling | All handlers return `isError` responses, never throw |
| package.json | description, keywords, author, license, homepage, repository |
| README | Clear first paragraph, copy-pasteable install, tools table |

---

## Real result

Built and audited with `create-mcp`:

**[japan-seasons-mcp](https://github.com/haomingkoo/japan-seasons-mcp)** — live Japan seasonal travel data (cherry blossoms, autumn leaves, fruit picking, festivals). 12 tools, 1,700+ GPS-tagged spots, live JMC forecast data.

Smithery score: **98/100** with every auditable dimension maxed.

---

## Installation

**Option 1 — install script**
```bash
curl -fsSL https://raw.githubusercontent.com/haomingkoo/create-mcp/main/install.sh | sh
```

**Option 2 — manual**
```bash
mkdir -p ~/.claude/skills/create-mcp
curl -o ~/.claude/skills/create-mcp/skill.md \
  https://raw.githubusercontent.com/haomingkoo/create-mcp/main/skill.md
```

**Option 3 — clone**
```bash
git clone https://github.com/haomingkoo/create-mcp.git
cp -r create-mcp/skill.md ~/.claude/skills/create-mcp/skill.md
```

Restart Claude Code. Run `/create-mcp` in any session.

---

## Requirements

- [Claude Code](https://claude.ai/code)
- Node.js 18+ (for building TypeScript MCPs)
- `@modelcontextprotocol/sdk` (installed automatically in scaffolded projects)

---

## License

MIT · Built by [Haoming Koo](https://kooexperience.com)
