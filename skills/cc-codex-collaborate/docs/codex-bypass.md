# Codex Bypass Mode

This document defines how cc-codex-collaborate handles Codex unavailability and bypass review.

When Codex is unavailable (quota exhausted, CLI not installed, auth failure, API error), the skill can bypass Codex review with Claude Code acting as an adversarial reviewer.

## Config

`config.codex.unavailable_policy` controls behavior:
- `strict_pause`: Always pause, never bypass. Safest.
- `ask_or_bypass_once`: Ask user, allow one-time bypass per gate. Recommended.
- `auto_bypass_low_medium`: Automatically bypass for low/medium risk. High/critical still pause.
- `always_ask`: Always ask user when Codex unavailable.
- `custom`: User-defined policy.

`config.codex.bypass` controls bypass details:
- `enabled`: Whether bypass is allowed.
- `mode`: `once_per_gate` or `auto_low_medium`.
- `require_human_confirmation`: Whether user must confirm bypass.
- `max_consecutive_bypassed_gates`: Max bypasses before forcing Codex.
- `allow_for_high_risk` / `allow_for_critical_risk`: Risk level gating.
- `require_later_codex_recheck`: Whether Codex must recheck later.

## bypass-codex command

Run:
```bash
python3 .claude/skills/cc-codex-collaborate/scripts/cccc-bypass-codex.py [status|once|apply|off]
```

- `status`: Show bypass config and state.
- `once`: Request one-time bypass for current gate. May require user confirmation.
- `apply --gate=<gate> --reason=<reason>`: Apply bypass after Claude adversarial review. Creates artifact in `docs/cccc/reviews/bypass/`.
- `off`: Disable bypass, set `strict_pause`.

## Claude adversarial bypass review

When bypass is used, Claude Code must act as an adversarial reviewer following `prompts/claude-adversarial-bypass-review.md`:
1. Assume the implementation is wrong until proven otherwise.
2. Check acceptance criteria, tests, architecture consistency.
3. Check security, secrets, production, wallet risks.
4. For high/critical risk, prefer `needs_human` or `unsafe`.
5. Mark output as `lower_assurance`.
6. Require later Codex recheck.

## Bypass review artifacts

Stored in `docs/cccc/reviews/bypass/<gate>-claude-bypass-review-<timestamp>.json`.

Gate status values:
- `pass`: Codex reviewed and approved.
- `bypassed`: Claude adversarial bypass review approved (lower assurance).
- `not_run`, `fail`, `needs_human`: No valid review.

`bypassed` is NOT the same as `pass`. It indicates lower assurance.

## codex-recheck command

When Codex becomes available, re-check all bypassed gates:
```bash
.claude/skills/cc-codex-collaborate/scripts/cccc-codex-recheck.sh
```

If Codex passes: remove from `pending_codex_recheck`, update gate status to `pass`.
If Codex fails: pause with `PAUSED_FOR_CODEX_RECHECK_FAILURE`.

## Prohibited bypass scenarios

Bypass is NEVER allowed for:
- Real wallet private keys, seed phrases, keystores
- Real money / mainnet transactions
- Production deployments
- Destructive operations
- Critical risk scenarios
