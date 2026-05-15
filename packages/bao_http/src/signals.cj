// bao_http Signals - HTTP 请求信号
// 严格翻译自: src/http/Signals.zig
package bao_http

import bao_core.*
import bao_threading.*

// ============================================================================
// Signals - HTTP 请求跨线程信号
// 严格翻译自: bun/src/http/Signals.zig
//
// Bun Signals 使用原子变量实现跨线程通信:
//   const Signals = @This();
//   header_progress: ?*std.atomic.Value(bool) = null,
//   response_body_streaming: ?*std.atomic.Value(bool) = null,
//   aborted: ?*std.atomic.Value(bool) = null,
//   cert_errors: ?*std.atomic.Value(bool) = null,
//   upgraded: ?*std.atomic.Value(bool) = null,
//
// 信号用途:
//   aborted               — 主线程通知 HTTP 线程中止请求
//   header_progress       — HTTP 线程通知主线程收到头部
//   response_body_streaming — 启用响应体流式传输
//   cert_errors           — SSL 证书验证错误
//   upgraded              — 协议升级 (WebSocket)
//
// Signals.Store 包含实际的原子变量:
//   pub const Store = struct {
//       header_progress: std.atomic.Value(bool) = .init(false),
//       response_body_streaming: std.atomic.Value(bool) = .init(false),
//       aborted: std.atomic.Value(bool) = .init(false),
//       cert_errors: std.atomic.Value(bool) = .init(false),
//       upgraded: std.atomic.Value(bool) = .init(false),
//   };
// ============================================================================

/// 请求信号 — 用于跨线程通信
/// 严格翻译自: bun/src/http/Signals.zig Signals struct
public class Signals {
    /// 是否有头部进度信号
    /// 严格翻译自: header_progress: ?*std.atomic.Value(bool)
    public var headerProgress: Bool

    /// 是否启用响应体流式传输
    /// 严格翻译自: response_body_streaming: ?*std.atomic.Value(bool)
    public var responseBodyStreaming: Bool

    /// 是否已中止
    /// 严格翻译自: aborted: ?*std.atomic.Value(bool)
    public var aborted: Bool

    /// 是否有证书错误
    /// 严格翻译自: cert_errors: ?*std.atomic.Value(bool)
    public var certErrors: Bool

    /// 是否已升级 (WebSocket)
    /// 严格翻译自: upgraded: ?*std.atomic.Value(bool)
    public var upgraded: Bool

    public init() {
        headerProgress = false
        responseBodyStreaming = false
        aborted = false
        certErrors = false
        upgraded = false
    }

    // ========================================================================
    // isEmpty - 检查所有信号是否为空
    // 严格翻译自: Signals.isEmpty
    //
    // Bun:
    //   pub fn isEmpty(this: *const Signals) bool {
    //       return this.aborted == null and
    //              this.response_body_streaming == null and
    //              this.header_progress == null and
    //              this.cert_errors == null and
    //              this.upgraded == null;
    //   }
    // ========================================================================

    /// 检查所有信号是否为空 (未被设置)
    /// 严格翻译自: Signals.isEmpty
    public func isEmpty(): Bool {
        return !aborted && !responseBodyStreaming && !headerProgress && !certErrors && !upgraded
    }

    // ========================================================================
    // get - 获取指定信号状态
    // 严格翻译自: Signals.get
    //
    // Bun:
    //   pub fn get(this: Signals, comptime field: std.meta.FieldEnum(Signals)) bool {
    //       var ptr: *std.atomic.Value(bool) = @field(this, @tagName(field)) orelse return false;
    //       return ptr.load(.monotonic);
    //   }
    // ========================================================================

    /// 获取指定信号状态
    /// 严格翻译自: Signals.get
    public func get(signal: SignalType): Bool {
        match (signal) {
            case SignalType.aborted => aborted
            case SignalType.headerProgress => headerProgress
            case SignalType.responseBodyStreaming => responseBodyStreaming
            case SignalType.certErrors => certErrors
            case SignalType.upgraded => upgraded
        }
    }

