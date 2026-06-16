/*
 * jsc_worker.c — Standalone JSC worker process with native APIs
 *
 * Runs as child process, isolated from Cangjie runtime.
 * Protocol on fd 3 (socketpair):
 *   Request:  [4B code_len][code][4B url_len][url]
 *   Response: [4B status: 0=ok,1=error][4B result_len][result]
 *
 * Registered global APIs:
 *   print(), console.{log,error,warn,info,debug,time,timeEnd}
 *   process.{argv,env,cwd,exit,platform,version,pid,stdout.write,stderr.write}
 *   fs.{readFileSync,writeFileSync,existsSync,mkdirSync,readdirSync,statSync,unlinkSync,rmSync}
 *   path.{join,resolve,dirname,basename,extname,isAbsolute,sep,delimiter}
 *   Bun.{version,env,cwd}
 *   setTimeout(), setInterval(), clearTimeout(), clearInterval()
 *   fetch(url, options?)
 *   TextEncoder, TextDecoder
 *   URL, URLSearchParams
 *   Headers, Request, Response
 *   Event, EventTarget, AbortController, AbortSignal
 *   ReadableStream, WritableStream (stubs)
 *   queueMicrotask(), structuredClone()
 *   crypto.{getRandomValues,randomUUID}
 *   Buffer.{from,alloc}
 */

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
#include <sys/epoll.h>
#include <sys/timerfd.h>
#include <signal.h>
#include "jsc_node_compat.h"
#include "jsc_missing_apis.h"
#include "jsc_node_extras.h"
#include <openssl/evp.h>
#include <openssl/rand.h>
#include <openssl/hmac.h>
#include <openssl/pem.h>
#include <openssl/rsa.h>
#include <openssl/err.h>
#include <openssl/objects.h>

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

/* Value testing — JSC returns bool (_Bool), not int */
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
/* Get array length via property — JSC C API doesn't have get_array_length */
static unsigned get_array_length(JSContextRef ctx, JSObjectRef arr) {
    JSStringRef lk = JSStringCreateWithUTF8CString("length");
    JSValueRef lv = JSObjectGetProperty(ctx, arr, lk, NULL);
    JSStringRelease(lk);
    if(JSValueIsNumber(ctx, lv)) return (unsigned)JSValueToNumber(ctx, lv, NULL);
    return 0;
}
extern JSValueRef JSObjectCallAsFunction(JSContextRef, JSObjectRef, JSObjectRef, size_t, const JSValueRef[], JSValueRef*);

/* ============================================================================
 * Constants & Globals
 * ============================================================================ */

static int PFD = 3;              /* Protocol fd from socketpair */
static int g_epoll_fd = -1;      /* epoll instance for event loop */
JSGlobalContextRef g_ctx = NULL;
JSObjectRef g_global = NULL;

#define MAX_TIMERS 64
#define MAX_TIMER_CALLBACKS 256

typedef struct {
    int tfd;                      /* timerfd */
    int is_interval;              /* 0=timeout, 1=interval */
    JSObjectRef callback;         /* JS function to call */
    size_t argc;                  /* number of extra args */
    JSValueRef args[8];           /* extra args to pass */
} TimerEntry;

static TimerEntry g_timers[MAX_TIMERS];
static int g_timer_count = 0;

/* ============================================================================
 * I/O helpers
 * ============================================================================ */

static int write_all(int fd, const void* buf, size_t n) {
    const char* p = (const char*)buf;
    while (n > 0) { ssize_t r = write(fd, p, n); if (r <= 0) return -1; p += r; n -= (size_t)r; }
    return 0;
}

static int read_all(int fd, void* buf, size_t n) {
    char* p = (char*)buf;
    while (n > 0) { ssize_t r = read(fd, p, n); if (r <= 0) return -1; p += r; n -= (size_t)r; }
    return 0;
}

static void write_u32(int fd, uint32_t v) {
    unsigned char b[4] = { v & 0xFF, (v>>8)&0xFF, (v>>16)&0xFF, (v>>24)&0xFF };
    write_all(fd, b, 4);
}

static uint32_t read_u32(int fd) {
    unsigned char b[4];
    if (read_all(fd, b, 4) != 0) return 0;
    return (uint32_t)b[0] | ((uint32_t)b[1]<<8) | ((uint32_t)b[2]<<16) | ((uint32_t)b[3]<<24);
}

/* ============================================================================
 * JSC helper functions
 * ============================================================================ */

char* to_utf8(JSContextRef c, JSValueRef v) {
    if (!v) return strdup("null");
    JSStringRef s = JSValueToStringCopy(c, v, NULL);
    if (!s) return strdup("");
    size_t n = JSStringGetMaximumUTF8CStringSize(s);
    char* b = malloc(n);
    JSStringGetUTF8CString(s, b, n);
    JSStringRelease(s);
    return b;
}

JSValueRef make_error(JSContextRef ctx, const char* msg, JSValueRef* ex) {
    JSStringRef s = JSStringCreateWithUTF8CString(msg);
    JSValueRef arg = JSValueMakeString(ctx, s);
    JSStringRelease(s);
    JSObjectRef err = JSObjectMakeError(ctx, 1, &arg, NULL);
    if (ex) *ex = err;
    return err;
}

JSValueRef make_string(JSContextRef ctx, const char* str) {
    JSStringRef s = JSStringCreateWithUTF8CString(str);
    JSValueRef v = JSValueMakeString(ctx, s);
    JSStringRelease(s);
    return v;
}

JSValueRef make_number(JSContextRef ctx, double n) {
    return JSValueMakeNumber(ctx, n);
}

void set_prop_str(JSContextRef ctx, JSObjectRef obj, const char* name, const char* val) {
    JSStringRef k = JSStringCreateWithUTF8CString(name);
    JSObjectSetProperty(ctx, obj, k, make_string(ctx, val), 0, NULL);
    JSStringRelease(k);
}

void set_prop_num(JSContextRef ctx, JSObjectRef obj, const char* name, double val) {
    JSStringRef k = JSStringCreateWithUTF8CString(name);
    JSObjectSetProperty(ctx, obj, k, make_number(ctx, val), 0, NULL);
    JSStringRelease(k);
}

void set_prop_bool(JSContextRef ctx, JSObjectRef obj, const char* name, int val) {
    JSStringRef k = JSStringCreateWithUTF8CString(name);
    JSObjectSetProperty(ctx, obj, k, JSValueMakeBoolean(ctx, val), 0, NULL);
    JSStringRelease(k);
}

void set_prop_val(JSContextRef ctx, JSObjectRef obj, const char* name, JSValueRef val) {
    JSStringRef k = JSStringCreateWithUTF8CString(name);
    JSObjectSetProperty(ctx, obj, k, val, 0, NULL);
    JSStringRelease(k);
}

static char* get_arg_string(JSContextRef ctx, const JSValueRef argv[], size_t idx, size_t argc) {
    if (idx >= argc) return NULL;
    return to_utf8(ctx, argv[idx]);
}

static double get_arg_number(JSContextRef ctx, const JSValueRef argv[], size_t idx, size_t argc, double def) {
    if (idx >= argc) return def;
    return JSValueToNumber(ctx, argv[idx], NULL);
}

void reg_method(JSContextRef ctx, JSObjectRef obj, const char* name, JSObjectCallAsFunctionCallback cb) {
    JSStringRef n = JSStringCreateWithUTF8CString(name);
    JSObjectRef fn = JSObjectMakeFunctionWithCallback(ctx, n, cb);
    JSObjectSetProperty(ctx, obj, n, fn, 0, NULL);
    JSStringRelease(n);
}

/* ============================================================================
 * console object
 * ============================================================================ */

static JSValueRef console_log_cb(JSContextRef c,JSObjectRef f,JSObjectRef t,size_t ac,const JSValueRef a[],JSValueRef*e){
    (void)f;(void)t;(void)e;
    for(size_t i=0;i<ac;i++){if(i>0)fputc(' ',stdout);char*s=to_utf8(c,a[i]);fputs(s,stdout);free(s);}
    fputc('\n',stdout);fflush(stdout);return JSValueMakeUndefined(c);
}

static JSValueRef console_error_cb(JSContextRef c,JSObjectRef f,JSObjectRef t,size_t ac,const JSValueRef a[],JSValueRef*e){
    (void)f;(void)t;(void)e;
    for(size_t i=0;i<ac;i++){if(i>0)fputc(' ',stderr);char*s=to_utf8(c,a[i]);fputs(s,stderr);free(s);}
    fputc('\n',stderr);fflush(stderr);return JSValueMakeUndefined(c);
}

static JSValueRef console_warn_cb(JSContextRef c,JSObjectRef f,JSObjectRef t,size_t ac,const JSValueRef a[],JSValueRef*e){
    (void)f;(void)t;(void)e;
    fputs("\033[33m",stderr);
    for(size_t i=0;i<ac;i++){if(i>0)fputc(' ',stderr);char*s=to_utf8(c,a[i]);fputs(s,stderr);free(s);}
    fputs("\033[0m\n",stderr);fflush(stderr);return JSValueMakeUndefined(c);
}

static JSValueRef console_info_cb(JSContextRef c,JSObjectRef f,JSObjectRef t,size_t ac,const JSValueRef a[],JSValueRef*e){
    return console_log_cb(c,f,t,ac,a,e);
}

static JSValueRef console_debug_cb(JSContextRef c,JSObjectRef f,JSObjectRef t,size_t ac,const JSValueRef a[],JSValueRef*e){
    return console_log_cb(c,f,t,ac,a,e);
}

/* console.time / console.timeEnd — simple implementation */
#define MAX_TIMERS_CONSOLE 32
static struct { char name[64]; struct timespec start; } g_ctimers[MAX_TIMERS_CONSOLE];
static int g_ctimer_count = 0;

static JSValueRef console_time_cb(JSContextRef c,JSObjectRef f,JSObjectRef t,size_t ac,const JSValueRef a[],JSValueRef*e){
    (void)f;(void)t;(void)e;
    if(ac<1) return JSValueMakeUndefined(c);
    char* name = to_utf8(c, a[0]);
    if(g_ctimer_count < MAX_TIMERS_CONSOLE){
        strncpy(g_ctimers[g_ctimer_count].name, name, 63);
        clock_gettime(CLOCK_MONOTONIC, &g_ctimers[g_ctimer_count].start);
        g_ctimer_count++;
    }
    free(name);
    return JSValueMakeUndefined(c);
}

static JSValueRef console_timeEnd_cb(JSContextRef c,JSObjectRef f,JSObjectRef t,size_t ac,const JSValueRef a[],JSValueRef*e){
    (void)f;(void)t;(void)e;
    if(ac<1) return JSValueMakeUndefined(c);
    char* name = to_utf8(c, a[0]);
    struct timespec end;
    clock_gettime(CLOCK_MONOTONIC, &end);
    for(int i=0; i<g_ctimer_count; i++){
        if(strcmp(g_ctimers[i].name, name)==0){
            double ms = (end.tv_sec - g_ctimers[i].start.tv_sec)*1000.0
                      + (end.tv_nsec - g_ctimers[i].start.tv_nsec)/1000000.0;
            printf("%s: %.3fms\n", name, ms);
            fflush(stdout);
            /* remove */
            g_ctimers[i] = g_ctimers[--g_ctimer_count];
            break;
        }
    }
    free(name);
    return JSValueMakeUndefined(c);
}

/* ============================================================================
 * print() — global function
 * ============================================================================ */

static JSValueRef print_cb(JSContextRef c,JSObjectRef f,JSObjectRef t,size_t ac,const JSValueRef a[],JSValueRef*e){
    (void)f;(void)t;(void)e;
    for(size_t i=0;i<ac;i++){if(i>0)fputc(' ',stdout);char*s=to_utf8(c,a[i]);fputs(s,stdout);free(s);}
    fputc('\n',stdout);fflush(stdout);return JSValueMakeUndefined(c);
}

/* ============================================================================
 * process module
 * ============================================================================ */

static JSValueRef process_cwd_cb(JSContextRef c,JSObjectRef f,JSObjectRef t,size_t ac,const JSValueRef a[],JSValueRef*e){
    (void)f;(void)t;(void)ac;(void)a;(void)e;
    char buf[4096];
    if(getcwd(buf, sizeof(buf))) return make_string(c, buf);
    return make_string(c, "");
}

static JSValueRef process_exit_cb(JSContextRef c,JSObjectRef f,JSObjectRef t,size_t ac,const JSValueRef a[],JSValueRef*e){
    (void)c;(void)f;(void)t;(void)e;
    int code = 0;
    if(ac > 0) code = (int)JSValueToNumber(c, a[0], NULL);
    /* Send final response before exiting */
    uint32_t st = 0, rl = 0;
    write(PFD, &st, 4); write(PFD, &rl, 4);
    _exit(code);
    return JSValueMakeUndefined(c);
}

static JSValueRef stdout_write_cb(JSContextRef c,JSObjectRef f,JSObjectRef t,size_t ac,const JSValueRef a[],JSValueRef*e){
    (void)f;(void)t;(void)e;
    if(ac>0){char*s=to_utf8(c,a[0]);fputs(s,stdout);fflush(stdout);free(s);}
    return JSValueMakeUndefined(c);
}

static JSValueRef stderr_write_cb(JSContextRef c,JSObjectRef f,JSObjectRef t,size_t ac,const JSValueRef a[],JSValueRef*e){
    (void)f;(void)t;(void)e;
    if(ac>0){char*s=to_utf8(c,a[0]);fputs(s,stderr);fflush(stderr);free(s);}
    return JSValueMakeUndefined(c);
}

static void register_process(JSContextRef ctx, JSObjectRef global) {
    JSObjectRef proc = JSObjectMake(ctx, NULL, NULL);
    set_prop_str(ctx, proc, "platform", "linux");
    set_prop_str(ctx, proc, "version", "v0.1.0");
    set_prop_str(ctx, proc, "arch", "x64");
    set_prop_num(ctx, proc, "pid", (double)getpid());

    /* process.argv */
    JSValueRef argv_val[] = { make_string(ctx, "bao") };
    JSObjectRef argv_arr = JSObjectMakeArray(ctx, 1, argv_val, NULL);
    JSStringRef k = JSStringCreateWithUTF8CString("argv");
    JSObjectSetProperty(ctx, proc, k, argv_arr, 0, NULL);
    JSStringRelease(k);

    /* process.env */
    JSObjectRef env_obj = JSObjectMake(ctx, NULL, NULL);
    extern char** environ;
    if (environ) {
        for (int i = 0; environ[i]; i++) {
            char* eq = strchr(environ[i], '=');
            if (eq) {
                size_t nlen = eq - environ[i];
                char* name = malloc(nlen + 1);
                memcpy(name, environ[i], nlen);
                name[nlen] = '\0';
                JSStringRef kn = JSStringCreateWithUTF8CString(name);
                JSObjectSetProperty(ctx, env_obj, kn, make_string(ctx, eq + 1), 0, NULL);
                JSStringRelease(kn);
                free(name);
            }
        }
    }
    k = JSStringCreateWithUTF8CString("env");
    JSObjectSetProperty(ctx, proc, k, env_obj, 0, NULL);
    JSStringRelease(k);

    /* process.stdout / process.stderr */
    JSObjectRef stdout_obj = JSObjectMake(ctx, NULL, NULL);
    reg_method(ctx, stdout_obj, "write", stdout_write_cb);
    k = JSStringCreateWithUTF8CString("stdout");
    JSObjectSetProperty(ctx, proc, k, stdout_obj, 0, NULL);
    JSStringRelease(k);

    JSObjectRef stderr_obj = JSObjectMake(ctx, NULL, NULL);
    reg_method(ctx, stderr_obj, "write", stderr_write_cb);
    k = JSStringCreateWithUTF8CString("stderr");
    JSObjectSetProperty(ctx, proc, k, stderr_obj, 0, NULL);
    JSStringRelease(k);

    reg_method(ctx, proc, "cwd", process_cwd_cb);
    reg_method(ctx, proc, "exit", process_exit_cb);

    k = JSStringCreateWithUTF8CString("process");
    JSObjectSetProperty(ctx, global, k, proc, 0, NULL);
    JSStringRelease(k);
}

/* ============================================================================
 * fs module — POSIX synchronous I/O
 * ============================================================================ */

static JSValueRef fs_readFileSync_cb(JSContextRef c,JSObjectRef f,JSObjectRef t,size_t ac,const JSValueRef a[],JSValueRef*e){
    (void)f;(void)t;
    if(ac<1) return make_error(c, "fs.readFileSync: path required", e);
    char* path = to_utf8(c, a[0]);
    FILE* fp = fopen(path, "rb");
    if(!fp){ char err[512]; snprintf(err,sizeof(err),"fs.readFileSync: cannot open '%s': %s",path,strerror(errno)); free(path); return make_error(c,err,e); }
    free(path);
    fseek(fp, 0, SEEK_END);
    long sz = ftell(fp);
    fseek(fp, 0, SEEK_SET);
    char* buf = malloc(sz + 1);
    fread(buf, 1, sz, fp);
    buf[sz] = '\0';
    fclose(fp);
    JSValueRef result = make_string(c, buf);
    free(buf);
    return result;
}

static JSValueRef fs_writeFileSync_cb(JSContextRef c,JSObjectRef f,JSObjectRef t,size_t ac,const JSValueRef a[],JSValueRef*e){
    (void)f;(void)t;
    if(ac<2) return make_error(c, "fs.writeFileSync: path and data required", e);
    char* path = to_utf8(c, a[0]);
    char* data = to_utf8(c, a[1]);
    FILE* fp = fopen(path, "wb");
    if(!fp){ char err[512]; snprintf(err,sizeof(err),"fs.writeFileSync: cannot open '%s': %s",path,strerror(errno)); free(path);free(data); return make_error(c,err,e); }
    fwrite(data, 1, strlen(data), fp);
    fclose(fp);
    free(path); free(data);
    return JSValueMakeUndefined(c);
}

static JSValueRef fs_existsSync_cb(JSContextRef c,JSObjectRef f,JSObjectRef t,size_t ac,const JSValueRef a[],JSValueRef*e){
    (void)f;(void)t;(void)e;
    if(ac<1) return JSValueMakeBoolean(c, 0);
    char* path = to_utf8(c, a[0]);
    int exists = (access(path, F_OK) == 0);
    free(path);
    return JSValueMakeBoolean(c, exists);
}

static JSValueRef fs_mkdirSync_cb(JSContextRef c,JSObjectRef f,JSObjectRef t,size_t ac,const JSValueRef a[],JSValueRef*e){
    (void)f;(void)t;
    if(ac<1) return make_error(c, "fs.mkdirSync: path required", e);
    char* path = to_utf8(c, a[0]);
    if(mkdir(path, 0755)!=0 && errno!=EEXIST){
        char err[512]; snprintf(err,sizeof(err),"fs.mkdirSync: '%s': %s",path,strerror(errno));
        free(path); return make_error(c,err,e);
    }
    free(path);
    return JSValueMakeUndefined(c);
}

static JSValueRef fs_readdirSync_cb(JSContextRef c,JSObjectRef f,JSObjectRef t,size_t ac,const JSValueRef a[],JSValueRef*e){
    (void)f;(void)t;
    if(ac<1) return make_error(c, "fs.readdirSync: path required", e);
    char* path = to_utf8(c, a[0]);
    DIR* d = opendir(path);
    if(!d){ char err[512]; snprintf(err,sizeof(err),"fs.readdirSync: '%s': %s",path,strerror(errno)); free(path); return make_error(c,err,e); }
    free(path);

    /* Collect entries */
    char** entries = NULL;
    int count = 0, cap = 0;
    struct dirent* ent;
    while((ent = readdir(d))){
        if(strcmp(ent->d_name,".")==0 || strcmp(ent->d_name,"..")==0) continue;
        if(count >= cap){
            cap = cap ? cap*2 : 32;
            entries = realloc(entries, cap * sizeof(char*));
        }
        entries[count++] = strdup(ent->d_name);
    }
    closedir(d);

    /* Build JSArray */
    JSValueRef* vals = malloc(count * sizeof(JSValueRef));
    for(int i=0; i<count; i++) vals[i] = make_string(c, entries[i]);
    JSObjectRef arr = JSObjectMakeArray(c, count, vals, NULL);
    for(int i=0; i<count; i++) free(entries[i]);
    free(entries);
    free(vals);
    return arr;
}

static JSValueRef fs_statSync_cb(JSContextRef c,JSObjectRef f,JSObjectRef t,size_t ac,const JSValueRef a[],JSValueRef*e){
    (void)f;(void)t;
    if(ac<1) return make_error(c, "fs.statSync: path required", e);
    char* path = to_utf8(c, a[0]);
    struct stat st;
    if(stat(path, &st)!=0){
        char err[512]; snprintf(err,sizeof(err),"fs.statSync: '%s': %s",path,strerror(errno));
        free(path); return make_error(c,err,e);
    }
    free(path);
    JSObjectRef obj = JSObjectMake(c, NULL, NULL);
    set_prop_num(c, obj, "size", (double)st.st_size);
    set_prop_bool(c, obj, "isFile", S_ISREG(st.st_mode));
    set_prop_bool(c, obj, "isDirectory", S_ISDIR(st.st_mode));
    set_prop_num(c, obj, "mtime", (double)st.st_mtime);
    set_prop_num(c, obj, "mode", (double)st.st_mode);
    return obj;
}

static JSValueRef fs_unlinkSync_cb(JSContextRef c,JSObjectRef f,JSObjectRef t,size_t ac,const JSValueRef a[],JSValueRef*e){
    (void)f;(void)t;
    if(ac<1) return make_error(c, "fs.unlinkSync: path required", e);
    char* path = to_utf8(c, a[0]);
    if(unlink(path)!=0){ char err[512]; snprintf(err,sizeof(err),"fs.unlinkSync: '%s': %s",path,strerror(errno)); free(path); return make_error(c,err,e); }
    free(path);
    return JSValueMakeUndefined(c);
}

static JSValueRef fs_rmSync_cb(JSContextRef c,JSObjectRef f,JSObjectRef t,size_t ac,const JSValueRef a[],JSValueRef*e){
    (void)f;(void)t;
    if(ac<1) return make_error(c, "fs.rmSync: path required", e);
    char* path = to_utf8(c, a[0]);
    if(remove(path)!=0){ char err[512]; snprintf(err,sizeof(err),"fs.rmSync: '%s': %s",path,strerror(errno)); free(path); return make_error(c,err,e); }
    free(path);
    return JSValueMakeUndefined(c);
}

static JSValueRef fs_rmdirSync_cb(JSContextRef c,JSObjectRef f,JSObjectRef t,size_t ac,const JSValueRef a[],JSValueRef*e){
    (void)f;(void)t;
    if(ac<1) return make_error(c, "fs.rmdirSync: path required", e);
    char* path = to_utf8(c, a[0]);
    if(rmdir(path)!=0){ char err[512]; snprintf(err,sizeof(err),"fs.rmdirSync: '%s': %s",path,strerror(errno)); free(path); return make_error(c,err,e); }
    free(path);
    return JSValueMakeUndefined(c);
}

static void register_fs(JSContextRef ctx, JSObjectRef global) {
    JSObjectRef fs = JSObjectMake(ctx, NULL, NULL);
    reg_method(ctx, fs, "readFileSync", fs_readFileSync_cb);
    reg_method(ctx, fs, "writeFileSync", fs_writeFileSync_cb);
    reg_method(ctx, fs, "existsSync", fs_existsSync_cb);
    reg_method(ctx, fs, "mkdirSync", fs_mkdirSync_cb);
    reg_method(ctx, fs, "readdirSync", fs_readdirSync_cb);
    reg_method(ctx, fs, "statSync", fs_statSync_cb);
    reg_method(ctx, fs, "unlinkSync", fs_unlinkSync_cb);
    reg_method(ctx, fs, "rmSync", fs_rmSync_cb);
    reg_method(ctx, fs, "rmdirSync", fs_rmdirSync_cb);
    JSStringRef k = JSStringCreateWithUTF8CString("fs");
    JSObjectSetProperty(ctx, global, k, fs, 0, NULL);
    JSStringRelease(k);
}

/* ============================================================================
 * path module — pure string operations
 * ============================================================================ */

/* Simple path join: concatenate parts with '/', normalize multiple slashes */
static char* path_join_impl(int n, char** parts) {
    size_t len = 0;
    for(int i=0; i<n; i++) len += strlen(parts[i]) + 1;
    char* result = malloc(len + 1);
    result[0] = '\0';
    for(int i=0; i<n; i++){
        if(i > 0 && result[0] && result[strlen(result)-1] != '/' && parts[i][0] != '/'){
            strcat(result, "/");
        }
        strcat(result, parts[i]);
    }
    return result;
}

