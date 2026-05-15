#!/usr/bin/env python3
"""CCCC review fingerprint — compute review cache fingerprint."""
import argparse
import hashlib
import json
import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(os.environ.get("CLAUDE_PROJECT_DIR",
                            subprocess.getoutput("git rev-parse --show-toplevel 2>/dev/null || pwd")).strip())
WORKSPACE = ROOT / "docs/cccc"


def sha256_of(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


def get_diff_stat() -> str:
    try:
        r = subprocess.run(["git", "diff", "--stat"], capture_output=True, text=True, cwd=str(ROOT), timeout=10)
        return r.stdout.strip()
    except Exception:
        return ""


def get_diff_content(since: str | None = None) -> str:
    try:
        cmd = ["git", "diff"]
        if since:
            cmd.append(since)
        r = subprocess.run(cmd, capture_output=True, text=True, cwd=str(ROOT), timeout=15)
        return r.stdout.strip()
    except Exception:
        return ""


def compute_fingerprint(milestone_id: str | None = None,
                        acceptance_criteria: str = "",
                        diff: str = "",
                        test_summary: str = "",
                        docs_hash: str = "") -> dict:
    components = {
        "milestone": milestone_id or "",
        "acceptance_criteria_hash": sha256_of(acceptance_criteria),
        "diff_hash": sha256_of(diff),
        "test_hash": sha256_of(test_summary),
        "docs_hash": docs_hash,
    }

    combined = json.dumps(components, sort_keys=True)
    fingerprint = sha256_of(combined)

    return {
        "fingerprint": fingerprint,
        "components": components,
    }


def check_cache(fingerprint: str, state: dict) -> dict | None:
    cache = state.get("codex_review_cache", {})
    entry = cache.get(fingerprint)
    if entry:
        review_file = entry.get("review_file", "")
        status = entry.get("status", "")
        if status == "pass" and review_file:
            return entry
    return None


def record_cache(fingerprint: str, review_file: str, status: str, state_path: Path):
    state = json.loads(state_path.read_text(encoding="utf-8"))
    state.setdefault("codex_review_cache", {})[fingerprint] = {
        "review_file": review_file,
        "status": status,
        "recorded_at": __import__("datetime").datetime.now(
            __import__("datetime").timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    }
    state_path.write_text(json.dumps(state, ensure_ascii=False, indent=2) + "\n")


def main():
    parser = argparse.ArgumentParser(
        description="Compute review fingerprint from milestone diff",
    )
    subparsers = parser.add_subparsers(dest="command")

    p_compute = subparsers.add_parser("compute", help="Compute fingerprint for current milestone diff")
    p_compute.add_argument("--milestone", default=None, help="Milestone ID")
    p_compute.add_argument("--since", default=None, help="Git commit to diff since")

    p_check = subparsers.add_parser("check-cache", help="Check if fingerprint exists in cache")
    p_check.add_argument("--fingerprint", required=True, help="Fingerprint to check")

    p_record = subparsers.add_parser("record-cache", help="Record a fingerprint in cache")
    p_record.add_argument("--fingerprint", required=True, help="Fingerprint to record")
    p_record.add_argument("--review-file", required=True, help="Path to review file")
    p_record.add_argument("--status", required=True, help="Review status")

    args = parser.parse_args()

    if not args.command:
        parser.print_help()
        return 0

    cmd = args.command

    if cmd == "compute":
        milestone_id = args.milestone
        since = args.since

        diff = get_diff_content(since)

        state_path = WORKSPACE / "state.json"
        acceptance_criteria = ""
        test_summary = ""
        if state_path.exists():
            st = json.loads(state_path.read_text(encoding="utf-8"))
            mid = milestone_id or st.get("current_milestone_id", "")
            acceptance_criteria = mid

        docs_hash_parts = []
        for doc in ["architecture.md", "roadmap.md", "milestone-backlog.md"]:
            p = WORKSPACE / doc
            if p.exists():
                docs_hash_parts.append(sha256_of(p.read_text(encoding="utf-8")[:2000]))
        docs_hash = sha256_of("|".join(docs_hash_parts))

        result = compute_fingerprint(milestone_id, acceptance_criteria, diff, test_summary, docs_hash)
        print(json.dumps(result, ensure_ascii=False, indent=2))
        return 0

    elif cmd == "check-cache":
        fp = args.fingerprint

        state_path = WORKSPACE / "state.json"
        state = json.loads(state_path.read_text(encoding="utf-8"))
        hit = check_cache(fp, state)
        print(json.dumps({"cache_hit": hit is not None, "entry": hit}, ensure_ascii=False, indent=2))
        return 0

    elif cmd == "record-cache":
        fp = args.fingerprint
        review_file = args.review_file
        status = args.status

        state_path = WORKSPACE / "state.json"
        record_cache(fp, review_file, status, state_path)
        print(json.dumps({"recorded": True, "fingerprint": fp}, ensure_ascii=False, indent=2))
        return 0

    return 0


if __name__ == "__main__":
    sys.exit(main())
