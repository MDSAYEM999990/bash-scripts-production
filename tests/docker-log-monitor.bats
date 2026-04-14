#!/usr/bin/env bats
# Tests for docker-log-monitor.sh

load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'

setup() {
    export SCRIPT_PATH="${BATS_TEST_DIRNAME}/../scripts/docker-log-monitor.sh"
    export BINSTUB="${BATS_TEST_TMPDIR}/bin"
    mkdir -p "$BINSTUB"

    # Stub docker
    cat > "${BINSTUB}/docker" << 'EOF'
#!/bin/bash
if [[ "$1" == "ps" ]]; then
    echo "abc1234567 web"
elif [[ "$2" == "logs" ]]; then
    echo "2024-01-01T00:00:00Z ERROR test error message"
fi
exit 0
EOF
    chmod +x "${BINSTUB}/docker"
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

@test "runs successfully with default container and pattern" {
    run "$SCRIPT_PATH"
    assert_success
    assert_output --partial "Monitoring container"
}

@test "set -euo pipefail is present" {
    run grep "set -euo pipefail" "$SCRIPT_PATH"
    assert_success
}

@test "sources utils.sh" {
    run grep "source.*lib/utils.sh" "$SCRIPT_PATH"
    assert_success
}
