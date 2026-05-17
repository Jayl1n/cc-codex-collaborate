# CCCC — Claude Code × Codex 协作引擎

<p align="center">
  <strong>版本</strong> 0.1.22 &nbsp;|&nbsp; <strong>代号</strong> CCCC &nbsp;|&nbsp; <strong>协议</strong> MIT
</p>

<p align="center">
  <a href="./README_EN.md">English</a>
</p>

---

**CCCC**（cc-codex-collaborate）是一个 Claude Code Skill，让 Claude Code 和 Codex 在安全的、基于里程碑的工程循环中协作。

Claude Code 负责发现项目、制定规划、实现里程碑、修复问题、管理状态。Codex 作为独立只读审阅者，挑战初始规划、审阅每个里程碑、建议安全的下一步。遇到歧义、敏感操作、真实密钥、生产变更、资金操作或阈值失败时，必须由人类决策。

---

## 它做什么

把一次编码任务变成可控的协作循环：

1. **检测语言** — 识别用户主语言，全程使用该语言交互。
2. **发现项目** — 规划前先理解已有代码和架构。
3. **构建上下文** — 在 `docs/cccc` 下生成项目上下文文件。
4. **制定路线** — 生成 roadmap 与 milestone backlog。
5. **自审规划** — Claude Code 先做规划自审（planning self-review）。
6. **对抗审核** — Codex 再做推翻式规划审核（adversarial plan review）。
7. **安全启动** — 规划安全并通过后才进入实现阶段。
8. **逐个实现** — 每次只实现一个 milestone。
9. **独立审阅** — Codex 以只读模式审阅当前 diff。
10. **修复迭代** — 修复 → 再审阅 → 通过后进入下一 milestone，直到完成或触发暂停。

## 设计原则

| 原则 | 说明 |
| --- | --- |
| **Claude Code 主导** | Claude Code 是唯一的编排者和实现者 |
| **Codex 只审不写** | Codex 只读、推翻式审阅，不修改代码 |
| **人类兜底** | 敏感决策必须由人类确认 |
| **先理解再规划** | 没有项目理解，不做项目规划 |
| **上下文先行** | 没有 `context-bundle.md`，不让 Codex 规划 |
| **审核前置** | 没有自审 + 对抗审核，不开始实现 |
| **安全闸门** | 遇到密钥/资金/生产/破坏性操作，不能自动继续 |
| **Codex 门禁** | Codex 审阅不可跳过，必须通过才能进入下一阶段 |

## Mandatory Codex Gates（P0 级规则）

**Codex 审阅永远不是可选的。**

必须遵守的规则：

1. 没有 Codex 规划审阅通过，不允许开始实现
2. 没有 Codex milestone 审阅通过，不允许标记 milestone 完成
3. 没有 Codex 最终审阅通过，不允许标记任务完成
4. Codex 不可用、失败或返回无效 JSON 时，必须暂停（状态 `PAUSED_FOR_CODEX`）
5. 即使是简单任务，Codex 审阅也必须执行
6. 自检（cat、测试、lint、build）不能替代 Codex 审阅

简记口诀：

```text
No Codex plan review, no implementation.
No Codex milestone review, no milestone pass.
No Codex final review, no task completion.
Codex unavailable means pause, not skip.
```

## 首次使用

```text
/cc-codex-collaborate setup
```

Setup 是交互式配置向导：

1. 检测用户主语言
2. 选择配置预设（快速 / 严格 / 自定义）
3. 生成 `docs/cccc/` 工作区
4. 生成 `docs/cccc/config.json`（项目配置）
5. 生成 `docs/cccc/state.json`（运行状态）
6. 生成 `.claude/commands/` 快捷命令
7. **不启用** hooks，**不开始** 任务

配置预设：

| 预设 | 适用场景 | 特点 |
| --- | --- | --- |
| **A. 快速配置** | 大多数项目（推荐） | 3 轮 review，1200 diff 行，P1 阻塞 |
| **B. 严格配置** | 高风险项目 | 4 轮 review，600 diff 行，P2 也阻塞 |
| **C. 自定义** | 逐项配置 | 语言、模式、粒度、review 阈值、自动化 |

## 开始任务

```text
/cc-codex-collaborate "你的任务描述"
```

这里输入的是自然语言任务描述，不是固定任务名。例如：

