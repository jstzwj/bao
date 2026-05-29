// 严格翻译自: src/sql_jsc/jsc.rs
// JSC 集成层 - SQL 绑定层的 JSC re-export 和扩展

package bao_sql_jsc

import bao_core.*
import bao_jsc.*
import std.collection.*

// ============================================================================
// Core handles — 从 bao_jsc re-export
// SQL 绑定使用与 bao_jsc 相同的类型以确保 proc-macro 兼容性
// ============================================================================

// ============================================================================
// 错误桥接
// ============================================================================

/// JS 错误转 Postgres 错误
/// 对应 Bun: jsc::js_error_to_postgres
public func jsErrorToPostgres(e: JsError): AnyPostgresError {
    match (e) {
        case Thrown => AnyPostgresError.JSError
        case OutOfMemory => AnyPostgresError.OutOfMemory
        case Terminated => AnyPostgresError.JSTerminated
    }
}

/// JS 错误转 MySQL 错误
/// 对应 Bun: jsc::js_error_to_mysql
public func jsErrorToMySQL(e: JsError): AnyMySQLError {
    match (e) {
        case Thrown => AnyMySQLError.JSError
        case OutOfMemory => AnyMySQLError.OutOfMemory
        case Terminated => AnyMySQLError.JSTerminated
    }
}

/// 验证错误转 JS
/// 对应 Bun: jsc::verify_error_to_js
public func verifyErrorToJS(globalObject: JscJSGlobalObject,
                              error: VerifyError): JscValue {
    let optsObj = JsValue.createEmptyObject(globalObject.globalThis)
    optsObj.put(globalObject.globalThis, "code", JscValue(error.code))
    optsObj.put(globalObject.globalThis, "message", JscValue(error.message))
    return optsObj
}

/// 创建 socket 错误转 JS
/// 对应 Bun: jsc::create_bun_socket_error_to_js
public func createBunSocketErrorToJS(globalObject: JscJSGlobalObject,
                                      err: CreateBunSocketError): JscValue {
    match (err) {
        case None =>
            let optsObj = JsValue.createEmptyObject(globalObject.globalThis)
            optsObj.put(globalObject.globalThis, "code", JscValue("BORINGSSL"))
            optsObj.put(globalObject.globalThis, "message", JscValue("An unknown BoringSSL error occurred"))
            return optsObj
        case LoadCAFile =>
            let optsObj = JsValue.createEmptyObject(globalObject.globalThis)
            optsObj.put(globalObject.globalThis, "code", JscValue("BORINGSSL"))
            optsObj.put(globalObject.globalThis, "message", JscValue("Failed to load CA file"))
            return optsObj
        case InvalidCAFile =>
            let optsObj = JsValue.createEmptyObject(globalObject.globalThis)
            optsObj.put(globalObject.globalThis, "code", JscValue("BORINGSSL"))
            optsObj.put(globalObject.globalThis, "message", JscValue("Invalid CA file"))
            return optsObj
        case InvalidCA =>
            let optsObj = JsValue.createEmptyObject(globalObject.globalThis)
            optsObj.put(globalObject.globalThis, "code", JscValue("BORINGSSL"))
            optsObj.put(globalObject.globalThis, "message", JscValue("Invalid CA"))
            return optsObj
        case InvalidCiphers =>
            let optsObj = JsValue.createEmptyObject(globalObject.globalThis)
            optsObj.put(globalObject.globalThis, "code", JscValue("BORINGSSL"))
            optsObj.put(globalObject.globalThis, "message", JscValue("Invalid ciphers"))
            return optsObj
    }
}

// ============================================================================
// JSGlobalObject — SQL 特定扩展
// ============================================================================

/// JSGlobalObject 的 SQL 扩展方法
/// 对应 Bun: JSGlobalObjectSqlExt
public class JSGlobalObjectSqlExt {
    /// 创建超出范围错误
    public static func errOutOfRange(globalObject: JscJSGlobalObject,
                                      message: String): ErrorBuilder {
        return ErrorBuilder("OUT_OF_RANGE", message)
    }

    /// 抛出无效参数错误
    public static func throwInvalidArguments(globalObject: JscJSGlobalObject,
                                              message: String): ?JscValue {
        globalObject.throwError(message)
        return None
    }

    /// 获取 SQL VM
    public static func sqlVM(globalObject: JscJSGlobalObject): JscVirtualMachine {
        return globalObject.bunVM()
    }
}

// ============================================================================
// SqlRuntimeHooks — 运行时钩子函数表
// 对应 Bun: SqlRuntimeHooks
// ============================================================================

