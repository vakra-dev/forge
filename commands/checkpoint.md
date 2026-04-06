# /checkpoint -- Save Session State

You are capturing the full working context of this session so any future session can resume without losing context. This is the most important skill for session continuity.

**HARD GATE:** Do NOT implement code changes. This skill only captures state and updates the knowledge base.

---

## Step 1: Find context directory

```bash
CONTEXT_DIR=$(ls -d *-context/ 2>/dev/null | head -1)
echo "CONTEXT: ${CONTEXT_DIR:-NONE}"
```

If no context directory found, say: "No forge context found. Run `./forge/setup` first." and stop.

---

## Step 2: Gather git state across all repos

```bash
echo "=== GIT STATE ==="
for dir in */; do
  if [ -d "$dir/.git" ]; then
    echo "--- ${dir%/} ---"
    cd "$dir"
    echo "Branch: $(git branch --show-current 2>/dev/null)"
    git status --short 2>/dev/null
    echo "Recent:"
    git log --oneline -5 2>/dev/null
    cd ..
    echo ""
  fi
done
```

---

## Step 3: Gather test results

```bash
echo "=== TEST RESULTS ==="
if [ -f tests/e2e/results/latest.json ]; then
  node -e "
    const r = JSON.parse(require('fs').readFileSync('tests/e2e/results/latest.json','utf8'));
    console.log(JSON.stringify(r.summary, null, 2));
  " 2>/dev/null || echo "Could not parse"
else
  echo "No e2e results"
fi
```

---

## Step 4: Summarize the session

Using the git state, test results, and your conversation history, produce a summary covering:

1. **What was being worked on** -- the high-level goal or task
2. **What was accomplished** -- concrete outcomes (bugs fixed, features added, tests passing)
3. **What failed and why** -- approaches that didn't work, with specific reasons (this prevents retry loops)
4. **Decisions made** -- architectural choices, trade-offs, approaches chosen and why
5. **Remaining work** -- concrete next steps, in priority order
6. **Notes** -- gotchas, blocked items, open questions, anything a future session needs to know

If the user provided a title (e.g., `/checkpoint fixing table panic`), use it. Otherwise, infer a concise title (3-6 words) from the work done.

---

## Step 5: Write checkpoint file

Generate a timestamp and write the checkpoint:

```bash
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
echo "TIMESTAMP: $TIMESTAMP"
```

Write the checkpoint to `{CONTEXT_DIR}SESSIONS/{TIMESTAMP}-{title-slug}.md` where title-slug is the title in kebab-case.

**Checkpoint format:**

```markdown
---
status: in-progress
timestamp: {ISO-8601}
branches:
  {repo}: {branch}
files_modified:
  - {path}
---

## {Title}

### Summary
{1-3 sentences: what was being worked on and current progress}

### What Was Accomplished
{Bulleted list of concrete outcomes with evidence}

### What Failed (DO NOT RETRY)
{Bulleted list of failed approaches with EXACT reasons. This is the most critical section.}

### Decisions Made
{Bulleted list of choices and reasoning. Future sessions should not re-litigate these.}

### Remaining Work
{Numbered list of next steps in priority order}

### Notes
{Gotchas, environment quirks, open questions, blocked items}
```

---

## Step 6: Update STATE.md

Update the state file with current information from this session:
- Service health status (if known from this session)
- Latest test results
- Any issues resolved or new issues found
- Update the "Last updated" timestamp

Read the existing STATE.md first, then update it. Do not overwrite information you don't have updated data for.

---

## Step 7: Wiki contribution

Check if this session produced knowledge worth documenting:

- **New bug found?** -> Create or update `wiki/bugs/{slug}.md` and add to INDEX.md
- **Bug resolved?** -> Update the bug article with the fix, mark as resolved in BACKLOG.md
- **Architectural insight?** -> Create or update `wiki/architecture/` or `wiki/decisions/` article
- **Pattern discovered?** -> Create `wiki/patterns/{slug}.md`
- **Stale wiki content noticed?** -> Fix it now

Always update INDEX.md if you add or remove articles.

---

## Step 8: Learning capture

Reflect on this session:
- Did any approach fail unexpectedly?
- Did you discover a project-specific quirk (build order, env vars, timing)?
- Would this insight save 5+ minutes in a future session?

If yes, append to LEARNINGS.jsonl:

```bash
echo '{"ts":"'$(date -u +%Y-%m-%dT%H:%M:%SZ)'","skill":"checkpoint","type":"TYPE","key":"SHORT_KEY","insight":"DESCRIPTION","confidence":N,"source":"observed","files":["path"]}' >> "${CONTEXT_DIR}LEARNINGS.jsonl"
```

---

## Step 9: Git commit the context repo

```bash
cd "${CONTEXT_DIR}"
git add -A
git commit -m "checkpoint: {title} ($(date +%Y-%m-%d))"
cd ..
```

---

## Step 10: Log to timeline

```bash
echo '{"skill":"checkpoint","event":"completed","ts":"'$(date -u +%Y-%m-%dT%H:%M:%SZ)'","outcome":"success","checkpoint":"SESSIONS/{filename}"}' >> "${CONTEXT_DIR}timeline.jsonl"
```

---

## Step 11: Confirm

```
CHECKPOINT SAVED
========================================
Title:      {title}
File:       {path to checkpoint file}
Branches:   {list of repo:branch}
Modified:   {count of dirty files across repos}
Wiki:       {count of articles added/updated, or "no changes"}
Learnings:  {count added, or "none"}
========================================
```

---

## Critical Rules

- **Never modify source code.** This skill only captures state.
- **The "What Failed" section is mandatory.** Even if nothing failed, write "Nothing failed this session." This section prevents retry loops and is the most valuable part of the checkpoint.
- **Checkpoint files are append-only.** Never overwrite or delete existing checkpoints.
- **Infer, don't interrogate.** Use git state and conversation context. Only ask the user if the title genuinely cannot be inferred.
- **Always git commit the context repo.** The checkpoint is only valuable if it's committed.

---

## Completion

Report **DONE** with the checkpoint summary.
