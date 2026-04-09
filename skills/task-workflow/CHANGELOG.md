# Changelog

All notable changes to the **task-workflow** skill will be documented in this file.

## [1.2.0] - 2026-02-15

### Added
- Symlink resolution convention in Common Patterns — resolve `~/.claude/` paths via `realpath` before editing to avoid modifying shared symlink targets
- Commands section mapping slash commands to their corresponding operations

**Reasoning**: Editing symlinked files instead of worktree copies caused changes to land in the wrong repository. Documenting the symlink resolution convention prevents this. Source: REC-002 from 202602151458-Lessons-Learned-Symlink-Resolution-Before-Editing.md. Command file location was undocumented, causing unnecessary exploration to find where commands are defined. Source: REC-001 from 202602150121-Lessons-Learned-Init-Workspace-Command.md.

## [1.0.0] - 2026-02-15

### Added
- Initial version tracking

**Reasoning**: Baseline version established to enable skill evolution tracking (pfeff/cursor-rules#36).
