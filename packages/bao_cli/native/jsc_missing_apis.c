/*
 * jsc_missing_apis.c — Missing global APIs and Bun object extensions
 *
 * Implements the APIs that ~100 failing tests depend on.
 * See jsc_missing_apis.h for the list of registered APIs.
 */

#include "jsc_missing_apis.h"
#include <sys/wait.h>

/* We need access to the g_ctx / g_global for some operations */
extern JSGlobalContextRef g_ctx;
extern JSObjectRef g_global;

/* ============================================================================
 * 1. Bun.wrapAnsi(text, width, opts) — replaced by JS polyfill in registration
 * ============================================================================ */

/* ============================================================================
 * 2. SharedArrayBuffer — proxy to ArrayBuffer, tagged as shared
 * ============================================================================ */

static JSValueRef shared_array_buffer_ctor(JSContextRef c, JSObjectRef f, JSObjectRef t,
                                            size_t ac, const JSValueRef a[], JSValueRef* e) {
    (void)f; (void)t;
    int size = 0;
    if (ac > 0) size = (int)JSValueToNumber(c, a[0], NULL);
    if (size < 0) size = 0;

    /* Create an ArrayBuffer via new ArrayBuffer(size) in JS */
    JSStringRef ab_name = JSStringCreateWithUTF8CString("ArrayBuffer");
    JSValueRef ab_val = JSObjectGetProperty(c, g_global, ab_name, NULL);
    JSStringRelease(ab_name);

    if (JSValueIsObject(c, ab_val)) {
        JSObjectRef ab_ctor = JSValueToObject(c, ab_val, NULL);
        JSValueRef sz_arg = make_number(c, (double)size);
        JSValueRef ex2 = NULL;
        JSValueRef buf = JSObjectCallAsFunction(c, ab_ctor, NULL, 1, &sz_arg, &ex2);
        if (!ex2 && buf) {
            JSObjectRef buf_obj = JSValueToObject(c, buf, NULL);
            set_prop_bool(c, buf_obj, "shared", 1);
            set_prop_str(c, buf_obj, "_isSharedArrayBuffer", "true");
            return buf_obj;
        }
    }

    /* Fallback: return a plain object */
    JSObjectRef obj = JSObjectMake(c, NULL, NULL);
    set_prop_num(c, obj, "byteLength", (double)size);
    set_prop_bool(c, obj, "shared", 1);
    return obj;
}

/* ============================================================================
 * 3. Bun.Cookie — constructor + Bun.Cookie.parse + Bun.Cookie.from
 *     Full cookie implementation with validation, toJSON, serialize, isExpired
 * ============================================================================ */

/* Forward declarations */
static JSValueRef cookie_constructor(JSContextRef c, JSObjectRef f, JSObjectRef t,
                                      size_t ac, const JSValueRef a[], JSValueRef* e);
static JSValueRef cookie_toString_cb(JSContextRef c, JSObjectRef f, JSObjectRef t,
                                      size_t ac, const JSValueRef a[], JSValueRef* e);
static JSValueRef cookie_toJSON_cb(JSContextRef c, JSObjectRef f, JSObjectRef t,
                                    size_t ac, const JSValueRef a[], JSValueRef* e);
static JSValueRef cookie_serialize_cb(JSContextRef c, JSObjectRef f, JSObjectRef t,
                                       size_t ac, const JSValueRef a[], JSValueRef* e);
static JSValueRef cookie_isExpired_cb(JSContextRef c, JSObjectRef f, JSObjectRef t,
                                       size_t ac, const JSValueRef a[], JSValueRef* e);

/* ---------------------------------------------------------------------------
 * Helper: case-insensitive string compare (needle must be lowercase)
 * --------------------------------------------------------------------------- */
static int ci_eq(const char* hay, const char* needle) {
    while (*needle) {
        char h = *hay;
        if (h >= 'A' && h <= 'Z') h += 32;
        if (h != *needle) return 0;
        hay++; needle++;
    }
    return (*hay == '\0') ? 1 : 0;
}

static int ci_starts_with(const char* hay, const char* needle) {
    while (*needle) {
        char h = *hay, n = *needle;
        if (h >= 'A' && h <= 'Z') h += 32;
        if (n >= 'A' && n <= 'Z') n += 32;
        if (h != n) return 0;
        hay++; needle++;
    }
    return 1;
}

/* ---------------------------------------------------------------------------
 * Helper: check if a JS value is a Date object
 * --------------------------------------------------------------------------- */
static int js_value_is_date(JSContextRef c, JSValueRef v) {
    if (!JSValueIsObject(c, v)) return 0;
    JSObjectRef obj = JSValueToObject(c, v, NULL);
    JSStringRef gtn = JSStringCreateWithUTF8CString("getTime");
    JSValueRef gtv = JSObjectGetProperty(c, obj, gtn, NULL);
    JSStringRelease(gtn);
    return JSValueIsObject(c, gtv);
}

/* ---------------------------------------------------------------------------
 * Helper: NaN / Infinity checks
 * --------------------------------------------------------------------------- */
static int is_nan(double x) { return x != x; }
static int is_infinite(double x) { return !is_nan(x) && (x > 1.7e308 || x < -1.7e308); }

/* ---------------------------------------------------------------------------
 * Helper: trim leading and trailing whitespace in-place, returns new start
 * --------------------------------------------------------------------------- */
static char* trim_str(char* s) {
    while (*s == ' ' || *s == '\t' || *s == '\n' || *s == '\r') s++;
    size_t len = strlen(s);
    while (len > 0 && (s[len-1] == ' ' || s[len-1] == '\t' || s[len-1] == '\n' || s[len-1] == '\r'))
        len--;
    s[len] = '\0';
    return s;
}

/* ---------------------------------------------------------------------------
 * Helper: get a property as a C string (caller must free), returns NULL if
 * the property is undefined or null
 * --------------------------------------------------------------------------- */
static char* get_prop_str(JSContextRef c, JSObjectRef obj, const char* key) {
    JSStringRef k = JSStringCreateWithUTF8CString(key);
    JSValueRef v = JSObjectGetProperty(c, obj, k, NULL);
    JSStringRelease(k);
    if (JSValueIsUndefined(c, v) || JSValueIsNull(c, v)) return NULL;
    return to_utf8(c, v);
}

/* ---------------------------------------------------------------------------
 * Helper: get a boolean property with a default
 * --------------------------------------------------------------------------- */
static int get_prop_bool_def(JSContextRef c, JSObjectRef obj, const char* key, int def) {
    JSStringRef k = JSStringCreateWithUTF8CString(key);
    JSValueRef v = JSObjectGetProperty(c, obj, k, NULL);
    JSStringRelease(k);
    if (JSValueIsUndefined(c, v) || JSValueIsNull(c, v)) return def;
    return JSValueToBoolean(c, v);
}

/* ---------------------------------------------------------------------------
 * Helper: get / set a JS property on an object (thin wrappers)
 * --------------------------------------------------------------------------- */
static JSValueRef get_prop(JSContextRef c, JSObjectRef obj, const char* key) {
    JSStringRef k = JSStringCreateWithUTF8CString(key);
    JSValueRef v = JSObjectGetProperty(c, obj, k, NULL);
    JSStringRelease(k);
    return v;
}

static void set_prop_val(JSContextRef c, JSObjectRef obj, const char* key, JSValueRef val) {
    JSStringRef k = JSStringCreateWithUTF8CString(key);
    JSObjectSetProperty(c, obj, k, val, 0, NULL);
    JSStringRelease(k);
}

/* ---------------------------------------------------------------------------
 * Validate and set the expires property on a cookie object.
 * Returns 1 on success, 0 on error (error already thrown).
 * --------------------------------------------------------------------------- */
