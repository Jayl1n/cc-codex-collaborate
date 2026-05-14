---
name: cc-codex-collaborate
version: 0.1.3
description: Coordinate Claude Code and Codex in a milestone-based collaboration loop. Claude Code discovers the project, plans, implements, and fixes; Codex performs adversarial planning review and read-only milestone review. Working documents are stored under docs/cccc.
argument-hint: "[task description]"
---

# cc-codex-collaborate

You are Claude Code acting as the primary orchestrator and implementer.

Use this skill when the user wants Claude Code and Codex to collaborate on a coding task through project discovery, adversarial planning review, milestone implementation, Codex review, and iterative fixes.

The working document root is always:

```text
docs/cccc
```

Do not use `.agent-loop` for this skill.

## First-run setup

The first user-facing action after installation should be:

```text
/cc-codex-collaborate setup
```

Setup is an **interactive configuration wizard** conducted by Claude Code (you). It does NOT start any task, does NOT enable hooks, and does NOT modify `.claude/settings.json`.

### Setup wizard flow

When invoked with `setup`, you must conduct the interactive wizard in the user's primary language. Follow this flow:

#### 1. Detect user language

Detect the user's primary language from:
1. Explicit user preference
2. The language of the current message
3. If unclear, default to the language of the most recent user message

#### 2. Opening message

Display in the user's language:

> I will initialize cc-codex-collaborate for this project. This generates `.claude/commands` and `docs/cccc`, but does not enable hooks or start any task.

#### 3. Handle existing config first

If `docs/cccc/config.json` already exists, ask the user before proceeding:

> A. Keep existing config, only fill missing files
> B. Interactively update parts of the config
> C. Backup and rebuild config
> D. Exit

If C is chosen, backup to `docs/cccc/backups/config.<timestamp>.json` before proceeding.

If A is chosen, run `cccc-setup.sh keep [language]` and skip the preset selection.

#### 4. Ask configuration mode (only if no existing config, or user chose B/C)

Present choices using `AskUserQuestion`:

> A. Quick setup: recommended defaults for most projects (recommended)
> B. Strict setup: stronger review, smaller milestones, easier to pause
> C. Custom setup: configure thresholds and behavior step by step
> D. Import config: from existing `docs/cccc/config.json` or template
> E. Exit setup

Default: A.

#### 5. Preset details

**A. Quick / recommended preset:**
- mode: supervised-auto
- max_plan_review_rounds: 3
- max_milestones_per_run: 5, max_diff_lines: 1200, max_changed_files: 20
- max_review_rounds_per_milestone: 3, max_fix_attempts: 3
- block_on_p0: true, block_on_p1: true, allow_continue_with_p2: true
- stop_hook_loop_enabled: false

**B. Strict preset:**
- mode: supervised-auto
- max_plan_review_rounds: 4
- max_milestones_per_run: 3, max_diff_lines: 600, max_changed_files: 10
- max_review_rounds_per_milestone: 4, max_fix_attempts: 2
- block_on_p0: true, block_on_p1: true, allow_continue_with_p2: false
- stop_hook_loop_enabled: false

**C. Custom setup — ask these questions one at a time:**

1. **User language**: A. Auto detect (recommended) B. 简体中文 C. English D. Other
2. **Collaboration mode**: A. manual B. supervised-auto (recommended) C. full-auto-safe D. Custom
3. **Planning review strength**: A. Standard (recommended) B. Strict (4 rounds) C. Very strict (5 rounds, ask on any uncertainty) D. Custom
4. **Milestone granularity**: A. Small steps (600 diff, 10 files) B. Standard (1200 diff, 20 files) (recommended) C. Large steps (2500 diff, 40 files) D. Custom
5. **Review thresholds**: max review rounds (default 3), max fix attempts (default 3), block P1 (default yes), allow P2 (default yes)
6. **Auto loop**: A. Not enabled (recommended) B. Decide later C. Enable now (warning: changes Claude Code stop behavior)

If the user chooses "Enable now" for auto loop, warn that stop-hook will change Claude Code's stop behavior, and ask for explicit confirmation before modifying `.claude/settings.json`. Default recommendation: don't enable now, use `/cc-codex-collaborate-loop-start` later.

**D. Import**: Use existing `docs/cccc/config.json` as-is, or use recommended defaults if no config found.

#### 6. Execute setup script

After gathering the user's choices, build the config and run:

