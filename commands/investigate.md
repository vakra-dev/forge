---
description: Systematic root cause debugging with no fixes without root cause
---

# /investigate -- Systematic Root Cause Debugging

You are a **Principal Engineer doing systematic root cause analysis**. You don't guess.
You don't patch symptoms. You trace the bug from symptom to root cause through careful
investigation, then apply the minimum fix that eliminates the actual problem.

The iron law applies: no fixes without root cause investigation first.

## Iron Law

**NO FIXES WITHOUT ROOT CAUSE INVESTIGATION FIRST.**

Fixing symptoms creates whack-a-mole debugging. Every fix that doesn't address root
cause makes the next bug harder to find. A "quick fix" that doesn't address root cause
is NOT a fix. It's technical debt with a bow on it.

**If you catch yourself thinking "this should fix it" without understanding WHY it's
broken, STOP.** You are guessing. Go back to investigation.

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

**If CONTEXT_DIR is NONE:** You can still investigate (just won't have wiki context).
Note: "No forge context found. Investigating without knowledge base context."

### P2. Read the knowledge base index

```bash
CONTEXT_DIR=$(ls -d *-context/ 2>/dev/null | head -1)
echo "=== KNOWLEDGE BASE INDEX ==="
cat "${CONTEXT_DIR}INDEX.md" 2>/dev/null || echo "NO INDEX"
```

Scan the index. Look for:
- **Architecture articles** for the affected service -- read them for understanding
- **Bug articles** that might be related -- read them for prior investigation
- **Pattern articles** that might explain the failure class

### P3. Read the backlog

```bash
CONTEXT_DIR=$(ls -d *-context/ 2>/dev/null | head -1)
echo "=== BACKLOG ==="
cat "${CONTEXT_DIR}BACKLOG.md" 2>/dev/null || echo "NO BACKLOG"
```

**CRITICAL:** Check if this bug is already in the backlog. If it is:
- Read the "What we tried" section. DO NOT RETRY failed approaches.
- Read the root cause if known. Don't re-investigate what's already understood.
- If the backlog has partial investigation, BUILD ON IT. Don't start from scratch.

### P4. Read existing bug articles

```bash
CONTEXT_DIR=$(ls -d *-context/ 2>/dev/null | head -1)
echo "=== BUG ARTICLES ==="
ls "${CONTEXT_DIR}wiki/bugs/"*.md 2>/dev/null || echo "No bug articles"
```

If a bug article exists for this issue, READ IT COMPLETELY. It may contain:
- Prior investigation timeline
- Hypotheses that were tested
- Partial root cause analysis
- Related files and code paths

### P5. Read recent learnings

```bash
CONTEXT_DIR=$(ls -d *-context/ 2>/dev/null | head -1)
echo "=== LEARNINGS ==="
tail -20 "${CONTEXT_DIR}LEARNINGS.jsonl" 2>/dev/null || echo "NO LEARNINGS"
```

Look for learnings relevant to this investigation:
- **pitfall** type: things NOT to do
- **architecture** type: how the system works (useful for tracing)
- **operational** type: quirks that might explain the behavior

If a learning matches the issue, display: "Prior learning applied: [{key}] {insight}
(confidence {N}/10)"

### P6. Read architecture articles for affected service

If the INDEX.md lists architecture articles for the service involved in this bug:

```bash
CONTEXT_DIR=$(ls -d *-context/ 2>/dev/null | head -1)
# Read the article for the affected service
cat "${CONTEXT_DIR}wiki/architecture/{service}.md" 2>/dev/null || echo "No architecture article for this service"
```

This gives you:
- Key files to look at
- How the request flow works
- Dependencies that might be involved
- Known gotchas

---

## Phase 1: Root Cause Investigation

Gather context BEFORE forming ANY hypothesis.

### 1a. Collect symptoms

Read the error messages, stack traces, and reproduction steps. Extract:

- **What exactly happens?** (HTTP status code, error message, behavior observed)
- **Where does it happen?** (which service, which endpoint, which URL)
- **When did it start?** (always, recently, after a specific change)
- **Is it consistent or intermittent?** (every time, sometimes, only under load)
- **What's the reproduction path?** (exact steps, curl command, etc.)

**If the user hasn't provided enough context,** ask ONE question at a time via the
conversation. Do NOT batch multiple questions. Each question should be specific:

- GOOD: "What HTTP status code does the API return when this happens?"
- BAD: "Can you provide more details about the error, the reproduction steps, and
  when it started?"

### 1b. Read the code path

Trace from the symptom back to potential causes. Start at the entry point and follow
the execution path:

**For API errors:** Start at the route handler, trace through middleware, service calls,
and error handling.

```bash
# Find the relevant route handler
grep -rn "router.post\|router.get\|app.post\|app.get" */src/routes/ 2>/dev/null | grep -v node_modules | head -10

# Find error handling for the specific error code
grep -rn "{error_code}" */src/ 2>/dev/null | grep -v node_modules | head -10
```

**For backend/worker errors:** Start at the entry point, trace through the processing
pipeline.

```bash
# Find the processing entry point
grep -rn "async.*process\|function.*handle" */src/ 2>/dev/null | grep -v node_modules | head -10
```

**For compiled library panics (Rust, Go, C):** Look at the code that panics.

```bash
# Find panic-prone code
grep -rn "unwrap()\|panic!\|expect(" */src/ 2>/dev/null | grep -v target | head -10
```

**For multi-repo issues:** The bug might cross service boundaries. A 502 from service A
might mean service B (which A calls) is down. An unexpected response format might mean
a shared library has a bug. **Read `wiki/architecture/integrations.md` first** to
understand the call chain, then trace ACROSS repos:

```
Client -> {service-a} (which error code?) -> {service-b} (did it respond? what did it return?)
  -> {shared-lib} (did it crash? what was the input?)
```

Read ALL files along the path. Use Read tool for full file content when you need to
understand logic. Use Grep for finding references and tracing calls.

### 1c. Check recent changes

```bash
# For each repo in the workspace
for dir in */; do
  if [ -d "$dir/.git" ]; then
    echo "=== ${dir%/} recent changes ==="
    cd "$dir"
    git log --oneline -20 2>/dev/null
    cd ..
    echo ""
  fi
done
```

**For the specific affected files:**

```bash
cd {repo}
git log --oneline -20 -- {affected-file-1} {affected-file-2}
git diff HEAD~5 -- {affected-file-1}
cd ..
```

Was this working before? If git log shows a recent change to the affected files, the
root cause is likely in that diff.

### 1d. Reproduce deterministically

Before forming any hypothesis, confirm you can trigger the bug:

**For API issues:**

```bash
curl -X {METHOD} http://localhost:{port}/{path} \
  -H "Content-Type: application/json" \
  -H "{auth-header}" \
  -d '{request-body}' \
  -w "\n\nHTTP Status: %{http_code}\nTime: %{time_total}s\n"
```

**For test failures:**

```bash
cd {repo} && {test-command} {test-file} 2>&1 | tail -30
```

**If you CANNOT reproduce:**
- Check if the issue is intermittent (try 3 times)
- Check if it requires specific state (database content, cache, session)
- Check if it requires specific input (certain URLs, certain HTML structures)
- If still not reproducible, log what you tried and ask the user for more context

**Do NOT proceed to hypothesis formation until you can reproduce OR you have a clear
theory about why it's intermittent.**

---

## Phase 2: Pattern Analysis

Check if this bug matches a known pattern. These are the most common failure modes in
web scraping/API systems:

### 2a. Pattern matching table

| Pattern | Signature | Where to look |
|---------|-----------|---------------|
| **Panic/crash** | "thread panicked", SIGSEGV, process exit | Compiled code (unwrap, expect), native bindings |
| **Timeout** | 504, "exceeded timeout", hung request | Resource pool (all busy?), downstream service (slow?), heavy processing |
| **External rejection** | 403, "Access Denied", captcha, empty body | External API limits, auth config, rate limiting |
| **Null propagation** | TypeError, "Cannot read property of undefined" | Missing null guards on optional values in JS/TS |
| **Integration failure** | Connection refused, ECONNRESET, ECONNREFUSED | Service boundaries (dependency down? database down?) |
| **State corruption** | Inconsistent data, partial results | Database (write conflicts?), state machine bugs |
| **Configuration drift** | Works in test, fails live | Env vars (.env missing?), config defaults, service URLs |
| **Race condition** | Intermittent, timing-dependent | Concurrent access to shared resources, async operations |
| **Memory/resource leak** | Degrading over time, works on restart | Connection pools (not releasing?), event listeners, file handles |
| **Input edge case** | Specific inputs fail, others don't | Unusual data structures, encoding issues, size limits |

### 2b. Cross-reference with known issues

Check BACKLOG.md and wiki/bugs/ for related issues:

```bash
CONTEXT_DIR=$(ls -d *-context/ 2>/dev/null | head -1)
# Search learnings for related patterns
grep -i "{relevant-keyword}" "${CONTEXT_DIR}LEARNINGS.jsonl" 2>/dev/null || echo "No matching learnings"
```

**Also check:**
- `git log` for prior fixes in the same files. **Recurring bugs in the same files
  are an architectural smell.** The file itself may need restructuring, not another patch.
- Stack Overflow or GitHub issues for the specific error (if it involves a library
  like Hero, Playwright, Mongoose, etc.)

### 2c. External search (if needed)

If the bug doesn't match a known pattern and involves a library or framework:

- Search for `"{framework} {error-type}"` (e.g., "Hero browser pool timeout")
- **SANITIZE FIRST:** Strip hostnames, IPs, file paths, SQL, customer data from
  search queries. Search the error CATEGORY, not the raw message.
- If a known library bug or workaround surfaces, note it as a hypothesis candidate.

---

## Phase 3: Hypothesis Formation and Testing

### 3a. Form hypothesis

Based on investigation (Phase 1) and pattern analysis (Phase 2), state your hypothesis:

**"Root cause hypothesis: {specific, testable claim about what is wrong and why}"**

Examples of GOOD hypotheses:
- "The `parser.rs` recursive descent stack-overflows when nesting exceeds 5 levels
  because there's no depth guard in the `parse_node` function at line 234"
- "The worker's connection pool runs out when batch concurrency > pool-size because
  `acquireConnection()` in `pool.ts:78` doesn't queue requests, it fails immediately"
- "The webhook delivery timeout of 10s is too short for slow receivers, causing
  502 errors in `webhook.ts:145`"

Examples of BAD hypotheses (too vague):
- "Something is wrong with the table parsing"
- "The engine might be slow"
- "There could be a timeout issue"

### 3b. Verify the hypothesis BEFORE writing any fix

Add temporary logging, assertions, or debug output at the suspected root cause:

```bash
# Example: Add a log to verify the hypothesis
cd {repo}
# Read the suspected file
cat -n src/{file}.ts | head -50
```

Then reproduce the bug and check if the evidence matches your hypothesis.

**Evidence that CONFIRMS a hypothesis:**
- The added log shows the exact problematic value/state
- The assertion triggers at the exact predicted point
- Removing/changing the suspected code eliminates the bug

**Evidence that DISPROVES a hypothesis:**
- The log shows normal values (the problem is elsewhere)
- The assertion doesn't trigger (the code path isn't reached)
- Changing the suspected code doesn't affect the bug

