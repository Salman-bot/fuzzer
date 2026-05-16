# fuzzer

Fuzzy file-content search for plain text, PDF, and DOCX — Tk GUI,
Arabic-aware, macOS-only.

```sh
# one-shot setup on a fresh Mac
./install.sh

# launch the GUI
fuzzer
```

Full walkthrough: [docs/USAGE.md](docs/USAGE.md). Fresh-Mac install:
[docs/INSTALL.md](docs/INSTALL.md).

## Features

### Search

- Substring + fuzzy matching (default threshold 80, adjustable).
- Recursive folder search.
- Case-sensitive / case-insensitive toggle.
- SQLite extraction cache keyed by `(path, mtime)` — repeat searches are
  near-instant.
- Optional [ripgrep-all](https://github.com/phiresky/ripgrep-all) backend
  extends file coverage to `.epub .xlsx .sqlite .mkv` etc.

### File formats

- `.txt .md .rst .csv .tsv .log .json .xml .html .htm`
- `.pdf` via PyMuPDF, falling back to pdfplumber.
- `.docx .doc` via python-docx.

### Arabic

- Native `_ar_norm` C extension for diacritic / variant normalization
  (Python fallback if the C extension didn't build).
- PyMuPDF `sort=True` to fix Arabic ligature order in PDFs.
- CoreText shaping on macOS; `arabic_reshaper` + `python-bidi` fallback.

### GUI

- Drag-and-drop file/folder paths into the search field.
- Double-click a row to open: PDF → Preview at the matched page with
  yellow highlights on every hit; text/code → `code` / `cursor` / `subl`
  at the matched line.
- **Dark mode** with a moon-purple palette — `Mode → 🌙 Dark mode` or
  `⌘D`, persisted across sessions.
- Window auto-fits to its content and **centers on screen** each launch.
- Persistent state (`~/.fuzzer_gui_state.json`): search history, toggles,
  theme, window geometry, last files.

### Export

Click **Export…** in the GUI to save results as `.csv`, `.tsv`, `.json`,
`.txt`, or `.xlsx`.

## Companion tool: `transcribe`

Turns YouTube URLs / audio / video into searchable PDFs that fuzzer can
then index. See [docs/INSTALL.md](docs/INSTALL.md#7-optional-the-transcribe-helper).

## Documentation

All docs live in [docs/](docs/):

| File | Covers |
| ---- | ------ |
| [docs/INSTALL.md](docs/INSTALL.md) | Fresh-Mac setup (Homebrew → fuzzer → optional transcribe) |
| [docs/USAGE.md](docs/USAGE.md) | GUI walkthrough |
| [docs/INTERNALS.md](docs/INTERNALS.md) | Architecture, `_ar_norm` C extension |
| [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md) | Build / test / contribute |
| [docs/GenAI_Harms.md](docs/GenAI_Harms.md) | Research notes (separate topic) |

### Building the HTML docs site

```sh
make docs        # full HTML site under docs/_build/
make docs-serve  # docs + local web server at http://localhost:8765/
make docs-api    # API reference only
```

`make docs` auto-installs `pdoc markdown pygments` to the user site if
missing.

## Testing

```sh
make test            # 25 unit tests against synthetic fixtures (no network)
make test-corpus     # fetch ~50 real PDFs from arXiv + Arabic Wikipedia
make test            # now also runs TestRealCorpus parametrized over those files
```

The `TestRealCorpus` class in [test_fuzzer.py](test_fuzzer.py) is auto-skipped
when `test_pdfs/` is empty, so `make test` works on a fresh clone without the
corpus.

## Repo layout

```text
fuzzer            ← the GUI app (Python, no .py extension so it's on $PATH)
transcribe        ← helper: YouTube/audio/video → searchable PDF
test_fuzzer.py    ← pytest suite
Makefile          ← test / build-native / docs targets
native/           ← C extension source for _ar_norm
docs/             ← hand-maintained docs (+ _build/ generated site)
```

## License

See repo for license terms.
