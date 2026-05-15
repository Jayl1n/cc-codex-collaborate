#!/usr/bin/env python3
"""CCCC Gates — show plan/milestone/final/safety gate status."""
import json
import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(os.environ.get("CLAUDE_PROJECT_DIR", subprocess.getoutput("git rev-parse --show-toplevel 2>/dev/null || pwd")).strip())
WORKSPACE = ROOT / "docs/cccc"


def read_json(path: Path) -> dict | None:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except Exception:
        return None


def lang() -> str:
    cfg = read_json(WORKSPACE / "config.json")
    if cfg:
        return cfg.get("language", {}).get("user_language", "zh")
    return "zh"


def check_plan_gate(cfg: dict, st: dict):
    print("Plan review gate:")
    plan_status = st.get("codex_plan_review_status", "not_run")
    plan_file = st.get("last_codex_plan_review_file")
    roadmap_status = st.get("roadmap_status", "not_reviewed")
    impl_allowed = plan_status == "pass" or plan_status == "bypassed"

    print(f"  Codex plan review: {plan_status}")
    if plan_status == "bypassed":
        print(f"  Assurance: lower_than_codex_review (Claude bypass)")
        bypass_file = st.get("last_codex_bypass_review_file")
        if bypass_file:
            print(f"  Bypass review file: {bypass_file}")
    if plan_file and plan_status != "bypassed":
        exists = Path(plan_file).exists() if not plan_file.startswith("/tmp") else True
        print(f"  Review file: {plan_file} ({'exists' if exists else 'missing'})")
    elif not plan_file and plan_status != "bypassed":
        print(f"  Review file: (none)")

    print(f"  Roadmap status: {roadmap_status}")
    if plan_status == "bypassed":
        print(f"  Implementation allowed: yes, but lower assurance")
        print(f"  Required follow-up: Run /cccc codex-recheck when Codex is available.")
    else:
        print(f"  Implementation allowed: {'yes' if impl_allowed else 'no'}")
    if not impl_allowed and plan_status != "bypassed":
        if plan_status == "not_run":
            print(f"  原因: Codex plan review 尚未执行。运行 /cccc plan-review")
        elif plan_status == "fail":
            print(f"  原因: Codex plan review 未通过。修复后重新提交。")
        elif plan_status == "needs_human":
            print(f"  原因: Codex plan review 需要人工干预。")
        else:
            print(f"  原因: plan review 状态为 {plan_status}")
    print()


def check_milestone_gate(cfg: dict, st: dict):
    print("Milestone review gate:")
    mid = st.get("current_milestone_id")
    review_status = st.get("current_milestone_codex_review_status", "not_run")
    review_file = st.get("current_milestone_codex_review_file")
    pass_allowed = review_status == "pass" or review_status == "bypassed"

    print(f"  Current milestone: {mid or '(none)'}")
    if not mid:
        print(f"  Milestone pass allowed: no — no current milestone")
        print(f"  原因: 当前没有活跃 milestone")
        print()
        return

    print(f"  Codex review: {review_status}")
    if review_status == "bypassed":
        print(f"  Assurance: lower_than_codex_review (Claude bypass)")
        bypass_file = st.get("last_codex_bypass_review_file")
        if bypass_file:
            print(f"  Bypass review file: {bypass_file}")
    if review_file and review_status != "bypassed":
        exists = Path(review_file).exists() if not review_file.startswith("/tmp") else True
        print(f"  Review file: {review_file} ({'exists' if exists else 'missing'})")
    elif not review_file and review_status != "bypassed":
        print(f"  Review file: (none)")

    if review_status == "bypassed":
        print(f"  Milestone pass allowed: yes, but lower assurance")
        print(f"  Required follow-up: Run /cccc codex-recheck when Codex is available.")
    else:
        print(f"  Milestone pass allowed: {'yes' if pass_allowed else 'no'}")
    if not pass_allowed and review_status != "bypassed":
        if review_status == "not_run":
            print(f"  原因: Codex milestone review 尚未执行。不允许直接标记 milestone passed。")
        elif review_status == "fail":
            print(f"  原因: Codex milestone review 未通过。修复后重新提交 review。")
        elif review_status == "needs_human":
            print(f"  原因: Codex milestone review 需要人工干预。")
        else:
            print(f"  原因: review 状态为 {review_status}")
    print()


