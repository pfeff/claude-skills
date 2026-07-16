---
name: pr-review-workflow
description: >-
  The disciplined four-stage pipeline for taking ONE pull request from review
  to merge: (a) automated review, (b) problem-grounded intent reconciliation,
  (c) human review, (d) account-aware gh approval + merge. Use when reviewing
  and landing a single PR, or when asked for "automated review + reconcile with
  intent + human review" on a PR. For a QUEUE of PRs, `pr-batch-triage` runs
  this pipeline across many; for the parallel-specialist automated-review engine
  alone, see `review`.
version: 1.0.0
allowed-tools:
  - Bash
  - Agent
  - AskUserQuestion
  - Read
---

# pr-review-workflow — one PR, review → merge

## (a) Automated review
Read the full diff; assess correctness, security, simplicity, scope-creep.
(Delegate to the `review` engine for a parallel-specialist pass when the diff
is large.) Post a **single sticky verdict comment**, upserted in place — edit
the existing `<!-- review:metadata -->` comment (`gh api -X PATCH
.../issues/comments/<id>`, note `-F` not `-f` for `body=@file`), else create —
with a `**<VERDICT>**` headline (CLEAN/ADVISORY/BLOCKING) + metadata block.

## (b) Intent reconciliation (problem-grounded)
Judge the diff against **the problem it was meant to solve**, never a
restatement of its title. Source the problem from the PR body Summary/Context,
linked issues, operator-correction memories, or session friction; then decide
whether the diff resolves *that*. **A missing motivating problem is itself a
finding.** Flag drift, scope creep, supersession, staleness, conflicts.

## (c) Human review
Present to the operator: **change summary + problem-grounded intent
reconciliation + justification for approval**. Take the decision via
`AskUserQuestion` (approve / fix / rebase / close / hold).
- On **fix/rebase/close**: dispatch a worktree-isolated worker, then
  **re-review the post-change diff** before approval (fix-then-re-review).
  Pure rebase / one-liner may trust self-verification; materially new code
  gets a fresh review pass.

## (d) gh approval + merge (account-aware)
- **A PR author cannot approve their own PR** — approve from the *other*
  account. **Verify the author first** (`gh pr view <n> --json author`); never
  assume the mapping (wrong guess → "Can not approve your own pull request").
- The agent is **barred from recording approvals** (two-party review):
  approvals are operator actions (`! gh pr review --approve`) from the correct
  account. Merging an already-approved PR (incl. as author) is fine.
- Merge with the **repo's method** (e.g. squash vs `--merge`); verify it
  landed (`gh pr view --json state,mergedAt`).

## Edge Cases
- Account mapping must be verified per PR.
- Merge method differs per repo (squash disabled on some).
- Re-review threshold: rebase/one-liner vs materially new code.
- Paired PRs across repos: merge both or neither.
- Force-pushed branch with a live worktree: reconcile (usually stale-index
  noise vs real work) before merging to avoid orphaning.
- Superseded PR: recommend close with a pointer to the merged replacement.

## See also
- `pr-batch-triage` — runs this pipeline across a queue of PRs.
- `review` — the parallel-specialist automated-review engine used in (a).
- `l1-review` / `l2-review` — supervisory reviews that read the `review:metadata` marker this workflow posts.
