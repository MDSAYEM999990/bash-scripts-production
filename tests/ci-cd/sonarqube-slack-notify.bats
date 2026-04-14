#!/usr/bin/env bats
load "${BATS_TEST_DIRNAME}/../test_helper/bats-support/load"
load "${BATS_TEST_DIRNAME}/../test_helper/bats-assert/load"

setup() {
    export SCRIPT_PATH="${BATS_TEST_DIRNAME}/../../scripts/ci-cd/sonarqube-slack-notify.sh"
    export BINSTUB="${BATS_TEST_TMPDIR}/bin"
    mkdir -p "$BINSTUB"

    cat > "${BINSTUB}/sonar-scanner" << 'EOF'
#!/bin/bash
echo "mock-sonar-scanner $*"
exit 0
EOF
    chmod +x "${BINSTUB}/sonar-scanner"

    cat > "${BINSTUB}/curl" << 'EOF'
#!/bin/bash
# Return a passing quality gate response for API calls
if [[ "$*" == *"qualitygates"* ]]; then
    echo '{"projectStatus":{"status":"OK"}}'
else
    echo "mock-curl $*"
fi
exit 0
EOF
    chmod +x "${BINSTUB}/curl"

    if ! command -v jq &>/dev/null; then
        cat > "${BINSTUB}/jq" << 'EOF'
#!/bin/bash
echo "OK"
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

@test "exits 1 without required --project-key argument" {
    run "$SCRIPT_PATH"
    assert_failure
}

@test "uses sonar-scanner for analysis" {
    run grep "sonar-scanner" "$SCRIPT_PATH"
    assert_success
}

@test "set -euo pipefail is present" {
    run grep "set -euo pipefail" "$SCRIPT_PATH"
    assert_success
}
