# Project #4 Field IDs

Cached field metadata for GitHub Project #4 (`pfeff`). Eliminates the need to query `gh project field-list` before setting field values.

**Last refreshed**: 2026-02-24

## Project

| Key | Value |
|-----|-------|
| Owner | `pfeff` |
| Number | `4` |
| Node ID | `PVT_kwHNa8POARiyqQ` |

## Fields

Most commonly set fields: **Status**, **Requirement ID**, **OKR**, **Sprint**, **Strategic Objective**, **Horizon**.

| Field | ID | Type |
|-------|----|------|
| Title | `PVTF_lAHNa8POARiyqc4N0wga` | Text |
| Assignees | `PVTF_lAHNa8POARiyqc4N0wgb` | Text |
| Status | `PVTSSF_lAHNa8POARiyqc4N0wgc` | SingleSelect |
| Labels | `PVTF_lAHNa8POARiyqc4N0wgd` | Text |
| Linked pull requests | `PVTF_lAHNa8POARiyqc4N0wge` | Text |
| Milestone | `PVTF_lAHNa8POARiyqc4N0wgf` | Text |
| Repository | `PVTF_lAHNa8POARiyqc4N0wgg` | Text |
| Reviewers | `PVTF_lAHNa8POARiyqc4N0wgh` | Text |
| Parent issue | `PVTF_lAHNa8POARiyqc4N0wgi` | Text |
| Sub-issues progress | `PVTF_lAHNa8POARiyqc4N0wgj` | Text |
| OKR | `PVTF_lAHNa8POARiyqc4PS04Q` | Text |
| Requirement ID | `PVTF_lAHNa8POARiyqc4PS04R` | Text |
| Architecture Component | `PVTSSF_lAHNa8POARiyqc4PS04S` | SingleSelect |
| Workflow Priority | `PVTF_lAHNa8POARiyqc4PS04a` | Text |
| Horizon | `PVTSSF_lAHNa8POARiyqc4PUq7b` | SingleSelect |
| Sprint | `PVTSSF_lAHNa8POARiyqc4PbrwT` | SingleSelect |
| Strategic Objective | `PVTSSF_lAHNa8POARiyqc4Pbrxg` | SingleSelect |

## Single-Select Options

### Status

| Option | ID |
|--------|----|
| Backlog | `f235fcf2` |
| Planned | `eeeb34e7` |
| In Progress | `cb2de778` |
| Review | `fcf9e71d` |
| Done | `f0e6c77a` |
| Cancelled | `168af494` |

### Architecture Component

| Option | ID |
|--------|----|
| Orchestrator Core | `3cd009b1` |
| Agent Abstraction Layer | `295856ee` |
| Security Model | `48d470df` |
| Integration Layer | `97984d8a` |
| Observability | `a42b09e7` |

### Horizon

| Option | ID |
|--------|----|
| H1: Now (maintain) | `3a1d6140` |
| H2: Next (build) | `e0177cca` |
| H3: Future (scale) | `eeee012e` |

### Sprint

| Option | ID |
|--------|----|
| Sprint 1 (Feb 17-21) | `fc2bcc83` |
| Sprint 2 (Feb 24-28) | `8a3a19ee` |
| Backlog | `21f1d532` |

### Strategic Objective

| Option | ID |
|--------|----|
| S1: Generate Revenue | `996b68eb` |
| S2: Maintain Stability | `3c8cd543` |
| S3: Compound the Advantage | `8632094a` |
| Maintenance | `5f022452` |

## Refresh Instructions

Sprint options change each sprint. Refresh after each sprint planning session.

To refresh, run:

```bash
TMPF=$(mktemp)
cat > "$TMPF" <<'EOF'
query($owner: String!) {
  user(login: $owner) {
    projectV2(number: 4) {
      id
      fields(first: 50) {
        nodes {
          ... on ProjectV2Field { id name }
          ... on ProjectV2SingleSelectField { id name options { id name } }
        }
      }
    }
  }
}
EOF
gh api graphql -F query="$(cat $TMPF)" -f owner=pfeff | jq .
rm "$TMPF"
```

Update the tables above with the output and set **Last refreshed** to today's date.
