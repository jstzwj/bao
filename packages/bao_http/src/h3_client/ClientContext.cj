// bao_http h3_client ClientContext - HTTP/3 全局客户端上下文
// 严格翻译自: src/http/h3_client/ClientContext.zig
package bao_http.h3_client

import bao_core.*
import bao_collections.*

// ============================================================================
// H3ClientContext - HTTP/3 全局客户端上下文
// 严格翻译自: bun/src/http/h3_client/ClientContext.zig
//
// Bun ClientContext:
//   //! Process-global lazily-initialised on the HTTP thread. Owns the lsquic
//   //! client engine and the live-session registry. Never freed — the engine
//   //! lives for the process, same as the HTTP thread itself.
//
// 字段:
//   qctx: *quic.Context,
//   sessions: std.ArrayListUnmanaged(*ClientSession) = .{},
//   var instance: ?*ClientContext = null;
//   var lsquic_init_once = bun.once(quic.globalInit);
//
// 关键方法:
//   get, getOrCreate, connect, unregister, abortByHttpId, streamBodyByHttpId
// ============================================================================

/// HTTP/3 全局客户端上下文
/// 严格翻译自: bun/src/http/h3_client/ClientContext.zig ClientContext struct
public class H3ClientContext {
    /// 活跃会话列表
    /// 严格翻译自: sessions: std.ArrayListUnmanaged(*ClientSession) = .{}
    public var sessions: ArrayList<H3ClientSession>

    /// 全局单例实例
    /// 严格翻译自: var instance: ?*ClientContext = null
    private static var instance: ?H3ClientContext = None

    /// 是否已初始化 lsquic
    private static var lsquicInitialized: Bool = false

    public init() {
        sessions = ArrayList<H3ClientSession>()
    }

    // ========================================================================
    // get - 获取全局实例
    // 严格翻译自:
    //   pub fn get() ?*ClientContext { return instance; }
    // ========================================================================

    /// 获取全局实例
    /// 严格翻译自: ClientContext.get
    public static func get(): ?H3ClientContext {
        return instance
    }

    // ========================================================================
    // getOrCreate - 获取或创建全局实例
    // 严格翻译自:
    //   pub fn getOrCreate(loop: *uws.Loop) ?*ClientContext {
    //       if (instance) |i| return i;
    //       lsquic_init_once.call(.{});
    //       const qctx = quic.Context.createClient(...);
    //       callbacks.register(qctx);
    //       const self = bun.handleOom(bun.default_allocator.create(ClientContext));
    //       self.* = .{ .qctx = qctx };
    //       instance = self;
    //       return self;
    //   }
    // ========================================================================

    /// 获取或创建全局实例
    /// 严格翻译自: ClientContext.getOrCreate
    public static func getOrCreate(): H3ClientContext {
        match (instance) {
            case Some(ctx) => return ctx
            case None => {
                if (!lsquicInitialized) {
                    lsquicInitialized = true
                    // 桩: 初始化 lsquic 全局状态
                }
                let ctx = H3ClientContext()
                // 桩: 创建 QUIC 上下文, 注册回调
                instance = ctx
                return ctx
            }
        }
    }

    // ========================================================================
    // connect - 查找或打开连接并排队请求
    // 严格翻译自:
    //   pub fn connect(this: *ClientContext, client: *HTTPClient,
    //       hostname: []const u8, port: u16) bool {
    //       const reject = client.flags.reject_unauthorized;
    //       // 1. 查找可复用会话
    //       for (this.sessions.items) |s| {
    //           if (s.matches(hostname, port, reject) and s.hasHeadroom()) {
    //               s.enqueue(client);
    //               return true;
    //           }
    //       }
    //       // 2. 创建新会话
    //       const session = ClientSession.new(.{...});
    //       session.registry_index = this.sessions.items.len;
    //       this.sessions.append(session);
    //       session.enqueue(client);
    //       // 3. 发起 QUIC 连接
    //       switch (this.qctx.connect(...)) {
    //           .socket => |qs| { session.qsocket = qs; ... },
    //           .pending => |pending| { PendingConnect.register(...); },
    //           .err => { ... return false; },
    //       }
    //       return true;
    //   }
    // ========================================================================

    /// 查找或打开连接并排队请求
    /// 严格翻译自: ClientContext.connect
    public func connect(client: H3ClientRef, hostname: String, port: Int64, rejectUnauthorized: Bool): Bool {
        // 1. 查找可复用会话
        for (s in sessions) {
            if (s.matches(hostname, port, rejectUnauthorized) && s.hasHeadroom()) {
                s.enqueue(client)
                return true
            }
        }

        // 2. 创建新会话
        let session = H3ClientSession(hostname, port, rejectUnauthorized)
        session.registryIndex = sessions.size
        sessions.append(session)
        session.enqueue(client)

        // 3. 发起 QUIC 连接 (桩)
        // 实际: qctx.connect() -> socket / pending / err
        session.qsocket = Some(QuicSocketRef(0))

        return true
    }

    // ========================================================================
    // unregister - 从注册表中移除会话
    // 严格翻译自:
    //   pub fn unregister(this: *ClientContext, session: *ClientSession) void {
    //       const i = session.registry_index;
    //       if (i >= this.sessions.items.len or this.sessions.items[i] != session) return;
    //       _ = this.sessions.swapRemove(i);
    //       if (i < this.sessions.items.len)
    //           this.sessions.items[i].registry_index = i;
    //       session.registry_index = std.math.maxInt(u32);
    //   }
    // ========================================================================

    /// 从注册表中移除会话
    /// 严格翻译自: ClientContext.unregister
    public func unregister(session: H3ClientSession): Unit {
        let i = session.registryIndex
        if (i >= sessions.size || sessions[i] !== session) {
            return
        }
        sessions.removeAt(Int32(i))
        // 更新被 swap 的元素的索引
        if (i < sessions.size) {
            sessions[i].registryIndex = i
        }
        session.registryIndex = Int64.max
    }

    // ========================================================================
    // abortByHttpId - 按 HTTP ID 中止请求
    // 严格翻译自:
    //   pub fn abortByHttpId(async_http_id: u32) bool {
    //       const this = instance orelse return false;
    //       for (this.sessions.items) |s| {
    //           if (s.abortByHttpId(async_http_id)) return true;
    //       }
    //       return false;
    //   }
    // ========================================================================

    /// 按 HTTP ID 中止请求
    /// 严格翻译自: ClientContext.abortByHttpId
    public static func abortByHttpId(asyncHttpId: Int64): Bool {
        match (instance) {
            case Some(ctx) => {
                for (s in ctx.sessions) {
                    if (s.abortByHttpId(asyncHttpId)) {
                        return true
                    }
                }
                return false
            }
            case None => return false
        }
    }

    // ========================================================================
    // streamBodyByHttpId - 按 HTTP ID 流式传输请求体
    // 严格翻译自: ClientContext.streamBodyByHttpId
    // ========================================================================

    /// 按 HTTP ID 流式传输请求体
    /// 严格翻译自: ClientContext.streamBodyByHttpId
    public static func streamBodyByHttpId(asyncHttpId: Int64, ended: Bool): Unit {
        match (instance) {
            case Some(ctx) => {
                for (s in ctx.sessions) {
                    s.streamBodyByHttpId(asyncHttpId, ended)
                }
            }
            case None => ()
        }
    }
}
