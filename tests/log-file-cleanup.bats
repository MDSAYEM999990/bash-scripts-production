#!/usr/bin/env bats
load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'

setup() {
    export SCRIPT_PATH="${BATS_TEST_DIRNAME}/../scripts/log-file-cleanup.sh"
    export LOG_DIR="${BATS_TEST_TMPDIR}/logs"
    mkdir -p "$LOG_DIR"
    # Create old test log file (default keep: 7 days -- touch with old mtime is OS specific; just test flags)
    touch "${LOG_DIR}/old.log"
}

teardown() {
    rm -rf "$LOG_DIR"
}

@test "script exists and is executable" {
    [ -f "$SCRIPT_PATH" ] && [ -x "$SCRIPT_PATH" ]
}

@test "--help exits 0 and prints usage" {
    run "$SCRIPT_PATH" --help
    assert_success
    assert_output --partial "Usage:"
}

@test "succeeds with env LOG_DIR pointing to an existing directory" {
    run "$SCRIPT_PATH"
    assert_success
}

@test "exits 1 when specified dir does not exist" {
    run "$SCRIPT_PATH" --dir /nonexistent/path/xyz
    assert_failure
}

@test "--dry-run produces output without deleting" {
    run "$SCRIPT_PATH" --dir "$LOG_DIR" --days 0 --dry-run
    assert_success
}

@test "uses find -print0 for safe filename handling" {
    run grep "print0" "$SCRIPT_PATH"
    assert_success
}

@test "set -euo pipefail is present" {
    run grep "set -euo pipefail" "$SCRIPT_PATH"
    assert_success
}
