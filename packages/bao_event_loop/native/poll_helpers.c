/*
 * poll_helpers.c - epoll/kqueue C helper functions for Bao event loop
 *
 * These functions are called from Cangjie via C FFI (foreign func).
 * They handle struct allocation/access for epoll_event, kevent, and timespec
 * since Cangjie cannot directly manipulate C struct layouts.
 *
 * Corresponding declarations in: bao_event_loop/src/poll.cj lines 542-571
 */

#include <stdlib.h>
#include <string.h>
#include <stdint.h>

#ifdef __linux__
#include <sys/epoll.h>
#include <sys/eventfd.h>
#include <unistd.h>
#endif

#if defined(__APPLE__) || defined(__FreeBSD__)
#include <sys/event.h>
#include <sys/time.h>
#endif

/* ============================================================================
 * epoll helpers (Linux)
 * struct epoll_event { uint32_t events; epoll_data_t data; }
 * epoll_data_t is union { void *ptr; int fd; uint32_t u32; uint64_t u64; }
 * ============================================================================ */

#ifdef __linux__

void *unsafeMallocEpollEvent(void) {
    return malloc(sizeof(struct epoll_event));
}

void unsafeFreeEpollEvent(void *ptr) {
    free(ptr);
}

void setEpollEventEvents(void *ptr, uint32_t events) {
    ((struct epoll_event *)ptr)->events = events;
}

void setEpollEventData(void *ptr, uint64_t data) {
    ((struct epoll_event *)ptr)->data.u64 = data;
}

uint32_t getEpollEventEvents(void *ptr) {
    return ((struct epoll_event *)ptr)->events;
}

uint64_t getEpollEventData(void *ptr) {
    return ((struct epoll_event *)ptr)->data.u64;
}

void *unsafeMallocEpollEvents(int64_t count) {
    return malloc((size_t)count * sizeof(struct epoll_event));
}

void unsafeFreeEpollEvents(void *ptr, int64_t count) {
    (void)count;
    free(ptr);
}

void *getEpollEventAt(void *buffer, int64_t index) {
    return &((struct epoll_event *)buffer)[index];
}

#else

/* Non-Linux stubs - epoll not available */
void *unsafeMallocEpollEvent(void) { return NULL; }
void unsafeFreeEpollEvent(void *ptr) { (void)ptr; }
void setEpollEventEvents(void *ptr, uint32_t events) { (void)ptr; (void)events; }
void setEpollEventData(void *ptr, uint64_t data) { (void)ptr; (void)data; }
uint32_t getEpollEventEvents(void *ptr) { (void)ptr; return 0; }
uint64_t getEpollEventData(void *ptr) { (void)ptr; return 0; }
void *unsafeMallocEpollEvents(int64_t count) { (void)count; return NULL; }
void unsafeFreeEpollEvents(void *ptr, int64_t count) { (void)ptr; (void)count; }
void *getEpollEventAt(void *buffer, int64_t index) { (void)buffer; (void)index; return NULL; }

#endif /* __linux__ */

/* ============================================================================
 * kqueue helpers (macOS/BSD)
 * struct kevent {
 *     uintptr_t ident;
 *     short     filter;
 *     uint16_t  flags;
 *     uint32_t  fflags;
 *     intptr_t  data;
 *     void      *udata;
 * }
 * ============================================================================ */

#if defined(__APPLE__) || defined(__FreeBSD__)

void *unsafeMallocKevent(void) {
    return malloc(sizeof(struct kevent));
}

void unsafeFreeKevent(void *ptr) {
    free(ptr);
}

void *unsafeMallocKevents(int64_t count) {
    return malloc((size_t)count * sizeof(struct kevent));
}

void unsafeFreeKevents(void *ptr, int64_t count) {
    (void)count;
    free(ptr);
}

void keventSet(void *ptr, uint64_t ident, int16_t filter, uint16_t flags,
               uint32_t fflags, int64_t data, void *udata) {
    struct kevent *kev = (struct kevent *)ptr;
    kev->ident = (uintptr_t)ident;
    kev->filter = filter;
    kev->flags = flags;
    kev->fflags = fflags;
    kev->data = (intptr_t)data;
    kev->udata = udata;
}

