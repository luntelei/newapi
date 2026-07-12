# newapi

[![License](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](LICENSE)
[![ShellCheck](https://github.com/luntelei/newapi/actions/workflows/shellcheck.yml/badge.svg)](https://github.com/luntelei/newapi/actions/workflows/shellcheck.yml)
[![Platform](https://img.shields.io/badge/platform-Linux%20%2B%20systemd-informational.svg)](#requirements)
[![Upstream](https://img.shields.io/badge/upstream-QuantumNous%2Fnew--api-orange.svg)](https://github.com/QuantumNous/new-api)

Unofficial Linux installer and systemd manager for [QuantumNous/new-api](https://github.com/QuantumNous/new-api).

New API 非官方 Linux 一键安装与 systemd 管理脚本，适合个人学习、技术研究和个人/小规模自用部署。

## Important Notice

This repository is not affiliated with, endorsed by, or maintained by the `QuantumNous/new-api` project.

- This project does not provide a hosted service, public operation service, resale service, proxy service, VPN service, or telecom service.
- This project does not modify, mirror, relicense, or redistribute the New API source code.
- The installer downloads New API release binaries from the upstream `QuantumNous/new-api` GitHub releases and verifies the upstream Linux checksum file when available.
- New API is licensed separately by its upstream project under GNU AGPLv3, with additional attribution requirements described by upstream.
- You are responsible for your own deployment, network exposure, account security, API keys, logs, data, and legal compliance.

Read [DISCLAIMER.md](DISCLAIMER.md), [LEGAL.md](LEGAL.md), and the upstream [New API license](https://github.com/QuantumNous/new-api/blob/main/LICENSE) before use.

## Suitable Use

- Personal learning and technical research.
- Personal or small-scale self-hosted deployment on your own Linux VPS.
- Quickly evaluating New API through a lightweight binary + systemd setup.
- Managing a New API binary service with simple commands.

## Not Suitable For

- Public commercial operation, resale, managed hosting, or unauthorized operation on behalf of others.
- Any use that violates laws, regulations, cloud provider policies, model provider terms, or upstream project licenses.
- Abuse, unauthorized access, privacy infringement, credential misuse, spam, scraping, or evasion of platform restrictions.
- High-availability, multi-node, enterprise-audited production environments without your own review and hardening.

## Features

- One-command installation for Linux VPS environments with systemd.
- Automatic upstream release download for amd64 and arm64 Linux binaries.
- Upstream `checksums-linux.txt` verification during install/update.
- systemd service creation and lifecycle management.
- Port configuration, status summary, logs, health checks, update, backup, and restore.
- Optional BBR management commands; BBR is never enabled automatically.
- Fresh installs keep the original New API Web setup flow for the root account.
- Default SQLite deployment without Docker, Nginx, ACME, Redis, MySQL, or PostgreSQL.

## Requirements

- Linux VPS with systemd.
- Root privileges.
- `curl`, `wget`, `tar`, and `ca-certificates`; the installer attempts to install these base packages.
- amd64 or arm64 CPU architecture.

## Quick Start

Run as `root`:

```bash
bash <(curl -Ls https://raw.githubusercontent.com/luntelei/newapi/main/install.sh)
```

After installation, open:

```text
http://SERVER_IP:3000
```

On a fresh install, create the root account through New API's built-in Web initialization page. This project does not generate, display, reset, or directly modify the New API administrator password.

## Runtime Layout

| Item | Path |
| --- | --- |
| Install directory | `/usr/local/new-api` |
| Config file | `/usr/local/new-api/.env` |
| SQLite database | `/usr/local/new-api/data/one-api.db` |
| Logs | `/usr/local/new-api/logs` |
| Backups | `/usr/local/new-api/backups` |
| systemd service | `/etc/systemd/system/new-api.service` |
| CLI command | `/usr/bin/new-api` |
| Default port | `3000` |

## Management Commands

```bash
new-api help
new-api summary
new-api uri
new-api status
new-api log
new-api restart
new-api update
new-api update-script
new-api set-port 3001
new-api check
new-api backup
new-api restore /usr/local/new-api/backups/new-api-YYYYmmdd-HHMMSS.tar.gz
new-api bbr status
new-api bbr enable
new-api bbr disable
new-api uninstall
```

`new-api bbr enable` and `new-api bbr disable` change system network parameters. Review your VPS provider policy and system state before using them.

## Security Notes

- Do not publish `.env`, SQLite database files, logs, backups, API keys, tokens, or screenshots containing secrets.
- Configure firewall rules and expose only the ports you need.
- Use HTTPS through your own reverse proxy if the service is reachable from the Internet.
- Back up `/usr/local/new-api/.env` and `/usr/local/new-api/data/one-api.db` before updates or system migration.
- Treat restore operations as sensitive because backups may contain credentials, tokens, and user data.

For vulnerability reports and hardening guidance, see [SECURITY.md](SECURITY.md).

## License And Upstream Attribution

This repository's installer scripts, management scripts, service file, and documentation are licensed under the [Apache License 2.0](LICENSE).

New API itself is developed by the upstream [QuantumNous/new-api](https://github.com/QuantumNous/new-api) project and is licensed separately under [GNU AGPLv3](https://github.com/QuantumNous/new-api/blob/main/LICENSE). This repository's Apache-2.0 license does not cover the upstream New API source code, binaries, trademarks, UI, documentation, releases, or any other upstream materials.

If you modify, distribute, operate, or provide network access to New API or a modified New API version, you must independently comply with the upstream AGPLv3 license and any additional upstream attribution requirements.

## Contributing

Issues and pull requests are welcome when they stay within this project's scope: lightweight installation, systemd management, checks, documentation, and compatibility improvements for personal or small-scale self-hosted use.

Before contributing, read [CONTRIBUTING.md](CONTRIBUTING.md), [LEGAL.md](LEGAL.md), and [SECURITY.md](SECURITY.md).
