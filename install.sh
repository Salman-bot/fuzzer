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
# Prefer Brew Python: Apple's CLT Python is too old and ships no headers.
# Probe @X/bin/python3 too -- the /opt/homebrew/bin symlink may be missing.
find_brew_python() {
    local p
    for p in /opt/homebrew/bin/python3 /usr/local/bin/python3; do
        [[ -x "$p" ]] && { echo "$p"; return 0; }
    done
    # Sort numerically descending on the python@X suffix so 3.14 wins over 3.13.
    while IFS= read -r p; do
        [[ -x "$p" ]] && { echo "$p"; return 0; }
    done < <(find /opt/homebrew/opt /usr/local/opt -maxdepth 3 \
                  -name python3 -path '*python@*/bin/python3' 2>/dev/null \
             | sort -t@ -k2 -V -r)
    return 1
}

PYTHON="$(find_brew_python || true)"

# If no Brew Python and Homebrew itself is available, install python@3.14
# rather than falling back to Apple's CLT Python (which would break the GUI
# and the native build).
if [[ -z "$PYTHON" ]] && command -v brew >/dev/null 2>&1; then
    step "no Brew Python found — installing python@3.14 via Homebrew…"
    if brew install python@3.14; then
        ok "python@3.14 installed"
        PYTHON="$(find_brew_python || true)"
    else
        warn "brew install python@3.14 failed — falling back to system Python."
    fi
fi

# Last resort: whatever's on PATH (usually Apple's CLT Python).
[[ -z "$PYTHON" ]] && PYTHON="$(command -v python3 || command -v python || true)"
if [[ -z "$PYTHON" ]]; then
    fail "python3 not found and Brew install didn't work. Install manually:
  brew install python@3.14
  or download from https://www.python.org/downloads/"
fi
PYVER="$("$PYTHON" -c 'import sys; print("%d.%d"%sys.version_info[:2])')"

