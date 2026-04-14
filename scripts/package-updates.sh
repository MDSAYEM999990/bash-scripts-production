#!/bin/bash
# package-updates.sh — Check for and optionally install available package updates.
# Usage: ./package-updates.sh [options]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/utils.sh"

AUTO_INSTALL=false

usage() {
    cat <<EOF
Usage: $(basename "$0") [options]

Detect the system package manager (apt, yum/dnf, brew, apk) and report
available updates. Optionally install them after confirmation.

Options:
  --install     Install all available updates (asks for confirmation)
  -h, --help    Show this help message

Examples:
  $(basename "$0")
  $(basename "$0") --install
EOF
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --install) AUTO_INSTALL=true; shift ;;
        -h|--help) usage ;;
        *) log_error "Unknown option: $1"; usage ;;
    esac
done

if command -v apt-get &>/dev/null; then
    PKG_MGR="apt"
elif command -v dnf &>/dev/null; then
    PKG_MGR="dnf"
elif command -v yum &>/dev/null; then
    PKG_MGR="yum"
elif command -v brew &>/dev/null; then
    PKG_MGR="brew"
elif command -v apk &>/dev/null; then
    PKG_MGR="apk"
else
    log_error "No supported package manager found (apt, dnf, yum, brew, apk)."
    exit 1
fi

log_info "Package manager: ${PKG_MGR}"
log_info "Checking for available updates..."

case "$PKG_MGR" in
    apt)
        apt-get -qq update
        UPGRADABLE=$(apt-get --simulate upgrade 2>/dev/null | grep "^Inst " | wc -l || echo "0")
        log_info "${UPGRADABLE} package(s) can be upgraded."
        if "$AUTO_INSTALL" && [[ "$UPGRADABLE" -gt 0 ]]; then
            confirm_action "Install ${UPGRADABLE} package update(s)?"
            apt-get -y upgrade
        fi
        ;;
    dnf|yum)
        "$PKG_MGR" check-update --quiet || true
        if "$AUTO_INSTALL"; then
            confirm_action "Install all available updates?"
            "$PKG_MGR" -y upgrade
        fi
        ;;
    brew)
        brew update --quiet
        OUTDATED=$(brew outdated | wc -l | tr -d ' ')
        log_info "${OUTDATED} formula(e) can be upgraded."
        if "$AUTO_INSTALL" && [[ "$OUTDATED" -gt 0 ]]; then
            confirm_action "Upgrade ${OUTDATED} formula(e)?"
            brew upgrade
        fi
        ;;
    apk)
        apk update --quiet
        if "$AUTO_INSTALL"; then
            confirm_action "Upgrade all packages?"
            apk upgrade
        fi
        ;;
esac

log_info "Done."
