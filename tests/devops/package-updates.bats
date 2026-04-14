#\!/usr/bin/env bats
load "${BATS_TEST_DIRNAME}/../test_helper/bats-support/load"
load "${BATS_TEST_DIRNAME}/../test_helper/bats-assert/load"

setup() {
    export SCRIPT_PATH="${BATS_TEST_DIRNAME}/../../scripts/devops/package-updates.sh"
    export BINSTUB="${BATS_TEST_TMPDIR}/bin"
    mkdir -p "$BINSTUB"

    # Stub apt to simulate Ubuntu environment
    cat > "${BINSTUB}/apt" << 'EOF'
#\!/bin/bash
echo "mock-apt $*"
exit 0
EOF
    chmod +x "${BINSTUB}/apt"
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

@test "does not use dollar-question-mark anti-pattern" {
    run grep '\$?' "$SCRIPT_PATH"
    assert_failure
}

@test "set -euo pipefail is present" {
    run grep "set -euo pipefail" "$SCRIPT_PATH"
    assert_success
}
