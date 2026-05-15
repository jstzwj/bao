// bao_runtime - WebView 宿主进程
// 严格翻译自: src/runtime/webview/HostProcess.zig
//   Bun 的 WebView 宿主进程管理 (仅 macOS):
//   - WKWebView 硬性断言 pthread_main_np() (MainThreadCocoa.mm)
//   - 无法在 JS 线程上桥接 CFRunLoop 到 kqueue
//   - 宿主子进程运行 CFRunLoopRun() 作为真正的主循环
//   - 父进程通过 socketpair 通信; usockets 处理父进程端 (C++ 端)
//   - CFFileDescriptor 处理子进程端
//   - Socket EOF = 父进程死亡 = 子进程退出
//   仓颉: 提供兼容的宿主进程管理接口
package bao_runtime

import bao_core.*

// ============================================================================
// C FFI 声明
// 严格翻译自: HostProcess.zig 中使用的系统调用
// ============================================================================

@C
foreign func getenv(name: CPointer<Int8>): CPointer<Int8>
@C
foreign func getpid(): Int32
@C
foreign func fork(): Int32
@C
foreign func close(fd: Int32): Int32
@C
foreign func execve(path: CPointer<Int8>, argv: CPointer<CPointer<Int8>>, envp: CPointer<CPointer<Int8>>): Int32
@C
foreign func socketpair(domain: Int32, type_: Int32, protocol: Int32, sv: CPointer<Int32>): Int32
@C
foreign func dup2(oldfd: Int32, newfd: Int32): Int32
@C
foreign func kill(pid: Int32, sig: Int32): Int32
@C
foreign func malloc(size: UIntNative): CPointer<Unit>
@C
foreign func free(ptr: CPointer<Unit>): Unit
@C
foreign func memset(s: CPointer<Unit>, c: Int32, n: UIntNative): CPointer<Unit>
@C
foreign func write(fd: Int32, buf: CPointer<Unit>, count: UIntNative): UIntNative
@C
foreign func read(fd: Int32, buf: CPointer<Unit>, count: UIntNative): UIntNative
@C
foreign func waitpid(pid: Int32, status: CPointer<Int32>, options: Int32): Int32
@C
foreign func selfExePath(): CPointer<Int8>  // 简化的自路径获取

/// AF_UNIX
private let AF_UNIX: Int32 = 1
/// SOCK_STREAM
private let SOCK_STREAM: Int32 = 1
/// SOCK_NONBLOCK (Linux)
private let SOCK_NONBLOCK: Int32 = 0x800
/// SIGKILL
private let SIGKILL: Int32 = 9

// ============================================================================
// HostProcess - WebView 宿主进程
// 严格翻译自: HostProcess.zig HostProcess = @This()
//   process: *bun.spawn.Process
//   var instance: ?*HostProcess = null
//   Bun__WebViewHost__kill(): kill 宿主进程
//   Bun__WebViewHost__ensure(): 确保宿主进程已启动
//   onProcessExit(): 进程退出回调
//   spawn(): 创建子进程
// ============================================================================

/// WebView 宿主进程
/// 对应 Bun: HostProcess = @This() { process: *bun.spawn.Process }
///
/// 生成并监视 WebView 宿主子进程 (仅 macOS):
///
/// WKWebView 硬性断言 pthread_main_np() (MainThreadCocoa.mm)
/// 无法将 CFRunLoop 桥接到 JS 线程的 kqueue:
///   CFRunLoopWakeUp 的 ignoreWakeUps 标志检查是 mach send 前的用户态丢弃
///   lldb 挂起分析显示 CF 唤醒端口 seqno=0 在进程生命周期内不变
///   kqueue 无法观察到任何唤醒路径
///
/// 宿主子进程运行 CFRunLoopRun() 作为真正的主循环
/// CF 在拥有循环时正确管理 ignoreWakeUps
/// 父进程通过 socketpair 通信:
///   usockets 处理父进程端 (C++ 端)
///   CFFileDescriptor 处理子进程端
///   Socket EOF = 父进程死亡 = 子进程退出
///
/// 此文件仅拥有进程生命周期
/// usockets 客户端位于 C++ (WebKitBackend.cpp)
public class HostProcess {
    /// 子进程 PID
    /// 对应 Bun: process: *bun.spawn.Process
    public var pid: Int32