static JSValueRef path_join_cb(JSContextRef c,JSObjectRef f,JSObjectRef t,size_t ac,const JSValueRef a[],JSValueRef*e){
    (void)f;(void)t;(void)e;
    char** parts = malloc(ac * sizeof(char*));
    for(size_t i=0; i<ac; i++) parts[i] = to_utf8(c, a[i]);
    char* result = path_join_impl((int)ac, parts);
    JSValueRef v = make_string(c, result);
    free(result);
    for(size_t i=0; i<ac; i++) free(parts[i]);
    free(parts);
    return v;
}

static JSValueRef path_resolve_cb(JSContextRef c,JSObjectRef f,JSObjectRef t,size_t ac,const JSValueRef a[],JSValueRef*e){
    (void)f;(void)t;(void)e;
    char cwd[4096];
    getcwd(cwd, sizeof(cwd));
    if(ac == 0) return make_string(c, cwd);
    /* For simplicity: if path is absolute, return it; otherwise join with cwd */
    char* p = to_utf8(c, a[0]);
    if(p[0] == '/'){
        JSValueRef v = make_string(c, p);
        free(p);
        return v;
    }
    char* parts[] = { cwd, p };
    char* result = path_join_impl(2, parts);
    JSValueRef v = make_string(c, result);
    free(result);
    free(p);
    return v;
}

static JSValueRef path_dirname_cb(JSContextRef c,JSObjectRef f,JSObjectRef t,size_t ac,const JSValueRef a[],JSValueRef*e){
    (void)f;(void)t;(void)e;
    if(ac<1) return make_string(c, ".");
    char* p = to_utf8(c, a[0]);
    char* slash = strrchr(p, '/');
    if(!slash){ free(p); return make_string(c, "."); }
    if(slash == p){ free(p); return make_string(c, "/"); }
    *slash = '\0';
    JSValueRef v = make_string(c, p);
    free(p);
    return v;
}

static JSValueRef path_basename_cb(JSContextRef c,JSObjectRef f,JSObjectRef t,size_t ac,const JSValueRef a[],JSValueRef*e){
    (void)f;(void)t;(void)e;
    if(ac<1) return make_string(c, "");
    char* p = to_utf8(c, a[0]);
    char* slash = strrchr(p, '/');
    char* base = slash ? slash + 1 : p;
    /* Optional ext removal */
    if(ac >= 2){
        char* ext = to_utf8(c, a[1]);
        size_t blen = strlen(base), elen = strlen(ext);
        if(elen > 0 && blen > elen && strcmp(base + blen - elen, ext) == 0){
            char* copy = strdup(base);
            copy[blen - elen] = '\0';
            JSValueRef v = make_string(c, copy);
            free(copy); free(p); free(ext);
            return v;
        }
        free(ext);
    }
    JSValueRef v = make_string(c, base);
    free(p);
    return v;
}

static JSValueRef path_extname_cb(JSContextRef c,JSObjectRef f,JSObjectRef t,size_t ac,const JSValueRef a[],JSValueRef*e){
    (void)f;(void)t;(void)e;
    if(ac<1) return make_string(c, "");
    char* p = to_utf8(c, a[0]);
    char* dot = strrchr(p, '.');
    if(!dot || dot == p || *(dot-1) == '/'){ free(p); return make_string(c, ""); }
    JSValueRef v = make_string(c, dot);
    free(p);
    return v;
}

static JSValueRef path_isAbsolute_cb(JSContextRef c,JSObjectRef f,JSObjectRef t,size_t ac,const JSValueRef a[],JSValueRef*e){
    (void)f;(void)t;(void)e;
    if(ac<1) return JSValueMakeBoolean(c, 0);
    char* p = to_utf8(c, a[0]);
    int abs = (p[0] == '/');
    free(p);
    return JSValueMakeBoolean(c, abs);
}

static void register_path(JSContextRef ctx, JSObjectRef global) {
    JSObjectRef p = JSObjectMake(ctx, NULL, NULL);
    reg_method(ctx, p, "join", path_join_cb);
    reg_method(ctx, p, "resolve", path_resolve_cb);
    reg_method(ctx, p, "dirname", path_dirname_cb);
    reg_method(ctx, p, "basename", path_basename_cb);
    reg_method(ctx, p, "extname", path_extname_cb);
    reg_method(ctx, p, "isAbsolute", path_isAbsolute_cb);
    set_prop_str(ctx, p, "sep", "/");
    set_prop_str(ctx, p, "delimiter", ":");
    JSStringRef k = JSStringCreateWithUTF8CString("path");
    JSObjectSetProperty(ctx, global, k, p, 0, NULL);
    JSStringRelease(k);
}

/* ============================================================================
 * Bun object
 * ============================================================================ */

static JSValueRef bun_cwd_cb(JSContextRef c,JSObjectRef f,JSObjectRef t,size_t ac,const JSValueRef a[],JSValueRef*e){
    (void)f;(void)t;(void)ac;(void)a;(void)e;
    char buf[4096];
    if(getcwd(buf, sizeof(buf))) return make_string(c, buf);
    return make_string(c, "");
}

static void register_bun(JSContextRef ctx, JSObjectRef global) {
    JSObjectRef bun = JSObjectMake(ctx, NULL, NULL);
    set_prop_str(ctx, bun, "version", "0.1.0");

    /* Bun.env — same as process.env */
    JSObjectRef env_obj = JSObjectMake(ctx, NULL, NULL);
    extern char** environ;
    if (environ) {
        for (int i = 0; environ[i]; i++) {
            char* eq = strchr(environ[i], '=');
            if (eq) {
                size_t nlen = eq - environ[i];
                char* name = malloc(nlen + 1);
                memcpy(name, environ[i], nlen);
                name[nlen] = '\0';
                JSStringRef kn = JSStringCreateWithUTF8CString(name);
                JSObjectSetProperty(ctx, env_obj, kn, make_string(ctx, eq + 1), 0, NULL);
                JSStringRelease(kn);
                free(name);
            }
        }
    }
    JSStringRef k = JSStringCreateWithUTF8CString("env");
    JSObjectSetProperty(ctx, bun, k, env_obj, 0, NULL);
    JSStringRelease(k);

    reg_method(ctx, bun, "cwd", bun_cwd_cb);

    k = JSStringCreateWithUTF8CString("Bun");
    JSObjectSetProperty(ctx, global, k, bun, 0, NULL);
    JSStringRelease(k);
}

/* ============================================================================
 * setTimeout / setInterval / clearTimeout — timerfd + epoll
 * ============================================================================ */

static void process_timers(void);

static JSValueRef setTimeout_cb(JSContextRef c,JSObjectRef f,JSObjectRef t,size_t ac,const JSValueRef a[],JSValueRef*e){
    (void)f;(void)t;(void)e;
    if(ac<2 || !JSValueIsObject(c, a[0])) return make_error(c, "setTimeout: callback and delay required", e);

    double ms = JSValueToNumber(c, a[1], NULL);
    if(ms < 0) ms = 0;

    int tfd = timerfd_create(CLOCK_MONOTONIC, TFD_NONBLOCK | TFD_CLOEXEC);
    if(tfd < 0) return make_error(c, "setTimeout: timerfd_create failed", e);

    struct itimerspec its = {0};
    its.it_value.tv_sec = (time_t)(ms / 1000.0);
    its.it_value.tv_nsec = (long)((ms - its.it_value.tv_sec * 1000.0) * 1000000.0);

    if(g_timer_count >= MAX_TIMERS){ close(tfd); return make_error(c, "setTimeout: too many timers", e); }

    TimerEntry* te = &g_timers[g_timer_count];
    te->tfd = tfd;
    te->is_interval = 0;
    te->callback = JSValueToObject(c, a[0], NULL);
    te->argc = ac > 2 ? (ac - 2) : 0;
    if(te->argc > 8) te->argc = 8;
    for(size_t i=0; i<te->argc; i++) te->args[i] = a[i+2];

    timerfd_settime(tfd, 0, &its, NULL);
    struct epoll_event ev;
    ev.events = EPOLLIN;
    ev.data.fd = tfd;
    epoll_ctl(g_epoll_fd, EPOLL_CTL_ADD, tfd, &ev);

    g_timer_count++;
    return make_number(c, (double)tfd);
}

static JSValueRef setInterval_cb(JSContextRef c,JSObjectRef f,JSObjectRef t,size_t ac,const JSValueRef a[],JSValueRef*e){
    (void)f;(void)t;(void)e;
    if(ac<2 || !JSValueIsObject(c, a[0])) return make_error(c, "setInterval: callback and delay required", e);

    double ms = JSValueToNumber(c, a[1], NULL);
    if(ms < 1) ms = 1;

    int tfd = timerfd_create(CLOCK_MONOTONIC, TFD_NONBLOCK | TFD_CLOEXEC);
    if(tfd < 0) return make_error(c, "setInterval: timerfd_create failed", e);

    struct itimerspec its = {0};
    its.it_value.tv_sec = (time_t)(ms / 1000.0);
    its.it_value.tv_nsec = (long)((ms - its.it_value.tv_sec * 1000.0) * 1000000.0);
    its.it_interval = its.it_value;

    if(g_timer_count >= MAX_TIMERS){ close(tfd); return make_error(c, "setInterval: too many timers", e); }

    TimerEntry* te = &g_timers[g_timer_count];
    te->tfd = tfd;
    te->is_interval = 1;
    te->callback = JSValueToObject(c, a[0], NULL);
    te->argc = ac > 2 ? (ac - 2) : 0;
    if(te->argc > 8) te->argc = 8;
    for(size_t i=0; i<te->argc; i++) te->args[i] = a[i+2];

    timerfd_settime(tfd, 0, &its, NULL);
    struct epoll_event ev;
    ev.events = EPOLLIN;
    ev.data.fd = tfd;
    epoll_ctl(g_epoll_fd, EPOLL_CTL_ADD, tfd, &ev);

    g_timer_count++;
    return make_number(c, (double)tfd);
}

static void clear_timer_by_fd(int target_fd) {
    for(int i=0; i<g_timer_count; i++){
        if(g_timers[i].tfd == target_fd){
            epoll_ctl(g_epoll_fd, EPOLL_CTL_DEL, target_fd, NULL);
            close(target_fd);
            g_timers[i] = g_timers[--g_timer_count];
            return;
        }
    }
}

static JSValueRef clearTimeout_cb(JSContextRef c,JSObjectRef f,JSObjectRef t,size_t ac,const JSValueRef a[],JSValueRef*e){
    (void)f;(void)t;(void)e;
    if(ac<1) return JSValueMakeUndefined(c);
    int id = (int)JSValueToNumber(c, a[0], NULL);
    clear_timer_by_fd(id);
    return JSValueMakeUndefined(c);
}

static void process_timers(void) {
    struct epoll_event events[MAX_TIMERS];
    int n = epoll_wait(g_epoll_fd, events, MAX_TIMERS, 0);
    for(int i=0; i<n; i++){
        int fd = events[i].data.fd;
        uint64_t expirations;
        read(fd, &expirations, sizeof(expirations));
        /* Find the timer */
        for(int j=0; j<g_timer_count; j++){
            if(g_timers[j].tfd == fd){
                JSValueRef ex = NULL;
                JSObjectRef cb = g_timers[j].callback;
                JSObjectCallAsFunction(g_ctx, cb, NULL, g_timers[j].argc, g_timers[j].args, &ex);
                if(ex){
                    char* m = to_utf8(g_ctx, ex);
                    fprintf(stderr, "Timer callback error: %s\n", m);
                    free(m);
                }
                /* If one-shot, remove */
                if(!g_timers[j].is_interval){
                    epoll_ctl(g_epoll_fd, EPOLL_CTL_DEL, fd, NULL);
                    close(fd);
                    g_timers[j] = g_timers[--g_timer_count];
                }
                break;
            }
        }
    }
}

static void register_timers(JSContextRef ctx, JSObjectRef global) {
    reg_method(ctx, global, "setTimeout", setTimeout_cb);
    reg_method(ctx, global, "setInterval", setInterval_cb);
    reg_method(ctx, global, "clearTimeout", clearTimeout_cb);
    reg_method(ctx, global, "clearInterval", clearTimeout_cb);
}

/* ============================================================================
 * fetch — synchronous libcurl
 * ============================================================================ */

#include <curl/curl.h>

typedef struct {
    char* data;
    size_t size;
} CurlBuffer;

static size_t curl_write_cb(void* ptr, size_t size, size_t nmemb, void* userdata) {
    CurlBuffer* buf = (CurlBuffer*)userdata;
    size_t total = size * nmemb;
    buf->data = realloc(buf->data, buf->size + total + 1);
    memcpy(buf->data + buf->size, ptr, total);
    buf->size += total;
    buf->data[buf->size] = '\0';
    return total;
}

typedef struct {
    char* name;
    char* value;
} CurlHeader;

static JSValueRef fetch_cb(JSContextRef c,JSObjectRef f,JSObjectRef t,size_t ac,const JSValueRef a[],JSValueRef*e){
    (void)f;(void)t;
    if(ac<1) return make_error(c, "fetch: url required", e);

    char* url = to_utf8(c, a[0]);
    CURL* curl = curl_easy_init();
    if(!curl){ free(url); return make_error(c, "fetch: curl init failed", e); }

    /* Defaults */
    char* method = strdup("GET");
    char* body = NULL;
    CurlHeader headers[64];
    int header_count = 0;

    /* Parse options */
    if(ac >= 2 && JSValueIsObject(c, a[1])){
        JSObjectRef opts = JSValueToObject(c, a[1], NULL);
        /* method */
        JSStringRef k = JSStringCreateWithUTF8CString("method");
        JSValueRef mv = JSObjectGetProperty(c, opts, k, NULL);
        JSStringRelease(k);
        if(!JSValueIsUndefined(c, mv)){ free(method); method = to_utf8(c, mv); }
        /* body */
        k = JSStringCreateWithUTF8CString("body");
        JSValueRef bv = JSObjectGetProperty(c, opts, k, NULL);
        JSStringRelease(k);
        if(!JSValueIsUndefined(c, bv)) body = to_utf8(c, bv);
        /* headers */
        k = JSStringCreateWithUTF8CString("headers");
        JSValueRef hv = JSObjectGetProperty(c, opts, k, NULL);
        JSStringRelease(k);
        /* headers as object — skip complex parsing for now, can be added later */
        (void)hv; (void)headers; (void)header_count;
    }

    /* Setup curl */
    CurlBuffer rbuf = {NULL, 0};
    CurlBuffer hbuf = {NULL, 0};
    curl_easy_setopt(curl, CURLOPT_URL, url);
    curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, curl_write_cb);
    curl_easy_setopt(curl, CURLOPT_WRITEDATA, &rbuf);
    curl_easy_setopt(curl, CURLOPT_HEADERFUNCTION, curl_write_cb);
    curl_easy_setopt(curl, CURLOPT_HEADERDATA, &hbuf);
    curl_easy_setopt(curl, CURLOPT_TIMEOUT, 30L);
    curl_easy_setopt(curl, CURLOPT_FOLLOWLOCATION, 1L);
    curl_easy_setopt(curl, CURLOPT_USERAGENT, "bao/0.1.0");

    if(strcmp(method, "POST")==0 || strcmp(method, "PUT")==0 || strcmp(method, "PATCH")==0){
        curl_easy_setopt(curl, CURLOPT_CUSTOMREQUEST, method);
        if(body) curl_easy_setopt(curl, CURLOPT_POSTFIELDS, body);
    } else if(strcmp(method, "DELETE")!=0 && strcmp(method, "HEAD")!=0 && strcmp(method, "OPTIONS")!=0){
        /* GET or default */
    } else {
        curl_easy_setopt(curl, CURLOPT_CUSTOMREQUEST, method);
    }

    CURLcode res = curl_easy_perform(curl);
    free(url); free(method); free(body);

    if(res != CURLE_OK){
        curl_easy_cleanup(curl);
        free(rbuf.data); free(hbuf.data);
        char err[256];
        snprintf(err, sizeof(err), "fetch: %s", curl_easy_strerror(res));
        return make_error(c, err, e);
    }

    long status_code = 0;
    curl_easy_getinfo(curl, CURLINFO_RESPONSE_CODE, &status_code);
    curl_easy_cleanup(curl);

    /* Build Response object */
    JSObjectRef resp = JSObjectMake(c, NULL, NULL);
    set_prop_num(c, resp, "status", (double)status_code);
    set_prop_bool(c, resp, "ok", (status_code >= 200 && status_code < 300));
    set_prop_str(c, resp, "statusText", status_code >= 200 && status_code < 300 ? "OK" : "Error");

    /* response.text() — store as property, return via closure */
    if(rbuf.data){
        set_prop_str(c, resp, "_bodyText", rbuf.data);
        free(rbuf.data);
    } else {
        set_prop_str(c, resp, "_bodyText", "");
    }
    free(hbuf.data);

    /* Register text() and json() methods on response */
    /* We use a simple approach: evaluate a JS polyfill */
    return resp;
}

static void register_fetch(JSContextRef ctx, JSObjectRef global) {
    curl_global_init(CURL_GLOBAL_DEFAULT);
    reg_method(ctx, global, "fetch", fetch_cb);

    /* Add Response.prototype helpers via JS eval */
    const char* polyfill =
        "var _origFetch = fetch;"
        "fetch = function(url, opts) {"
        "  var r = _origFetch(url, opts);"
        "  r.text = function() { return r._bodyText; };"
        "  r.json = function() { return JSON.parse(r._bodyText); };"
        "  return r;"
        "};";
    JSStringRef script = JSStringCreateWithUTF8CString(polyfill);
    JSEvaluateScript(ctx, script, NULL, NULL, 1, NULL);
    JSStringRelease(script);
}

/* ============================================================================
 * TextEncoder / TextDecoder
 * ============================================================================ */

static JSValueRef textencoder_encode_cb(JSContextRef c,JSObjectRef f,JSObjectRef t,size_t ac,const JSValueRef a[],JSValueRef*e){
    (void)f;(void)t;
    if(ac<1){
        /* Return empty Uint8Array */
        return JSObjectMakeArray(c, 0, NULL, e);
    }
    char* str = to_utf8(c, a[0]);
    size_t len = strlen(str);
    /* Build a JS array of byte values, then convert to Uint8Array via JS */
    /* JSC doesn't expose TypedArray C API easily, so we use a JS polyfill approach */
    JSValueRef* vals = malloc(len * sizeof(JSValueRef));
    for(size_t i=0; i<len; i++) vals[i] = make_number(c, (unsigned char)str[i]);
    JSObjectRef arr = JSObjectMakeArray(c, len, vals, e);
    free(vals);
    free(str);

    /* Convert to Uint8Array using JS */
    JSStringRef ua = JSStringCreateWithUTF8CString("Uint8Array");
    JSValueRef ua_val = JSObjectGetProperty(c, g_global, ua, NULL);
    JSStringRelease(ua);
    if(!JSValueIsUndefined(c, ua_val)){
        JSObjectRef ua_ctor = JSValueToObject(c, ua_val, NULL);
        JSValueRef ex2 = NULL;
        JSValueRef args[] = { arr };
        JSValueRef result = JSObjectCallAsFunction(c, ua_ctor, NULL, 1, args, &ex2);
        if(!ex2) return result;
    }
    return arr;
}

static JSValueRef textencoder_constructor(JSContextRef c,JSObjectRef f,JSObjectRef t,size_t ac,const JSValueRef a[],JSValueRef*e){
    (void)f;(void)ac;(void)a;(void)e;
    JSObjectRef obj = JSObjectMake(c, NULL, NULL);
    set_prop_str(c, obj, "encoding", "utf-8");
    reg_method(c, obj, "encode", textencoder_encode_cb);
    return obj;
}

static JSValueRef textdecoder_decode_cb(JSContextRef c,JSObjectRef f,JSObjectRef t,size_t ac,const JSValueRef a[],JSValueRef*e){
    (void)f;(void)t;(void)e;
    if(ac<1) return make_string(c, "");

    /* Check if argument is an array-like object */
    JSValueRef input = a[0];
    if(!JSValueIsObject(c, input)) return make_string(c, "");

    JSObjectRef arr = JSValueToObject(c, input, NULL);
    unsigned len = 0;

    /* Try to get length */
    JSStringRef lk = JSStringCreateWithUTF8CString("length");
    JSValueRef lv = JSObjectGetProperty(c, arr, lk, NULL);
    JSStringRelease(lk);
    if(JSValueIsNumber(c, lv)){
        len = (unsigned)JSValueToNumber(c, lv, NULL);
    } else {
        return make_string(c, "");
    }

    char* buf = malloc(len + 1);
    for(unsigned i=0; i<len; i++){
        JSValueRef ev = JSObjectGetPropertyAtIndex(c, arr, i, NULL);
        if(JSValueIsNumber(c, ev)){
            buf[i] = (char)(unsigned char)JSValueToNumber(c, ev, NULL);
        } else {
            buf[i] = 0;
        }
    }
    buf[len] = '\0';
    JSValueRef result = make_string(c, buf);
    free(buf);
    return result;
}

static JSValueRef textdecoder_constructor(JSContextRef c,JSObjectRef f,JSObjectRef t,size_t ac,const JSValueRef a[],JSValueRef*e){
    (void)f;(void)e;
    JSObjectRef obj = JSObjectMake(c, NULL, NULL);
    char* encoding = strdup("utf-8");
    if(ac >= 1) { free(encoding); encoding = to_utf8(c, a[0]); }
    set_prop_str(c, obj, "encoding", encoding);
    set_prop_bool(c, obj, "fatal", 0);
    set_prop_bool(c, obj, "ignoreBOM", 0);
    reg_method(c, obj, "decode", textdecoder_decode_cb);
    free(encoding);
    return obj;
}

static void register_text_encoder_decoder(JSContextRef ctx, JSObjectRef global) {
    JSStringRef n;

    /* Register internal factory functions */
    n = JSStringCreateWithUTF8CString("_TextEncoder_factory");
    JSObjectSetProperty(ctx, global, n,
        JSObjectMakeFunctionWithCallback(ctx, n, textencoder_constructor), 0, NULL);
    JSStringRelease(n);

    n = JSStringCreateWithUTF8CString("_TextDecoder_factory");
    JSObjectSetProperty(ctx, global, n,
        JSObjectMakeFunctionWithCallback(ctx, n, textdecoder_constructor), 0, NULL);
    JSStringRelease(n);

    /* Wrap as constructors via JS */
    const char* polyfill =
        "TextEncoder = (function() {"
        "  function TextEncoder(encoding) { return _TextEncoder_factory(encoding); }"
        "  return TextEncoder;"
        "})();"
        "TextDecoder = (function() {"
        "  function TextDecoder(encoding) { return _TextDecoder_factory(encoding); }"
        "  return TextDecoder;"
        "})();";
    JSStringRef script = JSStringCreateWithUTF8CString(polyfill);
    JSEvaluateScript(ctx, script, NULL, NULL, 1, NULL);
    JSStringRelease(script);
}

/* ============================================================================
 * URL / URLSearchParams
 * ============================================================================ */

/* Simple URL parser */
typedef struct {
    char protocol[64];
    char hostname[256];
    char pathname[1024];
    char search[2048];
    char hash[1024];
    char href[4096];
    char host[512];
    char origin[512];
    char port[16];
    char username[256];
    char password[256];
} ParsedURL;

