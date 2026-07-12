# Security Policy

## Supported Scope

Security reports are accepted for this repository's installer script, management script, systemd service file, and documentation.

Security issues in New API itself should be reported to the upstream [QuantumNous/new-api](https://github.com/QuantumNous/new-api) project.

## Reporting A Vulnerability

Please open a GitHub issue with sensitive values removed, or contact the maintainer through the repository owner's public GitHub contact channel if private handling is needed.

Do not publish:

- API keys or tokens.
- `.env` contents.
- SQLite database files.
- Backup archives.
- Full logs containing secrets.
- Public IPs, domains, or account identifiers that you do not want disclosed.

## Deployment Hardening

Before exposing New API to the Internet:

- Configure firewall rules and expose only required ports.
- Put the service behind HTTPS if remote access is needed.
- Protect administrator credentials and API keys.
- Back up `/usr/local/new-api/.env` and `/usr/local/new-api/data/one-api.db`.
- Review logs before sharing them.
- Confirm that BBR changes are acceptable for your VPS provider and system.
- Keep this script and the upstream New API binary updated.

## Secret Handling

The scripts may operate on files containing credentials and user data. Treat these paths as sensitive:

- `/usr/local/new-api/.env`
- `/usr/local/new-api/data/one-api.db`
- `/usr/local/new-api/logs`
- `/usr/local/new-api/backups`

Do not commit or upload these files.
