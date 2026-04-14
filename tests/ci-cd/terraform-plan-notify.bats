#!/usr/bin/env bats
load "${BATS_TEST_DIRNAME}/../test_helper/bats-support/load"
load "${BATS_TEST_DIRNAME}/../test_helper/bats-assert/load"

setup() {
    export SCRIPT_PATH="${BATS_TEST_DIRNAME}/../../scripts/ci-cd/terraform-plan-notify.sh"
    export BINSTUB="${BATS_TEST_TMPDIR}/bin"
    mkdir -p "$BINSTUB"
    export TF_DIR="${BATS_TEST_TMPDIR}/tf"
    mkdir -p "$TF_DIR"

    # Stub terraform
    cat > "${BINSTUB}/terraform" <<'STUB'
#!/bin/bash
if [[ "$1" == "init" ]]; then echo "Terraform initialized."; exit 0; fi
if [[ "$1" == "workspace" ]]; then exit 0; fi
if [[ "$1" == "plan" ]]; then
    echo "Plan: 2 to add, 1 to change, 0 to destroy."
    exit 0
fi
exit 0
STUB
    chmod +x "${BINSTUB}/terraform"

    # Stub curl (webhook call)
    cat > "${BINSTUB}/curl" <<'STUB'
#!/bin/bash
echo "curl $*"
exit 0
STUB
    chmod +x "${BINSTUB}/curl"

    # Stub jq
    cat > "${BINSTUB}/jq" <<'STUB'
#!/bin/bash
echo '{"text":"plan summary"}'
exit 0
STUB
    chmod +x "${BINSTUB}/jq"

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

@test "exits 1 without --webhook when not dry-run" {
    run "$SCRIPT_PATH" --dir "$TF_DIR"
    assert_failure
    assert_output --partial "webhook"
}

@test "dry-run exits 0 without posting to Slack" {
    run "$SCRIPT_PATH" --dir "$TF_DIR" --dry-run
    assert_success
    assert_output --partial "dry-run"
}

@test "runs terraform plan and posts summary" {
    run "$SCRIPT_PATH" --webhook "https://hooks.slack.com/fake" --dir "$TF_DIR"
    assert_success
}

@test "set -euo pipefail is present" {
    grep -q 'set -euo pipefail' "$SCRIPT_PATH"
}
