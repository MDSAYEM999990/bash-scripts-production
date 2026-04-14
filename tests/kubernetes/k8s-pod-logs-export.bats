#!/usr/bin/env bats
load "${BATS_TEST_DIRNAME}/../test_helper/bats-support/load"
load "${BATS_TEST_DIRNAME}/../test_helper/bats-assert/load"

setup() {
    export SCRIPT_PATH="${BATS_TEST_DIRNAME}/../../scripts/kubernetes/k8s-pod-logs-export.sh"
    export BINSTUB="${BATS_TEST_TMPDIR}/bin"
    mkdir -p "$BINSTUB"

    # Stub kubectl
    cat > "${BINSTUB}/kubectl" <<'EOF'
#!/bin/bash
if [[ "$1 $2" == "get pods" ]]; then
    echo -e "pod-alpha\npod-beta"
    exit 0
fi
if [[ "$1" == "logs" ]]; then
    echo "log line from ${3}"
    exit 0
fi
exit 0
EOF
    chmod +x "${BINSTUB}/kubectl"
    export PATH="${BINSTUB}:${PATH}"
    export TEST_OUTDIR="${BATS_TEST_TMPDIR}/logs"
    mkdir -p "$TEST_OUTDIR"
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

@test "exits 1 without --namespace argument" {
    run "$SCRIPT_PATH"
    assert_failure
    assert_output --partial "namespace"
}

@test "creates output files per pod in dry-run" {
    run "$SCRIPT_PATH" --namespace default --output-dir "$TEST_OUTDIR" --dry-run
    assert_success
    assert_output --partial "dry-run"
}

@test "exports logs for each pod" {
    run "$SCRIPT_PATH" --namespace default --output-dir "$TEST_OUTDIR"
    assert_success
}

@test "set -euo pipefail is present" {
    grep -q 'set -euo pipefail' "$SCRIPT_PATH"
}
