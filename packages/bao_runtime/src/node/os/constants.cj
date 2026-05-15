// 操作系统常量定义
// 对应 Bun: src/runtime/node/os/constants.zig
// 严格翻译自: src/runtime/node/os/constants.zig
package bao_runtime

// ============================================================================
// OS 常量创建
// 对应 Bun: src/runtime/node/os/constants.zig - create
// ============================================================================
public class OsConstants {
    // 创建 errno 常量对象
    // 对应 Bun: src/runtime/node/os/constants.zig - createErrno
    public static func errno(): Map<String, Int32> {
        let m = HashMap<String, Int32>()
        m.put("E2BIG", 7)
        m.put("EACCES", 13)
        m.put("EADDRINUSE", 98)
        m.put("EADDRNOTAVAIL", 99)
        m.put("EAFNOSUPPORT", 97)
        m.put("EAGAIN", 11)
        m.put("EALREADY", 114)
        m.put("EBADF", 9)
        m.put("EBADMSG", 74)
        m.put("EBUSY", 16)
        m.put("ECANCELED", 125)
        m.put("ECHILD", 10)
        m.put("ECONNABORTED", 103)
        m.put("ECONNREFUSED", 111)
        m.put("ECONNRESET", 104)
        m.put("EDEADLK", 35)
        m.put("EDESTADDRREQ", 89)
        m.put("EDOM", 33)
        m.put("EDQUOT", 122)
        m.put("EEXIST", 17)
        m.put("EFAULT", 14)
        m.put("EFBIG", 27)
        m.put("EHOSTUNREACH", 113)
        m.put("EIDRM", 43)
        m.put("EILSEQ", 84)
        m.put("EINPROGRESS", 115)
        m.put("EINTR", 4)
        m.put("EINVAL", 22)
        m.put("EIO", 5)
        m.put("EISCONN", 106)
        m.put("EISDIR", 21)
        m.put("ELOOP", 40)
        m.put("EMFILE", 24)
        m.put("EMLINK", 31)
        m.put("EMSGSIZE", 90)
        m.put("EMULTIHOP", 72)
        m.put("ENAMETOOLONG", 36)
        m.put("ENETDOWN", 100)
        m.put("ENETRESET", 102)
        m.put("ENETUNREACH", 101)
        m.put("ENFILE", 23)
        m.put("ENOBUFS", 105)
        m.put("ENODATA", 61)
        m.put("ENODEV", 19)
        m.put("ENOENT", 2)
        m.put("ENOEXEC", 8)
        m.put("ENOLCK", 37)
        m.put("ENOLINK", 67)
        m.put("ENOMEM", 12)
        m.put("ENOMSG", 42)
        m.put("ENOPROTOOPT", 92)
        m.put("ENOSPC", 28)
        m.put("ENOSR", 63)
        m.put("ENOSTR", 60)
        m.put("ENOSYS", 38)
        m.put("ENOTCONN", 107)
        m.put("ENOTDIR", 20)
        m.put("ENOTEMPTY", 39)
        m.put("ENOTSOCK", 88)
        m.put("ENOTSUP", 95)
        m.put("ENOTTY", 25)
        m.put("ENOVERFLOW", 75)
        m.put("EPERM", 1)
        m.put("EPFNOSUPPORT", 96)
        m.put("EPIPE", 32)
        m.put("EPROTO", 71)
        m.put("EPROTONOSUPPORT", 93)
        m.put("EPROTOTYPE", 91)
        m.put("ERANGE", 34)
        m.put("EROFS", 30)
        m.put("ESPIPE", 29)
        m.put("ESRCH", 3)
        m.put("ESTALE", 70)
        m.put("ETIME", 62)
        m.put("ETIMEDOUT", 110)
        m.put("ETXTBSY", 26)
        m.put("EWOULDBLOCK", 11)
        m.put("EXDEV", 18)
        return m
    }

    // 创建信号常量对象
    // 对应 Bun: src/runtime/node/os/constants.zig - createSignals
    public static func signals(): Map<String, Int32> {
        let m = HashMap<String, Int32>()
        m.put("SIGHUP", 1)
        m.put("SIGINT", 2)
        m.put("SIGQUIT", 3)
        m.put("SIGILL", 4)
        m.put("SIGTRAP", 5)
        m.put("SIGABRT", 6)
        m.put("SIGIOT", 6)
        m.put("SIGBUS", 7)
        m.put("SIGFPE", 8)
        m.put("SIGKILL", 9)
        m.put("SIGUSR1", 10)
        m.put("SIGSEGV", 11)
        m.put("SIGUSR2", 12)
        m.put("SIGPIPE", 13)
        m.put("SIGALRM", 14)
        m.put("SIGTERM", 15)
        m.put("SIGCHLD", 17)
        m.put("SIGSTKFLT", 16)
        m.put("SIGCONT", 18)
        m.put("SIGSTOP", 19)
        m.put("SIGTSTP", 20)
        m.put("SIGTTIN", 21)
        m.put("SIGTTOU", 22)
        m.put("SIGURG", 23)
        m.put("SIGXCPU", 24)
        m.put("SIGXFSZ", 25)
        m.put("SIGVTALRM", 26)
        m.put("SIGPROF", 27)
        m.put("SIGWINCH", 28)
        m.put("SIGIO", 29)
        m.put("SIGPOLL", 29)
        m.put("SIGPWR", 30)
        m.put("SIGSYS", 31)
        return m
    }

    // 创建优先级常量对象
    // 对应 Bun: src/runtime/node/os/constants.zig - createPriority
    public static func priority(): Map<String, Int32> {
        let m = HashMap<String, Int32>()
        m.put("PRIORITY_LOW", 19)
        m.put("PRIORITY_BELOW_NORMAL", 10)
        m.put("PRIORITY_NORMAL", 0)
        m.put("PRIORITY_ABOVE_NORMAL", -7)
        m.put("PRIORITY_HIGH", -14)
        m.put("PRIORITY_HIGHEST", -20)
        return m
    }

    // 创建 dlopen 常量对象
    // 对应 Bun: src/runtime/node/os/constants.zig - createDlopen
    public static func dlopen(): Map<String, Int32> {
        let m = HashMap<String, Int32>()
        m.put("RTLD_LAZY", 1)
        m.put("RTLD_NOW", 2)
        m.put("RTLD_GLOBAL", 256)
        m.put("RTLD_LOCAL", 0)
        m.put("RTLD_DEEPBIND", 8)
        return m
    }

    // 创建完整常量对象
    // 对应 Bun: src/runtime/node/os/constants.zig - create
    public static func create(): Map<String, Any> {
        let m = HashMap<String, Any>()
        m.put("errno", errno())
        m.put("signals", signals())
        m.put("priority", priority())
        m.put("dlopen", dlopen())
        return m
    }
}
