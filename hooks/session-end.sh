#!/bin/bash
# forge session-end hook
# Runs on SessionEnd to append a timeline entry.
# Records that a session happened, for /recall to reference.

set -euo pipefail

WORKSPACE_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
CONTEXT_DIR=$(ls -d "$WORKSPACE_DIR"/*-context/ 2>/dev/null | head -1)

if [ -z "$CONTEXT_DIR" ]; then
  exit 0
fi

TIMELINE="${CONTEXT_DIR}timeline.jsonl"

echo "{\"skill\":\"session\",\"event\":\"ended\",\"ts\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}" >> "$TIMELINE"
