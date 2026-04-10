# /checkpoint -- Save Session State

You are a **Staff Engineer writing meticulous session notes**. Your job is to capture
the COMPLETE working context of this session so that ANY future session -- even weeks
from now, even by a different person -- can pick up exactly where we left off without
losing a single insight, decision, or failed approach.

This is the most important skill for session continuity. A good checkpoint saves hours
of re-investigation. A bad checkpoint (or a missing one) means starting from scratch.

**HARD GATE:** Do NOT implement code changes. This skill captures state, updates the
knowledge base, and commits to the context repo. It does not modify source code.

---

## Preamble -- Load Context

### P1. Find the context directory

```bash
CONTEXT_DIR=$(ls -d *-context/ 2>/dev/null | head -1)
if [ -n "$CONTEXT_DIR" ]; then
  echo "CONTEXT_DIR: $CONTEXT_DIR"
  PROJECT_NAME=$(echo "$CONTEXT_DIR" | sed 's/-context\///')
  echo "PROJECT: $PROJECT_NAME"
else
  echo "CONTEXT_DIR: NONE"
fi
```

**If CONTEXT_DIR is NONE:** Tell the user: "No forge context directory found. Run
`./forge/setup` to initialize." Then STOP. Report as BLOCKED.

### P2. Read current state for comparison

```bash
CONTEXT_DIR=$(ls -d *-context/ 2>/dev/null | head -1)
echo "=== CURRENT STATE ==="
cat "${CONTEXT_DIR}STATE.md" 2>/dev/null || echo "NO STATE"
echo ""
echo "=== CURRENT BACKLOG ==="
cat "${CONTEXT_DIR}BACKLOG.md" 2>/dev/null || echo "NO BACKLOG"
echo ""
echo "=== CURRENT INDEX ==="
cat "${CONTEXT_DIR}INDEX.md" 2>/dev/null || echo "NO INDEX"
```

### P3. Read the latest checkpoint for continuity

```bash
CONTEXT_DIR=$(ls -d *-context/ 2>/dev/null | head -1)
echo "=== LATEST CHECKPOINT ==="
LATEST=$(ls -t "${CONTEXT_DIR}SESSIONS/"*.md 2>/dev/null | head -1)
if [ -n "$LATEST" ]; then
  echo "Previous: $LATEST"
  cat "$LATEST"
else
  echo "No previous checkpoints"
fi
```

If a previous checkpoint exists, read it. The new checkpoint should show PROGRESS
from the previous one: what was remaining that is now done, what new work appeared.

---

## Step 1: Gather Git State Across ALL Repos

For every repo in the workspace, capture its complete git state:

```bash
echo "=== GIT STATE ==="
echo ""
for dir in */; do
  if [ -d "$dir/.git" ]; then
    echo "═══ ${dir%/} ═══"
    echo ""

    # Branch
    BRANCH=$(cd "$dir" && git branch --show-current 2>/dev/null || echo "detached")
    echo "  Branch: $BRANCH"

    # Dirty files
    DIRTY=$(cd "$dir" && git status --porcelain 2>/dev/null)
    DIRTY_COUNT=$(echo "$DIRTY" | grep -c . 2>/dev/null || echo "0")
    echo "  Dirty files: $DIRTY_COUNT"
    if [ "$DIRTY_COUNT" -gt 0 ]; then
      echo "$DIRTY" | head -20 | sed 's/^/    /'
      if [ "$DIRTY_COUNT" -gt 20 ]; then
        echo "    ... and $((DIRTY_COUNT - 20)) more"
      fi
    fi

    # Staged files
    STAGED=$(cd "$dir" && git diff --cached --name-only 2>/dev/null)
    STAGED_COUNT=$(echo "$STAGED" | grep -c . 2>/dev/null || echo "0")
    echo "  Staged files: $STAGED_COUNT"

    # Recent commits (last 5)
    echo "  Recent commits:"
    cd "$dir" && git log --oneline -5 --date=short --format="    %h %s (%ad)" 2>/dev/null || echo "    no commits"
    cd ..

    # Unpushed
    UNPUSHED=$(cd "$dir" && git log @{u}..HEAD --oneline 2>/dev/null | wc -l | tr -d ' ')
    echo "  Unpushed commits: $UNPUSHED"

    echo ""
  fi
done
```

---

## Step 2: Gather Test Results

### 2a. E2E test results

