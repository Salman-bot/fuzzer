#!/usr/bin/env python3
"""Build the fuzzer documentation.

Renders every docs/*.md to docs/_build/*.html with a shared template + sidebar,
and runs pdoc to generate docs/_build/api.html from the fuzzer script.

Usage:
    python3 docs/build.py        # full build
    python3 docs/build.py --api  # only the pdoc API reference
"""
from __future__ import annotations

import argparse
import shutil
import subprocess
import sys
from pathlib import Path

import markdown

ROOT = Path(__file__).resolve().parent.parent
DOC = ROOT / "docs"
OUT = DOC / "_build"

# Markdown extensions: tables, fenced code, code highlighting, table of contents.
MD_EXT = ["tables", "fenced_code", "codehilite", "toc", "sane_lists"]
MD_EXT_CFG = {"codehilite": {"guess_lang": False, "css_class": "highlight"}}

CSS = """
:root {
  --bg: #ffffff; --fg: #1c1e22; --muted: #5f6571; --border: #dcdfe3;
  --accent: #2563eb; --code-bg: #f5f7fa; --sidebar: #f4f5f7;
}
@media (prefers-color-scheme: dark) {
  :root {
    --bg: #1e1e1e; --fg: #d4d4d4; --muted: #9aa0a6; --border: #2d2d2d;
    --accent: #6ea8ff; --code-bg: #252526; --sidebar: #181818;
  }
}
* { box-sizing: border-box; }
body {
  margin: 0; font-family: -apple-system, BlinkMacSystemFont, "Helvetica Neue",
    Helvetica, Arial, sans-serif;
  background: var(--bg); color: var(--fg); line-height: 1.55;
}
.layout { display: flex; min-height: 100vh; }
.sidebar {
  width: 240px; background: var(--sidebar); border-right: 1px solid var(--border);
  padding: 24px 20px; position: sticky; top: 0; height: 100vh; overflow-y: auto;
}
.sidebar h2 { margin: 0 0 16px; font-size: 16px; color: var(--accent); }
.sidebar ul { list-style: none; padding: 0; margin: 0; }
.sidebar li { margin: 6px 0; }
.sidebar a { color: var(--fg); text-decoration: none; display: block; padding: 4px 8px;
  border-radius: 4px; font-size: 14px; }
.sidebar a:hover { background: var(--border); }
.sidebar a.active { background: var(--accent); color: white; }
.content {
  flex: 1; padding: 32px 48px; max-width: 920px; margin: 0 auto;
}
h1, h2, h3, h4 { color: var(--fg); }
h1 { border-bottom: 2px solid var(--border); padding-bottom: 8px; }
h2 { border-bottom: 1px solid var(--border); padding-bottom: 4px; margin-top: 32px; }
a { color: var(--accent); }
code {
  background: var(--code-bg); padding: 2px 6px; border-radius: 3px;
  font-family: "SF Mono", Menlo, Consolas, monospace; font-size: 0.9em;
}
pre {
  background: var(--code-bg); padding: 14px 16px; border-radius: 6px;
  overflow-x: auto; border: 1px solid var(--border);
}
pre code { background: transparent; padding: 0; }
table {
  border-collapse: collapse; margin: 16px 0; width: 100%;
}
th, td {
  border: 1px solid var(--border); padding: 8px 12px; text-align: left;
}
th { background: var(--code-bg); }
img { max-width: 100%; }
blockquote {
  border-left: 4px solid var(--accent); padding-left: 16px; margin: 16px 0;
  color: var(--muted);
}
.highlight .k, .highlight .kd, .highlight .kn { color: #c586c0; }
.highlight .s, .highlight .s1, .highlight .s2 { color: #ce9178; }
.highlight .c, .highlight .c1, .highlight .cm { color: #6a9955; font-style: italic; }
.highlight .nf, .highlight .nc { color: #4ec9b0; }
.highlight .mi, .highlight .mf { color: #b5cea8; }
.highlight .o { color: var(--fg); }
"""

# Order matters: this drives the sidebar order.
NAV = [
    ("INSTALL.html",      "Install"),
    ("USAGE.html",        "Usage"),
    ("INTERNALS.html",    "Internals"),
    ("DEVELOPMENT.html",  "Development"),
    ("api.html",          "API reference"),
]


def render_sidebar(active: str) -> str:
    items = []
    for href, label in NAV:
        cls = ' class="active"' if href == active else ""
        items.append(f'    <li><a href="{href}"{cls}>{label}</a></li>')
    return (
        '<nav class="sidebar">\n'
        '  <h2>fuzzer docs</h2>\n'
        '  <ul>\n' + "\n".join(items) + "\n  </ul>\n"
        '</nav>'
    )