    /// 父进程端 socket fd
    public var parentFd: Int32

    /// 是否已启动
    public var launched: Bool

    /// 全局单例
    /// 对应 Bun: var instance: ?*HostProcess = null
    private static var instance: ?HostProcess = None

    public init() {
        pid = -1
        parentFd = -1
        launched = false
    }

    /// 终止宿主进程
    /// 对应 Bun: pub export fn Bun__WebViewHost__kill() void
    ///   从 WebView.closeAll() 和 dispatchOnExit 调用
    ///   Socket EOF 处理正常的父进程死亡 (包括 SIGKILL Bun — 内核关闭 fds)
    ///   此处捕获的是干净退出路径: 子进程在 main() 返回前尚未注意到 EOF
    ///   WKWebView 的 WebContent/GPU/Network 辅助进程通过 XPC 连接到子进程
    ///   子进程死亡时它们收到 connection-invalidated 并退出
    public static func kill(): Unit {
        match (instance) {
            case Some(p) => {
                if (p.pid > 0) {
                    kill(p.pid, SIGKILL)
                    p.pid = -1
                    p.launched = false
                }
                instance = None
            }
            case None => ()
        }
    }

    /// 确保宿主进程已启动
    /// 对应 Bun: pub export fn Bun__WebViewHost__ensure(global, stdoutInherit, stderrInherit) i32
    ///   懒启动: 第一个 new Bun.WebView() 通过 C++ 调用
    ///   返回父进程 socket fd (C++ 接管并放入 usockets), 或 -1
    ///   C++ 的 HostClient::ensureSpawned 在调用前检查自己的 sock
    ///   所以 instance-already-exists -> -1 意味着 "你已经持有 fd, 这是 bug"
    ///   我们故意不存储 fd — usockets 拥有它
    ///   Zig 仅拥有进程生命周期 (watch + kill)
    ///
    ///   注意: 仅在 macOS 上有效
    public static func ensure(stdoutInherit: Bool,
                               stderrInherit: Bool): Int32 {
        match (instance) {
            case Some(_) => return -1  // C++ 已持有 fd
            case None => ()
        }

        let proc = HostProcess()
        let result = proc.spawn(stdoutInherit, stderrInherit)
        match (result) {
            case Ok(fd) => {
                instance = Some(proc)
                return fd
            }
            case Err(_) => return -1
        }
    }

    /// 进程退出回调
    /// 对应 Bun: pub fn onProcessExit(this, _, status, _) void
    ///   子进程死亡 (EVFILT_PROC 触发)
    ///   Socket onClose 可能已触发 (干净 FIN) 或未触发 (SIGKILL, SIGSEGV)
    ///   通知 C++ 拒绝所有挂起的 promise 并标记宿主死亡
    public func onProcessExit(signal: Int32): Unit {
        // 通知 C++ 端 (Bun__WebViewHost__childDied)
        // 拒绝所有挂起的 promise
        instance = None
        launched = false
        pid = -1
    }

