/*
 * BAO JSC Compatibility Stubs
 *
 * 所有 JSC 操作通过 jsc_bridge.c 的 dlopen 方式动态加载。
 * 此文件提供所有 bao_jsc 包所需的 JSC 符号的空实现，
 * 使得二进制文件不需要在链接时包含 libjavascriptcoregtk。
 *
 * 这些 stub 在实际使用中不会被调用（--jsc 模式走 jsc_bridge.c 路径）。
 * 如果被意外调用，会安全地返回零值/NULL。
 */

#include <stdint.h>
#include <stddef.h>
#include <string.h>

/* Opaque JSC types */
typedef void* JSContextRef;
typedef void* JSObjectRef;
typedef void* JSStringRef;
typedef void* JSValueRef;
typedef struct OpaqueJSContext* JSGlobalContextRef;

typedef enum {
    kJSTypeUndefined, kJSTypeNull, kJSTypeBoolean,
    kJSTypeNumber, kJSTypeString, kJSTypeObject, kJSTypeSymbol
} JSType;

typedef JSValueRef (*JSObjectCallAsFunctionCallback)(
    JSContextRef, JSObjectRef, JSObjectRef, size_t, const JSValueRef[], JSValueRef*);

/* ============================================================================
 * 标准 JSC C API 空实现
 * ============================================================================ */

JSGlobalContextRef JSGlobalContextCreate(JSObjectRef cls) { (void)cls; return NULL; }
void JSGlobalContextRelease(JSGlobalContextRef ctx) { (void)ctx; }
JSObjectRef JSContextGetGlobalObject(JSContextRef ctx) { (void)ctx; return NULL; }

JSValueRef JSEvaluateScript(JSContextRef c, JSStringRef s, JSObjectRef t, JSStringRef u, int l, JSValueRef* e) {
    (void)c;(void)s;(void)t;(void)u;(void)l;(void)e; return NULL;
}
int JSCheckScriptSyntax(JSContextRef c, JSStringRef s, JSStringRef u, int l, JSValueRef* e) {
    (void)c;(void)s;(void)u;(void)l;(void)e; return 0;
}
void JSGarbageCollect(JSContextRef ctx) { (void)ctx; }

JSStringRef JSStringCreateWithUTF8CString(const char* s) { (void)s; return NULL; }
void JSStringRelease(JSStringRef s) { (void)s; }
size_t JSStringGetMaximumUTF8CStringSize(JSStringRef s) { (void)s; return 0; }
size_t JSStringGetUTF8CString(JSStringRef s, char* b, size_t sz) { (void)s;(void)b;(void)sz; return 0; }
size_t JSStringGetLength(JSStringRef s) { (void)s; return 0; }
int JSStringIsEqualToUTF8CString(JSStringRef a, const char* b) { (void)a;(void)b; return 0; }

JSValueRef JSValueMakeUndefined(JSContextRef c) { (void)c; return NULL; }
JSValueRef JSValueMakeNull(JSContextRef c) { (void)c; return NULL; }
JSValueRef JSValueMakeBoolean(JSContextRef c, int v) { (void)c;(void)v; return NULL; }
JSValueRef JSValueMakeNumber(JSContextRef c, double v) { (void)c;(void)v; return NULL; }
JSValueRef JSValueMakeString(JSContextRef c, JSStringRef s) { (void)c;(void)s; return NULL; }

