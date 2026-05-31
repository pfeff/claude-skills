---
name: lN-review-doctrine
description: Shared doctrine reference for L{N}-review skills (l1-review, l2-review). Holds the 3-axis checklist (Conformance, Process, Objective Advancement), the work-type → required-verification map consumed by axis 2, the finding/verdict schema, and the self-PR posting caveat. This skill has no operations — it is reference content read by `/l1-review` and `/l2-review` at review time. Never inline this doctrine into the l1-review or l2-review skills themselves — operator-confirmed rules must persist in one place.
allowed-tools:
  - Read
version: 1.0.0
---

# lN-review-doctrine — shared L{N}-review doctrine

This skill is a **doctrine-only reference**. It defines what L{N}-review *is*,
regardless of N. The actual review skills (`l1-review`, `l2-review`) are thin
executors that load this doctrine at review time and apply it at their layer.

All the doctrine lives in this file's body so it is deliverable by name (invoke
the skill; the rendered body enters context). If you find yourself about to add a
rule by editing a review skill, **edit this file instead** — that is the
doctrine-drift failure mode this split exists to prevent.

## Invariants

L{N}-review **never re-runs** `/review`. Code-level correctness, security,
simplicity, and architecture review is L0's `/review` job; the L{N}-review skill
consumes its output artifact (`.claude/reviews/latest.md`) as evidence for axis 2.

L{N}-review **always evaluates against L{N}'s parent objective**, not L{N-1}'s
task description. This is the recursive lever; see axis 3 below for what to read to
determine L{N}'s objective.

---

## Role

You are the L{N}-review evaluator. Your job: take a single work product (typically
a PR, but it can be a sign-off action or a goal-tree node completion) produced by
L{N-1}, evaluate it on three axes, emit a structured verdict, and write the
verdict to `.claude/reviews/l<N>-latest.md`.

You are **not** L0's `/review`. You do not read the diff line-by-line for
code-level correctness, security, simplicity, or architecture. That work is L0's
`/review` — you consume its output as evidence for axis 2, you do not duplicate it.

You are **not** L{N-1}. You are evaluating L{N-1}'s output against L{N}'s parent
objective, which is broader than L{N-1}'s task.

## The three axes

Every L{N}-review walks these three axes, in order. Each axis returns one of
`PASS` / `FAIL` / `UNCLEAR`, plus zero or more findings.

### Axis 1 — Conformance

**Question**: Does the work product match the task L{N} handed to L{N-1}?

**Inputs**:
- The task description L{N-1} was given (goal-tree node summary, workspace
  DESIGN.md, dispatch prompt, or PR description).
- The diff / artifact under review (`gh pr diff <PR>` or equivalent).

**Checks**:
- Is the diff *within scope*? Files outside the named scope, or files inside scope
  that were not touched, are flagged.
- Does the diff *attempt* every named acceptance criterion? Missed criteria are
  FAIL; partial attempts with TODOs are UNCLEAR.
- Are there obvious wrong-file / abandoned-WIP / leftover-debugging signatures?
  (e.g. `console.log`, `dbg!`, commented-out code unrelated to the task.)
- **Minimality** (maintained surface is a cost): among ways to meet the objective,
  does the diff add the *least* surface (net lines, rules, files, branch points)?
  Three sub-checks, each a `surface-bloat` finding when it fails:
  - **Least surface that meets the objective.** Extra rules, files, or branch
    points beyond what the criteria require — flag the excess. Surface is a
    tiebreaker only; never demand a cut that regresses function (that is an axis-3
    concern, not axis 1).
  - **Pointer over inline (DRY).** Could added doctrine reference an existing home
    instead of duplicating it? This reinforces verification-map sub-checklist item
    5 (no inlined doctrine in consumer skills) and the doctrine/rationale split —
    do not re-derive a rule that already has a home.
  - **Dead surface.** Is anything added that nothing references or applies — a rule
    no path triggers, code no caller hits, doctrine no skill reads? Flag for
    deletion rather than merge.
- **Documentation Impact (Diataxis)**: PLAN.md (or the task's dispatch brief, if no
  PLAN.md exists) is expected to declare a structured "Documentation Impact" block
  per Diataxis quadrant. For each quadrant the PLAN claimed a doc would be updated,
  the diff must include the corresponding change. See the "Documentation Impact
  (Diataxis) schema" sub-section below for the block shape, quadrant defaults, and
  finding categories.

