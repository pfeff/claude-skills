# Scaffold Project

Create Ralph Wiggum configuration files from templates using values collected by the gather-requirements operation. Supports both single-repo and multi-repo workspaces.

## Files Created

### Single-repo mode

| File | Purpose |
|------|---------|
| `PROMPT_plan.md` | Planning phase instructions for the agent |
| `PROMPT_build.md` | Build phase instructions for the agent |
| `.ralph/gates.md` | Project-specific gate commands (test, lint, build) |
| `.ralph/services.md` | External service dependencies and health checks |
| `specs/` | Directory for requirement specification files |
| `specs/example.md` | Example spec file demonstrating the format |

### Multi-repo mode (additional files)

| File | Purpose |
|------|---------|
| `.ralph/workspace.md` | Workspace manifest listing repos, paths, and gate references |
| `<repo>/.ralph/gates.md` | Per-repo gate commands (one per repo) |

In multi-repo mode, `PROMPT_plan.md`, `PROMPT_build.md`, `specs/`, and `.ralph/workspace.md` are created at the workspace root. Each repo gets its own `.ralph/gates.md`.

## Parameters

Values from gather-requirements:

### Single-repo parameters

| Value | Required | Used in |
|-------|----------|---------|
| `workspace_type` | yes | Mode selection (`single`) |
| `language` | yes | Context only |
| `test_command` | yes | `.ralph/gates.md` |
| `lint_command` | yes | `.ralph/gates.md` |
| `build_command` | no | `.ralph/gates.md` |
| `typecheck_command` | no | `.ralph/gates.md` |
| `docker_compose` | no | `.ralph/services.md` |
| `compose_file` | no | `.ralph/services.md` |
| `health_checks` | no | `.ralph/services.md` |
| `health_timeout` | no | `.ralph/services.md` |

### Multi-repo parameters

| Value | Required | Used in |
|-------|----------|---------|
| `workspace_type` | yes | Mode selection (`multi`) |
| `repos` | yes | `.ralph/workspace.md` |
| `repos[].name` | yes | `.ralph/workspace.md`, directory reference |
| `repos[].path` | yes | `.ralph/workspace.md`, gate file path |
| `repos[].language` | yes | Context only |
| `repos[].test_command` | yes | `<repo>/.ralph/gates.md` |
| `repos[].lint_command` | yes | `<repo>/.ralph/gates.md` |
| `repos[].build_command` | no | `<repo>/.ralph/gates.md` |
| `repos[].typecheck_command` | no | `<repo>/.ralph/gates.md` |
| `docker_compose` | no | `.ralph/services.md` |
| `compose_file` | no | `.ralph/services.md` |
| `health_checks` | no | `.ralph/services.md` |
| `health_timeout` | no | `.ralph/services.md` |

## Execution Steps

### 1. Check Existing Files

Before creating files, check if any already exist:
- `PROMPT_plan.md`
- `PROMPT_build.md`
- `.ralph/gates.md` (single-repo) or `.ralph/workspace.md` (multi-repo)
- `.ralph/services.md`
- `specs/`

If files exist, ask the user via AskUserQuestion:
1. **Skip existing files** (preserve customizations)
2. **Overwrite with fresh templates**

### 2. Create Files

Generate files from skill sources:

**Substitution templates**: `${CLAUDE_PLUGIN_ROOT}/skills/ralph-wiggum/templates/` (use `{{placeholder}}` syntax)
**PROMPT files**: `${CLAUDE_PLUGIN_ROOT}/skills/ralph-wiggum/` (skill root — copied verbatim, no substitution)

#### 2a. PROMPT_plan.md
Copy from skill root `PROMPT_plan.md`. No substitution needed.

#### 2b. PROMPT_build.md
Copy from skill root `PROMPT_build.md`. No substitution needed.

#### 2c. Gates configuration

**Single-repo mode**: Create `.ralph/` directory. Generate `.ralph/gates.md` from `templates/gates.md`, substituting user-provided commands:

```markdown
# Gates

## Commands

| Gate | Command |
|------|---------|
| lint | `{{lint_command}}` |
| typecheck | `{{typecheck_command}}` |
| test | `{{test_command}}` |
| build | `{{build_command}}` |
```

**Multi-repo mode**: For each repo, create `<repo_path>/.ralph/gates.md` from `templates/gates.md`, substituting that repo's gate commands. Then create `.ralph/workspace.md` from `templates/workspace.md`:

```markdown
# Workspace

## Repos

| Repo | Path | Gates |
|------|------|-------|
| {{repo_name}} | `{{repo_path}}` | `{{repo_path}}/.ralph/gates.md` |

## Branch

| Setting | Value |
|---------|-------|
| name | `{{branch_name}}` |
| strategy | `workspace` |
```

The `{{branch_name}}` is derived from the first spec file slug (e.g., `ralph/user-auth`). If the workspace uses worktree branches, use the existing branch name instead.

#### 2d. .ralph/services.md (conditional)
Only create if user provided external dependencies (`docker_compose` is true). Generate from `templates/services.md`, substituting user-provided values. Skip entirely if no dependencies were specified. Created at workspace root in both modes.

#### 2e. specs/example.md
Copy from `templates/specs/example.md`. No substitution needed.

### 3. Verify and Show Next Steps

After creating files:

1. List all created files with their paths
2. Display next steps:

**Single-repo**:
   - Write specs in `specs/` directory (one topic per file)
   - Run `./loop.sh plan` to generate PLAN.md
   - Run `./loop.sh build` to start autonomous build loop

**Multi-repo**:
   - Write specs in `specs/` directory — prefix tasks with `[repo-name]` to target specific repos
   - Review `.ralph/workspace.md` to verify repo list and paths
   - Review each repo's `.ralph/gates.md` for correct commands
   - Run `./loop.sh plan` to generate PLAN.md (from workspace root)
   - Run `./loop.sh build` to start autonomous build loop (from workspace root)

## Output

List of created files with their paths and whether each was newly created or skipped (existing). Example:

```
Created:
  - PROMPT_plan.md
  - PROMPT_build.md
  - .ralph/gates.md
  - specs/example.md
Skipped (existing):
  - (none)
```

## Error Handling

| Condition | Behavior |
|-----------|----------|
| Template file not found at expected path | Report missing template path and stop — do not create partial scaffolding |
| File write fails (permissions, disk) | Report error for the specific file, continue with remaining files |
| User chose "Skip existing files" | Preserve existing files, only create missing ones |
| User chose "Overwrite" | Replace all existing files with fresh templates |
| Multi-repo: repo directory doesn't exist | Report missing repo path, skip that repo's `.ralph/gates.md`, continue with others |
