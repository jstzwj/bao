/*
 * BAO_STUB(native-link): C ABI shims needed while the Cangjie packages are
 * being wired to Bun's native dependency graph.
 *
 * These functions do not execute JavaScript and do not delegate to Node. They
 * only satisfy Cangjie FFI symbols used by Bao's own runtime packages so the
 * in-process VirtualMachine path can link. Replace the libc-backed mimalloc
 * shims with the real mimalloc package when that native library is integrated.
 */

#define _GNU_SOURCE

#include <errno.h>
#include <pthread.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <termios.h>
#include <unistd.h>

#ifdef __linux__
#include <arpa/inet.h>
#include <netinet/in.h>
#include <sys/epoll.h>
#include <sys/eventfd.h>
#include <sys/timerfd.h>
#endif

#if defined(__APPLE__) || defined(__FreeBSD__)
#include <sys/event.h>
#include <sys/time.h>
#endif

extern char **environ;

void *mi_malloc(size_t size) { return malloc(size); }
void mi_free(void *ptr) { free(ptr); }
void *mi_realloc(void *ptr, size_t size) { return realloc(ptr, size); }

int *errno_location(void) { return &errno; }

char *environPtr(int64_t index) {
    if (index < 0 || environ == NULL) {
        return NULL;
    }
    return environ[index];
}

int64_t c_read(int32_t fd, void *buf, int64_t count) {
    return (int64_t)read(fd, buf, (size_t)count);
}

int64_t c_write(int32_t fd, const void *buf, int64_t count) {
    return (int64_t)write(fd, buf, (size_t)count);
}

int32_t c_close(int32_t fd) { return close(fd); }

void pthread_set_name_np(uintptr_t thread, const char *name) {
#if defined(__linux__)
    pthread_setname_np((pthread_t)thread, name);
#elif defined(__FreeBSD__)
    pthread_set_name_np((pthread_t)thread, name);
#else
    (void)thread;
    (void)name;
#endif
}

static struct termios saved_termios;
static int saved_termios_fd = -1;
static int saved_termios_valid = 0;

int Bun__ttySetMode(int fd, int mode) {
    if (mode == 0) {
        if (saved_termios_valid && saved_termios_fd == fd) {
            return tcsetattr(fd, TCSANOW, &saved_termios);
        }
        return 0;
    }

    struct termios tio;
    if (tcgetattr(fd, &tio) != 0) {
        return errno;
    }
    if (!saved_termios_valid) {
        saved_termios = tio;
        saved_termios_fd = fd;
        saved_termios_valid = 1;
    }

    cfmakeraw(&tio);
    return tcsetattr(fd, TCSANOW, &tio) == 0 ? 0 : errno;
}

#ifdef __linux__

void *unsafeMallocEpollEvent(void) { return malloc(sizeof(struct epoll_event)); }
void unsafeFreeEpollEvent(void *ptr) { free(ptr); }
void setEpollEventEvents(void *ptr, uint32_t events) { ((struct epoll_event *)ptr)->events = events; }
void setEpollEventData(void *ptr, uint64_t data) { ((struct epoll_event *)ptr)->data.u64 = data; }
uint32_t getEpollEventEvents(void *ptr) { return ((struct epoll_event *)ptr)->events; }
uint64_t getEpollEventData(void *ptr) { return ((struct epoll_event *)ptr)->data.u64; }
void *unsafeMallocEpollEvents(int64_t count) { return malloc((size_t)count * sizeof(struct epoll_event)); }
void unsafeFreeEpollEvents(void *ptr, int64_t count) {
    (void)count;
    free(ptr);
}
void *getEpollEventAt(void *buffer, int64_t index) { return &((struct epoll_event *)buffer)[index]; }

int32_t bao_eventfd(uint32_t initval, int32_t flags) {
    return (int32_t)eventfd((unsigned int)initval, flags);
}

int32_t bao_timerfd_create(void) {
    return (int32_t)timerfd_create(CLOCK_MONOTONIC, TFD_NONBLOCK | TFD_CLOEXEC);
}