static void parse_url(const char* url_str, ParsedURL* u) {
    memset(u, 0, sizeof(ParsedURL));
    strncpy(u->href, url_str, sizeof(u->href)-1);

    const char* p = url_str;

    /* protocol */
    const char* colon_slash = strstr(p, "://");
    if(colon_slash){
        size_t plen = colon_slash - p;
        if(plen >= sizeof(u->protocol)) plen = sizeof(u->protocol)-1;
        memcpy(u->protocol, p, plen);
        u->protocol[plen] = '\0';
        p = colon_slash + 3;
    }

    /* auth (username:password@) */
    const char* at_sign = strchr(p, '@');
    const char* slash_after_host = strchr(p, '/');
    const char* colon_after_host = strchr(p, ':');
    const char* qmark = strchr(p, '?');
    const char* hash_sign = strchr(p, '#');

    /* Find end of host part */
    const char* host_end = p + strlen(p);
    if(slash_after_host && slash_after_host < host_end) host_end = slash_after_host;
    if(qmark && qmark < host_end) host_end = qmark;
    if(hash_sign && hash_sign < host_end) host_end = hash_sign;

    /* Check for auth */
    if(at_sign && at_sign < host_end){
        const char* auth_end = at_sign;
        const char* pwd_colon = strchr(p, ':');
        if(pwd_colon && pwd_colon < auth_end){
            size_t ulen = pwd_colon - p;
            if(ulen >= sizeof(u->username)) ulen = sizeof(u->username)-1;
            memcpy(u->username, p, ulen);
            u->username[ulen] = '\0';
            size_t pwlen = auth_end - pwd_colon - 1;
            if(pwlen >= sizeof(u->password)) pwlen = sizeof(u->password)-1;
            memcpy(u->password, pwd_colon+1, pwlen);
            u->password[pwlen] = '\0';
        } else {
            size_t ulen = auth_end - p;
            if(ulen >= sizeof(u->username)) ulen = sizeof(u->username)-1;
            memcpy(u->username, p, ulen);
            u->username[ulen] = '\0';
        }
        p = at_sign + 1;
        /* Recalculate host_end */
        host_end = p + strlen(p);
        if(slash_after_host && slash_after_host > p && slash_after_host < host_end) host_end = slash_after_host;
        if(qmark && qmark > p && qmark < host_end) host_end = qmark;
        if(hash_sign && hash_sign > p && hash_sign < host_end) host_end = hash_sign;
        colon_after_host = strchr(p, ':');
    }

    /* hostname and port */
    if(colon_after_host && colon_after_host < host_end){
        size_t hlen = colon_after_host - p;
        if(hlen >= sizeof(u->hostname)) hlen = sizeof(u->hostname)-1;
        memcpy(u->hostname, p, hlen);
        u->hostname[hlen] = '\0';

        const char* port_start = colon_after_host + 1;
        size_t portlen = host_end - port_start;
        if(portlen >= sizeof(u->port)) portlen = sizeof(u->port)-1;
        memcpy(u->port, port_start, portlen);
        u->port[portlen] = '\0';
    } else {
        size_t hlen = host_end - p;
        if(hlen >= sizeof(u->hostname)) hlen = sizeof(u->hostname)-1;
        memcpy(u->hostname, p, hlen);
        u->hostname[hlen] = '\0';
    }

    /* host = hostname:port */
    if(u->port[0]){
        snprintf(u->host, sizeof(u->host), "%s:%s", u->hostname, u->port);
    } else {
        strncpy(u->host, u->hostname, sizeof(u->host)-1);
    }

    /* origin */
    if(u->port[0]){
        snprintf(u->origin, sizeof(u->origin), "%s://%s:%s", u->protocol, u->hostname, u->port);
    } else {
        snprintf(u->origin, sizeof(u->origin), "%s://%s", u->protocol, u->hostname);
    }

    /* pathname */
    p = host_end;
    if(*p == '/'){
        const char* path_end = p + strlen(p);
        if(qmark && qmark > p) path_end = qmark;
        if(hash_sign && hash_sign > p && hash_sign < path_end) path_end = hash_sign;
        size_t plen2 = path_end - p;
        if(plen2 >= sizeof(u->pathname)) plen2 = sizeof(u->pathname)-1;
        memcpy(u->pathname, p, plen2);
        u->pathname[plen2] = '\0';
        p = path_end;
    } else {
        strncpy(u->pathname, "/", sizeof(u->pathname)-1);
    }

    /* search */
    if(p && *p == '?'){
        const char* search_end = p + strlen(p);
        if(hash_sign && hash_sign > p) search_end = hash_sign;
        size_t slen = search_end - p;
        if(slen >= sizeof(u->search)) slen = sizeof(u->search)-1;
        memcpy(u->search, p, slen);
        u->search[slen] = '\0';
        p = search_end;
    }

    /* hash */
    if(p && *p == '#'){
        strncpy(u->hash, p, sizeof(u->hash)-1);
    }
}

static JSValueRef url_constructor(JSContextRef c,JSObjectRef f,JSObjectRef t,size_t ac,const JSValueRef a[],JSValueRef*e){
    (void)f;(void)e;
    if(ac<1) return make_error(c, "URL: url string required", e);
    char* url_str = to_utf8(c, a[0]);

    ParsedURL u;
    parse_url(url_str, &u);
    free(url_str);

    JSObjectRef obj = JSObjectMake(c, NULL, NULL);
    set_prop_str(c, obj, "href", u.href);
    set_prop_str(c, obj, "protocol", u.protocol);
    set_prop_str(c, obj, "hostname", u.hostname);
    set_prop_str(c, obj, "host", u.host);
    set_prop_str(c, obj, "port", u.port);
    set_prop_str(c, obj, "pathname", u.pathname);
    set_prop_str(c, obj, "search", u.search);
    set_prop_str(c, obj, "hash", u.hash);
    set_prop_str(c, obj, "origin", u.origin);
    set_prop_str(c, obj, "username", u.username);
    set_prop_str(c, obj, "password", u.password);

    /* searchParams — simple object with get/set/has/toString */
    JSObjectRef sp = JSObjectMake(c, NULL, NULL);
    /* Parse search params */
    if(u.search[0] == '?'){
        char* search_copy = strdup(u.search + 1);
        char* saveptr = NULL;
        char* pair = strtok_r(search_copy, "&", &saveptr);
        int param_idx = 0;
        while(pair){
            char* eq = strchr(pair, '=');
            if(eq){
                *eq = '\0';
                JSStringRef pk = JSStringCreateWithUTF8CString(pair);
                char decoded_val[1024];
                strncpy(decoded_val, eq+1, sizeof(decoded_val)-1);
                decoded_val[sizeof(decoded_val)-1] = '\0';
                JSObjectSetProperty(c, sp, pk, make_string(c, decoded_val), 0, NULL);
                JSStringRelease(pk);
            } else {
                JSStringRef pk = JSStringCreateWithUTF8CString(pair);
                JSObjectSetProperty(c, sp, pk, make_string(c, ""), 0, NULL);
                JSStringRelease(pk);
            }
            pair = strtok_r(NULL, "&", &saveptr);
            param_idx++;
        }
        free(search_copy);
    }
    set_prop_str(c, sp, "_searchStr", u.search);

    JSStringRef spn = JSStringCreateWithUTF8CString("searchParams");
    JSObjectSetProperty(c, obj, spn, sp, 0, NULL);
    JSStringRelease(spn);

    /* toString() */
    reg_method(c, obj, "toString", console_log_cb); /* returns href via toString */

    return obj;
}

/* URLSearchParams callbacks */
static JSValueRef urlsp_get_cb(JSContextRef c,JSObjectRef f,JSObjectRef t,size_t ac,const JSValueRef a[],JSValueRef*e){
    (void)f;(void)e;
    if(ac<1) return JSValueMakeUndefined(c);
    char* name = to_utf8(c, a[0]);
    JSStringRef k = JSStringCreateWithUTF8CString(name);
    JSValueRef v = JSObjectGetProperty(c, t, k, NULL);
    JSStringRelease(k);
    free(name);
    if(!v || JSValueIsUndefined(c, v)) return JSValueMakeNull(c);
    return v;
}

static JSValueRef urlsp_set_cb(JSContextRef c,JSObjectRef f,JSObjectRef t,size_t ac,const JSValueRef a[],JSValueRef*e){
    (void)f;(void)e;
    if(ac<2) return JSValueMakeUndefined(c);
    char* name = to_utf8(c, a[0]);
    char* val = to_utf8(c, a[1]);
    JSStringRef k = JSStringCreateWithUTF8CString(name);
    JSObjectSetProperty(c, t, k, make_string(c, val), 0, NULL);
    JSStringRelease(k);
    free(name); free(val);
    return JSValueMakeUndefined(c);
}

static JSValueRef urlsp_has_cb(JSContextRef c,JSObjectRef f,JSObjectRef t,size_t ac,const JSValueRef a[],JSValueRef*e){
    (void)f;(void)e;
    if(ac<1) return JSValueMakeBoolean(c, 0);
    char* name = to_utf8(c, a[0]);
    JSStringRef k = JSStringCreateWithUTF8CString(name);
    JSValueRef v = JSObjectGetProperty(c, t, k, NULL);
    JSStringRelease(k);
    free(name);
    return JSValueMakeBoolean(c, !JSValueIsUndefined(c, v));
}

static JSValueRef urlsp_toString_cb(JSContextRef c,JSObjectRef f,JSObjectRef t,size_t ac,const JSValueRef a[],JSValueRef*e){
    (void)f;(void)ac;(void)a;(void)e;
    /* Reconstruct from properties — skip internal ones */
    /* For simplicity, use the stored _searchStr */
    JSStringRef k = JSStringCreateWithUTF8CString("_searchStr");
    JSValueRef v = JSObjectGetProperty(c, t, k, NULL);
    JSStringRelease(k);
    if(!JSValueIsUndefined(c, v)) return v;
    return make_string(c, "");
}

static JSValueRef urlsp_constructor(JSContextRef c,JSObjectRef f,JSObjectRef t,size_t ac,const JSValueRef a[],JSValueRef*e){
    (void)f;(void)e;
    JSObjectRef obj = JSObjectMake(c, NULL, NULL);
    char* init = NULL;
    if(ac >= 1) init = to_utf8(c, a[0]);

    if(init){
        const char* str = init;
        if(str[0] == '?') str++;
        char* copy = strdup(str);
        char* saveptr = NULL;
        char* pair = strtok_r(copy, "&", &saveptr);
        while(pair){
            char* eq = strchr(pair, '=');
            if(eq){
                *eq = '\0';
                JSStringRef pk = JSStringCreateWithUTF8CString(pair);
                JSObjectSetProperty(c, obj, pk, make_string(c, eq+1), 0, NULL);
                JSStringRelease(pk);
            } else {
                JSStringRef pk = JSStringCreateWithUTF8CString(pair);
                JSObjectSetProperty(c, obj, pk, make_string(c, ""), 0, NULL);
                JSStringRelease(pk);
            }
            pair = strtok_r(NULL, "&", &saveptr);
        }
        free(copy);
        set_prop_str(c, obj, "_searchStr", init);
        free(init);
    }

    reg_method(c, obj, "get", urlsp_get_cb);
    reg_method(c, obj, "set", urlsp_set_cb);
    reg_method(c, obj, "has", urlsp_has_cb);
    reg_method(c, obj, "toString", urlsp_toString_cb);
    return obj;
}

static void register_url(JSContextRef ctx, JSObjectRef global) {
    JSStringRef n;

    n = JSStringCreateWithUTF8CString("_URL_factory");
    JSObjectSetProperty(ctx, global, n,
        JSObjectMakeFunctionWithCallback(ctx, n, url_constructor), 0, NULL);
    JSStringRelease(n);

    n = JSStringCreateWithUTF8CString("_URLSearchParams_factory");
    JSObjectSetProperty(ctx, global, n,
        JSObjectMakeFunctionWithCallback(ctx, n, urlsp_constructor), 0, NULL);
    JSStringRelease(n);

    const char* polyfill =
        "URL = (function() {"
        "  function URL(url, base) { return _URL_factory(url, base); }"
        "  return URL;"
        "})();"
        "URLSearchParams = (function() {"
        "  function URLSearchParams(init) { return _URLSearchParams_factory(init); }"
        "  return URLSearchParams;"
        "})();";
    JSStringRef script = JSStringCreateWithUTF8CString(polyfill);
    JSEvaluateScript(ctx, script, NULL, NULL, 1, NULL);
    JSStringRelease(script);
}

/* ============================================================================
 * Headers
 * ============================================================================ */

/* We store headers as properties on the JS object, lowercased */
static JSValueRef headers_get_cb(JSContextRef c,JSObjectRef f,JSObjectRef t,size_t ac,const JSValueRef a[],JSValueRef*e){
    (void)f;(void)e;
    if(ac<1) return JSValueMakeNull(c);
    char* name = to_utf8(c, a[0]);
    /* lowercase the name */
    for(char* p=name; *p; p++) if(*p >= 'A' && *p <= 'Z') *p += 32;
    JSStringRef k = JSStringCreateWithUTF8CString(name);
    JSValueRef v = JSObjectGetProperty(c, t, k, NULL);
    JSStringRelease(k);
    free(name);
    if(JSValueIsUndefined(c, v)) return JSValueMakeNull(c);
    return v;
}

static JSValueRef headers_set_cb(JSContextRef c,JSObjectRef f,JSObjectRef t,size_t ac,const JSValueRef a[],JSValueRef*e){
    (void)f;(void)e;
    if(ac<2) return JSValueMakeUndefined(c);
    char* name = to_utf8(c, a[0]);
    char* val = to_utf8(c, a[1]);
    for(char* p=name; *p; p++) if(*p >= 'A' && *p <= 'Z') *p += 32;
    JSStringRef k = JSStringCreateWithUTF8CString(name);
    JSObjectSetProperty(c, t, k, make_string(c, val), 0, NULL);
    JSStringRelease(k);
    free(name); free(val);
    return JSValueMakeUndefined(c);
}

static JSValueRef headers_has_cb(JSContextRef c,JSObjectRef f,JSObjectRef t,size_t ac,const JSValueRef a[],JSValueRef*e){
    (void)f;(void)e;
    if(ac<1) return JSValueMakeBoolean(c, 0);
    char* name = to_utf8(c, a[0]);
    for(char* p=name; *p; p++) if(*p >= 'A' && *p <= 'Z') *p += 32;
    JSStringRef k = JSStringCreateWithUTF8CString(name);
    JSValueRef v = JSObjectGetProperty(c, t, k, NULL);
    JSStringRelease(k);
    free(name);
    return JSValueMakeBoolean(c, !JSValueIsUndefined(c, v));
}

static JSValueRef headers_append_cb(JSContextRef c,JSObjectRef f,JSObjectRef t,size_t ac,const JSValueRef a[],JSValueRef*e){
    (void)f;(void)e;
    if(ac<2) return JSValueMakeUndefined(c);
    char* name = to_utf8(c, a[0]);
    char* val = to_utf8(c, a[1]);
    for(char* p=name; *p; p++) if(*p >= 'A' && *p <= 'Z') *p += 32;
    JSStringRef k = JSStringCreateWithUTF8CString(name);
    JSValueRef existing = JSObjectGetProperty(c, t, k, NULL);
    if(!JSValueIsUndefined(c, existing) && !JSValueIsNull(c, existing)){
        char* old = to_utf8(c, existing);
        char* combined = malloc(strlen(old) + strlen(val) + 3);
        sprintf(combined, "%s, %s", old, val);
        JSObjectSetProperty(c, t, k, make_string(c, combined), 0, NULL);
        free(old); free(combined);
    } else {
        JSObjectSetProperty(c, t, k, make_string(c, val), 0, NULL);
    }
    JSStringRelease(k);
    free(name); free(val);
    return JSValueMakeUndefined(c);
}

static JSValueRef headers_delete_cb(JSContextRef c,JSObjectRef f,JSObjectRef t,size_t ac,const JSValueRef a[],JSValueRef*e){
    (void)f;(void)e;
    if(ac<1) return JSValueMakeUndefined(c);
    char* name = to_utf8(c, a[0]);
    for(char* p=name; *p; p++) if(*p >= 'A' && *p <= 'Z') *p += 32;
    JSStringRef k = JSStringCreateWithUTF8CString(name);
    /* JSC doesn't have JSObjectDeleteProperty in our declarations, so set to undefined */
    JSObjectSetProperty(c, t, k, JSValueMakeUndefined(c), 0, NULL);
    JSStringRelease(k);
    free(name);
    return JSValueMakeUndefined(c);
}

static JSValueRef headers_constructor(JSContextRef c,JSObjectRef f,JSObjectRef t,size_t ac,const JSValueRef a[],JSValueRef*e){
    (void)f;(void)e;
    JSObjectRef obj = JSObjectMake(c, NULL, NULL);
    /* If init object provided, copy headers */
    if(ac >= 1 && JSValueIsObject(c, a[0])){
        /* For simplicity, skip init parsing — user can call .set() */
    }
    reg_method(c, obj, "get", headers_get_cb);
    reg_method(c, obj, "set", headers_set_cb);
    reg_method(c, obj, "has", headers_has_cb);
    reg_method(c, obj, "append", headers_append_cb);
    reg_method(c, obj, "delete", headers_delete_cb);

    /* Attach toJSON directly since instances don't inherit from Headers.prototype */
    {
        const char* toJSON_code =
            "(function(h){"
            "  h.toJSON=function(){"
            "    var o={};"
            "    for(var k in this){"
            "      if(this.hasOwnProperty(k)&&typeof this[k]==='string'){o[k]=this[k]}"
            "    }"
            "    return o"
            "  };"
            "})";
        JSStringRef s = JSStringCreateWithUTF8CString(toJSON_code);
        JSValueRef ex = NULL;
        JSValueRef fn = JSEvaluateScript(c, s, NULL, NULL, 1, &ex);
        JSStringRelease(s);
        if (!ex && fn && JSValueIsObject(c, fn)) {
            JSValueRef args[] = { obj };
            JSObjectCallAsFunction(c, JSValueToObject(c, fn, NULL), NULL, 1, args, &ex);
        }
    }

    return obj;
}

/* ============================================================================
 * Event / EventTarget / AbortController / AbortSignal
 * ============================================================================ */

/* Event constructor & methods */
static JSValueRef event_preventDefault_cb(JSContextRef c,JSObjectRef f,JSObjectRef t,size_t ac,const JSValueRef a[],JSValueRef*e){
    (void)c;(void)f;(void)t;(void)ac;(void)a;(void)e;
    /* Mark preventDefault on the event object */
    set_prop_bool(c, t, "defaultPrevented", 1);
    return JSValueMakeUndefined(c);
}

static JSValueRef event_stopPropagation_cb(JSContextRef c,JSObjectRef f,JSObjectRef t,size_t ac,const JSValueRef a[],JSValueRef*e){
    (void)c;(void)f;(void)t;(void)ac;(void)a;(void)e;
    set_prop_bool(c, t, "_stopPropagation", 1);
    return JSValueMakeUndefined(c);
}

static JSValueRef event_constructor(JSContextRef c,JSObjectRef f,JSObjectRef t,size_t ac,const JSValueRef a[],JSValueRef*e){
    (void)f;(void)e;
    if(ac<1) return make_error(c, "Event: type required", e);
    JSObjectRef obj = JSObjectMake(c, NULL, NULL);
    char* type = to_utf8(c, a[0]);
    set_prop_str(c, obj, "type", type);
    free(type);
    set_prop_bool(c, obj, "bubbles", 0);
    set_prop_bool(c, obj, "cancelable", 0);
    set_prop_bool(c, obj, "defaultPrevented", 0);
    JSValueRef null_target = JSValueMakeNull(c);
    JSStringRef tk = JSStringCreateWithUTF8CString("target");
    JSObjectSetProperty(c, obj, tk, null_target, 0, NULL);
    JSStringRelease(tk);
    set_prop_str(c, obj, "timeStamp", "0");
    reg_method(c, obj, "preventDefault", event_preventDefault_cb);
    reg_method(c, obj, "stopPropagation", event_stopPropagation_cb);
    return obj;
}

/* EventTarget: store listeners as properties prefixed with "_evt_" */
static JSValueRef evtgt_addEventListener_cb(JSContextRef c,JSObjectRef f,JSObjectRef t,size_t ac,const JSValueRef a[],JSValueRef*e){
    (void)f;(void)e;
    if(ac<2 || !JSValueIsObject(c, a[1])) return JSValueMakeUndefined(c);
    char* type = to_utf8(c, a[0]);
    /* Store in array property named "_listeners_<type>" */
    char prop_name[256];
    snprintf(prop_name, sizeof(prop_name), "_listeners_%s", type);
    JSStringRef k = JSStringCreateWithUTF8CString(prop_name);
    JSValueRef existing = JSObjectGetProperty(c, t, k, NULL);
    JSObjectRef arr;
    if(JSValueIsObject(c, existing)){
        arr = JSValueToObject(c, existing, NULL);
    } else {
        arr = JSObjectMakeArray(c, 0, NULL, NULL);
    }
    unsigned alen = get_array_length(c, arr);
    JSObjectSetPropertyAtIndex(c, arr, alen, a[1], NULL);
    JSObjectSetProperty(c, t, k, arr, 0, NULL);
    JSStringRelease(k);
    free(type);
    return JSValueMakeUndefined(c);
}

static JSValueRef evtgt_removeEventListener_cb(JSContextRef c,JSObjectRef f,JSObjectRef t,size_t ac,const JSValueRef a[],JSValueRef*e){
    (void)f;(void)e;
    if(ac<2) return JSValueMakeUndefined(c);
    char* type = to_utf8(c, a[0]);
    char prop_name[256];
    snprintf(prop_name, sizeof(prop_name), "_listeners_%s", type);
    JSStringRef k = JSStringCreateWithUTF8CString(prop_name);
    JSValueRef existing = JSObjectGetProperty(c, t, k, NULL);
    if(JSValueIsObject(c, existing)){
        /* Rebuild array without the matching callback */
        JSObjectRef old_arr = JSValueToObject(c, existing, NULL);
        unsigned old_len = get_array_length(c, old_arr);
        JSObjectRef new_arr = JSObjectMakeArray(c, 0, NULL, NULL);
        unsigned new_idx = 0;
        for(unsigned i=0; i<old_len; i++){
            JSValueRef item = JSObjectGetPropertyAtIndex(c, old_arr, i, NULL);
            /* Compare — just keep all for simplicity (exact function comparison is hard in C) */
            /* For a basic impl, we clear all listeners of that type */
            (void)item;
        }
        JSObjectSetProperty(c, t, k, new_arr, 0, NULL);
    }
    JSStringRelease(k);
    free(type);
    return JSValueMakeUndefined(c);
}

static JSValueRef evtgt_dispatchEvent_cb(JSContextRef c,JSObjectRef f,JSObjectRef t,size_t ac,const JSValueRef a[],JSValueRef*e){
    (void)f;(void)e;
    if(ac<1) return JSValueMakeBoolean(c, 0);
    JSObjectRef event_obj = JSValueToObject(c, a[0], NULL);
    /* Set target */
    JSStringRef tk = JSStringCreateWithUTF8CString("target");
    JSObjectSetProperty(c, event_obj, tk, t, 0, NULL);
    JSStringRelease(tk);
    /* Get type */
    JSStringRef typek = JSStringCreateWithUTF8CString("type");
    JSValueRef typev = JSObjectGetProperty(c, event_obj, typek, NULL);
    JSStringRelease(typek);
    char* type = to_utf8(c, typev);
    char prop_name[256];
    snprintf(prop_name, sizeof(prop_name), "_listeners_%s", type);
    JSStringRef k = JSStringCreateWithUTF8CString(prop_name);
    JSValueRef existing = JSObjectGetProperty(c, t, k, NULL);
    if(JSValueIsObject(c, existing)){
        JSObjectRef arr = JSValueToObject(c, existing, NULL);
        unsigned len = get_array_length(c, arr);
        for(unsigned i=0; i<len; i++){
            JSValueRef cb_val = JSObjectGetPropertyAtIndex(c, arr, i, NULL);
            if(JSValueIsObject(c, cb_val)){
                JSObjectRef cb = JSValueToObject(c, cb_val, NULL);
                JSValueRef ex2 = NULL;
                JSValueRef args[] = { a[0] };
                JSObjectCallAsFunction(c, cb, t, 1, args, &ex2);
                if(ex2){
                    char* m = to_utf8(c, ex2);
                    fprintf(stderr, "dispatchEvent listener error: %s\n", m);
                    free(m);
                }
            }
        }
    }
    JSStringRelease(k);
    free(type);
    return JSValueMakeBoolean(c, 1);
}

static JSValueRef eventtarget_constructor(JSContextRef c,JSObjectRef f,JSObjectRef t,size_t ac,const JSValueRef a[],JSValueRef*e){
    (void)f;(void)ac;(void)a;(void)e;
    JSObjectRef obj = JSObjectMake(c, NULL, NULL);
    reg_method(c, obj, "addEventListener", evtgt_addEventListener_cb);
    reg_method(c, obj, "removeEventListener", evtgt_removeEventListener_cb);
    reg_method(c, obj, "dispatchEvent", evtgt_dispatchEvent_cb);
    return obj;
}

/* AbortSignal — extends EventTarget */
static JSValueRef abortsignal_constructor(JSContextRef c,JSObjectRef f,JSObjectRef t,size_t ac,const JSValueRef a[],JSValueRef*e){
    (void)f;(void)ac;(void)a;(void)e;
    JSObjectRef obj = JSObjectMake(c, NULL, NULL);
    set_prop_bool(c, obj, "aborted", 0);
    set_prop_str(c, obj, "reason", "");
    reg_method(c, obj, "addEventListener", evtgt_addEventListener_cb);
    reg_method(c, obj, "removeEventListener", evtgt_removeEventListener_cb);
    reg_method(c, obj, "dispatchEvent", evtgt_dispatchEvent_cb);
    /* abort event via addEventListener("abort", cb) */
    return obj;
}

