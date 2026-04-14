#!/usr/bin/env bats
load "${BATS_TEST_DIRNAME}/../test_helper/bats-support/load"
load "${BATS_TEST_DIRNAME}/../test_helper/bats-assert/load"

setup() {
    export SCRIPT_PATH="${BATS_TEST_DIRNAME}/../../scripts/notifications/log-monitor.sh"
    export LOG_FILE="${BATS_TEST_TMPDIR}/monitor.log"
    printf "INFO  normal line\nERROR critical failure here\nINFO  another normal\n" > "$LOG_FILE"
}

teardown() {
    rm -f "$LOG_FILE"
}

@test "script exists and is executable" {
    [ -f "$SCRIPT_PATH" ] && [ -x "$SCRIPT_PATH" ]
}

@test "--help exits 0 and prints usage" {
    run "$SCRIPT_PATH" --help
    assert_success
    assert_output --partial "Usage:"
}

@test "exits 1 without required --log argument" {
    run "$SCRIPT_PATH"
    assert_failure
}

@test "--static mode scans existing content and exits" {
    run "$SCRIPT_PATH" "$LOG_FILE" "ERROR" --static
    assert_success
    assert_output --partial "ERROR"
}

@test "set -euo pipefail is present" {
    run grep "set -euo pipefail" "$SCRIPT_PATH"
    assert_success
}

@test "sources utils.sh" {
    run grep "source.*lib/utils.sh" "$SCRIPT_PATH"
    assert_success
}
