#!/usr/bin/env python3
"""CCCC Curate Docs — classify, deduplicate, and extract engineering content from raw docs.

Reads source-index.json, processes sources requiring curation,
generates extraction reports, updates source-map and curation-state.
Does NOT modify canonical docs without user confirmation.
"""
import json
import os
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(os.environ.get("CLAUDE_PROJECT_DIR", subprocess.getoutput("git rev-parse --show-toplevel 2>/dev/null || pwd")).strip())
WORKSPACE = ROOT / "docs/cccc"
SOURCE_INDEX = WORKSPACE / "source-index.json"
SOURCE_MAP = WORKSPACE / "source-map.json"
CURATION_STATE = WORKSPACE / "curation-state.json"
CURATION_REPORTS = WORKSPACE / "curation/reports"
CURATION_EXTRACTIONS = WORKSPACE / "curation/extractions"

CLASSIFICATIONS = [
    "engineering_required",
    "engineering_optional",
    "architecture_decision",
    "implementation_task",
    "test_requirement",
    "risk_or_constraint",
    "product_context",
    "business_context",
    "monetization_context",
    "go_to_market_context",
    "irrelevant",
    "unclear",
    "conflict",
]


def load_json(path: Path, default=None):
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except Exception:
        return default if default is not None else {}


def save_json(path: Path, data):
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n")


def cmd_status():
    """Show curation status."""
    index = load_json(SOURCE_INDEX, {"sources": {}})
    cur_state = load_json(CURATION_STATE, {})

    pending = [
        s for s in index.get("sources", {}).values()
        if s.get("requires_curation") and s.get("status") not in ("deleted", "archived", "ignored")
    ]

    print("Curate-docs status:")
    print(f"  Total sources: {len(index.get('sources', {}))}")
    print(f"  Pending curation: {len(pending)}")
    print(f"  Pending conflicts: {len(cur_state.get('pending_conflicts', []))}")
    print(f"  Pending questions: {len(cur_state.get('pending_questions', []))}")
    print(f"  Canonical docs dirty: {cur_state.get('canonical_docs_dirty', False)}")
    print(f"  Requires replan: {cur_state.get('requires_replan', False)}")
    print(f"  Last curated at: {cur_state.get('last_curated_at', 'never')}")

    if pending:
        print("")
        print("Sources requiring curation:")
        for s in pending[:10]:
            print(f"  - {s['path']} ({s.get('status', 'unknown')}, {s.get('source_type', 'unknown')})")
        if len(pending) > 10:
            print(f"  ... and {len(pending) - 10} more")


def cmd_report():
    """Generate extraction report for sources requiring curation."""
    index = load_json(SOURCE_INDEX, {"sources": {}})
    source_map = load_json(SOURCE_MAP, {"version": 1, "last_updated_at": None, "mappings": []})
    cur_state = load_json(CURATION_STATE, {"version": 1, "pending_sources": [], "pending_conflicts": [], "pending_questions": [], "canonical_docs_dirty": False, "requires_replan": False})

    now = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

    pending = [
        s for s in index.get("sources", {}).values()
        if s.get("requires_curation") and s.get("status") not in ("deleted", "archived", "ignored")
    ]

    if not pending:
        print("No sources requiring curation.")
        print("Run /cccc sync-inbox first to discover new or changed documents.")
        return

    # Read source contents
    extractions = []
    for s in pending:
        src_path = ROOT / s["path"]
        content = ""
        if src_path.exists():
            try:
                content = src_path.read_text(encoding="utf-8", errors="replace")[:50000]
            except Exception:
                content = f"(cannot read: {s['path']})"

        extractions.append({
            "source_path": s["path"],
            "source_hash": s.get("sha256", ""),
            "source_type": s.get("source_type", "unknown"),
            "content_preview": content[:2000],
            "classification_pending": True,
        })

    # Generate extraction report
    CURATION_REPORTS.mkdir(parents=True, exist_ok=True)
    CURATION_EXTRACTIONS.mkdir(parents=True, exist_ok=True)

    report_ts = now.replace(":", "-").replace("T", "_")
    report_file = CURATION_REPORTS / f"curation-report-{report_ts}.md"
    extraction_file = CURATION_EXTRACTIONS / f"extraction-{report_ts}.json"

    # Write report
    report_lines = [
        f"# Curation Report",
        f"",
        f"Generated: {now}",
        f"Sources analyzed: {len(pending)}",
        f"",
        f"## Sources",
        f"",
    ]
    for ext in extractions:
        report_lines.append(f"### {ext['source_path']}")
        report_lines.append(f"- Type: {ext['source_type']}")
        report_lines.append(f"- Hash: {ext['source_hash'][:16]}...")
        report_lines.append(f"- Preview: {ext['content_preview'][:200]}...")
        report_lines.append("")

    report_file.write_text("\n".join(report_lines) + "\n")

    # Write machine-readable extraction
    save_json(extraction_file, {
        "generated_at": now,
        "sources_analyzed": len(pending),
        "extractions": extractions,
    })

    # Update curation-state
    cur_state["pending_sources"] = [s["path"] for s in pending]
    cur_state["last_extraction_report"] = str(report_file.relative_to(ROOT))
    save_json(CURATION_STATE, cur_state)

    print(f"CURATION_REPORT_GENERATED=true")
    print(f"Report: {report_file}")
    print(f"Extraction: {extraction_file}")
    print(f"Sources analyzed: {len(pending)}")
    print("")
    print("Claude Code must now:")
    print("  1. Read each source content")
    print("  2. Classify content into categories")
    print("  3. Identify conflicts")
    print("  4. Ask the user with brainstorm-style options")
    print("  5. Update canonical docs after user confirmation")
    print("")
    print("SYNC_AWAITING_DECISION=true")


def cmd_apply(strategy: str = "adopt"):
    """Mark sources as curated after user decision."""
    index = load_json(SOURCE_INDEX, {"sources": {}})
    source_map = load_json(SOURCE_MAP, {"version": 1, "last_updated_at": None, "mappings": []})
    cur_state = load_json(CURATION_STATE, {"version": 1, "pending_sources": [], "pending_conflicts": [], "pending_questions": [], "canonical_docs_dirty": False, "requires_replan": False})

    now = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

    # Mark pending sources as curated
    for path_str in cur_state.get("pending_sources", []):
        if path_str in index.get("sources", {}):
            index["sources"][path_str]["last_curated_at"] = now
            index["sources"][path_str]["requires_curation"] = False
            index["sources"][path_str]["status"] = "unchanged"

    source_map["last_updated_at"] = now
    cur_state["last_curated_at"] = now
    cur_state["pending_sources"] = []

    save_json(SOURCE_INDEX, index)
    save_json(SOURCE_MAP, source_map)
    save_json(CURATION_STATE, cur_state)

    print(f"Applied curation with strategy: {strategy}")
    print(f"Sources curated: {len(cur_state.get('pending_sources', []))}")
    print(f"Timestamp: {now}")


def main():
    import argparse
    parser = argparse.ArgumentParser(description="Curate raw documents")
    parser.add_argument("subcommand", nargs="?", default="status", choices=["status", "report", "apply"])
    parser.add_argument("--strategy", default="adopt")
    args = parser.parse_args()

    if args.subcommand == "status":
        cmd_status()
    elif args.subcommand == "report":
        cmd_report()
    elif args.subcommand == "apply":
        cmd_apply(strategy=args.strategy)


if __name__ == "__main__":
    main()
