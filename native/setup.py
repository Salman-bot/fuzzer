"""Build the _ar_norm C extension.

Usage:
    python3 setup.py build_ext --inplace

The compiled .so/.pyd lands next to this file. The Makefile target
`build-native` copies it up to the parent dir so `fuzzer` can import it.
"""
from setuptools import setup, Extension

setup(
    name="_ar_norm",
    version="1.0.0",
    description="Fast Arabic text normalization for fuzzer.",
    ext_modules=[
        Extension(
            "_ar_norm",
            sources=["ar_normalize.c"],
            extra_compile_args=["-O3", "-Wall", "-Wextra"],
        ),
    ],
)
