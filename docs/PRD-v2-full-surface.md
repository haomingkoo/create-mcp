# PRD: create-mcp v2 — Full Protocol Surface, Right Primitive for the Job

**Status:** Draft for review · **Date:** 2026-07-13 · **Owner:** Haoming Koo
**Research basis:** 6-agent sweep (MCP spec 2025-11-25, TS/Python SDK v1 APIs, Smithery/Glama scoring, 6 exemplar servers, local skill audit, sakura-push dogfood audit). Receipts inline.

## 1. Problem

create-mcp is tools-shaped. The CREATE design phase, AUDIT mapping tables, boilerplate,
evals, and README dimensions all model an MCP server as "a bag of tools." Three concrete
harms:

1. **It teaches a stale fact.** SKILL.md claims Smithery auto-awards 5pt for resources.
   No current source supports any resources category on Smithery; two independent
   third-party sources agree the current 100-pt rubric is: tools w/ descriptions (25),
   tool annotations (20), optional config (15), **workflow prompts, 3-5 of them (15)**,
   **icon.svg (10)**, README (15). Unverified against a primary Smithery source — see
   Open Questions — but either way our number is wrong.
2. **It misses the highest-leverage additions.** Workflow prompts (15pt) and icon (10pt)
   are the two largest scoring categories the skill doesn't cover at all.
3. **It can't scaffold or audit two-thirds of the protocol.** Resources (incl. RFC 6570
   templates), completions, notifications, annotations, icons (SEP-973), pagination,
   and tool outputSchema/structuredContent have zero implementation guidance. The evals
   only ever plant tool bugs.

## 2. Goals

