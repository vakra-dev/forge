---
description: Answer questions about large files with one cheap Haiku call; only the short answer enters your context
---

```bash
"$CLAUDE_PROJECT_DIR"/forge/scripts/bulk-read --question "<question>" --paths <file1> [<file2> ...]
```

Use it when answering needs most of a large file, or spans 3+ files / ~1500+ lines combined.
For "where is X" or one symbol, `Grep -n` plus `Read` with offset/limit is cheaper: do that.

Each call is independent. For a follow-up, ask again with the same `--paths`; the files go to
the worker, never into your context.

The answer cites `path:start-end`. `Read` those ranges (a few dozen lines) before editing,
or before relying on an exact value.
