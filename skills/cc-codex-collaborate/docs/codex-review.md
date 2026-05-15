# Codex Review

This document defines mandatory Codex gates, the adversarial plan review process, context bundle rules, and Codex plan review criteria.

## Mandatory Codex Gates

**This is a P0 invariant. Codex review is NEVER optional.**

Rules:

1. Claude Code MUST NOT begin implementation until Codex adversarial plan review has passed (or been bypassed with Claude adversarial review).
2. Claude Code MUST NOT mark a milestone as passed until Codex milestone review has passed (or been bypassed with Claude adversarial review).
3. Claude Code MUST NOT mark the whole task as completed until Codex final review has passed (or been bypassed with Claude adversarial review).
4. If Codex is unavailable, misconfigured, fails to run, or returns invalid JSON, Claude Code MUST check `config.codex.unavailable_policy` and follow the configured strategy.
5. Claude Code MUST NOT silently skip Codex review, even for trivial tasks.
6. For trivial tasks, Claude may use a lightweight plan and milestone, but Codex review is still required.
7. Self-checks such as cat, tests, lint, or build are NOT a substitute for Codex review.
8. A milestone can only be marked passed if there is a valid Codex review artifact with `status = pass` or a Claude adversarial bypass review artifact with `status = pass` for that milestone and review round.
9. If no Codex review artifact or approved bypass review exists, the only valid next action is to run Codex review, run bypass review, or pause.
10. Any final summary must mention the Codex review file or bypass review file used to approve the milestone.
11. Bypass review results are marked as `lower_assurance`. They do NOT count as Codex pass.
12. Critical-risk scenarios MUST NOT be bypassed.

**Invariants (memorize these):**

```text
No Codex plan review, no implementation.
No Codex milestone review, no milestone pass.
No Codex final review, no task completion.
Codex unavailable means pause, not skip.
```

**Before implementation:**

- Run `.claude/skills/cc-codex-collaborate/scripts/cccc-codex-check.sh` to verify Codex availability.
- Run `.claude/skills/cc-codex-collaborate/scripts/cccc-assert-codex-gates.py assert-plan-approved` to verify plan approval.
- If assertion fails, you MUST pause with `status = PAUSED_FOR_CODEX`.

**Before marking milestone passed:**

- Run `cccc-assert-codex-gates.py assert-milestone-approved`.
- If assertion fails, run `cccc-codex-milestone-review.sh` and wait for result.
- If review fails, fix and re-review. Do NOT skip.

**Before marking task DONE:**

- Run `cccc-assert-codex-gates.py assert-final-approved`.
- If assertion fails, run `cccc-codex-final-review.sh`.
- Only proceed to DONE if final review passes.

## Codex adversarial plan review

Codex must review the initial plan adversarially before implementation begins.

Codex should try to reject the plan by finding:

- misunderstood requirements
- missing project context
- unsafe assumptions
- milestones that are too large
- untestable acceptance criteria
- architecture conflicts
- security gaps
- secret-handling risks
- production, wallet, API key, or real-money risks
- missing human decisions

Only approve if the roadmap is clear, safe, scoped, testable, and aligned with the discovered project.

## Context bundle rule

Before every Codex call, regenerate:

```text
docs/cccc/context-bundle.md
```

The context bundle must include:

1. user language (from config.json)
2. original user task
3. current state
4. project map
5. architecture summary
6. test strategy
7. roadmap
8. milestone backlog status
9. completed milestones
10. current milestone
11. acceptance criteria
12. decision log summary
13. open questions
14. risk register
15. git status
16. diff summary
17. relevant diff
18. test output
19. last review result
20. current config thresholds

Hard rule:

```text
No context bundle, no Codex planning.
No project discovery, no roadmap.
No approved roadmap, no implementation.
No config.json, run setup first.
```
