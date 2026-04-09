# Changelog

All notable changes to the **self-improvement** skill will be documented in this file.

## [1.1.0] - 2026-02-15

### Added
- Version management step (Step 5c) in apply-improvement operation
- Automatic skill version bumping (patch/minor/major) when applying changes to skill files
- CHANGELOG.md entry generation with reasoning and REC-ID traceability
- Version update reporting in apply results output

**Reasoning**: Without automatic version management, skill improvements were applied but not tracked. This ensures every improvement is recorded with its motivation, closing the version tracking gap in the evolution pipeline (pfeff/cursor-rules#36, R1/R3).

## [1.0.0] - 2026-02-15

### Added
- Initial version tracking

**Reasoning**: Baseline version established to enable skill evolution tracking (pfeff/cursor-rules#36).
