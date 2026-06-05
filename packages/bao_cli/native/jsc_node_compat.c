/*
 * jsc_node_compat.c — Node.js compatible API registration for JSC worker
 *
 * Implements:
 *   - global module = { exports: {} }
 *   - global exports = module.exports
 *   - global __filename / __dirname (set per-script via node_compat_set_filename)
 *   - process.nextTick(callback)
 *   - require() enhancement for built-in modules:
 *       "events", "util", "os", "assert", "path", "fs"
 *   - EventEmitter (JS-level implementation via require("events"))
 */

#include "jsc_node_compat.h"
#include <sys/utsname.h>
#include <sys/sysinfo.h>

/* ============================================================================
 * Shared globals — the module.exports object must be stable across require()
 * ============================================================================ */

/* Global module.exports object, created once and refreshed per-script */
static JSObjectRef g_module_exports = NULL;

/* ============================================================================
 * Helper: eval a JS string and return the result
 * ============================================================================ */

static JSValueRef eval_js(JSContextRef ctx, const char* source, const char* source_url) {
    JSStringRef script = JSStringCreateWithUTF8CString(source);
    JSStringRef url = source_url ? JSStringCreateWithUTF8CString(source_url) : NULL;
    JSValueRef ex = NULL;
    JSValueRef result = JSEvaluateScript(ctx, script, NULL, url, 1, &ex);
    JSStringRelease(script);
    if (url) JSStringRelease(url);
    if (ex) {
        char* m = to_utf8(ctx, ex);
        fprintf(stderr, "node_compat eval error: %s\n", m);
        free(m);
        return JSValueMakeUndefined(ctx);
    }
    return result;
}

/* ============================================================================
 * node_compat_set_filename — set __filename and __dirname for current script
 * ============================================================================ */

void node_compat_set_filename(JSContextRef ctx, JSObjectRef global, const char* filepath) {
    if (!filepath || filepath[0] == '\0') {
        /* No filepath provided — set to empty string */
        set_prop_str(ctx, global, "__filename", "");
        set_prop_str(ctx, global, "__dirname", "");
        return;
    }

    /* Set __filename */
    set_prop_str(ctx, global, "__filename", filepath);

    /* Compute __dirname by stripping everything after the last '/' */
    const char* last_slash = strrchr(filepath, '/');
    if (last_slash && last_slash != filepath) {
        size_t dirlen = last_slash - filepath;
        char* dir = malloc(dirlen + 1);
        memcpy(dir, filepath, dirlen);
        dir[dirlen] = '\0';
        set_prop_str(ctx, global, "__dirname", dir);
        free(dir);
    } else if (last_slash == filepath) {
        /* Root directory */
        set_prop_str(ctx, global, "__dirname", "/");
    } else {
        /* No slash — use current directory */
        set_prop_str(ctx, global, "__dirname", ".");
    }
}

/* ============================================================================
 * process.nextTick — implemented via Promise.resolve().then(cb)
 * ============================================================================ */

static JSValueRef process_nextTick_cb(JSContextRef ctx, JSObjectRef function,
    JSObjectRef thisObject, size_t argc, const JSValueRef argv[], JSValueRef* exception) {
    (void)function; (void)thisObject; (void)exception;
    if (argc < 1 || !JSValueIsObject(ctx, argv[0])) {
        return make_error(ctx, "process.nextTick: callback required", exception);
    }
    /* Use Promise.resolve().then(cb) to schedule on microtask queue */
    const char* code =
        "(function(cb, args) {"
        "  Promise.resolve().then(function() {"
        "    if (typeof cb === 'function') {"
        "      if (args && args.length > 0) { cb.apply(null, args); }"
        "      else { cb(); }"
        "    }"
        "  });"
        "})";
    JSValueRef ex = NULL;
    JSValueRef nextTickFn = eval_js(ctx, code, "node_compat:nextTick");
    if (!nextTickFn || JSValueIsUndefined(ctx, nextTickFn)) {
        return JSValueMakeUndefined(ctx);
    }
    JSObjectRef fn = JSValueToObject(ctx, nextTickFn, &ex);
    if (ex || !fn) return JSValueMakeUndefined(ctx);

    /* Build args array for the callback */
    JSValueRef call_args[2];
    call_args[0] = argv[0]; /* callback function */
    if (argc > 1) {
        /* Extra args passed to nextTick */
        JSValueRef* extra = malloc((argc - 1) * sizeof(JSValueRef));
        for (size_t i = 1; i < argc; i++) extra[i - 1] = argv[i];
        call_args[1] = JSObjectMakeArray(ctx, argc - 1, extra, NULL);
        free(extra);
    } else {
        call_args[1] = JSObjectMakeArray(ctx, 0, NULL, NULL);
    }
    JSObjectCallAsFunction(ctx, fn, NULL, 2, call_args, &ex);
    return JSValueMakeUndefined(ctx);
}

/* ============================================================================
 * Built-in module: "events" — EventEmitter
 * ============================================================================ */

static JSValueRef create_events_module(JSContextRef ctx) {
    /*
     * Register EventEmitter as a global constructor via eval,
     * then return a module object that references it.
     * We cannot return the constructor from eval as a value because
     * JSC loses the [[Construct]] internal slot.
     * Instead, eval defines EventEmitter globally and we build the module in C.
     */

    /* Define EventEmitter constructor and prototype in global scope */
    const char* events_source =
        "function EventEmitter() {\n"
        "  this._events = Object.create(null);\n"
        "  this._maxListeners = 10;\n"
        "}\n"
        "\n"
        "EventEmitter.prototype.on = function(event, listener) {\n"
        "  if (typeof listener !== 'function') throw new TypeError('listener must be a function');\n"
        "  if (!this._events[event]) this._events[event] = [];\n"
        "  this._events[event].push(listener);\n"
        "  if (this._events[event].length > this._maxListeners) {\n"
        "    process.stderr.write('Warning: possible EventEmitter memory leak detected. '\n"
        "      + this._events[event].length + ' ' + event + ' listeners added. '\n"
        "      + 'Use emitter.setMaxListeners() to increase limit\\n');\n"
        "  }\n"
        "  return this;\n"
        "};\n"
        "\n"
        "EventEmitter.prototype.addListener = EventEmitter.prototype.on;\n"
        "\n"
        "EventEmitter.prototype.once = function(event, listener) {\n"
        "  if (typeof listener !== 'function') throw new TypeError('listener must be a function');\n"
        "  var self = this;\n"
        "  function onceWrapper() {\n"
        "    self.removeListener(event, onceWrapper);\n"
        "    return listener.apply(this, arguments);\n"
        "  }\n"
        "  onceWrapper._original = listener;\n"
        "  return this.on(event, onceWrapper);\n"
        "};\n"
        "\n"
        "EventEmitter.prototype.off = function(event, listener) {\n"
        "  return this.removeListener(event, listener);\n"
        "};\n"
        "\n"
        "EventEmitter.prototype.removeListener = function(event, listener) {\n"
        "  var list = this._events[event];\n"
        "  if (!list) return this;\n"
        "  for (var i = list.length - 1; i >= 0; i--) {\n"
        "    if (list[i] === listener || list[i]._original === listener) {\n"
        "      list.splice(i, 1);\n"
        "      break;\n"
        "    }\n"
        "  }\n"
        "  if (list.length === 0) delete this._events[event];\n"
        "  return this;\n"
        "};\n"
        "\n"
        "EventEmitter.prototype.emit = function(event) {\n"
        "  var list = this._events[event];\n"
        "  if (!list) return false;\n"
        "  var args = Array.prototype.slice.call(arguments, 1);\n"
        "  var listeners = list.slice();\n"
        "  for (var i = 0; i < listeners.length; i++) {\n"
        "    listeners[i].apply(this, args);\n"
        "  }\n"
        "  return true;\n"
        "};\n"
        "\n"
        "EventEmitter.prototype.removeAllListeners = function(event) {\n"
        "  if (event) { delete this._events[event]; }\n"
        "  else { this._events = Object.create(null); }\n"
        "  return this;\n"
        "};\n"
        "\n"
        "EventEmitter.prototype.listeners = function(event) {\n"
        "  return this._events[event] ? this._events[event].slice() : [];\n"
        "};\n"
        "\n"
        "EventEmitter.prototype.setMaxListeners = function(n) {\n"
        "  this._maxListeners = n;\n"
        "  return this;\n"
        "};\n"
        "\n"
        "EventEmitter.prototype.getMaxListeners = function() {\n"
        "  return this._maxListeners;\n"
        "};\n"
        "\n"
        "EventEmitter.prototype.eventNames = function() {\n"
        "  return Object.keys(this._events);\n"
        "};\n"
        "\n"
        "EventEmitter.prototype.prependListener = function(event, listener) {\n"
        "  if (typeof listener !== 'function') throw new TypeError('listener must be a function');\n"
        "  if (!this._events[event]) this._events[event] = [];\n"
        "  this._events[event].unshift(listener);\n"
        "  return this;\n"
        "};\n"
        "\n"
        "EventEmitter.prototype.prependOnceListener = function(event, listener) {\n"
        "  if (typeof listener !== 'function') throw new TypeError('listener must be a function');\n"
        "  var self = this;\n"
        "  function onceWrapper() {\n"
        "    self.removeListener(event, onceWrapper);\n"
        "    return listener.apply(this, arguments);\n"
        "  }\n"
        "  onceWrapper._original = listener;\n"
        "  return this.prependListener(event, onceWrapper);\n"
        "};\n"
        "\n"
        "EventEmitter.EventEmitter = EventEmitter;\n"
        "EventEmitter.defaultMaxListeners = 10;\n"
        "EventEmitter.listenerCount = function(emitter, event) {\n"
        "  var list = emitter._events[event];\n"
        "  return list ? list.length : 0;\n"
        "};\n";

    eval_js(ctx, events_source, "node_compat:events");

    /* Now build the module object referencing the global EventEmitter */
    JSObjectRef g = JSContextGetGlobalObject(ctx);
    JSStringRef k = JSStringCreateWithUTF8CString("EventEmitter");
    JSValueRef ee = JSObjectGetProperty(ctx, g, k, NULL);
    JSStringRelease(k);

    if (!ee || JSValueIsUndefined(ctx, ee)) {
        return JSObjectMake(ctx, NULL, NULL);
    }

    /* Build events module = EventEmitter constructor with EventEmitter property */
    /* The module IS the EventEmitter constructor, with EventEmitter.EventEmitter = EventEmitter */
    /* Already set in JS above */
    JSObjectRef module_obj = JSValueToObject(ctx, ee, NULL);
    return module_obj;
}

