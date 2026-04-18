#!/bin/bash
# forge session-init hook
# Runs on SessionStart (startup + compact) to inject project context automatically.
# Output goes directly into Claude's context window.

set -euo pipefail

WORKSPACE_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
CONTEXT_DIR=$(ls -d "$WORKSPACE_DIR"/*-context/ 2>/dev/null | head -1)

if [ -z "$CONTEXT_DIR" ]; then
  echo "[forge] No context directory found. Run ./forge/setup to initialize."
  exit 0
fi

PROJECT_NAME=$(basename "$CONTEXT_DIR" | sed 's/-context$//')

# --- Rules (non-negotiable, always loaded) ---
if [ -f "${CONTEXT_DIR}RULES.md" ] && [ -s "${CONTEXT_DIR}RULES.md" ]; then
  echo "=== PROJECT RULES (MUST FOLLOW) ==="
  cat "${CONTEXT_DIR}RULES.md"
  echo ""
fi

# --- Wiki index (navigation map, ~2K tokens) ---
if [ -f "${CONTEXT_DIR}INDEX.md" ]; then
  echo "=== KNOWLEDGE BASE INDEX ==="
  cat "${CONTEXT_DIR}INDEX.md"
  echo ""
fi

# --- Current state (what's healthy/broken) ---
if [ -f "${CONTEXT_DIR}STATE.md" ]; then
  echo "=== CURRENT STATE ==="
  cat "${CONTEXT_DIR}STATE.md"
  echo ""
fi

# --- Known issues (prevents retrying failed approaches) ---
if [ -f "${CONTEXT_DIR}BACKLOG.md" ] && [ -s "${CONTEXT_DIR}BACKLOG.md" ]; then
  ACTIVE_COUNT=$(grep -c "^### " "${CONTEXT_DIR}BACKLOG.md" 2>/dev/null || echo "0")
  if [ "$ACTIVE_COUNT" -gt 0 ]; then
    echo "=== BACKLOG ($ACTIVE_COUNT active issues) ==="
    cat "${CONTEXT_DIR}BACKLOG.md"
    echo ""
  fi
fi

# --- Learnings with confidence decay ---
if [ -f "${CONTEXT_DIR}LEARNINGS.jsonl" ] && [ -s "${CONTEXT_DIR}LEARNINGS.jsonl" ]; then
  echo "=== RECENT LEARNINGS (confidence-decayed) ==="
  NOW=$(date +%s)
  tail -30 "${CONTEXT_DIR}LEARNINGS.jsonl" | while IFS= read -r line; do
    TS=$(echo "$line" | grep -o '"ts":"[^"]*"' | head -1 | cut -d'"' -f4)
    CONF=$(echo "$line" | grep -o '"confidence":[0-9]*' | head -1 | cut -d: -f2)
    if [ -n "$TS" ] && [ -n "$CONF" ]; then
      # Calculate days since learning
      LEARN_TS=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$TS" +%s 2>/dev/null || date -d "$TS" +%s 2>/dev/null || echo "$NOW")
      DAYS_AGO=$(( (NOW - LEARN_TS) / 86400 ))
      DECAY=$(( DAYS_AGO / 30 ))
      EFFECTIVE=$(( CONF - DECAY ))
      if [ "$EFFECTIVE" -ge 3 ]; then
        echo "$line"
      fi
    else
      echo "$line"
    fi
  done
  echo ""
fi

# --- Latest checkpoint summary (what happened last session) ---
LATEST_SESSION=$(ls -t "${CONTEXT_DIR}SESSIONS/"*.md 2>/dev/null | head -1)
if [ -n "$LATEST_SESSION" ]; then
  echo "=== LATEST SESSION CHECKPOINT ==="
  echo "File: $LATEST_SESSION"
  # Show just the summary and remaining work sections (not the full checkpoint)
  sed -n '/^### Summary/,/^### What Was Accomplished/p' "$LATEST_SESSION" 2>/dev/null | head -5
  echo ""
  sed -n '/^### Remaining Work/,/^### /p' "$LATEST_SESSION" 2>/dev/null | head -15
  echo ""
fi

echo "[forge] Context loaded for project: $PROJECT_NAME"
