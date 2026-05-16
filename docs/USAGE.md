# Usage

`fuzzer` is a GUI-only fuzzy file-content search tool for plain text,
PDF, and DOCX files. Run it with no arguments to launch.

```sh
fuzzer
```

The window auto-sizes to fit its content on first launch and re-centers on
screen each time.

## GUI walkthrough

1. **Pick files / folders.** Drag-and-drop into the files entry box, or
   click the picker. Recursive search is a toggle.
2. **Type your pattern** in the search field.
3. **Toggle options** (Case-sensitive, Recursive, rga engine).
4. **Set the threshold** if needed (default `80` — minimum fuzzy similarity
   score on a 0–100 scale).
5. **Hit Search.** Results stream into the table.
6. **Double-click a row** to open the file at the matched location:
   - PDF → Preview, jumped to the matched page, with **yellow highlights**
     drawn on every hit on that page.
   - Text / code → `code` / `cursor` / `subl` (whichever is on `$PATH`),
     at the matched line.
7. **Export** via the Export… button — `.csv`, `.tsv`, `.json`, `.txt`, or
   `.xlsx`.

## Options reference

| Option | Effect |
| ------ | ------ |
| Case-sensitive | Match uppercase/lowercase exactly. Default off. |
| Recursive | Recurse into subfolders when a folder is given. |
| rga engine | Use [ripgrep-all](https://github.com/phiresky/ripgrep-all) as the search backend. Extends file coverage to docx / epub / xlsx / sqlite / mkv subtitles / etc. Trade-off: substring-only, no fuzzy fallback. Needs `brew install ripgrep-all`. |
| Threshold | Minimum fuzzy similarity score (0 = anything, 100 = exact only). Default `80`. |

## Dark mode

`Mode → 🌙 Dark mode` or `⌘⇧D` toggles a moon-purple palette. The choice
persists across launches.

## File formats

- **Plain text:** `.txt .md .rst .csv .tsv .log .json .xml .html .htm`
- **PDF** via PyMuPDF, falling back to pdfplumber.
- **DOCX / DOC** via python-docx.

With **rga** enabled, coverage extends to `.epub .xlsx .sqlite .mkv` and
several more.

## Arabic

- Native `_ar_norm` C extension for diacritic / variant normalization
  (Python fallback if the C extension didn't build).
- PyMuPDF `sort=True` to fix Arabic ligature order in PDFs.
- CoreText shaping on macOS, with `arabic_reshaper` + `python-bidi` as a
  fallback path.

## Persistent state

`~/.fuzzer_gui_state.json` stores: search history, option toggles,
theme, window geometry, and the last set of loaded files.

## Keyboard shortcuts

| Key  | Action            |
| ---- | ----------------- |
| `⌘D` | Toggle dark mode  |
| `⌘0` | Reset window size |
| `⌘Q` | Quit              |

## Exit codes

| Code | Meaning |
| ---- | ------- |
| `0`  | Clean exit |
| ≠0   | Unhandled error (see stderr) |

See also: [INSTALL.md](INSTALL.md).