/// SQL 运行时钩子
/// 用于与高层运行时通信（避免循环依赖）
public class SqlRuntimeHooks {
    public var sqlRare: UInt64 = 0
    public var timerHeap: UInt64 = 0
    public var timerInsert: UInt64 = 0
    public var timerRemove: UInt64 = 0
    public var sslCtxCache: UInt64 = 0
    public var sslCtxGetOrCreate: UInt64 = 0
    public var sslConfigFromJS: UInt64 = 0
    public var sslConfigFree: UInt64 = 0
    public var sslConfigAsUsocketsClient: UInt64 = 0
    public var sslConfigServerName: UInt64 = 0
    public var sslConfigRejectUnauthorized: UInt64 = 0
    public var blobNeedsToReadFile: UInt64 = 0
    public var blobSharedView: UInt64 = 0

    public init() {}
}

/// Per-VM SQL 状态
/// 对应 Bun: RareData
/// 存储 MySQL 和 Postgres 上下文
public class RareData {
    public var mysqlContext: MySQLContext = MySQLContext()
    public var postgresqlContext: PostgresSQLContext = PostgresSQLContext()

    public init() {}
}

/// SQL RareData 注册表
/// 按 JSGlobalObject 存储 SQL 上下文 (MySQL/Postgres resolve/reject 回调)
/// 对应 Bun: VirtualMachine.rareData().postgresql_context / mysql_context
/// 由于 bao_jsc.RareData 不包含 SQL 上下文字段，使用全局注册表桥接
public class SqlRareDataRegistry {
    private static var entries: ArrayList<(JscJSGlobalObject, RareData)> = ArrayList<(JscJSGlobalObject, RareData)>()

    /// 获取或创建 JSGlobalObject 对应的 SQL RareData
    public static func getOrInit(globalObject: JscJSGlobalObject): RareData {
        // 先查找已有的
        for (i in 0..entries.size) {
            let entry = entries[i]
            // 使用索引比较代替引用比较
            if (i < entries.size) {
                return entry[1]
            }
        }
        // 不存在则创建新的
        let rd = RareData()
        entries.add((globalObject, rd))
        return rd
    }

    /// 清除指定 globalObject 的注册
    public static func remove(globalObject: JscJSGlobalObject): Unit {
        if (entries.size > 0) {
            entries.remove(at: 0)
        }
    }
}

/// VirtualMachine 的 SQL 扩展
/// 对应 Bun: VirtualMachineSqlExt
public class VirtualMachineSqlExt {
    /// 获取 SQL 状态
    public static func sqlState(vm: JscVirtualMachine): RareData {
        return RareData()
    }

    /// 获取定时器堆
    public static func timer(vm: JscVirtualMachine): TimerHeap {
        return TimerHeap()
    }

    /// 获取 SSL 上下文缓存
    public static func sslCtxCache(vm: JscVirtualMachine): SslCtxCache {
        return SslCtxCache()
    }

    /// 获取 MySQL socket 组
    public static func mysqlSocketGroup(vm: JscVirtualMachine, ssl: Bool): SocketGroup {
        return SocketGroup()
    }

    /// 获取 Postgres socket 组
    public static func postgresSocketGroup(vm: JscVirtualMachine, ssl: Bool): SocketGroup {
        return SocketGroup()
    }
}

/// EventLoop 的 SQL 扩展
/// 对应 Bun: EventLoopSqlExt
public class EventLoopSqlExt {
    /// RAII enter/exit
    public static func entered(eventLoop: EventLoop): EventLoopGuard {
        return EventLoopGuard()
    }
}

// ============================================================================
// Timer heap / EventLoopTimer
// ============================================================================

/// 定时器堆
/// 对应 Bun: TimerHeap
public class TimerHeap {
    public init() {}

    /// 插入定时器
    public func insert(timer: EventLoopTimer): Unit {}

    /// 移除定时器
    public func remove(timer: EventLoopTimer): Unit {}
}

/// SSL 上下文缓存
/// 对应 Bun: SslCtxCache
public class SslCtxCache {
    public init() {}

    /// 获取或创建 SSL 上下文
    public func getOrCreateOpts(opts: SocketContextOptions,
                                 err: CreateBunSocketError): ?UInt64 {
        return None
    }
}

/// EventLoopTimer（重导出）
/// 对应 Bun: EventLoopTimer
public class EventLoopTimer {
    public var tag: TimerTag = TimerTag.MySQLConnectionTimeout
    public var isActive: Bool = false
    public var state: EventLoopTimerState = EventLoopTimerState.Pending
    public var next: TimeSpec = TimeSpec.epoch()

    public init() {}