**Verdict rule**: PASS if every named criterion is attempted AND the diff is within
scope AND the Documentation Impact discipline holds (per phased severity below).
FAIL if any criterion is unattempted, the diff is materially out of scope, OR a
load-bearing **Explanation**-quadrant doc was claimed-but-not-shipped. UNCLEAR for
ambiguous scope boundaries. `surface-bloat` findings are `warning`/`info` (surface
is a tiebreaker, never blocking) — they surface an UNCLEAR axis-1 → NEEDS-WORK,
prompting a smaller revision, but never gate on surface at the cost of function.

### Documentation Impact (Diataxis) schema

PLAN.md (or the task's dispatch brief, if no PLAN.md exists) declares affected docs
structured by Diataxis quadrant. The discipline is the **deliberate answer per
quadrant**; "N/A in all four" is a valid declaration for trivial fixes — absence of
the block is itself a finding.

Expected block shape:

```markdown
## Documentation Impact
- **Tutorial**: <doc path> | N/A
- **How-to**: <doc path> | N/A
- **Reference**: <doc path> | N/A
- **Explanation**: <doc path> | N/A
```

**Quadrant defaults the reviewer applies** when judging whether a PLAN.md's N/A
answer was plausible:

| Work type | Default quadrant(s) |
|-----------|---------------------|
| Architectural decision, state-model / contract change | **Explanation** (ADR or `DESIGN.md` DD entry) |
| New public surface (CLI command, API endpoint, infra tier) | **Reference + How-to** |
| Pattern extension (adopting another resource into an existing import block; adding a sibling to a known structure) | **Reference** at the pattern-defining file |
| Bug fix, lint cleanup, pure refactor with no behavior change | Typically 4×N/A — but if the bug exposed a documentation gap, that becomes an **Explanation** entry |
| New review/process discipline, new doctrine | **Explanation** + **How-to** + sometimes **Reference** |

**Findings**:

| Category | Severity | When |
|----------|----------|------|
| `docs-block-missing` | `info` (initial rollout) → `warning` (after habituation) | PLAN.md exists but lacks the structured block. Phased: log as `info` during initial adoption so existing PRs aren't gated; operators upgrade to `warning` once contributors are habituated. |
| `docs-claimed-not-shipped` | `blocking` if the claimed doc is in **Explanation** for a load-bearing decision; `warning` otherwise | PLAN.md claimed a doc and the diff omits it. |
| `docs-undeclared` | `info` | The diff contains a doc change in a quadrant PLAN.md said was N/A. Likely benign; flag for PLAN.md hygiene. |
| `docs-quadrant-mismatch` | `warning` | PLAN.md claimed a quadrant but the doc that was shipped fits a different quadrant (e.g., declared **Reference**, shipped pure narrative which belongs in **Explanation**). Recommend re-categorization. |

**Phased rollout note**: during initial adoption, treat `docs-block-missing` as
`info` (PASS-eligible). Once the discipline is established as an operator-confirmed
convention, upgrade the severity to `warning` (which surfaces an UNCLEAR axis-1 and
maps to a NEEDS-WORK verdict). The phase transition is itself a doctrine update —
land it as a follow-up PR against this file.

**What axis 1 is NOT**: code-correctness sniffing. A diff that attempts every
criterion but is wrong-on-the-merits PASSES axis 1 and FAILS axis 2 or 3. Don't
overload axis 1 — it is the cheap fail-fast for "did you even attempt the task?"

### Axis 2 — Process

**Question**: Did L{N-1} follow its required process for this work, including
running its own review/verification cycle?

**Inputs**:
- For N=1: `.claude/reviews/latest.md` from L0's own `/review` invocation (if
  present), CI status (`gh pr checks <PR>`), evidence of local validation (commit
  messages, PR description).
- For N=2: `.claude/reviews/l1-latest.md` for each L0 PR L1 accepted, plus L1's own
  work-product artifacts.
- The work-type → required-verification map from "Work-type → required-verification
  map" below.

**Checks**:
1. **Required-verification step ran.** Look up the work type in the
   verification map and confirm each required step ran with a green result. The map
   is authoritative; if a work type isn't listed, treat as UNCLEAR and flag a
   recommendation to extend the map.
