---
name: medical-records
description: "File a medical After Visit Summary into the Obsidian vault as a structured, queryable record. Extracts vitals and visit metadata from the document text, writes a dated note with flat Number frontmatter properties (so Obsidian Bases and Dataview can trend vitals across visits), archives and embeds the source scan, and slots the note into the Medical Vitals base. Usually invoked by the scan-document router when it classifies a scan as an after-visit summary, but can be run directly when the user says 'file this doctor visit', 'capture this after-visit summary', or 'log my visit vitals'. v1 handles after-visit summaries only."
argument-hint: "<path to the source PDF/image> (optionally with pre-extracted OCR text)"
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - AskUserQuestion
version: 1.0.0
---

# medical-records — file an After Visit Summary

A handler skill: turns the text of a medical After Visit Summary into a structured vault record. Consumes OCR'd text (from `scan-document`, or produced here if invoked directly) and the source file; produces a dated note + archived scan.

## When this fires

- Invoked by `scan-document` for class `medical.after-visit-summary`.
- Direct: "file this doctor visit", "capture this after-visit summary", "log my visit vitals".

## Inputs

- Path to the source scan (PDF/image).
- The recognized text. If not supplied (direct invocation), OCR it first: `pdftotext -layout` fast path, else `swift <scan-document-dir>/scripts/ocr.swift <file>`.

## Steps

1. **Extract** these fields from the text (leave a field out if genuinely absent — do not invent):
   - Visit metadata: `visit_date` (the appointment date), provider/institution, department, department phone, MRN, reason(s) for visit, referral(s) + expiry, follow-up date, medications.
   - Vitals: blood pressure (systolic + diastolic separately), weight, BMI, height, pulse, temperature, oxygen saturation.

2. **Resolve the vault** via the `obsidian-notes` host-config (`~/.claude/hosts/<hostname>.md`). Bail clearly if none is configured.

3. **Archive the scan:** copy the source file into `<vault>/Attachments/` named `<visit_date>-<slug>.<ext>` (e.g. `2026-06-03-osu-sleep-avs.pdf`). The attachment is a source artifact — name it by the document's own date for findability. Verify the filename is unique in the vault (the embed resolves by filename).

4. **Write the note** at `<vault>/Notes/<write-year>/<write-month>/<write-date>-<slug>.md`:
   - **Filename prefix = today's write date**, NOT the visit date. The prefix is a de-dupe / folder-partition key; the visit date lives in frontmatter as `visit_date`.
   - Frontmatter — the schema (see below). **Vitals are flat, top-level, Number-typed properties.** This is deliberate and load-bearing (see "Why this schema").
   - Body: visit header, a human-readable vitals table, plan & follow-up, a condensed instructions summary (keep patient-specific guidance; the full text lives in the embedded PDF), and the embedded source (`![[<attachment>]]`).

5. **Report** where the note and attachment landed, and note that it will appear in the Medical Vitals base.

## Frontmatter schema

```yaml
---
title: <provider> — After Visit Summary
type: medical-visit
visit_date: 2026-06-03            # semantic date (Date type)
tags:
  - medical/visit
  - <specialty>                   # e.g. sleep-medicine
provider: <institution>
department: <department>
department_phone: <phone>
mrn: "<mrn>"                      # quoted — keep as Text, not a number
visit_reason:
  - <reason>
referral: <referral + expiry>     # omit if none
follow_up: 2026-12-03             # omit if none
medications: <text or "none prescribed">
source_pdf: "[[<attachment filename>]]"
captured: 2026-07-13              # write date; matches filename prefix
# --- vitals: flat Number properties → Bases columns / Dataview trending ---
bp_systolic: 122
bp_diastolic: 68
weight_lb: 188
bmi: 26.98
height_in: 70
pulse_bpm: 77
temp_f: 97.3
spo2_pct: 99
---
```

## Why this schema (do not "improve" it back to the obvious-but-wrong forms)

Verified against Obsidian's official Properties and Bases docs:

- **Vitals are flat top-level properties, not a nested `vitals:` object.** Obsidian's Bases model is literally "each row is a file, each column is a property of that file," and Bases/Dataview read **frontmatter only, never the note body**. Nested properties are *not supported* in the Properties UI. So flat frontmatter is the correct — and only — form that serves both Bases and Dataview.
- **Blood pressure is split into two Numbers** (`bp_systolic`/`bp_diastolic`), not a single `122/68` string. Obsidian has 6 property types (Text, List, Number, Checkbox, Date, Date&time) and no unit type; a `122/68` value is Text and can't be trended. Split → both Numbers → aggregatable.
- **Numbers are bare** (no quotes, no units in the value) so they type as Number. Units go in the key (`weight_lb`, `temp_f`) since there is no unit type. `mrn` is the exception — quote it so it stays Text.
- **No `vital_` prefix.** `type: medical-visit` already scopes these; clean names make better Base columns.

## The Medical Vitals base

Records feed `<vault>/Areas/Health/Medical Vitals.base` — a table filtered to `type == "medical-visit"`, sorted by `visit_date`, with the vitals as columns and a `bp` formula (`bp_systolic + "/" + bp_diastolic`) for display. It exists after the first record; adding visits just adds rows. If it is missing, recreate it with that shape.

## Edge cases

- **Missing vitals:** omit absent properties rather than writing nulls or zeros — a zero would corrupt trend averages.
- **Ambiguous visit date:** if the appointment date isn't clearly recoverable, ask (AskUserQuestion) rather than guessing; it is the semantic key.
- **Non-AVS medical doc** (lab result, imaging, immunization): out of scope for v1 — say so and fall back to the router's generic capture. Those get their own handlers later.
- **Height unchanged across visits:** fine to carry it each time; it makes each record self-contained.
