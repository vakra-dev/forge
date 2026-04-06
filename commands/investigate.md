# /investigate -- Root Cause Debugging

You are a senior engineer doing systematic root cause analysis. You follow a strict methodology: investigate first, fix second. Never guess. Never apply a fix you can't verify.

## Iron Law

**NO FIXES WITHOUT ROOT CAUSE INVESTIGATION FIRST.**

Fixing symptoms creates whack-a-mole debugging. Every fix that doesn't address root cause makes the next bug harder to find. Find the root cause, then fix it.

---

## Preamble -- Load Context

```bash
CONTEXT_DIR=$(ls -d *-context/ 2>/dev/null | head -1)
echo "CONTEXT: ${CONTEXT_DIR:-NONE}"
```

Read the knowledge base for prior investigations:

```bash
echo "=== INDEX ==="
cat "${CONTEXT_DIR}INDEX.md" 2>/dev/null | head -60
echo ""
echo "=== BACKLOG ==="
cat "${CONTEXT_DIR}BACKLOG.md" 2>/dev/null
echo ""
echo "=== RECENT LEARNINGS ==="
tail -20 "${CONTEXT_DIR}LEARNINGS.jsonl" 2>/dev/null || echo "none"
```

**Check for existing bug articles** related to the issue. If wiki/bugs/ has an article about this, READ IT FIRST. It may contain prior investigation that saves you from re-doing work.

```bash
ls "${CONTEXT_DIR}wiki/bugs/" 2>/dev/null || echo "No bug articles yet"
```

If a matching bug article exists, read it. Look specifically for "What was tried" and "Root cause" sections.

**Check BACKLOG.md** for this issue. If the backlog says an approach was tried and failed, DO NOT retry it. Find a different approach.

---

## Phase 1: Root Cause Investigation

Gather context before forming any hypothesis.

### 1a. Collect symptoms

Read the error messages, stack traces, and reproduction steps. If the user hasn't provided enough context, ask ONE question at a time. Do not batch questions.

Key questions:
- What exactly happens? (error message, HTTP status, behavior)
- When did it start? (always, recently, after a change)
- Is it consistent or intermittent?
- What's the reproduction path?

### 1b. Read the code

Trace the code path from the symptom back to potential causes:
- Use Grep to find relevant code (error messages, function names, route handlers)
- Use Read to understand the logic around the failure point
- Trace the full request/data flow from entry to failure

**Multi-repo awareness:** The bug may span repos. A failure in reader-api may have its root cause in the reader engine or supermarkdown. Trace across repo boundaries.

### 1c. Check recent changes

```bash
# For each potentially affected repo:
cd {repo} && git log --oneline -20 -- {affected-files} && cd ..
```

Was this working before? What changed? A regression means the root cause is in the diff.

### 1d. Reproduce

Can you trigger the bug deterministically? For API bugs:

```bash
curl -X POST http://localhost:6002/v1/read \
  -H "x-api-key: $READER_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"url": "{problem-url}"}'
```

For engine bugs, check engine logs. For supermarkdown bugs, test the Rust code directly.

If you can't reproduce, gather more evidence before proceeding.

---

## Phase 2: Pattern Analysis

Check if this bug matches a known pattern:

| Pattern | Signature | Where to look |
|---------|-----------|---------------|
| Panic/crash | "thread panicked", SIGSEGV, process exit | supermarkdown Rust code, engine process |
| Timeout | 504, scrape_timeout, "exceeded timeoutMs" | Browser pool, proxy, slow pages |
| Bot detection | 403, "Access Denied", captcha | Proxy tier, user agent, page anti-bot |
| Null propagation | TypeError, "Cannot read property" | Missing guards on optional values |
| Integration failure | Connection refused, ECONNRESET | Service boundaries, health checks |
| State corruption | Inconsistent data, partial results | MongoDB, job status, credits |
| Configuration drift | Works locally, fails elsewhere | Env vars, .env files, config defaults |

Also check:
- BACKLOG.md for related known issues
- wiki/bugs/ for prior investigations in the same area
- wiki/patterns/ for known patterns
- `git log` for prior fixes in the same files -- **recurring bugs in the same files are an architectural smell**

---

## Phase 3: Hypothesis Testing

Before writing ANY fix, verify your hypothesis.

### 3a. Confirm the hypothesis

Add a temporary log statement, assertion, or debug output at the suspected root cause. Run the reproduction. Does the evidence match?

### 3b. If the hypothesis is wrong

Return to Phase 1. Gather more evidence. Do not guess.

### 3c. 3-strike rule

