#!/usr/bin/env bats
load "${BATS_TEST_DIRNAME}/../test_helper/bats-support/load"
load "${BATS_TEST_DIRNAME}/../test_helper/bats-assert/load"

setup() {
    export SCRIPT_PATH="${BATS_TEST_DIRNAME}/../../scripts/devops/docker-image-prune.sh"
    export BINSTUB="${BATS_TEST_TMPDIR}/bin"
    mkdir -p "$BINSTUB"

    # Stub docker
    cat > "${BINSTUB}/docker" <<'EOF'
#!/bin/bash
if [[ "$1 $2" == "images -q" ]]; then
    echo "sha256abc"
    echo "sha256def"
    exit 0
fi
if [[ "$1" == "rmi" ]]; then
    echo "Deleted: $2"
    exit 0
fi
exit 0
EOF
    chmod +x "${BINSTUB}/docker"
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

@test "dry-run shows images without deleting" {
    run "$SCRIPT_PATH" --dry-run
    assert_success
    assert_output --partial "dry-run"
}

@test "prunes images with --all-unused" {
    run "$SCRIPT_PATH" --all-unused
    assert_success
}

@test "prunes images by label" {
    run "$SCRIPT_PATH" --label "env=ci"
    assert_success
}

@test "set -euo pipefail is present" {
    grep -q 'set -euo pipefail' "$SCRIPT_PATH"
}