/* ============================================================================
 * Built-in module: "util"
 * ============================================================================ */

/* util.inspect — simple recursive serializer */
static JSValueRef util_inspect_cb(JSContextRef ctx, JSObjectRef function,
    JSObjectRef thisObject, size_t argc, const JSValueRef argv[], JSValueRef* exception) {
    (void)function; (void)thisObject; (void)exception;
    if (argc < 1) return make_string(ctx, "undefined");

    /* Simple approach: convert to string with some type info */
    if (JSValueIsUndefined(ctx, argv[0])) return make_string(ctx, "undefined");
    if (JSValueIsNull(ctx, argv[0])) return make_string(ctx, "null");

    if (JSValueIsString(ctx, argv[0])) {
        char* s = to_utf8(ctx, argv[0]);
        size_t len = strlen(s);
        char* buf = malloc(len + 4);
        snprintf(buf, len + 4, "'%s'", s);
        JSValueRef v = make_string(ctx, buf);
        free(buf);
        free(s);
        return v;
    }

    if (JSValueIsNumber(ctx, argv[0])) {
        char* s = to_utf8(ctx, argv[0]);
        JSValueRef v = make_string(ctx, s);
        free(s);
        return v;
    }

    if (JSValueIsBoolean(ctx, argv[0])) {
        int b = JSValueToBoolean(ctx, argv[0]);
        return make_string(ctx, b ? "true" : "false");
    }

    if (JSValueIsObject(ctx, argv[0])) {
        /* Check if it's a function */
        /* For objects, just use toString for now */
        char* s = to_utf8(ctx, argv[0]);
        JSValueRef v = make_string(ctx, s);
        free(s);
        return v;
    }

    char* s = to_utf8(ctx, argv[0]);
    JSValueRef v = make_string(ctx, s);
    free(s);
    return v;
}

/* util.promisify — wraps a callback-style function into a Promise-returning one */
static JSValueRef util_promisify_cb(JSContextRef ctx, JSObjectRef function,
    JSObjectRef thisObject, size_t argc, const JSValueRef argv[], JSValueRef* exception) {
    (void)function; (void)thisObject; (void)exception;
    if (argc < 1 || !JSValueIsObject(ctx, argv[0])) {
        return make_error(ctx, "util.promisify: original function required", exception);
    }
    /* Return a wrapper that calls original and returns a Promise.
       We store the original function as a property on the wrapper. */
    const char* code =
        "(function(orig) {\n"
        "  function promisified() {\n"
        "    var args = Array.prototype.slice.call(arguments);\n"
        "    return new Promise(function(resolve, reject) {\n"
        "      args.push(function(err, result) {\n"
        "        if (err) reject(err);\n"
        "        else resolve(result);\n"
        "      });\n"
        "      orig.apply(null, args);\n"
        "    });\n"
        "  }\n"
        "  promisified._original = orig;\n"
        "  return promisified;\n"
        "})\n";

    JSValueRef factoryFn = eval_js(ctx, code, "node_compat:promisify_factory");
    if (!factoryFn || JSValueIsUndefined(ctx, factoryFn)) {
        return argv[0]; /* fallback: return original */
    }
    JSValueRef ex = NULL;
    JSObjectRef factory = JSValueToObject(ctx, factoryFn, &ex);
    if (ex || !factory) return argv[0];

    JSValueRef result = JSObjectCallAsFunction(ctx, factory, NULL, 1, argv, &ex);
    if (ex) return argv[0];
    return result ? result : argv[0];
}

/* util.callbackify — wraps a Promise-returning function into callback-style */
static JSValueRef util_callbackify_cb(JSContextRef ctx, JSObjectRef function,
    JSObjectRef thisObject, size_t argc, const JSValueRef argv[], JSValueRef* exception) {
    (void)function; (void)thisObject; (void)exception;
    if (argc < 1 || !JSValueIsObject(ctx, argv[0])) {
        return make_error(ctx, "util.callbackify: async function required", exception);
    }
    const char* code =
        "(function(orig) {\n"
        "  return function callbackified() {\n"
        "    var args = Array.prototype.slice.call(arguments);\n"
        "    var cb = args.pop();\n"
        "    var p;\n"
        "    try { p = orig.apply(null, args); }\n"
        "    catch(e) { return cb(e); }\n"
        "    if (p && typeof p.then === 'function') {\n"
        "      p.then(function(val) { cb(null, val); }, function(err) { cb(err); });\n"
        "    } else {\n"
        "      cb(null, p);\n"
        "    }\n"
        "  };\n"
        "})\n";
    JSValueRef factoryFn = eval_js(ctx, code, "node_compat:callbackify_factory");
    if (!factoryFn || JSValueIsUndefined(ctx, factoryFn)) return argv[0];
    JSValueRef ex = NULL;
    JSObjectRef factory = JSValueToObject(ctx, factoryFn, &ex);
    if (ex || !factory) return argv[0];
    JSValueRef result = JSObjectCallAsFunction(ctx, factory, NULL, 1, argv, &ex);
    if (ex) return argv[0];
    return result ? result : argv[0];
}

