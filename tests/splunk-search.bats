#!/usr/bin/env bats
load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'

setup() {
    export SCRIPT_PATH="${BATS_TEST_DIRNAME}/../scripts/splunk-search.sh"
    export BINSTUB="${BATS_TEST_TMPDIR}/bin"
    mkdir -p "$BINSTUB"

    CALL_COUNT=0
    cat > "${BINSTUB}/curl" << 'EOF'
#!/bin/bash
# First call: create SID; subsequent calls: job status/results
if [[ "$*" == *"/search/jobs"* ]] && [[ "$*" != *"/search/jobs/"* ]]; then
    echo '{"sid":"12345"}'
elif [[ "$*" == *"/search/jobs/12345"* ]] && [[ "$*" != *"results"* ]]; then
    echo '{"entry":[{"content":{"dispatchState":"DONE"}}]}'
elif [[ "$*" == *"results"* ]]; then
    echo '{"results":[{"_raw":"test event"}]}'
else
    echo "mock-curl $*"
fi
exit 0
EOF
    chmod +x "${BINSTUB}/curl"

    if ! command -v jq &>/dev/null; then
        cat > "${BINSTUB}/jq" << 'EOF'
#!/bin/bash
echo "12345"
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

@test "exits 1 without required --query argument" {
    run "$SCRIPT_PATH"
    assert_failure
}

@test "exits 1 without required --host argument" {
    run "$SCRIPT_PATH" --query "index=main"
    assert_failure
}

@test "set -euo pipefail is present" {
    run grep "set -euo pipefail" "$SCRIPT_PATH"
    assert_success
}
