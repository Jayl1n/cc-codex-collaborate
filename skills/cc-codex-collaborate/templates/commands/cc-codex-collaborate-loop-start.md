<!-- generated-by: cc-codex-collaborate -->
<!-- generated-file: true -->
<!-- template-version: 0.1.8 -->

---
description: Enable cc-codex-collaborate stop-hook automation for full-auto-safe loop continuation.
argument-hint: ""
---

Enable cc-codex-collaborate loop automation.

Execute:

```bash
.claude/skills/cc-codex-collaborate/scripts/cccc-loop-start.sh
```

This command installs cccc hook scripts into `.claude/hooks`, registers them in `.claude/settings.json`, sets `docs/cccc/config.json` `automation.stop_hook_loop_enabled` to `true`, and sets `docs/cccc/state.json` mode to `full-auto-safe`.

After running it, summarize what changed in the user's primary language. Remind the user that safety pauses still apply for secrets, wallet keys, production operations, real funds, destructive commands, and unresolved human questions.