```text
/cc-codex-collaborate "给用户模块添加邮箱验证功能"
/cc-codex-collaborate "refactor the auth middleware to use JWT"
```

## config.json 与 state.json

| 文件 | 用途 | 何时修改 |
| --- | --- | --- |
| `docs/cccc/config.json` | 项目级配置：模式、阈值、语言、安全策略、自动化 | setup 时或手动编辑 |
| `docs/cccc/state.json` | 运行时状态：当前 milestone、status、review 轮次、pause reason | 每次运行自动更新 |

config.json 存储的内容：
- 语言设置（`language`）
- 协作模式（`mode`）
- 规划审核阈值（`planning`）
- Milestone 粒度（`milestones`）
- Review 阈值（`review`）
- 自动化设置（`automation`）
- 安全策略（`safety`）
- Codex 行为（`codex`）

state.json 只存储运行时数据：
- 当前 milestone、状态、review 轮次
- pause reason、completed/blocked milestones
- loop 续跑计数、last context update

## 运行时工作区

`docs/cccc` 在 setup 时自动生成，无需手动创建。

```
docs/cccc/
  config.json              # 项目配置
  state.json               # 运行状态
  project-brief.md         # 项目简报
  project-map.md           # 项目地图
  current-state.md         # 当前状态快照
  architecture.md          # 架构说明
  test-strategy.md         # 测试策略
  roadmap.md               # 路线图
  milestone-backlog.md     # 里程碑待办
  decision-log.md          # 决策日志
  risk-register.md         # 风险登记
  open-questions.md        # 待解决问题
  context-bundle.md        # 上下文摘要（Codex 审阅的输入）
  reviews/                 # 审阅记录
  logs/                    # 运行日志
  runtime/                 # 运行时临时文件
  backups/                 # 配置备份
```

模板位于 `.claude/skills/cc-codex-collaborate/templates/cccc/`。

## 安装

将 skill 目录安装到目标项目：

```
.claude/skills/cc-codex-collaborate/
```

发布 zip 不包含以下运行时目录，它们会在需要时自动生成：

```
.claude/commands/
.claude/hooks/
docs/cccc/
```

## 升级

升级 skill 时，先安装新版 skill 文件（git pull、覆盖 zip、包管理器等）。

然后运行：

```text
/cc-codex-collaborate update
```

update 会安全迁移：
- `docs/cccc/config.json` — 补齐新字段，保留用户设置
- `docs/cccc/state.json` — 补齐新字段，保留运行状态
- `.claude/commands/` — 同步生成的命令，保留用户修改的命令
- `.claude/hooks/` — 仅在 loop 已启用时同步

update 不会覆盖：
- `roadmap.md`、`milestone-backlog.md`、`decision-log.md`、`risk-register.md`
- `docs/cccc/reviews/`、`docs/cccc/logs/`

update 会在 `docs/cccc/backups/update-<timestamp>/` 下创建备份。

如果之前没有启用 hooks，update 不会自动启用。

使用 `/cc-codex-collaborate-loop-status` 查看是否建议 update。

## 命令参考

所有命令都有完整形式和短别名两种写法：

| 完整命令 | 短别名 |
| --- | --- |
| `/cc-codex-collaborate` | `/cccc` |
| `/cc-codex-collaborate-loop-status` | `/cccc-loop-status` |
| `/cc-codex-collaborate-loop-start` | `/cccc-loop-start` |
| `/cc-codex-collaborate-loop-stop` | `/cccc-loop-stop` |

短别名调用同一个脚本，行为与完整命令完全一致。以下文档统一使用 `/cccc` 简写。

### 主命令

