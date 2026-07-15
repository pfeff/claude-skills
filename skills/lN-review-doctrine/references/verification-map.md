# L{N}-review — work-type → required-verification map

Consumed by axis 2 (Process) of the L{N}-review checklist
(`checklist.md`). For each work type, lists the verification steps
that MUST have run green for axis 2 to PASS. If a step is missing
or non-green, axis 2 is FAIL.

**Detection**: the review skill picks the work type by inspecting
the PR's changed-file extensions. The first row whose pattern
matches any file in the diff wins. If no row matches, treat as
UNCLEAR on axis 2 and emit an `info` finding recommending the map
be extended.

## Map

| Work type | File-pattern signal | Required green steps | Notes |
|-----------|---------------------|----------------------|-------|
| Terraform | `*.tf`, `*.tfvars` | `terraform fmt -check`, `terraform validate`, `terraform plan` (on the PR branch, against the target tier) | The PR #8 / B1 walk-through: `validate` would have caught the broken `aws_s3_bucket.state.arn` refs. CI's plan comment counts only when the plan is for the exact tier touched by the diff. |
| Go | `*.go`, `go.mod`, `go.sum` | `go build ./...`, `go test ./...`, `golangci-lint run` (or repo-configured linter) | |
| Python | `*.py`, `pyproject.toml`, `requirements*.txt` | `ruff check`, repo test runner (`pytest`), `mypy` if configured | |
| Elixir | `*.ex`, `*.exs`, `mix.exs`, `mix.lock` | `mix compile --warnings-as-errors`, `mix test`, `mix dialyzer` (if configured), `mix sobelow` (if configured) | `dialyzer` (type) and `sobelow` (security) are the Elixir-specific gates with no Python analog; both are conditional on being configured in the repo. |
| Shell | `*.sh`, `*.bash`, files with `#!/.../sh` | `shellcheck`, repo test runner if `bats`/`shunit2` present | |
| YAML / CI workflows | `.github/workflows/*.yml`, `*.yaml`, `*.yml` | `yamllint` (if configured), `actionlint` for workflow files | Workflow changes additionally require axis-3 attention to verify the workflow runs at least once green on this PR. |
| Markdown / docs only | `*.md` only (no code files in diff) | `markdownlint` if configured; otherwise no required verification | Pure-doc PRs pass axis 2 by default; axis 1 (conformance) and axis 3 (objective) still apply. |
| Claude skills / commands | `claude/skills/**`, `claude/commands/**` | See [Doctrine-class PR sub-checklist](#doctrine-class-pr-sub-checklist) below — there is no equivalent of `terraform validate` for skill markdown, so axis 2 substitutes a concrete manual list. | Doctrine-only skills (no `operations/` directory — pure reference) require every item; executor skills (have `operations/`) require items 1, 3, 4. Item 6 (mechanical host-agnosticism) applies to **any** PR touching published content, both kinds. |
| Claude workflows | `claude/workflows/*.js`, `.claude/workflows/*.js` | `node --check <file>` (JS syntax parse) for each changed workflow file, AND meta-shape validation — see [Workflow-class PR sub-checklist](#workflow-class-pr-sub-checklist) below. | Analogous to the Claude-skills doctrine-class row: there is no runtime test for a workflow script in review, so axis 2 substitutes parse + meta-shape as the static gate. |
| Mission data | `*.tsv` (mission-data artifacts) | Parse-check against the consuming script — run the script/function that reads or derives from the file and confirm it parses cleanly and the derived value computes (e.g. `measure-mission.sh calc_P` for `pipeline.tsv`) | The consuming script may live in another repo (guardian/mission); there is no static linter for ad hoc TSV schemas, so axis 2 substitutes this generic parse-check. |
| Mixed (multiple patterns) | Multiple rows match | Union of required steps from every matched row | All required steps must be green. A red Go test and a green TF plan in the same PR is FAIL. |

## Doctrine-class PR sub-checklist

There is no automated verifier for Claude-skills/commands markdown
— "manual axis-2 check" was the original entry, but per the
PR #158 review that wording produced an UNCLEAR self-application
and missed the L1↔L2 contract break the doctrine was meant to
prevent. The following concrete checklist substitutes. Failure of
any item emits an axis-2 finding at the listed severity (per
`checklist.md` severity rules):

1. **Artifact-path consistency** (correctness — **blocking**) —
   For every consumer skill that reads a producer skill's
   artifact, the producer's `operations/run.md` must actually
   write to the path the consumer's `operations/run.md` reads.
   Grep both directions; mismatches are blocking. Concrete
   recipe (substitute the actual producer/consumer pair):

   ```bash
   # Producer's write set — every path the producer writes:
   grep -rnE '\.claude/reviews/.*\.md|(write|cat\s*>) ' \
       claude/skills/<producer-skill>/operations/

   # Consumer's read set — every path the consumer reads:
   grep -rnE '\.claude/reviews/.*\.md|gh api .*/reviews|\
       l[0-9]+-review:metadata' \
       claude/skills/<consumer-skill>/operations/
   ```

   A consumer-side path that doesn't appear in the producer's
   write set is a mismatch — blocking finding. (Posted PR
   comments count as the producer's write set when the doctrine
   posting protocol is in use — see `checklist.md` "How the
   next layer reads the artifact".)

   This is the rule that would have caught PR #158's L1↔L2
   contract break (l2-review read `${L1_REVIEW_ARTIFACT_DIR:-...}`
   but l1-review wrote to `.claude/reviews/l1-latest.md` and
   stripped frontmatter before posting).
2. **Cross-skill reference resolution** (architecture — warning)
   — Every `../<skill>/...` link in SKILL.md and
   `references/<file>.md` link in operations must resolve to an
   existing path inside `claude/skills/`.
3. **SKILL.md frontmatter validity** (correctness — **blocking**)
   — YAML frontmatter must parse and declare `name`,
   `description`, `allowed-tools`, `version`. A skill that won't
   load is non-functional.
4. **Files referenced exist** (correctness — warning) — Every
   `Read(...)` / `Read: <path>` reference in operations must
   point at a file present in the diff or already in the repo.
   Dangling reads are a warning (the operation can degrade
   gracefully only if the doctrine says so explicitly).
5. **No inlined doctrine in consumer skills** (architecture —
   warning) — Doctrine-only skills (no `operations/` directory)
   own the rules; executor skills must point at the doctrine,
   not copy it. Duplicate paragraphs between a consumer and its
   doctrine source are a warning.
6. **Host-agnosticism verified mechanically** (correctness —
   **blocking** on a published surface) — Published content
   (skills, commands, docs) must carry no host-specific or
   private-instance leak. **Do NOT credit host-agnosticism on
   inspection alone** — eyeballing misses leaks at scale. Verify
   by *running a tool*:
   - Prefer the repo's host-agnostic guardrail when present —
     `sh scripts/check-host-agnostic.sh` — and require a clean
     (exit 0) result.
   - Otherwise, run an inline grep over the diff's published trees
     for the three leak classes: absolute home paths (`/Users/`,
     `/home/<name>`); private machine hostnames (sourced from a
     host-local blocklist / `~/.claude/hosts/` basenames — **never
     hardcode a private hostname into this doctrine**, that is
     itself a leak); and private-repo slugs / private-instance
     path segments. ANY hit is a finding, blocking for a published
     surface.
   - Once the repo's host-agnostic CI check is configured (a
     workflow that invokes the guardrail), require it **green** on
     the PR — treat a missing or red host-agnostic check as a gap
     (axis-2 finding, UNCLEAR → NEEDS-WORK rather than a silent
     PASS).

Item 1 is the load-bearing one for cross-skill contracts; item 6
is the load-bearing one against host/private leaks (mechanical,
never eyeballed); the others are loading/coherence checks. Running
them together takes a few minutes of grepping and is the actual
content of axis 2 for doctrine-class PRs.

## Workflow-class PR sub-checklist

There is no runtime test for a workflow script (`*.js` under
`claude/workflows/`) in review — its real behavior is its own
run, not static review. Axis 2 substitutes parse + meta-shape as
the static gate. Failure of any item emits an axis-2 finding at
the listed severity (per `checklist.md` severity rules):

1. **Parse** (correctness — **blocking**) — `node --check <file>`
   parses green for every changed `*.js` workflow. A non-parsing
   workflow is non-functional.
2. **meta-shape** (correctness — **blocking**) — the script
   declares `export const meta = { ... }` as the first statement,
   with at least `name` (string), `description` (string), and
   `phases` (array), and (per the Workflow `meta` rule) it is a
   pure literal — no variables, calls, or spreads. A missing or
   non-literal `meta` is blocking: the workflow won't load.
3. (Optional, info) Deeper runtime behavior isn't review-gated —
   that's the workflow's own run, not static review.

## Extending the map

When a PR's work type isn't listed:
1. Axis 2 returns UNCLEAR for that PR.
2. The review emits an `info` finding: `recommendation: extend
   lN-review-doctrine/references/verification-map.md with a row
   for <pattern>`.
3. The map gets a PR adding the row, following the table shape
   above.

Do not silently default new work types to "no verification
required" — that turns axis 2 into a rubber stamp.

## L{N}-specific notes

- **N=1 (l1-review)**: the steps above run on the L0's PR
  directly. Evidence: GitHub Actions checks (`gh pr checks <PR>`)
  and/or local commit-message annotations from the L0.
- **N=2 (l2-review)**: every constituent L0 PR L1 accepted must
  itself satisfy the steps above. l2-review's axis 2 reads the
  l1-review comment posted on each constituent PR (via the
  `<!-- l1-review:metadata -->` marker; see `checklist.md`
  "Posting protocol") and confirms l1-review's own axis 2
  PASSed. Transitive: if l1-review missed a required step,
  l2-review is the second line of defense.

## When the map is wrong

Same rule as `checklist.md`: fix it here via PR against `pfeff/claude-skills`. Do not patch verification rules inside the
review skills themselves.