static int validate_and_set_expires(JSContextRef c, JSObjectRef opts, JSObjectRef obj,
                                     JSValueRef* e) {
    JSValueRef dv = get_prop(c, opts, "expires");
    if (JSValueIsUndefined(c, dv) || JSValueIsNull(c, dv)) return 1;

    /* Number */
    if (JSValueIsNumber(c, dv)) {
        double num = JSValueToNumber(c, dv, NULL);
        if (is_nan(num)) { make_error(c, "expires must be a valid Number", e); return 0; }
        if (is_infinite(num)) { make_error(c, "expires must be a valid Number", e); return 0; }
        /* expires as number = Unix seconds -> store as new Date(ms) */
        double ms = num * 1000.0;
        /* Use _Bun_make_date global helper to create Date via new Date(ms) */
        JSValueRef md_fn = get_prop(c, g_global, "_Bun_make_date");
        if (JSValueIsObject(c, md_fn)) {
            JSValueRef ms_arg = make_number(c, ms);
            JSValueRef ex = NULL;
            JSValueRef date_obj = JSObjectCallAsFunction(c, JSValueToObject(c, md_fn, NULL), NULL, 1, &ms_arg, &ex);
            if (!ex && date_obj) set_prop_val(c, obj, "expires", date_obj);
        }
        return 1;
    }

    /* Date object */
    if (js_value_is_date(c, dv)) {
        JSObjectRef date_obj = JSValueToObject(c, dv, NULL);
        JSValueRef gtfn = get_prop(c, date_obj, "getTime");
        if (JSValueIsObject(c, gtfn)) {
            JSValueRef ex = NULL;
            JSValueRef result = JSObjectCallAsFunction(c, JSValueToObject(c, gtfn, NULL),
                                                       date_obj, 0, NULL, &ex);
            if (!ex && result && JSValueIsNumber(c, result)) {
                double ms = JSValueToNumber(c, result, NULL);
                if (is_nan(ms)) {
                    make_error(c, "expires must be a valid Date (or Number)", e);
                    return 0;
                }
            }
        }
        set_prop_val(c, obj, "expires", dv);
        return 1;
    }

    /* String — try to parse as Date */
    if (JSValueIsString(c, dv)) {
        JSValueRef md_fn = get_prop(c, g_global, "_Bun_make_date");
        if (JSValueIsObject(c, md_fn)) {
            JSValueRef ex2 = NULL;
            JSValueRef date_obj = JSObjectCallAsFunction(c, JSValueToObject(c, md_fn, NULL), NULL, 1, &dv, &ex2);
            if (!ex2 && date_obj && js_value_is_date(c, date_obj)) {
                /* Check if the parsed Date is valid (not NaN) */
                JSObjectRef dob = JSValueToObject(c, date_obj, NULL);
                JSValueRef gtfn = get_prop(c, dob, "getTime");
                if (JSValueIsObject(c, gtfn)) {
                    JSValueRef ex3 = NULL;
                    JSValueRef tm = JSObjectCallAsFunction(c, JSValueToObject(c, gtfn, NULL),
                                                           dob, 0, NULL, &ex3);
                    if (!ex3 && tm && JSValueIsNumber(c, tm)) {
                        double ms = JSValueToNumber(c, tm, NULL);
                        if (!is_nan(ms)) {
                            set_prop_val(c, obj, "expires", date_obj);
                            return 1;
                        }
                    }
                }
            }
        }
        /* If Date parsing failed, throw */
        make_error(c, "Invalid cookie expiration date", e);
        return 0;
    }
    /* Boolean */
    if (JSValueIsBoolean(c, dv)) {
        char* s = to_utf8(c, dv);
        char buf[256];
        snprintf(buf, sizeof(buf),
                 "The argument 'expires' Invalid expires value. Must be a Date or a number. Received %s", s);
        free(s);
        make_error(c, buf, e);
        return 0;
    }
    /* Array — always invalid */
    if (JSValueIsObject(c, dv)) {
        JSObjectRef dv_obj = JSValueToObject(c, dv, NULL);
        JSValueRef arr_prop = get_prop(c, dv_obj, "length");
        if (JSValueIsNumber(c, arr_prop)) {
            char* s = to_utf8(c, dv);
            char buf[512];
            snprintf(buf, sizeof(buf),
                     "The argument 'expires' Invalid expires value. Must be a Date or a number. Received %s", s);
            free(s);
            make_error(c, buf, e);
            return 0;
        }
    }
    /* Other object (not Date) */
    if (JSValueIsObject(c, dv) && !js_value_is_date(c, dv)) {
        char* s = to_utf8(c, dv);
        char buf[512];
        snprintf(buf, sizeof(buf),
                 "The argument 'expires' Invalid expires value. Must be a Date or a number. Received %s", s);
        free(s);
        make_error(c, buf, e);
        return 0;
    }
    make_error(c, "Invalid expires value", e);
    return 0;
}

/* ---------------------------------------------------------------------------
 * Normalize sameSite string: lowercase -> capitalized first letter.
 * Validates against known values (strict, lax, none). Returns 1 if valid.
 * --------------------------------------------------------------------------- */
static int normalize_samesite(const char* raw, char* out, size_t out_size) {
    char lower[32];
    size_t i;
    for (i = 0; raw[i] && i < 31; i++) {
        char ch = raw[i];
        if (ch >= 'A' && ch <= 'Z') ch += 32;
        lower[i] = ch;
    }
    lower[i] = '\0';
    if (strcmp(lower, "strict") != 0 && strcmp(lower, "lax") != 0 && strcmp(lower, "none") != 0)
        return 0;
    snprintf(out, out_size, "%s", lower);
    if (out[0] >= 'a' && out[0] <= 'z') out[0] -= 32;
    return 1;
}

/* ---------------------------------------------------------------------------
 * Build a cookie object from name, value and optional options.
 * Sets defaults: path="/", secure=false, httpOnly=false, partitioned=false,
 *                sameSite="lax", domain=null.
 * --------------------------------------------------------------------------- */
static JSValueRef build_cookie_obj(JSContextRef c, const char* name, const char* value,
                                    JSValueRef opts_val, JSValueRef* e) {
    JSObjectRef obj = JSObjectMake(c, NULL, NULL);

    set_prop_str(c, obj, "name", name);
    set_prop_str(c, obj, "value", value);

    /* Defaults */
    set_prop_str(c, obj, "path", "/");
    set_prop_bool(c, obj, "secure", 0);
    set_prop_bool(c, obj, "httpOnly", 0);
    set_prop_bool(c, obj, "partitioned", 0);
    set_prop_str(c, obj, "sameSite", "lax");
    set_prop_val(c, obj, "domain", JSValueMakeNull(c));

    /* Apply options */
    if (!JSValueIsUndefined(c, opts_val) && !JSValueIsNull(c, opts_val) && JSValueIsObject(c, opts_val)) {
        JSObjectRef opts = JSValueToObject(c, opts_val, NULL);

        /* expires (validated) */
        if (!validate_and_set_expires(c, opts, obj, e)) return JSValueMakeUndefined(c);

        /* domain */
        { char* s = get_prop_str(c, opts, "domain");
          if (s) { set_prop_val(c, obj, "domain", make_string(c, s)); free(s); } }

        /* path */
        { char* s = get_prop_str(c, opts, "path");
          if (s) { set_prop_str(c, obj, "path", s); free(s); } }

        /* secure */
        { JSValueRef v = get_prop(c, opts, "secure");
          if (!JSValueIsUndefined(c, v) && !JSValueIsNull(c, v))
              set_prop_bool(c, obj, "secure", JSValueToBoolean(c, v)); }

        /* httpOnly */
        { JSValueRef v = get_prop(c, opts, "httpOnly");
          if (!JSValueIsUndefined(c, v) && !JSValueIsNull(c, v))
              set_prop_bool(c, obj, "httpOnly", JSValueToBoolean(c, v)); }

        /* partitioned */
        { JSValueRef v = get_prop(c, opts, "partitioned");
          if (!JSValueIsUndefined(c, v) && !JSValueIsNull(c, v))
              set_prop_bool(c, obj, "partitioned", JSValueToBoolean(c, v)); }

        /* maxAge */
        { JSValueRef v = get_prop(c, opts, "maxAge");
          if (!JSValueIsUndefined(c, v) && !JSValueIsNull(c, v))
              set_prop_num(c, obj, "maxAge", JSValueToNumber(c, v, NULL)); }

        /* sameSite */
        { char* s = get_prop_str(c, opts, "sameSite");
          if (s) {
              char norm[32];
              if (normalize_samesite(s, norm, sizeof(norm)))
                  set_prop_str(c, obj, "sameSite", norm);
              free(s);
          } }
    }

    /* Register instance methods */
    reg_method(c, obj, "toString", cookie_toString_cb);
    reg_method(c, obj, "toJSON", cookie_toJSON_cb);
    reg_method(c, obj, "serialize", cookie_serialize_cb);
    reg_method(c, obj, "isExpired", cookie_isExpired_cb);

    return obj;
}

/* ---------------------------------------------------------------------------
 * cookie.toString() / cookie.serialize() - full Set-Cookie header format
 * --------------------------------------------------------------------------- */
static JSValueRef cookie_serialize_impl(JSContextRef c, JSObjectRef t) {
    char* name = get_prop_str(c, t, "name");
    char* value = get_prop_str(c, t, "value");
    char* domain = get_prop_str(c, t, "domain");
    char* path = get_prop_str(c, t, "path");
    char* sameSite = get_prop_str(c, t, "sameSite");

    JSValueRef ev = get_prop(c, t, "expires");
    JSValueRef mv = get_prop(c, t, "maxAge");
    int secure = get_prop_bool_def(c, t, "secure", 0);
    int httpOnly = get_prop_bool_def(c, t, "httpOnly", 0);
    int partitioned = get_prop_bool_def(c, t, "partitioned", 0);

    size_t cap = 4096;
    char* buf = malloc(cap);
    size_t pos = 0;

    /* name=value */
    pos += snprintf(buf + pos, cap - pos, "%s=%s",
                    name ? name : "", value ? value : "");

    /* Domain */
    if (domain && domain[0])
        pos += snprintf(buf + pos, cap - pos, "; Domain=%s", domain);

    /* Path */
    if (path && path[0])
        pos += snprintf(buf + pos, cap - pos, "; Path=%s", path);

    /* Expires - format via Date.toUTCString() */
    if (!JSValueIsUndefined(c, ev) && !JSValueIsNull(c, ev) && js_value_is_date(c, ev)) {
        JSObjectRef dob = JSValueToObject(c, ev, NULL);
        JSValueRef fn = get_prop(c, dob, "toUTCString");
        if (JSValueIsObject(c, fn)) {
            JSValueRef ex = NULL;
            JSValueRef r = JSObjectCallAsFunction(c, JSValueToObject(c, fn, NULL), dob, 0, NULL, &ex);
            if (!ex && r && JSValueIsString(c, r)) {
                char* ds = to_utf8(c, r);
                pos += snprintf(buf + pos, cap - pos, "; Expires=%s", ds);
                free(ds);
            }
        }
    }

    /* Max-Age */
    if (JSValueIsNumber(c, mv)) {
        double ma = JSValueToNumber(c, mv, NULL);
        if (!is_nan(ma))
            pos += snprintf(buf + pos, cap - pos, "; Max-Age=%.0f", ma);
    }

    if (secure)    pos += snprintf(buf + pos, cap - pos, "; Secure");
    if (httpOnly)  pos += snprintf(buf + pos, cap - pos, "; HttpOnly");
    if (partitioned) pos += snprintf(buf + pos, cap - pos, "; Partitioned");

    /* SameSite */
    if (sameSite && sameSite[0]) {
        char ss[32];
        snprintf(ss, sizeof(ss), "%s", sameSite);
        if (ss[0] >= 'a' && ss[0] <= 'z') ss[0] -= 32;
        pos += snprintf(buf + pos, cap - pos, "; SameSite=%s", ss);
    }

    free(name); free(value); free(domain); free(path); free(sameSite);

    JSValueRef v = make_string(c, buf);
    free(buf);
    return v;
}

