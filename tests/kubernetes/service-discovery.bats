#!/usr/bin/env bats
load "${BATS_TEST_DIRNAME}/../test_helper/bats-support/load"
load "${BATS_TEST_DIRNAME}/../test_helper/bats-assert/load"

setup() {
    export SCRIPT_PATH="${BATS_TEST_DIRNAME}/../../scripts/kubernetes/service-discovery.sh"
    export BINSTUB="${BATS_TEST_TMPDIR}/bin"
    mkdir -p "$BINSTUB"

    # Stub kubectl
    cat > "${BINSTUB}/kubectl" <<'STUB'
#!/bin/bash
if [[ "$1 $2" == "get services" ]]; then
    echo "NAME         TYPE        CLUSTER-IP    EXTERNAL-IP   PORT(S)   AGE"
    echo "frontend     ClusterIP   10.0.0.1      <none>        80/TCP    5d"
    echo "backend      NodePort    10.0.0.2      <none>        8080/TCP  3d"
    exit 0
fi
if [[ "$1 $2" == "get endpoints" ]]; then
    echo "NAME       ENDPOINTS         AGE"
    echo "frontend   192.168.1.1:80    5d"
    exit 0
fi
exit 0
STUB
    chmod +x "${BINSTUB}/kubectl"
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

@test "lists all services in default namespace" {
    run "$SCRIPT_PATH"
    assert_success
}

@test "lists services in specified namespace" {
    run "$SCRIPT_PATH" --namespace production
    assert_success
}

@test "filters by service type" {
    run "$SCRIPT_PATH" --type ClusterIP
    assert_success
}

@test "shows endpoints when --show-endpoints passed" {
    run "$SCRIPT_PATH" --show-endpoints
    assert_success
}

@test "set -euo pipefail is present" {
    grep -q 'set -euo pipefail' "$SCRIPT_PATH"
}
