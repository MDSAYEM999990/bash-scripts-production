# Contributing to bash-scripts

Thank you for your interest in contributing! This guide covers everything you need to add scripts, fix bugs, or improve the test suite.

---

## Quick Start

```bash
# Clone the repo
git clone https://github.com/wesleyscholl/bash-scripts.git
cd bash-scripts

# Install BATS test framework (submodules are already committed)
# Run the full test suite
bats $(find tests -name '*.bats' -not -path '*/test_helper/*' | sort)
```

---

## Repository Layout

```
bash-scripts/
├── scripts/
│   ├── lib/
│   │   └── utils.sh               # Shared helpers — log_info, log_error, check_dependency
│   ├── backup/                    # Backup & data-protection scripts
│   ├── ci-cd/                     # CI/CD pipeline scripts
│   ├── devops/                    # Docker, Git, infrastructure scripts
│   ├── kubernetes/                # kubectl / k8s scripts
│   ├── monitoring/                # Alerting and observability scripts
│   ├── notifications/             # Slack, email, and log aggregation
│   ├── system/                    # OS-level health and resource scripts
│   └── utils/                     # General-purpose utilities
└── tests/
    ├── test_helper/               # BATS support libraries (bats-support, bats-assert)
    ├── utils.bats                 # Tests for lib/utils.sh
    └── <category>/                # One .bats file per script, mirroring scripts/
```

---

## Adding a New Script

### 1. Choose the right category directory

| Category | Use for |
|---|---|
| `backup/` | Data backup, dump, rotation |
| `ci-cd/` | Build pipelines, deployment automation |
| `devops/` | Docker, Git, infrastructure provisioning |
| `kubernetes/` | kubectl operations, pod management |
| `monitoring/` | Alerting, health checks, cost monitoring |
| `notifications/` | Slack, email, log aggregation |
| `system/` | OS resources, process management |
| `utils/` | General-purpose helpers, secret management |

### 2. Use the standard script template

Every script **must** follow this structure:

```bash
#!/bin/bash
# script-name.sh — One-line description
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/utils.sh
source "${SCRIPT_DIR}/../lib/utils.sh"

# --- default values ---
MY_FLAG=""
DRY_RUN=false

usage() {
    cat <<EOF
Usage: $(basename "$0") [options]

Short description of what this script does.

Options:
  --my-flag VALUE  Description                  (env: MY_ENV_VAR)
  --dry-run        Show what would happen, make no changes
  -h, --help       Show this help message

Examples:
  $(basename "$0") --my-flag value
  $(basename "$0") --dry-run
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --my-flag)  MY_FLAG="$2"; shift 2 ;;
        --dry-run)  DRY_RUN=true; shift ;;
        -h|--help)  usage; exit 0 ;;
        *) log_error "Unknown option: $1"; usage; exit 1 ;;
    esac
done

# --- validate required args ---
if [[ -z "$MY_FLAG" ]]; then
    log_error "--my-flag is required."
    usage
    exit 1
fi

# --- main logic ---
if [[ "$DRY_RUN" == "true" ]]; then
    log_info "[dry-run] Would do X with ${MY_FLAG}."
    exit 0
fi

# do the real work here

exit 0
```

### 3. Key rules

- `set -euo pipefail` — mandatory on every script.
- **Never put `exit` inside `usage()`**. Call `usage; exit 0` or `usage; exit 1` at the call sites.
- Exit codes: `0` = success, `1` = bad user input / missing argument, `2` = runtime / system error.
- Accept `--dry-run` on any script that modifies state.
- Accept `--help` / `-h` that prints a usage example.
- For `--quiet` support, redirect `log_info` calls behind a flag check where appropriate.
- Source `utils.sh` using `"${SCRIPT_DIR}/../lib/utils.sh"` (scripts live one level below `scripts/`).
- Make executable: `chmod +x scripts/<category>/your-script.sh`.

### 4. Bash 3.2 compatibility (macOS default shell)

macOS ships with bash 3.2. Avoid:

| Dangerous | Safe alternative |
|---|---|
| `mapfile` / `readarray` | `while IFS= read -r line; do arr+=("$line"); done < <(cmd)` |
| Empty array under `set -u`: `"${arr[@]}"` | Always pre-populate arrays, or check `"${#arr[@]}" -gt 0` first |
| `[[ str =~ regex ]]` with complex regex | Use `grep -qE` or `awk` |

---

## Adding Tests

