# CLAUDE.md

A skill package (no app code) that walks an agent through scaffolding, auditing and publishing TypeScript MCP servers. `SKILL.md` is the Claude Code skill; `codex/create-mcp/SKILL.md` is the Codex port. Keep the two in step.

## Commands

```bash
bash evals/run.sh                  # levels 0-1: static checks + live broken-fixture run (what CI runs)
RUN_HEADLESS=1 bash evals/run.sh   # adds levels 2-3 via headless `claude -p`; spends real tokens
./install.sh                       # Claude Code install
./install-codex.sh                 # Codex install
```

## Gotchas

- `install.sh` always curls from GitHub `main`, so it installs the published version, not your working copy. `install-codex.sh` copies locally when run from the repo.
- Both installers list every reference file explicitly. A new file under `references/` must be added to both, or users never get it.
- `evals/files/broken-mcp-index.ts` is deliberately broken; its planted bugs are recorded in `evals/files/planted-bugs.json`. Don't fix it.
