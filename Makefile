PYTHON := $(shell command -v python3 2>/dev/null || command -v python 2>/dev/null)
TEST   := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))test_fuzzer.py

.PHONY: test test-v test-vv demo install

test:
	$(PYTHON) -m pytest $(TEST) -s

test-v:
	$(PYTHON) -m pytest $(TEST) -v -s

test-vv:
	$(PYTHON) -m pytest $(TEST) -v -s --tb=short

demo:
	$(PYTHON) -m pytest "$(TEST)::TestVisualHighlight" -v -s

install:
	$(PYTHON) -m pip install pymupdf thefuzz pdfplumber anthropic openpyxl python-docx
