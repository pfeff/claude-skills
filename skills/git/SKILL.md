---
name: git
description: Git usage patterns and conventions. Use when the user requests commits or git operations. Enforces compact commit messages (headline + 1-2 sentences), conventional commit format, no Claude annotations, and focuses on WHY not WHAT in summaries.
allowed-tools:
  - Bash(git status:*)
  - Bash(git diff:*)
  - Bash(git log:*)
  - Bash(git show:*)
  - Bash(git rev-parse:*)
  - Bash(git branch:*)
  - Bash(git remote:*)
  - Bash(git config --get:*)
  - Bash(git ls-files:*)
  - Bash(git describe:*)
  - Bash(git rev-list:*)
  - Bash(git cat-file:*)
  - Bash(git worktree list:*)
  - Bash(git fetch:*)
  - Bash(git pull:*)
  - Bash(gh pr view:*)
  - Bash(gh pr merge:*)
  - Bash(gh api repos:*)
version: 1.2.0
---

# Git Skill

Encapsulates preferred git usage patterns and conventions.

## Core Principles

**Incremental Commits**: Commit at logical boundaries during implementation

| Commit when... | Don't commit when... |
|----------------|---------------------|
| Logical unit complete (model, service, component) | Small part of a larger unit |
| Tests pass + meaningful progress | Tests failing |
| About to switch contexts (backend → frontend) | Purely scaffolding with no behavior |
| About to attempt risky/uncertain changes | Would need a "WIP" commit message |

Heuristic: "Can I write a meaningful commit message? If yes, commit. If I'd write 'WIP', keep working."

**Commit Messages**: Keep compact and meaningful
- Headline + 1-2 sentence summary maximum
- Avoid duplicating what's obvious from the diff
- For bug fixes: indicate the specific bug that was fixed
- Use conventional commit format (feat, fix, refactor, docs, etc.)
- NO "Generated with Claude" or "Co-Authored-By" annotations

## Operations

### Committing Changes

**When**: User requests a commit or asks to save work to git.

**Implementation**: Load `operations/commit.md` for detailed steps.

**Quick summary**: Stage changes, craft compact commit message, create commit.

### Merging Pull Requests

**When**: User requests merging a PR, especially from a worktree context.

**Implementation**: Load `operations/merge-pr.md` for detailed steps.

**Quick summary**: Resolve merge strategy (explicit input → repo CLAUDE.md `Merge Strategy` → GitHub repo settings → default `--merge`), detect worktree context, merge without `--delete-branch` in worktrees to avoid checkout failure, delete remote branch separately.

### Creating Pull Requests

**When**: User requests a PR for the current branch.

**Implementation**: Inline — PR creation is a single command, no progressive disclosure needed.

```bash
gh pr create --title "..." --body "..."
```

**Quick summary**: Create PR via GitHub CLI with compact title and structured body.

## Commit Message Format

```
<type>: <headline>

<1-2 sentence summary explaining why, not what>
```

**Types**:
- `feat`: New feature
- `fix`: Bug fix
- `refactor`: Code restructuring without behavior change
- `docs`: Documentation only
- `test`: Test additions or modifications
- `chore`: Maintenance tasks

**Examples**:

Good:
```
fix: correct AD username rendering in init script

The username variable was incorrectly escaped, causing registration failures.
```

```
feat: add OAuth2 support for API authentication

Enables token-based auth for external integrations.
```

Bad (too verbose):
```
fix: fixed the bug where the AD username was being rendered incorrectly

This commit fixes the issue where the AD username variable in the init script
was being rendered with incorrect escaping, which was causing the servers to
fail to register with Active Directory and subsequently fail all downstream
initialization steps.
```

## Progressive Disclosure

Load only what you need:

- `operations/commit.md` - Commit workflow implementation
- `operations/merge-pr.md` - Worktree-aware PR merge

## See Also

- User's global CLAUDE.md for commit conventions
- Conventional Commits specification
