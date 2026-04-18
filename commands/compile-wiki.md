---
description: Compile a structured knowledge base wiki from the codebase
---

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

## Wiki Structure Principles (READ THIS FIRST)

The wiki exists for ONE purpose: to give future LLM sessions enough context to
work effectively without re-reading the entire codebase. Every structural choice
serves this goal.

### Principle 1: INDEX.md is the router, not the content

INDEX.md is always loaded into context (via hooks or CLAUDE.md). It must be:
- **Under 2,000 tokens.** If it grows larger, summaries are too verbose.
- **One line per article.** Format: `- [filename.md](path) -- what it covers (specific keywords)`
- **Keywords matter.** The LLM uses the one-line summary to decide whether to read
  the full article. "Backend API docs" is useless. "Backend API: auth middleware,
  rate limiting, Zod validation, credit deduction, job queue" is useful.

The LLM reads INDEX.md, picks the relevant articles, reads those. It never reads
the entire wiki. This is how 50+ articles stay efficient: the router is small,
the content is on-demand.

### Principle 2: Articles are self-contained

Each article must make sense on its own. An LLM reading `wiki/architecture/backend-api.md`
should understand that service without needing to also read `overview.md`. Include:
- What this thing IS (2-3 sentences)
- How it connects to other parts of the system (dependencies, consumers)
- The specific files/functions that matter (with paths and line numbers)
- Non-obvious behavior (the stuff that trips people up)

### Principle 3: Reference code, don't copy it

Write `backend/src/middleware/auth.ts:42 -- validates bearer token` not a copy of
the function. Code changes, wiki references get stale. But a reference to
`file:line -- what it does` is easy to verify and update. The wiki explains WHAT
and WHY. The code shows HOW.

### Principle 4: Structured for scanning, not reading

LLMs scan. They don't read top-to-bottom like humans. Structure for scanning:
- **Tables** for reference data (endpoints, config vars, error codes)
- **Numbered lists** for sequences (request flow, startup order)
- **Bold key terms** at the start of each bullet
- **Headers** that describe content, not categories ("How auth works" not "Authentication")
- **No prose paragraphs longer than 3 sentences.** Break them up.

### Principle 5: The integrations article is the most valuable

In multi-repo workspaces, `wiki/architecture/integrations.md` is what enables
cross-service debugging. It must document:
- Which repos call which (with protocol: HTTP, SDK, shared DB)
- What the contracts look like (request/response shapes)
- What breaks when each dependency is down
- Shared data models and where they diverge

An LLM debugging a 502 needs to know "service A calls service B via HTTP at
`/internal/process`, and if B is down, A returns 502 with error code
`upstream_unavailable`." That single sentence saves 10 minutes of tracing.

### Principle 6: Staleness markers

Every article should have a way to detect staleness:
- Reference specific file paths (if the file is gone, the article is stale)
- Include the "Last updated" date at the bottom
- Note the git commit hash when major changes were documented

### Anti-patterns (DO NOT do these)

- **Don't write marketing copy.** "Our elegant microservice architecture" is waste.
  Write "3 Node.js services + 1 Rust library, all hitting the same MongoDB."
- **Don't document the obvious.** "Express is a web framework" is waste. Document
  what's specific to THIS project.
- **Don't create empty placeholder articles.** An article with "TODO: document this"
  pollutes INDEX.md and wastes context tokens.
- **Don't nest wiki directories deeper than 2 levels.** `wiki/architecture/` is fine.
  `wiki/architecture/services/backend/middleware/` is not.

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

### 2b. For CLI tools / background daemons

Read:
1. CLI entry point (how it starts, what flags it takes)
2. Core processing loop or pipeline
3. Resource management (pools, connections, workers)
4. Error handling and shutdown

### 2c. For Rust / Go / compiled libraries

Read:
1. Build manifest (`Cargo.toml`, `go.mod`)
2. Public API (`src/lib.rs`, exported package)
3. Key modules
4. FFI / NAPI / WASM bindings (how other languages call it)

### 2d. For frontend apps

Read:
1. `package.json` (dependencies, scripts)
2. Entry point (main component)
3. Route structure
4. API client (how it calls the backend)

### 2e. For SDKs / client libraries

Read:
1. Package manifest
2. Client class (main API surface)
3. Types/interfaces
4. Error handling

### 2f. For documentation sites

Read:
1. Config file (`mint.json`, `docusaurus.config.js`, etc.)
2. Navigation structure
3. Key concept pages
4. API reference pages

### 2g. Cross-repo integration points (CRITICAL for multi-repo workspaces)

After reading individual repos, trace how they connect. For each pair of repos
that communicate:

1. **How does repo A call repo B?** (HTTP, SDK import, shared DB, message queue, CLI)
2. **What is the contract?** (API endpoints, request/response shapes, error codes)
3. **What data is shared?** (database collections/tables, schemas, types)
4. **What is the dependency direction?** (who depends on whom, what breaks if B is down)
5. **Are there shared types or schemas?** (duplicated types, generated clients, shared packages)

