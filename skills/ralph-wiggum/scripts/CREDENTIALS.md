# Credential Management

## Overview

Ralph Wiggum uses OAuth token extracted from macOS Keychain for container authentication. **API keys are not supported** - Ralph requires the Claude subscription (OAuth).

## Execution Model

**Always use `run-container.sh`** to run Ralph:

```bash
./run-container.sh /path/to/project
```

- `run-container.sh` - Entry point; extracts credentials, starts container, invokes loop
- `loop.sh` - Internal orchestrator; **only runs inside the container**

Running `loop.sh` directly on the host will fail with an error directing you to use `run-container.sh`.

## Authentication

`run-container.sh` extracts OAuth token from Keychain and passes it via `CLAUDE_CODE_OAUTH_TOKEN` environment variable.

```bash
./run-container.sh /path/to/project --network
```

**How it works:**
1. Script extracts token from macOS Keychain (`Claude Code-credentials`)
2. Passes `CLAUDE_CODE_OAUTH_TOKEN` environment variable to container
3. Mounts writable `~/.claude.json` with `{"hasCompletedOnboarding": true}`
4. Mounts writable `~/.claude/` directory for Claude's runtime files

**Important:** `~/.claude.json` must be writable - Claude updates this file during operation.

## Security Model

### What enters the container

| Credential | How Passed |
|------------|------------|
| OAuth token | Environment variable |
| Git author name/email | Environment variable |

### Why macOS Keychain Access Doesn't Work

Claude CLI stores account credentials in the **macOS Keychain**:
- `Claude Safe Storage` - encryption key
- `Claude Code-credentials` - auth tokens

Docker containers cannot access macOS Keychain directly. The script extracts tokens before container launch.

### What does NOT enter the container

- SSH keys
- AWS credentials
- GitHub tokens
- Any files from `~/.config`, `~/.ssh`, `~/.aws`
- Host environment variables (except explicitly passed)

### Container isolation

The container runs with:
- **No network by default** - prevents credential exfiltration
- **Read-only filesystem** - prevents credential persistence
- **No privileged access** - `--cap-drop ALL`, `--security-opt no-new-privileges`
- **Non-root user** - runs as `ralph` user inside container
- **Temp files cleaned up** - credentials removed when script exits

## Git Operations

Git operations inside the container use environment variables for author info:

```bash
GIT_AUTHOR_NAME="Your Name"
GIT_AUTHOR_EMAIL="you@example.com"
```

These are automatically populated from your host's `git config`. No SSH keys are passed.

## Best Practices

1. **Never commit credentials** - The pre-commit hook blocks secrets
2. **OAuth only** - API keys (`ANTHROPIC_API_KEY`) are not supported; Ralph uses Claude subscription
3. **Token expiration** - OAuth tokens expire in 8-12 hours; re-run `claude login` to refresh
4. **Audit network access** - Review `network-allowlist.conf` before enabling network mode
