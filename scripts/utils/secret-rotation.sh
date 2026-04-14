#!/bin/bash
# secret-rotation.sh — Rotate a secret in AWS Secrets Manager or HashiCorp Vault
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/utils.sh
source "${SCRIPT_DIR}/../lib/utils.sh"

BACKEND=""
SECRET_NAME=""
NEW_VALUE=""
VAULT_ADDR="${VAULT_ADDR:-http://127.0.0.1:8200}"
VAULT_TOKEN="${VAULT_TOKEN:-}"
AWS_REGION="${AWS_DEFAULT_REGION:-us-east-1}"
DRY_RUN=false
NOTIFY_WEBHOOK="${SECRET_NOTIFY_WEBHOOK:-}"

usage() {
    cat <<EOF
Usage: $(basename "$0") [options]

Rotate a secret value in AWS Secrets Manager or HashiCorp Vault.

Options:
  --backend BACKEND   Secret backend: aws or vault                  (required)
  --secret NAME       Secret name/path to update                    (required)
  --value VALUE       New secret value                              (env: NEW_SECRET_VALUE)
  --region REGION     AWS region                                    (env: AWS_DEFAULT_REGION, default: us-east-1)
  --vault-addr URL    Vault address                                 (env: VAULT_ADDR)
  --vault-token TOK   Vault token                                   (env: VAULT_TOKEN)
  --webhook URL       Slack webhook to notify on success            (env: SECRET_NOTIFY_WEBHOOK)
  --dry-run           Show what would change, make no changes
  -h, --help          Show this help message

Examples:
  $(basename "$0") --backend aws --secret prod/db_password --value 'NewP@ss!'
  $(basename "$0") --backend vault --secret secret/app/api_key --value 'abc123' --dry-run
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --backend)      BACKEND="$2";         shift 2 ;;
        --secret)       SECRET_NAME="$2";     shift 2 ;;
        --value)        NEW_VALUE="$2";       shift 2 ;;
        --region)       AWS_REGION="$2";      shift 2 ;;
        --vault-addr)   VAULT_ADDR="$2";      shift 2 ;;
        --vault-token)  VAULT_TOKEN="$2";     shift 2 ;;
        --webhook)      NOTIFY_WEBHOOK="$2";  shift 2 ;;
        --dry-run)      DRY_RUN=true;         shift ;;
        -h|--help)      usage; exit 0 ;;
        *) log_error "Unknown option: $1"; usage; exit 1 ;;
    esac
done

# Prefer env var for the new value to avoid shell history exposure
NEW_VALUE="${NEW_VALUE:-${NEW_SECRET_VALUE:-}}"

if [[ -z "$BACKEND" ]]; then
    log_error "A backend (--backend aws|vault) is required."
    usage
    exit 1
fi

if [[ -z "$SECRET_NAME" ]]; then
    log_error "A secret name (--secret) is required."
    usage
    exit 1
fi

if [[ -z "$NEW_VALUE" ]]; then
    log_error "A new secret value (--value or NEW_SECRET_VALUE env) is required."
    usage
    exit 1
fi

case "$BACKEND" in
    aws)
        check_dependency aws
        if [[ "$DRY_RUN" == "true" ]]; then
            log_info "[dry-run] Would update AWS Secrets Manager secret '${SECRET_NAME}' in region '${AWS_REGION}'."
            exit 0
        fi
        log_info "Rotating AWS Secrets Manager secret: ${SECRET_NAME}"
        aws secretsmanager put-secret-value \
            --region "$AWS_REGION" \
            --secret-id "$SECRET_NAME" \
            --secret-string "$NEW_VALUE" \
            --output text --query 'Name' || {
            log_error "Failed to rotate secret '${SECRET_NAME}'."
            exit 2
        }
        ;;
    vault)
        check_dependency vault
        if [[ "$DRY_RUN" == "true" ]]; then
            log_info "[dry-run] Would write Vault secret at path '${SECRET_NAME}'."
            exit 0
        fi
        export VAULT_ADDR VAULT_TOKEN
        log_info "Rotating Vault secret: ${SECRET_NAME}"
        vault kv put "$SECRET_NAME" value="$NEW_VALUE" || {
            log_error "Failed to rotate Vault secret '${SECRET_NAME}'."
            exit 2
        }
        ;;
    *)
        log_error "Invalid backend: '${BACKEND}'. Use 'aws' or 'vault'."
        exit 1
        ;;
esac

log_info "Secret '${SECRET_NAME}' rotated successfully."

if [[ -n "$NOTIFY_WEBHOOK" ]]; then
    PAYLOAD=$(jq -n \
        --arg name "$SECRET_NAME" \
        --arg host "$(hostname)" \
        '{text: ("*Secret Rotated* on `" + $host + "`: `" + $name + "`")}')
    curl -fsSL -X POST -H 'Content-type: application/json' \
        --data "$PAYLOAD" "$NOTIFY_WEBHOOK" 2>/dev/null \
        || log_warn "Could not send rotation notification."
fi

exit 0