Look for:
- Import statements that reference other repos in the workspace
- HTTP client calls to `localhost:{port}` pointing at sibling services
- Shared database connection strings across repos
- SDK packages published by one repo and consumed by another
- Shared config or environment variables

```bash
# Find cross-repo HTTP calls
grep -rn "localhost:\|127\.0\.0\.1:" */src/ 2>/dev/null | grep -v node_modules | head -20

# Find shared database references
grep -rn "mongodb://\|postgres://\|DATABASE_URL\|MONGO" */src/ */.env* 2>/dev/null | grep -v node_modules | head -20

# Find internal SDK/package imports across repos
for dir in */; do
  [ -f "$dir/package.json" ] && grep -o '"@[^"]*"' "$dir/package.json" 2>/dev/null | while read pkg; do
    for other in */; do
      [ "$dir" != "$other" ] && [ -f "$other/package.json" ] && grep -q "\"name\": $pkg" "$other/package.json" 2>/dev/null && echo "  $dir imports $pkg from $other"
    done
  done
done
```

**This is the most valuable knowledge for multi-repo debugging.** When a bug
crosses service boundaries, knowing exactly how repo A calls repo B (and what
the contract looks like) saves hours of tracing.

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

- **{Database}** ({connection string}): Used by {list services}. Database name: {name}.
- {Other shared resources: caches, queues, file storage, etc.}

## Key URLs

| URL | Service | Auth |
|-----|---------|------|
| http://localhost:{port}/health | {service} | None |
| http://localhost:{port}/{path} | {service} | {auth method} |
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
| `src/routes/{main}.ts` | Primary route handler | `{router}` |
| `src/middleware/{auth}.ts` | Auth middleware | `{authMiddleware}` |
| ... | ... | ... |

{List the 10-20 most important files. Not every file, just the ones a developer
needs to understand to work on this service.}

## How It Works

### Request Flow
{Trace a typical request from entry to response. Be specific:}

1. Request arrives at `{METHOD} {path}` (`src/routes/{file}:{line}`)
2. Middleware chain runs: {list each middleware in order}
3. Request body validated with {validation library/schema}
4. Core business logic: {what happens, what other services are called}
5. Response formatted and returned
6. Side effects: {logging, metrics, async jobs, etc.}

### Error Handling
{How errors are caught, formatted, and returned. Reference the error codes.}

### Background Jobs
{If the service has async jobs, explain the lifecycle: creation -> processing -> completion.}

## Configuration

| Variable | Default | Required | Description |
|----------|---------|----------|-------------|
| `PORT` | 6002 | No | Server port |
| `DATABASE_URL` | `{connection string}` | Yes | Database connection |
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
- **{Database}** -- {what it stores there}
- **{Other service}** (localhost:{port}) -- {what it calls it for, protocol}
- {other dependencies}

### Depended on by:
- **{Consumer service}** -- {how it calls this service and why}
- **{SDK / external consumers}** -- {how they interact}

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

{For each major user-facing operation, trace the complete lifecycle across all
services involved. Include file:line references.}

## {Operation Name} (e.g., "Create Resource", "Process Job", "User Login")

1. **{Entry point service}** (`{repo}/src/{file}:{line}`)
   - What it receives (request shape)
   - What validation/auth it performs
   - What it calls next and why
2. **{Next service in chain}** (`{repo}/src/{file}:{line}`)
   - What it receives from the previous service
   - What processing it does
   - What it returns or passes downstream
3. **{Continue for each service in the chain}**

{Repeat for each major operation. Cover both the happy path and key error paths.
The goal is that someone debugging a cross-service issue can trace exactly which
service handles which part of the request.}
```

### 3d. Cross-repo integration article

Create `wiki/architecture/integrations.md`:

**This article is the most valuable artifact for multi-repo workspaces.** It
documents how repos talk to each other, what contracts they share, and what
breaks when something changes.

```markdown
# Cross-Repo Integrations

## Integration Map

{ASCII or text diagram showing which repos call which, and how:}

```
{repo-a} --HTTP--> {repo-b} --SDK--> {repo-c}
    \                                    |
     +--------shared DB-----------------+
```

## Service-to-Service Connections

### {repo-a} -> {repo-b}

