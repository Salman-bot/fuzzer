#!/usr/bin/env bash
# install.sh — set up the fuzzer environment on a fresh device.
#
# Installs Python dependencies, builds the _ar_norm C extension, and
# verifies the toolchain. Designed to be safe to re-run.
#
# Usage:
#   ./install.sh                 # core deps + native build
#   ./install.sh --with-docs     # also install pdoc/markdown/pygments
#   ./install.sh --with-corpus   # also fetch ~50 test PDFs (≈140 MB)
#   ./install.sh --user          # pip install --user (useful when system Python is PEP 668-locked)
#   ./install.sh --help          # show this help

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

WITH_DOCS=0
WITH_CORPUS=0
PIP_USER=0

for arg in "$@"; do
    case "$arg" in
        --with-docs)   WITH_DOCS=1 ;;
        --with-corpus) WITH_CORPUS=1 ;;
        --user)        PIP_USER=1 ;;
        -h|--help)
            sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'
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

# ── platform + toolchain checks ───────────────────────────────────────────────
case "$(uname -s)" in
    Darwin) PLATFORM=macos ;;
    Linux)  PLATFORM=linux ;;
    *)      PLATFORM=other; warn "untested platform $(uname -s) — proceeding anyway" ;;
esac
ok "platform: $PLATFORM"

PYTHON="$(command -v python3 || command -v python || true)"
if [[ -z "$PYTHON" ]]; then
    echo
    fail "python3 not found.
  macOS:  brew install python  (or install from https://www.python.org/downloads/)
  Linux:  sudo apt install python3 python3-pip  (Debian/Ubuntu)
          sudo dnf install python3 python3-pip  (Fedora)"
fi
PYVER="$("$PYTHON" -c 'import sys; print("%d.%d"%sys.version_info[:2])')"
ok "python: $PYTHON (v$PYVER)"

if ! "$PYTHON" -c 'import sys; assert sys.version_info >= (3, 9)' 2>/dev/null; then
    fail "Python 3.9+ required (found $PYVER)."
fi

# C compiler — needed for _ar_norm. Try cc first (most portable).
CC_BIN="$(command -v cc || command -v clang || command -v gcc || true)"
if [[ -z "$CC_BIN" ]]; then
    echo
    warn "no C compiler found — _ar_norm will fall back to pyarabic / pure Python."
    case "$PLATFORM" in
        macos) warn "  install Xcode CLT:  xcode-select --install" ;;
        linux) warn "  Debian/Ubuntu:      sudo apt install build-essential python3-dev"
               warn "  Fedora:             sudo dnf install gcc python3-devel" ;;
    esac
else
    ok "C compiler: $CC_BIN"
fi

# Python headers (Python.h) — required for the C extension build.
HAS_HEADERS=1
if ! "$PYTHON" -c 'import sysconfig, os; p=sysconfig.get_path("include"); assert os.path.exists(os.path.join(p, "Python.h"))' 2>/dev/null; then
    HAS_HEADERS=0
    warn "Python development headers (Python.h) not found — _ar_norm build will be skipped."
    case "$PLATFORM" in
        linux) warn "  Debian/Ubuntu:      sudo apt install python3-dev"
               warn "  Fedora:             sudo dnf install python3-devel" ;;
    esac
fi

# ── pip availability ──────────────────────────────────────────────────────────
if ! "$PYTHON" -m pip --version >/dev/null 2>&1; then
    fail "pip not available for $PYTHON. Install it via:
  $PYTHON -m ensurepip --upgrade
  or your package manager (e.g. apt install python3-pip)."
fi
ok "pip: $($PYTHON -m pip --version | awk '{print $1, $2}')"

# ── Python deps ───────────────────────────────────────────────────────────────
PIP_ARGS=(install --upgrade)
[[ $PIP_USER -eq 1 ]] && PIP_ARGS+=(--user)

# Auto-detect PEP 668 (externally-managed) Pythons and add --user if not already.
if [[ $PIP_USER -eq 0 ]] && "$PYTHON" -m pip install --dry-run --quiet pip 2>&1 | grep -q "externally-managed"; then
    warn "Python is externally-managed (PEP 668) — switching to --user install."
    PIP_ARGS+=(--user)
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

DOC_DEPS=(pdoc markdown pygments)

step "installing Python dependencies (${#CORE_DEPS[@]} packages)…"
"$PYTHON" -m pip "${PIP_ARGS[@]}" "${CORE_DEPS[@]}"
ok "core dependencies installed"

if [[ $WITH_DOCS -eq 1 ]]; then
    step "installing doc dependencies (${#DOC_DEPS[@]} packages)…"
    "$PYTHON" -m pip "${PIP_ARGS[@]}" "${DOC_DEPS[@]}"
    ok "doc dependencies installed"
fi

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
mods = ["fitz", "rapidfuzz", "pdfplumber", "anthropic", "openpyxl", "docx", "pyarabic"]
missing = []
for m in mods:
    try:
        importlib.import_module(m)
    except Exception as e:
        missing.append((m, str(e)))
if missing:
    print("  some imports failed:")
    for m, err in missing:
        print(f"    - {m}: {err}")
    sys.exit(1)
print(f"  all {len(mods)} core modules import cleanly")
PY
ok "smoke test passed"

# ── Next steps ────────────────────────────────────────────────────────────────
cat <<EOF

${BOLD}done.${RST}

next steps:
  ${DIM}# launch the GUI${RST}
  ./fuzzer

  ${DIM}# one-shot CLI search${RST}
  ./fuzzer "climate" *.pdf

  ${DIM}# run the unit tests${RST}
  make test

  ${DIM}# (optional) AI mode — needs an Anthropic API key${RST}
  export ANTHROPIC_API_KEY=sk-ant-…

  ${DIM}# (optional) fetch real PDFs for the corpus tests${RST}
  make test-corpus && make test
EOF