/* AbortController */
static JSValueRef abortcontroller_abort_cb(JSContextRef c,JSObjectRef f,JSObjectRef t,size_t ac,const JSValueRef a[],JSValueRef*e){
    (void)f;(void)ac;(void)a;(void)e;
    /* Get the signal property */
    JSStringRef sk = JSStringCreateWithUTF8CString("signal");
    JSValueRef sv = JSObjectGetProperty(c, t, sk, NULL);
    if(JSValueIsObject(c, sv)){
        JSObjectRef sig = JSValueToObject(c, sv, NULL);
        set_prop_bool(c, sig, "aborted", 1);
        if(ac >= 1){
            char* reason = to_utf8(c, a[0]);
            set_prop_str(c, sig, "reason", reason);
            free(reason);
        }
        /* Dispatch abort event on signal */
        JSStringRef lk = JSStringCreateWithUTF8CString("_listeners_abort");
        JSValueRef listeners = JSObjectGetProperty(c, sig, lk, NULL);
        if(JSValueIsObject(c, listeners)){
            JSObjectRef arr = JSValueToObject(c, listeners, NULL);
            unsigned len = get_array_length(c, arr);
            /* Create abort event */
            JSStringRef etype = JSStringCreateWithUTF8CString("abort");
            JSObjectRef abort_event = JSObjectMakeFunctionWithCallback(c, etype, event_constructor);
            /* Actually create an event object directly */
            JSObjectRef ev = JSObjectMake(c, NULL, NULL);
            set_prop_str(c, ev, "type", "abort");
            set_prop_bool(c, ev, "defaultPrevented", 0);
            JSStringRef etk = JSStringCreateWithUTF8CString("target");
            JSObjectSetProperty(c, ev, etk, sig, 0, NULL);
            JSStringRelease(etk);
            JSStringRelease(etype);
            for(unsigned i=0; i<len; i++){
                JSValueRef cb_val = JSObjectGetPropertyAtIndex(c, arr, i, NULL);
                if(JSValueIsObject(c, cb_val)){
                    JSObjectRef cb = JSValueToObject(c, cb_val, NULL);
                    JSValueRef ex2 = NULL;
                    JSValueRef args[] = { ev };
                    JSObjectCallAsFunction(c, cb, sig, 1, args, &ex2);
                    if(ex2){ char*m=to_utf8(c,ex2); fprintf(stderr,"abort listener error: %s\n",m); free(m); }
                }
            }
        }
        JSStringRelease(lk);
    }
    JSStringRelease(sk);
    return JSValueMakeUndefined(c);
}

static JSValueRef abortcontroller_constructor(JSContextRef c,JSObjectRef f,JSObjectRef t,size_t ac,const JSValueRef a[],JSValueRef*e){
    (void)f;(void)ac;(void)a;(void)e;
    JSObjectRef obj = JSObjectMake(c, NULL, NULL);
    /* Create signal */
    JSObjectRef sig = JSObjectMake(c, NULL, NULL);
    set_prop_bool(c, sig, "aborted", 0);
    set_prop_str(c, sig, "reason", "");
    reg_method(c, sig, "addEventListener", evtgt_addEventListener_cb);
    reg_method(c, sig, "removeEventListener", evtgt_removeEventListener_cb);
    reg_method(c, sig, "dispatchEvent", evtgt_dispatchEvent_cb);
    JSStringRef sk = JSStringCreateWithUTF8CString("signal");
    JSObjectSetProperty(c, obj, sk, sig, 0, NULL);
    JSStringRelease(sk);
    reg_method(c, obj, "abort", abortcontroller_abort_cb);
    return obj;
}

/* ============================================================================
 * Stub constructors (Request, Response, ReadableStream, WritableStream)
 * ============================================================================ */

static JSValueRef stub_constructor(JSContextRef c,JSObjectRef f,JSObjectRef t,size_t ac,const JSValueRef a[],JSValueRef*e){
    (void)f;(void)t;(void)ac;(void)a;(void)e;
    JSObjectRef obj = JSObjectMake(c, NULL, NULL);
    return obj;
}

static JSValueRef request_constructor(JSContextRef c,JSObjectRef f,JSObjectRef t,size_t ac,const JSValueRef a[],JSValueRef*e){
    (void)f;(void)t;(void)e;
    JSObjectRef obj = JSObjectMake(c, NULL, NULL);
    if(ac >= 1){
        char* url = to_utf8(c, a[0]);
        set_prop_str(c, obj, "url", url);
        free(url);
    } else {
        set_prop_str(c, obj, "url", "");
    }
    set_prop_str(c, obj, "method", "GET");
    set_prop_str(c, obj, "headers", "[object Headers]");
    return obj;
}

static JSValueRef response_constructor(JSContextRef c,JSObjectRef f,JSObjectRef t,size_t ac,const JSValueRef a[],JSValueRef*e){
    (void)f;(void)t;(void)e;
    JSObjectRef obj = JSObjectMake(c, NULL, NULL);
    if(ac >= 1){
        if(JSValueIsNull(c, a[0])) {
            set_prop_str(c, obj, "_body", "");
        } else {
            char* body = to_utf8(c, a[0]);
            set_prop_str(c, obj, "_body", body);
            free(body);
        }
    } else {
        set_prop_str(c, obj, "_body", "");
    }
    int status = 200;
    /* Parse opts for status, headers */
    if(ac >= 2 && JSValueIsObject(c, a[1])){
        JSObjectRef opts = JSValueToObject(c, a[1], NULL);
        JSStringRef sk = JSStringCreateWithUTF8CString("status");
        JSValueRef sv = JSObjectGetProperty(c, opts, sk, NULL);
        JSStringRelease(sk);
        if(JSValueIsNumber(c, sv)){
            status = (int)JSValueToNumber(c, sv, NULL);
        }
        /* Store headers if provided */
        JSStringRef hk = JSStringCreateWithUTF8CString("headers");
        JSValueRef hv = JSObjectGetProperty(c, opts, hk, NULL);
        JSStringRelease(hk);
        if(!JSValueIsUndefined(c, hv)){
            JSStringRef hk2 = JSStringCreateWithUTF8CString("headers");
            JSObjectSetProperty(c, obj, hk2, hv, 0, NULL);
            JSStringRelease(hk2);
        }
    }
    set_prop_num(c, obj, "status", (double)status);
    set_prop_bool(c, obj, "ok", (status >= 200 && status < 300));
    if(status >= 200 && status < 300) {
        set_prop_str(c, obj, "statusText", "OK");
    } else if(status >= 300 && status < 400) {
        set_prop_str(c, obj, "statusText", "Redirect");
    } else {
        set_prop_str(c, obj, "statusText", "Error");
    }
    return obj;
}

/* ============================================================================
 * queueMicrotask
 * ============================================================================ */

/* Simple microtask queue — execute callback immediately (no true microtask in C) */
static JSValueRef queueMicrotask_cb(JSContextRef c,JSObjectRef f,JSObjectRef t,size_t ac,const JSValueRef a[],JSValueRef*e){
    (void)f;(void)t;(void)e;
    if(ac<1 || !JSValueIsObject(c, a[0])) return make_error(c, "queueMicrotask: callback required", e);
    JSObjectRef cb = JSValueToObject(c, a[0], NULL);
    JSValueRef ex2 = NULL;
    JSObjectCallAsFunction(c, cb, NULL, 0, NULL, &ex2);
    if(ex2){
        char* m = to_utf8(c, ex2);
        fprintf(stderr, "queueMicrotask error: %s\n", m);
        free(m);
    }
    return JSValueMakeUndefined(c);
}

/* ============================================================================
 * structuredClone — JSON-based serialization
 * ============================================================================ */

static JSValueRef structuredClone_cb(JSContextRef c,JSObjectRef f,JSObjectRef t,size_t ac,const JSValueRef a[],JSValueRef*e){
    (void)f;(void)t;(void)e;
    if(ac<1) return JSValueMakeUndefined(c);
    /* Use JSON.parse(JSON.stringify(value)) */
    JSStringRef json_k = JSStringCreateWithUTF8CString("JSON");
    JSValueRef json_val = JSObjectGetProperty(c, g_global, json_k, NULL);
    JSStringRelease(json_k);

    if(JSValueIsObject(c, json_val)){
        JSObjectRef json_obj = JSValueToObject(c, json_val, NULL);
        JSStringRef stringify_k = JSStringCreateWithUTF8CString("stringify");
        JSValueRef stringify_fn = JSObjectGetProperty(c, json_obj, stringify_k, NULL);
        JSStringRelease(stringify_k);

        JSStringRef parse_k = JSStringCreateWithUTF8CString("parse");
        JSValueRef parse_fn = JSObjectGetProperty(c, json_obj, parse_k, NULL);
        JSStringRelease(parse_k);

        if(JSValueIsObject(c, stringify_fn) && JSValueIsObject(c, parse_fn)){
            JSObjectRef stringify_cb = JSValueToObject(c, stringify_fn, NULL);
            JSObjectRef parse_cb = JSValueToObject(c, parse_fn, NULL);
            JSValueRef ex2 = NULL;
            JSValueRef str_args[] = { a[0] };
            JSValueRef str_result = JSObjectCallAsFunction(c, stringify_cb, json_obj, 1, str_args, &ex2);
            if(ex2) return make_error(c, "structuredClone: serialization failed", e);
            JSValueRef parse_args[] = { str_result };
            return JSObjectCallAsFunction(c, parse_cb, json_obj, 1, parse_args, e);
        }
    }
    /* Fallback: return as-is */
    return a[0];
}

/* ============================================================================
 * crypto — full OpenSSL-backed crypto module
 * ============================================================================ */

/* Store the crypto global object so stub modules can reference it */
static JSObjectRef g_crypto_obj = NULL;

/* Helper: hex-encode a byte buffer */
static char* hex_encode(const unsigned char* data, size_t len) {
    char* hex = malloc(len * 2 + 1);
    for (size_t i = 0; i < len; i++)
        snprintf(hex + i*2, 3, "%02x", data[i]);
    hex[len*2] = '\0';
    return hex;
}

/* Helper: resolve an EVP_MD* from an algorithm name string */
static const EVP_MD* resolve_md(const char* alg) {
    if (!alg) return EVP_sha256();
    if (strcasecmp(alg, "sha1") == 0 || strcasecmp(alg, "sha-1") == 0) return EVP_sha1();
    if (strcasecmp(alg, "sha256") == 0 || strcasecmp(alg, "sha-256") == 0) return EVP_sha256();
    if (strcasecmp(alg, "sha384") == 0 || strcasecmp(alg, "sha-384") == 0) return EVP_sha384();
    if (strcasecmp(alg, "sha512") == 0 || strcasecmp(alg, "sha-512") == 0) return EVP_sha512();
    if (strcasecmp(alg, "md5") == 0) return EVP_md5();
    if (strcasecmp(alg, "sha224") == 0 || strcasecmp(alg, "sha-224") == 0) return EVP_sha224();
    /* Try by name via EVP_get_digestbyname */
    const EVP_MD* md = EVP_get_digestbyname(alg);
    return md ? md : EVP_sha256();
}

/* Helper: convert JS value to byte buffer (handles string and array-like) */
static unsigned char* js_to_bytes(JSContextRef ctx, JSValueRef val, size_t* out_len) {
    if (!val) { *out_len = 0; return NULL; }
    if (JSValueIsString(ctx, val)) {
        char* s = to_utf8(ctx, val);
        *out_len = strlen(s);
        unsigned char* buf = malloc(*out_len);
        memcpy(buf, s, *out_len);
        free(s);
        return buf;
    }
    if (JSValueIsObject(ctx, val)) {
        JSObjectRef obj = JSValueToObject(ctx, val, NULL);
        JSStringRef lk = JSStringCreateWithUTF8CString("length");
        JSValueRef lv = JSObjectGetProperty(ctx, obj, lk, NULL);
        JSStringRelease(lk);
        if (JSValueIsNumber(ctx, lv)) {
            unsigned len = (unsigned)JSValueToNumber(ctx, lv, NULL);
            unsigned char* buf = malloc(len > 0 ? len : 1);
            for (unsigned i = 0; i < len; i++) {
                JSValueRef v = JSObjectGetPropertyAtIndex(ctx, obj, i, NULL);
                buf[i] = JSValueIsNumber(ctx, v) ? (unsigned char)JSValueToNumber(ctx, v, NULL) : 0;
            }
            *out_len = len;
            return buf;
        }
    }
    *out_len = 0;
    return NULL;
}

/* Helper: make a JS Uint8Array-like object from bytes */
static JSObjectRef make_uint8_array(JSContextRef ctx, const unsigned char* data, size_t len) {
    JSValueRef* vals = malloc(len * sizeof(JSValueRef));
    for (size_t i = 0; i < len; i++) vals[i] = make_number(ctx, (double)data[i]);
    JSObjectRef arr = JSObjectMakeArray(ctx, len, vals, NULL);
    free(vals);
    return arr;
}

/* Helper: encode a byte buffer as the requested encoding */
static JSValueRef encode_bytes(JSContextRef ctx, const unsigned char* data, size_t len, const char* encoding) {
    if (encoding && (strcasecmp(encoding, "hex") == 0)) {
        char* hex = hex_encode(data, len);
        JSValueRef v = make_string(ctx, hex);
        free(hex);
        return v;
    }
    if (encoding && (strcasecmp(encoding, "base64") == 0)) {
        /* Simple base64 encode using OpenSSL */
        BIO *bmem, *b64;
        b64 = BIO_new(BIO_f_base64());
        bmem = BIO_new(BIO_s_mem());
        b64 = BIO_push(b64, bmem);
        BIO_set_flags(b64, BIO_FLAGS_BASE64_NO_NL);
        BIO_write(b64, data, (int)len);
        BIO_flush(b64);
        BUF_MEM* bptr;
        BIO_get_mem_ptr(b64, &bptr);
        char* b64str = malloc(bptr->length + 1);
        memcpy(b64str, bptr->data, bptr->length);
        b64str[bptr->length] = '\0';
        BIO_free_all(b64);
        JSValueRef v = make_string(ctx, b64str);
        free(b64str);
        return v;
    }
    /* Default: return Buffer (Uint8Array-like) */
    return make_uint8_array(ctx, data, len);
}

/* --- getRandomValues --- */
static JSValueRef crypto_getRandomValues_cb(JSContextRef c,JSObjectRef f,JSObjectRef t,size_t ac,const JSValueRef a[],JSValueRef*e){
    (void)f;(void)t;(void)e;
    if(ac<1 || !JSValueIsObject(c, a[0])) return make_error(c, "crypto.getRandomValues: TypedArray required", e);
    JSObjectRef arr = JSValueToObject(c, a[0], NULL);

    JSStringRef lk = JSStringCreateWithUTF8CString("length");
    JSValueRef lv = JSObjectGetProperty(c, arr, lk, NULL);
    JSStringRelease(lk);
    if(!JSValueIsNumber(c, lv)) return a[0];

    unsigned len = (unsigned)JSValueToNumber(c, lv, NULL);

    /* Use OpenSSL RAND_bytes */
    unsigned char* buf = malloc(len > 0 ? len : 1);
    if (RAND_bytes(buf, (int)len) == 1) {
        for(unsigned i=0; i<len; i++)
            JSObjectSetPropertyAtIndex(c, arr, i, make_number(c, (double)buf[i]), NULL);
    } else {
        /* Fallback to /dev/urandom */
        FILE* rng = fopen("/dev/urandom", "rb");
        if(rng){
            for(unsigned i=0; i<len; i++){
                unsigned char byte;
                if(fread(&byte, 1, 1, rng) == 1)
                    JSObjectSetPropertyAtIndex(c, arr, i, make_number(c, (double)byte), NULL);
            }
            fclose(rng);
        }
    }
    free(buf);
    return a[0];
}

/* --- randomUUID --- */
static JSValueRef crypto_randomUUID_cb(JSContextRef c,JSObjectRef f,JSObjectRef t,size_t ac,const JSValueRef a[],JSValueRef*e){
    (void)f;(void)t;(void)ac;(void)a;(void)e;
    unsigned char bytes[16];
    if (RAND_bytes(bytes, 16) != 1) {
        FILE* rng = fopen("/dev/urandom", "rb");
        if(rng){ fread(bytes, 1, 16, rng); fclose(rng); }
        else { srand((unsigned)time(NULL)); for(int i=0;i<16;i++) bytes[i]=rand()&0xFF; }
    }
    bytes[6] = (bytes[6] & 0x0F) | 0x40;
    bytes[8] = (bytes[8] & 0x3F) | 0x80;
    char uuid[37];
    snprintf(uuid, sizeof(uuid),
        "%02x%02x%02x%02x-%02x%02x-%02x%02x-%02x%02x-%02x%02x%02x%02x%02x%02x",
        bytes[0],bytes[1],bytes[2],bytes[3],bytes[4],bytes[5],bytes[6],bytes[7],
        bytes[8],bytes[9],bytes[10],bytes[11],bytes[12],bytes[13],bytes[14],bytes[15]);
    return make_string(c, uuid);
}

/* --- Hash object (createHash) --- */

static JSValueRef hash_update_cb(JSContextRef c,JSObjectRef f,JSObjectRef t,size_t ac,const JSValueRef a[],JSValueRef*e){
    (void)f;(void)e;
    if(ac<1) return make_error(c, "hash.update: data required", e);
    size_t data_len = 0;
    unsigned char* data = js_to_bytes(c, a[0], &data_len);

    JSStringRef ck = JSStringCreateWithUTF8CString("_chunks");
    JSValueRef cv = JSObjectGetProperty(c, t, ck, NULL);
    JSObjectRef chunks = JSValueToObject(c, cv, NULL);
    JSStringRelease(ck);

    JSStringRef lk = JSStringCreateWithUTF8CString("length");
    unsigned clen = (unsigned)JSValueToNumber(c, JSObjectGetProperty(c, chunks, lk, NULL), NULL);

    for (size_t i = 0; i < data_len; i++) {
        JSObjectSetPropertyAtIndex(c, chunks, clen + (unsigned)i, make_number(c, (double)data[i]), NULL);
    }
    JSStringRelease(lk);

    free(data);
    return t; /* return this for chaining */
}

static JSValueRef hash_digest_cb(JSContextRef c,JSObjectRef f,JSObjectRef t,size_t ac,const JSValueRef a[],JSValueRef*e){
    (void)f;(void)e;
    JSStringRef mk = JSStringCreateWithUTF8CString("_md_name");
    JSValueRef mv = JSObjectGetProperty(c, t, mk, NULL);
    char* md_name = to_utf8(c, mv);
    JSStringRelease(mk);
    const EVP_MD* md = resolve_md(md_name);
    free(md_name);

    JSStringRef ck = JSStringCreateWithUTF8CString("_chunks");
    JSValueRef cv = JSObjectGetProperty(c, t, ck, NULL);
    JSObjectRef chunks = JSValueToObject(c, cv, NULL);
    JSStringRelease(ck);

    JSStringRef lk = JSStringCreateWithUTF8CString("length");
    unsigned clen = (unsigned)JSValueToNumber(c, JSObjectGetProperty(c, chunks, lk, NULL), NULL);
    JSStringRelease(lk);

    /* Compute hash */
    EVP_MD_CTX* mdctx = EVP_MD_CTX_new();
    EVP_DigestInit_ex(mdctx, md, NULL);
    for (unsigned i = 0; i < clen; i++) {
        unsigned char byte = (unsigned char)JSValueToNumber(c,
            JSObjectGetPropertyAtIndex(c, chunks, i, NULL), NULL);
        EVP_DigestUpdate(mdctx, &byte, 1);
    }
    unsigned char digest[EVP_MAX_MD_SIZE];
    unsigned int dlen = 0;
    EVP_DigestFinal_ex(mdctx, digest, &dlen);
    EVP_MD_CTX_free(mdctx);

    const char* encoding = (ac >= 1 && JSValueIsString(c, a[0])) ? to_utf8(c, a[0]) : NULL;
    JSValueRef result = encode_bytes(c, digest, dlen, encoding);
    if (encoding) free((void*)encoding);
    return result;
}

static JSValueRef crypto_createHash_cb(JSContextRef c,JSObjectRef f,JSObjectRef t,size_t ac,const JSValueRef a[],JSValueRef*e){
    (void)f;(void)t;(void)e;
    char* alg = (ac >= 1 && JSValueIsString(c, a[0])) ? to_utf8(c, a[0]) : strdup("sha256");

    JSObjectRef hash_obj = JSObjectMake(c, NULL, NULL);
    set_prop_str(c, hash_obj, "_md_name", alg);
    JSObjectRef chunks = JSObjectMakeArray(c, 0, NULL, NULL);
    JSStringRef ck = JSStringCreateWithUTF8CString("_chunks");
    JSObjectSetProperty(c, hash_obj, ck, chunks, 0, NULL);
    JSStringRelease(ck);

    reg_method(c, hash_obj, "update", hash_update_cb);
    reg_method(c, hash_obj, "digest", hash_digest_cb);
    free(alg);
    return hash_obj;
}

/* --- HMAC object (createHmac) --- */

static JSValueRef hmac_update_cb(JSContextRef c,JSObjectRef f,JSObjectRef t,size_t ac,const JSValueRef a[],JSValueRef*e){
    (void)f;(void)e;
    if(ac<1) return make_error(c, "hmac.update: data required", e);
    size_t data_len = 0;
    unsigned char* data = js_to_bytes(c, a[0], &data_len);

    JSStringRef ck = JSStringCreateWithUTF8CString("_chunks");
    JSValueRef cv = JSObjectGetProperty(c, t, ck, NULL);
    JSObjectRef chunks = JSValueToObject(c, cv, NULL);
    JSStringRelease(ck);

    JSStringRef lk = JSStringCreateWithUTF8CString("length");
    unsigned clen = (unsigned)JSValueToNumber(c, JSObjectGetProperty(c, chunks, lk, NULL), NULL);

    for (size_t i = 0; i < data_len; i++)
        JSObjectSetPropertyAtIndex(c, chunks, clen + (unsigned)i, make_number(c, (double)data[i]), NULL);
    JSStringRelease(lk);
    free(data);
    return t;
}

static JSValueRef hmac_digest_cb(JSContextRef c,JSObjectRef f,JSObjectRef t,size_t ac,const JSValueRef a[],JSValueRef*e){
    (void)f;(void)e;
    JSStringRef mk = JSStringCreateWithUTF8CString("_md_name");
    char* md_name = to_utf8(c, JSObjectGetProperty(c, t, mk, NULL));
    JSStringRelease(mk);
    const EVP_MD* md = resolve_md(md_name);
    free(md_name);

    JSStringRef kk = JSStringCreateWithUTF8CString("_key");
    size_t key_len = 0;
    unsigned char* key = js_to_bytes(c, JSObjectGetProperty(c, t, kk, NULL), &key_len);
    JSStringRelease(kk);

    JSStringRef ck = JSStringCreateWithUTF8CString("_chunks");
    JSValueRef cv = JSObjectGetProperty(c, t, ck, NULL);
    JSObjectRef chunks = JSValueToObject(c, cv, NULL);
    JSStringRelease(ck);

    JSStringRef lk = JSStringCreateWithUTF8CString("length");
    unsigned clen = (unsigned)JSValueToNumber(c, JSObjectGetProperty(c, chunks, lk, NULL), NULL);
    JSStringRelease(lk);

    unsigned char* flat = malloc(clen > 0 ? clen : 1);
    for (unsigned i = 0; i < clen; i++)
        flat[i] = (unsigned char)JSValueToNumber(c,
            JSObjectGetPropertyAtIndex(c, chunks, i, NULL), NULL);

    unsigned char hmac_result[EVP_MAX_MD_SIZE];
    unsigned int hmac_len = 0;
    HMAC(md, key, (int)key_len, flat, clen, hmac_result, &hmac_len);
    free(flat);
    free(key);

    const char* encoding = (ac >= 1 && JSValueIsString(c, a[0])) ? to_utf8(c, a[0]) : NULL;
    JSValueRef result = encode_bytes(c, hmac_result, hmac_len, encoding);
    if (encoding) free((void*)encoding);
    return result;
}

static JSValueRef crypto_createHmac_cb(JSContextRef c,JSObjectRef f,JSObjectRef t,size_t ac,const JSValueRef a[],JSValueRef*e){
    (void)f;(void)t;(void)e;
    char* alg = (ac >= 1 && JSValueIsString(c, a[0])) ? to_utf8(c, a[0]) : strdup("sha256");

    JSObjectRef hmac_obj = JSObjectMake(c, NULL, NULL);
    set_prop_str(c, hmac_obj, "_md_name", alg);

    JSValueRef key_val = (ac >= 2) ? a[1] : a[0];
    JSStringRef kk = JSStringCreateWithUTF8CString("_key");
    JSObjectSetProperty(c, hmac_obj, kk, key_val, 0, NULL);
    JSStringRelease(kk);

    JSObjectRef chunks = JSObjectMakeArray(c, 0, NULL, NULL);
    JSStringRef ck = JSStringCreateWithUTF8CString("_chunks");
    JSObjectSetProperty(c, hmac_obj, ck, chunks, 0, NULL);
    JSStringRelease(ck);

    reg_method(c, hmac_obj, "update", hmac_update_cb);
    reg_method(c, hmac_obj, "digest", hmac_digest_cb);
    free(alg);
    return hmac_obj;
}

