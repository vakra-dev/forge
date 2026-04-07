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
requires brew services start" or "reader engine needs --pool-size 3"):

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

For EACH service identified in CLAUDE.md (or common ports if no CLAUDE.md):

```bash
echo "=== SERVICE HEALTH CHECKS ==="
echo ""

# Check each known service
# For each service, check both /health and /ready if applicable
# Capture response body (not just status code) for richer diagnostics

echo "--- Reader Engine (6003) ---"
ENGINE_HEALTH=$(curl -sf http://localhost:6003/health 2>/dev/null)
ENGINE_CODE=$?
if [ $ENGINE_CODE -eq 0 ]; then
  echo "  Health: UP"
  echo "  Response: $ENGINE_HEALTH"
else
  echo "  Health: DOWN (curl exit code: $ENGINE_CODE)"
fi
echo ""

echo "--- Reader API (6002) ---"
API_HEALTH=$(curl -sf http://localhost:6002/health 2>/dev/null)
API_CODE=$?
if [ $API_CODE -eq 0 ]; then
  echo "  Health: UP"
  echo "  Response: $API_HEALTH"
else
  echo "  Health: DOWN (curl exit code: $API_CODE)"
fi
echo ""

echo "--- Reader API Readiness (6002) ---"
API_READY=$(curl -sf http://localhost:6002/ready 2>/dev/null)
READY_CODE=$?
if [ $READY_CODE -eq 0 ]; then
  echo "  Ready: YES"
  echo "  Response: $API_READY"
else
  echo "  Ready: NO (curl exit code: $READY_CODE)"
fi
echo ""

echo "--- Cloud API (6001) ---"
CLOUD_HEALTH=$(curl -sf http://localhost:6001/health 2>/dev/null)
CLOUD_CODE=$?
if [ $CLOUD_CODE -eq 0 ]; then
  echo "  Health: UP"
  echo "  Response: $CLOUD_HEALTH"
else
  echo "  Health: DOWN (curl exit code: $CLOUD_CODE)"
fi
echo ""

echo "--- Cloud App (6006) ---"
APP_STATUS=$(curl -sf -o /dev/null -w "%{http_code}" http://localhost:6006 2>/dev/null || echo "000")
if [ "$APP_STATUS" != "000" ]; then
  echo "  Health: UP (HTTP $APP_STATUS)"
else
  echo "  Health: DOWN"
fi
echo ""

echo "--- Docs (6005) ---"
DOCS_STATUS=$(curl -sf -o /dev/null -w "%{http_code}" http://localhost:6005 2>/dev/null || echo "000")
if [ "$DOCS_STATUS" != "000" ]; then
  echo "  Health: UP (HTTP $DOCS_STATUS)"
else
  echo "  Health: DOWN"
fi
echo ""

echo "--- MongoDB (27017) ---"
MONGO_PING=$(mongosh --eval "db.runCommand({ping:1})" --quiet 2>/dev/null | head -1)
if echo "$MONGO_PING" | grep -q "ok"; then
  echo "  Health: UP"
  echo "  Response: $MONGO_PING"
else
  echo "  Health: DOWN or not installed"
fi
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

### 3a. E2E test results

```bash
echo "=== E2E TEST RESULTS ==="
if [ -f tests/e2e/results/latest.json ]; then
  echo "File: tests/e2e/results/latest.json"
  node -e "
    const fs = require('fs');
    const r = JSON.parse(fs.readFileSync('tests/e2e/results/latest.json', 'utf8'));
    console.log('Timestamp:    ' + r.timestamp);
    console.log('Filter:       ' + (r.config.filter || 'all'));
    console.log('Total URLs:   ' + r.config.totalUrls);
    console.log('Pass:         ' + r.summary.pass);
    console.log('Partial:      ' + r.summary.partial);
    console.log('Fail:         ' + r.summary.fail);
    console.log('Crash:        ' + r.summary.crash);
    console.log('Flaky:        ' + (r.summary.flaky || 0));
    console.log('Avg response: ' + r.summary.avgResponseMs + 'ms');
    console.log('P95 response: ' + r.summary.p95ResponseMs + 'ms');
    console.log('Duration:     ' + (r.summary.totalDurationMs/1000).toFixed(1) + 's');

    // Show top failures
    var failures = r.results.filter(function(x) { return x.status === 'fail' || x.status === 'crash'; });
    if (failures.length > 0) {
      console.log('');
      console.log('Top failures:');
      failures.slice(0, 10).forEach(function(f) {
        console.log('  [' + f.status.toUpperCase() + '] ' + f.url);
        if (f.errorCode) console.log('    Error: ' + f.errorCode + ' - ' + (f.errorMessage || '').slice(0, 80));
        if (f.qualityIssues && f.qualityIssues.length > 0) console.log('    Issues: ' + f.qualityIssues.join(', '));
      });
      if (failures.length > 10) console.log('  ... and ' + (failures.length - 10) + ' more');
    }
  " 2>/dev/null || echo "  Could not parse e2e results JSON"
