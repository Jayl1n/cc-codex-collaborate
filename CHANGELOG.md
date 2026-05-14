# Changelog

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
