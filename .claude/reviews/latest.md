---
target: PR #87
timestamp: 2026-05-18T15:44:12Z
agents: 4
blocking: 2
advisory: 11
verdict: BLOCKING
---

## Review Summary

**Target**: PR #87 (pfeff/claude-skills)
**Agents**: 4 (security, simplicity, architecture, correctness)
**Verdict**: BLOCKING — 2 issue(s) must be resolved

### Blocking

- **skills/task-workflow/scripts/create-workspace.sh:243** — [security] _path traversal_ — Qualified-form regex `^([a-zA-Z0-9._-]+)/([a-zA-Z0-9._-]+)$` permits `.` and `..` in either segment. `resolve_repo_path "pfeff/.."` matches, builds `$HOME/src/github/pfeff/..` → resolves to `$HOME/src/github`, the `-d` test passes, and the function returns that path. Downstream `basename` → `..`, `worktree_path="$WORKSPACE_PATH/.."`, and `cd "$repo_path"` operates on attacker-chosen paths above the workspace. Reachable from untrusted issue bodies that name `other-owner/other-repo` patterns (per `workspace-from-issue.md` step 4). Fix: reject any segment that equals `.`/`..` or contains `..`, e.g. `[[ "$owner" == *..* || "$repo" == *..* || "$owner" =~ ^\.+$ || "$repo" =~ ^\.+$ ]] && return 1`. Same hardening should apply to the bare-name branch (line 259) since its contract is now publicly documented.

- **skills/task-workflow/scripts/create-workspace.sh:269,920** — [architecture] _layering inconsistency / latent regression_ — This PR widens `resolve_repo_path` to accept qualified `owner/repo` AND updates `workspace-from-issue.md` to emit qualified names, but two downstream call sites still interpolate the raw `$repo` arg instead of `basename "$repo_path"`:
  - `format_repos_list` (line 269): renders `- pfeff/guardian: $WORKSPACE_PATH/pfeff/guardian` in CLAUDE.md, but the actual worktree is at `$WORKSPACE_PATH/guardian`. CLAUDE.md is wrong from day one of the new flow.
  - `create_node_workspace` (line 920): `worktree_path="$WORKSPACE_PATH/$repo"` creates `$WORKSPACE_PATH/pfeff/guardian/` as worktree in node mode, which is broken.

  The PR description acknowledges this as R4 follow-up, but R2 is what introduces qualified `--repos` values from the skill layer, so deferring leaves CLAUDE.md broken and node mode broken from merge onward. Either fix both call sites in this PR, OR gate `workspace-from-issue.md`'s qualified emission until R4 ships.

### Advisory

- **skills/task-workflow/scripts/create-workspace.sh:259** — [security] _path traversal (bare-name branch)_ (warning) — The unqualified regex `^[a-zA-Z0-9._-]+$` still allows `.` and `..`. `for match in ~/src/github/*/".."; do` returns `~/src/github` via the first org match. Pre-existing but now in a function whose contract is publicly documented — tighten alongside the qualified-form fix.

- **skills/task-workflow/scripts/create-workspace.sh:201-219** — [simplicity] _complexity_ (warning) — Inline awk for filtering 15 stop words runs ~18 lines with BEGIN block, associative array, and fallback branch. A `tr ' ' '\n' | grep -vxFf <(printf '%s\n' $stopwords) | head -3 | paste -sd-` pipeline would express the same logic in 2-3 lines. Acceptable awk for the volume, but worth simplifying if the file isn't expected to grow more awk.

- **skills/task-workflow/scripts/create-workspace.sh:215-217** — [simplicity] _over-defensive_ (warning) — The "all tokens are stop words" fallback exists for inputs like `"the and or"` that don't appear in real headlines. Test case at `test-create-workspace.sh:82-83` is synthetic. Empty slug from a degenerate headline is an acceptable failure mode; consider deleting the fallback and the test together (4 lines code, 2 lines test).

- **skills/task-workflow/scripts/test-create-workspace.sh:40-52** — [simplicity, architecture] _premature abstraction + naming_ (warning) — `assert_slug_excludes` is a one-off helper used 3 times in a single test block; the other 4 slug tests use `assert_eq` on the full expected slug, which would work fine here too. Replace with `assert_eq "skills-reference-obsidian" "$slug" "issue #85 example"` and delete the helper (-12 lines, -1 concept). Also: name diverges from sibling style — `test-close-workspace.sh` uses `assert_exit_code`, `assert_stderr_contains` (property-of-thing). The closest fit would be `assert_slug_excludes_word`, or just inline.

