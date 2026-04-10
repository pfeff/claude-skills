---
target: PR #30 (pfeff/claude-skills)
timestamp: 2026-04-10T17:15:00Z
agents: 4
blocking: 0
advisory: 5
verdict: CLEAN
---

## Review Summary

**Target**: PR #30 — feat(ralph-wiggum): install task in container, generalize feature merge
**Agents**: 4 (security, simplicity, architecture, correctness)
**Verdict**: CLEAN — advisory findings only

### Advisory

- **skills/ralph-wiggum/scripts/.devcontainer/devcontainer.json:6** — [security] _supply chain_ (warning) — New third-party devcontainer feature `ghcr.io/eitsupi/devcontainer-features/go-task:1` is pulled from a personal GHCR namespace (not the official `devcontainers/` org) and uses an unpinned floating tag (`:1`). A compromised or hijacked upstream would execute arbitrary code during container build. Worth pinning to an immutable digest or documenting the trust decision. Note: existing `node:1` and `github-cli:1` features are also unpinned, but those are from the more trusted `devcontainers/` namespace.
- **skills/ralph-wiggum/scripts/run-container.sh:163** — [security] _override surface_ (warning) — The generalized merge `(($ralph[0].features // {}) * (.features // {}))` expands the project-config override surface to all current and future ralph features (project values win on key collision). Not a regression — the prior `//=` form also let project values fully replace ralph defaults — but the additive merge means any future ralph feature is automatically overridable. Consider whether security-critical features should be locked.
- **skills/ralph-wiggum/scripts/run-container.sh:163** — [correctness] _merge edge case_ (info) — jq's `*` is a recursive merge. If a project sets a feature key to a non-object (e.g., `null` or `false` to disable), the merge raises a jq type error (`object and null cannot be multiplied`). Not a regression and unlikely in practice, but worth noting if anyone tries to "disable" a ralph feature this way.
- **skills/ralph-wiggum/scripts/run-container.sh:163** — [security] _nested options_ (info) — Because `*` is recursive, project-supplied nested feature options will deep-merge into ralph's, which could silently enable options ralph did not intend (e.g., `installTools`, `version` overrides). Worth an explicit test case if security-relevant options are ever added.
- **skills/ralph-wiggum/scripts/run-container.sh:161** — [simplicity] _generalization_ (info) — The refactor from hardcoded `//=` lines to the merge expression is a net win: scales to N features without edits, removes coupling between this script and the specific feature list. Smaller diff long-term than adding a third `//=` line. No action needed.

### Correctness check (DESIGN.md acceptance criteria)

- ✓ Criterion 1 (`task --version` succeeds): satisfied — `eitsupi/go-task` is Debian/Ubuntu-compatible and installs to `/usr/local/bin/task`.
- ✓ Criterion 2 (`task lint` / `task test` work): satisfied — binary on PATH for all users including `vscode` remoteUser.
- ✓ Criterion 3 (no manual step): satisfied — declarative feature in devcontainer.json.
- ✓ Criterion 4 (works on rebuild): satisfied — features re-apply on every `devcontainer up` from clean. Verified end-to-end with `--build-no-cache`.

### Architecture

- ✓ `$CLAUDE_PLUGIN_ROOT` convention in README matches established usage in `skills/goal-tree/operations/*.md` and `skills/goal-tree/scripts/*.sh`.
- ✓ Progressive disclosure entry for `scripts/` mirrors how `templates/` is listed in SKILL.md.
- ✓ Version bump aligned across SKILL.md frontmatter and CHANGELOG.
