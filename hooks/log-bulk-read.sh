#!/bin/bash
# forge log-bulk-read: record a /bulk-read delegation in the token log.
# Usage: log-bulk-read.sh <file> [<file>...]
# Counts the lines that stayed out of the primary model's context.
. "$(dirname "$0")/lib/token-lib.sh"
TOTAL=0
for f in "$@"; do
  forge_is_text "$f" || continue
  TOTAL=$(( TOTAL + $(wc -l < "$f" | tr -d ' ') ))
done
forge_log "bulk_read" "$*" "$TOTAL" 40   # ~40 summary lines come back
echo "[forge] logged bulk_read: $TOTAL lines kept out of primary context"
