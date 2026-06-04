/*
 * jsc_bridge.c — JSC C API 回调桥接层
 *
 * Phase 1: 原生回调直接在 C 层实现（print, console.log 等）
 * 不 #include <JavaScriptCore/JavaScriptCore.h>，而是手动声明需要的类型和函数
 * （与 jsc_stubs.c 保持一致，避免构建系统需要额外的 -I 路径）
 *
 * 对应 Bun: src/jsc/bindings/ZigGlobalObject.cpp 中注册内置对象
 */

#include <stdint.h>
#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* ============================================================================
 * JSC 不透明类型 — 手动声明（与 jsc_stubs.c 一致）
 * ============================================================================ */
typedef void* JSContextRef;
typedef void* JSObjectRef;
typedef void* JSStringRef;
typedef void* JSValueRef;
typedef struct OpaqueJSContext* JSGlobalContextRef;

/* JSValue types enum */
typedef enum {
    kJSTypeUndefined,
    kJSTypeNull,
    kJSTypeBoolean,
    kJSTypeNumber,
    kJSTypeString,
    kJSTypeObject,
    kJSTypeSymbol
} JSType;

/* JSObjectCallAsFunctionCallback — 回调函数类型 */
typedef JSValueRef (*JSObjectCallAsFunctionCallback)(
    JSContextRef ctx,
    JSObjectRef function,
    JSObjectRef thisObject,
    size_t argumentCount,
    const JSValueRef arguments[],
    JSValueRef* exception
);

/* ============================================================================
 * JSC C API 函数声明 — extern（由 libJavaScriptCore.a 提供）
 * ============================================================================ */

/* Context */
extern JSGlobalContextRef JSGlobalContextCreate(JSObjectRef globalObjectClass);
extern void JSGlobalContextRelease(JSGlobalContextRef ctx);
extern JSObjectRef JSContextGetGlobalObject(JSContextRef ctx);

/* Script execution */
extern JSValueRef JSEvaluateScript(
    JSContextRef ctx, JSStringRef script, JSObjectRef thisObject,
    JSStringRef sourceURL, int startingLineNumber, JSValueRef* exception);

/* String */
extern JSStringRef JSStringCreateWithUTF8CString(const char* string);
extern void JSStringRelease(JSStringRef string);
extern size_t JSStringGetMaximumUTF8CStringSize(JSStringRef string);
extern size_t JSStringGetUTF8CString(JSStringRef string, char* buffer, size_t bufferSize);

/* Value creation */
extern JSValueRef JSValueMakeUndefined(JSContextRef ctx);
extern JSValueRef JSValueMakeNull(JSContextRef ctx);
extern JSValueRef JSValueMakeBoolean(JSContextRef ctx, int value);
extern JSValueRef JSValueMakeNumber(JSContextRef ctx, double value);
extern JSValueRef JSValueMakeString(JSContextRef ctx, JSStringRef string);

/* Value type check */
extern int JSValueIsUndefined(JSContextRef ctx, JSValueRef value);
extern int JSValueIsNull(JSContextRef ctx, JSValueRef value);
extern int JSValueIsBoolean(JSContextRef ctx, JSValueRef value);
extern int JSValueIsNumber(JSContextRef ctx, JSValueRef value);
extern int JSValueIsString(JSContextRef ctx, JSValueRef value);
extern int JSValueIsObject(JSContextRef ctx, JSValueRef value);

/* Value conversion */
extern int JSValueToBoolean(JSContextRef ctx, JSValueRef value);
extern double JSValueToNumber(JSContextRef ctx, JSValueRef value, JSValueRef* exception);
extern JSStringRef JSValueToStringCopy(JSContextRef ctx, JSValueRef value, JSValueRef* exception);

/* Object operations */
extern JSObjectRef JSObjectMake(JSContextRef ctx, void* jsClass, void* data);
extern JSObjectRef JSObjectMakeFunctionWithCallback(
    JSContextRef ctx, JSStringRef name, JSObjectCallAsFunctionCallback callAsFunction);
