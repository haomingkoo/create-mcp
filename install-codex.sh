#!/bin/sh
set -e

SKILL_DIR="${CODEX_HOME:-$HOME/.codex}/skills/create-mcp"
BASE_URL="https://raw.githubusercontent.com/haomingkoo/create-mcp/main"
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

echo "Installing create-mcp Codex skill..."

mkdir -p "$SKILL_DIR/references"
mkdir -p "$SKILL_DIR/agents"

if [ -f "$SCRIPT_DIR/codex/create-mcp/SKILL.md" ] && [ -f "$SCRIPT_DIR/SKILL.md" ] && [ -f "$SCRIPT_DIR/references/typescript-boilerplate.md" ]; then
  cp "$SCRIPT_DIR/codex/create-mcp/SKILL.md" "$SKILL_DIR/SKILL.md"
  cp "$SCRIPT_DIR/codex/create-mcp/agents/openai.yaml" "$SKILL_DIR/agents/openai.yaml"
  cp "$SCRIPT_DIR/SKILL.md" "$SKILL_DIR/references/create-mcp-workflow.md"
  cp "$SCRIPT_DIR/references/typescript-boilerplate.md" "$SKILL_DIR/references/typescript-boilerplate.md"
  cp "$SCRIPT_DIR/references/smithery-config.md" "$SKILL_DIR/references/smithery-config.md"
  cp "$SCRIPT_DIR/references/deployment-guide.md" "$SKILL_DIR/references/deployment-guide.md"
  cp "$SCRIPT_DIR/references/discovery-guide.md" "$SKILL_DIR/references/discovery-guide.md"
  cp "$SCRIPT_DIR/references/primitives-guide.md" "$SKILL_DIR/references/primitives-guide.md"
else
  curl -fsSL "$BASE_URL/codex/create-mcp/SKILL.md"                  -o "$SKILL_DIR/SKILL.md"
  curl -fsSL "$BASE_URL/codex/create-mcp/agents/openai.yaml"       -o "$SKILL_DIR/agents/openai.yaml"
  curl -fsSL "$BASE_URL/SKILL.md"                                  -o "$SKILL_DIR/references/create-mcp-workflow.md"
  curl -fsSL "$BASE_URL/references/typescript-boilerplate.md"      -o "$SKILL_DIR/references/typescript-boilerplate.md"
  curl -fsSL "$BASE_URL/references/smithery-config.md"             -o "$SKILL_DIR/references/smithery-config.md"
  curl -fsSL "$BASE_URL/references/deployment-guide.md"            -o "$SKILL_DIR/references/deployment-guide.md"
  curl -fsSL "$BASE_URL/references/discovery-guide.md"             -o "$SKILL_DIR/references/discovery-guide.md"
  curl -fsSL "$BASE_URL/references/primitives-guide.md"            -o "$SKILL_DIR/references/primitives-guide.md"
fi

echo "Done. Restart Codex and use create-mcp for MCP work."
