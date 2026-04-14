#!/usr/bin/env bats
# Tests for create-confluence-page.sh

load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'

setup() {
    export SCRIPT_PATH="${BATS_TEST_DIRNAME}/../scripts/create-confluence-page.sh"
    export BINSTUB="${BATS_TEST_TMPDIR}/bin"
    mkdir -p "$BINSTUB"

    # Stub curl: return a fake page ID response
    cat > "${BINSTUB}/curl" << 'EOF'
#!/bin/bash
echo '{"id":"12345","title":"Test Page"}'
exit 0
EOF
    chmod +x "${BINSTUB}/curl"

    # Stub jq with real jq or a passthrough
    if ! command -v jq &>/dev/null; then
        cat > "${BINSTUB}/jq" << 'EOF'
#!/bin/bash
echo '{"type":"page","title":"Test","body":{"storage":{"value":"content"}}}'
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

@test "exits 1 without required --space argument" {
    run "$SCRIPT_PATH"
    assert_failure
}

@test "exits 1 when only --space is given (missing --title)" {
    run "$SCRIPT_PATH" --space MYSPACE
    assert_failure
}

@test "uses jq to build safe JSON payload" {
    run grep "jq -n" "$SCRIPT_PATH"
    assert_success
}

@test "set -euo pipefail is present" {
    run grep "set -euo pipefail" "$SCRIPT_PATH"
    assert_success
}
