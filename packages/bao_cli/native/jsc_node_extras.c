/*
 * jsc_node_extras.c — Additional Node.js compatibility modules for JSC worker
 *
 * Implements:
 *   1. require('zlib') — REAL deflate/inflate/gzip/gunzip + brotli via C libs
 *   2. Buffer.compare / isBuffer / concat / byteLength
 *   3. Buffer.prototype.write
 *   4. process.binding() stub
 *   5. assert.match / doesNotMatch / ifError / rejects / doesNotReject
 *   6. require('node:tty')
 *   7. require('timers')
 *
 * Strategy: Use C callbacks for zlib/brotli, JS eval for the rest.
 */

#include "jsc_node_extras.h"
#include <zlib.h>
#include <brotli/encode.h>
#include <brotli/decode.h>

/* ============================================================================
 * Helper: eval a JS string and return the result
 * ============================================================================ */

static JSValueRef eval_js_extras(JSContextRef ctx, const char* source, const char* source_url) {
    JSStringRef script = JSStringCreateWithUTF8CString(source);
    JSStringRef url = source_url ? JSStringCreateWithUTF8CString(source_url) : NULL;
    JSValueRef ex = NULL;
    JSValueRef result = JSEvaluateScript(ctx, script, NULL, url, 1, &ex);
    JSStringRelease(script);
    if (url) JSStringRelease(url);
    if (ex) {
        char* m = to_utf8(ctx, ex);
        fprintf(stderr, "node_extras eval error [%s]: %s\n", source_url ? source_url : "?", m);
        free(m);
        return JSValueMakeUndefined(ctx);
    }
    return result;
}

/* ============================================================================
 * Helper: extract byte array from a JS value (Array or TypedArray-like)
 * Returns malloc'd buffer. Caller must free. Sets *out_len.
 * ============================================================================ */

static unsigned char* js_value_to_bytes(JSContextRef ctx, JSValueRef val, size_t* out_len) {
    *out_len = 0;
    if (!val || !JSValueIsObject(ctx, val)) {
        /* Try converting string to bytes */
        if (val && JSValueIsString(ctx, val)) {
            char* s = to_utf8(ctx, val);
            size_t slen = strlen(s);
            unsigned char* buf = (unsigned char*)malloc(slen);
            memcpy(buf, s, slen);
            free(s);
            *out_len = slen;
            return buf;
        }
        return NULL;
    }

    JSObjectRef arr = JSValueToObject(ctx, val, NULL);
    JSStringRef lk = JSStringCreateWithUTF8CString("length");
    JSValueRef lv = JSObjectGetProperty(ctx, arr, lk, NULL);
    JSStringRelease(lk);
    if (!JSValueIsNumber(ctx, lv)) return NULL;

    size_t len = (size_t)JSValueToNumber(ctx, lv, NULL);
    unsigned char* buf = (unsigned char*)malloc(len > 0 ? len : 1);
    for (size_t i = 0; i < len; i++) {
        JSValueRef ev = JSObjectGetPropertyAtIndex(ctx, arr, (unsigned)i, NULL);
        if (JSValueIsNumber(ctx, ev)) {
            buf[i] = (unsigned char)((unsigned int)JSValueToNumber(ctx, ev, NULL) & 0xFF);
        } else {
            buf[i] = 0;
        }
    }
    *out_len = len;
    return buf;
}

/* Helper: make a JS array from bytes */
static JSObjectRef bytes_to_js_array(JSContextRef ctx, const unsigned char* data, size_t len) {
    JSValueRef* vals = (JSValueRef*)malloc(len * sizeof(JSValueRef));
    for (size_t i = 0; i < len; i++) {
        vals[i] = make_number(ctx, (double)data[i]);
    }
    JSObjectRef arr = JSObjectMakeArray(ctx, len, vals, NULL);
    free(vals);
    return arr;
}

/* ============================================================================
 * zlib C callbacks — real compression/decompression
 * ============================================================================ */

/* zlib.inflateSync(buffer) -> Buffer */
static JSValueRef zlib_inflateSync_cb(JSContextRef c, JSObjectRef f, JSObjectRef t,
                                       size_t ac, const JSValueRef a[], JSValueRef* e) {
    (void)f; (void)t;
    if (ac < 1) return make_error(c, "zlib.inflateSync: buffer required", e);

    size_t in_len = 0;
    unsigned char* in_buf = js_value_to_bytes(c, a[0], &in_len);
    if (!in_buf) return make_error(c, "zlib.inflateSync: invalid input", e);

    /* Try with growing output buffer */
    size_t out_cap = in_len * 8;
    if (out_cap < 256) out_cap = 256;
    unsigned char* out_buf = (unsigned char*)malloc(out_cap);

    z_stream strm;
    memset(&strm, 0, sizeof(strm));

    int ret = inflateInit(&strm);
    if (ret != Z_OK) {
        free(in_buf); free(out_buf);
        return make_error(c, "zlib.inflateSync: inflateInit failed", e);
    }

    strm.next_in = in_buf;
    strm.avail_in = (uInt)in_len;

    /* Loop with buffer reallocation if needed */
    int max_tries = 16;
    do {
        strm.next_out = out_buf + strm.total_out;
        strm.avail_out = (uInt)(out_cap - strm.total_out);

        ret = inflate(&strm, Z_FINISH);
        if (ret == Z_STREAM_END) break;
        if (ret == Z_BUF_ERROR && strm.avail_out == 0) {
            /* Need more output space — reallocate */
            size_t new_cap = out_cap * 2;
            unsigned char* new_buf = (unsigned char*)realloc(out_buf, new_cap);
            if (!new_buf) {
                (void)inflateEnd(&strm);
                free(in_buf); free(out_buf);
                return make_error(c, "zlib.inflateSync: out of memory", e);
            }
            out_buf = new_buf;
            out_cap = new_cap;
            ret = Z_OK; /* continue */
            continue;
        }
        if (ret != Z_OK) {
            const char* msg = strm.msg ? strm.msg : "inflate failed";
            char err[512];
            snprintf(err, sizeof(err), "zlib.inflateSync: %s", msg);
            (void)inflateEnd(&strm);
            free(in_buf); free(out_buf);
            return make_error(c, err, e);
        }
    } while (--max_tries > 0);

    if (ret != Z_STREAM_END) {
        (void)inflateEnd(&strm);
        free(in_buf); free(out_buf);
        return make_error(c, "zlib.inflateSync: inflate failed (too many iterations)", e);
    }

    size_t out_len = strm.total_out;
    (void)inflateEnd(&strm);
    free(in_buf);

    JSObjectRef result = bytes_to_js_array(c, out_buf, out_len);
    free(out_buf);
    return result;
}

/* zlib.deflateSync(buffer) -> Buffer */
static JSValueRef zlib_deflateSync_cb(JSContextRef c, JSObjectRef f, JSObjectRef t,
                                       size_t ac, const JSValueRef a[], JSValueRef* e) {
    (void)f; (void)t;
    if (ac < 1) return make_error(c, "zlib.deflateSync: buffer required", e);

    size_t in_len = 0;
    unsigned char* in_buf = js_value_to_bytes(c, a[0], &in_len);
    if (!in_buf) return make_error(c, "zlib.deflateSync: invalid input", e);

    size_t out_cap = compressBound((uLong)in_len);
    unsigned char* out_buf = (unsigned char*)malloc(out_cap);

    z_stream strm;
    memset(&strm, 0, sizeof(strm));
    strm.next_in = in_buf;
    strm.avail_in = (uInt)in_len;
    strm.next_out = out_buf;
    strm.avail_out = (uInt)out_cap;

    int ret = deflateInit(&strm, Z_DEFAULT_COMPRESSION);
    if (ret != Z_OK) {
        free(in_buf); free(out_buf);
        return make_error(c, "zlib.deflateSync: deflateInit failed", e);
    }

    ret = deflate(&strm, Z_FINISH);
    if (ret != Z_STREAM_END) {
        (void)deflateEnd(&strm);
        free(in_buf); free(out_buf);
        return make_error(c, "zlib.deflateSync: deflate failed", e);
    }

    size_t out_len = strm.total_out;
    (void)deflateEnd(&strm);
    free(in_buf);

    JSObjectRef result = bytes_to_js_array(c, out_buf, out_len);
    free(out_buf);
    return result;
}

