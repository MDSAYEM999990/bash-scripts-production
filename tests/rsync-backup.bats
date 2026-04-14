#!/usr/bin/env bats
load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'

setup() {
    export SCRIPT_PATH="${BATS_TEST_DIRNAME}/../scripts/rsync-backup.sh"
    export BINSTUB="${BATS_TEST_TMPDIR}/bin"
    mkdir -p "$BINSTUB"

    cat > "${BINSTUB}/rsync" << 'EOF'
#!/bin/bash
echo "mock-rsync $*"
exit 0
EOF
    chmod +x "${BINSTUB}/rsync"
    export PATH="${BINSTUB}:$PATH"

    export SRC_DIR="${BATS_TEST_TMPDIR}/source"
    export DEST_DIR="${BATS_TEST_TMPDIR}/dest"
    mkdir -p "$SRC_DIR" "$DEST_DIR"
    echo "data" > "${SRC_DIR}/file.txt"
}

@test "script exists and is executable" {
    [ -f "$SCRIPT_PATH" ] && [ -x "$SCRIPT_PATH" ]
}

@test "--help exits 0 and prints usage" {
    run "$SCRIPT_PATH" --help
    assert_success
    assert_output --partial "Usage:"
}

@test "exits 1 without required --src argument" {
    run "$SCRIPT_PATH"
    assert_failure
}

@test "exits 1 without --dest argument" {
    run "$SCRIPT_PATH" --src "$SRC_DIR"
    assert_failure
}

@test "calls rsync with source and destination" {
    run "$SCRIPT_PATH" --src "$SRC_DIR" --dest "$DEST_DIR"
    assert_success
    assert_output --partial "mock-rsync"
}

@test "--dry-run passes --dry-run to rsync" {
    run "$SCRIPT_PATH" --src "$SRC_DIR" --dest "$DEST_DIR" --dry-run
    assert_success
    assert_output --partial "dry-run"
}

@test "does not use dollar-question-mark anti-pattern" {
    run grep '\$?' "$SCRIPT_PATH"
    assert_failure
}

@test "set -euo pipefail is present" {
    run grep "set -euo pipefail" "$SCRIPT_PATH"
    assert_success
}
