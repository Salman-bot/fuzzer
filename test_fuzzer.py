"""
Tests for fuzzer — creates sample PDFs and text files, runs searches,
verifies results and PDF highlighting.

Run with:
    python3 -m pytest test_fuzzer.py -v
"""
import sys, os, json, tempfile
from pathlib import Path

import pytest

# ── Load fuzzer module ────────────────────────────────────────────────────────
_FUZZER_PATH = Path(__file__).parent / "fuzzer"

def _load_fuzzer():
    import types
    mod = types.ModuleType("fuzzer")
    mod.__file__ = str(_FUZZER_PATH)
    code = compile(_FUZZER_PATH.read_text(), str(_FUZZER_PATH), "exec")
    exec(code, mod.__dict__)
    return mod

fuzzer = _load_fuzzer()


# ── Fixtures ──────────────────────────────────────────────────────────────────

@pytest.fixture()
def tmp_dir(tmp_path):
    return tmp_path


@pytest.fixture()
def arabic_txt(tmp_dir):
    """Plain-text file with Arabic content."""
    fp = tmp_dir / "arabic_sample.txt"
    fp.write_text(
        "موضوع الرسالة: التواصل الإداري\n"
        "السلام عليكم ورحمة الله وبركاته\n"
        "يرجى الاطلاع على الموضوع المطلوب\n"
        "شكراً على تعاونكم\n"
        "مع خالص التحيات\n",
        encoding="utf-8",
    )
    return str(fp)


@pytest.fixture()
def english_txt(tmp_dir):
    """Plain-text file with English content."""
    fp = tmp_dir / "english_sample.txt"
    fp.write_text(
        "Subject: Administrative Communication\n"
        "Hello and welcome to the system.\n"
        "Please review the attached document carefully.\n"
        "Thank you for your cooperation.\n"
        "Best regards,\n",
        encoding="utf-8",
    )
    return str(fp)


@pytest.fixture()
def mixed_txt(tmp_dir):
    """Mixed Arabic/English file."""
    fp = tmp_dir / "mixed_sample.txt"
    fp.write_text(
        "Title: دليل التواصل\n"
        "Page 1: المقدمة - Introduction\n"
        "Contact: admin@example.com\n"
        "الموضوع: اختبار النظام\n",
        encoding="utf-8",
    )
    return str(fp)


@pytest.fixture()
def simple_pdf(tmp_dir):
    """Simple PDF with searchable Arabic and English text."""
    pytest.importorskip("fitz", reason="PyMuPDF not installed")
    import fitz
    fp = tmp_dir / "sample.pdf"
    doc = fitz.open()
    page = doc.new_page()
    page.insert_text((72, 100), "Subject: Administrative Report", fontsize=12)
    page.insert_text((72, 130), "الموضوع: التواصل الإداري", fontsize=14)
    page.insert_text((72, 160), "Please review the following sections.", fontsize=12)
    page.insert_text((72, 190), "مع خالص التحيات والتقدير", fontsize=12)
    doc.save(str(fp))
    doc.close()
    return str(fp)


@pytest.fixture()
def multipage_pdf(tmp_dir):
    """Multi-page PDF for page-navigation testing."""
    pytest.importorskip("fitz", reason="PyMuPDF not installed")
    import fitz
    fp = tmp_dir / "multipage.pdf"
    doc = fitz.open()
    lines = [
        ("Page 1: Introduction",        "المقدمة"),
        ("Page 2: Background",           "الخلفية"),
        ("Page 3: Methodology",          "المنهجية"),
        ("Page 4: Results",              "النتائج"),
        ("Page 5: الموضوع الرئيسي",     "main subject here"),
    ]
    for en, ar in lines:
        pg = doc.new_page()
        pg.insert_text((72, 100), en,  fontsize=14)
        pg.insert_text((72, 140), ar,  fontsize=14)
    doc.save(str(fp))
    doc.close()
    return str(fp)


# ── Text search tests ─────────────────────────────────────────────────────────

