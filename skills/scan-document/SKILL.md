---
name: scan-document
description: "Capture a scanned document (PDF or image) into text, classify what it is, and route it to the right follow-up workflow. This is the front door for any scan the user drops in — after-visit summaries, lab results, receipts, letters, contracts, statements. OCRs natively on macOS (Vision framework, no tesseract/poppler), classifies the document from the recognized text, and either hands off to a specialized handler skill (e.g. medical-records for an after-visit summary) or does a generic vault capture when no handler matches. Use when the user says 'scan this', 'OCR this', 'capture/archive this document', 'what is this scan', or points at a PDF/image and wants it read and filed."
argument-hint: "<path to a PDF or image file>"
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - Skill
  - AskUserQuestion
version: 1.0.0
---

# scan-document — OCR, classify, route

The user-facing front door for scanned documents. Three phases: **OCR → classify → route**. Owns the native OCR primitive; delegates domain-specific filing to handler skills.

## When this fires

- "scan this", "OCR this", "read this scan"
- "capture / archive this document", "file this into my vault"
- "what is this?" pointing at a scanned PDF or image
- Any PDF/image the user wants turned into text and put somewhere sensible

## Inputs

A path to a `.pdf`, `.png`, `.jpg`/`.jpeg`, or `.heic`. If no path is given, ask for one (or the most recent file in `~/Downloads` if the user says "the scan I just downloaded").

## Phase 1 — OCR (extract text)

1. **Text-layer fast path (PDF only):** `pdftotext -layout <file> -` . If it returns non-trivial text, use it — the PDF already has a text layer; skip OCR.
2. **Native OCR fallback:** if the fast path is empty (a true scan) or the input is an image, run the bundled Swift script:
   ```
   swift <skill-dir>/scripts/ocr.swift <file>
   ```
   It rasterizes PDF pages via PDFKit and recognizes text with Vision (`VNRecognizeTextRequest`, accurate + language correction). Output is page-delimited (`===== PAGE n =====`). Fully native — no tesseract or poppler. First run may take a few seconds per page.

Keep the recognized text; it feeds both classification and any handler.

## Phase 2 — Classify

Read the recognized text and decide the document type. Judgment call, not a model — look at headers, issuer, and structure. Known classes today:

| Class | Signals | Route to |
|---|---|---|
| `medical.after-visit-summary` | "After Visit Summary", MRN, vitals, provider/clinic, follow-up | **`medical-records`** handler |
| _(unknown / everything else)_ | no known handler matches | **generic capture** (below) |

This table is the extension point: as new handler skills are added, add a row. Only `medical.after-visit-summary` has a handler in v1.

## Phase 3 — Route

**If a handler exists for the class:** invoke it via the Skill tool, passing the original file path and the recognized text. Example: for `medical.after-visit-summary`, invoke `medical-records`. The handler owns filing, schema, and archival — do not duplicate its work here.

**If no handler matches (generic capture):**
1. Resolve the host vault via the `obsidian-notes` skill's host-config (or `~/.claude/hosts/<hostname>.md`). Bail with a clear message if no vault is configured.
2. Copy the source file into `<vault>/Attachments/` with a slugged, content-descriptive name.
3. Create a dated note in `<vault>/Notes/YYYY/MM/`:
   - Filename prefix = **today's date** (the write date — the prefix is a de-dupe / partition key, not the document's own date). Slug from a short description of the document.
   - Frontmatter: `type` (best guess, e.g. `receipt`, `letter`, `statement`), `tags: [scan]` plus a type tag, `captured: <today>`, `source: "[[<attachment filename>]]"`, and any obvious dated field as its own property (e.g. `doc_date`).
   - Body: a one-line summary, the recognized text under a `## Text` heading, and the embedded source (`![[<attachment filename>]]`).
4. Report where it landed.

## Edge cases

- **Ambiguous class:** if the text plausibly fits a handler but you're not sure, ask the user (AskUserQuestion) before routing rather than guessing into the wrong handler.
- **Multi-document scan:** if one file clearly contains several distinct documents, say so and ask whether to split or treat as one.
- **Empty OCR:** if both the fast path and Vision return nothing (blank/failed scan), report it — don't create an empty note.
- **Sensitive content:** medical, financial, and legal scans are private by nature. Capture into the local vault only; never send content to an external service without explicit operator say-so.

## Composition

- Owns `scripts/ocr.swift` (the reusable native OCR primitive).
- Delegates domain filing to handler skills. v1 handler: **`medical-records`**.
- Handlers may also be invoked directly by the user; this router is just the classify-and-dispatch entry point.
