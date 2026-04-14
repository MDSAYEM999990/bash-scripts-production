#!/usr/bin/env bats
load "${BATS_TEST_DIRNAME}/../test_helper/bats-support/load"
load "${BATS_TEST_DIRNAME}/../test_helper/bats-assert/load"

setup() {
    export SCRIPT_PATH="${BATS_TEST_DIRNAME}/../../scripts/system/system-resource-reporter.sh"
    export REPORT_FILE="${BATS_TEST_TMPDIR}/report.txt"
}

teardown() {
    rm -f "$REPORT_FILE"
}

@test "script exists and is executable" {
    [ -f "$SCRIPT_PATH" ] && [ -x "$SCRIPT_PATH" ]
}

@test "--help exits 0 and prints usage" {
    run "$SCRIPT_PATH" --help
    assert_success
    assert_output --partial "Usage:"
}

@test "does not define inline color constants" {
    # All colors come from utils.sh; script should not redefine RED/GREEN/YELLOW
    run grep '^RED=\|^GREEN=\|^YELLOW=\|^BLUE=' "$SCRIPT_PATH"
    assert_failure
}

@test "set -euo pipefail is present" {
    run grep "set -euo pipefail" "$SCRIPT_PATH"
    assert_success
}

@test "sources utils.sh" {
    run grep "source.*lib/utils.sh" "$SCRIPT_PATH"
    assert_success
}