Every new script **requires** a corresponding BATS test file.

### Test file location & naming

```
scripts/monitoring/my-alert.sh   →   tests/monitoring/my-alert.bats
```

### Standard test file structure

```bash
#!/usr/bin/env bats
load "${BATS_TEST_DIRNAME}/../test_helper/bats-support/load"
load "${BATS_TEST_DIRNAME}/../test_helper/bats-assert/load"

setup() {
    export SCRIPT_PATH="${BATS_TEST_DIRNAME}/../../scripts/<category>/my-script.sh"
    export BINSTUB="${BATS_TEST_TMPDIR}/bin"
    mkdir -p "$BINSTUB"

    # Create stubs for external commands (kubectl, aws, docker, etc.)
    cat > "${BINSTUB}/mycmd" <<'STUB'
#!/bin/bash
echo "stub output"
exit 0
STUB
    chmod +x "${BINSTUB}/mycmd"

    export PATH="${BINSTUB}:${PATH}"
}

# Required tests — every script needs these four:
@test "script exists and is executable" {
    [ -f "$SCRIPT_PATH" ]
    [ -x "$SCRIPT_PATH" ]
}

@test "--help exits 0 and prints usage" {
    run "$SCRIPT_PATH" --help
    assert_success
    assert_output --partial "Usage:"
}

@test "exits 1 without required argument" {
    run "$SCRIPT_PATH"
    assert_failure
}

@test "set -euo pipefail is present" {
    grep -q 'set -euo pipefail' "$SCRIPT_PATH"
}

# Add behavioural tests below:
@test "dry-run exits 0 and prints dry-run message" {
    run "$SCRIPT_PATH" --required-arg value --dry-run
    assert_success
    assert_output --partial "dry-run"
}
```

### Path depth rules

```
tests/utils.bats          → test_helper at  tests/test_helper/
                            scripts at       scripts/

tests/subdir/foo.bats     → test_helper at  ${BATS_TEST_DIRNAME}/../test_helper/   (one level up)
                            scripts at       ${BATS_TEST_DIRNAME}/../../scripts/    (two levels up)
```

### Stubbing external commands

- Create executable stubs in `${BATS_TEST_TMPDIR}/bin/` and prepend to `$PATH`.
- Stubs should return appropriate exit codes and predictable output.
- Never require live external services (AWS, GCP, Kubernetes) in tests.
- Use `teardown()` if you create files outside `BATS_TEST_TMPDIR`.

---

## Running Tests

```bash
# Full suite
find tests -name '*.bats' -not -path '*/test_helper/*' | sort | xargs bats

# Single file
bats tests/monitoring/aws-cost-alert.bats

# Single category
bats tests/kubernetes/

# Verbose (shows test names as they run)
find tests -name '*.bats' -not -path '*/test_helper/*' | sort | xargs bats --tap
```

---

## Linting

All scripts are linted with [ShellCheck](https://www.shellcheck.net/). Install it and run:

```bash
shellcheck scripts/**/*.sh scripts/lib/utils.sh
```

The CI pipeline runs ShellCheck on every pull request and fails on any warning.

---

## Commit Message Format

This repo follows [Conventional Commits](https://www.conventionalcommits.org/):

```
type(scope): short description

Body (optional) — explain why, not what.
```

| Type | Use for |
|---|---|
| `feat` | New script or feature |
| `fix` | Bug fix in a script or test |
| `test` | New or updated BATS tests only |
| `docs` | Documentation only |
| `refactor` | Code change with no behaviour change |
| `chore` | CI, tooling, dependency updates |

**Scope** = the script name or category (e.g. `feat(db-backup)`, `fix(monitoring)`, `test(kubernetes)`).

---

## Pull Request Checklist

Before opening a PR, verify:

- [ ] New script follows the standard template (see above).
- [ ] `set -euo pipefail` present.
- [ ] `--help` works and includes an example.
- [ ] `--dry-run` implemented for any state-modifying script.
- [ ] Script is executable (`chmod +x`).
- [ ] Corresponding `.bats` test file exists in the matching `tests/<category>/` directory.
- [ ] All four required tests are present (exists, --help, missing-arg, set -euo).
- [ ] Full suite passes locally: `find tests -name '*.bats' -not -path '*/test_helper/*' | sort | xargs bats`.
- [ ] `shellcheck` produces zero warnings on the new/modified script.
- [ ] Commit message follows Conventional Commits format.
