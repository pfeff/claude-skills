---
name: self-verify
description: Self-verification capability for dispatched jobs. Before reporting "done," a job invokes this skill to check its own change against the 3-axis review doctrine (Conformance / Process / Objective-Advancement) by composing existing review tooling and tests, then emits a structured annotation artifact. The annotation is evidence for the operator's review — not a gate, not a blocker.
allowed-tools:
  - Bash
  - Read
  - Grep
  - Write
  - Task
version: 1.0.0
---

# self-verify — job self-verification + annotation

A dispatched job invokes this skill **before** reporting "done." The skill runs
the job's own change through the 3-axis doctrine by composing existing review
tooling and tests, then writes a structured annotation to
`.claude/reviews/self-verify-latest.md`. The operator's review session reads
this artifact as evidence rather than trusting a bare "done."

This skill is an **annotation producer only**. It does not gate, block, merge,
open PRs, or integrate with any queue.

## When to invoke

Invoke at the end of the job's work, after all changes are made but before
sending the "done" signal to the operator. Typical trigger: "I've made the
changes, now let me verify before reporting."

## Inputs

Gather these before starting the verification procedure:

| Input | How to obtain |
|-------|---------------|
| Diff of the job's changes | `git diff HEAD` (uncommitted) or `git diff <base>...<branch>` |
| Task context | Read the task description in priority order: `DESIGN.md` in the workspace → `PLAN.md` → dispatch prompt → PR description |
| Acceptance criteria | Extract from the task context above |
| Repo root | Working directory or `--worktree <path>` if operating remotely |

## Procedure

### Step 1 — Get the diff

```bash
# Uncommitted changes:
git diff HEAD

# Branch vs base (for a completed feature branch):
git diff $(git merge-base HEAD origin/main)...HEAD
```

Store as `$DIFF`. If the diff is empty, write an annotation with
`verdict: warn` and note `no changes detected — nothing to verify`.

### Step 2 — Identify work type and run required verification

Detect the work type from the diff's changed file extensions (same detection
logic as the lN-review-doctrine verification map). See
`../lN-review-doctrine/SKILL.md` for the full map; summary of the most common
cases:

| Work type | Signal | Required steps |
|-----------|--------|----------------|
| Claude skills | `**/skills/**`, `**/commands/**` | Doctrine-class sub-checklist (see below) |
| Go | `*.go`, `go.mod` | `go build ./...`, `go test ./...`, `golangci-lint run` |
| Python | `*.py`, `pyproject.toml` | `ruff check`, `pytest` (or repo runner), `mypy` if configured |
| Terraform | `*.tf`, `*.tfvars` | `terraform fmt -check`, `terraform validate` |
| Markdown/docs only | `*.md` only | `markdownlint` if configured; otherwise no required step |
| Mixed | Multiple patterns match | Union of all required steps |

For **Claude skills** (doctrine-class), run the following sub-checklist. Each
item that fails becomes a finding in the annotation:

1. **Artifact-path consistency** (blocking) — For every cross-skill
   producer/consumer pair, verify the producer writes to the path the consumer
   reads. Grep both directions. If no operations/ directory exists in the
   changed skill, this item is N/A.
2. **Cross-skill reference resolution** (warning) — Every `../<skill>/...`
   link in SKILL.md and `references/<file>.md` links in operations must resolve
   to an existing path.
3. **SKILL.md frontmatter validity** (blocking) — YAML frontmatter must parse
   and declare `name`, `description`, `allowed-tools`, `version`. Command:
   ```bash
   python3 -c "
   import sys; content = open('skills/<name>/SKILL.md').read()
   parts = content.split('---', 2)
   fm = parts[1] if len(parts) >= 3 else ''
   missing = [f for f in ['name:','description:','allowed-tools:','version:'] if f not in fm]
   print('FAIL:', missing) if missing else print('PASS')
   "
   ```
4. **Files referenced exist** (warning) — Every `Read(...)` / `Read: <path>`
   reference in operations must point at an existing file.
5. **No inlined doctrine** (warning) — Doctrine-only skills own the rules;
   executor skills must reference, not duplicate.