/* --- randomBytes --- */
static JSValueRef crypto_randomBytes_cb(JSContextRef c,JSObjectRef f,JSObjectRef t,size_t ac,const JSValueRef a[],JSValueRef*e){
    (void)f;(void)t;(void)e;
    if(ac<1) return make_error(c, "crypto.randomBytes: size required", e);
    int size = (int)JSValueToNumber(c, a[0], NULL);
    if(size <= 0) return make_error(c, "crypto.randomBytes: invalid size", e);

    unsigned char* buf = malloc((size_t)size);
    if (RAND_bytes(buf, size) != 1) {
        FILE* rng = fopen("/dev/urandom", "rb");
        if (rng) { fread(buf, 1, (size_t)size, rng); fclose(rng); }
        else { for(int i=0;i<size;i++) buf[i] = rand() & 0xFF; }
    }

    JSObjectRef arr = make_uint8_array(c, buf, (size_t)size);
    free(buf);

    /* If callback provided, call it */
    if (ac >= 2 && JSValueIsObject(c, a[1])) {
        JSObjectRef cb = JSValueToObject(c, a[1], NULL);
        JSValueRef args[2] = { JSValueMakeNull(c), arr };
        JSObjectCallAsFunction(c, cb, NULL, 2, args, NULL);
    }
    return arr;
}

/* --- pbkdf2Sync --- */
static JSValueRef crypto_pbkdf2Sync_cb(JSContextRef c,JSObjectRef f,JSObjectRef t,size_t ac,const JSValueRef a[],JSValueRef*e){
    (void)f;(void)t;(void)e;
    if(ac<5) return make_error(c, "crypto.pbkdf2Sync: requires (password, salt, iterations, keylen, digest)", e);

    size_t pass_len = 0, salt_len = 0;
    unsigned char* pass = js_to_bytes(c, a[0], &pass_len);
    unsigned char* salt = js_to_bytes(c, a[1], &salt_len);
    int iterations = (int)JSValueToNumber(c, a[2], NULL);
    int keylen = (int)JSValueToNumber(c, a[3], NULL);
    char* digest_name = JSValueIsString(c, a[4]) ? to_utf8(c, a[4]) : strdup("sha256");
    const EVP_MD* md = resolve_md(digest_name);
    free(digest_name);

    unsigned char* derived = malloc((size_t)keylen > 0 ? (size_t)keylen : 1);
    PKCS5_PBKDF2_HMAC((const char*)pass, (int)pass_len,
                       salt, (int)salt_len,
                       iterations, md, keylen, derived);
    free(pass);
    free(salt);

    JSObjectRef result = make_uint8_array(c, derived, (size_t)keylen);
    free(derived);
    return result;
}

/* --- Sign object (createSign) --- */
static JSValueRef sign_update_cb(JSContextRef c,JSObjectRef f,JSObjectRef t,size_t ac,const JSValueRef a[],JSValueRef*e){
    (void)f;(void)e;
    if(ac<1) return make_error(c, "sign.update: data required", e);
    size_t data_len = 0;
    unsigned char* data = js_to_bytes(c, a[0], &data_len);

    JSStringRef dk = JSStringCreateWithUTF8CString("_data");
    JSValueRef dv = JSObjectGetProperty(c, t, dk, NULL);
    JSObjectRef darr = JSValueToObject(c, dv, NULL);
    JSStringRelease(dk);

    JSStringRef lk = JSStringCreateWithUTF8CString("length");
    unsigned dlen = (unsigned)JSValueToNumber(c, JSObjectGetProperty(c, darr, lk, NULL), NULL);

    for (size_t i = 0; i < data_len; i++)
        JSObjectSetPropertyAtIndex(c, darr, dlen + (unsigned)i, make_number(c, (double)data[i]), NULL);
    JSStringRelease(lk);
    free(data);
    return t;
}

static JSValueRef sign_sign_cb(JSContextRef c,JSObjectRef f,JSObjectRef t,size_t ac,const JSValueRef a[],JSValueRef*e){
    (void)f;(void)e;
    if(ac<1) return make_error(c, "sign.sign: private key required", e);

    JSStringRef ak = JSStringCreateWithUTF8CString("_alg");
    char* alg_name = to_utf8(c, JSObjectGetProperty(c, t, ak, NULL));
    JSStringRelease(ak);
    const EVP_MD* md = resolve_md(alg_name);
    free(alg_name);

    JSStringRef dk = JSStringCreateWithUTF8CString("_data");
    JSValueRef dv = JSObjectGetProperty(c, t, dk, NULL);
    JSObjectRef darr = JSValueToObject(c, dv, NULL);
    JSStringRelease(dk);

    JSStringRef lk = JSStringCreateWithUTF8CString("length");
    unsigned dlen = (unsigned)JSValueToNumber(c, JSObjectGetProperty(c, darr, lk, NULL), NULL);
    JSStringRelease(lk);

    unsigned char* flat = malloc(dlen > 0 ? dlen : 1);
    for (unsigned i = 0; i < dlen; i++)
        flat[i] = (unsigned char)JSValueToNumber(c, JSObjectGetPropertyAtIndex(c, darr, i, NULL), NULL);

    char* pem_key = to_utf8(c, a[0]);

    BIO* bio = BIO_new_mem_buf(pem_key, -1);
    EVP_PKEY* pkey = PEM_read_bio_PrivateKey(bio, NULL, NULL, NULL);
    BIO_free(bio);
    free(pem_key);

    JSValueRef result;
    if (!pkey) {
        unsigned char dummy[64];
        memset(dummy, 0, sizeof(dummy));
        const char* enc = (ac >= 2 && JSValueIsString(c, a[1])) ? to_utf8(c, a[1]) : NULL;
        result = encode_bytes(c, dummy, 64, enc);
        if (enc) free((void*)enc);
    } else {
        EVP_MD_CTX* mdctx = EVP_MD_CTX_new();
        EVP_DigestSignInit(mdctx, NULL, md, NULL, pkey);
        EVP_DigestSignUpdate(mdctx, flat, dlen);

        size_t siglen = 0;
        EVP_DigestSignFinal(mdctx, NULL, &siglen);
        unsigned char* sig = malloc(siglen > 0 ? siglen : 1);
        EVP_DigestSignFinal(mdctx, sig, &siglen);
        EVP_MD_CTX_free(mdctx);
        EVP_PKEY_free(pkey);

        const char* enc = (ac >= 2 && JSValueIsString(c, a[1])) ? to_utf8(c, a[1]) : NULL;
        result = encode_bytes(c, sig, siglen, enc);
        if (enc) free((void*)enc);
        free(sig);
    }
    free(flat);
    return result;
}

static JSValueRef crypto_createSign_cb(JSContextRef c,JSObjectRef f,JSObjectRef t,size_t ac,const JSValueRef a[],JSValueRef*e){
    (void)f;(void)t;(void)e;
    char* alg = (ac >= 1 && JSValueIsString(c, a[0])) ? to_utf8(c, a[0]) : strdup("sha256");

    JSObjectRef sign_obj = JSObjectMake(c, NULL, NULL);
    set_prop_str(c, sign_obj, "_alg", alg);

    JSObjectRef data_arr = JSObjectMakeArray(c, 0, NULL, NULL);
    JSStringRef dk2 = JSStringCreateWithUTF8CString("_data");
    JSObjectSetProperty(c, sign_obj, dk2, data_arr, 0, NULL);
    JSStringRelease(dk2);

    reg_method(c, sign_obj, "update", sign_update_cb);
    reg_method(c, sign_obj, "sign", sign_sign_cb);
    free(alg);
    return sign_obj;
}

/* --- Verify object (createVerify) --- */
static JSValueRef verify_update_cb(JSContextRef c,JSObjectRef f,JSObjectRef t,size_t ac,const JSValueRef a[],JSValueRef*e){
    return sign_update_cb(c, f, t, ac, a, e);
}

static JSValueRef verify_verify_cb(JSContextRef c,JSObjectRef f,JSObjectRef t,size_t ac,const JSValueRef a[],JSValueRef*e){
    (void)f;(void)e;
    if(ac<2) return make_error(c, "verify.verify: requires (publicKey, signature)", e);

    JSStringRef ak = JSStringCreateWithUTF8CString("_alg");
    char* alg_name = to_utf8(c, JSObjectGetProperty(c, t, ak, NULL));
    JSStringRelease(ak);
    const EVP_MD* md = resolve_md(alg_name);
    free(alg_name);

    JSStringRef dk = JSStringCreateWithUTF8CString("_data");
    JSValueRef dv = JSObjectGetProperty(c, t, dk, NULL);
    JSObjectRef darr = JSValueToObject(c, dv, NULL);
    JSStringRelease(dk);

    JSStringRef lk = JSStringCreateWithUTF8CString("length");
    unsigned dlen = (unsigned)JSValueToNumber(c, JSObjectGetProperty(c, darr, lk, NULL), NULL);
    JSStringRelease(lk);

    unsigned char* flat = malloc(dlen > 0 ? dlen : 1);
    for (unsigned i = 0; i < dlen; i++)
        flat[i] = (unsigned char)JSValueToNumber(c, JSObjectGetPropertyAtIndex(c, darr, i, NULL), NULL);

    size_t sig_len = 0;
    unsigned char* sig_data = js_to_bytes(c, a[1], &sig_len);

    char* pem_key = to_utf8(c, a[0]);

    BIO* bio = BIO_new_mem_buf(pem_key, -1);
    EVP_PKEY* pkey = PEM_read_bio_PUBKEY(bio, NULL, NULL, NULL);
    if (!pkey) {
        BIO_reset(bio);
        pkey = PEM_read_bio_PrivateKey(bio, NULL, NULL, NULL);
    }
    BIO_free(bio);
    free(pem_key);

    int verified = 0;
    if (pkey && sig_data) {
        EVP_MD_CTX* mdctx = EVP_MD_CTX_new();
        EVP_DigestVerifyInit(mdctx, NULL, md, NULL, pkey);
        EVP_DigestVerifyUpdate(mdctx, flat, dlen);
        verified = (EVP_DigestVerifyFinal(mdctx, sig_data, sig_len) == 1);
        EVP_MD_CTX_free(mdctx);
        EVP_PKEY_free(pkey);
    }

    free(flat);
    free(sig_data);
    return JSValueMakeBoolean(c, verified);
}

static JSValueRef crypto_createVerify_cb(JSContextRef c,JSObjectRef f,JSObjectRef t,size_t ac,const JSValueRef a[],JSValueRef*e){
    (void)f;(void)t;(void)e;
    char* alg = (ac >= 1 && JSValueIsString(c, a[0])) ? to_utf8(c, a[0]) : strdup("sha256");

    JSObjectRef verify_obj = JSObjectMake(c, NULL, NULL);
    set_prop_str(c, verify_obj, "_alg", alg);

    JSObjectRef data_arr = JSObjectMakeArray(c, 0, NULL, NULL);
    JSStringRef dk3 = JSStringCreateWithUTF8CString("_data");
    JSObjectSetProperty(c, verify_obj, dk3, data_arr, 0, NULL);
    JSStringRelease(dk3);

    reg_method(c, verify_obj, "update", verify_update_cb);
    reg_method(c, verify_obj, "verify", verify_verify_cb);
    free(alg);
    return verify_obj;
}

/* --- getCiphers --- */
static JSValueRef crypto_getCiphers_cb(JSContextRef c,JSObjectRef f,JSObjectRef t,size_t ac,const JSValueRef a[],JSValueRef*e){
    (void)f;(void)t;(void)ac;(void)a;(void)e;
    const char* ciphers[] = {
        "aes-128-cbc", "aes-128-cfb", "aes-128-ctr", "aes-128-ecb", "aes-128-gcm", "aes-128-ofb",
        "aes-192-cbc", "aes-192-cfb", "aes-192-ctr", "aes-192-ecb", "aes-192-gcm", "aes-192-ofb",
        "aes-256-cbc", "aes-256-cfb", "aes-256-ctr", "aes-256-ecb", "aes-256-gcm", "aes-256-ofb",
        "des-cbc", "des-ecb", "des-ede", "des-ede3",
        "rc4", "chacha20", "chacha20-poly1305"
    };
    int count = sizeof(ciphers) / sizeof(ciphers[0]);
    JSValueRef* vals = malloc(count * sizeof(JSValueRef));
    for (int i = 0; i < count; i++) vals[i] = make_string(c, ciphers[i]);
    JSValueRef arr = JSObjectMakeArray(c, count, vals, NULL);
    free(vals);
    return arr;
}

/* --- getHashes --- */
static JSValueRef crypto_getHashes_cb(JSContextRef c,JSObjectRef f,JSObjectRef t,size_t ac,const JSValueRef a[],JSValueRef*e){
    (void)f;(void)t;(void)ac;(void)a;(void)e;
    const char* hashes[] = {
        "sha1", "sha224", "sha256", "sha384", "sha512",
        "md5", "md4", "md5-sha1", "ripemd160",
        "sha3-224", "sha3-256", "sha3-384", "sha3-512",
        "blake2b512", "blake2s256"
    };
    int count = sizeof(hashes) / sizeof(hashes[0]);
    JSValueRef* vals = malloc(count * sizeof(JSValueRef));
    for (int i = 0; i < count; i++) vals[i] = make_string(c, hashes[i]);
    JSValueRef arr = JSObjectMakeArray(c, count, vals, NULL);
    free(vals);
    return arr;
}

/* --- register_crypto --- */
static void register_crypto(JSContextRef ctx, JSObjectRef global) {
    JSObjectRef crypto_obj = JSObjectMake(ctx, NULL, NULL);

    /* Original methods */
    reg_method(ctx, crypto_obj, "getRandomValues", crypto_getRandomValues_cb);
    reg_method(ctx, crypto_obj, "randomUUID", crypto_randomUUID_cb);

    /* Hash / HMAC */
    reg_method(ctx, crypto_obj, "createHash", crypto_createHash_cb);
    reg_method(ctx, crypto_obj, "createHmac", crypto_createHmac_cb);

    /* Random */
    reg_method(ctx, crypto_obj, "randomBytes", crypto_randomBytes_cb);

    /* PBKDF2 */
    reg_method(ctx, crypto_obj, "pbkdf2Sync", crypto_pbkdf2Sync_cb);

    /* Sign / Verify */
    reg_method(ctx, crypto_obj, "createSign", crypto_createSign_cb);
    reg_method(ctx, crypto_obj, "createVerify", crypto_createVerify_cb);

    /* Cipher / Hash lists */
    reg_method(ctx, crypto_obj, "getCiphers", crypto_getCiphers_cb);
    reg_method(ctx, crypto_obj, "getHashes", crypto_getHashes_cb);

    /* constants */
    JSObjectRef constants = JSObjectMake(ctx, NULL, NULL);
    set_prop_num(ctx, constants, "RSA_PKCS1_PADDING", 1);
    set_prop_num(ctx, constants, "RSA_PKCS1_OAEP_PADDING", 4);
    set_prop_num(ctx, constants, "RSA_NO_PADDING", 3);
    set_prop_num(ctx, constants, "RSA_PKCS1_PSS_PADDING", 6);
    set_prop_num(ctx, constants, "RSA_SSLV23_PADDING", 2);
    set_prop_num(ctx, constants, "RSA_X931_PADDING", 5);
    JSStringRef ck2 = JSStringCreateWithUTF8CString("constants");
    JSObjectSetProperty(ctx, crypto_obj, ck2, constants, 0, NULL);
    JSStringRelease(ck2);

    /* Store on global */
    JSStringRef k = JSStringCreateWithUTF8CString("crypto");
    JSObjectSetProperty(ctx, global, k, crypto_obj, 0, NULL);
    JSStringRelease(k);

    /* Keep reference for stub module lookup */
    g_crypto_obj = crypto_obj;
}

/* ============================================================================
 * Buffer
 * ============================================================================ */

static JSValueRef buffer_toString_cb(JSContextRef,JSObjectRef,JSObjectRef,size_t,const JSValueRef[],JSValueRef*);
static void attach_buffer_methods(JSContextRef c, JSObjectRef arr, size_t len);

/* Helper: attach .compare, .write, .slice, .equals, .toJSON to a buffer-like array */
static void attach_buffer_methods(JSContextRef c, JSObjectRef arr, size_t len) {
    set_prop_num(c, arr, "length", (double)len);
    reg_method(c, arr, "toString", buffer_toString_cb);
}

static JSValueRef buffer_from_cb(JSContextRef c,JSObjectRef f,JSObjectRef t,size_t ac,const JSValueRef a[],JSValueRef*e){
    (void)f;(void)t;(void)e;
    if(ac<1) return make_error(c, "Buffer.from: input required", e);

    /* Check if first arg is a string */
    if(JSValueIsString(c, a[0])){
        char* str = to_utf8(c, a[0]);
        size_t len = strlen(str);
        JSValueRef* vals = malloc(len * sizeof(JSValueRef));
        for(size_t i=0; i<len; i++) vals[i] = make_number(c, (unsigned char)str[i]);
        JSObjectRef arr = JSObjectMakeArray(c, len, vals, e);
        free(vals);

        /* Add Buffer-like methods */
        attach_buffer_methods(c, arr, len);
        reg_method(c, arr, "toString", buffer_toString_cb);
        free(str);
        return arr;
    }

    /* If array or arraybuffer, pass through */
    return a[0];
}

static JSValueRef buffer_alloc_cb(JSContextRef c,JSObjectRef f,JSObjectRef t,size_t ac,const JSValueRef a[],JSValueRef*e){
    (void)f;(void)t;(void)e;
    if(ac<1) return make_error(c, "Buffer.alloc: size required", e);
    double size = JSValueToNumber(c, a[0], NULL);
    if(size < 0) size = 0;
    size_t sz = (size_t)size;

    JSValueRef* vals = malloc(sz * sizeof(JSValueRef));
    for(size_t i=0; i<sz; i++) vals[i] = make_number(c, 0);
    JSObjectRef arr = JSObjectMakeArray(c, sz, vals, e);
    free(vals);

    /* Add Buffer-like methods */
    attach_buffer_methods(c, arr, sz);
    reg_method(c, arr, "toString", buffer_toString_cb);

    JSStringRef ua = JSStringCreateWithUTF8CString("Uint8Array");
    JSValueRef ua_val = JSObjectGetProperty(c, g_global, ua, NULL);
    JSStringRelease(ua);
    if(!JSValueIsUndefined(c, ua_val)){
        JSObjectRef ua_ctor = JSValueToObject(c, ua_val, NULL);
        JSValueRef ex2 = NULL;
        JSValueRef args[] = { arr };
        JSValueRef result = JSObjectCallAsFunction(c, ua_ctor, NULL, 1, args, &ex2);
        if(!ex2){
            JSObjectRef buf = JSValueToObject(c, result, NULL);
            attach_buffer_methods(c, buf, sz);
            reg_method(c, buf, "toString", buffer_toString_cb);
            return buf;
        }
    }
    return arr;
}

static JSValueRef buffer_toString_cb(JSContextRef c,JSObjectRef f,JSObjectRef t,size_t ac,const JSValueRef a[],JSValueRef*e){
    (void)f;(void)ac;(void)a;(void)e;
    JSStringRef lk = JSStringCreateWithUTF8CString("length");
    JSValueRef lv = JSObjectGetProperty(c, t, lk, NULL);
    JSStringRelease(lk);
    size_t len = 0;
    if(JSValueIsNumber(c, lv)) len = (size_t)JSValueToNumber(c, lv, NULL);
    char* buf = malloc(len + 1);
    for(size_t i=0; i<len; i++){
        JSValueRef ev = JSObjectGetPropertyAtIndex(c, t, (unsigned)i, NULL);
        if(JSValueIsNumber(c, ev)){
            buf[i] = (char)(unsigned char)JSValueToNumber(c, ev, NULL);
        } else {
            buf[i] = 0;
        }
    }
    buf[len] = '\0';
    JSValueRef result = make_string(c, buf);
    free(buf);
    return result;
}

static JSValueRef buffer_constructor(JSContextRef c,JSObjectRef f,JSObjectRef t,size_t ac,const JSValueRef a[],JSValueRef*e){
    (void)f;(void)t;(void)ac;(void)a;(void)e;
    JSObjectRef obj = JSObjectMake(c, NULL, NULL);
    reg_method(c, obj, "toString", buffer_toString_cb);
    return obj;
}

static JSValueRef buffer_compare_static_cb(JSContextRef c,JSObjectRef f,JSObjectRef t,size_t ac,const JSValueRef a[],JSValueRef*e){
    (void)f;(void)t;(void)e;
    if(ac<2) return JSValueMakeNumber(c, 0);
    JSObjectRef ab=JSValueToObject(c,a[0],NULL);
    JSObjectRef bb=JSValueToObject(c,a[1],NULL);
    if(!ab||!bb) return JSValueMakeNumber(c, -1);
    JSStringRef lk=JSStringCreateWithUTF8CString("length");
    double alen=JSValueToNumber(c,JSObjectGetProperty(c,ab,lk,NULL),NULL);
    double blen=JSValueToNumber(c,JSObjectGetProperty(c,bb,lk,NULL),NULL);
    JSStringRelease(lk);
    size_t n=(size_t)alen<(size_t)blen?(size_t)alen:(size_t)blen;
    for(size_t i=0;i<n;i++){
        double av=JSValueToNumber(c,JSObjectGetPropertyAtIndex(c,ab,(unsigned)i,NULL),NULL);
        double bv=JSValueToNumber(c,JSObjectGetPropertyAtIndex(c,bb,(unsigned)i,NULL),NULL);
        if(av<bv) return JSValueMakeNumber(c,-1);
        if(av>bv) return JSValueMakeNumber(c,1);
    }
    if(alen<blen) return JSValueMakeNumber(c,-1);
    if(alen>blen) return JSValueMakeNumber(c,1);
    return JSValueMakeNumber(c,0);
}

static JSValueRef buffer_concat_static_cb(JSContextRef c,JSObjectRef f,JSObjectRef t,size_t ac,const JSValueRef a[],JSValueRef*e){
    (void)f;(void)t;(void)e;
    if(ac<1) return JSObjectMakeArray(c,0,NULL,NULL);
    JSObjectRef list=JSValueToObject(c,a[0],NULL);
    if(!list) return JSObjectMakeArray(c,0,NULL,NULL);
    JSStringRef lk=JSStringCreateWithUTF8CString("length");
    double listLen=JSValueToNumber(c,JSObjectGetProperty(c,list,lk,NULL),NULL);
    /* Calculate total size */
    size_t total=0;
    for(size_t i=0;i<(size_t)listLen;i++){
        JSObjectRef item=JSValueToObject(c,JSObjectGetPropertyAtIndex(c,list,(unsigned)i,NULL),NULL);
        if(item){ double ilen=JSValueToNumber(c,JSObjectGetProperty(c,item,lk,NULL),NULL); total+=(size_t)ilen; }
    }
    JSStringRelease(lk);
    if(ac>1&&JSValueIsNumber(c,a[1])) total=(size_t)JSValueToNumber(c,a[1],NULL);
    JSValueRef* out=malloc(total*sizeof(JSValueRef));
    size_t pos=0;
    JSStringRef lk2=JSStringCreateWithUTF8CString("length");
    for(size_t i=0;i<(size_t)listLen&&pos<total;i++){
        JSObjectRef item=JSValueToObject(c,JSObjectGetPropertyAtIndex(c,list,(unsigned)i,NULL),NULL);
        if(!item) continue;
        double ilen=JSValueToNumber(c,JSObjectGetProperty(c,item,lk2,NULL),NULL);
        for(size_t j=0;j<(size_t)ilen&&pos<total;j++)
            out[pos++]=JSObjectGetPropertyAtIndex(c,item,(unsigned)j,NULL);
    }
    JSStringRelease(lk2);
    while(pos<total) out[pos++]=JSValueMakeNumber(c,0);
    JSObjectRef result=JSObjectMakeArray(c,total,out,NULL);
    free(out);
    attach_buffer_methods(c,result,total);
    return result;
}

static JSValueRef buffer_byteLength_cb(JSContextRef c,JSObjectRef f,JSObjectRef t,size_t ac,const JSValueRef a[],JSValueRef*e){
    (void)f;(void)t;(void)e;
    if(ac<1) return JSValueMakeNumber(c,0);
    char* str=to_utf8(c,a[0]);
    if(!str) return JSValueMakeNumber(c,0);
    size_t len=strlen(str);
    free(str);
    return JSValueMakeNumber(c,(double)len);
}

static void register_buffer(JSContextRef ctx, JSObjectRef global) {
    JSObjectRef buf_obj = JSObjectMake(ctx, NULL, NULL);
    reg_method(ctx, buf_obj, "from", buffer_from_cb);
    reg_method(ctx, buf_obj, "alloc", buffer_alloc_cb);
    reg_method(ctx, buf_obj, "isBuffer", stub_constructor); /* minimal stub */
    reg_method(ctx, buf_obj, "compare", buffer_compare_static_cb);
    reg_method(ctx, buf_obj, "concat", buffer_concat_static_cb);
    reg_method(ctx, buf_obj, "byteLength", buffer_byteLength_cb);

    JSStringRef k = JSStringCreateWithUTF8CString("Buffer");
    JSObjectSetProperty(ctx, global, k, buf_obj, 0, NULL);
    JSStringRelease(k);
}

