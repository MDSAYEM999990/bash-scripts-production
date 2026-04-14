#!/usr/bin/env bats
load "${BATS_TEST_DIRNAME}/../test_helper/bats-support/load"
load "${BATS_TEST_DIRNAME}/../test_helper/bats-assert/load"

setup() {
    export SCRIPT_PATH="${BATS_TEST_DIRNAME}/../../scripts/backup/db-backup.sh"
    export BINSTUB="${BATS_TEST_TMPDIR}/bin"
    mkdir -p "$BINSTUB"

    # Stub mysqldump
    cat > "${BINSTUB}/mysqldump" <<'EOF'
#!/bin/bash
echo "-- MySQL dump"
exit 0
EOF
    chmod +x "${BINSTUB}/mysqldump"

    # Stub pg_dump
    cat > "${BINSTUB}/pg_dump" <<'EOF'
#!/bin/bash
echo "-- PostgreSQL dump"
exit 0
EOF
    chmod +x "${BINSTUB}/pg_dump"

    # Stub gzip
    cat > "${BINSTUB}/gzip" <<'EOF'
#!/bin/bash
cat  # passthrough — just read stdin
exit 0
EOF
    chmod +x "${BINSTUB}/gzip"

    # Stub find (to avoid rotating real files)
    cat > "${BINSTUB}/find" <<'EOF'
#!/bin/bash
exit 0
EOF
    chmod +x "${BINSTUB}/find"

    export PATH="${BINSTUB}:${PATH}"
    export BACKUP_DIR="${BATS_TEST_TMPDIR}/backups"
    mkdir -p "$BACKUP_DIR"
}

@test "script exists and is executable" {
    [ -f "$SCRIPT_PATH" ]
    [ -x "$SCRIPT_PATH" ]
}

@test "--help exits 0 and prints usage" {
    run "$SCRIPT_PATH" --help
    assert_success
    assert_output --partial "Usage:"
}

@test "exits 1 without --type argument" {
    run "$SCRIPT_PATH" --database testdb
    assert_failure
    assert_output --partial "type"
}

@test "exits 1 without --database argument" {
    run "$SCRIPT_PATH" --type mysql
    assert_failure
    assert_output --partial "database"
}

@test "dry-run mysql shows action without running" {
    run "$SCRIPT_PATH" --type mysql --database mydb --output-dir "$BACKUP_DIR" --dry-run
    assert_success
    assert_output --partial "dry-run"
}

@test "dry-run postgres shows action without running" {
    run "$SCRIPT_PATH" --type postgres --database mydb --output-dir "$BACKUP_DIR" --dry-run
    assert_success
    assert_output --partial "dry-run"
}

@test "exits 1 for invalid --type" {
    run "$SCRIPT_PATH" --type sqlite --database mydb
    assert_failure
}

@test "set -euo pipefail is present" {
    grep -q 'set -euo pipefail' "$SCRIPT_PATH"
}
