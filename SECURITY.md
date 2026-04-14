# Security Policy

## Supported Versions

| Version | Supported |
|---------|-----------|
| main    | ✅        |

## Reporting a Vulnerability

If you discover a security vulnerability in this repository, **please do not open a public GitHub issue**.

Instead, report it privately:

1. **GitHub Private Vulnerability Reporting** (preferred): Go to the [Security tab](../../security/advisories/new) and click **Report a vulnerability**.
2. **Email**: Open a private discussion with the maintainer via GitHub.

Please include:
- A clear description of the vulnerability
- Steps to reproduce
- Potential impact
- Any suggested mitigations

You can expect an acknowledgement within **72 hours** and a resolution or status update within **7 days**.

## Sensitive Values — Never Commit Secrets

Scripts in this repository accept credentials exclusively through environment variables or CLI flags. **Never hard-code or commit**:

- API tokens (Slack, Jenkins, GitHub, etc.)
- Cloud credentials (AWS access keys, GCP service account keys)
- Database passwords
- Vault tokens or other secrets
- SSH private keys

### Examples of correct usage

```bash
# ✅ Pass via environment variable
export SLACK_WEBHOOK="$(cat ~/.secrets/slack_webhook)"
./scripts/notifications/slack-notify.sh --message "Deploy complete"

# ✅ Pass via --flag at runtime
./scripts/utils/secret-rotation.sh \
  --backend aws \
  --secret my-app/db-password \
  --value "$NEW_PASSWORD"

# ❌ NEVER embed secrets in scripts or committed config files
SLACK_WEBHOOK="https://hooks.slack.com/services/..."  # hard-coded — do NOT do this
```

### Git hygiene

- Add `.env` and any credential files to `.gitignore` before working locally.
- Use `git secret`, `git-crypt`, or a secrets manager for any config that must be stored.
- The pre-commit hook (`.pre-commit-config.yaml`) runs ShellCheck on all shell files before every commit. Install it with:

```bash
pip install pre-commit
pre-commit install
```

## Scope

Security issues in scope:

- Command injection via unvalidated input
- Unsafe use of `eval`, `exec`, or dynamic variable expansion with user-controlled data
- Credential leakage via log output or insecure temp files
- Insecure default permissions on output files containing sensitive data

Out of scope:

- Vulnerabilities in third-party tools called by scripts (kubectl, aws-cli, etc.)
- Issues requiring physical access to the machine running the scripts

## Security Best Practices for Contributors

1. **Validate all external input** before use in command substitutions or file paths.
2. **Quote all variables**: `"$VAR"` not `$VAR` — prevents word splitting and glob expansion.
3. **Use `set -euo pipefail`** at the top of every script.
4. **Avoid `eval`** entirely unless absolutely necessary and input is fully sanitized.
5. **Restrict output file permissions**: use `chmod 600` for files containing credentials or sensitive output.
6. **Use `mktemp`** for temporary files; always clean up with a `trap` on EXIT.
7. **Redirect errors to stderr** (`>&2`), never to stdout where they might be piped to commands.

See [CONTRIBUTING.md](CONTRIBUTING.md) for the full script template that enforces these practices.