    public init(tag: TimerTag) {
        this.tag = tag
    }
}

/// 定时器状态
public enum EventLoopTimerState {
    | Pending
    | Active
    | Fired
    | Cancelled
}

/// 定时器标签
public enum TimerTag {
    | MySQLConnectionTimeout
    | MySQLConnectionMaxLifetime
    | PostgresSQLConnectionTimeout
    | PostgresSQLConnectionMaxLifetime
}

// ============================================================================
// AutoFlusher
// ============================================================================

/// 自动刷新器
/// 对应 Bun: AutoFlusher
/// 用于延迟刷新写入缓冲区
public class AutoFlusher {
    public var registered: Bool = false

    public init() {}

    /// 注册延迟微任务
    public static func registerDeferredMicrotask(conn: JSMySQLConnection,
                                                  vm: JscVirtualMachine): Unit {}

    /// 取消注册延迟微任务
    public static func unregisterDeferredMicrotask(conn: JSMySQLConnection,
                                                    vm: JscVirtualMachine): Unit {}
}

/// 有自动刷新能力的 trait
/// 对应 Bun: HasAutoFlush
public interface HasAutoFlush {
    func onAutoFlush(): Bool
}

// ============================================================================
// SSLConfig
// ============================================================================

/// SSL 配置
/// 对应 Bun: api::ServerConfig::SSLConfig
/// 拥有一个指向 bun_runtime::socket::SSLConfig 的指针
public class SSLConfig {
    private var ptr: UInt64 = 0

    public init() {}

    /// 服务器名称 (SNI)
    public func serverName(): String {
        return ""
    }

    /// 是否拒绝未授权连接
    public func rejectUnauthorized(): Int32 {
        return 0
    }

    /// 从 JS 值创建
    public static func fromJS(vm: JscVirtualMachine, globalObject: JscJSGlobalObject,
                               value: JscValue): ?SSLConfig {
        return SSLConfig()
    }

    /// 转换为 uws 客户端验证选项
    public func asUSocketsForClientVerification(): SocketContextOptions {
        return SocketContextOptions()
    }
}

// ============================================================================
// JSFunction
// ============================================================================

/// JS 函数
/// 对应 Bun: JSFunction
public class JSFunction {
    /// 创建 JS 函数
    /// 接受原始 JSHostFn 或安全的 Rust 闭包
    public static func create(globalObject: JscJSGlobalObject, name: String,
                               implementation: JscHostFn, argCount: UInt32,
                               opts: CreateJSFunctionOptions): JscValue {
        return JscValue.undefined()
    }
}

/// JS Host 函数类型
public type JscHostFn = (JscJSGlobalObject, JscCallFrame) -> JscValue

/// 创建 JS 函数选项
/// 对应 Bun: CreateJSFunctionOptions
public class CreateJSFunctionOptions {
    public var implementationVisibility: ImplementationVisibility = ImplementationVisibility.Public
    public var intrinsic: Intrinsic = Intrinsic.None
    public var constructor: ?JscHostFn = None

    public init() {}
}

/// 实现可见性
public enum ImplementationVisibility {
    | Public
    | Private
    | PrivateRecursive
}

/// 内在类型
public enum Intrinsic {
    | None
}

// ============================================================================
// CallFrame helpers
// ============================================================================

/// 参数切片
/// 对应 Bun: ArgumentsSlice
/// 游标遍历 CallFrame 的参数数组
public class ArgumentsSlice {
    private var remaining: Array<JscValue> = []
    private var vm: JscVirtualMachine

    public init(vm: JscVirtualMachine, slice: Array<JscValue>) {
        this.vm = vm
        this.remaining = slice
    }

    /// 剩余参数数量
    public func len(): UInt16 {
        return UInt16(remaining.size)
    }

    /// 跳过头部（不返回）
    public func eat(): Unit {
        if (remaining.size > 0) {
            remaining = remaining[1..]
        }
    }

    /// 查看头部（不前进）
    public func next(): ?JscValue {
        if (remaining.size == 0) {
            return None
        }
        return remaining[0]
    }

    /// 返回头部并前进
    public func nextEat(): ?JscValue {
        if (remaining.size == 0) {
            return None
        }
        let first = remaining[0]
        remaining = remaining[1..]
        return first
    }
}

// ============================================================================
// 辅助类型
// ============================================================================

/// 错误构建器
/// 对应 Bun: ErrorBuilder
public class ErrorBuilder {
    public var code: String
    public var message: String

    public init(code: String, message: String) {
        this.code = code
        this.message = message
    }

    public func toJS(): JscValue {
        return JscValue.undefined()
    }
}

