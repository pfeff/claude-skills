# Changelog

All notable changes to the **git** skill will be documented in this file.

## [1.2.0] - 2026-02-23

### Added
- Merge strategy resolution in merge-pr operation (Step 2b): explicit input → repo CLAUDE.md `Merge Strategy` convention → GitHub repo settings API → default `--merge`
- `Bash(gh api repos:*)` to allowed-tools for querying repo merge settings

### Changed
- **Breaking**: Default merge method changed from `--squash` to `--merge`. Repos preferring squash should add `Merge Strategy: squash` to their CLAUDE.md.

**Reasoning**: Merge strategy is irreversible and varies by repo. Hardcoding `--squash` caused incorrect merges in repos configured for merge commits (pfeff/cursor-rules#67).

## [1.1.0] - 2026-02-15

### Added
- Branch guard step (Step 1b) in commit operation warns when committing to main/master

**Reasoning**: Committing directly to protected branches prevented PR creation during a session, requiring manual branch creation and cherry-picking. Source: REC-001 from 202602151100-Lessons-Learned-Ralph-Wiggum-Operations-Directory.md.

## [1.0.0] - 2026-02-15

### Added
- Initial version tracking

**Reasoning**: Baseline version established to enable skill evolution tracking (pfeff/cursor-rules#36).
