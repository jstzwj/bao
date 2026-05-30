/*
 * futex_syscall.c - C helper for futex system calls
 * Cangjie cannot convert CPointer to Int64 directly, so we provide C wrappers.
 */
#include <unistd.h>
#include <sys/syscall.h>
#include <time.h>

long bao_futex_wait(void* uaddr, int expect) {
    return syscall(SYS_futex, uaddr, FUTEX_WAIT_PRIVATE, expect, NULL, NULL, 0);
}

long bao_futex_timed_wait(void* uaddr, int expect, long sec, long nsec) {
    struct timespec ts;
    ts.tv_sec = (time_t)sec;
    ts.tv_nsec = (long)nsec;
    return syscall(SYS_futex, uaddr, FUTEX_WAIT_PRIVATE, expect, &ts, NULL, 0);
}

long bao_futex_wake(void* uaddr, int count) {
    return syscall(SYS_futex, uaddr, FUTEX_WAKE_PRIVATE, count, NULL, NULL, 0);
}
