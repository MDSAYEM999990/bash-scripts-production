#!/usr/bin/env bats
# Tests for account-expiry-notify.sh

load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'

setup() {
    export SCRIPT_PATH="${BATS_TEST_DIRNAME}/../scripts/account-expiry-notify.sh"
    export BINSTUB="${BATS_TEST_TMPDIR}/bin"
    mkdir -p "$BINSTUB"

    # Stub mail so no real email is sent
    cat > "${BINSTUB}/mail" << 'EOF'
#!/bin/bash
echo "mock-mail $*"
exit 0
EOF
    chmod +x "${BINSTUB}/mail"
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

@test "exits 1 without required --email argument" {
    run "$SCRIPT_PATH"
    assert_failure
}

@test "exits 1 when --email is missing with --threshold set" {
    run "$SCRIPT_PATH" --threshold 30
    assert_failure
}

@test "set -euo pipefail is present" {
    run grep "set -euo pipefail" "$SCRIPT_PATH"
    assert_success
}

@test "sources utils.sh" {
    run grep "source.*lib/utils.sh" "$SCRIPT_PATH"
    assert_success
}
