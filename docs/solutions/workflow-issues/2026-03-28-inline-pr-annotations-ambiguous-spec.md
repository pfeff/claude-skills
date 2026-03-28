---
title: "Inline PR annotations fail due to ambiguous diff parsing spec"
date: 2026-03-28
problem_type: workflow_issue
severity: medium
symptoms:
  - "Review comments post as summary-only instead of inline on specific lines"
  - "422 errors from GitHub API when posting PR review"
  - "Findings land on wrong lines in PR diff"
  - "Path mismatch between finding file paths and diff file paths"
tags: [inline-comments, pr-review, diff-parsing, github-api, 422-error, post-review]
root_cause: "post-review.md Step 4 lacked explicit diff parsing algorithm — agents interpreted ambiguous instructions differently, leading to incorrect line maps and path mismatches"
module: review
component: post-review
repo: claude-skills
---

## Problem

The post-review operation spec (`skills/review/operations/post-review.md`) instructed agents to "track the right-side line numbers" from unified diffs but didn't specify the algorithm. Key gaps:

1. **No parsing algorithm**: How to extract file paths from `+++ b/<path>` headers (strip `b/` prefix), how `c` from `@@ -a,b +c,d @@` initializes the right-side counter, how to increment for context/added lines but not removed lines.
2. **No path normalization**: Findings use paths like `src/foo.js` but diffs use `b/src/foo.js` — no instruction to strip prefixes.
3. **No malformed finding handling**: Findings with non-integer lines or missing paths were silently dropped instead of falling back to body-only.
4. **Vague 422 recovery**: "Remove the offending comment and retry" with no identification strategy, retry cap, or final fallback.

## Solution

Updated post-review.md with three targeted fixes:

**Step 4 — Explicit parsing algorithm**:
- Extract file paths by stripping `b/` from `+++ b/<path>`
- Per-hunk line tracking: `right_line = c`, increment for context (` `) and added (`+`) lines, skip removed (`-`) lines
- Edge cases: binary files, rename-only diffs, `+++ /dev/null` (deleted files)

**Steps 5-6 — Path normalization and malformed finding handling**:
- Strip leading `./` from finding paths before lookup
- Malformed findings (non-positive-integer line, bad format) classified as body-only instead of dropped

**Step 9 — 422 recovery procedure**:
1. Log error body
2. Identify offending comment from error message
3. Move offending comments to review body
4. Retry once
5. If second 422, post body-only review — no further retries

## Prevention

- Spec files for agent-interpreted operations should include explicit algorithms, not just intent descriptions
- Path handling should always specify normalization rules when data crosses format boundaries (findings vs diffs)
- Error recovery procedures should always specify: identification method, retry cap, and final fallback
