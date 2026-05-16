# fuzzer

A friendly search tool for your Mac. Type a word — even if you misspell
it or it's in Arabic — and it finds it inside your files. Works on
`.txt`, `.md`, `.pdf`, `.docx`, and lots more.

> If you've never installed anything from a terminal before, that's fine.
> Just follow the steps below in order, paste each block, and hit Enter.

---

## How to install on a fresh Mac

It takes about 10–15 minutes, mostly waiting for downloads. You'll only
do this once.

### Step 1 — Open Terminal

Press `⌘ + Space` (the Spotlight shortcut), type **Terminal**, hit
Enter. A window opens with a blinking cursor.

**That window is the Terminal — every command in this guide goes
there.** It looks something like this:

```text
yourname@MacBook ~ %  ▮
```

How to use it:

1. **Select a code block in this README** (the grey boxes below each
   step) and copy it — `⌘ + C`, or right-click → Copy.
2. **Click into the Terminal window** so the blinking cursor lives there.
3. **Paste** — `⌘ + V`, or right-click → Paste. The command appears on
   that line.
4. **Press Enter** to run it. Wait for it to finish (the prompt with
   `%` comes back when it's done).

Repeat for every step. If a command asks for your Mac password, type it
in — you won't see any letters or dots, that's normal — and press Enter.

### Step 2 — Install Apple's developer tools

```sh
xcode-select --install
```

A popup appears. Click **Install** and wait (~3 minutes). If it says
"already installed", you're done with this step — move on.

### Step 3 — Install Homebrew

Homebrew is like an App Store, but for the Terminal. It's how you
install most developer tools on a Mac. Paste this:

```sh
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

When it's done, it prints two lines that start with `eval`. **Copy each
one, paste it in, and press Enter.** That makes the `brew` command
available everywhere.

### Step 4 — Install Git, Python, and a couple of helpers

```sh
brew install git python@3.14 ffmpeg yt-dlp
```

- **Git** is the tool that downloads code from GitHub (see Step 5).
- **Python** is the language fuzzer is written in.
- **ffmpeg** and **yt-dlp** are needed if you also want to use the
  YouTube → PDF feature.

### Step 5 — Download fuzzer from GitHub

> **What is GitHub?** It's a website where developers share code, like
> Google Drive for source code. fuzzer's code lives at
> <https://github.com/Salman-bot/fuzzer>. You don't need an account or
> login to download it — it's public, anyone can copy it.

This command downloads a copy of fuzzer to a folder called `bin` inside
your home folder:

```sh
git clone https://github.com/Salman-bot/fuzzer.git ~/bin
cd ~/bin
```

(`cd ~/bin` moves your Terminal into that folder so the next steps run
in the right place.)

### Step 6 — Run the installer

```sh
./install.sh
```

This takes 5–10 minutes. It installs the Python libraries fuzzer needs,
builds a small helper for Arabic text, and installs **Skim** (a PDF
viewer that jumps to the right page when you click a search result).
It's safe to re-run anytime.

### Step 7 — Make `fuzzer` work from anywhere

```sh
echo 'export PATH="$HOME/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

After this you can type `fuzzer` from any folder and it'll work.

### Step 8 — Launch the app

```sh
fuzzer
```

The window opens. Drag a folder of PDFs into the **Files/folders** box,
type a word in the **Pattern** box, click **Search**.

That's the whole install. Everything below is optional reading.

---

## To get future updates

When a new version of fuzzer is released on GitHub, pull it down with:

```sh
cd ~/bin
git pull
./install.sh
```

`git pull` grabs the latest code; `./install.sh` re-runs the installer
in case anything new is required.

---

## What it actually does

- Searches inside `.txt`, `.md`, `.pdf`, `.docx`, and many more formats.
- Finds your word even with typos or different spellings (fuzzy matching).
- Arabic-aware — ignores diacritics and handles letter variants.
- Double-click a result to jump straight to the page or line in the file.
- Yellow-highlights every hit on the PDF page when it opens.
- Dark mode, drag-and-drop, search history, export to Excel / CSV / JSON.
- Built-in Claude chat panel — ask questions *about* your search results.

## How it works (in one picture)

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
can then search. Click the **Transcribe…** button in the toolbar, pick
a `.docx` of YouTube links (your source), then pick a folder (your
output). It runs in the background and shows a purple progress bar at
the bottom of the window.

Next to the button is a **model dropdown** — pick how careful you want
the transcription to be:

| Model    | Size    | Speed        | Best for                                  |
| -------- | ------- | ------------ | ----------------------------------------- |
| `tiny`   | ~75 MB  | fastest      | quick previews, English only really       |
| `base`   | ~150 MB | very fast    | rough drafts                              |
| `small`  | ~500 MB | fast         | decent quality, most common dialects      |
| `medium` | ~1.5 GB | slower       | good for non-English / accented speech    |
| `large`  | ~3 GB   | slowest      | highest quality — **default**             |
| `turbo`  | ~1.5 GB | ~5× of large | nearly large quality, much faster         |

> **First run with a model is slow** — Whisper downloads the model file
> the first time you use it. A dialog warns you with the size before
> the download starts. Every later run uses the cached copy and starts
> instantly.

From the terminal:

```sh
transcribe links.docx -o transcripts/ --model large --cookies chrome --also txt
transcribe links.docx --model turbo      # almost as accurate as large, much faster
transcribe lecture.mp4 -o lecture.pdf    # a local video, not YouTube
```

## What about the Claude chat?

The right side of the fuzzer window has a chat box you can ignore — or
use to ask Claude questions about your search results. It needs an API
key from Anthropic; the **API Key…** button in the toolbar walks you
through it. The setup is fully optional — searching, opening files, and
exporting all work without it.

Step-by-step setup for the chat is in
[docs/INSTALL.md → section 8](docs/INSTALL.md#8--claude-api-key-optional-for-the-chat-panel).

## More

- **[docs/INSTALL.md](docs/INSTALL.md)** — the deeper install reference,
  including the Claude chat setup and a troubleshooting table.
- **[docs/USAGE.md](docs/USAGE.md)** — a short tour of the app once it's
  running.

## License

See repo for license terms.
