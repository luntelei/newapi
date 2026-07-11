# newapi

New API binary + systemd one-click installer and management scripts.

## One-Click Install

Run as `root` on a Linux VPS with systemd:

```bash
bash <(curl -Ls https://raw.githubusercontent.com/luntelei/newapi/main/install.sh)
```

The installer downloads the latest `QuantumNous/new-api` Linux release binary, verifies `checksums-linux.txt`, installs to `/usr/local/new-api`, creates `/usr/bin/new-api`, and starts `new-api.service`.

Default runtime layout:

- Install dir: `/usr/local/new-api`
- Config file: `/usr/local/new-api/.env`
- SQLite data: `/usr/local/new-api/data/one-api.db`
- Logs: `/usr/local/new-api/logs`
- Default port: `3000`

## Management

```bash
new-api help
new-api status
new-api log
new-api restart
new-api update
new-api set-port 3001
new-api backup
new-api restore /usr/local/new-api/backups/new-api-YYYYmmdd-HHMMSS.tar.gz
new-api uninstall
```

The default deployment uses local SQLite and does not install Docker, Nginx, ACME, Redis, MySQL, or PostgreSQL.
