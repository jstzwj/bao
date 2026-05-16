// bao_http h2_client PendingConnect - TLS 连接进行中的占位符
// 严格翻译自: src/http/h2_client/PendingConnect.zig
package bao_http.h2_client

import bao_core.*
import bao_collections.*

// ============================================================================
// H2PendingConnect - TLS 连接进行中的占位符
// 严格翻译自: bun/src/http/h2_client/PendingConnect.zig
//
// Bun PendingConnect:
//   //! Placeholder registered while a fresh TLS connect is in flight so that
//   //! concurrent h2-capable requests to the same origin coalesce onto its
//   //! eventual session instead of each opening a separate socket.
//   pub const new = bun.TrivialNew(@This());
//   hostname: []const u8,
//   port: u16,
//   ssl_config: ?*SSLConfig,
//   waiters: std.ArrayListUnmanaged(*HTTPClient) = .{},
//
// 核心用途:
//   当一个新的 TLS 连接正在建立时注册此占位符，以便并发 h2 请求
//   可以合并到同一个会话上，而不是每个都打开单独的 socket
// ============================================================================

/// TLS 连接进行中的占位符
/// 严格翻译自: bun/src/http/h2_client/PendingConnect.zig PendingConnect struct
public class H2PendingConnect {
    /// 目标主机名
    /// 严格翻译自: hostname: []const u8
    public var hostname: String

    /// 目标端口
    /// 严格翻译自: port: u16
    public var port: Int64

    /// SSL 配置
    /// 严格翻译自: ssl_config: ?*SSLConfig
    public var sslConfig: ?H2SslConfigRef

    /// 等待此连接完成的 HTTP 客户端列表
    /// 严格翻译自: waiters: std.ArrayListUnmanaged(*HTTPClient) = .{}
    public var waiters: ArrayList<H2WaiterRef>

    public init(hostname: String, port: Int64, sslConfig: ?H2SslConfigRef) {
        this.hostname = hostname
        this.port = port
        this.sslConfig = sslConfig
        waiters = ArrayList<H2WaiterRef>()
    }

    // ========================================================================
    // matches - 检查是否匹配给定的连接参数
    // 严格翻译自:
    //   pub fn matches(this: *const @This(), hostname: []const u8, port: u16,
    //                  ssl_config: ?*SSLConfig) bool {
    //       return this.port == port and this.ssl_config == ssl_config and
    //              strings.eqlLong(this.hostname, hostname, true);
    //   }
    // ========================================================================

    /// 检查是否匹配给定的连接参数
    /// 严格翻译自: PendingConnect.matches
    public func matches(hostname: String, port: Int64, sslConfig: ?H2SslConfigRef): Bool {
        if (this.port != port) {
            return false
        }
        match (this.sslConfig) {
            case Some(sc) => {
                match (sslConfig) {
                    case Some(other) => {
                        if (sc.ptr != other.ptr) {
                            return false
                        }
                    }
                    case None => return false
                }
            }
            case None => {
                match (sslConfig) {
                    case Some(_) => return false
                    case None => ()
                }
            }
        }
        return this.hostname == hostname
    }

    // ========================================================================
    // unregisterFrom - 从上下文的 pending 列表中注销
    // 严格翻译自:
    //   pub fn unregisterFrom(this: *@This(), ctx: *NewHTTPContext(true)) void {
    //       const list = &ctx.pending_h2_connects;
    //       for (list.items, 0..) |p, i| {
    //           if (p == this) {
    //               _ = list.swapRemove(i);
    //               return;
    //           }
    //       }
    //   }
    // ========================================================================

    /// 从上下文的 pending 列表中注销
    /// 严格翻译自: PendingConnect.unregisterFrom
    public func unregisterFrom(ctx: H2PendingConnectList): Unit {
        ctx.remove(this)
    }

    /// 添加等待者
    public func addWaiter(waiter: H2WaiterRef): Unit {
        waiters.append(waiter)
    }

    /// 清理资源
    /// 严格翻译自: PendingConnect.deinit
    public func deinit(): Unit {
        waiters = ArrayList<H2WaiterRef>()
    }
}

/// 待连接列表 (上下文管理)
public class H2PendingConnectList {
    private var list: ArrayList<H2PendingConnect>

    public init() {
        list = ArrayList<H2PendingConnect>()
    }

    /// 添加待连接
    public func add(pc: H2PendingConnect): Unit {
        list.append(pc)
    }

    /// 移除待连接
    public func remove(pc: H2PendingConnect): Unit {
        var i: Int64 = 0
        while (i < list.size) {
            if (list[i] === pc) {
                list.removeAt(Int32(i))
                return
            }
            i += 1
        }
    }

    /// 查找匹配的待连接
    public func find(hostname: String, port: Int64, sslConfig: ?H2SslConfigRef): ?H2PendingConnect {
        for (pc in list) {
            if (pc.matches(hostname, port, sslConfig)) {
                return Some(pc)
            }
        }
        return None
    }
}

/// SSL 配置引用 (避免循环依赖)
public class H2SslConfigRef {
    public var ptr: Int64  // 指针标识符

    public init(ptr: Int64) {
        this.ptr = ptr
    }
}

/// 等待者引用
public class H2WaiterRef {
    public var asyncHttpId: Int64

    public init(id: Int64) {
        asyncHttpId = id
    }
}