uint64_t getKeventIdent(void *ptr) {
    return (uint64_t)((struct kevent *)ptr)->ident;
}

int16_t getKeventFilter(void *ptr) {
    return ((struct kevent *)ptr)->filter;
}

uint16_t getKeventFlags(void *ptr) {
    return ((struct kevent *)ptr)->flags;
}

void *getKeventAt(void *buffer, int64_t index) {
    return &((struct kevent *)buffer)[index];
}

#else

/* Non-BSD stubs - kqueue not available */
void *unsafeMallocKevent(void) { return NULL; }
void unsafeFreeKevent(void *ptr) { (void)ptr; }
void *unsafeMallocKevents(int64_t count) { (void)count; return NULL; }
void unsafeFreeKevents(void *ptr, int64_t count) { (void)ptr; (void)count; }
void keventSet(void *ptr, uint64_t ident, int16_t filter, uint16_t flags,
               uint32_t fflags, int64_t data, void *udata) {
    (void)ptr; (void)ident; (void)filter; (void)flags;
    (void)fflags; (void)data; (void)udata;
}
uint64_t getKeventIdent(void *ptr) { (void)ptr; return 0; }
int16_t getKeventFilter(void *ptr) { (void)ptr; return 0; }
uint16_t getKeventFlags(void *ptr) { (void)ptr; return 0; }
void *getKeventAt(void *buffer, int64_t index) { (void)buffer; (void)index; return NULL; }

#endif /* __APPLE__ || __FreeBSD__ */

/* ============================================================================
 * timespec helpers
 * struct timespec { time_t tv_sec; long tv_nsec; }
 * ============================================================================ */

void *unsafeMallocTimespec(void) {
#ifdef __linux__
    return malloc(sizeof(struct timespec));
#elif defined(__APPLE__) || defined(__FreeBSD__)
    return malloc(sizeof(struct timespec));
#else
    return NULL;
#endif
}

void setTimespec(void *ptr, int64_t sec, int64_t nsec) {
#ifdef __linux__
    struct timespec *ts = (struct timespec *)ptr;
    ts->tv_sec = (time_t)sec;
    ts->tv_nsec = (long)nsec;
#elif defined(__APPLE__) || defined(__FreeBSD__)
    struct timespec *ts = (struct timespec *)ptr;
    ts->tv_sec = (time_t)sec;
    ts->tv_nsec = (long)nsec;
#else
    (void)ptr; (void)sec; (void)nsec;
#endif
}

void unsafeFreeTimespec(void *ptr) {
    free(ptr);
}

/* ============================================================================
 * eventfd helper (Linux) - for cross-thread wakeup
 * ============================================================================ */

#ifdef __linux__

#ifndef EFD_NONBLOCK
#define EFD_NONBLOCK 04000
#endif
#ifndef EFD_CLOEXEC
#define EFD_CLOEXEC 02000000
#endif

int32_t bao_eventfd(uint32_t initval, int32_t flags) {
    return (int32_t)eventfd((unsigned int)initval, flags);
}

/* ============================================================================
 * timerfd helpers (Linux) - for MiniEventLoop timers
 * timerfd_create/timerfd_settime integrate with epoll for precise timing
 * ============================================================================ */

#include <sys/timerfd.h>
#include <time.h>

#ifndef TFD_NONBLOCK
#define TFD_NONBLOCK 04000
#endif
#ifndef TFD_CLOEXEC
#define TFD_CLOEXEC 02000000
#endif

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
    /* If delay_ms is 0, set it_value to a minimal value to arm the timer */
    if (delay_ms == 0 && interval_ms > 0) {
        ts.it_value.tv_sec = ts.it_interval.tv_sec;
        ts.it_value.tv_nsec = ts.it_interval.tv_nsec;
    }
    return timerfd_settime(fd, 0, &ts, NULL);
}

#endif /* __linux__ */
