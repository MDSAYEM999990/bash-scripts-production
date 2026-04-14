#!/usr/bin/env bats
load "${BATS_TEST_DIRNAME}/../test_helper/bats-support/load"
load "${BATS_TEST_DIRNAME}/../test_helper/bats-assert/load"

setup() {
    export SCRIPT_PATH="${BATS_TEST_DIRNAME}/../../scripts/monitoring/cert-auto-renew.sh"
    export BINSTUB="${BATS_TEST_TMPDIR}/bin"
    mkdir -p "$BINSTUB"

    # Stub certbot — default: no renewal
    cat > "${BINSTUB}/certbot" <<'STUB'
#!/bin/bash
echo "No renewals were due."
exit 0
STUB
    chmod +x "${BINSTUB}/certbot"

    # Stub systemctl
    cat > "${BINSTUB}/systemctl" <<'STUB'
#!/bin/bash
echo "systemctl $*"
exit 0
STUB
    chmod +x "${BINSTUB}/systemctl"

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

@test "dry-run passes --dry-run flag to certbot" {
    # certbot stub records how it was called
    cat > "${BINSTUB}/certbot" <<'STUB'
#!/bin/bash
echo "certbot-called-with: $*"
exit 0
STUB
    chmod +x "${BINSTUB}/certbot"
    run "$SCRIPT_PATH" --dry-run
    assert_success
    assert_output --partial "--dry-run"
}

@test "runs certbot renew by default" {
    run "$SCRIPT_PATH"
    assert_success
}

@test "reloads nginx when renewal succeeds" {
    # Stub certbot to report success
    cat > "${BINSTUB}/certbot" <<'STUB'
#!/bin/bash
echo "Congratulations, all renewals succeeded."
exit 0
STUB
    run "$SCRIPT_PATH" --web-server nginx
    assert_success
    assert_output --partial "nginx"
}

@test "set -euo pipefail is present" {
    grep -q 'set -euo pipefail' "$SCRIPT_PATH"
}
