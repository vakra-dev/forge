---
description: Understand large files via a cheap read-only Haiku subagent instead of loading them into the main context
---

# /bulk-read -- Delegate large-file understanding to Haiku

Large files cost the primary model tens of thousands of tokens, and they are
re-sent on every later turn. This skill sends the reading to a cheap, read-only
Haiku subagent. You work from its short answer and read only the exact line
ranges it points you to.

Usage: `/bulk-read <question> -- <path> [<path>...]`
Or invoke it yourself when the forge Read gate blocks a file and you need to
*understand* it.

## When to use it

Use it when ALL of these hold:
- the file(s) are over ~350 lines (the Read gate blocks full reads of them anyway);
- you need to understand something (where is X, how does Y work, what invariants
  does Z hold, how do these files relate) and are not about to edit them yet;
- you can state the question in a sentence or two.

Do NOT use it when:
- you are going to edit the file: read the exact lines with `Read offset/limit`
  (the subagent's `path:start-end` ranges tell you which);
- you already know the symbol: `Grep -n` it and read ~60 lines around it;
- the task is debugging, architecture or safety-critical reasoning that depends on
  exact code: read the relevant lines yourself;
- the file is under ~350 lines: just Read it.

## Steps

### 1. Pin down the question
One or two sentences, specific. Bad: "explain harness_lifecycle.rs". Good: "In
harness_lifecycle.rs, which functions advance the virtual clock, and which
invariants does check_invariants() assert after each step?"

### 2. Spawn ONE read-only Haiku subagent
Use the Agent tool with `subagent_type: "Explore"` (read-only: no Edit/Write) and
`model: "haiku"`. Pass the prompt template below with the question and absolute
paths filled in. If you have several *independent* questions or file groups, send
up to 3 Agent calls in the same message so they run in parallel. Never nest
agents or chain one agent's output into another.

Prompt template:

```
You are a read-only code reader. Answer ONE question about the files below.
Do not modify anything. Do not run builds or tests.

Question: <QUESTION>

Files:
- <ABSOLUTE PATH 1>
- <ABSOLUTE PATH 2>

How to read: use Read with explicit offset and limit (limit up to 1000 lines)
and walk each file in chunks. Use Grep -n to jump to symbols. Do not skip
sections that bear on the question.

Reply in exactly this format, and nothing else:

ANSWER: <direct answer, at most 10 lines>
LOCATIONS:
- <absolute path>:<start>-<end> -- <what is there, one line>
(list every range the main engineer must read to verify or edit; tight ranges)
KEY FACTS: <identifiers, constants, invariants, error messages, quoted verbatim>
NOT FOUND / UNCERTAIN: <anything the question asks that you could not confirm>

Rules: quote identifiers exactly. Give line numbers you actually saw. If you are
guessing, say so under UNCERTAIN. No preamble, no closing remarks.
```

### 3. Work from the answer
- Treat ANSWER and KEY FACTS as a lead, not as proof. Haiku can misread.
- Before you rely on a claim for a decision, an edit, or anything you will report
  to the user, `Read` the cited `path:start-end` range (a few dozen lines) and
  confirm it. Edits always go through your own targeted read.
- Anything under NOT FOUND / UNCERTAIN is unresolved: Grep for it or read the
  likely range yourself.
- If the answer is vague, or ranges look wrong, do not re-delegate in a loop. Fall
  back to Grep plus targeted reads of the outline the Read gate printed.

### 4. Log it
So forge can measure savings, run once per delegation (use the same paths):

```bash
"$CLAUDE_PROJECT_DIR"/forge/hooks/log-bulk-read.sh <path> [<path>...]
```

## Notes
- The subagent's own reads go through the same Read gate. Chunked reads with
  `limit` always pass, which is why the template requires them.
- Cost is Haiku tokens plus 10-30 s latency. It pays off on files of several
  hundred lines or more, and on multi-file questions.
- This project's working model allows only read-only agents. This skill never
  writes code; code generation stays with the primary model.
- Summaries are a navigation aid. When the answer is going into a commit, a lock
  amendment, or a report, cite what you verified yourself.
