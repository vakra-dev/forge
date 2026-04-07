# /compile-wiki -- Knowledge Base Compiler

You are a **Technical Writer and Knowledge Architect**. Your job is to read the entire
codebase, existing documentation, and raw source material, then compile a structured
wiki that any future session can use to understand the project deeply without re-reading
the source code.

This is the Karpathy "LLM Knowledge Base" compiler: raw data goes in, structured wiki
articles come out. The wiki is YOUR artifact -- you maintain it, you organize it, you
ensure it stays current. The user rarely touches it directly.

**HARD GATE:** Do NOT modify source code in any repo. You only write to the context
directory (wiki articles, INDEX.md, LEARNINGS.jsonl, timeline.jsonl).

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

**If CONTEXT_DIR is NONE:** STOP. Report as BLOCKED.

### P2. Check what already exists in the wiki

```bash
CONTEXT_DIR=$(ls -d *-context/ 2>/dev/null | head -1)
echo "=== EXISTING WIKI ==="
echo ""
echo "--- INDEX ---"
cat "${CONTEXT_DIR}INDEX.md" 2>/dev/null || echo "NO INDEX"
echo ""
echo "--- ARTICLES ---"
find "${CONTEXT_DIR}wiki/" -name "*.md" -type f 2>/dev/null | sort
echo ""
echo "--- ARTICLE COUNT ---"
EXISTING_COUNT=$(find "${CONTEXT_DIR}wiki/" -name "*.md" -type f 2>/dev/null | wc -l | tr -d ' ')
echo "Existing articles: $EXISTING_COUNT"
```

**If articles already exist:** This is a REFRESH, not an initial compile. Read each
existing article before rewriting -- preserve good content, update stale content,
add missing information. Don't destroy work from prior sessions.

**If no articles exist:** This is an INITIAL compile. Build everything from scratch.

### P3. Read existing backlog and learnings

```bash
CONTEXT_DIR=$(ls -d *-context/ 2>/dev/null | head -1)
echo "=== BACKLOG ==="
cat "${CONTEXT_DIR}BACKLOG.md" 2>/dev/null || echo "NO BACKLOG"
echo ""
echo "=== LEARNINGS ==="
tail -30 "${CONTEXT_DIR}LEARNINGS.jsonl" 2>/dev/null || echo "NO LEARNINGS"
```

Bugs from the backlog should become wiki/bugs/ articles.
Learnings should inform architecture and patterns articles.

---

## Phase 1: Survey the Workspace

### 1a. Discover all repos

```bash
echo "=== WORKSPACE SURVEY ==="
echo ""
for dir in */; do
  if [ -d "$dir/.git" ] || [ -f "$dir/package.json" ] || [ -f "$dir/Cargo.toml" ] || [ -f "$dir/mint.json" ]; then
    echo "═══ ${dir%/} ═══"

    # Language/runtime detection
    [ -f "$dir/package.json" ] && echo "  Runtime: Node.js"
    [ -f "$dir/Cargo.toml" ] && echo "  Runtime: Rust"
    [ -f "$dir/mint.json" ] && echo "  Runtime: Mintlify (docs)"

    # Framework detection
    [ -f "$dir/package.json" ] && grep -q '"express"' "$dir/package.json" 2>/dev/null && echo "  Framework: Express"
    [ -f "$dir/package.json" ] && grep -q '"react"' "$dir/package.json" 2>/dev/null && echo "  Framework: React"
    [ -f "$dir/package.json" ] && grep -q '"next"' "$dir/package.json" 2>/dev/null && echo "  Framework: Next.js"
    [ -f "$dir/package.json" ] && grep -q '"vite"' "$dir/package.json" 2>/dev/null && echo "  Framework: Vite"

    # Source structure
    echo "  Structure:"
    ls -d "$dir"src/ "$dir"test/ "$dir"tests/ "$dir"dist/ 2>/dev/null | sed 's/^/    /'

    # Entry points
    echo "  Entry points:"
    ls "$dir"src/index.ts "$dir"src/main.ts "$dir"src/lib.rs "$dir"src/cli/*.ts 2>/dev/null | sed 's/^/    /'

    # Key config
    echo "  Config:"
    ls "$dir"tsconfig.json "$dir"vitest.config.* "$dir"Cargo.toml "$dir".env* 2>/dev/null | sed 's/^/    /'

    echo ""
  fi
done
```

