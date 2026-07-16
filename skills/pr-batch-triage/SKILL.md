---
name: pr-batch-triage
description: >-
  Triage a whole QUEUE of open PRs to merge: scope the batch, fan out the
  review stages across all PRs in parallel, synthesize a ranked human-review
  handoff, then drive each PR to merge. Use when asked to "triage the PR
  queue", "review these PRs", "clear the open PRs", or handed a stack of PRs.
  Orchestrates `pr-review-workflow` per PR — for a single PR, use that directly.
version: 1.0.0
allowed-tools:
  - Bash
  - Agent
  - AskUserQuestion
  - Read
---

# pr-batch-triage — queue of PRs → merged

## 1. Scope the batch
`gh pr list --repo <owner/repo> --state open --json
number,title,author,headRefName,createdAt`. If scope is ambiguous (recent
batch vs every open PR incl. stragglers), ask via `AskUserQuestion`.

## 2. Fan out review stages (parallel)
Dispatch one Sonnet subagent per PR running **stages (a)+(b) of
`pr-review-workflow`** — automated review (post the sticky marker comment) +
problem-grounded intent reconciliation. Subagents never approve/merge.

## 3. Synthesize the human-review handoff
Ranked table: PR · verdict (+counts) · intent (matches/drift/superseded) ·
CI + mergeable · recommendation. Call out cross-PR collisions (same
file/anchor, version bumps), a dependency-aware **merge order**, and paired
PRs.

## 4. Drive each PR through the workflow's human + merge stages
Loop PRs (in merge order), one at a time, through **stages (c)+(d) of
`pr-review-workflow`**: present summary + intent + justification, take the
operator decision, dispatch fix/rebase workers + re-review as needed, then
account-aware approval + merge. Verify each landed; re-fan a re-review after
any material change.

## Edge Cases
- All the `pr-review-workflow` edge cases apply per PR (account mapping, merge
  method, re-review threshold, paired PRs, worktree reconciliation, closes).
- **Cross-PR conflicts**: two PRs touching the same file/anchor — sequence
  them; the second rebases (and re-bumps version) after the first merges.
- **Keystone ordering**: merge a blocker-clearing PR first when others depend
  on it.
- Batch scope (recent vs all) is a judgment call — confirm.

## See also
- `pr-review-workflow` — the per-PR pipeline this orchestrates.
- `review` — the automated-review engine invoked within each PR's stage (a).
