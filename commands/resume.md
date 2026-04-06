# /resume -- Load Session Context and Brief

You are loading context from a previous session so the user can pick up where they left off. Do NOT start working. Do NOT modify code. Present the context and wait for direction.

---

## Step 1: Find context directory

```bash
CONTEXT_DIR=$(ls -d *-context/ 2>/dev/null | head -1)
echo "CONTEXT: ${CONTEXT_DIR:-NONE}"
```

If no context directory found, say: "No forge context found. Run `./forge/setup` first." and stop.

---

## Step 2: Load the knowledge base index

Read INDEX.md -- this is the map of everything we know:

```bash
cat "${CONTEXT_DIR}INDEX.md" 2>/dev/null || echo "NO INDEX -- run /compile-wiki to build the knowledge base"
```

---

## Step 3: Load current state

```bash
echo "=== STATE ==="
cat "${CONTEXT_DIR}STATE.md" 2>/dev/null || echo "NO STATE"
```

---

## Step 4: Load known issues

```bash
echo "=== BACKLOG ==="
cat "${CONTEXT_DIR}BACKLOG.md" 2>/dev/null || echo "NO BACKLOG"
```

---

## Step 5: Load recent learnings

```bash
echo "=== RECENT LEARNINGS ==="
tail -20 "${CONTEXT_DIR}LEARNINGS.jsonl" 2>/dev/null || echo "NO LEARNINGS"
```

---

## Step 6: Load recent timeline

```bash
echo "=== RECENT ACTIVITY ==="
tail -10 "${CONTEXT_DIR}timeline.jsonl" 2>/dev/null || echo "NO TIMELINE"
```

---

## Step 7: Find latest session checkpoint

```bash
echo "=== LATEST CHECKPOINT ==="
LATEST=$(ls -t "${CONTEXT_DIR}SESSIONS/"*.md 2>/dev/null | head -1)
if [ -n "$LATEST" ]; then
  echo "FILE: $LATEST"
  cat "$LATEST"
else
  echo "NO CHECKPOINTS"
fi
```

If a checkpoint exists, read it fully. It contains: what was being worked on, decisions made, remaining work, and notes/gotchas.

---

## Step 8: Present structured briefing

Synthesize everything into a clear briefing:

```
SESSION BRIEFING
========================================

Project: {from context directory name}
Last checkpoint: {title from latest SESSIONS/ file, or "none"}
Last activity: {most recent timeline entry}

STACK HEALTH:
  {summary from STATE.md -- what's up, what's down}

KNOWN ISSUES ({count}):
  1. {title} [{severity}] -- {one-line status}
  2. ...

WHAT WAS HAPPENING:
  {from checkpoint: summary of work in progress}

DECISIONS ALREADY MADE:
  {from checkpoint: key decisions that shouldn't be revisited}

WHAT NOT TO RETRY:
  {from BACKLOG: approaches that were tried and failed}

REMAINING WORK:
  {from checkpoint: next steps in priority order}

KNOWLEDGE BASE:
  {count} wiki articles available. Key areas: {list top categories from INDEX.md}

RECENT LEARNINGS:
  {top 3 most relevant learnings from LEARNINGS.jsonl}

========================================
Ready to continue. What would you like to work on?
```

---

## Critical Rules

- **Do NOT start working automatically.** Present the briefing and wait.
- **Do NOT modify the checkpoint file.** It's a historical record.
- **Do NOT skip the "What Not To Retry" section.** This is the most important section. It prevents wasted work.
- **If the checkpoint mentions decisions, do NOT re-litigate them.** They were made for a reason. If the user wants to change them, they'll say so.

---

## Step 9: Log to timeline

```bash
echo '{"skill":"resume","event":"completed","ts":"'$(date -u +%Y-%m-%dT%H:%M:%SZ)'","outcome":"success"}' >> "${CONTEXT_DIR}timeline.jsonl"
```

---

## Completion

Report **DONE** after presenting the briefing. Then wait for the user's direction.