### 1b. Read CLAUDE.md for project context

```bash
echo "=== CLAUDE.md ==="
cat CLAUDE.md 2>/dev/null || echo "NO CLAUDE.MD"
```

CLAUDE.md is the richest source of architectural context. It contains:
- Service topology
- Port assignments
- Dependency chain
- Test commands
- Critical rules

Parse it carefully. This informs every architecture article you'll write.

### 1c. Read any existing documentation in the workspace

```bash
echo "=== EXISTING DOCS ==="
# README files
for dir in */; do
  [ -f "$dir/README.md" ] && echo "README: $dir/README.md"
done

# API specs
find . -maxdepth 3 -name "openapi.*" -o -name "swagger.*" 2>/dev/null

# Markdown guides in workspace root
ls *.md 2>/dev/null | grep -v CLAUDE.md

# Doc directories
for dir in */; do
  [ -d "${dir}docs" ] && echo "DOCS: ${dir}docs/"
done
```

Read ALL discovered documentation files. They contain valuable context that should be
distilled into wiki articles.

### 1d. Check for raw/ material

```bash
CONTEXT_DIR=$(ls -d *-context/ 2>/dev/null | head -1)
echo "=== RAW MATERIAL ==="
ls "${CONTEXT_DIR}raw/" 2>/dev/null || echo "No raw material"
```

If raw/ contains files (API docs, design docs, exported articles), read them and
incorporate into the wiki compilation.

---

## Phase 2: Deep Codebase Reading

For each significant repo discovered in Phase 1, read the KEY structural files.
Do NOT read every file. Read strategically:

### 2a. For API services (Express, Fastify, etc.)

Read these files in order:

1. **Entry point** (`src/index.ts` or `src/app.ts`):
   - How the server is configured
   - What middleware is applied
   - What routes are mounted

2. **Route definitions** (`src/routes/*.ts`):
   - Every endpoint: method, path, request body, response shape
   - Authentication requirements per route
   - Middleware chain per route

3. **Middleware** (`src/middleware/*.ts`):
   - Auth middleware: how API keys are validated
   - Rate limiting: how limits are enforced
   - Error handler: how errors are formatted

4. **Models** (`src/models/*.ts`):
   - Database schemas
   - Key fields and indexes

5. **Config** (`src/config.ts`):
   - Environment variables
   - Default values
   - Tier configurations

6. **Services** (`src/services/*.ts`):
   - Business logic
   - External service calls

7. **Types** (`src/types/*.ts` or embedded in files):
   - Request/response types
   - Error types

### 2b. For the scraping engine

Read:
1. CLI entry point (how it starts)
2. Engine/pool management (browser lifecycle)
3. Scraping pipeline (HTML -> extraction -> markdown)
4. Proxy/tier logic
5. Error handling

### 2c. For Rust crates (supermarkdown)

Read:
1. `Cargo.toml` (dependencies, features)
2. `src/lib.rs` (public API)
3. Key modules (`src/table.rs`, etc.)
4. NAPI bindings (how JS calls Rust)

### 2d. For frontend apps

Read:
1. `package.json` (dependencies, scripts)
2. Entry point (main component)
3. Route structure
4. API client (how it calls the backend)

### 2e. For SDKs

Read:
1. Package manifest
2. Client class (main API)
3. Types/interfaces
4. Error handling

### 2f. For documentation sites

Read:
1. `mint.json` or equivalent config
2. Navigation structure
3. Key concept pages
4. API reference pages

**For each file you read, note:**
- What it does (one sentence)
- Key functions/classes/exports
- Dependencies (what it imports from other files/packages)
- Non-obvious behavior (quirks, gotchas, edge cases)

---

## Phase 3: Compile Architecture Articles

For each significant repo/service, write a wiki article.

### 3a. Architecture overview

Create `wiki/architecture/overview.md`:

