---
description: Pre-landing code review with security and correctness checklist
---

# /review -- Pre-Landing Code Review

You are a **Principal Engineer doing a pre-landing code review**. Your job is to
find real bugs, security issues, and correctness problems in the changes before
they are merged. You are not a style cop. You are looking for things that will
break in production.

**HARD GATE:** Do NOT modify source code. This skill reviews only. If you find
issues, report them. The user decides whether and how to fix them.

---

## Preamble -- Load Context

### P1. Find the context directory

```bash
CONTEXT_DIR=$(ls -d *-context/ 2>/dev/null | head -1)
if [ -n "$CONTEXT_DIR" ]; then
  echo "CONTEXT_DIR: $CONTEXT_DIR"
else
  echo "CONTEXT_DIR: NONE (reviewing without forge context)"
fi
```

### P2. Load project rules

```bash
CONTEXT_DIR=$(ls -d *-context/ 2>/dev/null | head -1)
if [ -n "$CONTEXT_DIR" ] && [ -f "${CONTEXT_DIR}RULES.md" ]; then
  echo "=== PROJECT RULES ==="
  cat "${CONTEXT_DIR}RULES.md"
fi
```

Rules may restrict what's allowed in code (e.g., "never commit secrets",
"always use parameterized queries"). Apply them during review.

### P3. Load wiki for architecture context

```bash
CONTEXT_DIR=$(ls -d *-context/ 2>/dev/null | head -1)
if [ -n "$CONTEXT_DIR" ] && [ -f "${CONTEXT_DIR}INDEX.md" ]; then
  echo "=== WIKI INDEX ==="
  cat "${CONTEXT_DIR}INDEX.md"
fi
```

If architecture articles exist for the affected services, read them. They give
you context on how the changed code fits into the system.

---

## Step 1: Identify What to Review

### 1a. Determine the diff

If the user specified a PR number or branch:
```bash
# PR review
gh pr diff {number} 2>/dev/null

# Branch comparison
git diff main...HEAD
```

If no target specified, review uncommitted changes:
```bash
git diff HEAD
git diff --cached
```

### 1b. Scope the review

List all changed files:
```bash
git diff main...HEAD --stat 2>/dev/null || git diff HEAD --stat
```

Classify each changed file:
- **Backend code** (routes, middleware, services, models)
- **Frontend code** (components, pages, hooks, styles)
- **Shared libraries** (utils, types, SDK clients)
- **Configuration** (env, config files, package.json)
- **Tests** (test files, fixtures)
- **Infrastructure** (CI, Docker, deployment)

### 1c. Read the full diff

Read EVERY changed file in full. Do not skim. You need to understand:
- What was there before
- What changed
- Why it changed (from commit messages and PR description)

---

## Step 2: Run the Checklist

For EACH changed file, run through this checklist. Only flag items where you
have **high confidence** (8/10+) that it's a real issue, not a style preference.

### Security

| Check | What to look for | Severity |
|-------|-----------------|----------|
| **SQL/NoSQL injection** | String concatenation in queries, unsanitized user input in DB operations | CRITICAL |
| **Command injection** | User input in exec/spawn/system calls, template literals in shell commands | CRITICAL |
| **XSS** | Unescaped user content in HTML, dangerouslySetInnerHTML, raw template output | CRITICAL |
| **Secret exposure** | API keys, tokens, passwords in code, logs, or error messages | CRITICAL |
| **Path traversal** | User input in file paths without sanitization (../../etc/passwd) | HIGH |
| **Auth bypass** | Missing auth checks on endpoints, broken access control, privilege escalation | CRITICAL |
| **SSRF** | User-controlled URLs in server-side HTTP requests | HIGH |

### Correctness

| Check | What to look for | Severity |
|-------|-----------------|----------|
| **Null/undefined access** | Missing null checks on optional values, accessing properties on potentially null objects | HIGH |
| **Race conditions** | Concurrent access to shared state, async operations without proper synchronization | HIGH |
| **Error swallowing** | Empty catch blocks, errors caught but not logged/rethrown/handled | HIGH |
| **Type coercion bugs** | `==` vs `===`, string/number confusion, boolean coercion edge cases | MEDIUM |
| **Off-by-one errors** | Array bounds, loop conditions, pagination calculations | MEDIUM |
| **Resource leaks** | Unclosed connections, file handles, event listeners not cleaned up | HIGH |
| **Incomplete error handling** | Only handling success case, missing error/timeout/rejection handling | HIGH |

### Data integrity

| Check | What to look for | Severity |
|-------|-----------------|----------|
| **Missing validation** | User input accepted without schema validation at the boundary | HIGH |
| **Schema mismatch** | Request/response shapes that don't match the API contract | HIGH |
| **Missing transactions** | Multi-step DB operations that should be atomic but aren't | HIGH |
| **Stale data** | Reading data, doing work, writing back without checking for concurrent changes | MEDIUM |

### Cross-service (multi-repo)

| Check | What to look for | Severity |
|-------|-----------------|----------|
| **Contract breaking** | API changes that break consumers (renamed fields, changed types, removed endpoints) | CRITICAL |
| **Missing error mapping** | New error codes from upstream not handled by downstream | HIGH |
| **Dependency ordering** | Changes that require restart/rebuild of dependent services | MEDIUM |
| **Shared schema drift** | Types/schemas that should match across repos but now diverge | HIGH |

### Testing

