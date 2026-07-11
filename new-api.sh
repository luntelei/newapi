#!/usr/bin/env bash

set -Eeuo pipefail

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

APP_NAME="new-api"
SERVICE_NAME="new-api"
GITHUB_REPO="QuantumNous/new-api"
INSTALL_DIR="/usr/local/new-api"
DATA_DIR="${INSTALL_DIR}/data"
LOG_DIR="${INSTALL_DIR}/logs"
BACKUP_DIR="${INSTALL_DIR}/backups"
ENV_FILE="${INSTALL_DIR}/.env"
BIN_PATH="${INSTALL_DIR}/new-api"
SERVICE_PATH="/etc/systemd/system/new-api.service"
CLI_PATH="/usr/bin/new-api"
INSTALL_URL="${NEW_API_INSTALL_URL:-https://raw.githubusercontent.com/luntelei/newapi/main/install.sh}"

log_info() { echo -e "${green}[INFO]${plain} $*"; }
log_warn() { echo -e "${yellow}[WARN]${plain} $*"; }
log_error() { echo -e "${red}[ERROR]${plain} $*" >&2; }

need_root() {
    if [[ "${EUID}" -ne 0 ]]; then
        log_error "Please run this command with root privilege."
        exit 1
    fi
}

confirm() {
    local prompt="$1"
    local default="${2:-n}"
    local answer
    read -r -p "${prompt} [y/n] (default: ${default}): " answer
    answer="${answer:-${default}}"
    [[ "${answer}" == "y" || "${answer}" == "Y" ]]
}

check_install() {
    if [[ ! -x "${BIN_PATH}" ]]; then
        log_error "New API is not installed. Run: new-api install"
        exit 1
    fi
}

run_installer() {
    need_root
    local version="${1:-}"
    if [[ -x "${INSTALL_DIR}/install.sh" ]]; then
        bash "${INSTALL_DIR}/install.sh" "${version}"
    elif [[ -f "./install.sh" ]]; then
        bash "./install.sh" "${version}"
    else
        log_warn "Local install.sh not found; downloading installer from ${INSTALL_URL}."
        bash <(curl -fsSL "${INSTALL_URL}") "${version}"
    fi
}

start_service() {
    need_root
    check_install
    systemctl start "${SERVICE_NAME}"
    systemctl status "${SERVICE_NAME}" --no-pager -l
}

stop_service() {
    need_root
    check_install
    systemctl stop "${SERVICE_NAME}"
    log_info "${SERVICE_NAME} stopped."
}

restart_service() {
    need_root
    check_install
    systemctl restart "${SERVICE_NAME}"
    systemctl status "${SERVICE_NAME}" --no-pager -l
}

status_service() {
    check_install
    systemctl status "${SERVICE_NAME}" --no-pager -l
}

enable_service() {
    need_root
    check_install
    systemctl enable "${SERVICE_NAME}"
    log_info "${SERVICE_NAME} enabled on boot."
}

disable_service() {
    need_root
    check_install
    systemctl disable "${SERVICE_NAME}"
    log_info "${SERVICE_NAME} disabled on boot."
}

show_log() {
    check_install
    journalctl -u "${SERVICE_NAME}.service" -e --no-pager -f
}

get_env_value() {
    local key="$1"
    [[ -f "${ENV_FILE}" ]] || return 0
    grep -E "^${key}=" "${ENV_FILE}" | tail -n 1 | cut -d= -f2-
}

mask_secret() {
    local value="$1"
    local length="${#value}"
    if [[ "${length}" -le 10 ]]; then
        echo "********"
    else
        echo "${value:0:6}********${value: -4}"
    fi
}

