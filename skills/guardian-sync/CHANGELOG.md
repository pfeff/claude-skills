# Changelog

All notable changes to the **guardian-sync** skill will be documented in this file.

## [1.2.0] - 2026-02-24

### Added
- Repo freshness check (`git pull --ff-only`) as step 1 in all three operations (sync-traceability, validate-coverage, add-requirement)

**Reasoning**: Operations edited guardian repo files without ensuring the local branch was current, causing merge conflicts when the remote had diverged. Source: REC-002 from 202602162320-Lessons Learned - Guardian Milestone Tracking.md.

## [1.1.0] - 2026-02-15

### Added
- Post-add validation checklist in add-requirement operation verifying cross-references across REQUIREMENTS.md, ARCHITECTURE.md, and TRACEABILITY.md

**Reasoning**: Adding requirements requires updating several cross-references that were easy to miss, leading to inconsistent documentation. Source: REC-002 from 202602141029-Lessons-Learned-Document-Claude-Code-Primary-Backend.md.

## [1.0.0] - 2026-02-15

### Added
- Initial version tracking

**Reasoning**: Baseline version established to enable skill evolution tracking (pfeff/cursor-rules#36). Skill already had version field.
