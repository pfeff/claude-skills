# Gather Requirements

Collect project information needed to scaffold Ralph Wiggum configuration files. Supports both single-repo and multi-repo workspaces.

## Parameters

- None. All values gathered interactively via AskUserQuestion.

## Execution Steps

### 1. Detect Workspace Type

Scan the current directory for git repositories:

```
Glob: pattern="*/.git"
```

Also check if the current directory itself is a git repo (`ls .git`).

**Classification**:
- **Single-repo**: Current directory is a git repo (`.git` exists at root), OR exactly one subdirectory contains `.git`
- **Multi-repo**: Two or more subdirectories contain `.git` (directories or files — worktrees use `.git` files)

If multi-repo detected, list the discovered repos and confirm with the user:

```
AskUserQuestion:
  question: "I found multiple repos in this workspace. Which should be included in the Ralph loop?"
  options:
    - "All repos" — include all discovered repos
    - "Select repos" — let me pick which repos to include
```

Record the repo list: `[{name: <dir_name>, path: <relative_path>}]`

If single-repo, proceed with existing single-repo flow (steps 2-3).

### 2. Collect Core Project Info

**Single-repo mode**: Use AskUserQuestion to gather **required** information:

- **Project language/framework**: Node.js, Python, Go, Rust, etc.
- **Test command**: e.g., `npm test`, `pytest`, `go test ./...`
- **Lint command**: e.g., `npm run lint`, `ruff check .`, `golangci-lint run`

And **optional** information:

- **Build command**: e.g., `npm run build`, `go build ./...`
- **Typecheck command**: e.g., `tsc --noEmit`, `mypy .`

**Multi-repo mode**: For each repo in the list, collect gate commands. Present all repos together:

```
AskUserQuestion:
  question: "For each repo, provide gate commands (leave empty to skip a gate):"
```

Collect per-repo:

| Value | Required | Per-repo |
|-------|----------|----------|
| `language` | yes | yes |
| `test_command` | yes | yes |
| `lint_command` | yes | yes |
| `build_command` | no | yes |
| `typecheck_command` | no | yes |

### 3. Collect External Dependencies (Optional)

Ask the user about external service dependencies:

- Does your project use Docker Compose for local services? (y/n)
  - If yes:
    - Docker Compose file path (default: `docker-compose.yml`)
    - Service health check commands (e.g., `pg_isready -h localhost`, `redis-cli ping`)
    - Timeout per health check in seconds (default: `30`)

If the user answers no or skips, do not create `.ralph/services.md` in the scaffold step.

### 4. Return Collected Values

**Single-repo mode** — pass the following to the scaffold-project operation:

| Value | Required | Default |
|-------|----------|---------|
| `workspace_type` | yes | `single` |
| `language` | yes | — |
| `test_command` | yes | — |
| `lint_command` | yes | — |
| `build_command` | no | _(empty)_ |
| `typecheck_command` | no | _(empty)_ |
| `docker_compose` | no | `false` |
| `compose_file` | no | `docker-compose.yml` |
| `health_checks` | no | _(empty)_ |
| `health_timeout` | no | `30` |

**Multi-repo mode** — pass the following to the scaffold-project operation:

> **Note on health_checks structure**: Each entry is `{service_name, health_check_command, timeout_seconds}` matching the `templates/services.md` placeholders.

| Value | Required | Default |
|-------|----------|---------|
| `workspace_type` | yes | `multi` |
| `repos` | yes | — |
| `repos[].name` | yes | directory name |
| `repos[].path` | yes | relative path |
| `repos[].language` | yes | — |
| `repos[].test_command` | yes | — |
| `repos[].lint_command` | yes | — |
| `repos[].build_command` | no | _(empty)_ |
| `repos[].typecheck_command` | no | _(empty)_ |
| `docker_compose` | no | `false` |
| `compose_file` | no | `docker-compose.yml` |
| `health_checks` | no | _(empty)_ |
| `health_timeout` | no | `30` |

## Output

The collected values structure (single-repo or multi-repo variant from step 4), ready to pass directly to the scaffold-project operation.

## Error Handling

| Condition | Behavior |
|-----------|----------|
| No `.git` found in current directory or subdirectories | Report "No git repositories found — cannot scaffold". Stop. |
| User selects "Select repos" in multi-repo mode | Present discovered repo names as AskUserQuestion options for individual selection |
| User cancels or skips all questions | Stop gracefully — do not proceed to scaffold-project with incomplete values |
| Current directory is a git repo AND has git subdirectories | Classify as single-repo (current directory takes precedence) |
