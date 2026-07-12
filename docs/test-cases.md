# Test Cases

This document defines the test coverage for the installer, management script, systemd service, default SQLite deployment, backup/restore flow, optional BBR management, repository documentation, and GitHub CI.

The test target is this repository's installer and management layer. It does not modify the upstream `QuantumNous/new-api` source code.

## 1. Static Checks And CI

| ID | Scenario | Steps | Expected Result |
| --- | --- | --- | --- |
| ST-001 | Bash syntax check | Run `bash -n install.sh && bash -n new-api.sh`. | Exit code is `0`. |
| ST-002 | ShellCheck | Run `shellcheck install.sh new-api.sh`. | No warnings or errors. |
| ST-003 | GitHub Actions | Push to `main` or open a pull request. | The `ShellCheck` workflow succeeds. |
| ST-004 | Line ending rules | Review `.gitattributes`, then checkout the repository on a fresh clone. | `.sh`, `.service`, `.md`, `.yml`, `.yaml`, `LICENSE`, `.github/**`, and `docs/**` use LF line endings. |
| ST-005 | Documentation links | Check every local README link to `LICENSE`, `DISCLAIMER.md`, `LEGAL.md`, `SECURITY.md`, and `CONTRIBUTING.md`. | All linked files exist. |

## 2. One-Command Installation

| ID | Scenario | Steps | Expected Result |
| --- | --- | --- | --- |
| IN-001 | Clean VPS install | As `root`, run `bash <(curl -Ls https://raw.githubusercontent.com/luntelei/newapi/main/install.sh)`. | Installation completes without `unbound variable` or similar shell errors. |
| IN-002 | Root privilege check | Run the installer as a non-root user. | The installer exits with a clear root privilege error. |
| IN-003 | systemd requirement | Run in an environment without `systemctl`. | The installer exits with a clear systemd requirement error. |
| IN-004 | Supported architectures | Run on amd64 and arm64 Linux hosts. | The installer selects the matching upstream release asset. |
| IN-005 | Unsupported architecture | Run on, or simulate, a non-amd64/non-arm64 architecture. | The installer exits with a clear unsupported architecture error. |
| IN-006 | Base dependency install | Test on Debian/Ubuntu, CentOS/Rocky, Fedora, Arch, and openSUSE families. | The installer uses the matching package manager and installs `curl`, `wget`, `tar`, and `ca-certificates`. |
| IN-007 | Checksum success | Install with normal upstream binary and `checksums-linux.txt`. | `sha256sum -c` succeeds. |
| IN-008 | Checksum missing or mismatch | Simulate a missing checksum line or bad hash. | Installation fails and the bad binary is not installed. |
| IN-009 | Runtime layout | After installation, inspect `/usr/local/new-api`. | `.env`, `data`, `logs`, and `backups` match the README layout. |
| IN-010 | systemd service file | Inspect `/etc/systemd/system/new-api.service`. | `WorkingDirectory`, `EnvironmentFile`, and `ExecStart` point to `/usr/local/new-api`. |
| IN-011 | CLI command | Run `command -v new-api` after installation. | `/usr/bin/new-api` exists and is executable. |
| IN-012 | Built-in root setup | Open `http://SERVER_IP:3000` after a fresh install. | New API's built-in Web initialization flow is shown; this project does not generate or display a root password. |
| IN-013 | Default component boundary | Compare installed packages and services before/after installation. | Docker, Nginx, ACME, Redis, MySQL, and PostgreSQL are not installed automatically. |
| IN-014 | BBR default boundary | Compare BBR-related sysctl settings before/after installation. | Installation does not enable or disable BBR automatically. |

## 3. Update And Rollback

| ID | Scenario | Steps | Expected Result |
| --- | --- | --- | --- |
| UP-001 | Update to latest | Run `new-api update` after installation. | The latest upstream release is downloaded and the service returns to `running`. |
| UP-002 | Update to specified tag | Run `new-api update <tag>`. | The specified upstream tag asset is downloaded and installed. |
| UP-003 | Previous binary backup | Update when a binary already exists. | A `new-api.backup.*` binary is created before replacement. |
| UP-004 | systemd reload order | Observe logs during update. | systemd is reloaded before service start, and no stale unit behavior appears. |
| UP-005 | Download failure rollback | Simulate a failed release download. | The previous binary remains installed and the service is not broken. |
| UP-006 | Start failure rollback | Simulate a replacement binary that cannot start. | The previous binary is restored and the old service is restarted. |
| UP-007 | Script self-update | Run `new-api update-script`. | `/usr/bin/new-api` and `/usr/local/new-api/new-api.sh` are updated successfully. |

## 4. Service And Management Commands

| ID | Scenario | Steps | Expected Result |
| --- | --- | --- | --- |
| MG-001 | Install check | Run `new-api check`. | Install dir, data dir, log dir, env file, binary, service, and command are all `ok`. |
| MG-002 | Summary | Run `new-api summary`. | Output includes service state, autostart state, port, version, install path, and config path. |
| MG-003 | Access URLs | Run `new-api uri`. | Local, LAN, and public URLs are shown when available. |
| MG-004 | Secret masking | Run `new-api config`. | `SESSION_SECRET` is masked and not printed in full. |
| MG-005 | Service lifecycle | Run `new-api status`, `start`, `stop`, and `restart`. | systemd state matches each command. |
| MG-006 | Autostart lifecycle | Run `new-api enable` and `new-api disable`, then `systemctl is-enabled new-api`. | Autostart state changes correctly. |
| MG-007 | Valid port change | Run `new-api set-port 3001`. | `.env` is updated, the service restarts, and port `3001` responds. |
| MG-008 | Invalid port change | Run `new-api set-port` with empty, non-numeric, `0`, and `65536` values. | The command rejects the input and does not change `.env`. |
| MG-009 | Commands before install | Run management commands after removing the installed binary. | Commands fail clearly without unsafe side effects. |

