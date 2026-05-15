// 严格翻译自: src/runtime/server/InspectorBunFrontendDevServerAgent.zig
// Inspector Bun 前端开发服务器代理 - 用于通知 Inspector 关于开发服务器事件
package bao_runtime

import bao_core.*
import bao_jsc.*

// ============================================================================
// InspectorBunFrontendDevServerAgentHandle - C 端不透明句柄
// 严格翻译自: InspectorBunFrontendDevServerAgentHandle (opaque)
// Bun: const InspectorBunFrontendDevServerAgentHandle = opaque { ... }
// ============================================================================

/// InspectorBunFrontendDevServerAgentHandle - C 端句柄
/// 对应 Bun: opaque 类型，包含 C 外部函数声明
public open class InspectorBunFrontendDevServerAgentHandle {
    /// 底层 native 指针
    public var nativeHandle: UIntNative = 0

    public init() {}

    public init(handle: UIntNative) {
        nativeHandle = handle
    }

    // ========================================================================
    // C 外部函数绑定
    // 严格翻译自: extern "c" fn InspectorBunFrontendDevServerAgent__*
    // ========================================================================

    /// 通知客户端已连接
    /// 对应 Bun: InspectorBunFrontendDevServerAgent__notifyClientConnected
    public func notifyClientConnected(devServerId: Int32, connectionId: Int32): Unit {
        InspectorNative.notifyClientConnected(nativeHandle, devServerId, connectionId)
    }

    /// 通知客户端已断开
    /// 对应 Bun: InspectorBunFrontendDevServerAgent__notifyClientDisconnected
    public func notifyClientDisconnected(devServerId: Int32, connectionId: Int32): Unit {
        InspectorNative.notifyClientDisconnected(nativeHandle, devServerId, connectionId)
    }

    /// 通知打包开始
    /// 对应 Bun: InspectorBunFrontendDevServerAgent__notifyBundleStart
    public func notifyBundleStart(devServerId: Int32, triggerFiles: Array<BaoString>, triggerFilesLen: UIntNative): Unit {
        InspectorNative.notifyBundleStart(nativeHandle, devServerId, triggerFiles, triggerFilesLen)
    }

    /// 通知打包完成
    /// 对应 Bun: InspectorBunFrontendDevServerAgent__notifyBundleComplete
    public func notifyBundleComplete(devServerId: Int32, durationMs: Float64): Unit {
        InspectorNative.notifyBundleComplete(nativeHandle, devServerId, durationMs)
    }

    /// 通知打包失败
    /// 对应 Bun: InspectorBunFrontendDevServerAgent__notifyBundleFailed
    public func notifyBundleFailed(devServerId: Int32, buildErrorsPayloadBase64: BaoString): Unit {
        InspectorNative.notifyBundleFailed(nativeHandle, devServerId, buildErrorsPayloadBase64)
    }

    /// 通知客户端导航
    /// 对应 Bun: InspectorBunFrontendDevServerAgent__notifyClientNavigated
    public func notifyClientNavigated(devServerId: Int32, connectionId: Int32, url: BaoString, routeBundleId: Int32): Unit {
        InspectorNative.notifyClientNavigated(nativeHandle, devServerId, connectionId, url, routeBundleId)
    }

    /// 通知客户端错误已报告
    /// 对应 Bun: InspectorBunFrontendDevServerAgent__notifyClientErrorReported
    public func notifyClientErrorReported(devServerId: Int32, clientErrorPayloadBase64: BaoString): Unit {
        InspectorNative.notifyClientErrorReported(nativeHandle, devServerId, clientErrorPayloadBase64)
    }

    /// 通知图更新
    /// 对应 Bun: InspectorBunFrontendDevServerAgent__notifyGraphUpdate
    public func notifyGraphUpdate(devServerId: Int32, visualizerPayloadBase64: BaoString): Unit {
        InspectorNative.notifyGraphUpdate(nativeHandle, devServerId, visualizerPayloadBase64)
    }

    /// 通知控制台日志
    /// 对应 Bun: InspectorBunFrontendDevServerAgent__notifyConsoleLog
    public func notifyConsoleLog(devServerId: Int32, kind: UInt8, data: BaoString): Unit {
        InspectorNative.notifyConsoleLog(nativeHandle, devServerId, kind, data)
    }
}

