#!/bin/bash
# terraform-plan-notify.sh — Run terraform plan and post a summary to Slack
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/utils.sh
source "${SCRIPT_DIR}/../lib/utils.sh"

WEBHOOK_URL="${TF_SLACK_WEBHOOK:-}"
WORKING_DIR="."
WORKSPACE=""
VAR_FILE=""
DRY_RUN=false

usage() {
    cat <<EOF
Usage: $(basename "$0") [options]

Run 'terraform plan' in the specified directory and post a concise summary
(added/changed/destroyed counts) to a Slack webhook.

Options:
  --webhook URL       Slack incoming webhook URL                    (env: TF_SLACK_WEBHOOK, required)
  --dir PATH          Terraform working directory                   (default: .)
  --workspace NAME    Terraform workspace to select before planning
  --var-file FILE     Pass a .tfvars file to terraform plan
  --dry-run           Run terraform plan but do not post to Slack
  -h, --help          Show this help message

Examples:
  $(basename "$0") --webhook https://hooks.slack.com/... --dir infra/
  $(basename "$0") --webhook https://hooks.slack.com/... --workspace staging
  $(basename "$0") --dir infra/ --dry-run
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --webhook)    WEBHOOK_URL="$2";   shift 2 ;;
        --dir)        WORKING_DIR="$2";   shift 2 ;;
        --workspace)  WORKSPACE="$2";     shift 2 ;;
        --var-file)   VAR_FILE="$2";      shift 2 ;;
        --dry-run)    DRY_RUN=true;       shift ;;
        -h|--help)    usage; exit 0 ;;
        *) log_error "Unknown option: $1"; usage; exit 1 ;;
    esac
done

if [[ -z "$WEBHOOK_URL" ]] && [[ "$DRY_RUN" == "false" ]]; then
    log_error "A Slack webhook URL is required (--webhook or TF_SLACK_WEBHOOK)."
    usage
    exit 1
fi

check_dependency terraform
check_dependency jq

if [[ ! -d "$WORKING_DIR" ]]; then
    log_error "Working directory not found: ${WORKING_DIR}"
    exit 2
fi

cd "$WORKING_DIR"

if [[ -n "$WORKSPACE" ]]; then
    log_info "Selecting workspace: ${WORKSPACE}"
    terraform workspace select "$WORKSPACE" || terraform workspace new "$WORKSPACE"
fi

# Build plan command as an array — always ≥2 elements (safe under bash 3.2 set -u)
PLAN_CMD=(terraform plan -no-color)
[[ -n "$VAR_FILE" ]] && PLAN_CMD+=(-var-file="$VAR_FILE")

log_info "Running terraform plan..."
PLAN_OUTPUT=$("${PLAN_CMD[@]}" 2>&1) || {
    log_error "terraform plan failed."
    echo "$PLAN_OUTPUT" >&2
    exit 2
}

# Extract the summary line (e.g. "Plan: 2 to add, 1 to change, 0 to destroy.")
SUMMARY=$(echo "$PLAN_OUTPUT" | grep -E '^Plan:|No changes\.' | tail -1 || echo "Plan complete.")

log_info "Plan summary: ${SUMMARY}"

if [[ "$DRY_RUN" == "true" ]]; then
    log_info "[dry-run] Would post to Slack: ${SUMMARY}"
    exit 0
fi

HOST=$(hostname)
PAYLOAD=$(jq -n \
    --arg summary "$SUMMARY" \
    --arg host "$HOST" \
    --arg dir "$WORKING_DIR" \
    '{text: ("*Terraform Plan* on `" + $host + "` — `" + $dir + "`\n" + $summary)}')

curl -fsSL -X POST -H 'Content-type: application/json' \
    --data "$PAYLOAD" "$WEBHOOK_URL" || {
    log_error "Failed to post Slack notification."
    exit 2
}

log_info "Slack notification sent."
exit 0
