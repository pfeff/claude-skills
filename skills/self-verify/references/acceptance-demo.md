# Acceptance Demo — self-verify skill

Demonstrates the skill against two sample changes: a known-good change and a
change with a planted defect. The temporary sample files were removed after
recording these results; the working tree contains only the deliverable.

**Run date**: 2026-07-01T18:14:43Z
**Repo**: feat/self-verify-skill worktree of claude-skills
**Annotator**: self-verify v1.0.0 (manual execution following SKILL.md procedure)

---

## Sample 1 — Known Good

### Change description

Added `skills/_test-good/SKILL.md`: a minimal doctrine-only skill with valid
YAML frontmatter (`name`, `description`, `allowed-tools`, `version` all
present), no host-specific content, no cross-skill references, no `Read()`
calls, and no `operations/` directory.

**Task context**: "Add a known-good skill fixture for self-verify acceptance test."

### Verification steps run

| Step | Command | Result | Detail |
|------|---------|--------|--------|
| Item 1 — artifact-path consistency | n/a (no operations/) | PASS | N/A |
| Item 2 — cross-skill reference resolution | `grep -rE '../[a-z]' skills/_test-good/` | PASS | No cross-skill references found |
| Item 3 — frontmatter validity | `python3` frontmatter parse | PASS | All required fields present: name, description, allowed-tools, version |
| Item 4 — files referenced exist | `grep -rE 'Read\(' skills/_test-good/` | PASS | No Read() references |
| Item 5 — no inlined doctrine | inspection | PASS | N/A — no operations/, no doctrine content |
| Item 6 — host-agnostic | `HOST_AGNOSTIC_DIRS=skills/_test-good sh scripts/check-host-agnostic.sh` | PASS | Exit 0 — no absolute paths, no hostname leaks, no private repo slugs |

`/review`: n/a — pure skills/doc change, no code files in diff. `review_verdict: n/a`.

### Annotation produced

```
verdict: pass
axes:
  conformance: pass
  process:     pass
  objective:   pass
blocking: 0
warning: 0
```

**PASS** — 0 blocking and 0 advisory finding(s).

- Axis 1 (Conformance): PASS — task criterion (add a valid skill) attempted; diff
  is within scope; no debris.
- Axis 2 (Process): PASS — all 6 doctrine-class checklist items passed; no code
  review required for doc-only change; no skipped hooks.
- Axis 3 (Objective-Advancement): PASS — change provides a loadable, host-agnostic
  skill fixture; advances the acceptance-test objective with no local-optimum failures.

**Outcome**: good change PASSED with evidence. No false-green risk detected — the
checklist items were mechanically verified, not assumed.

---

## Sample 2 — Planted Defect

### Change description

Added `skills/_test-defect/SKILL.md`: a skill with a missing `version` field
in its YAML frontmatter. All other frontmatter fields (`name`, `description`,
`allowed-tools`) were present. The body describes what is broken so the defect
is intentional and documented.

**Planted defect**: `version:` field absent from YAML frontmatter. Per
lN-review-doctrine Doctrine-class sub-checklist item 3 — SKILL.md frontmatter
validity — this is a **blocking** finding (skill will not load).

**Task context**: "Add a broken skill fixture for self-verify acceptance test."

### Verification steps run

| Step | Command | Result | Detail |
|------|---------|--------|--------|
| Item 1 — artifact-path consistency | n/a (no operations/) | PASS | N/A |
| Item 2 — cross-skill reference resolution | `grep -rE '../[a-z]' skills/_test-defect/` | PASS | No cross-skill references |
| Item 3 — frontmatter validity | `python3` frontmatter parse | **FAIL** | Missing required fields: `['version:']` |
| Item 4 — files referenced exist | `grep -rE 'Read\(' skills/_test-defect/` | PASS | No Read() references |
| Item 5 — no inlined doctrine | inspection | PASS | N/A |
| Item 6 — host-agnostic | `HOST_AGNOSTIC_DIRS=skills/_test-defect sh scripts/check-host-agnostic.sh` | PASS | Exit 0 |

`/review`: n/a — doc-only change. `review_verdict: n/a`.

### Annotation produced

```
verdict: fail
axes:
  conformance: pass
  process:     fail
  objective:   warn
blocking: 1
warning: 0
```

**FAIL** — 1 blocking and 0 advisory finding(s).

- Axis 1 (Conformance): PASS — task criterion (add a skill fixture) attempted; diff
  within scope.
- Axis 2 (Process): **FAIL** — doctrine-class item 3 (SKILL.md frontmatter
  validity) returned a blocking failure:
  ```
  - axis: 2
    severity: blocking
    category: frontmatter-invalid
    location: skills/_test-defect/SKILL.md
    evidence: YAML frontmatter missing required `version` field; the skill will not load.
    recommendation: Add `version: <semver>` to the YAML frontmatter.
  ```
- Axis 3 (Objective-Advancement): WARN — axis 2 blocking failure means the skill
  is non-functional; cannot confirm objective advancement of a non-loadable skill.

**Specific reason flagged**: `skills/_test-defect/SKILL.md` is missing the
`version` frontmatter field — a blocking finding under doctrine-class item 3.

**Outcome**: defect CAUGHT. The skill correctly identified the specific field
missing and labeled the finding as blocking (not a mere advisory). The good
change was not false-greened — both results are supported by mechanically-run
checks, not eyeball inspection.

---

## False-green risk assessment

The current procedure has one bounded false-green risk: if a `DESIGN.md`/task
context is absent or vague, Axis 1 (Conformance) and Axis 3 (Objective
Advancement) degrade to `warn` rather than `fail`. The "never collapse UNCLEAR
to pass" invariant from lN-review-doctrine is the guard — the skill produces
`warn` not `pass` in this case. A human operator reading a `warn` verdict must
still evaluate the ambiguous axes before accepting the work.

No false-green was produced in either sample run.