/* zlib.gunzipSync(buffer) -> Buffer — inflate with wbits=31 (gzip) */
static JSValueRef zlib_gunzipSync_cb(JSContextRef c, JSObjectRef f, JSObjectRef t,
                                      size_t ac, const JSValueRef a[], JSValueRef* e) {
    (void)f; (void)t;
    if (ac < 1) return make_error(c, "zlib.gunzipSync: buffer required", e);

    size_t in_len = 0;
    unsigned char* in_buf = js_value_to_bytes(c, a[0], &in_len);
    if (!in_buf) return make_error(c, "zlib.gunzipSync: invalid input", e);

    size_t out_cap = in_len * 8;
    if (out_cap < 256) out_cap = 256;
    unsigned char* out_buf = (unsigned char*)malloc(out_cap);

    z_stream strm;
    memset(&strm, 0, sizeof(strm));

    int ret = inflateInit2(&strm, 15 + 16);
    if (ret != Z_OK) {
        free(in_buf); free(out_buf);
        return make_error(c, "zlib.gunzipSync: inflateInit2 failed", e);
    }

    strm.next_in = in_buf;
    strm.avail_in = (uInt)in_len;

    int max_tries = 16;
    do {
        strm.next_out = out_buf + strm.total_out;
        strm.avail_out = (uInt)(out_cap - strm.total_out);
        ret = inflate(&strm, Z_FINISH);
        if (ret == Z_STREAM_END) break;
        if (ret == Z_BUF_ERROR && strm.avail_out == 0) {
            size_t new_cap = out_cap * 2;
            unsigned char* new_buf = (unsigned char*)realloc(out_buf, new_cap);
            if (!new_buf) { (void)inflateEnd(&strm); free(in_buf); free(out_buf); return make_error(c, "zlib.gunzipSync: out of memory", e); }
            out_buf = new_buf; out_cap = new_cap; ret = Z_OK; continue;
        }
        if (ret != Z_OK) {
            const char* msg = strm.msg ? strm.msg : "gunzip failed";
            char err[512]; snprintf(err, sizeof(err), "zlib.gunzipSync: %s", msg);
            (void)inflateEnd(&strm); free(in_buf); free(out_buf);
            return make_error(c, err, e);
        }
    } while (--max_tries > 0);

    if (ret != Z_STREAM_END) { (void)inflateEnd(&strm); free(in_buf); free(out_buf); return make_error(c, "zlib.gunzipSync: failed", e); }

    size_t out_len = strm.total_out;
    (void)inflateEnd(&strm);
    free(in_buf);

    JSObjectRef result = bytes_to_js_array(c, out_buf, out_len);
    free(out_buf);
    return result;
}

/* zlib.gzipSync(buffer) -> Buffer — deflate with wbits=31 (gzip) */
static JSValueRef zlib_gzipSync_cb(JSContextRef c, JSObjectRef f, JSObjectRef t,
                                    size_t ac, const JSValueRef a[], JSValueRef* e) {
    (void)f; (void)t;
    if (ac < 1) return make_error(c, "zlib.gzipSync: buffer required", e);

    size_t in_len = 0;
    unsigned char* in_buf = js_value_to_bytes(c, a[0], &in_len);
    if (!in_buf) return make_error(c, "zlib.gzipSync: invalid input", e);

    size_t out_cap = compressBound((uLong)in_len) + 64;
    unsigned char* out_buf = (unsigned char*)malloc(out_cap);

    z_stream strm;
    memset(&strm, 0, sizeof(strm));
    strm.next_in = in_buf;
    strm.avail_in = (uInt)in_len;
    strm.next_out = out_buf;
    strm.avail_out = (uInt)out_cap;

    /* wbits=31 means 15 window bits + 16 for gzip encoding */
    int ret = deflateInit2(&strm, Z_DEFAULT_COMPRESSION, Z_DEFLATED, 15 + 16, 8, Z_DEFAULT_STRATEGY);
    if (ret != Z_OK) {
        free(in_buf); free(out_buf);
        return make_error(c, "zlib.gzipSync: deflateInit2 failed", e);
    }

    ret = deflate(&strm, Z_FINISH);
    if (ret != Z_STREAM_END) {
        (void)deflateEnd(&strm);
        free(in_buf); free(out_buf);
        return make_error(c, "zlib.gzipSync: deflate failed", e);
    }

    size_t out_len = strm.total_out;
    (void)deflateEnd(&strm);
    free(in_buf);

    JSObjectRef result = bytes_to_js_array(c, out_buf, out_len);
    free(out_buf);
    return result;
}

/* zlib.inflateRawSync(buffer) -> Buffer */
static JSValueRef zlib_inflateRawSync_cb(JSContextRef c, JSObjectRef f, JSObjectRef t,
                                          size_t ac, const JSValueRef a[], JSValueRef* e) {
    (void)f; (void)t;
    if (ac < 1) return make_error(c, "zlib.inflateRawSync: buffer required", e);

    size_t in_len = 0;
    unsigned char* in_buf = js_value_to_bytes(c, a[0], &in_len);
    if (!in_buf) return make_error(c, "zlib.inflateRawSync: invalid input", e);

    size_t out_cap = in_len * 8;
    if (out_cap < 256) out_cap = 256;
    unsigned char* out_buf = (unsigned char*)malloc(out_cap);

    z_stream strm;
    memset(&strm, 0, sizeof(strm));

    int ret = inflateInit2(&strm, -15);
    if (ret != Z_OK) { free(in_buf); free(out_buf); return make_error(c, "zlib.inflateRawSync: inflateInit2 failed", e); }

    strm.next_in = in_buf;
    strm.avail_in = (uInt)in_len;

    int max_tries = 16;
    do {
        strm.next_out = out_buf + strm.total_out;
        strm.avail_out = (uInt)(out_cap - strm.total_out);
        ret = inflate(&strm, Z_FINISH);
        if (ret == Z_STREAM_END) break;
        if (ret == Z_BUF_ERROR && strm.avail_out == 0) {
            size_t new_cap = out_cap * 2;
            unsigned char* new_buf = (unsigned char*)realloc(out_buf, new_cap);
            if (!new_buf) { (void)inflateEnd(&strm); free(in_buf); free(out_buf); return make_error(c, "zlib.inflateRawSync: out of memory", e); }
            out_buf = new_buf; out_cap = new_cap; ret = Z_OK; continue;
        }
        if (ret != Z_OK) {
            const char* msg = strm.msg ? strm.msg : "inflateRaw failed";
            char err[512]; snprintf(err, sizeof(err), "zlib.inflateRawSync: %s", msg);
            (void)inflateEnd(&strm); free(in_buf); free(out_buf);
            return make_error(c, err, e);
        }
    } while (--max_tries > 0);

    if (ret != Z_STREAM_END) { (void)inflateEnd(&strm); free(in_buf); free(out_buf); return make_error(c, "zlib.inflateRawSync: failed", e); }

    size_t out_len = strm.total_out;
    (void)inflateEnd(&strm);
    free(in_buf);

    JSObjectRef result = bytes_to_js_array(c, out_buf, out_len);
    free(out_buf);
    return result;
}

/* zlib.deflateRawSync(buffer) -> Buffer */
static JSValueRef zlib_deflateRawSync_cb(JSContextRef c, JSObjectRef f, JSObjectRef t,
                                          size_t ac, const JSValueRef a[], JSValueRef* e) {
    (void)f; (void)t;
    if (ac < 1) return make_error(c, "zlib.deflateRawSync: buffer required", e);

    size_t in_len = 0;
    unsigned char* in_buf = js_value_to_bytes(c, a[0], &in_len);
    if (!in_buf) return make_error(c, "zlib.deflateRawSync: invalid input", e);

    size_t out_cap = compressBound((uLong)in_len);
    unsigned char* out_buf = (unsigned char*)malloc(out_cap);

    z_stream strm;
    memset(&strm, 0, sizeof(strm));
    strm.next_in = in_buf;
    strm.avail_in = (uInt)in_len;
    strm.next_out = out_buf;
    strm.avail_out = (uInt)out_cap;

    int ret = deflateInit2(&strm, Z_DEFAULT_COMPRESSION, Z_DEFLATED, -15, 8, Z_DEFAULT_STRATEGY);
    if (ret != Z_OK) {
        free(in_buf); free(out_buf);
        return make_error(c, "zlib.deflateRawSync: deflateInit2 failed", e);
    }

    ret = deflate(&strm, Z_FINISH);
    if (ret != Z_STREAM_END) {
        (void)deflateEnd(&strm);
        free(in_buf); free(out_buf);
        return make_error(c, "zlib.deflateRawSync: deflate failed", e);
    }

    size_t out_len = strm.total_out;
    (void)deflateEnd(&strm);
    free(in_buf);

    JSObjectRef result = bytes_to_js_array(c, out_buf, out_len);
    free(out_buf);
    return result;
}