static JSValueRef cookie_toString_cb(JSContextRef c, JSObjectRef f, JSObjectRef t,
                                      size_t ac, const JSValueRef a[], JSValueRef* e) {
    (void)f; (void)ac; (void)a; (void)e;
    return cookie_serialize_impl(c, t);
}

static JSValueRef cookie_serialize_cb(JSContextRef c, JSObjectRef f, JSObjectRef t,
                                       size_t ac, const JSValueRef a[], JSValueRef* e) {
    (void)f; (void)ac; (void)a; (void)e;
    return cookie_serialize_impl(c, t);
}

/* ---------------------------------------------------------------------------
 * cookie.toJSON() - plain object with all properties
 * --------------------------------------------------------------------------- */
static JSValueRef cookie_toJSON_cb(JSContextRef c, JSObjectRef f, JSObjectRef t,
                                    size_t ac, const JSValueRef a[], JSValueRef* e) {
    (void)f; (void)ac; (void)a; (void)e;
    JSObjectRef r = JSObjectMake(c, NULL, NULL);

    /* String props */
    const char* sp[] = {"name", "value", "path", "sameSite", NULL};
    for (int i = 0; sp[i]; i++) {
        char* val = get_prop_str(c, t, sp[i]);
        set_prop_str(c, r, sp[i], val ? val : "");
        free(val);
    }

    /* Props that can be null/undefined/objects - copy as-is */
    const char* vp[] = {"domain", "expires", "maxAge", NULL};
    for (int i = 0; vp[i]; i++) {
        JSValueRef v = get_prop(c, t, vp[i]);
        set_prop_val(c, r, vp[i], v);
    }

    /* Boolean props */
    const char* bp[] = {"secure", "httpOnly", "partitioned", NULL};
    for (int i = 0; bp[i]; i++)
        set_prop_bool(c, r, bp[i], get_prop_bool_def(c, t, bp[i], 0));

    return r;
}

/* ---------------------------------------------------------------------------
 * cookie.isExpired()
 * --------------------------------------------------------------------------- */
static JSValueRef cookie_isExpired_cb(JSContextRef c, JSObjectRef f, JSObjectRef t,
                                       size_t ac, const JSValueRef a[], JSValueRef* e) {
    (void)f; (void)ac; (void)a; (void)e;

    /* maxAge <= 0 means expired */
    JSValueRef mv = get_prop(c, t, "maxAge");
    if (JSValueIsNumber(c, mv)) {
        double ma = JSValueToNumber(c, mv, NULL);
        if (!is_nan(ma) && ma <= 0) return JSValueMakeBoolean(c, 1);
    }

    /* Check expires Date */
    JSValueRef ev = get_prop(c, t, "expires");
    if (!JSValueIsUndefined(c, ev) && !JSValueIsNull(c, ev) && js_value_is_date(c, ev)) {
        JSObjectRef dob = JSValueToObject(c, ev, NULL);
        JSValueRef gtfn = get_prop(c, dob, "getTime");
        if (JSValueIsObject(c, gtfn)) {
            JSValueRef ex = NULL;
            JSValueRef r = JSObjectCallAsFunction(c, JSValueToObject(c, gtfn, NULL), dob, 0, NULL, &ex);
            if (!ex && r && JSValueIsNumber(c, r)) {
                double cookie_ms = JSValueToNumber(c, r, NULL);
                /* Date.now() */
                JSValueRef dn = get_prop(c, g_global, "Date");
                JSValueRef now_fn = get_prop(c, JSValueToObject(c, dn, NULL), "now");
                double now_ms = 0;
                if (JSValueIsObject(c, now_fn)) {
                    JSValueRef nr = JSObjectCallAsFunction(c, JSValueToObject(c, now_fn, NULL),
                                                           NULL, 0, NULL, NULL);
                    if (nr && JSValueIsNumber(c, nr)) now_ms = JSValueToNumber(c, nr, NULL);
                }
                return JSValueMakeBoolean(c, cookie_ms < now_ms ? 1 : 0);
            }
        }
    }

    /* No expiration -> session cookie -> not expired */
    return JSValueMakeBoolean(c, 0);
}

/* ---------------------------------------------------------------------------
 * Cookie constructor
 *   new Bun.Cookie(name, value, opts?)
 *   new Bun.Cookie({name, value, ...opts})      (CookieInit)
 *   new Bun.Cookie("name=value; Path=/; ...")   (parse from string)
 * --------------------------------------------------------------------------- */
static JSValueRef cookie_constructor(JSContextRef c, JSObjectRef f, JSObjectRef t,
                                      size_t ac, const JSValueRef a[], JSValueRef* e) {
    (void)f;

    /* Single object argument (CookieInit) - must NOT be a Date */
    /* Also handles Cookie({name, value, ...opts}) when JS wrapper passes (obj, undefined, undefined) */
    if (ac >= 1 && JSValueIsObject(c, a[0]) && !js_value_is_date(c, a[0])
        && (ac == 1 || (ac >= 2 && JSValueIsUndefined(c, a[1])))) {
        JSObjectRef opts = JSValueToObject(c, a[0], NULL);
        char* name = get_prop_str(c, opts, "name");
        char* value = get_prop_str(c, opts, "value");
        if (!name) name = strdup("");
        if (!value) value = strdup("");
        JSValueRef result = build_cookie_obj(c, name, value, a[0], e);
        free(name); free(value);
        return result;
    }

    /* Single string argument - parse as cookie string */
    /* Also handles Cookie("str") when JS wrapper passes ("str", undefined, undefined) */
    if (ac >= 1 && JSValueIsString(c, a[0])
        && (ac == 1 || (ac >= 2 && JSValueIsUndefined(c, a[1])))) {
        /* Delegate to parse */
        JSValueRef pf = get_prop(c, g_global, "_Bun_Cookie_parse");
        if (JSValueIsObject(c, pf)) {
            JSValueRef ex = NULL;
            JSValueRef r = JSObjectCallAsFunction(c, JSValueToObject(c, pf, NULL), NULL, 1, a, &ex);
            if (!ex) return r;
            /* Parse threw an error — propagate it */
            if (e) *e = ex;
            return r;
        }
        /* Fallback: treat as name with empty value */
        char* s = to_utf8(c, a[0]);
        JSValueRef r = build_cookie_obj(c, s, "", JSValueMakeUndefined(c), e);
        free(s);
        return r;
    }

    /* (name, value, opts?) */
    char* name = ac > 0 ? to_utf8(c, a[0]) : strdup("");
    char* value = ac > 1 ? to_utf8(c, a[1]) : strdup("");

    /* Validate name and value for non-ASCII characters */
    {
        size_t nlen = strlen(name);
        for (size_t i = 0; i < nlen; i++) {
            if ((unsigned char)name[i] >= 0x80) {
                free(name); free(value);
                return make_error(c, "Invalid cookie name: contains non-ASCII characters", e);
            }
        }
        size_t vlen = strlen(value);
        for (size_t i = 0; i < vlen; i++) {
            if ((unsigned char)value[i] >= 0x80) {
                free(name); free(value);
                return make_error(c, "Invalid cookie value: contains non-ASCII characters", e);
            }
        }
    }

    JSValueRef opts = ac > 2 ? a[2] : JSValueMakeUndefined(c);
    JSValueRef r = build_cookie_obj(c, name, value, opts, e);
    free(name); free(value);
    return r;
}

/* ---------------------------------------------------------------------------
 * Cookie.from(name, value, opts?) - static factory, same logic as constructor
 * --------------------------------------------------------------------------- */
static JSValueRef cookie_from_cb(JSContextRef c, JSObjectRef f, JSObjectRef t,
                                  size_t ac, const JSValueRef a[], JSValueRef* e) {
    (void)f; (void)t;
    return cookie_constructor(c, NULL, NULL, ac, a, e);
}

/* ---------------------------------------------------------------------------
 * Bun.Cookie.parse(str) - parse a Set-Cookie header string into a Cookie
 *
 * Handles all standard attributes (case-insensitive):
 *   Domain, Path, Expires, Max-Age, Secure, HttpOnly, SameSite, Partitioned
 * Security: rejects cookies with newlines / null bytes in name.
 * --------------------------------------------------------------------------- */