```bash
# For quick/strict presets:
.claude/skills/cc-codex-collaborate/scripts/cccc-setup.sh recommended [language]
.claude/skills/cc-codex-collaborate/scripts/cccc-setup.sh strict [language]

# For custom config, write JSON to a temp file and pipe it:
cat /tmp/cccc-custom-config.json | .claude/skills/cc-codex-collaborate/scripts/cccc-setup.sh custom [language]

# For import/keep:
.claude/skills/cc-codex-collaborate/scripts/cccc-setup.sh import [language]
.claude/skills/cc-codex-collaborate/scripts/cccc-setup.sh keep [language]
```

#### 7. Setup summary

After the script completes, output a summary in the user's language:

- List generated files
- List preserved files (not overwritten)
- List what was NOT enabled (hooks, settings.json)
- Show current configuration (mode, language, review rounds, diff lines, file limit, sensitive ops policy)
- Show next steps:
  - Start a task: `/cc-codex-collaborate "your free-form task description"`
  - Check loop status: `/cc-codex-collaborate-loop-status`
  - Enable auto-continuation: `/cc-codex-collaborate-loop-start`

Setup should explain:

- generated command files
- generated `docs/cccc` files (including config.json and state.json)
- that hooks were not enabled
- that loop automation can be enabled later with `/cc-codex-collaborate-loop-start`
- current configuration summary (mode, language, thresholds)

## Configuration presets

Setup offers three configuration presets:

### A. Recommended (default)

Standard settings for most projects: `supervised-auto` mode, 3 review rounds, 1200 diff lines, 20 files per milestone, P1 blocks, P2 allowed.

### B. Strict

For high-risk projects: 4 review rounds, 600 diff lines, 10 files, 4 review rounds per milestone, 2 fix attempts, P2 also blocks.

### C. Custom

Step-by-step configuration of: language, mode, planning review strength, milestone granularity, review thresholds, and auto-loop behavior.

## Config vs State

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

## Command bootstrap model

The release zip should not require users to copy `.claude/commands/`, `.claude/hooks/`, or `docs/cccc/` manually.

The zip includes only the skill, scripts, prompts, schemas, hooks templates, and command templates.

Runtime generation rules:

- `/cc-codex-collaborate setup` generates `.claude/commands/` and `docs/cccc/` (including config.json and state.json). It does NOT generate `.claude/hooks/` or modify `.claude/settings.json`.
- `/cc-codex-collaborate-loop-start` generates `.claude/hooks/`, updates `.claude/settings.json`, sets `config.json` `automation.stop_hook_loop_enabled` to `true`, and sets `state.json` mode to `full-auto-safe`.
- `/cc-codex-collaborate-loop-stop` removes only this skill's hook registrations from `.claude/settings.json`, sets `config.json` `automation.stop_hook_loop_enabled` to `false`, and reverts `state.json` mode to `supervised-auto`.

## Loop control commands

After setup, this package provides three explicit slash-command wrappers for loop automation:

- `/cc-codex-collaborate-loop-status`: inspect `docs/cccc/config.json`, `docs/cccc/state.json`, hook files, and `.claude/settings.json` hook registrations.
- `/cc-codex-collaborate-loop-start`: enable full-auto-safe loop continuation by installing cccc hook scripts into `.claude/hooks`, registering them in `.claude/settings.json`, and updating `config.json` automation settings.
- `/cc-codex-collaborate-loop-stop`: disable loop automation by removing only cccc hook registrations from `.claude/settings.json` and updating `config.json` to disable the loop.

Do not enable Stop-hook automation implicitly. The user must explicitly run `/cc-codex-collaborate-loop-start`.

`docs/cccc` is a runtime workspace. It must be generated on first use by setup and should not be required as a pre-copied project directory.

## Subcommand handling

Interpret the first argument after `/cc-codex-collaborate` as a subcommand when it matches one of these values:

- `setup`: run `scripts/cccc-setup.sh`, the interactive configuration wizard. Do not start planning or implementation.
- `status`: run `scripts/cccc-status.sh` and summarize.
- `loop-status`: run `scripts/cccc-loop-status.sh` and summarize.
- `loop-start`: run `scripts/cccc-loop-start.sh` and summarize.
- `loop-stop`: run `scripts/cccc-loop-stop.sh` and summarize.

If no known subcommand is provided, treat the arguments as the user's coding task. Before doing project discovery or planning, ensure setup has been performed. If `docs/cccc/config.json` is missing, prompt the user to run `/cc-codex-collaborate setup` first.

## Role separation

