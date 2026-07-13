#!/usr/bin/env bash
# evals/run.sh — leveled E2E harness for the create-mcp skill (PRD-v2-full-surface.md §5).
#
# Level 0 (static, always run):    JSON validity, planted-bug markers present in the
#   fixture source, doc cross-references resolve, evals.json fixture files exist,
#   installers parse.
# Level 1 (fixture-live, always run): boots evals/files/broken-mcp-index.ts over real
#   stdio JSON-RPC and asserts the runtime-observable planted bugs (T2, T3a, T3b, T5a)
#   are actually exhibited by the protocol responses, not just present as source
#   comments. T4 (single-call prompt) and T5b (missing icon) are absence/semantic-type
#   bugs with no protocol-level signature; their markers are still checked in level 0.
# Level 2 (E2E CREATE, gated):     headless `claude -p` scaffolds a server from a fixed
#   brief, then asserts it builds with tsc and answers the protocol surface.
# Level 3 (E2E AUDIT, gated):      headless `claude -p` audits the broken fixture and
#   the report is diffed against evals/files/planted-bugs.json for recall.
#
# Levels 2-3 spend real tokens (headless `claude -p` runs) and are skipped by default.
# Set RUN_HEADLESS=1 to run them.
#
# Usage: evals/run.sh
# Exit code: 0 iff every check in every executed level passed.

set -uo pipefail
cd "$(dirname "$0")/.." || exit 1   # repo root
EVALS_DIR="evals"
PASS=0
FAIL=0

check() {
  local desc="$1" ok="$2"
  if [ "$ok" = "0" ]; then
    echo "PASS  $desc"
    PASS=$((PASS + 1))
  else
    echo "FAIL  $desc"
    FAIL=$((FAIL + 1))
  fi
}

level0() {
  echo "== Level 0: static checks =="

  node -e "JSON.parse(require('fs').readFileSync('$EVALS_DIR/evals.json','utf8'))" 2>/dev/null
  check "evals.json is valid JSON" $?

  node -e "JSON.parse(require('fs').readFileSync('$EVALS_DIR/files/planted-bugs.json','utf8'))" 2>/dev/null
  check "planted-bugs.json is valid JSON" $?

  node -e "
    const fs = require('fs');
    const bugs = JSON.parse(fs.readFileSync('$EVALS_DIR/files/planted-bugs.json', 'utf8')).planted_bugs;
    const src = fs.readFileSync('$EVALS_DIR/files/broken-mcp-index.ts', 'utf8');
    const missing = bugs.filter((b) => !src.includes(b.marker));
    if (missing.length) { console.error('missing markers: ' + missing.map((b) => b.id).join(', ')); process.exit(1); }
  "
  check "every planted-bugs.json marker is present in the fixture source" $?

  node -e "
    const fs = require('fs');
    const seen = new Set();
    const files = ['SKILL.md'].concat(fs.readdirSync('references').map((f) => 'references/' + f));
    for (const f of files) {
      const text = fs.readFileSync(f, 'utf8');
      for (const m of text.matchAll(/references\/[A-Za-z0-9_-]+\.md/g)) seen.add(m[0]);
    }
    const missing = [...seen].filter((p) => !fs.existsSync(p));
    if (missing.length) { console.error('broken doc references: ' + missing.join(', ')); process.exit(1); }
  "
  check "every references/*.md path linked from SKILL.md or references/ exists" $?

  node -e "
    const fs = require('fs');
    const evals = JSON.parse(fs.readFileSync('$EVALS_DIR/evals.json', 'utf8')).evals;
    const missing = [];
    for (const e of evals) for (const f of (e.files || [])) if (!fs.existsSync(f)) missing.push(f);
    if (missing.length) { console.error('missing eval fixture files: ' + missing.join(', ')); process.exit(1); }
  "
  check "every file referenced in evals.json's 'files' arrays exists" $?

  bash -n install.sh
  check "install.sh parses (bash -n)" $?

  bash -n install-codex.sh
  check "install-codex.sh parses (bash -n)" $?
}

level1() {
  echo "== Level 1: fixture-live protocol checks =="

  if [ ! -d "$EVALS_DIR/node_modules" ]; then
    echo "installing evals/ dependencies..."
    if ! (cd "$EVALS_DIR" && npm install --silent); then
      check "evals/ dependencies installed" 1
      return
    fi
  fi
  check "evals/ dependencies installed" 0

  node "$EVALS_DIR/mcp-test-client.mjs" "$EVALS_DIR/specs/broken-mcp-fixture.json"
  check "broken-mcp-index.ts fixture exhibits planted bugs T2/T3a/T3b/T5a at the protocol level" $?
}

