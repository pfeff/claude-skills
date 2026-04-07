# Changelog

All notable changes to the **obsidian-notes** skill will be documented in this file.

## [2.0.0] - 2026-03-05

### Added
- Complete Obsidian CLI (v1.12+) command reference (`references/cli.md`)
- CLI prerequisites and setup documentation
- CLI-based operations for search, properties, tags, and daily notes
- Decision guide for CLI vs direct file operations
- obsidian-headless documentation for sync-only use cases

### Changed
- Updated skill to prefer CLI commands for link-safe operations
- Properties management now uses `obsidian property:set`
- File moves now use `obsidian move` to preserve links
- Direct file write reserved for full note content creation

### Deprecated
- Low-level file operations for property/tag management (use CLI instead)

**Reasoning**: Obsidian 1.12 introduced official CLI with link-safe operations, native property management, and integrated search. CLI ensures data integrity compared to direct file manipulation.

## [1.0.0] - 2026-02-15

### Added
- Initial version tracking

**Reasoning**: Baseline version established to enable skill evolution tracking (pfeff/cursor-rules#36).
