# Check Operation

Report-only, mechanical health check over the skills estate: detects three classes of
spec-vs-reality drift.

## Billing guard

Interactive `/drift-check` only — no scheduled pass.

## Steps

1. **Locate the repo root** — the script auto-discovers it by walking up from CWD looking
   for `.claude-plugin/plugin.json`; pass an explicit path only if CWD isn't inside the repo.
2. **Run the script**:
   ```
   python3 ${CLAUDE_PLUGIN_ROOT}/skills/drift-check/scripts/drift_check.py [repo_root]
   ```
   This runs all three checks and prints a findings report.
3. **Emit the findings report** to the operator, unmodified from what the script produced (or
   summarized if long) — this skill never edits or fixes anything the checks find.

## What each check detects

- **Unreleased plugin content** — `drift_check.check_unreleased_drift(repo_root)`: finds the
  last commit that changed the `version` line of `.claude-plugin/plugin.json`
  (`last_version_bump_commit`), then lists commits after it touching `skills/**` or
  `.claude-plugin/**` (`unreleased_commits`). Non-empty ⇒ drift; PR numbers are parsed from
  commit subjects where present (the repo's `(#123)` convention).
- **Dangling file references** — `drift_check.check_dangling_references(repo_root)`: scans
  every `skills/*/SKILL.md` and `skills/*/operations/*.md` for high-precision path
  references (`${CLAUDE_PLUGIN_ROOT}/...`, bare backtick `` `skills/...` ``, or bare
  backtick `` `scripts/...` `` resolved relative to the skill's own directory) and checks
  each resolved path exists on disk.
- **Registry mismatches** — `drift_check.check_registry_mismatches(repo_root)`: set-compares
  directories under `skills/` against `.claude-plugin/marketplace.json`'s `skills` array.

## Acceptance criteria

- All three checks run and report findings (or "OK") deterministically.
- The script never edits any file — report-only.
- Unit tests pass (`python3 -m unittest test_drift_check`), including fixtures modeled on
  the three real drift instances found 2026-07-21: unreleased PR content, a dangling
  `SKILL.md` file reference, and a registry/dir mismatch.

## Integration Points

- `drift_check.py` — `${CLAUDE_PLUGIN_ROOT}/skills/drift-check/scripts/drift_check.py`
