#!/usr/bin/env python3
"""CCCC sync-docs — detect and sync docs/cccc document changes with user interaction."""
import json
import sys
import os
import subprocess
from pathlib import Path

sys.path.insert(0, os.path.dirname(__file__))
from cccc_docs import (
    ROOT, WORKSPACE, TRACKED_DOCS, SEMANTIC_ROLES,
    read_json, write_json, file_sha256, now_utc,
    read_doc_index, write_doc_index, compute_doc_status, classify_changes,
    summarize_changes, max_impact,
)


def init_doc_index(index: dict) -> dict:
    for doc_name in TRACKED_DOCS:
        path = WORKSPACE / doc_name
        h = file_sha256(path)
        if h:
            index.setdefault("documents", {})[doc_name] = {
                "sha256": h,
                "size_bytes": path.stat().st_size,
                "last_seen_at": now_utc(),
                "semantic_role": SEMANTIC_ROLES.get(doc_name, "unknown"),
                "last_change_type": None,
            }
    return index


def apply_option_a(changes: list[dict], summary: str):
    state_path = WORKSPACE / "state.json"
    state = read_json(state_path) or {}

    state["docs_sync_status"] = "changed"
    state["docs_changed_since_last_sync"] = True
    state["planning_invalidated_by_doc_change"] = True
    state["planning_invalidation_reason"] = summary
    state["roadmap_status"] = "stale_due_to_doc_change"
    state["codex_plan_review_status"] = "invalidated"
    state["status"] = "NEEDS_REPLAN"
    state["pause_reason"] = "Documentation changes require replan before implementation."
    state["last_doc_change_summary"] = summary
    state["last_doc_change_impact"] = max_impact(changes)
    state["last_doc_sync_decision"] = "adopt_and_replan"
    state["last_docs_sync_at"] = now_utc()
    state["updated_at"] = now_utc()

    write_json(state_path, state)

    index = read_doc_index()
    for c in changes:
        doc_name = c["file"]
        path = WORKSPACE / doc_name
        h = file_sha256(path)
        index.setdefault("documents", {})[doc_name] = {
            "sha256": h,
            "size_bytes": path.stat().st_size if path.exists() else 0,
            "last_seen_at": now_utc(),
            "semantic_role": SEMANTIC_ROLES.get(doc_name, "unknown"),
            "last_change_type": " + ".join(c.get("change_types", ["unknown"])),
        }
    index["last_synced_at"] = now_utc()
    index["last_change_summary"] = summary
    write_doc_index(index)

    write_decision_log("adopt_and_replan", changes, summary)


def apply_option_b(changes: list[dict], summary: str):
    state_path = WORKSPACE / "state.json"
    state = read_json(state_path) or {}

    state["docs_sync_status"] = "context_updated"
    state["docs_changed_since_last_sync"] = False
    state["last_doc_change_summary"] = summary
    state["last_doc_change_impact"] = max_impact(changes)
    state["last_doc_sync_decision"] = "context_only"
    state["last_docs_sync_at"] = now_utc()
    state["updated_at"] = now_utc()

    write_json(state_path, state)

    index = read_doc_index()
    for c in changes:
        doc_name = c["file"]
        path = WORKSPACE / doc_name
        h = file_sha256(path)
        index.setdefault("documents", {})[doc_name] = {
            "sha256": h,
            "size_bytes": path.stat().st_size if path.exists() else 0,
            "last_seen_at": now_utc(),
            "semantic_role": SEMANTIC_ROLES.get(doc_name, "unknown"),
            "last_change_type": " + ".join(c.get("change_types", ["unknown"])),
        }
    index["last_synced_at"] = now_utc()
    index["last_change_summary"] = summary
    write_doc_index(index)

    write_decision_log("context_only", changes, summary)


def apply_option_c(summary: str):
    state_path = WORKSPACE / "state.json"
    state = read_json(state_path) or {}

    state["status"] = "PAUSED_FOR_HUMAN"
    state["pause_reason"] = "Documentation changes detected and require manual decision."
    state["last_doc_sync_decision"] = "pause"
    state["last_docs_sync_at"] = now_utc()
    state["updated_at"] = now_utc()

    write_json(state_path, state)
    write_decision_log("pause", [], summary)


def apply_option_d(changes: list[dict], summary: str):
    index = read_doc_index()
    for c in changes:
        doc_name = c["file"]
        path = WORKSPACE / doc_name
        h = file_sha256(path)
        index.setdefault("documents", {})[doc_name] = {
            "sha256": h,
            "size_bytes": path.stat().st_size if path.exists() else 0,
            "last_seen_at": now_utc(),
            "semantic_role": SEMANTIC_ROLES.get(doc_name, "unknown"),
            "last_change_type": " + ".join(c.get("change_types", ["unknown"])),
        }
    index["last_synced_at"] = now_utc()
    write_doc_index(index)

    write_decision_log("ignore", changes, "User chose to ignore doc changes for workflow state.")


def write_decision_log(decision: str, changes: list[dict], summary: str):
    log_path = WORKSPACE / "decision-log.md"
    ts = now_utc()
    entry = f"\n## Docs sync at {ts}\n- Decision: {decision}\n- Summary: {summary}\n"
    if changes:
        for c in changes:
            types_str = " + ".join(c.get("change_types", ["unknown"]))
            entry += f"- {c['file']}: {c['status']} | {types_str} | impact={c['impact']}\n"

    if log_path.exists():
        log_path.write_text(log_path.read_text(encoding="utf-8") + entry)
    else:
        log_path.write_text(f"# Decision Log{entry}")


