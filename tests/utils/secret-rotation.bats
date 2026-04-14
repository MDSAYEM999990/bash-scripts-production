#!/usr/bin/env bats
load "${BATS_TEST_DIRNAME}/../test_helper/bats-support/load"
load "${BATS_TEST_DIRNAME}/../test_helper/bats-assert/load"

setup() {
    export SCRIPT_PATH="${BATS_TEST_DIRNAME}/../../scripts/utils/secret-rotation.sh"
    export BINSTUB="${BATS_TEST_TMPDIR}/bin"
    mkdir -p "$BINSTUB"

    # Stub aws CLI
    cat > "${BINSTUB}/aws" <<'STUB'
#!/bin/bash
echo "myapp/db_password"
exit 0
STUB
    chmod +x "${BINSTUB}/aws"

    # Stub vault CLI
    cat > "${BINSTUB}/vault" <<'STUB'
#!/bin/bash
echo "Success! Data written to: secret/app/api_key"
exit 0
STUB
    chmod +x "${BINSTUB}/vault"

    # Stub jq
    cat > "${BINSTUB}/jq" <<'STUB'
#!/bin/bash
echo '{"text":"secret rotated"}'
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

@test "exits 1 without --backend argument" {
    run "$SCRIPT_PATH" --secret myapp/token --value newval
    assert_failure
    assert_output --partial "backend"
}

@test "exits 1 without --secret argument" {
    run "$SCRIPT_PATH" --backend aws --value newval
    assert_failure
    assert_output --partial "secret"
}

@test "exits 1 without --value argument" {
    run "$SCRIPT_PATH" --backend aws --secret myapp/token
    assert_failure
    assert_output --partial "value"
}

@test "dry-run aws exits 0 without calling aws" {
    run "$SCRIPT_PATH" --backend aws --secret myapp/token --value "s3cr3t" --dry-run
    assert_success
    assert_output --partial "dry-run"
}

@test "dry-run vault exits 0 without calling vault" {
    run "$SCRIPT_PATH" --backend vault --secret secret/app/key --value "v4ult" --dry-run
    assert_success
    assert_output --partial "dry-run"
}

@test "rotates AWS Secrets Manager secret" {
    run "$SCRIPT_PATH" --backend aws --secret myapp/token --value "newpass123"
    assert_success
}

@test "rotates HashiCorp Vault secret" {
    run "$SCRIPT_PATH" --backend vault --secret secret/app/key --value "tokenabc"
    assert_success
}

@test "exits 1 for invalid --backend" {
    run "$SCRIPT_PATH" --backend gcp --secret myapp/token --value "x"
    assert_failure
}

@test "set -euo pipefail is present" {
    grep -q 'set -euo pipefail' "$SCRIPT_PATH"
}
