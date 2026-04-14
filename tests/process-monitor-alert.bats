#\!/usr/bin/env bats
load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'

setup() {
    export SCRIPT_PATH="${BATS_TEST_DIRNAME}/../scripts/process-monitor-alert.sh"
    export BINSTUB="${BATS_TEST_TMPDIR}/bin"
    mkdir -p "$BINSTUB"

    # Stub pgrep to simulate process found
    cat > "${BINSTUB}/pgrep" << 'EOF'
#\!/bin/bash
echo "12345"
exit 0
EOF
    chmod +x "${BINSTUB}/pgrep"

    # Stub mail
    cat > "${BINSTUB}/mail" << 'EOF'
#\!/bin/bash
echo "mock-mail $*"
exit 0
EOF
    chmod +x "${BINSTUB}/mail"
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

@test "exits 1 without required --process argument" {
    run "$SCRIPT_PATH"
    assert_failure
}

@test "exits 0 when process is running" {
    run "$SCRIPT_PATH" --process nginx
    assert_success
}

@test "set -euo pipefail is present" {
    run grep "set -euo pipefail" "$SCRIPT_PATH"
    assert_success
}
