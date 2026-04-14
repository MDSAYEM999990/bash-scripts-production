#!/usr/bin/env bats
load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'

setup() {
    export SCRIPT_PATH="${BATS_TEST_DIRNAME}/../scripts/scale-deployment.sh"
    export BINSTUB="${BATS_TEST_TMPDIR}/bin"
    mkdir -p "$BINSTUB"

    cat > "${BINSTUB}/kubectl" << 'EOF'
#!/bin/bash
echo "mock-kubectl $*"
exit 0
EOF
    chmod +x "${BINSTUB}/kubectl"
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

@test "exits 1 without required --deployment argument" {
    run "$SCRIPT_PATH"
    assert_failure
}

@test "exits 1 without required --replicas argument" {
    run "$SCRIPT_PATH" --deployment myapp
    assert_failure
}

@test "calls kubectl scale with correct arguments" {
    run "$SCRIPT_PATH" --deployment myapp --replicas 3
    assert_success
    assert_output --partial "mock-kubectl"
    assert_output --partial "scale"
}

@test "set -euo pipefail is present" {
    run grep "set -euo pipefail" "$SCRIPT_PATH"
    assert_success
}
