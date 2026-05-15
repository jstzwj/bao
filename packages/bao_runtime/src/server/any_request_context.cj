// AnyRequestContext - 请求上下文的通用包装器
// 严格翻译自: Bun src/runtime/server/AnyRequestContext.zig
// 对应: 不同类型 (HTTP/HTTPS/Debug) 的 RequestContext 统一调度
package bao_runtime.server

import bao_core.*
import bao_collections.*

// ============================================================================
// AnyRequestContext - 请求上下文通用包装器
// 严格翻译自: src/runtime/server/AnyRequestContext.zig
// Bun: const AnyRequestContext = @This()
// 这是一个泛型包装器，将 HTTP/HTTPS/Debug/HTTP3 等不同类型的
// RequestContext 统一为单一类型，方便在 API 层面使用
// ============================================================================

/// AnyRequestContext - 统一的请求上下文引用
/// 对应 Bun: AnyRequestContext { tagged_pointer: Pointer }
/// Bun 使用 tagged pointer 来区分不同类型 (HTTP, HTTPS, Debug, H3)
/// 仓颉使用枚举 + 类型来简化实现
public enum AnyRequestContextTag {
    | Http
    | Https
    | DebugHttp
    | DebugHttps
    | H3
    | H3Tls
}

/// AnyRequestContext - 统一的请求上下文
/// 对应 Bun: pub const AnyRequestContext = @This()
/// Bun 使用 TaggedPointerUnion 来指向不同的 RequestContext
/// 仓颉直接持有 RequestContext 引用
public class AnyRequestContext {
    /// 标签 - 对应 Bun: tagged_pointer: Pointer
    public var tag: AnyRequestContextTag

    /// 实际的请求上下文 - 对应 Bun 中 tagged pointer 指向的对象
    public var context: ?RequestContext

    /// 对应 Bun: pub const Null: @This() = .{ .tagged_pointer = Pointer.Null }
    public static let Null: AnyRequestContext = AnyRequestContext()

    public init() {
        tag = AnyRequestContextTag.Http
        context = None
    }

    public init(tag: AnyRequestContextTag, context: RequestContext) {
        this.tag = tag
        this.context = Some(context)
    }

    /// 初始化
    /// 对应 Bun: pub fn init(request_ctx: anytype) AnyRequestContext
    public static func init(ctx: RequestContext): AnyRequestContext {
        return AnyRequestContext(AnyRequestContextTag.Http, ctx)
    }

    /// 初始化 (带标签)
    public static func init(tag: AnyRequestContextTag, ctx: RequestContext): AnyRequestContext {
        return AnyRequestContext(tag, ctx)
    }

    /// 是否为 Null
    /// 对应 Bun: if (self.tagged_pointer.isNull()) return default
    public func isNull(): Bool {
        return context == None
    }

    // ========================================================================
    // 调度方法
    // 严格翻译自 AnyRequestContext 中的所有 dispatch 方法
    // 对应 Bun: inline fn dispatch(self, Ret, default, cb, args) Ret
    // ========================================================================

    /// 设置附加中止回调
    /// 对应 Bun: pub fn setAdditionalOnAbortCallback(self, cb) void
    public func setAdditionalOnAbortCallback(cb: ?AdditionalOnAbortCallback): Unit {
        match (context) {
            case Some(ctx) => ctx.additionalOnAbort = cb
            case None => ()
        }
    }

    /// 内存开销
    /// 对应 Bun: pub fn memoryCost(self) usize
    public func memoryCost(): Int64 {
        match (context) {
            case Some(ctx) => ctx.memoryCost()
            case None => Int64(0)
        }
    }

    /// 获取指定类型
    /// 对应 Bun: pub fn get(self, comptime T: type) ?*T
    public func get(): ?RequestContext {
        return context
    }

    /// 设置超时
    /// 对应 Bun: pub fn setTimeout(self, seconds) bool
    public func setTimeout(seconds: Int64): Bool {
        match (context) {
            case Some(ctx) => ctx.setTimeout(seconds)
            case None => false
        }
    }

    /// 设置 Cookie
    /// 对应 Bun: pub fn setCookies(self, cookie_map) void
    public func setCookies(cookieMap: ?CookieMapRef): Unit {
        match (context) {
            case Some(ctx) => ctx.setCookies(cookieMap)
            case None => ()
        }
    }

    /// 启用超时事件
    /// 对应 Bun: pub fn enableTimeoutEvents(self) void
    public func enableTimeoutEvents(): Unit {
        match (context) {
            case Some(ctx) => ctx.setTimeoutHandler()
            case None => ()
        }
    }

    /// 获取远端 Socket 信息
    /// 对应 Bun: pub fn getRemoteSocketInfo(self) ?uws.SocketAddress
    public func getRemoteSocketInfo(): ?SocketAddress {
        match (context) {
            case Some(ctx) => ctx.getRemoteSocketInfo()
            case None => None
        }
    }

    /// 分离请求
    /// 对应 Bun: pub fn detachRequest(self) void
    public func detachRequest(): Unit {
        match (context) {
            case Some(ctx) => ctx.detachRequest()
            case None => ()
        }
    }

    /// 设置请求
    /// 对应 Bun: pub fn setRequest(self, req) void
    public func setRequest(req: RawRequestRef): Unit {
        match (context) {
            case Some(ctx) => ctx.setRequest(req)
            case None => ()
        }
    }

    /// 获取请求
    /// 对应 Bun: pub fn getRequest(self) ?*uws.Request
    public func getRequest(): ?RawRequestRef {
        match (context) {
            case Some(ctx) => ctx.getRequest()
            case None => None
        }
    }

    /// 中止处理
    /// 对应 Bun: pub fn onAbort(self, response) void
    public func onAbort(): Unit {
        match (context) {
            case Some(ctx) => ctx.onAbort()
            case None => ()
        }
    }

    /// 增加引用
    /// 对应 Bun: pub fn ref(self) void
    public func ref(): Unit {
        match (context) {
            case Some(ctx) => ctx.ref()
            case None => ()
        }
    }

    /// 设置中止信号
    /// 对应 Bun: pub fn setSignalAborted(self, reason) void
    public func setSignalAborted(reason: Int64): Unit {
        match (context) {
            case Some(ctx) => ctx.setSignalAborted(reason)
            case None => ()
        }
    }

    /// 获取开发服务器
    /// 对应 Bun: pub fn devServer(self) ?*bun.bake.DevServer
    public func devServer(): ?ServerRef {
        match (context) {
            case Some(ctx) => ctx.server
            case None => None
        }
    }

    /// 减少引用
    /// 对应 Bun: pub fn deref(self) void
    public func deref(): Unit {
        match (context) {
            case Some(ctx) => ctx.deref()
            case None => ()
        }
    }
}