// ============================================================================
// ConsoleLogKind - 控制台日志类型
// 严格翻译自: bun.bake.DevServer.ConsoleLogKind (u8 enum)
// Bun: pub const ConsoleLogKind = enum(u8) { ... }
// ============================================================================

/// 控制台日志类型
/// 对应 Bun: bun.bake.DevServer.ConsoleLogKind
public enum ConsoleLogKind {
    | Log
    | Warn
    | Error
    | Info
    | Debug
    | Trace

    /// 转为 UInt8
    /// 对应 Bun: @intFromEnum(kind)
    public func toUInt8(): UInt8 {
        match (this) {
            case Log => 0
            case Warn => 1
            case Error => 2
            case Info => 3
            case Debug => 4
            case Trace => 5
        }
    }

    /// 从 UInt8 创建
    public static func fromUInt8(v: UInt8): ConsoleLogKind {
        match (v) {
            case 0 => Log
            case 1 => Warn
            case 2 => Error
            case 3 => Info
            case 4 => Debug
            case 5 => Trace
            case _ => Log
        }
    }
}

// ============================================================================
// BunFrontendDevServerAgent - Bun 前端开发服务器代理
// 严格翻译自: BunFrontendDevServerAgent struct
// Bun: pub const BunFrontendDevServerAgent = struct { ... }
// ============================================================================

/// Bun 前端开发服务器代理
/// 对应 Bun: pub const BunFrontendDevServerAgent = struct { ... }
/// 负责将开发服务器事件（客户端连接/断开、打包开始/完成/失败、导航、错误等）
/// 转发给 Inspector 前端
public class BunFrontendDevServerAgent {
    /// 下一个 Inspector 连接 ID
    /// 对应 Bun: next_inspector_connection_id: i32 = 0
    public var nextInspectorConnectionId: Int32 = 0

    /// Inspector 句柄 (null 表示未启用)
    /// 对应 Bun: handle: ?*InspectorBunFrontendDevServerAgentHandle = null
    public var handle: ?InspectorBunFrontendDevServerAgentHandle = None

    public init() {}

    public init(handle: InspectorBunFrontendDevServerAgentHandle) {
        this.handle = Some(handle)
    }

    // ========================================================================
    // nextConnectionID - 获取下一个连接 ID
    // 严格翻译自: pub fn nextConnectionID(this: *BunFrontendDevServerAgent) i32
    // ========================================================================

    /// 获取下一个连接 ID
    /// 对应 Bun: pub fn nextConnectionID(this: *BunFrontendDevServerAgent) i32
    /// Bun 使用 wrapping add (%+)
    public func nextConnectionID(): Int32 {
        let id = nextInspectorConnectionId
        nextInspectorConnectionId = nextInspectorConnectionId &+ 1
        return id
    }

    // ========================================================================
    // isEnabled - 检查代理是否启用
    // 严格翻译自: pub fn isEnabled(this: *const BunFrontendDevServerAgent) bool
    // ========================================================================

    /// 检查代理是否已启用
    /// 对应 Bun: pub fn isEnabled(this: *const BunFrontendDevServerAgent) bool
    public func isEnabled(): Bool {
        match (handle) {
            case Some(_) => true
            case None => false
        }
    }

    // ========================================================================
    // notifyClientConnected - 通知客户端连接
    // 严格翻译自: pub fn notifyClientConnected(this, devServerId, connectionId) void
    // ========================================================================

    /// 通知客户端已连接
    /// 对应 Bun: pub fn notifyClientConnected(this: *const BunFrontendDevServerAgent, devServerId: DebuggerId, connectionId: i32) void
    public func notifyClientConnected(devServerId: Int32, connectionId: Int32): Unit {
        match (handle) {
            case Some(h) => h.notifyClientConnected(devServerId, connectionId)
            case None => ()
        }
    }

    // ========================================================================
    // notifyClientDisconnected - 通知客户端断开
    // 严格翻译自: pub fn notifyClientDisconnected(this, devServerId, connectionId) void
    // ========================================================================

    /// 通知客户端已断开连接
    /// 对应 Bun: pub fn notifyClientDisconnected(this: *const BunFrontendDevServerAgent, devServerId: DebuggerId, connectionId: i32) void
    public func notifyClientDisconnected(devServerId: Int32, connectionId: Int32): Unit {
        match (handle) {
            case Some(h) => h.notifyClientDisconnected(devServerId, connectionId)
            case None => ()
        }
    }

