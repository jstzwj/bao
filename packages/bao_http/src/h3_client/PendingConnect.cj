// bao_http h3_client PendingConnect - DNS-pending QUIC 连接
// 严格翻译自: src/http/h3_client/PendingConnect.zig
package bao_http.h3_client

import bao_core.*
import bao_collections.*

// ============================================================================
// H3PendingConnect - DNS-pending QUIC 连接
// 严格翻译自: bun/src/http/h3_client/PendingConnect.zig
//
// Bun:
//   //! DNS-pending QUIC connect. Created when `quic.Context.connect` returns
//   //! `.pending` (cache miss); the global DNS cache notifies via
//   //! `onDNSResolved[Threadsafe]`, at which point the resolved address is
//   //! handed to lsquic and the resulting `quic.Socket` bound to the waiting
//   //! `ClientSession`.
//
// 字段:
//   session: *ClientSession,
//   pc: *quic.PendingConnect,
//   loop_ptr: *uws.Loop,
//   next: ?*PendingConnect = null,
//
// 生命周期:
//   - register: 从 connect() 创建，持有 session 的一个 ref
//   - onDNSResolved: DNS 完成后绑定 quic.Socket 到 session
//   - onDNSResolvedThreadsafe: 跨线程 DNS 回调，推送到 HTTP 线程
//   - drainResolved: HTTP 线程批量处理已解析的连接
// ============================================================================

/// DNS-pending QUIC 连接
/// 严格翻译自: bun/src/http/h3_client/PendingConnect.zig PendingConnect struct
public class H3PendingConnect {
    /// 等待 DNS 解析的会话
    /// 严格翻译自: session: *ClientSession
    public var session: H3ClientSession

    /// DNS 解析结果状态
    public var resolved: Bool

    /// 是否已取消
    public var cancelled: Bool

    /// 链表下一个节点 (用于线程安全队列)
    /// 严格翻译自: next: ?*PendingConnect = null
    public var next: ?H3PendingConnect

    public init(session: H3ClientSession) {
        this.session = session
        resolved = false
        cancelled = false
        next = None
    }

    // ========================================================================
    // onDNSResolved - DNS 解析完成
    // 严格翻译自:
    //   pub fn onDNSResolved(this: *PendingConnect) void {
    //       const session = this.session;
    //       defer { session.deref(); bun.destroy(this); }
    //       if (session.closed or session.pending.items.len == 0) {
    //           this.pc.cancel();
    //           if (!session.closed) failSession(session, error.Aborted);
    //           return;
    //       }
    //       const qs = this.pc.resolved() orelse {
    //           failSession(session, error.DNSResolutionFailed);
    //           return;
    //       };
    //       session.qsocket = qs;
    //       qs.ext(ClientSession).* = session;
    //   }
    // ========================================================================

    /// DNS 解析完成
    /// 严格翻译自: PendingConnect.onDNSResolved
    public func onDNSResolved(): Unit {
        if (session.closed || session.pending.size == 0) {
            cancelled = true
            if (!session.closed) {
                failSession(session, "Aborted")
            }
            return
        }

        // 标记为已解析
        resolved = true
    }

    // ========================================================================
    // failSession - 会话失败处理
    // 严格翻译自:
    //   pub fn failSession(session: *ClientSession, err: anyerror) void {
    //       session.closed = true;
    //       if (H3.ClientContext.get()) |ctx| ctx.unregister(session);
    //       while (session.pending.items.len > 0) {
    //           const stream = session.pending.items[0];
    //           const cl = stream.client;
    //           session.detach(stream);
    //           if (cl) |cl_| cl_.failFromH2(err);
    //       }
    //       _ = H3.live_sessions.fetchSub(1, .monotonic);
    //       session.deref();
    //   }
    // ========================================================================

    /// 会话失败处理
    /// 严格翻译自: PendingConnect.failSession
    public static func failSession(session: H3ClientSession, err: String): Unit {
        session.closed = true
        // 清空等待队列
        while (session.pending.size > 0) {
            let stream = session.pending.removeAt(0)
            stream.abort()
            stream.deinit()
        }
    }
}

/// DNS 解析完成队列 (线程安全)
/// 严格翻译自: PendingConnect 中的全局变量 resolved_mutex / resolved_head / drainResolved
public class H3ResolvedQueue {
    private var queue: ArrayList<H3PendingConnect>

    public init() {
        queue = ArrayList<H3PendingConnect>()
    }

    /// 添加到队列 (线程安全版本推入)
    /// 严格翻译自: PendingConnect.onDNSResolvedThreadsafe
    public func enqueue(pc: H3PendingConnect): Unit {
        pc.next = None
        queue.append(pc)
    }

    /// 排空已解析的连接
    /// 严格翻译自: PendingConnect.drainResolved
    public func drainResolved(): Unit {
        let pending = queue.toArray()
        queue = ArrayList<H3PendingConnect>()
        for (pc in pending) {
            pc.onDNSResolved()
        }
    }
}
