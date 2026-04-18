# forge

> Persistent memory, compounding knowledge, and autonomous skills for Claude Code.

Most real projects span multiple repos that talk to each other. A frontend calls a backend, the backend calls a shared library, an SDK wraps the API. Claude Code treats each session as a blank slate. forge gives it a brain that persists across sessions and understands your entire workspace as one system.

Clone it. Run setup. Context loads automatically. The wiki gets smarter every session.

MIT licensed. Built by [vakra-dev](https://vakra.dev).

---

## What forge does

**Automatic context loading.** Hooks inject your project's rules, wiki index, state, backlog, and learnings into every session automatically. Even after context compaction, the essential context is re-injected. No manual steps.

**A self-improving wiki about your work.** `/compile-wiki` reads your codebase and builds a structured knowledge base: architecture, APIs, data flow, service integrations. Every session contributes to it. The wiki is structured specifically for LLM consumption: scannable tables, concrete file references, one-line summaries for routing. After a few sessions, it knows your system better than any doc you'd write by hand.

**Multi-repo awareness.** forge sees all repos in your workspace as one system. When a bug in service A is actually caused by service B's API contract, forge traces it across the boundary. The wiki captures how your repos integrate: shared schemas, internal API contracts, event flows, dependency chains.

**Project rules that persist.** `/rule never add co-authored-by to commits` saves the rule permanently. It's loaded into every future session via hooks and enforced automatically on git commits. Rules accumulate over time.

**Autonomous debugging and fixing.** `/test-fix` runs your tests, investigates failures, fixes bugs with atomic commits, and verifies fixes, in a loop, unattended. Safety gates prevent runaway changes.

---

## Quick start

```bash
# Clone into your workspace (the directory that contains your repos)
cd your-workspace
git clone https://github.com/vakra-dev/forge.git

# Run setup
./forge/setup
```

Setup does four things:
1. Creates `{project}-context/`, your persistent knowledge base (its own git repo)
2. Symlinks skills into `.claude/commands/`
3. Wires hooks into `.claude/settings.json` (auto-context loading)
4. Checks for `CLAUDE.md` (a template is provided)

No dependencies. No build step. Pure markdown, bash, and git.

### First session

```
/compile-wiki          Build the knowledge base from your codebase
/rule                  Add project-specific rules
/status                Check workspace health
```

### Daily workflow

```
# Context loads automatically via hooks. Just start working.
# For a full structured briefing:
/recall

# Fix bugs autonomously:
/test-fix

# Save progress:
/checkpoint
```

### Update forge

```bash
cd forge && git pull && ./forge/setup
```

---

## Hooks (automatic context pipeline)

forge uses Claude Code hooks to automatically manage context. No manual loading required.

| Hook | When it fires | What it does |
|------|--------------|-------------|
| **SessionStart** | Session start + after compaction | Injects RULES, INDEX, STATE, BACKLOG, learnings (with confidence decay) |
| **PreToolUse** | Before `git commit` | Checks RULES.md and blocks commits that violate project rules |
| **SessionEnd** | Session ends | Appends timeline entry for session tracking |

This means:
- Every session starts with full context, automatically
- After context compaction, the essential context is re-injected
- Project rules are enforced without relying on the model to remember them
- `/recall` is still available for the full structured briefing, but basic context is always there

---

## Project Rules

Rules are persistent, non-negotiable instructions for your project. They accumulate over time.

```bash
# Add rules
/rule never add co-authored-by to commits
/rule always run lint before committing
/rule use pnpm not npm
/rule never modify files in legacy/ without approval

# View rules
/rule list

# Remove a rule
/rule remove never add co-authored-by to commits
```

Rules are stored in `{project}-context/RULES.md`, git-tracked, and loaded automatically via hooks into every session.

---

## Multi-repo workspaces

forge is built for the way real projects work: multiple repos in one workspace, tightly coupled through APIs, shared types, and deployment dependencies.

```
your-workspace/
  frontend/              # React app
  backend-api/           # Express/FastAPI
  shared-lib/            # Shared types, utils
  worker/                # Background jobs
  project-context/       # forge's persistent brain (tracks ALL repos)
  forge/                 # The tool
```

### The wiki captures integration knowledge

The wiki doesn't just document each repo in isolation. It captures the connections:

- How services call each other (HTTP, SDK, shared DB, message queue)
- Request lifecycle across service boundaries
- Shared data models and where they diverge
- Dependency chains: what to rebuild/restart when something changes
- Cross-service failure modes and how to debug them

The `wiki/architecture/integrations.md` article is the single most valuable artifact for multi-repo debugging.

---

## Skills

forge ships with 8 skills. Each is a detailed prompt (400-960 lines) encoding an autonomous workflow with safety gates, wiki contribution, and escalation rules.

### /compile-wiki

Reads the entire codebase and compiles structured wiki articles optimized for LLM consumption:

- `wiki/architecture/overview.md`: Service topology, ports, dependencies
- `wiki/architecture/integrations.md`: How repos connect (the most valuable article)
- `wiki/architecture/{service}.md`: Per-service deep dive
- `wiki/api/endpoints.md`: Every endpoint with request/response shapes
- `wiki/bugs/{slug}.md`: Investigation articles for known bugs
- `wiki/patterns/`: Recurring patterns discovered during work
- `INDEX.md`: Master index (~2K tokens, loaded by hooks automatically)

The wiki is structured for agents, not humans:
- Tables for reference data (scannable)
- File:line references instead of copied code (verifiable)
- One-line summaries in INDEX.md with specific keywords (routable)
- Self-contained articles (readable without other articles)
- No prose paragraphs longer than 3 sentences (skimmable)

### /review

Pre-landing code review with a structured checklist. Finds real bugs and security issues, not style preferences.

**Checklist categories:**
- SQL/NoSQL injection, command injection, XSS, secret exposure, auth bypass
- Null/undefined access, race conditions, error swallowing, resource leaks
- Missing validation, schema mismatch, missing transactions
- Contract-breaking changes across repos, missing error mapping

Only flags findings at 8/10+ confidence. Reports CRITICAL and HIGH by default.

### /rule

Adds persistent project rules. Rules are loaded by hooks into every session and enforced on git commits automatically. See [Project Rules](#project-rules).

### /status

Checks every service, every repo's git state, test results. Cross-references with known issues.

### /recall

Full structured session briefing: stack health, known issues, what not to retry, remaining work. Waits for direction.

### /checkpoint

Captures complete session state: git state across all repos, what was done, what failed and **why**, decisions made, remaining work. The "What Failed" section prevents future sessions from retrying dead ends.

### /investigate

Systematic root cause analysis. No fixes without root cause. 3-strike escalation rule. Scope-locks to the affected repo.

### /test-fix

The main autonomy skill. Run it and walk away. Runs tests, investigates failures, fixes with atomic commits, verifies fixes. Self-regulates with WTF-likelihood scoring. 20-fix hard cap.

---

## The Knowledge Base

### How it compounds

```
Session 1:   /compile-wiki reads codebase -> writes 15 wiki articles
Session 2:   /test-fix finds bug -> writes wiki/bugs/worker-crash.md
Session 3:   /investigate traces root cause -> updates the bug article
Session 4:   New session reads INDEX.md (via hooks) -> skips re-investigation
Session 10:  Wiki has 50+ articles. Deep context on demand.
Session 20:  Agent knows every decision, every past bug, every failed approach.
```

### Learnings with confidence decay

Learnings are institutional knowledge stored in `LEARNINGS.jsonl`. Each entry has a confidence score (1-10). Confidence decays by 1 point per 30 days. A learning scored 8 two months ago has effective confidence 6. Learnings below confidence 3 are filtered out when loaded.

This prevents stale advice from six months ago carrying the same weight as yesterday's discovery.

### Structure

```
{project}-context/
  INDEX.md                      # Master index (loaded by hooks, ~2K tokens)
  STATE.md                      # Live health of all services/repos
  BACKLOG.md                    # Known issues + what was tried
  RULES.md                      # Project rules (loaded by hooks)
  LEARNINGS.jsonl               # Institutional knowledge (confidence-decayed)
  timeline.jsonl                # Skill event history
  SESSIONS/                     # Session checkpoint files
  wiki/
    architecture/               # Service topology, internals, data flow, integrations
    api/                        # Endpoints, error codes, contracts
    bugs/                       # Per-issue investigation articles
    decisions/                  # Architectural decision records
    patterns/                   # Recurring patterns and approaches
  raw/                          # Source material for compilation
```

All layers are git-tracked. Every update is a commit. Full history and diffs.

---

## Safety

forge is designed to be left alone. Every autonomous skill has explicit safety gates:

| Gate | What it prevents |
|------|-----------------|
| **Root cause required** | No fixes without confirmed root cause. No guessing. |
| **3-strike rule** | 3 failed attempts on same bug -> stop, log, move on |
| **20-fix cap** | Hard stop at 20 fixes per session |
| **WTF-likelihood** | Risk score every 5 fixes. >20% -> stop and report |
| **Regression check** | Full re-run after fixes. Fixes must not break passing tests |
| **Scope lock** | Edits restricted to affected repo/directory |
| **Atomic commits** | One commit per fix. Each independently revertable |
| **Never retry** | Reads BACKLOG first. Won't retry documented failed approaches |
| **Never merge** | Creates commits. Never merges or pushes without approval |
| **Rule enforcement** | Pre-commit hook checks RULES.md and blocks violations |

---

## Persistence layers

| Layer | File | Purpose |
|-------|------|---------|
| **Index** | `INDEX.md` | Navigate the wiki (loaded by hooks) |
| **State** | `STATE.md` | Current health of all services and repos |
| **Backlog** | `BACKLOG.md` | Known issues + what was tried (prevents retry loops) |
| **Rules** | `RULES.md` | Project-specific instructions (loaded by hooks) |
| **Wiki** | `wiki/**/*.md` | Deep knowledge articles |
| **Learnings** | `LEARNINGS.jsonl` | Institutional knowledge (confidence-decayed) |
| **Timeline** | `timeline.jsonl` | Skill event history |
| **Checkpoints** | `SESSIONS/*.md` | Session snapshots |

---

## Make it your own

forge is designed to be cloned, adapted, and extended. Here's how to get started with your own project.

### 1. Clone into your workspace

```bash
cd your-workspace     # the directory that contains your repos
git clone https://github.com/vakra-dev/forge.git
./forge/setup
```

### 2. Fill in your CLAUDE.md

Setup creates a template at `CLAUDE.md`. Fill in your architecture, repos, ports, and test commands. This is how forge learns the shape of your project.

### 3. Build the knowledge base

```bash
/compile-wiki
```

This reads your entire codebase and compiles a structured wiki. The wiki is optimized for LLM consumption: scannable tables, file:line references, one-line summaries for routing.

### 4. Add your rules

```bash
/rule always run tests before committing
/rule use pnpm not npm
/rule never force push to main
```

Rules persist across sessions and are enforced automatically via hooks.

### 5. Start working

From here, forge is self-sustaining. Every session loads context automatically. Every skill updates the wiki as a side effect. The knowledge base compounds.

### Adapting the skills

All skills are plain markdown files in `forge/commands/`. Read them, modify them, add new ones. They're detailed prompts (400-960 lines) encoding autonomous workflows. You can:

- **Edit a skill** to match your workflow (e.g., change the test-fix safety caps)
- **Add a new skill** by creating a `.md` file in `commands/` with YAML frontmatter
- **Remove skills** you don't need (delete the file, re-run setup)

### Adapting the hooks

Hook scripts live in `forge/hooks/`. They're plain bash. Edit them to match your stack:

- **session-init.sh**: Change what context loads at session start
- **pre-commit-check.sh**: Add custom pre-commit validations
- **session-end.sh**: Add custom session-end behavior

### Keeping forge updated

```bash
cd forge && git pull && ./forge/setup
```

Your context repo is untouched (it's a separate git repo). Updates only affect skill prompts and hooks.

### Architecture

forge separates the tool from the data:
- **`forge/`**: Generic framework. Clone it, update it, fork it.
- **`{project}-context/`**: Your project's persistent brain. Created by setup, owned by you.

---

## Project structure

```
forge/
  README.md                     # This file
  LICENSE                       # MIT
  setup                         # Setup script (creates context, links commands, wires hooks)
  commands/                     # Skill prompts (8 files)
    status.md                   #   Health dashboard
    recall.md                   #   Session briefing
    checkpoint.md               #   Save session state
    compile-wiki.md             #   Knowledge base compiler
    investigate.md              #   Root cause debugging
    test-fix.md                 #   Autonomous test-fix loop
    review.md                   #   Pre-landing code review
    rule.md                     #   Add project rules
  hooks/                        # Claude Code hook scripts
    session-init.sh             #   Auto-load context on session start
    pre-commit-check.sh         #   Enforce rules on git commits
    session-end.sh              #   Log session to timeline
  templates/                    # Templates for context repo initialization
    CLAUDE.md.tmpl
    STATE.md.tmpl
    BACKLOG.md.tmpl
    INDEX.md.tmpl
    RULES.md.tmpl
```

---

## Contributing

forge is open source and contributions are welcome. The best way to contribute:

1. **Use it.** The most valuable feedback comes from real projects.
2. **File issues.** Bug reports, feature requests, workflow improvements.
3. **Submit PRs.** New skills, hook improvements, wiki structure enhancements.
4. **Share your experience.** How you adapted forge for your workflow helps others.

## Credits

forge builds on ideas from [gstack](https://github.com/garrytan/gstack), [everything-claude-code](https://github.com/nicobailey/everything-claude-code), [Karpathy's LLM Knowledge Bases](https://x.com/karpathy/status/1924490451796930886), and [beads](https://github.com/gastownhall/beads).

---

## License

[MIT](LICENSE). Free to use, fork, modify, distribute.

Built by [vakra-dev](https://vakra.dev).