    // ========================================================================
    // notifyBundleStart - 通知打包开始
    // 严格翻译自: pub fn notifyBundleStart(this, devServerId, triggerFiles) void
    // ========================================================================

    /// 通知打包开始
    /// 对应 Bun: pub fn notifyBundleStart(this: *const BunFrontendDevServerAgent, devServerId: DebuggerId, triggerFiles: []bun.String) void
    public func notifyBundleStart(devServerId: Int32, triggerFiles: Array<BaoString>): Unit {
        match (handle) {
            case Some(h) => h.notifyBundleStart(devServerId, triggerFiles, triggerFiles.size)
            case None => ()
        }
    }

    // ========================================================================
    // notifyBundleComplete - 通知打包完成
    // 严格翻译自: pub fn notifyBundleComplete(this, devServerId, durationMs) void
    // ========================================================================

    /// 通知打包完成
    /// 对应 Bun: pub fn notifyBundleComplete(this: *const BunFrontendDevServerAgent, devServerId: DebuggerId, durationMs: f64) void
    public func notifyBundleComplete(devServerId: Int32, durationMs: Float64): Unit {
        match (handle) {
            case Some(h) => h.notifyBundleComplete(devServerId, durationMs)
            case None => ()
        }
    }

    // ========================================================================
    // notifyBundleFailed - 通知打包失败
    // 严格翻译自: pub fn notifyBundleFailed(this, devServerId, buildErrorsPayloadBase64) void
    // ========================================================================

    /// 通知打包失败
    /// 对应 Bun: pub fn notifyBundleFailed(this: *const BunFrontendDevServerAgent, devServerId: DebuggerId, buildErrorsPayloadBase64: *bun.String) void
    public func notifyBundleFailed(devServerId: Int32, buildErrorsPayloadBase64: BaoString): Unit {
        match (handle) {
            case Some(h) => h.notifyBundleFailed(devServerId, buildErrorsPayloadBase64)
            case None => ()
        }
    }

    // ========================================================================
    // notifyClientNavigated - 通知客户端导航
    // 严格翻译自: pub fn notifyClientNavigated(this, devServerId, connectionId, url, routeBundleId) void
    // ========================================================================

    /// 通知客户端导航
    /// 对应 Bun: pub fn notifyClientNavigated(this: *const BunFrontendDevServerAgent, devServerId: DebuggerId, connectionId: i32, url: *bun.String, routeBundleId: ?DevServer.RouteBundle.Index) void
    /// routeBundleId 为 null 时传 -1
    public func notifyClientNavigated(devServerId: Int32, connectionId: Int32, url: BaoString, routeBundleId: ?Int32): Unit {
        match (handle) {
            case Some(h) => {
                let bundleId: Int32 = match (routeBundleId) {
                    case Some(id) => id
                    case None => -1
                }
                h.notifyClientNavigated(devServerId, connectionId, url, bundleId)
            }
            case None => ()
        }
    }

    // ========================================================================
    // notifyClientErrorReported - 通知客户端错误已报告
    // 严格翻译自: pub fn notifyClientErrorReported(this, devServerId, clientErrorPayloadBase64) void
    // ========================================================================

    /// 通知客户端错误已报告
    /// 对应 Bun: pub fn notifyClientErrorReported(this: *const BunFrontendDevServerAgent, devServerId: DebuggerId, clientErrorPayloadBase64: *bun.String) void
    public func notifyClientErrorReported(devServerId: Int32, clientErrorPayloadBase64: BaoString): Unit {
        match (handle) {
            case Some(h) => h.notifyClientErrorReported(devServerId, clientErrorPayloadBase64)
            case None => ()
        }
    }

    // ========================================================================
    // notifyGraphUpdate - 通知依赖图更新
    // 严格翻译自: pub fn notifyGraphUpdate(this, devServerId, visualizerPayloadBase64) void
    // ========================================================================

    /// 通知依赖图更新
    /// 对应 Bun: pub fn notifyGraphUpdate(this: *const BunFrontendDevServerAgent, devServerId: DebuggerId, visualizerPayloadBase64: *bun.String) void
    public func notifyGraphUpdate(devServerId: Int32, visualizerPayloadBase64: BaoString): Unit {
        match (handle) {
            case Some(h) => h.notifyGraphUpdate(devServerId, visualizerPayloadBase64)
            case None => ()
        }
    }

