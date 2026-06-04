/*
 * jsc_wrappers.c — JSC wrapper function stubs
 *
 * These JSC__* and Bun__* wrapper functions are referenced by bao_jsc 
 * compiled Cangjie code. They wrap the standard JSC C API.
 * Since we link libJavaScriptCore.a directly, we can implement them
 * by calling the real JSC functions.
 */
#include <stdint.h>
#include <stddef.h>
#include <string.h>

/* JSC opaque types */
typedef void* JSContextRef;
typedef void* JSObjectRef;
typedef void* JSStringRef;
typedef void* JSValueRef;

typedef JSValueRef (*JSObjectCallAsFunctionCallback)(
    JSContextRef, JSObjectRef, JSObjectRef, size_t, const JSValueRef[], JSValueRef*);

/* Standard JSC C API */
extern JSObjectRef JSObjectMakeFunctionWithCallback(JSContextRef, JSStringRef, JSObjectCallAsFunctionCallback);
extern JSStringRef JSStringCreateWithUTF8CString(const char*);
extern void JSStringRelease(JSStringRef);
extern int JSStringIsEqualToUTF8CString(JSStringRef, const char*);
extern int JSValueIsObject(JSContextRef, JSValueRef);
extern int JSValueToBoolean(JSContextRef, JSValueRef);
extern double JSValueToNumber(JSContextRef, JSValueRef, JSValueRef*);
extern JSObjectRef JSValueToObject(JSContextRef, JSValueRef, JSValueRef*);
extern JSValueRef JSObjectCallAsFunction(JSContextRef, JSObjectRef, JSObjectRef, size_t, const JSValueRef[], JSValueRef*);
extern int JSObjectIsFunction(JSContextRef, JSObjectRef);
extern void JSValueProtect(JSContextRef, JSValueRef);
extern void JSValueUnprotect(JSContextRef, JSValueRef);
extern void* JSObjectGetTypedArrayBytesPtr(JSContextRef, JSObjectRef, JSValueRef*);
extern JSObjectRef JSObjectGetTypedArrayBuffer(JSContextRef, JSObjectRef, JSValueRef*);
extern size_t JSObjectGetTypedArrayLength(JSContextRef, JSObjectRef, JSValueRef*);
extern JSObjectRef JSObjectMakeTypedArrayWithBytesNoCopy(JSContextRef, unsigned, void*, size_t, void(*)(void*,void*), void*, JSValueRef*);
extern JSObjectRef JSObjectMakeTypedArrayWithArrayBuffer(JSContextRef, unsigned, JSObjectRef, JSValueRef*);
extern JSObjectRef JSObjectMakeError(JSContextRef, size_t, const JSValueRef[], JSValueRef*);

/* JSC__ wrappers — called by bao_jsc Cangjie code */
int JSC__JSValueIsUndefined(int64_t ctx, int64_t v) { (void)ctx; (void)v; return 0; }
int JSC__JSValueIsNull(int64_t ctx, int64_t v) { (void)ctx; (void)v; return 0; }
int JSC__JSValueIsBoolean(int64_t ctx, int64_t v) { (void)ctx; (void)v; return 0; }
int JSC__JSValueIsNumber(int64_t ctx, int64_t v) { (void)ctx; (void)v; return 0; }
int JSC__JSValueIsString(uint64_t g, int64_t v) { (void)g; (void)v; return 0; }
int JSC__JSValueIsObject(int64_t v) { (void)v; return 0; }
int JSC__JSValueToBoolean(uint64_t g, int64_t v) { (void)g; (void)v; return 0; }
double JSC__JSValueToNumber(uint64_t g, int64_t v) { (void)g; (void)v; return 0.0; }
int64_t JSC__JSValueToString(uint64_t g, int64_t v) { (void)g; (void)v; return 0; }
int64_t JSC__JSValueToObject(uint64_t g, int64_t v) { (void)g; (void)v; return 0; }
int64_t JSC__JSValueGet(uint64_t g, int64_t v, const char* n, int64_t nl) { (void)g; (void)v; (void)n; (void)nl; return 0; }
void JSC__JSValuePut(uint64_t g, int64_t v, const char* n, int64_t nl, int64_t pv) { (void)g; (void)v; (void)n; (void)nl; (void)pv; }
int64_t JSC__JSGlobalObjectCreateEmptyObject(uint64_t g, int64_t c) { (void)g; (void)c; return 0; }
int64_t JSC__JSGlobalObjectCreateArray(uint64_t g, int64_t c) { (void)g; (void)c; return 0; }

