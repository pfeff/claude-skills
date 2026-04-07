# Obsidian CLI Reference

Official command-line interface for Obsidian (v1.12+). The CLI operates through Obsidian's runtime, ensuring link integrity and template support.

## Prerequisites

- Obsidian 1.12 or later
- CLI registered: Settings > General > Command line interface > Register CLI
- Obsidian must be running for commands to work

## Command Syntax

```
obsidian <command> [vault="Name"] [param=value] [--flags]
```

- Parameters use `key=value` pairs (no leading dashes)
- Boolean flags use `--prefix`
- Values with spaces require quotes
- `vault="Name"` must be first parameter if specified

## Files & Folders

| Command | Description |
|---------|-------------|
| `obsidian files` | List all notes in vault |
| `obsidian files folder=Projects/` | List notes in specific folder |
| `obsidian files total` | Count total notes |
| `obsidian folders` | List all directories |
| `obsidian read file="Note Name"` | Retrieve note content |
| `obsidian create name="Title"` | Create new note |
| `obsidian create name="Title" template="Template"` | Create note from template |
| `obsidian append file="Note" content="Text"` | Append to note end |
| `obsidian prepend file="Note" content="Text"` | Prepend to note start |
| `obsidian move file="Note" to=Archive/` | Move note (preserves links) |
| `obsidian delete file="Note"` | Move to trash |
| `obsidian delete file="Note" --permanent` | Permanent deletion |

## Search & Query

| Command | Description |
|---------|-------------|
| `obsidian search query="term"` | Full-text search |
| `obsidian search query="[tag:tagname]"` | Search by tag |
| `obsidian search query="[status:active]"` | Search by property |
| `obsidian search query="term" format=json` | Structured output |
| `obsidian search:open query="term"` | Search and open results in Obsidian |

## Daily Notes

| Command | Description |
|---------|-------------|
| `obsidian daily` | Open today's daily note |
| `obsidian daily:read` | Retrieve daily note content |
| `obsidian daily:append content="Text"` | Append to daily note |
| `obsidian daily:prepend content="Text"` | Prepend to daily note |
| `obsidian daily:open date=2026-03-05` | Open specific date's note |

## Properties (YAML Frontmatter)

| Command | Description |
|---------|-------------|
| `obsidian properties file="Note"` | List all properties in file |
| `obsidian properties` | List all properties in vault |
| `obsidian property:read name=status file="Note"` | Read specific property |
| `obsidian property:set name=status value=active file="Note"` | Set property |
| `obsidian property:set name=date value=2026-03-05 type=date file="Note"` | Set typed property |
| `obsidian property:remove name=fieldname file="Note"` | Remove property |

### Property Types

- `text` (default)
- `list`
- `number`
- `checkbox`
- `date`
- `datetime`

## Tags & Links

| Command | Description |
|---------|-------------|
| `obsidian tags` | List all tags in vault |
| `obsidian tags counts sort=count` | Tags with counts, sorted by frequency |
| `obsidian tags file="Note"` | Tags in specific file |
| `obsidian tag name=pkm` | Get tag info (count, files) |
| `obsidian tag name=pkm verbose` | Tag info with file list |
| `obsidian links file="Note"` | Outgoing links from note |
| `obsidian backlinks file="Note"` | Incoming links to note |
| `obsidian unresolved` | List broken wikilinks |
| `obsidian orphans` | List disconnected notes |
| `obsidian deadends` | List files with no outgoing links |

## Tasks

| Command | Description |
|---------|-------------|
| `obsidian tasks` | List all tasks |
| `obsidian task:create content="Task text"` | Create new task |
| `obsidian task:complete task=id` | Mark task complete |

## Plugins & Themes

| Command | Description |
|---------|-------------|
| `obsidian plugins` | List installed plugins |
| `obsidian plugin:enable id=dataview` | Enable plugin |
| `obsidian plugin:disable id=calendar` | Disable plugin |
| `obsidian plugin:reload id=plugin-name` | Reload plugin |
| `obsidian themes` | List available themes |
| `obsidian theme:set name="Minimal"` | Switch theme |

## Publishing & Sync

| Command | Description |
|---------|-------------|
| `obsidian publish:add file="Note"` | Publish note |
| `obsidian publish:remove file="Note"` | Unpublish note |
| `obsidian sync:status` | Check sync status |
| `obsidian history file="Note"` | View version history |

## Developer Tools

| Command | Description |
|---------|-------------|
| `obsidian version` | Display CLI version |
| `obsidian help` | Show help documentation |
| `obsidian dev:screenshot path="file.png"` | Capture screenshot |
| `obsidian eval code="JavaScript"` | Execute JS in Obsidian runtime |

## Output Formats

Use `format=` parameter with supported commands:

| Format | Description |
|--------|-------------|
| `json` | Structured JSON for scripting |
| `csv` | Spreadsheet-compatible |
| `md` | Markdown list |
| `yaml` | YAML output |
| `tree` | Hierarchical display |

Example: `obsidian search query="term" format=json`

## TUI Mode (Terminal User Interface)

Run `obsidian` without arguments to launch interactive mode:

| Key | Action |
|-----|--------|
| `↑/↓` | Navigate files |
| `/` | Search by filename |
| `Enter` | Open in Obsidian |
| `n` | Create note |
| `d` | Delete note |
| `r` | Rename note |
| `q` | Quit |

## CLI vs Direct File Operations

### When to Use CLI

- **Properties management**: `properties:set` handles YAML correctly
- **Tag operations**: `tags:rename` updates all occurrences
- **File moves**: `move` preserves internal links
- **Search**: Uses Obsidian's search engine
- **Template-based creation**: Applies templates through runtime

### When to Use Direct File Operations

- **Full note content**: `create` command has limited content support
- **Complex frontmatter**: Multi-line YAML with keywords array
- **Bulk operations**: Direct file ops may be faster for batch processing
- **Offline operation**: CLI requires Obsidian to be running

## Obsidian Headless (Sync Only)

Separate npm package for syncing vaults without the desktop app.

```bash
npm install -g obsidian-headless
```

| Command | Description |
|---------|-------------|
| `ob login` | Authenticate with Obsidian account |
| `ob sync-list-remote` | List remote vaults |
| `ob sync-list-local` | List local vaults |
| `ob sync-setup` | Configure local-to-remote sync |
| `ob sync` | Execute synchronization |
| `ob sync --continuous` | Watch and sync continuously |
| `ob sync-status` | View sync state |

Requires Node.js 22+. See [obsidian-headless](https://github.com/obsidianmd/obsidian-headless).

## Resources

- [Official CLI Documentation](https://help.obsidian.md/cli)
- [Obsidian Headless](https://help.obsidian.md/headless)
- [Obsidian GitHub](https://github.com/obsidianmd)
