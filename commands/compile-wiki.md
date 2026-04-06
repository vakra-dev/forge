# /compile-wiki -- Build and Refresh the Knowledge Base

You are the knowledge base compiler. Your job is to read the codebase, existing documentation, and raw source material, then compile structured wiki articles that any future session can use to understand the project deeply.

This is the Karpathy "LLM Knowledge Base" pattern: raw data -> compiled wiki -> index -> compounding knowledge.

---

## Preamble -- Load Context

```bash
CONTEXT_DIR=$(ls -d *-context/ 2>/dev/null | head -1)
echo "CONTEXT: ${CONTEXT_DIR:-NONE}"
```

If no context directory found, stop.

Read existing INDEX.md to understand what's already documented:

```bash
cat "${CONTEXT_DIR}INDEX.md" 2>/dev/null || echo "NO INDEX -- starting fresh"
```

Read existing wiki articles to avoid rewriting what's already good:

```bash
echo "=== EXISTING WIKI ==="
find "${CONTEXT_DIR}wiki/" -name "*.md" -type f 2>/dev/null | sort
```

---

## Step 1: Survey the codebase

Understand what repos exist and what they contain:

```bash
echo "=== REPOS ==="
for dir in */; do
  if [ -d "$dir/.git" ] || [ -f "$dir/package.json" ] || [ -f "$dir/Cargo.toml" ]; then
    echo "--- ${dir%/} ---"
    # Key config files
    ls "$dir"package.json "$dir"Cargo.toml "$dir"tsconfig.json "$dir"mint.json 2>/dev/null
    # Source structure
    ls -d "$dir"src/ "$dir"test/ "$dir"tests/ 2>/dev/null
    echo ""
  fi
done
```

For each repo found, read the key structural files:
- `package.json` (dependencies, scripts)
- `src/` directory listing (understand the code organization)
- Entry points (index.ts, main.ts, lib.rs, etc.)
- Route definitions (for API services)
- Config files
- Existing README.md or documentation

**Do NOT read every file.** Read entry points, route files, config, and type definitions. Follow imports only when needed to understand architecture.

---

## Step 2: Read existing documentation

Check for existing docs in the workspace:

```bash
echo "=== EXISTING DOCS ==="
# README files
find . -maxdepth 2 -name "README.md" -type f 2>/dev/null
# Doc directories
ls -d */docs/ */doc/ 2>/dev/null
# API specs
find . -maxdepth 3 -name "openapi.*" -o -name "swagger.*" 2>/dev/null
# Markdown guides
find . -maxdepth 1 -name "*.md" -type f 2>/dev/null
```

Read the CLAUDE.md if it exists -- it has the project-specific architecture and rules:

```bash
cat CLAUDE.md 2>/dev/null || echo "NO CLAUDE.MD"
```

Read any raw/ material in the context directory:

```bash
ls "${CONTEXT_DIR}raw/" 2>/dev/null || echo "No raw material"
```

---

## Step 3: Compile architecture articles

For each significant repo/service, write a wiki article in `wiki/architecture/`. Each article should cover:

- **What it is** -- one-paragraph summary
- **Key files** -- the 5-10 most important files with one-line descriptions
- **How it works** -- the main code flow, from entry point through processing to output
- **Configuration** -- env vars, config files, ports
- **Dependencies** -- what it depends on (other services, databases, external APIs)
- **Testing** -- how to run tests, what test infrastructure exists

**Format for architecture articles:**

```markdown
# {Service/Repo Name}

## Overview
{1-2 paragraphs: what this is, what problem it solves, how it fits in the system}

## Key Files
| File | Purpose |
|------|---------|
| `src/index.ts` | Entry point, server startup |
| `src/routes/read.ts` | Main scraping endpoint |
| ... | ... |

## How It Works
{Explain the main code flow. Use concrete file:function references.}

## Configuration
| Variable | Default | Description |
|----------|---------|-------------|
| `PORT` | 6002 | Server port |
| ... | ... | ... |

## Dependencies
- Depends on: {list services, databases}
- Depended on by: {list consumers}

## Testing
```bash
{exact command to run tests}
```
{count} test files, using {framework}.
```

Write one article per major service/repo. Save to `{CONTEXT_DIR}wiki/architecture/{slug}.md`.

---

## Step 4: Compile API reference articles

If the project has API endpoints (HTTP routes, CLI commands, SDK methods), document them:

