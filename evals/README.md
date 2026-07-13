# evals/

Eval prompts (`evals.json`) and the E2E test harness for the create-mcp skill
(PRD-v2-full-surface.md §5).

## Run it

```bash
evals/run.sh
```

Runs level 0 (static checks) and level 1 (boots `files/broken-mcp-index.ts` over real
stdio JSON-RPC and asserts the planted bugs are actually observable at the protocol
level) every time. Exits 0 only if every executed check passes.

Level 2 (headless E2E CREATE) and level 3 (headless E2E AUDIT) spend real tokens via
`claude -p` and are skipped by default — set `RUN_HEADLESS=1` to include them. See the
header comment in `run.sh` for what each level checks.

## Files

- `evals.json` — prompts + expectations for the skill's own output quality (no runner
  in this repo executes these directly; they're read by whoever is grading a run)
- `files/broken-mcp-index.ts` + `files/data/recipes.json` — a deliberately flawed MCP
  server fixture, used by both the audit-path evals and level 1
- `files/planted-bugs.json` — manifest of every bug planted in the fixture, with a
  `marker` comment level 0 confirms exists in the source
- `mcp-test-client.mjs` — generic raw JSON-RPC stdio test client; spawns a server,
  replays a spec's `steps`, checks `assertions` against the responses
- `specs/broken-mcp-fixture.json` — the level 1 spec: boots the broken fixture and
  asserts bugs T2, T3a, T3b, T5a are observable at the protocol level (T4 and T5b have
  no protocol-level signature — single-call-prompt judgment and a missing-file/array
  absence — so level 0's marker grep is their only automated check)
- `run.sh` — the leveled runner described above
