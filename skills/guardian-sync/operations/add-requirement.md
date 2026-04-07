# Add Requirement Operation

Add a new requirement with proper ID and cross-references.

## Purpose

Ensures new requirements are added consistently with:
- Proper ID following naming convention
- OKR linkage
- Architecture references
- Optional issue creation

## Inputs

Gather from user:

| Field | Required | Description | Example |
|-------|----------|-------------|---------|
| Project | Yes | Target project prefix | AO, CR, GN |
| Category | Yes | Requirement category | CORE, AGENT, SKILL, SEC, INT, OBS, NFR |
| Title | Yes | Requirement title | "Guardian Sync Skill" |
| Description | Yes | Requirement description | "Skill for syncing traceability..." |
| OKR | Yes | Linked objective/key result | O2/KR2.1 |
| Priority | Yes | P0, P1, P2 | P1 |
| Architecture | No | Link to ARCHITECTURE.md section | Agent Abstraction Layer |

## Implementation

### 1. Ensure Guardian Repo is Current

Pull latest changes before modifying any files. Abort if the pull fails (e.g., diverged branch).

```bash
GUARDIAN_PATH="${HOME}/src/github/pfeff/guardian"
cd "${GUARDIAN_PATH}" && git pull --ff-only
```

If `git pull --ff-only` fails, **stop the operation** and report the error. The local branch may have diverged from the remote — resolve manually before retrying.

### 2. Determine Next ID

Find the highest existing ID for the project/category:

```bash
GUARDIAN_PATH="${HOME}/src/github/pfeff/guardian"
grep -oE '\b(AO|CR|GN)-[A-Z]+-[0-9]+\b' "${GUARDIAN_PATH}/REQUIREMENTS.md" | \
  grep "^${PROJECT}-${CATEGORY}" | \
  sort -t- -k3 -n | tail -1
```

Increment the number for the new ID.

### 3. Format Requirement Block

Use this template:

```markdown
### {ID}: {Title}
**OKR:** {OKR}
**Priority:** {Priority}
**Status:** Not Started
**Architecture:** [{Architecture Section}](ARCHITECTURE.md#{anchor})
**Issues:** (none yet)

{Description}
```

### 4. Insert into REQUIREMENTS.md

Add to appropriate section (Functional or Non-Functional Requirements).

Requirements should be grouped by project prefix (AO, CR, GN) and sorted by category and number.

### 5. Update Architecture (Optional)

If the requirement introduces a new component or significantly changes existing architecture:

1. Add or update the relevant section in ARCHITECTURE.md
2. Reference the new requirement ID

### 6. Create Issue (Optional)

If user wants to create implementation issue:

```bash
gh issue create \
  --repo pfeff/{repo} \
  --title "{Title}" \
  --body "Implements requirement {ID}

## Requirement

{Description}

## Acceptance Criteria

- [ ] Implementation complete
- [ ] Tests passing
- [ ] Documentation updated"
```

Then add to project and set custom fields using cached IDs from `references/project-field-ids.md`:

```bash
# Add to project
gh project item-add 4 --owner pfeff --url {issue_url}

# Set fields using cached IDs (see references/project-field-ids.md)
# Example: set Requirement ID (text field)
gh project item-edit --project-id PVT_kwHNa8POARiyqQ \
  --id {item_id} \
  --field-id PVTF_lAHNa8POARiyqc4PS04R \
  --text "{requirement_id}"

# Example: set Status to "In Progress" (single-select field)
gh project item-edit --project-id PVT_kwHNa8POARiyqQ \
  --id {item_id} \
  --field-id PVTSSF_lAHNa8POARiyqc4N0wgc \
  --single-select-option-id cb2de778
```

## Example

**Input**:
- Project: CR
- Category: SKILL
- Title: Guardian Sync Skill
- Description: Skill for synchronizing Guardian documentation and traceability matrix
- OKR: O2/KR2.1
- Priority: P1

**Generated ID**: CR-SKILL-01

**REQUIREMENTS.md entry**:

```markdown
### CR-SKILL-01: Guardian Sync Skill
**OKR:** O2/KR2.1
**Priority:** P1
**Status:** Not Started
**Architecture:** [Cursor-Rules Integration](ARCHITECTURE.md#cursor-rules-integration)
**Issues:** (none yet)

Skill for synchronizing Guardian documentation and traceability matrix. Provides operations for regenerating TRACEABILITY.md from GitHub Project data, validating requirement coverage, and adding new requirements.
```

## Post-Add Validation Checklist

After adding a requirement, verify all cross-references exist:

- [ ] REQUIREMENTS.md contains the new requirement block with correct ID
- [ ] OKR linkage matches an existing objective in PROJECT.md
- [ ] Architecture section referenced exists in ARCHITECTURE.md (if specified)
- [ ] Requirement ID follows naming convention: `{PROJECT}-{CATEGORY}-{NN}`
- [ ] Status is set to "Not Started"
- [ ] If issue created: issue URL is added to the **Issues** field
- [ ] If issue created: issue is added to the Guardian project board
- [ ] TRACEABILITY.md is regenerated via `sync-traceability` to include the new requirement

**Automated check** (run after adding):
```bash
GUARDIAN_PATH="${HOME}/src/github/pfeff/guardian"
# Verify requirement ID exists in REQUIREMENTS.md
grep -q "{ID}" "${GUARDIAN_PATH}/REQUIREMENTS.md" && echo "✅ REQUIREMENTS.md" || echo "❌ REQUIREMENTS.md"
# Verify TRACEABILITY.md references the requirement
grep -q "{ID}" "${GUARDIAN_PATH}/TRACEABILITY.md" && echo "✅ TRACEABILITY.md" || echo "❌ TRACEABILITY.md"
# Verify architecture reference (if specified)
grep -q "{ARCHITECTURE_SECTION}" "${GUARDIAN_PATH}/ARCHITECTURE.md" && echo "✅ ARCHITECTURE.md" || echo "❌ ARCHITECTURE.md"
```

## Post-Add Actions

1. Commit changes to REQUIREMENTS.md
2. If architecture updated, commit ARCHITECTURE.md
3. Run sync-traceability if issue was created
4. Notify team of new requirement if significant
