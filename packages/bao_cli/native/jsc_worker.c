/*
 * jsc_worker.c — Standalone JSC worker process
 * Runs as child process, isolated from Cangjie runtime.
 * Protocol on fd 3 (socketpair), print output on stdout/stderr.
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <unistd.h>

typedef void* JSContextRef;
typedef void* JSObjectRef;
typedef void* JSStringRef;
typedef void* JSValueRef;
typedef struct OpaqueJSContext* JSGlobalContextRef;
typedef JSValueRef (*JSObjectCallAsFunctionCallback)(JSContextRef,JSObjectRef,JSObjectRef,size_t,const JSValueRef[],JSValueRef*);

extern JSGlobalContextRef JSGlobalContextCreate(JSObjectRef);
extern void JSGlobalContextRelease(JSGlobalContextRef);
extern JSObjectRef JSContextGetGlobalObject(JSContextRef);
extern JSValueRef JSEvaluateScript(JSContextRef,JSStringRef,JSObjectRef,JSStringRef,int,JSValueRef*);
extern JSStringRef JSStringCreateWithUTF8CString(const char*);
extern void JSStringRelease(JSStringRef);
extern size_t JSStringGetMaximumUTF8CStringSize(JSStringRef);
extern size_t JSStringGetUTF8CString(JSStringRef,char*,size_t);
extern JSValueRef JSValueMakeUndefined(JSContextRef);
extern int JSValueIsUndefined(JSContextRef,JSValueRef);
extern JSStringRef JSValueToStringCopy(JSContextRef,JSValueRef,JSValueRef*);
extern JSObjectRef JSObjectMakeFunctionWithCallback(JSContextRef,JSStringRef,JSObjectCallAsFunctionCallback);
extern void JSObjectSetProperty(JSContextRef,JSObjectRef,JSStringRef,JSValueRef,unsigned,JSValueRef*);
extern JSObjectRef JSObjectMake(JSContextRef,void*,void*);

static int PFD = 3;

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

/* print() — stdout */
static JSValueRef print_cb(JSContextRef c,JSObjectRef f,JSObjectRef t,size_t ac,const JSValueRef a[],JSValueRef*e){
    (void)f;(void)t;(void)e;
    for(size_t i=0;i<ac;i++){if(i>0)fputc(' ',stdout);char*s=to_utf8(c,a[i]);fputs(s,stdout);free(s);}
    fputc('\n',stdout);fflush(stdout);return JSValueMakeUndefined(c);
}

/* console.log() — stdout */
static JSValueRef console_log_cb(JSContextRef c,JSObjectRef f,JSObjectRef t,size_t ac,const JSValueRef a[],JSValueRef*e){
    (void)f;(void)t;(void)e;
    for(size_t i=0;i<ac;i++){if(i>0)fputc(' ',stdout);char*s=to_utf8(c,a[i]);fputs(s,stdout);free(s);}
    fputc('\n',stdout);fflush(stdout);return JSValueMakeUndefined(c);
}

/* console.error() — stderr */
static JSValueRef console_error_cb(JSContextRef c,JSObjectRef f,JSObjectRef t,size_t ac,const JSValueRef a[],JSValueRef*e){
    (void)f;(void)t;(void)e;
    for(size_t i=0;i<ac;i++){if(i>0)fputc(' ',stderr);char*s=to_utf8(c,a[i]);fputs(s,stderr);free(s);}
    fputc('\n',stderr);fflush(stderr);return JSValueMakeUndefined(c);
}

/* console.warn() — stderr yellow */
static JSValueRef console_warn_cb(JSContextRef c,JSObjectRef f,JSObjectRef t,size_t ac,const JSValueRef a[],JSValueRef*e){
    (void)f;(void)t;(void)e;
    fputs("\033[33m",stderr);
    for(size_t i=0;i<ac;i++){if(i>0)fputc(' ',stderr);char*s=to_utf8(c,a[i]);fputs(s,stderr);free(s);}
    fputs("\033[0m\n",stderr);fflush(stderr);return JSValueMakeUndefined(c);
}

/* console.info() — same as log */
static JSValueRef console_info_cb(JSContextRef c,JSObjectRef f,JSObjectRef t,size_t ac,const JSValueRef a[],JSValueRef*e){
    return console_log_cb(c,f,t,ac,a,e);
}

/* Helper: register a method on an object */
static void reg_method(JSContextRef ctx, JSObjectRef obj, const char* name, JSObjectCallAsFunctionCallback cb) {
    JSStringRef n = JSStringCreateWithUTF8CString(name);
    JSObjectRef fn = JSObjectMakeFunctionWithCallback(ctx, n, cb);
    JSObjectSetProperty(ctx, obj, n, fn, 0, NULL);
    JSStringRelease(n);
}

static void w32(uint32_t v){unsigned char b[4]={v&0xff,(v>>8)&0xff,(v>>16)&0xff,(v>>24)&0xff};write(PFD,b,4);}
static uint32_t r32(void){unsigned char b[4];if(read(PFD,b,4)!=4)return 0;return b[0]|(b[1]<<8)|(b[2]<<16)|((uint32_t)b[3]<<24);}
static int rexact(void*buf,size_t n){size_t d=0;while(d<n){ssize_t r=read(PFD,(char*)buf+d,n-d);if(r<=0)return -1;d+=r;}return 0;}

int main(void){
    JSGlobalContextRef ctx=JSGlobalContextCreate(NULL);
    if(!ctx){w32(1);w32(21);write(PFD,"Cannot create context",21);return 1;}
    JSObjectRef g=JSContextGetGlobalObject(ctx);

    /* Register global print() */
    JSStringRef pn=JSStringCreateWithUTF8CString("print");
    JSObjectRef pf=JSObjectMakeFunctionWithCallback(ctx,pn,print_cb);
    JSObjectSetProperty(ctx,g,pn,pf,0,NULL);JSStringRelease(pn);

    /* Register console object with log/error/warn/info */
    JSStringRef cn=JSStringCreateWithUTF8CString("console");
    JSObjectRef co=JSObjectMake(ctx,NULL,NULL);
    reg_method(ctx,co,"log",console_log_cb);
    reg_method(ctx,co,"error",console_error_cb);
    reg_method(ctx,co,"warn",console_warn_cb);
    reg_method(ctx,co,"info",console_info_cb);
    JSObjectSetProperty(ctx,g,cn,co,0,NULL);JSStringRelease(cn);

    while(1){
        uint32_t cl=r32();if(cl==0)break;
        char*code=malloc(cl+1);if(rexact(code,cl)){free(code);break;}code[cl]=0;
        uint32_t ul=r32();char*url=NULL;
        if(ul>0){url=malloc(ul+1);if(rexact(url,ul)){free(code);free(url);break;}url[ul]=0;}
        JSStringRef sc=JSStringCreateWithUTF8CString(code);
        JSStringRef us=url?JSStringCreateWithUTF8CString(url):NULL;
        JSValueRef ex=NULL;JSValueRef res=JSEvaluateScript(ctx,sc,NULL,us,1,&ex);
        JSStringRelease(sc);if(us)JSStringRelease(us);free(code);free(url);
        if(ex){char*m=to_utf8(ctx,ex);uint32_t ml=strlen(m);w32(1);w32(ml);write(PFD,m,ml);free(m);}
        else{char*rs=NULL;uint32_t rl=0;if(res&&!JSValueIsUndefined(ctx,res)){rs=to_utf8(ctx,res);rl=strlen(rs);}
        w32(0);w32(rl);if(rl>0)write(PFD,rs,rl);free(rs);}
    }
    JSGlobalContextRelease(ctx);return 0;
}