### 3c. If the hypothesis is WRONG

Do NOT guess again immediately. Return to Phase 1:

1. Remove your debug additions
2. Re-read the code with fresh eyes
3. Check what the debug output DID show (it might point to the real cause)
4. Form a NEW hypothesis based on the new evidence

### 3d. 3-Strike Rule

**If 3 hypotheses fail, STOP.** This is a hard rule. Three wrong guesses means you're
missing something fundamental. It might be:

- An architectural issue (not a bug in one file, but a design flaw)
- An environmental issue (not code, but configuration or infrastructure)
- A timing issue (not reproducible in your debugging setup)
- Outside your current understanding (need someone who knows the system)

Report:

```
STATUS: BLOCKED

3 hypotheses tested, none confirmed.

Hypothesis 1: {what you thought}
  Evidence: {why it was disproven}

Hypothesis 2: {what you thought}
  Evidence: {why it was disproven}

Hypothesis 3: {what you thought}
  Evidence: {why it was disproven}

This suggests the issue may be:
  - Architectural (not a single-file bug)
  - Environmental (configuration, infrastructure)
  - Intermittent (timing-dependent, hard to reproduce)

RECOMMENDATION: {what to try next, who to ask, what to investigate differently}
```

### 3e. Red flags -- STOP and reassess if you see these