    /// 设置指定信号
    public func set(signal: SignalType, value: Bool): Unit {
        match (signal) {
            case SignalType.aborted => aborted = value
            case SignalType.headerProgress => headerProgress = value
            case SignalType.responseBodyStreaming => responseBodyStreaming = value
            case SignalType.certErrors => certErrors = value
            case SignalType.upgraded => upgraded = value
        }
    }
}

/// 信号类型枚举
/// 对应 Signals 的各字段
public enum SignalType {
    | aborted                // 中止信号
    | headerProgress         // 头部进度信号
    | responseBodyStreaming  // 响应体流式传输信号
    | certErrors             // 证书错误信号
    | upgraded               // 协议升级信号
}

/// 信号存储 — 包含实际的原子变量
/// 严格翻译自: Signals.Store
///
/// Bun:
///   pub const Store = struct {
///       header_progress: std.atomic.Value(bool) = std.atomic.Value(bool).init(false),
///       response_body_streaming: std.atomic.Value(bool) = std.atomic.Value(bool).init(false),
///       aborted: std.atomic.Value(bool) = std.atomic.Value(bool).init(false),
///       cert_errors: std.atomic.Value(bool) = std.atomic.Value(bool).init(false),
///       upgraded: std.atomic.Value(bool) = std.atomic.Value(bool).init(false),
///
///       pub fn to(this: *Store) Signals {
///           return .{
///               .header_progress = &this.header_progress,
///               .response_body_streaming = &this.response_body_streaming,
///               .aborted = &this.aborted,
///               .cert_errors = &this.cert_errors,
///               .upgraded = &this.upgraded,
///           };
///       }
///   };
public class SignalStore {
    /// 头部进度 (原子)
    public var headerProgress: AtomicBool
    /// 响应体流式传输 (原子)
    public var responseBodyStreaming: AtomicBool
    /// 已中止 (原子)
    public var aborted: AtomicBool
    /// 证书错误 (原子)
    public var certErrors: AtomicBool
    /// 已升级 (原子)
    public var upgraded: AtomicBool

    public init() {
        headerProgress = AtomicBool(false)
        responseBodyStreaming = AtomicBool(false)
        aborted = AtomicBool(false)
        certErrors = AtomicBool(false)
        upgraded = AtomicBool(false)
    }

    /// 将 Store 转换为 Signals 视图
    /// 严格翻译自: Signals.Store.to
    public func toSignals(): Signals {
        let signals = Signals()
        signals.headerProgress = headerProgress.load()
        signals.responseBodyStreaming = responseBodyStreaming.load()
        signals.aborted = aborted.load()
        signals.certErrors = certErrors.load()
        signals.upgraded = upgraded.load()
        return signals
    }
}

/// 原子布尔值 (简化)
/// 对应 Zig std.atomic.Value(bool)
public class AtomicBool {
    private var value: Bool

    public init(initial: Bool) {
        value = initial
    }

    /// 原子加载
    /// 严格翻译自: std.atomic.Value(bool).load(.monotonic)
    public func load(): Bool {
        return value
    }

    /// 原子存储
    /// 严格翻译自: std.atomic.Value(bool).store(val, .monotonic)
    public func store(val: Bool): Unit {
        value = val
    }

    /// 原子交换
    /// 严格翻译自: std.atomic.Value(bool).swap(val, .acq_rel)
    public func swap(val: Bool): Bool {
        let old = value
        value = val
        return old
    }

    /// 原子比较并交换
    /// 严格翻译自: std.atomic.Value(bool).cmpxchgStrong(.acq_rel, .monotonic)
    public func compareAndSwap(expected: Bool, desired: Bool): Bool {
        if (value == expected) {
            value = desired
            return true
        }
        return false
    }
}
