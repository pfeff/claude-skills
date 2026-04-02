# Changelog

All notable changes to the **ralph-wiggum** skill will be documented in this file.

## [1.3.0] - 2026-03-03

### Added
- Multi-repo workspace support: workspace manifest, per-repo gates, `[repo-name]` task annotations
- End-to-End Flow section in SKILL.md documenting operation orchestration
- Prerequisites section in SKILL.md
- Output and Error Handling sections to both operations

### Fixed
- Template path references in scaffold-project.md (PROMPT files are at skill root, not templates/)
- Placeholder syntax consistency: all inline examples now use `{{double_braces}}` matching template files
- Branch name variable aligned between scaffold-project.md and workspace.md template

**Reasoning**: Review found critical path errors and structural gaps vs ci-feedback-loop exemplar. Source: pfeff/cursor-rules#16.

## [1.2.0] - 2026-02-28

### Changed
- Moved "Files Created" table to `operations/scaffold-project.md`
- Moved "Environment Requirements" to `references/environment.md`
- Added Progressive Disclosure section to SKILL.md

**Reasoning**: Align SKILL.md with standard format from SKILL_DEVELOPMENT.md. Non-operation details moved to operation docs and references for proper progressive disclosure. Source: pfeff/cursor-rules#17.

## [1.1.0] - 2026-02-15

### Added
- Environment requirements table with check commands and common issues
- Pre-flight check snippet for loop.sh

**Reasoning**: Loop iterations failed silently due to missing or expired Claude CLI authentication. Documenting prerequisites and adding pre-flight checks prevents wasted iterations. Source: REC-003 from 202601201630-Lessons Learned - Ralph Loop Test Side Quest.md.

## [1.0.0] - 2026-02-15

### Added
- Initial version tracking

**Reasoning**: Baseline version established to enable skill evolution tracking (pfeff/cursor-rules#36).
