#!/usr/bin/env python3
"""CCCC bypass-codex — manage Codex bypass when Codex is unavailable."""
import json
import os
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(os.environ.get("CLAUDE_PROJECT_DIR",
                            subprocess.getoutput("git rev-parse --show-toplevel 2>/dev/null || pwd")).strip())
WORKSPACE = ROOT / "docs/cccc"
BYPASS_DIR = WORKSPACE / "reviews" / "bypass"


def read_json(path: Path) -> dict | None:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except Exception:
        return None


def write_json(path: Path, data: dict):
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n")


def now_utc() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def load_config() -> dict:
    return read_json(WORKSPACE / "config.json") or {}


def load_state() -> dict:
    return read_json(WORKSPACE / "state.json") or {}


def save_state(state: dict):
    state["updated_at"] = now_utc()
    write_json(WORKSPACE / "state.json", state)


def get_bypass_cfg(cfg: dict) -> dict:
    return cfg.get("codex", {}).get("bypass", {})


def get_current_gate(state: dict) -> str | None:
    plan_status = state.get("codex_plan_review_status", "not_run")
    ms_status = state.get("current_milestone_codex_review_status", "not_run")
    final_status = state.get("codex_final_review_status", "not_run")
    current_status = state.get("status", "")

    if plan_status in ("not_run", "fail", "invalidated") and current_status not in ("DONE", "COMPLETED"):
        return "plan_review"
    if final_status in ("not_run", "fail") and current_status not in ("DONE", "COMPLETED"):
        return "final_review"
    if ms_status in ("not_run", "fail") and state.get("current_milestone_id"):
        return "milestone_review"
    return None


def get_risk_level(state: dict, cfg: dict) -> str:
    known_risks = state.get("known_risks", [])
    has_critical = any("critical" in str(r).lower() for r in known_risks)
    has_high = any("high" in str(r).lower() for r in known_risks)
    safety = cfg.get("safety", {})
    if has_critical or any([safety.get("pause_on_real_secrets"), safety.get("pause_on_wallet_private_keys"),
                            safety.get("pause_on_production_access"), safety.get("pause_on_real_money")]):
        return "critical"
    if has_high:
        return "high"
    return "medium"


SENSITIVE_KEYWORDS = ["wallet", "private_key", "seed_phrase", "mainnet", "production",
                       "real_money", "destructive", "secret", "auth_critical"]


def is_sensitive_operation(state: dict) -> bool:
    pause_reason = (state.get("pause_reason") or "").lower()
    return any(kw in pause_reason for kw in SENSITIVE_KEYWORDS)


def can_bypass(state: dict, cfg: dict) -> tuple[bool, str]:
    codex_cfg = cfg.get("codex", {})
    bypass_cfg = get_bypass_cfg(cfg)

    if not bypass_cfg.get("enabled", False):
        return False, "Bypass not enabled in config."

    if not codex_cfg.get("required", True):
        return False, "Codex not required — no bypass needed."

    risk = get_risk_level(state, cfg)
    if risk == "critical":
        return False, "Critical risk: bypass prohibited."
    if risk == "high" and not bypass_cfg.get("allow_for_high_risk", False):
        return False, "High risk: bypass prohibited by default."

    if is_sensitive_operation(state):
        return False, "Sensitive operation detected: bypass prohibited."

    max_consec = bypass_cfg.get("max_consecutive_bypassed_gates", 1)
    consec = state.get("consecutive_bypassed_gates", 0)
    if consec >= max_consec:
        return False, f"Max consecutive bypassed gates ({max_consec}) reached."

    return True, ""


def cmd_status(cfg: dict, state: dict):
    codex_cfg = cfg.get("codex", {})
    bypass_cfg = get_bypass_cfg(codex_cfg)

    print("Codex bypass status:")
    print(f"  codex.required: {codex_cfg.get('required', True)}")
    print(f"  codex.fail_closed: {codex_cfg.get('fail_closed', True)}")
    print(f"  unavailable_policy: {codex_cfg.get('unavailable_policy', 'strict_pause')}")
    print(f"  bypass.enabled: {bypass_cfg.get('enabled', False)}")
    print(f"  bypass.mode: {bypass_cfg.get('mode', 'none')}")
    print(f"  allowed risk levels: low, medium{' + high' if bypass_cfg.get('allow_for_high_risk') else ''}")
    print(f"  max consecutive bypassed gates: {bypass_cfg.get('max_consecutive_bypassed_gates', 1)}")

    gate = get_current_gate(state)
    print(f"  current gate: {gate or 'none'}")

    risk = get_risk_level(state, cfg)
    print(f"  current risk level: {risk}")

    allowed, reason = can_bypass(state, cfg)
    print(f"  bypass currently allowed: {'yes' if allowed else 'no'}")
    if not allowed and reason:
        print(f"  reason: {reason}")

    last_bypass = state.get("last_codex_bypass_review_file")
    if last_bypass:
        print(f"  last bypass review: {last_bypass}")

    pending = state.get("pending_codex_recheck", [])
    print(f"  pending Codex rechecks: {len(pending)}")
    if pending:
        for p in pending:
            print(f"    - {p}")

    lower = state.get("lower_assurance_mode", False)
    print(f"  lower_assurance_mode: {lower}")


