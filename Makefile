PYTHON := $(shell command -v python3 2>/dev/null || command -v python 2>/dev/null)
ROOT   := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
TEST   := $(ROOT)test_fuzzer.py
NATIVE := $(ROOT)native

.PHONY: test test-v test-vv demo install build-native clean-native bench-native docs docs-api docs-clean docs-serve doc doc-clean test-corpus test-corpus-clean

test: build-native
	$(PYTHON) -m pytest $(TEST) -s

test-v: build-native
	$(PYTHON) -m pytest $(TEST) -v -s

test-vv: build-native
	$(PYTHON) -m pytest $(TEST) -v -s --tb=short

demo: build-native
	$(PYTHON) -m pytest "$(TEST)::TestVisualHighlight" -v -s

install:
	$(PYTHON) -m pip install pymupdf rapidfuzz pdfplumber anthropic openpyxl python-docx pyarabic tkinterdnd2

# Build the _ar_norm C extension and drop the .so next to the fuzzer script.
# Idempotent: skips rebuild if the .so already exists and is newer than the .c.
build-native:
	@if [ -z "$$(ls $(ROOT)_ar_norm*.so 2>/dev/null)" ] || \
	    [ $(NATIVE)/ar_normalize.c -nt "$$(ls $(ROOT)_ar_norm*.so 2>/dev/null | head -1)" ]; then \
	  echo "→ building _ar_norm C extension"; \
	  cd $(NATIVE) && $(PYTHON) setup.py build_ext --inplace >/dev/null 2>&1 && \
	  cp $(NATIVE)/_ar_norm*.so $(ROOT) && \
	  echo "✓ _ar_norm installed at $(ROOT)"; \
	else \
	  echo "✓ _ar_norm up to date"; \
	fi

clean-native:
	rm -f $(ROOT)_ar_norm*.so $(NATIVE)/_ar_norm*.so
	rm -rf $(NATIVE)/build

# Build the documentation site into doc/_build/.
# Requires: pip install pdoc markdown pygments
docs:
	@$(PYTHON) -c "import pdoc, markdown" 2>/dev/null || \
	  (echo "→ installing doc dependencies"; \
	   $(PYTHON) -m pip install --quiet --user --break-system-packages pdoc markdown pygments)
	@$(PYTHON) $(ROOT)doc/build.py

docs-api:
	@$(PYTHON) $(ROOT)doc/build.py --api

docs-clean:
	rm -rf $(ROOT)doc/_build

# Serve docs locally on http://localhost:8765/ — handy for clicking through links.
docs-serve: docs
	@cd $(ROOT)doc/_build && $(PYTHON) -m http.server 8765

# Regenerate project_info.md from the current source via the Claude CLI.
# The file is gitignored — it's a regenerable snapshot, not source of truth.
# (Note: `make docs` builds the HTML site under doc/_build/; `make doc` is this one-file overview.)
doc:
	@command -v claude >/dev/null || { \
	  echo ""; \
	  echo "✗ 'claude' CLI not found — this target needs Claude Code installed."; \
	  echo ""; \
	  echo "  Install:   npm install -g @anthropic-ai/claude-code"; \
	  echo "  Docs:      https://docs.claude.com/en/docs/claude-code/overview"; \
	  echo "  Quickstart: https://docs.claude.com/en/docs/claude-code/quickstart"; \
	  echo ""; \
	  echo "  After install, run 'claude' once to sign in (a Claude.ai account works)."; \
	  echo "  Or use an API key — create one at:"; \
	  echo "    https://console.anthropic.com/settings/keys"; \
	  echo "  then export it:   export ANTHROPIC_API_KEY=sk-ant-…"; \
	  echo ""; \
	  exit 2; \
	}
	@echo "→ regenerating project_info.md (calling claude -p)…"
	@claude -p --permission-mode acceptEdits "Read this repository (fuzzer, test_fuzzer.py, Makefile, native/ar_normalize.c, doc/*.md, .sixth/mcp/sixth-mcp-settings.json if present) and write a concise codebase overview to project_info.md, overwriting any existing content. Use these sections: Summary, Architecture, Directory Structure, Key Abstractions, Data Flow, Non-Obvious Behaviours, Suggested Reading Order. Keep the existing HTML regen header comment at the top of the file. Be terse — link file paths inline; do not pad with restated obvious facts. Follow markdownlint defaults: a blank line around every heading, around every list block, and around every fenced code block; every fence must carry a language tag (use 'text' for the directory tree)." >/dev/null
	@test -s $(ROOT)project_info.md && echo "✓ project_info.md updated" || { echo "✗ project_info.md was not written"; exit 1; }

doc-clean:
	rm -f $(ROOT)project_info.md $(ROOT)project_info__*.md

# Fetch ~50 public Arabic + English PDFs into test_pdfs/ for the corpus test.
# Idempotent: re-running skips files already on disk. The corpus is gitignored
# (large binary blobs; regenerate any time).
test-corpus:
	@$(PYTHON) $(ROOT)tools/fetch_test_pdfs.py --target 50

test-corpus-clean:
	rm -rf $(ROOT)test_pdfs

bench-native: build-native
	@$(PYTHON) -c "import sys; sys.path.insert(0, '$(ROOT)'); \
	import timeit, re, _ar_norm; \
	D = re.compile(r'[ً-ْٰـ]'); \
	A = str.maketrans({'أ':'ا','إ':'ا','آ':'ا','ٱ':'ا'}); \
	Y = str.maketrans({'ى':'ي','ئ':'ي'}); \
	py = lambda s: D.sub('', s).translate(A).translate(Y); \
	sample = 'موضوع الرسالة: التواصل الإداري ' * 50; \
	n = 50000; \
	tp = timeit.timeit(lambda: py(sample), number=n); \
	tc = timeit.timeit(lambda: _ar_norm.normalize(sample), number=n); \
	print(f'  Python: {tp*1000/n:.3f} ms/call'); \
	print(f'  C ext:  {tc*1000/n:.3f} ms/call'); \
	print(f'  Speedup: {tp/tc:.1f}x')"
