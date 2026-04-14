#!/bin/bash
# slack-notify.sh — Send a notification to a Slack channel via Incoming Webhook.
# Usage: ./slack-notify.sh [options]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/utils.sh"

WEBHOOK_URL="${SLACK_WEBHOOK_URL:-}"
MESSAGE="${MESSAGE:-}"
USERNAME="${SLACK_USERNAME:-DevOps Bot}"
ICON="${SLACK_ICON:-:robot_face:}"
CHANNEL="${SLACK_CHANNEL:-}"

usage() {
    cat <<EOF
Usage: $(basename "$0") [options]

Post a message to a Slack channel using an Incoming Webhook URL.

Options:
  --webhook URL    Slack Incoming Webhook URL (env: SLACK_WEBHOOK_URL)
  --message TEXT   Message text              (env: MESSAGE)
  --channel CHAN   Override default channel  (env: SLACK_CHANNEL)
  --username NAME  Bot display name          (env: SLACK_USERNAME, default: DevOps Bot)
  --icon EMOJI     Bot icon emoji            (env: SLACK_ICON, default: :robot_face:)
  -h, --help       Show this help message

Examples:
  $(basename "$0") --webhook https://hooks.slack.com/... --message "Deploy complete!"
  SLACK_WEBHOOK_URL=https://... $(basename "$0") --message "Build failed" --channel "#alerts"
EOF
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --webhook)  WEBHOOK_URL="$2"; shift 2 ;;
        --message)  MESSAGE="$2";     shift 2 ;;
        --channel)  CHANNEL="$2";     shift 2 ;;
        --username) USERNAME="$2";    shift 2 ;;
        --icon)     ICON="$2";        shift 2 ;;
        -h|--help)  usage ;;
        *) log_error "Unknown option: $1"; usage ;;
    esac
done

check_dependency curl
check_dependency jq

if [[ -z "$WEBHOOK_URL" ]]; then
    log_error "Slack webhook URL is required (--webhook or env var SLACK_WEBHOOK_URL)."
    exit 1
fi
if [[ -z "$MESSAGE" ]]; then
    log_error "Message is required (--message or env var MESSAGE)."
    exit 1
fi

PAYLOAD=$(jq -n \
    --arg text     "$MESSAGE" \
    --arg username "$USERNAME" \
    --arg icon     "$ICON" \
    '{text: $text, username: $username, icon_emoji: $icon}')

if [[ -n "$CHANNEL" ]]; then
    PAYLOAD=$(echo "$PAYLOAD" | jq --arg ch "$CHANNEL" '. + {channel: $ch}')
fi

log_info "Sending Slack notification..."
curl --silent --fail --show-error \
    -X POST -H "Content-Type: application/json" \
    --data "$PAYLOAD" \
    "$WEBHOOK_URL"
log_info "Notification sent."