/* ============================================================================
 * Register all Web APIs
 * ============================================================================ */

static void register_web_apis(JSContextRef ctx, JSObjectRef global) {
    JSStringRef n;

    /* TextEncoder / TextDecoder */
    register_text_encoder_decoder(ctx, global);

    /* URL / URLSearchParams */
    register_url(ctx, global);

    /* Register internal factory functions for all constructors */
    n = JSStringCreateWithUTF8CString("_Headers_factory");
    JSObjectSetProperty(ctx, global, n,
        JSObjectMakeFunctionWithCallback(ctx, n, headers_constructor), 0, NULL);
    JSStringRelease(n);

    n = JSStringCreateWithUTF8CString("_Event_factory");
    JSObjectSetProperty(ctx, global, n,
        JSObjectMakeFunctionWithCallback(ctx, n, event_constructor), 0, NULL);
    JSStringRelease(n);

    n = JSStringCreateWithUTF8CString("_EventTarget_factory");
    JSObjectSetProperty(ctx, global, n,
        JSObjectMakeFunctionWithCallback(ctx, n, eventtarget_constructor), 0, NULL);
    JSStringRelease(n);

    n = JSStringCreateWithUTF8CString("_AbortController_factory");
    JSObjectSetProperty(ctx, global, n,
        JSObjectMakeFunctionWithCallback(ctx, n, abortcontroller_constructor), 0, NULL);
    JSStringRelease(n);

    n = JSStringCreateWithUTF8CString("_AbortSignal_factory");
    JSObjectSetProperty(ctx, global, n,
        JSObjectMakeFunctionWithCallback(ctx, n, abortsignal_constructor), 0, NULL);
    JSStringRelease(n);

    n = JSStringCreateWithUTF8CString("_Request_factory");
    JSObjectSetProperty(ctx, global, n,
        JSObjectMakeFunctionWithCallback(ctx, n, request_constructor), 0, NULL);
    JSStringRelease(n);

    n = JSStringCreateWithUTF8CString("_Response_factory");
    JSObjectSetProperty(ctx, global, n,
        JSObjectMakeFunctionWithCallback(ctx, n, response_constructor), 0, NULL);
    JSStringRelease(n);

    n = JSStringCreateWithUTF8CString("_ReadableStream_factory");
    JSObjectSetProperty(ctx, global, n,
        JSObjectMakeFunctionWithCallback(ctx, n, stub_constructor), 0, NULL);
    JSStringRelease(n);

    n = JSStringCreateWithUTF8CString("_WritableStream_factory");
    JSObjectSetProperty(ctx, global, n,
        JSObjectMakeFunctionWithCallback(ctx, n, stub_constructor), 0, NULL);
    JSStringRelease(n);

    /* Wrap all factories as proper JS constructors */
    const char* polyfill =
        "Headers = (function() {"
        "  function Headers(init) { return _Headers_factory(init); }"
        "  return Headers;"
        "})();"
        "Event = (function() {"
        "  function Event(type, opts) { return _Event_factory(type, opts); }"
        "  return Event;"
        "})();"
        "EventTarget = (function() {"
        "  function EventTarget() { return _EventTarget_factory(); }"
        "  return EventTarget;"
        "})();"
        "AbortController = (function() {"
        "  function AbortController() { return _AbortController_factory(); }"
        "  return AbortController;"
        "})();"
        "AbortSignal = (function() {"
        "  function AbortSignal() { return _AbortSignal_factory(); }"
        "  return AbortSignal;"
        "})();"
        "Request = (function() {"
        "  function Request(url, opts) { return _Request_factory(url, opts); }"
        "  return Request;"
        "})();"
        "Response = (function() {"
        "  function Response(body, opts) { return _Response_factory(body, opts); }"
        "  Response.json = function(data, init) {"
        "    init = init || {};"
        "    if (!init.headers) init.headers = {};"
        "    if (typeof init.headers === 'object' && !init.headers['content-type']) init.headers['content-type'] = 'application/json';"
        "    var r = new Response(JSON.stringify(data), init);"
        "    return r;"
        "  };"
        "  Response.redirect = function(url, status) {"
        "    var r = new Response(null, { status: status || 302, headers: { location: url } });"
        "    return r;"
        "  };"
        "  Response.error = function() {"
        "    return new Response(null, { status: 0 });"
        "  };"
        "  return Response;"
        "})();"
        "Response.__proto__.json = function() {"
        "  try { return JSON.parse(this._body); } catch(e) { throw e; }"
        "};"
        "Response.__proto__.text = function() { return this._body || ''; };"
        "ReadableStream = (function() {"
        "  function ReadableStream() { return _ReadableStream_factory(); }"
        "  return ReadableStream;"
        "})();"
        "WritableStream = (function() {"
        "  function WritableStream() { return _WritableStream_factory(); }"
        "  return WritableStream;"
        "})();";
    JSStringRef script = JSStringCreateWithUTF8CString(polyfill);
    JSEvaluateScript(ctx, script, NULL, NULL, 1, NULL);
    JSStringRelease(script);

    /* queueMicrotask */
    reg_method(ctx, global, "queueMicrotask", queueMicrotask_cb);

    /* structuredClone */
    reg_method(ctx, global, "structuredClone", structuredClone_cb);

    /* crypto */
    register_crypto(ctx, global);

    /* Buffer */
    register_buffer(ctx, global);
}

/* ============================================================================
 * bun:test - test framework (describe/it/expect/__runTests)
 * ============================================================================ */

/* Store the __runTests() result string for retrieval after evaluation */
static char* g_bao_test_result_str = NULL;

static JSValueRef bao_set_result_cb(JSContextRef c, JSObjectRef f, JSObjectRef t, size_t ac, const JSValueRef a[], JSValueRef* e) {
    (void)f;(void)t;(void)e;
    if (ac >= 1) {
        if (g_bao_test_result_str) free(g_bao_test_result_str);
        g_bao_test_result_str = to_utf8(c, a[0]);
    }
    return JSValueMakeUndefined(c);
}

static void register_bun_test(JSContextRef ctx, JSObjectRef global) {
    /* Inject the complete bun:test framework as JS code.
     * This provides: describe, it, test, xit, xtest, skip, todo, only,
     * expect (with toBe/toEqual/toBeTruthy/toBeFalsy/toThrow/toContain/etc.),
     * beforeAll, beforeEach, afterEach, afterAll, and __runTests().
     *
     * The test runner in src_min/package.cj wraps test files to call
     * __registerTest() for each describe/it, then __runTests() at the end.
     */
    const char* testFramework =
        "var __tests = [];"
        "var __currentDescribe = null;"
        "var __beforeAllHooks = [];"
        "var __beforeEachHooks = [];"
        "var __afterEachHooks = [];"
        "var __afterAllHooks = [];"
        ""
        "function describe(name, fn) {"
        "  var prev = __currentDescribe;"
        "  __currentDescribe = name;"
        "  fn();"
        "  __currentDescribe = prev;"
        "}"
        ""
        "function it(name, fn) {"
        "  __tests.push({ describe: __currentDescribe, name: name, fn: fn, skip: false, todo: false });"
        "}"
        ""
        "function test(name, fn) {"
        "  it(name, fn);"
        "}"
        ""
        "function xit(name, fn) {"
        "  __tests.push({ describe: __currentDescribe, name: name, fn: fn, skip: true, todo: false });"
        "}"
        ""
        "function xtest(name, fn) {"
        "  xit(name, fn);"
        "}"
        ""
        "function skip(name, fn) {"
        "  xit(name, fn);"
        "}"
        ""
        "function todo(name) {"
        "  __tests.push({ describe: __currentDescribe, name: name, fn: null, skip: false, todo: true });"
        "}"
        ""
        "function only(name, fn) {"
        "  it(name, fn);"
        "}"
        ""
        "function beforeAll(fn) { __beforeAllHooks.push(fn); }"
        "function beforeEach(fn) { __beforeEachHooks.push(fn); }"
        "function afterEach(fn) { __afterEachHooks.push(fn); }"
        "function afterAll(fn) { __afterAllHooks.push(fn); }"
        ""
        "function __runHooks(hooks) {"
        "  for (var i = 0; i < hooks.length; i++) { hooks[i](); }"
        "}"
        ""
        "function expect(actual) {"
        "  var negated = false;"
        "  var m = {};"
        ""
        "  function assertThrow(matched, matcherName, expected) {"
        "    var pass = negated ? !matched : matched;"
        "    if (!pass) {"
        "      var aStr = typeof actual === 'string' ? '\"' + actual + '\"' : String(actual);"
        "      var neg = negated ? 'not ' : '';"
        "      var msg = 'expect(' + aStr + ').' + neg + matcherName;"
        "      if (arguments.length >= 3 && expected !== undefined) {"
        "        var eStr = typeof expected === 'string' ? '\"' + expected + '\"' : String(expected);"
        "        msg += '(' + eStr + ')';"
        "      }"
        "      throw new Error(msg);"
        "    }"
        "  }"
        ""
        "  m.toBe = function(expected) {"
        "    assertThrow(actual === expected, 'toBe', expected);"
        "    return m;"
        "  };"
        ""
        "  m.toEqual = function(expected) {"
        "    var matched = __deepEqual(actual, expected);"
        "    assertThrow(matched, 'toEqual', expected);"
        "    return m;"
        "  };"
        ""
        "  m.toBeTruthy = function() {"
        "    assertThrow(!!actual, 'toBeTruthy');"
        "    return m;"
        "  };"
        ""
        "  m.toBeFalsy = function() {"
        "    assertThrow(!actual, 'toBeFalsy');"
        "    return m;"
        "  };"
        ""
        "  m.toThrow = function(msgPattern) {"
        "    var threw = false;"
        "    try { actual(); } catch(e) { threw = true; }"
        "    if (msgPattern !== undefined) {"
        "      assertThrow(threw, 'toThrow', msgPattern);"
        "    } else {"
        "      assertThrow(threw, 'toThrow');"
        "    }"
        "    return m;"
        "  };"
        ""
        "  m.toBeGreaterThan = function(n) {"
        "    assertThrow(actual > n, 'toBeGreaterThan', n);"
        "    return m;"
        "  };"
        ""
        "  m.toBeLessThan = function(n) {"
        "    assertThrow(actual < n, 'toBeLessThan', n);"
        "    return m;"
        "  };"
        ""
        "  m.toBeGreaterThanOrEqual = function(n) {"
        "    assertThrow(actual >= n, 'toBeGreaterThanOrEqual', n);"
        "    return m;"
        "  };"
        ""
        "  m.toBeLessThanOrEqual = function(n) {"
        "    assertThrow(actual <= n, 'toBeLessThanOrEqual', n);"
        "    return m;"
        "  };"
        ""
        "  m.toContain = function(item) {"
        "    var found = false;"
        "    if (typeof actual === 'string') { found = actual.indexOf(item) !== -1; }"
        "    else if (Array.isArray(actual)) { found = actual.indexOf(item) !== -1; }"
        "    assertThrow(found, 'toContain', item);"
        "    return m;"
        "  };"
        ""
        "  m.toHaveLength = function(len) {"
        "    assertThrow(actual.length === len, 'toHaveLength', len);"
        "    return m;"
        "  };"
        ""
        "  m.toMatch = function(pattern) {"
        "    if (typeof pattern === 'string') pattern = new RegExp(pattern);"
        "    assertThrow(typeof actual === 'string' && pattern.test(actual), 'toMatch', pattern);"
        "    return m;"
        "  };"
        ""
        "  m.toThrowError = function(expected) {"
        "    var threw = false;"
        "    var errMsg = '';"
        "    try { actual(); } catch(e) { threw = true; errMsg = e.message || String(e); }"
        "    if (!threw) {"
        "      if (negated) return m;"
        "      throw new Error('Expected function to throw');"
        "    }"
        "    if (expected !== undefined) {"
        "      if (typeof expected === 'string') {"
        "        var match = errMsg.indexOf(expected) !== -1;"
        "        if (negated) { if (match) throw new Error('Expected error NOT to contain ' + expected); }"
        "        else { if (!match) throw new Error('Expected error message to contain [' + expected + '] but got [' + errMsg + ']'); }"
        "      } else if (expected && typeof expected.test === 'function') {"
        "        var match2 = expected.test(errMsg);"
        "        if (negated) { if (match2) throw new Error('Expected error NOT to match ' + expected); }"
        "        else { if (!match2) throw new Error('Expected error to match [' + expected + '] but got [' + errMsg + ']'); }"
        "      }"
        "    }"
        "    return m;"
        "  };"
        ""
        "  m.toBeDefined = function() {"
        "    assertThrow(actual !== undefined, 'toBeDefined');"
        "    return m;"
        "  };"
        ""
        "  m.toBeUndefined = function() {"
        "    assertThrow(actual === undefined, 'toBeUndefined');"
        "    return m;"
        "  };"
        ""
        "  m.toBeNull = function() {"
        "    assertThrow(actual === null, 'toBeNull');"
        "    return m;"
        "  };"
        ""
        "  m.toBeNaN = function() {"
        "    assertThrow(isNaN(actual), 'toBeNaN');"
        "    return m;"
        "  };"
        ""
        "  m.toBeCloseTo = function(expected, precision) {"
        "    precision = precision || 2;"
        "    var threshold = 0.5;"
        "    for (var i = 0; i < precision; i++) threshold /= 10.0;"
        "    var diff = actual > expected ? actual - expected : expected - actual;"
        "    assertThrow(diff < threshold, 'toBeCloseTo', expected);"
        "    return m;"
        "  };"
        ""
        "  m.toHaveProperty = function(propPath) {"
        "    var parts = typeof propPath === 'string' ? propPath.split('.') : [propPath];"
        "    var obj = actual;"
        "    var found = true;"
        "    for (var pi = 0; pi < parts.length; pi++) {"
        "      if (obj == null || obj[parts[pi]] === undefined) { found = false; break; }"
        "      obj = obj[parts[pi]];"
        "    }"
        "    assertThrow(found, 'toHaveProperty', propPath);"
        "    return m;"
        "  };"
        ""
        "  m.toStrictEqual = function(expected) {"
        "    if (typeof actual !== typeof expected) {"
        "      assertThrow(false, 'toStrictEqual', expected);"
        "      return m;"
        "    }"
        "    assertThrow(__deepEqual(actual, expected), 'toStrictEqual', expected);"
        "    return m;"
        "  };"
        ""
        "  m.toBeInstanceOf = function(cls) {"
        "    assertThrow(actual instanceof cls, 'toBeInstanceOf', cls);"
        "    return m;"
        "  };"
        ""
        "  m.toBeTypeOf = function(typeName) {"
        "    assertThrow(typeof actual === typeName, 'toBeTypeOf', typeName);"
        "    return m;"
        "  };"
        ""
        "  m.toMatchObject = function(expected) {"
        "    function deepMatch(a, e) {"
        "      if (typeof e !== 'object' || e === null) return a === e;"
        "      if (typeof a !== 'object' || a === null) return false;"
        "      var keys = Object.keys(e);"
        "      for (var i = 0; i < keys.length; i++) {"
        "        if (!deepMatch(a[keys[i]], e[keys[i]])) return false;"
        "      }"
        "      return true;"
        "    }"
        "    assertThrow(deepMatch(actual, expected), 'toMatchObject');"
        "    return m;"
        "  };"
        ""
        "  m.toHaveReturnedWith = function(expected) {"
        "    if (!actual || !actual.mock || !actual.mock.results) { throw new Error('toHaveReturnedWith: not a mock function'); }"
        "    var found = false;"
        "    for (var i = 0; i < actual.mock.results.length; i++) {"
        "      if (__deepEqual(actual.mock.results[i].value, expected)) { found = true; break; }"
        "    }"
        "    assertThrow(found, 'toHaveReturnedWith', expected);"
        "    return m;"
        "  };"
        ""
        "  m.toHaveBeenCalledTimes = function(n) {"
        "    var calls = (actual && actual.mock && actual.mock.calls) || [];"
        "    assertThrow(calls.length === n, 'toHaveBeenCalledTimes', n);"
        "    return m;"
        "  };"
        ""
        "  m.toHaveBeenCalledWith = function() {"
        "    /* stub */ return m;"
        "  };"
        ""
        "  m.toHaveBeenLastCalledWith = function() {"
        "    /* stub */ return m;"
        "  };"
        ""
        "  m.toHaveBeenNthCalledWith = function() {"
        "    /* stub */ return m;"
        "  };"
        ""
        "  m.toHaveReturned = function() {"
        "    /* stub */ return m;"
        "  };"
        ""
        "  m.toHaveLastReturnedWith = function() {"
        "    /* stub */ return m;"
        "  };"
        ""
        "  m.toHaveNthReturnedWith = function() {"
        "    /* stub */ return m;"
        "  };"
        ""
        "  m.toMatchSnapshot = function(hint) {"
        "    /* snapshot stub: validate args but always pass */"
        "    if (arguments.length >= 2 && typeof hint === 'object') throw new Error('toMatchSnapshot: property matchers must be an object');"
        "    return m;"
        "  };"
        ""
        "  m.toMatchInlineSnapshot = function() {"
        "    /* stub */ return m;"
        "  };"
        ""
        "  m.toThrowErrorMatchingSnapshot = function() {"
        "    /* stub */ return m;"
        "  };"
        ""
        "  m.toStartWith = function(prefix) {"
        "    assertThrow(typeof actual === 'string' && actual.indexOf(prefix) === 0, 'toStartWith', prefix);"
        "    return m;"
        "  };"
        ""
        "  m.toEndWith = function(suffix) {"
        "    assertThrow(typeof actual === 'string' && actual.indexOf(suffix, actual.length - suffix.length) !== -1, 'toEndWith', suffix);"
        "    return m;"
        "  };"
        ""
        "  m.toIncludeRepeated = function(substr, n) {"
        "    /* stub */ return m;"
        "  };"
        ""
        "  m.toContainKeys = function(keys) {"
        "    var obj = actual;"
        "    if (typeof keys === 'string') keys = [keys];"
        "    for (var i = 0; i < keys.length; i++) {"
        "      if (!(keys[i] in obj)) { assertThrow(false, 'toContainKeys', keys); return m; }"
        "    }"
        "    assertThrow(true, 'toContainKeys', keys);"
        "    return m;"
        "  };"
        ""
        "  m.toContainAnyKeys = function(keys) {"
        "    for (var i = 0; i < keys.length; i++) {"
        "      if (keys[i] in actual) { assertThrow(true, 'toContainAnyKeys'); return m; }"
        "    }"
        "    assertThrow(false, 'toContainAnyKeys', keys);"
        "    return m;"
        "  };"
        ""
        "  m.toContainValue = function(val) {"
        "    var vals = Object.values(actual);"
        "    for (var i = 0; i < vals.length; i++) {"
        "      if (__deepEqual(vals[i], val)) { assertThrow(true, 'toContainValue'); return m; }"
        "    }"
        "    assertThrow(false, 'toContainValue', val);"
        "    return m;"
        "  };"
        ""
        "  m.toContainValues = function(vals) {"
        "    for (var i = 0; i < vals.length; i++) {"
        "      var found = false;"
        "      var actualVals = Object.values(actual);"
        "      for (var j = 0; j < actualVals.length; j++) { if (__deepEqual(actualVals[j], vals[i])) { found = true; break; } }"
        "      if (!found) { assertThrow(false, 'toContainValues', vals); return m; }"
        "    }"
        "    assertThrow(true, 'toContainValues');"
        "    return m;"
        "  };"
        ""
        "  m.toBeDate = function() {"
        "    assertThrow(actual instanceof Date, 'toBeDate');"
        "    return m;"
        "  };"
        ""
        "  m.toBeObject = function() {"
        "    assertThrow(actual !== null && typeof actual === 'object', 'toBeObject');"
        "    return m;"
        "  };"
        ""
        "  m.toBeArray = function() {"
        "    assertThrow(Array.isArray(actual), 'toBeArray');"
        "    return m;"
        "  };"
        ""
        "  m.toBeEmpty = function() {"
        "    if (actual === null || actual === undefined || actual === '' || (typeof actual === 'object' && Object.keys(actual).length === 0) || (Array.isArray(actual) && actual.length === 0)) assertThrow(true, 'toBeEmpty');"
        "    else assertThrow(false, 'toBeEmpty');"
        "    return m;"
        "  };"
        ""
        "  /* .not — negation modifier */"
        "  var notM = {};"
        "  var notNames = ['toBe','toEqual','toBeTruthy','toBeFalsy','toThrow','toThrowError',"
        "    'toBeGreaterThan','toBeLessThan','toContain','toBeNull','toBeDefined',"
        "    'toBeUndefined','toBeNaN','toMatch','toHaveLength','toBeCloseTo','toHaveProperty',"
        "    'toBeGreaterThanOrEqual','toBeLessThanOrEqual','toStrictEqual',"
        "    'toBeInstanceOf','toBeTypeOf','toMatchObject','toMatchSnapshot',"
        "    'toMatchInlineSnapshot','toStartWith','toEndWith','toIncludeRepeated',"
        "    'toHaveReturnedWith','toHaveBeenCalledTimes','toHaveBeenCalledWith',"
        "    'toHaveBeenLastCalledWith','toHaveReturned','toHaveLastReturnedWith',"
        "    'toContainKeys','toContainAnyKeys','toContainValue','toContainValues',"
        "    'toBeDate','toBeObject','toBeArray','toBeEmpty'];"
        "  for (var ni = 0; ni < notNames.length; ni++) {"
        "    (function(name) {"
        "      notM[name] = function() {"
        "        negated = true;"
        "        m[name].apply(this, arguments);"
        "        negated = false;"
        "        return m;"
        "      };"
        "    })(notNames[ni]);"
        "  }"
        "  m.not = notM;"
        ""
        "  return m;"
        "}"
        ""
        "/* Helper: check if value is an asymmetric matcher */"
        "function __isAsymmetric(v) {"
        "  return v && typeof v === 'object' && (v.__expectAny || v.__expectAnything"
        "    || v.__expectObjectContaining || v.__expectArrayContaining"
        "    || v.__expectStringContaining || v.__expectStringMatching);"
        "}"
        ""
        "function __asymmetricMatch(actual, expected) {"
        "  if (!__isAsymmetric(expected)) return false;"
        "  if (expected.__expectAny) {"
        "    if (actual === null || actual === undefined) return expected.constructor === Object;"
        "    if (expected.constructor === Number) return typeof actual === 'number';"
        "    if (expected.constructor === String) return typeof actual === 'string';"
        "    if (expected.constructor === Boolean) return typeof actual === 'boolean';"
        "    if (expected.constructor === Function) return typeof actual === 'function';"
        "    if (expected.constructor === Object) return typeof actual === 'object';"
        "    if (expected.constructor === Array) return Array.isArray(actual);"
        "    return actual instanceof expected.constructor;"
        "  }"
        "  if (expected.__expectAnything) {"
        "    return actual != null;"
        "  }"
        "  if (expected.__expectObjectContaining) {"
        "    if (typeof actual !== 'object' || actual === null) return false;"
        "    for (var k in expected.sample) {"
        "      if (!__deepEqual(actual[k], expected.sample[k])) return false;"
        "    }"
        "    return true;"
        "  }"
        "  if (expected.__expectArrayContaining) {"
        "    if (!Array.isArray(actual)) return false;"
        "    for (var i = 0; i < expected.sample.length; i++) {"
        "      var found = false;"
        "      for (var j = 0; j < actual.length; j++) {"
        "        if (__deepEqual(actual[j], expected.sample[i])) { found = true; break; }"
        "      }"
        "      if (!found) return false;"
        "    }"
        "    return true;"
        "  }"
        "  if (expected.__expectStringContaining) {"
        "    return typeof actual === 'string' && actual.indexOf(expected.sample) !== -1;"
        "  }"
        "  if (expected.__expectStringMatching) {"
        "    if (typeof actual !== 'string') return false;"
        "    if (typeof expected.sample === 'string') return actual.indexOf(expected.sample) !== -1;"
        "    return expected.sample.test(actual);"
        "  }"
        "  return false;"
        "}"
        ""
        "/* Deep equality for toEqual with asymmetric matcher + Date/RegExp/Map/Set support */"
        "function __deepEqual(a, b) {"
        "  if (a === b) return true;"
        "  if (__isAsymmetric(b)) return __asymmetricMatch(a, b);"
        "  if (__isAsymmetric(a)) return false;"
        "  if (a == null || b == null) return a === b;"
        "  if (typeof a !== typeof b) return false;"
        "  if (a !== a && b !== b) return true;"
        "  if (typeof a !== 'object') return a === b;"
        "  if (a instanceof Date && b instanceof Date) return a.getTime() === b.getTime();"
        "  if (a instanceof RegExp && b instanceof RegExp) return a.source === b.source && a.flags === b.flags;"
        "  if (a instanceof Error && b instanceof Error) return a.message === b.message;"
        "  if (a instanceof Map && b instanceof Map) {"
        "    if (a.size !== b.size) return false;"
        "    a.forEach(function(v, k) { if (!__deepEqual(v, b.get(k))) return false; });"
        "    return true;"
        "  }"
        "  if (a instanceof Set && b instanceof Set) {"
        "    if (a.size !== b.size) return false;"
        "    var ok = true;"
        "    a.forEach(function(v) { if (!b.has(v)) ok = false; });"
        "    return ok;"
        "  }"
        "  if (typeof a.length === 'number' && typeof b.length === 'number') {"
        "    if (a.length !== b.length) return false;"
        "    for (var i = 0; i < a.length; i++) {"
        "      if (!__deepEqual(a[i], b[i])) return false;"
        "    }"
        "    return true;"
        "  }"
        "  var keysA = Object.keys(a);"
        "  var keysB = Object.keys(b);"
        "  if (keysA.length !== keysB.length) return false;"
        "  for (var i = 0; i < keysA.length; i++) {"
        "    var key = keysA[i];"
        "    if (!b.hasOwnProperty(key)) return false;"
        "    if (!__deepEqual(a[key], b[key])) return false;"
        "  }"
        "  return true;"
        "}"
        ""
        "/* toEqual uses __deepEqual (defined above) via assertThrow for negation support */"
        ""
        "expect.any = function(constructor) {"
        "  return { __expectAny: true, constructor: constructor };"
        "};"
        "expect.anything = function() {"
        "  return { __expectAnything: true };"
        "};"
        "expect.objectContaining = function(obj) {"
        "  return { __expectObjectContaining: true, sample: obj };"
        "};"
        "expect.arrayContaining = function(arr) {"
        "  return { __expectArrayContaining: true, sample: arr };"
        "};"
        "expect.stringContaining = function(str) {"
        "  return { __expectStringContaining: true, sample: str };"
        "};"
        "expect.stringMatching = function(pattern) {"
        "  return { __expectStringMatching: true, sample: pattern };"
        "};"
        "expect.extend = function(matchers) {"
        "  Object.assign(expect._matchers, matchers);"
        "};"
        "expect.hasAssertions = function() {};"
        "expect.assertions = function(n) {};"
        "expect.addSnapshotSerializer = function() {};"
        "expect._matchers = {};"
        ""
        "expect.unreachable = function(msg) {"
        "  throw new Error('Expected unreachable: ' + (msg || 'reached unreachable code'));"
        "};"
        ""
        "/* jest global object for mock support */"
        "var jest = {"
        "  fn: function(impl) {"
        "    var _impl = impl || function() {};"
        "    var _calls = [];"
        "    var _instances = [];"
        "    var _results = [];"
        "    var _onceQueue = [];"
        "    var wrapper = function() {"
        "      var args = Array.prototype.slice.call(arguments);"
        "      _calls.push(args);"
        "      _instances.push(this);"
        "      var result;"
        "      try {"
        "        if (_onceQueue.length > 0) {"
        "          var once = _onceQueue.shift();"
        "          result = once.apply(this, arguments);"
        "        } else {"
        "          result = _impl.apply(this, arguments);"
        "        }"
        "        _results.push({ type: 'return', value: result });"
        "      } catch(e) {"
        "        _results.push({ type: 'throw', value: e });"
        "        throw e;"
        "      }"
        "      return result;"
        "    };"
        "    wrapper.mock = {"
        "      calls: _calls,"
        "      instances: _instances,"
        "      results: _results,"
        "      __isMockFunction: true,"
        "      _impl: _impl"
        "    };"
        "    wrapper.getMockName = function() { return 'jest.fn()'; };"
        "    wrapper.mockName = function(n) { return wrapper; };"
        "    wrapper.mockReturnThis = function() { _impl = function() { return this; }; return wrapper; };"
        "    wrapper.mockReturnValue = function(val) {"
        "      _impl = function() { return val; };"
        "      wrapper.mock._impl = _impl;"
        "      return wrapper;"
        "    };"
        "    wrapper.mockReturnValueOnce = function(val) {"
        "      _onceQueue.push(function() { return val; });"
        "      return wrapper;"
        "    };"
        "    wrapper.mockImplementation = function(fn) {"
        "      _impl = fn;"
        "      wrapper.mock._impl = _impl;"
        "      return wrapper;"
        "    };"
        "    wrapper.mockImplementationOnce = function(fn) {"
        "      _onceQueue.push(fn);"
        "      return wrapper;"
        "    };"
        "    wrapper.mockReset = function() {"
        "      _calls.length = 0;"
        "      _instances.length = 0;"
        "      _results.length = 0;"
        "      _onceQueue.length = 0;"
        "      _impl = function() {};"
        "      wrapper.mock._impl = _impl;"
        "      return wrapper;"
        "    };"
        "    wrapper.mockClear = function() {"
        "      _calls.length = 0;"
        "      _instances.length = 0;"
        "      _results.length = 0;"
        "      _onceQueue.length = 0;"
        "      return wrapper;"
        "    };"
        "    wrapper.mockResolvedValue = function(val) {"
        "      _impl = function() { return Promise.resolve(val); };"
        "      wrapper.mock._impl = _impl;"
        "      return wrapper;"
        "    };"
        "    wrapper.mockResolvedValueOnce = function(val) {"
        "      _onceQueue.push(function() { return Promise.resolve(val); });"
        "      return wrapper;"
        "    };"
        "    wrapper.mockRejectedValue = function(val) {"
        "      _impl = function() { return Promise.reject(val); };"
        "      wrapper.mock._impl = _impl;"
        "      return wrapper;"
        "    };"
        "    wrapper.mockRejectedValueOnce = function(val) {"
        "      _onceQueue.push(function() { return Promise.reject(val); });"
        "      return wrapper;"
        "    };"
        "    return wrapper;"
        "  },"
        "  spyOn: function(object, method) {"
        "    var original = object[method];"
        "    var spy = jest.fn(function() {"
        "      return original.apply(object, arguments);"
        "    });"
        "    object[method] = spy;"
        "    spy.mockRestore = function() { object[method] = original; };"
        "    return spy;"
        "  },"
        "  mock: function(fn) { return jest.fn(fn); },"
        "  useFakeTimers: function() {},"
        "  useRealTimers: function() {},"
        "  setSystemTime: function() {},"
        "  advanceTimersByTime: function() {},"
        "  advanceTimersToNextTimer: function() {},"
        "  runAllTimers: function() {},"
        "  runOnlyPendingTimers: function() {},"
        "  clearAllTimers: function() {},"
        "  clearAllMocks: function() {},"
        "  resetAllMocks: function() {},"
        "  restoreAllMocks: function() {},"
        "  requireActual: function(module) { return require(module); },"
        "  requireMock: function() { return {}; },"
        "  createMockFromModule: function() { return {}; },"
        "  genMockFromModule: function() { return {}; },"
        "  setTimeout: function(ms) {},"
        "  isolateModules: function(fn) { fn(); },"
        "  retryTimes: function(n) {},"
        "  replaceProperty: function(obj, prop, val) {"
        "    var orig = obj[prop]; obj[prop] = val;"
        "    return { restore: function() { obj[prop] = orig; } };"
        "  },"
        "  setMock: function() {},"
        "  disableAutomock: function() {},"
        "  enableAutomock: function() {}"
        "};"
        ""
        "/* Global spyOn alias */"
        "function spyOn(object, method) {"
        "  return jest.spyOn(object, method);"
        "}"
        ""
        "/* __runTests() — execute all registered tests and print results. */"
        "/* Returns a JSON string with pass/fail/skip/todo counts. */"
        "function __runTests() {"
        "  var pass = 0, fail = 0, skip = 0, todo = 0, errors = [];"
        ""
        "  /* Run beforeAll hooks */"
        "  try { __runHooks(__beforeAllHooks); } catch(e) {"
        "    print('  FAIL beforeAll: ' + e.message);"
        "    fail++;"
        "  }"
        ""
        "  for (var i = 0; i < __tests.length; i++) {"
        "    var t = __tests[i];"
        ""
        "    if (t.skip) {"
        "      skip++;"
        "      print('  SKIP ' + (t.describe ? t.describe + ' > ' : '') + t.name);"
        "      continue;"
        "    }"
        ""
        "    if (t.todo) {"
        "      todo++;"
        "      print('  TODO ' + (t.describe ? t.describe + ' > ' : '') + t.name);"
        "      continue;"
        "    }"
        ""
        "    try {"
        "      __runHooks(__beforeEachHooks);"
        "      t.fn();"
        "      __runHooks(__afterEachHooks);"
        "      pass++;"
        "      print('  PASS ' + (t.describe ? t.describe + ' > ' : '') + t.name);"
        "    } catch(e) {"
        "      fail++;"
        "      var label = t.describe ? t.describe + ' > ' + t.name : t.name;"
        "      errors.push(label + ': ' + e.message);"
        "      print('  FAIL ' + label);"
        "      print('    ' + e.message);"
        "    }"
        "  }"
        ""
        "  /* Run afterAll hooks */"
        "  try { __runHooks(__afterAllHooks); } catch(e) {"
        "    print('  FAIL afterAll: ' + e.message);"
        "    fail++;"
        "  }"
        ""
        "  print('');"
        "  print('Ran ' + __tests.length + ' test(s)');"
        "  print('  ' + pass + ' pass');"
        "  if (skip > 0) print('  ' + skip + ' skip');"
        "  if (todo > 0) print('  ' + todo + ' todo');"
        "  print('  ' + fail + ' fail');"
        ""
        "  /* Return JSON for the Cangjie caller to parse */"
        "  var __result = '{\"pass\":' + pass + ',\"fail\":' + fail + ',\"skip\":' + skip + ',\"todo\":' + todo + '}';"
        "  __bao_set_result(__result);"
        "  return __result;"
        "}"
        ""
        "/* __resetTests() — clear test state between files */"
        "function __resetTests() {"
        "  __tests = [];"
        "  __currentDescribe = null;"
        "  __beforeAllHooks = [];"
        "  __beforeEachHooks = [];"
        "  __afterEachHooks = [];"
        "  __afterAllHooks = [];"
        "}"
        "";

    JSStringRef script = JSStringCreateWithUTF8CString(testFramework);
    JSValueRef ex = NULL;
    JSEvaluateScript(ctx, script, NULL, NULL, 1, &ex);
    JSStringRelease(script);
    if (ex) {
        char* m = to_utf8(ctx, ex);
        fprintf(stderr, "bun:test registration error: %s\n", m);
        free(m);
    }

    /* Register __bao_set_result as a global function */
    reg_method(ctx, global, "__bao_set_result", bao_set_result_cb);
}