int32_t bao_timerfd_set(int32_t fd, int64_t delay_ms, int64_t interval_ms) {
    struct itimerspec ts;
    memset(&ts, 0, sizeof(ts));
    ts.it_value.tv_sec = (time_t)(delay_ms / 1000);
    ts.it_value.tv_nsec = (long)((delay_ms % 1000) * 1000000);
    ts.it_interval.tv_sec = (time_t)(interval_ms / 1000);
    ts.it_interval.tv_nsec = (long)((interval_ms % 1000) * 1000000);
    if (delay_ms == 0 && interval_ms > 0) {
        ts.it_value = ts.it_interval;
    }
    return timerfd_settime(fd, 0, &ts, NULL);
}

void *unsafeMallocSockaddrIn(void) { return calloc(1, sizeof(struct sockaddr_in)); }
void unsafeFreeSockaddrIn(void *ptr) { free(ptr); }

int32_t parseAddress(const char *host, int64_t port, void *addr) {
    struct sockaddr_in *in = (struct sockaddr_in *)addr;
    memset(in, 0, sizeof(*in));
    in->sin_family = AF_INET;
    in->sin_port = htons((uint16_t)port);
    if (host == NULL || host[0] == '\0') {
        in->sin_addr.s_addr = htonl(INADDR_ANY);
        return 0;
    }
    return inet_pton(AF_INET, host, &in->sin_addr) == 1 ? 0 : -1;
}

#else

void *unsafeMallocEpollEvent(void) { return NULL; }
void unsafeFreeEpollEvent(void *ptr) { (void)ptr; }
void setEpollEventEvents(void *ptr, uint32_t events) { (void)ptr; (void)events; }
void setEpollEventData(void *ptr, uint64_t data) { (void)ptr; (void)data; }
uint32_t getEpollEventEvents(void *ptr) { (void)ptr; return 0; }
uint64_t getEpollEventData(void *ptr) { (void)ptr; return 0; }
void *unsafeMallocEpollEvents(int64_t count) { (void)count; return NULL; }
void unsafeFreeEpollEvents(void *ptr, int64_t count) { (void)ptr; (void)count; }
void *getEpollEventAt(void *buffer, int64_t index) { (void)buffer; (void)index; return NULL; }
int32_t bao_eventfd(uint32_t initval, int32_t flags) { (void)initval; (void)flags; return -1; }
int32_t bao_timerfd_create(void) { return -1; }
int32_t bao_timerfd_set(int32_t fd, int64_t delay_ms, int64_t interval_ms) {
    (void)fd; (void)delay_ms; (void)interval_ms; return -1;
}
void *unsafeMallocSockaddrIn(void) { return NULL; }
void unsafeFreeSockaddrIn(void *ptr) { (void)ptr; }
int32_t parseAddress(const char *host, int64_t port, void *addr) {
    (void)host; (void)port; (void)addr; return -1;
}

#endif

#if defined(__APPLE__) || defined(__FreeBSD__)
void *unsafeMallocKevent(void) { return malloc(sizeof(struct kevent)); }
void unsafeFreeKevent(void *ptr) { free(ptr); }
void *unsafeMallocKevents(int64_t count) { return malloc((size_t)count * sizeof(struct kevent)); }
void unsafeFreeKevents(void *ptr, int64_t count) { (void)count; free(ptr); }
void keventSet(void *ptr, uint64_t ident, int16_t filter, uint16_t flags,
               uint32_t fflags, int64_t data, void *udata) {
    struct kevent *kev = (struct kevent *)ptr;
    EV_SET(kev, (uintptr_t)ident, filter, flags, fflags, (intptr_t)data, udata);
}
uint64_t getKeventIdent(void *ptr) { return (uint64_t)((struct kevent *)ptr)->ident; }
int16_t getKeventFilter(void *ptr) { return ((struct kevent *)ptr)->filter; }
uint16_t getKeventFlags(void *ptr) { return ((struct kevent *)ptr)->flags; }
void *getKeventAt(void *buffer, int64_t index) { return &((struct kevent *)buffer)[index]; }
#else
int32_t kqueue(void) { return -1; }
int32_t kevent(int32_t kq, void *changelist, int32_t nchanges, void *eventlist, int32_t nevents, void *timeout) {
    (void)kq; (void)changelist; (void)nchanges; (void)eventlist; (void)nevents; (void)timeout; return -1;
}
void *unsafeMallocKevent(void) { return NULL; }
void unsafeFreeKevent(void *ptr) { (void)ptr; }
void *unsafeMallocKevents(int64_t count) { (void)count; return NULL; }
void unsafeFreeKevents(void *ptr, int64_t count) { (void)ptr; (void)count; }
void keventSet(void *ptr, uint64_t ident, int16_t filter, uint16_t flags,
               uint32_t fflags, int64_t data, void *udata) {
    (void)ptr; (void)ident; (void)filter; (void)flags; (void)fflags; (void)data; (void)udata;
}
uint64_t getKeventIdent(void *ptr) { (void)ptr; return 0; }
int16_t getKeventFilter(void *ptr) { (void)ptr; return 0; }
uint16_t getKeventFlags(void *ptr) { (void)ptr; return 0; }
void *getKeventAt(void *buffer, int64_t index) { (void)buffer; (void)index; return NULL; }
#endif