/* zlib.unzipSync(buffer) -> Buffer — auto-detect zlib/gzip header */
static JSValueRef zlib_unzipSync_cb(JSContextRef c, JSObjectRef f, JSObjectRef t,
                                     size_t ac, const JSValueRef a[], JSValueRef* e) {
    (void)f; (void)t;
    if (ac < 1) return make_error(c, "zlib.unzipSync: buffer required", e);

    size_t in_len = 0;
    unsigned char* in_buf = js_value_to_bytes(c, a[0], &in_len);
    if (!in_buf) return make_error(c, "zlib.unzipSync: invalid input", e);

    size_t out_cap = in_len * 8;
    if (out_cap < 256) out_cap = 256;
    unsigned char* out_buf = (unsigned char*)malloc(out_cap);

    z_stream strm;
    memset(&strm, 0, sizeof(strm));

    /* wbits=15+32 = auto-detect zlib or gzip header */
    int ret = inflateInit2(&strm, 15 + 32);
    if (ret != Z_OK) { free(in_buf); free(out_buf); return make_error(c, "zlib.unzipSync: inflateInit2 failed", e); }

    strm.next_in = in_buf;
    strm.avail_in = (uInt)in_len;

    int max_tries = 16;
    do {
        strm.next_out = out_buf + strm.total_out;
        strm.avail_out = (uInt)(out_cap - strm.total_out);
        ret = inflate(&strm, Z_FINISH);
        if (ret == Z_STREAM_END) break;
        if (ret == Z_BUF_ERROR && strm.avail_out == 0) {
            size_t new_cap = out_cap * 2;
            unsigned char* new_buf = (unsigned char*)realloc(out_buf, new_cap);
            if (!new_buf) { (void)inflateEnd(&strm); free(in_buf); free(out_buf); return make_error(c, "zlib.unzipSync: out of memory", e); }
            out_buf = new_buf; out_cap = new_cap; ret = Z_OK; continue;
        }
        if (ret != Z_OK) {
            const char* msg = strm.msg ? strm.msg : "unzip failed";
            char err[512]; snprintf(err, sizeof(err), "zlib.unzipSync: %s", msg);
            (void)inflateEnd(&strm); free(in_buf); free(out_buf);
            return make_error(c, err, e);
        }
    } while (--max_tries > 0);

    if (ret != Z_STREAM_END) { (void)inflateEnd(&strm); free(in_buf); free(out_buf); return make_error(c, "zlib.unzipSync: failed", e); }

    size_t out_len = strm.total_out;
    (void)inflateEnd(&strm);
    free(in_buf);

    JSObjectRef result = bytes_to_js_array(c, out_buf, out_len);
    free(out_buf);
    return result;
}

/* zlib.brotliDecompressSync(buffer) -> Buffer */
static JSValueRef zlib_brotliDecompressSync_cb(JSContextRef c, JSObjectRef f, JSObjectRef t,
                                                 size_t ac, const JSValueRef a[], JSValueRef* e) {
    (void)f; (void)t;
    if (ac < 1) return make_error(c, "zlib.brotliDecompressSync: buffer required", e);

    size_t in_len = 0;
    unsigned char* in_buf = js_value_to_bytes(c, a[0], &in_len);
    if (!in_buf) return make_error(c, "zlib.brotliDecompressSync: invalid input", e);

    /* Get decoded size first */
    size_t decoded_size = 0;
    BrotliDecoderResult bret = BrotliDecoderDecompress(in_len, in_buf, &decoded_size, NULL);
    if (bret == BROTLI_DECODER_RESULT_ERROR) {
        /* Try with a reasonable buffer size */
        decoded_size = in_len * 10;
        if (decoded_size < 1024) decoded_size = 1024;
    }

    unsigned char* out_buf = (unsigned char*)malloc(decoded_size);
    size_t out_len = decoded_size;
    BrotliDecoderResult ret2 = BrotliDecoderDecompress(in_len, in_buf, &out_len, out_buf);
    if (ret2 != BROTLI_DECODER_RESULT_SUCCESS) {
        /* Try larger buffer */
        free(out_buf);
        decoded_size = in_len * 20;
        if (decoded_size < 4096) decoded_size = 4096;
        out_buf = (unsigned char*)malloc(decoded_size);
        out_len = decoded_size;
        ret2 = BrotliDecoderDecompress(in_len, in_buf, &out_len, out_buf);
        if (ret2 != BROTLI_DECODER_RESULT_SUCCESS) {
            free(in_buf); free(out_buf);
            return make_error(c, "zlib.brotliDecompressSync: decompression failed", e);
        }
    }
    free(in_buf);

    JSObjectRef result = bytes_to_js_array(c, out_buf, out_len);
    free(out_buf);
    return result;
}

/* zlib.brotliCompressSync(buffer) -> Buffer */
static JSValueRef zlib_brotliCompressSync_cb(JSContextRef c, JSObjectRef f, JSObjectRef t,
                                               size_t ac, const JSValueRef a[], JSValueRef* e) {
    (void)f; (void)t;
    if (ac < 1) return make_error(c, "zlib.brotliCompressSync: buffer required", e);

    size_t in_len = 0;
    unsigned char* in_buf = js_value_to_bytes(c, a[0], &in_len);
    if (!in_buf) return make_error(c, "zlib.brotliCompressSync: invalid input", e);

    size_t out_cap = BrotliEncoderMaxCompressedSize(in_len);
    if (out_cap == 0) out_cap = in_len + 1024;
    unsigned char* out_buf = (unsigned char*)malloc(out_cap);
    size_t out_len = out_cap;

    BROTLI_BOOL bret = BrotliEncoderCompress(
        BROTLI_DEFAULT_QUALITY, BROTLI_DEFAULT_WINDOW, BROTLI_DEFAULT_MODE,
        in_len, in_buf, &out_len, out_buf);

    if (!bret) {
        free(in_buf); free(out_buf);
        return make_error(c, "zlib.brotliCompressSync: compression failed", e);
    }
    free(in_buf);

    JSObjectRef result = bytes_to_js_array(c, out_buf, out_len);
    free(out_buf);
    return result;
}

/* ============================================================================
 * Register zlib module with real C callbacks + JS wrapper for async/create*
 * ============================================================================ */

static void register_zlib_module(JSContextRef ctx) {
    /* Create the zlib module object */
    JSObjectRef zlib_obj = JSObjectMake(ctx, NULL, NULL);

    /* Register sync C callbacks */
    reg_method(ctx, zlib_obj, "inflateSync", zlib_inflateSync_cb);
    reg_method(ctx, zlib_obj, "deflateSync", zlib_deflateSync_cb);
    reg_method(ctx, zlib_obj, "gunzipSync", zlib_gunzipSync_cb);
    reg_method(ctx, zlib_obj, "gzipSync", zlib_gzipSync_cb);
    reg_method(ctx, zlib_obj, "inflateRawSync", zlib_inflateRawSync_cb);
    reg_method(ctx, zlib_obj, "deflateRawSync", zlib_deflateRawSync_cb);
    reg_method(ctx, zlib_obj, "unzipSync", zlib_unzipSync_cb);
    reg_method(ctx, zlib_obj, "brotliDecompressSync", zlib_brotliDecompressSync_cb);
    reg_method(ctx, zlib_obj, "brotliCompressSync", zlib_brotliCompressSync_cb);

    /* Store as global for JS wrapper to reference */
    JSStringRef k = JSStringCreateWithUTF8CString("__zlib_native");
    JSObjectSetProperty(ctx, JSContextGetGlobalObject(ctx), k, zlib_obj, 0, NULL);
    JSStringRelease(k);
}

