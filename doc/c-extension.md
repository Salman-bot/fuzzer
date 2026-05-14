# `_ar_norm` — Arabic normalization C extension

A small CPython extension that performs the Arabic text normalization
`fuzzer` needs on every line of every searched file. It replaces a
`re.sub` + two `.translate()` calls with a single UTF-8 byte walk.

**Speedup:** ~11× faster than the pure-Python reference on a typical
Arabic line (0.054 ms → 0.005 ms per call, measured with `make bench-native`).

## Source

[native/ar_normalize.c](../native/ar_normalize.c) — ~120 lines of C99.

## What it does

| Operation | Codepoints | Rule |
| --------- | ---------- | ---- |
| Drop diacritics | U+064B – U+0652 | All eight harakat (fatha, kasra, damma, shadda, sukun, etc.) |
| Drop superscript alef | U+0670 | Drop |
| Drop tatweel | U+0640 | Drop |
| Normalize alef | U+0623 (أ), U+0625 (إ), U+0622 (آ), U+0671 (ٱ) | → U+0627 (ا) |
| Normalize yeh | U+0649 (ى), U+0626 (ئ) | → U+064A (ي) |

All other codepoints — including non-Arabic Unicode, English, digits, and
punctuation — pass through unchanged. The walk is UTF-8-safe for 1-, 2-, 3-,
and 4-byte sequences; only 2-byte sequences in the Arabic block trigger
decode + map logic, so non-Arabic text incurs ~zero overhead beyond a single
byte-class check per byte.

## Python API

```python
import _ar_norm

_ar_norm.normalize("السَّلَامُ عَلَيْكُمْ")
# → 'السلام عليكم'

_ar_norm.normalize("أهلا إلى آدم ٱلله")
# → 'اهلا الي ادم الله'

_ar_norm.normalize("Hello أحمد 123")
# → 'Hello احمد 123'
```

Signature: `normalize(s: str) -> str`.

Empty input returns empty output. Malformed UTF-8 is passed through
byte-for-byte (it is also handled by the final `PyUnicode_DecodeUTF8(...,
"replace")` decode, so non-decodable bytes become U+FFFD).

## Integration in fuzzer

`fuzzer` picks one of three implementations at module-load time, in this
priority:

```python
# fuzzer:224–249
try:
    import _ar_norm
    def _normalize_arabic(s): return _ar_norm.normalize(s)
except ImportError:
    try:
        from pyarabic.normalize import normalize_searchtext as _ar_norm_search
        def _normalize_arabic(s): return _ar_norm_search(s)
    except ImportError:
        # pure-Python regex + translate fallback
        ...
```

The C extension is loaded from the directory containing the `fuzzer` script
(added to `sys.path` at load time), so it works without an `install` step —
just `make build-native`.

## Building

```sh
make build-native    # idempotent; rebuilds only if .c is newer than .so
make clean-native    # remove the .so and the build/ tree
make bench-native    # compare C vs Python reference, print speedup
```

Manually:

```sh
cd native
python3 setup.py build_ext --inplace
cp _ar_norm*.so ..
```

Output binary name is platform-specific:

- macOS (Python 3.14, arm64): `_ar_norm.cpython-314-darwin.so`
- Linux (Python 3.11, x86_64): `_ar_norm.cpython-311-x86_64-linux-gnu.so`
- Windows: `_ar_norm.cp311-win_amd64.pyd`

The Makefile uses a glob (`_ar_norm*.so`) so it doesn't care which suffix
your CPython produces. The .so is **not** committed to git — each platform
builds its own.

## Testing

`make bench-native` and the existing pytest suite both exercise it. The
extension is used by every test that searches Arabic text because
`_normalize_arabic` is called from `_tokenize`, which the PDF highlighting
path uses on every dict line.

## Why not use ctypes / cffi?

Both add a per-call FFI overhead that would erase most of the speedup for
short strings. The CPython C API lets us return a Python `str` directly from
a `char *` buffer with one `PyUnicode_DecodeUTF8` call.

## Memory model

The output buffer is allocated once per call with `PyMem_Malloc(src_len + 1)`
— output is bounded by input length (drops shrink, maps preserve length, ASCII
copies one-for-one). It's freed before return. No reference cycles.