void *unsafeMallocTimespec(void) { return malloc(sizeof(struct timespec)); }
void unsafeFreeTimespec(void *ptr) { free(ptr); }
void setTimespec(void *ptr, int64_t sec, int64_t nsec) {
    struct timespec *ts = (struct timespec *)ptr;
    ts->tv_sec = (time_t)sec;
    ts->tv_nsec = (long)nsec;
}

/* ========================================================================
 * BAO_STUB(futex): minimal futex stubs for bao_threading
 * Replace with real futex syscall FFI when available.
 * ======================================================================== */
#include <linux/futex.h>
#include <sys/syscall.h>

int bao_futex_wait(int32_t *addr, int32_t expected, const struct timespec *timeout) {
    return syscall(SYS_futex, addr, FUTEX_WAIT_PRIVATE, expected, timeout, NULL, 0);
}
int bao_futex_timed_wait(int32_t *addr, int32_t expected, const struct timespec *timeout) {
    return syscall(SYS_futex, addr, FUTEX_WAIT_PRIVATE, expected, timeout, NULL, 0);
}
int bao_futex_wake(int32_t *addr, int32_t count) {
    return syscall(SYS_futex, addr, FUTEX_WAKE_PRIVATE, count, NULL, NULL, 0);
}

/* ========================================================================
 * BAO_STUB(atomic): GCC atomic builtin wrappers for Cangjie FFI
 * Cangjie's @C foreign func declarations generate calls to these symbols.
 * Use asm labels on function definitions to emit the exact symbol names.
 * ======================================================================== */
#include <stdatomic.h>

uint32_t bao_atomic_load_uint32(_Atomic uint32_t *ptr, int memmodel) __asm__("__atomic_load_n");
uint32_t bao_atomic_load_uint32(_Atomic uint32_t *ptr, int memmodel) {
    return atomic_load_explicit(ptr, memory_order_seq_cst);
}

void bao_atomic_store_uint32(_Atomic uint32_t *ptr, uint32_t val, int memmodel) __asm__("__atomic_store_n");
void bao_atomic_store_uint32(_Atomic uint32_t *ptr, uint32_t val, int memmodel) {
    atomic_store_explicit(ptr, val, memory_order_seq_cst);
}

uint32_t bao_atomic_exchange_uint32(_Atomic uint32_t *ptr, uint32_t val, int memmodel) __asm__("__atomic_exchange_n");
uint32_t bao_atomic_exchange_uint32(_Atomic uint32_t *ptr, uint32_t val, int memmodel) {
    return atomic_exchange_explicit(ptr, val, memory_order_seq_cst);
}

uint32_t bao_atomic_fetch_add_uint32(_Atomic uint32_t *ptr, uint32_t delta, int memmodel) __asm__("__atomic_fetch_add");
uint32_t bao_atomic_fetch_add_uint32(_Atomic uint32_t *ptr, uint32_t delta, int memmodel) {
    return atomic_fetch_add_explicit(ptr, delta, memory_order_seq_cst);
}

int bao_sync_cas_uint32(_Atomic uint32_t *ptr, uint32_t expected, uint32_t desired) __asm__("__sync_bool_compare_and_swap");
int bao_sync_cas_uint32(_Atomic uint32_t *ptr, uint32_t expected, uint32_t desired) {
    return atomic_compare_exchange_strong(ptr, &expected, desired);
}
