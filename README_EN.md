# CCCC — Claude Code × Codex Collaboration Engine

<p align="center">
  <strong>Version</strong> 0.1.17 &nbsp;|&nbsp; <strong>Short name</strong> CCCC &nbsp;|&nbsp; <strong>License</strong> MIT
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
| **Codex gates** | Codex review is mandatory, must pass before proceeding |

## Mandatory Codex Gates (P0 Rule)

**Codex review is NEVER optional.**

Required rules:

1. No Codex plan review passed, no implementation may start
2. No Codex milestone review passed, no milestone may be marked complete
3. No Codex final review passed, no task may be marked DONE
4. If Codex is unavailable, fails, or returns invalid JSON, must pause (status `PAUSED_FOR_CODEX`)
5. Even for trivial tasks, Codex review must be performed
6. Self-checks (cat, tests, lint, build) are NOT a substitute for Codex review

Invariants:

```text
No Codex plan review, no implementation.
No Codex milestone review, no milestone pass.
No Codex final review, no task completion.
Codex unavailable means pause, not skip.
```

## First-time setup

```text
/cc-codex-collaborate setup
```

Setup is an interactive configuration wizard that:

1. Detects the user's primary language
2. Presents configuration presets (recommended / strict / custom)
3. Generates the `docs/cccc/` workspace
4. Creates `docs/cccc/config.json` (project configuration)
5. Creates `docs/cccc/state.json` (runtime state)
6. Generates `.claude/commands/` shortcut commands
7. Does **not** enable hooks or start any task

Configuration presets:

| Preset | Use case | Highlights |
| --- | --- | --- |
| **A. Quick setup** | Most projects (recommended) | 3 review rounds, 1200 diff lines, P1 blocks |
| **B. Strict setup** | High-risk projects | 4 review rounds, 600 diff lines, P2 also blocks |
| **C. Custom** | Step-by-step config | Language, mode, granularity, review thresholds, automation |

## Start a task

```text
/cc-codex-collaborate "your task description"
```

This is a free-form natural language task description, not a fixed task name. For example:

```text
/cc-codex-collaborate "add email verification to the user module"
/cc-codex-collaborate "refactor the auth middleware to use JWT"
```

## config.json vs state.json

| File | Purpose | When modified |
| --- | --- | --- |
| `docs/cccc/config.json` | Project-level config: mode, thresholds, language, safety, automation | During setup or manual edit |
| `docs/cccc/state.json` | Runtime state: current milestone, status, review rounds, pause reason | Updated automatically each run |

`config.json` stores:
- Language settings (`language`)
- Collaboration mode (`mode`)
- Planning review thresholds (`planning`)
- Milestone granularity (`milestones`)
- Review thresholds (`review`)
- Automation settings (`automation`)
- Safety policies (`safety`)
- Codex behavior (`codex`)

`state.json` only stores runtime data:
- Current milestone, status, review round counts
- Pause reason, completed/blocked milestones
- Loop continuation count, last context update

## Runtime workspace

`docs/cccc` is generated automatically by setup — no manual creation needed.

