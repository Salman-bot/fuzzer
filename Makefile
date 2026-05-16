PYTHON := $(shell command -v python3 2>/dev/null || command -v python 2>/dev/null)
ROOT   := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
TEST   := $(ROOT)test_fuzzer.py
NATIVE := $(ROOT)native

.PHONY: test test-v test-vv demo install build-native clean-native bench-native docs docs-api docs-clean docs-serve test-corpus test-corpus-clean

test: build-native
	$(PYTHON) -m pytest $(TEST) -s

test-v: build-native
	$(PYTHON) -m pytest $(TEST) -v -s

test-vv: build-native
	$(PYTHON) -m pytest $(TEST) -v -s --tb=short

demo: build-native
	$(PYTHON) -m pytest "$(TEST)::TestVisualHighlight" -v -s

install:
	$(PYTHON) -m pip install pymupdf rapidfuzz pdfplumber openpyxl python-docx pyarabic tkinterdnd2 arabic_reshaper python-bidi

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

# Build the documentation site into docs/_build/.
# Requires: pip install pdoc markdown pygments
docs:
	@$(PYTHON) -c "import pdoc, markdown" 2>/dev/null || \
	  (echo "→ installing doc dependencies"; \
	   $(PYTHON) -m pip install --quiet --user --break-system-packages pdoc markdown pygments)
	@$(PYTHON) $(ROOT)docs/build.py

docs-api:
	@$(PYTHON) $(ROOT)docs/build.py --api

docs-clean:
	rm -rf $(ROOT)docs/_build

# Serve docs locally on http://localhost:8765/ — handy for clicking through links.
docs-serve: docs
	@cd $(ROOT)docs/_build && $(PYTHON) -m http.server 8765

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
