# Submodule Workflows

Patterns for working with git submodules safely and effectively.

## Detached HEAD Risk

Submodules commonly end up in detached HEAD state after:
- `git clone --recursive`
- `git submodule update`
- dotbot/dotfiles installation

**Problem**: In detached HEAD state, content from main branch may not be visible. New files created in this state are easily lost or lead to duplicates when main is checked out.

**Symptoms**:
- `git status` shows "HEAD detached at <commit>"
- Files you expect to exist are missing
- Creating "new" content that already exists on main

## Sync-Before-Work Pattern

Before creating or modifying content in a submodule:

```bash
cd <submodule-directory>

# Check current state
git status

# If detached or behind, sync to main
git checkout main && git pull origin main
```

**When to apply**:
- Before creating new files in submodule
- Before starting work session on submodule content
- After running dotfiles/dotbot install

## Submodule Update Commands

```bash
# Initialize submodules (after clone)
git submodule update --init --recursive

# Update submodules to latest commit tracked by parent
git submodule update --recursive

# Update submodules to latest remote (may advance beyond parent's tracked commit)
git submodule update --remote --merge
```

## Committing Submodule Changes

When you modify content inside a submodule:

1. **Commit inside submodule first**:
   ```bash
   cd <submodule>
   git add .
   git commit -m "feat: add new feature"
   git push
   ```

2. **Update parent repo's submodule reference**:
   ```bash
   cd <parent-repo>
   git add <submodule-path>
   git commit -m "chore: update submodule reference"
   ```

## Common Issues

### "Changes not staged" for submodule

Parent repo shows submodule as modified but you haven't changed it:
```bash
# Check what changed
git diff <submodule-path>

# If just commit pointer moved, update or reset
git submodule update <submodule-path>
```

### Lost work in detached HEAD

If you committed while detached:
```bash
# Find the commit
git reflog

# Cherry-pick to main
git checkout main
git cherry-pick <commit-sha>
```

## Best Practices

1. **Always check state** before working: `git status`
2. **Stay on main** when making changes
3. **Commit and push** submodule changes before updating parent
4. **Pull submodule updates** when switching branches in parent
