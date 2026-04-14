#!/usr/bin/env bats
load "${BATS_TEST_DIRNAME}/../test_helper/bats-support/load"
load "${BATS_TEST_DIRNAME}/../test_helper/bats-assert/load"

setup() {
    export SCRIPT_PATH="${BATS_TEST_DIRNAME}/../../scripts/backup/log-rotation.sh"
    export LOG_FILE="${BATS_TEST_TMPDIR}/test.log"
    # Create a log file with known content
    printf '%0.s X' {1..100} > "$LOG_FILE"
}

teardown() {
    rm -f "${BATS_TEST_TMPDIR}/test.log"*
}

@test "script exists and is executable" {
    [ -f "$SCRIPT_PATH" ] && [ -x "$SCRIPT_PATH" ]
}

@test "--help exits 0 and prints usage" {
    run "$SCRIPT_PATH" --help
    assert_success
    assert_output --partial "Usage:"
}

@test "runs successfully with env LOG_FILE set (no rotation needed)" {
    run "$SCRIPT_PATH"
    assert_success
    assert_output --partial "no rotation needed"
}

@test "exits 1 when log file does not exist" {
    run "$SCRIPT_PATH" --file /nonexistent/file.log
    assert_failure
}

@test "rotates log file — creates compressed archive" {
    # --max-mb 0 forces rotation on any file size
    run "$SCRIPT_PATH" --file "$LOG_FILE" --max-mb 0
    assert_success
    local archived; archived=$(find "${BATS_TEST_TMPDIR}" -name "*.gz" 2>/dev/null | head -1)
    [ -n "$archived" ]
}

@test "set -euo pipefail is present" {
    run grep "set -euo pipefail" "$SCRIPT_PATH"
    assert_success
}