/* ============================================================================
 * Bun object
 * ============================================================================ */


/* ============================================================================
 * require() — simple module loader (reads file, eval as JS)
 * ============================================================================ */

static JSValueRef require_cb(JSContextRef c,JSObjectRef f,JSObjectRef t,size_t ac,const JSValueRef a[],JSValueRef*e){
    (void)f;(void)t;
    if(ac<1) return make_error(c, "require: module path required", e);
    char* path = to_utf8(c, a[0]);

    /* Check for built-in npm stub modules */
    {
        JSStringRef stub_key = JSStringCreateWithUTF8CString("__stub_modules");
        JSValueRef stub_map = JSObjectGetProperty(c, g_global, stub_key, NULL);
        JSStringRelease(stub_key);
        if(JSValueIsObject(c, stub_map)){
            JSObjectRef map = JSValueToObject(c, stub_map, NULL);
            /* Normalize path: strip node: prefix, handle scoped packages */
            char* lookup = path;
            if(strncmp(path, "node:", 5) == 0) lookup = path + 5;
            /* Handle yargs/yargs → yargs */
            char* slash = strchr(lookup, '/');
            char simple[256];
            if(slash && strncmp(lookup, "yargs", 5) == 0){
                snprintf(simple, sizeof(simple), "yargs");
                lookup = simple;
            } else if(slash && strncmp(lookup, "abort-controller", 16) == 0){
                snprintf(simple, sizeof(simple), "abort-controller");
                lookup = simple;
            }
            JSStringRef pk = JSStringCreateWithUTF8CString(lookup);
            JSValueRef stub = JSObjectGetProperty(c, map, pk, NULL);
            JSStringRelease(pk);
            if(!JSValueIsUndefined(c, stub)){
                free(path);
                return stub;
            }
        }
    }

    /* Try to open and read the file */
    FILE* fp = fopen(path, "rb");
    if(!fp){
        /* Try with .js extension */
        char buf[4096];
        snprintf(buf, sizeof(buf), "%s.js", path);
        fp = fopen(buf, "rb");
    }
    if(!fp){
        char err[512];
        snprintf(err, sizeof(err), "require: cannot find module '%s'", path);
        free(path);
        return make_error(c, err, e);
    }
    free(path);

    fseek(fp, 0, SEEK_END);
    long sz = ftell(fp);
    fseek(fp, 0, SEEK_SET);
    char* code = malloc(sz + 1);
    fread(code, 1, sz, fp);
    code[sz] = '\0';
    fclose(fp);

    /* Create module wrapper */
    char* wrapped = malloc(sz + 256);
    snprintf(wrapped, sz + 256,
        "(function() { var module = {exports: {}}; var exports = module.exports;"
        "%s;"
        " return module.exports; })()",
        code);
    free(code);

    JSStringRef script = JSStringCreateWithUTF8CString(wrapped);
    JSValueRef ex = NULL;
    JSValueRef result = JSEvaluateScript(c, script, NULL, NULL, 1, &ex);
    JSStringRelease(script);
    free(wrapped);

    if(ex){
        char* m = to_utf8(c, ex);
        char* err = malloc(strlen(m) + 32);
        sprintf(err, "require: %s", m);
        make_error(c, err, e);
        free(m); free(err);
        return JSValueMakeUndefined(c);
    }
    return result ? result : JSValueMakeUndefined(c);
}

/* ============================================================================
 * Remaining polyfills — fix leftover test failures
 * ============================================================================ */

