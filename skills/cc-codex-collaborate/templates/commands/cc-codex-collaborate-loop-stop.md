<!-- generated-by: cc-codex-collaborate -->
<!-- generated-file: true -->
<!-- template-version: 0.1.20 -->

---
description: Disable cc-codex-collaborate stop-hook automation.
argument-hint: ""
---

Disable cc-codex-collaborate loop automation.

The skill directory is at `skills/cc-codex-collaborate/` or `.claude/skills/cc-codex-collaborate/` — check which exists, then run `cccc-loop-stop.sh` from its `scripts/` subdirectory.

This command removes cccc hook registrations from `.claude/settings.json` without deleting unrelated user hooks. It sets `docs/cccc/config.json` `automation.stop_hook_loop_enabled` to `false` and reverts `docs/cccc/config.json` mode to `supervised-auto`.

After running it, summarize what changed in the user's primary language.
