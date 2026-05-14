# fuzzer — documentation

`fuzzer` is a fuzzy file-content search tool. It works on plain text, PDF, and
DOCX files; supports Arabic + English; has a CLI and a Tk GUI; and can
optionally use Claude for semantic search.

## Table of contents

| Doc | What it covers |
| --- | -------------- |
| [usage.md](usage.md) | CLI flags, examples, GUI walkthrough |
| [architecture.md](architecture.md) | High-level overview + sequence diagram |
| [c-extension.md](c-extension.md) | `_ar_norm` C extension reference |
| [development.md](development.md) | Build, test, contribute |
| [api.html](api.html) | Generated Python API reference (run `make docs`) |
| [sequence-diagram.md](sequence-diagram.md) | Source mermaid for the architecture diagram |

## Quick start

```sh
# Search PDFs for an Arabic phrase
fuzzer "التواصل الإداري" report.pdf

# Recursive English search across a folder, 70 % fuzzy threshold
fuzzer -r -t 70 "climate" ./papers/

# AI semantic search (needs ANTHROPIC_API_KEY)
fuzzer -a "what does the author say about renewable energy?" paper.pdf

# Export
fuzzer -o hits.xlsx "topic" *.pdf

# GUI
fuzzer
```

## Build the docs

```sh
make docs      # renders HTML to doc/_build/
make docs-api  # only the pdoc API reference
```