TEMPLATE = """<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{title} — fuzzer docs</title>
<style>{css}</style>
</head>
<body>
<div class="layout">
{sidebar}
<main class="content">
{body}
</main>
</div>
</body>
</html>
"""


def md_to_html(md_path: Path, out_path: Path) -> None:
    text = md_path.read_text(encoding="utf-8")
    md = markdown.Markdown(extensions=MD_EXT, extension_configs=MD_EXT_CFG)
    body = md.convert(text)
    # Rewrite .md links → .html for in-doc cross-references
    body = body.replace('.md"', '.html"').replace(".md#", ".html#")
    # Title: first H1, or filename
    title = md_path.stem.replace("-", " ").title()
    for line in text.splitlines():
        if line.startswith("# "):
            title = line[2:].strip()
            break
    html = TEMPLATE.format(
        title=title,
        css=CSS,
        sidebar=render_sidebar(out_path.name),
        body=body,
    )
    out_path.write_text(html, encoding="utf-8")
    print(f"  ✓ {out_path.relative_to(ROOT)}")


def build_api(out_dir: Path) -> bool:
    """Run pdoc against a temporary .py copy of the fuzzer script.

    pdoc requires a .py extension to import via the standard machinery; the
    fuzzer script has none. Copy → run pdoc → wrap in the shared template
    → clean up.
    """
    print("→ generating API reference with pdoc")
    fuzzer_src = ROOT / "fuzzer"
    # pdoc resolves the module name from the path; a leading dot trips it,
    # so we use a plain name and clean it up unconditionally below.
    tmp_py = ROOT / "fuzzer_pdoc_tmp.py"
    shutil.copy2(fuzzer_src, tmp_py)
    try:
        return _extracted_from_build_api_15(out_dir, tmp_py)
    finally:
        tmp_py.unlink(missing_ok=True)


# TODO Rename this here and in `build_api`
def _extracted_from_build_api_15(out_dir, tmp_py):
    proc = subprocess.run(
        [sys.executable, "-m", "pdoc",
         "--no-show-source",
         "-o", str(out_dir / "_pdoc"),
         str(tmp_py)],
        cwd=str(ROOT),
        capture_output=True, text=True,
    )
    if proc.returncode != 0:
        print(f"  ✗ pdoc failed: {proc.stderr.strip()[:400]}")
        return False
    # pdoc writes <out>/_pdoc/<modname>.html plus a small index.html.
    # Pick the file matching the module name (largest, real content).
    pdoc_dir = out_dir / "_pdoc"
    pdoc_html = pdoc_dir / f"{tmp_py.stem}.html"
    if not pdoc_html.exists():
        print(f"  ✗ pdoc produced no {tmp_py.stem}.html")
        return False
    # Wrap pdoc's body in our shared template
    raw = pdoc_html.read_text(encoding="utf-8")
    # Extract just the <body> contents — pdoc emits a full document
    i = raw.find("<body")
    j = raw.rfind("</body>")
    body = raw[raw.find(">", i) + 1: j] if i != -1 and j != -1 else raw
    html = TEMPLATE.format(
        title="API reference",
        css=CSS + "\n.pdoc { font-size: 14px; }\n",
        sidebar=render_sidebar("api.html"),
        body=f'<h1>API reference</h1><div class="pdoc">{body}</div>',
    )
    (out_dir / "api.html").write_text(html, encoding="utf-8")
    shutil.rmtree(pdoc_dir, ignore_errors=True)
    print(f"  ✓ {(out_dir / 'api.html').relative_to(ROOT)}")
    return True


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--api", action="store_true",
                    help="only build the API reference")
    args = ap.parse_args()

    OUT.mkdir(parents=True, exist_ok=True)

    if not args.api:
        print("→ rendering markdown pages")
        for md_file in sorted(DOC.glob("*.md")):
            md_to_html(md_file, OUT / (md_file.stem + ".html"))

        # Copy assets (images) into _build
        for ext in (".png", ".jpg", ".svg", ".gif"):
            for asset in DOC.glob(f"*{ext}"):
                shutil.copy2(asset, OUT / asset.name)
                print(f"  ✓ {asset.name} (copied)")

    build_api(OUT)

    print(f"\nDocs ready at {OUT.relative_to(ROOT)}/index.html")
    return 0


if __name__ == "__main__":
    sys.exit(main())