- **Protocol:** HTTP / gRPC / SDK import / shared database / message queue
- **How:** {e.g., "repo-a calls POST /v1/process on repo-b via HTTP client in
  repo-a/src/services/processor.ts:42"}
- **Contract:**
  - Request: {shape, key fields}
  - Response: {shape, key fields}
  - Error codes: {what repo-b returns on failure}
- **Auth:** {how repo-a authenticates to repo-b, e.g., internal API key, JWT}
- **What breaks if repo-b is down:** {e.g., "repo-a returns 502 to the client"}

### {repo-b} -> {repo-c}
{Same format}

## Shared Data

### Database: {name}
- **Used by:** {list repos}
- **Shared collections/tables:**
  | Collection/Table | Written by | Read by | Key fields |
  |-----------------|-----------|---------|------------|
  | {name} | {repo} | {repo, repo} | {fields} |

### Shared Types / Schemas
- **{type name}:** Defined in {repo/path}, consumed by {repo/path}
  - Are they kept in sync? (shared package, copy-pasted, generated?)
  - Known divergences: {any}

## Dependency Chain

Changes flow downstream. When you change something, here's what needs to
restart, rebuild, or be aware:

- {upstream repo} change -> {what to rebuild} -> {what to restart}
- {shared-lib} change -> {rebuild consumers} -> {restart services}

## Common Cross-Service Failure Modes

| Failure | Symptom in {repo-a} | Actual cause in {repo-b} | How to debug |
|---------|---------------------|--------------------------|--------------|
| {name} | {what you see} | {what's actually wrong} | {where to look} |
```

**Why this article matters:** Most bugs in multi-repo systems manifest in one
service but originate in another. This article is the map for tracing across
boundaries. Every skill should update it when they discover a new integration
path or failure mode.

---

## Phase 4: Compile API Reference Articles

If the project has HTTP APIs, document them exhaustively.

### 4a. Endpoints article

Create `wiki/api/endpoints.md`:

```markdown
# API Endpoints

## Authentication
{How auth works: header name, token format, validation process}

## Endpoints

### {METHOD} {path}
{Purpose, request body (every field), response shape (every field), error codes}

### {METHOD} {path}
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
| `{error_code}` | {status} | {what triggers it} | {how to fix} |
| ... | ... | ... | ... |

## Details

### {error_code} ({status})
{When it triggers, what the response looks like, how to fix it}

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
- GOOD: "Backend API middleware chain: auth, rate limiting, quota, idempotency"
- BAD: "Backend API documentation"

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
- "backend-api uses fire-and-forget for usage tracking but awaits in the sync path to ensure 200 is never returned without logging" (architecture, confidence 9)
- "shared-lib NAPI bindings are in backend/src/native/, not in shared-lib itself" (operational, confidence 10)
- "frontend and backend share the same database collections, including User and Workspace" (architecture, confidence 9)
- "service-a calls service-b via internal SDK, not direct HTTP, so errors are wrapped" (architecture, confidence 9)
- "when shared-lib changes, backend must be rebuilt before restarting the API" (operational, confidence 10)

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
   module" but "`backend/src/middleware/auth.ts:23`, the `verifyToken` function that
   validates the bearer token by checking it against the sessions table."

3. **Don't copy-paste code.** Reference it with file:line. The wiki explains WHAT and
   WHY. The code shows HOW. Link to the code, don't duplicate it.

4. **Keep articles focused.** One topic per article. If an article exceeds ~500 lines,
   split it into sub-articles.

5. **INDEX.md must be EXACTLY right.** Every article on disk must be listed. Every
   listed article must exist. No orphans. Run the lint check.

6. **Document non-obvious things.** "This is an Express server" is obvious. "The rate
   limiter pre-checks quota before processing, then does a post-flight atomic deduction
   after the operation completes, so the request can still fail after the initial check
   passes" is useful.

7. **Cross-link articles.** Bug articles should link to the architecture article for
   the affected service. Architecture articles should link to related bugs and patterns.
   INDEX.md should be the hub, but articles should link to each other too.

8. **Track compilation metadata.** The INDEX.md footer shows when it was last compiled
   and how many articles/words exist. This helps future sessions know if the wiki is
   fresh or stale.

9. **Always create the integrations article.** In multi-repo workspaces, the
   `wiki/architecture/integrations.md` article is the single most valuable artifact.
   It documents how repos call each other, what contracts they share, and what breaks
   when something changes. If it doesn't exist, create it. If it exists, verify it's
   still accurate.

10. **Take positions, don't hedge.** When documenting architecture, state what the
    system does. Not "the service might use caching" but "the service caches responses
    for 60s in Redis, keyed by URL hash." If you're uncertain, say "unverified" with
    what you observed. Never write "there are many ways to think about this."

11. **Write for the agent that comes after you.** Every article should answer: "If a
    new Claude session needs to debug/modify this part of the system, what does it need
    to know?" If the answer is "read the code," your article isn't useful enough.

12. **Load RULES.md before compiling.** Read the project rules and respect them in the
    wiki. If rules say "never mention X," the wiki should not mention X.

---

## Completion Status

- **DONE** -- Wiki compiled/refreshed, INDEX.md rebuilt, lint passed, committed.
- **DONE_WITH_CONCERNS** -- Compiled but: stale content detected (files referenced in
  articles no longer exist), or coverage gaps (repos without articles), or lint issues
  that couldn't be auto-fixed.
- **BLOCKED** -- No context directory, or codebase is empty/inaccessible.
