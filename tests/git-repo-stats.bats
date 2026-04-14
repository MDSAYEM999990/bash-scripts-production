#!/usr/bin/env bats
# Tests for git-repo-stats.sh

load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'

setup() {
    export SCRIPT_PATH="${BATS_TEST_DIRNAME}/../scripts/git-repo-stats.sh"
    export GIT_REPO="${BATS_TEST_TMPDIR}/repo"
    mkdir -p "$GIT_REPO"
    git -C "$GIT_REPO" init -q
    git -C "$GIT_REPO" config user.email "test@test.com"
    git -C "$GIT_REPO" config user.name "Test"
    echo "hello" > "${GIT_REPO}/file.txt"
    git -C "$GIT_REPO" add .
    git -C "$GIT_REPO" commit -q -m "initial commit"
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

@test "exits 1 when run outside a git repository" {
    run bash -c "cd '${BATS_TEST_TMPDIR}' && '${SCRIPT_PATH}'"
    assert_failure
}

@test "runs successfully inside a git repository" {
    run bash -c "cd '${GIT_REPO}' && '${SCRIPT_PATH}'"
    assert_success
}

@test "does not use backtick command substitution" {
    run grep '`' "$SCRIPT_PATH"
    assert_failure  # backticks should NOT appear
}

@test "set -euo pipefail is present" {
    run grep "set -euo pipefail" "$SCRIPT_PATH"
    assert_success
}
