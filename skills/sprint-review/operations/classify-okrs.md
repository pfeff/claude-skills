# Classify OKRs Operation

Map closed issues and merged PRs to strategic streams using REQUIREMENTS.md as the OKR source. Produces a breakdown table by stream for the report.

**References**: R2 (OKR Classification)

## Inputs

| Input | Source | Description |
|-------|--------|-------------|
| Issues list | gather-data output | All issues closed in the sprint, with labels and body |
| PRs list | gather-data output | All PRs merged in the sprint |
| OKR source | `guardian/REQUIREMENTS.md` | Strategic stream and requirement definitions |

## Strategic Streams

The streams are derived from the OKR prefix pattern in REQUIREMENTS.md:

| Stream | OKR Prefix | Focus |
|--------|-----------|-------|
| S1: Generate Revenue | `S1-E*/KR1.*` | Revenue model, market validation, impact measurement |
| S2: Maintain Stability | `S2-E*/KR2.*` | Process maturity, documentation, conventions |
| S3: Compound the Advantage | `S3-E*/KR3.*` | Agent tooling, orchestration, automation |

## Process

### 1. Fetch OKR Definitions

Read REQUIREMENTS.md from the local guardian clone to build the requirement-to-stream mapping:

```
Read ~/src/github/pfeff/guardian/REQUIREMENTS.md
```

Parse each requirement block to extract:
- **Requirement ID** (e.g., `AO-CORE-01`)
- **OKR field** (e.g., `S3-E1/KR3.1`)
- **Stream** — the `S1`, `S2`, or `S3` prefix from the OKR field

Build a lookup: `requirement_id → stream`.

### 2. Classify Each Issue

For each closed issue from the gather-data output, attempt classification in priority order:

1. **Requirement ID in body or title** — Match patterns like `AO-CORE-01`, `CR-SKILL-02`, `GN-REV-01` against the requirement-to-stream lookup. Scan issue body for requirement ID references (e.g., in commit messages, PR links, or explicit mentions).

2. **OKR reference in body** — Match direct OKR patterns like `S3-E1/KR3.1` or `KR1.2` in the issue body or title. Extract the stream prefix.

3. **Repository heuristic** — If the issue's repo has a dominant stream mapping in REQUIREMENTS.md, use that as a soft signal:
   - `agent-orchestrator` → predominantly S3
   - `agent-coordinator` → predominantly S3
   - `cursor-rules` → predominantly S3
   - `guardian` → mixed (check further)

4. **Label-based** — Map known labels to streams if the repo uses them (e.g., `revenue`, `process`, `tooling`).

5. **Keyword matching** — As a last resort, scan title/body for stream-indicative keywords:
   - S1: revenue, market, customer, pricing, validation, pilot, LOI, business model
   - S2: process, stability, documentation, convention, hygiene, maintenance
   - S3: agent, orchestrator, coordinator, skill, automation, backend, routing, TUI

6. **Unclassified** — If none of the above produce a match, mark as `Unclassified`.

### 3. Classify Each PR

Apply the same classification logic as issues. PRs often reference issues, so additionally:

- **Linked issue** — If the PR body contains `Closes #N`, `Fixes #N`, or `Resolves #N`, inherit the classification from the linked issue.
- **PR branch name** — Branch names like `feat/AO-CORE-01-state-machine` contain requirement IDs.

### 4. Produce Stream Breakdown Table

Aggregate classifications into a summary table:

```markdown
## Strategic Alignment (OKR Mapping)

| Stream | Issues | PRs | Focus |
|--------|--------|-----|-------|
| S1: Generate Revenue | 24 | 12 | Revenue model ADRs, baseline measurement |
| S2: Maintain Stability | 6 | 7 | Process documentation, conventions |
| S3: Compound the Advantage | 63 | 44 | Agent backends, routing, coordinator foundation |
| Unclassified | 0 | 0 | — |
```

The **Focus** column is a brief summary of what the classified items actually covered — not a restatement of the stream definition. Derive it from the titles of the classified items.

### 5. Produce Detailed Classification List

For transparency and downstream use, output the per-item classification:

```markdown
### Classification Details

| Repo | # | Title | Stream | Method |
|------|---|-------|--------|--------|
| guardian | #42 | Revenue model ADR | S1 | requirement-id (GN-REV-01) |
| guardian | #50 | Update CLAUDE.md conventions | S2 | keyword |
| agent-orchestrator | #15 | Add Gemini backend | S3 | requirement-id (AO-AGENT-01) |
| guardian | #55 | Fix typo in README | Unclassified | — |
```

The **Method** column records which classification step produced the match, aiding review and refinement.

## Handling Ambiguity

- If an issue maps to multiple streams (e.g., OKR field lists `S3-E1/KR3.1, S1-E2/KR1.5`), classify under the **first** stream listed.
- If classification confidence is low (keyword-only match), note it in the Method column as `keyword (low confidence)`.
- Present unclassified items prominently — a high unclassified count signals that REQUIREMENTS.md coverage or issue hygiene needs attention.

## Output

This operation's output is consumed by:
- **generate-report** — the stream breakdown table goes directly into the Strategic Alignment section
- **reconcile-board** — stream data enriches the board reconciliation with OKR context
