#!/bin/bash
# forge check-bash-read hook
# PreToolUse on Bash. Closes the Read-gate loophole: blocks `cat`/`less`/`more`
# of large files, and `head`/`tail` asking for more than the limit.
# Only simple, single commands are inspected: anything with a pipe, redirect,
# heredoc, &&, ; or a subshell is allowed. Exit 0 = allow, Exit 2 = block.
#
# Config: FORGE_MAX_READ_LINES (default 350), FORGE_ALLOW_FULL_READ=1 to bypass.

set -uo pipefail
. "$(dirname "$0")/lib/token-lib.sh"

[ "${FORGE_ALLOW_FULL_READ:-0}" = "1" ] && exit 0

INPUT=$(cat)
if command -v jq >/dev/null 2>&1; then
  CMD=$(echo "$INPUT" | jq -r '.tool_input.command // empty')
else
  CMD=$(echo "$INPUT" | grep -o '"command":"[^"]*"' | head -1 | cut -d'"' -f4)
fi
[ -z "$CMD" ] && exit 0

# Compound / piped / redirected commands: allow
case "$CMD" in
  *"|"*|*">"*|*"<"*|*"&"*|*";"*|*'$('*|*'`'*|*$'\n'*) exit 0 ;;
esac

# shellcheck disable=SC2206
read -r -a TOK <<< "$CMD"
PROG="${TOK[0]:-}"
case "$PROG" in cat|less|more|head|tail) ;; *) exit 0 ;; esac

# Parse flags / operands
COUNT=""            # requested line count for head/tail
TAIL_FROM_START=0   # tail -n +N reads to EOF
FILES=()
i=1
while [ $i -lt ${#TOK[@]} ]; do
  t="${TOK[$i]}"
  # cat/less/more flags (e.g. cat -n) are never line counts
  if [ "$PROG" != "head" ] && [ "$PROG" != "tail" ] && [[ "$t" == -* ]]; then i=$((i+1)); continue; fi
  case "$t" in
    -n|--lines)
      i=$((i+1)); v="${TOK[$i]:-}"
      case "$v" in +*) TAIL_FROM_START=1 ;; esac
      COUNT="${v#[+-]}" ;;
    -n*)  v="${t#-n}"; case "$v" in +*) TAIL_FROM_START=1 ;; esac; COUNT="${v#[+-]}" ;;
    --lines=*) v="${t#--lines=}"; COUNT="${v#[+-]}" ;;
    -f|-F|--follow*) exit 0 ;;                       # tail -f: streaming, not a file read
    -[0-9]*) COUNT="${t#-}" ;;                      # head -20 / tail -20
    -*) ;;                                          # other flags (-n handled above, -c bytes ignored)
    *)  FILES+=("${t//[\"\']/}") ;;
  esac
  i=$((i+1))
done

[ ${#FILES[@]} -eq 0 ] && exit 0

# head/tail with a small explicit count are targeted reads
if [ "$PROG" = "head" ] || [ "$PROG" = "tail" ]; then
  if [ -n "$COUNT" ] && [[ "$COUNT" =~ ^[0-9]+$ ]] && [ "$TAIL_FROM_START" -eq 0 ] \
     && [ "$COUNT" -le "$FORGE_MAX_READ_LINES" ]; then
    exit 0
  fi
  [ -z "$COUNT" ] && exit 0                         # default is 10 lines
fi

TOTAL=0; BIG=""
for f in "${FILES[@]}"; do
  case "$f" in /*) ;; *) f="$(forge_workspace)/$f" ;; esac
  forge_is_text "$f" || continue
  n=$(wc -l < "$f" | tr -d ' ')
  TOTAL=$((TOTAL + n)); BIG="${BIG}${f} (${n} lines)"$'\n'
done

[ "$TOTAL" -le "$FORGE_MAX_READ_LINES" ] && exit 0

forge_log "bash_blocked" "${FILES[*]}" "$TOTAL"

{
  echo "BLOCKED by forge: \`$PROG\` would load $TOTAL lines (limit $FORGE_MAX_READ_LINES). Grep -n, Read with offset/limit, or sed -n 'A,Bp' (<= $FORGE_MAX_READ_LINES lines). To understand most of the file or 3+ files: /bulk-read."
} >&2
exit 2
