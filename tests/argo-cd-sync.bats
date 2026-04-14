#!/usr/bin/env bats
# Tests for argo-cd-sync.sh

load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'

setup() {
    export SCRIPT_PATH="${BATS_TEST_DIRNAME}/../scripts/argo-cd-sync.sh"
    export BINSTUB="${BATS_TEST_TMPDIR}/bin"
    mkdir -p "$BINSTUB"

    cat > "${BINSTUB}/curl" << 'EOF'
#!/bin/bash
echo '{"kind":"Application","status":{"sync":{"status":"Synced"}}}'
exit 0
EOF
    chmod +x "${BINSTUB}/curl"
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

@test "exits 1 without required args" {
    run "$SCRIPT_PATH"
    assert_failure
}

@test "exits 1 with only --server (missing --app)" {
    run "$SCRIPT_PATH" --server argocd.example.com
    assert_failure
}

@test "invokes argocd with correct app arg" {
    run "$SCRIPT_PATH" --server argocd.example.com --app my-app --token testtoken
    assert_success
    assert_output --partial "my-app"
}

@test "sources utils.sh" {
    run grep "source.*lib/utils.sh" "$SCRIPT_PATH"
    assert_success
}
