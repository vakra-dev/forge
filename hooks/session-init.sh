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

# Token optimization: STATE.md -> RESUME section only, BACKLOG.md -> titles only.
# FORGE_INIT_FULL=1 restores the old behaviour (inject both files whole).
FORGE_INIT_FULL="${FORGE_INIT_FULL:-0}"
FORGE_STATE_FALLBACK_LINES="${FORGE_STATE_FALLBACK_LINES:-40}"

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
  if [ "$FORGE_INIT_FULL" = "1" ]; then
    cat "${CONTEXT_DIR}STATE.md"
  else
    # RESUME block: from the first "## ...RESUME..." heading to the next "## " heading.
    # Inside it, inject only the "### Now" subsection plus a titled list of the rest.
    RESUME=$(awk '/^## .*RESUME/ {f=1; print; next} f && /^## / {exit} f {print}' "${CONTEXT_DIR}STATE.md")
    if [ -n "$RESUME" ]; then
      NOW=$(echo "$RESUME" | awk '/^### Now/ {f=1; print; next} f && /^### / {exit} f {print}')
      if [ -n "$NOW" ]; then
        echo "$RESUME" | sed -n '1,/^### /p' | sed '$d'
        echo "$NOW"
        echo ""
        echo "[forge] Other RESUME subsections (line: title) -- Read with offset/limit only when needed:"
        awk '/^## .*RESUME/ {f=1; next} f && /^## / {exit} f && /^### / {print NR+0 ": " $0}' "${CONTEXT_DIR}STATE.md" | head -20
      else
        echo "$RESUME"
      fi
      echo ""
      echo "[forge] STATE.md is trimmed. Full file: ${CONTEXT_DIR}STATE.md ($(wc -l < "${CONTEXT_DIR}STATE.md" | tr -d ' ') lines) -- Grep -n / Read with offset+limit, never whole."
    else
      head -n "$FORGE_STATE_FALLBACK_LINES" "${CONTEXT_DIR}STATE.md"
      echo ""
      echo "[forge] No RESUME heading in STATE.md; showing first $FORGE_STATE_FALLBACK_LINES lines. Full file: ${CONTEXT_DIR}STATE.md"
    fi
  fi
  echo ""
fi

# --- Known issues (prevents retrying failed approaches) ---
if [ -f "${CONTEXT_DIR}BACKLOG.md" ] && [ -s "${CONTEXT_DIR}BACKLOG.md" ]; then
  ACTIVE_COUNT=$(grep -c "^### " "${CONTEXT_DIR}BACKLOG.md" 2>/dev/null || echo "0")
  if [ "$ACTIVE_COUNT" -gt 0 ]; then
    echo "=== BACKLOG ($ACTIVE_COUNT active issues) ==="
    if [ "$FORGE_INIT_FULL" = "1" ]; then
      cat "${CONTEXT_DIR}BACKLOG.md"
    else
      grep -n "^### " "${CONTEXT_DIR}BACKLOG.md" | cut -c1-160
      echo "[forge] Titles only (line: title). Read details with offset/limit from ${CONTEXT_DIR}BACKLOG.md before retrying any approach listed there."
    fi
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