def main():
    if not WORKSPACE.exists():
        print("ERROR: docs/cccc does not exist. Run /cc-codex-collaborate setup first.", file=sys.stderr)
        return 1

    strategy = None
    for arg in sys.argv[1:]:
        if arg.startswith("--strategy="):
            strategy = arg.split("=", 1)[1]

    index = read_doc_index()
    is_first_sync = not index.get("documents")

    if is_first_sync:
        print("doc-index.json is empty or missing. Initializing first sync.")
        init_doc_index(index)
        index["last_synced_at"] = now_utc()
        write_doc_index(index)

        state_path = WORKSPACE / "state.json"
        state = read_json(state_path) or {}
        state["docs_sync_status"] = "clean"
        state["docs_changed_since_last_sync"] = False
        state["last_docs_sync_at"] = now_utc()
        state["updated_at"] = now_utc()
        write_json(state_path, state)

        print("First sync complete. All documents indexed as baseline.")
        print("No changes detected (baseline established).")
        return 0

    changed = compute_doc_status(index)
    if not changed:
        print("No document changes detected since last sync.")

        state_path = WORKSPACE / "state.json"
        state = read_json(state_path) or {}
        state["docs_sync_status"] = "clean"
        state["docs_changed_since_last_sync"] = False
        state["last_docs_sync_at"] = now_utc()
        state["updated_at"] = now_utc()
        write_json(state_path, state)

        index["last_synced_at"] = now_utc()
        write_doc_index(index)
        return 0

    classified = classify_changes(changed)
    impact = max_impact(classified)
    summary = summarize_changes(classified)

    if strategy:
        return apply_strategy(strategy, classified, impact, summary)

    print("Document changes detected:")
    print()
    for c in classified:
        types_str = " + ".join(c.get("change_types", ["unknown"]))
        print(f"  {c['file']}")
        print(f"    type: {types_str}")
        print(f"    impact: {c['impact']}")
        desc = _describe_change(c)
        if desc:
            print(f"    {desc}")
        print()

    print(f"Max impact: {impact}")
    print()
    print("How would you like to sync these changes?")
    print()
    print("A. Adopt docs as new source of truth, invalidate old plan, and replan (Recommended)")
    print("B. Only update context-bundle, do not change roadmap or Codex approval")
    print("C. Pause workflow, record risk, handle manually later")
    print("D. Ignore these changes, only update doc-index")
    print("E. View detailed diff, then decide")
    print("F. Custom: describe what you want")

    if impact in ("high", "critical"):
        print()
        print("Default recommendation: A (adopt and replan) due to high/critical impact.")

    print()
    print("SYNC_AWAITING_DECISION=true")
    print(f"SYNC_MAX_IMPACT={impact}")
    print(f"SYNC_CHANGE_COUNT={len(classified)}")
    return 0


def _describe_change(c: dict) -> str:
    types = c.get("change_types", [])
    if "stack_change" in types:
        return "Technology stack change detected — old roadmap may be invalid."
    if "architecture_change" in types:
        return "Architecture change detected — old roadmap may be invalid."
    if "roadmap_change" in types:
        return "Roadmap was modified — milestone order or scope may have changed."
    if "milestone_change" in types:
        return "Milestone backlog was modified — current milestone may have changed."
    if "risk_policy_change" in types:
        return "Risk register was modified — safety constraints may have changed."
    if "testing_policy_change" in types:
        return "Test strategy was modified."
    if "brief_change" in types:
        return "Project brief or goals were modified."
    if "open_question_change" in types:
        return "Open questions were modified."
    return ""


def apply_strategy(strategy: str, classified: list[dict], impact: str, summary: str) -> int:
    if strategy == "adopt_and_replan":
        apply_option_a(classified, summary)
        print("Adopted docs as new source of truth. Planning invalidated.")
        print("State: NEEDS_REPLAN")
        print("Next: /cc-codex-collaborate replan")
    elif strategy == "context_only":
        if impact in ("high", "critical"):
            print("WARNING: High/critical impact detected but choosing context-only update.")
            print("This may cause roadmap/architecture inconsistency.")
        apply_option_b(classified, summary)
        print("Context updated. Planning NOT invalidated.")
        print("Next: /cc-codex-collaborate gates or continue workflow")
    elif strategy == "pause":
        apply_option_c(summary)
        print("Workflow paused for manual decision.")
        print("Next: /cc-codex-collaborate sync-docs or /cc-codex-collaborate resume")
    elif strategy == "ignore":
        if impact in ("high", "critical"):
            print("WARNING: High/critical impact detected but choosing to ignore.")
        apply_option_d(classified, summary)
        print("Changes ignored. Only doc-index updated.")
    elif strategy == "view_diff":
        _show_diff(classified)
        print()
        print("View the diff above, then re-run sync-docs with a decision.")
    else:
        print(f"Unknown strategy: {strategy}")
        print("Claude Code must ask the user to choose A/B/C/D/E/F.")
        return 1
    return 0


def _show_diff(changes: list[dict]):
    try:
        for c in changes:
            doc_name = c["file"]
            result = subprocess.run(
                ["git", "diff", "--", f"docs/cccc/{doc_name}"],
                capture_output=True, text=True, cwd=str(ROOT), timeout=10,
            )
            if result.stdout.strip():
                print(f"--- {doc_name} ---")
                lines = result.stdout.strip().split("\n")
                print("\n".join(lines[:80]))
                if len(lines) > 80:
                    print(f"... ({len(lines) - 80} more lines)")
                print()
            else:
                print(f"--- {doc_name}: no git diff available (possibly untracked) ---")
                path = WORKSPACE / doc_name
                if path.exists():
                    text = path.read_text(encoding="utf-8")
                    preview = text[:500]
                    print(preview)
                    if len(text) > 500:
                        print("... (truncated)")
                print()
    except Exception as e:
        print(f"Could not show diff: {e}")


if __name__ == "__main__":
    sys.exit(main())