show_config() {
    check_install
    local port sqlite_path tz error_log session_secret
    port="$(get_env_value PORT)"
    sqlite_path="$(get_env_value SQLITE_PATH)"
    tz="$(get_env_value TZ)"
    error_log="$(get_env_value ERROR_LOG_ENABLED)"
    session_secret="$(get_env_value SESSION_SECRET)"

    echo -e "${green}New API config${plain}"
    echo "Install dir: ${INSTALL_DIR}"
    echo "Binary:      ${BIN_PATH}"
    echo "Config:      ${ENV_FILE}"
    echo "Data dir:    ${DATA_DIR}"
    echo "Log dir:     ${LOG_DIR}"
    echo "PORT:        ${port:-3000}"
    echo "SQLITE_PATH: ${sqlite_path:-}"
    echo "TZ:          ${tz:-}"
    echo "ERROR_LOG:   ${error_log:-}"
    if [[ -n "${session_secret}" ]]; then
        echo "SESSION_SECRET: $(mask_secret "${session_secret}")"
    else
        echo "SESSION_SECRET: <missing>"
    fi
}

set_env_var() {
    local key="$1"
    local value="$2"
    local tmp_file
    need_root
    mkdir -p "${INSTALL_DIR}"
    touch "${ENV_FILE}"
    tmp_file="$(mktemp)"
    awk -v key="${key}" -v value="${value}" '
        BEGIN { done = 0 }
        $0 ~ "^" key "=" { print key "=" value; done = 1; next }
        { print }
        END { if (done == 0) print key "=" value }
    ' "${ENV_FILE}" >"${tmp_file}"
    mv "${tmp_file}" "${ENV_FILE}"
    chmod 600 "${ENV_FILE}"
}

set_port() {
    need_root
    check_install
    local port="${1:-}"
    if [[ -z "${port}" ]]; then
        read -r -p "Please enter the new panel port: " port
    fi
    if ! [[ "${port}" =~ ^[0-9]+$ ]] || [[ "${port}" -lt 1 || "${port}" -gt 65535 ]]; then
        log_error "Invalid port: ${port}"
        exit 1
    fi
    set_env_var "PORT" "${port}"
    log_info "PORT has been set to ${port}. Restarting service..."
    systemctl restart "${SERVICE_NAME}"
    systemctl status "${SERVICE_NAME}" --no-pager -l
}

backup_data() {
    need_root
    check_install
    mkdir -p "${DATA_DIR}" "${LOG_DIR}" "${BACKUP_DIR}"
    local backup_file="${BACKUP_DIR}/new-api-$(date +%Y%m%d-%H%M%S).tar.gz"
    tar -czf "${backup_file}" -C "${INSTALL_DIR}" .env data logs
    chmod 600 "${backup_file}"
    log_info "Backup created: ${backup_file}"
}

restore_data() {
    need_root
    check_install
    local archive="${1:-}"
    if [[ -z "${archive}" ]]; then
        log_error "Usage: new-api restore <backup.tar.gz>"
        exit 1
    fi
    if [[ ! -f "${archive}" ]]; then
        log_error "Backup file not found: ${archive}"
        exit 1
    fi
    if tar -tzf "${archive}" | grep -Eq '(^/|(^|/)\.\.(/|$))'; then
        log_error "Backup archive contains unsafe paths."
        exit 1
    fi
    if ! confirm "This will stop New API and restore ${archive}. Continue?" "n"; then
        log_warn "Restore cancelled."
        exit 0
    fi
    systemctl stop "${SERVICE_NAME}" || true
    mkdir -p "${INSTALL_DIR}"
    tar -xzf "${archive}" -C "${INSTALL_DIR}"
    chmod 600 "${ENV_FILE}" 2>/dev/null || true
    systemctl start "${SERVICE_NAME}"
    systemctl status "${SERVICE_NAME}" --no-pager -l
}

