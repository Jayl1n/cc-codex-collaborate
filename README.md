# CCCC — Claude Code × Codex 协作引擎

<p align="center">
  <strong>版本</strong> 0.1.7 &nbsp;|&nbsp; <strong>代号</strong> CCCC &nbsp;|&nbsp; <strong>协议</strong> MIT
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

### 主命令

```text
/cc-codex-collaborate <任务描述>    启动完整协作流程
/cc-codex-collaborate setup         交互式配置向导（首次使用入口）
/cc-codex-collaborate update        安全迁移工作区（升级后同步）
/cc-codex-collaborate plan          生成/更新规划
/cc-codex-collaborate plan-review   触发规划审核
/cc-codex-collaborate run           运行当前 milestone
/cc-codex-collaborate review        触发 milestone 审阅
/cc-codex-collaborate status        查看当前状态
/cc-codex-collaborate resume        恢复上次中断的任务
```

### Loop 自动化命令

| 命令 | 作用 |
| --- | --- |
| `/cc-codex-collaborate-loop-status` | 查看 config/state 状态、loop 模式、hooks 配置 |
| `/cc-codex-collaborate-loop-start` | 启用 Stop-hook 自动续跑（`full-auto-safe` 模式） |
| `/cc-codex-collaborate-loop-stop` | 禁用 loop 自动化，移除 cccc 的 hook 注册 |

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
