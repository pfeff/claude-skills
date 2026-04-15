# Changelog

All notable changes to the **ralph-wiggum** skill will be documented in this file.

## [1.5.0] - 2026-04-14

### Removed
- `generate_merged_config` function from `run-container.sh`. With Docker MCP, the editor container always uses the Ralph generic image — project devcontainers define test images only. The merge logic (feature injection, postCreateCommand append, remoteUser override, runArgs merge) was dead code.

**Reasoning**: D.3.4 (autoresearch). Project devcontainer merging was designed for a world where Ralph ran inside project-specific containers. Docker MCP changed the architecture: editor containers are always Ralph's generic image. Source: autoresearch tree #5, node D.3.4.

## [1.4.0] - 2026-04-10

### Added
- `ghcr.io/eitsupi/devcontainer-features/go-task` devcontainer feature so `task <target>` works inside the Ralph sandbox. Closes the gap surfaced by C.2.1 where container dispatch used Taskfile as the standardized repo interface but the binary was missing. **Pinned to digest** `sha256:8a6c4b4f9d7559f32400da0c11d1bb11e59732f47f7db5defca68e7712544d13` (feature v1.0.4, installs `task` 3.49.1) so a compromised upstream cannot silently swap out the install at container build time.
- `run-container.sh` now warns to stderr when a project's `.devcontainer/devcontainer.json` overrides any ralph feature key. Project values still win on collision (so legitimate options like `node.version` keep working) — the warning surfaces the override so operators see when a ralph default has been swapped out.

### Changed
- `run-container.sh` feature merge generalized: instead of hand-listing `node` and `github-cli`, it now does an additive merge of all ralph features into the project's `.features` (project values win on collision). Future ralph features propagate without per-feature touch-ups. Non-object project values (e.g., `null`/`false` to "disable" a feature) are coerced to `{}` so jq's recursive merge does not error.
- README invocation paths updated to use `$CLAUDE_PLUGIN_ROOT/skills/ralph-wiggum/scripts/run-container.sh` (the in-tree migration done in 1.3.x left the README pointing at the old `scripts/ralph/` path).

**Reasoning**: C.2.6 (autoresearch). DESIGN.md asked for `task` in the Ralph container; validated end-to-end with the digest-pinned go-task feature: `task --version` returns 3.49.1 in a clean container and survives a `--build-no-cache` rebuild. Digest pin and override warning address the supply-chain and override-surface advisories from the PR review. Source: autoresearch tree #5, node C.2.6.

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
