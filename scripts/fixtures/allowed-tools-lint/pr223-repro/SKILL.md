---
name: l1-review
description: L1-over-L0 work-product review. Applies the shared L{N}-review 3-axis doctrine (Conformance / Process / Objective Advancement) to a single L0 PR. Reads but does NOT re-run L0's `/review`; treats its artifact as evidence for axis 2. Reads L0's `/review` verdict from the posted `<!-- review:metadata -->` PR marker (not the gitignored local file) as axis-2 evidence. Writes a local verdict record at `.claude/reviews/l1-latest.md` (with YAML frontmatter) for the L1's own use, and posts the canonical cross-operator artifact as a PR comment carrying a `<!-- l1-review:metadata -->` marker that l2-review parses for axis-2 evidence. Invoked by the L1 role when its supervise tick reports `new-state: PR opened` on an L0 pane.
allowed-tools:
  - Bash
  - Read
  - Write
  - Grep
version: 1.2.1
---

# /l1-review — L1-over-L0 review executor

Applies the shared L{N}-review doctrine at N=1 to a single L0 PR.

## Surface

```
/l1-review <PR>
```
