---
description: Add persistent project rules that are enforced every session
---

# /rule -- Add Project Rules

You are managing the project's persistent rules. Rules are non-negotiable
instructions that apply to every session. They are loaded automatically via
hooks at session start, so every future session follows them without the user
needing to repeat themselves.

## How rules work

Rules live in `{project}-context/RULES.md`. They are:
- **Persistent:** survive across sessions (git-tracked in the context repo)
- **Automatic:** loaded by the SessionStart hook into every session's context
- **Enforceable:** the pre-commit hook checks commit-related rules automatically
- **Cumulative:** each `/rule` adds to the list, never replaces

## Handling the user's input

The user provides a rule as natural language after `/rule`. Examples:
- `/rule never add co-authored-by claude to commits`
- `/rule always run lint and formatter before committing`
- `/rule use pnpm not npm`
- `/rule never modify files in the legacy/ directory`
- `/rule always write tests for new functions`

## Steps

### Step 1: Find the context directory

```bash
CONTEXT_DIR=$(ls -d *-context/ 2>/dev/null | head -1)
if [ -n "$CONTEXT_DIR" ]; then
  echo "CONTEXT_DIR: $CONTEXT_DIR"
else
  echo "CONTEXT_DIR: NONE"
fi
```

**If CONTEXT_DIR is NONE:** Tell the user to run `./forge/setup` first. STOP.

### Step 2: Read existing rules

```bash
CONTEXT_DIR=$(ls -d *-context/ 2>/dev/null | head -1)
echo "=== CURRENT RULES ==="
cat "${CONTEXT_DIR}RULES.md" 2>/dev/null || echo "No RULES.md found"
```

### Step 3: Parse and format the new rule

Convert the user's natural language into a clear, actionable rule statement.

**Formatting guidelines:**
- Start with a verb: "Never", "Always", "Use", "Prefer", "Avoid"
- Be specific and unambiguous
- One rule per line
- Use a bullet point (`- `)

**Examples of well-formatted rules:**
- `- Never add Co-Authored-By lines to git commit messages`
- `- Always run lint and formatter before committing code`
- `- Use pnpm as the package manager, never npm or yarn`
- `- Never modify files in the legacy/ directory without explicit approval`
- `- Always write unit tests for new functions in src/`
- `- Prefer functional style over class-based patterns`
- `- Never commit .env files or secrets`

**Check for duplicates:** If the new rule is semantically the same as an existing
rule, tell the user it already exists. Don't add duplicates.

### Step 4: Append the rule to RULES.md

Append the formatted rule to the end of `{CONTEXT_DIR}RULES.md`.

### Step 5: Commit to context repo

```bash
CONTEXT_DIR=$(ls -d *-context/ 2>/dev/null | head -1)
cd "$CONTEXT_DIR"
git add RULES.md
git commit -m "rule: {brief description of the rule}"
cd ..
```

### Step 6: Confirm

```
RULE ADDED
════════════════════════════════════════
Rule: {the formatted rule}
File: {CONTEXT_DIR}RULES.md
Total rules: {count}

This rule will be loaded automatically in every future session.
════════════════════════════════════════
```

## Listing rules

If the user says `/rule list` or `/rule show`, just display the current rules:

```bash
CONTEXT_DIR=$(ls -d *-context/ 2>/dev/null | head -1)
cat "${CONTEXT_DIR}RULES.md"
```

## Removing rules

If the user says `/rule remove {rule text}`, read RULES.md, find the matching
rule, remove it, and commit. Confirm what was removed.

## Critical Rules

1. **Never replace RULES.md.** Always append. The user's existing rules must be preserved.
2. **One rule per `/rule` invocation.** If the user provides multiple rules at once,
   add them all but confirm each one.
3. **Always commit.** Rules must be git-tracked so they persist.
4. **Be precise.** A vague rule like "write good code" is useless. Ask the user to
   be more specific if the rule is too broad.
