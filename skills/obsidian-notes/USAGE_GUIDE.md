# Obsidian Notes Skill - Usage Guide

This skill guides Claude Code in creating Obsidian notes according to your conventions.

## What This Skill Does

The skill teaches Claude Code to:
- Create date-based work notes with DDHHmm timestamp format
- Generate proper frontmatter with tags and date links
- Follow your Johnny Decimal system for permanent notes
- Use liberal wikilinks to connect concepts
- Materialize date-based notes into permanent notes
- Migrate legacy notes to your current system

## Installation

1. Download the `obsidian-notes.skill` file
2. In Claude Code, add the skill using your skill manager
3. The skill will automatically trigger when you work with Obsidian notes

## Example Usage Scenarios

### Creating a Date-Based Work Note
```
"Create an Obsidian note documenting my work on implementing the new caching layer"
```

Claude Code will:
- Generate the correct DDHHmm timestamp
- Create the file in `Notes/YYYY/MM/` with proper naming
- Add frontmatter with relevant tags
- Structure it with Overview section
- Prompt you for content details

### Creating a Permanent Note
```
"Create a permanent note about caching strategies, synthesizing the work from my recent implementation notes"
```

Claude Code will:
- Check your Johnny Decimal index
- Suggest an appropriate XX.YY number
- Create the note in `M99 Personal Notes/`
- Link back to source date-based notes
- Use the permanent_note tag

### Materializing Notes
```
"Materialize my notes about Redis implementation into a permanent note"
```

Claude Code will:
- Review your date-based notes on Redis
- Extract key insights and evergreen knowledge
- Create a synthesized permanent note
- Maintain proper links between notes

## Skill Components

### SKILL.md
Main instructions covering:
- Note types (date-based vs permanent)
- File naming conventions
- Frontmatter standards
- Linking strategies
- Common operations

### references/templates.md
Concrete examples:
- Full note templates
- Real-world examples
- Tag vocabularies
- Filename patterns

### scripts/note_helper.py
Utility for:
- Generating DDHHmm timestamps
- Creating proper filenames
- Building correct paths
- Formatting date links

## Customization

To modify the skill for your needs:
1. Extract the .skill file (it's a zip)
2. Edit SKILL.md or references/templates.md
3. Repackage using the package_skill.py script

## Tips

- The skill automatically triggers when you mention "Obsidian", "note", or similar keywords
- You can be conversational: "Document today's work on the API"
- Claude Code will ask for clarification on tags, Johnny Decimal numbers, etc.
- The note_helper.py script can be used independently in your own workflows

## Your Convention Summary

- **Date-based notes**: `Notes/YYYY/MM/DDHHmm-Title.md`
- **Machine-generated notes**: `Generated/YYYYMMDDHHmm-Title.md`
- **Permanent notes**: `M99 Personal Notes/XX.YY Title.md`
- **Index**: `M99 Personal Notes/00.00 Index.md`
- **Tags**: snake_case format
- **Links**: Liberal wikilinks to keywords
- **Purpose**: Date-based → source material → Permanent notes