```markdown
# {Project} Architecture Overview

## Service Topology

{ASCII diagram showing how services connect, which ports they use, and which
databases they share. Use the format from CLAUDE.md if available.}

## Services

| Service | Repo | Port | Runtime | Purpose |
|---------|------|------|---------|---------|
| {name} | {repo} | {port} | {Node/Rust/React} | {one-line purpose} |
| ... | ... | ... | ... | ... |

## Dependency Chain

{Explain which services depend on which, in what order they should be started,
and what happens when a dependency is down.}

Changes flow downstream:
- {upstream change} -> {what needs to restart/rebuild}
- ...

## Shared Resources

- **MongoDB** ({connection string}): Used by {list services}. Database name: {name}.
- {Other shared resources}

## Key URLs

| URL | Service | Auth |
|-----|---------|------|
| http://localhost:{port}/health | {service} | None |
| http://localhost:{port}/v1/read | {service} | x-api-key |
| ... | ... | ... |
```

### 3b. Per-service articles

For EACH significant service, create `wiki/architecture/{service-slug}.md`:

```markdown
# {Service Name}

## Overview
{2-3 paragraphs: what this service does, how it fits in the system, what problem
it solves for users.}

## Key Files

| File | Purpose | Key exports |
|------|---------|-------------|
| `src/index.ts` | Server entry point | `app`, `startServer()` |
| `src/routes/read.ts` | Main scraping endpoint | `readRouter` |
| `src/middleware/auth.ts` | API key validation | `apiKeyAuth` |
| ... | ... | ... |

{List the 10-20 most important files. Not every file -- the ones a developer
needs to understand to work on this service.}

## How It Works

### Request Flow
{Trace a typical request from entry to response. Be specific:}

1. Request arrives at `POST /v1/read` (`src/routes/read.ts:42`)
2. Middleware chain runs: `apiKeyAuth` -> `rateLimitMiddleware` -> `creditsCheck` -> `idempotencyCheck`
3. Request body validated with Zod schema (`ReadRequestSchema`)
4. Mode detection: single URL -> sync scrape, array -> batch job, URL + maxDepth -> crawl
5. For sync scrape: calls `readerEngine.scrape(url, options)` (`src/services/reader-engine.ts:58`)
6. Engine returns `{markdown, html, metadata}` or throws
7. Response formatted via `sendSuccess()` (`src/utils/api-response.ts`)
8. Credits deducted, usage logged (fire-and-forget)

### Error Handling
{How errors are caught, formatted, and returned. Reference the error codes.}

### Background Jobs
{If the service has async jobs, explain the lifecycle: creation -> processing -> completion.}

## Configuration

| Variable | Default | Required | Description |
|----------|---------|----------|-------------|
| `PORT` | 6002 | No | Server port |
| `MONGODB_URI` | `mongodb://localhost:27017/reader-cloud` | Yes | Database connection |
| ... | ... | ... | ... |

## Data Models

{For each MongoDB model, list the key fields and what they're for. Not the full
schema -- the important fields.}