int JSC__JSObjectIsFunction(JSContextRef c, JSObjectRef o) { return JSObjectIsFunction(c, o); }
JSValueRef JSC__JSObjectCallAsFunction(JSContextRef c, JSObjectRef o, JSObjectRef t, size_t ac, const JSValueRef* av, JSValueRef* ex) { return JSObjectCallAsFunction(c, o, t, ac, av, ex); }
JSValueRef JSC__JSObjectCallAsFunctionWithThis(JSContextRef c, JSObjectRef o, JSObjectRef th, size_t ac, const JSValueRef* av, JSValueRef* ex) { return JSObjectCallAsFunction(c, o, th, ac, av, ex); }
void JSC__JSValueProtect(JSContextRef c, JSValueRef v) { JSValueProtect(c, v); }
void JSC__JSValueUnprotect(JSContextRef c, JSValueRef v) { JSValueUnprotect(c, v); }
JSStringRef JSC__JSStringCreateWithUTF8CString(const char* s) { return JSStringCreateWithUTF8CString(s); }
int JSC__JSStringIsEqualToUTF8CString(JSStringRef a, const char* b) { return JSStringIsEqualToUTF8CString(a, b); }
void JSC__JSStringRelease(JSStringRef s) { JSStringRelease(s); }
void* JSC__JSObjectGetTypedArrayBytePtr(JSContextRef c, JSObjectRef o, JSValueRef* ex) { return JSObjectGetTypedArrayBytesPtr(c, o, ex); }
JSObjectRef JSC__JSObjectGetTypedArrayBuffer(JSContextRef c, JSObjectRef o, JSValueRef* ex) { return JSObjectGetTypedArrayBuffer(c, o, ex); }
size_t JSC__JSObjectGetTypedArrayLength(JSContextRef c, JSObjectRef o, JSValueRef* ex) { return JSObjectGetTypedArrayLength(c, o, ex); }
JSObjectRef JSC__JSObjectMakeError(JSContextRef c, size_t ac, const JSValueRef* av, JSValueRef* ex) { return JSObjectMakeError(c, ac, av, ex); }
JSObjectRef JSC__JSObjectMakeTypedArrayWithArrayBuffer(JSContextRef c, unsigned t, JSObjectRef b, JSValueRef* ex) { return JSObjectMakeTypedArrayWithArrayBuffer(c, t, b, ex); }
JSObjectRef JSC__JSObjectMakeTypedArrayWithBytesNoCopy(JSContextRef c, unsigned t, void* b, size_t l, void(*d)(void*,void*), void* u, JSValueRef* ex) { return JSObjectMakeTypedArrayWithBytesNoCopy(c, t, b, l, d, u, ex); }

/* Bun helpers */
int Bun__String__eqlUTF8(const char* a, int64_t alen, const char* b, int64_t blen) {
    if (alen != blen) return 0;
    return a && b && alen >= 0 && blen >= 0 && memcmp(a, b, (size_t)alen) == 0;
}
int64_t Bun__createFFIFunctionValue(uint64_t g, const char* sym, int64_t slen, int64_t ac, uint64_t fp, uint64_t d) {
    (void)g; (void)sym; (void)slen; (void)ac; (void)fp; (void)d;
    return 0;
}
