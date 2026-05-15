# Codex Review Budget and Frequency

This document defines the review budget system, frequency policy, fingerprint cache, and checkpoint support.

Codex review frequency is controlled by `config.codex_review_policy`.

## Rules

1. Do not call Codex for obvious local failures before Claude fixes them.
2. Use the smallest sufficient review level (self-check, adversarial, targeted, full context).
3. Use targeted or diff-only context when full context is unnecessary.
4. Use batched Codex review for low-risk milestones when policy allows.
5. Use Claude adversarial review between Codex reviews when policy allows.
6. Mark Claude-only reviews as lower assurance.
7. High-risk and critical-risk changes must not silently bypass Codex.
8. Use review fingerprint cache to avoid repeated Codex calls on identical diffs.
9. Prefer reviewing diff since last Codex-approved checkpoint.

## Review levels

| Level | Codex? | Description |
| --- | --- | --- |
| `claude_self_check` | No | Claude self-check only |
| `claude_adversarial` | No | Claude adversarial review (lower assurance) |
| `codex_targeted` | Yes | Codex reviews targeted diff + tests |
| `codex_full_context` | Yes | Codex reviews full context bundle |

## Review frequency by risk

| Risk | Default frequency |
| --- | --- |
| Low | Every 3 milestones (Balanced), every 5 (Budget) |
| Medium | Every 2 milestones |
| High | Every milestone |
| Critical | Every milestone |
| Plan review | Always Codex |
| Final review | Always Codex |

## codex-budget command

```bash
python3 .claude/skills/cc-codex-collaborate/scripts/cccc-codex-budget.py
```

Shows: policy mode, calls this run, pending batch, checkpoint status, recommendations.

## review-now command

```bash
.claude/skills/cc-codex-collaborate/scripts/cccc-review-now.sh [current|batch|full]
```

Forces immediate Codex review. Does not bypass safety limits.

## checkpoint command

```bash
.claude/skills/cc-codex-collaborate/scripts/cccc-checkpoint.sh [status|record|commit]
```

- `status`: Show checkpoint status and diff since last approved commit.
- `record`: Record current HEAD as Codex-approved checkpoint (no git commit).
- `commit`: Create a git checkpoint commit after user confirmation.

## review-policy decision script

Before each review, run:
```bash
python3 .claude/skills/cc-codex-collaborate/scripts/cccc-review-policy.py --gate=<gate>
```

Returns decision: `run_codex_full_context`, `run_codex_targeted`, `skip_codex_use_claude_adversarial`, `batch_pending`, `cache_hit`, `budget_exhausted`.
