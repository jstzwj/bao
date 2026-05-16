// bao_node_fallbacks - Node.js 内置模块的 JS polyfill 注册表
// 严格翻译自: src/node-fallbacks/lib.rs, src/node-fallbacks/Cargo.toml
//   Bun 在运行时通过此模块注册 Node.js 内置模块的 JS 回退实现
//   当原生 C++/Zig 实现不可用时，Bun 加载这些 JS polyfill
//   这些文件在构建时通过 build-fallbacks.ts 编译为 ESM/CJS 模块
//
// 在仓颉版本中，此包:
//   1. 注册所有 Node.js 内置模块的模块名 -> 映射关系
//   2. 提供模块注册表，供运行时 JS 引擎查询
//   3. 保持与 Bun 的 node-fallbacks 模块完全一致的模块列表
package bao_node_fallbacks

import bao_core.*

// ============================================================================
// NodeFallbackModule - Node.js 回退模块枚举
// 严格翻译自: src/node-fallbacks/lib.rs + build-fallbacks.ts
//   Bun 通过 readdirSync(".") 列出所有 .js 文件并注册为内置模块
//   每个文件名 (不含 .js) 对应一个 Node.js 内置模块名
// ============================================================================

/// Node.js 内置模块回退实现注册表
/// 对应 Bun: build-fallbacks.ts 中扫描的所有 .js 文件
/// 这些模块在运行时按需加载，当原生实现不可用时作为回退
public enum NodeFallbackModule {
    | Assert            // assert.js - 断言模块
    | Buffer            // buffer.js - Buffer 类 (2035行, 最大)
    | Console           // console.js - 控制台 (重导出)
    | Constants         // constants.js - POSIX 常量 (O_RDONLY, S_IFMT, errno, signal 等)
    | Crypto            // crypto.js - 加密模块
    | Domain            // domain.js - 域模块 (已弃用)
    | Events            // events.js - EventEmitter (545行)
    | Http              // http.js - HTTP 模块 (重导出)
    | Https             // https.js - HTTPS 模块
    | Net               // net.js - 网络模块
    | Os                // os.js - 操作系统信息
    | Path              // path.js - 路径处理 (533行)
    | Process           // process.js - 进程对象
    | Punycode          // punycode.js - Punycode 编码 (重导出)
    | Querystring       // querystring.js - 查询字符串解析
    | Stream            // stream.js - 流模块 (重导出)
    | StringDecoder     // string_decoder.js - 字符串解码器
    | Sys               // sys.js - 系统模块 (util 别名)
    | Timers            // timers.js - 定时器
    | TimersPromises    // timers.promises.js - Promise 化定时器 (238行)
    | Tty               // tty.js - 终端模块
    | Url               // url.js - URL 解析 (755行)
    | Util              // util.js - 工具函数 (959行)
    | Zlib              // zlib.js - 压缩模块 (重导出)
}

/// Node.js 回退模块注册表
/// 对应 Bun 运行时中的 Node.js 内置模块查找机制
/// Bun 通过 Module.builtinModules 和 node-fallbacks/ 目录中的 .js 文件
/// 构建完整的内置模块列表
public class NodeFallbackRegistry {
    /// 已注册的模块列表
    private static var modules: ArrayList<NodeFallbackModule> = ArrayList<NodeFallbackModule>()

    /// 初始化注册表 (注册所有模块)
    /// 对应 Bun: build-fallbacks.ts 中 readdirSync(".") 扫描 .js 文件
    public static func init(): Unit {
        modules.clear()
        modules.append(NodeFallbackModule.Assert)
        modules.append(NodeFallbackModule.Buffer)
        modules.append(NodeFallbackModule.Console)
        modules.append(NodeFallbackModule.Constants)
        modules.append(NodeFallbackModule.Crypto)
        modules.append(NodeFallbackModule.Domain)
        modules.append(NodeFallbackModule.Events)
        modules.append(NodeFallbackModule.Http)
        modules.append(NodeFallbackModule.Https)
        modules.append(NodeFallbackModule.Net)
        modules.append(NodeFallbackModule.Os)
        modules.append(NodeFallbackModule.Path)
        modules.append(NodeFallbackModule.Process)
        modules.append(NodeFallbackModule.Punycode)
        modules.append(NodeFallbackModule.Querystring)
        modules.append(NodeFallbackModule.Stream)
        modules.append(NodeFallbackModule.StringDecoder)
        modules.append(NodeFallbackModule.Sys)
        modules.append(NodeFallbackModule.Timers)
        modules.append(NodeFallbackModule.TimersPromises)
        modules.append(NodeFallbackModule.Tty)
        modules.append(NodeFallbackModule.Url)
        modules.append(NodeFallbackModule.Util)
        modules.append(NodeFallbackModule.Zlib)
    }