2. **L{N-1}'s own review cycle ran with a non-blocking verdict.**
   - For N=1: `/review` artifact at `.claude/reviews/latest.md` exists, was produced
     for this PR (matches PR number / branch), and verdict is not BLOCKING.
   - For N=2: an `.claude/reviews/l1-latest.md` exists for every constituent L0 PR
     L1 accepted, verdicts are not BLOCKING, and L1-review's own axes returned PASS
     (or surfaced advisories L1 explicitly acknowledged).
3. **CI is green** — red CI is itself an axis-2 FAIL regardless of the cause. The
   skill must not paper over red CI by claiming the failures are unrelated.
4. **No reliance on `/review` for axes it cannot cover.** If a blocker class is
   known to be invisible to `/review` (e.g. a fresh-apply trap that only manifests
   on a clean checkout, not the author's local state), do not credit `/review`'s
   green verdict as covering it — surface as UNCLEAR and route to axis 3.

**Verdict rule**: PASS if every required step ran green AND L{N-1}'s own review
produced a non-blocking verdict AND CI is green. FAIL on any of: missing required
step, BLOCKING upstream verdict, red CI. UNCLEAR when evidence is unavailable (e.g.
artifact missing) — never collapse UNCLEAR to PASS.

### Axis 3 — Objective Advancement

**Question**: Does the work product appropriately advance L{N}'s parent objective
and allow L{N} to pass its own review cycle?

**This is the recursive lever.** Each L{N}-review evaluates against **L{N}'s**
parent objective, NOT L{N-1}'s task. The same diff can PASS axis 3 at N=1 (advances
L1's local objective) and FAIL axis 3 at N=2 (breaks L2's broader contract). The
canonical failure: a committed import block that satisfies "make today's apply
succeed" (L{N-1}'s local task) but breaks "bootstrap is reproducible across
accounts / DR / fresh apply" (L{N}'s broader contract).

**Inputs**:
- L{N}'s parent objective. Read in this order; first hit wins:
  1. `GOAL.md` in the L{N} session's workspace (iteration goal).
  2. Project `CLAUDE.md` "Objective" / "Task" section.
  3. Goal-tree parent node summary (or `GOAL.md` on bootstrap-mode hosts).
  4. If none of the above is reachable, surface UNCLEAR and ask the L{N} role to
     provide its objective in the next tick.
- The work product under review (same diff/artifact as axes 1 and 2).
- L{N}'s own review cycle's known failure modes — does the work product trip any of
  them?

**Checks**:
1. **Forward progress on parent objective.** Identify the parent objective's
   acceptance criteria. Map the work product onto them: does it close any, partially
   advance any, regress any?
2. **Local-optimum failure detection.** Ask: "does the work product satisfy
   L{N-1}'s local task while breaking a property L{N} requires?" Properties commonly
   broken at this seam: reproducibility, portability, downstream contract semantics,
   transitive guarantees consumers were relying on.
3. **L{N}-cycle passability.** Will L{N}'s own review by L{N+1} pass if L{N} accepts
   this work product as-is? If not, the work product fails axis 3 at this layer —
   even if it passes at L{N-1}.

**Verdict rule**: PASS if the work product makes forward progress on the parent
objective AND introduces no local-optimum failures relative to L{N}'s scope AND
L{N}-cycle passability holds. FAIL on any of: regresses parent objective,
introduces a local-optimum failure visible at L{N}'s scope, would fail L{N+1}'s
review. UNCLEAR when parent objective is unreadable (default deny — the L{N} role
must provide context).

## Finding schema

Every finding is one entry in the artifact body:

```yaml
- axis: 1 | 2 | 3
  severity: blocking | warning | info
  category: <free-form short tag — e.g. scope-mismatch, surface-bloat, missing-validation, local-optimum, contract-drift>
  location: <file:line if applicable, else PR-wide>
  evidence: <one sentence stating what was observed>
  recommendation: <one sentence stating what should change>
```

**Severity rules**:
- `blocking` is restricted to **correctness failures, security vulnerabilities,
  data-loss risks, and CI-red**. Anything else is `warning` or `info` regardless of
  how strongly you feel about it. This matches a per-line code reviewer's
  BLOCKING-tier rule, kept in sync so the verdict translation across layers is
  meaningful.