```bash
echo "=== E2E RESULTS ==="
if [ -f tests/e2e/results/latest.json ]; then
  node -e "
    const r = JSON.parse(require('fs').readFileSync('tests/e2e/results/latest.json','utf8'));
    console.log('Timestamp: ' + r.timestamp);
    console.log('Pass:      ' + r.summary.pass + '/' + r.config.totalUrls + ' (' + ((r.summary.pass/r.config.totalUrls)*100).toFixed(1) + '%)');
    console.log('Fail:      ' + r.summary.fail);
    console.log('Crash:     ' + r.summary.crash);
    console.log('Partial:   ' + r.summary.partial);
    console.log('Duration:  ' + (r.summary.totalDurationMs/1000).toFixed(1) + 's');
  " 2>/dev/null || echo "Could not parse"
else
  echo "No e2e results"
fi
```

### 2b. Check for recent unit test runs

```bash
echo ""
echo "=== UNIT TEST STATUS ==="
for dir in reader reader-api reader-cloud-api supermarkdown; do
  if [ -d "$dir" ]; then
    HAS_TESTS="no"
    [ -f "$dir/vitest.config.ts" ] || [ -f "$dir/vitest.config.js" ] && HAS_TESTS="vitest"
    [ -f "$dir/Cargo.toml" ] && HAS_TESTS="cargo"
    echo "  ${dir}: framework=$HAS_TESTS"
  fi
done
```

---

## Step 3: Summarize the Session

Using ALL available context (git state, test results, your conversation history in this
session, the previous checkpoint), produce a comprehensive summary covering EVERY one
of these sections. Do NOT skip any section, even if it seems empty.

### 3a. Determine the title

If the user provided a title (e.g., `/checkpoint fixing table panic`), use it exactly.

If no title provided, infer one from the session's work. The title should be 3-8 words
that describe the main activity. Examples:
- "e2e test suite setup"
- "investigating table.rs panic"
- "fixing amazon scrape failures"
- "initial wiki compilation"
- "reader-api error handling"

Convert to kebab-case for the filename: "investigating-table-rs-panic"

### 3b. What was being worked on

1-3 sentences describing the high-level goal. Be specific: not "working on bugs" but
"investigating why supermarkdown panics on nested HTML tables in Wikipedia articles."

### 3c. What was accomplished

Bulleted list of CONCRETE outcomes. For each, include evidence:
- "Fixed the pool timeout in reader engine (commit abc1234)"
- "E2e test suite now passes 85/150 URLs (was 70/150)"
- "Created wiki/bugs/table-rs-panic.md with investigation findings"
- "Ran /compile-wiki, knowledge base now has 12 articles"