uninstall_app() {
    need_root
    if ! confirm "Are you sure you want to uninstall New API service files?" "n"; then
        log_warn "Uninstall cancelled."
        exit 0
    fi

    systemctl stop "${SERVICE_NAME}" >/dev/null 2>&1 || true
    systemctl disable "${SERVICE_NAME}" >/dev/null 2>&1 || true
    rm -f "${SERVICE_PATH}" "${CLI_PATH}"
    systemctl daemon-reload
    systemctl reset-failed >/dev/null 2>&1 || true
    log_info "Service and command entry removed."

    if [[ -d "${INSTALL_DIR}" ]]; then
        if confirm "Delete ${INSTALL_DIR} including data, logs, backups and .env?" "n"; then
            rm -rf "${INSTALL_DIR}"
            log_info "Removed ${INSTALL_DIR}."
        else
            log_warn "Kept data directory: ${INSTALL_DIR}"
        fi
    fi
}

latest_version() {
    curl -fsSL "https://api.github.com/repos/${GITHUB_REPO}/releases/latest" \
        | grep '"tag_name":' \
        | sed -E 's/.*"([^"]+)".*/\1/' \
        | head -n 1
}

show_version() {
    if [[ -x "${BIN_PATH}" ]]; then
        echo -n "Local binary: "
        "${BIN_PATH}" --version || true
    else
        echo "Local binary: not installed"
    fi
    echo -n "Latest release: "
    latest_version || echo "unknown"
}

show_help() {
    cat <<'EOF'
New API management commands:
  new-api                 Show interactive menu
  new-api install         Install New API
  new-api update [tag]    Update to latest release or a specified release tag
  new-api start           Start service
  new-api stop            Stop service
  new-api restart         Restart service
  new-api status          Show service status
  new-api enable          Enable autostart on boot
  new-api disable         Disable autostart on boot
  new-api log             Follow systemd logs
  new-api config          Show key config values
  new-api set-port [port] Set service port and restart
  new-api backup          Backup .env, data and logs
  new-api restore <file>  Restore a backup archive
  new-api uninstall       Uninstall service files, optionally delete data
  new-api version         Show local and latest versions
  new-api help            Show this help
EOF
}

show_menu() {
    clear || true
    echo -e "${green}New API Management Menu${plain}"
    echo "  1. Install"
    echo "  2. Update"
    echo "  3. Start"
    echo "  4. Stop"
    echo "  5. Restart"
    echo "  6. Status"
    echo "  7. Logs"
    echo "  8. Enable autostart"
    echo "  9. Disable autostart"
    echo " 10. View config"
    echo " 11. Set port"
    echo " 12. Backup"
    echo " 13. Restore"
    echo " 14. Version"
    echo " 15. Uninstall"
    echo "  0. Exit"
    echo
    read -r -p "Please choose an option: " choice
    case "${choice}" in
    1) run_installer ;;
    2)
        read -r -p "Version tag (leave blank for latest): " version
        run_installer "${version}"
        ;;
    3) start_service ;;
    4) stop_service ;;
    5) restart_service ;;
    6) status_service ;;
    7) show_log ;;
    8) enable_service ;;
    9) disable_service ;;
    10) show_config ;;
    11) set_port ;;
    12) backup_data ;;
    13)
        read -r -p "Backup file path: " archive
        restore_data "${archive}"
        ;;
    14) show_version ;;
    15) uninstall_app ;;
    0) exit 0 ;;
    *) log_error "Invalid option." ;;
    esac
}

main() {
    local command="${1:-}"
    case "${command}" in
    "") show_menu ;;
    install)
        shift
        run_installer "${1:-}"
        ;;
    update)
        shift
        run_installer "${1:-}"
        ;;
    start) start_service ;;
    stop) stop_service ;;
    restart) restart_service ;;
    status) status_service ;;
    enable) enable_service ;;
    disable) disable_service ;;
    log | logs) show_log ;;
    config) show_config ;;
    set-port)
        shift
        set_port "${1:-}"
        ;;
    backup) backup_data ;;
    restore)
        shift
        restore_data "${1:-}"
        ;;
    uninstall) uninstall_app ;;
    version) show_version ;;
    help | -h | --help) show_help ;;
    *)
        log_error "Unknown command: ${command}"
        show_help
        exit 1
        ;;
    esac
}

main "$@"
