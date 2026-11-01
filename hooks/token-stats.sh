#!/bin/bash
# forge token-stats: summarise .claude/forge-token-log.jsonl
# Usage: token-stats.sh [days]   (default: all time)
# Tokens are ESTIMATES (12 tokens/line); they show direction, not billing.
LOG="${CLAUDE_PROJECT_DIR:-$(pwd)}/.claude/forge-token-log.jsonl"
DAYS="${1:-0}"
[ -s "$LOG" ] || { echo "No forge token log yet ($LOG)."; exit 0; }
command -v jq >/dev/null 2>&1 || { echo "token-stats needs jq"; exit 1; }
SINCE="1970-01-01T00:00:00Z"
[ "$DAYS" -gt 0 ] && SINCE=$(date -u -v-"${DAYS}"d +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -d "$DAYS days ago" +%Y-%m-%dT%H:%M:%SZ)

echo "forge token savings (since ${SINCE%%T*}; estimates)"
echo "------------------------------------------------"
jq -rs --arg since "$SINCE" '
  map(select(.ts >= $since)) as $e
  | ($e | group_by(.event) | map({event: .[0].event, n: length, tokens: (map(.est_tokens) | add)})) as $g
  | ($g[] | "\(.event|.+"            "|.[0:14])  count \(.n|tostring|.+"     "|.[0:5])  ~\(.tokens) tokens kept out of context"),
    "",
    "Top files by blocked/delegated reads:",
    ($e | map(select(.event != "targeted_read")) | group_by(.file) | map({f: .[0].file, n: length, t: (map(.est_tokens)|add)})
      | sort_by(-.t) | .[:8][] | "  \(.n)x  ~\(.t)  \(.f)"),
    "",
    "Total est. tokens kept out of Opus context (blocked + bulk_read): ~\($e | map(select(.event != "targeted_read") | .est_tokens) | add // 0)"
' "$LOG"