- **Endpoints** -- every route with method, path, request body, response shape
- **Error codes** -- every error code with HTTP status, cause, and handling advice
- **Authentication** -- how auth works, key types, header format
- **Rate limiting** -- limits, headers, retry behavior

Save to `{CONTEXT_DIR}wiki/api/`.

---

## Step 5: Compile bug articles from BACKLOG.md

Read BACKLOG.md. For each active issue, if there isn't already a wiki/bugs/ article, create one:

```markdown
# {Bug Title}

**Status:** {Open/Investigating/Resolved}
**Severity:** {Critical/High/Medium/Low}
**Repo:** {affected repo}
**Discovered:** {date}

## Symptoms
{What the user/system observes}

## Affected Areas
{Files, endpoints, URLs}

## Investigation History
{What was tried, what was found -- chronological}

## Root Cause
{If known, the actual cause. If unknown, current best hypothesis.}

## Fix
{If resolved, what was changed. Include file:line references.}
```

Save to `{CONTEXT_DIR}wiki/bugs/{slug}.md`.

---

## Step 6: Build INDEX.md

After all articles are written, rebuild INDEX.md from scratch:

```markdown
# {Project} Knowledge Base

Master index of all wiki articles. Read this first to navigate.

## Architecture ({count} articles)
- [{title}]({path}) -- {one-line summary}
- ...

## API Reference ({count} articles)
- [{title}]({path}) -- {one-line summary}
- ...

## Bugs ({count} articles)
- [{title}]({path}) -- {one-line summary} [{status}]
- ...

## Decisions ({count} articles)
- [{title}]({path}) -- {one-line summary}
- ...

## Patterns ({count} articles)
- [{title}]({path}) -- {one-line summary}
- ...

---
Last compiled: {ISO timestamp}
Articles: {total count} | Est. words: ~{estimate}
```

---

## Step 7: Lint existing articles (if this is a refresh, not initial compile)

If wiki articles already existed before this run, check each one:

1. **Stale content:** Does the article reference files that no longer exist? Flag and fix.
2. **Inconsistencies:** Does BACKLOG.md say an issue is open but the bug article says resolved? Fix.
3. **Missing links:** Are there articles not listed in INDEX.md? Add them.
4. **Orphan entries:** Are there INDEX.md entries pointing to deleted articles? Remove them.
5. **Suggested new articles:** Based on recent git history and learnings, are there topics that should have articles but don't? List them.

Report any linting findings.

---

## Step 8: Git commit

```bash
cd "${CONTEXT_DIR}"
git add -A
git commit -m "wiki: compile knowledge base ($(date +%Y-%m-%d))"
cd ..
```

---

## Step 9: Log to timeline and capture learnings

```bash
echo '{"skill":"compile-wiki","event":"completed","ts":"'$(date -u +%Y-%m-%dT%H:%M:%SZ)'","outcome":"success","articles_written":N}' >> "${CONTEXT_DIR}timeline.jsonl"
```

If you discovered architectural insights, non-obvious patterns, or project quirks while reading the code, log them to LEARNINGS.jsonl.

---

## Step 10: Report

```
WIKI COMPILED
========================================
Articles written: {count new}
Articles updated: {count updated}
Articles unchanged: {count}
Linting issues: {count, or "none"}
Total articles: {count}
Estimated words: ~{estimate}

New articles:
  - wiki/architecture/{name}.md
  - wiki/api/{name}.md
  - ...

Linting findings:
  - {any stale/inconsistent/missing items}

Knowledge base is ready. Future sessions will read INDEX.md first.
========================================
```

---

## Critical Rules

- **Read before writing.** Check if an article already exists before creating it. Update rather than overwrite when possible.
- **Be concrete.** Name real files, real functions, real line numbers. Not "the auth module" but "reader-api/src/middleware/auth.ts:23, the apiKeyAuth function."
- **Keep articles focused.** One topic per article. If an article exceeds ~500 lines, split it.
- **INDEX.md must be accurate.** Every article listed must exist. Every existing article must be listed.
- **Do not document obvious things.** Document architecture, decisions, patterns, and bugs. Don't document "this is a JavaScript file."
- **Wiki is for knowledge, not code.** Don't copy-paste source code into wiki articles. Reference it with file:line.

---

## Completion

Report **DONE** with compilation summary. Or **DONE_WITH_CONCERNS** if linting found issues that need manual attention.