int JSValueIsUndefined(JSContextRef c, JSValueRef v) { (void)c;(void)v; return 0; }
int JSValueIsNull(JSContextRef c, JSValueRef v) { (void)c;(void)v; return 0; }
int JSValueIsBoolean(JSContextRef c, JSValueRef v) { (void)c;(void)v; return 0; }
int JSValueIsNumber(JSContextRef c, JSValueRef v) { (void)c;(void)v; return 0; }
int JSValueIsString(JSContextRef c, JSValueRef v) { (void)c;(void)v; return 0; }
int JSValueIsObject(JSContextRef c, JSValueRef v) { (void)c;(void)v; return 0; }
int JSValueIsSymbol(JSContextRef c, JSValueRef v) { (void)c;(void)v; return 0; }
int JSValueIsEqual(JSContextRef c, JSValueRef a, JSValueRef b, JSValueRef* e) { (void)c;(void)a;(void)b;(void)e; return 0; }
int JSValueIsStrictEqual(JSContextRef c, JSValueRef a, JSValueRef b) { (void)c;(void)a;(void)b; return 0; }
int JSValueIsInstanceOfConstructor(JSContextRef c, JSValueRef v, JSObjectRef o, JSValueRef* e) { (void)c;(void)v;(void)o;(void)e; return 0; }

int JSValueToBoolean(JSContextRef c, JSValueRef v) { (void)c;(void)v; return 0; }
double JSValueToNumber(JSContextRef c, JSValueRef v, JSValueRef* e) { (void)c;(void)v;(void)e; return 0.0; }
JSStringRef JSValueToStringCopy(JSContextRef c, JSValueRef v, JSValueRef* e) { (void)c;(void)v;(void)e; return NULL; }
JSObjectRef JSValueToObject(JSContextRef c, JSValueRef v, JSValueRef* e) { (void)c;(void)v;(void)e; return NULL; }
JSType JSValueGetType(JSContextRef c, JSValueRef v) { (void)c;(void)v; return kJSTypeUndefined; }

void JSValueProtect(JSContextRef c, JSValueRef v) { (void)c;(void)v; }
void JSValueUnprotect(JSContextRef c, JSValueRef v) { (void)c;(void)v; }

JSObjectRef JSObjectMake(JSContextRef c, void* cls, void* d) { (void)c;(void)cls;(void)d; return NULL; }
JSObjectRef JSObjectMakeFunctionWithCallback(JSContextRef c, JSStringRef n, JSObjectCallAsFunctionCallback cb) { (void)c;(void)n;(void)cb; return NULL; }
void JSObjectSetProperty(JSContextRef c, JSObjectRef o, JSStringRef n, JSValueRef v, unsigned a, JSValueRef* e) { (void)c;(void)o;(void)n;(void)v;(void)a;(void)e; }
JSValueRef JSObjectGetProperty(JSContextRef c, JSObjectRef o, JSStringRef n, JSValueRef* e) { (void)c;(void)o;(void)n;(void)e; return NULL; }
int JSObjectHasProperty(JSContextRef c, JSObjectRef o, JSStringRef n) { (void)c;(void)o;(void)n; return 0; }
int JSObjectDeleteProperty(JSContextRef c, JSObjectRef o, JSStringRef n, JSValueRef* e) { (void)c;(void)o;(void)n;(void)e; return 0; }
void JSObjectSetPrototype(JSContextRef c, JSObjectRef o, JSValueRef v) { (void)c;(void)o;(void)v; }
JSValueRef JSObjectGetPrototype(JSContextRef c, JSObjectRef o) { (void)c;(void)o; return NULL; }
int JSObjectIsFunction(JSContextRef c, JSObjectRef o) { (void)c;(void)o; return 0; }
int JSObjectIsConstructor(JSContextRef c, JSObjectRef o) { (void)c;(void)o; return 0; }
JSValueRef JSObjectCallAsFunction(JSContextRef c, JSObjectRef o, JSObjectRef t, size_t n, const JSValueRef* a, JSValueRef* e) { (void)c;(void)o;(void)t;(void)n;(void)a;(void)e; return NULL; }
JSObjectRef JSObjectCallAsConstructor(JSContextRef c, JSObjectRef o, size_t n, const JSValueRef* a, JSValueRef* e) { (void)c;(void)o;(void)n;(void)a;(void)e; return NULL; }
JSObjectRef JSObjectMakeArray(JSContextRef c, size_t n, const JSValueRef* a, JSValueRef* e) { (void)c;(void)n;(void)a;(void)e; return NULL; }
JSObjectRef JSObjectMakeError(JSContextRef c, size_t n, const JSValueRef* a, JSValueRef* e) { (void)c;(void)n;(void)a;(void)e; return NULL; }
JSObjectRef JSObjectMakeTypedArray(JSContextRef c, JSType t, size_t l, JSValueRef* e) { (void)c;(void)t;(void)l;(void)e; return NULL; }
JSObjectRef JSObjectMakeTypedArrayWithBytesNoCopy(JSContextRef c, JSType t, void* b, size_t l, void(*d)(void*,void*), void* u, JSValueRef* e) { (void)c;(void)t;(void)b;(void)l;(void)d;(void)u;(void)e; return NULL; }
JSObjectRef JSObjectGetTypedArrayBuffer(JSContextRef c, JSObjectRef o, JSValueRef* e) { (void)c;(void)o;(void)e; return NULL; }
void* JSObjectGetTypedArrayBytesPtr(JSContextRef c, JSObjectRef o, JSValueRef* e) { (void)c;(void)o;(void)e; return NULL; }
size_t JSObjectGetTypedArrayLength(JSContextRef c, JSObjectRef o, JSValueRef* e) { (void)c;(void)o;(void)e; return 0; }
size_t JSObjectGetTypedArrayByteLength(JSContextRef c, JSObjectRef o, JSValueRef* e) { (void)c;(void)o;(void)e; return 0; }
size_t JSObjectGetTypedArrayByteOffset(JSContextRef c, JSObjectRef o, JSValueRef* e) { (void)c;(void)o;(void)e; return 0; }
void* JSObjectGetArrayBufferBytesPtr(JSContextRef c, JSObjectRef o, JSValueRef* e) { (void)c;(void)o;(void)e; return NULL; }
size_t JSObjectGetArrayBufferByteLength(JSContextRef c, JSObjectRef o, JSValueRef* e) { (void)c;(void)o;(void)e; return 0; }

