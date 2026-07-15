# Annotation Schema

The self-verify skill writes one file per run:

```
.claude/reviews/self-verify-latest.md
```

The file is overwritten on each run. It is the job's own record and the
operator's review evidence. It is **not** consumed by the lN-review chain
(that chain reads `l1-latest.md` / `l2-latest.md`); self-verify is upstream
of that chain and feeds it by ensuring the job's change is in order before
the L1 reviewer picks it up.

**Not the PR marker.** This schema is a local-file annotation only — it is
never posted to a PR and has its own lowercase `pass|warn|fail` verdict
vocabulary (see "Field rules" below). It is a distinct artifact from the
`<!-- review:metadata -->` / `<!-- l<N>-review:metadata -->` markers that
`/review` and `l1-review`/`l2-review` post to the PR; for that schema —
fields, integer-count types, and posting commands — see the "Marker
emission template" in `../../lN-review-doctrine/references/checklist.md`.
Do not copy this file's shape when composing that marker.

---

## File format

### Frontmatter (YAML, machine-parseable)

```yaml
---
verdict: pass | warn | fail
job_context: <branch name, worktree path, or "working-tree">
diff_target: <git ref range or "working-tree">
task_source: <path to task context file, or "dispatch-prompt">
axes:
  conformance: pass | warn | fail
  process:     pass | warn | fail
  objective:   pass | warn | fail
evidence:
  tests_run:
    - step: <step name>
      command: <command run>
      result: pass | fail | skipped
      detail: <one line — exit code, test count, or error summary>
  review_verdict: CLEAN | BLOCKING | n/a
  review_artifact: .claude/reviews/latest.md | n/a
  scope_check: pass | fail | n/a
blocking: <integer count of blocking findings>
warning: <integer count of warning findings>
annotated_at: <ISO 8601 UTC, e.g. 2026-07-01T12:00:00Z>
annotator: self-verify
---
```

**Field rules:**

- `verdict` is derived from the axis verdicts using the rubric in SKILL.md. It
  is never set manually — always computed.
- `axes.*` values are lowercase `pass`/`warn`/`fail` (distinct from the
  lN-review-doctrine uppercase PASS/FAIL/UNCLEAR — this schema uses lowercase
  to distinguish self-verify artifacts from L1/L2 review artifacts).
- `evidence.tests_run` is a list of every required verification step from the
  work-type map, in the order they ran. Include skipped steps with
  `result: skipped` and a `detail` explaining why.
- `evidence.review_verdict` is the `verdict` field from
  `.claude/reviews/latest.md` after running `/review`, or `n/a` if the repo
  is skills/docs-only with no code to review.
- `evidence.scope_check` is `pass` if no out-of-scope files appear in the
  diff, `fail` if any do, `n/a` if scope is undefined (no task context found).
- `blocking` and `warning` count findings in the body (see below). `info`
  findings are not counted in frontmatter — they appear in the body only.

---

### Body

```markdown
**<VERDICT>** — <blocking> blocking and <warning> advisory finding(s).

## Axis 1 — Conformance

<verdict badge: PASS | WARN | FAIL>

<per-finding entries, or "_no findings_" if none>

## Axis 2 — Process

<verdict badge: PASS | WARN | FAIL>

<per-finding entries, or "_no findings_" if none>

## Axis 3 — Objective Advancement

<verdict badge: PASS | WARN | FAIL>

<per-finding entries, or "_no findings_" if none>
```

### Finding entry format

Each finding in the body:

```yaml
- axis: 1 | 2 | 3
  severity: blocking | warning | info
  category: <short tag, e.g. frontmatter-invalid, scope-mismatch, missing-test, host-leak>
  location: <skills/<name>/SKILL.md or file:line if known, else "change-wide">
  evidence: <one sentence — what was observed>
  recommendation: <one sentence — what should change>
```

**Severity rules** (inherited from lN-review-doctrine):

- `blocking` — correctness failures, security vulnerabilities, data-loss risks,
  and any required verification step that failed with non-zero exit. Anything
  else is `warning` or `info`.
- `warning` — legitimate concern the operator should evaluate; does not
  independently block merge.
- `info` — FYI / follow-up.

---

## Example: PASS annotation

```markdown
---
verdict: pass
job_context: feat/add-noop-skill
diff_target: origin/main...feat/add-noop-skill
task_source: DESIGN.md
axes:
  conformance: pass
  process:     pass
  objective:   pass
evidence:
  tests_run:
    - step: frontmatter-validity
      command: "python3 -c ..."
      result: pass
      detail: "all required fields present: name, description, allowed-tools, version"
    - step: host-agnostic
      command: "HOST_AGNOSTIC_DIRS=skills/example-noop sh scripts/check-host-agnostic.sh"
      result: pass
      detail: "exit 0, no leaks detected"
  review_verdict: n/a
  review_artifact: n/a
  scope_check: pass
blocking: 0
warning: 0
annotated_at: 2026-07-01T10:00:00Z
annotator: self-verify
---

**PASS** — 0 blocking and 0 advisory finding(s).

## Axis 1 — Conformance

PASS

_no findings_

## Axis 2 — Process

PASS

_no findings_

## Axis 3 — Objective Advancement

PASS

_no findings_
```

---

## Example: FAIL annotation (blocking frontmatter defect)

```markdown
---
verdict: fail
job_context: feat/add-broken-skill
diff_target: origin/main...feat/add-broken-skill
task_source: dispatch-prompt
axes:
  conformance: pass
  process:     fail
  objective:   warn
evidence:
  tests_run:
    - step: frontmatter-validity
      command: "python3 -c ..."
      result: fail
      detail: "missing required fields: ['version']"
    - step: host-agnostic
      command: "HOST_AGNOSTIC_DIRS=skills/example-broken sh scripts/check-host-agnostic.sh"
      result: pass
      detail: "exit 0, no leaks detected"
  review_verdict: n/a
  review_artifact: n/a
  scope_check: pass
blocking: 1
warning: 0
annotated_at: 2026-07-01T10:05:00Z
annotator: self-verify
---

**FAIL** — 1 blocking and 0 advisory finding(s).

## Axis 1 — Conformance

PASS

_no findings_

## Axis 2 — Process

FAIL

- axis: 2
  severity: blocking
  category: frontmatter-invalid
  location: skills/example-broken/SKILL.md
  evidence: YAML frontmatter is missing the required `version` field; the skill will not load.
  recommendation: Add `version: <semver>` to the YAML frontmatter.

## Axis 3 — Objective Advancement

WARN

- axis: 3
  severity: info
  category: blocked-by-axis-2
  location: change-wide
  evidence: Axis 2 has a blocking failure; axis 3 objective-advancement cannot be cleanly evaluated until the skill is loadable.
  recommendation: Resolve the frontmatter defect, re-run self-verify.
```