/* util.inherits(ctor, superCtor) */
static JSValueRef util_inherits_cb(JSContextRef ctx, JSObjectRef function,
    JSObjectRef thisObject, size_t argc, const JSValueRef argv[], JSValueRef* exception) {
    (void)function; (void)thisObject; (void)exception;
    if (argc < 2) return JSValueMakeUndefined(ctx);
    const char* code =
        "(function(ctor, superCtor) {\n"
        "  if (ctor === undefined || ctor === null) throw new TypeError('ctor must be a function');\n"
        "  if (superCtor === undefined || superCtor === null) throw new TypeError('superCtor must be a function');\n"
        "  ctor.super_ = superCtor;\n"
        "  ctor.prototype = Object.create(superCtor.prototype, {\n"
        "    constructor: { value: ctor, enumerable: false, writable: true, configurable: true }\n"
        "  });\n"
        "})\n";
    JSValueRef factoryFn = eval_js(ctx, code, "node_compat:inherits_factory");
    if (!factoryFn || JSValueIsUndefined(ctx, factoryFn)) return JSValueMakeUndefined(ctx);
    JSValueRef ex = NULL;
    JSObjectRef factory = JSValueToObject(ctx, factoryFn, &ex);
    if (ex || !factory) return JSValueMakeUndefined(ctx);
    JSObjectCallAsFunction(ctx, factory, NULL, 2, argv, &ex);
    return JSValueMakeUndefined(ctx);
}

/* util.format(fmt, ...args) */
static JSValueRef util_format_cb(JSContextRef ctx, JSObjectRef function,
    JSObjectRef thisObject, size_t argc, const JSValueRef argv[], JSValueRef* exception) {
    (void)function; (void)thisObject; (void)exception;
    if (argc == 0) return make_string(ctx, "");
    /* Simple implementation: use a JS polyfill */
    const char* code =
        "(function() {\n"
        "  var args = Array.prototype.slice.call(arguments);\n"
        "  if (args.length === 0) return '';\n"
        "  var fmt = args[0];\n"
        "  if (typeof fmt !== 'string') return args.map(function(a) { return String(a); }).join(' ');\n"
        "  var i = 1;\n"
        "  return fmt.replace(/%[sdjifoO%]/g, function(m) {\n"
        "    if (m === '%%') return '%';\n"
        "    if (i >= args.length) return m;\n"
        "    var val = args[i++];\n"
        "    switch(m) {\n"
        "      case '%s': return String(val);\n"
        "      case '%d': return Number(val);\n"
        "      case '%j': try { return JSON.stringify(val); } catch(e) { return '[Circular]'; }\n"
        "      case '%i': return parseInt(val, 10);\n"
        "      case '%f': return parseFloat(val);\n"
        "      case '%o': case '%O': return JSON.stringify(val, null, 2);\n"
        "      default: return m;\n"
        "    }\n"
        "  });\n"
        "})\n";
    JSValueRef factoryFn = eval_js(ctx, code, "node_compat:format");
    if (!factoryFn || JSValueIsUndefined(ctx, factoryFn)) {
        if (argc < 1) return make_string(ctx, "");
        char* s = to_utf8(ctx, argv[0]);
        JSValueRef v = make_string(ctx, s);
        free(s);
        return v;
    }
    JSValueRef ex = NULL;
    JSObjectRef factory = JSValueToObject(ctx, factoryFn, &ex);
    if (ex || !factory) {
        char* s = to_utf8(ctx, argv[0]);
        JSValueRef v = make_string(ctx, s);
        free(s);
        return v;
    }
    JSValueRef result = JSObjectCallAsFunction(ctx, factory, NULL, argc, argv, &ex);
    return result ? result : make_string(ctx, "");
}

/* util.deprecate(fn, msg) */
static JSValueRef util_deprecate_cb(JSContextRef ctx, JSObjectRef function,
    JSObjectRef thisObject, size_t argc, const JSValueRef argv[], JSValueRef* exception) {
    (void)function; (void)thisObject; (void)exception;
    if (argc < 1 || !JSValueIsObject(ctx, argv[0])) return JSValueMakeUndefined(ctx);
    const char* code =
        "(function(fn, msg) {\n"
        "  var warned = false;\n"
        "  function deprecated() {\n"
        "    if (!warned) {\n"
        "      process.stderr.write('DeprecationWarning: ' + (msg || 'This function is deprecated') + '\\n');\n"
        "      warned = true;\n"
        "    }\n"
        "    return fn.apply(this, arguments);\n"
        "  }\n"
        "  return deprecated;\n"
        "})\n";
    JSValueRef factoryFn = eval_js(ctx, code, "node_compat:deprecate_factory");
    if (!factoryFn || JSValueIsUndefined(ctx, factoryFn)) return argv[0];
    JSValueRef ex = NULL;
    JSObjectRef factory = JSValueToObject(ctx, factoryFn, &ex);
    if (ex || !factory) return argv[0];
    JSValueRef result = JSObjectCallAsFunction(ctx, factory, NULL, argc, argv, &ex);
    return result ? result : argv[0];
}

static JSValueRef create_util_module(JSContextRef ctx) {
    /*
     * Build the util module by eval-ing a JS expression that returns the complete
     * module object. This avoids the function-value-corruption issue when using
     * JSObjectGetProperty + JSObjectSetProperty.
     * Only inspect stays as a C callback since it needs low-level value testing.
     */

    /* First, register inspect as a hidden global callback */
    JSStringRef k = JSStringCreateWithUTF8CString("__util_inspect_cb__");
    JSObjectRef inspect_fn = JSObjectMakeFunctionWithCallback(ctx, k, util_inspect_cb);
    JSObjectRef g = JSContextGetGlobalObject(ctx);
    JSObjectSetProperty(ctx, g, k, inspect_fn, 0, NULL);
    JSStringRelease(k);

    /* Now eval a JS expression that builds the complete module and returns it */
    const char* util_module_js =
        "(function() {\n"
        "  var m = {};\n"
        "  m.inspect = __util_inspect_cb__;\n"
        "  m.format = function() {\n"
        "    var args = Array.prototype.slice.call(arguments);\n"
        "    if (args.length === 0) return '';\n"
        "    var fmt = args[0];\n"
        "    if (typeof fmt !== 'string') return args.map(function(a) { return String(a); }).join(' ');\n"
        "    var i = 1;\n"
        "    return fmt.replace(/%[sdjifoO%]/g, function(m) {\n"
        "      if (m === '%%') return '%';\n"
        "      if (i >= args.length) return m;\n"
        "      var val = args[i++];\n"
        "      switch(m) {\n"
        "        case '%s': return String(val);\n"
        "        case '%d': return Number(val);\n"
        "        case '%j': try { return JSON.stringify(val); } catch(e) { return '[Circular]'; }\n"
        "        case '%i': return parseInt(val, 10);\n"
        "        case '%f': return parseFloat(val);\n"
        "        case '%o': case '%O': return JSON.stringify(val, null, 2);\n"
        "        default: return m;\n"
        "      }\n"
        "    });\n"
        "  };\n"
        "  m.promisify = function(orig) {\n"
        "    function promisified() {\n"
        "      var args = Array.prototype.slice.call(arguments);\n"
        "      return new Promise(function(resolve, reject) {\n"
        "        args.push(function(err, result) {\n"
        "          if (err) reject(err); else resolve(result);\n"
        "        });\n"
        "        orig.apply(null, args);\n"
        "      });\n"
        "    }\n"
        "    promisified._original = orig;\n"
        "    return promisified;\n"
        "  };\n"
        "  m.callbackify = function(orig) {\n"
        "    return function callbackified() {\n"
        "      var args = Array.prototype.slice.call(arguments);\n"
        "      var cb = args.pop();\n"
        "      var p;\n"
        "      try { p = orig.apply(null, args); }\n"
        "      catch(e) { return cb(e); }\n"
        "      if (p && typeof p.then === 'function') {\n"
        "        p.then(function(val) { cb(null, val); }, function(err) { cb(err); });\n"
        "      } else { cb(null, p); }\n"
        "    };\n"
        "  };\n"
        "  m.inherits = function(ctor, superCtor) {\n"
        "    if (ctor === undefined || ctor === null) throw new TypeError('ctor must be a function');\n"
        "    if (superCtor === undefined || superCtor === null) throw new TypeError('superCtor must be a function');\n"
        "    ctor.super_ = superCtor;\n"
        "    ctor.prototype = Object.create(superCtor.prototype, {\n"
        "      constructor: { value: ctor, enumerable: false, writable: true, configurable: true }\n"
        "    });\n"
        "  };\n"
        "  m.deprecate = function(fn, msg) {\n"
        "    var warned = false;\n"
        "    function deprecated() {\n"
        "      if (!warned) {\n"
        "        process.stderr.write('DeprecationWarning: ' + (msg || 'This function is deprecated') + '\\n');\n"
        "        warned = true;\n"
        "      }\n"
        "      return fn.apply(this, arguments);\n"
        "    }\n"
        "    return deprecated;\n"
        "  };\n"
        "  return m;\n"
        "})()\n";

    JSValueRef result = eval_js(ctx, util_module_js, "node_compat:util_module");

    /* Clean up hidden global */
    k = JSStringCreateWithUTF8CString("__util_inspect_cb__");
    JSObjectSetProperty(ctx, g, k, JSValueMakeUndefined(ctx), 0, NULL);
    JSStringRelease(k);

    if (!result || JSValueIsUndefined(ctx, result)) {
        return JSObjectMake(ctx, NULL, NULL);
    }
    return result;
}

