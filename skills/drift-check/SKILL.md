---
name: drift-check
description: "Report-only health check that mechanically detects spec-vs-reality drift in the skills estate: merged-but-unreleased plugin content, dangling file references in skill docs, and registry mismatches between skills/ dirs and marketplace.json. Operator-invoked via /drift-check. Findings only — never edits anything it finds. Use to audit the skills estate for drift between what's merged/on-disk and what's released/documented/registered."
argument-hint: "[blank to check the whole skills estate]"
allowed-tools:
  - Read
  - Bash
version: 0.1.1
---

# Drift Check

On-demand, report-only health check over the skills estate itself — the plugin repo's own
spec-vs-reality drift, not the KB (contrast with `kb-lint`, which audits KB notes). Mechanically
detects three classes of drift the plugin can silently accumulate between releases and
between doc edits:

1. **Unreleased plugin content** — commits touching `skills/**` or `.claude-plugin/**` merged
   after the last version-bump commit to `.claude-plugin/plugin.json`. A non-empty result
   means `.claude-plugin/plugin.json`'s version understates what's actually on the branch.
2. **Dangling file references** — a `SKILL.md` or `operations/*.md` doc referencing a
   repo-relative or `${CLAUDE_PLUGIN_ROOT}`-relative path that no longer exists (renamed,
   moved, or deleted without updating the doc that pointed at it).
3. **Registry mismatches** — a directory under `skills/` absent from
   `.claude-plugin/marketplace.json`'s `skills` array, or a registry entry pointing at a
   directory that doesn't exist.

This skill is **report-only**: it never edits or fixes anything it finds. It exists to make
drift visible; the operator (or a follow-up PR) decides what to do about it.

## Billing posture

`/drift-check` is **operator-invoked and interactive** → subscription billing pool. No
scheduled pass (same billing-guard rationale as `/kb-lint`).

## Invocation

```
/drift-check              # check the whole skills estate
```

## Execution

1. Load the operation: `Read(${CLAUDE_PLUGIN_ROOT}/skills/drift-check/operations/check.md)`
2. Execute it (runs the deterministic script, emits the findings report).
3. Emit the findings report. Do not edit anything the checks find — report only.

## Integration Points

- **`drift-check`'s own script** —
  `${CLAUDE_PLUGIN_ROOT}/skills/drift-check/scripts/drift_check.py` (all three checks;
  stdlib-only, zero-dependency, matches `kb-core`'s convention).

## Tests

```
cd skills/drift-check/scripts && python3 -m unittest test_drift_check
```

Stdlib `unittest` (zero-dependency), exercising the real git binary against real fixture
repos — no mocks (matches `kb-lint/scripts/test_kb_lint_git.py`'s convention).

## Known limitations

- Check 2 (dangling references) is deliberately high-precision, not high-recall: it only
  matches backtick-quoted or `${CLAUDE_PLUGIN_ROOT}`-relative paths that contain a `/` and
  end in a real file extension. References inside fenced code blocks, prose without
  backticks, or paths without an extension are not scanned. This trades missed edge cases
  for avoiding false positives across the corpus (same trade-off documented in
  `check-allowed-tools.py`'s R4).
- Bare backtick `` `scripts/...` `` references are ambiguous between a skill's own
  `scripts/` subdirectory and the repo's top-level `scripts/` maintainer tooling — both
  conventions exist in this repo. Both candidates are tried before flagging dangling, so
  this doesn't false-positive, but a reference could in principle resolve to the "wrong"
  one of two files that both happen to exist.
- Placeholder paths inside fenced code blocks (e.g. a `my-skill` shell-snippet example)
  are excluded by the fenced-block skip above, so they no longer false-positive. A
  placeholder in *non-fenced* prose still can — this check has no way to distinguish a
  template placeholder from a real reference outside a fence.
- Check 1 assumes a roughly linear (rebase-merged) history on the checked-out branch,
  matching this repo's convention; it does not attempt merge-commit-specific traversal.

## See Also

- `skills/kb-lint` — the closest sibling (report-only checker, deterministic scripts +
  agent-orchestrated operation doc); audits KB notes rather than the plugin repo itself.
- `skills/kb-core` — the zero-dependency stdlib-only script convention this skill follows.