/* ============================================================================
 * Main entry point
 * ============================================================================ */

void register_node_extras(JSContextRef ctx, JSObjectRef global) {
    /* Register native zlib callbacks first */
    register_zlib_module(ctx);

    /*
     * Inject everything in a single large JS eval to avoid issues with
     * JSObjectSetProperty losing function references.
     */

    const char* extras_code =
        "(function() {\n"
        /* ---- 1. zlib module with real native + JS wrappers ---- */
        "  var _native = __zlib_native;\n"
        "  var zlib = {\n"
        "    deflateSync: function(buf, opts) { return _native.deflateSync(buf); },\n"
        "    inflateSync: function(buf, opts) { return _native.inflateSync(buf); },\n"
        "    deflateRawSync: function(buf, opts) { return _native.deflateRawSync(buf); },\n"
        "    inflateRawSync: function(buf, opts) { return _native.inflateRawSync(buf); },\n"
        "    gzipSync: function(buf, opts) { return _native.gzipSync(buf); },\n"
        "    gunzipSync: function(buf, opts) { return _native.gunzipSync(buf); },\n"
        "    unzipSync: function(buf, opts) { return _native.unzipSync(buf); },\n"
        "    brotliCompressSync: function(buf, opts) { return _native.brotliCompressSync(buf); },\n"
        "    brotliDecompressSync: function(buf, opts) { return _native.brotliDecompressSync(buf); },\n"
        /* Async wrappers that call sync versions */
        "    deflate: function(buf, opts, cb) {\n"
        "      if (typeof opts === 'function') { cb = opts; opts = {}; }\n"
        "      try { var r = _native.deflateSync(buf); if (cb) cb(null, r); return; }\n"
        "      catch(e) { if (cb) cb(e); return; }\n"
        "    },\n"
        "    inflate: function(buf, opts, cb) {\n"
        "      if (typeof opts === 'function') { cb = opts; opts = {}; }\n"
        "      try { var r = _native.inflateSync(buf); if (cb) cb(null, r); return; }\n"
        "      catch(e) { if (cb) cb(e); return; }\n"
        "    },\n"
        "    gzip: function(buf, opts, cb) {\n"
        "      if (typeof opts === 'function') { cb = opts; opts = {}; }\n"
        "      try { var r = _native.gzipSync(buf); if (cb) cb(null, r); return; }\n"
        "      catch(e) { if (cb) cb(e); return; }\n"
        "    },\n"
        "    gunzip: function(buf, opts, cb) {\n"
        "      if (typeof opts === 'function') { cb = opts; opts = {}; }\n"
        "      try { var r = _native.gunzipSync(buf); if (cb) cb(null, r); return; }\n"
        "      catch(e) { if (cb) cb(e); return; }\n"
        "    },\n"
        "    unzip: function(buf, opts, cb) {\n"
        "      if (typeof opts === 'function') { cb = opts; opts = {}; }\n"
        "      try { var r = _native.unzipSync(buf); if (cb) cb(null, r); return; }\n"
        "      catch(e) { if (cb) cb(e); return; }\n"
        "    },\n"
        "    brotliCompress: function(buf, opts, cb) {\n"
        "      if (typeof opts === 'function') { cb = opts; opts = {}; }\n"
        "      try { var r = _native.brotliCompressSync(buf); if (cb) cb(null, r); return; }\n"
        "      catch(e) { if (cb) cb(e); return; }\n"
        "    },\n"
        "    brotliDecompress: function(buf, opts, cb) {\n"
        "      if (typeof opts === 'function') { cb = opts; opts = {}; }\n"
        "      try { var r = _native.brotliDecompressSync(buf); if (cb) cb(null, r); return; }\n"
        "      catch(e) { if (cb) cb(e); return; }\n"
        "    },\n"
        /* create* functions returning stream-like objects with _handle.writeSync */
        "    createDeflate: function(opts) {\n"
        "      return _makeZlibStream('deflate', opts);\n"
        "    },\n"
        "    createInflate: function(opts) {\n"
        "      return _makeZlibStream('inflate', opts);\n"
        "    },\n"
        "    createDeflateRaw: function(opts) {\n"
        "      return _makeZlibStream('deflateRaw', opts);\n"
        "    },\n"
        "    createInflateRaw: function(opts) {\n"
        "      return _makeZlibStream('inflateRaw', opts);\n"
        "    },\n"
        "    createGzip: function(opts) {\n"
        "      return _makeZlibStream('gzip', opts);\n"
        "    },\n"
        "    createGunzip: function(opts) {\n"
        "      return _makeZlibStream('gunzip', opts);\n"
        "    },\n"
        "    createUnzip: function(opts) {\n"
        "      return _makeZlibStream('unzip', opts);\n"
        "    },\n"
        "    createBrotliCompress: function(opts) {\n"
        "      return _makeZlibStream('brotliCompress', opts);\n"
        "    },\n"
        "    createBrotliDecompress: function(opts) {\n"
        "      return _makeZlibStream('brotliDecompress', opts);\n"
        "    },\n"
        /* Zstd stubs */
        "    zstdCompressSync: function(buf, opts) { return buf; },\n"
        "    zstdDecompressSync: function(buf, opts) { return buf; },\n"
        "    createZstdCompress: function(opts) { return _makeZlibStream('zstdCompress', opts); },\n"
        "    createZstdDecompress: function(opts) { return _makeZlibStream('zstdDecompress', opts); },\n"
        "    zstdCompress: function(buf, opts, cb) {\n"
        "      if (typeof opts === 'function') { cb = opts; } if (cb) cb(null, buf);\n"
        "    },\n"
        "    zstdDecompress: function(buf, opts, cb) {\n"
        "      if (typeof opts === 'function') { cb = opts; } if (cb) cb(null, buf);\n"
        "    },\n"
        /* kMaxLength property */
        "    kMaxLength: 1073741823,\n"
        /* Constants */
        "    constants: {\n"
        "      Z_OK: 0, Z_STREAM_END: 1, Z_NEED_DICT: 2,\n"
        "      Z_ERRNO: -1, Z_STREAM_ERROR: -2, Z_DATA_ERROR: -3,\n"
        "      Z_MEM_ERROR: -4, Z_BUF_ERROR: -5, Z_VERSION_ERROR: -6,\n"
        "      Z_NO_FLUSH: 0, Z_PARTIAL_FLUSH: 1, Z_SYNC_FLUSH: 2,\n"
        "      Z_FULL_FLUSH: 3, Z_FINISH: 4, Z_BLOCK: 5, Z_TREES: 6,\n"
        "      Z_FILTERED: 1, Z_HUFFMAN_ONLY: 2, Z_RLE: 3, Z_FIXED: 4,\n"
        "      Z_DEFAULT_STRATEGY: 0,\n"
        "      Z_BINARY: 0, Z_TEXT: 1, Z_ASCII: 1, Z_UNKNOWN: 2,\n"
        "      Z_DEFLATED: 8,\n"
        "      Z_DEFAULT_COMPRESSION: -1, Z_NO_COMPRESSION: 0,\n"
        "      Z_BEST_SPEED: 1, Z_BEST_COMPRESSION: 9,\n"
        "      BROTLI_DECODE: 0, BROTLI_ENCODE: 1,\n"
        "      BROTLI_OPERATION_PROCESS: 0, BROTLI_OPERATION_FLUSH: 1,\n"
        "      BROTLI_OPERATION_FINISH: 2, BROTLI_OPERATION_EMIT_METADATA: 3,\n"
        "      BROTLI_PARAM_MODE: 0, BROTLI_PARAM_QUALITY: 1,\n"
        "      BROTLI_PARAM_LGWIN: 2, BROTLI_PARAM_LGBLOCK: 3,\n"
        "      BROTLI_PARAM_DISABLE_LITERAL_CONTEXT_MODELING: 4,\n"
        "      BROTLI_PARAM_SIZE_HINT: 5,\n"
        "      BROTLI_PARAM_LARGE_WINDOW: 6,\n"
        "      BROTLI_PARAM_NPOSTFIX: 7,\n"
        "      BROTLI_PARAM_NDIRECT: 8,\n"
        "      BROTLI_MODE_GENERIC: 0, BROTLI_MODE_TEXT: 1, BROTLI_MODE_FONT: 2,\n"
        "      BROTLI_DEFAULT_QUALITY: 11, BROTLI_DEFAULT_WINDOW: 22,\n"
        "      BROTLI_DEFAULT_MODE: 0,\n"
        "      BROTLI_MIN_WINDOW_BITS: 10, BROTLI_MAX_WINDOW_BITS: 24,\n"
        "      BROTLI_MIN_INPUT_BITS: 16, BROTLI_MAX_INPUT_BITS: 24,\n"
        "      BROTLI_MIN_QUALITY: 0, BROTLI_MAX_QUALITY: 11,\n"
        "      ZSTD_VERSION: '1.5.0',\n"
        "      ZSTD_MIN_COMPRESSION_LEVEL: -131072,\n"
        "      ZSTD_MAX_COMPRESSION_LEVEL: 22,\n"
        "      ZSTD_DEFAULT_COMPRESSION_LEVEL: 3\n"
        "    }\n"
        "  };\n"
        "\n"
        /* ---- Zlib/Brotli/Zstd class constructors ---- */
        "  function Zlib() {}\n"
        "  function Brotli() {}\n"
        "  function Zstd() {}\n"
        "\n"
        "  zlib.Deflate = function(opts) {\n"
        "    if (!(this instanceof zlib.Deflate)) return new zlib.Deflate(opts);\n"
        "    this._opts = opts || {};\n"
        "    this.bytesWritten = 0;\n"
        "    this._handle = _makeHandle('deflate', this._opts);\n"
        "    this._pendingClose = true;\n"
        "  };\n"
        "  zlib.Deflate.prototype = Object.create(Zlib.prototype);\n"
        "  zlib.Deflate.prototype.constructor = zlib.Deflate;\n"
        "  zlib.Deflate.__proto__ = Zlib;\n"
        "\n"
        "  zlib.Inflate = function(opts) {\n"
        "    if (!(this instanceof zlib.Inflate)) return new zlib.Inflate(opts);\n"
        "    this._opts = opts || {};\n"
        "    this.bytesWritten = 0;\n"
        "    this._handle = _makeHandle('inflate', this._opts);\n"
        "    this._pendingClose = true;\n"
        "  };\n"
        "  zlib.Inflate.prototype = Object.create(Zlib.prototype);\n"
        "  zlib.Inflate.prototype.constructor = zlib.Inflate;\n"
        "  zlib.Inflate.__proto__ = Zlib;\n"
        "\n"
        "  zlib.DeflateRaw = function(opts) {\n"
        "    if (!(this instanceof zlib.DeflateRaw)) return new zlib.DeflateRaw(opts);\n"
        "    this._opts = opts || {};\n"
        "    this.bytesWritten = 0;\n"
        "    this._handle = _makeHandle('deflateRaw', this._opts);\n"
        "    this._pendingClose = true;\n"
        "  };\n"
        "  zlib.DeflateRaw.prototype = Object.create(Zlib.prototype);\n"
        "  zlib.DeflateRaw.prototype.constructor = zlib.DeflateRaw;\n"
        "  zlib.DeflateRaw.__proto__ = Zlib;\n"
        "\n"
        "  zlib.InflateRaw = function(opts) {\n"
        "    if (!(this instanceof zlib.InflateRaw)) return new zlib.InflateRaw(opts);\n"
        "    this._opts = opts || {};\n"
        "    this.bytesWritten = 0;\n"
        "    this._handle = _makeHandle('inflateRaw', this._opts);\n"
        "    this._pendingClose = true;\n"
        "  };\n"
        "  zlib.InflateRaw.prototype = Object.create(Zlib.prototype);\n"
        "  zlib.InflateRaw.prototype.constructor = zlib.InflateRaw;\n"
        "  zlib.InflateRaw.__proto__ = Zlib;\n"
        "\n"
        "  zlib.Gzip = function(opts) {\n"
        "    if (!(this instanceof zlib.Gzip)) return new zlib.Gzip(opts);\n"
        "    this._opts = opts || {};\n"
        "    this.bytesWritten = 0;\n"
        "    this._handle = _makeHandle('gzip', this._opts);\n"
        "    this._pendingClose = true;\n"
        "  };\n"
        "  zlib.Gzip.prototype = Object.create(Zlib.prototype);\n"
        "  zlib.Gzip.prototype.constructor = zlib.Gzip;\n"
        "  zlib.Gzip.__proto__ = Zlib;\n"
        "\n"
        "  zlib.Gunzip = function(opts) {\n"
        "    if (!(this instanceof zlib.Gunzip)) return new zlib.Gunzip(opts);\n"
        "    this._opts = opts || {};\n"
        "    this.bytesWritten = 0;\n"
        "    this._handle = _makeHandle('gunzip', this._opts);\n"
        "    this._pendingClose = true;\n"
        "  };\n"
        "  zlib.Gunzip.prototype = Object.create(Zlib.prototype);\n"
        "  zlib.Gunzip.prototype.constructor = zlib.Gunzip;\n"
        "  zlib.Gunzip.__proto__ = Zlib;\n"
        "\n"
        "  zlib.Unzip = function(opts) {\n"
        "    if (!(this instanceof zlib.Unzip)) return new zlib.Unzip(opts);\n"
        "    this._opts = opts || {};\n"
        "    this.bytesWritten = 0;\n"
        "    this._handle = _makeHandle('unzip', this._opts);\n"
        "    this._pendingClose = true;\n"
        "  };\n"
        "  zlib.Unzip.prototype = Object.create(Zlib.prototype);\n"
        "  zlib.Unzip.prototype.constructor = zlib.Unzip;\n"
        "  zlib.Unzip.__proto__ = Zlib;\n"
        "\n"
        "  zlib.BrotliCompress = function(opts) {\n"
        "    if (!(this instanceof zlib.BrotliCompress)) return new zlib.BrotliCompress(opts);\n"
        "    this._opts = opts || {};\n"
        "    this.bytesWritten = 0;\n"
        "    this._handle = _makeHandle('brotliCompress', this._opts);\n"
        "    this._pendingClose = true;\n"
        "  };\n"
        "  zlib.BrotliCompress.prototype = Object.create(Brotli.prototype);\n"
        "  zlib.BrotliCompress.prototype.constructor = zlib.BrotliCompress;\n"
        "  zlib.BrotliCompress.__proto__ = Brotli;\n"
        "\n"
        "  zlib.BrotliDecompress = function(opts) {\n"
        "    if (!(this instanceof zlib.BrotliDecompress)) return new zlib.BrotliDecompress(opts);\n"
        "    this._opts = opts || {};\n"
        "    this.bytesWritten = 0;\n"
        "    this._handle = _makeHandle('brotliDecompress', this._opts);\n"
        "    this._pendingClose = true;\n"
        "  };\n"
        "  zlib.BrotliDecompress.prototype = Object.create(Brotli.prototype);\n"
        "  zlib.BrotliDecompress.prototype.constructor = zlib.BrotliDecompress;\n"
        "  zlib.BrotliDecompress.__proto__ = Brotli;\n"
        "\n"
        "  zlib.ZstdCompress = function(opts) {\n"
        "    if (!(this instanceof zlib.ZstdCompress)) return new zlib.ZstdCompress(opts);\n"
        "    this._opts = opts || {};\n"
        "    this.bytesWritten = 0;\n"
        "    this._handle = _makeHandle('zstdCompress', this._opts);\n"
        "    this._pendingClose = true;\n"
        "  };\n"
        "  zlib.ZstdCompress.prototype = Object.create(Zstd.prototype);\n"
        "  zlib.ZstdCompress.prototype.constructor = zlib.ZstdCompress;\n"
        "  zlib.ZstdCompress.__proto__ = Zstd;\n"
        "\n"
        "  zlib.ZstdDecompress = function(opts) {\n"
        "    if (!(this instanceof zlib.ZstdDecompress)) return new zlib.ZstdDecompress(opts);\n"
        "    this._opts = opts || {};\n"
        "    this.bytesWritten = 0;\n"
        "    this._handle = _makeHandle('zstdDecompress', this._opts);\n"
        "    this._pendingClose = true;\n"
        "  };\n"
        "  zlib.ZstdDecompress.prototype = Object.create(Zstd.prototype);\n"
        "  zlib.ZstdDecompress.prototype.constructor = zlib.ZstdDecompress;\n"
        "  zlib.ZstdDecompress.__proto__ = Zstd;\n"
        "\n"
        /* ---- Set .name on all constructors ---- */
        "  ['Deflate','Inflate','DeflateRaw','InflateRaw','Gzip','Gunzip','Unzip',\n"
        "   'BrotliCompress','BrotliDecompress','ZstdCompress','ZstdDecompress'].forEach(function(n) {\n"
        "    Object.defineProperty(zlib[n], 'name', { value: n, configurable: true });\n"
        "  });\n"
        "  Object.defineProperty(Zlib, 'name', { value: 'Zlib', configurable: true });\n"
        "  Object.defineProperty(Brotli, 'name', { value: 'Brotli', configurable: true });\n"
        "  Object.defineProperty(Zstd, 'name', { value: 'Zstd', configurable: true });\n"
        "\n"
        /* ---- _makeHandle: creates an object with writeSync that does bounds checking ---- */
        "  function _makeHandle(mode, opts) {\n"
        "    var h = {\n"
        "      mode: mode,\n"
        "      buffer: null,\n"
        "      cb: null,\n"
        "      availOutBefore: 0,\n"
        "      availInBefore: 0,\n"
        "      inOff: 0,\n"
        "      flushFlag: 0,\n"
        /* writeSync with bounds checking */
        "      writeSync: function(flush, inBuf, inOff, inLen, outBuf, outOff, outLen) {\n"
        "        /* Bounds checking for in_len / out_len */\n"
        "        if (inBuf !== null && inBuf !== undefined) {\n"
        "          var inBLen = inBuf.length;\n"
        "          if (inLen > inBLen) {\n"
        "            throw new RangeError('in_len exceeds input buffer length');\n"
        "          }\n"
        "          if (inOff + inLen > inBLen) {\n"
        "            throw new RangeError('in_off + in_len exceeds input buffer length');\n"
        "          }\n"
        "        }\n"
        "        if (outBuf !== null && outBuf !== undefined) {\n"
        "          var outBLen = outBuf.length;\n"
        "          if (outLen > outBLen) {\n"
        "            throw new RangeError('out_len exceeds output buffer length');\n"
        "          }\n"
        "          if (outOff + outLen > outBLen) {\n"
        "            throw new RangeError('out_off + out_len exceeds output buffer length');\n"
        "          }\n"
        "        }\n"
        /* Extract the slice of input data */
        "        var inputData = inBuf;\n"
        "        if (inBuf !== null && inBuf !== undefined && (inOff > 0 || inLen < inBuf.length)) {\n"
        "          inputData = inBuf.slice(inOff, inOff + inLen);\n"
        "        }\n"
        /* Do the actual compression/decompression */
        "        var result;\n"
        "        try {\n"
        "          if (mode === 'deflate' || mode === 'gzip' || mode === 'deflateRaw') {\n"
        "            result = _native.deflateSync(inputData);\n"
        "          } else if (mode === 'inflate' || mode === 'gunzip' || mode === 'unzip' || mode === 'inflateRaw') {\n"
        "            result = _native.inflateSync(inputData);\n"
        "          } else if (mode === 'brotliCompress') {\n"
        "            result = _native.brotliCompressSync(inputData);\n"
        "          } else if (mode === 'brotliDecompress') {\n"
        "            result = _native.brotliDecompressSync(inputData);\n"
        "          } else {\n"
        "            result = inputData;\n"
        "          }\n"
        "        } catch(e) {\n"
        "          if (this.cb) this.cb(e);\n"
        "          return;\n"
        "        }\n"
        /* Copy result into output buffer */
        "        if (outBuf && result) {\n"
        "          var copyLen = Math.min(result.length, outLen);\n"
        "          for (var i = 0; i < copyLen; i++) {\n"
        "            outBuf[outOff + i] = result[i];\n"
        "          }\n"
        "        }\n"
        "        if (this.cb) this.cb(null);\n"
        "        return result ? result.length : 0;\n"
        "      },\n"
        /* write (async version - just calls writeSync) */
        "      write: function(flush, inBuf, inOff, inLen, outBuf, outOff, outLen) {\n"
        "        return this.writeSync(flush, inBuf, inOff, inLen, outBuf, outOff, outLen);\n"
        "      },\n"
        "      close: function() {},\n"
        "      reset: function() {}\n"
        "    };\n"
        "    return h;\n"
        "  }\n"
        "\n"
        /* ---- _makeZlibStream: creates a Transform-like stream object ---- */
        "  function _makeZlibStream(mode, opts) {\n"
        "    var chunks = [];\n"
        "    var ended = false;\n"
        "    var stream = {\n"
        "      _handle: _makeHandle(mode, opts),\n"
        "      bytesWritten: 0,\n"
        "      _chunks: chunks,\n"
        "      _ended: ended,\n"
        "      _mode: mode,\n"
        "      _encoding: null,\n"
        "      setEncoding: function(enc) { this._encoding = enc; },\n"
        "      push: function(chunk) {\n"
        "        if (chunk === null) {\n"
        "          this.end();\n"
        "          return;\n"
        "        }\n"
        "        var data = (typeof chunk === 'string') ? Buffer.from(chunk) : chunk;\n"
        "        this.bytesWritten += data.length;\n"
        /* Compress/decompress the chunk */
        "        var result;\n"
        "        try {\n"
        "          if (this._mode === 'deflate') result = _native.deflateSync(data);\n"
        "          else if (this._mode === 'inflate') result = _native.inflateSync(data);\n"
        "          else if (this._mode === 'deflateRaw') result = _native.deflateRawSync(data);\n"
        "          else if (this._mode === 'inflateRaw') result = _native.inflateRawSync(data);\n"
        "          else if (this._mode === 'gzip') result = _native.gzipSync(data);\n"
        "          else if (this._mode === 'gunzip') result = _native.gunzipSync(data);\n"
        "          else if (this._mode === 'unzip') result = _native.unzipSync(data);\n"
        "          else if (this._mode === 'brotliCompress') result = _native.brotliCompressSync(data);\n"
        "          else if (this._mode === 'brotliDecompress') result = _native.brotliDecompressSync(data);\n"
        "          else result = data;\n"
        "        } catch(e) { return; }\n"
        "        chunks.push(result);\n"
        "      },\n"
        "      write: function(chunk, enc, cb) {\n"
        "        this.push(chunk);\n"
        "        if (typeof enc === 'function') enc();\n"
        "        if (typeof cb === 'function') cb();\n"
        "        return true;\n"
        "      },\n"
        "      end: function(chunk, enc, cb) {\n"
        "        if (chunk) this.push(chunk);\n"
        "        this._ended = true;\n"
        "        if (typeof enc === 'function') enc();\n"
        "        if (typeof cb === 'function') cb();\n"
        "        return this;\n"
        "      },\n"
        "      on: function(evt, fn) {\n"
        "        if (evt === 'end' && this._ended) { fn(); return this; }\n"
        "        if (evt === 'finish' && this._ended) { fn(); return this; }\n"
        "        return this;\n"
        "      },\n"
        "      pipe: function(dest) { return dest; },\n"
        "      close: function() { this._ended = true; },\n"
        /* Make stream work as Response body (text/bytes) */
        "      text: function() {\n"
        "        var all = this._chunks;\n"
        "        var s = '';\n"
        "        for (var i = 0; i < all.length; i++) {\n"
        "          for (var j = 0; j < all[i].length; j++) {\n"
        "            s += String.fromCharCode(all[i][j]);\n"
        "          }\n"
        "        }\n"
        "        return Promise.resolve(s);\n"
        "      },\n"
        "      bytes: function() {\n"
        "        var total = 0;\n"
        "        for (var i = 0; i < this._chunks.length; i++) total += this._chunks[i].length;\n"
        "        var r = new Uint8Array(total);\n"
        "        var off = 0;\n"
        "        for (var i = 0; i < this._chunks.length; i++) {\n"
        "          for (var j = 0; j < this._chunks[i].length; j++) r[off++] = this._chunks[i][j];\n"
        "        }\n"
        "        return Promise.resolve(r);\n"
        "      },\n"
        "      getReader: function() {\n"
        "        var self = this;\n"
        "        var done = false;\n"
        "        return {\n"
        "          read: function() {\n"
        "            if (done) return Promise.resolve({done: true, value: undefined});\n"
        "            done = true;\n"
        "            var total = 0;\n"
        "            for (var i = 0; i < self._chunks.length; i++) total += self._chunks[i].length;\n"
        "            var r = new Uint8Array(total);\n"
        "            var off = 0;\n"
        "            for (var i = 0; i < self._chunks.length; i++) {\n"
        "              for (var j = 0; j < self._chunks[i].length; j++) r[off++] = self._chunks[i][j];\n"
        "            }\n"
        "            return Promise.resolve({done: false, value: r});\n"
        "          },\n"
        "          cancel: function() {}\n"
        "        };\n"
        "      }\n"
        "    };\n"
        "    return stream;\n"
        "  }\n"
        "\n"
        /* ---- 2. Buffer extensions ---- */
        "  if (typeof Buffer !== 'undefined') {\n"
        "    Buffer.compare = function(a, b) {\n"
        "      var al = a.length, bl = b.length;\n"
        "      var len = al < bl ? al : bl;\n"
        "      for (var i = 0; i < len; i++) {\n"
        "        var va = a[i] || 0, vb = b[i] || 0;\n"
        "        if (va < vb) return -1;\n"
        "        if (va > vb) return 1;\n"
        "      }\n"
        "      return al < bl ? -1 : al > bl ? 1 : 0;\n"
        "    };\n"
        "    Buffer.isBuffer = function(b) {\n"
        "      return b && typeof b === 'object' && b.length !== undefined;\n"
        "    };\n"
        "    Buffer.concat = function(list, totalLength) {\n"
        "      if (!list || list.length === 0) {\n"
        "        var empty = new Array(0);\n"
        "        empty.length = 0;\n"
        "        return empty;\n"
        "      }\n"
        "      if (!totalLength) {\n"
        "        totalLength = 0;\n"
        "        for (var i = 0; i < list.length; i++) totalLength += list[i].length;\n"
        "      }\n"
        "      var result = new Array(totalLength);\n"
        "      var offset = 0;\n"
        "      for (var i = 0; i < list.length; i++) {\n"
        "        for (var j = 0; j < list[i].length; j++) {\n"
        "          result[offset++] = list[i][j];\n"
        "        }\n"
        "      }\n"
        "      result.length = totalLength;\n"
        "      result.toString = function(enc) {\n"
        "        var s = '';\n"
        "        for (var k = 0; k < this.length; k++) s += String.fromCharCode(this[k]);\n"
        "        return s;\n"
        "      };\n"
        "      return result;\n"
        "    };\n"
        "    Buffer.byteLength = function(str, enc) {\n"
        "      if (typeof str !== 'string') return 0;\n"
        "      try {\n"
        "        return (new TextEncoder().encode(str)).length;\n"
        "      } catch(e) {\n"
        "        return str.length;\n"
        "      }\n"
        "    };\n"
        "  }\n"
        "\n"
        /* ---- 3. Buffer.prototype.write ---- */
        "  if (typeof Buffer !== 'undefined' && Buffer.from) {\n"
        "    var _bp = Buffer.from('');\n"
        "    if (_bp && !_bp.write) {\n"
        "      var _origFrom = Buffer.from;\n"
        "      Buffer.from = function(arg) {\n"
        "        var r = _origFrom.apply(this, arguments);\n"
        "        if (!r.write) {\n"
        "          r.write = function(str, offset, length) {\n"
        "            offset = offset || 0;\n"
        "            var bytes;\n"
        "            try { bytes = new TextEncoder().encode(str); } catch(e) { bytes = []; for (var k=0;k<str.length;k++) bytes.push(str.charCodeAt(k)); }\n"
        "            var len = length ? Math.min(length, bytes.length) : bytes.length;\n"
        "            for (var i = 0; i < len && (offset + i) < this.length; i++) {\n"
        "              this[offset + i] = bytes[i];\n"
        "            }\n"
        "            return len;\n"
        "          };\n"
        "        }\n"
        "        return r;\n"
        "      };\n"
        "    }\n"
        "  }\n"
        "\n"
        /* ---- 4. process.binding stub ---- */
        "  if (typeof process !== 'undefined' && !process.binding) {\n"
        "    process.binding = function(name) { return {}; };\n"
        "  }\n"
        "\n"
        /* ---- 5. assert extensions ---- */
        "  var _assertExt = function() {};\n"
        "  _assertExt.match = function(string, regexp, message) {\n"
        "    if (!regexp.test(string)) {\n"
        "      throw new Error(message || 'Expected \"' + string + '\" to match ' + regexp);\n"
        "    }\n"
        "  };\n"
        "  _assertExt.doesNotMatch = function(string, regexp, message) {\n"
        "    if (regexp.test(string)) {\n"
        "      throw new Error(message || 'Expected \"' + string + '\" not to match ' + regexp);\n"
        "    }\n"
        "  };\n"
        "  _assertExt.ifError = function(err) {\n"
        "    if (err) throw err;\n"
        "  };\n"
        "  _assertExt.rejects = function(asyncFn, error) {\n"
        "    var p = (typeof asyncFn === 'function') ? asyncFn() : asyncFn;\n"
        "    if (p && typeof p.then === 'function') {\n"
        "      return p.then(function() {\n"
        "        throw new Error('AssertionError: missing expected rejection');\n"
        "      }, function(err) {\n"
        "        if (error && !(err instanceof error)) {\n"
        "          throw new Error('AssertionError: expected rejection of specific type');\n"
        "        }\n"
        "      });\n"
        "    }\n"
        "    return Promise.resolve();\n"
        "  };\n"
        "  _assertExt.doesNotReject = function(asyncFn, error) {\n"
        "    var p = (typeof asyncFn === 'function') ? asyncFn() : asyncFn;\n"
        "    if (p && typeof p.then === 'function') {\n"
        "      return p.then(function() {}, function(err) {\n"
        "        throw new Error('AssertionError: got unwanted rejection: ' + err);\n"
        "      });\n"
        "    }\n"
        "    return Promise.resolve();\n"
        "  };\n"
        "\n"
        /* ---- 6. node:tty module ---- */
        "  var tty = {\n"
        "    isatty: function(fd) { return false; },\n"
        "    WriteStream: function(fd) { this.fd = fd; },\n"
        "    ReadStream: function(fd) { this.fd = fd; }\n"
        "  };\n"
        "\n"
        /* ---- 7. timers module ---- */
        "  var timersModule = {\n"
        "    setTimeout: setTimeout,\n"
        "    setInterval: setInterval,\n"
        "    clearTimeout: clearTimeout,\n"
        "    clearInterval: clearInterval,\n"
        "    setImmediate: typeof setImmediate !== 'undefined' ? setImmediate : function(cb) { Promise.resolve().then(cb); },\n"
        "    clearImmediate: typeof clearImmediate !== 'undefined' ? clearImmediate : function() {}\n"
        "  };\n"
        "\n"
        /* ---- 8. stream module stub ---- */
        "  function _makeStream() { return { on: function() {}, write: function() {}, end: function() {}, pipe: function() {} }; }\n"
        "  var streamModule = {\n"
        "    PassThrough: function() { return _makeStream(); },\n"
        "    Transform: function() { return _makeStream(); },\n"
        "    Readable: function() { return _makeStream(); },\n"
        "    Writable: function() { return _makeStream(); },\n"
        "    Duplex: function() { return _makeStream(); },\n"
        "    finished: function(s, cb) { if (cb) cb(null); },\n"
        "    pipeline: function() { var cb = arguments[arguments.length-1]; if (typeof cb === 'function') cb(null); }\n"
        "  };\n"
        "\n"
        /* ---- 9. child_process stub ---- */
        "  var childProcessModule = {\n"
        "    execSync: function() { return ''; },\n"
        "    exec: function(cmd, opts, cb) { if (typeof opts === 'function') { cb = opts; } if (cb) cb(null, '', ''); },\n"
        "    spawn: function() { return { on: function() {}, stdout: { on: function() {} }, stderr: { on: function() {} } }; },\n"
        "    spawnSync: function() { return { status: 0, stdout: '', stderr: '' }; },\n"
        "    fork: function() { return { on: function() {}, send: function() {} }; }\n"
        "  };\n"
        "\n"
        /* ---- 10. http/https stubs ---- */
        "  var httpModule = {\n"
        "    request: function() { return { on: function() {}, end: function() {} }; },\n"
        "    get: function() { return { on: function() {}, end: function() {} }; },\n"
        "    createServer: function() { return { listen: function() {}, close: function() {}, on: function() {} }; }\n"
        "  };\n"
        "\n"
        /* ---- 11. crypto — use real native crypto global ---- */
        "  var cryptoModule = (typeof crypto !== 'undefined') ? crypto : {\n"
        "    createHash: function() { return { update: function(s) { return this; }, digest: function(enc) { return ''; } }; },\n"
        "    createHmac: function() { return { update: function(s) { return this; }, digest: function(enc) { return ''; } }; },\n"
        "    randomBytes: function(n, cb) { var b = []; for(var i=0;i<n;i++) b.push(0); if(cb) cb(null, b); return b; },\n"
        "    pbkdf2Sync: function() { return []; },\n"
        "    scryptSync: function() { return []; }\n"
        "  };\n"
        "\n"
        /* ---- 12. url module stub ---- */
        "  var urlModule = {\n"
        "    URL: typeof URL !== 'undefined' ? URL : function() {},\n"
        "    URLSearchParams: typeof URLSearchParams !== 'undefined' ? URLSearchParams : function() {},\n"
        "    parse: function(u) { return { href: u, protocol: '', host: '', hostname: '', pathname: u }; },\n"
        "    format: function(u) { return u.href || u; },\n"
        "    resolve: function(b, r) { return r; }\n"
        "  };\n"
        "\n"
        /* ---- 13. Other stubs ---- */
        "  var querystringModule = {\n"
        "    parse: function(s) { var r = {}; if(!s) return r; s.split('&').forEach(function(p) { var kv = p.split('='); r[kv[0]] = kv[1] || ''; }); return r; },\n"
        "    stringify: function(o) { return Object.keys(o).map(function(k) { return k + '=' + o[k]; }).join('&'); }\n"
        "  };\n"
        "  var netModule = {\n"
        "    createServer: function() { return { listen: function() {}, close: function() {}, on: function() {} }; }\n"
        "  };\n"
        "  var dnsModule = {\n"
        "    lookup: function(h, cb) { if(cb) cb(null, '127.0.0.1'); },\n"
        "    resolve: function(h, cb) { if(cb) cb(null, ['127.0.0.1']); }\n"
        "  };\n"
        "  var readlineModule = {\n"
        "    createInterface: function() { return { on: function() {}, close: function() {}, question: function(q, cb) { if(cb) cb(''); } }; }\n"
        "  };\n"
        "  var vmModule = {\n"
        "    runInNewContext: function(c) { return eval(c); },\n"
        "    runInThisContext: function(c) { return eval(c); },\n"
        "    createContext: function() { return {}; },\n"
        "    Script: function(c) { this.runInNewContext = function() { return eval(c); }; }\n"
        "  };\n"
        "  var moduleModule = {\n"
        "    createRequire: function() { return require; }\n"
        "  };\n"
        "  var stringDecoderModule = {\n"
        "    StringDecoder: function() { this.write = function(b) { return b; }, this.end = function() { return ''; }; }\n"
        "  };\n"
        "  var bufferModule = {\n"
        "    Buffer: Buffer\n"
        "  };\n"
        "\n"
        /* ---- Re-wrap require to intercept new module names ---- */
        "  var _prevRequire = require;\n"
        "  var _extraBuiltins = {\n"
        "    'zlib': zlib,\n"
        "    'node:zlib': zlib,\n"
        "    'tty': tty,\n"
        "    'node:tty': tty,\n"
        "    'timers': timersModule,\n"
        "    'node:timers': timersModule,\n"
        "    'stream': streamModule,\n"
        "    'node:stream': streamModule,\n"
        "    'buffer': bufferModule,\n"
        "    'node:buffer': bufferModule,\n"
        "    'child_process': childProcessModule,\n"
        "    'node:child_process': childProcessModule,\n"
        "    'http': httpModule,\n"
        "    'https': httpModule,\n"
        "    'node:http': httpModule,\n"
        "    'node:https': httpModule,\n"
        "    'crypto': cryptoModule,\n"
        "    'node:crypto': cryptoModule,\n"
        "    'url': urlModule,\n"
        "    'node:url': urlModule,\n"
        "    'querystring': querystringModule,\n"
        "    'net': netModule,\n"
        "    'dns': dnsModule,\n"
        "    'readline': readlineModule,\n"
        "    'vm': vmModule,\n"
        "    'module': moduleModule,\n"
        "    'string_decoder': stringDecoderModule,\n"
        "    'perf_hooks': { performance: typeof performance !== 'undefined' ? performance : { now: function() { return 0; } } },\n"
        "    'node:perf_hooks': undefined,\n"
        "    'assert': undefined,\n"
        "    'util': undefined,\n"
        "    'fs': undefined,\n"
        "    'path': undefined,\n"
        "    'events': undefined,\n"
        "    'os': undefined\n"
        "  };\n"
        "\n"
        "  require = function(name) {\n"
        "    if (name && _extraBuiltins[name] !== undefined && _extraBuiltins[name] !== null) {\n"
        "      return _extraBuiltins[name];\n"
        "    }\n"
        "    if (typeof name === 'string' && name.indexOf('node:') === 0) {\n"
        "      var bare = name.substring(5);\n"
        "      try { return _prevRequire(bare); } catch(e) {}\n"
        "      if (_extraBuiltins[bare] !== undefined && _extraBuiltins[bare] !== null) return _extraBuiltins[bare];\n"
        "      return {};\n"
        "    }\n"
        "    return _prevRequire(name);\n"
        "  };\n"
        "  if (_prevRequire.resolve) require.resolve = _prevRequire.resolve;\n"
        "  if (_prevRequire.cache) require.cache = _prevRequire.cache;\n"
        "  if (_prevRequire.builtin) require.builtin = _prevRequire.builtin;\n"
        "\n"
        /* ---- Extend assert module with match/doesNotMatch/etc ---- */
        "  try {\n"
        "    var _assert = require('assert');\n"
        "    if (_assert) {\n"
        "      _assert.match = _assertExt.match;\n"
        "      _assert.doesNotMatch = _assertExt.doesNotMatch;\n"
        "      _assert.ifError = _assertExt.ifError;\n"
        "      _assert.rejects = _assertExt.rejects;\n"
        "      _assert.doesNotReject = _assertExt.doesNotReject;\n"
        "      _assert.notDeepEqual = _assert.notDeepEqual || function(a, b, m) {\n"
        "        function deepEqual(x, y) {\n"
        "          if (x === y) return true;\n"
        "          if (x === null || y === null) return false;\n"
        "          if (typeof x !== 'object' || typeof y !== 'object') return false;\n"
        "          var ka = Object.keys(x), kb = Object.keys(y);\n"
        "          if (ka.length !== kb.length) return false;\n"
        "          for (var i = 0; i < ka.length; i++) { if (!deepEqual(x[ka[i]], y[ka[i]])) return false; }\n"
        "          return true;\n"
        "        }\n"
        "        if (deepEqual(a, b)) throw new Error(m || 'AssertionError: should not be deeply equal');\n"
        "      };\n"
        "      _assert.notStrictEqual = _assert.notStrictEqual || function(a, b, m) {\n"
        "        if (a === b) throw new Error(m || 'AssertionError: should not strictly equal');\n"
        "      };\n"
        "    }\n"
        "  } catch(e) { /* assert module not available yet */ }\n"
        "\n"
        "})()\n";

    eval_js_extras(ctx, extras_code, "node_extras:all");
}
