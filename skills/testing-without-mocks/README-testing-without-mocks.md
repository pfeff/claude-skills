# Testing Without Mocks Skill

A comprehensive skill for Test-Driven Development using the Testing Without Mocks pattern language by James Shore.

## What You Get

This skill helps you write fast, maintainable, refactorable tests using **Nullables** instead of mocking frameworks. It supports Python, Go, and Elixir with idiomatic patterns for each language.

## Skill Contents

### Main File
- **SKILL.md** - TDD workflow, pattern selection guide, quick reference by language, and common scenarios

### Reference Documentation (7 files)

1. **foundational-patterns.md** - Core principles that everything builds on:
   - Narrow Tests
   - State-Based Tests
   - Overlapping Sociable Tests
   - Zero-Impact Instantiation
   - Parameterless Instantiation
   - Signature Shielding

2. **nullability-patterns.md** - The heart of the methodology:
   - Nullables (production code with "off" switches)
   - Embedded Stub
   - Thin Wrapper (for statically-typed languages)
   - Configurable Responses
   - Output Tracking
   - Behavior Simulation
   - Fake It Once You Make It

3. **infrastructure-patterns.md** - Testing external systems:
   - Infrastructure Wrappers
   - Narrow Integration Tests
   - Paranoic Telemetry

4. **logic-patterns.md** - Testing pure computation:
   - Easily-Visible Behavior
   - Testable Libraries
   - Collaborator-Based Isolation

5. **architectural-patterns.md** - Optional but helpful structures:
   - A-Frame Architecture
   - Logic Sandwich
   - Traffic Cop
   - Grow Evolutionary Seeds

6. **legacy-patterns.md** - Converting existing code:
   - Descend the Ladder (top-down conversion)
   - Climb the Ladder (bottom-up conversion)
   - Replace Mocks with Nullables
   - Throwaway Stub

7. **language-examples.md** - Complete working examples:
   - Python ROT13 encoder (with pytest)
   - Go ROT13 encoder (with testify)
   - Elixir ROT13 encoder (with ExUnit)

## How to Use This Skill

### For New Projects

1. Read the Foundational Patterns
2. Follow the TDD Workflow in SKILL.md
3. Reference Language Examples for your language
4. Use Pattern Selection Guide when stuck

### For Existing Code

1. Read Foundational Patterns
2. Read Legacy Patterns (Descend or Climb the Ladder)
3. Start with one module/class
4. Convert incrementally

### Typical TDD Session

```
User: "Help me test this login controller using TDD"
Claude: [Uses skill to guide through:]
1. Identify code type (Application with infrastructure)
2. Write narrow, state-based test
3. Create Nullables for dependencies
4. Implement with Logic Sandwich pattern
5. Refactor confidently
```

## Key Benefits

- **No broad tests required** - All narrow, focused tests
- **Easy refactoring** - Tests check behavior, not implementation
- **Fast & deterministic** - Infrastructure is "nulled" in tests
- **Readable tests** - Clear arrange-act-assert structure
- **Works with existing code** - Mix with mocks during conversion

## Pattern Quick Reference

| Pattern | Use When |
|---------|----------|
| Narrow Tests | Always - base pattern |
| State-Based Tests | Always - check results, not calls |
| Nullables | Testing code with infrastructure |
| Embedded Stub | Creating low-level infrastructure wrappers |
| Fake It Once You Make It | Creating high-level wrappers |
| Narrow Integration Tests | Testing actual infrastructure |
| A-Frame Architecture | Starting fresh with good separation |
| Descend/Climb the Ladder | Converting existing code |

## Credit

Based on "Testing Without Mocks: A Pattern Language" by James Shore
https://www.jamesshore.com/v2/projects/nullables/testing-without-mocks

Adapted for Claude skill format with multi-language support (Python, Go, Elixir).

## Installation

Upload the `testing-without-mocks.skill` file to Claude to install this skill.
