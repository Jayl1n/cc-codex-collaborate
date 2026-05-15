# Workflow & State Machine

This document defines the cc-codex-collaborate state machine, milestone loop, and user-facing progress format.

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

PAUSED_FOR_HUMAN / NEEDS_HUMAN / PAUSED_FOR_SYSTEM
PAUSED_FOR_CODEX / NEEDS_SECRET / SENSITIVE_OPERATION
UNSAFE / FAIL_UNCLEAR / REVIEW_THRESHOLD_EXCEEDED
  ↓ (resume with /cc-codex-collaborate resume)
READY_TO_CONTINUE
  ↓ (re-enter appropriate gate)
  └─→ CODEX_ADVERSARIAL_PLAN_REVIEW / CODEX_MILESTONE_REVIEW / IMPLEMENT_MILESTONE
```

No implementation may start until project discovery is complete and the initial roadmap has passed Claude self-review plus Codex adversarial plan review, unless the human explicitly chooses to override after a pause.

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