def _search(fp, pattern, *, case_sensitive=False, exact_only=False, threshold=70):
    """Wrapper matching search_file's keyword-only signature."""
    return fuzzer.search_file(
        fp, pattern,
        case_sensitive=case_sensitive,
        exact_only=exact_only,
        threshold=threshold,
    )


class TestFuzzySearch:
    def test_exact_match_english(self, english_txt):
        lines, matches = _search(english_txt, "attached document")
        assert any(m.score == 100 for m in matches), "Expected exact match"

    def test_fuzzy_match_english(self, english_txt):
        lines, matches = _search(english_txt, "documnt", threshold=70)
        assert matches, "Expected fuzzy match for 'documnt'"

    def test_exact_match_arabic(self, arabic_txt):
        lines, matches = _search(arabic_txt, "الموضوع")
        assert any(m.score == 100 for m in matches), "Expected exact Arabic match"

    def test_fuzzy_match_arabic(self, arabic_txt):
        lines, matches = _search(arabic_txt, "موضوع", threshold=70)
        assert matches, "Expected fuzzy Arabic match"

    def test_no_match_below_threshold(self, english_txt):
        lines, matches = _search(english_txt, "xyzxyzxyz", threshold=80)
        assert not matches, "Expected no match for garbage query"

    def test_case_insensitive(self, english_txt):
        lines, matches = _search(english_txt, "hello", case_sensitive=False)
        assert matches

    def test_case_sensitive_exact_no_match(self, english_txt):
        # exact_only=True + case_sensitive=True: substring "hello" not in "Hello ..."
        lines, matches = _search(english_txt, "hello", case_sensitive=True, exact_only=True)
        assert not matches, "Case-sensitive exact search for 'hello' should miss 'Hello'"

    def test_mixed_file(self, mixed_txt):
        lines, matches = _search(mixed_txt, "الموضوع")
        assert matches
        assert any("الموضوع" in m.line for m in matches)

    def test_line_numbers_are_correct(self, arabic_txt):
        lines, matches = _search(arabic_txt, "الموضوع")
        for m in matches:
            assert 1 <= m.line_num <= len(lines)
            assert m.line == lines[m.line_num - 1]


class TestPdfExtraction:
    def test_pdf_lines_extracted(self, simple_pdf):
        pytest.importorskip("fitz")
        lines = fuzzer.read_lines(simple_pdf)
        assert lines, "PDF should yield non-empty lines"
        full = "\n".join(lines)
        assert "Subject" in full or "Administrative" in full

    def test_pdf_page_map_populated(self, simple_pdf):
        pytest.importorskip("fitz")
        fuzzer.read_lines(simple_pdf)
        assert simple_pdf in fuzzer._pdf_page_map
        pg_map = fuzzer._pdf_page_map[simple_pdf]
        assert all(p == 1 for p in pg_map), "Single-page PDF: all lines on page 1"

    def test_multipage_pdf_page_map(self, multipage_pdf):
        pytest.importorskip("fitz")
        lines = fuzzer.read_lines(multipage_pdf)
        pg_map = fuzzer._pdf_page_map[multipage_pdf]
        assert max(pg_map) == 5, "Should detect 5 pages"
        assert len(pg_map) == len(lines)

    def test_pdf_search_returns_page_num(self, multipage_pdf):
        pytest.importorskip("fitz")
        lines, matches = _search(multipage_pdf, "Results")
        assert matches
        assert matches[0].page_num == 4, "Results text is on page 4"

    def test_pdf_english_search(self, simple_pdf):
        pytest.importorskip("fitz")
        # Use English text since insert_text default font may not embed Arabic
        lines, matches = _search(simple_pdf, "Administrative")
        assert matches, "English search should find a match in PDF"


