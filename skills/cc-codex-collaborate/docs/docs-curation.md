# Docs Curation Pipeline

This document defines the mixed-document curation pipeline: ingest-docs, sync-inbox, curate-docs, distill-project commands, and the raw vs canonical docs rules.

## Core principle

Raw discussion notes are evidence, not authority. Canonical docs are authority after curation. Code implementation must follow canonical docs, not raw notes.

## Raw Notes vs Canonical Docs

1. `docs/cccc/inbox` is raw discussion material, only evidence.
2. `docs/cccc/product` is product/business reference material, does not directly drive code.
3. `docs/cccc/canonical` is the engineering authority.
4. Root-level `docs/cccc/*.md` files remain compatible mirrors of canonical content.
5. Claude Code MUST NOT directly implement code based on inbox/raw notes.
6. Any engineering requirements from raw notes must first be curated into canonical docs.
7. Any architecture/roadmap/milestone changes must go through curate-docs or sync-docs, possibly triggering replan.
8. If raw notes conflict with canonical docs, pause and ask the user.
9. If canonical docs conflict with code, record in open-questions or risk-register, consider replan.
10. Codex plan review should be based on canonical docs, not raw notes.

## Directory structure

```
docs/cccc/inbox/
  raw-notes/          # User's own raw notes
  gpt-discussions/    # GPT/Claude discussion exports
  imported-docs/      # Imported external documents

docs/cccc/canonical/
  project-brief.md
  engineering-scope.md
  architecture.md
  roadmap.md
  milestone-backlog.md
  test-strategy.md
  risk-register.md
  decision-log.md
  open-questions.md

docs/cccc/product/
  product-notes.md
  business-notes.md
  monetization-notes.md
  go-to-market-notes.md

docs/cccc/archive/
  irrelevant/         # Content not related to current project
  superseded/         # Content replaced by newer versions

docs/cccc/curation/
  reports/            # Curation reports
  conflicts/          # Conflict records
  extractions/        # Machine-readable extractions
```

## Index files

- `docs/cccc/source-index.json` — Tracks raw doc hashes, status (new/changed/unchanged/deleted/archived/ignored), curation needs.
- `docs/cccc/source-map.json` — Maps raw source content to canonical doc targets with classification and confidence.
- `docs/cccc/curation-state.json` — Tracks curation state: pending sources, conflicts, questions, dirty flags.

## Content classification

curate-docs classifies content into:

- `engineering_required` — Must affect implementation (e.g., "must use PostgreSQL")
- `engineering_optional` — Engineering suggestions (e.g., "consider Redis")
- `architecture_decision` — Architecture changes (e.g., "MySQL → PostgreSQL")
- `implementation_task` — Convertible to milestones (e.g., "create CLI")
- `test_requirement` — Testing requirements (e.g., "need e2e tests")
- `risk_or_constraint` — Risks or constraints (e.g., "no real API keys")
- `product_context` — Product background not directly engineering (e.g., "lower friction onboarding")
- `business_context` — Business context (e.g., "enterprise SaaS")
- `monetization_context` — Monetization plans (e.g., "subscription pricing")
- `go_to_market_context` — GTM strategy (e.g., "channel growth")
- `irrelevant` — Not related to current project
- `unclear` — Needs user clarification
- `conflict` — Conflicts with existing canonical docs, code, or other sources

## ingest-docs command

Import external discussion documents into inbox.

```bash
.claude/skills/cc-codex-collaborate/scripts/cccc-ingest-docs.sh [path...] 
```

- Copies files to `docs/cccc/inbox/imported-docs/`
- Handles duplicate names with timestamp suffix
- Does NOT modify canonical docs, roadmap, or state
- Auto-runs sync-inbox after import

Without arguments, shows usage instructions and suggests placing files in inbox manually.

## sync-inbox command

Incremental discovery of inbox document changes.

```bash
python3 .claude/skills/cc-codex-collaborate/scripts/cccc-sync-inbox.py [--json] [--path <path>] [--max-file-bytes <n>]
```

- Scans `docs/cccc/inbox/` for text files (.md, .txt, .json, .yaml, .yml, .csv, .rst)
- Computes SHA256 hashes
- Updates `source-index.json`
- Marks sources as: new, changed, unchanged, deleted
- New or changed sources get `requires_curation = true`
- Does NOT modify canonical docs, roadmap, or current milestone

## curate-docs command

Read, classify, deduplicate, and extract engineering content from raw docs.

```bash
python3 .claude/skills/cc-codex-collaborate/scripts/cccc-curate-docs.py [status|report|apply] [--strategy <strategy>]
```

- `status`: Show curation status (pending sources, conflicts, dirty flags)
- `report`: Generate extraction report for sources requiring curation. Sets `SYNC_AWAITING_DECISION=true` — Claude Code must ask the user with brainstorm-style options.
- `apply`: Mark sources as curated after user confirmation.

### curate-docs interactive flow

When conflicts, high-impact content, or ambiguities are found, Claude Code must ask the user with brainstorm-style options:

Example Chinese:
```
我从混杂文档中提炼到这些内容：

工程相关：
1. 数据库从 MySQL 切换到 PostgreSQL
2. 后端从 Express 切换到 Next.js
...

发现冲突：
1. 文档 A 说使用 Express
2. 文档 B 说改为 Next.js

你希望如何处理？

A. 采纳工程相关内容，更新 canonical docs，隔离商业化内容
B. 只提炼工程内容，不修改 roadmap
C. 采纳 Next.js + PostgreSQL
D. 暂停
E. 查看详细报告
F. 自由输入
```

After user confirmation:
- Update canonical docs
- Move product/business content to `docs/cccc/product/`
- Archive irrelevant content
- If engineering facts change affects roadmap/architecture:
  - `curation-state.requires_replan = true`
  - `state.curation_requires_replan = true`
  - `state.status = NEEDS_CURATION`
  - Recommend `/cccc replan`

## distill-project command

Rebuild clean project state from all sources.

```bash
.claude/skills/cc-codex-collaborate/scripts/cccc-distill-project.sh
```

Inputs: inbox docs + canonical docs + product docs + git log/status + code structure.

Outputs:
- `docs/cccc/curation/reports/distill-report-<timestamp>.md`
- Updated canonical docs
- Updated source-map and curation-state
- If planning changed: mark NEEDS_REPLAN

distill-project must distinguish: engineering facts, engineering assumptions, product context, business context, out-of-scope content, conflicts, open questions.

After completion, recommend `/cccc replan`.

## Relationship to other commands

- `sync-docs` — Canonical/planning docs change sync
- `sync-inbox` — Raw/inbox docs incremental discovery
- `curate-docs` — Extract engineering facts from raw docs into canonical
- `distill-project` — Full project state rebuild from all sources
- `replan` — Re-plan based on canonical docs and run Codex review
