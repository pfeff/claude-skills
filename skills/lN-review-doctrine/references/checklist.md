# L{N}-review — canonical checklist

This is the doctrine consumed by `l1-review` (N=1) and `l2-review`
(N=2) at review time. **Read this file at review time; never inline
its content into a review skill's operations.**

If you find yourself about to add a new rule by editing a review
skill, edit this file instead.

---

## Role

You are the L{N}-review evaluator. Your job: take a single work
product (typically a PR, but it can be a sign-off action or a
coord-tree node completion) produced by L{N-1}, evaluate it on
three axes, emit a structured verdict, and write the verdict to
`.claude/reviews/l<N>-latest.md`.

You are **not** L0's `/review`. You do not read the diff line-by-
line for code-level correctness, security, simplicity, or
architecture. That work is L0's `/review` — you consume its output
as evidence for axis 2, you do not duplicate it.

You are **not** L{N-1}. You are evaluating L{N-1}'s output against
L{N}'s parent objective, which is broader than L{N-1}'s task.

## Reviewer independence

L{N}-review **runs in an independent context window**. The grader
must be a fresh verifier — a separate context (a sub-agent, or a
clean session) that receives only the work product (the PR/diff and
its posted artifacts) plus L{N}'s parent objective — **not** the
reasoning trace or conversation that produced the work. Self-
critique in the authoring context is not a valid L{N}-review: an
author grading its own output in the same context rationalizes the
choices it already made and cannot see them as an outside reader
would. A verifier sub-agent outperforms self-critique precisely
because grading happens in an independent context window.

## The three axes

Every L{N}-review walks these three axes, in order. Each axis
returns one of `PASS` / `FAIL` / `UNCLEAR`, plus zero or more
findings.

### Axis 1 — Conformance

**Question**: Does the work product match the task L{N} handed to
L{N-1}?

**Inputs**:
- The task description L{N-1} was given (coord-tree node summary,
  workspace DESIGN.md, dispatch prompt, or PR description).
- The diff / artifact under review (`gh pr diff <PR>` or
  equivalent).

**Checks**:
- Is the diff *within scope*? Files outside the named scope, or
  files inside scope that were not touched, are flagged.
- Does the diff *attempt* every named acceptance criterion? Missed
  criteria are FAIL; partial attempts with TODOs are UNCLEAR.
- Are there obvious wrong-file / abandoned-WIP / leftover-debugging
  signatures? (e.g. `console.log`, `dbg!`, commented-out code
  unrelated to the task.)
- **Project standing rules.** Project-wide architectural
  constraints (e.g. a project `CLAUDE.md` `## Standing Rules`
  section) are conformance criteria too — assess the diff against
  each. A violated standing rule is an axis-1 finding at the
  severity the rule implies (a correctness/security rule →
  `blocking`; a convention → `warning`). Rules carrying a
  `**Detector**:` hint may be grep-pre-filtered: no match →
  auto-pass.
