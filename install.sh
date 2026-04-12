#!/bin/sh
set -e

SKILL_DIR="$HOME/.claude/skills/create-mcp"
SKILL_URL="https://raw.githubusercontent.com/haomingkoo/create-mcp/main/skill.md"

echo "Installing create-mcp skill..."
mkdir -p "$SKILL_DIR"
curl -fsSL "$SKILL_URL" -o "$SKILL_DIR/skill.md"
echo "Done. Restart Claude Code and run /create-mcp"
