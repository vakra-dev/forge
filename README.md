# forge

Autonomous engineering framework for Claude Code. Clone it into any workspace, run setup, and get: a knowledge base that compounds across sessions, skills that test/debug/fix autonomously, and persistent context that survives session boundaries.

## Quick start

```bash
# Clone into your workspace
cd your-workspace
git clone https://github.com/vakra-dev/forge.git

# Run setup
./forge/setup

# Start using
/status          # Check your stack health
/compile-wiki    # Build knowledge base from your codebase
/test-fix        # Autonomous test -> fix loop
/investigate     # Root cause debugging
/checkpoint      # Save session state
/resume          # Load session state
```

## What it does

**Knowledge base:** An LLM-compiled wiki of your entire project. Architecture, APIs, bugs, decisions, patterns. The LLM maintains it. Every session's work compounds into it. Inspired by [Karpathy's LLM Knowledge Bases](https://x.com/karpathy) pattern.

**Autonomous skills:** Commands that run multi-step workflows with safety gates. `/test-fix` runs your test suite, investigates failures, fixes bugs, verifies fixes, and loops. `/investigate` does root cause debugging with a 3-strike escalation rule. Each skill updates the knowledge base as it works.

**Session persistence:** Checkpoints, learnings, and timeline survive across sessions. When you start a new session, `/resume` loads full context. No cold starts.

## How it works

forge creates two things in your workspace:

1. **`{project}-context/`** -- A git-tracked knowledge base (separate repo). Contains wiki articles, state, backlog, learnings, session checkpoints.
2. **`.claude/commands/`** -- Claude Code command files that encode autonomous workflows.

The context repo is your project's persistent memory. The commands are the skills that read and write to it. Every session compounds into the knowledge base.

## Architecture

```
your-workspace/
  forge/                    # The tool (this repo)
    commands/               # Skill prompts
    templates/              # Templates for context repo
    setup                   # Setup script

  {project}-context/        # Created by setup (separate git repo)
    INDEX.md                # Navigate the wiki
    STATE.md                # Service health
    BACKLOG.md              # Known issues
    LEARNINGS.jsonl         # Institutional knowledge
    wiki/                   # LLM-compiled articles
    SESSIONS/               # Checkpoints

  .claude/commands/         # Symlinked from forge/commands/
  CLAUDE.md                 # Project-specific routing
```

## Skills

| Skill | What it does |
|-------|-------------|
| `/status` | Quick health check across all services and repos |
| `/resume` | Load session context, present briefing, do not start working |
| `/checkpoint` | Save session state, update wiki, commit to context repo |
| `/compile-wiki` | Build/refresh knowledge base from codebase |
| `/investigate` | Root cause debugging. Iron law: no fixes without root cause |
| `/test-fix` | Autonomous test -> investigate -> fix -> verify loop |

## Inspired by

- [gstack](https://github.com/garrytan/gstack) -- Garry Tan's AI engineering framework
- [Karpathy's LLM Knowledge Bases](https://x.com/karpathy) -- LLM-compiled wikis that compound
- [beads](https://github.com/gastownhall/beads) -- Persistent memory for AI agents

## License

MIT
