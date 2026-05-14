# Changelog

## 0.1.3 - 2026-05-14

### Added

- Interactive setup wizard with three configuration presets: recommended, strict, custom.
- `docs/cccc/config.json` for project-level configuration (mode, thresholds, language, safety, automation, codex behavior).
- Configuration presets: Quick (recommended), Strict (high-risk), Custom (step-by-step).
- Existing config detection: setup asks whether to keep, update, backup-and-rebuild, or exit.
- Config backup on rebuild: `docs/cccc/backups/config.<timestamp>.json`.
- `cccc_config_value()` helper in `cccc-common.sh` for reading config values.
- `docs/cccc/backups/` directory in workspace layout.

### Changed

- `docs/cccc/state.json` now only stores runtime state (milestone, status, review counts, pause reason). All thresholds moved to `config.json`.
- Setup is now an interactive wizard, not a silent bootstrap. It detects language, offers presets, and summarizes.
- Loop scripts (`loop-start`, `loop-stop`, `loop-status`) now read from `config.json` instead of `state.json`.
- `loop-stop` updates `config.json` (disables `automation.stop_hook_loop_enabled`, reverts mode to `supervised-auto`).
- `loop-start` updates `config.json` (enables loop, sets mode to `full-auto-safe`).
- Removed public `init` subcommand. Setup is the sole entry point; init is internal only.
- `cccc-init.sh` preserves existing `user_language` instead of overwriting on re-init.
- Version bumped to 0.1.3.

### Removed

- Public `/cc-codex-collaborate init` subcommand.
- Thresholds from `state.json` (now in `config.json`).

## 0.1.2 - 2026-05-14

### Changed

- Added first-run setup flow: `/cc-codex-collaborate setup`.
- The release zip no longer pre-populates root `.claude/commands/`.
- Setup now generates `.claude/commands/` from `.claude/skills/cc-codex-collaborate/templates/commands/`.
- Setup also generates or verifies the runtime workspace under `docs/cccc/`.
- Setup reports generated files, preserved files, hook state, and simple usage.
- Hooks remain opt-in and are enabled only by `/cc-codex-collaborate-loop-start` or `/cc-codex-collaborate loop-start`.

## 0.1.1 - 2026-05-14

### Changed

- Replaced old short loop command aliases with explicit commands:
  - `/cc-codex-collaborate-loop-status`
  - `/cc-codex-collaborate-loop-start`
  - `/cc-codex-collaborate-loop-stop`
- Moved hook scripts into the skill package under `.claude/skills/cc-codex-collaborate/hooks/`.
- Added loop start/stop/status scripts that install, configure, inspect, and remove CCCC hook registrations.
- Changed `docs/cccc` to a runtime-generated workspace. The zip ships templates under `.claude/skills/cc-codex-collaborate/templates/cccc/` instead of pre-populating a project workspace.

## 0.1.0 - 2026-05-14

### Added

- Initial Claude Code + Codex collaboration skill.
- Project discovery, planning, Claude self-review, Codex adversarial plan review, milestone loop, safety gates, language detection, and brainstorming-style human questions.
