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
RAW_BASE_URL="${NEW_API_RAW_BASE_URL:-https://raw.githubusercontent.com/luntelei/newapi/main}"

log_info() { echo -e "${green}[INFO]${plain} $*"; }
log_warn() { echo -e "${yellow}[WARN]${plain} $*"; }
log_error() { echo -e "${red}[ERROR]${plain} $*" >&2; }

require_root() {
    if [[ "${EUID}" -ne 0 ]]; then
        log_error "Please run this script with root privilege."
        exit 1
    fi
}

detect_release() {
    if [[ -f /etc/os-release ]]; then
        # shellcheck disable=SC1091
        source /etc/os-release
        echo "${ID:-unknown}"
    elif [[ -f /usr/lib/os-release ]]; then
        # shellcheck disable=SC1091
        source /usr/lib/os-release
        echo "${ID:-unknown}"
    else
        echo "unknown"
    fi
}

detect_arch() {
    case "$(uname -m)" in
    x86_64 | x64 | amd64) echo "amd64" ;;
    armv8* | arm64 | aarch64) echo "arm64" ;;
    *)
        log_error "Unsupported CPU architecture: $(uname -m). Only amd64 and arm64 are supported."
        exit 1
        ;;
    esac
}

install_base() {
    local release="$1"
    log_info "Installing base dependencies for ${release}..."
    case "${release}" in
    centos | almalinux | rocky | oracle)
        yum install -y -q curl wget tar ca-certificates
        ;;
    fedora)
        dnf install -y -q curl wget tar ca-certificates
        ;;
    arch | manjaro | parch)
        pacman -Sy --noconfirm curl wget tar ca-certificates
        ;;
    opensuse-tumbleweed | opensuse-leap)
        zypper refresh
        zypper -q install -y curl wget tar ca-certificates
        ;;
    *)
        apt-get update
        DEBIAN_FRONTEND=noninteractive apt-get install -y -q curl wget tar ca-certificates
        ;;
    esac

    if ! command -v sha256sum >/dev/null 2>&1; then
        log_error "sha256sum is required but was not found after dependency installation."
        exit 1
    fi
}

latest_version() {
    curl -fsSL "https://api.github.com/repos/${GITHUB_REPO}/releases/latest" \
        | grep '"tag_name":' \
        | sed -E 's/.*"([^"]+)".*/\1/' \
        | head -n 1
}

asset_name_for_arch() {
    local version="$1"
    local arch="$2"
    case "${arch}" in
    amd64) echo "new-api-${version}" ;;
    arm64) echo "new-api-arm64-${version}" ;;
    esac
}

random_secret() {
    if command -v openssl >/dev/null 2>&1; then
        openssl rand -hex 32
        return
    fi
    od -An -N32 -tx1 /dev/urandom | tr -d ' \n'
}

