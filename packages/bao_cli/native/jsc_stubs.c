/*
 * BAO_STUB(jsc): JSC API stubs for linking.
 * These are placeholder stubs that allow the bao_cli to link while the
 * real JSC integration is not yet complete. They should be replaced with
 * real JSC bindings when available.
 */

#include <stdint.h>
#include <stddef.h>
#include <string.h>

/* Opaque JSC types */
typedef void* JSContextRef;
typedef void* JSObjectRef;
typedef void* JSStringRef;
typedef void* JSValueRef;
typedef void* JSGlobalContextRef;

/* JSValue types */
typedef enum { kJSTypeUndefined, kJSTypeNull, kJSTypeBoolean, kJSTypeNumber, kJSTypeString, kJSTypeObject } JSType;

/* String */
JSStringRef JSStringCreateWithUTF8CString(const char *s) { return NULL; }
void JSStringRelease(JSStringRef s) {}
int JSStringIsEqualToUTF8CString(JSStringRef a, const char *b) { return 0; }

/* Value type check */
JSType JSValueGetType(JSContextRef ctx, JSValueRef v) { return kJSTypeUndefined; }
int JSValueIsUndefined(JSContextRef ctx, JSValueRef v) { return 1; }
int JSValueIsNull(JSContextRef ctx, JSValueRef v) { return 0; }
int JSValueIsBoolean(JSContextRef ctx, JSValueRef v) { return 0; }
int JSValueIsNumber(JSContextRef ctx, JSValueRef v) { return 0; }
int JSValueIsString(JSContextRef ctx, JSValueRef v) { return 0; }
int JSValueIsObject(JSContextRef ctx, JSValueRef v) { return 0; }
int JSValueIsSymbol(JSContextRef ctx, JSValueRef v) { return 0; }
int JSValueIsStrictEqual(JSContextRef ctx, JSValueRef a, JSValueRef b) { return 0; }
int JSValueIsEqual(JSContextRef ctx, JSValueRef a, JSValueRef b, JSValueRef *ex) { return 0; }
int JSValueToBoolean(JSContextRef ctx, JSValueRef v) { return 0; }
double JSValueToNumber(JSContextRef ctx, JSValueRef v, JSValueRef *ex) { return 0.0; }
JSStringRef JSValueToStringCopy(JSContextRef ctx, JSValueRef v, JSValueRef *ex) { return NULL; }
JSObjectRef JSValueToObject(JSContextRef ctx, JSValueRef v, JSValueRef *ex) { return NULL; }
JSValueRef JSValueMakeUndefined(JSContextRef ctx) { return NULL; }
JSValueRef JSValueMakeNull(JSContextRef ctx) { return NULL; }
JSValueRef JSValueMakeBoolean(JSContextRef ctx, int b) { return NULL; }
JSValueRef JSValueMakeNumber(JSContextRef ctx, double d) { return NULL; }
JSValueRef JSValueMakeString(JSContextRef ctx, JSStringRef s) { return NULL; }
void JSValueProtect(JSContextRef ctx, JSValueRef v) {}
void JSValueUnprotect(JSContextRef ctx, JSValueRef v) {}

/* Object */
int JSObjectHasProperty(JSContextRef ctx, JSObjectRef o, JSStringRef n) { return 0; }
JSValueRef JSObjectGetProperty(JSContextRef ctx, JSObjectRef o, JSStringRef n, JSValueRef *ex) { return NULL; }
void JSObjectSetProperty(JSContextRef ctx, JSObjectRef o, JSStringRef n, JSValueRef v, JSValueRef *ex) {}
int JSObjectDeleteProperty(JSContextRef ctx, JSObjectRef o, JSStringRef n, JSValueRef *ex) { return 0; }
JSObjectRef JSObjectGetPrototype(JSContextRef ctx, JSObjectRef o) { return NULL; }
void JSObjectSetPrototype(JSContextRef ctx, JSObjectRef o, JSValueRef p) {}
int JSObjectIsFunction(JSContextRef ctx, JSObjectRef o) { return 0; }
JSValueRef JSObjectCallAsFunction(JSContextRef ctx, JSObjectRef o, JSObjectRef t, size_t ac, const JSValueRef *av, JSValueRef *ex) { return NULL; }
int JSObjectIsConstructor(JSContextRef ctx, JSObjectRef o) { return 0; }
JSObjectRef JSObjectCallAsConstructor(JSContextRef ctx, JSObjectRef o, size_t ac, const JSValueRef *av, JSValueRef *ex) { return NULL; }
JSObjectRef JSObjectMakeError(JSContextRef ctx, size_t ac, const JSValueRef *av, JSValueRef *ex) { return NULL; }
void* JSObjectGetTypedArrayBytesPtr(JSContextRef ctx, JSObjectRef o, JSValueRef *ex) { return NULL; }
size_t JSObjectGetTypedArrayByteLength(JSContextRef ctx, JSObjectRef o, JSValueRef *ex) { return 0; }
size_t JSObjectGetArrayBufferByteLength(JSContextRef ctx, JSObjectRef o, JSValueRef *ex) { return 0; }
void* JSObjectGetArrayBufferBytesPtr(JSContextRef ctx, JSObjectRef o, JSValueRef *ex) { return NULL; }
JSObjectRef JSObjectMakeTypedArrayWithBytesNoCopy(JSContextRef ctx, JSType t, void *b, size_t l, void(*d)(void*p,void*u), void *u, JSValueRef *ex) { return NULL; }
JSObjectRef JSObjectMakeTypedArray(JSContextRef ctx, JSType t, size_t l, JSValueRef *ex) { return NULL; }
JSObjectRef JSObjectGetTypedArrayBuffer(JSContextRef ctx, JSObjectRef o, JSValueRef *ex) { return NULL; }
size_t JSObjectGetTypedArrayByteOffset(JSContextRef ctx, JSObjectRef o, JSValueRef *ex) { return 0; }
size_t JSObjectGetTypedArrayLength(JSContextRef ctx, JSObjectRef o, JSValueRef *ex) { return 0; }
JSStringRef* JSObjectCopyPropertyNames(JSContextRef ctx, JSObjectRef o) { return NULL; }

