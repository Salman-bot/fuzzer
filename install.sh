#!/usr/bin/env bash
# install.sh — set up the fuzzer environment on a fresh Mac.
#
# Installs Python dependencies, builds the _ar_norm C extension, and
# verifies the toolchain. Designed to be safe to re-run.
#
# Usage:
#   ./install.sh                 # core deps + native build
#   ./install.sh --with-corpus   # also fetch ~50 test PDFs (≈140 MB)
#   ./install.sh --user          # pip install --user (useful when system Python is PEP 668-locked)
#   ./install.sh --help          # show this help

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

WITH_CORPUS=0
PIP_USER=0

for arg in "$@"; do
    case "$arg" in
        --with-corpus) WITH_CORPUS=1 ;;
        --user)        PIP_USER=1 ;;
        -h|--help)
            sed -n '2,11p' "$0" | sed 's/^# \{0,1\}//'
            exit 0
            ;;
        *)
            echo "✗ unknown flag: $arg (try --help)" >&2
            exit 2
            ;;
    esac
done

# ── pretty output ─────────────────────────────────────────────────────────────
if [[ -t 1 ]]; then
    BOLD=$'\033[1m'; DIM=$'\033[2m'; RED=$'\033[31m'
    GRN=$'\033[32m'; YEL=$'\033[33m'; RST=$'\033[0m'
else
    BOLD=""; DIM=""; RED=""; GRN=""; YEL=""; RST=""
fi
step() { echo "${BOLD}→${RST} $*"; }
ok()   { echo "${GRN}✓${RST} $*"; }
warn() { echo "${YEL}!${RST} $*" >&2; }
fail() { echo "${RED}✗${RST} $*" >&2; exit 1; }

# ── platform check ────────────────────────────────────────────────────────────
if [[ "$(uname -s)" != "Darwin" ]]; then
    fail "This installer is macOS-only. Detected $(uname -s)."
fi
ok "platform: macOS"

# ── toolchain checks ──────────────────────────────────────────────────────────
PYTHON="$(command -v python3 || command -v python || true)"
if [[ -z "$PYTHON" ]]; then
    fail "python3 not found. Install via Homebrew:
  brew install python@3.14
  or download from https://www.python.org/downloads/"
fi
PYVER="$("$PYTHON" -c 'import sys; print("%d.%d"%sys.version_info[:2])')"
ok "python: $PYTHON (v$PYVER)"

if ! "$PYTHON" -c 'import sys; assert sys.version_info >= (3, 9)' 2>/dev/null; then
    fail "Python 3.9+ required (found $PYVER)."
fi

# C compiler — needed for _ar_norm.
CC_BIN="$(command -v cc || command -v clang || true)"
if [[ -z "$CC_BIN" ]]; then
    warn "no C compiler found — _ar_norm will fall back to pyarabic / pure Python."
    warn "  install Xcode CLT:  xcode-select --install"
else
    ok "C compiler: $CC_BIN"
fi

# Python headers (Python.h) — required for the C extension build.
HAS_HEADERS=1
if ! "$PYTHON" -c 'import sysconfig, os; p=sysconfig.get_path("include"); assert os.path.exists(os.path.join(p, "Python.h"))' 2>/dev/null; then
    HAS_HEADERS=0
    warn "Python development headers (Python.h) not found — _ar_norm build will be skipped."
    warn "  Homebrew Python ships them; if missing, reinstall with: brew reinstall python@3.14"
fi

# ── pip availability ──────────────────────────────────────────────────────────
if ! "$PYTHON" -m pip --version >/dev/null 2>&1; then
    fail "pip not available for $PYTHON. Install it via:
  $PYTHON -m ensurepip --upgrade"
fi
ok "pip: $($PYTHON -m pip --version | awk '{print $1, $2}')"

# ── Python deps ───────────────────────────────────────────────────────────────
PIP_ARGS=(install --upgrade)
[[ $PIP_USER -eq 1 ]] && PIP_ARGS+=(--user)

# Auto-detect PEP 668 (externally-managed) Pythons via the marker file. On
# Homebrew Python the marker lives at <stdlib>/EXTERNALLY-MANAGED and pip
# refuses system installs without --break-system-packages. --user alone is
# NOT enough on pip 24.1+ — the marker still blocks. Detect and add both.
if "$PYTHON" -c "
import sysconfig, os, sys
m = os.path.join(sysconfig.get_path('stdlib'), 'EXTERNALLY-MANAGED')
sys.exit(0 if os.path.exists(m) else 1)
" 2>/dev/null; then
    warn "Python is externally-managed (PEP 668) — adding --user --break-system-packages."
    [[ $PIP_USER -eq 0 ]] && PIP_ARGS+=(--user)
    PIP_ARGS+=(--break-system-packages)
