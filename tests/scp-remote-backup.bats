#!/usr/bin/env bats
load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'

setup() {
    export SCRIPT_PATH="${BATS_TEST_DIRNAME}/../scripts/scp-remote-backup.sh"
    export BINSTUB="${BATS_TEST_TMPDIR}/bin"
    mkdir -p "$BINSTUB"

    cat > "${BINSTUB}/tar" << 'EOF'
#!/bin/bash
echo "mock-tar $*"
# Create a fake archive file
for i in "$@"; do
    [[ "$i" == *.tar.gz ]] && touch "$i"
done
exit 0
EOF
    chmod +x "${BINSTUB}/tar"

    cat > "${BINSTUB}/scp" << 'EOF'
#!/bin/bash
echo "mock-scp $*"
exit 0
EOF
    chmod +x "${BINSTUB}/scp"
    export PATH="${BINSTUB}:$PATH"

    export SRC_DIR="${BATS_TEST_TMPDIR}/source"
    mkdir -p "$SRC_DIR"
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

@test "exits 1 without --host argument" {
    run "$SCRIPT_PATH" --src "$SRC_DIR"
    assert_failure
}

@test "uses TMPDIR or /tmp for temp archive" {
    run grep 'TMPDIR\|/tmp' "$SCRIPT_PATH"
    assert_success
}

@test "set -euo pipefail is present" {
    run grep "set -euo pipefail" "$SCRIPT_PATH"
    assert_success
}