    /// 获取模块名
    /// 对应 Bun: basename(name, extname(name)).replaceAll(".", "/")
    /// 例如: "timers.promises.js" -> "timers/promises"
    ///       "string_decoder.js" -> "string_decoder"
    public static func moduleName(mod: NodeFallbackModule): String {
        match(mod) {
            case Assert => "assert"
            case Buffer => "buffer"
            case Console => "console"
            case Constants => "constants"
            case Crypto => "crypto"
            case Domain => "domain"
            case Events => "events"
            case Http => "http"
            case Https => "https"
            case Net => "net"
            case Os => "os"
            case Path => "path"
            case Process => "process"
            case Punycode => "punycode"
            case Querystring => "querystring"
            case Stream => "stream"
            case StringDecoder => "string_decoder"
            case Sys => "sys"
            case Timers => "timers"
            case TimersPromises => "timers/promises"
            case Tty => "tty"
            case Url => "url"
            case Util => "util"
            case Zlib => "zlib"
        }
    }

    /// 获取模块文件名
    /// 对应 Bun: 各 .js 文件名
    public static func moduleFileName(mod: NodeFallbackModule): String {
        match(mod) {
            case Assert => "assert.js"
            case Buffer => "buffer.js"
            case Console => "console.js"
            case Constants => "constants.js"
            case Crypto => "crypto.js"
            case Domain => "domain.js"
            case Events => "events.js"
            case Http => "http.js"
            case Https => "https.js"
            case Net => "net.js"
            case Os => "os.js"
            case Path => "path.js"
            case Process => "process.js"
            case Punycode => "punycode.js"
            case Querystring => "querystring.js"
            case Stream => "stream.js"
            case StringDecoder => "string_decoder.js"
            case Sys => "sys.js"
            case Timers => "timers.js"
            case TimersPromises => "timers.promises.js"
            case Tty => "tty.js"
            case Url => "url.js"
            case Util => "util.js"
            case Zlib => "zlib.js"
        }
    }

    /// 根据模块名查找模块
    /// 对应 Bun 运行时的内置模块查找
    public static func findModule(name: String): ?NodeFallbackModule {
        for (mod in modules) {
            if (moduleName(mod) == name) {
                return Some(mod)
            }
        }
        return None
    }

    /// 获取所有已注册模块
    public static func getAllModules(): ArrayList<NodeFallbackModule> {
        return modules
    }

    /// 是否为重导出型模块 (只有一行 export default)
    /// 对应 Bun: console.js, stream.js 等只重导出已有全局对象
    public static func isReexport(mod: NodeFallbackModule): Bool {
        match(mod) {
            case Console => true
            case Stream => true
            case Domain => true
            case Punycode => true
            case StringDecoder => true
            case Zlib => true
            case _ => false
        }
    }

    /// 是否为命名空间型模块 (点分模块名)
    /// 对应 Bun: build-fallbacks.ts 中 basename(name, extname(name)).replaceAll(".", "/")
    public static func isNamespaced(mod: NodeFallbackModule): Bool {
        match(mod) {
            case TimersPromises => true
            case _ => false
        }
    }

    /// 获取模块输出格式
    /// 对应 Bun: build-fallbacks.ts 中 --format 参数
    /// stream 使用 CJS 格式，其他使用 ESM 格式
    public static func moduleFormat(mod: NodeFallbackModule): String {
        match(mod) {
            case Stream => "cjs"
            case _ => "esm"
        }
    }
}

