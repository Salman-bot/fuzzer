/* _ar_norm — fast Arabic text normalization for fuzzer.
 *
 * Strips diacritics + tatweel, normalizes alef/yeh variants. Equivalent to:
 *
 *     _AR_DIACRITICS = re.compile(r"[ً-ْٰـ]")
 *     _ALEF_VARIANTS = {أ, إ, آ, ٱ} -> ا
 *     _YEH_VARIANTS  = {ى, ئ}      -> ي
 *
 * Single-pass UTF-8 walk, ~10-20x faster than the regex+translate pipeline
 * on typical Arabic text.
 */
#define PY_SSIZE_T_CLEAN
#include <Python.h>
#include <stdint.h>
#include <string.h>

/* Codepoints to drop entirely. */
static inline int ar_is_drop(uint32_t cp) {
    /* U+064B–U+0652: harakat (fatha, kasra, damma, shadda, sukun, etc.) */
    /* U+0670: superscript alef                                        */
    /* U+0640: tatweel (kashida)                                       */
    return (cp >= 0x064B && cp <= 0x0652) || cp == 0x0670 || cp == 0x0640;
}

/* Returns target codepoint, or 0 to keep original. */
static inline uint32_t ar_map(uint32_t cp) {
    switch (cp) {
        case 0x0623: /* أ */
        case 0x0625: /* إ */
        case 0x0622: /* آ */
        case 0x0671: /* ٱ */
            return 0x0627; /* ا */
        case 0x0649: /* ى */
        case 0x0626: /* ئ */
            return 0x064A; /* ي */
        default:
            return 0;
    }
}

/* Encode a codepoint in the 2-byte UTF-8 range (U+0080–U+07FF) into dst. */
static inline void enc2(uint32_t cp, uint8_t *dst) {
    dst[0] = (uint8_t)(0xC0 | (cp >> 6));
    dst[1] = (uint8_t)(0x80 | (cp & 0x3F));
}

static PyObject *py_normalize(PyObject *self, PyObject *args) {
    (void)self;
    const char *src;
    Py_ssize_t src_len;
    if (!PyArg_ParseTuple(args, "s#:normalize", &src, &src_len)) return NULL;

    /* Output ≤ input: drops shrink, maps preserve length, others copy. */
    char *buf = (char *)PyMem_Malloc((size_t)src_len + 1);
    if (!buf) return PyErr_NoMemory();

    const uint8_t *s = (const uint8_t *)src;
    Py_ssize_t i = 0, o = 0;

    while (i < src_len) {
        uint8_t b = s[i];
        if (b < 0x80) {
            buf[o++] = (char)b;
            i++;
        } else if ((b & 0xE0) == 0xC0 && i + 1 < src_len) {
            uint32_t cp = ((uint32_t)(b & 0x1F) << 6) | (uint32_t)(s[i + 1] & 0x3F);
            if (ar_is_drop(cp)) {
                /* drop */
            } else {
                uint32_t mapped = ar_map(cp);
                if (mapped) {
                    enc2(mapped, (uint8_t *)(buf + o));
                    o += 2;
                } else {
                    buf[o++] = (char)b;
                    buf[o++] = (char)s[i + 1];
                }
            }
            i += 2;
        } else if ((b & 0xF0) == 0xE0 && i + 2 < src_len) {
            buf[o++] = (char)b;
            buf[o++] = (char)s[i + 1];
            buf[o++] = (char)s[i + 2];
            i += 3;
        } else if ((b & 0xF8) == 0xF0 && i + 3 < src_len) {
            buf[o++] = (char)b;
            buf[o++] = (char)s[i + 1];
            buf[o++] = (char)s[i + 2];
            buf[o++] = (char)s[i + 3];
            i += 4;
        } else {
            buf[o++] = (char)b;
            i++;
        }
    }

    PyObject *result = PyUnicode_DecodeUTF8(buf, o, "replace");
    PyMem_Free(buf);
    return result;
}

static PyMethodDef AR_Methods[] = {
    {"normalize", py_normalize, METH_VARARGS,
     "normalize(s) -> str: strip diacritics + tatweel, normalize alef/yeh."},
    {NULL, NULL, 0, NULL},
};

static struct PyModuleDef ar_norm_module = {
    PyModuleDef_HEAD_INIT,
    "_ar_norm",
    "Fast Arabic text normalization (C implementation).",
    -1,
    AR_Methods,
    NULL, NULL, NULL, NULL,
};

PyMODINIT_FUNC PyInit__ar_norm(void) {
    return PyModule_Create(&ar_norm_module);
}
