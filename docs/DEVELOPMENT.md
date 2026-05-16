# Development

## Install dependencies

```sh
make install
# = pip install pymupdf rapidfuzz pdfplumber openpyxl python-docx
#               pyarabic tkinterdnd2 arabic_reshaper python-bidi
```

All deps are optional — `fuzzer` falls back gracefully if any are missing
(see [INTERNALS.md](INTERNALS.md#optional-dependencies)).

## Build the C extension

```sh
make build-native    # builds _ar_norm and drops the .so next to the script
```

The `test` and `demo` targets depend on `build-native`, so `make test` will
build the extension automatically.

## Run tests

```sh
make test       # 25 tests; the visual one opens a PDF in Preview for 1.5s
make test-v     # verbose
make test-vv    # verbose with short tracebacks
make demo       # only the visual highlight demo
```

The visual test (`TestVisualHighlight`) opens a highlighted PDF in
Preview and auto-closes it after the assertion. To skip:

```sh
python3 -m pytest test_fuzzer.py --deselect test_fuzzer.py::TestVisualHighlight
```

## Build the docs

```sh
make docs        # markdown → HTML in doc/_build/, plus pdoc API reference
make docs-api    # just the pdoc API reference
```

The `docs` target uses:

- **pdoc** for the Python API reference (auto-generated from docstrings)
- **markdown** for the prose docs in `doc/*.md`
- **mermaid-cli** for diagrams (already used for the sequence diagram)

## Project conventions

- The script is named `fuzzer` (no `.py`) so it can be dropped onto `$PATH`
  and called directly. Imports work via the standard shebang interpreter.
- The test suite loads `fuzzer` by compiling and `exec`'ing it into a fresh
  `types.ModuleType` — see `_load_fuzzer()` in `test_fuzzer.py`.
- Optional dependencies are imported at the point of use, never at module
  top, so a partial install still runs.
- The GUI is one big nested-function block inside `run_gui()` — every helper
  closes over the local state dict so we don't need a class.

## Editing the C extension

1. Edit [native/ar_normalize.c](../native/ar_normalize.c)
2. `make build-native` (idempotent — only rebuilds if the .c is newer)
3. `make bench-native` to confirm the speedup
4. `make test` for correctness (the Arabic search tests exercise the extension)

For new normalization rules, add to `ar_is_drop()` (codepoints to delete) or
`ar_map()` (codepoint substitutions). Both inline functions live at the top
of `ar_normalize.c`.

## Adding a new file format

1. Write `_extract_<format>(fp) -> Optional[List[str]]` in `fuzzer`
2. Add `.<ext>` → `_extract_<format>` to `_EXT_MAP`
3. Add a test fixture and a search test in `test_fuzzer.py`

If extraction yields per-page or per-section metadata you want surfaced (like
PDF page numbers), store it in a module-level dict keyed by `fp` — see
`_pdf_page_map` for the pattern.

## Releasing

There is no release process yet. The script is intended to live on `$PATH`
and update via `git pull`. The C extension rebuilds via `make build-native`.

## Filing bugs

Include:

1. Output of `fuzzer --help` (confirms version + supported flags)
2. The exact command you ran
3. A minimal sample file that reproduces the issue (if applicable)
4. Python version: `python3 --version`
5. Platform: `uname -a`