/* Global context */
JSGlobalContextRef JSGlobalContextCreate(JSObjectRef c) { return NULL; }
void JSGlobalContextRelease(JSGlobalContextRef c) {}

/* Evaluate */
int JSCheckScriptSyntax(JSContextRef ctx, JSStringRef s, JSStringRef u, int l, JSValueRef *ex) { return 0; }
JSValueRef JSEvaluateScript(JSContextRef ctx, JSStringRef s, JSObjectRef t, JSStringRef u, int l, JSValueRef *ex) { return NULL; }
void JSGarbageCollect(JSContextRef ctx) {}

/* JSC prefixed (Bun naming) */
int JSC__JSObjectIsFunction(JSContextRef c, JSObjectRef o) { return JSObjectIsFunction(c, o); }
JSValueRef JSC__JSObjectCallAsFunction(JSContextRef c, JSObjectRef o, JSObjectRef t, size_t ac, const JSValueRef *av, JSValueRef *ex) { return JSObjectCallAsFunction(c, o, t, ac, av, ex); }
JSObjectRef JSC__JSObjectGetTypedArrayBuffer(JSContextRef c, JSObjectRef o, JSValueRef *ex) { return JSObjectGetTypedArrayBuffer(c, o, ex); }
void* JSC__JSObjectGetTypedArrayBytePtr(JSContextRef c, JSObjectRef o, JSValueRef *ex) { return JSObjectGetTypedArrayBytesPtr(c, o, ex); }
size_t JSC__JSObjectGetTypedArrayLength(JSContextRef c, JSObjectRef o, JSValueRef *ex) { return JSObjectGetTypedArrayLength(c, o, ex); }
JSObjectRef JSC__JSObjectMakeError(JSContextRef c, size_t ac, const JSValueRef *av, JSValueRef *ex) { return JSObjectMakeError(c, ac, av, ex); }
JSObjectRef JSC__JSObjectMakeTypedArrayWithArrayBuffer(JSContextRef c, JSType t, JSObjectRef b, JSValueRef *ex) { return NULL; }
JSObjectRef JSC__JSObjectMakeTypedArrayWithBytesNoCopy(JSContextRef c, JSType t, void *b, size_t l, void(*d)(void*p,void*u), void *u, JSValueRef *ex) { return JSObjectMakeTypedArrayWithBytesNoCopy(c, t, b, l, d, u, ex); }
JSStringRef JSC__JSStringCreateWithUTF8CString(const char *s) { return JSStringCreateWithUTF8CString(s); }
int JSC__JSStringIsEqualToUTF8CString(JSStringRef a, const char *b) { return JSStringIsEqualToUTF8CString(a, b); }
void JSC__JSStringRelease(JSStringRef s) { JSStringRelease(s); }
void JSC__JSValueProtect(JSContextRef c, JSValueRef v) { JSValueProtect(c, v); }
void JSC__JSValueUnprotect(JSContextRef c, JSValueRef v) { JSValueUnprotect(c, v); }

/* Bun string helper */
int Bun__String__eqlUTF8(const char *a, int64_t alen, const char *b, int64_t blen) {
    if (alen != blen) return 0;
    return a && b && alen >= 0 && blen >= 0 && memcmp(a, b, (size_t)alen) == 0;
}
