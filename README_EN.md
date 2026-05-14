# CCCC — Claude Code × Codex Collaboration Engine

<p align="center">
  <strong>Version</strong> 0.1.2 &nbsp;|&nbsp; <strong>Short name</strong> CCCC &nbsp;|&nbsp; <strong>License</strong> MIT
</p>

<p align="center">
  <a href="./README.md">中文</a>
</p>

---

**CCCC** (cc-codex-collaborate) is a Claude Code skill that coordinates Claude Code and Codex in a safe, milestone-based engineering loop.

Claude Code discovers the project, builds the plan, implements milestones, fixes issues, and manages state. Codex acts as an independent read-only reviewer that challenges the initial plan, reviews each milestone, and proposes safe next steps. Human input is required for ambiguity, sensitive operations, real secrets, production changes, real money, or threshold failures.

---

## What it does

Turns a coding task into a controlled collaboration loop:

1. **Detect language** — Identify the user's primary language and use it throughout.
2. **Discover project** — Understand the existing codebase and architecture before planning.
3. **Build context** — Generate project context files under `docs/cccc`.
4. **Draft roadmap** — Create a roadmap and milestone backlog.
5. **Self-review** — Claude Code performs its own planning self-review.
6. **Adversarial review** — Codex challenges the plan in read-only mode.
7. **Safe start** — Implementation begins only after the plan is safe and approved.
8. **One milestone at a time** — Implement a single milestone per iteration.
9. **Independent review** — Codex reviews the current diff in read-only mode.
10. **Fix and iterate** — Fix → re-review → proceed to the next milestone, until complete or a pause condition triggers.

## Design principles

| Principle | Description |
| --- | --- |
| **Claude Code leads** | Claude Code is the sole orchestrator and implementer |
| **Codex reviews only** | Codex is read-only and adversarial — it never modifies code |
| **Humans own sensitive decisions** | Sensitive operations require human confirmation |
| **Understand before planning** | No project planning without project discovery |
| **Context first** | No Codex planning without `context-bundle.md` |
| **Review before code** | No implementation without self-review + adversarial review |
| **Safety gates** | Secrets, money, production, and destructive ops cannot auto-continue |

## Runtime workspace

`docs/cccc` is generated automatically on first use — no manual setup needed.

```
docs/cccc/
  state.json              # Runtime state
  project-brief.md        # Project brief
  project-map.md          # Project map
  current-state.md        # Current state snapshot
  architecture.md         # Architecture overview
  test-strategy.md        # Test strategy
  roadmap.md              # Roadmap
  milestone-backlog.md    # Milestone backlog
  decision-log.md         # Decision log
  risk-register.md        # Risk register
  open-questions.md       # Open questions
  context-bundle.md       # Context summary (input for Codex reviews)
  reviews/                # Review records
  logs/                   # Runtime logs
  runtime/                # Runtime temporary files
```

Templates live in `.claude/skills/cc-codex-collaborate/templates/cccc/`.

## Installation

Install the skill directory into your target project:

```
.claude/skills/cc-codex-collaborate/
```

The release zip does not include the following runtime directories — they are generated on demand:

```
.claude/commands/
.claude/hooks/
docs/cccc/
```

## Quick start

### 1. First-time setup

```text
/cc-codex-collaborate setup
```

Setup generates or verifies the following:

```
.claude/commands/
  cc-codex-collaborate-loop-status.md
  cc-codex-collaborate-loop-start.md
  cc-codex-collaborate-loop-stop.md

docs/cccc/
  state.json, project-brief.md, project-map.md, ...
  reviews/, logs/, runtime/
```

Setup **does not overwrite** existing files and **does not enable** hooks. After completion, it reports what was generated, what was preserved, hook status, and basic usage.

### 2. Run a task

```text
/cc-codex-collaborate "your task description"
```

## Command reference

### Main commands

```text
/cc-codex-collaborate <task>       Start the full collaboration loop
/cc-codex-collaborate setup        First-time initialization
/cc-codex-collaborate init <task>  Initialize a task only (no loop)
/cc-codex-collaborate plan         Generate/update the plan
/cc-codex-collaborate plan-review  Trigger plan review
/cc-codex-collaborate run          Run the current milestone
/cc-codex-collaborate review       Trigger milestone review
/cc-codex-collaborate status       Show current status
/cc-codex-collaborate resume       Resume an interrupted task
```

### Loop automation commands

After setup, these shortcut commands are available:

| Command | Purpose |
| --- | --- |
| `/cc-codex-collaborate-loop-status` | Show `docs/cccc` status, loop mode, and hook configuration |
| `/cc-codex-collaborate-loop-start` | Enable Stop-hook auto-continuation (`full-auto-safe` mode) |
| `/cc-codex-collaborate-loop-stop` | Disable loop automation and remove CCCC hook registrations |

## Hook behavior

Hooks are **not enabled by default**. Explicitly run:

```text
/cc-codex-collaborate-loop-start
```

The Stop hook only supervises "continue if unfinished" — it **never bypasses**:

- Human questions &ensp;·&ensp; Real secrets &ensp;·&ensp; Wallet private keys / seed phrases
- Real API keys &ensp;·&ensp; Production operations &ensp;·&ensp; Real-money actions
- Destructive commands &ensp;·&ensp; Codex `needs_human` &ensp;·&ensp; Threshold failures

To disable auto-continuation:

```text
/cc-codex-collaborate-loop-stop
```

## Human-question design

When clarification is needed, the skill uses a brainstorming-style gate:

1. Explain why the question matters
2. Provide 2–5 concrete options
3. Recommend a safe default when possible
4. Include an `Other` option for custom input
5. Record the decision in `docs/cccc/decision-log.md`

## Suggested .gitignore

```gitignore
docs/cccc/logs/
docs/cccc/runtime/
```

You may commit `docs/cccc/*.md` to preserve planning and review history.

---

## License

[MIT](./LICENSE)
