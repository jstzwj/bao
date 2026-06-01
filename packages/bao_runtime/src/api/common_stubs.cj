// bao_runtime.api 公共 stub 类型
// 子包隔离导致无法直接引用 bao_runtime.webcore/bao_runtime.node 中的类型
// 此文件集中定义所有需要的 stub 类型
package bao_runtime.api

import bao_jsc.{JsGlobalObject, JsValue, CallFrame, BunVirtualMachine}
import bao_core.{Allocator, Output}
import bao_collections.{ArrayList, HashMap}

// 缺失的类型桥接
public type JsCallFrame = CallFrame
public type VirtualMachine = BunVirtualMachine

// ============================================================================
// ArrayBufferStrong — ArrayBuffer 强引用
// 对应 Bun: jsc.ArrayBuffer.Strong
// TODO(bao-runtime-api): 接入 JSC ArrayBuffer 绑定后替换为真实实现
// ============================================================================
public class ArrayBufferStrong {
    private var buffer: Array<UInt8>

    public init() {
        buffer = []
    }

    public init(buffer: Array<UInt8>) {
        this.buffer = buffer
    }

    /// 获取底层 ArrayBuffer (自引用 stub)
    public func getArrayBuffer(): ArrayBufferStrong { this }

    /// 获取字节切片 (副本)
    public func byteSlice(): Array<UInt8> { buffer }

    /// 获取字节切片 (副本)
    public func slice(): Array<UInt8> { buffer }

    /// 获取字节长度
    public func byteLength(): Int64 { Int64(buffer.size) }

    /// 释放引用
    public func deinit(): Unit {
        buffer = []
    }
}

// ============================================================================
// ReadableStream — 可读流
// 对应 Bun: jsc.WebCore.ReadableStream
// TODO(bao-runtime-api): 接入 WebCore.ReadableStream 绑定后替换
// ============================================================================
public class ReadableStream {
    private var disturbed: Bool

    public init() {
        disturbed = false
    }

    /// 从 JS 值创建 ReadableStream
    // 对应 Bun: ReadableStream.fromJS()
    public static func fromJS(value: JsValue, globalThis: JsGlobalObject): ?ReadableStream {
        if (value.isEmptyOrUndefinedOrNull()) {
            return None
        }
        // TODO(bao-runtime-api): 接入真实 JS ReadableStream 提取逻辑
        return None
    }

    /// 流是否已被扰动 (已读取/已取消)
    public func isDisturbed(globalThis: JsGlobalObject): Bool { disturbed }

    /// 取消流
    public func cancel(globalThis: JsGlobalObject): Unit {
        disturbed = true
    }
}

// ============================================================================
// UvPipe — libuv 管道
// 对应 Bun: bun.io.UvPipe (包装 uv_pipe_t)
// TODO(bao-runtime-api): 接入 libuv 管道绑定后替换
// ============================================================================
public class UvPipe {
    public init() {}
}

// ============================================================================
// Mutex — 互斥锁
// 对应 Bun: bun.Mutex (std.Thread.Mutex 的包装)
// TODO(bao-runtime-api): 接入 Cangjie threading.Mutex 后替换
// ============================================================================
public class Mutex {
    public init() {}
    public func lock(): Unit {}
    public func unlock(): Unit {}
}

// ============================================================================
// WriterRefCount — 写入器引用计数
// 对应 Bun: bun.io.WriterRefCount
// TODO(bao-runtime-api): 接入 IO 子系统后替换
// ============================================================================
public class WriterRefCount {
    public init() {}
}

// ============================================================================
// Result — 通用结果类型
// 对应 Bun 中的各种 Result 类型
// TODO(bao-runtime-api): 根据实际使用场景替换为具体类型
// ============================================================================
public class Result { public init() {} }

// ============================================================================
// StdioPipeItem — Stdio 管道项
// 对应 Bun: bun.spawn.StdioPipe
// TODO(bao-runtime-api): 接入子进程 stdio 管道后替换
// ============================================================================
public class StdioPipeItem { public init() {} }

// ============================================================================
// IPCDecodedIPCMessage — IPC 解码消息
// 对应 Bun: bun.IPC.DecodedIPCMessage
// TODO(bao-runtime-api): 接入 IPC 子系统后替换
// ============================================================================
public class IPCDecodedIPCMessage { public init() {} }