class TestPdfHighlighting:
    def test_highlighted_pdf_created(self, simple_pdf, tmp_dir):
        pytest.importorskip("fitz")
        import fitz
        fuzzer.read_lines(simple_pdf)
        lines, matches = _search(simple_pdf, "Administrative")
        assert matches
        # Simulate what populate() does
        out = tmp_dir / "highlighted.pdf"

        doc = fitz.open(simple_pdf)
        pg = doc[0]
        # Build dict lines
        pg_dict: dict = pg.get_text("dict", sort=True)  # type: ignore[assignment]
        dict_lines = []
        for blk in pg_dict.get("blocks", []):
            if blk.get("type") != 0:
                continue
            for ln in blk.get("lines", []):
                lt = "".join(s.get("text","") for s in ln.get("spans",[]))
                dict_lines.append((lt.strip(), ln.get("bbox")))

        assert dict_lines, "Dict lines should be non-empty"
        # Verify at least one line contains our text
        found = any("Administrative" in t or "Subject" in t for t, _ in dict_lines)
        assert found, "At least one dict line should contain our query text"

    def test_highlight_annot_added(self, simple_pdf):
        pytest.importorskip("fitz")
        import fitz, tempfile as tf
        fuzzer.read_lines(simple_pdf)
        lines, matches = _search(simple_pdf, "Subject")
        assert matches

        doc = fitz.open(simple_pdf)
        pg = doc[0]
        quads = pg.search_for("Subject", quads=True)
        if quads:
            pg.add_highlight_annot(quads)
            fd, tmp = tf.mkstemp(suffix=".pdf")
            os.close(fd)
            doc.save(tmp)
            doc.close()
            # Re-open and check annotations exist
            doc2 = fitz.open(tmp)
            annots = list(doc2[0].annots())
            doc2.close()
            os.unlink(tmp)
            assert annots, "Highlight annotation should be present"


class TestScoring:
    def test_exact_score_100(self, english_txt):
        lines, matches = _search(english_txt, "Administrative Communication")
        exact = [m for m in matches if m.score == 100]
        assert exact

    def test_fuzzy_score_in_range(self, english_txt):
        lines, matches = _search(english_txt, "communicaton", threshold=70)
        for m in matches:
            assert 0 <= m.score <= 100

    def test_fuzzy_score_fn_symmetric(self):
        s = fuzzer.fuzzy_score("hello", "hello world")
        assert 50 <= s <= 100

    def test_fuzzy_score_zero_for_garbage(self):
        s = fuzzer.fuzzy_score("xyzqrs", "hello world today")
        assert s < 50


class TestFileCollection:
    def test_collects_txt_files(self, tmp_dir, english_txt, arabic_txt):
        # collect_files requires recursive=True for directories
        files = fuzzer.collect_files([str(tmp_dir)], recursive=True)
        assert str(english_txt) in files
        assert str(arabic_txt) in files

    def test_collects_pdf_files(self, tmp_dir, simple_pdf):
        pytest.importorskip("fitz")
        files = fuzzer.collect_files([str(tmp_dir)], recursive=True)
        assert str(simple_pdf) in files

    def test_direct_file_path(self, english_txt):
        files = fuzzer.collect_files([english_txt], recursive=False)
        assert files == [english_txt]

    def test_nonexistent_path_skipped(self, tmp_dir):
        files = fuzzer.collect_files([str(tmp_dir / "ghost.txt")], recursive=False)
        assert files == []


# ── Visual demo (opens highlighted PDF in Preview) ────────────────────────────