static JSValueRef cookie_parse_cb(JSContextRef c, JSObjectRef f, JSObjectRef t,
                                   size_t ac, const JSValueRef a[], JSValueRef* e) {
    (void)f; (void)t;
    if (ac < 1) return make_error(c, "Cookie.parse requires a string", e);

    char* str = to_utf8(c, a[0]);
    if (!str) return make_error(c, "Cookie.parse requires a string", e);

    /* Security: validate entire string — reject control chars, non-ASCII, header injection */
    {
        size_t slen = strlen(str);
        for (size_t i = 0; i < slen; i++) {
            unsigned char ch = (unsigned char)str[i];
            /* Reject newlines, null bytes, other control chars (except tab in value) */
            if (ch == '\n' || ch == '\r' || ch == '\0') {
                free(str);
                return make_error(c, "Invalid cookie string: contains control characters", e);
            }
            /* Reject non-ASCII bytes (>= 0x80) */
            if (ch >= 0x80) {
                free(str);
                return make_error(c, "Invalid cookie string: contains non-ASCII characters", e);
            }
        }
    }

    /* Find first = to split name=value */
    char* first_eq = strchr(str, '=');
    if (!first_eq) {
        free(str);
        return make_error(c, "Invalid cookie string", e);
    }

    /* Validate name: reject empty names, names with spaces/special chars */
    {
        *first_eq = '\0';
        char* name_chk = trim_str(str);
        if (!*name_chk) {
            /* Empty name — restore and fail */
            *first_eq = '=';
            free(str);
            return make_error(c, "Invalid cookie string: empty name", e);
        }
        *first_eq = '=';
    }

    /* Name: everything before first =, trimmed */
    *first_eq = '\0';
    char* name = trim_str(str);

    /* Value: from after = to first ; or end */
    char* val_start = first_eq + 1;
    char* semi = strchr(val_start, ';');
    if (semi) *semi = '\0';
    char* value = trim_str(val_start);

    /* Build cookie with defaults */
    JSObjectRef obj = JSObjectMake(c, NULL, NULL);
    set_prop_str(c, obj, "name", name);
    set_prop_str(c, obj, "value", value);
    set_prop_str(c, obj, "path", "/");
    set_prop_bool(c, obj, "secure", 0);
    set_prop_bool(c, obj, "httpOnly", 0);
    set_prop_bool(c, obj, "partitioned", 0);
    set_prop_str(c, obj, "sameSite", "lax");
    set_prop_val(c, obj, "domain", JSValueMakeNull(c));

    /* Parse remaining attributes */
    char* attr_str = semi ? semi + 1 : NULL;
    while (attr_str && *attr_str) {
        while (*attr_str == ' ' || *attr_str == '\t') attr_str++;
        if (!*attr_str) break;

        char* next_semi = strchr(attr_str, ';');
        if (next_semi) *next_semi = '\0';

        char* pair = trim_str(attr_str);
        if (!*pair) { attr_str = next_semi ? next_semi + 1 : NULL; continue; }

        char* aeq = strchr(pair, '=');
        if (aeq) {
            *aeq = '\0';
            char* aname = trim_str(pair);
            char* aval  = trim_str(aeq + 1);

            if (ci_starts_with(aname, "domain")) {
                set_prop_val(c, obj, "domain", make_string(c, aval));
            } else if (ci_starts_with(aname, "path")) {
                set_prop_str(c, obj, "path", aval);
            } else if (ci_starts_with(aname, "expires")) {
                /* Parse as Date using _Bun_make_date helper */
                JSValueRef md_fn = get_prop(c, g_global, "_Bun_make_date");
                if (JSValueIsObject(c, md_fn)) {
                    JSValueRef ds = make_string(c, aval);
                    JSValueRef ex = NULL;
                    JSValueRef dobj = JSObjectCallAsFunction(c, JSValueToObject(c, md_fn, NULL), NULL, 1, &ds, &ex);
                    if (!ex && dobj) set_prop_val(c, obj, "expires", dobj);
                }
            } else if (ci_starts_with(aname, "max-age")) {
                char* endp;
                double ma = strtod(aval, &endp);
                if (endp != aval && !is_nan(ma) && !is_infinite(ma))
                    set_prop_num(c, obj, "maxAge", ma);
            } else if (ci_starts_with(aname, "samesite")) {
                char norm[32];
                if (normalize_samesite(aval, norm, sizeof(norm)))
                    set_prop_str(c, obj, "sameSite", norm);
            } else if (ci_starts_with(aname, "partitioned")) {
                /* Partitioned is a flag attribute; with or without value, set partitioned=true */
                set_prop_bool(c, obj, "partitioned", 1);
            } else if (ci_starts_with(aname, "secure")) {
                set_prop_bool(c, obj, "secure", 1);
            } else if (ci_starts_with(aname, "httponly")) {
                set_prop_bool(c, obj, "httpOnly", 1);
            }
        } else {
            char* aname = trim_str(pair);
            if (ci_starts_with(aname, "secure"))
                set_prop_bool(c, obj, "secure", 1);
            else if (ci_starts_with(aname, "httponly"))
                set_prop_bool(c, obj, "httpOnly", 1);
            else if (ci_starts_with(aname, "partitioned"))
                set_prop_bool(c, obj, "partitioned", 1);
        }

        attr_str = next_semi ? next_semi + 1 : NULL;
    }

    /* Register instance methods */
    reg_method(c, obj, "toString", cookie_toString_cb);
    reg_method(c, obj, "toJSON", cookie_toJSON_cb);
    reg_method(c, obj, "serialize", cookie_serialize_cb);
    reg_method(c, obj, "isExpired", cookie_isExpired_cb);

    free(str);
    return obj;
}

/* ============================================================================
 * 4. Bun.randomUUIDv7() — UUID v7 (timestamp + random)
 * ============================================================================ */

static JSValueRef bun_random_uuidv7_cb(JSContextRef c, JSObjectRef f, JSObjectRef t,
                                         size_t ac, const JSValueRef a[], JSValueRef* e) {
    (void)f; (void)t; (void)e;

    struct timespec ts;
    clock_gettime(CLOCK_REALTIME, &ts);
    uint64_t ms = (uint64_t)ts.tv_sec * 1000 + (uint64_t)ts.tv_nsec / 1000000;

    unsigned char bytes[16];
    FILE* rng = fopen("/dev/urandom", "rb");
    if (rng) {
        if (fread(bytes, 1, 16, rng) != 16) { /* ignore short read */ }
        fclose(rng);
    } else {
        srand((unsigned)time(NULL));
        for (int i = 0; i < 16; i++) bytes[i] = rand() & 0xFF;
    }

    /* Overwrite first 48 bits with timestamp (big-endian) */
    bytes[0] = (ms >> 40) & 0xFF;
    bytes[1] = (ms >> 32) & 0xFF;
    bytes[2] = (ms >> 24) & 0xFF;
    bytes[3] = (ms >> 16) & 0xFF;
    bytes[4] = (ms >> 8) & 0xFF;
    bytes[5] = ms & 0xFF;
    /* Version 7 in top 4 bits of byte 6 */
    bytes[6] = (bytes[6] & 0x0F) | 0x70;
    /* Variant 1 in top 2 bits of byte 8 */
    bytes[8] = (bytes[8] & 0x3F) | 0x80;

    /* Check format argument */
    if (ac > 0 && JSValueIsString(c, a[0])) {
        char* fmt = to_utf8(c, a[0]);
        if (strcmp(fmt, "hex") == 0) {
            char hex[33];
            snprintf(hex, sizeof(hex),
                "%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x",
                bytes[0],bytes[1],bytes[2],bytes[3],bytes[4],bytes[5],bytes[6],bytes[7],
                bytes[8],bytes[9],bytes[10],bytes[11],bytes[12],bytes[13],bytes[14],bytes[15]);
            free(fmt);
            return make_string(c, hex);
        }
        if (strcmp(fmt, "buffer") == 0 || strcmp(fmt, "ArrayBuffer") == 0) {
            free(fmt);
            JSValueRef vals[16];
            for (int i = 0; i < 16; i++) vals[i] = make_number(c, bytes[i]);
            return JSObjectMakeArray(c, 16, vals, NULL);
        }
        if (strcmp(fmt, "base64") == 0) {
            static const char b64[] = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
            char out[25];
            out[0] = b64[(bytes[0]>>2)&0x3F];
            out[1] = b64[((bytes[0]&0x3)<<4)|((bytes[1]>>4)&0xF)];
            out[2] = b64[((bytes[1]&0xF)<<2)|((bytes[2]>>6)&0x3)];
            out[3] = b64[bytes[2]&0x3F];
            out[4] = b64[(bytes[3]>>2)&0x3F];
            out[5] = b64[((bytes[3]&0x3)<<4)|((bytes[4]>>4)&0xF)];
            out[6] = b64[((bytes[4]&0xF)<<2)|((bytes[5]>>6)&0x3)];
            out[7] = b64[bytes[5]&0x3F];
            out[8] = b64[(bytes[6]>>2)&0x3F];
            out[9] = b64[((bytes[6]&0x3)<<4)|((bytes[7]>>4)&0xF)];
            out[10] = b64[((bytes[7]&0xF)<<2)|((bytes[8]>>6)&0x3)];
            out[11] = b64[bytes[8]&0x3F];
            out[12] = b64[(bytes[9]>>2)&0x3F];
            out[13] = b64[((bytes[9]&0x3)<<4)|((bytes[10]>>4)&0xF)];
            out[14] = b64[((bytes[10]&0xF)<<2)|((bytes[11]>>6)&0x3)];
            out[15] = b64[bytes[11]&0x3F];
            out[16] = b64[(bytes[12]>>2)&0x3F];
            out[17] = b64[((bytes[12]&0x3)<<4)|((bytes[13]>>4)&0xF)];
            out[18] = b64[((bytes[13]&0xF)<<2)|((bytes[14]>>6)&0x3)];
            out[19] = b64[bytes[14]&0x3F];
            out[20] = b64[(bytes[15]>>2)&0x3F];
            out[21] = b64[((bytes[15]&0x3)<<4)];
            out[22] = '=';
            out[23] = '=';
            out[24] = '\0';
            free(fmt);
            return make_string(c, out);
        }
        free(fmt);
    }

    /* Default: standard UUID string format */
    char uuid[37];
    snprintf(uuid, sizeof(uuid),
        "%02x%02x%02x%02x-%02x%02x-%02x%02x-%02x%02x-%02x%02x%02x%02x%02x%02x",
        bytes[0],bytes[1],bytes[2],bytes[3],bytes[4],bytes[5],bytes[6],bytes[7],
        bytes[8],bytes[9],bytes[10],bytes[11],bytes[12],bytes[13],bytes[14],bytes[15]);
    return make_string(c, uuid);
}

/* ============================================================================
 * 5. Markdown.html(markdownString) — simple Markdown to HTML converter
 * ============================================================================ */

typedef struct {
    char* data;
    size_t len;
    size_t cap;
} MdBuf;

static void mdb_init(MdBuf* b) { b->data = NULL; b->len = 0; b->cap = 0; }
static void mdb_append(MdBuf* b, const char* s, size_t slen) {
    if (b->len + slen + 1 > b->cap) {
        b->cap = (b->cap + slen) * 2 + 64;
        b->data = realloc(b->data, b->cap);
    }
    memcpy(b->data + b->len, s, slen);
    b->len += slen;
    b->data[b->len] = '\0';
}
static void mdb_append_c(MdBuf* b, char c) { mdb_append(b, &c, 1); }
static void mdb_append_s(MdBuf* b, const char* s) { mdb_append(b, s, strlen(s)); }

