#!/bin/bash
# aws-cost-alert.sh — Query AWS Cost Explorer and alert if spend exceeds threshold
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/utils.sh
source "${SCRIPT_DIR}/../lib/utils.sh"

THRESHOLD=""
PERIOD="MONTHLY"
WEBHOOK_URL="${AWS_COST_WEBHOOK:-}"
GRANULARITY="MONTHLY"
DRY_RUN=false

usage() {
    cat <<EOF
Usage: $(basename "$0") [options]

Query AWS Cost Explorer for the current month's spend and send a Slack
alert when the total exceeds a threshold.

Requirements:
  - AWS CLI configured with credentials that have ce:GetCostAndUsage permission
  - jq

Options:
  --threshold AMOUNT  Alert threshold in USD                       (required)
  --webhook URL       Slack incoming webhook URL                   (env: AWS_COST_WEBHOOK)
  --period PERIOD     Cost period: MONTHLY or DAILY               (default: MONTHLY)
  --dry-run           Query cost but do not send an alert
  -h, --help          Show this help message

Examples:
  $(basename "$0") --threshold 500 --webhook https://hooks.slack.com/...
  $(basename "$0") --threshold 100 --period DAILY --dry-run
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --threshold) THRESHOLD="$2";    shift 2 ;;
        --webhook)   WEBHOOK_URL="$2";  shift 2 ;;
        --period)    PERIOD="$2";       shift 2 ;;
        --dry-run)   DRY_RUN=true;      shift ;;
        -h|--help)   usage; exit 0 ;;
        *) log_error "Unknown option: $1"; usage; exit 1 ;;
    esac
done

if [[ -z "$THRESHOLD" ]]; then
    log_error "A cost threshold (--threshold) is required."
    usage
    exit 1
fi

check_dependency aws
check_dependency jq

# Date range: start of current month to tomorrow
START_DATE=$(date -u +"%Y-%m-01")
END_DATE=$(date -u -v+1d +"%Y-%m-%d" 2>/dev/null || date -u -d "+1 day" +"%Y-%m-%d")

log_info "Querying AWS Cost Explorer (${START_DATE} → ${END_DATE}, granularity: ${PERIOD})..."

COST_JSON=$(aws ce get-cost-and-usage \
    --time-period "Start=${START_DATE},End=${END_DATE}" \
    --granularity "$PERIOD" \
    --metrics "UnblendedCost" \
    --output json 2>&1) || {
    log_error "AWS CLI call failed."
    echo "$COST_JSON" >&2
    exit 2
}

TOTAL=$(echo "$COST_JSON" | jq -r '.ResultsByTime[0].Total.UnblendedCost.Amount // "0"')
UNIT=$(echo  "$COST_JSON" | jq -r '.ResultsByTime[0].Total.UnblendedCost.Unit   // "USD"')

log_info "Current spend: ${TOTAL} ${UNIT}  (threshold: ${THRESHOLD} ${UNIT})"

# Numeric comparison using awk (avoids bc dependency)
OVER_THRESHOLD=$(awk "BEGIN { print (${TOTAL} > ${THRESHOLD}) ? 1 : 0 }")

if [[ "$OVER_THRESHOLD" -eq 1 ]]; then
    MESSAGE="*AWS Cost Alert* — $(hostname)\nCurrent spend: \`${TOTAL} ${UNIT}\` exceeds threshold of \`${THRESHOLD} ${UNIT}\`."
    log_warn "Threshold exceeded: ${TOTAL} ${UNIT} > ${THRESHOLD} ${UNIT}"

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[dry-run] Would post alert to Slack."
        exit 0
    fi

    if [[ -n "$WEBHOOK_URL" ]]; then
        PAYLOAD=$(jq -n --arg text "$(printf '%b' "$MESSAGE")" '{text: $text}')
        curl -fsSL -X POST -H 'Content-type: application/json' \
            --data "$PAYLOAD" "$WEBHOOK_URL" || log_warn "Could not post Slack alert."
    fi
    exit 0
else
    log_info "Spend is within threshold."
fi

exit 0
