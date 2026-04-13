# Commit Operation

Creates a git commit with compact, meaningful commit messages.

## Purpose

Stage and commit changes following project conventions: compact messages, conventional commit format, no Claude annotations.

## Inputs

- **files** (optional): Specific files to stage, or all changes if not specified
- **message** (optional): Pre-written commit message, or craft from changes if not provided
- **type** (optional): Conventional commit type (feat, fix, refactor, etc.)

## Implementation Steps

### 1. Resolve Repository Path

Before running git commands, resolve symlinks to find the actual repository:

```bash
# If working with specific files, resolve their actual path
realpath <file> | xargs dirname

# Find the git repository root from that path
git -C <resolved_path> rev-parse --show-toplevel
```

**Common symlink mappings**:
- `~/.claude/` → `~/src/github/pfeff/dotfiles/claude/`
- `${CLAUDE_PLUGIN_ROOT}/skills/` → `~/src/github/pfeff/claude-skills/` (was previously `~/src/github/pfeff/dotfiles/cursor-rules/` submodule — no longer active)

If the resolved path differs from pwd, run all subsequent git commands with `-C <repo_path>`.

### 1b. Branch Guard

Check the current branch before committing:

```bash
CURRENT_BRANCH=$(git -C <repo_path> branch --show-current)
```

If on `main` or `master`, warn the user:

```
⚠️  You are on the '${CURRENT_BRANCH}' branch.
Committing directly to protected branches makes it harder to create PRs for review.

Suggestion: Create a feature branch first:
  git checkout -b <feature-branch>
```

Proceed only if the user explicitly confirms they want to commit to the protected branch.

### 2. Review Current State

Run in parallel:
```bash
git status
git diff --staged
git diff
```

Understand what's changed and what's already staged.

### 2b. Evaluate Commit Readiness

When committing **during implementation** (not when the user explicitly requests a commit of specific files), apply the **Incremental Commits** principle from the git skill core principles. Stage only files related to the logical unit — not `git add .`.

### 3. Stage Changes

**If specific files provided**:
```bash
git add <file1> <file2> ...
```

**If no files specified**:
- Stage relevant changes based on context
- Skip files that likely contain secrets (.env, credentials.json, etc.)
- Warn user if they specifically request to commit secret files

### 4. Craft Commit Message

**If message not provided**, analyze the diff and create compact message:

1. Determine commit type (feat, fix, refactor, docs, test, chore)
2. Write concise headline (50 chars or less)
3. Add 1-2 sentence summary explaining WHY, not WHAT
4. For bug fixes: indicate the specific bug that was fixed
5. Avoid duplicating what's obvious from the diff

**Format**:
```
<type>: <headline>

<1-2 sentence summary>
```

**Guidelines**:
- Headline: imperative mood, no period, lowercase after colon
- Summary: Focus on motivation and context, not implementation details
- Bug fixes: "Fixes incorrect X causing Y" not "Changes X to Y"
- Features: Explain the capability added, not the code changes

### 5. Create Commit

Use HEREDOC for proper formatting:
```bash
git commit -m "$(cat <<'EOF'
<type>: <headline>

<summary sentences>
EOF
)"
```

**NEVER include**:
- "Generated with Claude Code" annotations
- "Co-Authored-By: Claude" lines
- Emoji (unless user explicitly requests)

### 6. Verify Success

```bash
git log -1 --oneline
```

Show user the commit was created successfully.

## Examples

### Bug Fix Commit
```bash
git add init-script.sh
git commit -m "$(cat <<'EOF'
fix: correct AD username variable escaping

The username was rendered without proper quotes, causing AD registration failures.
EOF
)"
```

### Feature Commit
```bash
git add src/auth/oauth.py src/auth/__init__.py
git commit -m "$(cat <<'EOF'
feat: add OAuth2 authentication provider

Enables token-based auth for external API integrations.
EOF
)"
```

### Refactor Commit
```bash
git add src/database/connection.py
git commit -m "$(cat <<'EOF'
refactor: extract connection pool into separate class

Improves testability and makes pool configuration more explicit.
EOF
)"
```

## Edge Cases

| Case | Response |
|------|----------|
| Symlinked files | Resolve symlinks, run git in actual repository |
| No changes to commit | Report "No changes to commit" |
| Secrets in staged files | Warn and ask for confirmation |
| Pre-commit hook fails | Show error, let user decide next steps |
| Merge conflict markers | Abort and ask user to resolve |
| Detached HEAD | Warn user about state |

## Integration Points

- **Conventional Commits**: Uses standard type prefixes
- **User preferences**: Respects CLAUDE.md commit guidelines
- **Pre-commit hooks**: Runs without --no-verify unless explicitly requested
- **Git history**: Checks recent commits for style consistency

## Anti-Patterns to Avoid

❌ **Don't**:
- Include implementation details obvious from diff
- Write paragraphs explaining code changes
- Add Claude attribution annotations
- Use vague messages like "fix bug" or "update code"
- Duplicate the headline in the summary

✅ **Do**:
- Focus on WHY the change was needed
- Be specific about bugs being fixed
- Keep it compact (headline + 1-2 sentences)
- Use conventional commit types
- Make the summary add context not in the diff
