# fuzzer — documentation

`fuzzer` is a fuzzy file-content search tool. It works on plain text, PDF, and
DOCX files; supports Arabic + English; and can optionally use Claude for
semantic search and grounded chat.

> **The CLI is no longer maintained.** All development is focused on the GUI.

## Table of contents

| Doc | What it covers |
| --- | -------------- |
| [usage.md](usage.md) | GUI walkthrough and reference |
| [architecture.md](architecture.md) | High-level overview + sequence diagram |
| [c-extension.md](c-extension.md) | `_ar_norm` C extension reference |
| [development.md](development.md) | Build, test, contribute |
| [api.html](api.html) | Generated Python API reference (run `make docs`) |
| [sequence-diagram.md](sequence-diagram.md) | Source mermaid for the architecture diagram |

## Quick start

```sh
# Install (Windows)
.\install.ps1

# Install (Linux / macOS)
./install.sh

# Launch the GUI
fuzzer
```

## Build the docs

```sh
make docs      # renders HTML to doc/_build/
make docs-api  # only the pdoc API reference
```
