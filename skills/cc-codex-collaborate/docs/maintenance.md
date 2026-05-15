# Maintenance & Resume

This document defines maintenance commands and the resume workflow for paused states.

## Maintenance commands

### reset / reset state

Reset state machine runtime state. Run `cccc-reset.sh`. Uses `cccc-rehydrate-state.py` to infer current milestone from planning docs, reviews, and git history. Does NOT delete planning docs, reviews, or logs. Always creates backup.

### doctor

Diagnose installation, config, hooks, Codex, gates, and context. Run `cccc-doctor.py`. Outputs PASS/WARN/FAIL with fix suggestions. Does NOT modify files.

### rebuild-context

Rebuild context-bundle.md. Run `cccc-build-context.sh`. Does NOT modify milestone status or run Codex.

### gates

Show plan/milestone/final/safety/testing gate status. Run `cccc-gates.py`. Does NOT modify files.

### repair

Auto-fix safe inconsistencies: deprecated state fields, missing hooks, missing commands, recoverable milestone ID, missing context. Run `cccc-repair.sh`. Backs up before modifying. Does NOT bypass Codex gates, safety pauses, NEEDS_SECRET, SENSITIVE_OPERATION, or UNSAFE.

### trace

Show recent state machine events from logs, reviews, and decision log. Run `cccc-trace.py`. Does NOT modify files.

### dev-smoke

Developer self-test: JSON validation, shell syntax, Python compile, core file existence, script executability. Run `cccc-dev-smoke.sh`. Does NOT modify user files.

### codex-check

Check Codex CLI availability. Run `cccc-codex-check.sh`.

## Resume command

When invoked with `resume`, Claude Code must recover a paused workflow without bypassing safety rules.

### Resume flow

1. Read `docs/cccc/config.json` and `docs/cccc/state.json`.
2. Explain why the workflow is paused (status + pause_reason).
3. If the status allows automatic resume (e.g. `READY_TO_CONTINUE`), call `cccc-resume.sh` and continue the state machine.
4. If the status requires user confirmation or answers, use the user's primary language with brainstorm-style options.
5. After user confirms:
   - Write to `docs/cccc/decision-log.md`
   - Update `docs/cccc/open-questions.md` if applicable
   - Update `docs/cccc/state.json`:
     - `previous_status` = old status
     - `status` = `READY_TO_CONTINUE`
     - `resume_reason` = reason for resuming
     - `resume_strategy` = selected strategy
     - `last_resumed_at` = UTC timestamp
     - `stop_hook_continuations` = 0
     - `pause_reason` = null
   - Do NOT mark any milestone as passed.
   - Do NOT mark the task as DONE.
   - Do NOT mark any Codex gate as pass.
6. If `config.mode = full-auto-safe` and `automation.stop_hook_loop_enabled = true`:
   - Resume must immediately continue executing the state machine.
   - Do not just output "resumed" and stop.
7. If `mode != full-auto-safe`:
   - After resume, output next-step suggestions. Do not force auto-continue.

### Safe resume rules by status

**PAUSED_FOR_HUMAN / NEEDS_HUMAN:**
- If `pause_reason` or `open-questions.md` has unanswered questions, ask the user first.
- Brainstorm-style options: A. recommended approach, B. conservative approach, C. skip milestone, D. continue with risk recorded, E. free input.
- After answer: write decision-log, update open-questions, set status to `READY_TO_CONTINUE`.
- Do NOT mark milestone as passed. Must re-enter the appropriate gate (e.g. Codex review).

**PAUSED_FOR_CODEX:**
- Run `cccc-codex-check.sh` first.
- If Codex is still unavailable: remain `PAUSED_FOR_CODEX`, output reason.
- If Codex is available: clear `codex_unavailable_reason`, set status to `READY_TO_CONTINUE`.
- Must re-run the missing Codex gate (plan/milestone/final review). Resume does NOT skip Codex.

**PAUSED_FOR_SYSTEM:**
- Remind user that a system/API error caused the pause.
- Options: A. checked logs, continue, B. view StopFailure logs, C. exit, D. free input.
- User must explicitly confirm. If no confirmation, do not continue.
- On continue: record in decision-log, reset `stop_hook_continuations = 0`, set `READY_TO_CONTINUE`.

**NEEDS_SECRET:**
- Default: cannot resume.
- Remind user: do NOT send real secrets, API keys, wallet private keys, or seed phrases to Claude.
- Options: A. configured locally, continue, B. use mock/dummy/test fixture, C. skip milestone, D. exit.
- If A or B: record decision-log (NO secret values), set `READY_TO_CONTINUE`.
- If C: mark milestone as blocked/skipped, record risk.

**SENSITIVE_OPERATION / UNSAFE:**
- Default: do not auto-resume.
- Options: A. remain paused, B. switch to safe alternative, C. confirm safe local test, D. skip milestone, E. free input.
- Prohibited resume: real money, mainnet transactions, real wallet keys, production deployments, destructive irreversible operations.
- Unless user provides a safe alternative, remain paused.

**FAIL_UNCLEAR / REVIEW_THRESHOLD_EXCEEDED:**
- Options: A. pause for manual intervention, B. extend review budget +1 round, C. record risk and proceed, D. skip milestone, E. free input.
- If B: increase review budget, record decision-log, set `READY_TO_CONTINUE`.
- If C or D: must record known risk. Cannot skip P0/P1 security issues.

### Non-interactive resume

The resume script supports non-interactive arguments:
- `--confirm`: confirm the resume action
- `--strategy recommended`: use recommended approach
- `--strategy mock`: use mock/dummy secrets
- `--strategy skip`: skip current milestone
- `--strategy extend-review`: extend review budget +1

### Resume script

Run:
```bash
.claude/skills/cc-codex-collaborate/scripts/cccc-resume.sh [--confirm] [--strategy <strategy>]
```

The script only updates state and outputs guidance. It does NOT execute Codex review or implement code. The actual continuation is driven by the SKILL.md state machine.
