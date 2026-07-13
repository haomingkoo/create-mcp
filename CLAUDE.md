# CLAUDE.md

## Purpose
A Claude Code (and Codex) skill package that guides an agent through the full MCP server
lifecycle — scaffold a new TypeScript MCP server, audit/fix an existing one against 10
quality dimensions, and publish it (npm/Smithery/directories).

## Tech Stack
- Markdown-based skill definitions (no application code in this repo itself)
- Shell scripts (`sh`) for installers
- JSON for eval definitions
- Targets projects built with TypeScript + `@modelcontextprotocol/sdk` (templates live in
  `references/typescript-boilerplate.md`, not executed here)

## Commands
There is no build/test suite in this repo — it's a skill package, not an application.

- Install skill for Claude Code: `./install.sh` (or the curl one-liner in README.md)
- Install skill for Codex: `./install-codex.sh`
- Invoke the skill inside Claude Code: `/create-mcp`
- No `npm install`, `npm run build`, or test runner exists in this repo (do not invent one)

## Architecture
- `SKILL.md` — canonical skill definition for Claude Code (CREATE / AUDIT / PUBLISH paths)
- `codex/create-mcp/SKILL.md` + `codex/create-mcp/agents/openai.yaml` — Codex port of the
  same workflow, installed separately via `install-codex.sh`
- `references/` — detail docs the skill reads on demand:
  - `typescript-boilerplate.md` — package.json/tsconfig/src templates for scaffolded MCPs
  - `smithery-config.md` — smithery.yaml / smithery.remote-config.json templates + scoring table
  - `deployment-guide.md` — stdio vs hosted HTTP explainer
  - `discovery-guide.md` — AI-search surfaces, ChatGPT connector setup, MCPB packaging
- `evals/evals.json` — eval prompts/expectations for testing the skill's own output quality;
  `evals/files/broken-mcp-index.ts` — a deliberately flawed MCP server fixture used by the
  audit-path evals (no eval runner script exists in-repo)
- `install.sh` / `install-codex.sh` — copy `SKILL.md` + `references/` into
  `~/.claude/skills/create-mcp` or `~/.codex/skills/create-mcp`
- `README.md` / `ARTICLE.md` — user-facing docs and a written walkthrough of the project

## Key Files
- `SKILL.md` — start here to understand or modify the workflow logic
- `references/smithery-config.md` — scoring rubric referenced throughout audits
- `evals/evals.json` — source of truth for what "good skill output" looks like
