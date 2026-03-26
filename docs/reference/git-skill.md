# Git Skill

Enforces compact commit messages, conventional commit format, incremental commit discipline, and worktree-aware PR operations.

## Overview

The git skill teaches Claude Code a consistent set of git conventions: when to commit, how to write commit messages, how to merge PRs safely from worktrees, and how to create PRs via GitHub CLI. It uses progressive disclosure — the skill loads lightweight summaries first and only reads detailed operation files when needed.

## Installation

```bash
claude plugin install pfeff/claude-skills
```

The skill activates automatically when you request git operations (commits, PRs, merges).

## Invocation

```
/claude-skills:git
```

Or simply ask Claude Code to commit, create a PR, or merge a PR — the skill triggers based on the operation.

## Operations

### Committing Changes

**Trigger**: "commit", "save work to git", or any request to create a git commit.

**What it does**:

1. **Resolves symlinks** — runs `realpath` on file paths to find the actual git repository (handles symlinked skill/config directories)
2. **Branch guard** — warns if you're on `main` or `master` and suggests creating a feature branch
3. **Reviews state** — runs `git status`, `git diff --staged`, and `git diff` in parallel
4. **Evaluates readiness** — applies the incremental commit heuristic (see [Core Principles](#core-principles))
5. **Stages changes** — adds specific files or relevant changes; skips secrets (`.env`, `credentials.json`)
6. **Crafts message** — analyzes the diff and writes a compact conventional commit message
7. **Commits** — creates the commit using HEREDOC formatting
8. **Verifies** — shows `git log -1 --oneline`

**Inputs** (all optional):

| Input | Description |
|-------|-------------|
| `files` | Specific files to stage (defaults to all relevant changes) |
| `message` | Pre-written commit message (otherwise crafted from diff) |
| `type` | Conventional commit type: `feat`, `fix`, `refactor`, `docs`, `test`, `chore` |

### Merging Pull Requests

**Trigger**: "merge PR", "merge this PR", or any request to merge a pull request.

**What it does**:

1. **Detects worktree context** — compares `git-common-dir` and `git-dir` to determine if you're in a worktree
2. **Identifies the PR** — finds the PR for the current branch via `gh pr view`
3. **Resolves merge strategy** using this resolution chain:
   - Explicit input (`merge`, `squash`, or `rebase`)
   - Repo `CLAUDE.md` → looks for `Merge Strategy: <method>` line
   - GitHub repo settings → queries allowed merge types via API
   - Default: `merge`
4. **Merges** — in worktrees, uses `--delete-branch=false` then deletes remote branch separately to avoid the "branch already checked out" fatal error
5. **Verifies** — confirms PR state is `MERGED`

**Inputs** (all optional):

| Input | Description |
|-------|-------------|
| `pr` | PR number or branch name (defaults to current branch's PR) |
| `method` | Merge method: `merge`, `squash`, or `rebase` |

**Why worktrees need special handling**: `gh pr merge --delete-branch` tries to checkout the default branch locally after deleting the remote branch. In a worktree, that branch is already checked out in the main working tree, causing a fatal error.

### Creating Pull Requests

**Trigger**: "create PR", "open a PR", or any request to create a pull request.

**What it does**: Creates a PR using `gh pr create` with a compact title and structured body.

```bash
gh pr create --title "<type>: <description>" --body "..."
```

## Core Principles

### Incremental Commits

Commit at logical boundaries, not at arbitrary checkpoints.

| Commit when... | Don't commit when... |
|----------------|---------------------|
| Logical unit complete (model, service, component) | Small part of a larger unit |
| Tests pass + meaningful progress | Tests failing |
| About to switch contexts (backend → frontend) | Purely scaffolding with no behavior |
| About to attempt risky/uncertain changes | Would need a "WIP" commit message |

**Heuristic**: "Can I write a meaningful commit message? If yes, commit. If I'd write 'WIP', keep working."

### Commit Message Format

```
<type>: <headline>

<1-2 sentence summary explaining why, not what>
```

**Rules**:
- Headline: imperative mood, no period, lowercase after colon, 50 chars or less
- Summary: motivation and context, not implementation details
- Bug fixes: state the specific bug ("Fixes incorrect X causing Y")
- Features: explain the capability, not the code changes
- Never include Claude attribution annotations or emoji

**Types**: `feat`, `fix`, `refactor`, `docs`, `test`, `chore`

### What Good Looks Like

```
fix: correct AD username variable escaping

The username was rendered without proper quotes, causing AD registration failures.
```

```
feat: add OAuth2 authentication provider

Enables token-based auth for external API integrations.
```

### What Bad Looks Like

```
fix: fixed the bug where the AD username was being rendered incorrectly

This commit fixes the issue where the AD username variable in the init script
was being rendered with incorrect escaping, which was causing the servers to
fail to register with Active Directory and subsequently fail all downstream
initialization steps.
```

Too verbose. Duplicates the headline. Explains what (not why). Uses past tense.

## Allowed Tools

The skill grants Claude Code permission to run these commands without prompting:

| Category | Commands |
|----------|----------|
| **Read-only git** | `git status`, `git diff`, `git log`, `git show`, `git rev-parse`, `git branch`, `git remote`, `git config --get`, `git ls-files`, `git describe`, `git rev-list`, `git cat-file`, `git worktree list` |
| **Network git** | `git fetch`, `git pull`, `git push origin --delete` |
| **GitHub CLI** | `gh pr view`, `gh pr merge`, `gh api repos` |

Write operations (`git add`, `git commit`, `git push`) still require user approval.

## Edge Cases

| Scenario | Behavior |
|----------|----------|
| Symlinked files | Resolves via `realpath`, runs git in actual repository |
| On main/master | Warns and suggests feature branch; proceeds only with explicit confirmation |
| No changes to commit | Reports "No changes to commit" |
| Secrets in staged files | Warns and asks for confirmation |
| Pre-commit hook fails | Shows error, lets user decide |
| Merge conflict markers | Aborts, asks user to resolve |
| Detached HEAD | Warns about state |
| PR already merged | Reports status, takes no action |
| PR has failing checks | Warns, lets user decide to proceed with `--admin` |
| Worktree merge | Skips `--delete-branch`, deletes remote branch separately |

## File Structure

```
skills/git/
├── SKILL.md                        # Skill definition and entry point
├── operations/
│   ├── commit.md                   # Commit workflow details
│   └── merge-pr.md                 # Worktree-aware merge workflow
└── templates/
    └── commit-message.tmpl         # Message structure template
```

## See Also

- [Conventional Commits specification](https://www.conventionalcommits.org/)
- [testing-without-mocks](testing-without-mocks.md) — TDD skill (pairs well with commit-at-green-tests)
- [ci-feedback-loop](ci-feedback-loop.md) — CI monitoring after push
