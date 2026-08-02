#!/usr/bin/env python3
"""Compliant-note primitives for writing to the Obsidian vault from a cloud session.

A cloud session has no macOS `obsidian` CLI — no Templater to resolve `<% tp.date.now() %>`,
no property registry to keep frontmatter well-formed. So a note written from the cloud must
emit **resolved** frontmatter directly and self-validate against the vault's own contract
(`_meta/vocabulary.md` + `_meta/agent-contract.md`). This module holds exactly those
deterministic, unit-testable primitives; it does no git or filesystem I/O of its own beyond
reading a vocabulary string a caller hands it.

Design notes:
- **The vault's files are the source of truth.** `parse_vocabulary` reads the *live*
  `_meta/vocabulary.md` from the clone rather than hardcoding field values here, because the
  vocabulary drifts (the live vault already carries `project: Job Search` where the doc lists
  `job-search`). Hardcoding would rot; parsing tracks the vault.
- **Quoting mirrors the local `fm-emit.py` discipline.** A bare `: `, `#`, `[`, or leading `@`
  in an unquoted scalar silently breaks the `---` block, and there is no CLI here to catch it.
- **Required vs optional** follows `_meta/vocabulary.md`: `type` is required single-value;
  `area`/`project`/`status` are optional single-value; `tags` is optional multi-value.
"""

import re


# --- Vocabulary parsing (reads the vault's own _meta/vocabulary.md) ----------

# The single-value constrained fields, in the order vocabulary.md documents them. `tags` is
# deliberately excluded — it is freeform/multi-value ("new topical tags are fine").
CONSTRAINED_FIELDS = ("type", "area", "project", "status")


def parse_vocabulary(md_text: str) -> dict:
    """Parse the vault's ``_meta/vocabulary.md`` into ``{field: set(values)}`` for the
    constrained single-value fields (``type``/``area``/``project``/``status``).

    The file documents each field as a markdown section (``## type``, ``## area (optional…)``,
    …) followed by a ``| Value | Description |`` table; the value is the first table column.
    Returns a dict mapping each field in ``CONSTRAINED_FIELDS`` to the set of allowed values
    (an empty set if that section or its table is absent, so a caller can tell "no constraint
    parsed" from "value not allowed"). Robust to the ``## field (optional, single-value)``
    heading suffixes the live file uses."""
    vocab = {field: set() for field in CONSTRAINED_FIELDS}
    current = None
    for line in md_text.splitlines():
        heading = re.match(r"^##\s+([a-zA-Z]+)\b", line)
        if heading:
            name = heading.group(1).lower()
            current = name if name in vocab else None
            continue
        if current is None:
            continue
        # A table data row: "| value | description |". Skip the header row and the
        # "|---|---|" separator.
        if line.lstrip().startswith("|"):
            cells = [c.strip() for c in line.strip().strip("|").split("|")]
            if not cells:
                continue
            value = cells[0]
            if not value or value.lower() == "value" or set(value) <= set("-: "):
                continue
            vocab[current].add(value)
    return vocab


# --- Slug + path (agent-contract.md path scheme) -----------------------------


def slugify(title: str) -> str:
    """Vault slug: lowercase, non-alphanumeric runs collapse to a single hyphen, ends trimmed
    (``_meta/agent-contract.md``: "lowercase, hyphenated, 2-5 words"). Word-count trimming is a
    caller concern; this owns only the normalization."""
    return re.sub(r"[^a-z0-9]+", "-", title.strip().lower()).strip("-")


def note_path(date_str: str, slug: str) -> str:
    """Vault-relative path for a new note: ``YYYY/MM/YYYY-MM-DD-<slug>.md`` (the only note
    location the agent-contract permits besides ``_attachments/``). ``date_str`` must be an
    ISO ``YYYY-MM-DD``; raises ``ValueError`` otherwise so a malformed date can't land a note
    in a bogus folder."""
    m = re.fullmatch(r"(\d{4})-(\d{2})-(\d{2})", date_str)
    if not m:
        raise ValueError(f"date must be YYYY-MM-DD, got {date_str!r}")
    if not slug:
        raise ValueError("slug must be non-empty (title slugified to nothing?)")
    year, month, _ = m.groups()
    return f"{year}/{month}/{date_str}-{slug}.md"


# --- YAML scalar quoting (fm-emit.py discipline) -----------------------------

# YAML plain (unquoted) scalars break, or change meaning, when they contain these. Kept
# deliberately conservative — quoting a safe string is harmless; failing to quote an unsafe
# one silently corrupts the frontmatter block.
_YAML_BOOL_NULL = {
    "true", "false", "yes", "no", "on", "off", "null", "none", "~", "",
}


