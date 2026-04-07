# Johnny Decimal System Integration

This reference provides guidance on integrating permanent notes with the Johnny Decimal system.

## Understanding Johnny Decimal

Johnny Decimal is a system for organizing information using a two-level numbering scheme:
- **Areas**: 10-90 (first two digits, groups of 10)
- **Categories**: .01-.99 (last two digits within each area)

Example: `32.05 Hybrid Search Strategies`
- Area 32: Information Retrieval Systems
- Category .05: Specific search implementation

## Index File (`00.00 Index.md`)

The index file is the master reference for all Johnny Decimal categories. It should be structured like:

```markdown
# Johnny Decimal Index

## 10-19 Personal Knowledge Management
- 10.01 Note-taking methods
- 10.02 Zettelkasten principles
- 10.05 Knowledge synthesis

## 20-29 Software Development
- 20.01 Programming languages
- 20.05 Design patterns
- 20.12 Testing strategies

## 30-39 Systems and Architecture
- 30.01 Distributed systems
- 30.05 Database design
- 30.12 API design

## 40-49 [Your Area]
...
```

## Best Practices

### Before Creating a Permanent Note

1. **Read the index**: Always check `00.00 Index.md` first
2. **Find the area**: Identify which 10-range fits the topic
3. **Check existing categories**: See what .XX numbers are already used
4. **Choose or create**: Use existing category or add new one
5. **Update index**: If creating new category, update the index

### Choosing Numbers

**Use existing category when**:
- Topic clearly fits an existing .XX category
- The category scope is broad enough
- You want to keep related notes together

**Create new category when**:
- Topic doesn't fit existing categories
- You anticipate multiple notes in this sub-area
- Distinction is meaningful for future retrieval

**Avoid**:
- Too many narrow categories (use tags instead)
- Overlapping category definitions
- Numbers without clear meaning

### Area Allocation Strategy

Allocate areas thoughtfully:
- **10-19**: Meta/systems (how you organize)
- **20-39**: Core domains (your main work areas)
- **40-69**: Supporting domains
- **70-89**: Reference/resources
- **90-99**: Personal/miscellaneous

Leave gaps for future expansion:
- Don't use 10, 11, 12... sequentially
- Use 10, 15, 20, 25 to allow insertions
- Reserve flexibility for subcategory growth

## Integration Workflow

### From Date-Based to Permanent

```
1. Review date-based notes on a topic
2. Identify the core insight/pattern
3. Check index for appropriate area
4. Determine if existing category fits
5. If yes: Use that number
6. If no: Select next available .XX in that area
7. Create permanent note
8. Link back to source date-based notes
9. Update index if new category
```

### Naming Conventions

**File naming**: `XX.YY Title.md`
- Space after the number
- Title case for readability
- Descriptive but concise

**Good examples**:
- `32.05 Hybrid Search Strategies.md`
- `20.08 React Component Patterns.md`
- `45.12 Database Indexing Methods.md`

**Avoid**:
- `32.05-Hybrid-Search.md` (use space, not dash)
- `32.05.md` (needs descriptive title)
- `Hybrid Search Strategies.md` (needs number prefix)

## Migration Considerations

When migrating from legacy systems:

### From Folder-Based Organization
- Map folders to areas (e.g., "Backend Dev" → 30-39)
- Merge similar notes into single permanent notes
- Preserve important distinctions as separate categories

### From Tag-Only Systems
- Major tags become areas
- Sub-tags help define categories
- Keep tags for cross-cutting concerns

### From Chronological Only
- Extract evergreen insights
- Group by topic, not time
- Reference original date-based notes

## Maintenance

### Regular Reviews
- Quarterly: Review index structure
- Monthly: Check for orphaned notes
- Weekly: Ensure new notes are properly numbered

### Index Updates
- Add new categories as created
- Document category scope if ambiguous
- Remove categories only if truly obsolete

### Refactoring
- Merge overlapping categories carefully
- Renumber only when absolutely necessary
- Maintain redirects/links during refactoring

## Example Index Structure

```markdown
# 00.00 Index

## 10-19 Knowledge Systems
- 10.01 Zettelkasten Method
- 10.05 Note-taking Strategies
- 10.08 Knowledge Synthesis

## 20-29 Software Engineering
- 20.01 Programming Paradigms
- 20.05 Design Patterns
- 20.08 Code Architecture
- 20.12 Testing Approaches

## 30-39 Data and Search
- 30.01 Database Design
- 30.05 Search Systems
- 30.08 Data Structures
- 30.12 Query Optimization

## 32 Information Retrieval (Sub-area)
- 32.01 Vector Embeddings
- 32.03 BM25 Algorithm  
- 32.05 Hybrid Search Strategies
- 32.08 Rank Fusion Methods

## 40-49 Web Development
- 40.01 Frontend Frameworks
- 40.05 State Management
- 40.08 API Integration

## 90-99 Personal
- 90.01 Career Development
- 90.05 Learning Resources
- 90.08 Project Ideas
```

## Quick Reference

**Creating permanent note checklist**:
- [ ] Read `00.00 Index.md`
- [ ] Identify appropriate area (10-90)
- [ ] Find or create category (.01-.99)
- [ ] Use format: `XX.YY Title.md`
- [ ] Add to `M99 Personal Notes/`
- [ ] Include `permanent_note` tag
- [ ] Link to source notes
- [ ] Update index if needed
