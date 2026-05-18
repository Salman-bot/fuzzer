#!/usr/bin/env python3
"""
Fetch a small corpus of public Arabic + English PDFs for testing `fuzzer`
against real-world documents.

Sources:
  * English — arXiv (well-known ML/CS papers; stable URLs)
  * Arabic  — Arabic Wikipedia PDF export API

Downloads land in ../test_pdfs/ relative to this script. Existing files are
skipped (so the script is idempotent and resumable). Failures are logged and
do not abort the run — we make best effort to hit the target count.

Run:
    python3 tools/fetch_test_pdfs.py                 # default target: 50
    python3 tools/fetch_test_pdfs.py --target 30
    python3 tools/fetch_test_pdfs.py --replace       # wipe test_pdfs/ first
    python3 tools/fetch_test_pdfs.py --replace -t 20 # fresh corpus of 20
"""
from __future__ import annotations

import argparse
import sys
import time
import urllib.parse
import urllib.request
from pathlib import Path

ARXIV_IDS = [
    # well-known ML / CS papers, stable URLs
    "1706.03762",  # Attention Is All You Need
    "1409.0473",   # Bahdanau et al — neural translation w/ attention
    "1412.6980",   # Adam optimizer
    "1502.03167",  # Batch Normalization
    "1512.03385",  # ResNet
    "1810.04805",  # BERT
    "2005.14165",  # GPT-3
    "2106.09685",  # LoRA
    "2203.02155",  # InstructGPT
    "2205.11916",  # Chain-of-Thought
    "2210.03629",  # ReAct
    "2303.08774",  # GPT-4 technical report
    "2304.03442",  # Generative Agents
    "2305.10403",  # PaLM 2
    "2307.09288",  # LLaMA 2
    "2310.06825",  # Mistral 7B
    "1409.3215",   # Seq2Seq
    "1503.02531",  # Knowledge Distillation
    "1611.01603",  # BiDAF
    "1607.06450",  # LayerNorm
    "1810.10683",  # T5
    "2001.08361",  # Scaling Laws
    "2107.03374",  # Codex / HumanEval
    "2112.10752",  # Latent Diffusion
    "2204.02311",  # PaLM
]

# Arabic Wikipedia article titles (well-known topics with long articles).
# We try each via the REST PDF export API; failures are skipped.
WIKI_AR_TITLES = [
    "علم_الفلك", "الرياضيات", "الفيزياء", "الكيمياء", "الأحياء",
    "اللغة_العربية", "مكة_المكرمة", "المدينة_المنورة", "الرياض", "القاهرة",
    "بيروت", "دمشق", "الإمبراطورية_العثمانية", "الحضارة_الإسلامية",
    "التاريخ", "الفلسفة", "الأدب_العربي", "الشعر_العربي", "العصر_العباسي",
    "المتنبي", "ابن_خلدون", "الجاحظ", "ابن_سينا", "الكندي",
    "الفارابي", "الخوارزمي", "ابن_بطوطة", "الجزيرة_العربية",
    "المملكة_العربية_السعودية", "علم_الحاسوب",
]


def _fetch(url: str, dest: Path, *, timeout: int = 45) -> tuple[bool, str]:
    """Download url → dest. Returns (ok, message). Skips if dest already exists."""
    if dest.exists() and dest.stat().st_size > 1024:
        return True, f"skip (cached, {dest.stat().st_size:,} B)"
    try:
        req = urllib.request.Request(
            url, headers={"User-Agent": "fuzzer-test-corpus/1.0 (testing only)"}
        )
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            ctype = resp.headers.get("Content-Type", "")
            if "pdf" not in ctype.lower():
                return False, f"not a pdf (Content-Type: {ctype})"
            data = resp.read()
        if len(data) < 1024:
            return False, f"too small ({len(data)} B)"
        dest.write_bytes(data)
        return True, f"ok ({len(data):,} B)"
    except Exception as exc:
        return False, f"error: {type(exc).__name__}: {exc}"


def _arxiv_url(arxiv_id: str) -> tuple[str, str]:
    return f"https://arxiv.org/pdf/{arxiv_id}", f"arxiv_{arxiv_id.replace('.', '_')}.pdf"


def _wiki_ar_url(title: str) -> tuple[str, str]:
    quoted = urllib.parse.quote(title, safe="")
    url = f"https://ar.wikipedia.org/api/rest_v1/page/pdf/{quoted}"
    # Filesystem-safe name: ASCII transliteration not needed; keep the encoded form.
    safe = quoted.replace("%", "_")
    return url, f"wiki_ar_{safe}.pdf"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("-t", "--target", type=int, default=50,
                        help="stop after this many successful downloads (default: 50)")
    parser.add_argument("--out", type=Path,
                        default=Path(__file__).resolve().parent.parent / "test_pdfs",
                        help="output directory")
    parser.add_argument("--replace", action="store_true",
                        help="wipe the output directory before fetching")
    args = parser.parse_args()
    if args.replace and args.out.exists():
        # Only remove PDFs we plausibly created — keep any other files the
        # user dropped in. Matches the prefixes our two fetchers produce.
        removed = 0
        for p in list(args.out.glob("arxiv_*.pdf")) + list(args.out.glob("wiki_ar_*.pdf")):
            p.unlink(missing_ok=True)
            removed += 1
        if removed:
            print(f"→ --replace: removed {removed} previously-fetched PDFs")
    args.out.mkdir(parents=True, exist_ok=True)

    # Interleave English + Arabic so a partial run still gives a mixed corpus.
    jobs: list[tuple[str, str, str]] = []  # (lang, url, filename)
    en = [(_arxiv_url(i), "en") for i in ARXIV_IDS]
    ar = [(_wiki_ar_url(t), "ar") for t in WIKI_AR_TITLES]
    n = max(len(en), len(ar))
    for i in range(n):
        if i < len(en):
            (u, f), lang = en[i]
            jobs.append((lang, u, f))
        if i < len(ar):
            (u, f), lang = ar[i]
            jobs.append((lang, u, f))

    ok = 0
    fail = 0
    skipped = 0
    by_lang = {"en": 0, "ar": 0}

    print(f"→ fetching up to {args.target} PDFs into {args.out}", flush=True)
    for lang, url, fname in jobs:
        if ok >= args.target:
            break
        dest = args.out / fname
        if dest.exists() and dest.stat().st_size > 1024:
            skipped += 1
            ok += 1
            by_lang[lang] += 1
            print(f"  [{ok:2d}/{args.target}] {lang} skip   {fname}", flush=True)
            continue
        good, msg = _fetch(url, dest)
        if good:
            ok += 1
            by_lang[lang] += 1
            print(f"  [{ok:2d}/{args.target}] {lang} {msg:<28s} {fname}", flush=True)
        else:
            fail += 1
            print(f"  [-- /{args.target}] {lang} FAIL  {fname}  ({msg})", flush=True)
        # be polite to upstreams
        time.sleep(0.3)

    print()
    print(f"✓ done: {ok} ok ({by_lang['en']} en, {by_lang['ar']} ar), "
          f"{fail} failed, {skipped} cached")
    return 0 if ok > 0 else 1


if __name__ == "__main__":
    sys.exit(main())