/* ============================================================================
 * Built-in module: "os"
 * ============================================================================ */

static JSValueRef os_platform_cb(JSContextRef ctx, JSObjectRef function,
    JSObjectRef thisObject, size_t argc, const JSValueRef argv[], JSValueRef* exception) {
    (void)function; (void)thisObject; (void)argc; (void)argv; (void)exception;
    return make_string(ctx, "linux");
}

static JSValueRef os_homedir_cb(JSContextRef ctx, JSObjectRef function,
    JSObjectRef thisObject, size_t argc, const JSValueRef argv[], JSValueRef* exception) {
    (void)function; (void)thisObject; (void)argc; (void)argv; (void)exception;
    const char* home = getenv("HOME");
    return make_string(ctx, home ? home : "/root");
}

static JSValueRef os_tmpdir_cb(JSContextRef ctx, JSObjectRef function,
    JSObjectRef thisObject, size_t argc, const JSValueRef argv[], JSValueRef* exception) {
    (void)function; (void)thisObject; (void)argc; (void)argv; (void)exception;
    const char* tmp = getenv("TMPDIR");
    if (!tmp) tmp = "/tmp";
    return make_string(ctx, tmp);
}

static JSValueRef os_cpus_cb(JSContextRef ctx, JSObjectRef function,
    JSObjectRef thisObject, size_t argc, const JSValueRef argv[], JSValueRef* exception) {
    (void)function; (void)thisObject; (void)argc; (void)argv; (void)exception;
    long nprocs = sysconf(_SC_NPROCESSORS_ONLN);
    if (nprocs < 1) nprocs = 1;

    JSValueRef* cpus = malloc(nprocs * sizeof(JSValueRef));
    for (long i = 0; i < nprocs; i++) {
        JSObjectRef cpu = JSObjectMake(ctx, NULL, NULL);
        set_prop_str(ctx, cpu, "model", "unknown");
        set_prop_num(ctx, cpu, "speed", 0);
        JSObjectRef times = JSObjectMake(ctx, NULL, NULL);
        set_prop_num(ctx, times, "user", 0);
        set_prop_num(ctx, times, "nice", 0);
        set_prop_num(ctx, times, "sys", 0);
        set_prop_num(ctx, times, "idle", 0);
        set_prop_num(ctx, times, "irq", 0);
        JSStringRef tk = JSStringCreateWithUTF8CString("times");
        JSObjectSetProperty(ctx, cpu, tk, times, 0, NULL);
        JSStringRelease(tk);
        cpus[i] = cpu;
    }
    JSObjectRef arr = JSObjectMakeArray(ctx, nprocs, cpus, NULL);
    free(cpus);
    return arr;
}

static JSValueRef os_totalmem_cb(JSContextRef ctx, JSObjectRef function,
    JSObjectRef thisObject, size_t argc, const JSValueRef argv[], JSValueRef* exception) {
    (void)function; (void)thisObject; (void)argc; (void)argv; (void)exception;
    struct sysinfo info;
    if (sysinfo(&info) != 0) return make_number(ctx, 0);
    return make_number(ctx, (double)(info.totalram * info.mem_unit));
}

static JSValueRef os_freemem_cb(JSContextRef ctx, JSObjectRef function,
    JSObjectRef thisObject, size_t argc, const JSValueRef argv[], JSValueRef* exception) {
    (void)function; (void)thisObject; (void)argc; (void)argv; (void)exception;
    struct sysinfo info;
    if (sysinfo(&info) != 0) return make_number(ctx, 0);
    return make_number(ctx, (double)(info.freeram * info.mem_unit));
}

static JSValueRef os_type_cb(JSContextRef ctx, JSObjectRef function,
    JSObjectRef thisObject, size_t argc, const JSValueRef argv[], JSValueRef* exception) {
    (void)function; (void)thisObject; (void)argc; (void)argv; (void)exception;
    struct utsname buf;
    if (uname(&buf) != 0) return make_string(ctx, "Linux");
    return make_string(ctx, buf.sysname);
}

static JSValueRef os_release_cb(JSContextRef ctx, JSObjectRef function,
    JSObjectRef thisObject, size_t argc, const JSValueRef argv[], JSValueRef* exception) {
    (void)function; (void)thisObject; (void)argc; (void)argv; (void)exception;
    struct utsname buf;
    if (uname(&buf) != 0) return make_string(ctx, "");
    return make_string(ctx, buf.release);
}

static JSValueRef os_arch_cb(JSContextRef ctx, JSObjectRef function,
    JSObjectRef thisObject, size_t argc, const JSValueRef argv[], JSValueRef* exception) {
    (void)function; (void)thisObject; (void)argc; (void)argv; (void)exception;
    return make_string(ctx, "x64");
}

static JSValueRef os_hostname_cb(JSContextRef ctx, JSObjectRef function,
    JSObjectRef thisObject, size_t argc, const JSValueRef argv[], JSValueRef* exception) {
    (void)function; (void)thisObject; (void)argc; (void)argv; (void)exception;
    char buf[256];
    if (gethostname(buf, sizeof(buf)) != 0) return make_string(ctx, "");
    return make_string(ctx, buf);
}

static JSValueRef os_EOL_cb(JSContextRef ctx, JSObjectRef function,
    JSObjectRef thisObject, size_t argc, const JSValueRef argv[], JSValueRef* exception) {
    (void)function; (void)thisObject; (void)argc; (void)argv; (void)exception;
    return make_string(ctx, "\n");
}

static JSValueRef create_os_module(JSContextRef ctx) {
    JSObjectRef os = JSObjectMake(ctx, NULL, NULL);
    reg_method(ctx, os, "platform", os_platform_cb);
    reg_method(ctx, os, "homedir", os_homedir_cb);
    reg_method(ctx, os, "tmpdir", os_tmpdir_cb);
    reg_method(ctx, os, "cpus", os_cpus_cb);
    reg_method(ctx, os, "totalmem", os_totalmem_cb);
    reg_method(ctx, os, "freemem", os_freemem_cb);
    reg_method(ctx, os, "type", os_type_cb);
    reg_method(ctx, os, "release", os_release_cb);
    reg_method(ctx, os, "arch", os_arch_cb);
    reg_method(ctx, os, "hostname", os_hostname_cb);
    set_prop_str(ctx, os, "EOL", "\n");
    return os;
}