## 5. Backup And Restore

| ID | Scenario | Steps | Expected Result |
| --- | --- | --- | --- |
| BK-001 | Create backup | Run `new-api backup`. | A `backups/new-api-*.tar.gz` file is created. |
| BK-002 | Backup permissions | Run `stat` on the generated backup. | Backup file mode is `600`. |
| BK-003 | Backup contents | Run `tar -tzf <backup>`. | The archive contains `.env`, `data`, and `logs`. |
| BK-004 | Restore valid backup | Change a config value, then run `new-api restore <backup>` and confirm. | The service stops, data is restored, systemd reloads, and the service returns to `running`. |
| BK-005 | Restore missing backup | Run `new-api restore missing.tar.gz`. | The command fails clearly and does not damage existing data. |
| BK-006 | Restore cancellation | Run restore and answer `n`. | Existing data is not modified. |

## 6. Optional BBR Management

| ID | Scenario | Steps | Expected Result |
| --- | --- | --- | --- |
| BB-001 | BBR status | Run `new-api bbr status`. | Current congestion control, qdisc, and available algorithms are shown. |
| BB-002 | Enable cancellation | Run `new-api bbr enable` and answer `n`. | `/etc/sysctl.conf` is not changed. |
| BB-003 | Enable success | On a disposable BBR-capable VPS, run `new-api bbr enable` and answer `y`. | sysctl is backed up, `fq` and `bbr` are written, and `sysctl -p` succeeds. |
| BB-004 | Disable cancellation | Run `new-api bbr disable` and answer `n`. | `/etc/sysctl.conf` is not changed. |
| BB-005 | Disable success | Run `new-api bbr disable` and answer `y`. | sysctl is backed up and restored to `pfifo_fast` and `cubic`. |
| BB-006 | Unsupported kernel | Run enable on a kernel that does not list BBR. | A clear warning is shown; failure is not silent. |

## 7. Security And Compliance Boundary

| ID | Scenario | Steps | Expected Result |
| --- | --- | --- | --- |
| SC-001 | No administrator password display | Search the repository for password/root reset output paths. | The project does not provide a way to view administrator passwords. |
| SC-002 | No direct root database reset | Search for SQLite update/admin reset logic. | The project does not directly modify the database to reset administrator accounts. |
| SC-003 | No secret leakage | Run `new-api config`, `summary`, and `check`. | Full `SESSION_SECRET` values are not printed. |
| SC-004 | Documentation boundary | Review README, `LEGAL.md`, and `DISCLAIMER.md`. | The repository is clearly unofficial, non-hosted, personal/small-scale, and separate from upstream AGPLv3 New API. |
| SC-005 | Runtime secrets not tracked | Run `git ls-files` and search for `.env`, `.db`, `.tar.gz`, and runtime log paths. | Runtime secrets, databases, backups, and logs are not tracked. |

## 8. VPS End-To-End Acceptance

| ID | Scenario | Steps | Expected Result |
| --- | --- | --- | --- |
| E2E-001 | Clean VPS first install | Remove `/usr/local/new-api`, `/usr/bin/new-api`, and `/etc/systemd/system/new-api.service`, then run the one-command installer. | Installation succeeds and the service is `running`. |
| E2E-002 | Local HTTP response | Run `curl -fsS -I http://127.0.0.1:3000`. | Response includes `HTTP/1.1 200 OK`. |
| E2E-003 | Core command smoke test | Run `new-api check`, `summary`, `uri`, `bbr status`, and `backup`. | All commands complete without unexpected errors. |
| E2E-004 | Release consistency | Confirm the release tag SHA for `v0.1.0`. | The tag points to the tested commit. |
| E2E-005 | Repeat install | Run the one-command installer again on an already installed host. | The install/update path completes and preserves `.env` and `data`. |

## Acceptance Criteria

- P0 must pass: `ST-001` through `ST-003`, `IN-001`, `IN-009` through `IN-012`, `IN-014`, `MG-001` through `MG-003`, `BK-001`, `SC-001` through `SC-005`, and `E2E-001` through `E2E-003`.
- Before a public release, also pass `UP-001`, `UP-005`, `UP-006`, `BB-001`, and `BB-002`.
- Before claiming broad distribution support, run `IN-006` on at least Debian, Ubuntu, and Rocky Linux.
- After any script change, rerun Bash syntax checks, ShellCheck, and a clean disposable VPS one-command smoke test.

## Assumptions

- Tests do not modify upstream `QuantumNous/new-api` source code.
- Root account initialization is verified only by checking the upstream New API Web setup page; tests do not create, read, or reset administrator passwords.
- BBR enable/disable tests modify system network parameters and must run only on disposable VPS instances.
- Restore, uninstall, and port-change tests can be destructive and must run only on disposable test hosts.
