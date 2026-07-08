---
name: mcp-hyphen-declared-fixture
description: "Regression fixture: a hyphenated mcp__ tool that IS declared and IS mandated must not be flagged (no truncation false positive)."
allowed-tools: [Bash, Read, mcp__agent-coordinator__ac_report]
version: 1.0.0
---

# mcp-hyphen-declared-fixture

## Steps

### 1. Report status

This step MUST invoke the mcp__agent-coordinator__ac_report tool to
emit the run outcome before returning.
