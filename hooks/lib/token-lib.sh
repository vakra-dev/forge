#!/bin/bash
# forge token-optimization helpers (sourced by check-file-size.sh, check-bash-read.sh)

FORGE_MAX_READ_LINES="${FORGE_MAX_READ_LINES:-350}"
FORGE_MAX_READ_BYTES="${FORGE_MAX_READ_BYTES:-40000}"   # ~10K tokens; catches few-line, very wide files
FORGE_TOKENS_PER_LINE=20   # measured ~23 for dense Rust, ~12 for prose

forge_workspace() { echo "${CLAUDE_PROJECT_DIR:-$(pwd)}"; }

# Append one JSON line to <workspace>/.claude/forge-token-log.jsonl (never fails the hook)
forge_log() {
  local event="$1" file="$2" lines="$3" read_lines="${4:-0}"
  local log; log="$(forge_workspace)/.claude/forge-token-log.jsonl"
  local avoided=$(( lines - read_lines )); [ "$avoided" -lt 0 ] && avoided=0
  local saved=$(( avoided * FORGE_TOKENS_PER_LINE ))
  {
    mkdir -p "$(dirname "$log")"
    printf '{"ts":"%s","event":"%s","file":"%s","lines":%s,"est_tokens":%s}\n' \
      "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$event" "${file//\"/\\\"}" "$lines" "$saved" >> "$log"
  } 2>/dev/null || true
}

# True if file is an existing, text (non-binary) file
forge_is_text() { [ -f "$1" ] && grep -Iq . "$1" 2>/dev/null; }

# Print a capped outline (line-numbered headings / definitions) of a file
forge_outline() {
  local f="$1"
  case "$f" in
    *.md|*.markdown)
      grep -nE '^#{1,3} ' "$f" 2>/dev/null | head -25 ;;
    *)
      grep -nE '^[[:space:]]*(pub(\([a-z]+\))?[[:space:]]+)?(async[[:space:]]+)?(unsafe[[:space:]]+)?(export[[:space:]]+)?(default[[:space:]]+)?(fn|struct|enum|trait|impl|mod|class|interface|def|function|func|type)[[:space:]]' "$f" 2>/dev/null | head -25 ;;
  esac
}