def cmd_once(cfg: dict, state: dict, args: list[str]):
    bypass_cfg = get_bypass_cfg(cfg)
    gate = get_current_gate(state)

    if not gate:
        print("No active gate requires Codex review. Nothing to bypass.")
        return

    allowed, reason = can_bypass(state, cfg)
    if not allowed:
        print(f"Bypass not allowed: {reason}")
        print("This gate must wait for Codex to become available.")
        return

    reason_str = args[0] if args else "codex_cli_unavailable"
    allowed_reasons = bypass_cfg.get("allowed_reasons", [])
    if allowed_reasons and reason_str not in allowed_reasons:
        print(f"Reason '{reason_str}' not in allowed bypass reasons: {allowed_reasons}")
        print("Use one of the allowed reasons or choose 'user_explicit_override'.")
        return

    require_confirm = bypass_cfg.get("require_human_confirmation", True)
    if require_confirm:
        print(f"BYPYASS_GATE={gate}")
        print(f"BYPASS_REASON={reason_str}")
        print(f"BYPASS_RISK={get_risk_level(state, cfg)}")
        print("CONFIRMATION_REQUIRED=true")
        print("")
        print("Claude Code must ask the user to confirm this bypass.")
        print("Options:")
        print("  A. Confirm bypass with Claude adversarial review")
        print("  B. Wait for Codex, do not bypass")
        print("  C. Free input")
        print("")
        print("After confirmation, Claude Code must perform adversarial review following:")
        print("  .claude/skills/cc-codex-collaborate/prompts/claude-adversarial-bypass-review.md")
        print("")
        print("Then generate bypass review artifact in docs/cccc/reviews/bypass/")
        print("Then run: python3 scripts/cccc-bypass-codex.py apply --gate=<gate> --reason=<reason>")
        return

    print(f"BYPASS_GATE={gate}")
    print(f"BYPASS_REASON={reason_str}")
    print(f"BYPASS_RISK={get_risk_level(state, cfg)}")
    print("CONFIRMATION_REQUIRED=false")
    print("auto_bypass=true")
    print("")
    print("Claude Code must perform adversarial review following:")
    print("  .claude/skills/cc-codex-collaborate/prompts/claude-adversarial-bypass-review.md")
    print("Then generate bypass review artifact in docs/cccc/reviews/bypass/")
    print("Then run: python3 scripts/cccc-bypass-codex.py apply --gate=<gate> --reason=<reason>")


