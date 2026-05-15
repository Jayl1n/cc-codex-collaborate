# Manual Documentation Sync

This document defines how docs/cccc document changes are detected, synced, and handled.

docs/cccc documents are user-editable. Users may manually modify architecture, roadmap, milestones, risk register, or other planning documents.

## Rules

1. docs/cccc documents are user-editable. Claude Code must not assume state.json is authoritative if docs/cccc documents changed.
2. Before continuing implementation, check docs sync status.
3. High-impact changes to architecture, stack, roadmap, milestone backlog, risk policy, or project brief may invalidate previous planning approval.
4. If planning is invalidated, no implementation is allowed until replan and Codex adversarial plan review pass.
5. sync-docs must ask the user how to apply changes using options plus free input.
6. Never silently ignore architecture or stack changes.
7. Never continue old milestones if docs say architecture or roadmap changed.
8. doc-index.json tracks file hashes for change detection. It is updated by sync-docs, not manually.

## sync-docs command

Run:
```bash
python3 .claude/skills/cc-codex-collaborate/scripts/cccc-sync-docs.py [--strategy=<strategy>]
```

If changes are detected and no `--strategy` is provided, output `SYNC_AWAITING_DECISION=true` and ask the user with brainstorm-style options:

- A. Adopt docs as new source of truth, invalidate old plan, replan (Recommended for high/critical impact)
- B. Only update context-bundle (safe for low impact)
- C. Pause workflow
- D. Ignore changes, only update doc-index
- E. View detailed diff
- F. Custom input

Strategies: `adopt_and_replan`, `context_only`, `pause`, `ignore`, `view_diff`.

## diff-docs command

Read-only. Run:
```bash
python3 .claude/skills/cc-codex-collaborate/scripts/cccc-diff-docs.py
```

## replan command

Run:
```bash
.claude/skills/cc-codex-collaborate/scripts/cccc-replan.sh
```

Replan must:
1. Re-read the project and docs/cccc documents.
2. Update roadmap.md, milestone-backlog.md, current-state.md.
3. Perform Claude planning self-review.
4. Run Codex adversarial plan review.
5. If Codex plan review passes: `roadmap_status = codex_approved`, `planning_invalidated_by_doc_change = false`, `status = READY_TO_CONTINUE`.
6. If Codex rejects or needs_human: set appropriate pause status. No implementation.

Replan should NOT auto-implement code unless: mode = full-auto-safe, loop enabled, Codex plan review pass, no pause_reason, and user explicitly allows.