- **G1 — Decision framework, not maximal surface.** A "which primitive?" design step
  grounded in observed practice: 4 of 6 top servers are tools-only; resources appear
  only for URI-addressable, hierarchical, read-mostly content (GitHub: repo files at
  refs); prompts are sparse and reserved for multi-tool workflows (GitHub: 2 prompts vs
  50+ tools); completions exist only as a companion to resource templates with free-text
  path args. Stripe is the canonical tools-only counter-example ("The server exposes
  the following MCP tools" — for a transactional API).
- **G2 — Full-surface scaffold + audit coverage** for: resources (static + templates),
  prompts (multi-message, embedded resources), completions, list_changed/updated
  notifications, shared annotations (audience/priority/lastModified — one validator,
  used by resources, prompt content, and tool results alike), icons, pagination,
  outputSchema/structuredContent.
- **G3 — Corrected registry intelligence.** Replace the stale Smithery table; add Glama
  reality (score is 100% tool-quality — TDQS 70% + coherence 30%; resources/prompts
  affect only directory facets/discoverability, which still matters: 6,250
  resource-servers and 5,821 prompt-servers are filterable).
- **G4 — E2E-testable skill.** Evals that exercise the new surface plus an end-to-end
  harness (§5).
- **G5 — Dogfood on sakura-push** (17 tools / 3 resources / 2 prompts / 0 templates /
  0 completions today). Candidates already identified (§6, issue 8).

## 3. Non-Goals

- **Tasks** (experimental, 2025-11-25, SEP-1686; moved to Extensions in the draft spec)
  — one callout paragraph, no scaffolding.
- **SDK v2** (TS `@modelcontextprotocol/server` 2.0.0-beta, Python v2 pre-release) —
  target **v1 stable** (TS `@modelcontextprotocol/sdk@1.x`, PyPI `mcp==1.x`); v2 gets an
  "experimental, revisit at GA" note.
- **Logging/sampling/roots depth** — SEP-2577 deprecates all three as of spec
  2026-07-28. Mention, don't invest.
- **MCP Apps / UI resources** — GitHub-only pattern so far; callout, not recommendation.

## 4. Design

### 4.1 SKILL.md — CREATE path
- Phase 2 (Design) gains a **primitive decision step**:
  - static, read-only dataset → resource (sakura-push validates this 3× over)
  - parameterized hierarchical read (one string arg → listing) → **resource template**
    (+ completions if args are free-text)
  - recurring multi-tool workflow → prompt. Detection heuristics: mine
    SERVER_INSTRUCTIONS/tool-routing prose for "use X then Y" chains; check
    prompt/tool naming symmetry across paired domains (sakura vs koyo asymmetry was
    found exactly this way)
  - side effects / writes / computation → tool (default)
- Phase 3 (Build) gains v1 snippets for each primitive with the source-verified
  gotchas: TS `ResourceTemplate` requires an explicit `list` key (`list: undefined` if
  none); `completable()` wraps prompt args while template completion uses the
  `complete: {param: cb}` constructor map — two different mechanisms; Python
  `@mcp.resource("scheme://{param}")` function params must match template vars by name;
  Python `mime_type` silently defaults to `text/plain` (a real bug class for JSON/binary).

### 4.2 SKILL.md — AUDIT path
New mapping tables for resources/templates/prompts/completions/notifications. New
checks: capability declaration matches implementation (completions and logging need
explicit `{}` declarations); `subscribe` and `listChanged` audited as independent flags;
shared annotations validator; icons; mime_type-default bug; alias/deprecation hygiene
(sakura-push's `plan_sakura_trip` alias pattern); pagination as ONE cross-cutting check
(resources/templates/prompts/tools lists); progress/cancellation as ambient patterns,
not capabilities.

### 4.3 references/
- **NEW `primitives-guide.md`**: the decision framework + all build snippets (single
  source of truth; SKILL.md links, doesn't duplicate).
- `smithery-config.md`: corrected rubric (flagged where third-party-sourced), icon.svg
  how-to, workflow-prompts guidance (3-5, multi-tool, sparse).
- `typescript-boilerplate.md`: template gains one static resource, one resource
  template + completion, one workflow prompt, capability declarations.

### 4.4 Evals + E2E harness (§5)
### 4.5 Codex port
Regenerate from the updated Claude skill; fix the two known drift bugs (path-case,
missing discovery-guide.md reference) as part of the sync.

### 4.6 README
Dimensions table gains the new surface; add version-targeting note (v1 stable).

## 5. End-to-End Test Strategy

Four levels, cheapest first (each level is one runnable command; ponytail: no
frameworks, plain scripts + asserts):

1. **Fixture evals (existing pattern, extended).** New planted bugs in a
   `broken-mcp` fixture: missing mime_type on JSON resource, template param/URI
   mismatch, undeclared completions capability, prompt that should be a tool and vice
   versa, missing icon. Assert the AUDIT path's report catches each (recall check
   against a manifest of planted bugs).
2. **E2E CREATE.** Script runs the skill headlessly (claude -p) in a temp dir against a
   fixed brief ("docs server: 3 documents, one templated doc resource, one summarize
   workflow prompt"). Then a ~60-line stdio JSON-RPC test client asserts: `initialize`
   capabilities match implementation; `tools/list`, `resources/list`,
   `resources/templates/list`, `prompts/list` all answer; `resources/read` returns
   declared mime type; `completion/complete` resolves a template arg; server builds
   with `tsc` first.
3. **E2E AUDIT.** Same headless run against the broken fixture; diff report vs planted
   manifest.
4. **Dogfood.** Run the upgraded skill's AUDIT on sakura-push; implement accepted
   candidates; verify Smithery re-scan holds 100/100 and Glama facets light up.

## 6. Milestones → Issues

| # | Issue | Size | Depends |
|---|---|---|---|
| 1 | Fix stale registry facts (Smithery rubric, Glama reality) in smithery-config.md + SKILL.md | S | — |
| 2 | Write references/primitives-guide.md (decision framework + v1 snippets) | M | — |
| 3 | CREATE path: primitive decision step + build-phase links | M | 2 |
| 4 | AUDIT path: full-surface tables + new checks | M | 2 |
| 5 | typescript-boilerplate.md: full-surface template | S | 2 |
| 6 | Evals: broken-mcp fixture v2 + E2E harness (levels 1-3) | L | 3,4,5 |
| 7 | Codex port: regenerate + fix 2 drift bugs | S | 3,4,5 |
| 8 | Dogfood sakura-push: fruit-calendar resource, prefecture-list resource, spots resource-templates + completions, plan_koyo_trip prompt | M | 2 (lives in sakura-push repo) |
| 9 | README dimensions table + version-targeting note | S | 3,4 |

## 7. Open Questions / Risks

- **Smithery rubric is third-party-sourced.** Two independent sources agree; primary
  source unlocated (docs 404). Action in issue 1: check Smithery scanner source /
  support; until then the table ships flagged "community-derived, [date]".
- **Draft spec churn**: stateless/per-request negotiation, Tasks→Extensions,
  sampling/roots dropped. Re-check `specification/versioning` before issue 6 lands.
- **mcp.so ranking**: unverifiable (403s). Stated as unknown, not assumed.
- **SDK v2 GA timing**: revisit version targeting when either SDK cuts a stable 2.0.0.

## 8. Success Criteria

- All 4 E2E levels green in CI-style run (`evals/run.sh` exit 0).
- AUDIT finds ≥ 90% of planted non-tool bugs on the v2 fixture.
- sakura-push keeps 100/100 on Smithery after dogfood changes; gains Glama
  resources/prompts facets.
- No claim in the skill about registry scoring without a source or an "unverified" flag.
