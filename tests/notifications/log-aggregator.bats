#!/usr/bin/env bats
load "${BATS_TEST_DIRNAME}/../test_helper/bats-support/load"
load "${BATS_TEST_DIRNAME}/../test_helper/bats-assert/load"

setup() {
    export SCRIPT_PATH="${BATS_TEST_DIRNAME}/../../scripts/notifications/log-aggregator.sh"

    # Create a couple of real temp log files
    export LOG1="${BATS_TEST_TMPDIR}/app.log"
    export LOG2="${BATS_TEST_TMPDIR}/error.log"
    echo "first line app" >  "$LOG1"
    echo "second line app" >> "$LOG1"
    echo "first error"    >  "$LOG2"

    export OUT_FILE="${BATS_TEST_TMPDIR}/aggregated.log"
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

@test "exits 1 without --output argument" {
    run "$SCRIPT_PATH" "$LOG1"
    assert_failure
    assert_output --partial "output"
}

@test "exits 1 when no source files given" {
    run "$SCRIPT_PATH" --output "$OUT_FILE"
    assert_failure
}

@test "aggregates two log files into output" {
    run "$SCRIPT_PATH" --output "$OUT_FILE" "$LOG1" "$LOG2"
    assert_success
    [ -f "$OUT_FILE" ]
    grep -q "app.log" "$OUT_FILE"
    grep -q "error.log" "$OUT_FILE"
}

@test "output lines contain timestamp prefix" {
    run "$SCRIPT_PATH" --output "$OUT_FILE" "$LOG1"
    assert_success
    grep -qE '^\[.+T.+Z\]' "$OUT_FILE"
}

@test "set -euo pipefail is present" {
    grep -q 'set -euo pipefail' "$SCRIPT_PATH"
}