level2() {
  echo "== Level 2: E2E CREATE (headless, gated) =="
  if [ "${RUN_HEADLESS:-0}" != "1" ]; then
    echo "SKIPPED (set RUN_HEADLESS=1 to run; spawns a real headless claude -p run)"
    return
  fi

  local tmp brief
  tmp=$(mktemp -d)
  brief="Build a docs MCP server: 3 static documents, one templated doc resource (read a doc by slug), and one summarize workflow prompt."

  if ! (cd "$tmp" && claude -p "$brief"); then
    check "level 2: headless CREATE run completed" 1
    return
  fi
  check "level 2: headless CREATE run completed" 0

  if ! (cd "$tmp" && npm install --silent && npx tsc --noEmit && npm run build --silent); then
    check "level 2: scaffolded server builds (tsc)" 1
    return
  fi
  check "level 2: scaffolded server builds (tsc)" 0

  # Resource/template/prompt names are whatever the headless run scaffolds, so this
  # spec discovers them at runtime via {{step.path}} substitution (see
  # mcp-test-client.mjs's header) instead of hard-coding names it can't know ahead
  # of time. The brief asks for 3 documents (resources), one templated doc resource,
  # and one prompt, so each list is expected to be non-empty.
  cat > "$tmp/.eval-spec.json" <<SPEC
{
  "command": "node", "args": ["dist/index.js"], "cwd": ".",
  "steps": [
    { "id": "init", "method": "initialize", "params": { "protocolVersion": "2025-06-18", "capabilities": {}, "clientInfo": { "name": "create-mcp-eval-client", "version": "0.0.1" } } },
    { "id": "initialized", "notify": "notifications/initialized" },
    { "id": "tools", "method": "tools/list" },
    { "id": "resources", "method": "resources/list" },
    { "id": "templates", "method": "resources/templates/list" },
    { "id": "prompts", "method": "prompts/list" },
    { "id": "read-doc", "method": "resources/read", "params": { "uri": "{{resources.result.resources.0.uri}}" } },
    {
      "id": "complete-template",
      "method": "completion/complete",
      "params": {
        "ref": { "type": "ref/resource", "uri": "{{templates.result.resourceTemplates.0.uriTemplate}}" },
        "argument": { "name": "value", "value": "" }
      }
    }
  ],
  "assertions": [
    { "desc": "tools/list answers without a protocol error", "step": "tools", "path": "error", "type": "notExists" },
    { "desc": "resources/list returns at least one of the 3 requested documents", "step": "resources", "path": "result.resources.0.uri", "type": "exists" },
    { "desc": "resources/templates/list returns the requested templated doc resource", "step": "templates", "path": "result.resourceTemplates.0.uriTemplate", "type": "exists" },
    { "desc": "prompts/list returns the requested summarize prompt", "step": "prompts", "path": "result.prompts.0.name", "type": "exists" },
    { "desc": "resources/read on a discovered document declares a mimeType", "step": "read-doc", "path": "result.contents.0.mimeType", "type": "exists" },
    { "desc": "completion/complete on the discovered template is wired up (capabilities.completions declared, no Method-not-found)", "step": "complete-template", "path": "error.code", "type": "notExists" }
  ]
}
SPEC
  node "$(pwd)/$EVALS_DIR/mcp-test-client.mjs" "$tmp/.eval-spec.json"
  check "level 2: scaffolded server answers the protocol surface" $?
}

level3() {
  echo "== Level 3: E2E AUDIT (headless, gated) =="
  if [ "${RUN_HEADLESS:-0}" != "1" ]; then
    echo "SKIPPED (set RUN_HEADLESS=1 to run; spawns a real headless claude -p run)"
    return
  fi

  local tmp report
  tmp=$(mktemp -d)
  cp -r "$EVALS_DIR/files/." "$tmp/"
  report="$tmp/.audit-report.txt"

  if ! (cd "$tmp" && claude -p "Audit and fix broken-mcp-index.ts against all quality dimensions, including resources, resource templates, completions, prompts, naming portability, and icon metadata. Report every issue found, before/after Smithery score." > "$report"); then
    check "level 3: headless AUDIT run completed" 1
    return
  fi
  check "level 3: headless AUDIT run completed" 0

  node -e "
    const fs = require('fs');
    const bugs = JSON.parse(fs.readFileSync('$EVALS_DIR/files/planted-bugs.json', 'utf8')).planted_bugs;
    const report = fs.readFileSync('$report', 'utf8').toLowerCase();
    const found = bugs.filter((b) => {
      const keywords = b.id.toLowerCase().split('-').slice(1);
      return keywords.every((k) => report.includes(k));
    });
    const recall = found.length / bugs.length;
    console.error('recall: ' + (recall * 100).toFixed(0) + '% (' + found.length + '/' + bugs.length + ') — ' + report);
    process.exit(recall >= 0.9 ? 0 : 1);
  "
  check "level 3: AUDIT report recall >= 90% of planted-bugs.json (PRD §8 target)" $?
}

level0
level1
level2
level3

echo
echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
exit $?
