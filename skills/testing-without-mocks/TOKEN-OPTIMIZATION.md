# Token Optimization - Testing Without Mocks Skill

## What Changed

The skill has been **optimized for token efficiency** by splitting language-specific examples into separate reference files.

## Token Savings

### Before Optimization
- **Single file**: `language-examples.md` (~8,000 tokens)
- All three language examples loaded together
- Always consumed ~8,000 tokens when any example was needed

### After Optimization
- **Three separate files**: 
  - `python-example.md` (~2,700 tokens)
  - `go-example.md` (~2,500 tokens)
  - `elixir-example.md` (~2,400 tokens)
- Claude only loads the specific language example needed
- **Saves ~5,500 tokens** when working in a single language

## How Progressive Disclosure Works

Skills use a three-level loading system:

1. **Metadata (Always loaded)** - ~100 words
   - Skill name and description
   - Used for skill discovery

2. **SKILL.md body (Loaded when triggered)** - ~3,000 tokens
   - Core workflow and patterns
   - Quick reference guides
   - Pattern selection logic

3. **Reference files (Lazy loaded)** - Variable size
   - `foundational-patterns.md` - Loaded for core concepts
   - `nullability-patterns.md` - Loaded for Nullables techniques
   - `python-example.md` - **Only** loaded when Python is detected
   - `go-example.md` - **Only** loaded when Go is detected
   - `elixir-example.md` - **Only** loaded when Elixir is detected

## Real-World Impact

**Example Session: Python TDD**
```
User: "Help me test this Python code with TDD"

Tokens loaded:
✓ Skill metadata: ~100 tokens
✓ SKILL.md: ~3,000 tokens
✓ foundational-patterns.md: ~4,000 tokens (if needed)
✓ python-example.md: ~2,700 tokens (only when Python detected)
✗ go-example.md: NOT LOADED (saves 2,500 tokens)
✗ elixir-example.md: NOT LOADED (saves 2,400 tokens)

Total savings: ~4,900 tokens per session
```

**Example Session: Go TDD**
```
User: "Help me test this Go service"

Tokens loaded:
✓ Skill metadata: ~100 tokens
✓ SKILL.md: ~3,000 tokens
✓ go-example.md: ~2,500 tokens (only when Go detected)
✗ python-example.md: NOT LOADED (saves 2,700 tokens)
✗ elixir-example.md: NOT LOADED (saves 2,400 tokens)

Total savings: ~5,100 tokens per session
```

## Benefits

1. **Faster initial load** - Less content to parse
2. **More context available** - Saved tokens can be used for conversation history
3. **Language-specific focus** - No irrelevant examples cluttering context
4. **Scalable pattern** - Easy to add more languages without bloating core skill

## File Structure

```
testing-without-mocks/
├── SKILL.md                              # Core workflow (always loaded)
└── references/
    ├── foundational-patterns.md          # Lazy loaded
    ├── nullability-patterns.md           # Lazy loaded
    ├── infrastructure-patterns.md        # Lazy loaded
    ├── logic-patterns.md                 # Lazy loaded
    ├── architectural-patterns.md         # Lazy loaded
    ├── legacy-patterns.md                # Lazy loaded
    ├── python-example.md                 # Lazy loaded (Python only)
    ├── go-example.md                     # Lazy loaded (Go only)
    └── elixir-example.md                 # Lazy loaded (Elixir only)
```

## How Claude Decides What to Load

Claude autonomously decides which reference files to load based on:
- User's request content
- Programming language mentioned or detected
- Patterns being discussed
- Complexity of the task

For example:
- "Test this Python code" → Loads `python-example.md`
- "Explain Nullables" → Loads `nullability-patterns.md`
- "Convert my Go tests" → Loads `go-example.md` + `legacy-patterns.md`

## Best Practices Applied

✅ **Split by usage pattern** - Language examples are natural boundaries
✅ **Keep core small** - SKILL.md stays under 500 lines
✅ **Reference from main** - Clear links show what's available
✅ **Semantic organization** - Related content stays together

## Installation

The optimized skill installs exactly the same way:

```bash
# Extract
unzip testing-without-mocks.skill -d testing-without-mocks

# Install
cp -r testing-without-mocks /path/to/plugin/skills/
```

The progressive loading is completely automatic - no configuration needed!

## Token Budget Context

For reference, Claude's context window can hold ~200,000 tokens. This optimization means:
- Skill uses **~2-3%** of context in typical sessions (before: ~4-5%)
- More room for code being tested
- More room for conversation history
- Better performance overall

## Future Optimizations

If the skill grows larger, we could further split:
- Pattern categories by complexity (beginner vs advanced)
- Testing scenarios (web apps, CLI tools, microservices)
- Framework-specific guides (Django, Rails, Phoenix)

The progressive disclosure pattern scales indefinitely!