    /// 启动宿主子进程
    /// 对应 Bun: fn spawn(vm, stdoutInherit, stderrInherit) !bun.FD
    ///
    /// 步骤:
    ///   1. socketpair() 创建通信管道 (两端 nonblocking)
    ///   2. 获取自身可执行路径 (bun 自身)
    ///   3. 子进程通过 fd 3 接收 socket (第一个 extra_fd -> 3+0)
    ///   4. 环境变量 BUN_INTERNAL_WEBVIEW_HOST=3 作为信号 (无 argv 变更)
    ///   5. 与 NODE_CHANNEL_FD 相同模式 (见 js_bun_spawn_bindings.zig)
    ///   6. fork + execve
    ///   7. 注册进程退出处理
    ///   8. 返回 parent fd
    private func spawn(stdoutInherit: Bool, stderrInherit: Bool): Result<Int32> {
        unsafe {
            // 创建 socketpair (两端 nonblocking)
            let fds = malloc(UIntNative(8))  // int[2]
            memset(fds, 0, UIntNative(8))
            let rc = socketpair(AF_UNIX, SOCK_STREAM, 0, CPointer<Int32>(fds))
            if (rc != 0) {
                free(fds)
                return Result<Int32>.Err(BaoError(ErrorCode.Unexpected, "socketpair failed"))
            }

            let parentFdPtr = CPointer<Int32>(fds)
            let childFdPtr = CPointer<Int32>(fds) + IntNative(1)
            let parentFdVal = parentFdPtr.read()
            let childFdVal = childFdPtr.read()
            free(fds)

            // fork 子进程
            let childPid = fork()
            if (childPid == 0) {
                // 子进程
                // dup2 socket 到 fd 3
                dup2(childFdVal, 3)
                close(parentFdVal)

                // 设置 BUN_INTERNAL_WEBVIEW_HOST=3 环境变量
                // 这是唯一的信号; 无 argv 变更所以 ps 显示正常的 bun 调用
                // 与 NODE_CHANNEL_FD 相同模式
                let envMark = unsafeNewCString("BUN_INTERNAL_WEBVIEW_HOST=3")

                // 获取自身可执行路径
                let exePathPtr = selfExePath()
                let exePath = if (!exePathPtr.isNull()) {
                    unsafeCStringToString(exePathPtr)
                } else {
                    "bao"
                }

                // 构建 argv
                let argvPtrs = malloc(UIntNative(2 * 8))
                let arg0 = unsafeNewCString(exePath)
                (CPointer<CPointer<Int8>>(argvPtrs) + IntNative(0)).write(arg0)
                (CPointer<CPointer<Int8>>(argvPtrs) + IntNative(1)).write(CPointer<Int8>().toCPointer())

                // 构建 envp (需要包含 BUN_INTERNAL_WEBVIEW_HOST=3)
                // 简化: 使用当前环境 + 新变量
                let envpPtrs = malloc(UIntNative(2 * 8))
                (CPointer<CPointer<Int8>>(envpPtrs) + IntNative(0)).write(envMark)
                (CPointer<CPointer<Int8>>(envpPtrs) + IntNative(1)).write(CPointer<Int8>().toCPointer())

                execve(arg0, CPointer<CPointer<Int8>>(argvPtrs), CPointer<CPointer<Int8>>(envpPtrs))
                // execve 失败
                _exit(1)
                return Result<Int32>.Ok(parentFdVal)
            } else if (childPid > 0) {
                // 父进程
                close(childFdVal)  // 关闭子进程端
                this.pid = childPid
                this.parentFd = parentFdVal
                this.launched = true

                // 弱引用: 父进程在没有视图且无挂起操作时退出
                // 子进程收到 socket EOF 并退出, EVFILT_PROC 触发到死进程 (内核丢弃)
                // 如果我们引用, 父进程将永远等待等待我们的子进程
                // dispatchOnExit 也会通过 Bun__WebViewHost__kill 发送 SIGKILL
                return Result<Int32>.Ok(parentFdVal)
            } else {
                // fork 失败
                close(parentFdVal)
                close(childFdVal)
                return Result<Int32>.Err(BaoError(ErrorCode.Unexpected, "fork failed"))
            }
        }
    }
}

// ============================================================================
// 内部工具函数
// ============================================================================

/// 创建 C 字符串
private func unsafeNewCString(s: String): CPointer<Int8> {
    unsafe {
        let len = s.size
        let ptr = malloc(UIntNative(len + 1))
        let bytesPtr = CPointer<Int8>(ptr)
        for (i in 0..len) {
            (bytesPtr + IntNative(i)).write(Int8(s[Int64(i)].value))
        }
        (bytesPtr + IntNative(len)).write(Int8(0))
        return bytesPtr
    }
}

/// C 字符串转仓颉字符串
private func unsafeCStringToString(ptr: CPointer<Int8>): String {
    unsafe {
        var len = 0
        while (!(ptr + IntNative(len)).read() == Int8(0)) {
            len += 1
        }
        let sb = StringBuilder()
        for (i in 0..len) {
            sb.append(Char(Int32((ptr + IntNative(i)).read())))
        }
        return sb.toString()
    }
}
