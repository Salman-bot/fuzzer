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

## 3 — System packages (includes git)

```sh
brew install git python@3.14 ffmpeg yt-dlp
```

`git` is the tool that downloads source code from GitHub. Check it works:

```sh
git --version
```

You should see something like `git version 2.45.0`.

---

## 4 — Pull the code from GitHub

The repo is public — no GitHub account or login is required.

```sh
git clone https://github.com/Salman-bot/fuzzer.git ~/bin
cd ~/bin
```

`git clone` downloads the code into `~/bin` (your home folder, then `bin`).
`cd ~/bin` moves your Terminal into that folder so the next commands run
in the right place.

To **update** later (get the newest version of fuzzer):

```sh
cd ~/bin
git pull
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

## 7b — Arabic search engine (native C extension)

Look at the bottom-left of the fuzzer window. The status bar shows
which Arabic engine is live:

```text
fuzzy: rapidfuzz   arabic: C ext (_ar_norm)   pdf: PyMuPDF
```

There are **three tiers**, in order of preference:

| Tier | Status bar label   | Speed   |
| ---- | ------------------ | ------- |
| 1    | `C ext (_ar_norm)` | fastest |
| 2    | `pyarabic`         | medium  |
| 3    | `regex fallback`   | slowest |

**Tier 1 — `C ext (_ar_norm)` is the best and what you want.** Native
C, roughly 10× faster than pyarabic, and frees the GIL on big batches.
Built from `native/ar_normalize.c` against the same Python `fuzzer`
launches with.

**Tier 2 — `pyarabic`.** Pure-Python tokenizer. Correct results, just
slower on large corpora. Auto-installed via pip, no compilation
needed — this is the fallback if the C extension can't build.

**Tier 3 — `regex fallback`.** Last-resort. Handles diacritics and
basic alef/yeh normalization but misses some hamza edge cases.

`./install.sh` from step 5 already tries to build the C extension —
on a clean Brew Python install it just works. If you see `arabic:
pyarabic` or `regex fallback` in the status bar, force a rebuild:

```sh
cd ~/bin && PY=$(awk 'NR==1{sub(/^#!/,""); print}' fuzzer) && "$PY" -m pip install --break-system-packages setuptools && make clean-native && make PYTHON="$PY" build-native && "$PY" -c "import sys; sys.path.insert(0,'.'); import _ar_norm; print(_ar_norm.normalize('أنا'))"
```

That one line (no shell comments — paste as-is): finds the exact
Python `fuzzer` launches with, installs `setuptools` if missing,
cleans any stale `.so`, rebuilds the C extension, and tests it. If
the final command prints **`انا`** the build worked — quit and
relaunch fuzzer, and the status bar will read `arabic: C ext
(_ar_norm)`.

If the build fails, the full compiler output is at
`~/bin/.ar_norm-build.log`. The three usual suspects:

- **`Python.h: No such file or directory`** — fuzzer's shebang points
  to a Python that doesn't ship headers. Check `head -1 ~/bin/fuzzer`.
  If it's `/usr/bin/python3` or anything under `/Library/Developer/
  CommandLineTools/`, re-run `./install.sh` — it now prefers Brew
  Python.
- **`command 'cc' failed`** — Xcode Command Line Tools missing. Run
  `xcode-select --install`, click **Install** in the popup, wait
  5–10 min for it to finish, then retry.
- **`ModuleNotFoundError: No module named 'setuptools'`** — the
  one-liner above handles this; if you ran it some other way, just
  `pip install --break-system-packages setuptools` first.

You don't *need* the C extension to use fuzzer — tier 2 (`pyarabic`)
gives correct results out of the box. But if you search large Arabic
corpora (50+ PDFs, hundreds of MB), tier 1 is noticeably faster and
worth the one-time setup.

---

## 8 — Claude API key (optional, for the chat panel)

The right side of the fuzzer window has a chat box that asks Claude
questions about your files. Searching, opening PDFs, and exporting work
**without** a key — you only need one for the chat panel.

### 8a. Create an Anthropic account

1. Open <https://console.anthropic.com> in your browser.
2. Click **Sign up** and create an account (email or Google).
3. Verify your email if asked.

### 8b. Add money (buy credits)

Anthropic uses **prepaid credit** — you put money in once and the chat
panel draws from it as you use it.

1. In the console, open **Settings → Plans & Billing** (or just
   **Billing**).
2. Click **Add payment method** and enter a card.
3. Click **Add credits** and choose an amount. The minimum is **$5**.
   Start with **$5** — it lasts a long time for normal use (see costs
   below).
4. Optional: turn on **Auto-reload** so credits top up automatically
   when they run low.

### 8c. Create an API key

1. In the console, open **Settings → API keys**.
2. Click **Create key**, give it a name like `fuzzer`, click **Create**.
3. Copy the key. It starts with `sk-ant-…`. **Copy it now** — the
   console won't show it again. (If you lose it, just create a new one.)

### 8d. Give the key to fuzzer

Two ways — pick one:

**Easy way (recommended):** in the fuzzer window, click the
**API Key…** button in the action row, paste the key, click **Save**.
fuzzer remembers it for next time.

**Terminal way:** add it to your shell so every program on your Mac can
see it:

```sh
echo 'export ANTHROPIC_API_KEY="sk-ant-..."' >> ~/.zshrc
source ~/.zshrc
```

(Replace `sk-ant-...` with your real key.)

### 8e. How much will it cost?

Live prices are on Anthropic's
[pricing page](https://www.anthropic.com/pricing) — they change
occasionally, so check there for exact numbers. Here is a rough guide
based on today's prices for the **default model** (Sonnet 4.6):

| What you do                                | Rough cost            |
| ------------------------------------------ | --------------------- |
| One chat turn (ask about ~10 search hits)  | **~1–2 ¢**            |
| Follow-up question in same chat (cached)   | a fraction of a cent  |
| 50 chat turns in a day                     | **~$0.50 – $1**       |
| A month of casual use (200–500 turns)      | **~$2 – $5**          |

So a one-time **$5 credit purchase typically lasts weeks to months** for
normal "search-then-ask-Claude" workflows. The big numbers come from
running many long Opus turns back-to-back — see the model picker in the
chat header to switch:

| Model          | When to use it                         | Relative cost |
| -------------- | -------------------------------------- | ------------- |
| **Haiku 4.5**  | Quick lookups, simple Q&A              | ~5× cheaper   |
| **Sonnet 4.6** | Default — strong all-rounder           | baseline      |
| **Opus 4.7**   | Hard reasoning, long analysis          | ~5× pricier   |

Every chat turn prints a usage line at the bottom of the chat panel:

```text
this turn: in 1,250  ·  out 380  tok      session (5 turns): in 6,800  ·  out 1,900  tok
```

Multiply those numbers by the per-million-token price on the pricing
page to see exactly what you spent. The console also shows a running
balance under **Billing → Usage**.

> Tip: keep one long chat going instead of restarting — fuzzer caches
> context, so follow-ups in the same chat are billed at the much
> cheaper "cache read" rate.

---

## 9 — Transcribe (audio / video / YouTube → searchable PDF)

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

### Which `--model` to pick

Next to the GUI **Transcribe…** button is a model dropdown; the CLI takes
the same names via `--model`. Bigger = more accurate, slower, larger
one-time download.

| Model    | Size    | Speed        | Best for                                  |
| -------- | ------- | ------------ | ----------------------------------------- |
| `tiny`   | ~75 MB  | fastest      | quick previews, English only really       |
| `base`   | ~150 MB | very fast    | rough drafts                              |
| `small`  | ~500 MB | fast         | decent quality, most common dialects      |
| `medium` | ~1.5 GB | slower       | good for non-English / accented speech    |
| `large`  | ~3 GB   | slowest      | highest quality — **default**             |
| `turbo`  | ~1.5 GB | ~5× of large | nearly large quality, much faster         |

> **First run with a model is slow** — Whisper downloads the model file
> the first time you use it. Every later run uses the cached copy and
> starts instantly.

---

## Sanity check

```sh
fuzzer --help
transcribe --help
```

---

## Troubleshooting

| Symptom                                       | Fix                                                                                                              |
| --------------------------------------------- | ---------------------------------------------------------------------------------------------------------------- |
| `command not found: brew`                     | Re-run the two `eval` lines from step 2.                                                                         |
| `command not found: git`                      | Re-run step 3 — `brew install git`.                                                                              |
| `command not found: fuzzer`                   | `source ~/.zshrc` or open a new Terminal window.                                                                 |
| Installer says "PDF backend missing"          | `pip3 install --break-system-packages pymupdf`.                                                                  |
| Status bar shows `arabic: regex fallback`     | C extension didn't build — see **Engine fallbacks** below.                                                       |
| Status bar shows `fuzzy: builtin Levenshtein` | `rapidfuzz` isn't installed for the Python `fuzzer` is using. Run `./install.sh` again.                          |
| Activity log floods `DOCX support requires…`  | Same root cause as Arabic fallback — wrong Python. See **Engine fallbacks** below.                               |
| Chat panel says "No API key"                  | Click **API Key…**, paste your key (step 8d).                                                                    |
| Chat panel says "Insufficient credit"         | Add credits at console.anthropic.com → Billing.                                                                  |
| Transcribe button greyed out                  | Whisper isn't installed — re-run step 9.                                                                         |
| Anything else                                 | Re-run `./install.sh` — safe to run again.                                                                       |

### Engine fallbacks (Arabic / DOCX / fuzzy still showing fallback after install)

The status bar at the bottom of the fuzzer window tells you which engine is
live. After a clean install it should read:

```text
fuzzy: rapidfuzz   arabic: C ext (_ar_norm)   pdf: PyMuPDF
```

If `arabic:` says `regex fallback` *and/or* the activity log floods with
`DOCX support requires python-docx`, fuzzer is launching against a
different Python than the one `install.sh` put the packages into. This
mostly happens when fuzzer is launched from the **Dock/Spotlight** (GUI
launches get a stripped PATH that resolves to Apple's system Python,
which has no packages).

`install.sh` pins fuzzer's shebang to the absolute path of the Python it
installed into — re-running fixes silent fallbacks. Check what fuzzer is
using:

```sh
head -1 ~/bin/fuzzer                          # the python fuzzer launches
$(head -1 ~/bin/fuzzer | sed 's|^#!||') \
    -c 'import docx, _ar_norm, rapidfuzz; print("OK")'
```

If the second command errors, re-run `./install.sh` from `~/bin`. The
smoke test prints `arabic engine: …` at the end so silent fallbacks
become loud.

If the C extension specifically refuses to build, the cause is almost
always missing Xcode Command Line Tools:

```sh
xcode-select --install
cd ~/bin && make build-native
```
