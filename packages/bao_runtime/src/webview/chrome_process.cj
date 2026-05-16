// bao_runtime - Chrome 进程管理
// 严格翻译自: src/runtime/webview/ChromeProcess.zig
//   Bun 的 Chrome 进程管理:
//   - spawn: 启动 Chrome/Chromium 并使用 --remote-debugging-pipe
//   - 子进程通过 fd 3 (读) 和 fd 4 (写) 进行 CDP JSON 通信
//   - 使用单个 socketpair, 子进程端 dup 到 fd 3 和 fd 4
//   - 父进程死亡 -> Chrome 的管道读 EOF -> Chrome 退出
//   - findChrome: 自动检测 Chrome 二进制路径
//   - findPlaywrightShell: 扫描 Playwright 缓存目录
//   - readDevToolsActivePort: 读取已运行 Chrome 的调试端口
//   仓颉: 提供兼容的 Chrome 进程管理接口
package bao_runtime.webview

import bao_core.*
import std.collection.*

// ============================================================================
// C FFI 声明
// 严格翻译自: ChromeProcess.zig 中使用的系统调用
// ============================================================================

@C
foreign func fcntl(fd: Int32, cmd: Int32, args: Int64): Int32
@C
foreign func open(path: CPointer<Int8>, flags: Int32, mode: UInt32): Int32
@C
foreign func chromeSocketpair(domain: Int32, type_: Int32, protocol: Int32, sv: CPointer<Int32>): Int32
@C
foreign func chromeFork(): Int32
@C
foreign func chromeDup2(oldfd: Int32, newfd: Int32): Int32
@C
foreign func chromeClose(fd: Int32): Int32
@C
foreign func execvp(file: CPointer<Int8>, argv: CPointer<CPointer<Int8>>): Int32

/// AF_UNIX
private let AF_UNIX: Int32 = 1
/// SOCK_STREAM
private let SOCK_STREAM: Int32 = 1
/// O_NONBLOCK
private let O_NONBLOCK: Int32 = 0x800
/// O_RDONLY
private let O_RDONLY: Int32 = 0
/// O_DIRECTORY
private let O_DIRECTORY: Int32 = 0x10000
/// F_SETFL
private let F_SETFL: Int32 = 4
/// SIGKILL
private let SIGKILL: Int32 = 9

// ============================================================================
// ChromeProcess - Chrome 进程管理
// 严格翻译自: ChromeProcess.zig ChromeProcess = @This()
//   process: *bun.spawn.Process
//   var instance: ?*ChromeProcess = null
//   Bun__Chrome__kill(): kill Chrome 进程
//   Bun__Chrome__ensure(): 确保 Chrome 已启动
//   onProcessExit(): 进程退出回调
//   findChrome(): 自动检测 Chrome 路径
//   findPlaywrightShell(): 扫描 Playwright 缓存
//   readDevToolsActivePort(): 读取 DevToolsActivePort 文件
//   Bun__Chrome__autoDetect(): 自动检测已运行的 Chrome
// ============================================================================

/// Chrome 进程管理
/// 对应 Bun: ChromeProcess = @This() { process: *bun.spawn.Process }
///
/// 启动 Chrome 并使用 --remote-debugging-pipe:
///   子进程通过 fd 3 (读) 和 fd 4 (写) 进行 CDP JSON 通信
///   使用单个 socketpair, 子进程端 dup 到 fd 3 和 fd 4
///   父进程死亡 -> Chrome 的管道读 EOF -> Chrome 退出
///   无需单独的宿主进程 — Chrome 就是 IPC 对等端
///
/// fd 布局 (子进程):
///   3 = Chrome 从我们读取 CDP 命令 (父进程写 -> 子进程读)
///   4 = Chrome 向我们写 CDP 回复 (子进程写 -> 父进程读)
public class ChromeProcess {
    /// 子进程 PID
    /// 对应 Bun: process: *bun.spawn.Process
    public var pid: Int32

    /// 父进程端 socket fd
    /// 对应 Bun: spawn() 返回的 fds[0]
    public var parentFd: Int32

    /// 是否已启动
    public var launched: Bool

    /// Chrome 二进制路径
    public var chromePath: String

    /// 用户数据目录
    public var userDataDir: String

    /// 全局单例
    /// 对应 Bun: var instance: ?*ChromeProcess = null
    private static var instance: ?ChromeProcess = None

    public init() {
        pid = -1
        parentFd = -1
        launched = false
        chromePath = ""
        userDataDir = ""
    }