/* ============================================================================
 * Built-in module: "assert"
 * ============================================================================ */

static JSValueRef assert_ok_cb(JSContextRef ctx, JSObjectRef function,
    JSObjectRef thisObject, size_t argc, const JSValueRef argv[], JSValueRef* exception) {
    (void)function; (void)thisObject;
    if (argc < 1) {
        return make_error(ctx, "assert: value required", exception);
    }
    int ok = JSValueToBoolean(ctx, argv[0]);
    if (!ok) {
        const char* msg = (argc >= 2) ? to_utf8(ctx, argv[1]) : "assertion failed";
        char* m = (argc >= 2) ? to_utf8(ctx, argv[1]) : strdup("assertion failed");
        char err[1024];
        snprintf(err, sizeof(err), "AssertionError: %s", m);
        free(m);
        return make_error(ctx, err, exception);
    }
    return JSValueMakeUndefined(ctx);
}

static JSValueRef assert_equal_cb(JSContextRef ctx, JSObjectRef function,
    JSObjectRef thisObject, size_t argc, const JSValueRef argv[], JSValueRef* exception) {
    (void)function; (void)thisObject;
    if (argc < 2) return make_error(ctx, "assert.equal: actual and expected required", exception);
    char* actual = to_utf8(ctx, argv[0]);
    char* expected = to_utf8(ctx, argv[1]);
    if (strcmp(actual, expected) != 0) {
        char err[1024];
        const char* msg = (argc >= 3) ? to_utf8(ctx, argv[2]) : NULL;
        if (msg) {
            snprintf(err, sizeof(err), "AssertionError: %s — expected %s, got %s", msg, expected, actual);
            free((char*)msg);
        } else {
            snprintf(err, sizeof(err), "AssertionError: expected %s, got %s", expected, actual);
        }
        free(actual); free(expected);
        return make_error(ctx, err, exception);
    }
    free(actual); free(expected);
    return JSValueMakeUndefined(ctx);
}

static JSValueRef assert_notEqual_cb(JSContextRef ctx, JSObjectRef function,
    JSObjectRef thisObject, size_t argc, const JSValueRef argv[], JSValueRef* exception) {
    (void)function; (void)thisObject;
    if (argc < 2) return make_error(ctx, "assert.notEqual: actual and expected required", exception);
    char* actual = to_utf8(ctx, argv[0]);
    char* expected = to_utf8(ctx, argv[1]);
    if (strcmp(actual, expected) == 0) {
        char err[1024];
        snprintf(err, sizeof(err), "AssertionError: %s should not equal %s", actual, expected);
        free(actual); free(expected);
        return make_error(ctx, err, exception);
    }
    free(actual); free(expected);
    return JSValueMakeUndefined(ctx);
}

/* assert.deepEqual — implemented via JS for recursive comparison */
static JSValueRef assert_deepEqual_cb(JSContextRef ctx, JSObjectRef function,
    JSObjectRef thisObject, size_t argc, const JSValueRef argv[], JSValueRef* exception) {
    (void)function; (void)thisObject;
    if (argc < 2) return make_error(ctx, "assert.deepEqual: actual and expected required", exception);

    /* Use a JS-based deep comparison */
    const char* code =
        "(function(actual, expected, message) {\n"
        "  function deepEqual(a, b) {\n"
        "    if (a === b) return true;\n"
        "    if (a === null || b === null) return false;\n"
        "    if (typeof a !== 'object' || typeof b !== 'object') return false;\n"
        "    var keysA = Object.keys(a);\n"
        "    var keysB = Object.keys(b);\n"
        "    if (keysA.length !== keysB.length) return false;\n"
        "    for (var i = 0; i < keysA.length; i++) {\n"
        "      var key = keysA[i];\n"
        "      if (!deepEqual(a[key], b[key])) return false;\n"
        "    }\n"
        "    return true;\n"
        "  }\n"
        "  if (!deepEqual(actual, expected)) {\n"
        "    throw new Error(message || ('AssertionError: ' + JSON.stringify(actual) + ' deepEqual ' + JSON.stringify(expected)));\n"
        "  }\n"
        "})\n";
    JSValueRef factoryFn = eval_js(ctx, code, "node_compat:deepEqual");
    if (!factoryFn || JSValueIsUndefined(ctx, factoryFn)) {
        /* Fallback: simple string compare */
        return assert_equal_cb(ctx, function, thisObject, argc, argv, exception);
    }
    JSValueRef ex = NULL;
    JSObjectRef factory = JSValueToObject(ctx, factoryFn, &ex);
    if (ex || !factory) return assert_equal_cb(ctx, function, thisObject, argc, argv, exception);

    JSValueRef result = JSObjectCallAsFunction(ctx, factory, NULL, argc, argv, &ex);
    if (ex) {
        char* m = to_utf8(ctx, ex);
        char err[1024];
        snprintf(err, sizeof(err), "AssertionError: %s", m);
        free(m);
        return make_error(ctx, err, exception);
    }
    return result ? result : JSValueMakeUndefined(ctx);
}

/* assert.throws — verify a function throws */
static JSValueRef assert_throws_cb(JSContextRef ctx, JSObjectRef function,
    JSObjectRef thisObject, size_t argc, const JSValueRef argv[], JSValueRef* exception) {
    (void)function; (void)thisObject;
    if (argc < 1 || !JSValueIsObject(ctx, argv[0])) {
        return make_error(ctx, "assert.throws: function required", exception);
    }
    const char* code =
        "(function(fn, errorType, message) {\n"
        "  try {\n"
        "    fn();\n"
        "    throw new Error(message || 'AssertionError: missing expected exception');\n"
        "  } catch(e) {\n"
        "    if (errorType && !(e instanceof errorType)) {\n"
        "      throw new Error(message || 'AssertionError: expected exception of a specific type');\n"
        "    }\n"
        "    /* Expected throw — pass */\n"
        "  }\n"
        "})\n";
    JSValueRef factoryFn = eval_js(ctx, code, "node_compat:throws");
    if (!factoryFn || JSValueIsUndefined(ctx, factoryFn)) {
        return JSValueMakeUndefined(ctx);
    }
    JSValueRef ex = NULL;
    JSObjectRef factory = JSValueToObject(ctx, factoryFn, &ex);
    if (ex || !factory) return JSValueMakeUndefined(ctx);

    JSValueRef result = JSObjectCallAsFunction(ctx, factory, NULL, argc, argv, &ex);
    if (ex) {
        char* m = to_utf8(ctx, ex);
        char err[1024];
        snprintf(err, sizeof(err), "AssertionError: %s", m);
        free(m);
        return make_error(ctx, err, exception);
    }
    return result ? result : JSValueMakeUndefined(ctx);
}

/* assert.doesNotThrow */
static JSValueRef assert_doesNotThrow_cb(JSContextRef ctx, JSObjectRef function,
    JSObjectRef thisObject, size_t argc, const JSValueRef argv[], JSValueRef* exception) {
    (void)function; (void)thisObject;
    if (argc < 1 || !JSValueIsObject(ctx, argv[0])) {
        return make_error(ctx, "assert.doesNotThrow: function required", exception);
    }
    const char* code =
        "(function(fn, message) {\n"
        "  try {\n"
        "    fn();\n"
        "  } catch(e) {\n"
        "    throw new Error(message || 'AssertionError: got unwanted exception');\n"
        "  }\n"
        "})\n";
    JSValueRef factoryFn = eval_js(ctx, code, "node_compat:doesNotThrow");
    if (!factoryFn || JSValueIsUndefined(ctx, factoryFn)) return JSValueMakeUndefined(ctx);
    JSValueRef ex = NULL;
    JSObjectRef factory = JSValueToObject(ctx, factoryFn, &ex);
    if (ex || !factory) return JSValueMakeUndefined(ctx);

    JSValueRef result = JSObjectCallAsFunction(ctx, factory, NULL, argc, argv, &ex);
    if (ex) {
        char* m = to_utf8(ctx, ex);
        char err[1024];
        snprintf(err, sizeof(err), "AssertionError: %s", m);
        free(m);
        return make_error(ctx, err, exception);
    }
    return result ? result : JSValueMakeUndefined(ctx);
}

