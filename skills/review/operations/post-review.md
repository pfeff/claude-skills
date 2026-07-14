# Post Review

Publishes the review from `.claude/reviews/latest.md` to a PR as a **single sticky
verdict comment** that is edited in place on every re-run — never appended. When the
reviewer is not the PR author, it also submits a lightweight formal review event
(`REQUEST_CHANGES` / `APPROVE`) so the PR's merge box reflects the verdict.

**Requires**: PR number passed as `$PR_NUMBER`. Must be a positive integer.

## Design

- **One comment, updated in place.** A single issue comment carries the full,
  human-readable review. It is identified by a hidden `<!-- review:metadata -->`
  marker. Re-running `/review` finds that comment and `PATCH`es it — the PR
  conversation never accumulates stale review dumps.
- **The comment is the authoritative artifact.** Its `**<VERDICT>**` line and the
  trailing `<!-- review:metadata -->` block are what higher layers (`l1-review`)
  read. This holds whether or not the formal review event succeeds.
- **The formal review event is best-effort.** GitHub rejects `REQUEST_CHANGES` and
  `APPROVE` on your own PR (422). When the reviewer is the PR author, skip the event
  silently — the sticky comment stands on its own.
- **No inline line comments.** Findings live in the one readable comment, not
  scattered across the diff.

## Step 1: Read Review Output

Read `.claude/reviews/latest.md` (relative to working directory). If the file does
not exist, stop silently — there is nothing to post.

## Step 2: Parse Frontmatter

Extract from the YAML frontmatter:
- `verdict`: `BLOCKING` or `CLEAN`
- `blocking`: integer count
- `advisory`: integer count
- `target`, `agents`, `degraded`: for the comment header

Unlike the old behavior, **do not skip** when `blocking + advisory == 0`. A clean
result still updates the sticky comment (so a previously-blocking comment flips to
clean on re-review) and, when applicable, submits an `APPROVE`.

## Step 3: Get Repository and Identity Context

```bash
read -r owner repo <<<"$(gh repo view --json owner,name -q '.owner.login + " " + .name')"
reviewer=$(gh api user -q .login)
pr_author=$(gh pr view "$PR_NUMBER" --json author -q .author.login)
```

Validate `owner` and `repo` contain only alphanumerics, hyphens, and underscores.
Validate `$PR_NUMBER` is a positive integer. Set `IS_SELF_PR=true` when `$reviewer`
equals `$pr_author`.

## Step 4: Parse Findings

Each finding line in `latest.md` follows:

```
- **file:line** — [agent] _category_ (severity) — Description
```

For each, extract `file`, `line`, `category`, and `description` (the `[agent]` tag is
not rendered in the readable comment, so it can be ignored). `(severity)` may be absent
on blocking findings — treat as `critical`. If a line doesn't match, keep its raw text
and render it verbatim (never drop a finding). Track which section
(`### Blocking` / `### Advisory`) each finding came from.

## Step 5: Compose the Comment Body

Build a readable Markdown body. Use the verdict to pick the heading:

| Verdict | Heading |
|---------|---------|
| `BLOCKING` | `## 🔴 Code Review — Changes requested` |
| `CLEAN` with advisories | `## 🟡 Code Review — No blocking issues` |
| `CLEAN`, zero findings | `## ✅ Code Review — Clean` |

Then, in order:

1. **Verdict line (authoritative, exact):**
   ```
   **<VERDICT>** — <blocking> blocking · <advisory> advisory
   ```
2. **Meta line** (italic, one line):
   `_Target: <target> · <agents> agents · updated <ISO-8601 UTC>_`
   Append ` · ⚠️ degraded-mode` when `degraded: true`.
3. A `---` divider.
4. **`### 🚫 Blocking (<n>)`** — omit if none. One entry per finding:
   ```
   **`<file>:<line>`** · <category>
   <description>
   ```
   (blank line between entries)
5. **`### 💡 Advisory (<n>)`** — omit if none. Same entry shape, with the severity
   shown when present: **`<file>:<line>`** · <category> · _<severity>_.
6. When there are zero findings, replace sections 3–5 with a single line:
   `No issues found across <agents> agents.`
7. **Trailing marker** (hidden HTML comment — the cross-operator contract; keep field
   names exact):
   ```
   <!-- review:metadata
   verdict: <CLEAN|BLOCKING>
   level: 0
   pr: <PR_NUMBER>
   target: <owner>/<repo>#<PR_NUMBER>
   blocking: <count>
   advisory: <count>
   reviewed_at: <ISO-8601 UTC>
   reviewer: review
   -->
   ```

Keep descriptions to 1–2 sentences; the goal is scannability. Write the composed body
to a temp file the later steps read:

```bash
BODYFILE=$(mktemp /tmp/review-body.XXXXXX.md)
chmod 600 "$BODYFILE"
# write the composed Markdown body to $BODYFILE
```

## Step 6: Upsert the Sticky Comment

Find an existing review comment authored by the current user carrying the marker, then
edit it; otherwise create a new one. Most-recent wins.

The lookup and the create/patch decision are separated deliberately: a **failed**
lookup (rate limit, network) must NOT be mistaken for "no existing comment found," or a
transient error would create a duplicate marker comment. Check the lookup's exit status
and hard-stop on failure — only an empty result from a *successful* lookup means create.

```bash
if ! EXISTING=$(gh api "/repos/$owner/$repo/issues/$PR_NUMBER/comments" --paginate \
  --jq "map(select(.user.login == \"$reviewer\" and (.body | contains(\"<!-- review:metadata\")))) | sort_by(.created_at) | last | .id // empty"); then
  echo "review: comment lookup failed — aborting to avoid a duplicate post" >&2
  exit 1
fi

if [ -n "$EXISTING" ]; then
  gh api -X PATCH "/repos/$owner/$repo/issues/comments/$EXISTING" -F body=@"$BODYFILE"
else
  gh api -X POST "/repos/$owner/$repo/issues/$PR_NUMBER/comments" -F body=@"$BODYFILE"
fi
```

This is the operation's core guarantee: **at most one review comment per reviewer, always current.**

## Step 7: Submit the Formal Review Event (best-effort)

**Skip this step entirely if `IS_SELF_PR=true`** — GitHub blocks review events on your
own PR. The sticky comment from Step 6 is the verdict.

Otherwise, keep the merge box in sync without stacking. Neither a `REQUEST_CHANGES`
nor an `APPROVE` event may accumulate across re-runs.

1. **Read the reviewer's current review state.** Fetch the most-recent review this
   reviewer has left on the PR (used both to clear stale blocks and to suppress a
   redundant `APPROVE`):
   ```bash
   LAST_STATE=$(gh api "/repos/$owner/$repo/pulls/$PR_NUMBER/reviews" --paginate \
     --jq "map(select(.user.login == \"$reviewer\")) | sort_by(.submitted_at) | last | .state // empty")
   ```
2. **Clear stale blocks.** Dismiss any active (non-dismissed) `REQUEST_CHANGES` review
   authored by the current user, so re-reviews don't pile up:
   ```bash
   gh api "/repos/$owner/$repo/pulls/$PR_NUMBER/reviews" --paginate \
     --jq "map(select(.user.login == \"$reviewer\" and .state == \"CHANGES_REQUESTED\")) | .[].id" \
   | while read -r rid; do
       gh api -X PUT "/repos/$owner/$repo/pulls/$PR_NUMBER/reviews/$rid/dismissals" \
         -f message="Superseded by re-review." -f event="DISMISS"
     done
   ```
3. **Submit the new event — but not a redundant one.** Body is a one-liner pointing at
   the sticky comment (the detail lives there, so the event stays lightweight and never
   becomes a second large comment):
   - `BLOCKING` → submit `event: REQUEST_CHANGES`, body `Changes requested — see the review summary comment.` (the prior block was just dismissed, so exactly one active `CHANGES_REQUESTED` remains).
   - `CLEAN` → **skip entirely if `LAST_STATE == "APPROVED"`** (an approval is already standing; re-posting would stack a second "Approved" event). Otherwise submit `event: APPROVE`, body `No blocking issues — see the review summary comment.`
   ```bash
   gh api -X POST "/repos/$owner/$repo/pulls/$PR_NUMBER/reviews" \
     -f event="$EVENT" -f body="$EVENT_BODY"
   ```

## Step 8: Report

Tell the user: whether the sticky comment was created or updated, the verdict, and
whether a formal `REQUEST_CHANGES`/`APPROVE` event was submitted or skipped (self-PR).

## Error Handling

| Error | Action |
|-------|--------|
| `.claude/reviews/latest.md` missing | Stop silently |
| `$PR_NUMBER` not a positive integer | Report error, stop |
| `gh repo view` / `gh api user` / `gh pr view` fails | Report error, stop |
| Comment lookup or upsert (Step 6) fails | Report the error and stop — never fall through to create on a failed lookup, or a transient error duplicates the comment. This is the authoritative artifact. |
| Formal review event (Step 7) returns 422 | The reviewer is likely the PR author despite the check, or the PR state disallows it. Log it, skip the event, keep the sticky comment. Do not retry. |
| Dismissal (Step 7.2) fails | Log and continue to the submit step — a lingering stale review is cosmetic, not blocking |