ensure_env_var() {
    local key="$1"
    local value="$2"
    touch "${ENV_FILE}"
    if grep -qE "^${key}=" "${ENV_FILE}"; then
        return
    fi
    printf '%s=%s\n' "${key}" "${value}" >>"${ENV_FILE}"
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

prepare_env() {
    mkdir -p "${INSTALL_DIR}" "${DATA_DIR}" "${LOG_DIR}" "${BACKUP_DIR}"
    chmod 700 "${INSTALL_DIR}"

    local fresh_env=0
    if [[ ! -f "${ENV_FILE}" ]]; then
        fresh_env=1
        touch "${ENV_FILE}"
        chmod 600 "${ENV_FILE}"
    fi

    ensure_env_var "PORT" "3000"
    ensure_env_var "SQLITE_PATH" "${DATA_DIR}/one-api.db?_busy_timeout=30000"
    ensure_env_var "SESSION_SECRET" "$(random_secret)"
    ensure_env_var "TZ" "Asia/Shanghai"
    ensure_env_var "ERROR_LOG_ENABLED" "true"

    if grep -q '^SESSION_SECRET=random_string$' "${ENV_FILE}"; then
        log_warn "SESSION_SECRET is the insecure default value; replacing it with a random secret."
        set_env_var "SESSION_SECRET" "$(random_secret)"
    fi

    if [[ "${fresh_env}" -eq 1 ]]; then
        log_info "Created ${ENV_FILE}"
    else
        log_info "Kept existing ${ENV_FILE} and added missing defaults."
    fi
    fix_install_contexts
}

download_file() {
    local url="$1"
    local output="$2"
    if ! curl -fL --retry 3 --connect-timeout 15 -o "${output}" "${url}"; then
        log_error "Failed to download ${url}"
        exit 1
    fi
}

download_release() {
    local version="$1"
    local arch="$2"
    local tmp_dir="$3"
    local asset_name
    asset_name="$(asset_name_for_arch "${version}" "${arch}")"

    local base_url="https://github.com/${GITHUB_REPO}/releases/download/${version}"
    local binary_url="${base_url}/${asset_name}"
    local checksum_url="${base_url}/checksums-linux.txt"

    log_info "Downloading New API ${version} (${arch})..."
    download_file "${binary_url}" "${tmp_dir}/${asset_name}"
    download_file "${checksum_url}" "${tmp_dir}/checksums-linux.txt"

    (
        cd "${tmp_dir}"
        local checksum_line
        checksum_line="$(grep -E "[[:space:]]${asset_name}$" checksums-linux.txt || true)"
        if [[ -z "${checksum_line}" ]]; then
            log_error "Checksum entry for ${asset_name} was not found."
            exit 1
        fi
        echo "${checksum_line}" | sha256sum -c -
    )

    chmod +x "${tmp_dir}/${asset_name}"
    DOWNLOADED_BINARY_PATH="${tmp_dir}/${asset_name}"
}

install_support_files() {
    local script_dir="$1"

    if [[ -f "${script_dir}/new-api.sh" ]]; then
        cp -f "${script_dir}/new-api.sh" "${INSTALL_DIR}/new-api.sh"
    else
        log_warn "Local new-api.sh not found; downloading from ${RAW_BASE_URL}."
        download_file "${RAW_BASE_URL}/new-api.sh" "${INSTALL_DIR}/new-api.sh"
    fi
    chmod +x "${INSTALL_DIR}/new-api.sh"
    cp -f "${INSTALL_DIR}/new-api.sh" "${CLI_PATH}"
    chmod +x "${CLI_PATH}"

    if [[ -f "${script_dir}/install.sh" ]]; then
        cp -f "${script_dir}/install.sh" "${INSTALL_DIR}/install.sh"
        chmod +x "${INSTALL_DIR}/install.sh"
    fi

    if [[ -f "${script_dir}/new-api.service" ]]; then
        cp -f "${script_dir}/new-api.service" "${SERVICE_PATH}"
    else
        cat >"${SERVICE_PATH}" <<'EOF'
[Unit]
Description=New API Service
After=network.target
Wants=network.target

[Service]
Type=simple
WorkingDirectory=/usr/local/new-api
EnvironmentFile=/usr/local/new-api/.env
ExecStart=/usr/local/new-api/new-api --port ${PORT} --log-dir /usr/local/new-api/logs
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
    fi
    fix_install_contexts
}

install_binary() {
    local source_binary="$1"
    local backup_binary=""
    local service_was_active=0

    systemctl daemon-reload

    if systemctl is-active --quiet "${SERVICE_NAME}" 2>/dev/null; then
        service_was_active=1
        log_info "Stopping ${SERVICE_NAME} before replacing binary..."
        systemctl stop "${SERVICE_NAME}"
    fi

    if [[ -f "${BIN_PATH}" ]]; then
        backup_binary="${BIN_PATH}.backup.$(date +%Y%m%d%H%M%S)"
        cp -f "${BIN_PATH}" "${backup_binary}"
        log_info "Backed up previous binary to ${backup_binary}"
    fi

    cp -f "${source_binary}" "${BIN_PATH}.new"
    chmod +x "${BIN_PATH}.new"
    mv -f "${BIN_PATH}.new" "${BIN_PATH}"
    fix_install_contexts

    if ! systemctl daemon-reload; then
        log_error "systemctl daemon-reload failed."
        [[ -n "${backup_binary}" ]] && cp -f "${backup_binary}" "${BIN_PATH}"
        exit 1
    fi

    if ! systemctl enable --now "${SERVICE_NAME}"; then
        log_error "Failed to start ${SERVICE_NAME}; attempting rollback."
        systemctl stop "${SERVICE_NAME}" >/dev/null 2>&1 || true
        if [[ -n "${backup_binary}" && -f "${backup_binary}" ]]; then
            cp -f "${backup_binary}" "${BIN_PATH}"
            if [[ "${service_was_active}" -eq 1 ]]; then
                systemctl start "${SERVICE_NAME}" >/dev/null 2>&1 || true
            fi
        fi
        journalctl -u "${SERVICE_NAME}.service" -n 50 --no-pager || true
        exit 1
    fi
}

print_result() {
    local port
    port="$(grep -E '^PORT=' "${ENV_FILE}" | tail -n 1 | cut -d= -f2-)"
    port="${port:-3000}"
    local local_ip public_ip
    local_ip="$(hostname -I 2>/dev/null | awk '{print $1}' || true)"
    public_ip="$(curl -fsS --connect-timeout 2 --max-time 4 https://api4.ipify.org 2>/dev/null || true)"
    if [[ -z "${public_ip}" ]]; then
        public_ip="$(curl -4 -fsS --connect-timeout 2 --max-time 4 https://ifconfig.me 2>/dev/null || true)"
    fi

    echo
    log_info "New API installation/update finished."
    echo -e "Access URL: ${green}http://127.0.0.1:${port}${plain}"
    if [[ -n "${local_ip}" ]]; then
        echo -e "LAN URL:    ${green}http://${local_ip}:${port}${plain}"
    fi
    if [[ -n "${public_ip}" ]]; then
        echo -e "Public URL: ${green}http://${public_ip}:${port}${plain}"
    fi
    echo -e "Config file: ${green}${ENV_FILE}${plain}"
    echo -e "Data dir:    ${green}${DATA_DIR}${plain}"
    echo -e "Logs:        ${green}new-api log${plain}"
    echo -e "Root setup:  ${yellow}open the Web page and use New API's built-in initialization flow.${plain}"
    echo
    new-api help || true
}

main() {
    require_root

    if ! command -v systemctl >/dev/null 2>&1; then
        log_error "systemctl is required. This installer targets Linux systems using systemd."
        exit 1
    fi

    local release arch version script_dir tmp_dir
    release="$(detect_release)"
    arch="$(detect_arch)"
    log_info "OS release: ${release}"
    log_info "CPU arch: ${arch}"

    install_base "${release}"

    version="${1:-}"
    if [[ -z "${version}" ]]; then
        version="$(latest_version)"
        if [[ -z "${version}" ]]; then
            log_error "Failed to fetch latest New API version from GitHub."
            exit 1
        fi
    fi
    log_info "Selected version: ${version}"

    tmp_dir="$(mktemp -d)"
    trap 'rm -rf "${tmp_dir:-}"' EXIT
    DOWNLOADED_BINARY_PATH=""
    download_release "${version}" "${arch}" "${tmp_dir}"

    prepare_env

    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
    install_support_files "${script_dir}"
    install_binary "${DOWNLOADED_BINARY_PATH}"
    print_result
}

main "$@"
