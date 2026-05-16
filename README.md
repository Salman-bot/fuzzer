# fuzzer

A friendly search tool for your Mac. Type a word — even if you misspell
it or it's in Arabic — and it finds it inside your files. Works on
`.txt`, `.md`, `.pdf`, `.docx`, and lots more.

## Install

Full step-by-step walkthrough is in
**[docs/INSTALL.md](docs/INSTALL.md)** — written for someone who has
never touched a terminal before. Quick version if you have Homebrew,
git, and Python 3.14 already:

```sh
git clone https://github.com/Salman-bot/fuzzer.git ~/bin
cd ~/bin && ./install.sh
echo 'export PATH="$HOME/bin:$PATH"' >> ~/.zshrc && source ~/.zshrc
fuzzer
```

## What it does

- Searches inside `.txt`, `.md`, `.pdf`, `.docx`, and many more formats.
- Finds your word even with typos or different spellings (fuzzy matching).
- Arabic-aware — ignores diacritics and handles letter variants.
- Double-click a result to jump straight to the page or line.
- Yellow-highlights every hit on the PDF page when it opens.
- Dark mode, drag-and-drop, search history, export to Excel / CSV / JSON.
- Built-in Claude chat panel — ask questions *about* your search results.

## How it works

```text
        you type a word
              │
              ▼
   ┌────────────────────────────────────┐
   │  fuzzer reads your files           │
   │  (txt · md · pdf · docx · csv …)   │
   │                                    │
   │  then fuzzy-matches every line     │
   │  against what you typed            │
   └────────────────────────────────────┘
              │
              ▼
   results table — one row per match
              │
              ▼ double-click a row
              │
   the file opens at the exact page / line
   (PDFs get yellow highlights on every hit)
```

The second search on the same folder is near-instant — fuzzer caches
what it reads.

## Companion tool: `transcribe`

Turns YouTube links, audio, or video into searchable PDFs that fuzzer
can then search. Click **Transcribe…** in the toolbar, pick a `.docx`
of YouTube links, then pick a folder.

```text
   .docx of YouTube links
            │
            ▼
   ┌──────────────────┐    ┌──────────────────┐    ┌──────────────────┐
   │  yt-dlp / ffmpeg │ →  │     Whisper      │ →  │   PyMuPDF        │
   │  download audio  │    │  speech → text   │    │   text → PDF     │
   └──────────────────┘    └──────────────────┘    └──────────────────┘
            │
            ▼
   one PDF per link  +  a combined master PDF
            │
            ▼
   fuzzer searches inside them
```

Setup and CLI usage:
[docs/INSTALL.md § 9](docs/INSTALL.md#9--transcribe-audio--video--youtube--searchable-pdf).

## Claude chat panel

The right side of the fuzzer window has a chat box you can ignore — or
use to ask Claude questions about your search results. Searching,
opening files, and exporting all work without it; the chat is optional.

```text
   your search results          you type a question
            │                            │
            └──────────┐    ┌────────────┘
                       ▼    ▼
              ┌──────────────────────┐
              │   Claude (Anthropic) │
              │  reads your results  │
              │   and answers you    │
              └──────────────────────┘
                       │
                       ▼
              answer streamed into
              the chat panel — every
              file path is clickable
```

Setup, API key, and rough costs:
[docs/INSTALL.md § 8](docs/INSTALL.md#8--claude-api-key-optional-for-the-chat-panel).

## More

- **[docs/INSTALL.md](docs/INSTALL.md)** — install, Claude API key
  setup, transcribe model choices, troubleshooting.
- **[docs/USAGE.md](docs/USAGE.md)** — a short tour of the app once
  it's running.

## License

Copyright © 2026 Salman. **All rights reserved.**

This software is provided for viewing and personal reference only.
Copying, modifying, distributing, or using any part of it in your own
project or product requires written permission. See [LICENSE](LICENSE)
for the full terms.

Licensing inquiries:
[aboofa09@gmail.com](mailto:aboofa09@gmail.com).