- **skills/task-workflow/scripts/create-workspace.sh:243** — [architecture] _API design_ (warning) — Qualified-form regex reuses one character class for owner and repo. GitHub owner rules are stricter (no leading `.`, no `_`, hyphens not at ends) than repo rules. Either tighten to match GitHub's actual rules, or rename the docstring concept from "owner-qualified" to "two-segment form" to keep the abstraction honest. As written, `./bad/repo` or `-foo/bar` get a path-shaped failure rather than clean validation.

- **skills/task-workflow/scripts/create-workspace.sh:1088-1098** — [architecture] _pattern adherence_ (warning) — `BASH_SOURCE`-vs-`$0` dispatcher guard is new to this codebase; sibling scripts under `skills/*/scripts/` do not use it (`close-workspace.sh` is tested via `bash $SCRIPT`, not source). DD4 justifies "bash mirrors `test-close-workspace.sh`" but doesn't justify the sourcing divergence. If this becomes the new test pattern, plan to retrofit siblings; otherwise document the per-script choice in DD4.

- **skills/task-workflow/operations/workspace-from-issue.md:123** — [correctness] _undocumented behavior_ (warning) — "Bare repo names mentioned in code blocks or file paths → default to the issue's owner and pass `<issue-owner>/<repo>`" is new policy beyond R2 ("Skill passes the primary repo to `--repos` in qualified form"). The auto-qualification of *additional* bare repos is plausible but unspecified and untestable (markdown-only). Either add a note to DESIGN.md R2, or drop the directive.

- **DESIGN.md:R3** — [correctness] _spec drift_ (warning) — R3 still lists "Repo resolution prefers `pfeff/` over `Tcetra/` for shared names" as a required test case, but the corrected DD2 says the script holds no owner preference and the test file (correctly) omits this case. Delete the bullet from R3 to keep spec and DD2 aligned; otherwise a future reader treats R3 as authoritative.

- **skills/task-workflow/scripts/test-create-workspace.sh:110-135** — [simplicity] _coverage gap_ (info) — No assertion for the ambiguous-unqualified case (`claude-skills` exists under both `pfeff` and `Tcetra` in the fixture but is never queried). This is the exact scenario R2 motivates. Add `path=$(resolve_repo_path "claude-skills")` and assert it returns *some* path — documents the alphabetical-first behavior as a regression baseline.

- **skills/task-workflow/operations/workspace-from-issue.md:208-281 vs :426-566** — [architecture] _drift risk_ (info) — File has two "Examples" sections and two "Error Handling" tables (Issue Mode and combined Issue+PWD). Duplication is pre-existing; the PR did update both copies for the qualified-form change (good). Recommend consolidating into a single Examples + single Error Handling section grouped by mode to reduce future drift.

- **skills/task-workflow/scripts/create-workspace.sh:198-220** — [correctness, architecture] _conforms_ (info, positive) — Stop-word list complete (15 words, in R1 order), inline per DD3, mirrors existing `SECRETS_CONFIG`/`ENVRC_CONFIG` inline-config pattern. Case-insensitive correct (lowercase before awk filter). Fallback to raw first-3 tokens matches R1 spec exactly.

- **skills/task-workflow/scripts/create-workspace.sh:223-252** — [correctness, architecture] _conforms_ (info, positive) — Qualified-form resolution: matches `^owner/repo$`, resolves to `$HOME/src/github/<owner>/<repo>`, returns 1 if absent (no glob fallback). Conforms to R2 layer 1 (mechanism) and DD1/DD2. Docstring honestly discloses the alphabetical-first behavior of the bare-name fallback as a mechanism-layer property — appropriate disclosure.

- **skills/task-workflow/operations/workspace-from-issue.md:114-130** — [security] _input flow_ (info) — Owner-qualified repo names flow from issue references into `--repos`. The operation does not constrain owner/repo characters beyond what GitHub allows, so untrusted issue bodies (`other-owner/other-repo` scraped from text) reach `create-workspace.sh` and hit the regex. Strengthens the case for the Critical regex fix above.
