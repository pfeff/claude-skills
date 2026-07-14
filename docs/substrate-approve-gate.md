# Substrate-approve gate

`.github/workflows/substrate-approve.yml` lets a fully-reviewed self-PR satisfy branch
protection **legitimately** — no `--admin` bypass, no weakening of protection.

## Why it exists

On a public repo with branch protection, a merge needs an approving review. But our PRs are
self-authored, and GitHub forbids approving your own PR; the L2 verdict is posted as a
*comment* review (not an approval), which does not count. The gate closes that gap by having
a **non-author identity** — the "Claude Code Worker" GitHub App — post the counting approval
once the work is genuinely CLEAN.

## When it approves

On `pull_request_review` (submitted/edited) and `check_suite` (completed), the workflow
approves a PR only when **all** hold:

1. A review from the expected reviewer (`vars.L2_REVIEWER_LOGIN`) carries an
   `l2-review:metadata` block with `verdict: CLEAN` and `level: 2`.
2. That review's `commit_id` equals the current head SHA (the verdict is bound to the
   reviewed commit — a stale CLEAN cannot approve a later push).
3. Every check-run on the head SHA is green (and any legacy commit statuses, if present).

If the approver App secrets are not configured, the workflow skips cleanly. It is idempotent
per head SHA, so its own approval does not re-trigger an approval loop.