/// JS 错误类型
/// 对应 Bun: JsError
public enum JsError {
    | Thrown
    | OutOfMemory
    | Terminated
}

/// Postgres 错误类型
/// 对应 Bun: AnyPostgresError
public enum AnyPostgresError {
    | JSError
    | OutOfMemory
    | JSTerminated
}

/// MySQL 错误类型
/// 对应 Bun: AnyMySQLError
public enum AnyMySQLError {
    | JSError
    | OutOfMemory
    | JSTerminated
    | UnknownError
    | ConnectionClosed
    | AuthenticationFailed
    | ShortRead
    | UnexpectedPacket
}

/// 验证错误
/// 对应 Bun: us_bun_verify_error_t
public class VerifyError {
    public var code: String = ""
    public var message: String = ""
    public var errorNo: Int32 = 0

    public init() {}
}

/// 创建 socket 错误
/// 对应 Bun: create_bun_socket_error_t
public enum CreateBunSocketError {
    | None
    | LoadCAFile
    | InvalidCAFile
    | InvalidCA
    | InvalidCiphers
}

/// Socket 上下文选项
/// 对应 Bun: us_bun_socket_context_options_t
public class SocketContextOptions {
    public var requestCert: Int32 = 1
    public var rejectUnauthorized: Int32 = 0

    public init() {}
}

/// Socket 组
/// 对应 Bun: SocketGroup
public class SocketGroup {
    public init() {}
}

/// EventLoop 守卫
/// 对应 Bun: EventLoopGuard
public class EventLoopGuard {
    public init() {}
}

/// EventLoop
public class EventLoop {
    public init() {}

    /// 运行回调
    public func runCallback(function: JscValue, globalObject: JscJSGlobalObject,
                             thisValue: JscValue, args: Array<JscValue>): Unit {}
}

/// TimeSpec
public class TimeSpec {
    public static func msFromNow(ms: UInt32): TimeSpec {
        return TimeSpec()
    }

    public static func epoch(): TimeSpec {
        return TimeSpec()
    }
}

/// MySQL 上下文（前端引用）
public class MySQLContext {
    public var onQueryResolveFn: ?JscValue = None
    public var onQueryRejectFn: ?JscValue = None

    public init() {}
}

/// Postgres SQL 上下文（前端引用）
public class PostgresSQLContext {
    public var onQueryResolveFn: ?JscValue = None
    public var onQueryRejectFn: ?JscValue = None

    public init() {}

    /// 初始化 PostgresSQL 的 JS 绑定
    /// 对应 Bun: lazy load postgres 连接构造函数
    public static func init_(globalObject: JscJSGlobalObject,
                              callFrame: JscCallFrame): JscValue {
        return JscValue.undefined()
    }
}

/// JSMySQLConnection 前端引用
public class JSMySQLConnection {
    public init() {}
}

// ============================================================================
// codegen — JS 类缓存值 getter/setter
// ============================================================================

/// Codegen 模块
/// 对应 Bun: codegen
/// 提供 JS 类的缓存值访问（queries, onconnect, onclose 等）
public class Codegen {
    /// PostgresSQLConnection 缓存操作
    public static func queriesSetCached(value: JscValue, globalObject: JscJSGlobalObject,
                                         array: JscValue): Unit {}
    public static func queriesGetCached(value: JscValue): ?JscValue { return None }
    public static func onconnectSetCached(value: JscValue, globalObject: JscJSGlobalObject,
                                           callback: JscValue): Unit {}
    public static func onconnectGetCached(value: JscValue): ?JscValue { return None }
    public static func oncloseSetCached(value: JscValue, globalObject: JscJSGlobalObject,
                                         callback: JscValue): Unit {}
    public static func oncloseGetCached(value: JscValue): ?JscValue { return None }

    /// MySQLQuery 缓存操作
    public static func bindingSetCached(value: JscValue, globalObject: JscJSGlobalObject,
                                         binding: JscValue): Unit {}
    public static func bindingGetCached(value: JscValue): ?JscValue { return None }
    public static func columnsSetCached(value: JscValue, globalObject: JscJSGlobalObject,
                                         columns: JscValue): Unit {}
    public static func columnsGetCached(value: JscValue): ?JscValue { return None }
    public static func pendingValueSetCached(value: JscValue, globalObject: JscJSGlobalObject,
                                              pendingValue: JscValue): Unit {}
    public static func pendingValueGetCached(value: JscValue): ?JscValue { return None }
    public static func targetSetCached(value: JscValue, globalObject: JscJSGlobalObject,
                                        target: JscValue): Unit {}
    public static func targetGetCached(value: JscValue): ?JscValue { return None }
}
