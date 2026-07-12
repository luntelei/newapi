# Contributing

Thank you for helping improve this unofficial New API installer and manager.

## Scope

Good contributions usually fit one of these areas:

- Linux installation compatibility.
- systemd service management.
- New API binary update flow.
- Checksum verification.
- Backup and restore safety.
- BBR status and opt-in management.
- README, FAQ, legal, and security documentation.
- GitHub issue templates and CI checks.

Out of scope:

- Modifying New API source code.
- Replacing New API's built-in root account setup flow.
- Adding public operation, resale, proxy, VPN, bypass, or abuse-oriented features.
- Storing or displaying administrator passwords.
- Direct database edits for administrator account changes.

## Development Guidelines

- Keep scripts POSIX-friendly where reasonable, but Bash is allowed.
- Preserve `set -Eeuo pipefail`.
- Prefer explicit checks and readable error messages.
- Do not print secrets.
- Do not enable BBR or other system tuning automatically.
- Keep default deployment lightweight: binary + systemd + SQLite.
- Use LF line endings for shell scripts and service files.

## Testing

Before opening a pull request, run:

```bash
bash -n install.sh
bash -n new-api.sh
shellcheck install.sh new-api.sh
```

For install or update behavior, test on a disposable Linux VPS whenever possible.

## Pull Requests

Please include:

- What changed.
- Why it changed.
- Commands used for testing.
- Linux distribution and CPU architecture if the change affects installation.
- Any compatibility or security notes.

By submitting a contribution, you agree that your contribution is licensed under Apache License 2.0 for this repository. This does not change the upstream New API license.