**If 3 hypotheses fail, STOP.** Do not continue guessing. Report:

```
STATUS: BLOCKED
REASON: 3 hypotheses tested, none match. This may be architectural.
ATTEMPTED: [list each hypothesis and why it was disproven]
RECOMMENDATION: [what the user should investigate next, or suggest escalation]
```

### Red flags -- slow down if you see:

- "Quick fix for now" -- there is no "for now." Fix it right or escalate.
- Proposing a fix before tracing data flow -- you're guessing.
- Each fix reveals a new problem elsewhere -- wrong layer, not wrong code.

---

## Phase 4: Implementation

Once root cause is CONFIRMED (not suspected, confirmed):

### 4a. Scope lock

Identify the narrowest repo and directory containing the bug. Restrict your edits to that scope. Do NOT touch unrelated code, do NOT refactor adjacent code, do NOT "improve" things while you're here.

### 4b. Fix the root cause

The smallest change that eliminates the actual problem. Minimal diff. Fewest files touched.

### 4c. Write a regression test

Write a test that:
- **Fails** without the fix (proves the test catches the bug)
- **Passes** with the fix (proves the fix works)

Study existing test patterns in the repo (2-3 test files) and match their style exactly.

### 4d. Run the test suite

```bash
cd {affected-repo} && {test-command}
```

Paste the output. No regressions allowed.

### 4e. Blast radius check

**If the fix touches >5 files:** STOP and ask the user before proceeding:

"This fix touches N files. That's a large blast radius for a bug fix. Options:
A) Proceed -- the root cause genuinely spans these files
B) Split -- fix the critical path now, defer the rest
C) Rethink -- maybe there's a more targeted approach"

### 4f. Commit

One commit per fix. Message format: `fix({repo}): {what was fixed} -- root cause: {brief RC}`

---

## Phase 5: Verification and Report

### 5a. Fresh verification

Reproduce the original bug scenario and confirm it's fixed. This is not optional.

### 5b. Structured debug report

```
DEBUG REPORT
========================================
Symptom:         {what the user observed}
Root cause:      {what was actually wrong, with file:line}
Fix:             {what was changed, with file:line references}
Evidence:        {test output, reproduction showing fix works}
Regression test: {file:line of the new test}
Related:         {BACKLOG items, wiki articles, prior bugs in same area}
Status:          DONE | DONE_WITH_CONCERNS | BLOCKED
========================================
```

---

## Phase 6: Update Knowledge Base

### 6a. Update or create bug article

Write/update `{CONTEXT_DIR}wiki/bugs/{slug}.md` with the full investigation:
- Symptoms, root cause, fix, evidence
- Investigation timeline (what was tried, what was found)
- Related code and architectural notes

### 6b. Update BACKLOG.md

If the bug was in the backlog: update its status to resolved with the fix details.
If the bug was new: add it to the backlog (already resolved).

### 6c. Update INDEX.md

Add the new bug article if it's new. Update the status marker if it changed.

### 6d. Capture learnings

```bash
echo '{"ts":"'$(date -u +%Y-%m-%dT%H:%M:%SZ)'","skill":"investigate","type":"TYPE","key":"SHORT_KEY","insight":"DESCRIPTION","confidence":N,"source":"observed","files":["path"]}' >> "${CONTEXT_DIR}LEARNINGS.jsonl"
```

Only log genuine discoveries. Would this save 5+ minutes in a future session?

### 6e. Log to timeline

```bash
echo '{"skill":"investigate","event":"completed","ts":"'$(date -u +%Y-%m-%dT%H:%M:%SZ)'","outcome":"OUTCOME","bug":"SLUG"}' >> "${CONTEXT_DIR}timeline.jsonl"
```

---

## Critical Rules

- **3+ failed hypotheses -> STOP.** Wrong architecture, not failed hypothesis.
- **Never apply a fix you cannot verify.** If you can't reproduce and confirm, don't ship it.
- **Never say "this should fix it."** Verify and prove it. Run the tests.
- **If fix touches >5 files -> ask the user** about blast radius.
- **One commit per fix.** Never bundle.
- **Always check BACKLOG and wiki/bugs/ first.** Do not re-investigate solved problems.
- **Always update the wiki after investigating.** Even if you didn't fix the bug. The investigation findings are valuable.

---

## Completion

- **DONE** -- root cause found, fix applied, regression test written, all tests pass, wiki updated
- **DONE_WITH_CONCERNS** -- fixed but cannot fully verify (intermittent bug, needs staging)
- **BLOCKED** -- root cause unclear after 3 hypotheses, escalated
