<!-- generated-by: cc-codex-collaborate -->
<!-- generated-file: true -->
<!-- template-version: 0.1.10 -->

---
description: Enable cc-codex-collaborate stop-hook automation and continue an active workflow if one exists.
argument-hint: ""
---

Enable cc-codex-collaborate loop automation.

Execute:

```bash
.claude/skills/cc-codex-collaborate/scripts/cccc-loop-start.sh
```

This command:
1. Installs cccc hook scripts into `.claude/hooks`, registers them in `.claude/settings.json`
2. Sets `docs/cccc/config.json`: `mode = full-auto-safe`, `automation.stop_hook_loop_enabled = true`
3. Sets `docs/cccc/state.json`: `stop_hook_continuations = 0`
4. Checks if an active workflow can be continued and outputs CCCC_WORKFLOW_ACTION markers

After running it, check the CCCC_WORKFLOW_ACTION marker in the output:

- **`continue_now`** — Immediately continue the cc-codex-collaborate state machine. Do not stop after enabling hooks.
- **`needs_resume`** — Suggest or execute `/cc-codex-collaborate resume` to handle the paused workflow.
- **`needs_task`** — No active workflow. Prompt the user to run `/cc-codex-collaborate "task description"`.
- **`done`** — The workflow is already completed. Prompt the user to start a new task.

Summarize what changed in the user's primary language. Remind the user that safety pauses still apply for secrets, wallet keys, production operations, real funds, destructive commands, and unresolved human questions.
