/*
 * jsc_bridge.c — JSC bridge via subprocess
 *
 * Spawns bao_jsc_worker as a child process, communicates via socketpair.
 * JSC runs completely isolated in the child process — no signal handler
 * or memory allocator conflicts with Cangjie runtime.
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
#include <errno.h>

/* Worker process state */
static int g_sock = -1;
static pid_t g_worker_pid = -1;
static char* g_worker_path = NULL;

/* ============================================================================
 * Helper: read/write with retry
 * ============================================================================ */
static int write_all(int fd, const void* buf, size_t n) {
    const char* p = (const char*)buf;
    while (n > 0) {
        ssize_t r = write(fd, p, n);
        if (r <= 0) return -1;
        p += r; n -= r;
    }
    return 0;
}

static int read_all(int fd, void* buf, size_t n) {
    char* p = (char*)buf;
    while (n > 0) {
        ssize_t r = read(fd, p, n);
        if (r <= 0) return -1;
        p += r; n -= r;
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

/* ============================================================================
 * Start/stop worker
 * ============================================================================ */
static int start_worker(void) {
    if (g_sock >= 0) return 0; /* already running */

    int sv[2];
    if (socketpair(AF_UNIX, SOCK_STREAM, 0, sv) != 0) return -1;

    pid_t pid = fork();
    if (pid < 0) { close(sv[0]); close(sv[1]); return -1; }

    if (pid == 0) {
        /* Child */
        close(sv[0]);
        dup2(sv[1], 3);
        close(sv[1]);
        /* Find worker binary next to main binary */
        if (!g_worker_path) {
            g_worker_path = "/proc/self/exe";
        }
        char worker[4096];
        ssize_t len = readlink("/proc/self/exe", worker, sizeof(worker)-20);
        if (len > 0) {
            worker[len] = '\0';
            /* Replace basename with bao_jsc_worker */
            char* slash = strrchr(worker, '/');
            if (slash) {
                strcpy(slash + 1, "bao_jsc_worker");
            }
        } else {
            strcpy(worker, "bao_jsc_worker");
        }
        execl(worker, "bao_jsc_worker", NULL);
        /* If execl fails, try PATH */
        execlp("bao_jsc_worker", "bao_jsc_worker", NULL);
        _exit(127);
    }

    /* Parent */
    close(sv[1]);
    g_sock = sv[0];
    g_worker_pid = pid;
    return 0;
}

static void stop_worker(void) {
    if (g_sock >= 0) {
        /* Send EOF by shutting down write side */
        shutdown(g_sock, SHUT_WR);
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
 * Public API — called from Cangjie via @C foreign func
 * ============================================================================ */

/**
 * Execute JavaScript code in the JSC worker subprocess.
 * Returns malloc'd result string (caller must free), or NULL.
 */
void* bao_jsc_run(void* code_ptr, void* filename_ptr) {
    const char* code = (const char*)code_ptr;
    const char* filename = (const char*)filename_ptr;

    if (start_worker() != 0) {
        return strdup("Error: cannot start JSC worker");
    }

    uint32_t codeLen = code ? (uint32_t)strlen(code) : 0;
    uint32_t urlLen = filename ? (uint32_t)strlen(filename) : 0;

    /* Send request */
    write_u32(g_sock, codeLen);
    if (codeLen > 0) write_all(g_sock, code, codeLen);
    write_u32(g_sock, urlLen);
    if (urlLen > 0) write_all(g_sock, filename, urlLen);

    /* Read response */
    uint32_t status = read_u32(g_sock);
    uint32_t resultLen = read_u32(g_sock);

    char* result = NULL;
    if (resultLen > 0 && resultLen < 1024*1024) {
        result = (char*)malloc(resultLen + 8);
        if (result) {
            if (read_all(g_sock, result, resultLen) != 0) {
                free(result);
                return strdup("Error: worker communication failed");
            }
            result[resultLen] = '\0';
        }
    } else {
        result = NULL;
    }

    if (status == 1) {
        /* Error — prefix with "Error: " */
        if (result) {
            size_t elen = strlen(result);
            char* err = (char*)malloc(elen + 8);
            if (err) { memcpy(err, "Error: ", 7); memcpy(err+7, result, elen+1); }
            free(result);
            return err;
        }
        return strdup("Error: unknown JSC error");
    }

    return result;  /* NULL for undefined, or malloc'd string */
}

/**
 * Free result from bao_jsc_run
 */
void bao_jsc_free(void* s) {
    free(s);
}

/**
 * Shutdown the worker
 */
void bao_jsc_shutdown(void) {
    stop_worker();
}

/* ============================================================================
 * Memory helpers — used by Cangjie string conversion
 * ============================================================================ */
void bao_c_free(void* ptr) { free(ptr); }
void* bao_c_malloc(uint64_t size) { return malloc((size_t)size); }

/* Test functions */
int bao_test_add(int a, int b) { return a + b; }

void* bao_noop_run(void* code, void* filename) {
    (void)code; (void)filename;
    return (void*)"NOOP_OK";
}
