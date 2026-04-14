#!/bin/bash
# create-confluence-page.sh — Create or verify a Confluence wiki page via the REST API.
# Usage: ./create-confluence-page.sh [options]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/utils.sh"

CONFLUENCE_URL="${CONFLUENCE_URL:-https://confluence.example.com}"
CONFLUENCE_USER="${CONFLUENCE_USER:-user@example.com}"
CONFLUENCE_API_TOKEN="${CONFLUENCE_API_TOKEN:-}"
SPACE_KEY="${SPACE_KEY:-DEVOPS}"
PAGE_TITLE="${PAGE_TITLE:-Deployment Report $(date +%Y-%m-%d)}"
PAGE_CONTENT="${PAGE_CONTENT:-<h1>Deployment Summary</h1><p>All systems are operational.</p>}"

usage() {
    cat <<EOF
Usage: $(basename "$0") [options]

Create a page in Confluence using the REST API.

Options:
  --url     URL    Confluence base URL       (env: CONFLUENCE_URL)
  --user    EMAIL  Confluence username/email (env: CONFLUENCE_USER)
  --token   TOKEN  Confluence API token      (env: CONFLUENCE_API_TOKEN)
  --space   KEY    Space key                 (env: SPACE_KEY,   default: ${SPACE_KEY})
  --title   TITLE  Page title                (env: PAGE_TITLE)
  --content HTML   Page body HTML            (env: PAGE_CONTENT)
  -h, --help       Show this help message

Examples:
  CONFLUENCE_API_TOKEN=mytoken $(basename "$0") --space ENG --title "Release Notes"
EOF
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --url)     CONFLUENCE_URL="$2";       shift 2 ;;
        --user)    CONFLUENCE_USER="$2";      shift 2 ;;
        --token)   CONFLUENCE_API_TOKEN="$2"; shift 2 ;;
        --space)   SPACE_KEY="$2";            shift 2 ;;
        --title)   PAGE_TITLE="$2";           shift 2 ;;
        --content) PAGE_CONTENT="$2";         shift 2 ;;
        -h|--help) usage ;;
        *) log_error "Unknown option: $1"; usage ;;
    esac
done

check_dependency curl
check_dependency jq

if [[ -z "$CONFLUENCE_API_TOKEN" ]]; then
    log_error "CONFLUENCE_API_TOKEN must be set via --token or the environment variable."
    exit 1
fi

PAYLOAD=$(jq -n \
    --arg type    "page" \
    --arg title   "$PAGE_TITLE" \
    --arg spaceKey "$SPACE_KEY" \
    --arg value   "$PAGE_CONTENT" \
    '{type: $type, title: $title, space: {key: $spaceKey},
      body: {storage: {value: $value, representation: "storage"}}}')

log_info "Creating Confluence page '${PAGE_TITLE}' in space '${SPACE_KEY}'..."

RESPONSE=$(curl --fail --silent --show-error \
    -X POST "${CONFLUENCE_URL}/rest/api/content" \
    -u "${CONFLUENCE_USER}:${CONFLUENCE_API_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "$PAYLOAD")

PAGE_ID=$(echo "$RESPONSE" | jq -r '.id')
log_info "Page created successfully (ID: ${PAGE_ID})."
