#!/usr/bin/env bash

set -Eeuo pipefail

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

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
SCRIPT_URL="${NEW_API_SCRIPT_URL:-https://raw.githubusercontent.com/luntelei/newapi/main/new-api.sh}"

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

pause_menu() {
    echo
    read -r -p "Press Enter to return to the menu..." _
    show_menu
}

service_file_exists() {
    [[ -f "${SERVICE_PATH}" ]]
}

binary_exists() {
    [[ -x "${BIN_PATH}" ]]
}

check_install() {
    if ! binary_exists; then
        log_error "New API is not installed. Run: new-api install"
        exit 1
    fi
}

get_env_value() {
    local key="$1"
    [[ -f "${ENV_FILE}" ]] || return 0
    awk -F= -v key="${key}" '$1 == key { value = substr($0, length(key) + 2) } END { if (value != "") print value }' "${ENV_FILE}"
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

service_state() {
    if ! service_file_exists; then
        echo "not installed"
    elif systemctl is-active --quiet "${SERVICE_NAME}" 2>/dev/null; then
        echo "running"
    else
        echo "stopped"
    fi
}

autostart_state() {
    if ! service_file_exists; then
        echo "not installed"
    elif systemctl is-enabled --quiet "${SERVICE_NAME}" 2>/dev/null; then
        echo "enabled"
    else
        echo "disabled"
    fi
}

local_version() {
    if binary_exists; then
        "${BIN_PATH}" --version 2>/dev/null | head -n 1 || echo "unknown"
    else
        echo "not installed"
    fi
}

latest_version() {
    curl -fsSL "https://api.github.com/repos/${GITHUB_REPO}/releases/latest" \
        | grep '"tag_name":' \
        | sed -E 's/.*"([^"]+)".*/\1/' \
        | head -n 1
}

primary_ipv4() {
    local ip=""
    ip="$(hostname -I 2>/dev/null | awk '{print $1}' || true)"
    if [[ -z "${ip}" ]] && command -v ip >/dev/null 2>&1; then
        ip="$(ip -4 route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="src") {print $(i+1); exit}}' || true)"
    fi
    echo "${ip}"
}

public_ipv4() {
    local ip=""
    ip="$(curl -fsS --connect-timeout 2 --max-time 4 https://api4.ipify.org 2>/dev/null || true)"
    if [[ -z "${ip}" ]]; then
        ip="$(curl -4 -fsS --connect-timeout 2 --max-time 4 https://ifconfig.me 2>/dev/null || true)"
    fi
    echo "${ip}"
}

format_host_url() {
    local host="$1"
    local port="$2"
    if [[ "${host}" == *:* ]]; then
        echo "http://[${host}]:${port}"
    else
        echo "http://${host}:${port}"
    fi
}

show_access_urls() {
    local port local_ip public_ip
    port="$(get_env_value PORT)"
    port="${port:-3000}"
    local_ip="$(primary_ipv4)"
    public_ip="$(public_ipv4)"

    echo -e "${green}Access URLs${plain}"
    echo "Local:  http://127.0.0.1:${port}"
    if [[ -n "${local_ip}" ]]; then
        echo "LAN:    $(format_host_url "${local_ip}" "${port}")"
    fi
    if [[ -n "${public_ip}" ]]; then
        echo "Public: $(format_host_url "${public_ip}" "${port}")"
    else
        echo "Public: unknown"
    fi
    echo
    echo "If this is a fresh New API install, open the Web page to complete the built-in root account setup."
}

show_summary() {
    local port
    port="$(get_env_value PORT)"
    port="${port:-3000}"

    echo -e "${green}New API status${plain}"
    echo "Service:   $(service_state)"
    echo "Autostart: $(autostart_state)"
    echo "Port:      ${port}"
    echo "Version:   $(local_version)"
    echo "Install:   ${INSTALL_DIR}"
    echo "Config:    ${ENV_FILE}"
}

fix_install_contexts() {
    chmod 700 "${INSTALL_DIR}" 2>/dev/null || true
    chmod 600 "${ENV_FILE}" 2>/dev/null || true
    if command -v restorecon >/dev/null 2>&1; then
        restorecon -R "${INSTALL_DIR}" "${SERVICE_PATH}" 2>/dev/null || true
    fi
    if command -v chcon >/dev/null 2>&1; then
        chcon -t usr_t "${ENV_FILE}" "${BIN_PATH}" "${INSTALL_DIR}/new-api.sh" "${INSTALL_DIR}/install.sh" 2>/dev/null || true
        chcon -t systemd_unit_file_t "${SERVICE_PATH}" 2>/dev/null || true
    fi
}

set_env_var() {
    local key="$1"
    local value="$2"
    local tmp_file
    need_root
    mkdir -p "${INSTALL_DIR}"
    touch "${ENV_FILE}"
    tmp_file="$(mktemp "${INSTALL_DIR}/.env.XXXXXX")"
    awk -v key="${key}" -v value="${value}" '
        BEGIN { done = 0 }
        $0 ~ "^" key "=" { print key "=" value; done = 1; next }
        { print }
        END { if (done == 0) print key "=" value }
    ' "${ENV_FILE}" >"${tmp_file}"
    chmod 600 "${tmp_file}"
    mv "${tmp_file}" "${ENV_FILE}"
    fix_install_contexts
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

show_config() {
    check_install
    local port sqlite_path sql_dsn redis_conn tz error_log session_secret frontend_url trusted_url
    port="$(get_env_value PORT)"
    sqlite_path="$(get_env_value SQLITE_PATH)"
    sql_dsn="$(get_env_value SQL_DSN)"
    redis_conn="$(get_env_value REDIS_CONN_STRING)"
    tz="$(get_env_value TZ)"
    error_log="$(get_env_value ERROR_LOG_ENABLED)"
    session_secret="$(get_env_value SESSION_SECRET)"
    frontend_url="$(get_env_value FRONTEND_BASE_URL)"
    trusted_url="$(get_env_value SESSION_COOKIE_TRUSTED_URL)"

    echo -e "${green}New API config${plain}"
    echo "Install dir: ${INSTALL_DIR}"
    echo "Binary:      ${BIN_PATH}"
    echo "Service:     ${SERVICE_PATH}"
    echo "Config:      ${ENV_FILE}"
    echo "Data dir:    ${DATA_DIR}"
    echo "Log dir:     ${LOG_DIR}"
    echo "PORT:        ${port:-3000}"
    echo "SQLITE_PATH: ${sqlite_path:-}"
    echo "SQL_DSN:     ${sql_dsn:+<configured>}"
    echo "REDIS:       ${redis_conn:+<configured>}"
    echo "TZ:          ${tz:-}"
    echo "ERROR_LOG:   ${error_log:-}"
    echo "FRONTEND:    ${frontend_url:-}"
    echo "TRUSTED_URL: ${trusted_url:-}"
    if [[ -n "${session_secret}" ]]; then
        echo "SESSION_SECRET: $(mask_secret "${session_secret}")"
    else
        echo "SESSION_SECRET: <missing>"
    fi
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
    local backup_file
    backup_file="${BACKUP_DIR}/new-api-$(date +%Y%m%d-%H%M%S).tar.gz"
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
    fix_install_contexts
    systemctl daemon-reload
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

show_version() {
    echo -n "Local binary: "
    local_version
    echo -n "Latest release: "
    latest_version || echo "unknown"
}

update_script() {
    need_root
    local tmp_file
    tmp_file="$(mktemp)"
    log_info "Downloading latest management script from ${SCRIPT_URL}"
    if ! curl -fL --retry 3 --connect-timeout 15 -o "${tmp_file}" "${SCRIPT_URL}"; then
        rm -f "${tmp_file}"
        log_error "Failed to download management script."
        exit 1
    fi
    if ! bash -n "${tmp_file}"; then
        rm -f "${tmp_file}"
        log_error "Downloaded script has syntax errors; keeping current script."
        exit 1
    fi
    install -m 755 "${tmp_file}" "${CLI_PATH}"
    mkdir -p "${INSTALL_DIR}"
    cp -f "${CLI_PATH}" "${INSTALL_DIR}/new-api.sh"
    chmod +x "${INSTALL_DIR}/new-api.sh"
    rm -f "${tmp_file}"
    log_info "Management script updated. Run: new-api help"
}

check_files() {
    echo -e "${green}Install check${plain}"
    [[ -d "${INSTALL_DIR}" ]] && echo "Install dir: ok" || echo "Install dir: missing"
    [[ -d "${DATA_DIR}" ]] && echo "Data dir:    ok" || echo "Data dir:    missing"
    [[ -d "${LOG_DIR}" ]] && echo "Log dir:     ok" || echo "Log dir:     missing"
    [[ -f "${ENV_FILE}" ]] && echo "Env file:    ok" || echo "Env file:    missing"
    binary_exists && echo "Binary:      ok" || echo "Binary:      missing"
    service_file_exists && echo "Service:     ok" || echo "Service:     missing"
    [[ -x "${CLI_PATH}" ]] && echo "Command:     ok" || echo "Command:     missing"
}

current_congestion() {
    sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null || echo "unknown"
}

current_qdisc() {
    sysctl -n net.core.default_qdisc 2>/dev/null || echo "unknown"
}

available_congestion() {
    sysctl -n net.ipv4.tcp_available_congestion_control 2>/dev/null || echo "unknown"
}

bbr_status() {
    echo -e "${green}BBR status${plain}"
    echo "Current congestion: $(current_congestion)"
    echo "Current qdisc:      $(current_qdisc)"
    echo "Available:          $(available_congestion)"
    if [[ "$(current_congestion)" == "bbr" ]]; then
        log_info "BBR is active."
    elif available_congestion | grep -qw "bbr"; then
        log_warn "BBR is available but not active."
    else
        log_warn "BBR is not listed as available by this kernel."
    fi
}

set_sysctl_kv() {
    local key="$1"
    local value="$2"
    local file="/etc/sysctl.conf"
    touch "${file}"
    if grep -qE "^[[:space:]]*${key}[[:space:]]*=" "${file}"; then
        sed -i -E "s|^[[:space:]]*${key}[[:space:]]*=.*|${key}=${value}|" "${file}"
    else
        printf '\n%s=%s\n' "${key}" "${value}" >>"${file}"
    fi
}

backup_sysctl_conf() {
    local backup
    backup="/etc/sysctl.conf.new-api.bak.$(date +%Y%m%d%H%M%S)"
    cp -a /etc/sysctl.conf "${backup}" 2>/dev/null || touch "${backup}"
    echo "${backup}"
}

enable_bbr() {
    need_root
    if [[ "$(current_congestion)" == "bbr" ]]; then
        log_info "BBR is already active."
        bbr_status
        return
    fi
    if ! available_congestion | grep -qw "bbr"; then
        log_warn "This kernel does not report BBR as available. The change may fail."
    fi
    if ! confirm "Enable BBR by updating /etc/sysctl.conf?" "n"; then
        log_warn "BBR enable cancelled."
        return
    fi
    local backup
    backup="$(backup_sysctl_conf)"
    set_sysctl_kv "net.core.default_qdisc" "fq"
    set_sysctl_kv "net.ipv4.tcp_congestion_control" "bbr"
    if ! sysctl -p >/dev/null; then
        log_error "sysctl -p failed. Backup: ${backup}"
        exit 1
    fi
    log_info "BBR settings applied. Backup: ${backup}"
    bbr_status
}

disable_bbr() {
    need_root
    if [[ "$(current_congestion)" != "bbr" ]] && [[ "$(current_qdisc)" != "fq" ]]; then
        log_info "BBR does not appear to be active."
        bbr_status
        return
    fi
    if ! confirm "Disable BBR and restore CUBIC/pfifo_fast in /etc/sysctl.conf?" "n"; then
        log_warn "BBR disable cancelled."
        return
    fi
    local backup
    backup="$(backup_sysctl_conf)"
    set_sysctl_kv "net.core.default_qdisc" "pfifo_fast"
    set_sysctl_kv "net.ipv4.tcp_congestion_control" "cubic"
    if ! sysctl -p >/dev/null; then
        log_error "sysctl -p failed. Backup: ${backup}"
        exit 1
    fi
    log_info "BBR disabled. Backup: ${backup}"
    bbr_status
}

bbr_menu() {
    clear || true
    echo -e "${green}BBR Optimization${plain}"
    echo "  1. Show BBR status"
    echo "  2. Enable BBR"
    echo "  3. Disable BBR"
    echo "  0. Back"
    echo
    read -r -p "Please choose an option: " choice
    case "${choice}" in
    1) bbr_status ;;
    2) enable_bbr ;;
    3) disable_bbr ;;
    0) show_menu ;;
    *) log_error "Invalid option." ;;
    esac
    pause_menu
}

