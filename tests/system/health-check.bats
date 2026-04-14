#!/usr/bin/env bats
# Tests for health-check.sh

load "${BATS_TEST_DIRNAME}/../test_helper/bats-support/load"
load "${BATS_TEST_DIRNAME}/../test_helper/bats-assert/load"

setup() {
    export SCRIPT_PATH="${BATS_TEST_DIRNAME}/../../scripts/system/health-check.sh"
    export BINSTUB="${BATS_TEST_TMPDIR}/bin"
    mkdir -p "$BINSTUB"

    # Stub systemctl — always report service as active
    cat > "${BINSTUB}/systemctl" << 'EOF'
#!/bin/bash
if [[ "$1" == "is-active" ]]; then
    echo "active"
    exit 0
fi
echo "mock-systemctl $*"
exit 0
EOF
    chmod +x "${BINSTUB}/systemctl"
    export PATH="${BINSTUB}:$PATH"
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

@test "runs with default services when none specified" {
    run "$SCRIPT_PATH"
    assert_success
}

@test "reports active when stub returns active" {
    run "$SCRIPT_PATH" --service nginx
    assert_success
    assert_output --partial "active"
}

@test "set -euo pipefail is present" {
    run grep "set -euo pipefail" "$SCRIPT_PATH"
    assert_success
}