- `warning` is for legitimate concerns the L{N} role should evaluate but which
  don't independently block merge.
- `info` is FYI / follow-up.

## Verdict rubric

Compute the verdict from the per-axis results and severities:

| Condition | Verdict |
|-----------|---------|
| Any axis FAIL with any `blocking` finding | `BLOCKING` |
| Any axis FAIL with no `blocking` finding | `NEEDS-WORK` |
| All axes PASS, no `blocking` findings | `CLEAN` |
| Any axis UNCLEAR, no axis FAIL | `NEEDS-WORK` (never collapse UNCLEAR to CLEAN) |

**Corollary**: an UNCLEAR on axis 2 must surface as ambiguity in the verdict body.
If the required verification step couldn't be evaluated (artifact missing, CI not
yet finished), the reviewer cannot claim CLEAN — verdict is NEEDS-WORK with a
finding requesting the evidence.

## Artifact format

The skill writes one file per review:
- `l1-review` → `.claude/reviews/l1-latest.md`
- `l2-review` → `.claude/reviews/l2-latest.md`

Frontmatter (machine-parseable; tick doctrine and other reviewers branch on it):

```yaml
---
verdict: CLEAN | NEEDS-WORK | BLOCKING
level: 1 | 2
pr: <PR number or "n/a">
target: <owner/repo#PR or local-branch-name>
axes:
  conformance: PASS | FAIL | UNCLEAR
  process:     PASS | FAIL | UNCLEAR
  objective:   PASS | FAIL | UNCLEAR
blocking: <count>
warning: <count>
reviewed_at: <iso8601>
reviewer: l<N>-review
---
```

`blocking` and `warning` are first-class because the post-body's first line
(`**<VERDICT>** — <N> blocking and <M> advisory finding(s).`) is the canonical
greppable summary across review layers and reuses these numbers. `info` count and
`findings` total are intentionally absent — they were prior double-bookkeeping;
consumers needing them can grep the body.

Body: per-axis sections, each with the findings emitted by that axis. Empty axes get
`_no findings_`.

## Posting protocol (cross-operator contract)

The PR review comment is the **canonical cross-operator artifact** for an
L{N}-review. The local `.claude/reviews/l<N>-latest.md` file is the L{N}'s own
record; another operator (or a higher-layer review) on a different host cannot read
that file. All cross-operator evidence — including the input that the next layer's
axis 2 reads — flows through the PR comment.

The skill posts via:

```bash
gh pr review <PR> --comment --body-file <post-body>
```

**Never `--request-changes`.** GitHub blocks REQUEST_CHANGES on a PR you opened
yourself. The `**<VERDICT>**` first line below is the authoritative label.

### Post-body composition

The post-body is built **freshly** for each review; do not derive it by stripping
the frontmatter from the workspace artifact (the positional strip is brittle if a
finding ever contains a literal `---` line). Compose it as:

1. **First line — exactly**:
   ```
   **<VERDICT>** — <blocking> blocking and <warning> advisory finding(s).
   ```
2. **Body** — the same per-axis sections as the workspace artifact body
   (Conformance / Process / Objective Advancement).
3. **Trailing metadata block** — an HTML comment carrying the machine-readable
   verdict for the next layer to parse:
   ```
   <!-- l<N>-review:metadata
   verdict: <CLEAN|NEEDS-WORK|BLOCKING>
   level: <N>
   pr: <number>
   target: <owner/repo>#<number>
   axes: { conformance: <PASS|FAIL|UNCLEAR>, process: <PASS|FAIL|UNCLEAR>, objective: <PASS|FAIL|UNCLEAR> }
   blocking: <count>
   warning: <count>
   reviewed_at: <iso8601>
   reviewer: l<N>-review
   -->
   ```

HTML comments are not rendered in the PR UI but are preserved in the comment body
and readable via `gh api /repos/.../pulls/<n>/reviews` or
`gh pr view <n> --json reviews`. This is the same pattern CI bots use for
`<!-- ...-comment -->` markers.

For `BLOCKING`, prefix every blocking finding's body with `🛑 BLOCKING — ` so a
human grepping the PR thread sees the blocking marker without parsing the metadata
block.

### How the next layer reads the artifact

L{N+1}-review's axis 2 reads the metadata block, NOT the workspace file (which it
cannot reach across operators). For each constituent PR:

1. `gh api /repos/<owner>/<repo>/pulls/<pr>/reviews` and filter to reviews authored
   by the expected L{N} reviewer.
2. For each candidate review body, search for `<!-- l<N>-review:metadata` … `-->`.
3. Pick the most recent review (`submitted_at`) that contains the marker.
4. Parse the YAML-shaped lines between the marker and the closing `-->` for
   `verdict`, `axes`, etc.
5. If no review with the marker is found → the L{N}-review is missing → axis 2
   records UNCLEAR for that constituent. Do **not** silently treat absence as PASS.

This is the only cross-operator path. There is no environment-variable artifact
store; do not introduce one without deprecating this scheme in tandem.

### Local workspace artifact

The local `.claude/reviews/l<N>-latest.md` file (frontmatter + body, same content
as posted minus the trailing HTML marker plus the original YAML frontmatter) is
written for the L{N}'s own records and for in-session re-use. It is single-file,
overwritten per review, and **not** consulted by any other layer's review. Treat it
as cache, not contract.

---

## Work-type → required-verification map

Consumed by axis 2 (Process). For each work type, lists the verification steps that
MUST have run green for axis 2 to PASS. If a step is missing or non-green, axis 2 is
FAIL.

**Detection**: the review skill picks the work type by inspecting the PR's
changed-file extensions. The first row whose pattern matches any file in the diff
wins. If no row matches, treat as UNCLEAR on axis 2 and emit an `info` finding
recommending the map be extended.

| Work type | File-pattern signal | Required green steps | Notes |
|-----------|---------------------|----------------------|-------|
| Terraform | `*.tf`, `*.tfvars` | `terraform fmt -check`, `terraform validate`, `terraform plan` (on the PR branch, against the target tier) | `validate` catches broken resource references that a plan-only CI comment can miss. A CI plan comment counts only when the plan is for the exact tier touched by the diff. |
| Go | `*.go`, `go.mod`, `go.sum` | `go build ./...`, `go test ./...`, `golangci-lint run` (or repo-configured linter) | |
| Python | `*.py`, `pyproject.toml`, `requirements*.txt` | `ruff check`, repo test runner (`pytest`, etc.), `mypy` if configured | |
| Shell | `*.sh`, `*.bash`, files with `#!/.../sh` | `shellcheck`, repo test runner if `bats`/`shunit2` present | |
| YAML / CI workflows | `.github/workflows/*.yml`, `*.yaml`, `*.yml` | `yamllint` (if configured), `actionlint` for workflow files | Workflow changes additionally require axis-3 attention to verify the workflow runs at least once green on this PR. |
| Markdown / docs only | `*.md` only (no code files in diff) | `markdownlint` if configured; otherwise no required verification | Pure-doc PRs pass axis 2 by default; axis 1 (conformance) and axis 3 (objective) still apply. |
| Claude skills / commands | `**/skills/**`, `**/commands/**` | See "Doctrine-class PR sub-checklist" below — there is no equivalent of `terraform validate` for skill markdown, so axis 2 substitutes a concrete manual list. | Doctrine-only skills (no `operations/` directory — pure reference) require every item; executor skills (have `operations/`) require items 1, 3, 4. |
| Claude workflows | `**/workflows/*.js` | `node --check <file>` (JS syntax parse) for each changed workflow file, AND meta-shape validation — see "Workflow-class PR sub-checklist" below. | Analogous to the Claude-skills doctrine-class row: there is no runtime test for a workflow script in review, so axis 2 substitutes parse + meta-shape as the static gate. |
| Mixed (multiple patterns) | Multiple rows match | Union of required steps from every matched row | All required steps must be green. A red Go test and a green TF plan in the same PR is FAIL. |

### Doctrine-class PR sub-checklist

There is no automated verifier for Claude-skills/commands markdown. The following
concrete checklist substitutes. Failure of any item emits an axis-2 finding at the
listed severity (per the severity rules above):