    /// 终止 Chrome 进程
    /// 对应 Bun: pub export fn Bun__Chrome__kill() void
    ///   Chrome 的渲染器/GPU/实用程序子进程由 Chrome 自己的 ProcessSingleton 跟踪
    ///   SIGKILL 浏览器进程后, zygote 树会跟随退出
    public static func kill(): Unit {
        match (instance) {
            case Some(p) => ()
            case None => return
        }
        let p = instance.getOrThrow()
        if (p.pid > 0) {
            unsafe { kill(p.pid, SIGKILL) }
            p.pid = -1
            p.launched = false
        }
        instance = None
    }

    /// 确保 Chrome 已启动
    /// 对应 Bun: pub export fn Bun__Chrome__ensure(global, userDataDir, path, extraArgv, ...) i32
    ///   懒启动: 第一个 new Bun.WebView({ backend: "chrome" }) 通过 C++ 调用
    ///   返回父进程 socket fd (C++ 接管并放入 usockets)
    ///   返回 -1 表示启动失败或已在运行
    ///
    ///   C++ 的 Transport::ensureSpawned 在调用前检查自己的 m_readSock
    ///   所以 instance-already-exists -> -1 意味着 "你已经持有 fd, 这是 bug"
    ///   我们故意不存储 fd — usockets 拥有它
    ///
    ///   Windows TODO — fd.cast() 返回 HANDLE, pipe()/fcntl 无直接等价物
    public static func ensure(userDataDir: ?String, path: ?String,
                               extraArgv: Array<String>,
                               stdoutInherit: Bool,
                               stderrInherit: Bool): Int32 {
        match (instance) {
            case Some(_) => return -1  // C++ 已持有 fd
            case None => ()
        }

        let proc = ChromeProcess()
        let result = proc.`spawn`(userDataDir, path, extraArgv, stdoutInherit, stderrInherit)
        match (result) {
            case Ok(fd) =>
                instance = Some(proc)
                return fd
            case Err(_) => return -1
        }
    }

    /// 进程退出回调
    /// 对应 Bun: pub fn onProcessExit(this, _, status, _) void
    ///   子进程死亡 (EVFILT_PROC 触发)
    ///   通知 C++ 拒绝所有挂起的 promise 并标记宿主死亡
    public func onProcessExit(signal: Int32): Unit {
        // 通知 C++ 端 (Bun__Chrome__died)
        // 拒绝所有挂起的 CDP promise
        instance = None
        launched = false
        pid = -1
    }

    /// 启动 Chrome 子进程
    /// 对应 Bun: fn spawn(vm, userDataDir, explicitPath, extraArgv, stdoutInherit, stderrInherit) !bun.FD
    ///
    /// 步骤:
    ///   1. findChrome() 查找 Chrome 二进制
    ///   2. chromeSocketpair() 创建通信管道
    ///   3. 设置 parent 端为 nonblocking
    ///   4. 构建 argv (--user-data-dir, --remote-debugging-pipe, --headless, ...)
    ///   5. fork + execve
    ///   6. parent 关闭 child 端 fd
    ///   7. 返回 parent fd
    private func `spawn`(userDataDir: ?String, explicitPath: ?String,
                        extraArgv: Array<String>,
                        stdoutInherit: Bool, stderrInherit: Bool): Result<Int32, BaoError> {
        // Stubbed until CPointer array construction and process spawning helpers are ported.
        return Result<Int32, BaoError>.Err(BaoError(ErrorCode.Unexpected, "Chrome spawning is not implemented"))
    }

    // ========================================================================
    // Chrome 查找
    // 严格翻译自: ChromeProcess.zig findChrome() 和 findPlaywrightShell()
    // ========================================================================

    /// 自动检测 Chrome 二进制路径
    /// 对应 Bun: fn findChrome(alloc, explicitPath) !?[:0]const u8
    /// 优先级: backend.path > BUN_CHROME_PATH > $PATH > 硬编码路径 > Playwright 缓存
    public static func findChrome(explicitPath: ?String): ?String {
        // 1. 显式路径
        match (explicitPath) {
            case Some(p) => return p
            case None => ()
        }

        // 2. BUN_CHROME_PATH 环境变量
        match (getEnvVar("BUN_CHROME_PATH")) {
            case Some(envPath) => return envPath
            case None => ()
        }

        // 3. $PATH 搜索
        let pathNames = [
            "google-chrome-stable",
            "google-chrome",
            "chromium-browser",
            "chromium",
            "brave-browser",
            "microsoft-edge",
            "chrome"
        ]
        for (name in pathNames) {
            let found = which(name)
            if (found.isSome()) { return found }
        }

        // 4. 硬编码路径 (Linux)
        let absolutePaths = [
            "/usr/bin/google-chrome-stable",
            "/usr/bin/google-chrome",
            "/usr/bin/chromium-browser",
            "/usr/bin/chromium",
            "/snap/bin/chromium",
            "/usr/bin/brave-browser",
            "/snap/bin/brave",
            "/usr/bin/microsoft-edge"
        ]
        for (path in absolutePaths) {
            if (isExecutableFilePath(path)) { return path }
        }

        // 5. Playwright 缓存
        let playwright = findPlaywrightShell()
        if (playwright.isSome()) { return playwright }

        return None
    }