// ============================================================================
// SpawnStdio — 子进程 Stdio 配置
// 对应 Bun: bun.spawn.Stdio
// TODO(bao-runtime-api): 接入 spawn stdio 配置后替换
// ============================================================================
public class SpawnStdio { public init() {} }

// ============================================================================
// EventLoop — 事件循环
// 对应 Bun: bun.JSC.EventLoop
// TODO(bao-runtime-api): 接入 JSC 事件循环绑定后替换
// ============================================================================
public class EventLoop {
    public init() {}

    public static func enterScope(eventLoop!: EventLoop): EventLoopScope {
        EventLoopScope()
    }
}

// ============================================================================
// EventLoopScope — 事件循环作用域
// 对应 Bun: bun.JSC.EventLoop.Scope
// TODO(bao-runtime-api): 接入 JSC 事件循环绑定后替换
// ============================================================================
public class EventLoopScope {
    public init() {}
    public func deinit(): Unit {}
}

// ============================================================================
// BackRef — 回引 (非拥有指针的反向引用)
// 对应 Bun: bun.ptr.BackRef(T)
// 用于从子对象安全地引用回父对象, 防止悬空指针
// ============================================================================
public class BackRef<T> {
    public var value: ?T = None

    public init() {}

    public init(value!: T) {
        this.value = Some(value)
    }

    /// 从值创建 BackRef
    public static func from(value!: T): BackRef<T> {
        BackRef<T>(value: value)
    }

    /// 获取引用的值 (如果存在)
    public func get(): ?T {
        value
    }

    /// 获取引用的值 (断言存在)
    public func getOrThrow(): T {
        value.getOrThrow()
    }

    /// 创建指针形式
    public func asPtr(): BackRefPtr<T> {
        BackRefPtr<T>(value: getOrThrow())
    }
}

// ============================================================================
// BackRefPtr — BackRef 的指针形式
// ============================================================================
public class BackRefPtr<T> {
    public var pointee: T

    public init(value!: T) {
        pointee = value
    }
}

// ============================================================================
// JSPromiseStrong — JS Promise 强引用
// 对应 Bun: jsc.JSPromise.Strong
// TODO(bao-runtime-api): 接入 JSC Promise 绑定后替换
// ============================================================================
public class JSPromiseStrong {
    private var promiseValue: JsValue

    public init() {
        promiseValue = JsValue.jsUndefined()
    }

    public init(globalThis: JsGlobalObject) {
        promiseValue = JsValue.jsUndefined()
    }

    public static func default(): JSPromiseStrong { JSPromiseStrong() }

    /// 获取 Promise 的当前值
    public func getValue(): JsValue { promiseValue }

    /// 解析 Promise
    public func resolve(globalThis: JsGlobalObject, value: JsValue): Unit {
        promiseValue = value
    }

    /// 拒绝 Promise
    public func reject(globalThis: JsGlobalObject, reason: JsValue): Unit {
        promiseValue = reason
    }
}

// ============================================================================
// IPCSendQueue — IPC 发送队列
// 对应 Bun: bun.IPC.SendQueue
// TODO(bao-runtime-api): 接入 IPC 子系统后替换
// ============================================================================
public class IPCSendQueue {
    public init() {}
    public func closeSocketNextTick(nextTick: Bool): Unit {}
    public func deinit(): Unit {}
}

// ============================================================================
// AbortSignal — 中止信号
// 对应 Bun: webcore.AbortSignal
// TODO(bao-runtime-api): 接入 WebCore.AbortSignal 后替换
// ============================================================================
public class AbortSignal {
    private var aborted: Bool

    public init() {
        aborted = false
    }

    /// 标记为已中止
    public func abort(): Unit {
        aborted = true
    }

    /// 是否已中止
    public func isAborted(): Bool {
        aborted
    }

    public func pendingActivityUnref(): Unit {}
    public func cleanNativeBindings(ctx: Any): Unit {}
    public func unref(): Unit {}
    public func addListener(ctx: Any, callback: Any): AbortSignal { this }
}

// ============================================================================
// ApiStringBuilder — API 字符串构建器
// 对应 Bun: bun.api.Strings.Builder
// 用于构建返回给 JS 的字符串, 避免多次 JS 分配
// ============================================================================
public class ApiStringBuilder {
    private var parts: ArrayList<String> = ArrayList<String>()
    public init() {}
    public func append(s: String): Unit {
        parts.append(s)
    }
    public func appendChar(c: UInt8): Unit {
        parts.append(String(Rune(c)))
    }
    public func appendChar(c: Rune): Unit {
        parts.append(String(c))
    }