/* assert.rejects — for async functions */
static JSValueRef assert_rejects_cb(JSContextRef ctx, JSObjectRef function,
    JSObjectRef thisObject, size_t argc, const JSValueRef argv[], JSValueRef* exception) {
    (void)function; (void)thisObject;
    if (argc < 1) return make_error(ctx, "assert.rejects: asyncFn or promise required", exception);
    const char* code =
        "(function(asyncFn, errorType, message) {\n"
        "  var p = (typeof asyncFn === 'function') ? asyncFn() : asyncFn;\n"
        "  if (!p || typeof p.then !== 'function') {\n"
        "    throw new Error(message || 'assert.rejects: expected a promise');\n"
        "  }\n"
        "  return p.then(function() {\n"
        "    throw new Error(message || 'AssertionError: missing expected rejection');\n"
        "  }, function(err) {\n"
        "    if (errorType && !(err instanceof errorType)) {\n"
        "      throw new Error(message || 'AssertionError: expected rejection of specific type');\n"
        "    }\n"
        "  });\n"
        "})\n";
    JSValueRef factoryFn = eval_js(ctx, code, "node_compat:rejects");
    if (!factoryFn || JSValueIsUndefined(ctx, factoryFn)) return JSValueMakeUndefined(ctx);
    JSValueRef ex = NULL;
    JSObjectRef factory = JSValueToObject(ctx, factoryFn, &ex);
    if (ex || !factory) return JSValueMakeUndefined(ctx);

    JSValueRef result = JSObjectCallAsFunction(ctx, factory, NULL, argc, argv, &ex);
    if (ex) {
        char* m = to_utf8(ctx, ex);
        char err[1024];
        snprintf(err, sizeof(err), "AssertionError: %s", m);
        free(m);
        return make_error(ctx, err, exception);
    }
    return result ? result : JSValueMakeUndefined(ctx);
}

/* The assert function itself — also callable as assert(value, message) */
static JSValueRef assert_function_cb(JSContextRef ctx, JSObjectRef function,
    JSObjectRef thisObject, size_t argc, const JSValueRef argv[], JSValueRef* exception) {
    return assert_ok_cb(ctx, function, thisObject, argc, argv, exception);
}

static JSValueRef create_assert_module(JSContextRef ctx) {
    /*
     * Build assert module entirely in JS via eval that returns a complete object.
     * All assert functions are JS-level since they need to throw errors.
     */

    const char* assert_module_js =
        "(function() {\n"
        "  var m = function assert(value, message) {\n"
        "    if (!value) throw new Error(message || 'assertion failed');\n"
        "  };\n"
        "  m.ok = function(value, message) {\n"
        "    if (!value) throw new Error(message || 'assertion failed');\n"
        "  };\n"
        "  m.equal = function(actual, expected, message) {\n"
        "    if (actual != expected) {\n"
        "      throw new Error(message || ('AssertionError: expected ' + expected + ', got ' + actual));\n"
        "    }\n"
        "  };\n"
        "  m.notEqual = function(actual, expected, message) {\n"
        "    if (actual == expected) {\n"
        "      throw new Error(message || ('AssertionError: ' + actual + ' should not equal ' + expected));\n"
        "    }\n"
        "  };\n"
        "  m.strictEqual = function(actual, expected, message) {\n"
        "    if (actual !== expected) {\n"
        "      throw new Error(message || ('AssertionError: expected ' + expected + ', got ' + actual));\n"
        "    }\n"
        "  };\n"
        "  m.notStrictEqual = function(actual, expected, message) {\n"
        "    if (actual === expected) {\n"
        "      throw new Error(message || ('AssertionError: ' + actual + ' should not strictly equal ' + expected));\n"
        "    }\n"
        "  };\n"
        "  m.deepEqual = function(actual, expected, message) {\n"
        "    function deepEqual(a, b) {\n"
        "      if (a === b) return true;\n"
        "      if (a === null || b === null) return false;\n"
        "      if (typeof a !== 'object' || typeof b !== 'object') return false;\n"
        "      var keysA = Object.keys(a);\n"
        "      var keysB = Object.keys(b);\n"
        "      if (keysA.length !== keysB.length) return false;\n"
        "      for (var i = 0; i < keysA.length; i++) {\n"
        "        var key = keysA[i];\n"
        "        if (!deepEqual(a[key], b[key])) return false;\n"
        "      }\n"
        "      return true;\n"
        "    }\n"
        "    if (!deepEqual(actual, expected)) {\n"
        "      throw new Error(message || ('AssertionError: ' + JSON.stringify(actual) + ' deepEqual ' + JSON.stringify(expected)));\n"
        "    }\n"
        "  };\n"
        "  m.throws = function(fn, errorType, message) {\n"
        "    try {\n"
        "      fn();\n"
        "      throw new Error(message || 'AssertionError: missing expected exception');\n"
        "    } catch(e) {\n"
        "      if (errorType && !(e instanceof errorType)) {\n"
        "        throw new Error(message || 'AssertionError: expected exception of a specific type');\n"
        "      }\n"
        "    }\n"
        "  };\n"
        "  m.doesNotThrow = function(fn, message) {\n"
        "    try { fn(); }\n"
        "    catch(e) { throw new Error(message || 'AssertionError: got unwanted exception'); }\n"
        "  };\n"
        "  m.rejects = function(asyncFn, errorType, message) {\n"
        "    var p = (typeof asyncFn === 'function') ? asyncFn() : asyncFn;\n"
        "    if (!p || typeof p.then !== 'function') {\n"
        "      throw new Error(message || 'assert.rejects: expected a promise');\n"
        "    }\n"
        "    return p.then(function() {\n"
        "      throw new Error(message || 'AssertionError: missing expected rejection');\n"
        "    }, function(err) {\n"
        "      if (errorType && !(err instanceof errorType)) {\n"
        "        throw new Error(message || 'AssertionError: expected rejection of specific type');\n"
        "      }\n"
        "    });\n"
        "  };\n"
        "  m.fail = function(message) {\n"
        "    throw new Error(message || 'assertion failed');\n"
        "  };\n"
        "  return m;\n"
        "})()\n";

    JSValueRef result = eval_js(ctx, assert_module_js, "node_compat:assert_module");
    if (!result || JSValueIsUndefined(ctx, result)) {
        return JSObjectMake(ctx, NULL, NULL);
    }
    return result;
}

/* ============================================================================
 * Enhanced require — intercepts built-in module names, falls back to file load
 * ============================================================================ */

/*
 * We cannot easily replace the require callback registered in jsc_worker.c
 * because that function does file I/O. Instead, we register the built-in
 * modules as globals and inject a require wrapper that checks built-ins first.
 *
 * The wrapper is:
 *   var _nativeRequire = require;
 *   var _builtinModules = { "events": eventsModule, ... };
 *   require = function(name) {
 *     if (_builtinModules[name]) return _builtinModules[name];
 *     return _nativeRequire(name);
 *   };
 */