def check_final_gate(cfg: dict, st: dict):
    print("Final review gate:")
    final_status = st.get("codex_final_review_status", "not_run")
    final_file = st.get("last_codex_final_review_file")
    completion_allowed = final_status == "pass" or final_status == "bypassed"

    print(f"  Codex final review: {final_status}")
    if final_status == "bypassed":
        print(f"  Assurance: lower_than_codex_review (Claude bypass)")
        bypass_file = st.get("last_codex_bypass_review_file")
        if bypass_file:
            print(f"  Bypass review file: {bypass_file}")
    if final_file and final_status != "bypassed":
        exists = Path(final_file).exists() if not final_file.startswith("/tmp") else True
        print(f"  Review file: {final_file} ({'exists' if exists else 'missing'})")
    elif not final_file and final_status != "bypassed":
        print(f"  Review file: (none)")

    if final_status == "bypassed":
        print(f"  Task completion allowed: yes, but lower assurance")
        print(f"  Required follow-up: Run /cccc codex-recheck when Codex is available.")
    else:
        print(f"  Task completion allowed: {'yes' if completion_allowed else 'no'}")
    if not completion_allowed and final_status != "bypassed":
        if final_status == "not_run":
            print(f"  原因: Codex final review 尚未执行。")
        elif final_status == "fail":
            print(f"  原因: Codex final review 未通过。")
        else:
            print(f"  原因: final review 状态为 {final_status}")
    print()


def check_safety_gate(st: dict):
    print("Safety gate:")
    status = st.get("status", "UNKNOWN")
    pause_reason = st.get("pause_reason")
    blocked = status in ("NEEDS_SECRET", "SENSITIVE_OPERATION", "UNSAFE",
                         "PAUSED_FOR_HUMAN", "NEEDS_HUMAN", "PAUSED_FOR_SYSTEM")

    print(f"  Status: {status}")
    print(f"  Pause reason: {pause_reason or '无'}")

    if blocked:
        print(f"  Safe to continue: no")
        print(f"  原因: 状态 {status} 需要人工处理。")
    else:
        print(f"  Safe to continue: yes")
    print()


def check_docs_sync_gate(st: dict):
    print("Docs sync gate:")
    sync_status = st.get("docs_sync_status", "unknown")
    changed = st.get("docs_changed_since_last_sync", False)
    planning_inv = st.get("planning_invalidated_by_doc_change", False)
    last_impact = st.get("last_doc_change_impact")
    impl_allowed = not planning_inv

    print(f"  docs_sync_status: {sync_status}")
    print(f"  changed_since_last_sync: {changed}")
    print(f"  planning_invalidated: {planning_inv}")
    if last_impact:
        print(f"  last_impact: {last_impact}")
    print(f"  implementation allowed: {'yes' if impl_allowed else 'no'}")

    if planning_inv:
        reason = st.get("planning_invalidation_reason", "unknown")
        print(f"  原因: Planning invalidated by doc changes. {reason}")
        print(f"  修复: /cccc replan")
    elif changed:
        print(f"  原因: Docs changed but not yet synced. Run /cccc sync-docs.")
    print()


def check_testing_gate(st: dict):
    print("Testing gate:")
    reviews_dir = WORKSPACE / "reviews" / "milestones"
    latest_review = None
    if reviews_dir.exists():
        for f in sorted(reviews_dir.glob("*.json"), reverse=True):
            data = read_json(f)
            if data:
                latest_review = data
                break

    if latest_review:
        test_assessment = latest_review.get("test_assessment", "not_evaluated")
        print(f"  Latest review test assessment: {test_assessment}")
    else:
        print(f"  No milestone review artifacts found")

    cont = st.get("stop_hook_continuations", 0)
    print(f"  Continuation budget: {cont} used")
    print()


