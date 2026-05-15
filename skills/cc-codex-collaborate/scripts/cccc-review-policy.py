#!/usr/bin/env python3
"""CCCC review policy — decide review level based on risk, budget, cache, and triggers."""
import argparse
import json
import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(os.environ.get("CLAUDE_PROJECT_DIR",
                            subprocess.getoutput("git rev-parse --show-toplevel 2>/dev/null || pwd")).strip())
WORKSPACE = ROOT / "docs/cccc"

sys.path.insert(0, str(Path(__file__).parent))
from cccc_review_fingerprint import compute_fingerprint, check_cache


def read_json(path: Path) -> dict | None:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except Exception:
        return None


def get_diff_stats() -> tuple[int, int]:
    try:
        r = subprocess.run(["git", "diff", "--shortstat"], capture_output=True, text=True, cwd=str(ROOT), timeout=10)
        text = r.stdout.strip()
        lines = 0
        files = 0
        import re
        m = re.search(r"(\d+) file", text)
        if m:
            files = int(m.group(1))
        m = re.search(r"(\d+) insertion", text)
        if m:
            lines += int(m.group(1))
        m = re.search(r"(\d+) deletion", text)
        if m:
            lines += int(m.group(1))
        return lines, files
    except Exception:
        return 0, 0


def get_risk_level(state: dict, cfg: dict) -> str:
    known_risks = state.get("known_risks", [])
    for r in known_risks:
        rs = str(r).lower()
        if "critical" in rs:
            return "critical"
    for r in known_risks:
        rs = str(r).lower()
        if "high" in rs:
            return "high"
    return "medium"


def get_milestones_since_last_codex(state: dict) -> int:
    completed = state.get("completed_milestones", [])
    count = 0
    for m in reversed(completed):
        ms = str(m).lower()
        if "codex_pass" in ms or "codex:pass" in ms:
            break
        count += 1
    return count


