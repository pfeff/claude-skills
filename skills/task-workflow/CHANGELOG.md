# Changelog

All notable changes to the **task-workflow** skill will be documented in this file.

## [1.9.0] - 2026-07-16

### Added
- `operations/falsification-check.md` — refute-first sub-routine for the synthesis/write boundary: run the single most direct read-only query that would falsify an infra-state claim before writing it down.
- `allowed-tools` frontmatter: declared `Edit`, `Task`, `Skill` — already mandated by existing `dispatch-task.md`, `fan-out.md`, `auto-advance.md`, `init-workspace.md`, and `open-workspace.md` steps but missing from the list, tripping `skill-lint`'s allowed-tools check once this file was touched.

**Reasoning**: Source LL-1 / R1 from `qmd://tcetra/Generated/202605210922-Lessons-Learned-DO-588-Octopus-Investigation.md`. During the DO-588 stack17 RCA, two diagnostic-framing errors required user correction because synthesis happened from one evidence path (GitHub Actions logs / Terraform plan diff) without cross-checking the authoritative read-only API (`aws ec2 describe-instances`).

## [1.8.0] - 2026-07-10

### Added
- `create-workspace.sh --meta --name NAME` — a lightweight, non-task-tree workspace kind at `~/src/work/meta/<name>/`. Auto-seeds a one-line DESIGN.md stub in the same `# ID: Headline` format `close-workspace.sh` already parses, and optionally creates a git worktree per `--repos` entry on branch `meta/NAME`. No CLAUDE.md, `.envrc`, `.claude/settings.json`, or tmuxp session — capability only, no existing dispatch/session is migrated to use it.

**Reasoning**: Two needs fell between the existing `task`/`node` modes (full ceremony) and freehand directories (invisible to `close-workspace.sh`/`list-workspaces` tooling): ephemeral background-agent worktree isolation, and interactive dual-pane session working directories. Both want a tracked, cleanup-participating directory without DESIGN.md-authoring burden, tmuxp requirement, or goal-tree scaffolding.

## [1.7.0] - 2026-06-11

### Added
- Acceptance-criteria lifecycle driving the session end-to-end:
  - init-workspace step 7 "Formalize Acceptance Criteria" — writes a checkable `## Acceptance Criteria` contract (`- [ ] **AC-N**` format) to DESIGN.md before task decomposition; idempotent (IDs never renumbered, boxes never reset)
  - Interview leads with AC confirm/amend; generic section questions only for remaining gaps
  - Task decomposition requires a `Satisfies: AC-N` line per task and an AC coverage check (every AC covered or explicitly deferred)
  - Review gate displays the AC contract above the task list
  - auto-advance step 5a checks off ACs with re-verification evidence as their tracing tasks complete
  - auto-advance step 7a sub-step 0: grep-checkable, deferral-aware AC gate blocks PR creation while any undeferred AC is unchecked; PR body carries the AC checklist; completion summary reports per-AC evidence
- `## Acceptance Criteria` placeholder section in DESIGN.md.tmpl

### Changed
- init-workspace steps 7–12 renumbered to 8–13 (new step 7 inserted); cross-references updated in solution-search.md

**Reasoning**: ACs previously existed only as an extraction hint flattened into prose Requirements — there was no explicit done-contract, the review gate approved implementation steps rather than outcomes, and auto-advance's completion check was purely mechanical (tasks + tests + PR) with nothing verifying the deliverable against criteria. Making the AC contract a first-class checkable artifact lets it drive decomposition, progress tracking, and the completion gate.

## [1.2.0] - 2026-02-15

### Added
- Symlink resolution convention in Common Patterns — resolve `~/.claude/` paths via `realpath` before editing to avoid modifying shared symlink targets
- Commands section mapping slash commands to their corresponding operations

**Reasoning**: Editing symlinked files instead of worktree copies caused changes to land in the wrong repository. Documenting the symlink resolution convention prevents this. Source: REC-002 from 202602151458-Lessons-Learned-Symlink-Resolution-Before-Editing.md. Command file location was undocumented, causing unnecessary exploration to find where commands are defined. Source: REC-001 from 202602150121-Lessons-Learned-Init-Workspace-Command.md.

## [1.0.0] - 2026-02-15

### Added
- Initial version tracking

**Reasoning**: Baseline version established to enable skill evolution tracking (pfeff/cursor-rules#36).