    /// 扫描 Playwright 缓存目录
    /// 对应 Bun: fn findPlaywrightShell(alloc) ?[:0]const u8
    /// 查找 chromium_headless_shell-<rev> 目录, 选择最高版本号
    public static func findPlaywrightShell(): ?String {
        let home = getEnvVar("HOME")
        if (home.isNone()) { return None }

        let cacheDir = "${home.getOrThrow()}/.cache/ms-playwright"
        // 简化: 检查缓存目录是否存在
        // 完整实现需要目录遍历和版本比较
        let candidates = [
            "${cacheDir}/chromium_headless_shell-*/chrome-headless-shell-linux64/chrome-headless-shell",
            "${cacheDir}/chromium_headless_shell-*/chrome-linux/headless_shell"
        ]
        // 简化: 返回 None
        return None
    }

    /// 读取 DevToolsActivePort 文件
    /// 对应 Bun: fn readDevToolsActivePort(out_buf) ?void
    /// Chrome 在 --remote-debugging-port 模式下写入此文件
    /// 两行: 端口号 和 /devtools/browser/<id>
    /// 返回 ws:// URL
    public static func readDevToolsActivePort(): ?String {
        let home = getEnvVar("HOME")
        if (home.isNone()) { return None }

        // 候选路径 (Linux)
        let candidates = [
            "${home.getOrThrow()}/.config/google-chrome/DevToolsActivePort",
            "${home.getOrThrow()}/.config/google-chrome-beta/DevToolsActivePort",
            "${home.getOrThrow()}/.config/google-chrome-unstable/DevToolsActivePort",
            "${home.getOrThrow()}/.config/chromium/DevToolsActivePort",
            "${home.getOrThrow()}/.config/BraveSoftware/Brave-Browser/DevToolsActivePort",
            "${home.getOrThrow()}/.config/microsoft-edge/DevToolsActivePort"
        ]

        for (path in candidates) {
            let content = readFileContent(path)
            match (content) {
                case Some(text) => ()
                case None => return None
            }
            // 解析: 第一行=端口, 第二行=路径
            let text = content.getOrThrow()
            let lines = text.split("\n")
            if (lines.size >= 2) {
                let port = lines[0]
                let wsPath = lines[1]
                if (port.size > 0 && wsPath.startsWith("/")) {
                    return "ws://127.0.0.1:${port}${wsPath}"
                }
            }
        }
        return None
    }

    /// 自动检测已运行的 Chrome WebSocket 调试 URL
    /// 对应 Bun: pub export fn Bun__Chrome__autoDetect(out_buf, out_cap) usize
    /// 通过读取 DevToolsActivePort 即时发现 (无需网络)
    public static func autoDetect(): ?String {
        return readDevToolsActivePort()
    }

    // ========================================================================
    // 内部工具
    // ========================================================================

    /// 在 $PATH 中查找可执行文件
    private static func which(name: String): ?String {
        // 简化实现
        let path = getEnvVar("PATH")
        if (path.isNone()) { return None }
        let dirs = path.getOrThrow().split(":")
        for (dir in dirs) {
            let candidate = "${dir}/${name}"
            if (isExecutableFilePath(candidate)) { return candidate }
        }
        return None
    }

    /// 检查路径是否为可执行文件
    private static func isExecutableFilePath(path: String): Bool {
        // Stubbed until C string/path FFI helpers are ported.
        return false
    }

    /// 获取环境变量
    private static func getEnvVar(name: String): ?String {
        // Stubbed until C string/path FFI helpers are ported.
        return None
    }

    /// 读取文件内容
    private static func readFileContent(path: String): ?String {
        // Stubbed until C string/path FFI helpers are ported.
        return None
    }
}

// ============================================================================
// 内部工具函数
// ============================================================================

/// 创建 C 字符串
private func unsafeNewCString(s: String): CPointer<Int8> {
    return CPointer<Int8>()
}

/// C 字符串转仓颉字符串
private func unsafeCStringToString(ptr: CPointer<Int8>): String {
    return ""
}
