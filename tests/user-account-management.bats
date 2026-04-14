#!/usr/bin/env bats
load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'

setup() {
    export SCRIPT_PATH="${BATS_TEST_DIRNAME}/../scripts/user-account-management.sh"
    export BINSTUB="${BATS_TEST_TMPDIR}/bin"
    mkdir -p "$BINSTUB"

    for cmd in useradd groupadd getent chpasswd usermod; do
        cat > "${BINSTUB}/${cmd}" << EOF
#!/bin/bash
echo "mock-${cmd} \$*"
exit 0
EOF
        chmod +x "${BINSTUB}/${cmd}"
    done
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

@test "exits 1 without required --username argument" {
    run "$SCRIPT_PATH"
    assert_failure
}

@test "checks for root or sudo requirement" {
    run grep -E 'EUID|whoami|sudo' "$SCRIPT_PATH"
    assert_success
}

@test "uses check_dependency for required commands" {
    run grep "check_dependency" "$SCRIPT_PATH"
    assert_success
}

@test "set -euo pipefail is present" {
    run grep "set -euo pipefail" "$SCRIPT_PATH"
    assert_success
}
