#!/usr/bin/env python3
"""CCCC diff-docs — detect docs/cccc document changes without modifying state."""
import json
import sys
import os
import subprocess
from pathlib import Path

sys.path.insert(0, os.path.dirname(__file__))
from cccc_docs import (
    ROOT, WORKSPACE, read_doc_index, compute_doc_status, classify_changes,
    summarize_changes, max_impact, now_utc,
)


def main():
    import argparse
    parser = argparse.ArgumentParser(description="Detect docs/cccc document changes without modifying state")
    parser.parse_args()

    if not WORKSPACE.exists():
        print("ERROR: docs/cccc does not exist. Run /cc-codex-collaborate setup first.", file=sys.stderr)
        return 1

    index = read_doc_index()
    if not index.get("documents"):
        print("doc-index.json is empty or missing.")
        print("Cannot determine which documents are new or modified.")
        print("Suggestion: run /cc-codex-collaborate sync-docs to initialize the index.")
        print()
        print("JSON_SUMMARY:")
        print(json.dumps({"status": "no_index", "changes": [], "max_impact": "unknown"}))
        return 0

    changed = compute_doc_status(index)
    if not changed:
        print("No document changes detected since last sync.")
        print()
        print("JSON_SUMMARY:")
        print(json.dumps({"status": "clean", "changes": [], "max_impact": "low"}))
        return 0

    classified = classify_changes(changed)
    impact = max_impact(classified)
    summary = summarize_changes(classified)

    print("Document changes detected:")
    print()
    for c in classified:
        types_str = " + ".join(c.get("change_types", ["unknown"]))
        print(f"  {c['file']}")
        print(f"    status: {c['status']}")
        print(f"    type: {types_str}")
        print(f"    impact: {c['impact']}")
        print()

    print(f"Max impact: {impact}")
    print()

    if impact in ("high", "critical"):
        print("Recommendation: run /cc-codex-collaborate sync-docs")
        print("High/critical changes may invalidate current planning.")
    elif impact == "medium":
        print("Recommendation: run /cc-codex-collaborate sync-docs")
    else:
        print("Recommendation: run /cc-codex-collaborate sync-docs (low impact, context-only update likely sufficient)")

    print()
    print("JSON_SUMMARY:")
    print(json.dumps({
        "status": "changed",
        "changes": [{k: v for k, v in c.items() if k != "sha256"} for c in classified],
        "max_impact": impact,
        "summary": summary,
    }, ensure_ascii=False, indent=2))

    return 0


if __name__ == "__main__":
    sys.exit(main())