```
docs/cccc/
  config.json              # Project configuration
  state.json               # Runtime state
  project-brief.md         # Project brief
  project-map.md           # Project map
  current-state.md         # Current state snapshot
  architecture.md         # Architecture overview
  test-strategy.md         # Test strategy
  roadmap.md              # Roadmap
  milestone-backlog.md    # Milestone backlog
  decision-log.md         # Decision log
  risk-register.md         # Risk register
  open-questions.md        # Open questions
  context-bundle.md        # Context summary (input for Codex reviews)
  reviews/                 # Review records
  logs/                    # Runtime logs
  runtime/                 # Runtime temporary files
  backups/                 # Config backups
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

## Updating

To upgrade the skill, first install the new skill files (git pull, overwrite zip, package manager, etc.).

Then run:

```text
/cc-codex-collaborate update
```

Update safely migrates:
- `docs/cccc/config.json` — adds new fields, preserves user settings
- `docs/cccc/state.json` — adds new fields, preserves runtime state
- `.claude/commands/` — syncs generated commands, preserves user-modified commands
- `.claude/hooks/` — only syncs if loop is already enabled

Update does NOT overwrite:
- `roadmap.md`, `milestone-backlog.md`, `decision-log.md`, `risk-register.md`
- `docs/cccc/reviews/`, `docs/cccc/logs/`

Update creates backup under `docs/cccc/backups/update-<timestamp>/`.

If hooks were not enabled before, update does NOT enable them.

Use `/cc-codex-collaborate-loop-status` to check whether update is recommended.

## Command reference

All commands have both full and short alias forms:

| Full command | Short alias |
| --- | --- |
| `/cc-codex-collaborate` | `/cccc` |
| `/cc-codex-collaborate-loop-status` | `/cccc-loop-status` |
| `/cc-codex-collaborate-loop-start` | `/cccc-loop-start` |
| `/cc-codex-collaborate-loop-stop` | `/cccc-loop-stop` |

Short aliases call the same scripts and behave identically to full commands. The docs below use `/cccc` for brevity.

### Main commands

```text
/cccc <task>            Start the full collaboration loop
/cccc setup             Interactive configuration wizard (first-time entry point)
/cccc update            Safe workspace migration (sync after upgrade)
/cccc force-update      Force sync regardless of version number
/cccc resume            Resume a paused workflow
/cccc sync-docs         Detect and sync docs/cccc document changes
/cccc diff-docs         Check for document changes (read-only)
/cccc replan            Re-plan after documentation changes
/cccc bypass-codex      Manage Codex bypass (alternative review when Codex unavailable)
/cccc codex-recheck     Re-check bypassed gates when Codex becomes available
/cccc codex-budget      Show Codex review budget, policy, cache, checkpoint
/cccc review-now        Force immediate Codex review (current/batch/full)
/cccc checkpoint        Manage Codex-approved checkpoints
/cccc reset             Reset state machine and rehydrate from docs
/cccc doctor            Diagnose installation, config, hooks, Codex, gates, context
/cccc rebuild-context   Rebuild context-bundle.md
/cccc gates             Show plan/milestone/final/safety/docs-sync gate status
/cccc repair            Auto-fix safe inconsistencies
/cccc trace             Show recent state machine events
/cccc dev-smoke         Developer self-test
/cccc codex-check       Check Codex CLI availability
/cccc plan              Generate/update the plan
/cccc plan-review       Trigger plan review
/cccc run               Run the current milestone
/cccc review            Trigger milestone review
/cccc status            Show current status
```

### Loop automation commands

| Command | Purpose |
| --- | --- |
| `/cccc-loop-status` | Show config/state status, loop mode, hook configuration, and resume guidance |
| `/cccc-loop-start` | Enable Stop-hook auto-continuation; if active workflow exists, continue immediately |
| `/cccc-loop-stop` | Disable loop automation and remove CCCC hook registrations |

### Maintenance and debugging commands

| Command | Purpose |
| --- | --- |
| `/cccc force-update` | Force sync skill templates to workspace regardless of version |
| `/cccc reset` | Reset state machine and rehydrate current progress from docs, reviews, and git history |
| `/cccc doctor` | Diagnose installation, hooks, config/state, Codex, gates, and context health |
| `/cccc rebuild-context` | Rebuild context-bundle.md for Codex |
| `/cccc gates` | Show plan/milestone/final/safety gate status |
| `/cccc repair` | Auto-fix safe inconsistencies (backs up before modifying) |
| `/cccc trace` | Show recent state machine events |
| `/cccc dev-smoke` | Developer self-test (JSON/shell/Python validation) |
| `/cccc codex-check` | Check Codex CLI availability |

## Codex Unavailable and Bypass Mode

By default, cc-codex-collaborate requires Codex for independent review. If Codex quota is exhausted, CLI is unavailable, or auth fails, the workflow pauses.

During setup, you choose a Codex unavailable policy:

- **Strict pause** — Safest, wait for Codex
- **Allow one-time bypass** — Claude Code performs adversarial review (Recommended)
- **Auto bypass for low/medium risk** — High risk still pauses
- **Always ask** — User decides each time
- **Custom**

Bypass is NOT the same as Codex pass. Bypass generates lower-assurance review artifacts. Gate status is `bypassed`, not `pass`.

When Codex becomes available:

```text
/cccc codex-recheck
```

Manage bypass:

```text
/cccc bypass-codex status    # Show bypass status
/cccc bypass-codex once      # Request one-time bypass
/cccc bypass-codex off       # Disable bypass
```

High-risk, critical-risk, wallet, production, and real-money scenarios cannot be bypassed by default.

## Reducing Codex Quota Usage

The default Balanced policy does not call Codex for every low-risk milestone:

- **Low risk**: Codex review every 3 milestones
- **Medium risk**: Codex review every 2 milestones
- **High risk / Critical**: Codex review every milestone
- **Plan / Final review**: Always Codex

Intermediate low-risk steps use Claude adversarial review (marked lower assurance).

Management tools:

```text
/cccc codex-budget     # View budget, policy, cache, checkpoint
/cccc review-now       # Force immediate Codex review
/cccc checkpoint       # Manage Codex-approved checkpoints
```

After Codex passes, create a checkpoint (git commit). Future reviews only cover new diff. Review cache avoids redundant Codex calls on identical diffs.

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

## Resuming a paused workflow

When a workflow is paused due to human input, Codex unavailability, system errors, review thresholds, or safety issues, use resume to continue:

```text
/cc-codex-collaborate resume
```

Resume does NOT bypass safety rules or automatically pass Codex gates. Resume rules by status:

| Paused status | Resume rule |
| --- | --- |
| `PAUSED_FOR_HUMAN` / `NEEDS_HUMAN` | Resume only after user answers open questions |
| `PAUSED_FOR_CODEX` | Resume only when Codex is available; must re-run the missing Codex gate |
| `PAUSED_FOR_SYSTEM` | Resume only after user confirms the system error is resolved |
| `NEEDS_SECRET` | Resume only after user configures secret locally or chooses mock |
| `SENSITIVE_OPERATION` / `UNSAFE` | Resume only with user's explicit safe alternative; real money/production ops prohibited |
| `REVIEW_THRESHOLD_EXCEEDED` | Resume only after user chooses to extend review, record risk, or pause |

## Does loop-start begin execution?

`/cc-codex-collaborate-loop-start` enables stop-hook auto-continuation.

- If an active workflow can be continued, it immediately continues the state machine.
- If the workflow is paused, it suggests running `/cc-codex-collaborate resume`.
- If no task exists, it only enables the loop and prompts: `/cc-codex-collaborate "your task description"`

## Syncing Manual Documentation Changes

docs/cccc is a user-editable planning workspace. If you manually modify architecture, roadmap, milestone, or other documents, run:

```text
/cccc sync-docs
```

To only view changes without modifying state:

```text
/cccc diff-docs
```

If architecture or roadmap has changed, replan:

```text
/cccc replan
```

High-impact changes invalidate old Codex plan approvals. sync-docs presents brainstorm-style options:

- A. Adopt docs and replan (Recommended)
- B. Only update context-bundle
- C. Pause workflow
- D. Ignore changes
- E. View diff
- F. Custom input

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
docs/cccc/backups/
```

You may commit `docs/cccc/*.md` and `docs/cccc/config.json` to preserve configuration and review history. `state.json` can be excluded since it's runtime state.

---

## License

[MIT](./LICENSE)
