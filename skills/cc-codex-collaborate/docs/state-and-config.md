# State & Config

This document defines the config.json vs state.json separation and the runtime workspace layout.

## config.json vs state.json

`docs/cccc/config.json` is the project-level configuration. It stores:

- language settings
- collaboration mode
- planning thresholds
- milestone granularity
- review thresholds
- automation settings
- safety policies
- codex behavior

`docs/cccc/state.json` is runtime state only:

- current milestone
- current status
- review round counts
- pause reason
- completed/blocked milestones
- last context update
- loop continuation count

All planning, review, and milestone thresholds must read from `config.json`. If `config.json` does not exist, prompt the user to run setup first.

## Runtime workspace

`docs/cccc` is generated automatically by setup — no manual creation needed.

```
docs/cccc/
  config.json              # Project configuration
  state.json               # Runtime state
  project-brief.md         # Project brief
  project-map.md           # Project map
  current-state.md         # Current state snapshot
  architecture.md          # Architecture overview
  test-strategy.md         # Test strategy
  roadmap.md               # Roadmap
  milestone-backlog.md     # Milestone backlog
  decision-log.md          # Decision log
  risk-register.md         # Risk register
  open-questions.md        # Open questions
  context-bundle.md        # Context summary (input for Codex reviews)
  doc-index.json           # Document hash tracking for change detection
  reviews/                 # Review records
    bypass/                # Bypass review artifacts
  logs/                    # Runtime logs
  runtime/                 # Runtime temporary files
  backups/                 # Config backups
```

Templates live in `.claude/skills/cc-codex-collaborate/templates/cccc/`.
