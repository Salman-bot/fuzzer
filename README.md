# fuzzer

Fuzzy file-content search for plain text, PDF, and DOCX — CLI + Tk GUI,
Arabic-aware, with optional Claude-powered semantic search and a grounded
chat panel.

```sh
# install deps, build native extension, run tests
make install build-native test

# fastest way to try it
./fuzzer                      # GUI
./fuzzer "climate" *.pdf      # one-shot CLI search
```

Detailed CLI/GUI reference lives in [doc/usage.md](doc/usage.md).

## Features

### Search

- Exact substring + fuzzy matching (default threshold 80, configurable per flag).
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

- `-a` / `--ai` for semantic line selection across a file (CLI + GUI).
- **Grounded chat panel** in the GUI: keeps conversation history, auto-loads
  the *Files/folders* selection as context, cites line tags like `[p.3 L42]`
  so answers point back to specific lines.

### GUI

- Drag-and-drop file/folder paths into the search field.
- Double-click a row to open: PDF → Preview at the matched page with yellow
  highlights on every hit; text/code → `code`/`cursor`/`subl` at the matched line.
- Persistent state (`~/.fuzzer_gui_state.json`): search history, API key,
  toggles, last files.

### Export

- `-o hits.{csv,tsv,json,txt,xlsx}` — format auto-detected from extension.

## Versions

| Version | Commit | Highlights |
| ------- | ------ | ---------- |
| 0.1.0 | [40426b9](../../commit/40426b9) | Initial release — CLI + GUI, fuzzy + exact, PDF/DOCX, export formats |
| 0.2.0 | [72c58ff](../../commit/72c58ff) | Arabic PDF highlighting, GUI polish, native `_ar_norm` extension |
| 0.3.0-dev | (working tree) | Grounded Claude chat panel with file context + conversation history; `make doc` / `make doc-clean` for regenerable codebase overviews |

No `__version__` constant ships in the script yet — versions track git tags / commits.

## Planned features

- **Click-to-jump on chat citations.** When Claude replies with `[p.3 L42]`, make the tag clickable to open the source PDF at that page/line.
- **Streaming responses** in the chat panel (currently waits for full reply).
- **Persist chat history** across GUI sessions, keyed per file selection.
- **AI mode for the CLI chat loop** — currently the CLI's `-a` is one-shot; bring the grounded conversational mode to the terminal.
- **More file formats** — `.epub`, `.rtf`, `.odt`.
- **Tests covering AI mode + chat** — currently neither path is exercised by `test_fuzzer.py`.
- **Windows install notes** — Makefile assumes Unix; document a PowerShell path.
- **Ship a `__version__` constant** in `fuzzer` and surface it via `--version`.

## Documentation

Two doc systems live side-by-side:

### Hand-maintained — [doc/](doc/)

The source of truth, edited by humans:

| File | Covers |
| ---- | ------ |
| [doc/index.md](doc/index.md) | Top page + quick start |
| [doc/usage.md](doc/usage.md) | CLI flags, examples, GUI walkthrough |
| [doc/architecture.md](doc/architecture.md) | Module layout, sequence diagram explanation |
| [doc/c-extension.md](doc/c-extension.md) | `_ar_norm` reference |
| [doc/development.md](doc/development.md) | Build / test / contribute |
| [doc/sequence-diagram.mmd](doc/sequence-diagram.mmd) | Mermaid source for the architecture diagram |

### Generated

| Artifact | Built by | What it is | Cleaned by |
| -------- | -------- | ---------- | ---------- |
| `doc/_build/*.html` | `make docs` | HTML site rendered from `doc/*.md` + pdoc API reference | `make docs-clean` |
| `doc/_build/api.html` | `make docs-api` | pdoc API reference only (faster) | `make docs-clean` |
| [project_info.md](project_info.md) | `make doc` | One-file codebase overview produced by `claude -p` (gitignored — regenerable) | `make doc-clean` |
| `test_pdfs/*.pdf` | `make test-corpus` | ~50 public Arabic + English PDFs for the real-corpus test (gitignored — fetched from arXiv + Arabic Wikipedia) | `make test-corpus-clean` |

#### Generating the docs

```sh
make docs        # full HTML site under doc/_build/
make docs-serve  # docs + local web server at http://localhost:8765/
make docs-api    # API reference only
make doc         # regenerate project_info.md via Claude CLI
```

`make doc` needs the [Claude Code](https://docs.claude.com/en/docs/claude-code/overview)
CLI installed. The target prints install instructions and an API-key link if
`claude` isn't found. You can sign in with a Claude.ai account or export an
`ANTHROPIC_API_KEY` from <https://console.anthropic.com/settings/keys>.

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

See [doc/architecture.md](doc/architecture.md#file-layout) for the full tree.
The short version:

```text
fuzzer            ← the script (CLI + GUI + core logic, no .py extension)
test_fuzzer.py    ← pytest suite
Makefile          ← test / build-native / docs / doc targets
native/           ← C extension source
doc/              ← hand-maintained docs (+ _build/ generated site)
```

## License

See repo for license terms.
