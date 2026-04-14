#!/usr/bin/env bats
load "${BATS_TEST_DIRNAME}/../test_helper/bats-support/load"
load "${BATS_TEST_DIRNAME}/../test_helper/bats-assert/load"

setup() {
    export SCRIPT_PATH="${BATS_TEST_DIRNAME}/../../scripts/notifications/slack-notify.sh"
    export BINSTUB="${BATS_TEST_TMPDIR}/bin"
    mkdir -p "$BINSTUB"

    cat > "${BINSTUB}/curl" << 'EOF'
#!/bin/bash
echo "mock-curl $*"
exit 0
EOF
    chmod +x "${BINSTUB}/curl"

    # Use real jq if available; else stub
    if ! command -v jq &>/dev/null; then
        cat > "${BINSTUB}/jq" << 'EOF'
#!/bin/bash
echo '{"text":"test"}'
exit 0
EOF
        chmod +x "${BINSTUB}/jq"
    fi
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

@test "exits 1 without required --webhook argument" {
    run "$SCRIPT_PATH"
    assert_failure
}

@test "exits 1 without required --message argument" {
    run "$SCRIPT_PATH" --webhook "https://hooks.slack.com/test"
    assert_failure
}

@test "uses jq -n to build safe JSON payload" {
    run grep "jq -n\|jq -rn" "$SCRIPT_PATH"
    assert_success
}

@test "calls curl with webhook url" {
    run "$SCRIPT_PATH" --webhook "https://hooks.slack.com/test" --message "hello"
    assert_success
    assert_output --partial "mock-curl"
}

@test "set -euo pipefail is present" {
    run grep "set -euo pipefail" "$SCRIPT_PATH"
    assert_success
}
