#!/bin/bash
# forge pre-commit-check hook
# Runs as PreToolUse on Bash when command matches "git commit*"
# Reads RULES.md and checks if any rules apply to commits.
# Exit 0 = allow, Exit 2 = block with reason on stderr.

set -euo pipefail

# Read the hook input from stdin
INPUT=$(cat)
COMMAND=$(echo "$INPUT" | grep -o '"command":"[^"]*"' | head -1 | cut -d'"' -f4 2>/dev/null || echo "")

WORKSPACE_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
CONTEXT_DIR=$(ls -d "$WORKSPACE_DIR"/*-context/ 2>/dev/null | head -1)

if [ -z "$CONTEXT_DIR" ] || [ ! -f "${CONTEXT_DIR}RULES.md" ]; then
  exit 0
fi

RULES_CONTENT=$(cat "${CONTEXT_DIR}RULES.md" 2>/dev/null || echo "")

if [ -z "$RULES_CONTENT" ]; then
  exit 0
fi

# Check for common rule violations in the commit command

# Rule: no co-author / no co-authored-by
if echo "$RULES_CONTENT" | grep -qi "co-author\|co-authored"; then
  if echo "$COMMAND" | grep -qi "co-authored-by\|co-author"; then
    echo "BLOCKED by project rule: commit contains Co-Authored-By line but project rules prohibit this. Remove the Co-Authored-By line from the commit message." >&2
    exit 2
  fi
fi

# Rule: no --no-verify
if echo "$RULES_CONTENT" | grep -qi "no-verify\|skip.*hook"; then
  if echo "$COMMAND" | grep -q "\-\-no-verify"; then
    echo "BLOCKED by project rule: --no-verify is prohibited. Run hooks normally." >&2
    exit 2
  fi
fi

# Rule: no force push
if echo "$RULES_CONTENT" | grep -qi "force.push\|force-push"; then
  if echo "$COMMAND" | grep -q "\-\-force\|push.*-f "; then
    echo "BLOCKED by project rule: force push is prohibited." >&2
    exit 2
  fi
fi

# All checks passed
exit 0
