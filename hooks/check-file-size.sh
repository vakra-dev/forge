#!/bin/bash
# forge check-file-size hook
# PreToolUse on Read. Blocks full-file reads of large files; targeted reads
# (offset/limit) always pass. Exit 0 = allow, Exit 2 = block (message on stderr).
#
# Config: FORGE_MAX_READ_LINES (default 350), FORGE_ALLOW_FULL_READ=1 to bypass.

set -uo pipefail
. "$(dirname "$0")/lib/token-lib.sh"

[ "${FORGE_ALLOW_FULL_READ:-0}" = "1" ] && exit 0

INPUT=$(cat)
if command -v jq >/dev/null 2>&1; then
  FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')
  OFFSET=$(echo "$INPUT" | jq -r '.tool_input.offset // empty')
  LIMIT=$(echo "$INPUT" | jq -r '.tool_input.limit // empty')
else
  FILE=$(echo "$INPUT" | grep -o '"file_path":"[^"]*"' | head -1 | cut -d'"' -f4)
  OFFSET=$(echo "$INPUT" | grep -o '"offset":[0-9]*' | head -1 | cut -d: -f2)
  LIMIT=$(echo "$INPUT" | grep -o '"limit":[0-9]*' | head -1 | cut -d: -f2)
fi

[ -z "$FILE" ] && exit 0
# Subagent reads (e.g. the /bulk-read worker) are not the expensive context: allow if the input names an agent
if command -v jq >/dev/null 2>&1 && [ -n "$(echo "$INPUT" | jq -r '.agent_id // empty')" ]; then exit 0; fi
forge_is_text "$FILE" || exit 0

LINES=$(wc -l < "$FILE" | tr -d ' ')
BYTES=$(wc -c < "$FILE" | tr -d ' ')

# Targeted read: allow (log it so we can see how often it happens)
if [ -n "$OFFSET" ] || [ -n "$LIMIT" ]; then
  if [ "$LINES" -gt "$FORGE_MAX_READ_LINES" ] || [ "$BYTES" -gt "$FORGE_MAX_READ_BYTES" ]; then
    forge_log "targeted_read" "$FILE" "$LINES" "${LIMIT:-2000}"
  fi
  exit 0
fi

if [ "$LINES" -le "$FORGE_MAX_READ_LINES" ] && [ "$BYTES" -le "$FORGE_MAX_READ_BYTES" ]; then exit 0; fi

# Wide files: estimate lines from bytes (~100 bytes/line) so the log reflects real cost
EST_LINES=$LINES; [ $((BYTES / 100)) -gt "$EST_LINES" ] && EST_LINES=$((BYTES / 100))
forge_log "read_blocked" "$FILE" "$EST_LINES"

{
  echo "BLOCKED by forge: $FILE has $LINES lines / $BYTES bytes (limits: $FORGE_MAX_READ_LINES lines, $FORGE_MAX_READ_BYTES bytes for full reads)."
  echo "Do one of:"
  echo "  1. Read a section: Read with offset/limit (outline below gives line numbers)."
  echo "  2. Grep -n for the symbol/term you need, then Read ~60 lines around the match."
  echo "  3. To UNDERSTAND the file (not edit it): run /bulk-read, which has a Haiku subagent"
  echo "     answer your question and return path:start-end line ranges to read next."
  echo ""
  echo "Outline (line: definition):"
  forge_outline "$FILE"
} >&2
exit 2
