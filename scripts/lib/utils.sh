#!/bin/bash
# scripts/lib/utils.sh — Shared utility library for bash-scripts
#
# Source this file from the scripts/ root:
#   source "$(dirname "${BASH_SOURCE[0]}")/lib/utils.sh"
# Source this file from a scripts/subdir/:
#   source "$(dirname "${BASH_SOURCE[0]}")/../lib/utils.sh"

# Prevent double-sourcing
[[ -n "${_UTILS_SH_LOADED:-}" ]] && return 0
readonly _UTILS_SH_LOADED=1

# ---------------------------------------------------------------------------
# Color constants (ANSI escapes; safe to use in echo -e)
# ---------------------------------------------------------------------------
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# ---------------------------------------------------------------------------
# Logging  — info goes to stdout; warn/error go to stderr
# ---------------------------------------------------------------------------
log_info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC}  $*" >&2; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

# ---------------------------------------------------------------------------
# check_dependency <cmd>
# Exits 1 with a helpful message if <cmd> is not on PATH.
# ---------------------------------------------------------------------------
check_dependency() {
    local cmd="$1"
    if ! command -v "$cmd" &>/dev/null; then
        log_error "Required command not found: '${cmd}'. Please install it and re-run."
        exit 1
    fi
}

# ---------------------------------------------------------------------------
# confirm_action [prompt]
# Prints prompt, reads user input.  Exits 1 if answer is not exactly "yes".
# ---------------------------------------------------------------------------
confirm_action() {
    local prompt="${1:-Are you sure? (yes/no)}"
    local answer
    read -rp "${prompt}: " answer
    if [[ "$answer" != "yes" ]]; then
        log_warn "Aborted by user."
        exit 1
    fi
}

# ---------------------------------------------------------------------------
# run_or_dry <cmd> [args...]
# Requires DRY_RUN variable to be set (true/false) in the calling script.
# When DRY_RUN=true, prints the command instead of executing it.
# ---------------------------------------------------------------------------
run_or_dry() {
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        echo -e "${YELLOW}[DRY-RUN]${NC} $*"
    else
        "$@"
    fi
}
