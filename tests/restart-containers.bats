#\!/usr/bin/env bats
load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'

setup() {
    export SCRIPT_PATH="${BATS_TEST_DIRNAME}/../scripts/restart-containers.sh"
    export BINSTUB="${BATS_TEST_TMPDIR}/bin"
    mkdir -p "$BINSTUB"

    cat > "${BINSTUB}/docker" << 'EOF'
#\!/bin/bash
if [[ "$1 $2" == "ps --format" ]] || [[ "$1" == "ps" ]]; then
    echo "web"
    echo "api"
    exit 0
fi
echo "mock-docker $*"
exit 0
EOF
    chmod +x "${BINSTUB}/docker"
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

@test "--dry-run does not call docker restart" {
    run "$SCRIPT_PATH" --dry-run
    assert_success
    # dry-run should not contain "mock-docker restart"
    refute_output --partial "mock-docker restart"
}

@test "set -euo pipefail is present" {
    run grep "set -euo pipefail" "$SCRIPT_PATH"
    assert_success
}
