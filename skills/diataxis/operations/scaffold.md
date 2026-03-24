# Scaffold Operation

**When**: User wants to create a Diataxis documentation structure for a project.

## Purpose

Creates the standard Diataxis directory structure with README templates that explain the purpose and guidelines for each documentation type.

## Execution

### Step 1: Determine Target Location

Check for existing docs structure:

```
Glob(pattern: "docs/**/*.md")
```

**If docs/ exists with content**:
- Ask if user wants to reorganize existing docs or add Diataxis structure alongside
- If reorganizing, load `operations/audit.md` first to categorize existing content

**If no docs/ exists**:
- Use current directory or ask user for target path

### Step 2: Create Directory Structure

Create directories:

```bash
mkdir -p docs/{tutorials,how-to,reference,explanation}
```

### Step 3: Create Main README

Write `docs/README.md`:

```markdown
# Documentation

This project uses the [Diataxis](https://diataxis.fr/) documentation framework.

## Quick Links

| Type | Purpose | Start Here |
|------|---------|------------|
| [Tutorials](tutorials/) | Learn by doing | For newcomers |
| [How-to Guides](how-to/) | Solve specific problems | For practitioners |
| [Reference](reference/) | Technical details | For lookup |
| [Explanation](explanation/) | Understand concepts | For deeper knowledge |

## Finding What You Need

- **New to this project?** Start with [tutorials](tutorials/)
- **Need to accomplish a task?** Check [how-to guides](how-to/)
- **Looking up an API/config?** See [reference](reference/)
- **Want to understand why?** Read [explanation](explanation/)

## Contributing

When adding documentation, choose the appropriate type:

1. **Tutorials**: Step-by-step lessons for beginners
2. **How-to guides**: Task-focused instructions
3. **Reference**: Factual, comprehensive descriptions
4. **Explanation**: Context and background
```

### Step 4: Create Section READMEs

**docs/tutorials/README.md**:

```markdown
# Tutorials

Tutorials are **learning-oriented** lessons that take a beginner through a series of steps to complete a project.

## Guidelines for Writing Tutorials

- Focus on **learning**, not on accomplishing a task
- Allow the user to learn by **doing**
- Get the user started immediately
- Make sure the tutorial **works** (test it!)
- Focus on **concrete steps**, not abstract concepts
- Provide the **minimum necessary explanation**
- Focus only on the steps the user needs to take

## Structure Template

1. Introduction (what will be built/learned)
2. Prerequisites
3. Step-by-step instructions
4. What you've learned
5. Next steps

## Anti-patterns to Avoid

- Teaching concepts instead of skills
- Offering choices or alternatives
- Including unnecessary explanations
- Assuming prior knowledge
```

**docs/how-to/README.md**:

```markdown
# How-to Guides

How-to guides are **task-oriented** directions that take the reader through the steps to solve a real-world problem.

## Guidelines for Writing How-to Guides

- Focus on a **specific task or problem**
- Provide a **series of steps** that lead to completion
- Assume the reader knows **what** they want to do, but not **how**
- Be flexible about naming (address real-world problems, not features)
- Don't explain concepts (link to Explanation docs)
- Be adaptable (show options where relevant)

## Structure Template

1. Title: "How to [accomplish X]"
2. Prerequisites (if any)
3. Steps with clear actions
4. Verification (how to confirm success)
5. Troubleshooting (common issues)

## Anti-patterns to Avoid

- Teaching instead of showing
- Including background explanation
- Addressing multiple problems in one guide
- Being too abstract
```

**docs/reference/README.md**:

```markdown
# Reference

Reference documentation is **information-oriented** technical descriptions of the machinery and how to operate it.

## Guidelines for Writing Reference Docs

- Structure around the **code/system structure**
- Be **consistent** in style and format
- Do nothing but **describe** (no instructions, explanations)
- Be **accurate** and up-to-date
- Include **examples** of usage
- Cross-reference related items

## Structure Suggestions

- API documentation (functions, parameters, return values)
- Configuration options (keys, types, defaults)
- CLI commands and flags
- Data structures and schemas
- Error codes and meanings

## Format Recommendations

| Element | Format |
|---------|--------|
| Function signature | Code block |
| Parameters | Table with name, type, description |
| Return values | Type and description |
| Examples | Annotated code blocks |

## Anti-patterns to Avoid

- Including how-to instructions
- Adding explanation or discussion
- Inconsistent formatting
- Outdated information
```

**docs/explanation/README.md**:

```markdown
# Explanation

Explanation documentation is **understanding-oriented** discussion that clarifies and illuminates a topic.

## Guidelines for Writing Explanations

- Focus on **why**, not what or how
- Provide **context** and background
- Discuss **alternatives and tradeoffs**
- Connect to the **bigger picture**
- Allow for **multiple perspectives**

## Topics Suited for Explanation

- Architecture decisions and rationale
- Design patterns used and why
- Historical context ("why it's this way")
- Comparisons with alternative approaches
- Conceptual overviews
- Philosophical considerations

## Structure Suggestions

- Start with the question being answered
- Provide background/context
- Explore the topic from multiple angles
- Conclude with implications or connections

## Anti-patterns to Avoid

- Including step-by-step instructions
- Pure technical description without context
- Being too abstract without grounding
- Avoiding a clear position
```

### Step 5: Report Results

Display:

```
Created Diataxis documentation structure:

docs/
├── README.md              (documentation index)
├── tutorials/README.md    (tutorial guidelines)
├── how-to/README.md       (how-to guidelines)
├── reference/README.md    (reference guidelines)
└── explanation/README.md  (explanation guidelines)

Next steps:
1. Review docs/README.md and customize for your project
2. Add your first tutorial in docs/tutorials/
3. Document common tasks in docs/how-to/
```

## Error Handling

| Error | Response |
|-------|----------|
| docs/ already exists with content | Offer to audit and reorganize |
| No write permission | Report and suggest sudo or different location |
| Not in a git repo | Warn but continue (docs can exist anywhere) |
