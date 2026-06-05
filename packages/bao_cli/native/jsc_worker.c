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
static JSGlobalContextRef g_ctx = NULL;
static JSObjectRef g_global = NULL;

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
        char* body = to_utf8(c, a[0]);
        set_prop_str(c, obj, "_body", body);
        free(body);
    }
    set_prop_num(c, obj, "status", 200);
    set_prop_bool(c, obj, "ok", 1);
    set_prop_str(c, obj, "statusText", "OK");
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
 * crypto — getRandomValues
 * ============================================================================ */

static JSValueRef crypto_getRandomValues_cb(JSContextRef c,JSObjectRef f,JSObjectRef t,size_t ac,const JSValueRef a[],JSValueRef*e){
    (void)f;(void)t;(void)e;
    if(ac<1 || !JSValueIsObject(c, a[0])) return make_error(c, "crypto.getRandomValues: TypedArray required", e);
    JSObjectRef arr = JSValueToObject(c, a[0], NULL);

    JSStringRef lk = JSStringCreateWithUTF8CString("length");
    JSValueRef lv = JSObjectGetProperty(c, arr, lk, NULL);
    JSStringRelease(lk);
    if(!JSValueIsNumber(c, lv)) return a[0];

    unsigned len = (unsigned)JSValueToNumber(c, lv, NULL);

    /* Read from /dev/urandom */
    FILE* rng = fopen("/dev/urandom", "rb");
    if(rng){
        for(unsigned i=0; i<len; i++){
            unsigned char byte;
            if(fread(&byte, 1, 1, rng) == 1){
                JSObjectSetPropertyAtIndex(c, arr, i, make_number(c, (double)byte), NULL);
            }
        }
        fclose(rng);
    } else {
        /* Fallback: use random() */
        srand((unsigned)time(NULL));
        for(unsigned i=0; i<len; i++){
            JSObjectSetPropertyAtIndex(c, arr, i, make_number(c, (double)(rand() & 0xFF)), NULL);
        }
    }
    return a[0];
}

static JSValueRef crypto_randomUUID_cb(JSContextRef c,JSObjectRef f,JSObjectRef t,size_t ac,const JSValueRef a[],JSValueRef*e){
    (void)f;(void)t;(void)ac;(void)a;(void)e;
    /* Generate a v4 UUID */
    unsigned char bytes[16];
    FILE* rng = fopen("/dev/urandom", "rb");
    if(rng){
        fread(bytes, 1, 16, rng);
        fclose(rng);
    } else {
        srand((unsigned)time(NULL));
        for(int i=0; i<16; i++) bytes[i] = rand() & 0xFF;
    }
    bytes[6] = (bytes[6] & 0x0F) | 0x40; /* version 4 */
    bytes[8] = (bytes[8] & 0x3F) | 0x80; /* variant 1 */
    char uuid[37];
    snprintf(uuid, sizeof(uuid),
        "%02x%02x%02x%02x-%02x%02x-%02x%02x-%02x%02x-%02x%02x%02x%02x%02x%02x",
        bytes[0],bytes[1],bytes[2],bytes[3],bytes[4],bytes[5],bytes[6],bytes[7],
        bytes[8],bytes[9],bytes[10],bytes[11],bytes[12],bytes[13],bytes[14],bytes[15]);
    return make_string(c, uuid);
}

static void register_crypto(JSContextRef ctx, JSObjectRef global) {
    JSObjectRef crypto_obj = JSObjectMake(ctx, NULL, NULL);
    reg_method(ctx, crypto_obj, "getRandomValues", crypto_getRandomValues_cb);
    reg_method(ctx, crypto_obj, "randomUUID", crypto_randomUUID_cb);
    JSStringRef k = JSStringCreateWithUTF8CString("crypto");
    JSObjectSetProperty(ctx, global, k, crypto_obj, 0, NULL);
    JSStringRelease(k);
}

/* ============================================================================
 * Buffer
 * ============================================================================ */

static JSValueRef buffer_toString_cb(JSContextRef,JSObjectRef,JSObjectRef,size_t,const JSValueRef[],JSValueRef*);
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

        /* Add Buffer-like toString that decodes bytes to string */
        reg_method(c, arr, "toString", buffer_toString_cb);
        set_prop_num(c, arr, "length", (double)len);
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
            set_prop_num(c, buf, "length", (double)sz);
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

static void register_buffer(JSContextRef ctx, JSObjectRef global) {
    JSObjectRef buf_obj = JSObjectMake(ctx, NULL, NULL);
    reg_method(ctx, buf_obj, "from", buffer_from_cb);
    reg_method(ctx, buf_obj, "alloc", buffer_alloc_cb);
    reg_method(ctx, buf_obj, "isBuffer", stub_constructor); /* minimal stub */

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
        "  return Response;"
        "})();"
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
        "    assertThrow(String(actual) === String(expected), 'toEqual', expected);"
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
        "    assertThrow(typeof actual === 'string' && actual.indexOf(pattern) !== -1, 'toMatch', pattern);"
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
        "    assertThrow(actual != null && actual[propPath] !== undefined, 'toHaveProperty', propPath);"
        "    return m;"
        "  };"
        ""
        "  /* .not — negation modifier */"
        "  var notM = {};"
        "  var notNames = ['toBe','toEqual','toBeTruthy','toBeFalsy','toThrow',"
        "    'toBeGreaterThan','toBeLessThan','toContain','toBeNull','toBeDefined',"
        "    'toBeUndefined','toBeNaN','toMatch','toHaveLength','toBeCloseTo','toHaveProperty',"
        "    'toBeGreaterThanOrEqual','toBeLessThanOrEqual'];"
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
 * Main — initialize + event loop
 * ============================================================================ */

int main(void){
    /* Ignore SIGPIPE */
    signal(SIGPIPE, SIG_IGN);

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

    /* bun:test framework */
    register_bun_test(g_ctx, g_global);

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