else
  echo "  No e2e results found at tests/e2e/results/latest.json"
  echo "  Run: READER_API_KEY=rdr_xxx npx tsx tests/e2e/run-scrape-suite.ts"
fi
```

### 3b. Unit test results (check if recently run)

For each repo with a test framework, check if tests have been run recently:

```bash
echo ""
echo "=== UNIT TEST STATUS ==="
for dir in reader reader-api reader-cloud-api supermarkdown; do
  if [ -d "$dir" ]; then
    echo "--- ${dir} ---"
    # Check for test config
    if [ -f "$dir/vitest.config.ts" ] || [ -f "$dir/vitest.config.js" ]; then
      echo "  Framework: vitest"
      echo "  Run: cd $dir && npx vitest run"
    elif [ -f "$dir/Cargo.toml" ]; then
      echo "  Framework: cargo test"
      echo "  Run: cd $dir && cargo test"
    else
      echo "  No test framework detected"
    fi
    # Check for recent test output
    if [ -d "$dir/node_modules/.vitest" ] || [ -d "$dir/coverage" ]; then
      echo "  Last run: exists (check timestamp)"
    fi
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

1. **Check if the affected service is running.** If the issue says "reader engine panics on
   nested tables" but the reader engine is DOWN, note: "Cannot verify -- service is down."

2. **Check if any test failures correspond to backlog items.** If BACKLOG says "Amazon pages
   return 403" and the e2e results show amazon.com failures, they're the same issue.

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

Project:     {from context directory name, e.g., "reader"}
Timestamp:   {current ISO timestamp}
Last check:  {timestamp from STATE.md, or "first check"}

SERVICES
────────────────────────────────────────────────────
  Reader Engine  (6003)  ██ UP       {response summary}
  Reader API     (6002)  ██ UP       {response summary}
  API Ready      (6002)  ██ YES      {dependency status}
  Cloud API      (6001)  ░░ DOWN     --
  Cloud App      (6006)  ░░ DOWN     --
  Docs           (6005)  ░░ DOWN     --
  MongoDB              ██ UP       ping ok

  Summary: {N}/{total} services healthy

REPOS
────────────────────────────────────────────────────
  reader           main     clean     abc1234 "fix: pool timeout" (2026-04-05)
  reader-api       main     3 dirty   def5678 "feat: batch retry" (2026-04-05)
  reader-cloud-api main     clean     ghi9012 "chore: update deps" (2026-04-04)
  supermarkdown    main     clean     jkl3456 "fix: table parsing" (2026-04-03)
  reader-sdks      main     clean     mno7890 "feat: stream support" (2026-04-02)

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

| Repo | Status | Port | Branch | Last Test | Notes |
|------|--------|------|--------|-----------|-------|
| reader (engine) | UP | 6003 | main | -- | Health OK |
| reader-api | UP | 6002 | main | -- | Health OK, ready OK |
| reader-cloud-api | DOWN | 6001 | main | -- | Not running |
| ... | ... | ... | ... | ... | ... |

## E2E Test Results (last run: {timestamp})
- Total: {N} URLs
- Pass: {N} ({percent}%)
- Fail: {N}
- Crash: {N}
- Partial: {N}
- Avg response: {N}ms

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

- Did you find an operational quirk? (e.g., "MongoDB must be started before reader-api")
- Did a service fail in an unexpected way? (e.g., "Cloud API returns 500 instead of proper health response")
- Did you discover a dependency not documented? (e.g., "reader-api /ready checks both MongoDB and engine")
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
DO log "reader-api /ready endpoint checks both MongoDB and engine health, so if engine
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

1. **Read-only on source code.** Never modify files in repos (reader, reader-api, etc.).
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