    /// 追加格式化字符串
    // 对应 Bun: bun.String.Builder.appendFormat
    public func appendFormat(fmt: String, value: String): Unit {
        // 简化: 替换 {} 占位符
        var result = fmt
        result = result.replace("{}", value)
        parts.append(result)
    }

    public func ensureUnusedCapacity(additional: Int64): Unit {}

    /// 转为 JS 字符串
    public func toString(globalThis: JsGlobalObject): JsValue {
        var out = ""
        for (part in parts) {
            out += part
        }
        return JsValue.jsString(out)
    }

    /// 转为普通字符串
    public func toString(): String {
        var out = ""
        for (part in parts) {
            out += part
        }
        out
    }

    public func deinit(): Unit {
        parts.clear()
    }
}

// ============================================================================
// Strings — 字符串工具
// 对应 Bun: bun.api.Strings
// ============================================================================
public class Strings {
    public static func eqlComptime(input!: String, expected!: String): Bool {
        return input == expected
    }

    public static func hasPrefixComptime(input!: String, prefix!: String): Bool {
        return input.startsWith(prefix)
    }

    public static func withoutTrailingSlashWindowsPath(input!: String): String {
        return input
    }

    public static func trimLeft(input!: Array<UInt8>, chars!: String): Array<UInt8> {
        var start: Int64 = 0
        while (start < input.size) {
            let c = input[start]
            if (chars == "/" && c == UInt8(47)) {
                start++
                continue
            }
            break
        }
        return input[start..input.size]
    }
}

// ============================================================================
// WaitPidResult — waitpid 返回结果
// 对应 Bun: bun.spawn.PosixSpawn.WaitPidResult
// ============================================================================
public class WaitPidResult {
    public var pid: Int32 = 0
    public var status: UInt32 = 0

    public init() {}

    public init(pid: Int32, status: UInt32) {
        this.pid = pid
        this.status = status
    }

    /// 从 waitpid 的原始 status 值构造
    // 对应 Bun: waitpid 返回值的解析
    // status 的低 16 位是 pid, 高 16 位中的低 8 位是退出码
    public static func fromRawStatus(rawStatus: Int32): WaitPidResult {
        WaitPidResult(
            Int32(rawStatus & 0xFFFF),
            UInt32((rawStatus >> 16) & 0xFF)
        )
    }

    /// 是否正常退出
    public func isExited(): Bool {
        // WIFEXITED: (status & 0x7f) == 0
        (status & 0x7F) == 0
    }

    /// 获取退出码 (仅当 isExited 为 true 时有意义)
    public func exitCode(): Int32 {
        // WEXITSTATUS: (status >> 8) & 0xff
        Int32((status >> 8) & 0xFF)
    }

    /// 是否被信号终止
    public func isSignaled(): Bool {
        // WIFSIGNALED: ((status & 0x7f) + 1) >> 1 > 0
        ((status & 0x7F) + 1) >> 1 > 0
    }

    /// 获取终止信号编号 (仅当 isSignaled 为 true 时有意义)
    public func termSignal(): Int32 {
        // WTERMSIG: status & 0x7f
        Int32(status & 0x7F)
    }
}

// ============================================================================
// FD — 文件描述符
// 对应 Bun: bun.FD (packed struct)
// 包装系统文件描述符, 提供统一的跨平台接口
// ============================================================================
public class FD {
    public var value: Int32 = 0

    public init(value: Int32) { this.value = value }

    /// 获取原生文件描述符值
    // 对应 Bun: FD.native()
    public func native(): Int32 { value }

    /// 获取原生文件描述符值 (已弃用, 使用 native)
    // 对应 Bun: FD.cast() (deprecated alias)
    public func cast(): Int32 { value }

    /// 关闭文件描述符
    // 对应 Bun: FD.close()
    public func close(): Unit {
        if (value >= 0) {
            // TODO(bao-runtime-api): 调用系统 close()
            value = -1
        }
    }

    /// 返回自身
    public func toFd(): FD { this }

    /// 转为 JS 数值
    public func toJS(globalThis!: JsGlobalObject): JsValue { JsValue.jsNumber(Int64(value)) }