def check_review_policy_gate(cfg: dict, st: dict):
    print("Review policy gate:")
    policy = cfg.get("codex_review_policy", {})
    budget = st.get("codex_budget", {})

    mode = policy.get("mode", "unknown")
    calls = budget.get("codex_calls_this_run", 0)
    max_calls = policy.get("budget", {}).get("max_codex_calls_per_run", 5)

    print(f"  Policy mode: {mode}")
    print(f"  Codex calls this run: {calls} / {max_calls}")
    print(f"  Budget remaining: {max(0, max_calls - calls)}")

    batch = st.get("codex_review_batch", {})
    pending = batch.get("pending_milestones", [])
    print(f"  Pending batch: {len(pending)} milestone(s)")

    cache = st.get("codex_review_cache", {})
    cache_count = len(cache) if isinstance(cache, dict) else 0
    print(f"  Review cache entries: {cache_count}")

    ckpt = st.get("checkpoint", {})
    last_commit = ckpt.get("last_codex_approved_commit")
    print(f"  Last Codex-approved commit: {last_commit or 'none'}")

    budget_exhausted = calls >= max_calls
    if budget_exhausted:
        print(f"  Budget exhausted: yes")
        print(f"  修复: 调整 budget 或使用 /cccc bypass-codex")
    else:
        print(f"  Budget exhausted: no")
    print()


def check_curation_gate(st: dict):
    """Check curation gate status."""
    print("Curation gate:")
    source_index_path = WORKSPACE / "source-index.json"
    curation_state_path = WORKSPACE / "curation-state.json"

    if not source_index_path.exists():
        print("  source-index: not found (no inbox docs tracked)")
        print("  implementation allowed: yes (no curation pipeline)")
        print()
        return

    idx = read_json(source_index_path) or {}
    pending = sum(1 for s in idx.get("sources", {}).values()
                  if s.get("requires_curation") and s.get("status") not in ("deleted", "archived", "ignored"))

    cs = read_json(curation_state_path) or {}
    conflicts = len(cs.get("pending_conflicts", []))
    dirty = cs.get("canonical_docs_dirty", False)
    requires_replan = cs.get("requires_replan", False)
    state_replan = st.get("curation_requires_replan", False)

    print(f"  pending curation: {pending}")
    print(f"  pending conflicts: {conflicts}")
    print(f"  canonical docs dirty: {dirty}")
    print(f"  requires replan: {requires_replan or state_replan}")

    impl_allowed = not (conflicts > 0 or requires_replan or state_replan)
    print(f"  implementation allowed: {'yes' if impl_allowed else 'no'}")

    if not impl_allowed:
        if conflicts > 0:
            print(f"  修复: /cccc curate-docs (resolve conflicts)")
        if requires_replan or state_replan:
            print(f"  修复: /cccc replan")
    elif pending > 0:
        print(f"  建议: /cccc curate-docs ({pending} inbox source(s) pending)")
    print()


def main():
    import argparse
    parser = argparse.ArgumentParser(description="Show plan/milestone/final/safety gate status")
    parser.parse_args()

    cfg = read_json(WORKSPACE / "config.json")
    st = read_json(WORKSPACE / "state.json")

    if not cfg or not st:
        print("ERROR: docs/cccc/config.json 或 state.json 不存在或无效。", file=sys.stderr)
        print("运行 /cc-codex-collaborate setup", file=sys.stderr)
        return 1

    print("当前 Gates：")
    print()

    check_plan_gate(cfg, st)
    check_milestone_gate(cfg, st)
    check_final_gate(cfg, st)
    check_safety_gate(st)
    check_docs_sync_gate(st)
    check_curation_gate(st)
    check_review_policy_gate(cfg, st)
    check_testing_gate(st)

    # Next steps
    plan_ok = st.get("codex_plan_review_status") == "pass"
    ms_ok = st.get("current_milestone_codex_review_status") == "pass"
    final_ok = st.get("codex_final_review_status") == "pass"
    mid = st.get("current_milestone_id")

    print("下一步：")
    if not plan_ok:
        print("  - 运行 Codex plan review 后才能开始实现")
    elif not mid:
        print("  - 没有活跃 milestone，运行 /cc-codex-collaborate resume 或开始新任务")
    elif not ms_ok:
        print(f"  - 运行 Codex milestone review (milestone {mid})，不允许直接标记 passed")
    elif not final_ok:
        print("  - 所有 milestone review 通过后运行 Codex final review")
    else:
        print("  - 所有 gate 通过，可以完成任务")

    return 0


if __name__ == "__main__":
    sys.exit(main())
