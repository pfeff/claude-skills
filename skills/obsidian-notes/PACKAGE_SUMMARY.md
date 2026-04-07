# Obsidian Notes Skill - Complete Package

## What You're Getting

A fully-functional Claude Code skill that teaches Claude to create and manage Obsidian notes using the **official Obsidian CLI (v1.12+)** and your specific conventions. The CLI provides link-safe operations, native property management, and integrated search.

### Files Included

1. **obsidian-notes.skill** (main deliverable)
   - Ready to import into Claude Code
   - Contains all instructions and resources

2. **USAGE_GUIDE.md** (documentation)
   - How to install and use the skill
   - Example scenarios
   - Tips and customization advice

## Skill Contents

### SKILL.md (Core Instructions)
- **Note Types**: Date-based work notes, machine-generated notes, permanent notes
- **File Naming**:
  - Date-based (Notes/): DDHHmm timestamp format
  - Generated/: YYYYMMDDHHmm timestamp format (full date in filename)
- **Organization**: Notes/YYYY/MM/, Generated/, and M99 Personal Notes/
- **Frontmatter**: YAML structure with tags and date links
- **Operations**: Creating, materializing, and migrating notes
- **Linking Strategy**: Liberal wikilinks to keywords

### references/templates.md
Complete examples including:
- Full note templates for both types
- Real-world examples matching your style
- Common tag vocabularies
- Filename patterns

### references/cli.md
Complete Obsidian CLI reference:
- All commands (files, search, properties, tags, tasks, plugins)
- Output formats (json, csv, md, yaml, tree)
- TUI mode documentation
- CLI vs direct file operation decision guide
- obsidian-headless for sync operations

### references/johnny_decimal.md
Detailed guidance on:
- Johnny Decimal system principles
- Index file structure and maintenance
- Integration workflow
- Migration strategies
- Best practices and naming conventions

### scripts/note_helper.py
Python utility that:
- Generates DDHHmm timestamps
- Creates proper filenames
- Builds correct directory paths
- Formats date links for frontmatter

## How It Works

When you use Claude Code and mention anything related to Obsidian notes, the skill automatically triggers. Claude Code will:

1. **Use Obsidian CLI** for link-safe operations (search, properties, tags, moves)
2. **Understand your conventions** from the skill instructions
3. **Generate proper timestamps** using the current date/time
4. **Create correct file structure** with appropriate paths
5. **Format frontmatter** with tags and date links
6. **Apply your linking strategy** with liberal wikilinks
7. **Follow Johnny Decimal** for permanent notes

## Key Features

### Date-Based Work Notes
```
Format: Notes/2025/11/060149-My-Note-Title.md
Purpose: Document technical work, decisions, implementations
Structure: Frontmatter + Overview + Details
Links: Liberal connections to keyword notes
```

### Permanent Notes
```
Format: M99 Personal Notes/32.05 Search Strategies.md
Purpose: Synthesized, evergreen knowledge
Organization: Johnny Decimal (XX.YY format)
Process: Materialize from multiple date-based notes
```

### Smart Behavior
- Checks current date/time automatically
- References your 00.00 Index for Johnny Decimal numbers
- Suggests appropriate tags based on content
- Maintains consistent formatting
- Preserves your established conventions

## Installation

1. Download `obsidian-notes.skill`
2. In Claude Code, import the skill
3. Start creating notes naturally!

## Example Interactions

**You:** "Create a note about implementing the Redis caching layer"

**Claude Code:**
- Generates timestamp (e.g., 060149)
- Creates: `Notes/2025/11/060149-Redis-Caching-Layer.md`
- Adds proper frontmatter with relevant tags
- Structures with Overview section
- Prompts for technical details

**You:** "Make this into a permanent note about caching strategies"

**Claude Code:**
- Reviews 00.00 Index for appropriate category
- Suggests Johnny Decimal number (e.g., 30.12)
- Creates: `M99 Personal Notes/30.12 Caching Strategies.md`
- Synthesizes content from date-based note
- Links back to original source note
- Uses permanent_note tag

## Customization

The skill is designed to be modified. If you need to adjust:

1. Extract the .skill file (it's a zip)
2. Edit SKILL.md or reference files
3. Repackage using the provided packaging script
4. Reimport into Claude Code

## Technical Details

**Skill Structure:**
```
obsidian-notes/
├── SKILL.md                          # Main instructions
├── references/
│   ├── cli.md                        # Obsidian CLI reference
│   ├── templates.md                  # Example templates
│   └── johnny_decimal.md             # JD system guide
└── scripts/
    └── note_helper.py                # Timestamp utility
```

**Progressive Disclosure:**
- Metadata always in context (~100 words)
- SKILL.md loaded when triggered (~2k words)
- Reference files loaded as needed
- Scripts executable without context loading

## Your Convention Summary

Based on your example, this skill enforces:

✅ **Timestamp Format**: DDHHmm (day + hour + minute)
✅ **Path Structure**: Notes/YYYY/MM/
✅ **Frontmatter**: YAML with tags array + date/month links
✅ **Linking**: Liberal wikilinks [[like this]]
✅ **Tag Format**: snake_case
✅ **Permanent Notes**: Johnny Decimal in M99 Personal Notes/
✅ **Index**: 00.00 Index.md for JD categories
✅ **Materialization**: Date-based → Permanent workflow

## Support

The skill includes:
- Detailed comments in SKILL.md
- Concrete examples in templates.md
- Comprehensive JD guide in johnny_decimal.md
- Tested utility script
- This usage guide

## Next Steps

1. Import obsidian-notes.skill into Claude Code
2. Try creating a date-based note
3. Practice materializing it to permanent
4. Adjust the skill if needed for your workflow

Enjoy your new Obsidian note-taking assistant! 🎉