# Brew Python 3.13+ ships without _tkinter; auto-install python-tk@$PYVER.
if ! "$PYTHON" -c 'import tkinter' 2>/dev/null; then
    if command -v brew >/dev/null 2>&1 && [[ "$PYTHON" == /opt/homebrew/* || "$PYTHON" == /usr/local/* ]]; then
        step "Brew Python missing Tk bindings - installing python-tk@${PYVER}..."
        if brew install "python-tk@${PYVER}"; then
            ok "python-tk@${PYVER} installed"
        else
            warn "brew install python-tk@${PYVER} failed - GUI will fail to launch."
            warn "  try manually: brew install python-tk@${PYVER}"
        fi
    else
        warn "tkinter not importable for $PYTHON - GUI will fail to launch."
    fi
fi
ok "python: $PYTHON (v$PYVER)"

if ! "$PYTHON" -c 'import sys; assert sys.version_info >= (3, 9)' 2>/dev/null; then
    fail "Python 3.9+ required (found $PYVER)."
fi

# Apple's CLT Python is technically usable for the headless parts but the GUI
# and native build both break against it. Warn loudly with the exact fix.
if [[ "$PYTHON" == /usr/bin/python3 ]] || \
   [[ "$PYTHON" == /Library/Developer/CommandLineTools/* ]]; then
    warn "Using Apple's Xcode CLT Python — its Tk is too old for the tabbed UI"
    warn "and it ships no Python.h (so _ar_norm can't build). Recommended:"
    warn "  brew install python@3.14   # then re-run ./install.sh"
fi

# Xcode Command Line Tools — needed for the C compiler that builds _ar_norm.
# The install dialog is async (user clicks Install, download takes ~5-10 min)
# so we kick it off and let the user re-run install.sh after it finishes.
if ! xcode-select -p >/dev/null 2>&1; then
    step "Xcode Command Line Tools not installed — triggering install…"
    xcode-select --install 2>/dev/null || true
    warn "A macOS popup should have appeared. Click 'Install' and wait for it"
    warn "  to finish (~5-10 min), then re-run ./install.sh."
    fail "aborting until Xcode CLT install completes."
fi

# C compiler — needed for _ar_norm. With CLT installed this should be present.
CC_BIN="$(command -v cc || command -v clang || true)"
if [[ -z "$CC_BIN" ]]; then
    warn "no C compiler on PATH — _ar_norm will fall back to pyarabic / pure Python."
    warn "  try: sudo xcode-select --reset && xcode-select --install"
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

# PEP 668: Brew Python needs --user + --break-system-packages; detect via marker.
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
    setuptools
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
    # Force clean rebuild — stale .so might pass mtime check but ABI-fail import.
    make clean-native >/dev/null 2>&1 || true
    # Pin PYTHON for make; output to log so failures aren't silent.
    BUILD_LOG="$ROOT/.ar_norm-build.log"
    if make PYTHON="$PYTHON" build-native >"$BUILD_LOG" 2>&1; then
        if "$PYTHON" -c "import sys; sys.path.insert(0, '$ROOT'); import _ar_norm; print(_ar_norm.normalize('أ'))" >/dev/null 2>&1; then
            ok "_ar_norm built and importable"
            rm -f "$BUILD_LOG"
        else
            warn "_ar_norm built but import failed — pure-Python fallback will be used."
            warn "  build log: $BUILD_LOG"
        fi
    else
        warn "native build failed — pure-Python fallback will be used."
        warn "  full build log: $BUILD_LOG  — last 10 lines:"
        tail -10 "$BUILD_LOG" 2>/dev/null | sed 's/^/    /' >&2 || true
    fi
else
    warn "skipping native build (compiler or Python headers missing) — pure-Python fallback will be used."
fi

# ── Skim PDF viewer: reliable AppleScript page-nav; Preview is fallback. ──
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

# ── Pin shebang to absolute Python (Dock launches have stripped PATH). ────
step "pinning fuzzer shebang to $PYTHON …"
ABS_PYTHON="$("$PYTHON" -c 'import sys; print(sys.executable)')"
if [[ -x "$ROOT/fuzzer" ]]; then
    # Portable in-place edit — BSD sed (macOS) requires the empty -i arg.
    sed -i '' "1s|^#!.*python.*|#!${ABS_PYTHON}|" "$ROOT/fuzzer"
    ok "fuzzer shebang → $ABS_PYTHON"
else
    warn "fuzzer script not found at $ROOT/fuzzer — skipping shebang pin."
fi

# ── Smoke test ────────────────────────────────────────────────────────────────
step "smoke test: importing core deps via $ABS_PYTHON …"
"$ABS_PYTHON" - "$ROOT" <<'PY'
import importlib, sys, os
sys.path.insert(0, sys.argv[1])  # so _ar_norm next to fuzzer is importable

# PDF support is "either or": at least one of fitz / pdfplumber must import.
# fuzzer prefers fitz (PyMuPDF — better Arabic) and falls back to pdfplumber.
pdf_backends = ["fitz", "pdfplumber"]
required = ["rapidfuzz", "openpyxl", "docx", "pyarabic",
            "arabic_reshaper", "bidi", "anthropic", "tkinterdnd2"]
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

# Check the native Arabic-normalize extension (the thing that flips the status
# bar from "regex fallback" to "C ext (_ar_norm)"). Non-fatal but loud.
try:
    import _ar_norm  # noqa: F401
    ar_ext_ok = True
except Exception as e:
    ar_ext_ok = False
    ar_ext_err = str(e)

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
    have = [m for m in pdf_backends if m not in {n for n, _ in missing_pdf}][0]
    print(f"  PDF support OK via {have} ({missing_pdf[0][0]} unavailable)")
if not ar_ext_ok:
    print(f"  ! _ar_norm C ext not importable — Arabic status bar will read 'regex fallback'")
    print(f"    reason: {ar_ext_err}")
    print(f"    fix:    re-run `make build-native` (needs Xcode CLT + Python headers)")
if fatal:
    sys.exit(1)
ok_count = len(required) - len(missing_req) + len(pdf_backends) - len(missing_pdf)
print(f"  {ok_count}/{len(required) + len(pdf_backends)} core modules import cleanly")
print(f"  arabic engine: {'C ext (_ar_norm)' if ar_ext_ok else 'regex fallback'}")
PY
ok "smoke test passed"

# ── Next steps ────────────────────────────────────────────────────────────────
cat <<EOF

${BOLD}done.${RST}

next steps:
  ${DIM}# run the unit tests${RST}
  make test

  ${DIM}# (optional) fetch real PDFs for the corpus tests${RST}
  make test-corpus && make test
EOF

# ── Desktop launcher: minimal Fuzzer.app shim that exec's the real fuzzer. ──
step "creating Desktop launcher (Fuzzer.app)..."
APP_DIR="$HOME/Desktop/Fuzzer.app"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"

cat >"$APP_DIR/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key><string>Fuzzer</string>
    <key>CFBundleIdentifier</key><string>com.salman.fuzzer</string>
    <key>CFBundleName</key><string>Fuzzer</string>
    <key>CFBundleDisplayName</key><string>Fuzzer</string>
    <key>CFBundleVersion</key><string>1.0</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>LSMinimumSystemVersion</key><string>10.13</string>
    <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

cat >"$APP_DIR/Contents/MacOS/Fuzzer" <<LAUNCHER
#!/bin/bash
exec "$ROOT/fuzzer"
LAUNCHER
chmod +x "$APP_DIR/Contents/MacOS/Fuzzer"

# Bump mtime so Finder/LaunchServices re-reads the bundle metadata.
touch "$APP_DIR"
ok "Fuzzer.app created at $APP_DIR (double-click to launch)"

# ── Launch fuzzer (detached, stderr → log). ────────────────────────────────
step "launching fuzzer..."
LAUNCH_LOG="$ROOT/.fuzzer-launch.log"
: >"$LAUNCH_LOG" 2>/dev/null || LAUNCH_LOG="/tmp/fuzzer-launch.log"
nohup "$ROOT/fuzzer" >"$LAUNCH_LOG" 2>&1 &
disown 2>/dev/null || true
# Tk needs a moment to register its NSApplication before `activate` works.
sleep 1
osascript -e 'tell application "Python" to activate' 2>/dev/null || true
ok "fuzzer launched (stderr -> $LAUNCH_LOG if it blanks/crashes)"