- **Minimality** (maintained surface is a cost — see the "Surface
  cost axis" in the steward `DESIGN.md`): among ways to meet the
  objective, does the diff add the *least* surface (net lines,
  rules, files, branch points)? Three sub-checks, each a
  `surface-bloat` finding when it fails:
  - **Least surface that meets the objective.** Extra rules, files,
    or branch points beyond what the criteria require — flag the
    excess. Surface is a tiebreaker only; never demand a cut that
    regresses function (that is an axis-3 concern, not axis 1).
  - **Pointer over inline (DRY).** Could added doctrine reference an
    existing home instead of duplicating it? This reinforces
    `verification-map.md` sub-checklist item 5 (no inlined doctrine
    in consumer skills) and the doctrine/rationale split — do not
    re-derive a rule that already has a home.
  - **Dead surface.** Is anything added that nothing references or
    applies — a rule no path triggers, code no caller hits,
    doctrine no skill reads? Flag for deletion rather than merge.
- **Documentation Impact (Diataxis)**: PLAN.md (or the task's
  dispatch brief, if no PLAN.md exists) is expected to declare a
  structured "Documentation Impact" block per Diataxis quadrant.
  For each quadrant the PLAN claimed a doc would be updated, the
  diff must include the corresponding change. See the
  "Documentation Impact (Diataxis) schema" sub-section below for
  the block shape, quadrant defaults, and finding categories.

**Verdict rule**: PASS if every named criterion is attempted AND
the diff is within scope AND the Documentation Impact discipline
holds (per phased severity below). FAIL if any criterion is
unattempted, the diff is materially out of scope, OR a load-bearing
**Explanation**-quadrant doc was claimed-but-not-shipped. UNCLEAR
for ambiguous scope boundaries. `surface-bloat` findings are
`warning`/`info` (surface is a tiebreaker, never blocking) — they
surface an UNCLEAR axis-1 → NEEDS-WORK, prompting a smaller
revision, but never gate on surface at the cost of function.

### Documentation Impact (Diataxis) schema

PLAN.md (or the task's dispatch brief, if no PLAN.md exists)
declares affected docs structured by Diataxis quadrant. The
discipline is the **deliberate answer per quadrant**; "N/A in all
four" is a valid declaration for trivial fixes — absence of the
block is itself a finding.

Expected block shape:

```markdown
## Documentation Impact
- **Tutorial**: <doc path> | N/A
- **How-to**: <doc path> | N/A
- **Reference**: <doc path> | N/A
- **Explanation**: <doc path> | N/A
```

**Quadrant defaults the reviewer applies** when judging whether a
PLAN.md's N/A answer was plausible:

| Work type | Default quadrant(s) |
|-----------|---------------------|
| Architectural decision, state-model / contract change | **Explanation** (ADR or `DESIGN.md` DD entry) |
| New public surface (CLI command, API endpoint, terraform tier) | **Reference + How-to** |
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

**Phased rollout note**: during initial adoption, treat
`docs-block-missing` as `info` (PASS-eligible). Once the discipline
is established in your operator-confirmed feedback memory, upgrade
the severity to `warning` (which surfaces an UNCLEAR axis-1 and
maps to a NEEDS-WORK verdict). The phase transition is itself a
doctrine update — land it as a follow-up PR against this file.

**What axis 1 is NOT**: code-correctness sniffing. A diff that
attempts every criterion but is wrong-on-the-merits PASSES axis 1
and FAILS axis 2 or 3. Don't overload axis 1 — it is the cheap
fail-fast for "did you even attempt the task?"

### Axis 2 — Process

**Question**: Did L{N-1} follow its required process for this work,
including running its own review/verification cycle?

**Inputs**:
- For N=1: L0's `/review` verdict from the posted
  `<!-- review:metadata -->` marker on the PR (the cross-operator
  artifact — see "How the next layer reads the artifact" below; the
  local `.claude/reviews/latest.md` is gitignored and unreadable
  across operators, so it is **not** the evidence), CI status
  (`gh pr checks <PR>`), evidence of local validation (commit
  messages, PR description).
- For N=2: `.claude/reviews/l1-latest.md` for each L0 PR L1
  accepted, plus L1's own work-product artifacts.
- The work-type → required-verification map from
  `verification-map.md`.

**Checks**:
1. **Required-verification step ran.** Look up the work type in
   `verification-map.md` and confirm each required step ran with
   a green result. The map is authoritative; if a work type isn't
   listed, treat as UNCLEAR and flag a recommendation to extend
   the map.
2. **L{N-1}'s own review cycle ran with a non-blocking verdict.**
   - For N=1: L0's `/review` posted its `<!-- review:metadata -->`
     marker on the PR (matches PR number / branch), and its
     `verdict` is not BLOCKING. A missing marker is UNCLEAR, not a
     silent PASS.
   - For N=2: an `.claude/reviews/l1-latest.md` exists for every
     constituent L0 PR L1 accepted, verdicts are not BLOCKING,
     and L1-review's own axes returned PASS (or surfaced
     advisories L1 explicitly acknowledged).
3. **CI is green** per [[feedback-l1-review-red-ci]] — red CI is
   itself an axis-2 FAIL regardless of the cause. The skill must
   not paper over red CI by claiming the failures are unrelated.
4. **No reliance on `/review` for axes it cannot cover.** If a
   blocker class is known to be invisible to `/review` (e.g.
   fresh-apply trap of B2 in DESIGN.md walk-through), do not
   credit `/review`'s green verdict as covering it — surface as
   UNCLEAR and route to axis 3.

**Verdict rule**: PASS if every required step ran green AND
L{N-1}'s own review produced a non-blocking verdict AND CI is
green. FAIL on any of: missing required step, BLOCKING upstream
verdict, red CI. UNCLEAR when evidence is unavailable (e.g.
artifact missing) — never collapse UNCLEAR to PASS.

### Axis 3 — Objective Advancement

**Question**: Does the work product appropriately advance L{N}'s
parent objective and allow L{N} to pass its own review cycle?

**This is the recursive lever.** Each L{N}-review evaluates against
**L{N}'s** parent objective, NOT L{N-1}'s task. The same diff can
PASS axis 3 at N=1 (advances L1's local objective) and FAIL axis 3
at N=2 (breaks L2's broader contract). See the PR #8 / B2 walk-
through in `DESIGN.md` for the canonical example (committed
import block satisfies "make today's apply succeed" but breaks
"bootstrap is reproducible across accounts / DR / fresh apply").

**Inputs**:
- L{N}'s parent objective. Read in this order; first hit wins:
  1. `GOAL.md` in the L{N} session's workspace (iteration goal).
  2. Project `CLAUDE.md` "Objective" / "Task" section.
  3. Coord-tree parent node summary via `ac_node_query` (or
     `GOAL.md` on bootstrap-mode hosts).
  4. If none of the above is reachable, surface UNCLEAR and ask
     the L{N} role to provide its objective in the next tick.
- The work product under review (same diff/artifact as axes 1
  and 2).
- L{N}'s own review cycle's known failure modes — does the work
  product trip any of them?

**Checks**:
1. **Forward progress on parent objective.** Identify the parent
   objective's acceptance criteria. Map the work product onto
   them: does it close any, partially advance any, regress any?
2. **Local-optimum failure detection.** Ask: "does the work
   product satisfy L{N-1}'s local task while breaking a property
   L{N} requires?" Properties commonly broken at this seam:
   reproducibility, portability, downstream contract semantics,
   transitive guarantees consumers were relying on. (See B2 in
   DESIGN.md walk-through for the canonical case.)
3. **L{N}-cycle passability.** Will L{N}'s own review by L{N+1}
   pass if L{N} accepts this work product as-is? If not, the
   work product fails axis 3 at this layer — even if it passes
   at L{N-1}.

**Verdict rule**: PASS if the work product makes forward progress
on the parent objective AND introduces no local-optimum failures
relative to L{N}'s scope AND L{N}-cycle passability holds. FAIL
on any of: regresses parent objective, introduces a local-optimum
failure visible at L{N}'s scope, would fail L{N+1}'s review.
UNCLEAR when parent objective is unreadable (default deny — the
L{N} role must provide context).

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
- `blocking` is restricted to **correctness failures, security
  vulnerabilities, data-loss risks, and CI-red**. Anything else is
  `warning` or `info` regardless of how strongly you feel about
  it. This matches `mbp/review`'s BLOCKING-tier rule, kept in
  sync so the verdict translation across layers is meaningful.
- `warning` is for legitimate concerns the L{N} role should
  evaluate but which don't independently block merge.
- `info` is FYI / follow-up.

## Verdict rubric

Compute the verdict from the per-axis results and severities:

| Condition | Verdict |
|-----------|---------|
| Any axis FAIL with any `blocking` finding | `BLOCKING` |
| Any axis FAIL with no `blocking` finding | `NEEDS-WORK` |
| All axes PASS, no `blocking` findings | `CLEAN` |
| Any axis UNCLEAR, no axis FAIL | `NEEDS-WORK` (never collapse UNCLEAR to CLEAN) |

**Corollary from PR #8 walk-through (DESIGN.md)**: an UNCLEAR on
axis 2 must surface as ambiguity in the verdict body. If the
required verification step couldn't be evaluated (artifact missing,
CI not yet finished), the reviewer cannot claim CLEAN — verdict is
NEEDS-WORK with a finding requesting the evidence.

### Single verdict vocabulary (legacy APPROVE/REJECT/ESCALATE is deprecated)

`CLEAN` / `NEEDS-WORK` / `BLOCKING` is the **only** verdict vocabulary for an
L{N}-review judgment, system-wide. There is exactly one judgment, and it lives here.

A legacy L1 review — `goal-tree/operations/l1-review.md` — once emitted
`APPROVE` / `REJECT` / `ESCALATE` from its own rubric. That review schema is
**deprecated**: the goal-tree operation no longer judges PRs; it is retained only as a
post-`CLEAN` *merge action* (merge / agent-coordinator deploy / coordinator update),
and `goal-tree/operations/execute-tree.md` now invokes `/l1-review` for the judgment.
The former vocabulary maps onto this doctrine's verdicts:

| Deprecated verdict | Doctrine verdict |
|--------------------|------------------|
| `APPROVE` | `CLEAN` |
| `REJECT` | `NEEDS-WORK` (or `BLOCKING` if any blocking finding) |
| `ESCALATE` | `NEEDS-WORK` / `BLOCKING` with a red-CI axis-2 FAIL routed to operator |

This mapping exists only to read historical artifacts; new reviews emit the doctrine
vocabulary directly. The CLEAN marker the `/l1-review` executor posts (see "Posting
protocol") is what `lN-lifecycle-doctrine` complete-check condition 4 gates
`merged → complete` on — the deprecated direct-merge path posted no marker and so
could never reach `complete`.

## Artifact format

The skill writes one file per review:
- `l1-review` → `.claude/reviews/l1-latest.md`
- `l2-review` → `.claude/reviews/l2-latest.md`

Frontmatter (machine-parseable; tick doctrine and other reviewers
branch on it):

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

`blocking` and `warning` are first-class frontmatter fields;
`warning` holds the pure warning-tier count only. `info` count and
`findings` total are intentionally absent from frontmatter — they
were prior double-bookkeeping; consumers needing them can grep the
body. **Advisory = warning + info.** The post-body's first line
(`**<VERDICT>** — <N> blocking and <M> advisory finding(s).`) is
the canonical greppable summary across review layers; `<M>` is the
*sum* of the warning-tier and info-tier findings actually present
in the composed body — never just the `warning` frontmatter value
on its own. See "Post-body composition" below for the mechanical
count-assertion this requires before posting.

Body: per-axis sections, each with the findings emitted by that
axis. Empty axes get `_no findings_`.

## Posting protocol (cross-operator contract)

The PR review comment is the **canonical cross-operator artifact**
for an L{N}-review. The local `.claude/reviews/l<N>-latest.md`
file is the L{N}'s own record; another operator (or a higher-
layer review) on a different host cannot read that file. All
cross-operator evidence — including the input that the next
layer's axis 2 reads — flows through the PR comment.

**The chain bottoms out at L0.** L0's `/review` posts the same way:
a dual-surface PR comment carrying a `<!-- review:metadata -->`
marker (note: **`review:metadata`, with no `l<N>-` prefix** — it is
the layer-0 marker, deliberately distinct from the
`l<N>-review:metadata` markers so a higher-layer
`l[0-9]+-review:metadata` scan never false-matches it). l1-review's
axis 2 reads that L0 marker as its authoritative `/review` evidence,
exactly as l2-review reads the `<!-- l1-review:metadata -->` marker.
The local `.claude/reviews/latest.md` L0 writes stays the L0's own
gitignored cache, never the cross-operator evidence. The L0 marker
block carries `verdict` (`CLEAN|BLOCKING`), `level: 0`, `pr`,
`target`, `blocking`, `advisory`, `reviewed_at`, and
`reviewer: review`.

The skill posts the canonical artifact to **two surfaces on the PR**, so
both the machine-read path and any human / plain-`gh pr view` check find
the marker:

```bash
# (1) PR review — the canonical machine-read surface (reviews API).
#     APPEND-ONLY: a submitted review object cannot be edited in place the
#     way an issue comment can, and consumers read it most-recent-wins (see
#     "How the next layer reads the artifact"), so re-running a review adds a
#     new review object each time. This is intentional and unchanged.
gh pr review <PR> --comment --body-file <post-body>
# (2) Issue-comment mirror — UPDATE-IN-PLACE, keyed on this review type's
#     marker token. Exactly one issue comment per marker type per PR: if a
#     comment already carries "$marker", PATCH it; else create one. See
#     "Find-or-update by marker" below.
```

**Never `--request-changes`.** GitHub blocks REQUEST_CHANGES on a
PR you opened yourself (observed on PR #8 in the DESIGN.md
walk-through), and a `--comment` review intentionally leaves
`reviewDecision` **empty** — an empty `reviewDecision` is therefore
**not** a signal that the review is missing; read the marker, not the
decision. The `**<VERDICT>**` first line below is the authoritative label.

**Canonical read surface = the reviews API** (`gh api
/repos/.../pulls/<n>/reviews` or `gh pr view <n> --json reviews`); all
automated consumers (the l{1,2}-supervise complete-checks and l2-review's
axis 2) read the marker there. The issue-comment mirror is a
visibility belt-and-suspenders for manual / rendered-view checks — **not**
a second source of truth; both surfaces carry the identical marker.
(Root cause, 2026-06-04 / PR #194: an l1-review marker was posted only as
a review; an operator check scanning issue comments / plain `gh pr view`
read the PR as un-reviewed. Mirroring closes that gap.)

### Find-or-update by marker (issue-comment surface — one comment per type)

**Rule.** The issue-comment surface holds **exactly one comment per
marker type per PR.** On every post, *find* the existing issue comment
carrying this review type's marker token and *update it in place*; only
*create* a new comment when none exists. Re-running a review (after a fix
commit, or a ladder re-post) therefore **edits** the existing comment
instead of appending a new one. This is the fix for the accumulation
defect (guardian#296: multiple same-type review comments piled up on
re-post).

**Marker token — defined in exactly one place per executor.** The dedup
key is *the marker token for this review type*, and each executor defines
that token **once** (the same string it composes into the trailing
metadata block). Keying find-or-update on that single definition — never
a token hardcoded a second time in the posting step — keeps this rule
robust to a future rename of the marker tokens (e.g. a Change/Acceptance/
Objective relayering): rename the one definition and the update-in-place
logic still finds its own comment. The tokens today are:

| Layer | Marker token (the `$marker` below) |
|-------|-------------------------------------|
| L0 (`/review`) | `<!-- review:metadata` |
| L1 (`l1-review`) | `<!-- l1-review:metadata` |
| L2 (`l2-review`) | `<!-- l2-review:metadata` |

(The literal `<!-- review:metadata` is **not** a substring of
`<!-- l1-review:metadata`, and the `l[0-9]+` markers are mutually
distinct, so a `contains($marker)` match never crosses layers.)

**Canonical procedure** — the one implementation every executor's
issue-comment post follows (`$owner_repo`, `$pr_number`, `$post_body`
already set; `$marker` is the executor's single token definition):

```bash
# Newest issue comment whose body carries THIS type's marker at line start.
#   --paginate + per_page=100: a PR that accumulated many comments (the exact
#     case this fixes) can hold the existing marker past page 1 — without
#     pagination it is missed and a duplicate is created anyway.
#   line-anchored test("(^|\n)$marker"): the metadata block always begins a
#     line, so an *inline* prose mention of the token (see the "Marker-quoting
#     caveat" in the executors) can't false-match and get destructively
#     overwritten by the PATCH below.
#   tail -1: newest-wins across all pages (comments list ascending by age).
existing_id="$(gh api --paginate "/repos/$owner_repo/issues/$pr_number/comments?per_page=100" \
  --jq ".[] | select(.body | test(\"(^|\\n)$marker\")) | .id" | tail -1)"
if [ -n "$existing_id" ]; then
  # Update in place — one comment per marker type, idempotent on re-post.
  gh api --method PATCH "/repos/$owner_repo/issues/comments/$existing_id" \
    -F body=@"$post_body"
else
  gh pr comment "$pr_number" --repo "$owner_repo" --body-file "$post_body"
fi
```

**Scope — issue-comment surface only.** This update-in-place rule governs
surface (2) *exclusively*. The PR **review-object** surface (1) is
**left as-is (append-only)**: a submitted review cannot be edited/deduped
the same way, and its canonical read is most-recent-wins, so a fresh
review object per run is correct and its behavior is **not** changed by
this rule. Do not silently apply find-or-update to the review-object
surface.

### Post-body composition

The post-body is built **freshly** for each review; do not derive
it by stripping the frontmatter from the workspace artifact (the
positional strip is brittle if a finding ever contains a literal
`---` line). Compose it as:

1. **First line — exactly**:
   ```
   **<VERDICT>** — <blocking> blocking and <advisory> advisory finding(s).
   ```
   `<advisory>` is the warning+info sum (see "Advisory = warning +
   info" above) — **not** a direct substitution of the `warning`
   frontmatter field.
2. **Body** — the same per-axis sections as the workspace
   artifact body (Conformance / Process / Objective Advancement).
3. **Trailing metadata block** — an HTML comment carrying the
   machine-readable verdict for the next layer to parse:
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
4. **Advisory count assertion (mechanical, before posting)** — count
   the warning-tier and info-tier finding bullets actually present
   in the composed body (step 2 above); their sum is the advisory
   count. Confirm this sum equals the `<advisory>` written into the
   first line. For L0's `<!-- review:metadata -->` marker, also
   confirm it equals the marker's `advisory` field (L0 persists the
   pre-summed count there). The `l<N>-review:metadata` marker's own
   `warning` field is a *separate*, pure warning-tier count — do
   **not** overwrite it with the advisory sum. **If the recount and
   `<advisory>` differ, fix the first line before posting — do not
   post a mismatched count.**

HTML comments are not rendered in the PR UI but are preserved in
the comment body and readable via `gh api /repos/.../pulls/<n>/reviews`
or `gh pr view <n> --json reviews`. This is the same pattern
GitHub-Actions bots use for `<!-- tf-plan-comment:bootstrap -->`
markers (e.g. PR #8's CI comments).

For `BLOCKING`, prefix every blocking finding's body with
`🛑 BLOCKING — ` so a human grepping the PR thread sees the
blocking marker without parsing the metadata block.

### How the next layer reads the artifact

L{N+1}-review's axis 2 reads the metadata block, NOT the workspace
file (which it cannot reach across operators). For each
constituent PR:

1. `gh api /repos/<owner>/<repo>/pulls/<pr>/reviews` and filter to
   reviews authored by the expected L{N} reviewer.
2. For each candidate review body, search for
   `<!-- l<N>-review:metadata` … `-->`.
3. Pick the most recent review (`submitted_at`) that contains
   the marker.
4. Parse the YAML-shaped lines between the marker and the closing
   `-->` for `verdict`, `axes`, etc.
5. If no review with the marker is found → the L{N}-review is
   missing → axis 2 records UNCLEAR for that constituent. Do
   **not** silently treat absence as PASS.

This is the only cross-operator path. There is no environment-
variable artifact store; do not introduce one without
deprecating this scheme in tandem.

**Bottom of the chain (L0).** The same procedure applies when
l1-review reads L0's `/review` evidence, with one substitution: the
marker is `<!-- review:metadata` (no `l<N>-` prefix), authored by
`review` rather than an `l<N>-review` reviewer. Filter on the marker
presence rather than the reviewer login (the L0 `/review` posts under
the same actor that opened the PR, so an author filter would exclude
it). Everything else — reviews-API-first, issue-comment mirror
fallback, most-recent-wins, missing-marker → UNCLEAR — is identical.

### Local workspace artifact

The local `.claude/reviews/l<N>-latest.md` file (frontmatter +
body, same content as posted minus the trailing HTML marker plus
the original YAML frontmatter) is written for the L{N}'s own
records and for in-session re-use. It is single-file,
overwritten per review, and **not** consulted by any other
layer's review. Treat it as cache, not contract.

#### Never committed to git

`.claude/reviews/*.md` — every review artifact at every layer
(`latest.md` from L0's `/review`, `l1-latest.md`, `l2-latest.md`)
— is a **local workspace record ONLY and MUST NEVER be committed
to git.** The canonical cross-operator artifact is the PR comment
(see *Posting protocol* above); the workspace file is per-host
cache that no other layer reads. Committing it serves no consumer
and actively harms: a review snapshot frozen in a commit drifts
from the real code state as the branch evolves, so any reader who
trusts the committed file reviews stale evidence.

**Root cause (2026-06-04):** Dev-Stacks-v2 PR #42 had committed a
`.claude/reviews/latest.md` that drifted from the real diff and
had to be re-synced. The artifact is cache, not source — freezing
cache in git history is the defect.

**Implementing requirement (per repo):** every repo that runs
`/review` or an L{N}-review MUST `.gitignore` `.claude/reviews/`
and untrack any already-committed copy
(`git rm --cached .claude/reviews/<file>`). This doctrine states
the rule; the per-repo `.gitignore` + untrack is the implementing
follow-up.

## When this doctrine is wrong

If a rule above is wrong for the current iteration, **fix it here**
via PR against `pfeff/claude-skills`. Do not patch the rule inside
`l1-review` or `l2-review` — those skills are pure executors of
this doctrine. Doctrine edits land on a branch and ship as a
versioned doctrine update.