def cmd_apply(cfg: dict, state: dict, args: list[str]):
    gate = None
    reason = "codex_cli_unavailable"
    i = 0
    while i < len(args):
        if args[i].startswith("--gate="):
            gate = args[i].split("=", 1)[1]
        elif args[i].startswith("--reason="):
            reason = args[i].split("=", 1)[1]
        i += 1

    if not gate:
        print("ERROR: --gate=<gate> is required for apply.", file=sys.stderr)
        return 1

    ts = now_utc().replace(":", "").replace("-", "")
    mid = state.get("current_milestone_id", "unknown")
    filename = f"{gate}-claude-bypass-review-{ts}.json"
    if gate == "milestone_review" and mid:
        filename = f"milestone-{mid}-claude-bypass-review-{ts}.json"

    BYPASS_DIR.mkdir(parents=True, exist_ok=True)
    review_path = BYPASS_DIR / filename

    artifact = {
        "reviewer": "claude",
        "review_type": "claude_adversarial_bypass",
        "bypasses_codex": True,
        "bypass_reason": reason,
        "assurance_level": "lower_than_codex_review",
        "gate": gate,
        "milestone_id": mid if gate == "milestone_review" else None,
        "risk_level": get_risk_level(state, cfg),
        "status": "pass",
        "findings": [],
        "test_assessment": {},
        "required_follow_up": [
            "Run Codex recheck when Codex quota is available.",
            f"Run: /cccc codex-recheck"
        ],
        "created_at": now_utc(),
    }

    write_json(review_path, artifact)

    # Update state
    state["lower_assurance_mode"] = True
    state["last_codex_bypass_at"] = now_utc()
    state["last_codex_bypass_reason"] = reason
    state["last_codex_bypass_scope"] = gate
    state["last_codex_bypass_review_file"] = str(review_path)
    state["consecutive_bypassed_gates"] = state.get("consecutive_bypassed_gates", 0) + 1
    state["codex_bypass_enabled_for_current_gate"] = False

    bypass_cfg = get_bypass_cfg(cfg)
    if bypass_cfg.get("require_later_codex_recheck", True):
        state.setdefault("pending_codex_recheck", []).append({
            "gate": gate,
            "milestone_id": mid if gate == "milestone_review" else None,
            "bypass_review_file": str(review_path),
            "bypassed_at": now_utc(),
            "reason": reason,
        })

    # Update gate status
    if gate == "plan_review":
        state["codex_plan_review_status"] = "bypassed"
        state["roadmap_status"] = "bypassed_by_claude_review"
    elif gate == "milestone_review":
        state["current_milestone_codex_review_status"] = "bypassed"
    elif gate == "final_review":
        state["codex_final_review_status"] = "bypassed"

    # Clear pause
    if state.get("status") == "PAUSED_FOR_CODEX":
        state["status"] = "READY_TO_CONTINUE"
        state["pause_reason"] = f"Codex bypassed for {gate}. Lower assurance mode."
    state["resume_reason"] = f"Codex bypassed for {gate} via Claude adversarial review."

    save_state(state)

    # Write decision-log
    log_path = WORKSPACE / "decision-log.md"
    entry = f"\n## Codex bypass at {now_utc()}\n- Gate: {gate}\n- Reason: {reason}\n- Reviewer: Claude adversarial bypass\n- Assurance: lower_than_codex_review\n- Review file: {review_path}\n- Status: bypassed\n"
    if log_path.exists():
        log_path.write_text(log_path.read_text(encoding="utf-8") + entry)
    else:
        log_path.write_text(f"# Decision Log{entry}")

    print(f"Bypass applied for gate: {gate}")
    print(f"Review artifact: {review_path}")
    print(f"Assurance level: lower_than_codex_review")
    print(f"State: READY_TO_CONTINUE (lower assurance)")
    print(f"Pending Codex recheck: added")
    print("")
    print("Do NOT mark this as Codex pass. This is a lower-assurance bypass.")
    print("Run /cccc codex-recheck when Codex is available.")
    return 0


def cmd_off(cfg: dict, state: dict):
    config_path = WORKSPACE / "config.json"

    config = read_json(config_path) or {}
    config.setdefault("codex", {})
    config["codex"]["bypass"] = config["codex"].get("bypass", {})
    config["codex"]["bypass"]["enabled"] = False
    config["codex"]["unavailable_policy"] = "strict_pause"

    write_json(config_path, config)

    print("Codex bypass disabled.")
    print("unavailable_policy set to strict_pause.")
    print("Historical bypass reviews preserved in docs/cccc/reviews/bypass/.")


def main():
    if not WORKSPACE.exists():
        print("ERROR: docs/cccc does not exist. Run /cccc setup first.", file=sys.stderr)
        return 1

    cfg = load_config()
    state = load_state()

    args = sys.argv[1:]
    subcmd = args[0] if args else "status"

    if subcmd == "status":
        cmd_status(cfg, state)
    elif subcmd == "once":
        cmd_once(cfg, state, args[1:])
    elif subcmd == "apply":
        return cmd_apply(cfg, state, args[1:])
    elif subcmd == "off":
        cmd_off(cfg, state)
    elif subcmd == "--help" or subcmd == "-h":
        print("Usage: cccc-bypass-codex.py [status|once|apply|off]")
        print("  status   Show bypass status and config")
        print("  once     Request one-time bypass for current gate")
        print("  apply    Apply bypass after Claude adversarial review")
        print("  off      Disable bypass, set strict_pause")
    else:
        print(f"Unknown subcommand: {subcmd}")
        print("Use: status, once, apply, off")
        return 1

    return 0


if __name__ == "__main__":
    sys.exit(main())
