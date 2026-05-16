# Installing `fuzzer`

Mac-only. Open **Terminal** (`⌘`+`Space` → `Terminal` → Enter) and run each
block below in order.

---

## 1 — Xcode Command Line Tools

```sh
xcode-select --install
```

Click **Install** in the dialog. Skip if already installed.

---

## 2 — Homebrew

```sh
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

When it finishes, run the two `eval` lines it prints (they add `brew` to
your shell).

---

## 3 — System packages

```sh
brew install git python@3.14 ffmpeg yt-dlp
```

---

## 4 — Clone the repo

```sh
git clone https://github.com/Salman-bot/fuzzer.git ~/bin
cd ~/bin
```

---

## 5 — Run the installer

```sh
./install.sh
```

This installs the Python libraries, builds the Arabic-normalize C
extension, and installs **Skim** (used for jump-to-page).

Add `--with-corpus` to also fetch ~50 sample PDFs.

---

## 6 — Put `fuzzer` on PATH

```sh
echo 'export PATH="$HOME/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

---

## 7 — Launch

```sh
fuzzer
```

The GUI opens. See [USAGE.md](USAGE.md) for the tour.

---

## 8 — Transcribe (audio / video / YouTube → searchable PDF)

`transcribe` runs from the CLI or directly from the fuzzer GUI (the
**Transcribe…** button in the action row).

Install the one extra dependency:

```sh
pip3 install --break-system-packages openai-whisper
```

### From the GUI

Click **Transcribe…**, pick a `.docx` of YouTube links, then pick an
output folder. fuzzer runs `transcribe` in batch mode with
`--model large --cookies chrome --also txt`, streams progress into the
activity log, and drops one PDF per link plus a `_combined.pdf` master
into the chosen folder. Click the status bar afterwards to reveal the
folder in Finder.

### From the CLI

```sh
transcribe https://www.youtube.com/watch?v=...
transcribe lecture.mp4 -o lecture.pdf
transcribe podcast.m4a --also txt,srt
transcribe URL --model medium --lang ar
transcribe links.docx -o transcripts/
```

First run of `--model medium` / `large` downloads the model (~1.5 GB /
~3 GB). After that it works offline.

---

## Sanity check

```sh
fuzzer --help
transcribe --help
```

---

## Troubleshooting

| Symptom                              | Fix                                                |
| ------------------------------------ | -------------------------------------------------- |
| `command not found: brew`            | Re-run the two `eval` lines from step 2.           |
| `command not found: fuzzer`          | `source ~/.zshrc` or open a new Terminal window.   |
| Installer says "PDF backend missing" | `pip3 install --break-system-packages pymupdf`.    |
| Transcribe button greyed out         | Whisper isn't installed — re-run step 8.           |
| Anything else                        | Re-run `./install.sh` — safe to run again.         |