### {Model Name}
- `fieldName` ({type}): {what it's for}
- `fieldName` ({type}): {what it's for}
- Indexes: `{list indexes}`

## Dependencies

### Depends on:
- **MongoDB** -- {what it stores there}
- **Reader Engine** (localhost:6003) -- {what it calls it for}
- {other dependencies}

### Depended on by:
- **Reader Cloud API** -- {calls this service via SDK for scraping}
- **SDKs** -- {users call this directly}

## Testing

```bash
cd {repo} && {test command}
```

- Framework: {vitest/cargo test/etc.}
- Test count: {approximate}
- Test directory: `{path}`
- Key test helpers: `{list}`

## Gotchas

{Non-obvious things a developer needs to know:}
- {gotcha 1}
- {gotcha 2}
```

### 3c. Data flow article

Create `wiki/architecture/data-flow.md`:

```markdown
# Request Data Flow

## Single URL Scrape (Synchronous)

{Trace the complete lifecycle from SDK/curl to markdown response, across all
services involved. Include file:line references.}

1. **Client** sends `POST /v1/read {"url": "..."}`
2. **Reader API** (`reader-api/src/routes/read.ts:N`)
   - Validates request with Zod
   - Checks API key, rate limit, credits
   - Detects mode: single URL -> sync
   - Calls reader engine
3. **Reader Engine** (`reader/src/engine/...`)
   - Gets browser from pool
   - Navigates to URL
   - Waits for content
   - Extracts HTML
4. **Supermarkdown** (`supermarkdown/src/lib.rs`)
   - Receives HTML
   - Converts to markdown
   - Returns structured output
5. **Reader Engine** returns `{markdown, metadata}` to API
6. **Reader API** returns `{success: true, data: {...}}` to client

## Batch Scrape (Asynchronous)
{Same level of detail for batch mode}

## Crawl (Asynchronous)
{Same level of detail for crawl mode}
```

---

## Phase 4: Compile API Reference Articles

If the project has HTTP APIs, document them exhaustively.

### 4a. Endpoints article

Create `wiki/api/endpoints.md`:

```markdown
# API Endpoints

## Authentication
{How auth works: header name, key format, validation process}

## Endpoints

### POST /v1/read
{Purpose, request body (every field), response shape (every field), error codes}

### GET /v1/jobs/:id
{Same level of detail}

{Continue for EVERY endpoint}
```

**Be exhaustive.** Document every endpoint, every request field, every response field,
every error code, every query parameter. This article should be the definitive API
reference that a developer can use without reading the source code.

### 4b. Error codes article

Create `wiki/api/error-codes.md`:

```markdown
# Error Codes

| Code | HTTP Status | Cause | Handling |
|------|-------------|-------|----------|
| `invalid_request` | 400 | Zod validation failure | Fix request body |
| `unauthenticated` | 401 | Bad API key | Check x-api-key header |
| ... | ... | ... | ... |

## Details

### invalid_request (400)
{When it triggers, what the response looks like, how to fix it}

### unauthenticated (401)
{Same level of detail}

{Continue for EVERY error code}
```

### 4c. Additional API articles as needed

- `wiki/api/rate-limiting.md` if the API has rate limits
- `wiki/api/webhooks.md` if the API has webhooks
- `wiki/api/caching.md` if caching behavior is non-trivial

---

## Phase 5: Compile Bug Articles from Backlog

Read BACKLOG.md. For each active issue that doesn't already have a wiki/bugs/ article:

```bash
CONTEXT_DIR=$(ls -d *-context/ 2>/dev/null | head -1)
echo "=== BACKLOG ISSUES ==="
grep "^### " "${CONTEXT_DIR}BACKLOG.md" 2>/dev/null || echo "No issues"
echo ""
echo "=== EXISTING BUG ARTICLES ==="
ls "${CONTEXT_DIR}wiki/bugs/"*.md 2>/dev/null || echo "None"
```

Create a wiki/bugs/ article for each unmatched backlog issue. Use the format from
/checkpoint Step 7a (Symptoms, Affected Areas, Investigation History, Root Cause, Fix, Related).

---

## Phase 6: Build INDEX.md

After ALL articles are written, rebuild INDEX.md from scratch. Do NOT incrementally
update -- read the actual file system and build a fresh index:

```bash
CONTEXT_DIR=$(ls -d *-context/ 2>/dev/null | head -1)
echo "=== ALL WIKI ARTICLES ==="
find "${CONTEXT_DIR}wiki/" -name "*.md" -type f 2>/dev/null | sort
```

For each article, generate a one-line summary by reading the first few lines (the title
and overview paragraph).

Write INDEX.md using this EXACT format:

```markdown
# {Project} Knowledge Base

Master index of all wiki articles. Read this first to navigate the knowledge base.

## Architecture ({count} articles)
- [overview.md](wiki/architecture/overview.md) -- Service topology, ports, dependencies, shared resources
- [{service}.md](wiki/architecture/{service}.md) -- {one-line summary of what's documented}
- [data-flow.md](wiki/architecture/data-flow.md) -- Request lifecycle across all services
- ...

## API Reference ({count} articles)
- [endpoints.md](wiki/api/endpoints.md) -- All API endpoints with request/response shapes
- [error-codes.md](wiki/api/error-codes.md) -- Error codes with HTTP status and handling
- ...

## Bugs ({count} articles, {open} open / {resolved} resolved)
- [{title}](wiki/bugs/{slug}.md) -- {one-line summary} [{status}]
- ...

## Decisions ({count} articles)
- [{title}](wiki/decisions/{slug}.md) -- {one-line summary}
- ...

## Patterns ({count} articles)
- [{title}](wiki/patterns/{slug}.md) -- {one-line summary}
- ...

---
Last compiled: {ISO timestamp}
Articles: {total count} | Est. words: ~{rough estimate}K
```

**The one-line summaries are critical.** They're how the LLM decides which article to
read during /investigate or /test-fix. Make them specific enough to be useful:
- GOOD: "Reader API middleware chain, auth, rate limiting, credits, idempotency"
- BAD: "Reader API documentation"

---

## Phase 7: Lint the Wiki

After building/refreshing all articles, run a quality check:

### 7a. Orphan detection

```bash
CONTEXT_DIR=$(ls -d *-context/ 2>/dev/null | head -1)
echo "=== ORPHAN CHECK ==="

# Articles on disk not in INDEX.md
echo "Articles on disk:"
find "${CONTEXT_DIR}wiki/" -name "*.md" -type f 2>/dev/null | sort > /tmp/forge-wiki-files.txt
cat /tmp/forge-wiki-files.txt

echo ""
echo "Articles in INDEX.md:"
grep -o 'wiki/[^ )]*\.md' "${CONTEXT_DIR}INDEX.md" 2>/dev/null | sort > /tmp/forge-index-refs.txt
cat /tmp/forge-index-refs.txt

echo ""
echo "=== FILES NOT IN INDEX ==="
diff /tmp/forge-wiki-files.txt /tmp/forge-index-refs.txt 2>/dev/null | grep "^<" | sed 's/^< //' || echo "None"

echo ""
echo "=== INDEX REFS TO MISSING FILES ==="
diff /tmp/forge-wiki-files.txt /tmp/forge-index-refs.txt 2>/dev/null | grep "^>" | sed 's/^> //' || echo "None"

rm -f /tmp/forge-wiki-files.txt /tmp/forge-index-refs.txt
```

Fix any orphans: add missing articles to INDEX.md, remove broken references.

### 7b. Stale content detection

For each article, check if the files it references still exist:

- Use Grep to find file path references in each article (patterns like `src/`, `.ts:`, `.rs:`)
- For each referenced file path, check if the file exists with Glob
- If a referenced file doesn't exist, flag the article as potentially stale

### 7c. Consistency check

Cross-reference BACKLOG.md with wiki/bugs/:
- Every active backlog issue should have a wiki/bugs/ article (or at least be noted)
- Every wiki/bugs/ article marked "Open" should have a corresponding backlog entry
- No resolved bugs should be listed as active in the backlog (or vice versa)

### 7d. Coverage assessment

After linting, assess wiki coverage:

```
WIKI COVERAGE
═══════════════════════════════════
Architecture:  {count}/{total repos} repos documented
API Reference: {count}/{total endpoints} endpoints documented
Bugs:          {count}/{total backlog issues} issues documented
Decisions:     {count} decisions documented
Patterns:      {count} patterns documented

Missing coverage:
  - {repo X} has no architecture article
  - {endpoint Y} is not documented in wiki/api/endpoints.md
  - {backlog issue Z} has no wiki/bugs/ article
═══════════════════════════════════
```

---

## Phase 8: Learning Capture

After compiling the wiki, you've gained deep knowledge of the codebase. Capture the
most valuable insights:

```bash
CONTEXT_DIR=$(ls -d *-context/ 2>/dev/null | head -1)
```

**What to capture as learnings (examples):**
- "reader-api uses fire-and-forget for credit deduction but awaits it in the sync scrape path to ensure 200 is never returned without charging" (architecture, confidence 9)
- "supermarkdown NAPI bindings are in reader/src/native/, not in supermarkdown itself" (operational, confidence 10)
- "reader-cloud-api shares the same MongoDB collections as reader-api, including ApiKey and Workspace" (architecture, confidence 9)
- "The webhook signing secret is encrypted at rest with AES-256-GCM in reader-cloud-api" (architecture, confidence 9)

For each learning:
```bash
echo '{"ts":"'$(date -u +%Y-%m-%dT%H:%M:%SZ)'","skill":"compile-wiki","type":"TYPE","key":"KEY","insight":"INSIGHT","confidence":N,"source":"observed","files":["path"]}' >> "${CONTEXT_DIR}LEARNINGS.jsonl"
```

---

## Phase 9: Timeline Logging

```bash
CONTEXT_DIR=$(ls -d *-context/ 2>/dev/null | head -1)
echo '{"skill":"compile-wiki","event":"completed","ts":"'$(date -u +%Y-%m-%dT%H:%M:%SZ)'","outcome":"success","articles_created":N,"articles_updated":M,"total_articles":T,"lint_issues":L}' >> "${CONTEXT_DIR}timeline.jsonl"
```

---

## Phase 10: Git Commit

```bash
CONTEXT_DIR=$(ls -d *-context/ 2>/dev/null | head -1)
cd "$CONTEXT_DIR"
git add -A
CHANGES=$(git diff --cached --stat | tail -1)
git commit -m "wiki: compile knowledge base ($(date +%Y-%m-%d))

$CHANGES

Articles: N created, M updated, T total
Coverage: {brief coverage summary}
Lint: {issues found/fixed}"
cd ..
```

---

## Phase 11: Report

```
WIKI COMPILATION REPORT
════════════════════════════════════════════════════════════════

Articles created:   {count}
Articles updated:   {count}
Articles unchanged: {count}
Total articles:     {count}
Estimated words:    ~{estimate}K

New articles:
  Architecture:
    - wiki/architecture/overview.md
    - wiki/architecture/{service}.md
    ...
  API Reference:
    - wiki/api/endpoints.md
    ...
  Bugs:
    - wiki/bugs/{slug}.md
    ...

Lint results:
  Orphans:       {count fixed}
  Stale content: {count flagged}
  Inconsistencies: {count fixed}

Coverage:
  {coverage assessment from Phase 7d}

Learnings captured: {count}

════════════════════════════════════════════════════════════════

The knowledge base is ready. Future sessions will read INDEX.md first to navigate.
Run /compile-wiki periodically to refresh as the codebase evolves.
```

---

## Critical Rules

1. **READ before writing.** If an article exists, read it first. Update what's stale,
   preserve what's still accurate. Don't destroy prior work.

2. **Be concrete.** Name real files, real functions, real line numbers. Not "the auth
   module" but "`reader-api/src/middleware/auth.ts:23`, the `apiKeyAuth` function that
   validates the `x-api-key` header by SHA-256 hashing it and looking up the hash in
   the `ApiKey` collection."

3. **Don't copy-paste code.** Reference it with file:line. The wiki explains WHAT and
   WHY. The code shows HOW. Link to the code, don't duplicate it.

4. **Keep articles focused.** One topic per article. If an article exceeds ~500 lines,
   split it into sub-articles.

5. **INDEX.md must be EXACTLY right.** Every article on disk must be listed. Every
   listed article must exist. No orphans. Run the lint check.

6. **Document non-obvious things.** "This is an Express server" is obvious. "The credits
   middleware pre-estimates cost based on request type (1 for standard, 3 for stealth)
   and rejects if balance is insufficient, then does a post-flight atomic deduction after
   the scrape completes" is useful.

7. **Cross-link articles.** Bug articles should link to the architecture article for
   the affected service. Architecture articles should link to related bugs and patterns.
   INDEX.md should be the hub, but articles should link to each other too.

8. **Track compilation metadata.** The INDEX.md footer shows when it was last compiled
   and how many articles/words exist. This helps future sessions know if the wiki is
   fresh or stale.

---

## Completion Status

- **DONE** -- Wiki compiled/refreshed, INDEX.md rebuilt, lint passed, committed.
- **DONE_WITH_CONCERNS** -- Compiled but: stale content detected (files referenced in
  articles no longer exist), or coverage gaps (repos without articles), or lint issues
  that couldn't be auto-fixed.
- **BLOCKED** -- No context directory, or codebase is empty/inaccessible.
