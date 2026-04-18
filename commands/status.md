---
description: Check health of all services, repos, and tests across the workspace
---

# /status -- Workspace Health Dashboard

You are a **Staff SRE running the morning health check**. Your job is to check every
service, every repo, every test suite, and every known issue across the entire workspace.
Present a clear dashboard so the user knows exactly what's healthy, what's broken, and
what needs attention. Then update the knowledge base with your findings.

**HARD GATE:** Do NOT modify source code. Do NOT fix issues. This skill diagnoses only.
You MAY update the knowledge base (wiki, STATE.md, timeline, learnings) because those
are diagnostic artifacts, not source code.

---

## Preamble -- Load Context

### P1. Find the context directory

Every forge workspace has a `{project}-context/` directory. Find it:

```bash
CONTEXT_DIR=$(ls -d *-context/ 2>/dev/null | head -1)
if [ -n "$CONTEXT_DIR" ]; then
  echo "CONTEXT_DIR: $CONTEXT_DIR"
else
  echo "CONTEXT_DIR: NONE"
fi
```

**If CONTEXT_DIR is NONE:** Tell the user: "No forge context directory found. Run
`./forge/setup` to initialize forge in this workspace." Then STOP. Do not proceed.
Report status as BLOCKED.

### P2. Read the knowledge base index

This tells you what articles exist and where to find deep information:

```bash
CONTEXT_DIR=$(ls -d *-context/ 2>/dev/null | head -1)
echo "=== KNOWLEDGE BASE INDEX ==="
cat "${CONTEXT_DIR}INDEX.md" 2>/dev/null || echo "NO INDEX (run /compile-wiki to build)"
```

Scan the index. Note which architecture articles exist (you may need them to understand
what services should be running). Note which bug articles exist (you'll cross-reference
with your findings).

### P3. Read current known state

This is what we knew LAST TIME. Your job is to verify if it's still accurate:

```bash
CONTEXT_DIR=$(ls -d *-context/ 2>/dev/null | head -1)
echo "=== LAST KNOWN STATE ==="
cat "${CONTEXT_DIR}STATE.md" 2>/dev/null || echo "NO STATE FILE"
```

Read STATE.md carefully. Note:
- Which services were UP last time?
- Which were DOWN?
- What was the last e2e test pass rate?
- When was state last updated?

### P4. Read known issues

These are the issues we already know about. Your health check should verify if they're
still active, resolved, or if new issues appeared:

```bash
CONTEXT_DIR=$(ls -d *-context/ 2>/dev/null | head -1)
echo "=== KNOWN ISSUES ==="
cat "${CONTEXT_DIR}BACKLOG.md" 2>/dev/null || echo "NO BACKLOG"
```

Count the active issues. Note their severities.

### P5. Read recent learnings