If nothing was accomplished (e.g., pure investigation that didn't lead to a fix), say
so honestly: "No code changes. Investigation session only."

### 3d. What failed and why (THE MOST IMPORTANT SECTION)

**This section prevents future sessions from wasting time.** For EVERY approach that
was tried and didn't work, document:

- **What was tried:** The specific approach, not a vague description
- **Why it failed:** The EXACT error message, the specific reason, the concrete outcome
- **What we learned from the failure:** Any insight gained

Examples of GOOD entries:
- "Tried increasing pool-size to 10: FAILED because Hero doesn't support >5 concurrent
  browsers on macOS due to Chromium process limits. Error: 'Failed to launch browser: too many open files'"
- "Tried replacing recursive table parsing with iterative: FAILED because the HTML
  structure has arbitrary nesting depth that can't be flattened without losing rowspan/colspan info"
- "Tried standard proxy for Amazon: FAILED with HTTP 503. Amazon's bot detection triggers
  on datacenter IPs regardless of user-agent"

Examples of BAD entries (too vague to be useful):
- "Tried fixing the table issue" (what exactly? what happened?)
- "Didn't work" (why not?)
- "Had some errors" (what errors?)

**Even if nothing failed, include this section** with: "No failed approaches this session."

### 3e. Decisions made

Bulleted list of architectural choices, trade-offs, and design decisions with reasoning:

- **Decision:** "Use streaming instead of polling for job progress"
  **Reason:** "Polling at 2s intervals misses rapid updates; SSE gives real-time progress"

- **Decision:** "Mark Amazon URLs as known-flaky in test fixtures"
  **Reason:** "Bot detection is an Amazon problem, not our code problem. Testing it
  wastes time and makes pass rates misleading"

Future sessions should NOT re-litigate these decisions unless explicitly told to.

### 3f. Remaining work

NUMBERED list of concrete next steps, in PRIORITY order:

1. Fix the table.rs panic for nested tables (supermarkdown)
2. Run /test-fix --only-failed to verify previous fixes
3. Add error mapping for scrape_timeout in reader-api
4. Set up CI pipeline for reader-api

Each item should be specific enough that a new session can start working immediately
without asking "what do you mean by this?"

### 3g. Notes

Anything that doesn't fit above but a future session needs to know:
- Environment quirks ("MongoDB must be started with --replSet for transactions")
- Open questions ("Not sure if the proxy issue is in Hero or in our config")
- Blocked items ("Waiting for Nihal to review PR #42 before continuing")
- Gotchas ("Don't run tests without READER_API_KEY set, they hang instead of failing")

---

## Step 4: Write the Checkpoint File

### 4a. Generate filename

```bash
CONTEXT_DIR=$(ls -d *-context/ 2>/dev/null | head -1)
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
echo "TIMESTAMP: $TIMESTAMP"
echo "SESSIONS_DIR: ${CONTEXT_DIR}SESSIONS/"
ls "${CONTEXT_DIR}SESSIONS/" 2>/dev/null
```

The filename is: `{TIMESTAMP}-{title-slug}.md`

Where title-slug is the title in kebab-case (lowercase, spaces to hyphens, remove
special characters). Example: `20260407-103045-investigating-table-rs-panic.md`

### 4b. Write the checkpoint

Write the file to `{CONTEXT_DIR}SESSIONS/{filename}` using this EXACT format:

```markdown
---
status: in-progress
timestamp: {ISO-8601, e.g., 2026-04-07T10:30:45Z}
project: {project name}
branches:
  reader: {branch}
  reader-api: {branch}
  reader-cloud-api: {branch}
  supermarkdown: {branch}
  {etc. for each repo with a .git directory}
files_modified:
  - {path/to/file1}
  - {path/to/file2}
  {list all dirty files across all repos}
---

## {Title}

### Summary
{3b: 1-3 sentences on what was being worked on}

### What Was Accomplished
{3c: Bulleted list with evidence}

### What Failed (DO NOT RETRY THESE)
{3d: For each failed approach:}
- **{approach}**: FAILED because {exact reason}
  Learned: {what we learned from the failure}

{If nothing failed:}
- No failed approaches this session.

### Decisions Made (DO NOT RE-LITIGATE)
{3e: For each decision:}
- **{decision}**: {reasoning}

{If no decisions:}
- No architectural decisions made this session.

### Remaining Work (Priority Order)
{3f: Numbered list}
1. {highest priority next step}
2. {next step}
...

### Notes
{3g: Environment quirks, open questions, blocked items, gotchas}
```

**The frontmatter is critical.** It enables /recall to filter by branch, check staleness,
and list modified files. Include ALL repos with their branches, not just the ones that
were modified.

**files_modified** comes from `git status --porcelain` across all repos. Use paths
relative to the workspace root: `reader-api/src/routes/read.ts`, not just `src/routes/read.ts`.

---

## Step 5: Update STATE.md

Read the current STATE.md and update it with information from this session:

```bash
CONTEXT_DIR=$(ls -d *-context/ 2>/dev/null | head -1)
cat "${CONTEXT_DIR}STATE.md"
```

**What to update in STATE.md:**
- "Last updated" timestamp -> now
- "Updated by" -> "checkpoint"
- Service status -> if you know (from running services during this session)
- E2E test results -> if tests were run this session
- Known Critical Issues -> add new issues, update resolved ones

**What NOT to update:**
- Don't change service status to UNKNOWN just because you didn't check it this session.
  Keep the previous known state. Only change if you have NEW information.

Write the updated STATE.md.

---

## Step 6: Update BACKLOG.md

Read the current BACKLOG.md:

```bash
CONTEXT_DIR=$(ls -d *-context/ 2>/dev/null | head -1)
cat "${CONTEXT_DIR}BACKLOG.md"
```

**Updates to make:**

1. **Issues RESOLVED this session:** Move from "Active Issues" to "Resolved Issues" with:
   - Date resolved
   - How it was fixed (commit reference)
   - "Resolved in session: {checkpoint title}"

2. **Issues INVESTIGATED but not fixed:** Update the "What we tried" section with the
   approaches tried this session and why they failed. This is the same content as the
   checkpoint's "What Failed" section, cross-referenced.

3. **NEW issues discovered this session:** Add to "Active Issues" with:
   - Severity
   - Repo
   - What happens
   - "Discovered in session: {checkpoint title}"

4. **Issues whose severity changed:** If investigation revealed an issue is more or less
   critical than previously thought, update the severity.

---

## Step 7: Wiki Contribution

This is where the knowledge base compounds. After EVERY session, check each category:

### 7a. Bug articles

**For each bug investigated this session** (whether fixed or not):

```bash
CONTEXT_DIR=$(ls -d *-context/ 2>/dev/null | head -1)
echo "=== EXISTING BUG ARTICLES ==="
ls "${CONTEXT_DIR}wiki/bugs/" 2>/dev/null || echo "No bug articles directory"
```

Check if a wiki/bugs/ article already exists for this bug:
- **If it exists:** Read it, then APPEND your findings to the Investigation History section.
  Update the Status if it changed (Open -> Resolved). Update Root Cause if you found it.
- **If it doesn't exist:** Create one using this format:

```markdown
# {Bug Title}

**Status:** {Open/Investigating/Resolved}
**Severity:** {Critical/High/Medium/Low}
**Repo:** {affected repo}
**Discovered:** {date}
**Resolved:** {date, if resolved}

## Symptoms
{What the user/system observes. Be specific: error messages, HTTP codes, behavior.}

## Affected Areas
- Files: {list specific files}
- Endpoints: {list affected API endpoints if applicable}
- URLs: {list specific URLs that trigger it if applicable}

## Investigation History

### {date} -- {session title}
{What was investigated, what was tried, what was found.}
{Include: hypothesis tested, evidence found, approach outcome.}

### {earlier date} -- {earlier session title}
{Prior investigation notes, if any}

## Root Cause
{If known: the actual cause with file:line reference.}
{If unknown: current best hypothesis with confidence level.}

## Fix
{If resolved: what was changed. Commit reference. Files modified.}
{If not resolved: "Not yet fixed."}

## Related
- BACKLOG: {link to backlog entry}
- Learnings: {relevant learning keys}
- Other bugs: {related bug articles}
```

### 7b. Architecture articles

Did you learn something about how the system works during this session?

- Discovered a dependency between services not previously documented?
- Found out how a particular code path works?
- Understood an error propagation chain?

**If yes:** Check if the relevant architecture article exists. Update it or create it.

### 7c. Decision articles

Did architectural decisions get made this session?

- Chose one approach over another?
- Decided on a technology or pattern?
- Made a trade-off?

**If yes:** Create `wiki/decisions/{slug}.md`:

```markdown
# {Decision Title}

**Date:** {date}
**Session:** {checkpoint title}
**Status:** Accepted

## Context
{What problem were we solving? What constraints existed?}

## Decision
{What was decided, specifically.}

## Reasoning
{Why this approach over alternatives.}

## Alternatives Considered
- {Alternative 1}: {why rejected}
- {Alternative 2}: {why rejected}

## Consequences
{What this decision means for future work.}
```

### 7d. Pattern articles

Did you notice a recurring pattern across the codebase?

- Same type of error appearing in multiple places?
- A code pattern that works well and should be replicated?
- An anti-pattern that caused the bug?

**If yes:** Create or update `wiki/patterns/{slug}.md`.

### 7e. Update INDEX.md

**If ANY wiki articles were created or updated** in steps 7a-7d:

```bash
CONTEXT_DIR=$(ls -d *-context/ 2>/dev/null | head -1)
echo "=== ALL WIKI ARTICLES ==="
find "${CONTEXT_DIR}wiki/" -name "*.md" -type f 2>/dev/null | sort
```

Read the current INDEX.md. Update it:
- Add entries for new articles with a one-line summary
- Update summaries for changed articles
- Update the "Last compiled" timestamp
- Update the article and word count

**Ensure INDEX.md is accurate:** Every article on disk must be listed. Every listed
article must exist on disk. No orphans in either direction.

---

## Step 8: Learning Capture

Reflect on the session. For EACH genuine discovery, append to LEARNINGS.jsonl:

```bash
CONTEXT_DIR=$(ls -d *-context/ 2>/dev/null | head -1)
echo '{"ts":"'$(date -u +%Y-%m-%dT%H:%M:%SZ)'","skill":"checkpoint","type":"TYPE","key":"SHORT_KEY","insight":"DESCRIPTION","confidence":N,"source":"SOURCE","files":["path"]}' >> "${CONTEXT_DIR}LEARNINGS.jsonl"
```

**What counts as a genuine discovery** (log these):
- "reader-api /ready checks both MongoDB AND engine health" (operational, confidence 9)
- "supermarkdown table.rs uses recursive descent that overflows at depth >5" (architecture, confidence 8)
- "running vitest with --reporter=verbose shows individual test names" (tool, confidence 10)
- "Amazon bot detection triggers on datacenter IPs regardless of user-agent" (pitfall, confidence 8)

**What does NOT count** (do not log these):
- "MongoDB was running" (obvious, not a learning)
- "Tests passed" (a fact, not a learning)
- "Used grep to find the file" (routine, not insightful)

**Types:** pattern, pitfall, preference, architecture, tool, operational
**Sources:** observed (you saw it), user-stated (user told you), inferred (you deduced it)
**Confidence:** 1-10 (8-9 verified, 4-6 inferred, 10 user-stated)

---

## Step 9: Timeline Logging

```bash
CONTEXT_DIR=$(ls -d *-context/ 2>/dev/null | head -1)
echo '{"skill":"checkpoint","event":"completed","ts":"'$(date -u +%Y-%m-%dT%H:%M:%SZ)'","outcome":"success","checkpoint":"SESSIONS/FILENAME","wiki_updates":N,"learnings_added":M}' >> "${CONTEXT_DIR}timeline.jsonl"
```

Replace FILENAME with the actual checkpoint filename, N with wiki articles created/updated,
M with learnings added.

---

## Step 10: Git Commit Context Repo

Commit ALL changes to the context repo:

```bash
CONTEXT_DIR=$(ls -d *-context/ 2>/dev/null | head -1)
cd "$CONTEXT_DIR"
git add -A
CHANGES=$(git diff --cached --stat | tail -1)
git commit -m "checkpoint: {title} ($(date +%Y-%m-%d))

$CHANGES

Session: {brief summary of what was done}
Wiki: {N articles created/updated}
Learnings: {M entries added}"
cd ..
```

**The commit message matters.** It should be descriptive enough that `git log --oneline`
in the context repo shows a meaningful history of sessions:

```
a1b2c3d checkpoint: investigating table-rs panic (2026-04-07)
d4e5f6g checkpoint: e2e test suite setup (2026-04-06)
h7i8j9k checkpoint: initial wiki compilation (2026-04-05)
```

---

## Step 11: Confirm to User

Present the checkpoint confirmation in this EXACT format:

```
CHECKPOINT SAVED
════════════════════════════════════════════════════════════════

Title:       {title}
File:        {full path to checkpoint file}
Timestamp:   {ISO timestamp}

Branches:
  {repo}: {branch}
  ...

Modified Files: {total count across all repos}
  {top 5 files, or "all clean" if none}

Context Updates:
  STATE.md:    {updated/unchanged}
  BACKLOG.md:  {N issues added, M updated, K resolved / unchanged}
  Wiki:        {N articles created, M updated / no changes}
  Learnings:   {N entries added / none}
  Committed:   {git commit hash}

════════════════════════════════════════════════════════════════

Next session: Run /recall to load this context.
```

---

## Critical Rules

1. **NEVER modify source code.** Only modify files in the context directory.

2. **The "What Failed" section is MANDATORY and must be DETAILED.** Vague failure
   descriptions are useless. "Tried X, didn't work" is a waste. "Tried X, failed because
   Y with error Z, which means W" is useful. This is the #1 most valuable section.

3. **Checkpoint files are APPEND-ONLY.** Never overwrite or delete existing checkpoints.
   Each /checkpoint creates a NEW file. The history of checkpoints is valuable.

4. **ALWAYS git commit the context repo.** A checkpoint that isn't committed can be lost.

5. **ALWAYS update STATE.md.** Even if the only change is the timestamp.

6. **ALWAYS check for wiki contributions.** Every session teaches something. If the wiki
   isn't getting richer after each checkpoint, you're not capturing enough.

7. **Infer, don't interrogate.** Use git state, conversation history, and test results
   to fill in the checkpoint. Only ask the user for the title if you genuinely cannot
   infer it from the session's work.

8. **Compare with the previous checkpoint.** If there was a previous checkpoint on the
   same branch, your "What Was Accomplished" section should show PROGRESS from the
   previous one's "Remaining Work."

---

## Completion Status

- **DONE** -- Checkpoint saved, context updated, wiki contributed, committed.
- **DONE_WITH_CONCERNS** -- Saved but: some sections are thin (e.g., couldn't determine
  what failed because session was very short), or wiki updates were skipped because the
  wiki doesn't exist yet (suggest /compile-wiki).
- **BLOCKED** -- No context directory. Forge not set up.