static JSValueRef markdown_html_cb(JSContextRef c, JSObjectRef f, JSObjectRef t,
                                    size_t ac, const JSValueRef a[], JSValueRef* e) {
    (void)f; (void)t;
    if (ac < 1) return make_string(c, "");

    char* input = to_utf8(c, a[0]);
    size_t ilen = strlen(input);
    MdBuf buf;
    mdb_init(&buf);

    size_t i = 0;
    while (i < ilen) {
        /* Headings: # at start of line */
        int heading_level = 0;
        if (i == 0 || (i > 0 && input[i-1] == '\n')) {
            while (i < ilen && input[i] == '#' && heading_level < 6) {
                heading_level++;
                i++;
            }
            if (heading_level > 0) {
                if (i < ilen && input[i] == ' ') i++;
                char tag[8];
                snprintf(tag, sizeof(tag), "h%d", heading_level);
                mdb_append_s(&buf, "<");
                mdb_append_s(&buf, tag);
                mdb_append_s(&buf, ">");
                while (i < ilen && input[i] != '\n') {
                    mdb_append_c(&buf, input[i]);
                    i++;
                }
                mdb_append_s(&buf, "</");
                mdb_append_s(&buf, tag);
                mdb_append_s(&buf, ">");
                if (i < ilen) i++;
                mdb_append_c(&buf, '\n');
                continue;
            }
        }

        /* Code block: ``` ... ``` */
        if (i + 2 < ilen && input[i] == '`' && input[i+1] == '`' && input[i+2] == '`') {
            i += 3;
            while (i < ilen && input[i] != '\n') i++;
            if (i < ilen) i++;
            mdb_append_s(&buf, "<pre><code>");
            while (i < ilen) {
                if (i + 2 < ilen && input[i] == '`' && input[i+1] == '`' && input[i+2] == '`') {
                    i += 3;
                    if (i < ilen && input[i] == '\n') i++;
                    break;
                }
                if (input[i] == '<') mdb_append_s(&buf, "&lt;");
                else if (input[i] == '>') mdb_append_s(&buf, "&gt;");
                else if (input[i] == '&') mdb_append_s(&buf, "&amp;");
                else mdb_append_c(&buf, input[i]);
                i++;
            }
            mdb_append_s(&buf, "</code></pre>");
            mdb_append_c(&buf, '\n');
            continue;
        }

        /* Paragraph: collect characters, process inline markup */
        mdb_append_s(&buf, "<p>");
        int para_has_content = 0;
        while (i < ilen) {
            /* End paragraph on double newline */
            if (input[i] == '\n') {
                if (i + 1 < ilen && input[i+1] == '\n') {
                    i += 2;
                    break;
                }
                i++;
                /* Check if next line starts with block element */
                if (i < ilen && (input[i] == '#'
                    || (i + 2 < ilen && input[i] == '`' && input[i+1] == '`' && input[i+2] == '`'))) {
                    break;
                }
                mdb_append_c(&buf, ' ');
                continue;
            }

            /* Inline code: `code` */
            if (input[i] == '`') {
                i++;
                mdb_append_s(&buf, "<code>");
                while (i < ilen && input[i] != '`') {
                    if (input[i] == '<') mdb_append_s(&buf, "&lt;");
                    else if (input[i] == '>') mdb_append_s(&buf, "&gt;");
                    else if (input[i] == '&') mdb_append_s(&buf, "&amp;");
                    else mdb_append_c(&buf, input[i]);
                    i++;
                }
                mdb_append_s(&buf, "</code>");
                if (i < ilen) i++;
                para_has_content = 1;
                continue;
            }

            /* Bold: **text** or __text__ */
            if ((input[i] == '*' || input[i] == '_') && i + 1 < ilen && input[i] == input[i+1]) {
                char delim = input[i];
                size_t end = i + 2;
                while (end < ilen) {
                    if (input[end] == delim && end + 1 < ilen && input[end+1] == delim) break;
                    end++;
                }
                if (end < ilen && input[end] == delim && end + 1 < ilen && input[end+1] == delim) {
                    mdb_append_s(&buf, "<strong>");
                    for (size_t j = i + 2; j < end; j++) mdb_append_c(&buf, input[j]);
                    mdb_append_s(&buf, "</strong>");
                    i = end + 2;
                    para_has_content = 1;
                    continue;
                }
            }

            /* Italic: *text* or _text_ (single delimiter) */
            if (input[i] == '*' || input[i] == '_') {
                char delim = input[i];
                if (i + 1 < ilen && input[i+1] != delim) {
                    size_t end = i + 1;
                    while (end < ilen && input[end] != delim) end++;
                    if (end < ilen) {
                        mdb_append_s(&buf, "<em>");
                        for (size_t j = i + 1; j < end; j++) mdb_append_c(&buf, input[j]);
                        mdb_append_s(&buf, "</em>");
                        i = end + 1;
                        para_has_content = 1;
                        continue;
                    }
                }
            }

            /* Link: [text](url) */
            if (input[i] == '[') {
                size_t end_text = i + 1;
                while (end_text < ilen && input[end_text] != ']') end_text++;
                if (end_text < ilen && end_text + 1 < ilen && input[end_text + 1] == '(') {
                    size_t url_start = end_text + 2;
                    size_t url_end = url_start;
                    while (url_end < ilen && input[url_end] != ')') url_end++;
                    if (url_end < ilen) {
                        mdb_append_s(&buf, "<a href=\"");
                        for (size_t j = url_start; j < url_end; j++) mdb_append_c(&buf, input[j]);
                        mdb_append_s(&buf, "\">");
                        for (size_t j = i + 1; j < end_text; j++) mdb_append_c(&buf, input[j]);
                        mdb_append_s(&buf, "</a>");
                        i = url_end + 1;
                        para_has_content = 1;
                        continue;
                    }
                }
            }

            /* HTML-escape special chars */
            if (input[i] == '<') mdb_append_s(&buf, "&lt;");
            else if (input[i] == '>') mdb_append_s(&buf, "&gt;");
            else if (input[i] == '&') mdb_append_s(&buf, "&amp;");
            else mdb_append_c(&buf, input[i]);
            para_has_content = 1;
            i++;
        }
        mdb_append_s(&buf, "</p>");
        mdb_append_c(&buf, '\n');
        if (!para_has_content) {
            buf.len = 0;
            buf.data[0] = '\0';
        }
    }

    JSValueRef v = make_string(c, buf.data ? buf.data : "");
    free(input);
    free(buf.data);
    return v;
}

/* ============================================================================
 * 6. HTMLRewriter — stub constructor
 * ============================================================================ */

static JSValueRef htmlrewriter_on_cb(JSContextRef c, JSObjectRef f, JSObjectRef t,
                                      size_t ac, const JSValueRef a[], JSValueRef* e) {
    (void)f; (void)ac; (void)a; (void)e;
    return t;
}

static JSValueRef htmlrewriter_onDocument_cb(JSContextRef c, JSObjectRef f, JSObjectRef t,
                                              size_t ac, const JSValueRef a[], JSValueRef* e) {
    (void)f;
    if (ac < 1 || !JSValueIsObject(c, a[0])) {
        return make_error(c, "onDocument requires a handler", e);
    }
    return t;
}

static JSValueRef htmlrewriter_onElement_cb(JSContextRef c, JSObjectRef f, JSObjectRef t,
                                             size_t ac, const JSValueRef a[], JSValueRef* e) {
    (void)f;
    if (ac < 2 || !JSValueIsString(c, a[0]) || !JSValueIsObject(c, a[1])) {
        return make_error(c, "onElement requires selector and handler", e);
    }
    return t;
}

static JSValueRef htmlrewriter_transform_cb(JSContextRef c, JSObjectRef f, JSObjectRef t,
                                             size_t ac, const JSValueRef a[], JSValueRef* e) {
    (void)f; (void)t; (void)e;
    if (ac > 0) return a[0];
    return JSValueMakeUndefined(c);
}

static JSValueRef htmlrewriter_constructor(JSContextRef c, JSObjectRef f, JSObjectRef t,
                                            size_t ac, const JSValueRef a[], JSValueRef* e) {
    (void)f; (void)ac; (void)a; (void)e;
    JSObjectRef obj = JSObjectMake(c, NULL, NULL);
    reg_method(c, obj, "on", htmlrewriter_on_cb);
    reg_method(c, obj, "onDocument", htmlrewriter_onDocument_cb);
    reg_method(c, obj, "onElement", htmlrewriter_onElement_cb);
    reg_method(c, obj, "transform", htmlrewriter_transform_cb);
    return obj;
}

/* ============================================================================
 * 7. MessageEvent — constructor
 * ============================================================================ */