extern void JSObjectSetProperty(
    JSContextRef ctx, JSObjectRef object, JSStringRef propertyName,
    JSValueRef value, unsigned attributes, JSValueRef* exception);
extern JSValueRef JSObjectGetProperty(
    JSContextRef ctx, JSObjectRef object, JSStringRef propertyName, JSValueRef* exception);

/* GC */
extern void JSGarbageCollect(JSContextRef ctx);
extern void JSValueProtect(JSContextRef ctx, JSValueRef value);
extern void JSValueUnprotect(JSContextRef ctx, JSValueRef value);

/* ============================================================================
 * 辅助函数 — JSStringRef ↔ UTF-8 C 字符串
 * ============================================================================ */

/**
 * 将 JSStringRef 转为堆分配的 UTF-8 C 字符串
 * 调用者负责 free() 返回值
 */
static char* bao_jsstring_to_utf8(JSStringRef jsStr) {
    size_t maxSize = JSStringGetMaximumUTF8CStringSize(jsStr);
    if (maxSize == 0) {
        char* empty = (char*)malloc(1);
        if (empty) empty[0] = '\0';
        return empty;
    }
    char* buf = (char*)malloc(maxSize);
    if (!buf) return NULL;
    JSStringGetUTF8CString(jsStr, buf, maxSize);
    return buf;
}

/**
 * 将 JSValueRef 转为 UTF-8 C 字符串
 * 调用者负责 free() 返回值
 */
static char* bao_jsvalue_to_string(JSContextRef ctx, JSValueRef val) {
    if (!val) {
        char* empty = (char*)malloc(7);
        if (empty) strcpy(empty, "undefined");
        return empty;
    }

    JSStringRef jsStr = JSValueToStringCopy(ctx, val, NULL);
    if (!jsStr) {
        char* empty = (char*)malloc(1);
        if (empty) empty[0] = '\0';
        return empty;
    }

    char* result = bao_jsstring_to_utf8(jsStr);
    JSStringRelease(jsStr);
    return result;
}

/* ============================================================================
 * 原生回调实现 — print, console.log/error/warn/info
 * 对应 Bun: src/jsc/host_fn.zig 中注册的 native functions
 * ============================================================================ */

/**
 * print(message...) — 全局 print 函数
 * 对应 Bun: bun/src/bun.js/bindings/BunObject.cpp Bun.print
 *
 * 打印所有参数（空格分隔）到 stdout，换行
 */
static JSValueRef bao_print_impl(
    JSContextRef ctx,
    JSObjectRef function,
    JSObjectRef thisObject,
    size_t argumentCount,
    const JSValueRef arguments[],
    JSValueRef* exception
) {
    (void)function;
    (void)thisObject;
    (void)exception;

    for (size_t i = 0; i < argumentCount; i++) {
        if (i > 0) fputc(' ', stdout);
        char* str = bao_jsvalue_to_string(ctx, arguments[i]);
        if (str) {
            fputs(str, stdout);
            free(str);
        }
    }
    fputc('\n', stdout);
    fflush(stdout);

    return JSValueMakeUndefined(ctx);
}

/**
 * console.log(message...) — console 对象的 log 方法
 * 对应 Bun: src/jsc/bindings/ConsoleObject.cpp
 */
static JSValueRef bao_console_log_impl(
    JSContextRef ctx,
    JSObjectRef function,
    JSObjectRef thisObject,
    size_t argumentCount,
    const JSValueRef arguments[],
    JSValueRef* exception
) {
    (void)function;
    (void)thisObject;
    (void)exception;

    for (size_t i = 0; i < argumentCount; i++) {
        if (i > 0) fputc(' ', stdout);
        char* str = bao_jsvalue_to_string(ctx, arguments[i]);
        if (str) {
            fputs(str, stdout);
            free(str);
        }
    }
    fputc('\n', stdout);
    fflush(stdout);

    return JSValueMakeUndefined(ctx);
}

/**
 * console.error(message...) — 带红色 ANSI 颜色输出到 stderr
 */
