# Testing Policy

This document defines review thresholds, testing expectations, and quality gates.

## Thresholds

Thresholds are stored in `docs/cccc/config.json`. Read them from there, not from state.json.

Default thresholds (recommended preset):

```json
{
  "planning": {
    "max_plan_review_rounds": 3
  },
  "milestones": {
    "max_milestones_per_run": 5,
    "max_diff_lines_per_milestone": 1200,
    "max_changed_files_per_milestone": 20
  },
  "review": {
    "max_review_rounds_per_milestone": 3,
    "max_fix_attempts_per_milestone": 3,
    "block_on_p0": true,
    "block_on_p1": true,
    "allow_continue_with_p2": true
  },
  "automation": {
    "stop_hook_loop_enabled": false,
    "max_stop_hook_continuations": 10
  }
}
```

Supported modes:

- `manual`: pause after each major phase.
- `supervised-auto`: default. Planning is strictly reviewed; implementation can loop automatically until risk or threshold.
- `full-auto-safe`: optional Stop hook can continue safe unfinished work, but never bypass hard pause conditions.

## Quality gates

- Every milestone must have testable acceptance criteria.
- Tests must pass before Codex review.
- P0 issues always block progression.
- P1 issues block unless `allow_continue_with_p2` is true and the issue is P1-only.
- Review threshold exceeded requires human decision (see [[maintenance]]).

## User language rule

Before planning or asking any question, detect the user's primary language.

Detection priority:

1. `config.json` `language.user_language` if not `"auto"`.
2. Explicit user preference.
3. Latest user instruction language.
4. Main task language if the message is mixed.
5. If still unclear, default to the language of the most recent user message.

Store it in `docs/cccc/config.json` as `language.user_language`.

All human-facing output must use `user_language`. Codex may reason in English, but Claude Code must summarize and ask questions in the user's language.