    // ========================================================================
    // notifyConsoleLog - 通知控制台日志
    // 严格翻译自: pub fn notifyConsoleLog(this, devServerId, kind, data) void
    // ========================================================================

    /// 通知控制台日志
    /// 对应 Bun: pub fn notifyConsoleLog(this: BunFrontendDevServerAgent, devServerId: DebuggerId, kind: bun.bake.DevServer.ConsoleLogKind, data: *bun.String) void
    public func notifyConsoleLog(devServerId: Int32, kind: ConsoleLogKind, data: BaoString): Unit {
        match (handle) {
            case Some(h) => h.notifyConsoleLog(devServerId, kind.toUInt8(), data)
            case None => ()
        }
    }

    // ========================================================================
    // setEnabled - 导出函数：设置代理启用状态
    // 严格翻译自: export fn Bun__InspectorBunFrontendDevServerAgent__setEnabled(agent) void
    // ========================================================================

    /// 设置代理为启用状态
    /// 对应 Bun: export fn Bun__InspectorBunFrontendDevServerAgent__setEnabled(agent: ?*InspectorBunFrontendDevServerAgentHandle) void
    /// 当 C 端调用时，将 handle 设置到虚拟机的 debugger 中
    public static func setEnabled(agent: ?InspectorBunFrontendDevServerAgentHandle): Unit {
        let vm = VirtualMachine.get()
        match (vm.debugger) {
            case Some(debugger) => {
                debugger.frontendDevServerAgent.handle = agent
            }
            case None => ()
        }
    }
}

// ============================================================================
// InspectorNative - 底层原生函数接口
// 严格翻译自: InspectorBunFrontendDevServerAgentHandle.c 中的 extern "c" 函数
// ============================================================================

/// Inspector 原生函数接口
/// 对应 Bun: InspectorBunFrontendDevServerAgentHandle.c 中的 extern 函数
public class InspectorNative {
    /// 通知客户端已连接
    public static func notifyClientConnected(agent: UIntNative, devServerId: Int32, connectionId: Int32): Unit {
        // FFI: InspectorBunFrontendDevServerAgent__notifyClientConnected
    }

    /// 通知客户端已断开
    public static func notifyClientDisconnected(agent: UIntNative, devServerId: Int32, connectionId: Int32): Unit {
        // FFI: InspectorBunFrontendDevServerAgent__notifyClientDisconnected
    }

    /// 通知打包开始
    public static func notifyBundleStart(agent: UIntNative, devServerId: Int32, triggerFiles: Array<BaoString>, triggerFilesLen: UIntNative): Unit {
        // FFI: InspectorBunFrontendDevServerAgent__notifyBundleStart
    }

    /// 通知打包完成
    public static func notifyBundleComplete(agent: UIntNative, devServerId: Int32, durationMs: Float64): Unit {
        // FFI: InspectorBunFrontendDevServerAgent__notifyBundleComplete
    }

    /// 通知打包失败
    public static func notifyBundleFailed(agent: UIntNative, devServerId: Int32, buildErrorsPayloadBase64: BaoString): Unit {
        // FFI: InspectorBunFrontendDevServerAgent__notifyBundleFailed
    }

    /// 通知客户端导航
    public static func notifyClientNavigated(agent: UIntNative, devServerId: Int32, connectionId: Int32, url: BaoString, routeBundleId: Int32): Unit {
        // FFI: InspectorBunFrontendDevServerAgent__notifyClientNavigated
    }

    /// 通知客户端错误已报告
    public static func notifyClientErrorReported(agent: UIntNative, devServerId: Int32, clientErrorPayloadBase64: BaoString): Unit {
        // FFI: InspectorBunFrontendDevServerAgent__notifyClientErrorReported
    }

    /// 通知依赖图更新
    public static func notifyGraphUpdate(agent: UIntNative, devServerId: Int32, visualizerPayloadBase64: BaoString): Unit {
        // FFI: InspectorBunFrontendDevServerAgent__notifyGraphUpdate
    }

    /// 通知控制台日志
    public static func notifyConsoleLog(agent: UIntNative, devServerId: Int32, kind: UInt8, data: BaoString): Unit {
        // FFI: InspectorBunFrontendDevServerAgent__notifyConsoleLog
    }
}
