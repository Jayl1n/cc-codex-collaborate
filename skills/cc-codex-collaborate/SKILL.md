---
name: cc-codex-collaborate
version: 0.1.2
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

When invoked with `setup`, do not start project implementation. Run:

```bash
.claude/skills/cc-codex-collaborate/scripts/cccc-setup.sh
```

The setup command must:

1. Generate `.claude/commands/` shortcut commands from `.claude/skills/cc-codex-collaborate/templates/commands/`.
2. Generate or verify the `docs/cccc/` runtime workspace from templates.
3. Preserve existing files and avoid overwriting user modifications.
4. Not enable hooks or Stop-hook automation.
5. Report to the user, in their primary language, exactly what was generated or preserved.
6. Show simple usage examples.

Setup should explain:

- generated command files
- generated `docs/cccc` files
- that hooks were not enabled
- that loop automation can be enabled later with `/cc-codex-collaborate-loop-start`

## Command bootstrap model

The release zip should not require users to copy `.claude/commands/`, `.claude/hooks/`, or `docs/cccc/` manually.

The zip includes only the skill, scripts, prompts, schemas, hooks templates, and command templates.

Runtime generation rules:

- `/cc-codex-collaborate setup` generates `.claude/commands/` and `docs/cccc/`.
- `/cc-codex-collaborate-loop-start` generates `.claude/hooks/` and updates `.claude/settings.json`.
- `/cc-codex-collaborate-loop-stop` removes only this skill's hook registrations.

## Loop control commands

After setup, this package provides three explicit slash-command wrappers for loop automation:

- `/cc-codex-collaborate-loop-status`: inspect `docs/cccc/state.json`, hook files, and `.claude/settings.json` hook registrations.
- `/cc-codex-collaborate-loop-start`: enable full-auto-safe loop continuation by installing cccc hook scripts into `.claude/hooks`, registering them in `.claude/settings.json`, and setting `docs/cccc/state.json` mode to `full-auto-safe`.
- `/cc-codex-collaborate-loop-stop`: disable loop automation by removing only cccc hook registrations from `.claude/settings.json` and returning state to supervised/manual mode.

Do not enable Stop-hook automation implicitly. The user must explicitly run `/cc-codex-collaborate-loop-start`.

`docs/cccc` is a runtime workspace. It must be generated on first use by initialization logic and should not be required as a pre-copied project directory.


## Subcommand handling

Interpret the first argument after `/cc-codex-collaborate` as a subcommand when it matches one of these values:

- `setup`: run `scripts/cccc-setup.sh`, then report generated files and simple usage. Do not start planning or implementation.
- `init`: run `scripts/cccc-init.sh` and begin project discovery.
- `status`: run `scripts/cccc-status.sh` and summarize.
- `loop-status`: run `scripts/cccc-loop-status.sh` and summarize.
- `loop-start`: run `scripts/cccc-loop-start.sh` and summarize.
- `loop-stop`: run `scripts/cccc-loop-stop.sh` and summarize.

If no known subcommand is provided, treat the arguments as the user's coding task. Before doing project discovery or planning, ensure setup has been performed. If `.claude/commands/` or `docs/cccc/` is missing, run `scripts/cccc-setup.sh` first, then continue.

## Role separation

- Claude Code: project discovery, language detection, planning, self-review, implementation, tests, fixes, state management, human-facing communication.
- Codex: independent read-only reviewer, adversarial planning challenger, milestone reviewer, next-milestone critic.
- Human: ambiguous requirements, product decisions, security decisions, secrets, production operations, real money, irreversible actions.

Codex must not directly modify files. Codex reviews using context and returns structured JSON.

## User language rule

Before planning or asking any question, detect the user's primary language.

Detection priority:

1. Explicit user preference.
2. Latest user instruction language.
3. Main task language if the message is mixed.
4. If still unclear, default to the language of the most recent user message.

Store it in `docs/cccc/state.json` as `user_language`.

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

## Default thresholds

Use these defaults unless the user overrides them in `docs/cccc/state.json`.

```json
{
  "max_plan_review_rounds": 3,
  "max_milestones_per_run": 5,
  "max_review_rounds_per_milestone": 3,
  "max_fix_attempts_per_milestone": 3,
  "max_stop_hook_continuations": 10,
  "max_context_refresh_rounds": 3,
  "max_diff_lines_per_milestone": 1200,
  "max_changed_files_per_milestone": 20,
  "on_max_review_exceeded": "pause"
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
9. The same milestone exceeds `max_review_rounds_per_milestone`.
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

1. user language
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

Hard rule:

```text
No context bundle, no Codex planning.
No project discovery, no roadmap.
No approved roadmap, no implementation.
```

## Milestone implementation loop

For each milestone:

1. Confirm roadmap is approved.
2. Confirm current milestone is clearly scoped.
3. Implement the smallest coherent change.
4. Run relevant tests and checks.
5. Perform Claude self-review.
6. Regenerate `docs/cccc/context-bundle.md`.
7. Run Codex milestone review in read-only mode.
8. If Codex passes, record acceptance and select next milestone.
9. If Codex fails with fixable findings, fix and repeat.
10. If Codex needs human input or detects unsafe work, pause.

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

The optional Stop hook may continue the loop only when:

- `docs/cccc/state.json` exists
- the loop is enabled
- status is not done
- status is not paused
- status is not unsafe
- status is not waiting for human input
- continuation count is below threshold

The Stop hook must never continue past hard pause conditions.

## User-facing progress format

Use the user's language.

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
