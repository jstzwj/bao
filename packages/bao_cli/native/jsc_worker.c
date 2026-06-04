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
extern int JSValueIsUndefined(JSContextRef, JSValueRef);
extern int JSValueIsNull(JSContextRef, JSValueRef);
extern int JSValueIsBoolean(JSContextRef, JSValueRef);
extern int JSValueIsNumber(JSContextRef, JSValueRef);
extern int JSValueIsString(JSContextRef, JSValueRef);
extern int JSValueIsObject(JSContextRef, JSValueRef);

/* Value conversion */
extern JSStringRef JSValueToStringCopy(JSContextRef, JSValueRef, JSValueRef*);
extern double JSValueToNumber(JSContextRef, JSValueRef, JSValueRef*);
extern int JSValueToBoolean(JSContextRef, JSValueRef);
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

static char* to_utf8(JSContextRef c, JSValueRef v) {
    if (!v) return strdup("null");
    JSStringRef s = JSValueToStringCopy(c, v, NULL);
    if (!s) return strdup("");
    size_t n = JSStringGetMaximumUTF8CStringSize(s);
    char* b = malloc(n);
    JSStringGetUTF8CString(s, b, n);
    JSStringRelease(s);
    return b;
}

static JSValueRef make_error(JSContextRef ctx, const char* msg, JSValueRef* ex) {
    JSStringRef s = JSStringCreateWithUTF8CString(msg);
    JSValueRef arg = JSValueMakeString(ctx, s);
    JSStringRelease(s);
    JSObjectRef err = JSObjectMakeError(ctx, 1, &arg, NULL);
    if (ex) *ex = err;
    return err;
}

static JSValueRef make_string(JSContextRef ctx, const char* str) {
    JSStringRef s = JSStringCreateWithUTF8CString(str);
    JSValueRef v = JSValueMakeString(ctx, s);
    JSStringRelease(s);
    return v;
}

static JSValueRef make_number(JSContextRef ctx, double n) {
    return JSValueMakeNumber(ctx, n);
}

static void set_prop_str(JSContextRef ctx, JSObjectRef obj, const char* name, const char* val) {
    JSStringRef k = JSStringCreateWithUTF8CString(name);
    JSObjectSetProperty(ctx, obj, k, make_string(ctx, val), 0, NULL);
    JSStringRelease(k);
}

static void set_prop_num(JSContextRef ctx, JSObjectRef obj, const char* name, double val) {
    JSStringRef k = JSStringCreateWithUTF8CString(name);
    JSObjectSetProperty(ctx, obj, k, make_number(ctx, val), 0, NULL);
    JSStringRelease(k);
}

static void set_prop_bool(JSContextRef ctx, JSObjectRef obj, const char* name, int val) {
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

static void reg_method(JSContextRef ctx, JSObjectRef obj, const char* name, JSObjectCallAsFunctionCallback cb) {
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

    /* require() */
    reg_method(g_ctx, g_global, "require", require_cb);

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
