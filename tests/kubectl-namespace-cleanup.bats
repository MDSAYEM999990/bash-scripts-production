#!/usr/bin/env bats
load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'

setup() {
    export SCRIPT_PATH="${BATS_TEST_DIRNAME}/../scripts/kubectl-namespace-cleanup.sh"
    export BINSTUB="${BATS_TEST_TMPDIR}/bin"
    mkdir -p "$BINSTUB"

    # Default stub: no terminating namespaces (empty jsonpath output = early exit)
    cat > "${BINSTUB}/kubectl" << 'EOF'
#!/bin/bash
if [[ "$1" == "get" && "$2" == "namespaces" ]]; then
    echo -n ""  # empty: no stuck namespaces
    exit 0
fi
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

@test "exits 0 when no namespaces are stuck in Terminating phase" {
    run "$SCRIPT_PATH"
    assert_success
    assert_output --partial "No namespaces"
}

@test "--dry-run flag is supported" {
    run grep '\-\-dry-run' "$SCRIPT_PATH"
    assert_success
}

@test "set -euo pipefail is present" {
    run grep "set -euo pipefail" "$SCRIPT_PATH"
    assert_success
}
