#!/bin/bash
# check-ssl-expiry.sh — Check SSL certificate expiration for a domain.
# Usage: ./check-ssl-expiry.sh [domain] [port] [--warn-days N]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/utils.sh"

DOMAIN="${1:-example.com}"
PORT="${2:-443}"
WARNING_DAYS=30

usage() {
    cat <<EOF
Usage: $(basename "$0") [domain] [port] [options]

Check SSL certificate expiration date for a domain.

Arguments:
  domain          Domain to check (default: ${DOMAIN})
  port            Port to connect on (default: ${PORT})

Options:
  --warn-days N   Days before expiry that trigger a warning (default: ${WARNING_DAYS})
  -h, --help      Show this help message

Exit codes:
  0   Certificate is valid and not expiring soon
  1   Certificate expires within the warning threshold
  2   Certificate has already expired

Examples:
  $(basename "$0") example.com
  $(basename "$0") example.com 8443 --warn-days 14
EOF
    exit 0
}

# Parse positional args and flags together
args=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        --warn-days) WARNING_DAYS="$2"; shift 2 ;;
        -h|--help)   usage ;;
        *) args+=("$1"); shift ;;
    esac
done
[[ ${#args[@]} -ge 1 ]] && DOMAIN="${args[0]}"
[[ ${#args[@]} -ge 2 ]] && PORT="${args[1]}"

check_dependency openssl

log_info "Checking SSL certificate for ${DOMAIN}:${PORT}..."

CERT_INFO=$(echo | openssl s_client -servername "$DOMAIN" -connect "${DOMAIN}:${PORT}" 2>/dev/null \
            | openssl x509 -noout -dates 2>/dev/null) || true

if [[ -z "$CERT_INFO" ]]; then
    log_error "Unable to retrieve certificate. Check that the domain is reachable."
    exit 1
fi

EXPIRY_DATE=$(echo "$CERT_INFO" | grep "notAfter" | cut -d= -f2)

# Cross-platform date parsing (Linux/macOS)
if EXPIRY_EPOCH=$(date -d "$EXPIRY_DATE" +%s 2>/dev/null); then
    :  # Linux
elif EXPIRY_EPOCH=$(date -j -f "%b %d %T %Y %Z" "$EXPIRY_DATE" +%s 2>/dev/null); then
    :  # macOS
else
    log_error "Could not parse certificate expiry date: ${EXPIRY_DATE}"
    exit 1
fi

CURRENT_EPOCH=$(date +%s)
DAYS_UNTIL_EXPIRY=$(( (EXPIRY_EPOCH - CURRENT_EPOCH) / 86400 ))

echo "  Certificate expiry : ${EXPIRY_DATE}"
echo "  Days until expiry  : ${DAYS_UNTIL_EXPIRY}"

echo | openssl s_client -servername "$DOMAIN" -connect "${DOMAIN}:${PORT}" 2>/dev/null \
      | openssl x509 -noout -subject -issuer 2>/dev/null || true

if [[ "$DAYS_UNTIL_EXPIRY" -lt 0 ]]; then
    log_error "Certificate has EXPIRED!"
    exit 2
elif [[ "$DAYS_UNTIL_EXPIRY" -lt "$WARNING_DAYS" ]]; then
    log_warn "Certificate expires in ${DAYS_UNTIL_EXPIRY} day(s) — under ${WARNING_DAYS}-day threshold."
    exit 1
else
    log_info "Certificate is valid (${DAYS_UNTIL_EXPIRY} days remaining)."
fi
