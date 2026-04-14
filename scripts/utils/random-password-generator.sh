#!/bin/bash
# random-password-generator.sh — Generate a cryptographically random password.
# Usage: ./random-password-generator.sh [options]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/utils.sh"

LENGTH="${LENGTH:-20}"
COUNT="${COUNT:-1}"
NO_SYMBOLS=false

usage() {
    cat <<EOF
Usage: $(basename "$0") [options]

Generate one or more cryptographically secure random passwords using /dev/urandom.

Options:
  --length N      Password length in characters (env: LENGTH, default: ${LENGTH})
  --count  N      Number of passwords to generate (default: ${COUNT})
  --no-symbols    Exclude special characters (alphanumeric only)
  -h, --help      Show this help message

Examples:
  $(basename "$0")
  $(basename "$0") --length 32 --count 5
  $(basename "$0") --length 16 --no-symbols
EOF
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --length)     LENGTH="$2";      shift 2 ;;
        --count)      COUNT="$2";       shift 2 ;;
        --no-symbols) NO_SYMBOLS=true;  shift   ;;
        -h|--help)    usage ;;
        *) log_error "Unknown option: $1"; usage ;;
    esac
done

if "$NO_SYMBOLS"; then
    CHAR_CLASS='a-zA-Z0-9'
else
    CHAR_CLASS='a-zA-Z0-9!@#$%^&*()-_=+[]{}|;:,.<>?'
fi

log_info "Generating ${COUNT} password(s) of length ${LENGTH}..."

for (( i=1; i<=COUNT; i++ )); do
    # LC_ALL=C ensures tr works with non-ASCII locales
    # || true suppresses SIGPIPE (141) from head closing the pipe before tr exhausts /dev/urandom
    LC_ALL=C tr -dc "$CHAR_CLASS" < /dev/urandom | head -c "${LENGTH}" || true
    echo
done
