#!/usr/bin/env bats
load "${BATS_TEST_DIRNAME}/../test_helper/bats-support/load"
load "${BATS_TEST_DIRNAME}/../test_helper/bats-assert/load"

setup() {
    export SCRIPT_PATH="${BATS_TEST_DIRNAME}/../../scripts/monitoring/http-status.sh"
    export BINSTUB="${BATS_TEST_TMPDIR}/bin"
    mkdir -p "$BINSTUB"

    cat > "${BINSTUB}/curl" << 'EOF'
#!/bin/bash
echo "200"
exit 0
EOF
    chmod +x "${BINSTUB}/curl"
    export PATH="${BINSTUB}:$PATH"
}

@test "script exists and is executable" {
    [ -f "$SCRIPT_PATH" ] && [ -x "$SCRIPT_PATH" ]
}

@test "--help exits 0 and prints usage" {
    run "$SCRIPT_PATH" --help
    assert_success
    assert_output --partial "Usage:"
}

@test "exits 1 without required --url argument" {
    run "$SCRIPT_PATH"
    assert_failure
}

@test "uses curl --write-out for numeric status code" {
    run grep 'write-out\|write_out' "$SCRIPT_PATH"
    assert_success
}

@test "set -euo pipefail is present" {
    run grep "set -euo pipefail" "$SCRIPT_PATH"
    assert_success
}