static void inject_enhanced_require(JSContextRef ctx, JSObjectRef global) {
    /*
     * Strategy: Build EVERYTHING in a single JS eval. This avoids all issues
     * with JSObjectSetProperty losing function references.
     *
     * C callbacks for native operations (os, inspect, etc.) are registered as
     * hidden globals via JSObjectMakeFunctionWithCallback, then the JS eval
     * references them directly.
     *
     * 1. Register native C callbacks as hidden globals
     * 2. Define EventEmitter in global scope
     * 3. Eval a single large JS script that:
     *    - Builds all module objects
     *    - Creates enhanced require
     */

    /* Step 1: Define EventEmitter in global scope */
    create_events_module(ctx);

    /* Step 2: Register C callbacks as hidden globals */
    /* util.inspect */
    JSStringRef k;
    k = JSStringCreateWithUTF8CString("__cb_inspect__");
    JSObjectSetProperty(ctx, global, k,
        JSObjectMakeFunctionWithCallback(ctx, k, util_inspect_cb), 0, NULL);
    JSStringRelease(k);

    /* os functions */
    k = JSStringCreateWithUTF8CString("__cb_os_platform__");
    JSObjectSetProperty(ctx, global, k,
        JSObjectMakeFunctionWithCallback(ctx, k, os_platform_cb), 0, NULL);
    JSStringRelease(k);

    k = JSStringCreateWithUTF8CString("__cb_os_homedir__");
    JSObjectSetProperty(ctx, global, k,
        JSObjectMakeFunctionWithCallback(ctx, k, os_homedir_cb), 0, NULL);
    JSStringRelease(k);

    k = JSStringCreateWithUTF8CString("__cb_os_tmpdir__");
    JSObjectSetProperty(ctx, global, k,
        JSObjectMakeFunctionWithCallback(ctx, k, os_tmpdir_cb), 0, NULL);
    JSStringRelease(k);

    k = JSStringCreateWithUTF8CString("__cb_os_cpus__");
    JSObjectSetProperty(ctx, global, k,
        JSObjectMakeFunctionWithCallback(ctx, k, os_cpus_cb), 0, NULL);
    JSStringRelease(k);

    k = JSStringCreateWithUTF8CString("__cb_os_totalmem__");
    JSObjectSetProperty(ctx, global, k,
        JSObjectMakeFunctionWithCallback(ctx, k, os_totalmem_cb), 0, NULL);
    JSStringRelease(k);

    k = JSStringCreateWithUTF8CString("__cb_os_freemem__");
    JSObjectSetProperty(ctx, global, k,
        JSObjectMakeFunctionWithCallback(ctx, k, os_freemem_cb), 0, NULL);
    JSStringRelease(k);

    k = JSStringCreateWithUTF8CString("__cb_os_type__");
    JSObjectSetProperty(ctx, global, k,
        JSObjectMakeFunctionWithCallback(ctx, k, os_type_cb), 0, NULL);
    JSStringRelease(k);

    k = JSStringCreateWithUTF8CString("__cb_os_release__");
    JSObjectSetProperty(ctx, global, k,
        JSObjectMakeFunctionWithCallback(ctx, k, os_release_cb), 0, NULL);
    JSStringRelease(k);

    k = JSStringCreateWithUTF8CString("__cb_os_arch__");
    JSObjectSetProperty(ctx, global, k,
        JSObjectMakeFunctionWithCallback(ctx, k, os_arch_cb), 0, NULL);
    JSStringRelease(k);

    k = JSStringCreateWithUTF8CString("__cb_os_hostname__");
    JSObjectSetProperty(ctx, global, k,
        JSObjectMakeFunctionWithCallback(ctx, k, os_hostname_cb), 0, NULL);
    JSStringRelease(k);

    /* Step 3: Eval the entire module setup + enhanced require in one JS eval */
    const char* setup_code =
        "(function() {\n"
        /* util module */
        "  var util = {};\n"
        "  util.inspect = __cb_inspect__;\n"
        "  util.format = function() {\n"
        "    var args = Array.prototype.slice.call(arguments);\n"
        "    if (args.length === 0) return '';\n"
        "    var fmt = args[0];\n"
        "    if (typeof fmt !== 'string') return args.map(function(a) { return String(a); }).join(' ');\n"
        "    var i = 1;\n"
        "    return fmt.replace(/%[sdjifoO%]/g, function(m) {\n"
        "      if (m === '%%') return '%';\n"
        "      if (i >= args.length) return m;\n"
        "      var val = args[i++];\n"
        "      switch(m) {\n"
        "        case '%s': return String(val);\n"
        "        case '%d': return Number(val);\n"
        "        case '%j': try { return JSON.stringify(val); } catch(e) { return '[Circular]'; }\n"
        "        case '%i': return parseInt(val, 10);\n"
        "        case '%f': return parseFloat(val);\n"
        "        case '%o': case '%O': return JSON.stringify(val, null, 2);\n"
        "        default: return m;\n"
        "      }\n"
        "    });\n"
        "  };\n"
        "  util.promisify = function(orig) {\n"
        "    function promisified() {\n"
        "      var args = Array.prototype.slice.call(arguments);\n"
        "      return new Promise(function(resolve, reject) {\n"
        "        args.push(function(err, result) {\n"
        "          if (err) reject(err); else resolve(result);\n"
        "        });\n"
        "        orig.apply(null, args);\n"
        "      });\n"
        "    }\n"
        "    promisified._original = orig;\n"
        "    return promisified;\n"
        "  };\n"
        "  util.callbackify = function(orig) {\n"
        "    return function callbackified() {\n"
        "      var args = Array.prototype.slice.call(arguments);\n"
        "      var cb = args.pop();\n"
        "      var p;\n"
        "      try { p = orig.apply(null, args); }\n"
        "      catch(e) { return cb(e); }\n"
        "      if (p && typeof p.then === 'function') {\n"
        "        p.then(function(val) { cb(null, val); }, function(err) { cb(err); });\n"
        "      } else { cb(null, p); }\n"
        "    };\n"
        "  };\n"
        "  util.inherits = function(ctor, superCtor) {\n"
        "    if (!ctor) throw new TypeError('ctor must be a function');\n"
        "    if (!superCtor) throw new TypeError('superCtor must be a function');\n"
        "    ctor.super_ = superCtor;\n"
        "    ctor.prototype = Object.create(superCtor.prototype, {\n"
        "      constructor: { value: ctor, enumerable: false, writable: true, configurable: true }\n"
        "    });\n"
        "  };\n"
        "  util.deprecate = function(fn, msg) {\n"
        "    var warned = false;\n"
        "    function deprecated() {\n"
        "      if (!warned) {\n"
        "        process.stderr.write('DeprecationWarning: ' + (msg || 'This function is deprecated') + '\\n');\n"
        "        warned = true;\n"
        "      }\n"
        "      return fn.apply(this, arguments);\n"
        "    }\n"
        "    return deprecated;\n"
        "  };\n"
        "\n"
        /* os module */
        "  var os = {\n"
        "    platform: __cb_os_platform__,\n"
        "    homedir: __cb_os_homedir__,\n"
        "    tmpdir: __cb_os_tmpdir__,\n"
        "    cpus: __cb_os_cpus__,\n"
        "    totalmem: __cb_os_totalmem__,\n"
        "    freemem: __cb_os_freemem__,\n"
        "    type: __cb_os_type__,\n"
        "    release: __cb_os_release__,\n"
        "    arch: __cb_os_arch__,\n"
        "    hostname: __cb_os_hostname__,\n"
        "    EOL: '\\n'\n"
        "  };\n"
        "\n"
        /* assert module */
        "  var assertModule = function(value, message) {\n"
        "    if (!value) throw new Error(message || 'assertion failed');\n"
        "  };\n"
        "  assertModule.ok = function(value, message) {\n"
        "    if (!value) throw new Error(message || 'assertion failed');\n"
        "  };\n"
        "  assertModule.equal = function(actual, expected, message) {\n"
        "    if (actual != expected) throw new Error(message || ('expected ' + expected + ', got ' + actual));\n"
        "  };\n"
        "  assertModule.notEqual = function(actual, expected, message) {\n"
        "    if (actual == expected) throw new Error(message || (actual + ' should not equal ' + expected));\n"
        "  };\n"
        "  assertModule.strictEqual = function(actual, expected, message) {\n"
        "    if (actual !== expected) throw new Error(message || ('expected ' + expected + ', got ' + actual));\n"
        "  };\n"
        "  assertModule.notStrictEqual = function(actual, expected, message) {\n"
        "    if (actual === expected) throw new Error(message || (actual + ' should not equal ' + expected));\n"
        "  };\n"
        "  assertModule.deepEqual = function(actual, expected, message) {\n"
        "    function deepEqual(a, b) {\n"
        "      if (a === b) return true;\n"
        "      if (a === null || b === null) return false;\n"
        "      if (typeof a !== 'object' || typeof b !== 'object') return false;\n"
        "      var keysA = Object.keys(a), keysB = Object.keys(b);\n"
        "      if (keysA.length !== keysB.length) return false;\n"
        "      for (var i = 0; i < keysA.length; i++) {\n"
        "        if (!deepEqual(a[keysA[i]], b[keysA[i]])) return false;\n"
        "      }\n"
        "      return true;\n"
        "    }\n"
        "    if (!deepEqual(actual, expected))\n"
        "      throw new Error(message || ('deepEqual: ' + JSON.stringify(actual) + ' != ' + JSON.stringify(expected)));\n"
        "  };\n"
        "  assertModule.throws = function(fn, errorType, message) {\n"
        "    try { fn(); throw new Error(message || 'missing expected exception'); }\n"
        "    catch(e) { if (errorType && !(e instanceof errorType)) throw new Error(message || 'wrong exception type'); }\n"
        "  };\n"
        "  assertModule.doesNotThrow = function(fn, message) {\n"
        "    try { fn(); } catch(e) { throw new Error(message || 'got unwanted exception'); }\n"
        "  };\n"
        "  assertModule.fail = function(message) { throw new Error(message || 'assertion failed'); };\n"
        "\n"
        /* Enhanced require */
        "  var _nativeRequire = require;\n"
        "  var _builtins = {\n"
        "    'events': EventEmitter,\n"
        "    'util': util,\n"
        "    'os': os,\n"
        "    'assert': assertModule,\n"
        "    'fs': fs,\n"
        "    'path': path\n"
        "  };\n"
        "  function enhancedRequire(name) {\n"
        "    if (name && _builtins[name] !== undefined && _builtins[name] !== null) return _builtins[name];\n"
        "    return _nativeRequire(name);\n"
        "  }\n"
        "  enhancedRequire.resolve = function(name) { return name; };\n"
        "  enhancedRequire.cache = {};\n"
        "  enhancedRequire.builtin = Object.keys(_builtins);\n"
        "  require = enhancedRequire;\n"
        "})()\n";

    eval_js(ctx, setup_code, "node_compat:setup_all");

    /* Clean up hidden globals */
    const char* hidden[] = {
        "__cb_inspect__",
        "__cb_os_platform__", "__cb_os_homedir__", "__cb_os_tmpdir__",
        "__cb_os_cpus__", "__cb_os_totalmem__", "__cb_os_freemem__",
        "__cb_os_type__", "__cb_os_release__", "__cb_os_arch__", "__cb_os_hostname__"
    };
    for (int i = 0; i < 11; i++) {
        k = JSStringCreateWithUTF8CString(hidden[i]);
        JSObjectSetProperty(ctx, global, k, JSValueMakeUndefined(ctx), 0, NULL);
        JSStringRelease(k);
    }
}

