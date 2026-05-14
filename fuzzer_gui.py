# fuzzer_gui.py
from __future__ import annotations

import argparse
import importlib.util
import sys
from importlib.machinery import SourceFileLoader
from pathlib import Path
from types import ModuleType
from typing import Optional


def _load_backend() -> ModuleType:
    """
    Load the existing backend from the repo's `fuzzer` script (no .py suffix).
    This avoids modifying the current CLI/GUI code while still giving you a
    dedicated Python entrypoint file.

    `fuzzer` has no `.py` extension (so it works as a binary on $PATH), so
    `spec_from_file_location` can't infer a loader — we pass SourceFileLoader
    explicitly.
    """
    backend_path = Path(__file__).resolve().with_name("fuzzer")
    if not backend_path.exists():
        raise FileNotFoundError(f"Could not find backend script at: {backend_path}")

    loader = SourceFileLoader("fuzzer_backend", str(backend_path))
    spec = importlib.util.spec_from_file_location(
        "fuzzer_backend", str(backend_path), loader=loader,
    )
    if spec is None or spec.loader is None:
        raise RuntimeError(f"Failed to create import spec for: {backend_path}")

    module = importlib.util.module_from_spec(spec)
    module.__file__ = str(backend_path)  # ensure __file__ is set before exec
    spec.loader.exec_module(module)
    return module


def main(argv: Optional[list[str]] = None) -> int:
    parser = argparse.ArgumentParser(
        prog="fuzzer_gui",
        description="Launch the fuzzer GUI (stylish Tk/ttk interface).",
    )
    parser.add_argument(
        "--native-debug",
        action="store_true",
        help="Enable the GUI's native normalization inspector (uses --test in backend).",
    )
    args = parser.parse_args(argv)

    orig_argv = sys.argv[:]
    try:
        if args.native_debug and "--test" not in sys.argv:
            sys.argv.append("--test")

        backend = _load_backend()
        run_gui = getattr(backend, "run_gui", None)
        if run_gui is None:
            raise AttributeError("Backend does not export run_gui()")

        # run_gui() returns an int status code
        return int(run_gui())
    finally:
        sys.argv = orig_argv


if __name__ == "__main__":
    raise SystemExit(main())
