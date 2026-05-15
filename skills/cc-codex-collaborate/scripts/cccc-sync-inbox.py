#!/usr/bin/env python3
"""CCCC Sync Inbox — incremental discovery of raw/inbox document changes.

Scans docs/cccc/inbox/ for new, changed, or deleted text files.
Updates source-index.json. Does NOT modify canonical docs or roadmap.
"""
import hashlib
import json
import os
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(os.environ.get("CLAUDE_PROJECT_DIR", subprocess.getoutput("git rev-parse --show-toplevel 2>/dev/null || pwd")).strip())
WORKSPACE = ROOT / "docs/cccc"
INBOX = WORKSPACE / "inbox"
SOURCE_INDEX = WORKSPACE / "source-index.json"

TEXT_EXTENSIONS = {".md", ".txt", ".json", ".yaml", ".yml", ".csv", ".rst"}
SKIP_DIRS = {"logs", "reviews", "backups", "runtime", "canonical", "product", "archive", "curation", "node_modules", ".git"}
DEFAULT_MAX_FILE_BYTES = 1024 * 1024  # 1MB


def sha256_of(path: Path) -> str | None:
    try:
        h = hashlib.sha256()
        with open(path, "rb") as f:
            for chunk in iter(lambda: f.read(8192), b""):
                h.update(chunk)
        return h.hexdigest()
    except Exception:
        return None


def classify_source(path: Path) -> str:
    parts = path.relative_to(INBOX).parts
    if len(parts) >= 2:
        subdir = parts[0]
        if subdir == "raw-notes":
            return "raw_note"
        elif subdir == "gpt-discussions":
            return "gpt_discussion"
        elif subdir == "imported-docs":
            return "imported_doc"
    return "unknown"


def scan_inbox(max_file_bytes: int = DEFAULT_MAX_FILE_BYTES) -> dict[str, dict]:
    """Scan inbox directory and return {relative_path_str: file_info}."""
    found = {}
    if not INBOX.exists():
        return found

    for path in INBOX.rglob("*"):
        if not path.is_file():
            continue
        if path.suffix.lower() not in TEXT_EXTENSIONS:
            continue
        # Skip if in skip dirs
        try:
            rel = path.relative_to(INBOX)
            if any(p in SKIP_DIRS for p in rel.parts):
                continue
        except ValueError:
            continue
        # Skip large files
        try:
            if path.stat().st_size > max_file_bytes:
                continue
        except OSError:
            continue

        rel_str = str(path.relative_to(ROOT))
        h = sha256_of(path)
        found[rel_str] = {
            "path": rel_str,
            "sha256": h,
            "size_bytes": path.stat().st_size,
            "source_type": classify_source(path),
        }

    return found


def sync(max_file_bytes: int = DEFAULT_MAX_FILE_BYTES, json_output: bool = False):
    now = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

    # Load or create source-index
    if SOURCE_INDEX.exists():
        try:
            index = json.loads(SOURCE_INDEX.read_text(encoding="utf-8"))
        except Exception:
            index = {"version": 1, "last_synced_at": None, "sources": {}}
    else:
        index = {"version": 1, "last_synced_at": None, "sources": {}}
    index.setdefault("sources", {})

    found = scan_inbox(max_file_bytes)

    # Determine statuses
    new_count = 0
    changed_count = 0
    deleted_count = 0
    unchanged_count = 0
    pending_curation = 0

    existing_paths = set(index["sources"].keys())
    found_paths = set(found.keys())

    # Deleted sources
    for path in existing_paths - found_paths:
        src = index["sources"][path]
        if src.get("status") not in ("deleted", "archived", "ignored"):
            src["status"] = "deleted"
            deleted_count += 1

    # New and changed sources
    for path, info in found.items():
        if path not in index["sources"]:
            # New source
            entry = {
                "path": info["path"],
                "sha256": info["sha256"],
                "size_bytes": info["size_bytes"],
                "first_seen_at": now,
                "last_seen_at": now,
                "last_curated_at": None,
                "status": "new",
                "source_type": info["source_type"],
                "requires_curation": True,
            }
            index["sources"][path] = entry
            new_count += 1
            pending_curation += 1
        else:
            # Existing source — check for changes
            entry = index["sources"][path]
            old_hash = entry.get("sha256")
            entry["last_seen_at"] = now
            entry["size_bytes"] = info["size_bytes"]
            entry["source_type"] = info["source_type"]

            if old_hash != info["sha256"]:
                entry["sha256"] = info["sha256"]
                if entry.get("status") not in ("archived", "ignored"):
                    entry["status"] = "changed"
                    entry["requires_curation"] = True
                    changed_count += 1
                    pending_curation += 1
            else:
                if entry.get("status") not in ("archived", "ignored", "deleted"):
                    entry["status"] = "unchanged"
                    unchanged_count += 1

    # Count pending curation
    for entry in index["sources"].values():
        if entry.get("requires_curation") and entry.get("status") not in ("deleted", "archived", "ignored"):
            pass  # already counted above

    index["last_synced_at"] = now
    SOURCE_INDEX.write_text(json.dumps(index, ensure_ascii=False, indent=2) + "\n")

    # Output
    if json_output:
        result = {
            "sync_result": "done",
            "new_count": new_count,
            "changed_count": changed_count,
            "deleted_count": deleted_count,
            "unchanged_count": unchanged_count,
            "pending_curation": sum(
                1 for s in index["sources"].values()
                if s.get("requires_curation") and s.get("status") not in ("deleted", "archived", "ignored")
            ),
            "total_sources": len(index["sources"]),
        }
        print(json.dumps(result, indent=2))
    else:
        print("sync-inbox result:")
        print(f"  New: {new_count}")
        print(f"  Changed: {changed_count}")
        print(f"  Deleted: {deleted_count}")
        print(f"  Unchanged: {unchanged_count}")
        pending = sum(
            1 for s in index["sources"].values()
            if s.get("requires_curation") and s.get("status") not in ("deleted", "archived", "ignored")
        )
        print(f"  Pending curation: {pending}")
        print(f"  Total sources: {len(index['sources'])}")
        if pending > 0:
            print("")
            print("Next: /cccc curate-docs")
        else:
            print("")
            print("No pending sources requiring curation.")


def main():
    import argparse
    parser = argparse.ArgumentParser(description="Sync inbox documents")
    parser.add_argument("--json", action="store_true", help="JSON output")
    parser.add_argument("--path", help="Additional path to scan")
    parser.add_argument("--max-file-bytes", type=int, default=DEFAULT_MAX_FILE_BYTES)
    args = parser.parse_args()
    sync(max_file_bytes=args.max_file_bytes, json_output=args.json)


if __name__ == "__main__":
    main()
