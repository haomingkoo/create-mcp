#!/bin/sh
set -e

SKILL_DIR="$HOME/.claude/skills/create-mcp"
BASE_URL="https://raw.githubusercontent.com/haomingkoo/create-mcp/main"

echo "Installing create-mcp skill..."

mkdir -p "$SKILL_DIR/references"
mkdir -p "$SKILL_DIR/evals/files"

curl -fsSL "$BASE_URL/skill.md"                                  -o "$SKILL_DIR/skill.md"
curl -fsSL "$BASE_URL/references/typescript-boilerplate.md"      -o "$SKILL_DIR/references/typescript-boilerplate.md"
curl -fsSL "$BASE_URL/references/smithery-config.md"             -o "$SKILL_DIR/references/smithery-config.md"
curl -fsSL "$BASE_URL/references/deployment-guide.md"            -o "$SKILL_DIR/references/deployment-guide.md"

echo "Done. Restart Claude Code and run /create-mcp"
