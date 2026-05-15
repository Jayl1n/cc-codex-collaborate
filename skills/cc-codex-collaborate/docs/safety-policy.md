# Safety Policy

This document defines hard pause conditions, role separation, and the brainstorming interaction pattern.

## Role separation

- Claude Code: project discovery, language detection, planning, self-review, implementation, tests, fixes, state management, human-facing communication.
- Codex: independent read-only reviewer, adversarial planning challenger, milestone reviewer, next-milestone critic, final reviewer.
- Human: ambiguous requirements, product decisions, security decisions, secrets, production operations, real money, irreversible actions.

Codex must not directly modify files. Codex reviews using context and returns structured JSON.

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
