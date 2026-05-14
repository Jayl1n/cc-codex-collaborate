# Security Policy

`cc-codex-collaborate` is designed to pause before sensitive work.

Do not paste real secrets into Claude Code, Codex, prompts, reviews, logs, or `docs/cccc` files.

Examples of secrets and sensitive data:

- wallet private keys
- seed phrases or mnemonics
- keystores
- production API keys
- database passwords
- OAuth client secrets
- SSH private keys
- cookies, sessions, tokens
- real user data

Use local sandbox environment variables or fake test fixtures instead.

The included hooks are guardrails, not a substitute for human review. Review commands and settings before enabling `full-auto-safe` mode.
