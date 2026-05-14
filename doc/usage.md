# Usage

`fuzzer` has two modes: a CLI for one-shot searches and scripts, and a Tk GUI
for interactive use. With no arguments, it launches the GUI.

## Supported file types

`.txt` `.md` `.rst` `.csv` `.tsv` `.log` `.json` `.xml` `.html` `.htm`
`.pdf` (via PyMuPDF or pdfplumber) `.docx` `.doc` (via python-docx)

## CLI reference

```sh
fuzzer [options] PATTERN FILE [FILE ...]
```

Case-insensitive matching and fuzzy matching are **on** by default. PDF / DOCX
extraction is cached in `~/.fuzzer_cache.sqlite` keyed by path + mtime — repeat
searches over the same files are near-instant.

### Matching options

| Flag | Effect |
| ---- | ------ |
| `-k`, `--case-sensitive` | Case-sensitive comparison |
| `-e`, `--exact` | Exact substring only — disable fuzzy scoring |
| `-t N`, `--threshold N` | Fuzzy similarity threshold 0–100 (default `80`) |
| `-a`, `--ai` | Semantic search via Claude (needs `ANTHROPIC_API_KEY`) |

### Output options

| Flag | Effect |
| ---- | ------ |
| `-v`, `--verbose` | Show the full sentence around each match |
| `-C N`, `--context N` | Print N lines of context above/below each match |
| `-l`, `--files-only` | Print only matched filenames |
| `-n`, `--no-line-numbers` | Suppress line numbers in output |
| `-r`, `--recursive` | Recurse into directories |
| `--no-color` | Disable ANSI colour codes |
| `-o FILE`, `--output FILE` | Export results. Format auto-detected from extension. |

### Export formats

`-o hits.csv` `.tsv` `.json` `.txt` `.xlsx` — extension picks the writer.

## Examples

```sh
# Verbose: include the surrounding sentence
fuzzer -v "global warming" thesis.pdf

# Exact, case-sensitive
fuzzer -ke "CaseSensitive" notes.txt

# Lower threshold for messy / OCR'd text
fuzzer -t 60 "aproximate" *.txt

# 2 lines of context above and below
fuzzer -C 2 "keyword" chapter.txt

# Recursive search over a folder
fuzzer -r "topic" ./docs/

# AI semantic search
fuzzer -a "renewable energy trends" paper.pdf

# Export
fuzzer -o hits.xlsx "topic" *.pdf
fuzzer -o hits.json "topic" *.pdf
```

## GUI

Launch with `fuzzer` (no args) or `fuzzer --gui` (or `python3 fuzzer_gui.py`).

The GUI mirrors the CLI flags as form controls. State is persisted to
`~/.fuzzer_gui_state.json` between sessions, including the search history,
last used files, threshold, API key, and option toggles.

### Workflow

1. Type or paste a pattern in the **Pattern** combobox (history is restored from previous sessions).
2. Type, paste, or **drag-drop** paths into the **Files/folders** entry. Picking a folder enables recursive search.
3. Toggle options (Case-sensitive, Exact only, Recursive, AI mode, Verbose).
4. Click **Search**. Progress appears in the status bar.
5. Results land in the table:
    - **Select a row** to update the **Selected-match** bar below (shows file + line + match info).
    - **Hover the Content** cell to see the full snippet in a tooltip.
    - **Double-click** a row to open the file:
        - PDF → opened in Preview at the matched page with yellow highlights on every match (macOS)
        - Text/code → opened in `code`/`cursor`/`subl` at the matched line if available, otherwise the default app
    - Press **Ctrl+C** to copy the currently selected match (file:line + snippet).
6. Click **Export…** to save results.

### AI mode

Click **API Key…** to store an `ANTHROPIC_API_KEY`. The key is saved to
`~/.fuzzer_gui_state.json`. With a key set, the bottom **Claude Chat** panel
becomes active and AI mode is selectable. AI matches are scored with the
`[AI]` tag and do not use a numeric similarity score.

### Arabic text

The GUI uses Geeza Pro / Arial Unicode MS for Arabic if available. On macOS,
CoreText handles RTL shaping natively. On other platforms, `arabic_reshaper`
+ `python-bidi` are used to reorder glyphs before display.

PyMuPDF's `sort=True` mode is used to fix Arabic ligature order in PDFs. A
broken-encoding fixup (`ا+م+ل` → `ا+ل+م` at word start) handles older PDFs
where the definite article was encoded out of order.

## Environment

| Variable | Purpose |
| -------- | ------- |
| `ANTHROPIC_API_KEY` | Used by `-a` / AI mode if no key is stored in the GUI state |

## Exit codes

| Code | Meaning |
| ---- | ------- |
| `0` | Matches found and printed |
| `1` | No matches found |
| `2` | Error (no files, bad arguments, missing dependencies) |
