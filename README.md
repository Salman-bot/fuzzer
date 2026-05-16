# fuzzer

Fuzzy file-content search for plain text, PDF, and DOCX — Tk GUI,
Arabic-aware, with optional Claude-powered semantic search and a grounded
chat panel.

> **The CLI is no longer maintained.** All development is focused on the GUI.
> Run `fuzzer` with no arguments to launch it.

```sh
# one-shot setup on a fresh machine (Python deps + native build + smoke test)
./install.sh           # Linux / macOS
.\install.ps1          # Windows

# launch the GUI
fuzzer
```

GUI reference lives in [docs/USAGE.md](docs/USAGE.md). Fresh-Mac setup
walkthrough: [docs/INSTALL.md](docs/INSTALL.md).

## Features

### Search

- Substring + fuzzy matching (default threshold 80, configurable per flag).
- **Whole-word** match (`\b` regex boundaries) — `asic` will NOT match `basic`.
  Either via the "Whole word" checkbox or implied by "Exact only".
- "Exact only" disables fuzzy *and* implies whole-word — the strictest mode.
- Recursive folder search with extension filtering.
- Case-sensitive / case-insensitive toggle.
- SQLite extraction cache keyed by `(path, mtime)` — repeat searches are near-instant.

### File formats

- `.txt .md .rst .csv .tsv .log .json .xml .html .htm`
- `.pdf` via PyMuPDF, falling back to pdfplumber.
- `.docx .doc` via python-docx.

### Arabic

- Native `_ar_norm` C extension for diacritic/variant normalization (with Python fallbacks).
- PyMuPDF `sort=True` to fix Arabic ligature order in PDFs.
- CoreText shaping on macOS; `arabic_reshaper` + `python-bidi` elsewhere.

### AI mode

Needs `ANTHROPIC_API_KEY`.

- **Grounded chat panel** in the GUI: keeps conversation history, cites line
  tags like `[p.3 L42]` so answers point back to specific lines.
- **Lazy file context** — Claude receives a tiny *manifest* (paths +
  previews) of your loaded files, not the content itself. It pulls what it
  needs via `search_in_context` (fuzzy search) and `read_file_chunk` tools.
  This keeps per-turn input small enough for tight rate limits (e.g. 10 K
  input tokens / minute).
- Token caps surface as visible warnings when responses, manifests, or tool
  results get truncated — no silent clipping.
- AI search mode in the GUI flags matches with `[AI]` instead of a numeric score.

### GUI

- Drag-and-drop file/folder paths into the search field.
- Double-click a row to open: PDF → Preview at the matched page with yellow
  highlights on every hit; text/code → `code`/`cursor`/`subl` at the matched line.
- **Dark mode** with a moon-purple palette — `Mode → 🌙 Dark mode` or
  `Ctrl+Shift+D`, persisted across sessions.
- Window auto-fits to its content and **centers on screen** each launch.
- Chat panel is **always open on launch** so it can't get lost behind
  results; collapse/expand with `Ctrl+Shift+C` during a session.
- Persistent state (`~/.fuzzer_gui_state.json`): search history, API key,
  toggles, theme, window geometry, last files.

### Export

- Click **Export…** in the GUI to save results as `.csv`, `.tsv`, `.json`, `.txt`, or `.xlsx`.

## Versions

| Version | Commit | Highlights |
| ------- | ------ | ---------- |
| 0.1.0 | [40426b9](../../commit/40426b9) | Initial release — CLI + GUI, fuzzy + exact, PDF/DOCX, export formats |
| 0.2.0 | [72c58ff](../../commit/72c58ff) | Arabic PDF highlighting, GUI polish, native `_ar_norm` extension |
| 0.3.0-dev | (working tree) | Grounded Claude chat panel with **lazy** file context (manifest + tool-driven reads); whole-word search option; moon-purple dark mode; auto-fit + centered window; visible token-limit warnings; `make doc` / `make doc-clean` for regenerable codebase overviews |

No `__version__` constant ships in the script yet — versions track git tags / commits.

## Planned features

- **Click-to-jump on chat citations.** When Claude replies with `[p.3 L42]`, make the tag clickable to open the source PDF at that page/line.
- **Streaming responses** in the chat panel (currently waits for full reply).
- **Persist chat history** across GUI sessions, keyed per file selection.
- **Click-to-jump on chat citations** — make `[p.3 L42]` tags in Claude's replies clickable to open the PDF at that page.
- **More file formats** — `.epub`, `.rtf`, `.odt`.
- **Tests covering AI mode + chat** — currently neither path is exercised by `test_fuzzer.py`.
- **Ship a `__version__` constant** in `fuzzer` and surface it in the GUI title bar.

## Documentation

All docs live in [docs/](docs/):

| File | Covers |
| ---- | ------ |
| [docs/INSTALL.md](docs/INSTALL.md) | Fresh-Mac setup (Homebrew → fuzzer → optional transcribe helper) |
| [docs/USAGE.md](docs/USAGE.md) | GUI walkthrough + CLI flags |
| [docs/INTERNALS.md](docs/INTERNALS.md) | Architecture, `_ar_norm` C extension, sequence diagram |
| [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md) | Build / test / contribute |
| [docs/GenAI_Harms.md](docs/GenAI_Harms.md) | Research notes (lit review + summary table + evidence synthesis) |

### Generated

| Artifact | Built by | What it is | Cleaned by |
| -------- | -------- | ---------- | ---------- |
| `docs/_build/*.html` | `make docs` | HTML site rendered from `docs/*.md` + pdoc API reference | `make docs-clean` |
| `docs/_build/api.html` | `make docs-api` | pdoc API reference only (faster) | `make docs-clean` |
| `test_pdfs/*.pdf` | `make test-corpus` | ~50 public Arabic + English PDFs for the real-corpus test (gitignored — fetched from arXiv + Arabic Wikipedia) | `make test-corpus-clean` |

#### Generating the docs

```sh
make docs        # full HTML site under docs/_build/
make docs-serve  # docs + local web server at http://localhost:8765/
make docs-api    # API reference only
```

`make docs` auto-installs `pdoc markdown pygments` to the user site if they're
missing.

## Testing

```sh
make test            # 25 unit tests against synthetic fixtures (no network)
make test-corpus     # fetch ~50 real PDFs from arXiv + Arabic Wikipedia
make test            # now also runs TestRealCorpus parametrized over those files
```

The `TestRealCorpus` class in [test_fuzzer.py](test_fuzzer.py) is auto-skipped
when `test_pdfs/` is empty, so `make test` works on a fresh clone without the
corpus. Once fetched, it iterates over every PDF and asserts that extraction,
page-mapping, fuzzy search, and Arabic normalization all behave on real input
— surfacing regressions that synthetic fixtures can't.

The corpus itself is gitignored (large binaries) — clone the URL list, not
the PDFs. A `test_pdfs.tar.gz` snapshot (~123 MB) is also kept on Proton
Drive as a backup in case the upstream URLs ever go stale; `make test-corpus`
remains the primary way to get the corpus.

## Repo layout

See [docs/INTERNALS.md](docs/INTERNALS.md) for the architecture section.
The short tree:

```text
fuzzer            ← the script (CLI + GUI + core logic, no .py extension)
transcribe        ← helper: YouTube/audio/video → searchable PDF
test_fuzzer.py    ← pytest suite
Makefile          ← test / build-native / docs targets
native/           ← C extension source
docs/             ← hand-maintained docs (+ _build/ generated site)
```

## License

See repo for license terms.
