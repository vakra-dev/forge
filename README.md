# forge

> Turn Claude Code into an autonomous engineering team.

forge is an open-source framework that gives Claude Code persistent memory, a compounding knowledge base, and autonomous skills that test, debug, and fix your code while you're away.

Clone it into any workspace. Run setup. Walk away. Come back to fixed bugs and PRs.

Built by [vakra-dev](https://vakra.dev). MIT licensed.

---

## The problem

Every Claude Code session starts from zero. It doesn't know what you tried yesterday, what failed, what decisions were made, or what's broken. You spend the first 10 minutes of every session re-explaining context. Multiply that across multiple repos, multiple products, multiple days. That's where your time goes.

## What forge does

**1. Knowledge base that compounds.** An LLM-compiled wiki of your entire project -- architecture, APIs, bugs, decisions, patterns. Every session reads it, every session contributes to it. After 10 sessions, the agent knows your codebase better than you do. Inspired by [Karpathy's LLM Knowledge Bases](https://x.com/karpathy/status/1924490451796930886) pattern.

**2. Autonomous skills with safety gates.** `/test-fix` runs your test suite, investigates every failure, fixes bugs with atomic commits, verifies fixes, and loops -- all without you in the room. `/investigate` does systematic root cause debugging with a hard rule: no fixes without root cause. Each skill has escalation rules (3-strike per bug), self-regulation (WTF-likelihood score), and hard caps (20 fixes per session).

**3. Session persistence that actually works.** `/checkpoint` captures everything: what was done, what failed (and WHY it failed), what decisions were made, what's left. `/recall` loads it all back and presents a briefing. The "What Failed -- DO NOT RETRY" section alone saves hours of wasted re-investigation.

**Why `/recall` and not `/resume`?** Claude Code has a built-in `/resume` command for the conversation picker. We named ours `/recall` to avoid the conflict.

---

## Quick start

### Install

```bash
# Clone into your workspace
cd your-workspace
git clone https://github.com/vakra-dev/forge.git

# Run setup
./forge/setup
```

That's it. Setup does three things:
1. Creates `{project}-context/` -- your project's persistent knowledge base (a separate git repo)
2. Symlinks `forge/commands/*.md` into `.claude/commands/` -- makes skills available as slash commands
3. Checks for `CLAUDE.md` -- your project-specific routing and architecture

### First session

```bash
# 1. Check what's running
/status

# 2. Build the knowledge base from your codebase
/compile-wiki

# 3. Start fixing bugs autonomously
/test-fix

# 4. Save your progress before ending the session
/checkpoint
```

### Next session

```bash
# Load context from where you left off
/recall

# Continue fixing (only re-runs previously failing tests)
/test-fix --only-failed
```

### Update forge

```bash
cd forge && git pull && ./forge/setup
```

---

## Skills

forge ships with 6 skills. Each is a detailed prompt (500-960 lines) that encodes an autonomous workflow with explicit safety gates, wiki contribution, learning capture, and completion protocols.

### /status -- Workspace Health Dashboard

**What it does:** Checks every service health endpoint, every repo's git state, latest test results, and cross-references with known issues. Presents a structured dashboard.

**When to use:** Start of session. Before running tests. After deploying changes. Whenever you want the full picture.

**What it produces:**
```
WORKSPACE HEALTH DASHBOARD
════════════════════════════════════════════════
Services:
  Reader Engine  (6003)  ██ UP
  Reader API     (6002)  ██ UP
  Cloud API      (6001)  ░░ DOWN
  MongoDB              ██ UP

  Summary: 3/4 services healthy

Repos:
  reader           main     clean     abc1234 "fix: pool timeout"
  reader-api       main     3 dirty   def5678 "feat: batch retry"

E2E Tests:
  Pass rate: 85/150 (56.7%)

Known Issues: 4 active
  [CRITICAL] table.rs panic on nested tables
  [HIGH] Amazon pages return Access Denied
════════════════════════════════════════════════
```

**Updates:** STATE.md, timeline. Creates wiki articles if new issues are discovered.

---

### /recall -- Session Briefing

**What it does:** Reads every piece of context (INDEX.md, STATE.md, BACKLOG.md, learnings, timeline, latest checkpoint) and synthesizes a structured briefing. Then WAITS for your direction.

**When to use:** Start of every new session. Coming back after a break. Picking up someone else's work.

**What it produces:**
```
SESSION BRIEFING
════════════════════════════════════════════════
Project:        reader
Last session:   2026-04-06, investigating table-rs panic
Stack health:   3/4 services up (Cloud API down)

KNOWN ISSUES (4 active)
  [CRITICAL] table.rs panic on nested tables

WHAT NOT TO RETRY
  - Increasing stack size: FAILED because the recursion is unbounded
  - Iterative table parsing: FAILED because rowspan/colspan lose context

REMAINING WORK
  1. Add depth guard in table.rs parse_table function
  2. Run /test-fix --only-failed to verify
════════════════════════════════════════════════
Ready to continue. What would you like to work on?
```

**Critical rule:** /recall NEVER starts working. It presents information and waits.

---

### /checkpoint -- Save Session State

**What it does:** Captures the complete working context: git state across all repos, test results, what was accomplished, what failed and WHY, decisions made, remaining work. Writes a structured checkpoint file. Updates STATE.md, BACKLOG.md, and wiki articles. Git commits the context repo.

**When to use:** End of every session. Before switching to a different task. Before a long break. Anytime you want to save progress.

**What it produces:**
```
CHECKPOINT SAVED
════════════════════════════════════════════════
Title:       investigating table-rs panic
File:        reader-context/SESSIONS/20260406-183045-investigating-table-rs-panic.md
Branches:    reader: main, reader-api: main, supermarkdown: main
Modified:    3 files across repos
Wiki:        1 article created (wiki/bugs/table-rs-panic.md)
Learnings:   2 entries added
Committed:   abc1234
════════════════════════════════════════════════
```

**The "What Failed" section is mandatory.** Even if nothing failed. This section is the single most valuable artifact for preventing wasted work in future sessions.

---

### /compile-wiki -- Knowledge Base Compiler

**What it does:** Reads the entire codebase (entry points, routes, middleware, models, config), existing documentation, and raw source material. Compiles structured wiki articles: architecture overviews, per-service deep dives, API reference, data flow diagrams. Builds INDEX.md for navigation. Runs linting to detect stale content, orphaned articles, and coverage gaps.

**When to use:** First time setting up forge. After major code changes. Periodically to refresh the knowledge base. Whenever the wiki feels stale.

**What it produces:**
- `wiki/architecture/overview.md` -- Service topology, ports, dependencies
- `wiki/architecture/{service}.md` -- Per-service deep dive (key files, request flow, config, gotchas)
- `wiki/architecture/data-flow.md` -- Full request lifecycle across services
- `wiki/api/endpoints.md` -- Every API endpoint with request/response shapes
- `wiki/api/error-codes.md` -- Every error code with causes and handling
- `wiki/bugs/{slug}.md` -- Bug articles from BACKLOG.md
- `INDEX.md` -- Master index with one-line summaries of every article

```
WIKI COMPILED
════════════════════════════════════════════════
Articles created:   12
Articles updated:   0
Total articles:     12
Estimated words:    ~45K

Coverage:
  Architecture: 5/5 repos documented
  API Reference: 13/13 endpoints documented
  Bugs:          4/4 backlog issues documented
════════════════════════════════════════════════
```

**The Karpathy pattern:** Raw data goes in, structured wiki comes out. The LLM maintains it, you rarely touch it directly. Your explorations and queries compound into it.

---

### /investigate -- Root Cause Debugging

**What it does:** Systematic root cause analysis with a hard iron law: NO FIXES WITHOUT ROOT CAUSE. Four phases: investigate (gather symptoms, read code, check history) → analyze (pattern matching, cross-reference with wiki/bugs) → hypothesize (form testable claim, verify before fixing) → implement (minimal fix, regression test, verify).

**When to use:** Debugging a specific issue. A test failure you want to understand deeply. An error you need to trace through multiple services.

**Safety gates:**
- **Iron law:** Will not write a fix until root cause is confirmed with evidence
- **3-strike rule:** 3 failed hypotheses → STOP and escalate (don't keep guessing)
- **Scope lock:** Restricts edits to the affected repo/directory (no scope creep)
- **Blast radius check:** Fix touching >5 files → asks before proceeding

**What it produces:**
```
DEBUG REPORT
════════════════════════════════════════════════
Symptom:    supermarkdown panics on nested tables
Root cause: Recursive descent in table.rs:234 has no depth guard
            Stack overflows at nesting depth >5
Fix:        Added depth limit of 10 in parse_table()
            File: supermarkdown/src/table.rs:234
            Commit: abc1234
Evidence:   Regression test passes, previously failing URLs now succeed
Status:     DONE
════════════════════════════════════════════════
```

**Updates:** wiki/bugs/ article with full investigation history, BACKLOG.md, learnings, INDEX.md.

---

### /test-fix -- Autonomous Test-Fix Loop

**What it does:** THE main autonomy skill. Runs the e2e test suite, triages results by priority (crash > fail > partial), skips known-flaky and already-documented issues, then enters the fix loop: investigate root cause → fix with atomic commit → verify fix → move to next failure. Self-regulates with WTF-likelihood scoring. Updates the entire knowledge base afterward.

**When to use:** "Go fix the bugs and come back when it's done." The morning workflow: `/test-fix`, walk away, come back to fixed code.

**Flags:**
```bash
/test-fix                    # Full suite, all URLs
/test-fix --only-failed      # Only re-run previously failing URLs (fast)
/test-fix --category wikipedia   # Only one category
/test-fix --limit 10         # Limit to N URLs
```

**Safety gates:**
- **Iron law:** Every fix has a confirmed root cause (no guessing)
- **One commit per fix:** Every fix is independently revertable
- **3-strike per bug:** 3 failed fix attempts → log to backlog, move to next
- **WTF-likelihood:** Every 5 fixes, compute a score. >20% → STOP and report
- **20-fix hard cap:** Stop at 20 fixes regardless. Defer the rest.
- **Regression check:** Full suite re-run after all fixes. YOUR fixes must not break passing tests.
- **Never retry failed approaches:** Reads BACKLOG.md first. If it says something was tried, finds a different approach.

**What it produces:**
```
TEST-FIX SESSION REPORT
════════════════════════════════════════════════
Before:    85/150 (56.7%)
After:     102/150 (68.0%)
Delta:     +17 improvements, 0 regressions

Fixes Applied (8):
  1. fix(supermarkdown): depth guard in table parser
  2. fix(reader-api): map ECONNRESET to upstream_unavailable
  3. fix(reader): increase pool timeout to 45s
  ...

Skipped -- 3 Strikes (2):
  1. github.com/anthropics/claude-code -- auth wall, 3 approaches tried
  2. arxiv.org/abs/2301.00234 -- PDF redirect, not standard HTML

Skipped -- Known Flaky (48):
  Amazon product pages -- bot detection (documented)

Safety: 8/20 cap, WTF 5%, 0 regressions
════════════════════════════════════════════════
```

---

## The Knowledge Base

forge uses the [Karpathy LLM Knowledge Base](https://x.com/karpathy/status/1924490451796930886) pattern: raw data is compiled by the LLM into a structured wiki, then operated on by the LLM to answer questions and incrementally enhance the wiki.

### How it compounds

```
Session 1:   /compile-wiki reads codebase → writes 15 wiki articles
Session 2:   /test-fix finds bug → writes wiki/bugs/table-panic.md
Session 3:   /investigate traces root cause → updates the bug article
Session 4:   New session reads INDEX.md → sees the article → skips re-investigation
Session 10:  Wiki has 50+ articles. Agent navigates via INDEX.md. Deep context on demand.
Session 20:  Agent knows every architectural decision, every past bug, every failed approach.
```

### Every skill is a wiki contributor

`/compile-wiki` does the initial build and periodic deep refresh. But the real compounding happens because every skill updates the wiki as a side effect of normal work:

- `/investigate` finds root cause → writes wiki/bugs/ article
- `/test-fix` discovers pattern → adds wiki/patterns/ article
- `/checkpoint` captures decision → adds wiki/decisions/ article
- Any skill notices stale content → fixes it inline
- Any skill discovers something new → creates article, updates INDEX.md

### Structure

```
{project}-context/
  INDEX.md                      # Master index (LLM reads this first, ~2K tokens)
  STATE.md                      # Live health of all services
  BACKLOG.md                    # Known issues + what was tried (prevents retry loops)
  LEARNINGS.jsonl               # Append-only institutional knowledge
  timeline.jsonl                # Skill event history
  SESSIONS/                     # Session checkpoint files
  wiki/
    architecture/               # Service topology, internals, data flow
    api/                        # Endpoints, error codes, rate limits
    bugs/                       # Per-issue investigation articles
    decisions/                  # Architectural decision records
    patterns/                   # Recurring patterns and approaches
  raw/                          # Source material for compilation
```

### INDEX.md -- the navigation layer

Every skill reads INDEX.md first. It's a brief summary of every article (~2K tokens). The LLM knows where everything is without reading 400K words of wiki content.

```markdown
# Reader Knowledge Base

## Architecture (5 articles)
- [overview.md](wiki/architecture/overview.md) -- Service topology, ports, dependencies
- [reader-engine.md](wiki/architecture/reader-engine.md) -- Browser pool, proxy, Hero
- [reader-api.md](wiki/architecture/reader-api.md) -- Express API, middleware, Zod
...

## Bugs (4 articles, 3 open / 1 resolved)
- [table-rs-panic.md](wiki/bugs/table-rs-panic.md) -- Supermarkdown panic on nested tables [OPEN]
- [amazon-bot-detection.md](wiki/bugs/amazon-bot-detection.md) -- 403 on product pages [KNOWN FLAKY]
...
```

---

## Persistence Layers

forge uses 7 persistence layers, each serving a different purpose:

| Layer | File | Purpose | Who writes | Who reads |
|-------|------|---------|-----------|-----------|
| **Index** | `INDEX.md` | Navigate the wiki | /compile-wiki, all skills | Every skill (first) |
| **State** | `STATE.md` | Current service health | /checkpoint, /test-fix, /status | Every skill |
| **Backlog** | `BACKLOG.md` | Known issues + failed approaches | /test-fix, /investigate | Every skill |
| **Wiki** | `wiki/**/*.md` | Deep knowledge articles | /compile-wiki, all skills | On-demand |
| **Learnings** | `LEARNINGS.jsonl` | Institutional knowledge | All skills | All skills |
| **Timeline** | `timeline.jsonl` | Event history | All skills | /recall |
| **Checkpoints** | `SESSIONS/*.md` | Session snapshots | /checkpoint | /recall |

All layers are git-tracked. Every update is a commit. You get full history and diffs.

---

## The Autonomous Workflow

### Daily workflow for a solo founder

**Morning (5 minutes):**
```bash
/recall                         # Load context from yesterday
/test-fix                       # Start autonomous test-fix loop
# Walk away. Go to office.
```

**Evening (10 minutes):**
```bash
/recall                         # See what happened
git log --oneline reader/       # Review the fix commits
git log --oneline reader-api/   # Review the fix commits
/checkpoint                     # Save state for tomorrow
```

### The target workflow (multiple products)

```
7:00 AM    Plan tasks across 5 products
7:30 AM    Start /test-fix in each workspace (5 terminal tabs)
           Leave for office
6:00 PM    Come back. Run /recall in each workspace.
           Review fix commits. Approve PRs.
           Run /checkpoint in each.
```

---

## Safety

forge is designed to be left alone. Every autonomous skill has explicit safety gates:

| Gate | What it prevents |
|------|-----------------|
| **Iron law** | No fixes without confirmed root cause. No guessing. |
| **3-strike rule** | 3 failed attempts on same bug → stop, log, move on |
| **20-fix cap** | Hard stop at 20 fixes per session. Prevents runaway changes. |
| **WTF-likelihood** | Every 5 fixes, compute a risk score. >20% → stop and report. |
| **Regression check** | Full suite re-run after fixes. Your fixes must not break passing tests. |
| **Scope lock** | Investigation restricts edits to affected repo/directory |
| **Atomic commits** | One commit per fix. Each independently revertable. |
| **Never retry** | Reads BACKLOG before fixing. Won't retry documented failed approaches. |
| **Never merge** | Creates commits. Never merges or pushes without user approval. |

---

## Multi-repo support

forge is multi-repo native. The context directory tracks state across ALL repos in the workspace. Skills trace bugs across service boundaries (e.g., a 502 from reader-api might have its root cause in the reader engine or supermarkdown).

```
your-workspace/
  service-a/          # Git repo
  service-b/          # Git repo
  shared-lib/         # Git repo
  project-context/    # Tracks state across all repos
  forge/              # The tool
```

`/status` checks every repo's git state. `/checkpoint` captures branches across all repos. `/test-fix` traces failures across service boundaries. `/investigate` scope-locks to the specific repo where the root cause lives.

---

## Reusability

forge separates the tool from the data:

- **`forge/`** (the tool) -- Generic. Works with any project. Clone and use.
- **`{project}-context/`** (the data) -- Project-specific. Created by setup.

For a new product:
```bash
cd new-product-workspace
git clone https://github.com/vakra-dev/forge.git
./forge/setup
# Edit CLAUDE.md with your project's architecture
/compile-wiki
```

The pattern is `{product}-context/` with the same structure. Skills are portable across all workspaces.

---

## Updating forge

```bash
cd forge && git pull && ./forge/setup
```

Setup re-links commands. Your context repo is untouched (it's a separate git repo). New commands and improvements are available immediately.

---

## How it's different from gstack

[gstack](https://github.com/garrytan/gstack) (Garry Tan, 60K+ stars) is the direct inspiration. Key differences:

| | gstack | forge |
|---|---|---|
| **Focus** | Browser QA, design review, shipping PRs | API testing, multi-repo debugging, knowledge compounding |
| **Knowledge** | JSONL learnings only | Full wiki (Karpathy pattern) + JSONL learnings |
| **Preamble** | 200 lines (telemetry, upgrades, proactive prompts) | 30 lines (load context, completion, escalation) |
| **Setup** | Clone + `./setup` builds Bun binaries (~58MB) | Clone + `./setup` creates context repo. No build step. |
| **Dependencies** | Bun, Playwright, Chromium | None. Pure markdown + git. |
| **Repo scope** | Single repo | Multi-repo native |
| **Browser** | Persistent Chromium daemon | None (API-first) |
| **Skills** | 23 specialists (CEO, designer, QA, release eng) | 6 core skills (status, resume, checkpoint, compile-wiki, investigate, test-fix) |
| **Voice** | Garry Tan's builder philosophy | Your project's voice (CLAUDE.md) |

We adapted the patterns that matter (session intelligence, learnings, checkpoint, investigate methodology, QA fix loop with WTF-likelihood) and left out what doesn't fit (browser automation, design tools, CEO/design review pipeline, 200-line preambles with telemetry).

---

## Inspired by

- **[gstack](https://github.com/garrytan/gstack)** -- Garry Tan's AI engineering framework. The skill architecture, preamble pattern, /investigate iron law, /qa WTF-likelihood, and session intelligence system are all adapted from gstack.
- **[Karpathy's LLM Knowledge Bases](https://x.com/karpathy/status/1924490451796930886)** -- The wiki compilation pattern. Raw data → LLM-compiled wiki → INDEX.md navigation → compounding knowledge.
- **[beads](https://github.com/gastownhall/beads)** -- Persistent memory for AI agents. State-as-labels, dependency-aware work queues, and the git-versioned context pattern.
- **[Everything Claude Code](https://github.com/anthropics/claude-code)** -- Session save/resume patterns, multi-agent orchestration concepts.

---

## Project structure

```
forge/
  README.md                     # This file
  setup                         # Setup script (bash)
  commands/                     # Skill prompts (6 files, 4,288 lines total)
    status.md                   #   717 lines -- health dashboard
    resume.md                   #   415 lines -- session briefing
    checkpoint.md               #   652 lines -- save session state
    compile-wiki.md             #   767 lines -- knowledge base compiler
    investigate.md              #   777 lines -- root cause debugging
    test-fix.md                 #   960 lines -- autonomous test-fix loop
  templates/                    # Templates for context repo initialization
    STATE.md.tmpl
    BACKLOG.md.tmpl
    INDEX.md.tmpl
    CLAUDE.md.tmpl
  docs/                         # Documentation (coming)
    architecture.md
    skills.md
    knowledge-base.md
```

---

## License

MIT. Free to use, fork, modify, distribute.

Built by [vakra-dev](https://vakra.dev).