show_help() {
    cat <<'EOF'
New API management commands:
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
EOF
}

show_menu() {
    clear || true
    echo -e "${green}New API Management Menu${plain}"
    echo "----------------------------------------"
    show_summary
    echo "----------------------------------------"
    echo "  1. Install"
    echo "  2. Update"
    echo "  3. Custom version"
    echo "  4. Update management script"
    echo "----------------------------------------"
    echo "  5. Start"
    echo "  6. Stop"
    echo "  7. Restart"
    echo "  8. Status"
    echo "  9. Logs"
    echo " 10. Enable autostart"
    echo " 11. Disable autostart"
    echo "----------------------------------------"
    echo " 12. View config"
    echo " 13. Set port"
    echo " 14. Access URLs"
    echo " 15. Check install"
    echo " 16. Version"
    echo "----------------------------------------"
    echo " 17. Backup"
    echo " 18. Restore"
    echo " 19. BBR optimization"
    echo " 20. Uninstall"
    echo "  0. Exit"
    echo
    read -r -p "Please choose an option: " choice
    case "${choice}" in
    1) run_installer ;;
    2) run_installer ;;
    3)
        read -r -p "Version tag: " version
        if [[ -z "${version}" ]]; then
            log_error "Version tag cannot be empty."
        else
            run_installer "${version}"
        fi
        ;;
    4) update_script ;;
    5) start_service ;;
    6) stop_service ;;
    7) restart_service ;;
    8) status_service ;;
    9) show_log ;;
    10) enable_service ;;
    11) disable_service ;;
    12) show_config ;;
    13) set_port ;;
    14) show_access_urls ;;
    15) check_files ;;
    16) show_version ;;
    17) backup_data ;;
    18)
        read -r -p "Backup file path: " archive
        restore_data "${archive}"
        ;;
    19) bbr_menu ;;
    20) uninstall_app ;;
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
    update-script) update_script ;;
    start) start_service ;;
    stop) stop_service ;;
    restart) restart_service ;;
    status) status_service ;;
    enable) enable_service ;;
    disable) disable_service ;;
    log | logs) show_log ;;
    summary) show_summary ;;
    config) show_config ;;
    uri | urls) show_access_urls ;;
    set-port)
        shift
        set_port "${1:-}"
        ;;
    backup) backup_data ;;
    restore)
        shift
        restore_data "${1:-}"
        ;;
    check) check_files ;;
    bbr)
        shift
        case "${1:-status}" in
        status) bbr_status ;;
        enable) enable_bbr ;;
        disable) disable_bbr ;;
        *) log_error "Usage: new-api bbr {status|enable|disable}"; exit 1 ;;
        esac
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
