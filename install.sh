#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

DOCS_TARGET="${1:-docs}"
SKILL_TARGET=".cursor/skills/workflow-automation/prompt-queue"
RULE_TARGET=".cursor/rules"

echo "Installing prompt-queue into current project..."
echo "  Queue folder: $DOCS_TARGET/"

mkdir -p "$SKILL_TARGET" "$RULE_TARGET" "$DOCS_TARGET"

cp "$SCRIPT_DIR/skill/prompt-queue/SKILL.md" "$SKILL_TARGET/SKILL.md"
cp "$SCRIPT_DIR/rules/prompt-queue.mdc"      "$RULE_TARGET/prompt-queue.mdc"
cp "$SCRIPT_DIR/templates/prompt_queue.md"    "$DOCS_TARGET/prompt_queue.md"
cp "$SCRIPT_DIR/templates/prompt_queue_state.md" "$DOCS_TARGET/prompt_queue_state.md"

if [ "$DOCS_TARGET" != "docs" ]; then
    sed -i '' "s|docs/prompt_queue.md|$DOCS_TARGET/prompt_queue.md|g" "$SKILL_TARGET/SKILL.md"
    sed -i '' "s|docs/prompt_queue_state.md|$DOCS_TARGET/prompt_queue_state.md|g" "$SKILL_TARGET/SKILL.md"
    sed -i '' "s|docs/prompt_queue.md|$DOCS_TARGET/prompt_queue.md|g" "$RULE_TARGET/prompt-queue.mdc"
    sed -i '' "s|docs/prompt_queue_state.md|$DOCS_TARGET/prompt_queue_state.md|g" "$RULE_TARGET/prompt-queue.mdc"
fi

echo ""
echo "Installed:"
echo "  $SKILL_TARGET/SKILL.md"
echo "  $RULE_TARGET/prompt-queue.mdc"
echo "  $DOCS_TARGET/prompt_queue.md        (edit this with your prompts)"
echo "  $DOCS_TARGET/prompt_queue_state.md  (auto-managed by the agent)"
if [ "$DOCS_TARGET" != "docs" ]; then
    echo ""
    echo "  Paths in SKILL.md and prompt-queue.mdc updated to use $DOCS_TARGET/"
fi
echo ""
echo "Usage: Open Cursor and say \"execute prompt queue\""
