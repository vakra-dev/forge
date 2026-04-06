# /status -- Quick Health Check

You are running a read-only diagnostic across the entire workspace. Do NOT modify any code or files (except appending to timeline.jsonl at the end).

---

## Preamble -- Load Context

Find the context directory. Look for a directory matching `*-context/` in the workspace root.

```bash
CONTEXT_DIR=$(ls -d *-context/ 2>/dev/null | head -1)
echo "CONTEXT: ${CONTEXT_DIR:-NONE}"
```

If no context directory found, say: "No forge context found. Run `./forge/setup` first." and stop.

Read the current state:

```bash
cat "${CONTEXT_DIR}STATE.md" 2>/dev/null || echo "NO STATE FILE"
```

Read known issues (just the headings, not full content):

```bash
grep "^### " "${CONTEXT_DIR}BACKLOG.md" 2>/dev/null || echo "NO BACKLOG"
```

Read recent activity:

```bash
tail -5 "${CONTEXT_DIR}timeline.jsonl" 2>/dev/null || echo "NO TIMELINE"
```

---

## Step 1: Check running services

Hit every health endpoint in the workspace. Common ports for web services: 3000-9999, and specifically any ports mentioned in STATE.md or CLAUDE.md.

```bash
echo "=== SERVICE HEALTH ==="
# Check common ports from CLAUDE.md / STATE.md
for port in 6001 6002 6003 6004 6005 6006; do
  STATUS=$(curl -sf -o /dev/null -w "%{http_code}" "http://localhost:$port/health" 2>/dev/null || echo "000")
  if [ "$STATUS" = "000" ]; then
    echo "  :$port  DOWN"
  else
    echo "  :$port  HTTP $STATUS"
  fi
done

# Check MongoDB if relevant
mongosh --eval "db.runCommand({ping:1})" --quiet 2>/dev/null && echo "  MongoDB: UP" || echo "  MongoDB: DOWN or not installed"
```

If the project has a `/ready` endpoint (reader-api style), check that too:

```bash
echo ""
echo "=== READINESS ==="
curl -sf http://localhost:6002/ready 2>/dev/null || echo "Reader API ready check: unavailable"
```

---

## Step 2: Check git status across repos

For every directory in the workspace that is a git repo:

```bash
echo ""
echo "=== REPO STATUS ==="
for dir in */; do
  if [ -d "$dir/.git" ]; then
    BRANCH=$(cd "$dir" && git branch --show-current 2>/dev/null || echo "?")
    DIRTY=$(cd "$dir" && git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
    LAST_COMMIT=$(cd "$dir" && git log --oneline -1 2>/dev/null || echo "no commits")
    echo "  ${dir%/}: branch=$BRANCH dirty=$DIRTY last=\"$LAST_COMMIT\""
  fi
done
```

---

## Step 3: Check latest test results

Look for test result files:

```bash
echo ""
echo "=== TEST RESULTS ==="
# Check for forge e2e results
if [ -f tests/e2e/results/latest.json ]; then
  node -e "
    const r = JSON.parse(require('fs').readFileSync('tests/e2e/results/latest.json','utf8'));
    console.log('E2E Run:', r.timestamp);
    console.log('  Pass:', r.summary.pass, '/', r.config.totalUrls);
    console.log('  Partial:', r.summary.partial);
    console.log('  Fail:', r.summary.fail);
    console.log('  Crash:', r.summary.crash);
  " 2>/dev/null || echo "  Could not parse e2e results"
else
  echo "  No e2e results found"
fi
```

---

## Step 4: Present summary

Compile everything into a clean summary:

```
WORKSPACE STATUS
========================================

Services:
  [port]: [UP/DOWN/NOT READY]
  ...

Repos:
  [name]: [branch] [clean/dirty] [last commit]
  ...

Tests:
  Last e2e run: [timestamp or "never"]
  Pass rate: [X/Y or "no data"]

Known Issues: [count from BACKLOG]
  [list issue titles]

Recent Activity:
  [last 3 timeline entries]
========================================
```

If any services are down or tests are failing, highlight those prominently.

---

## Step 5: Log to timeline

```bash
echo '{"skill":"status","event":"completed","ts":"'$(date -u +%Y-%m-%dT%H:%M:%SZ)'","outcome":"success"}' >> "${CONTEXT_DIR}timeline.jsonl"
```

---

## Completion

Report:
- **DONE** -- all checks completed, summary presented
- **DONE_WITH_CONCERNS** -- some services down, tests failing, or issues found