static JSValueRef bao_console_error_impl(
    JSContextRef ctx,
    JSObjectRef function,
    JSObjectRef thisObject,
    size_t argumentCount,
    const JSValueRef arguments[],
    JSValueRef* exception
) {
    (void)function;
    (void)thisObject;
    (void)exception;

    fputs("\033[31m", stderr);  /* red */
    for (size_t i = 0; i < argumentCount; i++) {
        if (i > 0) fputc(' ', stderr);
        char* str = bao_jsvalue_to_string(ctx, arguments[i]);
        if (str) {
            fputs(str, stderr);
            free(str);
        }
    }
    fputs("\033[0m\n", stderr);  /* reset + newline */
    fflush(stderr);

    return JSValueMakeUndefined(ctx);
}

/**
 * console.warn(message...) — 带黄色 ANSI 颜色输出到 stderr
 */
static JSValueRef bao_console_warn_impl(
    JSContextRef ctx,
    JSObjectRef function,
    JSObjectRef thisObject,
    size_t argumentCount,
    const JSValueRef arguments[],
    JSValueRef* exception
) {
    (void)function;
    (void)thisObject;
    (void)exception;

    fputs("\033[33m", stderr);  /* yellow */
    for (size_t i = 0; i < argumentCount; i++) {
        if (i > 0) fputc(' ', stderr);
        char* str = bao_jsvalue_to_string(ctx, arguments[i]);
        if (str) {
            fputs(str, stderr);
            free(str);
        }
    }
    fputs("\033[0m\n", stderr);  /* reset + newline */
    fflush(stderr);

    return JSValueMakeUndefined(ctx);
}

/**
 * console.info(message...) — 与 console.log 相同
 */
static JSValueRef bao_console_info_impl(
    JSContextRef ctx,
    JSObjectRef function,
    JSObjectRef thisObject,
    size_t argumentCount,
    const JSValueRef arguments[],
    JSValueRef* exception
) {
    return bao_console_log_impl(ctx, function, thisObject, argumentCount, arguments, exception);
}

/* ============================================================================
 * 内置函数注册 — 由 Cangjie JscRuntime.init() 调用
 * 对应 Bun: ZigGlobalObject.cpp 中 finishCreation 注册内置对象
 * ============================================================================ */

/**
 * 注册所有内置函数到 JSC 全局上下文
 *
 * 注册内容:
 *   - 全局 print() 函数
 *   - console 对象 (log, error, warn, info)
 *
 * Cangjie 调用: bao_jsc_setup_builtins(ctx)
 */
void bao_jsc_setup_builtins(JSContextRef ctx) {
    JSObjectRef globalObj = JSContextGetGlobalObject(ctx);

    /* --- 注册全局 print() --- */
    {
        JSStringRef name = JSStringCreateWithUTF8CString("print");
        JSObjectRef printFn = JSObjectMakeFunctionWithCallback(
            ctx, name, bao_print_impl
        );
        JSObjectSetProperty(ctx, globalObj, name, printFn, 0, NULL);
        JSStringRelease(name);
    }

    /* --- 注册 console 对象 --- */
    {
        JSStringRef consoleName = JSStringCreateWithUTF8CString("console");
        JSObjectRef consoleObj = JSObjectMake(ctx, NULL, NULL);

        /* console.log */
        {
            JSStringRef propName = JSStringCreateWithUTF8CString("log");
            JSObjectRef fn = JSObjectMakeFunctionWithCallback(ctx, propName, bao_console_log_impl);
            JSObjectSetProperty(ctx, consoleObj, propName, fn, 0, NULL);
            JSStringRelease(propName);
        }

        /* console.error */
        {
            JSStringRef propName = JSStringCreateWithUTF8CString("error");
            JSObjectRef fn = JSObjectMakeFunctionWithCallback(ctx, propName, bao_console_error_impl);
            JSObjectSetProperty(ctx, consoleObj, propName, fn, 0, NULL);
            JSStringRelease(propName);
        }

        /* console.warn */
        {
            JSStringRef propName = JSStringCreateWithUTF8CString("warn");
            JSObjectRef fn = JSObjectMakeFunctionWithCallback(ctx, propName, bao_console_warn_impl);
            JSObjectSetProperty(ctx, consoleObj, propName, fn, 0, NULL);
            JSStringRelease(propName);
        }

        /* console.info */
        {
            JSStringRef propName = JSStringCreateWithUTF8CString("info");
            JSObjectRef fn = JSObjectMakeFunctionWithCallback(ctx, propName, bao_console_info_impl);
            JSObjectSetProperty(ctx, consoleObj, propName, fn, 0, NULL);
            JSStringRelease(propName);
        }

        /* 设置 console 到全局对象 */
        JSObjectSetProperty(ctx, globalObj, consoleName, consoleObj, 0, NULL);
        JSStringRelease(consoleName);
    }
}

