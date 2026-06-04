/*
 * jsc_bridge.c — Subprocess JSC bridge
 *
 * Spawns bao_jsc_worker as a child process, communicates via socketpair.
 * JSC runs completely isolated in the child process — no Cangjie runtime conflict.
 * The main binary does NOT link libJavaScriptCore.a.
 *
 * Protocol on socketpair (fd 3 in child):
 *   Request:  [4B code_len][code][4B url_len][url]
 *   Response: [4B status: 0=ok,1=error][4B result_len][result]
 */

#include <stdint.h>
#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/socket.h>
#include <sys/wait.h>

/* Worker process state */
static int g_sock = -1;
static pid_t g_worker_pid = -1;

static int write_all(int fd, const void* buf, size_t n) {
    const char* p = (const char*)buf;
    while (n > 0) {
        ssize_t r = write(fd, p, n);
        if (r <= 0) return -1;
        p += r; n -= (size_t)r;
    }
    return 0;
}

static int read_all(int fd, void* buf, size_t n) {
    char* p = (char*)buf;
    while (n > 0) {
        ssize_t r = read(fd, p, n);
        if (r <= 0) return -1;
        p += r; n -= (size_t)r;
    }
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

/* Find bao_jsc_worker binary next to main binary */
static const char* find_worker_path(void) {
    static char path[4096] = {0};
    if (path[0]) return path;
    
    ssize_t len = readlink("/proc/self/exe", path, sizeof(path)-20);
    if (len > 0) {
        path[len] = '\0';
        char* slash = strrchr(path, '/');
        if (slash) strcpy(slash + 1, "bao_jsc_worker");
    } else {
        strcpy(path, "bao_jsc_worker");
    }
    return path;
}

static int start_worker(void) {
    if (g_sock >= 0) return 0;

    int sv[2];
    if (socketpair(AF_UNIX, SOCK_STREAM, 0, sv) != 0) return -1;

    pid_t pid = fork();
    if (pid < 0) { close(sv[0]); close(sv[1]); return -1; }

    if (pid == 0) {
        close(sv[0]);
        dup2(sv[1], 3);
        close(sv[1]);
        execl(find_worker_path(), "bao_jsc_worker", NULL);
        execlp("bao_jsc_worker", "bao_jsc_worker", NULL);
        _exit(127);
    }

    close(sv[1]);
    g_sock = sv[0];
    g_worker_pid = pid;
    return 0;
}

static void stop_worker(void) {
    if (g_sock >= 0) {
        /* Send EOF */
        uint32_t zero = 0;
        write_all(g_sock, &zero, 4);
        close(g_sock);
        g_sock = -1;
    }
    if (g_worker_pid > 0) {
        int st;
        waitpid(g_worker_pid, &st, 0);
        g_worker_pid = -1;
    }
}

/* ============================================================================
 * Cangjie FFI 接口
 * ============================================================================ */

void* bao_jsc_run(void* code_ptr, void* filename_ptr) {
    if (start_worker() != 0) {
        return strdup("Error: cannot start JSC worker");
    }

    const char* code = (const char*)code_ptr;
    const char* filename = (const char*)filename_ptr;

    uint32_t codeLen = code ? (uint32_t)strlen(code) : 0;
    uint32_t urlLen = filename ? (uint32_t)strlen(filename) : 0;

    write_u32(g_sock, codeLen);
    if (codeLen > 0) write_all(g_sock, code, codeLen);
    write_u32(g_sock, urlLen);
    if (urlLen > 0) write_all(g_sock, filename, urlLen);

    uint32_t status = read_u32(g_sock);
    uint32_t resultLen = read_u32(g_sock);

    char* result = NULL;
    if (resultLen > 0 && resultLen < 1024*1024) {
        result = (char*)malloc(resultLen + 1);
        if (result) {
            if (read_all(g_sock, result, resultLen) != 0) {
                free(result);
                return strdup("Error: worker communication failed");
            }
            result[resultLen] = '\0';
        }
    }

    if (status == 1) {
        /* Worker already returns the error message from JSC exception.toString().
         * JSC Error objects produce "Error: <message>" format.
         * Don't add another "Error: " prefix here. */
        return result;
    }

    return result;
}

void bao_jsc_free(void* s) { free(s); }

void bao_jsc_shutdown(void) { stop_worker(); }

int bao_test_add(int a, int b) { return a + b; }

void* bao_noop_run(void* code, void* filename) {
    (void)code; (void)filename;
    return NULL;
}

void bao_c_free(void* ptr) { free(ptr); }
void* bao_c_malloc(uint64_t size) { return malloc((size_t)size); }