// ============================================================================
// NodeConstants - Node.js 常量
// 严格翻译自: src/node-fallbacks/constants.js
//   POSIX 文件系统常量、errno、signal、SSL 选项等
// ============================================================================

/// Node.js 文件系统常量
/// 对应 Bun: node-fallbacks/constants.js 中的 POSIX 常量
/// macOS/Darwin 值 (Bun 原始文件为 macOS 常量)
public class NodeConstants {

    // === 文件打开标志 (O_*) ===
    public static let O_RDONLY: Int64 = 0
    public static let O_WRONLY: Int64 = 1
    public static let O_RDWR: Int64 = 2
    public static let O_CREAT: Int64 = 512
    public static let O_EXCL: Int64 = 2048
    public static let O_NOCTTY: Int64 = 131072
    public static let O_TRUNC: Int64 = 1024
    public static let O_APPEND: Int64 = 8
    public static let O_DIRECTORY: Int64 = 1048576
    public static let O_NOFOLLOW: Int64 = 256
    public static let O_SYNC: Int64 = 128
    public static let O_SYMLINK: Int64 = 2097152
    public static let O_NONBLOCK: Int64 = 4

    // === 文件类型掩码 (S_IF*) ===
    public static let S_IFMT: Int64 = 61440
    public static let S_IFREG: Int64 = 32768
    public static let S_IFDIR: Int64 = 16384
    public static let S_IFCHR: Int64 = 8192
    public static let S_IFBLK: Int64 = 24576
    public static let S_IFIFO: Int64 = 4096
    public static let S_IFLNK: Int64 = 40960
    public static let S_IFSOCK: Int64 = 49152

    // === 文件权限位 (S_IR*) ===
    public static let S_IRWXU: Int64 = 448
    public static let S_IRUSR: Int64 = 256
    public static let S_IWUSR: Int64 = 128
    public static let S_IXUSR: Int64 = 64
    public static let S_IRWXG: Int64 = 56
    public static let S_IRGRP: Int64 = 32
    public static let S_IWGRP: Int64 = 16
    public static let S_IXGRP: Int64 = 8
    public static let S_IRWXO: Int64 = 7
    public static let S_IROTH: Int64 = 4
    public static let S_IWOTH: Int64 = 2
    public static let S_IXOTH: Int64 = 1