typedef void* JSPropertyNameArrayRef;
typedef void* JSPropertyNameAccumulatorRef;
JSPropertyNameArrayRef JSObjectCopyPropertyNames(JSContextRef c, JSObjectRef o) { (void)c;(void)o; return NULL; }
void JSPropertyNameArrayRelease(JSPropertyNameArrayRef a) { (void)a; }
size_t JSPropertyNameArrayGetCount(JSPropertyNameArrayRef a) { (void)a; return 0; }
JSStringRef JSPropertyNameArrayGetNameAtIndex(JSPropertyNameArrayRef a, size_t i) { (void)a;(void)i; return NULL; }
void JSPropertyNameAccumulatorAddName(JSContextRef c, JSPropertyNameAccumulatorRef a, JSStringRef n) { (void)c;(void)a;(void)n; }

/* ============================================================================
 * JSC__ 前缀包装函数 — bao_jsc/ffi_imports.cj 使用
 * 这些是空实现，不会在实际 --jsc 路径中被调用
 * ============================================================================ */

int JSC__JsValue__isUndefined(int64_t v) { (void)v; return 0; }
int JSC__JsValue__isNull(int64_t v) { (void)v; return 0; }
int JSC__JsValue__isBoolean(int64_t v) { (void)v; return 0; }
int JSC__JsValue__isNumber(int64_t v) { (void)v; return 0; }
int JSC__JsValue__isString(uint64_t g, int64_t v) { (void)g;(void)v; return 0; }
int JSC__JsValue__isObject(int64_t v) { (void)v; return 0; }
int JSC__JsValue__toBoolean(uint64_t g, int64_t v) { (void)g;(void)v; return 0; }
double JSC__JsValue__toNumber(uint64_t g, int64_t v) { (void)g;(void)v; return 0.0; }
int64_t JSC__JsValue__toString(uint64_t g, int64_t v) { (void)g;(void)v; return 0; }
int64_t JSC__JsValue__toObject(uint64_t g, int64_t v) { (void)g;(void)v; return 0; }
int64_t JSC__JsValue__get(uint64_t g, int64_t v, const char* n, int64_t nl) { (void)g;(void)v;(void)n;(void)nl; return 0; }
void JSC__JsValue__put(uint64_t g, int64_t v, const char* n, int64_t nl, int64_t pv) { (void)g;(void)v;(void)n;(void)nl;(void)pv; }
int64_t JSC__JSGlobalObject__createEmptyObject(uint64_t g, int64_t c) { (void)g;(void)c; return 0; }
int64_t JSC__JSGlobalObject__createArray(uint64_t g, int64_t c) { (void)g;(void)c; return 0; }

