// 操作系统常量定义
// 对应 Bun: src/runtime/node/os/constants.zig
// 严格翻译自: src/runtime/node/os/constants.zig
package bao_runtime.node.os

import std.collection.*

// ============================================================================
// OS 常量创建
// 对应 Bun: src/runtime/node/os/constants.zig - create
// ============================================================================
public class OsConstants {
    // 创建 errno 常量对象
    // 对应 Bun: src/runtime/node/os/constants.zig - createErrno
    public static func errno(): HashMap<String, Int32> {
        let m = HashMap<String, Int32>()
        m.add("E2BIG", 7)
        m.add("EACCES", 13)
        m.add("EADDRINUSE", 98)
        m.add("EADDRNOTAVAIL", 99)
        m.add("EAFNOSUPPORT", 97)
        m.add("EAGAIN", 11)
        m.add("EALREADY", 114)
        m.add("EBADF", 9)
        m.add("EBADMSG", 74)
        m.add("EBUSY", 16)
        m.add("ECANCELED", 125)
        m.add("ECHILD", 10)
        m.add("ECONNABORTED", 103)
        m.add("ECONNREFUSED", 111)
        m.add("ECONNRESET", 104)
        m.add("EDEADLK", 35)
        m.add("EDESTADDRREQ", 89)
        m.add("EDOM", 33)
        m.add("EDQUOT", 122)
        m.add("EEXIST", 17)
        m.add("EFAULT", 14)
        m.add("EFBIG", 27)
        m.add("EHOSTUNREACH", 113)
        m.add("EIDRM", 43)
        m.add("EILSEQ", 84)
        m.add("EINPROGRESS", 115)
        m.add("EINTR", 4)
        m.add("EINVAL", 22)
        m.add("EIO", 5)
        m.add("EISCONN", 106)
        m.add("EISDIR", 21)
        m.add("ELOOP", 40)
        m.add("EMFILE", 24)
        m.add("EMLINK", 31)
        m.add("EMSGSIZE", 90)
        m.add("EMULTIHOP", 72)
        m.add("ENAMETOOLONG", 36)
        m.add("ENETDOWN", 100)
        m.add("ENETRESET", 102)
        m.add("ENETUNREACH", 101)
        m.add("ENFILE", 23)
        m.add("ENOBUFS", 105)
        m.add("ENODATA", 61)
        m.add("ENODEV", 19)
        m.add("ENOENT", 2)
        m.add("ENOEXEC", 8)
        m.add("ENOLCK", 37)
        m.add("ENOLINK", 67)
        m.add("ENOMEM", 12)
        m.add("ENOMSG", 42)
        m.add("ENOPROTOOPT", 92)
        m.add("ENOSPC", 28)
        m.add("ENOSR", 63)
        m.add("ENOSTR", 60)
        m.add("ENOSYS", 38)
        m.add("ENOTCONN", 107)
        m.add("ENOTDIR", 20)
        m.add("ENOTEMPTY", 39)
        m.add("ENOTSOCK", 88)
        m.add("ENOTSUP", 95)
        m.add("ENOTTY", 25)
        m.add("ENOVERFLOW", 75)
        m.add("EPERM", 1)
        m.add("EPFNOSUPPORT", 96)
        m.add("EPIPE", 32)
        m.add("EPROTO", 71)
        m.add("EPROTONOSUPPORT", 93)
        m.add("EPROTOTYPE", 91)
        m.add("ERANGE", 34)
        m.add("EROFS", 30)
        m.add("ESPIPE", 29)
        m.add("ESRCH", 3)
        m.add("ESTALE", 70)
        m.add("ETIME", 62)
        m.add("ETIMEDOUT", 110)
        m.add("ETXTBSY", 26)
        m.add("EWOULDBLOCK", 11)
        m.add("EXDEV", 18)
        return m
    }

    // 创建信号常量对象
    // 对应 Bun: src/runtime/node/os/constants.zig - createSignals
    public static func signals(): HashMap<String, Int32> {
        let m = HashMap<String, Int32>()
        m.add("SIGHUP", 1)
        m.add("SIGINT", 2)
        m.add("SIGQUIT", 3)
        m.add("SIGILL", 4)
        m.add("SIGTRAP", 5)
        m.add("SIGABRT", 6)
        m.add("SIGIOT", 6)
        m.add("SIGBUS", 7)
        m.add("SIGFPE", 8)
        m.add("SIGKILL", 9)
        m.add("SIGUSR1", 10)
        m.add("SIGSEGV", 11)
        m.add("SIGUSR2", 12)
        m.add("SIGPIPE", 13)
        m.add("SIGALRM", 14)
        m.add("SIGTERM", 15)
        m.add("SIGCHLD", 17)
        m.add("SIGSTKFLT", 16)
        m.add("SIGCONT", 18)
        m.add("SIGSTOP", 19)
        m.add("SIGTSTP", 20)
        m.add("SIGTTIN", 21)
        m.add("SIGTTOU", 22)
        m.add("SIGURG", 23)
        m.add("SIGXCPU", 24)
        m.add("SIGXFSZ", 25)
        m.add("SIGVTALRM", 26)
        m.add("SIGPROF", 27)
        m.add("SIGWINCH", 28)
        m.add("SIGIO", 29)
        m.add("SIGPOLL", 29)
        m.add("SIGPWR", 30)
        m.add("SIGSYS", 31)
        return m
    }

    // 创建优先级常量对象
    // 对应 Bun: src/runtime/node/os/constants.zig - createPriority
    public static func priority(): HashMap<String, Int32> {
        let m = HashMap<String, Int32>()
        m.add("PRIORITY_LOW", 19)
        m.add("PRIORITY_BELOW_NORMAL", 10)
        m.add("PRIORITY_NORMAL", 0)
        m.add("PRIORITY_ABOVE_NORMAL", -7)
        m.add("PRIORITY_HIGH", -14)
        m.add("PRIORITY_HIGHEST", -20)
        return m
    }

    // 创建 dlopen 常量对象
    // 对应 Bun: src/runtime/node/os/constants.zig - createDlopen
    public static func dlopen(): HashMap<String, Int32> {
        let m = HashMap<String, Int32>()
        m.add("RTLD_LAZY", 1)
        m.add("RTLD_NOW", 2)
        m.add("RTLD_GLOBAL", 256)
        m.add("RTLD_LOCAL", 0)
        m.add("RTLD_DEEPBIND", 8)
        return m
    }

    // 创建完整常量对象
    // 对应 Bun: src/runtime/node/os/constants.zig - create
    public static func create(): HashMap<String, Any> {
        let m = HashMap<String, Any>()
        m.add("errno", errno())
        m.add("signals", signals())
        m.add("priority", priority())
        m.add("dlopen", dlopen())
        return m
    }
}
