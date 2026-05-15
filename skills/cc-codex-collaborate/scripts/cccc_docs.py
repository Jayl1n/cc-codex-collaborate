"""Shared module for docs sync: hash detection, semantic classification, impact levels."""
import hashlib
import json
import os
import re
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(os.environ.get("CLAUDE_PROJECT_DIR",
                            subprocess.getoutput("git rev-parse --show-toplevel 2>/dev/null || pwd")).strip())
WORKSPACE = ROOT / "docs/cccc"

TRACKED_DOCS = [
    "project-brief.md",
    "project-map.md",
    "current-state.md",
    "architecture.md",
    "test-strategy.md",
    "roadmap.md",
    "milestone-backlog.md",
    "decision-log.md",
    "risk-register.md",
    "open-questions.md",
]

SEMANTIC_ROLES = {
    "project-brief.md": "brief",
    "project-map.md": "brief",
    "current-state.md": "state",
    "architecture.md": "architecture",
    "test-strategy.md": "testing",
    "roadmap.md": "roadmap",
    "milestone-backlog.md": "milestones",
    "decision-log.md": "unknown",
    "risk-register.md": "risks",
    "open-questions.md": "unknown",
}

CHANGE_TYPES = [
    "minor_doc_change",
    "architecture_change",
    "stack_change",
    "roadmap_change",
    "milestone_change",
    "risk_policy_change",
    "testing_policy_change",
    "brief_change",
    "open_question_change",
    "unknown_high_impact_change",
]

IMPACT_LEVELS = ["low", "medium", "high", "critical"]


def read_json(path: Path) -> dict | None:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except Exception:
        return None


def write_json(path: Path, data: dict):
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n")


def file_sha256(path: Path) -> str | None:
    if not path.exists():
        return None
    h = hashlib.sha256()
    for chunk in iter(lambda: path.open("rb").read(8192), b""):
        h.update(chunk)
    return h.hexdigest()


def now_utc() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def read_doc_index() -> dict:
    path = WORKSPACE / "doc-index.json"
    data = read_json(path)
    if data is None:
        return {"version": 1, "last_synced_at": None, "last_diff_at": None,
                "documents": {}, "last_change_summary": None}
    return data


def write_doc_index(index: dict):
    write_json(WORKSPACE / "doc-index.json", index)


def compute_doc_status(index: dict) -> list[dict]:
    results = []
    for doc_name in TRACKED_DOCS:
        path = WORKSPACE / doc_name
        entry = index.get("documents", {}).get(doc_name, {})
        old_hash = entry.get("sha256")
        current_hash = file_sha256(path)
        semantic_role = SEMANTIC_ROLES.get(doc_name, "unknown")

        if not path.exists():
            if old_hash:
                status = "deleted"
            else:
                continue
        elif old_hash is None:
            status = "added"
        elif current_hash != old_hash:
            status = "modified"
        else:
            status = "unchanged"

        if status == "unchanged":
            continue

        results.append({
            "file": doc_name,
            "status": status,
            "semantic_role": semantic_role,
            "sha256": current_hash,
            "size_bytes": path.stat().st_size if path.exists() else 0,
        })
    return results


def classify_changes(changed: list[dict]) -> list[dict]:
    for item in changed:
        doc = item["file"]
        status = item["status"]
        if status == "deleted":
            item["change_types"] = ["unknown_high_impact_change"]
            item["impact"] = "critical"
            continue

        text = ""
        path = WORKSPACE / doc
        if path.exists():
            try:
                text = path.read_text(encoding="utf-8").lower()
            except Exception:
                text = ""

        change_types = []

        if doc == "architecture.md" or doc == "current-state.md":
            if _has_architecture_keywords(text):
                change_types.append("architecture_change")
            if _has_stack_keywords(text):
                change_types.append("stack_change")
            if not change_types:
                change_types.append("minor_doc_change")

        elif doc == "roadmap.md":
            change_types.append("roadmap_change")

        elif doc == "milestone-backlog.md":
            change_types.append("milestone_change")

        elif doc == "risk-register.md":
            change_types.append("risk_policy_change")

        elif doc == "test-strategy.md":
            change_types.append("testing_policy_change")

        elif doc == "project-brief.md" or doc == "project-map.md":
            change_types.append("brief_change")

        elif doc == "open-questions.md":
            change_types.append("open_question_change")

        else:
            change_types.append("minor_doc_change")

        if not change_types:
            change_types = ["minor_doc_change"]

        item["change_types"] = change_types
        item["impact"] = _compute_impact(doc, change_types, status)

    return changed


def _has_architecture_keywords(text: str) -> bool:
    keywords = ["architecture", "backend", "frontend", "database", " db",
                "storage", "auth", "api", "service", "module", "framework",
                "server", "架构"]
    return any(kw in text for kw in keywords)


def _has_stack_keywords(text: str) -> bool:
    stack_patterns = [
        r"mysql", r"postgresql", r"postgres", r"sqlite", r"mongodb", r"redis",
        r"express", r"fastify", r"koa", r"nest", r"next\.?js", r"nextjs",
        r"react", r"vue", r"svelte", r"prisma", r"drizzle", r"typeorm", r"sequelize",
        r"\bgo\b", r"\brust\b", r"\bpython\b", r"\bnode\b",
        r"切换到", r"迁移到", r"改为", r"换成",
        r"switch\s+to", r"migrate\s+to", r"change\s+to", r"move\s+to",
    ]
    return any(re.search(p, text) for p in stack_patterns)


def _compute_impact(doc: str, change_types: list[str], status: str) -> str:
    if status == "deleted":
        return "critical"

    if "stack_change" in change_types:
        return "critical"
    if "risk_policy_change" in change_types:
        return "high"
    if "architecture_change" in change_types:
        return "high"
    if "roadmap_change" in change_types:
        return "high"
    if "milestone_change" in change_types:
        return "medium"
    if "brief_change" in change_types:
        return "high"
    if "testing_policy_change" in change_types:
        return "medium"
    if "open_question_change" in change_types:
        return "medium"
    if "minor_doc_change" in change_types:
        return "low"
    return "medium"


def max_impact(changes: list[dict]) -> str:
    order = {"critical": 4, "high": 3, "medium": 2, "low": 1}
    best = "low"
    for c in changes:
        if order.get(c.get("impact", "low"), 0) > order.get(best, 0):
            best = c["impact"]
    return best


def summarize_changes(changes: list[dict]) -> str:
    if not changes:
        return "No document changes detected."
    lines = []
    for c in changes:
        types_str = " + ".join(c.get("change_types", ["unknown"]))
        lines.append(f"- {c['file']}: {c['status']} | {types_str} | impact={c['impact']}")
    return "\n".join(lines)
