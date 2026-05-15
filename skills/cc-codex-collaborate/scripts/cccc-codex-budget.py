#!/usr/bin/env python3
"""CCCC codex-budget — show Codex review budget and policy status."""
import json
import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(os.environ.get("CLAUDE_PROJECT_DIR",
                            subprocess.getoutput("git rev-parse --show-toplevel 2>/dev/null || pwd")).strip())
WORKSPACE = ROOT / "docs/cccc"


def read_json(path: Path) -> dict | None:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except Exception:
        return None


def main():
    import argparse
    parser = argparse.ArgumentParser(description="Show Codex review budget and policy status")
    parser.parse_args()

    cfg = read_json(WORKSPACE / "config.json") or {}
    state = read_json(WORKSPACE / "state.json") or {}

    policy = cfg.get("codex_review_policy", {})
    budget_cfg = policy.get("budget", {})
    batch_cfg = policy.get("batching", {})
    frequency = policy.get("review_frequency", {})

    budget = state.get("codex_budget", {})
    batch = state.get("codex_review_batch", {})
    ckpt = state.get("checkpoint", {})
    cache = state.get("codex_review_cache", {})

    calls_this_run = budget.get("codex_calls_this_run", 0)
    max_calls = budget_cfg.get("max_codex_calls_per_run", 5)
    calls_this_phase = budget.get("codex_calls_this_phase", 0)
    max_phase = budget_cfg.get("max_codex_calls_per_phase", 8)
    pending_batch = batch.get("pending_milestones", [])
    last_approved = ckpt.get("last_codex_approved_commit")

    print("Codex review budget:")
    print(f"  Policy mode: {policy.get('mode', 'unknown')}")
    print()
    print(f"  Calls this run: {calls_this_run} / {max_calls}")
    print(f"  Calls this phase: {calls_this_phase} / {max_phase}")

    by_milestone = budget.get("codex_calls_by_milestone", {})
    if by_milestone:
        print("  Calls by milestone:")
        for mid, count in by_milestone.items():
            print(f"    {mid}: {count}")

    print()
    print("Review frequency:")
    for risk in ["low", "medium", "high", "critical"]:
        key = f"{risk}_risk_every_n_milestones"
        n = frequency.get(key, 1)
        print(f"  {risk} risk: every {n} milestone(s)")

    print()
    print("Pending batch:")
    if pending_batch:
        for m in pending_batch:
            print(f"  - {m}")
    else:
        print("  (none)")

    print()
    print("Checkpoint:")
    print(f"  Last Codex-approved commit: {last_approved or '(none)'}")
    rec = ckpt.get("pending_checkpoint_recommendation", False)
    print(f"  Checkpoint recommendation pending: {rec}")

    print()
    print("Review cache:")
    cache_count = len(cache) if isinstance(cache, dict) else 0
    print(f"  Cached entries: {cache_count}")

    print()
    remaining = max(0, max_calls - calls_this_run)
    if remaining <= budget_cfg.get("warn_when_remaining_calls_lte", 1) and remaining > 0:
        print(f"WARN: Only {remaining} Codex call(s) remaining this run.")
    elif remaining == 0:
        print("WARN: Codex budget exhausted for this run.")

    pending_recheck = state.get("pending_codex_recheck", [])
    if pending_recheck:
        print(f"Pending Codex rechecks: {len(pending_recheck)}")

    return 0


if __name__ == "__main__":
    sys.exit(main())