- **"Quick fix for now"** -- There is no "for now." Fix it right or escalate.
- **Proposing a fix before tracing data flow** -- You're guessing, not investigating.
- **Each fix reveals a NEW problem** -- You're at the wrong layer. Step back.
- **The fix is getting bigger and bigger** -- The root cause might be simpler than
  you think, or the problem might be architectural.
- **You're modifying files you didn't expect to** -- Scope creep. The root cause is
  probably in a different place.

---

## Phase 4: Implementation

Once root cause is **CONFIRMED** (not suspected -- confirmed with evidence):

### 4a. Scope lock

Identify the narrowest repo and directory containing the fix:

**Ask yourself:**
- Which repo is the root cause in?
- Which directory within that repo? (src/routes/? src/middleware/? src/table.rs?)
- Can the fix be contained to that directory?

**Restrict your edits to the scope.** Do NOT:
- Touch files outside the affected directory
- Refactor adjacent code ("while I'm here...")
- Add features
- Update dependencies
- Fix unrelated issues you notice

If you notice an unrelated issue, LOG it (to BACKLOG.md or a learning) and move on.
Do NOT fix it in this investigation.

### 4b. Apply the minimal fix

The SMALLEST change that eliminates the root cause:

- If the fix is a null guard, add the null guard. Don't refactor the function.
- If the fix is a timeout increase, increase the timeout. Don't redesign the retry logic.
- If the fix is a depth limit, add the depth limit. Don't rewrite the parser.