    /// 是否有效
    // 对应 Bun: FD.isValid()
    public func isValid(): Bool { value >= 0 }

    /// 判断是否为标准流
    public func stdioTag(): ?FDStdio { FDStdio.fromInt(i: value) }

    public operator func ==(right: FD): Bool { value == right.value }
    public operator func !=(right: FD): Bool { value != right.value }

    /// 无效文件描述符
    // 对应 Bun: FD.invalid
    public static let invalid: FD = FD(-1)

    /// 标准输入
    // 对应 Bun: FD.stdin()
    public static func stdin(): FD { FD(0) }

    /// 标准输出
    // 对应 Bun: FD.stdout()
    public static func stdout(): FD { FD(1) }

    /// 标准错误
    // 对应 Bun: FD.stderr()
    public static func stderr(): FD { FD(2) }

    /// 从原生文件描述符创建
    // 对应 Bun: FD.fromNative()
    public static func fromNative(fd: Int32): FD { FD(fd) }

    public static let Stdio: FDStdioHelper = FDStdioHelper()
}

// ============================================================================
// FDStdio — 标准流类型
// ============================================================================
public enum FDStdio { | std_in | std_out | std_err
    public static func fromInt(i!: Int32): ?FDStdio {
        match (i) {
            case 0 => Some(FDStdio.std_in)
            case 1 => Some(FDStdio.std_out)
            case 2 => Some(FDStdio.std_err)
            case _ => None
        }
    }
    public func fd(): FD {
        match (this) {
            case std_in => FD(0)
            case std_out => FD(1)
            case std_err => FD(2)
        }
    }
}

public class FDStdioHelper {
    public init() {}
    public func fromInt(i!: Int32): ?FDStdio { FDStdio.fromInt(i: i) }
}

// ============================================================================
// EventLoopHandle — 事件循环句柄
// 对应 Bun: EventLoopHandle (opaque pointer)
// 在 Bun 中持有事件循环的非拥有引用, 用于 ref/unref 操作
// TODO(bao-runtime-api): 接入真实事件循环后替换为持有 loop 指针的实现
// ============================================================================
public class EventLoopHandle {
    private var loopPtr: Int64

    public init() {
        loopPtr = 0
    }

    public init(loopPtr: Int64) {
        this.loopPtr = loopPtr
    }

    /// 保持事件循环活跃
    public func ref(): Unit {}

    /// 允许事件循环退出
    public func unref(): Unit {}

    /// 获取底层循环指针
    public func loop_(): Int64 { loopPtr }

    /// 设置底层循环指针
    public func setLoop(ptr: Int64): Unit {
        loopPtr = ptr
    }
}

// ============================================================================
// JsRef — JS 值引用句柄
// 对应 Bun: jsc.JsRef
// 用于跨线程/异步操作中保持对 JS 值的引用
// TODO(bao-runtime-api): 接入 JSC 保护/释放机制后替换
// ============================================================================
public class JsRef {
    private var value: ?JsValue

    public init() {
        value = None
    }

    public init(value: JsValue) {
        this.value = Some(value)
    }

    /// 创建空引用
    public static func empty(): JsRef { JsRef() }

    /// 创建强引用
    public static func initStrong(value!: JsValue, globalThis!: JsGlobalObject): JsRef {
        JsRef(value)
    }

    /// 创建弱引用
    public static func initWeak(value!: JsValue, globalThis!: JsGlobalObject): JsRef {
        JsRef(value)
    }

    /// 获取引用的值
    public func get(): JsValue {
        match (value) {
            case Some(v) => v
            case None => JsValue.jsUndefined()
        }
    }

    /// 尝试获取引用的值
    public func tryGet(): ?JsValue { value }

    /// 清除引用
    public func clear(): Unit {
        value = None
    }

    /// 释放引用 (JSC unprotect)
    public func finalize(): Unit {
        value = None
    }

    /// 升级为强引用
    public func upgrade(globalThis!: JsGlobalObject): Unit {}

    /// 降级为弱引用
    public func downgrade(): Unit {}

    /// 更新引用的值
    public func update(globalThis!: JsGlobalObject, value!: JsValue): Unit {
        this.value = Some(value)
    }

    /// 确保引用仍然有效
    public func ensureStillAlive(): Unit {}
}