int JSC__JSObjectIsFunction(JSContextRef c, JSObjectRef o) { (void)c;(void)o; return 0; }
JSValueRef JSC__JSObjectCallAsFunction(JSContextRef c, JSObjectRef o, JSObjectRef t, size_t ac, const JSValueRef* av, JSValueRef* ex) { (void)c;(void)o;(void)t;(void)ac;(void)av;(void)ex; return NULL; }
JSValueRef JSC__JSObjectCallAsFunctionWithThis(JSContextRef c, JSObjectRef o, JSObjectRef th, size_t ac, const JSValueRef* av, JSValueRef* ex) { (void)c;(void)o;(void)th;(void)ac;(void)av;(void)ex; return NULL; }
JSObjectRef JSC__JSObjectGetTypedArrayBuffer(JSContextRef c, JSObjectRef o, JSValueRef* ex) { (void)c;(void)o;(void)ex; return NULL; }
void* JSC__JSObjectGetTypedArrayBytePtr(JSContextRef c, JSObjectRef o, JSValueRef* ex) { (void)c;(void)o;(void)ex; return NULL; }
size_t JSC__JSObjectGetTypedArrayLength(JSContextRef c, JSObjectRef o, JSValueRef* ex) { (void)c;(void)o;(void)ex; return 0; }
JSObjectRef JSC__JSObjectMakeError(JSContextRef c, size_t ac, const JSValueRef* av, JSValueRef* ex) { (void)c;(void)ac;(void)av;(void)ex; return NULL; }
JSObjectRef JSC__JSObjectMakeTypedArrayWithArrayBuffer(JSContextRef c, JSType t, JSObjectRef b, JSValueRef* ex) { (void)c;(void)t;(void)b;(void)ex; return NULL; }
JSObjectRef JSC__JSObjectMakeTypedArrayWithBytesNoCopy(JSContextRef c, JSType t, void* b, size_t l, void(*d)(void*,void*), void* u, JSValueRef* ex) { (void)c;(void)t;(void)b;(void)l;(void)d;(void)u;(void)ex; return NULL; }
JSStringRef JSC__JSStringCreateWithUTF8CString(const char* s) { (void)s; return NULL; }
int JSC__JSStringIsEqualToUTF8CString(JSStringRef a, const char* b) { (void)a;(void)b; return 0; }
void JSC__JSStringRelease(JSStringRef s) { (void)s; }
void JSC__JSValueProtect(JSContextRef c, JSValueRef v) { (void)c;(void)v; }
void JSC__JSValueUnprotect(JSContextRef c, JSValueRef v) { (void)c;(void)v; }

/* Bun__ 辅助函数 */
int Bun__String__eqlUTF8(const char* a, int64_t alen, const char* b, int64_t blen) {
    if (alen != blen) return 0;
    return a && b && alen >= 0 && blen >= 0 && memcmp(a, b, (size_t)alen) == 0;
}

int64_t Bun__createFFIFunctionValue(uint64_t g, const char* sym, int64_t slen, int64_t ac, uint64_t fp, uint64_t d) {
    (void)g;(void)sym;(void)slen;(void)ac;(void)fp;(void)d;
    return 0;
}