These may contain operational knowledge relevant to the health check (e.g., "MongoDB
requires brew services start" or "worker needs --pool-size 3"):

```bash
CONTEXT_DIR=$(ls -d *-context/ 2>/dev/null | head -1)
echo "=== RECENT LEARNINGS ==="
tail -20 "${CONTEXT_DIR}LEARNINGS.jsonl" 2>/dev/null || echo "NO LEARNINGS"
```

If learnings mention operational quirks (env vars, startup order, common failures),
keep them in mind during the health check.

### P6. Read recent timeline

What skills have been run recently? When was the last checkpoint?

```bash
CONTEXT_DIR=$(ls -d *-context/ 2>/dev/null | head -1)
echo "=== RECENT ACTIVITY ==="
tail -10 "${CONTEXT_DIR}timeline.jsonl" 2>/dev/null || echo "NO TIMELINE"
```

### P7. Synthesize preamble context

Before proceeding, synthesize a one-paragraph summary:

"Last known state from {date}: {N} services tracked, {M} up, {K} issues known.
Last activity: {most recent timeline entry}. Knowledge base has {X} articles."

This grounds you in the current context before running checks.

---

## Step 1: Check All Running Services

### 1a. Read CLAUDE.md for service configuration

```bash
echo "=== SERVICE CONFIG FROM CLAUDE.md ==="
cat CLAUDE.md 2>/dev/null | grep -A 2 "localhost\|:60\|port\|Port" || echo "No service config in CLAUDE.md"
```

Parse CLAUDE.md to find which services exist and what ports they run on.
If CLAUDE.md has an Architecture section, use it to build the service list.
If not, fall back to checking common ports.

### 1b. Hit every health endpoint

For EACH service identified in CLAUDE.md, check its health endpoint:

```bash
echo "=== SERVICE HEALTH CHECKS ==="
echo ""

# For each service from CLAUDE.md, run:
check_service() {
  local name=$1
  local url=$2

  echo "--- ${name} ---"
  RESPONSE=$(curl -sf "$url" 2>/dev/null)
  if [ $? -eq 0 ]; then
    echo "  Health: UP"
    echo "  Response: $RESPONSE"
  else
    echo "  Health: DOWN"
  fi
  echo ""
}

# Example: check_service "Backend API (8001)" "http://localhost:8001/health"
# Run for every service listed in CLAUDE.md's Architecture section
```

Also check shared dependencies (databases, caches, queues):

```bash
# Check database connectivity (adapt to your database)
# MongoDB: mongosh --eval "db.runCommand({ping:1})" --quiet
# PostgreSQL: pg_isready -h localhost -p 5432
# Redis: redis-cli ping
```

### 1c. Classify each service

For each service, classify its status:

| Status | Meaning |
|--------|---------|
| **UP** | Health endpoint returned 200 |
| **DEGRADED** | Health returns 200 but ready returns non-200 (dependencies unhealthy) |
| **DOWN** | Health endpoint unreachable |
| **UNKNOWN** | Not checked (port not configured) |

**If a service was UP last time but is DOWN now:** Flag this prominently. This is a
regression that the user needs to know about.

**If a service was DOWN last time and is still DOWN:** Note it but don't alarm. It's
a known state.

**If a service was DOWN last time and is UP now:** Good news. Note the improvement.

---

## Step 2: Check Git Status Across All Repos

For every directory in the workspace that has a `.git` directory:

```bash
echo "=== GIT STATUS ACROSS REPOS ==="
echo ""
for dir in */; do
  if [ -d "$dir/.git" ]; then
    echo "--- ${dir%/} ---"
    BRANCH=$(cd "$dir" && git branch --show-current 2>/dev/null || echo "detached/unknown")
    DIRTY_COUNT=$(cd "$dir" && git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
    STAGED_COUNT=$(cd "$dir" && git diff --cached --name-only 2>/dev/null | wc -l | tr -d ' ')
    LAST_COMMIT=$(cd "$dir" && git log --oneline -1 --date=short --format="%h %s (%ad)" 2>/dev/null || echo "no commits")
    UNPUSHED=$(cd "$dir" && git log @{u}..HEAD --oneline 2>/dev/null | wc -l | tr -d ' ')

    echo "  Branch:     $BRANCH"
    echo "  Dirty:      $DIRTY_COUNT files"
    echo "  Staged:     $STAGED_COUNT files"
    echo "  Unpushed:   $UNPUSHED commits"
    echo "  Last commit: $LAST_COMMIT"

    # If dirty, list the modified files
    if [ "$DIRTY_COUNT" -gt 0 ]; then
      echo "  Modified files:"
      cd "$dir" && git status --porcelain 2>/dev/null | head -10 | sed 's/^/    /'
      if [ "$DIRTY_COUNT" -gt 10 ]; then
        echo "    ... and $((DIRTY_COUNT - 10)) more"
      fi
      cd ..
    fi
    echo ""
  fi
done
```

### 2b. Flag concerns

- **Dirty repos on main branch:** Flag as concern. Uncommitted changes on main risk being lost.
- **Repos with unpushed commits:** Flag as reminder. Work not backed up.
- **Repos on feature branches:** Note the branch name. Could be in-progress work.
- **Repos with >20 dirty files:** Flag as concern. That's a lot of uncommitted work.

---

## Step 3: Check Test Results

### 3a. Test results

Check for recent test results. Look for:
- JSON result files (e.g., `tests/results/latest.json`)
- JUnit XML reports
- Coverage reports
- Test output logs in the context directory

```bash
echo "=== TEST RESULTS ==="
# Check for test result files across repos
find . -maxdepth 4 \( -name "latest.json" -o -name "*.junit.xml" -o -name "test-results*" \) \
  -not -path "*/node_modules/*" 2>/dev/null | head -10

# Check for recent vitest/jest/cargo test output
for dir in */; do
  [ -d "$dir/coverage" ] && echo "  ${dir}: coverage report exists"
done
```

If structured results exist, parse them for pass/fail counts and top failures.
If no results exist, note it: "No test results found. Run tests via CLAUDE.md commands."

### 3b. Per-repo test status

For each repo in the workspace, detect the test framework:

```bash
echo ""
echo "=== PER-REPO TEST STATUS ==="
for dir in */; do
  if [ -d "$dir" ] && [ "$dir" != "forge/" ] && [[ ! "$dir" == *-context/ ]]; then
    echo "--- ${dir%/} ---"
    [ -f "$dir/vitest.config.ts" ] || [ -f "$dir/vitest.config.js" ] && echo "  Framework: vitest"
    [ -f "$dir/jest.config.ts" ] || [ -f "$dir/jest.config.js" ] && echo "  Framework: jest"
    [ -f "$dir/Cargo.toml" ] && echo "  Framework: cargo test"
    [ -f "$dir/pytest.ini" ] || [ -f "$dir/pyproject.toml" ] && echo "  Framework: pytest"
    [ -d "$dir/coverage" ] && echo "  Coverage report: exists"
    echo ""
  fi
done
```

**Note:** /status does NOT run tests. It checks if results exist and how fresh they are.
Running tests is the job of /test-fix.

### 3c. Compare with previous state

If STATE.md has previous test results, compare:
- Did pass rate improve or decline?
- Are there new failures not in the previous run?
- Are there fixes (previously failing URLs now passing)?

---

## Step 4: Cross-Reference with Backlog

For each known issue in BACKLOG.md:

1. **Check if the affected service is running.** If the issue says "worker panics on
   malformed input" but the worker is DOWN, note: "Cannot verify -- service is down."

2. **Check if any test failures correspond to backlog items.** If BACKLOG says "external
   API returns 403" and the test results show the same failures, they're the same issue.

3. **Check for NEW issues.** If the health check found problems not in the backlog, these
   are new issues that should be flagged prominently.

4. **Check for RESOLVED issues.** If a backlog item was failing but the latest test run
   shows it passing, it might be resolved. Flag as "possibly resolved -- verify with
   /investigate before removing from backlog."

---

## Step 5: Present the Dashboard

Compile ALL findings into a structured dashboard. This is the primary output of /status.
Follow this EXACT format:

```
WORKSPACE HEALTH DASHBOARD
════════════════════════════════════════════════════════════════

Project:     {from context directory name}
Timestamp:   {current ISO timestamp}
Last check:  {timestamp from STATE.md, or "first check"}

SERVICES
────────────────────────────────────────────────────
  {service name}  ({port})  ██ UP       {response summary}
  {service name}  ({port})  ██ UP       {response summary}
  {service name}  ({port})  ░░ DOWN     --
  {database}             ██ UP       ping ok

  Summary: {N}/{total} services healthy

REPOS
────────────────────────────────────────────────────
  {repo-name}      {branch}  {clean/N dirty}  {hash} "{commit msg}" ({date})
  {repo-name}      {branch}  {clean/N dirty}  {hash} "{commit msg}" ({date})

  Concerns: {list any dirty repos on main, unpushed commits, etc.}

E2E TESTS
────────────────────────────────────────────────────
  Last run:      {timestamp or "never"}
  Pass rate:     {pass}/{total} ({percent}%)
  Failures:      {fail count} fail, {crash count} crash, {partial count} partial
  Avg response:  {ms}ms (P95: {ms}ms)

  Top failures:
    1. {url} [{status}] -- {error or quality issues}
    2. ...
    (max 5)

KNOWN ISSUES ({count} active)
────────────────────────────────────────────────────
  [CRITICAL] {title} -- {one-line status}
  [HIGH]     {title} -- {one-line status}
  [MEDIUM]   {title} -- {one-line status}

NEW FINDINGS (not in backlog)
────────────────────────────────────────────────────
  {list any new issues discovered during this health check}
  {or "None -- all findings match known issues"}

POSSIBLY RESOLVED
────────────────────────────────────────────────────
  {list any backlog items that may be fixed based on test results}
  {or "None"}

CHANGES SINCE LAST CHECK
────────────────────────────────────────────────────
  {list what changed: services that went up/down, test rate changes, new issues}
  {or "First check -- no comparison available"}

════════════════════════════════════════════════════════════════
```

Use the box-drawing characters (═, ─, ║) for visual structure. Use ██ for UP/healthy
and ░░ for DOWN/unhealthy to make the dashboard scannable.

**If services are down that were up before:** Add a prominent warning at the top:

```
⚠ REGRESSION: {service} was UP at last check but is now DOWN
```

---

## Step 6: Update STATE.md

Now that you have fresh data, update STATE.md. Read the existing file first, then
rewrite it with current information:

```bash
CONTEXT_DIR=$(ls -d *-context/ 2>/dev/null | head -1)
echo "=== CURRENT STATE.md ==="
cat "${CONTEXT_DIR}STATE.md"
```

Write the updated STATE.md. Preserve any information you don't have updated data for
(e.g., if you didn't run tests, keep the previous test results). Always update:

- The "Last updated" timestamp
- The "Updated by" field (set to "status")
- Service health status for every service you checked
- E2E test results if you read the latest.json
- Known Critical Issues list (add new findings, mark possibly resolved)

**Format for STATE.md:**

```markdown
# {Project} Platform State

Last updated: {ISO timestamp}
Updated by: status

## Services

| Service | Status | Port | Branch | Notes |
|---------|--------|------|--------|-------|
| {name} | UP | {port} | {branch} | {notes} |
| {name} | DOWN | {port} | {branch} | {notes} |
| ... | ... | ... | ... | ... |

## Test Results (last run: {timestamp})
- Total: {N} tests
- Pass: {N} ({percent}%)
- Fail: {N}

## Known Critical Issues
1. [{severity}] {title} -- {status}
2. ...
```

---

## Step 7: Wiki Contribution

After completing the health check, evaluate whether the knowledge base needs updates:

### 7a. Check for new architecture knowledge

Did you discover services or ports not documented in the wiki? For example:
- A service running on a port not mentioned in wiki/architecture/overview.md
- A dependency relationship not documented (e.g., API depends on MongoDB being healthy)

**If yes:** Check if `wiki/architecture/overview.md` exists:

```bash
CONTEXT_DIR=$(ls -d *-context/ 2>/dev/null | head -1)
ls "${CONTEXT_DIR}wiki/architecture/" 2>/dev/null || echo "No architecture articles"
```

If the article exists, read it and check if it needs updating. If it's stale or missing
information you now have, update it.

If no architecture articles exist and this is a first health check, create a basic
`wiki/architecture/overview.md` with the service topology you discovered.

### 7b. Check for new bug discoveries

Did the health check reveal issues not in the backlog or wiki/bugs/?

```bash
CONTEXT_DIR=$(ls -d *-context/ 2>/dev/null | head -1)
echo "=== EXISTING BUG ARTICLES ==="
ls "${CONTEXT_DIR}wiki/bugs/" 2>/dev/null || echo "No bug articles"
```

**If you found a new issue** (service down unexpectedly, test regression, etc.):

1. Add it to BACKLOG.md under "Active Issues" with severity, repo, symptoms
2. Create a bug article at `wiki/bugs/{slug}.md` with:
   - Status: Open
   - Severity
   - Symptoms (what you observed during the health check)
   - Affected Areas
   - Investigation History: "Discovered during /status health check on {date}"
3. Update INDEX.md to include the new bug article

### 7c. Check for resolved issues

If the health check shows a previously failing test now passes, or a service that was
listed as problematic is now healthy:

1. Do NOT automatically remove from backlog. Flag as "Possibly resolved -- verify with
   /investigate before removing."
2. If a wiki/bugs/ article exists for it, add a note: "Health check on {date} shows
   this may be resolved. Needs verification."

### 7d. Update INDEX.md if articles were added/changed

If you created or updated ANY wiki articles in steps 7a-7c:

```bash
CONTEXT_DIR=$(ls -d *-context/ 2>/dev/null | head -1)
echo "=== CURRENT INDEX ==="
cat "${CONTEXT_DIR}INDEX.md"
```

Read the current INDEX.md. Add entries for new articles. Update summaries for changed
articles. Ensure every article file in wiki/ is listed, and every listed article exists.

### 7e. Stale content detection

While reading wiki articles during steps 7a-7d, check for stale content:

- Does any architecture article reference files that no longer exist?
- Does any bug article reference a resolved issue still marked as open?
- Does the INDEX.md list articles that don't exist on disk?

If you find stale content, fix it now. Don't leave it for /compile-wiki.

---

## Step 8: Learning Capture

Reflect on what you discovered during this health check:

- Did you find an operational quirk? (e.g., "database must be started before the API")
- Did a service fail in an unexpected way? (e.g., "service returns 500 instead of proper health response")
- Did you discover a dependency not documented? (e.g., "API /ready checks both database and worker health")
- Would any of this save time in a future session?

**If yes, append to LEARNINGS.jsonl.** Use this exact format:

```bash
CONTEXT_DIR=$(ls -d *-context/ 2>/dev/null | head -1)
echo '{"ts":"'$(date -u +%Y-%m-%dT%H:%M:%SZ)'","skill":"status","type":"operational","key":"SHORT_DESCRIPTIVE_KEY","insight":"ONE_LINE_DESCRIPTION_OF_WHAT_YOU_LEARNED","confidence":N,"source":"observed","files":["path/to/relevant/file"]}' >> "${CONTEXT_DIR}LEARNINGS.jsonl"
```

**Types for /status learnings:**
- `operational` -- startup order, env vars, port conflicts, service dependencies
- `architecture` -- discovered dependency relationships, service topology insights
- `pitfall` -- common failure modes, misleading error messages

**Confidence scale:**
- 9-10: You verified this directly (service responded, test ran)
- 7-8: You inferred this from strong evidence (error messages, config files)
- 4-6: You suspect this but haven't fully verified

**Only log genuine discoveries.** Don't log "MongoDB was running" -- that's not a learning.
DO log "API /ready endpoint checks both database and worker health, so if the worker
is down, API reports not ready even though it's running" -- that's useful operational
knowledge.

---

## Step 9: Timeline Logging

Log the completion of this health check:

```bash
CONTEXT_DIR=$(ls -d *-context/ 2>/dev/null | head -1)
echo '{"skill":"status","event":"completed","ts":"'$(date -u +%Y-%m-%dT%H:%M:%SZ)'","outcome":"success","services_up":N,"services_down":M,"test_pass_rate":"X/Y","new_issues":K,"wiki_updates":W}' >> "${CONTEXT_DIR}timeline.jsonl"
```

Replace:
- `N` with the number of services that are UP
- `M` with the number of services that are DOWN
- `X/Y` with the e2e test pass rate (or "unknown" if no results)
- `K` with the number of new issues found (not in backlog before)
- `W` with the number of wiki articles created or updated (0 if none)

**If the outcome was not success** (e.g., context directory not found, all services down):
- Set outcome to "error" or "blocked" as appropriate
- Still log the event -- the timeline should record all attempts

---

## Step 10: Git Commit Context Changes

If you modified ANY files in the context directory (STATE.md, BACKLOG.md, wiki articles,
LEARNINGS.jsonl, INDEX.md):

```bash
CONTEXT_DIR=$(ls -d *-context/ 2>/dev/null | head -1)
cd "$CONTEXT_DIR"
git add -A
CHANGES=$(git status --porcelain | wc -l | tr -d ' ')
if [ "$CHANGES" -gt 0 ]; then
  git commit -m "status: health check $(date +%Y-%m-%d) -- N/M services up, X/Y tests passing"
  echo "Context committed: $CHANGES files changed"
else
  echo "No context changes to commit"
fi
cd ..
```

Replace the commit message summary with actual numbers.

---

## Critical Rules

1. **Read-only on source code.** Never modify files in repos.
   Only modify files in the context directory.

2. **Show the full dashboard.** Even if everything is healthy, show the complete table.
   The user needs the full picture, not just "everything's fine."

3. **Flag changes since last check.** The delta between this check and the previous one
   (from STATE.md) is the most important information. What improved? What regressed?

4. **Always update STATE.md.** Even if nothing changed, update the timestamp so future
   sessions know how fresh the state data is.

5. **Cross-reference with backlog.** Don't just report what's down. Connect it to known
   issues. "Cloud API is down" is less useful than "Cloud API is down -- this is the
   same issue as BACKLOG #3 (pool pre-warming)."

6. **Create wiki articles for genuine discoveries.** If the health check reveals
   something about the architecture or a new bug, document it. The wiki should get
   richer after every /status run, not just after /compile-wiki.

7. **Be honest about unknowns.** If you can't check something (e.g., no test results
   to read), say "UNKNOWN" not "OK." Missing data is not the same as healthy.

8. **Log to timeline even on failure.** If /status itself fails (can't find context dir,
   all services down), log it. The timeline should show every attempt.

---

## Completion Status

Report one of:
- **DONE** -- All checks completed, dashboard presented, STATE.md updated, context committed.
- **DONE_WITH_CONCERNS** -- Checks completed but issues found: services down, tests failing,
  or new bugs discovered. The dashboard details what's wrong.
- **BLOCKED** -- Cannot run health check. Reasons: no context directory, no CLAUDE.md,
  workspace is not a forge workspace.

## Escalation

If ALL services are down AND there are no test results AND the context directory exists
but has never been populated:

```
STATUS: NEEDS_CONTEXT
REASON: Workspace appears uninitialized. Services not running, no test data.
ATTEMPTED: Health check on all configured ports
RECOMMENDATION: Start the services (see RUNNING-THE-STACK.md), then run /status again.
  If this is a new workspace, run /compile-wiki first to build the knowledge base.
```
