---
name: wildcard-star-entry-fixture
description: "Fixture (d): a bare * entry in allowed-tools means unrestricted; never flag."
allowed-tools:
  - Bash
  - "*"
version: 1.0.0
---

# wildcard-star-entry-fixture

## Steps

### 1. Dispatch a reviewer

This step MUST invoke the Agent tool. It also SHALL use the NotebookEdit
tool and the mcp__agent-coordinator__ac_report tool.