/* ============================================================================
 * register_node_compat — main entry point
 * ============================================================================ */

void register_node_compat(JSContextRef ctx, JSObjectRef global) {
    /* 1. Register global module = { exports: {} } */
    JSObjectRef module_obj = JSObjectMake(ctx, NULL, NULL);
    JSObjectRef exports_obj = JSObjectMake(ctx, NULL, NULL);
    JSStringRef k = JSStringCreateWithUTF8CString("exports");
    JSObjectSetProperty(ctx, module_obj, k, exports_obj, 0, NULL);
    JSStringRelease(k);

    k = JSStringCreateWithUTF8CString("module");
    JSObjectSetProperty(ctx, global, k, module_obj, 0, NULL);
    JSStringRelease(k);

    /* 2. Register global exports = module.exports */
    k = JSStringCreateWithUTF8CString("exports");
    JSObjectSetProperty(ctx, global, k, exports_obj, 0, NULL);
    JSStringRelease(k);

    /* Store exports object for later reference */
    g_module_exports = exports_obj;

    /* 3. Set initial __filename and __dirname (empty until script is loaded) */
    set_prop_str(ctx, global, "__filename", "");
    set_prop_str(ctx, global, "__dirname", "");

    /* 4. Add process.nextTick to the existing process object */
    k = JSStringCreateWithUTF8CString("process");
    JSValueRef proc_val = JSObjectGetProperty(ctx, global, k, NULL);
    JSStringRelease(k);
    if (proc_val && JSValueIsObject(ctx, proc_val)) {
        JSObjectRef proc = JSValueToObject(ctx, proc_val, NULL);
        reg_method(ctx, proc, "nextTick", process_nextTick_cb);

        /* Add process.versions */
        JSObjectRef versions = JSObjectMake(ctx, NULL, NULL);
        set_prop_str(ctx, versions, "node", "18.0.0");
        set_prop_str(ctx, versions, "bao", "0.1.0");
        set_prop_str(ctx, versions, "v8", "10.0.0");
        set_prop_str(ctx, versions, "openssl", "3.0.0");
        k = JSStringCreateWithUTF8CString("versions");
        JSObjectSetProperty(ctx, proc, k, versions, 0, NULL);
        JSStringRelease(k);

        /* Add process.version (if not already set — it is by register_process, but ensure format) */
        /* register_process already sets version to "v0.1.0" — that's fine */

        /* Add process.config */
        JSObjectRef config = JSObjectMake(ctx, NULL, NULL);
        set_prop_str(ctx, config, "target_defaults", "{}");
        set_prop_str(ctx, config, "variables", "{}");
        k = JSStringCreateWithUTF8CString("config");
        JSObjectSetProperty(ctx, proc, k, config, 0, NULL);
        JSStringRelease(k);

        /* Add process.release */
        JSObjectRef release = JSObjectMake(ctx, NULL, NULL);
        set_prop_str(ctx, release, "name", "node");
        k = JSStringCreateWithUTF8CString("release");
        JSObjectSetProperty(ctx, proc, k, release, 0, NULL);
        JSStringRelease(k);

        /* Add process.execPath */
        set_prop_str(ctx, proc, "execPath", "/usr/local/bin/bao");

        /* Add process.title */
        set_prop_str(ctx, proc, "title", "bao");

        /* Add process.uptime */
        /* We can store the start time globally, but for simplicity, return 0 */

        /* Add process.memoryUsage */
        const char* memusage_code =
            "(function() {\n"
            "  return function memoryUsage() {\n"
            "    return { rss: 0, heapTotal: 0, heapUsed: 0, external: 0, arrayBuffers: 0 };\n"
            "  };\n"
            "})()\n";
        JSValueRef memusage = eval_js(ctx, memusage_code, "node_compat:memoryUsage");
        if (memusage && JSValueIsObject(ctx, memusage)) {
            k = JSStringCreateWithUTF8CString("memoryUsage");
            JSObjectSetProperty(ctx, proc, k, JSValueToObject(ctx, memusage, NULL), 0, NULL);
            JSStringRelease(k);
        }
    }

    /* 5. Inject enhanced require() with built-in modules */
    inject_enhanced_require(ctx, global);

    /* 6. Register global as 'globalThis' alias if not already set */
    k = JSStringCreateWithUTF8CString("globalThis");
    JSObjectSetProperty(ctx, global, k, global, 0, NULL);
    JSStringRelease(k);
}
