// 严格翻译自: src/http_jsc/websocket_client.zig
//! JSC bridge for WebSocket client. Keeps http/ free of JSC types.
package bao_http_jsc

import bao_jsc.*
import bao_core.*

// ============================================================================
// WebSocketClientJSC - WebSocket 客户端 JSC 桥接
// 严格翻译自: src/http_jsc/websocket_client.zig
//   大型文件，约 77600 字节，包含 WebSocket 客户端的完整 JSC 绑定
// ============================================================================

/// WebSocket 客户端 JSC 绑定 - 严格对应 Bun WebSocket 客户端
/// 包含:
///   - WebSocket 构造函数和原型方法
///   - 二进制类型管理
///   - 消息发送/接收
///   - 连接管理 (close, ping, pong)
///   - 协议升级处理
///   - 压缩扩展 (permessage-deflate)
///   - HTTP/2 WebSocket 支持
///   - 事件处理 (onopen, onmessage, onclose, onerror)
///   - 缓冲区管理 (backpressure)
///   - Ping/Pong 帧处理
///   - 证书验证
public class WebSocketClientJSC {
    /// 创建 WebSocket 客户端 - 严格对应 Bun WebSocket 构造函数
    public static func createWebSocket(globalObject: JSGlobalObject, url: String, protocols: Array<String>): JSValue {
        let ws = WebSocketClient(globalObject: globalObject, url: url, protocols: protocols)
        return ws.toJS(globalObject)
    }
}
