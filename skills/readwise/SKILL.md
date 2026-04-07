---
description: >
  Access Readwise highlights and Reader documents via the CLI.
  Use when the user asks to search highlights, browse saved articles,
  triage their Reader inbox, review reading history, or interact with
  Readwise/Reader data. Also use when invoking `readwise` commands.
---

# Readwise CLI

Use the `readwise` command to access the user's Readwise highlights and Reader documents. Readwise has two products:

- **Readwise** — highlights from books, articles, podcasts, and more. Includes daily review and spaced repetition.
- **Reader** — a read-later app for saving and reading articles, PDFs, EPUBs, RSS feeds, emails, tweets, and videos.

## Setup

CLI is installed via dotfiles (`install.conf.yaml`). If not authenticated:

```bash
readwise login-with-token <token>
# Token from: https://readwise.io/access_token
```

## Global Options

| Flag | Effect |
|------|--------|
| `--json` | Machine-readable JSON output |
| `--refresh` | Force-refresh cached data |
| `--help` | Help for any command |

## Reader Commands

### Searching documents

```bash
readwise reader-search-documents --query "spaced repetition"
readwise reader-search-documents --query "AI" --category-in article --location-in later,shortlist
readwise reader-search-documents --query "AI" --author-search "Simon Willison" --location-in new
readwise reader-search-documents --query "transformers" --published-date-gt 2024-01-01
```

### Browsing documents

```bash
# Inbox (minimal fields to save tokens)
readwise reader-list-documents --location new --limit 10 --response-fields title,author,summary,word_count,category,saved_at

# Archived articles by tag
readwise reader-list-documents --location archive --tag research --category article

# Unseen inbox items
readwise reader-list-documents --location new --seen false

# RSS feed items
readwise reader-list-documents --location feed --limit 20 --response-fields title,author,summary,site_name

# Specific document by ID
readwise reader-list-documents --id <document_id>
```

Locations: `new` (inbox), `later`, `shortlist`, `archive`, `feed`. When the user says "inbox", use `new`.

### Reading and highlighting

```bash
# Full document content as Markdown
readwise reader-get-document-details --document-id <id>

# Get highlights on a document
readwise reader-get-document-highlights --document-id <id>

# Create a highlight (html_content must match document HTML)
readwise reader-create-highlight --document-id <id> --html-content "<p>passage</p>"
```

### Saving documents

```bash
readwise reader-create-document --url "https://example.com/article"
readwise reader-create-document --url "https://example.com" --title "Great Article" --tags research,ai
```

### Organizing

```bash
# Move documents between locations (max 50 per call)
readwise reader-move-documents --document-ids <id> --location archive

# Bulk mark as seen
readwise reader-bulk-edit-document-metadata --documents '[{"document_id": "<id>", "seen": true}]'

# Tags
readwise reader-list-tags
readwise reader-add-tags-to-document --document-id <id> --tag-names important,research
readwise reader-remove-tags-from-document --document-id <id> --tag-names old-tag
```

### Exporting

```bash
readwise reader-export-documents
readwise reader-get-export-documents-status --export-id <id>
readwise reader-export-documents --since-updated "2024-01-01T00:00:00Z"
```

## Readwise Commands

### Searching highlights

```bash
readwise readwise-search-highlights --vector-search-term "learning techniques"
readwise readwise-search-highlights --vector-search-term "memory" --full-text-queries '[{"field_name": "document_title", "search_term": "psychology"}]'
```

Full-text fields: `document_author`, `document_title`, `highlight_note`, `highlight_plaintext`, `highlight_tags`.

### Browsing highlights

```bash
readwise readwise-list-highlights --page-size 20
readwise readwise-list-highlights --book-id <id>
readwise readwise-list-highlights --highlighted-at-gt "2025-02-01T00:00:00Z"
```

### Creating and editing highlights

```bash
readwise readwise-create-highlights --highlights '[{"text": "Key insight", "title": "Book Title", "author": "Author Name"}]'
readwise readwise-update-highlight --highlight-id <id> --note "New note" --add-tags concept,review --color blue
readwise readwise-delete-highlight --highlight-id <id>
```

Colors: `yellow`, `blue`, `pink`, `orange`, `green`, `purple`.

### Daily review

```bash
readwise readwise-get-daily-review
```

## Example Workflows

**Triage the inbox:**
```bash
readwise reader-list-documents --location new --limit 10 --response-fields title,author,summary,word_count,category,saved_at
readwise reader-get-document-details --document-id <id>
readwise reader-move-documents --document-ids <id> --location later    # worth reading
readwise reader-move-documents --document-ids <id> --location archive  # skip
```

**Search across everything:**
```bash
readwise reader-search-documents --query "spaced repetition"
readwise readwise-search-highlights --vector-search-term "spaced repetition"
```

**Catch up on RSS:**
```bash
readwise reader-list-documents --location feed --limit 20 --response-fields title,author,summary,word_count,site_name
readwise reader-bulk-edit-document-metadata --documents '[{"document_id": "<id>", "seen": true}]'
readwise reader-move-documents --document-ids <id> --location later
```

**Save and annotate:**
```bash
readwise reader-create-document --url "https://example.com/article" --tags research
readwise reader-create-highlight --document-id <id> --html-content "<p>Key passage</p>" --note "Connects to..."
readwise reader-add-tags-to-document --document-id <id> --tag-names important
```

## Pre-built Skills

The CLI ships with AI agent skills. List them: `readwise skills list`

Install for Claude Code: `readwise skills install claude`

| Skill | Purpose |
|-------|---------|
| triage | AI-assisted inbox triage with relevance pitches |
| feed-catchup | Batch-process RSS, newsletters, social feeds |
| quiz | Self-assessment on recently read material |
| book-review | Long-form book review from highlights |
| reader-recap | Briefing on recent reading activity |
| build-persona | Personalized reading profile |
| highlight-graph | Visualize highlight connections |
| now-reading-page | Generate "Now Reading" webpage |
| surprise-me | Discover patterns in reading history |