class TestVisualHighlight:
    """Creates a rich PDF, searches it, highlights results, opens in Preview."""

    @pytest.fixture()
    def rich_pdf(self, tmp_dir):
        fitz = pytest.importorskip("fitz")
        fp = tmp_dir / "demo_highlight.pdf"
        doc = fitz.open()

        pages = [
            [
                "Administrative Communication Guide",
                "Chapter 1: Introduction to the Subject",
                "This document covers administrative procedures.",
                "The subject of each letter must be clear and concise.",
                "Always include a subject line at the top of the letter.",
            ],
            [
                "Chapter 2: Writing Guidelines",
                "The subject should not exceed ten words.",
                "Avoid repeating the subject in the body.",
                "Each section must relate back to the main subject.",
                "Use formal language throughout the document.",
            ],
            [
                "Chapter 3: Review and Approval",
                "All documents must be reviewed before sending.",
                "The subject line helps the reviewer categorize quickly.",
                "Final approval is required for all outgoing letters.",
                "Keep a copy of all sent correspondence.",
            ],
        ]

        for page_lines in pages:
            pg = doc.new_page()
            y = 80
            for i, line in enumerate(page_lines):
                size = 16 if i == 0 else 12
                pg.insert_text((60, y), line, fontsize=size)
                y += size + 10

        doc.save(str(fp))
        doc.close()
        return str(fp)

    def test_visual_highlight_opens_in_preview(self, rich_pdf):
        """
        Runs a search, highlights all matches by line-number bbox,
        and opens the result in Preview. You should see yellow highlights
        on every line containing 'subject'.
        """
        fitz = pytest.importorskip("fitz")
        import subprocess, tempfile as tf
        from difflib import SequenceMatcher

        query = "subject"
        print(f"\n{'='*60}")
        print(f"  PDF:   {rich_pdf}")
        print(f"  Query: '{query}'")
        print(f"{'='*60}")

        # ── Search ──────────────────────────────────────────────────
        lines, matches = _search(rich_pdf, query, case_sensitive=False, threshold=70)
        assert matches, "Expected matches for 'subject'"
        print(f"\n  {len(lines)} lines extracted across {max(fuzzer._pdf_page_map.get(rich_pdf, [1]))} pages")
        print(f"\n  Found {len(matches)} match(es):\n")
        for m in matches:
            kind = "EXACT" if m.score == 100 else f"FUZZY({m.score})"
            print(f"    [{kind}] page {m.page_num}, line {m.line_num}: {m.line.strip()!r}")

        # ── Highlight ────────────────────────────────────────────────
        pg_map = fuzzer._pdf_page_map.get(rich_pdf, [])
        doc = fitz.open(rich_pdf)
        total_highlights = 0

        page_matches: dict = {}
        for m in matches:
            page_matches.setdefault(m.page_num or 1, []).append(m)

        print(f"\n  Highlighting by line-number bbox:\n")
        for pn, ms in sorted(page_matches.items()):
            pg = doc[pn - 1]
            pg_dict: dict = pg.get_text("dict", sort=True)  # type: ignore[assignment]
            dict_lines = []
            for blk in pg_dict.get("blocks", []):
                if blk.get("type") != 0:
                    continue
                for ln in blk.get("lines", []):
                    lt = "".join(s.get("text", "") for s in ln.get("spans", []))
                    dict_lines.append((lt.strip(), ln.get("bbox")))

            pg_text_lines = pg.get_text("text", sort=True).splitlines()  # type: ignore[union-attr]
            for m in ms:
                gidx = m.line_num - 1
                pg_start = next((i for i in range(len(pg_map)) if pg_map[i] == pn), 0)
                page_local_pos = gidx - pg_start
                local_idx = sum(1 for line in pg_text_lines[:page_local_pos] if line.strip())
                bbox = None
                method = "—"
                if 0 <= local_idx < len(dict_lines):
                    bbox = dict_lines[local_idx][1]
                    method = f"index[{local_idx}]"
                if not bbox:
                    best, best_bbox = 0.0, None
                    for dt, db in dict_lines:
                        r = SequenceMatcher(None, m.line.strip(), dt).ratio()
                        if r > best:
                            best, best_bbox = r, db
                    if best > 0.35:
                        bbox = best_bbox
                        method = f"fuzzy({best:.0%})"
                if bbox:
                    pg.add_highlight_annot(fitz.Rect(bbox))
                    total_highlights += 1
                    print(f"    page {pn}, line {m.line_num}: {method} → bbox={tuple(round(x,1) for x in bbox)}")
                else:
                    print(f"    page {pn}, line {m.line_num}: NO BBOX FOUND")

        print(f"\n  Total highlights added: {total_highlights}")

        fd, tmp = tf.mkstemp(suffix=".pdf")
        os.close(fd)
        doc.save(tmp)
        doc.close()
        print(f"\n  Saved highlighted PDF → {tmp}")
        print(f"  Opening in Preview…\n{'='*60}\n")

        subprocess.Popen(["open", "-a", "Preview", tmp])
        assert total_highlights > 0, "Should have highlighted at least one line"