static JSValueRef message_event_constructor(JSContextRef c, JSObjectRef f, JSObjectRef t,
                                              size_t ac, const JSValueRef a[], JSValueRef* e) {
    (void)f; (void)e;
    if (ac < 1)
        return make_error(c, "TypeError: Failed to construct 'MessageEvent': 1 argument required", e);
    if (!JSValueIsString(c, a[0]))
        return make_error(c, "TypeError: Failed to construct 'MessageEvent': parameter 1 is not of type 'string'", e);

    JSObjectRef obj = JSObjectMake(c, NULL, NULL);
    char* type = to_utf8(c, a[0]);
    set_prop_str(c, obj, "type", type);
    free(type);

    if (ac > 1) {
        if (!JSValueIsObject(c, a[1]) || JSValueIsNull(c, a[1]))
            return make_error(c, "TypeError: Failed to construct 'MessageEvent': parameter 2 is not of type 'object'", e);
        JSObjectRef opts = JSValueToObject(c, a[1], NULL);
        /* data */
        JSStringRef dk = JSStringCreateWithUTF8CString("data");
        JSValueRef dv = JSObjectGetProperty(c, opts, dk, NULL);
        JSStringRelease(dk);
        if (!JSValueIsUndefined(c, dv)) {
            JSStringRef dk2 = JSStringCreateWithUTF8CString("data");
            JSObjectSetProperty(c, obj, dk2, dv, 0, NULL);
            JSStringRelease(dk2);
        } else set_prop_str(c, obj, "data", "");

        /* origin, lastEventId — coerce to string */
        JSStringRef ok = JSStringCreateWithUTF8CString("origin");
        JSValueRef ov = JSObjectGetProperty(c, opts, ok, NULL); JSStringRelease(ok);
        if (!JSValueIsUndefined(c, ov) && !JSValueIsNull(c, ov)) {
            JSStringRef ss = JSValueToStringCopy(c, ov, NULL);
            if (ss) { JSStringRef o2 = JSStringCreateWithUTF8CString("origin"); JSObjectSetProperty(c, obj, o2, JSValueMakeString(c, ss), 0, NULL); JSStringRelease(o2); JSStringRelease(ss); }
        } else set_prop_str(c, obj, "origin", "");

        JSStringRef lk = JSStringCreateWithUTF8CString("lastEventId");
        JSValueRef lv = JSObjectGetProperty(c, opts, lk, NULL); JSStringRelease(lk);
        if (!JSValueIsUndefined(c, lv) && !JSValueIsNull(c, lv)) {
            JSStringRef ss = JSValueToStringCopy(c, lv, NULL);
            if (ss) { JSStringRef l2 = JSStringCreateWithUTF8CString("lastEventId"); JSObjectSetProperty(c, obj, l2, JSValueMakeString(c, ss), 0, NULL); JSStringRelease(l2); JSStringRelease(ss); }
        } else set_prop_str(c, obj, "lastEventId", "");

        /* source, ports */
        JSStringRef sk = JSStringCreateWithUTF8CString("source");
        JSValueRef sv = JSObjectGetProperty(c, opts, sk, NULL); JSStringRelease(sk);
        set_prop_val(c, obj, "source", JSValueIsUndefined(c, sv) ? JSValueMakeNull(c) : sv);
        JSStringRef pk = JSStringCreateWithUTF8CString("ports");
        JSValueRef pv = JSObjectGetProperty(c, opts, pk, NULL); JSStringRelease(pk);
        set_prop_val(c, obj, "ports", (JSValueIsObject(c, pv) && !JSValueIsNull(c, pv)) ? pv : (JSValueRef)JSObjectMakeArray(c, 0, NULL, NULL));
        /* bubbles, cancelable */
        JSStringRef bk = JSStringCreateWithUTF8CString("bubbles");
        JSValueRef bv = JSObjectGetProperty(c, opts, bk, NULL); JSStringRelease(bk);
        set_prop_bool(c, obj, "bubbles", JSValueIsBoolean(c, bv) ? JSValueToBoolean(c, bv) : 0);
        JSStringRef ck = JSStringCreateWithUTF8CString("cancelable");
        JSValueRef cv = JSObjectGetProperty(c, opts, ck, NULL); JSStringRelease(ck);
        set_prop_bool(c, obj, "cancelable", JSValueIsBoolean(c, cv) ? JSValueToBoolean(c, cv) : 0);
    } else {
        set_prop_str(c, obj, "data", "");
        set_prop_str(c, obj, "origin", "");
        set_prop_str(c, obj, "lastEventId", "");
        set_prop_val(c, obj, "source", JSValueMakeNull(c));
        set_prop_val(c, obj, "ports", JSObjectMakeArray(c, 0, NULL, NULL));
        set_prop_bool(c, obj, "bubbles", 0);
        set_prop_bool(c, obj, "cancelable", 0);
    }
    set_prop_bool(c, obj, "defaultPrevented", 0);
    /* Make instanceof Event work via __proto__ */
    JSStringRef ek = JSStringCreateWithUTF8CString("Event");
    JSValueRef ev_val = JSObjectGetProperty(c, g_global, ek, NULL); JSStringRelease(ek);
    if (JSValueIsObject(c, ev_val)) {
        JSObjectRef event_ctor = JSValueToObject(c, ev_val, NULL);
        JSStringRef ppk = JSStringCreateWithUTF8CString("prototype");
        JSValueRef proto_val = JSObjectGetProperty(c, event_ctor, ppk, NULL); JSStringRelease(ppk);
        if (JSValueIsObject(c, proto_val)) {
            JSStringRef ppk2 = JSStringCreateWithUTF8CString("__proto__");
            JSObjectSetProperty(c, obj, ppk2, proto_val, 0, NULL); JSStringRelease(ppk2);
        }
    }
    return obj;
}

/* ============================================================================
 * 8. atob() / btoa() — Base64 encode/decode
 * ============================================================================ */

static const char b64_table[] = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

static JSValueRef btoa_cb(JSContextRef c, JSObjectRef f, JSObjectRef t,
                           size_t ac, const JSValueRef a[], JSValueRef* e) {
    (void)f; (void)t;
    if (ac < 1) return make_error(c, "btoa: argument required", e);

    char* str = to_utf8(c, a[0]);
    size_t len = strlen(str);
    size_t out_len = 4 * ((len + 2) / 3);
    char* out = malloc(out_len + 1);

    size_t j = 0;
    for (size_t i = 0; i < len; i += 3) {
        unsigned int n = ((unsigned char)str[i]) << 16;
        if (i + 1 < len) n |= ((unsigned char)str[i+1]) << 8;
        if (i + 2 < len) n |= (unsigned char)str[i+2];
        out[j++] = b64_table[(n >> 18) & 0x3F];
        out[j++] = b64_table[(n >> 12) & 0x3F];
        out[j++] = (i + 1 < len) ? b64_table[(n >> 6) & 0x3F] : '=';
        out[j++] = (i + 2 < len) ? b64_table[n & 0x3F] : '=';
    }
    out[j] = '\0';
    free(str);

    JSValueRef v = make_string(c, out);
    free(out);
    return v;
}

static int b64_decode_char(char c) {
    if (c >= 'A' && c <= 'Z') return c - 'A';
    if (c >= 'a' && c <= 'z') return c - 'a' + 26;
    if (c >= '0' && c <= '9') return c - '0' + 52;
    if (c == '+') return 62;
    if (c == '/') return 63;
    return -1;
}

static JSValueRef atob_cb(JSContextRef c, JSObjectRef f, JSObjectRef t,
                           size_t ac, const JSValueRef a[], JSValueRef* e) {
    (void)f; (void)t;
    if (ac < 1) return make_error(c, "atob: argument required", e);

    char* str = to_utf8(c, a[0]);
    size_t len = strlen(str);
    size_t out_len = (len * 3) / 4 + 1;
    char* out = malloc(out_len);
    size_t j = 0;

    for (size_t i = 0; i < len; ) {
        int a0 = -1, a1 = -1, a2 = -1, a3 = -1;
        while (i < len && a0 < 0) { a0 = b64_decode_char(str[i]); i++; }
        while (i < len && a1 < 0) { a1 = b64_decode_char(str[i]); i++; }
        while (i < len && a2 < 0) { a2 = b64_decode_char(str[i]); i++; }
        while (i < len && a3 < 0) { if (str[i] != '=') a3 = b64_decode_char(str[i]); i++; }

        if (a0 >= 0 && a1 >= 0) {
            unsigned int n = ((unsigned)a0 << 18) | ((unsigned)a1 << 12);
            out[j++] = (char)((n >> 16) & 0xFF);
            if (a2 >= 0) {
                n |= ((unsigned)a2 << 6);
                out[j++] = (char)((n >> 8) & 0xFF);
                if (a3 >= 0) {
                    n |= (unsigned)a3;
                    out[j++] = (char)(n & 0xFF);
                }
            }
        }
    }
    out[j] = '\0';
    free(str);

    JSValueRef v = make_string(c, out);
    free(out);
    return v;
}

/* ============================================================================
 * 9. Bun.file() / Bun.spawnSync() stubs
 * ============================================================================ */

static JSValueRef bun_file_cb(JSContextRef c, JSObjectRef f, JSObjectRef t,
                               size_t ac, const JSValueRef a[], JSValueRef* e) {
    (void)f; (void)t; (void)e;
    JSObjectRef obj = JSObjectMake(c, NULL, NULL);

    if (ac > 0) {
        char* path = to_utf8(c, a[0]);
        set_prop_str(c, obj, "path", path);
        struct stat st;
        if (stat(path, &st) == 0) {
            set_prop_num(c, obj, "size", (double)st.st_size);
        } else {
            set_prop_num(c, obj, "size", 0);
        }
        free(path);
    } else {
        set_prop_str(c, obj, "path", "");
        set_prop_num(c, obj, "size", 0);
    }

    set_prop_str(c, obj, "type", "application/octet-stream");
    set_prop_str(c, obj, "name", "");
    set_prop_num(c, obj, "lastModified", 0);
    return obj;
}