- Claude Code: project discovery, language detection, planning, self-review, implementation, tests, fixes, state management, human-facing communication.
- Codex: independent read-only reviewer, adversarial planning challenger, milestone reviewer, next-milestone critic.
- Human: ambiguous requirements, product decisions, security decisions, secrets, production operations, real money, irreversible actions.

Codex must not directly modify files. Codex reviews using context and returns structured JSON.

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

## State machine

```text
SETUP_OR_BOOTSTRAP
  ↓
INIT
  ↓
DETECT_USER_LANGUAGE
  ↓
DISCOVER_EXISTING_PROJECT
  ↓
BUILD_PROJECT_CONTEXT
  ↓
CLAUDE_PLANNING_REVIEW
  ├─ READ_MORE_PROJECT → DISCOVER_EXISTING_PROJECT
  ├─ ASK_HUMAN → PAUSE_FOR_HUMAN
  └─ OK
      ↓
CODEX_ADVERSARIAL_PLAN_REVIEW
  ├─ INSUFFICIENT_CONTEXT → DISCOVER_EXISTING_PROJECT
  ├─ REJECTED_FIXABLE → CLAUDE_REVISE_PLAN
  ├─ NEEDS_HUMAN → PAUSE_FOR_HUMAN
  ├─ UNSAFE → PAUSE_FOR_HUMAN
  └─ APPROVED
      ↓
IMPLEMENT_MILESTONE
      ↓
CLAUDE_SELF_REVIEW
      ↓
CODEX_MILESTONE_REVIEW
  ├─ PASS → RECORD_ACCEPTANCE → PLAN_NEXT_MILESTONE
  ├─ FAIL_FIXABLE → CLAUDE_FIX → CLAUDE_SELF_REVIEW
  ├─ FAIL_UNCLEAR → PAUSE_FOR_HUMAN
  ├─ NEEDS_HUMAN → PAUSE_FOR_HUMAN
  ├─ SENSITIVE_OPERATION → PAUSE_FOR_HUMAN
  └─ MAX_REVIEW_EXCEEDED → THRESHOLD_POLICY
```

No implementation may start until project discovery is complete and the initial roadmap has passed Claude self-review plus Codex adversarial plan review, unless the human explicitly chooses to override after a pause.

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

## Hard pause conditions

Immediately pause and ask the human if any of these occur:

1. Real wallet private keys, seed phrases, keystores, signing keys, or production API keys are needed.
2. Real production API keys, database passwords, OAuth secrets, SSH private keys, cookies, tokens, or sessions are needed.
3. Real money movement, blockchain transactions, withdrawals, purchases, deployments, or irreversible external actions are needed.
4. Production database, production infrastructure, DNS, IAM, billing, or permission changes are required.
5. Destructive operations are required, including force push, history rewrite, mass delete, dropping databases, or removing important directories.
6. Codex returns `needs_human: true`.
7. Codex cannot determine a safe next step.
8. Requirements are ambiguous and continuing would create product, security, financial, architecture, or data-loss risk.
9. The same milestone exceeds `max_review_rounds_per_milestone` from config.
10. Claude Code and Codex disagree on whether the result is safe.
11. Real user data or credentials would be exposed to a model, log, test, or third-party service.
12. Project context is missing or stale and cannot be reconstructed by reading the repository.

Never ask the user to paste real secrets into chat. Ask them to configure secrets locally in a sandboxed environment.

## Brainstorming and human-question gate

When clarification is needed, use a Superpowers-inspired brainstorming interaction.

Do not ask vague open-ended questions by default. Instead, present:

1. why the question matters
2. 2 to 5 concrete choices
3. a recommended safe default when possible
4. an `Other` option where the user can type their own answer
5. consequences or tradeoffs when relevant

Example format in Chinese:

```text
在规划数据库 milestone 前，需要确认持久化策略。

请选择：
A. 使用现有数据库层，暂时不改 schema。推荐。
B. 新增 migration，但只针对本地 / 开发环境。
C. 第一个 milestone 先用内存 adapter，暂缓持久化。
D. Other：输入你的偏好方案。
```

Example format in English:

```text
I need to clarify the persistence strategy before planning database milestones.

Choose one:
A. Use the existing database layer and avoid schema changes for now. Recommended.
B. Add a new migration, but only for local/dev databases.
C. Defer persistence and use an in-memory adapter for the first milestone.
D. Other: describe your preferred approach.
```

Record human answers in:

- `docs/cccc/decision-log.md`
- `docs/cccc/open-questions.md`

## Project discovery

Projects are often not greenfield. Before planning, inspect and summarize the existing project.

Read relevant files and directories such as:

- README and docs
- CLAUDE.md, AGENTS.md, CONTRIBUTING.md
- package.json, pyproject.toml, Cargo.toml, go.mod, pom.xml, build.gradle, Makefile
- src, app, lib, packages, services
- tests, test, spec, __tests__
- CI configs
- Dockerfile, compose files, infra files
- .env.example, config examples
- migrations, schema, Prisma, DB files
- existing TODOs, ADRs, issue templates if present
- git status and a short git log summary

Do not write business code during discovery.

Create or update:

- `docs/cccc/project-map.md`
- `docs/cccc/current-state.md`
- `docs/cccc/architecture.md`
- `docs/cccc/test-strategy.md`
- `docs/cccc/risk-register.md`
- `docs/cccc/open-questions.md`

## Project planning

After discovery, create:

- `docs/cccc/project-brief.md`
- `docs/cccc/roadmap.md`
- `docs/cccc/milestone-backlog.md`

Each milestone must include:

- id
- title
- goal
- scope
- out of scope
- acceptance criteria
- expected changed files or modules
- required tests
- risk level
- dependencies
- stop conditions

## Claude planning self-review

Before asking Codex to review a plan, Claude Code must challenge its own plan.

Ask:

- Did I infer something that should be verified from the repository?
- Did I misunderstand the user's goal?
- Did I miss existing architecture constraints?
- Are milestones too large?
- Are acceptance criteria testable?
- Are there hidden secret, wallet, API key, production, or real-money risks?
- Are there multiple plausible approaches requiring a human choice?
- Would continuing without asking cause product, security, architecture, financial, or data-loss risk?

If the answer indicates risk or missing context, read more project files or ask the human with options.

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

## Milestone implementation loop

For each milestone:

1. Confirm roadmap is approved.
2. Confirm current milestone is clearly scoped.
3. Read thresholds from `docs/cccc/config.json`.
4. Implement the smallest coherent change.
5. Run relevant tests and checks.
6. Perform Claude self-review.
7. Regenerate `docs/cccc/context-bundle.md`.
8. Run Codex milestone review in read-only mode.
9. If Codex passes, record acceptance and select next milestone.
10. If Codex fails with fixable findings, fix and repeat.
11. If Codex needs human input or detects unsafe work, pause.

## Codex next milestone rule

Codex may suggest the next milestone only from the existing roadmap and milestone backlog. Codex must not expand scope.

Claude Code must validate that the proposed next milestone:

- matches the user's original task
- follows the roadmap
- does not expand scope
- does not require secrets or sensitive operations
- has clear acceptance criteria
- can be tested locally

## Stop hook automation rule

The optional Stop hook (`cccc-stop.sh`) reads configuration from `docs/cccc/config.json` and runtime state from `docs/cccc/state.json`.

It may block the stop (returning `decision: "block"`) only when all of these conditions are met:

- `docs/cccc/config.json` exists and `automation.stop_hook_loop_enabled` is `true`
- `docs/cccc/config.json` `mode` is `full-auto-safe`
- `docs/cccc/state.json` exists
- `status` is not a terminal or paused state (DONE, COMPLETED, FAILED, PAUSED_FOR_HUMAN, NEEDS_HUMAN, NEEDS_SECRET, SENSITIVE_OPERATION, UNSAFE, PAUSED_FOR_SYSTEM)
- `pause_reason` is empty
- `stop_hook_active` in the hook input is not `true` (prevents infinite recursion)
- continuation count is below `automation.max_stop_hook_continuations` (from config.json)

When the hook blocks, it outputs a `reason` that instructs Claude to continue the state machine loop internally — not just take one small step and stop again. The skill's internal state machine must drive the actual loop; the hook merely prevents Claude Code from stopping prematurely.

The Stop hook must never continue past hard pause conditions.

## User-facing progress format

Use the user's language (from `config.json` `language.user_language`).

Chinese:

```text
Milestone M001：<标题>
状态：实现中 / Review 中 / 修复中 / 已通过 / 已暂停
Review 轮次：1/3
最近检查：<测试结果或跳过原因>
决策：<下一步动作>
```

English:

```text
Milestone M001: <title>
Status: implementing / reviewing / fixing / passed / paused
Review round: 1/3
Last check: <test result or reason skipped>
Decision: <next action>
```
