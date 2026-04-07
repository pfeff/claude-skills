# Validate Coverage Operation

Check for requirements without issues and issues without requirements.

## Purpose

Ensures complete traceability by identifying:
- Requirements defined in REQUIREMENTS.md without corresponding issues
- Issues in GitHub Project without requirement IDs

## Implementation

### 1. Ensure Guardian Repo is Current

Pull latest changes before reading files. Abort if the pull fails (e.g., diverged branch).

```bash
GUARDIAN_PATH="${HOME}/src/github/pfeff/guardian"
cd "${GUARDIAN_PATH}" && git pull --ff-only
```

If `git pull --ff-only` fails, **stop the operation** and report the error. The local branch may have diverged from the remote — resolve manually before retrying.

### 2. Extract Defined Requirements

Parse REQUIREMENTS.md for requirement IDs:

```bash
GUARDIAN_PATH="${HOME}/src/github/pfeff/guardian"
grep -oE '\b[A-Z]{2}-[A-Z]+-[0-9]+\b' "${GUARDIAN_PATH}/REQUIREMENTS.md" | sort -u > /tmp/defined_reqs.txt
```

### 3. Extract Linked Requirements

Query GitHub Project for requirement IDs in use:

```bash
gh project item-list 4 --owner pfeff --format json --limit 500 | \
  jq -r '.items[] | .["Requirement ID"] // empty' | \
  sort -u > /tmp/linked_reqs.txt
```

### 4. Compare Sets

Find gaps in both directions:

```bash
echo "## Requirements without issues:"
comm -23 /tmp/defined_reqs.txt /tmp/linked_reqs.txt

echo ""
echo "## Issues referencing unknown requirements:"
comm -13 /tmp/defined_reqs.txt /tmp/linked_reqs.txt
```

### 5. Report Results

Output format:

```
Checking requirement coverage...

## Requirements without issues:
AO-SEC-02
CR-SKILL-02

## Issues referencing unknown requirements:
AO-UNKNOWN-99

Coverage: 15/18 requirements linked (83%)
```

## Script Reference

The guardian repo includes `scripts/validate-coverage.sh`:

```bash
cd ~/src/github/pfeff/guardian
./scripts/validate-coverage.sh
```

## Recommended Actions

For **requirements without issues**:
1. Create issue(s) in appropriate repository
2. Add to GitHub Project #4
3. Set "Requirement ID" custom field
4. Run sync-traceability to update matrix

For **issues with unknown requirement IDs**:
1. Verify requirement ID is correct
2. If valid, add requirement to REQUIREMENTS.md
3. If typo, update the issue's Requirement ID field

For **unlinked issues** (no requirement ID):
1. Determine if issue relates to existing requirement
2. If yes, set the Requirement ID field
3. If no, either:
   - Create new requirement using add-requirement operation
   - Mark as non-requirement work (optional "ADMIN" or "MAINT" prefix)

## Coverage Thresholds

| Coverage | Status | Action |
|----------|--------|--------|
| 90-100% | Green | Maintain |
| 70-89% | Yellow | Address before release |
| <70% | Red | Prioritize gap closure |
