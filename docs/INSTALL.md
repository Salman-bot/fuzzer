# Installing `fuzzer` on a fresh Mac

`fuzzer` is the main project — a fuzzy file-content search GUI for plain
text, PDF, and DOCX (Arabic + English). `transcribe` is a helper script
that fuzzer can call to turn YouTube videos and audio files into PDFs
that fuzzer then searches.

This guide goes from a brand-new macOS install to a working `fuzzer`
GUI, with the optional bits at the end.

## 1. Homebrew

```sh
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

Follow the post-install hint to add `brew` to your `PATH` (the installer
prints the exact two lines for your shell — they look like
`eval "$(/opt/homebrew/bin/brew shellenv)"`).

## 2. System binaries

```sh
xcode-select --install                       # C compiler (for _ar_norm native build)
brew install python@3.14 ffmpeg yt-dlp
```

- `python@3.14` — interpreter for fuzzer + transcribe.
- `ffmpeg` — audio decoding for the transcribe helper.
- `yt-dlp` — only needed if you use transcribe on YouTube URLs.
- Xcode Command Line Tools — needed to build the `_ar_norm` C extension
  that speeds up Arabic normalization. Without it, fuzzer falls back to
  a pure-Python implementation (still works, just slower).

## 3. Clone and run install.sh

```sh
git clone https://github.com/Salman-bot/fuzzer.git ~/bin
cd ~/bin
./install.sh
```

`install.sh` does the rest:

- Installs every Python dependency fuzzer needs (`pymupdf`, `rapidfuzz`,
  `pdfplumber`, `anthropic`, `openpyxl`, `python-docx`, `pyarabic`,
  `tkinterdnd2`, `arabic_reshaper`, `python-bidi`).
- Auto-handles PEP 668 (externally-managed Python) by switching to
  `--user` installs.
- Builds the `_ar_norm` C extension.
- Smoke-tests every import.

To also get docs and the test corpus:

```sh
./install.sh --with-docs     # pdoc / markdown / pygments for `make docs`
./install.sh --with-corpus   # fetch ~50 real PDFs for TestRealCorpus
```

## 4. Put fuzzer on your PATH

```sh
echo 'export PATH="$HOME/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

## 5. Launch

```sh
fuzzer                       # GUI
```

## 6. Optional: AI mode

The GUI's grounded chat panel needs an Anthropic API key:

```sh
export ANTHROPIC_API_KEY=sk-ant-…
```

Get one at <https://console.anthropic.com/settings/keys>.

## 7. Optional: the `transcribe` helper

`transcribe` turns audio / video / YouTube URLs into searchable PDFs
that fuzzer can then index. One extra dep beyond what `install.sh`
already pulled in:

```sh
pip3 install --break-system-packages openai-whisper
```

Usage (output lands in the cwd by default):

```sh
transcribe URL_OR_FILE                       # → ./<title>.pdf
transcribe lecture.mp4 -o lecture.pdf
transcribe podcast.m4a --also txt,srt        # extra .txt/.srt sidecars
transcribe URL --model medium --lang ar      # high quality for non-English
transcribe URL --append ~/all.pdf            # also concat into a master PDF
```

Models: `tiny` is fastest but unreliable on non-English. Use `medium`
or `large` for Arabic / Japanese / etc. — first run downloads the model
(`tiny` ≈ 70 MB, `medium` ≈ 1.5 GB, `large` ≈ 3 GB) into
`~/.cache/whisper/`.

Fonts are auto-picked per script — Arial Unicode for Arabic, Hiragino
for CJK, Helvetica otherwise. All ship with macOS.

## Smoke test

```sh
fuzzer --help
transcribe --help            # only if you set up the helper
```