6. **Host-agnosticism** (blocking) — Run the repo's guardrail:
   ```bash
   HOST_AGNOSTIC_DIRS="skills/<name>" sh scripts/check-host-agnostic.sh
   ```
   Require exit 0. Any hit is a blocking finding.

Record which steps ran and their results as `evidence.tests_run` in the
annotation.

### Step 3 — Compose /review for code-level findings

Run the repo's `/review` skill against the diff to collect L0 per-line
code-level findings (security, simplicity, architecture, correctness). This
is evidence for Axis 2 — do not duplicate the review logic here.

For a branch:
```
/claude-skills:review <branch-or-PR>
```

For uncommitted working-tree changes, use the degraded inline path (the review
skill handles this when the diff is passed without a PR number). Read the
resulting `.claude/reviews/latest.md` after the run.

Store the review verdict (`CLEAN` / `BLOCKING`) in `evidence.review_verdict`.
If the review produces a `BLOCKING` verdict, that is a blocking finding in
Axis 2.

**If the repo has no code files** (pure skills/doc change), the review skill
will report no findings. Record `review_verdict: n/a` and note the reason.

### Step 4 — Evaluate the three axes

Using the definitions from `../lN-review-doctrine/SKILL.md`:

#### Axis 1 — Conformance

Does the diff match the task the job was given?

- Is every named acceptance criterion attempted?
- Is the diff within scope (no out-of-scope files touched)?
- Is there obvious WIP/debugging debris (console.log, commented-out code)?
- Minimality: does the diff add the least surface that meets the criteria?

Verdict: `pass` if all criteria attempted + in scope. `fail` if any criterion
unattempted or diff is materially out of scope. `warn` for ambiguous scope.

#### Axis 2 — Process

Did the job follow the required process?

- Required verification steps from Step 2 ran and passed.
- `/review` (Step 3) produced a non-BLOCKING verdict.
- No forced workarounds (skipped hooks, `--no-verify`, `--force`).

Verdict: `pass` if all required steps ran green. `fail` if any required step
failed or was skipped. `warn` if a step could not be evaluated (missing
artifact).

#### Axis 3 — Objective Advancement

Does the change make forward progress on the operator's objective?

Read the objective from (first hit wins):
1. `GOAL.md` in the workspace.
2. Project `CLAUDE.md` Objective / Task section.
3. Dispatch prompt / task description.

Checks:
- Does the work product close or advance acceptance criteria of the parent
  objective?
- Does it introduce a local-optimum failure (satisfies local task but breaks a
  broader property the operator needs)?
- Would the work product pass an L1 review if one were run?

Verdict: `pass` if forward progress + no local-optimum failures. `fail` if
it regresses the parent objective or introduces a known-bad local optimum.
`warn` when the objective is unreadable — surface as ambiguity, never
collapse to `pass`.

### Step 5 — Compute overall verdict and write annotation

Apply the verdict rubric from lN-review-doctrine:

| Condition | Verdict |
|-----------|---------|
| Any axis `fail` with any `blocking` finding | `fail` |
| Any axis `fail` with no `blocking` finding | `warn` |
| All axes `pass`, no `blocking` findings | `pass` |
| Any axis `warn`, no axis `fail` | `warn` (never collapse to `pass`) |

Write the annotation to `.claude/reviews/self-verify-latest.md`. See
`references/annotation-schema.md` for the exact format.

```bash
mkdir -p .claude/reviews
# write .claude/reviews/self-verify-latest.md (see annotation-schema.md)
```

After writing, display the annotation body to the operator (without
frontmatter) and then stop. Do not open PRs, merge, or take further action.

## What this skill does NOT do

- Does not gate or block the operator from proceeding.
- Does not open, comment on, or merge PRs.
- Does not integrate with a queue or coordinator.
- Does not re-implement review logic — it composes `/review` and the
  doctrine-class checklist.
- Does not write to any path other than `.claude/reviews/self-verify-latest.md`.

## References

- `references/annotation-schema.md` — the annotation file format
- `references/acceptance-demo.md` — acceptance test results (two sample runs)
- `../lN-review-doctrine/SKILL.md` — 3-axis doctrine and verification map
- `../review/SKILL.md` — the `/review` skill this composes for code-level findings
