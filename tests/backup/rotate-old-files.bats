#\!/usr/bin/env bats
load "${BATS_TEST_DIRNAME}/../test_helper/bats-support/load"
load "${BATS_TEST_DIRNAME}/../test_helper/bats-assert/load"

setup() {
    export SCRIPT_PATH="${BATS_TEST_DIRNAME}/../../scripts/backup/rotate-old-files.sh"
    export ARCHIVE_DIR="${BATS_TEST_TMPDIR}/archive"
    export WATCH_DIR="${BATS_TEST_TMPDIR}/watch"
    mkdir -p "$ARCHIVE_DIR" "$WATCH_DIR"
    touch "${WATCH_DIR}/keep.txt"
}

teardown() {
    rm -rf "$ARCHIVE_DIR" "$WATCH_DIR"
}

@test "script exists and is executable" {
    [ -f "$SCRIPT_PATH" ] && [ -x "$SCRIPT_PATH" ]
}

@test "--help exits 0 and prints usage" {
    run "$SCRIPT_PATH" --help
    assert_success
    assert_output --partial "Usage:"
}

@test "exits 1 without required --dir argument" {
    run "$SCRIPT_PATH"
    assert_failure
}

@test "--dry-run succeeds without moving files" {
    run "$SCRIPT_PATH" --dir "$WATCH_DIR" --days 0 --archive-dir "$ARCHIVE_DIR" --dry-run
    assert_success
    # file should still be in watch dir
    [ -f "${WATCH_DIR}/keep.txt" ]
}

@test "uses find -print0 for safe filename handling" {
    run grep "print0" "$SCRIPT_PATH"
    assert_success
}

@test "set -euo pipefail is present" {
    run grep "set -euo pipefail" "$SCRIPT_PATH"
    assert_success
}
