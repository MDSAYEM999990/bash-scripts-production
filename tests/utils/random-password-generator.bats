#\!/usr/bin/env bats
load "${BATS_TEST_DIRNAME}/../test_helper/bats-support/load"
load "${BATS_TEST_DIRNAME}/../test_helper/bats-assert/load"

setup() {
    export SCRIPT_PATH="${BATS_TEST_DIRNAME}/../../scripts/utils/random-password-generator.sh"
}

@test "script exists and is executable" {
    [ -f "$SCRIPT_PATH" ] && [ -x "$SCRIPT_PATH" ]
}

@test "--help exits 0 and prints usage" {
    run "$SCRIPT_PATH" --help
    assert_success
    assert_output --partial "Usage:"
}

@test "runs with no arguments and produces output" {
    run "$SCRIPT_PATH"
    assert_success
    [ "${#output}" -gt 0 ]
}

@test "--length sets password length" {
    run "$SCRIPT_PATH" --length 20
    assert_success
    # Isolate the password line (skip [INFO] log lines)
    local pw; pw=$(echo "$output" | grep -v '\[INFO\]' | head -1)
    [ "${#pw}" -eq 20 ]
}

@test "--count produces multiple passwords" {
    run "$SCRIPT_PATH" --count 3
    assert_success
    [ "$(echo "$output" | wc -l)" -ge 3 ]
}

@test "--no-symbols produces alphanumeric only" {
    run "$SCRIPT_PATH" --no-symbols --length 32
    assert_success
    # Isolate the password line and verify no symbols
    local pw; pw=$(echo "$output" | grep -v '\[INFO\]' | head -1)
    [[ "$pw" =~ ^[A-Za-z0-9]+$ ]]
}

@test "set -euo pipefail is present" {
    run grep "set -euo pipefail" "$SCRIPT_PATH"
    assert_success
}