    // === errno 常量 ===
    public static let E2BIG: Int64 = 7
    public static let EACCES: Int64 = 13
    public static let EADDRINUSE: Int64 = 48
    public static let EADDRNOTAVAIL: Int64 = 49
    public static let EAFNOSUPPORT: Int64 = 47
    public static let EAGAIN: Int64 = 35
    public static let EALREADY: Int64 = 37
    public static let EBADF: Int64 = 9
    public static let EBADMSG: Int64 = 94
    public static let EBUSY: Int64 = 16
    public static let ECANCELED: Int64 = 89
    public static let ECHILD: Int64 = 10
    public static let ECONNABORTED: Int64 = 53
    public static let ECONNREFUSED: Int64 = 61
    public static let ECONNRESET: Int64 = 54
    public static let EDEADLK: Int64 = 11
    public static let EDESTADDRREQ: Int64 = 39
    public static let EDOM: Int64 = 33
    public static let EDQUOT: Int64 = 69
    public static let EEXIST: Int64 = 17
    public static let EFAULT: Int64 = 14
    public static let EFBIG: Int64 = 27
    public static let EHOSTUNREACH: Int64 = 65
    public static let EIDRM: Int64 = 90
    public static let EILSEQ: Int64 = 92
    public static let EINPROGRESS: Int64 = 36
    public static let EINTR: Int64 = 4
    public static let EINVAL: Int64 = 22
    public static let EIO: Int64 = 5
    public static let EISCONN: Int64 = 56
    public static let EISDIR: Int64 = 21
    public static let ELOOP: Int64 = 62
    public static let EMFILE: Int64 = 24
    public static let EMLINK: Int64 = 31
    public static let EMSGSIZE: Int64 = 40
    public static let EMULTIHOP: Int64 = 95
    public static let ENAMETOOLONG: Int64 = 63
    public static let ENETDOWN: Int64 = 50
    public static let ENETRESET: Int64 = 52
    public static let ENETUNREACH: Int64 = 51
    public static let ENFILE: Int64 = 23
    public static let ENOBUFS: Int64 = 55
    public static let ENODATA: Int64 = 96
    public static let ENODEV: Int64 = 19
    public static let ENOENT: Int64 = 2
    public static let ENOEXEC: Int64 = 8
    public static let ENOLCK: Int64 = 77
    public static let ENOLINK: Int64 = 97
    public static let ENOMEM: Int64 = 12
    public static let ENOMSG: Int64 = 91
    public static let ENOPROTOOPT: Int64 = 42
    public static let ENOSPC: Int64 = 28
    public static let ENOSR: Int64 = 98
    public static let ENOSTR: Int64 = 99
    public static let ENOSYS: Int64 = 78
    public static let ENOTCONN: Int64 = 57
    public static let ENOTDIR: Int64 = 20
    public static let ENOTEMPTY: Int64 = 66
    public static let ENOTSOCK: Int64 = 38
    public static let ENOTSUP: Int64 = 45
    public static let ENOTTY: Int64 = 25
    public static let ENXIO: Int64 = 6
    public static let EOPNOTSUPP: Int64 = 102
    public static let EOVERFLOW: Int64 = 84
    public static let EPERM: Int64 = 1
    public static let EPIPE: Int64 = 32
    public static let EPROTO: Int64 = 100
    public static let EPROTONOSUPPORT: Int64 = 43
    public static let EPROTOTYPE: Int64 = 41
    public static let ERANGE: Int64 = 34
    public static let EROFS: Int64 = 30
    public static let ESPIPE: Int64 = 29
    public static let ESRCH: Int64 = 3
    public static let ESTALE: Int64 = 70
    public static let ETIME: Int64 = 101
    public static let ETIMEDOUT: Int64 = 60
    public static let ETXTBSY: Int64 = 26
    public static let EWOULDBLOCK: Int64 = 35
    public static let EXDEV: Int64 = 18

    // === 信号常量 ===
    public static let SIGHUP: Int64 = 1
    public static let SIGINT: Int64 = 2
    public static let SIGQUIT: Int64 = 3
    public static let SIGILL: Int64 = 4
    public static let SIGTRAP: Int64 = 5
    public static let SIGABRT: Int64 = 6
    public static let SIGIOT: Int64 = 6
    public static let SIGBUS: Int64 = 10
    public static let SIGFPE: Int64 = 8
    public static let SIGKILL: Int64 = 9
    public static let SIGUSR1: Int64 = 30
    public static let SIGSEGV: Int64 = 11
    public static let SIGUSR2: Int64 = 31
    public static let SIGPIPE: Int64 = 13
    public static let SIGALRM: Int64 = 14
    public static let SIGTERM: Int64 = 15
    public static let SIGCHLD: Int64 = 20
    public static let SIGCONT: Int64 = 19
    public static let SIGSTOP: Int64 = 17
    public static let SIGTSTP: Int64 = 18
    public static let SIGTTIN: Int64 = 21
    public static let SIGTTOU: Int64 = 22
    public static let SIGURG: Int64 = 16
    public static let SIGXCPU: Int64 = 24
    public static let SIGXFSZ: Int64 = 25
    public static let SIGVTALRM: Int64 = 26
    public static let SIGPROF: Int64 = 27
    public static let SIGWINCH: Int64 = 28
    public static let SIGIO: Int64 = 23
    public static let SIGSYS: Int64 = 12

    // === 文件访问常量 ===
    public static let F_OK: Int64 = 0
    public static let R_OK: Int64 = 4
    public static let W_OK: Int64 = 2
    public static let X_OK: Int64 = 1

    // === UDP 常量 ===
    public static let UV_UDP_REUSEADDR: Int64 = 4
}