/* ============================================================================
 * 执行脚本辅助 — 由 Cangjie JscRuntime.evaluateScript() 调用
 * ============================================================================ */

/**
 * 执行 JavaScript 脚本并返回结果的 UTF-8 字符串
 * 调用者负责 free() 返回值（NULL 表示错误或 undefined）
 *
 * 参数:
 *   ctx       — JSGlobalContextRef
 *   code      — JavaScript 源代码 (UTF-8)
 *   sourceUrl — 源文件 URL/路径 (可为 NULL)
 *   outError  — 输出参数，错误消息（可为 NULL）
 *              调用者负责 free() *outError
 *
 * 返回: 结果字符串（需 free），或 NULL（出错或 undefined）
 */
char* bao_jsc_eval_script(
    JSContextRef ctx,
    const char* code,
    const char* sourceUrl,
    char** outError
) {
    JSStringRef script = JSStringCreateWithUTF8CString(code);
    JSStringRef url = sourceUrl ? JSStringCreateWithUTF8CString(sourceUrl) : NULL;

    JSValueRef exception = NULL;
    JSValueRef result = JSEvaluateScript(ctx, script, NULL, url, 1, &exception);

    char* resultStr = NULL;

    if (exception) {
        /* 有异常 — 提取错误消息 */
        if (outError) {
            char* errMsg = bao_jsvalue_to_string(ctx, exception);
            if (sourceUrl) {
                size_t len = strlen(sourceUrl) + 2 + (errMsg ? strlen(errMsg) : 0) + 1;
                *outError = (char*)malloc(len);
                if (*outError) {
                    snprintf(*outError, len, "%s: %s", sourceUrl, errMsg ? errMsg : "");
                }
                free(errMsg);
            } else {
                *outError = errMsg;
            }
        }
        resultStr = NULL;
    } else if (result && !JSValueIsUndefined(ctx, result)) {
        /* 成功且有返回值 */
        resultStr = bao_jsvalue_to_string(ctx, result);
    } else {
        /* undefined 或无返回值 */
        if (outError) *outError = NULL;
        resultStr = NULL;
    }

    JSStringRelease(script);
    if (url) JSStringRelease(url);

    return resultStr;
}

/* ============================================================================
 * 内存管理辅助 — Cangjie 通过 @C foreign func 调用
 * ============================================================================ */

/**
 * free — 释放 C 分配的字符串内存
 */
void bao_c_free(void* ptr) {
    free(ptr);
}

void* bao_c_malloc(uint64_t size) {
    return malloc((size_t)size);
}

/**
 * 分配一个 char* 指针的空间（用于 outError 输出参数）
 * 初始值为 NULL
 */
char** bao_c_malloc_string_ptr(void) {
    char** ptr = (char**)malloc(sizeof(char*));
    if (ptr) *ptr = NULL;
    return ptr;
}

/**
 * 读取 char** 指向的 char* 值
 */
char* bao_c_read_string_ptr(char** ptr) {
    if (!ptr) return NULL;
    return *ptr;
}

/**
 * 释放 char** 指针本身（不释放 *ptr 指向的字符串）
 */
void bao_c_free_ptr(char** ptr) {
    free(ptr);
}
