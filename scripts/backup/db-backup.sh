#!/bin/bash
# db-backup.sh — Dump a MySQL or PostgreSQL database and rotate old backups
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/utils.sh
source "${SCRIPT_DIR}/../lib/utils.sh"

DB_TYPE=""
DB_HOST="localhost"
DB_PORT=""
DB_NAME=""
DB_USER=""
DB_PASS=""
OUTPUT_DIR="./db-backups"
KEEP_DAYS=7
DRY_RUN=false

usage() {
    cat <<EOF
Usage: $(basename "$0") [options]

Dump a MySQL or PostgreSQL database to a compressed file and rotate backups
older than --keep-days days.

Options:
  --type TYPE         Database type: mysql or postgres           (required)
  --host HOST         Database host                              (default: localhost)
  --port PORT         Database port                              (default: 3306/5432)
  --database NAME     Database name to dump                      (required)
  --user USER         Database username                          (env: DB_USER)
  --password PASS     Database password                          (env: DB_PASS)
  --output-dir DIR    Directory for backup files                 (default: ./db-backups)
  --keep-days N       Rotate backups older than N days           (default: 7)
  --dry-run           Show what would happen, make no changes
  -h, --help          Show this help message

Examples:
  $(basename "$0") --type mysql --database myapp --user root
  $(basename "$0") --type postgres --host db.example.com --database prod --user admin
  $(basename "$0") --type mysql --database myapp --keep-days 14 --dry-run
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --type)        DB_TYPE="$2";      shift 2 ;;
        --host)        DB_HOST="$2";      shift 2 ;;
        --port)        DB_PORT="$2";      shift 2 ;;
        --database)    DB_NAME="$2";      shift 2 ;;
        --user)        DB_USER="$2";      shift 2 ;;
        --password)    DB_PASS="$2";      shift 2 ;;
        --output-dir)  OUTPUT_DIR="$2";   shift 2 ;;
        --keep-days)   KEEP_DAYS="$2";    shift 2 ;;
        --dry-run)     DRY_RUN=true;      shift ;;
        -h|--help)     usage; exit 0 ;;
        *) log_error "Unknown option: $1"; usage; exit 1 ;;
    esac
done

# Fall back to environment variables
DB_USER="${DB_USER:-${DB_USER:-}}"
DB_PASS="${DB_PASS:-${DB_PASS:-}}"

if [[ -z "$DB_TYPE" ]]; then
    log_error "A database type (--type mysql|postgres) is required."
    usage
    exit 1
fi

if [[ "$DB_TYPE" != "mysql" && "$DB_TYPE" != "postgres" ]]; then
    log_error "Invalid --type '${DB_TYPE}'. Must be 'mysql' or 'postgres'."
    exit 1
fi

if [[ -z "$DB_NAME" ]]; then
    log_error "A database name (--database) is required."
    usage
    exit 1
fi

TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
OUTFILE="${OUTPUT_DIR}/${DB_NAME}_${TIMESTAMP}.sql.gz"

if [[ "$DRY_RUN" == "true" ]]; then
    log_info "[dry-run] Would dump ${DB_TYPE} database '${DB_NAME}' → ${OUTFILE}"
    log_info "[dry-run] Would rotate backups older than ${KEEP_DAYS} days in '${OUTPUT_DIR}'."
    exit 0
fi

mkdir -p "$OUTPUT_DIR"

case "$DB_TYPE" in
    mysql)
        check_dependency mysqldump
        [[ -z "$DB_PORT" ]] && DB_PORT="3306"
        DUMP_CMD=(mysqldump -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER")
        [[ -n "$DB_PASS" ]] && DUMP_CMD+=(-p"${DB_PASS}")
        DUMP_CMD+=("$DB_NAME")
        log_info "Dumping MySQL database '${DB_NAME}'..."
        "${DUMP_CMD[@]}" | gzip > "$OUTFILE"
        ;;
    postgres)
        check_dependency pg_dump
        [[ -z "$DB_PORT" ]] && DB_PORT="5432"
        export PGPASSWORD="${DB_PASS}"
        log_info "Dumping PostgreSQL database '${DB_NAME}'..."
        pg_dump -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" "$DB_NAME" | gzip > "$OUTFILE"
        unset PGPASSWORD
        ;;
esac

log_info "Backup written to: ${OUTFILE}"

# Rotate
log_info "Rotating backups older than ${KEEP_DAYS} day(s)..."
find "$OUTPUT_DIR" -name "${DB_NAME}_*.sql.gz" -mtime +"${KEEP_DAYS}" -print -delete || true

log_info "Database backup complete."
exit 0
