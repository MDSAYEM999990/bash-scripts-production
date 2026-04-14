#!/usr/bin/env bats
load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'

setup() {
    export SCRIPT_PATH="${BATS_TEST_DIRNAME}/../scripts/backup.sh"
    export BINSTUB="${BATS_TEST_TMPDIR}/bin"
    export DEST_DIR="${BATS_TEST_TMPDIR}/backup"
    export SRC_DIR="${BATS_TEST_TMPDIR}/source"
    mkdir -p "$DEST_DIR" "$SRC_DIR" "$BINSTUB"
    echo "data" > "${SRC_DIR}/data.txt"

    # Stub tar — record args without doing real archiving
    cat > "${BINSTUB}/tar" << 'EOF'
#!/bin/bash
echo "mock-tar $*"
for a in "$@"; do [[ "$a" == *.tgz ]] && touch "$a"; done
exit 0
EOF
    chmod +x "${BINSTUB}/tar"
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

@test "runs with --dest and calls tar" {
    run "$SCRIPT_PATH" --dest "$DEST_DIR"
    assert_success
    assert_output --partial "mock-tar"
}

@test "--src flag passes custom path to tar" {
    run "$SCRIPT_PATH" --src "$SRC_DIR" --dest "$DEST_DIR"
    assert_success
    assert_output --partial "$SRC_DIR"
}

@test "archive filename includes today's date" {
    run "$SCRIPT_PATH" --dest "$DEST_DIR"
    assert_success
    local today; today=$(date +%Y-%m-%d)
    assert_output --partial "$today"
}

@test "set -euo pipefail is present" {
    run grep "set -euo pipefail" "$SCRIPT_PATH"
    assert_success
}

@test "sources utils.sh" {
    run grep "source.*lib/utils.sh" "$SCRIPT_PATH"
    assert_success
}
