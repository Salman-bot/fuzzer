# Usage

`fuzzer` is a GUI-first search tool for plain text, PDF, and DOCX files.
Run it with no arguments to launch the GUI.

```sh
fuzzer          # launch the GUI
fuzzer --gui    # same
```

> **The CLI is no longer maintained.** It still works for one-shot searches
> but receives no new features or bug fixes. Use the GUI for all active use.

## Supported file types

`.txt` `.md` `.rst` `.csv` `.tsv` `.log` `.json` `.xml` `.html` `.htm`
`.pdf` (via PyMuPDF or pdfplumber) `.docx` `.doc` (via python-docx)

## GUI

Launch with `fuzzer` (no arguments) or `fuzzer --gui`.

State is persisted to `~/.fuzzer_gui_state.json` between sessions, including
the search history, last used files, threshold, API key, option toggles,
and window size/state. The window is centered on screen each launch (when
not maximized), and the chat panel always opens expanded so it's visible
right away — you can still collapse it during a session.

### Workflow

1. Type or paste a pattern in the **Pattern** combo box (history is restored from previous sessions).
2. Type, paste, or **drag-drop** paths into the **Files/folders** entry. Picking a folder enables recursive search.
3. Toggle options (Case-sensitive, Exact only, Recursive, AI mode, Verbose).
4. Click **Search**. Progress appears in the status bar.
5. Results land in the table:
    - **Select a row** to update the **Selected-match** bar below (shows file + line + match info).
    - **Hover the Content** cell to see the full snippet in a tooltip.
    - **Double-click** a row to open the file:
        - PDF → opened at the matched page with yellow highlights on every hit
        - Text/code → opened in `code`/`cursor`/`subl` at the matched line if available, otherwise the default app
    - Press **Ctrl+C** to copy the currently selected match (file:line + snippet).
6. Click **Export…** to save results as `.csv`, `.tsv`, `.json`, `.txt`, or `.xlsx`.

### Options

| Control | Effect |
| ------- | ------ |
| Case-sensitive | Match uppercase/lowercase exactly |
| Exact only | Strict whole-word match, no fuzzy — `asic` will NOT match `basic`. (Implies "Whole word".) |
| Whole word | Whole-word match for score-100 hits (regex `\b` boundaries). Fuzzy fallback still applies below the threshold. |
| Recursive | Search subfolders when a folder is given |
| AI mode | Semantic search via Claude (needs `ANTHROPIC_API_KEY` or a saved key) |
| Verbose (sentence) | Show the full sentence surrounding each match |
| Threshold | Minimum fuzzy similarity score 0–100 (default 80) |

### AI mode

Click **API Key…** to store an `ANTHROPIC_API_KEY`. The key is saved to
`~/.fuzzer_gui_state.json`. With a key set:

- The bottom **Claude Chat** panel becomes active.
- **AI mode** can be selected to use Claude for semantic search — matches are
  tagged `[AI]` instead of a numeric similarity score.
- The chat panel keeps full conversation history. When files are selected in
  *Files/folders*, Claude receives a tiny **manifest** (paths + previews) —
  not the full content — and reads on demand via tools.

### How the chat reads your files (lazy / on-demand)

To stay within strict API rate limits (e.g. 10 K input tokens/minute on
free-tier accounts), the chat panel does **not** preload file content. Instead:

1. When you select files/folders, Claude gets a manifest: filename, line
   count, page count (PDFs), and a one-line preview each — typically a few
   thousand tokens total.
2. Claude then uses tools to fetch what it needs:
    - **`search_in_context`** — fuzzy search across all your loaded files,
      returns matching lines with `[L42]` / `[p.3 L42]` tags.
    - **`read_file_chunk`** — read a specific line range from one file.
3. Quoted passages cite line tags so you can jump to them in the GUI.

If you ask *"summarize file X"* Claude will call `read_file_chunk` first.
If you ask *"find every mention of FPGA across these papers"* it calls
`search_in_context`. Either way, only the lines that matter come back over
the wire.

### Token limits and warnings

Both AI mode and the chat panel use Claude Sonnet 4.6 (200 K-token context).
Per-call caps and the warnings the GUI emits when you hit them:

| Limit | Default | Warning |
| ----- | ------- | ------- |
| AI search — document input | 120 K chars (~30 K tokens) per file | logs *"Document truncated …"* when a file is cut off, *"Large document …"* once it crosses 80 K chars |
| AI search — response | 8 192 output tokens | logs *"Response hit max_tokens cap …"* if Claude ran out of room |
| Chat — manifest size | 20 K chars (paths + previews only) | logs *"Manifest budget full …"* if too many files were selected to list — Claude can still reach unlisted files by exact path |
| Chat — response | 16 384 output tokens per round | warns in chat *"Response hit max_tokens cap …"* when truncated |
| Chat — tool result fed back to Claude | 40 K chars per call | warns in chat *"Tool … output truncated by N chars."* |
| Chat — extended thinking | 10 000 thinking-tokens budget | (falls back to no-thinking mode automatically) |
| Chat — kept turns of history | 40 user/assistant turns | (older turns drop silently; the leading manifest pair is preserved) |

Defaults can be tuned by editing the `_AI_*` and `_CHAT_*` constants near the
top of `ai_search_file` and the chat section in the `fuzzer` script.

### Chat panel

The **Claude Chat** panel at the bottom is **always visible on launch** —
even if you collapsed it last session — so you don't lose it behind the
results table:

- Click the **▾ / ▸ Claude Chat** header button to toggle it.
- **View → Claude Chat** menu item or **Ctrl+Shift+C** does the same.
- During a session the toggle is sticky; only the next-launch state is forced open.

### Dark mode

**Mode → 🌙 Dark mode** (or **Ctrl+Shift+D**) switches between light and dark themes live, no restart needed.

The dark theme uses a moon-purple palette — deep space purple-black background, lavender text, violet accent, and matching chat colors. The choice is persisted to `~/.fuzzer_gui_state.json`.

### Arabic text

The GUI uses `Geeza Pro` / `Arial Unicode MS` / `Tahoma` for Arabic if available.
On macOS, CoreText handles RTL shaping natively. On other platforms,
`arabic_reshaper` + `python-bidi` reorder glyphs before display.

`PyMuPDF`'s `sort=True` mode is used to fix Arabic ligature order in PDFs. A
broken-encoding fixup (`ا+م+ل` → `ا+ل+م` at word start) handles older PDFs
where the definite article was encoded out of order.

## Environment

| Variable | Purpose |
| -------- | ------- |
| `ANTHROPIC_API_KEY` | Used by AI mode if no key is stored in the GUI state |

## Exit codes

| Code | Meaning |
| ---- | ------- |
| `0` | Success (GUI exited cleanly, or CLI found matches) |
| `1` | No matches found (CLI only) |
| `2` | Error (no files, bad arguments, missing dependencies) |

---

## Legacy CLI reference

> **Not maintained.** Documented here for reference only.

```sh
fuzzer [options] PATTERN FILE [FILE ...]
```

| Flag | Effect |
| ---- | ------ |
| `-k`, `--case-sensitive` | Case-sensitive comparison |
| `-e`, `--exact` | Strict whole-word match, no fuzzy — `asic` will NOT match `basic` (implies `-w`) |
| `-w`, `--whole-word` | Whole-word match for score-100 hits (regex `\b` boundaries); fuzzy fallback still applies |
| `-t N`, `--threshold N` | Fuzzy similarity threshold 0–100 (default `80`) |
| `-a`, `--ai` | Semantic search via Claude (needs `ANTHROPIC_API_KEY`) |
| `-v`, `--verbose` | Show the full sentence around each match |
| `-C N`, `--context N` | Print N lines of context above/below each match |
| `-l`, `--files-only` | Print only matched filenames |
| `-n`, `--no-line-numbers` | Suppress line numbers in output |
| `-r`, `--recursive` | Recurse into directories |
| `--no-color` | Disable ANSI color codes |
| `-o FILE`, `--output FILE` | Export results (format auto-detected from extension) |

## Quick start

```sh
./install.sh          # Linux / macOS
.\install.ps1         # Windows
fuzzer                # launch the GUI
```

See also: [INTERNALS.md](INTERNALS.md), [DEVELOPMENT.md](DEVELOPMENT.md).
