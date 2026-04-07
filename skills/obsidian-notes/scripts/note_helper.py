#!/usr/bin/env python3
"""
Utility script for generating Obsidian note filenames and paths.
Handles DDHHmm timestamp format and directory structure.
"""

from datetime import datetime
import argparse
import sys


def generate_timestamp(dt=None):
    """
    Generate DDHHmm timestamp format.
    
    Args:
        dt: datetime object (uses current time if None)
    
    Returns:
        String in DDHHmm format (e.g., "161948")
    """
    if dt is None:
        dt = datetime.now()
    
    return dt.strftime("%d%H%M")


def generate_date_note_filename(title, dt=None):
    """
    Generate full filename for date-based work note.
    
    Args:
        title: Note title (will be converted to kebab-case)
        dt: datetime object (uses current time if None)
    
    Returns:
        Filename string (e.g., "161948-My-Note-Title.md")
    """
    timestamp = generate_timestamp(dt)
    
    # Convert title to kebab-case
    title_clean = title.replace(" ", "-").replace("_", "-")
    # Remove any characters that aren't alphanumeric or hyphens
    title_clean = "".join(c for c in title_clean if c.isalnum() or c == "-")
    
    return f"{timestamp}-{title_clean}.md"


def generate_date_note_path(title, vault_path=".", dt=None):
    """
    Generate full path for date-based work note.
    
    Args:
        title: Note title
        vault_path: Base path to Obsidian vault
        dt: datetime object (uses current time if None)
    
    Returns:
        Full path string (e.g., "./Notes/2025/09/161948-My-Note-Title.md")
    """
    if dt is None:
        dt = datetime.now()
    
    year = dt.strftime("%Y")
    month = dt.strftime("%m")
    filename = generate_date_note_filename(title, dt)
    
    return f"{vault_path}/Notes/{year}/{month}/{filename}"


def generate_date_links(dt=None):
    """
    Generate date and month wikilinks for frontmatter.
    
    Args:
        dt: datetime object (uses current time if None)
    
    Returns:
        Tuple of (date_link, month_link)
    """
    if dt is None:
        dt = datetime.now()
    
    date_link = dt.strftime('"%Y-%m-%d"')
    month_link = dt.strftime('"%Y-%m"')
    
    return date_link, month_link


def main():
    parser = argparse.ArgumentParser(
        description="Generate Obsidian note filenames and paths"
    )
    parser.add_argument(
        "title",
        help="Note title"
    )
    parser.add_argument(
        "--vault",
        default=".",
        help="Base path to Obsidian vault (default: current directory)"
    )
    parser.add_argument(
        "--filename-only",
        action="store_true",
        help="Output only the filename, not the full path"
    )
    parser.add_argument(
        "--timestamp-only",
        action="store_true",
        help="Output only the DDHHmm timestamp"
    )
    
    args = parser.parse_args()
    
    if args.timestamp_only:
        print(generate_timestamp())
    elif args.filename_only:
        print(generate_date_note_filename(args.title))
    else:
        print(generate_date_note_path(args.title, args.vault))


if __name__ == "__main__":
    main()
