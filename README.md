# fuzzer

A friendly search tool for your files. Type a word — even if you misspell
it or it's in Arabic — and `fuzzer` finds it inside your text files, PDFs,
and Word documents. Mac-only.

```sh
# one-time setup
./install.sh

# launch the app
fuzzer
```

## Docs

Everything you need is in two short pages:

- **[How to install](docs/INSTALL.md)** — fresh Mac, step by step.
- **[How to use it](docs/USAGE.md)** — open the app, search, open results.

## What it does

- Searches inside `.txt`, `.md`, `.pdf`, `.docx`, and many more.
- Fuzzy matching — finds your word even with typos or different spellings.
- Arabic-aware — ignores diacritics and handles letter variants.
- Double-click a result to jump straight to the matching page or line.
- Dark mode, drag-and-drop, history, export to Excel / CSV / JSON.
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

Behind the scenes, fuzzer keeps a small cache of files it has already
read — so the second search on the same folder is near-instant.

## Speed at a glance

Measured on 30 academic PDFs (≈ 127 MB, 58 000 lines of text):

| What you do                        | How long it takes                  |
| ---------------------------------- | ---------------------------------- |
| First search of a fresh folder     | ~ 0.5 s per PDF (reads + caches)   |
| Every search after that            | ~ 0.1 s for all 30 PDFs together   |
| Re-opening files from cache        | basically instant (1 600+ files/s) |
| Arabic text normalization speed-up | **12 ×** faster than pure Python   |

So the first scan of a new folder is the slow part — after that, every
search is sub-second even on a hundred-megabyte folder.

## The Claude chat panel — tokens & cost

The right side of the window has a chat box. You can ask Claude questions
about your search results, paste in passages, or just chat. Each turn
shows a small usage line like:

```text
this turn: in 1,250  ·  out 380  tok      session (5 turns): in 6,800  ·  out 1,900  tok
```

That's how many **tokens** (roughly: word-pieces) you sent and got back.

| Model          | Best for                                    | Cost (relative) |
| -------------- | ------------------------------------------- | --------------- |
| **Haiku 4.5**  | Quick lookups, summaries, simple Q&A        | Cheapest        |
| **Sonnet 4.6** | The default — strong all-rounder            | Mid             |
| **Opus 4.7**   | Hard reasoning, long analysis, deep reviews | Most expensive  |

A typical "ask about my results" turn is a few hundred to a few thousand
tokens. Live per-million-token prices are on Anthropic's
[pricing page](https://www.anthropic.com/pricing). The bar at the top of
the chat panel also shows your remaining rate-limit budget so you can
keep an eye on it.

> Tip: fuzzer caches your conversation context, so follow-up questions in
> the same chat are billed at a much lower "cache read" rate — keep one
> long chat going instead of restarting.

## Who is this for?

Anywhere you have a pile of documents and need to *find things inside them*:

- **Research & academia** — search across hundreds of papers, theses, and
  conference proceedings without opening each one. Arabic + English in
  the same query is fine.
- **Law & compliance** — full-text search through contracts, case files,
  and scanned (OCR'd) PDFs. Yellow highlights on the matched page make
  citation easy.
- **Journalism & investigations** — comb through leaked documents,
  transcripts, and reports. Pair with the `transcribe` helper to turn
  interview recordings into searchable PDFs.
- **Data analysis on unstructured text** — export hits to `.xlsx` /
  `.csv` / `.json` and pull them into Excel, pandas, or Power BI. Every
  row carries the file path, page number, line, and score so you can
  pivot, group, and cross-reference.
- **Archival & translation work** — fuzzy matching shrugs off typos, OCR
  errors, and spelling variants. For Arabic this means hamza, alef, and
  yaa variants all match without thinking about it.
- **Personal knowledge base** — point it at your `~/Documents` folder
  and treat it as a desktop Google for your own files.

## Companion tool: `transcribe`

Turns YouTube links, audio, or video into searchable PDFs that `fuzzer`
can then search. Setup is at the bottom of
[docs/INSTALL.md](docs/INSTALL.md#6-optional-the-transcribe-helper).

## License

See repo for license terms.