def main():
    parser = argparse.ArgumentParser(
        description="Decide Codex review level based on risk, budget, cache, and triggers",
    )
    parser.add_argument("--gate", default=None,
                        help="Review gate type (plan_review, final_review, or milestone)")
    args = parser.parse_args()
    gate = args.gate

    cfg = read_json(WORKSPACE / "config.json") or {}
    state = read_json(WORKSPACE / "state.json") or {}

    policy = cfg.get("codex_review_policy", {})
    mode = policy.get("mode", "balanced")
    frequency = policy.get("review_frequency", {})
    triggers = policy.get("review_triggers", {})
    budget_cfg = policy.get("budget", {})
    batch_cfg = policy.get("batching", {})
    cache_cfg = policy.get("cache", {})
    checkpoint_cfg = policy.get("checkpoint", {})

    risk = get_risk_level(state, cfg)
    diff_lines, diff_files = get_diff_stats()

    budget = state.get("codex_budget", {})
    calls_this_run = budget.get("codex_calls_this_run", 0)
    max_calls = budget_cfg.get("max_codex_calls_per_run", 5)
    budget_remaining = max(0, max_calls - calls_this_run)
    budget_exhausted = calls_this_run >= max_calls

    batch = state.get("codex_review_batch", {})
    pending_batch = batch.get("pending_milestones", [])

    ckpt = state.get("checkpoint", {})
    last_approved = ckpt.get("last_codex_approved_commit")
    diff_base = last_approved if checkpoint_cfg.get("prefer_review_since_last_codex_approved_commit", True) else None

    # Determine fingerprint
    fp_result = compute_fingerprint(
        state.get("current_milestone_id"),
        diff_base=diff_base if diff_base else None,
    )
    fp = fp_result["fingerprint"]

    cache_hit = False
    cached_review = None
    if cache_cfg.get("enabled", True) and cache_cfg.get("reuse_review_when_fingerprint_matches", True):
        cached_review = check_cache(fp, state)
        cache_hit = cached_review is not None

    # Decision logic
    decision = "run_codex_full_context"
    review_level = "codex_full_context"
    codex_required = True
    reason = ""
    triggered = []
    should_batch = False

    if gate == "plan_review":
        if triggers.get("always_review_plan", True):
            decision = "run_codex_full_context"
            review_level = "codex_full_context"
            codex_required = True
            reason = "Plan review: always requires Codex full context."
            triggered.append("always_review_plan")
        else:
            decision = "run_codex_targeted"
            review_level = "codex_targeted"

    elif gate == "final_review":
        if triggers.get("always_review_final", True):
            decision = "run_codex_full_context"
            review_level = "codex_full_context"
            codex_required = True
            reason = "Final review: always requires Codex full context."
            triggered.append("always_review_final")
        else:
            decision = "run_codex_targeted"
            review_level = "codex_targeted"

    else:
        # Milestone review
        if risk == "critical":
            decision = "run_codex_full_context"
            review_level = "codex_full_context"
            codex_required = True
            reason = "Critical risk: always Codex full context."
            triggered.append("critical_risk")

        elif risk == "high":
            freq = frequency.get("high_risk_every_n_milestones", 1)
            decision = "run_codex_targeted"
            review_level = "codex_targeted"
            codex_required = True
            reason = f"High risk: Codex required (every {freq} milestone(s))."
            triggered.append("high_risk")

        elif risk == "medium":
            freq = frequency.get("medium_risk_every_n_milestones", 2)
            since_last = get_milestones_since_last_codex(state)
            if (since_last + 1) % freq == 0:
                decision = "run_codex_targeted"
                review_level = "codex_targeted"
                codex_required = True
                reason = f"Medium risk: Codex every {freq} milestone(s)."
            else:
                decision = "skip_codex_use_claude_adversarial"
                review_level = "claude_adversarial"
                codex_required = False
                reason = f"Medium risk: Claude adversarial review. Codex every {freq} milestone(s)."

        else:
            freq = frequency.get("low_risk_every_n_milestones", 3)
            since_last = get_milestones_since_last_codex(state)
            if (since_last + 1) % freq == 0:
                if batch_cfg.get("enabled", True) and len(pending_batch) > 0:
                    decision = "batch_pending"
                    review_level = "codex_targeted"
                    codex_required = True
                    reason = f"Low risk: batch review of {len(pending_batch)} pending milestones."
                    should_batch = True
                else:
                    decision = "run_codex_targeted"
                    review_level = "codex_targeted"
                    codex_required = True
                    reason = f"Low risk: Codex every {freq} milestone(s)."
            else:
                decision = "skip_codex_use_claude_adversarial"
                review_level = "claude_adversarial"
                codex_required = False
                reason = f"Low risk: Claude adversarial review. Codex every {freq} milestone(s)."
                if batch_cfg.get("enabled", True):
                    should_batch = True

        # Large diff trigger
        if diff_lines > triggers.get("large_diff_lines", 800) or diff_files > triggers.get("large_changed_files", 12):
            if not codex_required:
                decision = "run_codex_targeted"
                review_level = "codex_targeted"
                codex_required = True
                reason = f"Large diff ({diff_lines} lines, {diff_files} files): Codex targeted."
            triggered.append("large_diff")

    # Cache check
    if cache_hit and codex_required:
        decision = "cache_hit"
        review_level = "cached"
        codex_required = False
        reason = f"Cache hit: reusing previous review. Fingerprint: {fp[:12]}..."

    # Budget check
    if codex_required and budget_exhausted:
        decision = "budget_exhausted"
        codex_required = False
        reason = f"Budget exhausted ({calls_this_run}/{max_calls}). Using bypass policy."

    result = {
        "decision": decision,
        "review_level": review_level,
        "codex_required": codex_required,
        "reason": reason,
        "triggers": triggered,
        "risk_level": risk,
        "batch": {
            "enabled": batch_cfg.get("enabled", True),
            "pending_milestones": pending_batch,
            "should_review_now": should_batch,
        },
        "budget": {
            "calls_this_run": calls_this_run,
            "max_calls_this_run": max_calls,
            "remaining": budget_remaining,
            "budget_exhausted": budget_exhausted,
        },
        "cache": {
            "fingerprint": fp,
            "cache_hit": cache_hit,
            "cached_review_file": cached_review.get("review_file") if cached_review else None,
        },
        "checkpoint": {
            "diff_base": diff_base,
            "using_last_codex_approved_commit": diff_base is not None,
            "last_codex_approved_commit": last_approved,
        },
        "diff_stats": {
            "lines": diff_lines,
            "files": diff_files,
        },
    }

    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(main())
