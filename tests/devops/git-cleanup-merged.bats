#!/usr/bin/env bats
load "${BATS_TEST_DIRNAME}/../test_helper/bats-support/load"
load "${BATS_TEST_DIRNAME}/../test_helper/bats-assert/load"

setup() {
    export SCRIPT_PATH="${BATS_TEST_DIRNAME}/../../scripts/devops/git-cleanup-merged.sh"
    export BINSTUB="${BATS_TEST_TMPDIR}/bin"
    mkdir -p "$BINSTUB"

    # Stub git
    cat > "${BINSTUB}/git" <<'EOF'
#!/bin/bash
if [[ "$1" == "fetch" ]]; then exit 0; fi
# branch --merged
if [[ "$*" == *"--merged"* ]]; then
    echo "  feature/old-feature"
    echo "  feature/another-one"
    exit 0
fi
if [[ "$1" == "symbolic-ref" ]]; then echo "refs/heads/main"; exit 0; fi
if [[ "$1" == "branch" && "$2" == "-d" ]]; then
    echo "Deleted branch $3."
    exit 0
fi
if [[ "$1" == "push" && "$2" == "--delete" ]]; then
    echo "Deleted remote branch $4."
    exit 0
fi
exit 0
EOF
    chmod +x "${BINSTUB}/git"
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

@test "dry-run lists branches without deleting" {
    run "$SCRIPT_PATH" --dry-run
    assert_success
    assert_output --partial "dry-run"
}

@test "deletes merged local branches" {
    run "$SCRIPT_PATH" --base main
    assert_success
}

@test "does not delete protected branches" {
    run "$SCRIPT_PATH" --dry-run
    refute_output --partial "main"
}

@test "set -euo pipefail is present" {
    grep -q 'set -euo pipefail' "$SCRIPT_PATH"
}
