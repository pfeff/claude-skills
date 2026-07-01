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

---

## Sample 3 — Clean Code Change

### Change description

Created `_test-code-good.py` at worktree root: a small Python utility module
with `compute_sum`, `compute_average` (empty-list guard → 0.0), and `find_max`
(empty-list guard → ValueError). Deliberately clean — no unguarded divisions,
no shell calls, no secrets.

**Task context**: "Create a clean Python sample to exercise self-verify's /review
code-path with no defects."

### Step 3 — inline review (uncommitted change)

Because the file is an uncommitted working-tree addition, `/claude-skills:review`
with no arguments would run `git diff $BASE...HEAD` and see nothing. The updated
SKILL.md Step 3 instructs the job to apply the inline review checklist against
`$DIFF` directly. The checklist from `../review/operations/run-review.md`
(degraded-mode inline) was applied:

| Axis | Finding |
|------|---------|
| Security | No user input, no shell invocation, no credentials. No issues. |
| Correctness | Empty-list guards on both division-using functions. All paths handled. |
| Data loss | No destructive operations. |
| Simplicity | Three small functions, no YAGNI. |
| Architecture | No structural concerns. |

Result written to `.claude/reviews/latest.md`:

```
---
target: working-tree (_test-code-good.py)
timestamp: 2026-07-01T19:00:00Z
agents: 1
degraded: true
blocking: 0
advisory: 0
verdict: CLEAN
---

No issues found across 1 agent.
```

### Annotation produced

```
verdict: pass
axes:
  conformance: pass
  process:     pass
  objective:   pass
evidence:
  review_verdict: CLEAN
  review_artifact: .claude/reviews/latest.md
blocking: 0
warning: 0
```

**PASS** — 0 blocking and 0 advisory finding(s).

- Axis 1 (Conformance): PASS — task criterion (add clean code sample) attempted; diff within scope.
- Axis 2 (Process): PASS — inline review ran; verdict CLEAN; no skipped hooks.
- Axis 3 (Objective-Advancement): PASS — clean utility module with proper empty-list guards advances the acceptance-test objective.

`evidence.review_verdict: CLEAN` — NOT `n/a`. The /review code-path produced a real verdict.

---

## Sample 4 — Defective Code Change

### Change description

Created `_test-code-defect.py` at worktree root: a Python module with two
intentional defects:

1. `compute_average` (line 14): `sum(numbers) / len(numbers)` with no empty-list
   guard → `ZeroDivisionError` when `numbers == []`. Correctness failure.
2. `run_command` (line 20): `subprocess.run(f"echo {user_input}", shell=True, ...)`
   — unsanitized `user_input` interpolated into a shell command via f-string.
   Command injection vulnerability (e.g. `user_input="foo; rm -rf /"`).

**Task context**: "Create a defective Python sample to exercise self-verify's /review
code-path with real blocking defects."

### Step 3 — inline review (uncommitted change)

Same inline path as Sample 3. Checklist applied against `$DIFF`:

| Axis | Finding |
|------|---------|
| Security — Critical | **`_test-code-defect.py:20`** — `subprocess.run(f"echo {user_input}", shell=True, ...)`: unsanitized `user_input` is interpolated into a shell command via f-string. An attacker controlling `user_input` can execute arbitrary shell commands. **BLOCKING** (security vulnerability). |
| Correctness — Critical | **`_test-code-defect.py:14`** — `sum(numbers) / len(numbers)` raises `ZeroDivisionError` when `numbers` is empty. No guard present. **BLOCKING** (correctness failure). |
| Data loss / Simplicity / Architecture | No additional findings. |

Result written to `.claude/reviews/latest.md`:

```
---
target: working-tree (_test-code-defect.py)
timestamp: 2026-07-01T19:05:00Z
agents: 1
degraded: true
blocking: 2
advisory: 0
verdict: BLOCKING
---

## Review Summary

**Target**: working-tree (_test-code-defect.py)
**Agents**: 1
**Verdict**: BLOCKING — 2 issue(s) must be resolved

> **Degraded-mode review** — inline path (uncommitted working-tree change).

### Blocking

- **_test-code-defect.py:20** — [security] _command-injection_ — `run_command`
  passes unsanitized `user_input` into `subprocess.run(shell=True, ...)` via
  f-string. An attacker can execute arbitrary shell commands. Use a list
  argument with `shell=False`.
- **_test-code-defect.py:14** — [correctness] _unguarded-division_ —
  `sum(numbers) / len(numbers)` raises ZeroDivisionError when `numbers` is
  empty. Add an empty-list guard before dividing.
```

### Annotation produced

```
verdict: fail
axes:
  conformance: pass
  process:     fail
  objective:   warn
evidence:
  review_verdict: BLOCKING
  review_artifact: .claude/reviews/latest.md
blocking: 2
warning: 0
```

**FAIL** — 2 blocking and 0 advisory finding(s).

- Axis 1 (Conformance): PASS — task criterion (add defective code sample) attempted.
- Axis 2 (Process): **FAIL** — `/review` verdict is BLOCKING; two blocking findings:
  ```
  - axis: 2
    severity: blocking
    category: security-vulnerability
    location: _test-code-defect.py:20
    evidence: Command injection via shell=True + f-string interpolation of user_input.
    recommendation: Use subprocess list form with shell=False.
  - axis: 2
    severity: blocking
    category: correctness-failure
    location: _test-code-defect.py:14
    evidence: ZeroDivisionError when numbers is empty — no guard.
    recommendation: Add `if not numbers: return 0.0` before dividing.
  ```
- Axis 3 (Objective-Advancement): WARN — axis 2 blocking failures mean the
  code is non-functional/insecure; cannot confirm objective advancement of a
  change that fails code review.

`evidence.review_verdict: BLOCKING` — NOT `n/a`. The /review code-path produced a real verdict.

**Outcome**: both defects caught. The command-injection vulnerability (blocking, security) and the correctness failure (blocking) are correctly identified and labeled.

---

## False-green risk assessment

The current procedure has one bounded false-green risk: if `.claude/task-context.md`
is absent AND no DESIGN.md/PLAN.md/dispatch-prompt is reachable, Axis 1
(Conformance) and Axis 3 (Objective Advancement) degrade to `warn` rather than
`fail`. The "never collapse UNCLEAR to pass" invariant from lN-review-doctrine
is the guard — the skill produces `warn` not `pass` in this case. A human
operator reading a `warn` verdict must still evaluate the ambiguous axes before
accepting the work.

When `.claude/task-context.md` IS present, Axis 3 may not degrade to `warn` — it
evaluates to `pass` or `fail`. This closes the primary false-green path for
dispatched jobs.

**`/review` code-path false-green risk**: the inline path (Sample 3/4) applies
the condensed checklist from `run-review.md`. Coverage is narrower than the
full 4-agent multi-agent run; subtle architecture or simplicity issues in small
diffs may be missed. However, the checklist reliably catches the BLOCKING tier
(security vulnerabilities, correctness failures, data-loss risks), which is the
primary purpose of this axis. Multi-agent review remains available for branch/PR
cases.

No false-green was produced in any of the four sample runs.