```text
/cccc <任务描述>       启动完整协作流程
/cccc setup            交互式配置向导（首次使用入口）
/cccc update           安全迁移工作区（升级后同步）
/cccc force-update     强制同步（无视版本号）
/cccc resume           恢复暂停的 workflow
/cccc sync-docs        检测并同步 docs/cccc 文档变化
/cccc diff-docs        只查看文档变化（不修改状态）
/cccc replan           文档变化后重新规划
/cccc bypass-codex     管理 Codex bypass（Codex 不可用时替代 review）
/cccc codex-recheck    Codex 恢复后重新检查 bypassed gates
/cccc codex-budget     查看 Codex 预算、策略、缓存、checkpoint
/cccc review-now       强制立即 Codex review（当前/batch/full）
/cccc checkpoint       管理 Codex-approved checkpoint
/cccc ingest-docs      导入外部讨论文档到 inbox
/cccc sync-inbox       增量发现 inbox 文档变化
/cccc curate-docs      提炼 raw docs 中的工程内容到 canonical docs
/cccc distill-project  从所有来源重建项目状态
/cccc reset            重置状态机（从文档重新推断进度）
/cccc doctor           诊断安装/配置/hooks/Codex/gates
/cccc rebuild-context  重新生成 context-bundle
/cccc gates            显示 plan/milestone/final/safety/docs-sync gate 状态
/cccc repair           自动修复安全的不一致状态
/cccc trace            查看最近状态机事件
/cccc dev-smoke        开发者自测
/cccc codex-check      检查 Codex CLI 可用性
/cccc plan             生成/更新规划
/cccc plan-review      触发规划审核
/cccc run              运行当前 milestone
/cccc review           触发 milestone 审阅
/cccc status           查看当前状态
```

### Loop 自动化命令

| 命令 | 作用 |
| --- | --- |
| `/cccc-loop-status` | 查看 config/state 状态、loop 模式、hooks 配置、resume 建议 |
| `/cccc-loop-start` | 启用 Stop-hook 自动续跑，如有活跃 workflow 则立即继续 |
| `/cccc-loop-stop` | 禁用 loop 自动化，移除 cccc 的 hook 注册 |

### 维护与调试命令

| 命令 | 作用 |
| --- | --- |
| `/cccc force-update` | 无视版本号，强制同步当前 skill 模板到项目工作区 |
| `/cccc reset` | 重置状态机运行状态，从 docs/cccc、reviews、git log 重新推断当前进度 |
| `/cccc doctor` | 一次性诊断安装、hooks、config/state、Codex、gates、context |
| `/cccc rebuild-context` | 重新生成 Codex 使用的 context-bundle |
| `/cccc gates` | 显示 plan/milestone/final/safety gate 状态 |
| `/cccc repair` | 自动修复安全的不一致状态（备份后修复） |
| `/cccc trace` | 查看最近状态机事件 |
| `/cccc dev-smoke` | 开发者自测（JSON/shell/Python 校验） |
| `/cccc codex-check` | 检查 Codex CLI 可用性 |

## Hook 行为

hooks **默认不启用**。需要显式执行：

```text
/cc-codex-collaborate-loop-start
```

Stop hook 只负责"未完成则继续"的监督，**绝不放行**以下危险操作：

- 人工问题 &ensp;·&ensp; 真实 secret &ensp;·&ensp; 钱包私钥/助记词
- 真实 API key &ensp;·&ensp; 生产环境操作 &ensp;·&ensp; 真实资金操作
- 破坏性命令 &ensp;·&ensp; Codex `needs_human` &ensp;·&ensp; 阈值失败

禁用自动续跑：

```text
/cc-codex-collaborate-loop-stop
```

## 恢复暂停的 workflow

当 workflow 因人工问题、Codex 不可用、系统错误、review 阈值或安全问题暂停后，用 resume 恢复：

```text
/cc-codex-collaborate resume
```

resume 不会绕过安全规则，也不会自动通过 Codex gate。不同暂停状态的恢复规则：

| 暂停状态 | 恢复方式 |
| --- | --- |
| `PAUSED_FOR_HUMAN` / `NEEDS_HUMAN` | 用户回答未解决问题后才可恢复 |
| `PAUSED_FOR_CODEX` | Codex 可用后才可恢复，必须重新运行缺失的 Codex gate |
| `PAUSED_FOR_SYSTEM` | 用户确认系统错误已解决后才可恢复 |
| `NEEDS_SECRET` | 用户在本地配置 secret 或选择 mock 后才可恢复 |
| `SENSITIVE_OPERATION` / `UNSAFE` | 用户明确选择安全替代方案后才可恢复，禁止恢复真实资金/生产操作 |
| `REVIEW_THRESHOLD_EXCEEDED` | 用户选择增加 review 轮次、记录风险或暂停处理 |

## loop-start 会不会开始执行任务？

`/cc-codex-collaborate-loop-start` 会启用 stop-hook 自动续跑。