fi

CORE_DEPS=(
    pymupdf
    rapidfuzz
    pdfplumber
    anthropic
    openpyxl
    python-docx
    pyarabic
    tkinterdnd2
    arabic_reshaper
    "python-bidi"
)

step "installing Python dependencies (${#CORE_DEPS[@]} packages)…"
"$PYTHON" -m pip "${PIP_ARGS[@]}" "${CORE_DEPS[@]}"
ok "core dependencies installed"

# ── Build _ar_norm native extension ───────────────────────────────────────────
if [[ -n "$CC_BIN" && $HAS_HEADERS -eq 1 ]]; then
    step "building _ar_norm C extension…"
    if make build-native; then
        if "$PYTHON" -c "import sys; sys.path.insert(0, '$ROOT'); import _ar_norm; print(_ar_norm.normalize('أ'))" >/dev/null 2>&1; then
            ok "_ar_norm built and importable"
        else
            warn "_ar_norm built but import failed — pure-Python fallback will be used."
        fi
    else
        warn "native build failed — pure-Python fallback will be used."
    fi
else
    warn "skipping native build (compiler or Python headers missing) — pure-Python fallback will be used."
fi

# ── Skim PDF viewer (optional but recommended) ────────────────────────────────
# fuzzer prefers Skim over Preview for opening PDF results: Skim has reliable
# `go to page N` AppleScript, where Preview needs fragile UI scripting via
# Cmd+Opt+G. If Skim isn't installed we silently fall back to Preview.
if [[ -d "/Applications/Skim.app" ]]; then
    ok "Skim already installed (used as the PDF viewer)"
elif command -v brew >/dev/null 2>&1; then
    step "installing Skim (PDF viewer with robust page-nav AppleScript)…"
    if brew install --cask skim; then
        ok "Skim installed"
    else
        warn "Skim install failed — fuzzer will fall back to Preview."
    fi
else
    warn "Homebrew not found — skipping Skim install."
    warn "  fuzzer will fall back to Preview. To install Skim later:"
    warn "    /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
    warn "    brew install --cask skim"
fi

# ── Optional: test corpus ─────────────────────────────────────────────────────
if [[ $WITH_CORPUS -eq 1 ]]; then
    step "fetching test corpus (~140 MB, network)…"
    make test-corpus
    ok "test corpus ready under test_pdfs/"
fi

# ── Smoke test ────────────────────────────────────────────────────────────────
step "smoke test: importing core deps…"
"$PYTHON" - <<'PY'
import importlib, sys
# PDF support is "either or": at least one of fitz / pdfplumber must import.
# fuzzer prefers fitz (PyMuPDF — better Arabic) and falls back to pdfplumber.
pdf_backends = ["fitz", "pdfplumber"]
required = ["rapidfuzz", "openpyxl", "docx", "pyarabic"]
missing_pdf = []
for m in pdf_backends:
    try:
        importlib.import_module(m)
    except Exception as e:
        missing_pdf.append((m, str(e)))
missing_req = []
for m in required:
    try:
        importlib.import_module(m)
    except Exception as e:
        missing_req.append((m, str(e)))

# Fail only if required modules are missing OR no PDF backend works at all.
fatal = bool(missing_req) or len(missing_pdf) == len(pdf_backends)
if missing_req:
    print("  required imports failed:")
    for m, err in missing_req:
        print(f"    - {m}: {err}")
if len(missing_pdf) == len(pdf_backends):
    print()
    print("  WARNING: PDF support requires pdfplumber or pymupdf — pip install pymupdf")
    print("  Both backends failed to import:")
    for m, err in missing_pdf:
        print(f"    - {m}: {err}")
    print("  fuzzer will still launch, but .pdf files will be skipped.")
elif missing_pdf:
    # One backend works, the other doesn't — informational, not fatal.
    have = [m for m in pdf_backends if m not in {n for n, _ in missing_pdf}][0]
    print(f"  PDF support OK via {have} ({missing_pdf[0][0]} unavailable)")
if fatal:
    sys.exit(1)
ok_count = len(required) - len(missing_req) + len(pdf_backends) - len(missing_pdf)
print(f"  {ok_count}/{len(required) + len(pdf_backends)} core modules import cleanly")
PY
ok "smoke test passed"

# ── Next steps ────────────────────────────────────────────────────────────────
cat <<EOF

${BOLD}done.${RST}

next steps:
  ${DIM}# launch the GUI${RST}
  ./fuzzer

  ${DIM}# run the unit tests${RST}
  make test

  ${DIM}# (optional) fetch real PDFs for the corpus tests${RST}
  make test-corpus && make test
EOF
