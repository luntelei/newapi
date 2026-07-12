# newapi

[![License](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](LICENSE)
[![ShellCheck](https://github.com/luntelei/newapi/actions/workflows/shellcheck.yml/badge.svg)](https://github.com/luntelei/newapi/actions/workflows/shellcheck.yml)
[![Platform](https://img.shields.io/badge/platform-Linux%20%2B%20systemd-informational.svg)](#requirements)
[![Upstream](https://img.shields.io/badge/upstream-QuantumNous%2Fnew--api-orange.svg)](https://github.com/QuantumNous/new-api)

Unofficial Linux installer and systemd manager for [QuantumNous/new-api](https://github.com/QuantumNous/new-api).

这是一个非官方 New API Linux 一键安装与 systemd 管理脚本，面向个人学习、技术研究和自有 VPS 上的小规模自托管部署。它不提供托管服务，也不包含 New API 源码；安装时会从上游 GitHub Release 下载官方 Linux 二进制并校验 checksum。

## Important Notice

This repository is not affiliated with, endorsed by, or maintained by the `QuantumNous/new-api` project.

- This project does not provide a hosted service, public operation service, resale service, proxy service, VPN service, or telecom service.
- This project does not modify, mirror, relicense, or redistribute the New API source code.
- The installer downloads New API release binaries from upstream `QuantumNous/new-api` GitHub releases and verifies `checksums-linux.txt`.
- New API is licensed separately by the upstream project under GNU AGPLv3, with additional attribution requirements described by upstream.
- You are responsible for your own deployment, network exposure, account security, API keys, logs, data, and legal compliance.

Read [DISCLAIMER.md](DISCLAIMER.md), [LEGAL.md](LEGAL.md), and the upstream [New API license](https://github.com/QuantumNous/new-api/blob/main/LICENSE) before use.

## Features

- One-command install or update on Linux VPS systems using systemd.
- Supports upstream New API Linux release binaries for `amd64` and `arm64`.
- Verifies upstream release checksums before installing the binary.
- Creates and manages a `new-api` systemd service.
- Installs a `new-api` management command at `/usr/bin/new-api`.
- Provides service start, stop, restart, status, autostart enable, and autostart disable commands.
- Shows service summary, access URLs, key config values, local/latest versions, and install health checks.
- Supports port changes through `.env` and restarts the service automatically.
- Supports backup and restore for `.env`, `data`, and `logs`.
- Supports management-script updates without reinstalling the service.
- Includes optional BBR status, enable, and disable commands. BBR is never enabled automatically.
- Keeps New API's built-in first-run Web initialization flow. This project does not generate an admin password.
- Uses SQLite by default. Docker, Nginx, ACME, Redis, MySQL, and PostgreSQL are not installed by this script.

## Tested Systems

The current installer and management script were validated on clean x86_64 VPS instances:

| System | Result |
| --- | --- |
| Ubuntu 26.04 LTS | Passed |
| Debian 13 | Passed |
| Rocky Linux 10.2 | Passed |
| Fedora 44 | Passed |
| openSUSE Leap 16.0 | Passed |
| Arch Linux | Passed |

The matrix covered clean install, service startup, HTTP readiness, CLI commands, config display, invalid port rejection, port changes, backup, restore cancel/confirm paths, update-script, update through installed installer, service lifecycle, autostart toggle, uninstall cancel/delete paths, and BBR status/cancel paths.

Real BBR enable/disable was not run in the matrix because it changes kernel network parameters.

## Requirements

- Linux VPS with systemd.
- Root privileges.
- `amd64` or `arm64` CPU architecture.
- Network access to GitHub releases and raw GitHub content.
- Base tools: `curl`, `wget`, `tar`, and `ca-certificates`.

The installer attempts to install the base tools using the system package manager:

| Family | Package manager branch |
| --- | --- |
| Ubuntu, Debian, other fallback systems | `apt-get` |
| Rocky Linux, AlmaLinux, CentOS, Oracle Linux | `yum` |
| Fedora | `dnf` |
| openSUSE Leap/Tumbleweed | `zypper` |
| Arch, Manjaro, Parch | `pacman` |

Alpine Linux, Fedora CoreOS, Flatcar Container Linux, FreeBSD, and OpenBSD are not supported targets for this script because this project expects Linux plus systemd.

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

To install a specific upstream New API release tag:

```bash
bash <(curl -Ls https://raw.githubusercontent.com/luntelei/newapi/main/install.sh) v1.0.0-rc.21
```

## Common Workflow

Check the service after installation:

```bash
new-api check
new-api summary
new-api uri
```

Change the panel port:

```bash
new-api set-port 3001
new-api uri
```

Update New API to the latest upstream release:

```bash
new-api update
```

Update only this management script:

```bash
new-api update-script
```

Create a backup before risky operations:

```bash
new-api backup
```

Restore a backup:

```bash
new-api restore /usr/local/new-api/backups/new-api-YYYYmmdd-HHMMSS.tar.gz
```

Uninstall service files and optionally delete data:

```bash
new-api uninstall
```

## Management Commands

```text
new-api                       Show interactive menu
new-api install               Install New API
new-api update [tag]          Update to latest release or a specified release tag
new-api update-script         Update this management script
new-api start                 Start service
new-api stop                  Stop service
new-api restart               Restart service
new-api status                Show service status
new-api enable                Enable autostart on boot
new-api disable               Disable autostart on boot
new-api log                   Follow systemd logs
new-api summary               Show compact service summary
new-api config                Show key config values
new-api uri                   Show local/public access URLs
new-api set-port [port]       Set service port and restart
new-api backup                Backup .env, data and logs
new-api restore <file>        Restore a backup archive
new-api check                 Check installed files
new-api bbr status            Show BBR status
new-api bbr enable            Enable BBR
new-api bbr disable           Disable BBR
new-api uninstall             Uninstall service files, optionally delete data
new-api version               Show local and latest versions
new-api help                  Show this help
```

## Runtime Layout

| Item | Path |
| --- | --- |
| Install directory | `/usr/local/new-api` |
| Config file | `/usr/local/new-api/.env` |
| SQLite database | `/usr/local/new-api/data/one-api.db` |
| Logs | `/usr/local/new-api/logs` |
| Backups | `/usr/local/new-api/backups` |
| Temporary install downloads | `/usr/local/new-api/.install.*` |
| systemd service | `/etc/systemd/system/new-api.service` |
| CLI command | `/usr/bin/new-api` |
| Default port | `3000` |

## What The Installer Does

1. Checks root privileges, systemd, OS family, and CPU architecture.
2. Installs base dependencies through the system package manager.
3. Resolves the requested upstream New API version, or the latest upstream release when no tag is provided.
4. Downloads the upstream Linux binary and `checksums-linux.txt`.
5. Verifies the checksum entry for the selected binary.
6. Creates `/usr/local/new-api`, `.env`, `data`, `logs`, and `backups`.
7. Generates a random `SESSION_SECRET` when needed.
8. Installs the New API binary, management script, and systemd service.
9. Enables and starts the service.
10. Prints local, LAN, and public access URLs when available.

## Configuration

The installer creates `/usr/local/new-api/.env` and preserves existing values on update. Missing defaults are appended.

Default values:

```env
PORT=3000
SQLITE_PATH=/usr/local/new-api/data/one-api.db?_busy_timeout=30000
TZ=Asia/Shanghai
ERROR_LOG_ENABLED=true
```

`SESSION_SECRET` is generated randomly. If an old insecure `SESSION_SECRET=random_string` value is detected, it is replaced.

Use `new-api config` to view important values. Sensitive values are masked.

## Backup And Restore

`new-api backup` archives:

- `/usr/local/new-api/.env`
- `/usr/local/new-api/data`
- `/usr/local/new-api/logs`

Backups are stored under:

```text
/usr/local/new-api/backups
```

`new-api restore <file>` validates that the archive does not contain absolute or parent-directory traversal paths before extracting it. Restore stops the service, extracts the archive, repairs file permissions and SELinux context when available, then starts the service again.

## BBR Commands

```bash
new-api bbr status
new-api bbr enable
new-api bbr disable
```

`status` is read-only.

`enable` and `disable` modify `/etc/sysctl.conf` and run `sysctl -p`. Review your VPS provider policy, kernel support, and current network state before using them.

## Compatibility Notes

- The installer uses `/usr/local/new-api/.install.*` for temporary downloads instead of `/tmp`, because some VPS images mount `/tmp` as a small tmpfs.
- On Debian and Ubuntu, the installer waits for apt/dpkg locks when another process such as `unattended-upgrades` is running.
- On SELinux systems, the scripts repair permissions and context for `.env`, the binary, scripts, and the systemd unit where possible.
- The service uses `EnvironmentFile=/usr/local/new-api/.env` and starts New API with `--port ${PORT}`.
- Opening the public URL may still require firewall or cloud security group changes outside this script.

## Troubleshooting

Check installed files:

```bash
new-api check
```

Show compact status:

```bash
new-api summary
```

Show systemd status:

```bash
new-api status
```

Follow logs:

```bash
new-api log
```

Restart the service:

```bash
new-api restart
```

Common causes:

- GitHub release download fails: check outbound network access to GitHub.
- Web page is not reachable from the Internet: check firewall, VPS security group, and the configured `PORT`.
- `new-api update` waits on Debian/Ubuntu: another apt/dpkg process may be running; the installer waits and retries.
- Restore fails: verify the backup file path and archive integrity.

## Security Notes

- Do not publish `.env`, SQLite database files, logs, backups, API keys, tokens, or screenshots containing secrets.
- Configure firewall rules and expose only the ports you need.
- Use HTTPS through your own reverse proxy if the service is reachable from the Internet.
- Back up `/usr/local/new-api/.env` and `/usr/local/new-api/data/one-api.db` before updates or system migration.
- Treat restore operations as sensitive because backups may contain credentials, tokens, and user data.
- Keep the VPS operating system updated and review New API upstream release notes before updating.

For vulnerability reports and hardening guidance, see [SECURITY.md](SECURITY.md).

## Suitable Use

- Personal learning and technical research.
- Personal or small-scale self-hosted deployment on your own Linux VPS.
- Quickly evaluating New API through a lightweight binary and systemd setup.
- Managing a New API binary service with simple commands.

## Not Suitable For

- Public commercial operation, resale, managed hosting, or unauthorized operation on behalf of others.
- Any use that violates laws, regulations, cloud provider policies, model provider terms, or upstream project licenses.
- Abuse, unauthorized access, privacy infringement, credential misuse, spam, scraping, or evasion of platform restrictions.
- High-availability, multi-node, enterprise-audited production environments without your own review and hardening.

## License And Upstream Attribution

This repository's installer scripts, management scripts, service file, and documentation are licensed under the [Apache License 2.0](LICENSE).

New API itself is developed by the upstream [QuantumNous/new-api](https://github.com/QuantumNous/new-api) project and is licensed separately under [GNU AGPLv3](https://github.com/QuantumNous/new-api/blob/main/LICENSE). This repository's Apache-2.0 license does not cover the upstream New API source code, binaries, trademarks, UI, documentation, releases, or any other upstream materials.

If you modify, distribute, operate, or provide network access to New API or a modified New API version, you must independently comply with the upstream AGPLv3 license and any additional upstream attribution requirements.

## Contributing

Issues and pull requests are welcome when they stay within this project's scope: lightweight installation, systemd management, checks, documentation, and compatibility improvements for personal or small-scale self-hosted use.

Before contributing, read [CONTRIBUTING.md](CONTRIBUTING.md), [LEGAL.md](LEGAL.md), and [SECURITY.md](SECURITY.md).