1. **Artifact-path consistency** (correctness — **blocking**) — For every consumer
   skill that reads a producer skill's artifact, the producer's `operations/run.md`
   must actually write to the path the consumer's `operations/run.md` reads. Grep
   both directions; mismatches are blocking. Concrete recipe (substitute the actual
   producer/consumer pair):

   ```bash
   # Producer's write set — every path the producer writes:
   grep -rnE '\.claude/reviews/.*\.md|(write|cat\s*>) ' \
       skills/<producer-skill>/operations/

   # Consumer's read set — every path the consumer reads:
   grep -rnE '\.claude/reviews/.*\.md|gh api .*/reviews|l[0-9]+-review:metadata' \
       skills/<consumer-skill>/operations/
   ```

   A consumer-side path that doesn't appear in the producer's write set is a
   mismatch — blocking finding. (Posted PR comments count as the producer's write
   set when the doctrine posting protocol is in use — see "How the next layer reads
   the artifact".) This is the rule that catches a producer/consumer contract break
   where the consumer reads one path but the producer writes another.
2. **Cross-skill reference resolution** (architecture — warning) — Every
   `../<skill>/...` link in SKILL.md and `references/<file>.md` link in operations
   must resolve to an existing path inside the skills directory.
3. **SKILL.md frontmatter validity** (correctness — **blocking**) — YAML
   frontmatter must parse and declare `name`, `description`, `allowed-tools`,
   `version`. A skill that won't load is non-functional.
4. **Files referenced exist** (correctness — warning) — Every `Read(...)` /
   `Read: <path>` reference in operations must point at a file present in the diff
   or already in the repo. Dangling reads are a warning (the operation can degrade
   gracefully only if the doctrine says so explicitly).
5. **No inlined doctrine in consumer skills** (architecture — warning) —
   Doctrine-only skills (no `operations/` directory) own the rules; executor skills
   must point at the doctrine, not copy it. Duplicate paragraphs between a consumer
   and its doctrine source are a warning.

Item 1 is the load-bearing one for cross-skill contracts; the others are
loading/coherence checks. Running the five together takes a few minutes of grepping
and is the actual content of axis 2 for doctrine-class PRs.

### Workflow-class PR sub-checklist

There is no runtime test for a workflow script (`*.js` under a `workflows/`
directory) in review — its real behavior is its own run, not static review. Axis 2
substitutes parse + meta-shape as the static gate. Failure of any item emits an
axis-2 finding at the listed severity:

1. **Parse** (correctness — **blocking**) — `node --check <file>` parses green for
   every changed `*.js` workflow. A non-parsing workflow is non-functional.
2. **meta-shape** (correctness — **blocking**) — the script declares
   `export const meta = { ... }` as the first statement, with at least `name`
   (string), `description` (string), and `phases` (array), and it is a pure literal
   — no variables, calls, or spreads. A missing or non-literal `meta` is blocking:
   the workflow won't load.
3. (Optional, info) Deeper runtime behavior isn't review-gated — that's the
   workflow's own run, not static review.

### Extending the map

When a PR's work type isn't listed:
1. Axis 2 returns UNCLEAR for that PR.
2. The review emits an `info` finding: `recommendation: extend the
   lN-review-doctrine verification map with a row for <pattern>`.
3. The map gets a PR adding the row, following the table shape above.

Do not silently default new work types to "no verification required" — that turns
axis 2 into a rubber stamp.

### L{N}-specific notes

- **N=1 (l1-review)**: the steps above run on the L0's PR directly. Evidence: CI
  checks (`gh pr checks <PR>`) and/or local commit-message annotations from the L0.
- **N=2 (l2-review)**: every constituent L0 PR L1 accepted must itself satisfy the
  steps above. l2-review's axis 2 reads the l1-review comment posted on each
  constituent PR (via the `<!-- l1-review:metadata -->` marker; see "Posting
  protocol") and confirms l1-review's own axis 2 PASSed. Transitive: if l1-review
  missed a required step, l2-review is the second line of defense.

---

## When this doctrine is wrong

If a rule above is wrong for the current iteration, **fix it here** via a PR against
this skill. Do not patch the rule inside `l1-review` or `l2-review` — those skills
are pure executors of this doctrine. Doctrine edits land on a branch and ship as a
versioned doctrine update.

## See also

- `lN-lifecycle-doctrine` — the parallel lifecycle doctrine; its
  `pr-open → fixing → merged` states drive when an L{N}-review runs.
- `l1-review` skill — executes this doctrine at N=1; `l2-review` skill — executes it
  at N=2.
- A per-line code-review skill (e.g. `review`) — L0's per-line review; its output is
  read by axis 2 of L{N}-review. Out of scope for changes here.