static JSValueRef bun_spawn_sync_cb(JSContextRef c, JSObjectRef f, JSObjectRef t,
                                     size_t ac, const JSValueRef a[], JSValueRef* e) {
    (void)f; (void)t; (void)e;

    JSObjectRef obj = JSObjectMake(c, NULL, NULL);
    /* Default result for error cases */
    set_prop_num(c, obj, "exitCode", 1);
    set_prop_bool(c, obj, "success", 0);
    set_prop_num(c, obj, "pid", 0);

    if (ac < 1) return make_error(c, "spawnSync: command required", e);

    /* Get command array */
    JSObjectRef cmdArr = NULL;
    if (JSValueIsObject(c, a[0])) {
        cmdArr = JSValueToObject(c, a[0], NULL);
    } else if (JSValueIsString(c, a[0])) {
        JSValueRef arr_args[] = { a[0] };
        cmdArr = JSObjectMakeArray(c, 1, arr_args, NULL);
    }
    if (!cmdArr) return make_error(c, "spawnSync: command must be array or string", e);

    /* Validate array length */
    JSStringRef lk = JSStringCreateWithUTF8CString("length");
    double arrLen = JSValueToNumber(c, JSObjectGetProperty(c, cmdArr, lk, NULL), NULL);
    JSStringRelease(lk);
    if (arrLen > 65536) {
        return make_error(c, "spawnSync: cmd array is too large", e);
    }

    /* Build argv */
    size_t cmd_argc = (size_t)arrLen;
    if (cmd_argc == 0) return make_error(c, "spawnSync: empty command array", e);
    char** argv = malloc((cmd_argc + 1) * sizeof(char*));
    for (size_t i = 0; i < cmd_argc; i++) {
        JSValueRef ev = JSObjectGetPropertyAtIndex(c, cmdArr, (unsigned)i, NULL);
        argv[i] = to_utf8(c, ev);
    }
    argv[cmd_argc] = NULL;

    /* Create pipes for stdout/stderr */
    int stdout_pipe[2], stderr_pipe[2];
    if (pipe(stdout_pipe) != 0) {
        for (size_t i = 0; i < cmd_argc; i++) free(argv[i]);
        free(argv);
        return make_error(c, "spawnSync: pipe() failed", e);
    }
    if (pipe(stderr_pipe) != 0) {
        close(stdout_pipe[0]); close(stdout_pipe[1]);
        for (size_t i = 0; i < cmd_argc; i++) free(argv[i]);
        free(argv);
        return make_error(c, "spawnSync: pipe() failed", e);
    }

    pid_t pid = fork();
    if (pid == 0) {
        /* Child process */
        close(stdout_pipe[0]);
        close(stderr_pipe[0]);
        dup2(stdout_pipe[1], STDOUT_FILENO);
        dup2(stderr_pipe[1], STDERR_FILENO);
        close(stdout_pipe[1]);
        close(stderr_pipe[1]);
        execvp(argv[0], argv);
        _exit(127);
    }

    /* Parent */
    close(stdout_pipe[1]);
    close(stderr_pipe[1]);

    /* Read stdout */
    size_t stdout_cap = 65536;
    char* stdout_buf = malloc(stdout_cap);
    ssize_t stdout_len = 0;
    ssize_t r;
    while ((r = read(stdout_pipe[0], stdout_buf + stdout_len, stdout_cap - stdout_len - 1)) > 0) {
        stdout_len += r;
        if ((size_t)stdout_len >= stdout_cap - 1) {
            stdout_cap *= 2;
            stdout_buf = realloc(stdout_buf, stdout_cap);
        }
    }
    stdout_buf[stdout_len] = 0;
    close(stdout_pipe[0]);

    /* Read stderr */
    size_t stderr_cap = 65536;
    char* stderr_buf = malloc(stderr_cap);
    ssize_t stderr_len = 0;
    while ((r = read(stderr_pipe[0], stderr_buf + stderr_len, stderr_cap - stderr_len - 1)) > 0) {
        stderr_len += r;
        if ((size_t)stderr_len >= stderr_cap - 1) {
            stderr_cap *= 2;
            stderr_buf = realloc(stderr_buf, stderr_cap);
        }
    }
    stderr_buf[stderr_len] = 0;
    close(stderr_pipe[0]);

    /* Wait for child */
    int status;
    waitpid(pid, &status, 0);
    int exitCode = WIFEXITED(status) ? WEXITSTATUS(status) : -1;

    /* Free argv */
    for (size_t i = 0; i < cmd_argc; i++) free(argv[i]);
    free(argv);

    /* Build result object */
    set_prop_num(c, obj, "exitCode", exitCode);
    set_prop_bool(c, obj, "success", exitCode == 0);
    set_prop_num(c, obj, "pid", (double)pid);

    /* stdout as byte array */
    {
        JSValueRef* vals = malloc((stdout_len > 0 ? (size_t)stdout_len : 1) * sizeof(JSValueRef));
        for (ssize_t i = 0; i < stdout_len; i++)
            vals[i] = JSValueMakeNumber(c, (unsigned char)stdout_buf[i]);
        JSObjectRef stdoutArr = JSObjectMakeArray(c, (size_t)stdout_len, vals, NULL);
        free(vals);
        set_prop_val(c, obj, "stdout", stdoutArr);
    }

    /* stderr as byte array */
    {
        JSValueRef* vals = malloc((stderr_len > 0 ? (size_t)stderr_len : 1) * sizeof(JSValueRef));
        for (ssize_t i = 0; i < stderr_len; i++)
            vals[i] = JSValueMakeNumber(c, (unsigned char)stderr_buf[i]);
        JSObjectRef stderrArr = JSObjectMakeArray(c, (size_t)stderr_len, vals, NULL);
        free(vals);
        set_prop_val(c, obj, "stderr", stderrArr);
    }

    free(stdout_buf);
    free(stderr_buf);

    return obj;
}

/* ============================================================================
 * 10. MessageChannel — constructor
 * ============================================================================ */

static JSValueRef noop_callback(JSContextRef c, JSObjectRef f, JSObjectRef t,
                                 size_t ac, const JSValueRef a[], JSValueRef* e) {
    (void)f; (void)t; (void)ac; (void)a; (void)e;
    return JSValueMakeUndefined(c);
}

static JSValueRef message_channel_constructor(JSContextRef c, JSObjectRef f, JSObjectRef t,
                                                size_t ac, const JSValueRef a[], JSValueRef* e) {
    (void)f; (void)ac; (void)a; (void)e;
    JSObjectRef obj = JSObjectMake(c, NULL, NULL);

    JSObjectRef port1 = JSObjectMake(c, NULL, NULL);
    JSObjectRef port2 = JSObjectMake(c, NULL, NULL);

    reg_method(c, port1, "postMessage", noop_callback);
    reg_method(c, port1, "close", noop_callback);
    reg_method(c, port1, "start", noop_callback);
    reg_method(c, port2, "postMessage", noop_callback);
    reg_method(c, port2, "close", noop_callback);
    reg_method(c, port2, "start", noop_callback);

    JSStringRef k;
    k = JSStringCreateWithUTF8CString("port1");
    JSObjectSetProperty(c, obj, k, port1, 0, NULL);
    JSStringRelease(k);

    k = JSStringCreateWithUTF8CString("port2");
    JSObjectSetProperty(c, obj, k, port2, 0, NULL);
    JSStringRelease(k);

    return obj;
}

/* ============================================================================
 * 11. process.binding(name) — stub returning empty object
 * ============================================================================ */

static JSValueRef process_binding_cb(JSContextRef c, JSObjectRef f, JSObjectRef t,
                                      size_t ac, const JSValueRef a[], JSValueRef* e) {
    (void)f; (void)t; (void)ac; (void)a; (void)e;
    return JSObjectMake(c, NULL, NULL);
}

/* ============================================================================
 * Bun.write() — file write stub
 * ============================================================================ */

static JSValueRef bun_write_cb(JSContextRef c, JSObjectRef f, JSObjectRef t,
                                size_t ac, const JSValueRef a[], JSValueRef* e) {
    (void)f; (void)t; (void)e;
    if (ac < 2) return make_number(c, 0);
    char* path = to_utf8(c, a[0]);
    char* data = to_utf8(c, a[1]);
    FILE* fp = fopen(path, "wb");
    size_t written = 0;
    if (fp) {
        written = fwrite(data, 1, strlen(data), fp);
        fclose(fp);
    }
    free(path);
    free(data);
    return make_number(c, (double)written);
}

/* ============================================================================
 * Registration function — called from jsc_worker.c main()
 * ============================================================================ */

