# FAQ

## Is this the official New API project?

No. This is an unofficial installer and systemd manager for [QuantumNous/new-api](https://github.com/QuantumNous/new-api).

## Does this repository modify New API?

No. The scripts download New API release binaries from the upstream GitHub releases and install them as a systemd service.

## Which license applies?

This repository's own scripts and documents use Apache License 2.0.

New API itself is licensed separately by the upstream project under GNU AGPLv3. You must comply with upstream licensing when using, modifying, distributing, or operating New API.

## Why is there no default root password?

Fresh installs use New API's built-in Web initialization flow. This project does not generate, display, reset, or directly modify administrator passwords.

## Does this install Docker, Nginx, HTTPS, Redis, MySQL, or PostgreSQL?

No. The default setup is intentionally lightweight: New API binary + systemd + SQLite.

## Does the installer enable BBR automatically?

No. BBR commands are available only as explicit opt-in management commands:

```bash
new-api bbr status
new-api bbr enable
new-api bbr disable
```

## What should I back up?

Back up at least:

- `/usr/local/new-api/.env`
- `/usr/local/new-api/data/one-api.db`
- `/usr/local/new-api/backups`

## Can I use this for public operation or resale?

This repository is not intended for public operation, resale, managed hosting, proxy/VPN services, bypass/evasion services, or any activity that violates laws, policies, provider terms, or upstream licenses.