- 如果当前已有可继续的 workflow，它会立即继续执行状态机。
- 如果当前 workflow 处于暂停状态，它会提示运行：`/cc-codex-collaborate resume`
- 如果没有当前任务，它只会启用 loop，并提示运行：`/cc-codex-collaborate "你的任务描述"`

## 手动文档同步

docs/cccc 下的文档是可人工编辑的项目规划工作区。如果用户手动修改了 architecture、roadmap、milestone 等文档，应该运行：

```text
/cccc sync-docs
```

只查看变化（不修改状态）：

```text
/cccc diff-docs
```

如果架构或 roadmap 发生改变，需要重新规划：

```text
/cccc replan
```

高影响变化会让旧的 Codex plan approval 失效。sync-docs 会用选项式问答让用户选择：

- A. 采纳文档并重新规划（推荐）
- B. 只更新 context-bundle
- C. 暂停 workflow
- D. 忽略本次变化
- E. 查看 diff
- F. 自由输入

## Codex 不可用与 Bypass 模式

默认情况下，cc-codex-collaborate 要求 Codex 做独立 review。如果 Codex 额度用尽、CLI 不可用或认证失败，workflow 会暂停。

在 setup 中你可以选择 Codex 不可用时的策略：

- **严格暂停** — 最安全，等待 Codex 恢复
- **允许一次性 bypass** — 由 Claude Code 做推翻式 review（推荐）
- **允许低/中风险自动 bypass** — 高风险仍暂停
- **每次都询问** — 用户逐次决定
- **自定义**

Bypass 不等于 Codex pass。Bypass 会生成 lower-assurance review artifact，gate 状态标记为 `bypassed`。

Codex 恢复后，运行：

```text
/cccc codex-recheck
```

管理 bypass：

```text
/cccc bypass-codex status    # 查看状态
/cccc bypass-codex once      # 请求一次性 bypass
/cccc bypass-codex off       # 关闭 bypass
```

高风险、关键风险、钱包、生产、真实资金场景默认禁止 bypass。

## 节省 Codex 额度

默认 Balanced 策略不会每个低风险 milestone 都调用 Codex：

- **低风险**：每 3 个 milestone 进行一次 Codex review
- **中风险**：每 2 个 Codex review
- **高风险 / Critical**：每个都审
- **Plan / Final review**：始终 Codex

中间低风险步骤使用 Claude adversarial review（标记 lower assurance）。

管理工具：

```text
/cccc codex-budget     # 查看预算、策略、缓存、checkpoint
/cccc review-now       # 强制立即 Codex review
/cccc checkpoint       # 管理 Codex-approved checkpoint
```

Codex pass 后建议 checkpoint（git commit），后续只 review 新 diff。Review cache 会避免相同 diff 重复消耗 Codex。

## 混杂文档提炼

如果你和 GPT / Claude 讨论过项目，生成了混杂文档，不要直接让 skill 根据这些 raw notes 实现代码。

推荐流程：

1. 把混杂文档放入：`docs/cccc/inbox/gpt-discussions/`
2. 运行：`/cccc sync-inbox`
3. 运行：`/cccc curate-docs`
4. 根据选项确认哪些内容进入 canonical docs
5. 如果架构或 roadmap 发生变化，运行：`/cccc replan`
6. 之后再执行：`/cccc "你的任务"`

核心原则：

- **inbox = 原始证据**（不直接驱动代码）
- **canonical = 工程事实来源**（经过提炼确认）
- **product = 产品/商业化资料**（不直接生成 milestone）
- **source-map = raw 到 canonical 的映射**
- **curation-state = 当前提炼状态**

## 追问设计

需要澄清时，采用 brainstorming 式追问：

1. 说明为什么需要这个决策
2. 给出 2–5 个具体选项
3. 尽量推荐安全的默认选项
4. 提供 `Other` 允许自由输入
5. 将决策记录到 `docs/cccc/decision-log.md`

## 推荐 .gitignore

```gitignore
docs/cccc/logs/
docs/cccc/runtime/
docs/cccc/backups/
```

可选择将 `docs/cccc/*.md` 和 `docs/cccc/config.json` 提交到 git，以保留配置和审阅历史。`state.json` 可以不提交，因为它是运行时临时状态。

---

## 许可证

[MIT](./LICENSE)
