#!/usr/bin/env bats
# Tests for check-ssl-expiry.sh

load "${BATS_TEST_DIRNAME}/../test_helper/bats-support/load"
load "${BATS_TEST_DIRNAME}/../test_helper/bats-assert/load"

setup() {
    export SCRIPT_PATH="${BATS_TEST_DIRNAME}/../../scripts/monitoring/check-ssl-expiry.sh"
    export BINSTUB="${BATS_TEST_TMPDIR}/bin"
    mkdir -p "$BINSTUB"

    # Stub openssl to return a date far in the future
    cat > "${BINSTUB}/openssl" << 'EOF'
#!/bin/bash
if [[ "$*" == *"s_client"* ]]; then
    echo "notAfter=Dec 31 23:59:59 2099 GMT"
fi
exit 0
EOF
    chmod +x "${BINSTUB}/openssl"
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

@test "exits 1 without required --host argument" {
    run "$SCRIPT_PATH"
    assert_failure
}

@test "sources utils.sh" {
    run grep "source.*lib/utils.sh" "$SCRIPT_PATH"
    assert_success
}