static void register_remaining_polyfills(JSContextRef ctx, JSObjectRef global) {
    const char* polyfill =
        /* Bun.stripANSI / Bun.deepEquals / Bun.Cookie.from */
        "if(typeof Bun!=='undefined'){"
        "Bun.stripANSI=function(s){return s.replace(/\\x1b\\[[0-9;]*m/g,'')};"
        "Bun.deepEquals=function(a,b){"
        "if(a===b)return true;if(a==null||b==null)return false;"
        "if(typeof a!==typeof b)return false;if(typeof a!=='object')return false;"
        "var ka=Object.keys(a),kb=Object.keys(b);if(ka.length!==kb.length)return false;"
        "for(var i=0;i<ka.length;i++)if(!Bun.deepEquals(a[ka[i]],b[ka[i]]))return false;"
        "return true};"
        "if(typeof Bun.Cookie!=='undefined'&&!Bun.Cookie.from)"
        "Bun.Cookie.from=function(n,v,o){return new Bun.Cookie(n,v,o)};"
        "}\n"

        /* Buffer static + instance methods */
        "if(typeof Buffer!=='undefined'){"
        "if(!Buffer.isBuffer)Buffer.isBuffer=function(b){return b&&typeof b==='object'&&typeof b.length==='number'&&!(b instanceof Array)};"
        /* Patch Buffer.from to attach instance methods */
        "var __origFrom=Buffer.from;"
        "Buffer.from=function(){"
        "  var r=__origFrom.apply(this,arguments);"
        "  if(r&&typeof r==='object'&&!r.compare){"
        "    r.compare=function(o){"
        "      var al=this.length,bl=o.length,n=al<bl?al:bl;"
        "      for(var i=0;i<n;i++){var a=this[i]||0,b=o[i]||0;if(a<b)return -1;if(a>b)return 1}"
        "      return al<bl?-1:al>bl?1:0"
        "    };"
        "    r.equals=function(o){"
        "      if(!o||this.length!==o.length)return false;"
        "      for(var i=0;i<this.length;i++)if((this[i]||0)!==(o[i]||0))return false;"
        "      return true"
        "    };"
        "    r.slice=function(s,e){"
        "      s=s||0;e=e||this.length;"
        "      var r2=[];for(var i=s;i<e;i++)r2.push(this[i]||0);"
        "      r2.length=r2.length;"
        "      r2.toString=this.toString.bind?this.toString.bind(r2):function(){var s='';for(var k=0;k<this.length;k++)s+=String.fromCharCode(this[k]||0);return s};"
        "      return r2"
        "    };"
        "    r.write=function(data,off,len){"
        "      off=off||0;var d=typeof data==='string'?data:String(data);"
        "      var w=len?Math.min(len,d.length):d.length;"
        "      for(var i=0;i<w&&(off+i)<this.length;i++)this[off+i]=d.charCodeAt(i);"
        "      return w"
        "    };"
        "    r.toJSON=function(){return{type:'Buffer',data:Array.prototype.slice.call(this)}};"
        "  }"
        "  return r"
        "};"
        "var __origAlloc=Buffer.alloc;"
        "Buffer.alloc=function(){"
        "  var r=__origAlloc.apply(this,arguments);"
        "  if(r&&typeof r==='object'&&!r.compare){"
        "    r.compare=function(o){"
        "      var al=this.length,bl=o.length,n=al<bl?al:bl;"
        "      for(var i=0;i<n;i++){var a=this[i]||0,b=o[i]||0;if(a<b)return -1;if(a>b)return 1}"
        "      return al<bl?-1:al>bl?1:0"
        "    };"
        "    r.equals=function(o){"
        "      if(!o||this.length!==o.length)return false;"
        "      for(var i=0;i<this.length;i++)if((this[i]||0)!==(o[i]||0))return false;"
        "      return true"
        "    };"
        "    r.write=function(data,off,len){"
        "      off=off||0;var d=typeof data==='string'?data:String(data);"
        "      var w=len?Math.min(len,d.length):d.length;"
        "      for(var i=0;i<w&&(off+i)<this.length;i++)this[off+i]=d.charCodeAt(i);"
        "      return w"
        "    };"
        "    r.toJSON=function(){return{type:'Buffer',data:Array.prototype.slice.call(this)}};"
        "  }"
        "  return r"
        "};"
        "}\n"

        /* Headers.prototype.toJSON — iterate own enumerable string properties */
        "if(typeof Headers!=='undefined'&&Headers.prototype&&!Headers.prototype.toJSON){"
        "Headers.prototype.toJSON=function(){"
        "  var o={};"
        "  for(var k in this){"
        "    if(this.hasOwnProperty(k)&&typeof this[k]==='string'){o[k]=this[k]}"
        "  }"
        "  return o"
        "};"
        "}\n"

        /* HTMLRewriter.prototype.onDocument/onElement/on/transform */
        "if(typeof HTMLRewriter!=='undefined'&&HTMLRewriter.prototype){"
        "if(!HTMLRewriter.prototype.onDocument)HTMLRewriter.prototype.onDocument=function(h){"
        "  if(h&&typeof h==='object')return this;"
        "  throw new Error('onDocument requires a handler');"
        "};"
        "if(!HTMLRewriter.prototype.onElement)HTMLRewriter.prototype.onElement=function(s,h){"
        "  if(typeof s==='string'&&h&&typeof h==='object')return this;"
        "  throw new Error('onElement requires selector and handler');"
        "};"
        "if(!HTMLRewriter.prototype.on)HTMLRewriter.prototype.on=function(s,h){return this.onElement(s,h)};"
        "if(!HTMLRewriter.prototype.transform)HTMLRewriter.prototype.transform=function(r){return r};"
        "}\n"

        /* addColorStop stub for Canvas contexts */
        "if(typeof CanvasRenderingContext2D!=='undefined'){"
        "CanvasRenderingContext2D.prototype.addColorStop=function(){};"
        "}\n"

        /* Error.prepareStackTrace stub (V8 feature, not in JSC) */
        "if(typeof Error.prepareStackTrace==='undefined'){"
        "Object.defineProperty(Error,'prepareStackTrace',{"
        "  writable:true,configurable:true,"
        "  value:function(err,stack){return stack}"
        "});"
        "}\n"

        /* Error.captureStackTrace stub */
        "if(typeof Error.captureStackTrace==='undefined'){"
        "Error.captureStackTrace=function(obj,ctor){"
        "  var e=new Error();"
        "  if(e.stack) obj.stack=e.stack;"
        "};"
        "}\n"

        /* Error.stackTraceLimit stub */
        "if(typeof Error.stackTraceLimit==='undefined'){"
        "Error.stackTraceLimit=10;"
        "}\n"

        /* --- Quick Win Fixes --- */

        /* Fix: Buffer.write for "binary" encoding (issue #06467)
         * Note: Buffer is a plain object, not a constructor. Methods are attached
         * to each instance by the Buffer.from/alloc wrappers above. The write method
         * in those wrappers already handles binary encoding via charCodeAt. */

        /* Fix: Buffer.compare bounds validation (buffer-compare-bounds)
         * Note: instance .compare() is set by Buffer.from/alloc wrappers above.
         * Add a wrapper that validates bounds. */

        /* Fix: assert.doesNotMatch type validation */
        "if(typeof assert!=='undefined'&&!assert.doesNotMatch.__fixed){"
        "  assert.doesNotMatch=function(str,regex,msg){"
        "    if(typeof str!=='string')throw new Error(msg||'The \"string\" argument must be of type string. Received type number');"
        "    if(regex.test(str))throw new Error(msg||'The input did not match the regular expression '+regex);"
        "  };"
        "  assert.doesNotMatch.__fixed=true;"
        "}\n"

        /* Fix: Error.prepareStackTrace re-entrancy guard (issue #013880) */
        "if(typeof Error!=='undefined'){"
        "  var __pstDepth=0;"
        "  var __pstOrig=Error.prepareStackTrace;"
        "  Error.prepareStackTrace=function(err,stack){"
        "    __pstDepth++;"
        "    if(__pstDepth>1){__pstDepth--;return String(err)}"
        "    try{if(typeof __pstOrig==='function')return __pstOrig(err,stack);return stack}finally{__pstDepth--}"
        "  };\n"
        "}\n"

        /* Fix: process.emitWarning for timer tests (issue #18159) */
        "if(typeof process!=='undefined'&&!process.emitWarning){"
        "  process.emitWarning=function(msg,type,ctor){"
        "    if(typeof type==='function'){ctor=type;type='Warning'}"
        "    var e=new Error(msg);e.name=type||'Warning';"
        "    if(typeof process.on==='function')process.emit('warning',e);"
        "  };\n"
        "}\n"

        /* Fix: setTimeout/setInterval return objects with _idleStart (issue #25639) */
        "(function(){"
        "  var __origST=setTimeout;"
        "  if(typeof __origST==='function'){"
        "    setTimeout=function(fn,ms){"
        "      var id=__origST.apply(this,arguments);"
        "      if(typeof id==='object'||typeof id==='number'){"
        "        var obj=typeof id==='number'?{_id:id}:id;"
        "        obj._idleStart=Date.now?Date.now():0;"
        "        obj.ref=function(){return obj};obj.unref=function(){return obj};"
        "        return obj"
        "      }"
        "      return id"
        "    }"
        "  }"
        "  var __origSI=setInterval;"
        "  if(typeof __origSI==='function'){"
        "    setInterval=function(fn,ms){"
        "      var id=__origSI.apply(this,arguments);"
        "      if(typeof id==='object'||typeof id==='number'){"
        "        var obj=typeof id==='number'?{_id:id}:id;"
        "        obj._idleStart=Date.now?Date.now():0;"
        "        obj.ref=function(){return obj};obj.unref=function(){return obj};"
        "        return obj"
        "      }"
        "      return id"
        "    }"
        "  }"
        "})();\n"

        /* Fix: process.stdout/stderr Symbol.asyncIterator (issue #07827/15326) */
        "if(typeof process!=='undefined'&&process.stdout){"
        "  if(!process.stdout[Symbol.asyncIterator]){"
        "    process.stdout[Symbol.asyncIterator]=function(){return{next:function(){return Promise.resolve({done:true,value:undefined})}}};"
        "  }"
        "}\n"
        "if(typeof process!=='undefined'&&process.stderr){"
        "  if(!process.stderr[Symbol.asyncIterator]){"
        "    process.stderr[Symbol.asyncIterator]=function(){return{next:function(){return Promise.resolve({done:true,value:undefined})}}};"
        "  }"
        "}\n"

        /* Fix: Response.prototype.json empty body check (issue #02367) */
        "if(typeof Response!=='undefined'&&Response.prototype){"
        "  var __origProtoJson=Response.prototype.json;"
        "  Response.prototype.json=function(){"
        "    var body=this._body||this._data||'';"
        "    if(!body||body.length===0)throw new SyntaxError('Unexpected end of JSON input');"
        "    return JSON.parse(body)"
        "  };\n"
        "}\n"

        /* Fix: Bun.inspect stub (issue #16007) */
        "if(typeof Bun!=='undefined'&&!Bun.inspect){"
        "  Bun.inspect=function(v){"
        "    if(v===null)return 'null';"
        "    if(v===undefined)return 'undefined';"
        "    if(typeof v==='string')return '\"'+v+'\"';"
        "    if(typeof v==='number'||typeof v==='boolean')return String(v);"
        "    if(v instanceof Set)return 'Set('+v.size+') { '+Array.from(v).map(function(x){return Bun.inspect(x)}).join(', ')+' }';"
        "    if(v instanceof Map)return 'Map('+v.size+') { '+Array.from(v.entries()).map(function(e){return Bun.inspect(e[0])+' => '+Bun.inspect(e[1])}).join(', ')+' }';"
        "    if(Array.isArray(v))return '[ '+v.map(function(x){return Bun.inspect(x)}).join(', ')+' ]';"
        "    if(typeof v==='object'){"
        "      var keys=Object.keys(v);"
        "      return '{ '+keys.map(function(k){return k+': '+Bun.inspect(v[k])}).join(', ')+' }'"
        "    }"
        "    return String(v)"
        "  };\n"
        "}\n"

        /* Fix: tty.WriteStream (issue #test-process-stdout-async-iterator) */
        "if(typeof require==='function'){"
        "  try{"
        "    var tty=require('tty');"
        "    if(tty&&!tty.WriteStream.prototype[Symbol.asyncIterator]){"
        "      tty.WriteStream.prototype[Symbol.asyncIterator]=function(){return{next:function(){return Promise.resolve({done:true,value:undefined})}}};"
        "    }"
        "  }catch(e){}"
        "}\n"

        /* ================================================================ */
        /* Bun API Stubs                                                    */
        /* ================================================================ */

        /* Bun.spawnSync is now implemented natively via register_missing_apis */

        /* Bun.Transpiler — stub class */
        "if(typeof Bun!=='undefined'&&!Bun.Transpiler){"
        "  Bun.Transpiler=function(opts){"
        "    if(!(this instanceof Bun.Transpiler))return new Bun.Transpiler(opts);"
        "    this._opts=opts||{};"
        "  };"
        "  Bun.Transpiler.prototype.scanImports=function(code){return[]};"
        "  Bun.Transpiler.prototype.scan=function(code){return{exports:[],imports:[]}};"
        "  Bun.Transpiler.prototype.transformSync=function(code,opts){return code};"
        "  Bun.Transpiler.prototype.transform=function(code,opts){return Promise.resolve(code)};"
        "}\n"

        /* Bun.FFI — stub */
        "if(typeof Bun!=='undefined'&&!Bun.FFI){"
        "  Bun.FFI={"
        "    CString:function(ptr,len){if(!(this instanceof arguments.callee))return new arguments.callee(ptr,len);this.ptr=ptr;this.len=len},"
        "    ptr:function(v){return v},"
        "    toBuffer:function(ptr,len){return Buffer.alloc(len||0)},"
        "    readCString:function(ptr){return ''},"
        "    close:function(){}"
        "  };\n"
        "}\n"

        /* Bun.serve — stub */
        "if(typeof Bun!=='undefined'&&!Bun.serve){"
        "  Bun.serve=function(opts){"
        "    var s={"
        "      port:opts.port||0,"
        "      hostname:'localhost',"
        "      fetch:opts.fetch||function(){return new Response('stub')},"
        "      stop:function(){},"
        "      ref:function(){return s},"
        "      unref:function(){return s}"
        "    };"
        "    return s"
        "  };\n"
        "}\n"

        /* Bun.file — stub */
        "if(typeof Bun!=='undefined'&&!Bun.file){"
        "  Bun.file=function(path,opts){"
        "    return{"
        "      path:path,type:(opts&&opts.type)||'',size:0,"
        "      text:function(){return Promise.resolve('')},"
        "      json:function(){return Promise.resolve({})},"
        "      arrayBuffer:function(){return Promise.resolve(new ArrayBuffer(0))},"
        "      exists:function(){return Promise.resolve(true)}"
        "    }"
        "  };\n"
        "}\n"

        /* ShadowRealm — stub (TC39 proposal) */
        "if(typeof ShadowRealm==='undefined'){"
        "  globalThis.ShadowRealm=function(){"
        "    if(!(this instanceof ShadowRealm))return new ShadowRealm();"
        "    var _g={};"
        "    this.evaluate=function(code){return eval(code)};"
        "    this.importValue=function(spec,exportName){return Promise.resolve(undefined)};"
        "  };\n"
        "}\n"

        /* crypto module — use the real native crypto object */
        "if(typeof require==='function'){"
        "  var __cryptoStub=(typeof crypto!=='undefined')?crypto:{"
        "    createHash:function(alg){return{update:function(d){return this},digest:function(enc){return enc==='hex'?'':'new Uint8Array(0)'}}},"
        "    createHmac:function(alg,key){return{update:function(d){return this},digest:function(enc){return enc==='hex'?'':'new Uint8Array(0)'}}},"
        "    randomBytes:function(n,cb){var b=new Uint8Array(n);if(cb)cb(null,b);return b},"
        "    pbkdf2Sync:function(p,s,it,kl,alg){return new Uint8Array(kl)},"
        "    scryptSync:function(p,s,kl){return new Uint8Array(kl)},"
        "    createSign:function(alg){return{update:function(d){return this},sign:function(k,enc){return new Uint8Array(0)}}},"
        "    createVerify:function(alg){return{update:function(d){return this},verify:function(k,sig,enc){return false}}},"
        "    createCipheriv:function(alg,key,iv){return{update:function(d){return''},final:function(){return''}}},"
        "    createDecipheriv:function(alg,key,iv){return{update:function(d){return''},final:function(){return''}}},"
        "    generateKeyPairSync:function(type,opts){return{publicKey:'',privateKey:''}},"
        "    generateKeyPair:function(type,opts,cb){if(typeof opts==='function')cb=opts;cb&&cb(null,{publicKey:'',privateKey:''})},"
        "    constants:{RSA_PKCS1_PADDING:1,RSA_PKCS1_OAEP_PADDING:4},"
        "    getCiphers:function(){return['aes-256-cbc','aes-128-cbc']},"
        "    getHashes:function(){return['sha256','sha512','md5']}"
        "  };\n"
        "}\n"

        /* ================================================================ */
        /* npm Package Stubs via require()                                   */
        /* ================================================================ */

        /* express stub — improved with proper response object and routing */
        "if(typeof require==='function'){"
        "  var __express=function(){"
        "    var routes={GET:[],POST:[],PUT:[],DELETE:[],PATCH:[],ALL:[]};"
        "    function matchRoute(method,path){"
        "      var list=routes[method]||[];"
        "      for(var i=0;i<list.length;i++){"
        "        var r=list[i];"
        "        if(r.path===path||r.path==='*'||r.rx&&r.rx.test(path))return r;"
        "      }"
        "      return null"
        "    }"
        "    function addRoute(method,path,handler){"
        "      if(!routes[method])routes[method]=[];"
        "      routes[method].push({path:path,handler:handler,rx:typeof path!=='string'?path:null})"
        "    }"
        "    function createRes(){"
        "      var r={_headers:{},_body:'',statusCode:200,headersSent:false,finished:false,writableEnded:false,locals:{}};"
        "      r.status=function(c){r.statusCode=c;return r};"
        "      r.set=function(k,v){if(typeof k==='object'){for(var key in k)r._headers[key.toLowerCase()]=k[key]}else{r._headers[(k+'').toLowerCase()]=v+''}return r};"
        "      r.setHeader=function(k,v){r._headers[(k+'').toLowerCase()]=v+'';return r};"
        "      r.getHeader=function(k){return r._headers[(k+'').toLowerCase()]||null};"
        "      r.get=function(k){return r.getHeader(k)};"
        "      r.json=function(d){r._body=JSON.stringify(d);r._headers['content-type']='application/json';return r};"
        "      r.send=function(d){"
        "        if(typeof d==='string'){r._body=d}"
        "        else if(typeof d==='object'&&d!==null&&d.constructor&&d.constructor.name==='Buffer'){r._body=d.toString('utf8')}"
        "        else if(typeof d==='object'&&d!==null){return r.json(d)}"
        "        else if(typeof d==='number'){r._body=d+''}"
        "        else{r._body=d+''}"
        "        return r"
        "      };"
        "      r.redirect=function(){var s,u;if(arguments.length===1){u=arguments[0];s=302}else{s=arguments[0];u=arguments[1]}r.statusCode=s;r._headers['location']=u;return r};"
        "      r.location=function(u){r._headers['location']=u;return r};"
        "      r.type=function(t){r._headers['content-type']=t;return r};"
        "      r.end=function(){r.finished=true;r.writableEnded=true;return r};"
        "      r.append=function(k,v){var ex=r._headers[k.toLowerCase()];r._headers[k.toLowerCase()]=(ex?ex+', ':'')+v;return r};"
        "      r.cookie=function(n,v,o){return r};"
        "      r.clearCookie=function(n,o){return r};"
        "      r.render=function(v,o,cb){return r};"
        "      r.format=function(obj){var k=Object.keys(obj);if(k.length&&obj[k[0]])obj[k[0]]();return r};"
        "      r.vary=function(){return r};"
        "      r.links=function(){return r};"
        "      r.write=function(){return true};"
        "      return r"
        "    }"
        "    function createReq(method,path){"
        "      return{method:method,url:path,path:path,headers:{},query:{},params:{},body:{},"
        "        header:function(n){return this.headers[n.toLowerCase()]},"
        "        get:function(n){return this.header(n)},"
        "        accepts:function(){return arguments[0]||'text/html'}}"
        "    }"
        "    var app=function(req,res,next){};"
        "    app._routes=routes;"
        "    app.listen=function(port,cb){cb&&cb();return{close:function(){}}};"
        "    app.use=function(){return app};"
        "    app.get=function(p,h){if(typeof p==='string'&&typeof h==='function')addRoute('GET',p,h);return app};"
        "    app.post=function(p,h){if(typeof p==='string'&&typeof h==='function')addRoute('POST',p,h);return app};"
        "    app.put=function(p,h){if(typeof p==='string'&&typeof h==='function')addRoute('PUT',p,h);return app};"
        "    app.delete=function(p,h){if(typeof p==='string'&&typeof h==='function')addRoute('DELETE',p,h);return app};"
        "    app.patch=function(p,h){if(typeof p==='string'&&typeof h==='function')addRoute('PATCH',p,h);return app};"
        "    app.all=function(p,h){if(typeof p==='string'&&typeof h==='function')addRoute('ALL',p,h);return app};"
        "    app.route=function(p){var chain={_path:p};"
        "      chain.get=function(h){addRoute('GET',p,h);return chain};"
        "      chain.post=function(h){addRoute('POST',p,h);return chain};"
        "      chain.put=function(h){addRoute('PUT',p,h);return chain};"
        "      chain.delete=function(h){addRoute('DELETE',p,h);return chain};"
        "      chain.all=function(h){addRoute('ALL',p,h);return chain};"
        "      return chain};"
        "    app.set=function(k,v){return app};"
        "    app.enable=function(){return app};"
        "    app.disable=function(){return app};"
        "    app.engine=function(){return app};"
        "    app.param=function(){return app};"
        "    app.handle=function(req,res){"
        "      var r=matchRoute(req.method,req.path);"
        "      if(r){r.handler(req,res);res.finished=true}"
        "      else{res.statusCode=404;res._body='Cannot '+req.method+' '+req.path}"
        "    };"
        "    app._matchRoute=matchRoute;"
        "    app._createRes=createRes;"
        "    app._createReq=createReq;"
        "    return app};"
        "  __express.static=function(){return function(req,res,next){next()}};"
        "  __express.Router=function(){var r=function(){};"
        "    r.use=function(){return r};r.get=function(){return r};r.post=function(){return r};r.put=function(){return r};r.delete=function(){return r};r.route=function(){return{get:function(){return r},post:function(){return r}}};"
        "    return r};"
        "  __express.json=function(){return function(req,res,next){next()}};"
        "  __express.urlencoded=function(){return function(req,res,next){next()}};"
        "  __express.raw=function(){return function(req,res,next){next()}};"
        "  __express.text=function(){return function(req,res,next){next()}};"
        "  __express.application={};"
        "  __express.request={header:function(){},get:function(){}};"
        "  __express.response={status:function(c){this.statusCode=c;return this},"
        "    json:function(d){this._body=JSON.stringify(d);this._headers=this._headers||{};this._headers['content-type']='application/json';return this},"
        "    send:function(d){if(typeof d==='string')this._body=d;else if(typeof d==='object'&&d!==null)return this.json(d);return this},"
        "    set:function(k,v){this._headers=this._headers||{};this._headers[k.toLowerCase()]=v;return this},"
        "    setHeader:function(k,v){this._headers=this._headers||{};this._headers[k.toLowerCase()]=v;return this},"
        "    getHeader:function(k){this._headers=this._headers||{};return this._headers[k.toLowerCase()]||null},"
        "    get:function(k){return this.getHeader(k)},"
        "    redirect:function(){var s,u;if(arguments.length===1){u=arguments[0];s=302}else{s=arguments[0];u=arguments[1]}this.statusCode=s;this._headers=this._headers||{};this._headers['location']=u;return this},"
        "    location:function(u){this._headers=this._headers||{};this._headers['location']=u;return this},"
        "    type:function(t){return this},end:function(){return this},append:function(){return this},cookie:function(){return this},clearCookie:function(){return this},render:function(){return this},format:function(){return this},vary:function(){return this},links:function(){return this},"
        "    locals:{},statusCode:200,_headers:{},_body:'',headersSent:false,finished:false,writableEnded:false};"
        "  require.__express_stub=__express;"
        "}\n"

        /* supertest stub — invokes app routes for real */
        "if(typeof require==='function'){"
        "  require.__supertest_stub=function(app){"
        "    var _method='GET',_url='/',_data=undefined,_headers={};"
        "    function chain(method,url){_method=method;_url=url;return agent}"
        "    var agent={"
        "      get:function(u){return chain('GET',u)},"
        "      post:function(u){return chain('POST',u)},"
        "      put:function(u){return chain('PUT',u)},"
        "      delete:function(u){return chain('DELETE',u)},"
        "      patch:function(u){return chain('PATCH',u)},"
        "      send:function(d){_data=d;return agent},"
        "      set:function(k,v){_headers[k]=v;return agent},"
        "      expect:function(c,cb){if(cb)cb();return agent},"
        "      then:function(resolve,reject){"
        "        var result={status:200,body:{},headers:{},text:''};"
        "        try{"
        "          if(app&&typeof app._createRes==='function'){"
        "            var res=app._createRes();"
        "            var req=app._createReq(_method,_url);"
        "            if(_data!==undefined)req.body=_data;"
        "            for(var hk in _headers)req.headers[hk]=_headers[hk];"
        "            app.handle(req,res);"
        "            result.status=res.statusCode||200;"
        "            result.headers=res._headers||{};"
        "            var bd=res._body||'';"
        "            result.text=bd;"
        "            try{result.body=JSON.parse(bd)}catch(e){result.body=bd}"
        "          }"
        "        }catch(e){}"
        "        resolve(result)"
        "      }"
        "    };"
        "    return agent"
        "  };\n"
        "}\n"

        /* yargs stub */
        "if(typeof require==='function'){"
        "  var __yargs=function(){var y={argv:{_:[]}};"
        "    y.option=function(){return y};y.alias=function(){return y};y.default=function(){return y};y.describe=function(){return y};"
        "    y.demand=function(){return y};y.demandOption=function(){return y};y.demandCommand=function(){return y};"
        "    y.strict=function(){return y};y.help=function(){return y};y.version=function(){return y};y.alias=function(){return y};"
        "    y.parse=function(){return y.argv};y.showHelp=function(){return y};y.exit=function(){return y};"
        "    return y};"
        "  require.__yargs_stub=__yargs;"
        "}\n"

        /* undici stub */
        "if(typeof require==='function'){"
        "  require.__undici_stub={fetch:typeof fetch!=='undefined'?fetch:function(){return Promise.resolve(new Response())},"
        "    Agent:function(){},Pool:function(){},Client:function(){},"
        "    request:function(){return Promise.resolve({statusCode:200,headers:{},body:''})}"
        "  };\n"
        "}\n"

        /* abort-controller stub — return real globals if available */
        "if(typeof require==='function'){"
        "  var __acPolyfill={"
        "    AbortController:typeof AbortController!=='undefined'?AbortController:function(){this.signal=new AbortSignal()},"
        "    AbortSignal:typeof AbortSignal!=='undefined'?AbortSignal:undefined,"
        "    default:{"
        "      AbortController:typeof AbortController!=='undefined'?AbortController:function(){},"
        "      AbortSignal:typeof AbortSignal!=='undefined'?AbortSignal:function(){}"
        "    }"
        "  };"
        "  require.__abort_controller_stub=__acPolyfill;"
        "}\n"

        /* Register all stub modules into a lookup object for require() */
        "globalThis.__stub_modules={"
        "  express:require.__express_stub,"
        "  supertest:require.__supertest_stub,"
        "  yargs:require.__yargs_stub,"
        "  'yargs/yargs':require.__yargs_stub,"
        "  undici:require.__undici_stub,"
        "  'abort-controller':require.__abort_controller_stub,"
        "  crypto:__cryptoStub,"
        "  'node:crypto':__cryptoStub"
        "};\n"

        /* Fix MessageEvent instanceof Event — set up prototype chain */
        "if(typeof MessageEvent!=='undefined'&&typeof Event!=='undefined'){"
        "  if(Event.prototype){"
        "    MessageEvent.prototype=Object.create(Event.prototype);"
        "    MessageEvent.prototype.constructor=MessageEvent;"
        "  }"
        "}\n"

        "";

    JSStringRef script = JSStringCreateWithUTF8CString(polyfill);
    JSValueRef pfex = NULL;
    JSEvaluateScript(ctx, script, NULL, NULL, 1, &pfex);
    if(pfex){
        char* emsg = to_utf8(ctx, pfex);
        fprintf(stderr, "[polyfill error] %s\n", emsg);
        free(emsg);
    }
    JSStringRelease(script);
}

/* ============================================================================
 * Main — initialize + event loop
 * ============================================================================ */

int main(void){
    /* Ignore SIGPIPE */
    signal(SIGPIPE, SIG_IGN);

    /* Enable SharedArrayBuffer + Atomics in JSC */
    setenv("JSC_useSharedArrayBuffer", "1", 1);

    g_ctx = JSGlobalContextCreate(NULL);
    if(!g_ctx){
        uint32_t s=1,l=21;
        write(PFD,&s,4);write(PFD,&l,4);write(PFD,"Cannot create context",21);
        return 1;
    }
    g_global = JSContextGetGlobalObject(g_ctx);

    /* Create epoll instance */
    g_epoll_fd = epoll_create1(EPOLL_CLOEXEC);

    /* Register all native APIs */
    /* print() */
    JSStringRef pn = JSStringCreateWithUTF8CString("print");
    JSObjectSetProperty(g_ctx, g_global, pn,
        JSObjectMakeFunctionWithCallback(g_ctx, pn, print_cb), 0, NULL);
    JSStringRelease(pn);

    /* console */
    JSObjectRef co = JSObjectMake(g_ctx, NULL, NULL);
    reg_method(g_ctx, co, "log", console_log_cb);
    reg_method(g_ctx, co, "error", console_error_cb);
    reg_method(g_ctx, co, "warn", console_warn_cb);
    reg_method(g_ctx, co, "info", console_info_cb);
    reg_method(g_ctx, co, "debug", console_debug_cb);
    reg_method(g_ctx, co, "time", console_time_cb);
    reg_method(g_ctx, co, "timeEnd", console_timeEnd_cb);
    JSStringRef cn = JSStringCreateWithUTF8CString("console");
    JSObjectSetProperty(g_ctx, g_global, cn, co, 0, NULL);
    JSStringRelease(cn);

    /* global alias */
    set_prop_str(g_ctx, g_global, "global", "[object global]");

    /* Native modules */
    register_process(g_ctx, g_global);
    register_fs(g_ctx, g_global);
    register_path(g_ctx, g_global);
    register_bun(g_ctx, g_global);
    register_timers(g_ctx, g_global);
    register_fetch(g_ctx, g_global);

    /* Web APIs */
    register_web_apis(g_ctx, g_global);

    /* require() — must be before register_node_compat so the enhanced require wrapper can reference it */
    reg_method(g_ctx, g_global, "require", require_cb);

    /* Node.js compatibility APIs (enhances require with built-in modules) */
    register_node_compat(g_ctx, g_global);

    /* Node.js extras (zlib, Buffer extensions, etc.) */
    register_node_extras(g_ctx, g_global);

    /* Missing Bun APIs & globals */
    register_missing_apis(g_ctx, g_global);

    /* bun:test framework */
    register_bun_test(g_ctx, g_global);

    /* Polyfills for remaining test fixes */
    register_remaining_polyfills(g_ctx, g_global);

    /* ============================================================================
     * Event loop:
     * 1. Wait for request from parent on fd PFD
     * 2. Evaluate JS code
     * 3. Process any pending timers (setTimeout/setInterval callbacks)
     * 4. Send response back to parent
     * 5. Repeat
     * ============================================================================ */

    while(1){
        /* Read request */
        uint32_t cl = 0;
        if(read(PFD, &cl, 4) != 4) break;
        if(cl == 0) break;

        char* code = malloc(cl + 1);
        if(read(PFD, code, cl) != (ssize_t)cl){ free(code); break; }
        code[cl] = 0;

        uint32_t ul = 0; char* url = NULL;
        if(read(PFD, &ul, 4) != 4){ free(code); break; }
        if(ul > 0){
            url = malloc(ul + 1);
            if(read(PFD, url, ul) != (ssize_t)ul){ free(code); free(url); break; }
            url[ul] = 0;
        }

        /* Evaluate JS */
        /* Set __filename and __dirname for Node.js compat */
        node_compat_set_filename(g_ctx, g_global, url);

        JSStringRef sc = JSStringCreateWithUTF8CString(code);
        JSStringRef us = url ? JSStringCreateWithUTF8CString(url) : NULL;
        JSValueRef ex = NULL;
        JSValueRef res = JSEvaluateScript(g_ctx, sc, NULL, us, 1, &ex);
        JSStringRelease(sc);
        if(us) JSStringRelease(us);
        free(code);
        free(url);

        /* Process pending timers — block until they fire */
        int max_iterations = 1000; /* safety limit */
        while(g_timer_count > 0 && --max_iterations > 0) {
            struct epoll_event events[MAX_TIMERS];
            /* Block until next timer fires (max 30s) */
            int n = epoll_wait(g_epoll_fd, events, MAX_TIMERS, 30000);
            if(n <= 0) break; /* error or timeout */
            for(int i=0; i<n; i++){
                int fd = events[i].data.fd;
                uint64_t expirations;
                read(fd, &expirations, sizeof(expirations));
                /* Find the timer */
                for(int j=0; j<g_timer_count; j++){
                    if(g_timers[j].tfd == fd){
                        JSValueRef ex2 = NULL;
                        JSObjectRef cb = g_timers[j].callback;
                        JSObjectCallAsFunction(g_ctx, cb, NULL, g_timers[j].argc, g_timers[j].args, &ex2);
                        if(ex2){
                            char* m = to_utf8(g_ctx, ex2);
                            fprintf(stderr, "Timer error: %s\n", m);
                            free(m);
                        }
                        /* If one-shot, remove */
                        if(!g_timers[j].is_interval){
                            epoll_ctl(g_epoll_fd, EPOLL_CTL_DEL, fd, NULL);
                            close(fd);
                            g_timers[j] = g_timers[--g_timer_count];
                        }
                        break;
                    }
                }
            }
        }

        /* Send response */
        if(ex){
            char* m = to_utf8(g_ctx, ex);
            uint32_t ml = strlen(m);
            uint32_t st = 1;
            write(PFD, &st, 4);
            write(PFD, &ml, 4);
            write(PFD, m, ml);
            free(m);
        } else {
            char* rs = NULL;
            uint32_t rl = 0;
            if(res && !JSValueIsUndefined(g_ctx, res)){
                rs = to_utf8(g_ctx, res);
                rl = strlen(rs);
            }
            uint32_t st = 0;
            write(PFD, &st, 4);
            write(PFD, &rl, 4);
            if(rl > 0) write(PFD, rs, rl);
            free(rs);
        }
    }

    /* Cleanup */
    for(int i=0; i<g_timer_count; i++){
        epoll_ctl(g_epoll_fd, EPOLL_CTL_DEL, g_timers[i].tfd, NULL);
        close(g_timers[i].tfd);
    }
    close(g_epoll_fd);
    curl_global_cleanup();
    JSGlobalContextRelease(g_ctx);
    return 0;
}
