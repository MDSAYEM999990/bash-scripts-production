#!/usr/bin/env bats
# Tests for grafana-metrics.sh

load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'

setup() {
    export SCRIPT_PATH="${BATS_TEST_DIRNAME}/../scripts/grafana-metrics.sh"
    export BINSTUB="${BATS_TEST_TMPDIR}/bin"
    mkdir -p "$BINSTUB"

    cat > "${BINSTUB}/curl" << 'EOF'
#!/bin/bash
echo "mock-curl $*"
exit 0
EOF
    chmod +x "${BINSTUB}/curl"

    if command -v jq &>/dev/null; then
        true  # use real jq
    else
        cat > "${BINSTUB}/jq" << 'EOF'
#!/bin/bash
echo '{}'
exit 0
EOF
        chmod +x "${BINSTUB}/jq"
    fi
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

@test "exits 1 without required --host argument" {
    run "$SCRIPT_PATH"
    assert_failure
}

@test "uses jq to build metric payload" {
    run grep "jq" "$SCRIPT_PATH"
    assert_success
}

@test "set -euo pipefail is present" {
    run grep "set -euo pipefail" "$SCRIPT_PATH"
    assert_success
}
