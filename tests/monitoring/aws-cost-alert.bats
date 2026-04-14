#!/usr/bin/env bats
load "${BATS_TEST_DIRNAME}/../test_helper/bats-support/load"
load "${BATS_TEST_DIRNAME}/../test_helper/bats-assert/load"

setup() {
    export SCRIPT_PATH="${BATS_TEST_DIRNAME}/../../scripts/monitoring/aws-cost-alert.sh"
    export BINSTUB="${BATS_TEST_TMPDIR}/bin"
    mkdir -p "$BINSTUB"

    # Stub aws CLI
    cat > "${BINSTUB}/aws" <<'STUB'
#!/bin/bash
echo '{"ResultsByTime":[{"Total":{"BlendedCost":{"Amount":"42.50","Unit":"USD"}}}]}'
exit 0
STUB
    chmod +x "${BINSTUB}/aws"

    # Stub jq
    cat > "${BINSTUB}/jq" <<'STUB'
#!/bin/bash
# Return a realistic cost amount
echo "42.50"
exit 0
STUB
    chmod +x "${BINSTUB}/jq"

    # Stub curl
    cat > "${BINSTUB}/curl" <<'STUB'
#!/bin/bash
echo "curl $*"
exit 0
STUB
    chmod +x "${BINSTUB}/curl"

    export PATH="${BINSTUB}:${PATH}"
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

@test "exits 1 without --threshold argument" {
    run "$SCRIPT_PATH"
    assert_failure
    assert_output --partial "threshold"
}

@test "dry-run suppresses Slack post when over threshold" {
    # jq stub returns 42.50; threshold 1 ensures the alert path is entered
    run "$SCRIPT_PATH" --threshold 1 --dry-run
    assert_success
    assert_output --partial "dry-run"
}

@test "exits 0 when cost is below threshold" {
    # jq stub returns 42.50; threshold 100
    run "$SCRIPT_PATH" --threshold 100
    assert_success
}

@test "sends alert when cost exceeds threshold" {
    # threshold 10 < 42.50
    run "$SCRIPT_PATH" --threshold 10 --webhook "https://hooks.slack.com/fake"
    assert_success
    assert_output --partial "curl"
}

@test "set -euo pipefail is present" {
    grep -q 'set -euo pipefail' "$SCRIPT_PATH"
}
