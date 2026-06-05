/*
 * jsc_worker_types.h — Shared JSC C API type declarations and extern declarations
 *
 * This header is included by both jsc_worker.c and jsc_node_compat.c
 * to share type definitions and utility function declarations.
 */

#ifndef JSC_WORKER_TYPES_H
#define JSC_WORKER_TYPES_H

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <unistd.h>
#include <sys/stat.h>
#include <sys/time.h>
#include <dirent.h>
#include <errno.h>
#include <fcntl.h>
#include <time.h>

/* ============================================================================
 * JSC C API type declarations
 * ============================================================================ */

typedef void* JSContextRef;
typedef void* JSObjectRef;
typedef void* JSStringRef;
typedef void* JSValueRef;
typedef struct OpaqueJSContext* JSGlobalContextRef;

typedef JSValueRef (*JSObjectCallAsFunctionCallback)(
    JSContextRef, JSObjectRef, JSObjectRef, size_t, const JSValueRef[], JSValueRef*);

/* Core */
extern JSGlobalContextRef JSGlobalContextCreate(JSObjectRef);
extern void JSGlobalContextRelease(JSGlobalContextRef);
extern JSObjectRef JSContextGetGlobalObject(JSContextRef);
extern JSValueRef JSEvaluateScript(JSContextRef, JSStringRef, JSObjectRef, JSStringRef, int, JSValueRef*);

/* String */
extern JSStringRef JSStringCreateWithUTF8CString(const char*);
extern void JSStringRelease(JSStringRef);
extern size_t JSStringGetMaximumUTF8CStringSize(JSStringRef);
extern size_t JSStringGetUTF8CString(JSStringRef, char*, size_t);
extern int JSStringIsEqualToUTF8CString(JSStringRef, const char*);

/* Value creation */
extern JSValueRef JSValueMakeUndefined(JSContextRef);
extern JSValueRef JSValueMakeNull(JSContextRef);
extern JSValueRef JSValueMakeNumber(JSContextRef, double);
extern JSValueRef JSValueMakeBoolean(JSContextRef, int);
extern JSValueRef JSValueMakeString(JSContextRef, JSStringRef);

/* Value testing */
extern _Bool JSValueIsUndefined(JSContextRef, JSValueRef);
extern _Bool JSValueIsNull(JSContextRef, JSValueRef);
extern _Bool JSValueIsBoolean(JSContextRef, JSValueRef);
extern _Bool JSValueIsNumber(JSContextRef, JSValueRef);
extern _Bool JSValueIsString(JSContextRef, JSValueRef);
extern _Bool JSValueIsObject(JSContextRef, JSValueRef);

/* Value conversion */
extern JSStringRef JSValueToStringCopy(JSContextRef, JSValueRef, JSValueRef*);
extern double JSValueToNumber(JSContextRef, JSValueRef, JSValueRef*);
extern _Bool JSValueToBoolean(JSContextRef, JSValueRef);
extern JSObjectRef JSValueToObject(JSContextRef, JSValueRef, JSValueRef*);

/* Object */
extern JSObjectRef JSObjectMake(JSContextRef, void*, void*);
extern JSObjectRef JSObjectMakeFunctionWithCallback(JSContextRef, JSStringRef, JSObjectCallAsFunctionCallback);
extern JSObjectRef JSObjectMakeArray(JSContextRef, size_t, const JSValueRef[], JSValueRef*);
extern JSObjectRef JSObjectMakeError(JSContextRef, size_t, const JSValueRef[], JSValueRef*);
extern void JSObjectSetProperty(JSContextRef, JSObjectRef, JSStringRef, JSValueRef, unsigned, JSValueRef*);
extern JSValueRef JSObjectGetProperty(JSContextRef, JSObjectRef, JSStringRef, JSValueRef*);
extern void JSObjectSetPropertyAtIndex(JSContextRef, JSObjectRef, unsigned, JSValueRef, JSValueRef*);
extern JSValueRef JSObjectGetPropertyAtIndex(JSContextRef, JSObjectRef, unsigned, JSValueRef*);
extern unsigned JSObjectGetArrayLength(JSContextRef, JSObjectRef);
extern JSValueRef JSObjectCallAsFunction(JSContextRef, JSObjectRef, JSObjectRef, size_t, const JSValueRef[], JSValueRef*);

/* ============================================================================
 * Shared utility function declarations (defined in jsc_worker.c)
 * ============================================================================ */

extern char* to_utf8(JSContextRef, JSValueRef);
extern JSValueRef make_error(JSContextRef, const char*, JSValueRef*);
extern JSValueRef make_string(JSContextRef, const char*);
extern JSValueRef make_number(JSContextRef, double);
extern void set_prop_str(JSContextRef, JSObjectRef, const char*, const char*);
extern void set_prop_num(JSContextRef, JSObjectRef, const char*, double);
extern void set_prop_bool(JSContextRef, JSObjectRef, const char*, int);
extern void reg_method(JSContextRef, JSObjectRef, const char*, JSObjectCallAsFunctionCallback);

#endif /* JSC_WORKER_TYPES_H */