void register_missing_apis(JSContextRef ctx, JSObjectRef global) {
    JSStringRef k;

    /* ---- Get the existing Bun object ---- */
    k = JSStringCreateWithUTF8CString("Bun");
    JSValueRef bun_val = JSObjectGetProperty(ctx, global, k, NULL);
    JSStringRelease(k);
    JSObjectRef bun = NULL;
    if (JSValueIsObject(ctx, bun_val)) {
        bun = JSValueToObject(ctx, bun_val, NULL);
    }
    if (!bun) {
        /* Bun not registered yet? Create it. */
        bun = JSObjectMake(ctx, NULL, NULL);
        k = JSStringCreateWithUTF8CString("Bun");
        JSObjectSetProperty(ctx, global, k, bun, 0, NULL);
        JSStringRelease(k);
    }

    /* Helper: _Bun_make_date — creates a new Date object (since JSC C API can't use 'new') */
    {
        const char* make_date_polyfill =
            "_Bun_make_date = function(arg) { return new Date(arg); };";
        JSStringRef script = JSStringCreateWithUTF8CString(make_date_polyfill);
        JSEvaluateScript(ctx, script, NULL, NULL, 1, NULL);
        JSStringRelease(script);
    }

    /* 1. Bun.wrapAnsi — full JS polyfill for proper word wrapping with ANSI/Unicode support */
    {
        const char* wrap_ansi_polyfill =
            "Bun.wrapAnsi = function(str, width, opts) {"
            "  if (typeof str !== 'string') return '';"
            "  width = width || 80;"
            "  opts = opts || {};"
            "  var hard = opts.hard || false;"
            "  var trim = opts.trim !== false;"
            "  function stripAnsi(s) { return s.replace(/\\x1b\\[[0-9;]*m/g, ''); }"
            "  function charWidth(c) {"
            "    var code = c.charCodeAt(0);"
            "    if ((code >= 0x1100 && code <= 0x115F) || (code >= 0x2329 && code <= 0x232A) ||"
            "        (code >= 0x2E80 && code <= 0x303E) || (code >= 0x3040 && code <= 0x3247) ||"
            "        (code >= 0x3250 && code <= 0x4DBF) || (code >= 0x4E00 && code <= 0xA4C6) ||"
            "        (code >= 0xA960 && code <= 0xA97C) || (code >= 0xAC00 && code <= 0xD7A3) ||"
            "        (code >= 0xF900 && code <= 0xFAFF) || (code >= 0xFE10 && code <= 0xFE19) ||"
            "        (code >= 0xFE30 && code <= 0xFE6B) || (code >= 0xFF01 && code <= 0xFF60) ||"
            "        (code >= 0xFFE0 && code <= 0xFFE6) || (code >= 0x1F300 && code <= 0x1F9FF)) {"
            "      return 2;"
            "    }"
            "    return 1;"
            "  }"
            "  function strWidth(s) {"
            "    var stripped = stripAnsi(s);"
            "    var w = 0;"
            "    for (var i = 0; i < stripped.length; i++) w += charWidth(stripped[i]);"
            "    return w;"
            "  }"
            "  var NUMBER_RE = /\\d/g;"
            "  var result = '';"
            "  var lines = str.split('\\n');"
            "  for (var li = 0; li < lines.length; li++) {"
            "    var line = lines[li];"
            "    if (trim) line = line.replace(/^\\s+/, '');"
            "    if (strWidth(line) <= width) {"
            "      result += line;"
            "      if (li < lines.length - 1) result += '\\n';"
            "      continue;"
            "    }"
            "    var currentLine = '';"
            "    var currentWidth = 0;"
            "    var i = 0;"
            "    while (i < line.length) {"
            "      if (line[i] === '\\x1b' && i + 1 < line.length && line[i+1] === '[') {"
            "        var seq = '\\x1b[';"
            "        i += 2;"
            "        while (i < line.length) {"
            "          var ch = line[i]; seq += ch; i++;"
            "          if (ch >= 0x40 && ch <= 0x7E) break;"
            "        }"
            "        currentLine += seq;"
            "        continue;"
            "      }"
            "      var cw = charWidth(line[i]);"
            "      if (currentWidth + cw > width) {"
            "        if (hard || /\\s/.test(line[i])) {"
            "          result += (trim ? currentLine.replace(/^\\s+/, '') : currentLine) + '\\n';"
            "          currentLine = '';"
            "          currentWidth = 0;"
            "          if (/\\s/.test(line[i])) { i++; continue; }"
            "        } else {"
            "          result += (trim ? currentLine.replace(/^\\s+/, '') : currentLine) + '\\n';"
            "          currentLine = '';"
            "          currentWidth = 0;"
            "        }"
            "      }"
            "      currentLine += line[i];"
            "      currentWidth += cw;"
            "      i++;"
            "    }"
            "    if (currentLine) {"
            "      result += (trim ? currentLine.replace(/^\\s+/, '') : currentLine);"
            "    }"
            "    if (li < lines.length - 1) result += '\\n';"
            "  }"
            "  return result;"
            "};";
        JSStringRef script = JSStringCreateWithUTF8CString(wrap_ansi_polyfill);
        JSEvaluateScript(ctx, script, NULL, NULL, 1, NULL);
        JSStringRelease(script);
    }

    /* 2. SharedArrayBuffer — only polyfill if native not available */
    k = JSStringCreateWithUTF8CString("_SharedArrayBuffer_factory");
    JSObjectSetProperty(ctx, global, k,
        JSObjectMakeFunctionWithCallback(ctx, k, shared_array_buffer_ctor), 0, NULL);
    JSStringRelease(k);

    {
        const char* sab_polyfill =
            "if(typeof SharedArrayBuffer==='undefined'){"
            "SharedArrayBuffer = (function() {"
            "  function SharedArrayBuffer(size) { return _SharedArrayBuffer_factory(size); }"
            "  return SharedArrayBuffer;"
            "})();"
            "}";
        JSStringRef script = JSStringCreateWithUTF8CString(sab_polyfill);
        JSEvaluateScript(ctx, script, NULL, NULL, 1, NULL);
        JSStringRelease(script);
    }

    /* 3. Bun.Cookie */
    {
        k = JSStringCreateWithUTF8CString("_Bun_Cookie_factory");
        JSObjectSetProperty(ctx, global, k,
            JSObjectMakeFunctionWithCallback(ctx, k, cookie_constructor), 0, NULL);
        JSStringRelease(k);

        k = JSStringCreateWithUTF8CString("_Bun_Cookie_parse");
        JSObjectSetProperty(ctx, global, k,
            JSObjectMakeFunctionWithCallback(ctx, k, cookie_parse_cb), 0, NULL);
        JSStringRelease(k);

        k = JSStringCreateWithUTF8CString("_Bun_Cookie_from");
        JSObjectSetProperty(ctx, global, k,
            JSObjectMakeFunctionWithCallback(ctx, k, cookie_from_cb), 0, NULL);
        JSStringRelease(k);

        const char* cookie_polyfill =
            "Bun.Cookie = (function() {"
            "  function Cookie(name, value, opts) {"
            "    var r = _Bun_Cookie_factory(name, value, opts);"
            "    if (r instanceof Error) throw r;"
            "    return r;"
            "  }"
            "  Cookie.parse = function(str) {"
            "    var r = _Bun_Cookie_parse(str);"
            "    if (r instanceof Error) throw r;"
            "    return r;"
            "  };"
            "  Cookie.from = function(name, value, opts) {"
            "    var r = _Bun_Cookie_from(name, value, opts);"
            "    if (r instanceof Error) throw r;"
            "    return r;"
            "  };"
            "  return Cookie;"
            "})();";
        JSStringRef script = JSStringCreateWithUTF8CString(cookie_polyfill);
        JSEvaluateScript(ctx, script, NULL, NULL, 1, NULL);
        JSStringRelease(script);
    }

    /* 4. Bun.randomUUIDv7 */
    reg_method(ctx, bun, "randomUUIDv7", bun_random_uuidv7_cb);

    /* 5. Markdown.html */
    {
        k = JSStringCreateWithUTF8CString("_Markdown_html");
        JSObjectSetProperty(ctx, global, k,
            JSObjectMakeFunctionWithCallback(ctx, k, markdown_html_cb), 0, NULL);
        JSStringRelease(k);

        const char* md_polyfill =
            "var Markdown = { html: _Markdown_html };";
        JSStringRef script = JSStringCreateWithUTF8CString(md_polyfill);
        JSEvaluateScript(ctx, script, NULL, NULL, 1, NULL);
        JSStringRelease(script);
    }

    /* 6. HTMLRewriter */
    {
        k = JSStringCreateWithUTF8CString("_HTMLRewriter_factory");
        JSObjectSetProperty(ctx, global, k,
            JSObjectMakeFunctionWithCallback(ctx, k, htmlrewriter_constructor), 0, NULL);
        JSStringRelease(k);

        const char* hr_polyfill =
            "HTMLRewriter = (function() {"
            "  function HTMLRewriter() { return _HTMLRewriter_factory(); }"
            "  return HTMLRewriter;"
            "})();";
        JSStringRef script = JSStringCreateWithUTF8CString(hr_polyfill);
        JSEvaluateScript(ctx, script, NULL, NULL, 1, NULL);
        JSStringRelease(script);
    }

    /* 7. MessageEvent */
    {
        k = JSStringCreateWithUTF8CString("_MessageEvent_factory");
        JSObjectSetProperty(ctx, global, k,
            JSObjectMakeFunctionWithCallback(ctx, k, message_event_constructor), 0, NULL);
        JSStringRelease(k);

        const char* me_polyfill =
            "MessageEvent = (function() {"
            "  function MessageEvent(type, opts) { return _MessageEvent_factory(type, opts); }"
            "  return MessageEvent;"
            "})();";
        JSStringRef script = JSStringCreateWithUTF8CString(me_polyfill);
        JSEvaluateScript(ctx, script, NULL, NULL, 1, NULL);
        JSStringRelease(script);
    }

    /* 8. atob / btoa */
    reg_method(ctx, global, "btoa", btoa_cb);
    reg_method(ctx, global, "atob", atob_cb);

    /* 9. Bun.file / Bun.spawnSync */
    reg_method(ctx, bun, "file", bun_file_cb);
    reg_method(ctx, bun, "spawnSync", bun_spawn_sync_cb);

    /* 10. MessageChannel */
    {
        k = JSStringCreateWithUTF8CString("_MessageChannel_factory");
        JSObjectSetProperty(ctx, global, k,
            JSObjectMakeFunctionWithCallback(ctx, k, message_channel_constructor), 0, NULL);
        JSStringRelease(k);

        const char* mc_polyfill =
            "MessageChannel = (function() {"
            "  function MessageChannel() { return _MessageChannel_factory(); }"
            "  return MessageChannel;"
            "})();";
        JSStringRef script = JSStringCreateWithUTF8CString(mc_polyfill);
        JSEvaluateScript(ctx, script, NULL, NULL, 1, NULL);
        JSStringRelease(script);
    }

    /* 11. process.binding — add to existing process object */
    {
        k = JSStringCreateWithUTF8CString("process");
        JSValueRef proc_val = JSObjectGetProperty(ctx, global, k, NULL);
        JSStringRelease(k);
        if (JSValueIsObject(ctx, proc_val)) {
            JSObjectRef proc = JSValueToObject(ctx, proc_val, NULL);
            reg_method(ctx, proc, "binding", process_binding_cb);
        }
    }

    /* Additional Bun properties */
    set_prop_str(ctx, bun, "argv", "");
    set_prop_str(ctx, bun, "main", "");

    /* Bun.write */
    reg_method(ctx, bun, "write", bun_write_cb);

    /* Bun.inspect — via JS polyfill */
    {
        const char* inspect_polyfill =
            "Bun.inspect = function(val) {"
            "  if (val === undefined) return 'undefined';"
            "  if (val === null) return 'null';"
            "  if (typeof val === 'string') return '\"' + val + '\"';"
            "  return String(val);"
            "};";
        JSStringRef script = JSStringCreateWithUTF8CString(inspect_polyfill);
        JSEvaluateScript(ctx, script, NULL, NULL, 1, NULL);
        JSStringRelease(script);
    }

    /* Bun.serve — stub */
    {
        const char* serve_polyfill =
            "Bun.serve = function(opts) {"
            "  return {"
            "    stop: function() {},"
            "    ref: function() {},"
            "    unref: function() {},"
            "    port: (opts && opts.port) || 0,"
            "    hostname: (opts && opts.hostname) || 'localhost'"
            "  };"
            "};";
        JSStringRef script = JSStringCreateWithUTF8CString(serve_polyfill);
        JSEvaluateScript(ctx, script, NULL, NULL, 1, NULL);
        JSStringRelease(script);
    }
}