def needs_quoting(value: str) -> bool:
    """True iff ``value`` must be double-quoted to survive as a YAML plain scalar. Covers the
    cases the local ``fm-emit.py`` guards: a bare ``: `` or trailing ``:``; a ``#`` comment
    introducer; leading indicator characters (``[ ] { } , & * ! | > @ \\` " ' % ? : -`` and
    leading/trailing whitespace); and bool/null/number lookalikes we want kept as strings."""
    if value == "" or value != value.strip():
        return True
    if value.lower() in _YAML_BOOL_NULL:
        return True
    # Number-lookalike (int/float) — quote so "123"/"1.5" stay strings.
    if re.fullmatch(r"[+-]?(\d+\.?\d*|\.\d+)", value):
        return True
    if value[0] in "[]{},&*!|>@`\"'%?:-#":
        return True
    if ": " in value or value.endswith(":") or " #" in value:
        return True
    return False


def yaml_scalar(value) -> str:
    """Render a single frontmatter value as a YAML scalar, quoting (and escaping ``\\`` and
    ``"``) only when ``needs_quoting`` says it's unsafe bare. Non-strings are stringified."""
    s = str(value)
    if needs_quoting(s):
        escaped = s.replace("\\", "\\\\").replace('"', '\\"')
        return f'"{escaped}"'
    return s


# --- Frontmatter emission ----------------------------------------------------

# Emission order matches the vault's Templater templates (Reference.md / Zettel.md): type,
# area, project, status, date, tags. Optional single-value fields are omitted when empty
# rather than emitted blank, so a cloud note carries only the keys it actually sets.
_FIELD_ORDER = ("type", "area", "project", "status", "date", "tags")


def emit_frontmatter(fields: dict) -> str:
    """Emit a resolved ``---``…``---`` YAML frontmatter block for a vault note.

    ``fields`` may carry any of ``type``/``area``/``project``/``status``/``date``/``tags`` plus
    arbitrary extra keys (emitted after the known ones, insertion order preserved — this is how
    KB provenance keys like ``source_key``/``sources`` ride along). Scalars are quoted per
    ``yaml_scalar``; ``tags`` (and any other list-valued key) render in block style to match the
    live vault. Empty/``None`` single-value fields are skipped; an empty ``tags`` renders as the
    flow list ``[]`` (the template default). ``type`` is always emitted first when present."""
    lines = ["---"]

    def emit_key(key, value):
        if isinstance(value, (list, tuple)):
            if len(value) == 0:
                lines.append(f"{key}: []")
            else:
                lines.append(f"{key}:")
                for item in value:
                    lines.append(f"  - {yaml_scalar(item)}")
        else:
            lines.append(f"{key}: {yaml_scalar(value)}")

    for key in _FIELD_ORDER:
        if key not in fields:
            continue
        value = fields[key]
        if value is None:
            continue
        if not isinstance(value, (list, tuple)) and str(value).strip() == "":
            continue
        emit_key(key, value)

    for key, value in fields.items():
        if key in _FIELD_ORDER or value is None:
            continue
        # Skip empty single-value extras, symmetric with the known-field loop above —
        # an empty scalar contributes no information and shouldn't emit a blank `key: ""`.
        if not isinstance(value, (list, tuple)) and str(value).strip() == "":
            continue
        emit_key(key, value)

    lines.append("---")
    return "\n".join(lines)


# --- Validation --------------------------------------------------------------


def validate_frontmatter(fields: dict, vocab: dict) -> list:
    """Return a list of human-readable compliance violations for ``fields`` against ``vocab``
    (the parsed ``_meta/vocabulary.md``). Empty list ⇒ compliant. Checks, per the vault
    contract:

    - ``type`` present and non-empty (required, single-value);
    - ``type``/``area``/``project``/``status`` values are in the vocabulary **when the
      vocabulary defines that field** — an unknown value is a violation the agent must resolve
      (the contract forbids inventing ``type``/``area``/``project`` values without CoS
      approval). A field whose vocab set is empty (unparsed) is skipped, not failed.

    ``tags`` is intentionally unchecked — freeform by contract. Path/location compliance is
    enforced by ``note_path``, not here."""
    violations = []
    note_type = str(fields.get("type", "")).strip()
    if not note_type:
        violations.append("missing required field: type")

    for field in CONSTRAINED_FIELDS:
        allowed = vocab.get(field) or set()
        if not allowed:
            continue
        raw = fields.get(field)
        if raw is None or str(raw).strip() == "":
            continue  # optional fields may be absent (type-absent already flagged above)
        value = str(raw).strip()
        if value not in allowed:
            violations.append(
                f"{field}: {value!r} not in vocabulary "
                f"({', '.join(sorted(allowed))}) — do not invent {field} values"
            )
    return violations