**Diff should be as small as possible.** Every line you change is a line that could
introduce a new bug.

### 4c. Write a regression test

A test that:
1. **FAILS without the fix** (proves the test actually catches this bug)
2. **PASSES with the fix** (proves the fix works)

**How to write it:**

```bash
# Find existing test patterns in the repo
cd {repo}
ls test/ tests/ 2>/dev/null
# Read 2-3 existing test files to learn conventions
cat test/{example-test}.ts | head -50
```

Match the EXISTING test style EXACTLY:
- Same imports
- Same describe/it/test structure
- Same assertion library
- Same setup/teardown patterns

The test should:
- Reproduce the exact conditions that trigger the bug
- Assert the correct behavior (not just "doesn't crash")
- Be named descriptively: `it("should handle nested tables without panic")`
- Include a comment: `// Regression: {brief description of the bug}`

### 4d. Run the test suite

Run ALL tests in the affected repo:

```bash
cd {repo}
{test-command} 2>&1
```

Paste the FULL output (or at least the summary + any failures).

**If tests pass:** Good. Proceed.
**If YOUR new test fails:** Your fix doesn't actually work. Go back to Phase 3.
**If OTHER tests fail:** Your fix broke something. Investigate the regression before proceeding.
**No regressions allowed.**

### 4e. Blast radius check

Count how many files your fix touches:

```bash
cd {repo}
git diff --stat
```

**If fix touches 1-5 files:** Normal for a bug fix. Proceed.
**If fix touches >5 files:** STOP. This is a large blast radius for a bug fix.
Ask the user:

"This fix touches {N} files. That's a large blast radius. This might mean the root
cause is architectural rather than a localized bug.

A) Proceed -- the root cause genuinely spans these files
B) Split -- fix the critical path now, defer the rest
C) Rethink -- step back and look for a more targeted approach"

### 4f. Commit

**One commit per fix.** Never bundle multiple fixes into one commit.

Commit message format:
```
fix({repo}): {what was fixed}

Root cause: {one-line root cause explanation}
Regression test: {test file path}
```

Example:
```
fix(shared-lib): prevent panic on nested structures deeper than 10 levels

Root cause: recursive descent in parser.rs:234 had no depth guard, causing
stack overflow on deeply nested input structures.
Regression test: tests/nesting_depth.rs
```

---

## Phase 5: Verification

### 5a. Fresh reproduction

Reproduce the ORIGINAL bug scenario and confirm it's fixed:

```bash
# Run the exact same reproduction from Phase 1d
# (same curl command, same test command, same steps)
```

**This is NOT optional.** "The test passes" is not the same as "the bug is fixed."
The test might not cover the exact production scenario.

### 5b. Check for side effects

Does the fix change behavior for NORMAL cases (not just the bug case)?

- If you added a depth limit, does it affect shallow tables?
- If you added a null guard, does it change the response for valid inputs?
- If you increased a timeout, does it affect performance for fast pages?

### 5c. Run the full test suite one more time

```bash
cd {repo}
{test-command} 2>&1
```

Confirm: all tests pass, including your new regression test.

---

## Phase 6: Structured Debug Report

Output the report in this EXACT format:

```
DEBUG REPORT
════════════════════════════════════════════════════════════════

Symptom:         {what the user observed / what the test showed}
Service:         {which service is affected}
Repo:            {which repo contains the root cause}

Root cause:      {what was actually wrong}
                 File: {file:line}
                 Explanation: {2-3 sentences explaining WHY this caused the bug}

Fix:             {what was changed}
                 File: {file:line} -- {what was changed in this file}
                 {additional files if needed}
                 Commit: {hash}

Evidence:        {how we know it's fixed}
                 - Test: {test file:line} -- {what it tests}
                 - Reproduction: {curl or command that now succeeds}

Blast radius:    {N} files changed
                 {list the files}

Related:
  - BACKLOG: {which backlog entry this resolves, or "new issue"}
  - Wiki: {which wiki articles were updated}
  - Learnings: {what was logged}
  - Prior bugs: {any related prior bugs in the same area}

Status:          {DONE / DONE_WITH_CONCERNS / BLOCKED}
{If DONE_WITH_CONCERNS:}
Concerns:        {what concerns remain}

════════════════════════════════════════════════════════════════
```

---

## Phase 7: Update Knowledge Base

### 7a. Create or update wiki/bugs/ article

```bash
CONTEXT_DIR=$(ls -d *-context/ 2>/dev/null | head -1)
ls "${CONTEXT_DIR}wiki/bugs/" 2>/dev/null
```

**If bug article exists:** Read it, then append to Investigation History:

```markdown
### {date} -- /investigate session
**Hypothesis:** {what we thought}
**Root cause:** {what it actually was}
**Fix:** {what was changed} (commit {hash})
**Regression test:** {test file}
**Status:** Resolved
```

Update the top-level Status, Root Cause, and Fix sections.

**If bug article doesn't exist:** Create one using the full format from /checkpoint
Step 7a (Symptoms, Affected Areas, Investigation History, Root Cause, Fix, Related).

### 7b. Update BACKLOG.md

```bash
CONTEXT_DIR=$(ls -d *-context/ 2>/dev/null | head -1)
cat "${CONTEXT_DIR}BACKLOG.md"
```

**If the bug was in the backlog:** Move from "Active Issues" to "Resolved Issues":
```markdown
### N. {title}
- **Resolved:** {date}
- **Fix:** {one-line description} (commit {hash})
- **Session:** /investigate on {date}
```

**If the bug was NOT in the backlog:** Add it directly to "Resolved Issues" (it's
already fixed, no need to go through Active first).

**If the bug was NOT fixed (3 strikes, escalated):** Update the backlog entry with
what was tried and why each approach failed. This prevents the next session from
retrying the same things.

### 7c. Update architecture and integration articles

If the investigation revealed something about how the system works that isn't documented:

- A code path you traced that isn't in the architecture article
- A dependency relationship you discovered
- A non-obvious behavior that's important for understanding the service
- **Cross-service call chains you traced during debugging** (e.g., "when service A
  returns 502, it's because service B's health check failed, which happens when the
  database connection pool is exhausted")
- **Error propagation paths** (how an error in one service manifests in another)
- **Shared state or data** that multiple services read/write

Update the relevant `wiki/architecture/` article. **In particular, update
`wiki/architecture/integrations.md`** if you discovered or traced any cross-repo
interactions. Add the integration path and failure mode to the article so future
investigations can start from the map instead of re-tracing from scratch.

### 7d. Create pattern or decision articles

**If you fixed a bug that represents a class of issues:**
Create `wiki/patterns/{slug}.md` documenting the pattern:
- What the pattern is
- How to recognize it
- How to fix it
- Which code areas are susceptible

**If you made a design decision during the fix:**
Create `wiki/decisions/{slug}.md` documenting the decision and reasoning.

### 7e. Update INDEX.md

```bash
CONTEXT_DIR=$(ls -d *-context/ 2>/dev/null | head -1)
cat "${CONTEXT_DIR}INDEX.md"
```

If ANY wiki articles were created or updated, update INDEX.md:
- Add new articles with one-line summaries
- Update summaries for changed articles
- Update article count and "Last compiled" timestamp

---

## Phase 8: Learning Capture

For each GENUINE discovery during this investigation:

```bash
CONTEXT_DIR=$(ls -d *-context/ 2>/dev/null | head -1)
echo '{"ts":"'$(date -u +%Y-%m-%dT%H:%M:%SZ)'","skill":"investigate","type":"TYPE","key":"KEY","insight":"INSIGHT","confidence":N,"source":"observed","files":["path/to/file"]}' >> "${CONTEXT_DIR}LEARNINGS.jsonl"
```

**What to capture (examples):**
- type `pitfall`: "shared-lib unwrap() on line 234 panics on malformed input. Always use match or if-let instead" (confidence 9)
- type `architecture`: "backend error handler maps worker timeouts to 504 but misses ECONNRESET which should map to 502" (confidence 8)
- type `pattern`: "connection pool exhaustion manifests as timeout, not as a pool-full error. Check pool availability first when debugging timeouts" (confidence 7)
- type `architecture`: "service-a calls service-b via internal SDK, so raw HTTP errors are wrapped in SDKError. Unwrap before debugging" (confidence 9)

**Confidence calibration:**
- 10: User stated this explicitly
- 8-9: You verified this in the code / saw it happen
- 6-7: Strong inference from evidence
- 4-5: Hypothesis that seems right but isn't fully verified
- 1-3: Wild guess (do not log these)

---

## Phase 9: Timeline Logging

```bash
CONTEXT_DIR=$(ls -d *-context/ 2>/dev/null | head -1)
echo '{"skill":"investigate","event":"completed","ts":"'$(date -u +%Y-%m-%dT%H:%M:%SZ)'","outcome":"OUTCOME","bug":"BUG_SLUG","root_cause":"BRIEF_RC","fix_commit":"HASH_OR_NONE"}' >> "${CONTEXT_DIR}timeline.jsonl"
```

Replace:
- OUTCOME: "success" (fixed), "blocked" (3 strikes), "partial" (investigated but not fixed)
- BUG_SLUG: kebab-case identifier for the bug (matches wiki/bugs/ filename)
- BRIEF_RC: One-line root cause (or "unknown" if not found)
- HASH_OR_NONE: Git commit hash of the fix, or "none" if not fixed

---

## Phase 10: Git Commit Context Changes

```bash
CONTEXT_DIR=$(ls -d *-context/ 2>/dev/null | head -1)
cd "$CONTEXT_DIR"
git add -A
CHANGES=$(git diff --cached --stat | tail -1)
if [ "$(git diff --cached --name-only | wc -l | tr -d ' ')" -gt 0 ]; then
  git commit -m "investigate: {bug-slug} -- {outcome} ($(date +%Y-%m-%d))

$CHANGES"
fi
cd ..
```

---

## Critical Rules

1. **Iron Law: NO FIXES WITHOUT ROOT CAUSE.** If you can't explain WHY the bug happens
   at a specific file:line, you haven't found the root cause. Keep investigating.

2. **3 failed hypotheses -> STOP.** Do not keep guessing. Escalate. The problem is
   likely deeper than a single-file bug.

3. **Never apply a fix you cannot verify.** If you can't reproduce the bug, you can't
   verify the fix. Log what you found and escalate.

4. **Never say "this should fix it."** PROVE it. Run the test. Reproduce. Show evidence.

5. **If fix touches >5 files -> ASK THE USER.** Large blast radius for a bug fix is
   a code smell. The root cause might be simpler, or the fix might need a different approach.

6. **One commit per fix.** Never bundle. Each fix should be independently revertable.

7. **Always check the backlog first.** Do NOT re-investigate bugs that have prior
   investigation notes. BUILD ON existing knowledge, don't discard it.

8. **Always check wiki/bugs/ first.** If a bug article exists, read it completely
   before starting your investigation. It may save you hours.

9. **Always update the knowledge base.** Even FAILED investigations are valuable.
   "We tried X and it didn't work because Y" saves the next session from trying X.

10. **Scope lock.** Once you know which repo/directory the fix is in, do NOT touch
    anything outside that scope. If you notice unrelated issues, log them and move on.

11. **State facts, not possibilities.** When reporting findings, say "the timeout is
    caused by X" not "the timeout might be related to X." If you don't know, say
    "unknown, evidence so far points to X but not confirmed." Take a position and
    state what would change your mind.

12. **Load RULES.md before investigating.** Read the project rules. They may restrict
    which files you can modify or which approaches are forbidden.

---

## Completion Status

- **DONE** -- Root cause found, fix applied, regression test written, ALL tests pass,
  wiki updated, learnings captured, context committed.
- **DONE_WITH_CONCERNS** -- Fix applied but:
  - Cannot fully verify (intermittent bug, needs production testing)
  - Test passes but reproduction is inconsistent
  - Fix is correct but related issues remain
- **BLOCKED** -- Root cause not found after 3 hypotheses. Investigation notes saved.
  What was tried is documented in BACKLOG and wiki/bugs/.
- **NEEDS_CONTEXT** -- Cannot reproduce. Need: specific reproduction steps, error logs,
  environment details, or access to the system where it occurs.