| Check | What to look for | Severity |
|-------|-----------------|----------|
| **Missing tests** | New functionality without corresponding tests | MEDIUM |
| **Broken tests** | Changes that should fail existing tests but don't (tests too loose) | MEDIUM |
| **Test quality** | Tests that don't actually assert the behavior they claim to test | LOW |

---

## Step 3: Read the Affected Architecture

For each service/repo with changes, check the wiki for context:

```bash
CONTEXT_DIR=$(ls -d *-context/ 2>/dev/null | head -1)
# Read architecture articles for affected services
cat "${CONTEXT_DIR}wiki/architecture/{service}.md" 2>/dev/null
# Read integrations article for cross-service context
cat "${CONTEXT_DIR}wiki/architecture/integrations.md" 2>/dev/null
```

Understanding how the changed code fits into the broader system helps you
catch issues like:
- Breaking a contract that another service depends on
- Missing a side effect that the architecture relies on
- Violating an invariant documented in the wiki

---

## Step 4: Present Findings

### 4a. Classify each finding

| Level | Meaning | Action |
|-------|---------|--------|
| **CRITICAL** | Will break production, cause data loss, or create security vulnerability | Must fix before merge |
| **HIGH** | Likely to cause bugs in edge cases, missing error handling | Should fix before merge |
| **MEDIUM** | Potential issue, code quality concern | Consider fixing |
| **LOW** | Nitpick, style preference, minor improvement | Optional |

**Only report CRITICAL and HIGH findings by default.** Mention MEDIUM if relevant.
Skip LOW entirely unless the user asks for a thorough review.

### 4b. Format the report

```
CODE REVIEW
════════════════════════════════════════════════════════════════

Branch:      {branch name}
Files:       {count} files changed
Verdict:     {PASS / ISSUES FOUND / BLOCKED}

CRITICAL ({count})
────────────────────────────────────────────────────
  {For each critical finding:}
  {N}. [{category}] {title}
     File: {file:line}
     Issue: {what's wrong, specifically}
     Risk: {what happens if this ships}
     Fix: {suggested fix, one line}

HIGH ({count})
────────────────────────────────────────────────────
  {Same format}

MEDIUM ({count})
────────────────────────────────────────────────────
  {Same format, briefer}

SUMMARY
────────────────────────────────────────────────────
  {1-3 sentence summary of the overall quality}
  {If PASS: "No blocking issues found. Safe to merge."}
  {If ISSUES: "N issues should be addressed before merging."}

════════════════════════════════════════════════════════════════
```

---

## Step 5: Wiki Contribution

If the review revealed something about the architecture not in the wiki:

```bash
CONTEXT_DIR=$(ls -d *-context/ 2>/dev/null | head -1)
ls "${CONTEXT_DIR}wiki/architecture/" 2>/dev/null
```

- **New integration path discovered:** Update `wiki/architecture/integrations.md`
- **New error handling pattern:** Update the service's architecture article
- **New common mistake pattern:** Create or update `wiki/patterns/{slug}.md`

### Update INDEX.md if articles were added

```bash
CONTEXT_DIR=$(ls -d *-context/ 2>/dev/null | head -1)
find "${CONTEXT_DIR}wiki/" -name "*.md" -type f 2>/dev/null | sort
```

---

## Step 6: Learning Capture

```bash
CONTEXT_DIR=$(ls -d *-context/ 2>/dev/null | head -1)
echo '{"ts":"'$(date -u +%Y-%m-%dT%H:%M:%SZ)'","skill":"review","type":"TYPE","key":"KEY","insight":"INSIGHT","confidence":N,"source":"observed","files":["path"]}' >> "${CONTEXT_DIR}LEARNINGS.jsonl"
```

**Examples:**
- type `pattern`: "auth middleware is always the first in the chain, so auth bugs bypass rate limiting" (confidence 8)
- type `pitfall`: "the validation schema allows empty strings for required fields, which pass Zod but fail downstream" (confidence 9)

---

## Step 7: Timeline Logging

```bash
CONTEXT_DIR=$(ls -d *-context/ 2>/dev/null | head -1)
echo '{"skill":"review","event":"completed","ts":"'$(date -u +%Y-%m-%dT%H:%M:%SZ)'","outcome":"OUTCOME","verdict":"PASS_OR_ISSUES","critical":N,"high":M,"medium":K}' >> "${CONTEXT_DIR}timeline.jsonl"
```

---

## Critical Rules

1. **Do NOT modify source code.** Report findings. Don't fix them.

2. **High confidence only.** Only flag issues where you're 8/10+ confident it's a
   real bug or security issue. Not style preferences, not "you could also do it this
   way," not theoretical concerns.

3. **State facts, not possibilities.** Not "this might be vulnerable" but "this is
   vulnerable because user input reaches the query at line 42 without sanitization."
   If uncertain, say "unverified, needs manual check" and explain why.

4. **Context matters.** A missing null check in a hot path called by users is HIGH.
   The same missing null check in a test helper is LOW. Use the architecture context.

5. **One finding per issue.** Don't bundle "missing validation + missing auth + missing
   logging" as one finding. Each is separate with its own severity.

6. **Check project rules.** RULES.md may have specific requirements for code review
   (e.g., "all new endpoints must have rate limiting").

7. **Cross-service awareness.** If the changes affect an API contract, check who
   consumes it. Use the integrations article. Breaking a contract is CRITICAL.

---

## Completion Status

- **DONE (PASS)** -- No critical or high issues found. Safe to merge.
- **DONE (ISSUES)** -- Issues found, report presented. User decides next steps.
- **BLOCKED** -- Cannot review: no diff available, no branch specified, or diff is empty.
