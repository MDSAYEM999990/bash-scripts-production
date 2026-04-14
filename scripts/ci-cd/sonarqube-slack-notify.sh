#!/bin/bash
# sonarqube-slack-notify.sh — Run a SonarQube scan and post quality gate results to Slack.
# Usage: ./sonarqube-slack-notify.sh [options]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/utils.sh"

SONAR_HOST="${SONAR_HOST:-}"
SONAR_TOKEN="${SONAR_TOKEN:-}"
PROJECT_KEY="${PROJECT_KEY:-}"
SLACK_WEBHOOK="${SLACK_WEBHOOK_URL:-}"
SOURCE_DIR="${SOURCE_DIR:-.}"

usage() {
    cat <<EOF
Usage: $(basename "$0") [options]

Run sonar-scanner against the project, fetch the quality gate status, and post
a pass/fail summary to Slack.

Options:
  --host        URL     SonarQube server URL          (env: SONAR_HOST)
  --token       TOKEN   SonarQube authentication token (env: SONAR_TOKEN)
  --project     KEY     SonarQube project key         (env: PROJECT_KEY)
  --webhook     URL     Slack Incoming Webhook URL    (env: SLACK_WEBHOOK_URL)
  --source-dir  PATH    Directory to analyze          (default: .)
  -h, --help            Show this help message

Examples:
  $(basename "$0") --host http://sonar.example.com --token mytoken --project my-project --webhook https://hooks.slack.com/...
EOF
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --host)       SONAR_HOST="$2";    shift 2 ;;
        --token)      SONAR_TOKEN="$2";   shift 2 ;;
        --project)    PROJECT_KEY="$2";   shift 2 ;;
        --webhook)    SLACK_WEBHOOK="$2"; shift 2 ;;
        --source-dir) SOURCE_DIR="$2";    shift 2 ;;
        -h|--help)    usage ;;
        *) log_error "Unknown option: $1"; usage ;;
    esac
done

check_dependency sonar-scanner
check_dependency curl
check_dependency jq

for var in SONAR_HOST SONAR_TOKEN PROJECT_KEY SLACK_WEBHOOK; do
    if [[ -z "${!var}" ]]; then
        log_error "Missing required value for ${var}."
        exit 1
    fi
done

log_info "Running SonarQube scan for project '${PROJECT_KEY}'..."
sonar-scanner \
    -Dsonar.host.url="$SONAR_HOST" \
    -Dsonar.login="$SONAR_TOKEN" \
    -Dsonar.projectKey="$PROJECT_KEY" \
    -Dsonar.sources="$SOURCE_DIR"

log_info "Fetching quality gate status..."
GATE_RESPONSE=$(curl --silent --fail --show-error \
    -u "${SONAR_TOKEN}:" \
    "${SONAR_HOST}/api/qualitygates/project_status?projectKey=${PROJECT_KEY}")

STATUS=$(echo "$GATE_RESPONSE" | jq -r '.projectStatus.status')
ISSUES=$(echo "$GATE_RESPONSE" | jq -r '[.projectStatus.conditions[] | select(.status=="ERROR") | .metricKey] | join(", ")' 2>/dev/null || echo "unknown")

if [[ "$STATUS" == "OK" ]]; then
    ICON=":white_check_mark:"
    MESSAGE="SonarQube gate *PASSED* for \`${PROJECT_KEY}\`."
else
    ICON=":x:"
    MESSAGE="SonarQube gate *FAILED* for \`${PROJECT_KEY}\`. Failing metrics: ${ISSUES}"
fi

PAYLOAD=$(jq -n \
    --arg text "${ICON} ${MESSAGE}" \
    --arg username "SonarQube Bot" \
    '{text: $text, username: $username, icon_emoji: ":sonarqube:"}')

log_info "Posting result to Slack (status: ${STATUS})..."
curl --silent --fail --show-error \
    -X POST -H "Content-Type: application/json" \
    --data "$PAYLOAD" \
    "$SLACK_WEBHOOK"
log_info "Done."
