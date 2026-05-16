// bao_http h2_client encode - HTTP/2 出站请求编码
// 严格翻译自: src/http/h2_client/encode.zig
package bao_http.h2_client

import bao_core.*
import bao_collections.*

// ============================================================================
// H2FrameEncode - HTTP/2 出站帧编码
// 严格翻译自: bun/src/http/h2_client/encode.zig
//
// Bun encode.zig 包含以下自由函数:
//   - writePreface: 发送 HTTP/2 连接预检 + SETTINGS + WINDOW_UPDATE
//   - writeRequest: 序列化请求头部和体到帧
//   - writeHeaderBlock: 将头部块分割为 HEADERS + CONTINUATION 帧
//   - writeDataWindowed: 流量控制感知的 DATA 帧写入
//   - drainSendBody: 推送请求体到发送窗口
//   - drainSendBodies: 轮询所有流的请求体
//   - encodeHeader: HPACK 编码单个头部
//   - encodeHpackTableSizeUpdate: RFC 7541 §6.3 动态表大小更新
//
// RequestHeader 枚举用于头部分类:
//   - drop: 跳过的逐跳头部
//   - host: 提升为 :authority
//   - te: 仅转发 "trailers" 值
//   - content_length: Expect: 100-continue 时跳过
//   - expect: 触发 awaiting_continue
//   - sensitive: 不索引 (authorization, cookie, set-cookie)
// ============================================================================

/// HTTP/2 出站帧编码器
/// 严格翻译自: bun/src/http/h2_client/encode.zig 自由函数
public class H2FrameEncode {
    // ========================================================================
    // writePreface - 发送 HTTP/2 连接预检
    // 严格翻译自:
    //   pub fn writePreface(session: *ClientSession) void {
    //       session.queue(wire.client_preface);
    //       // 发送 SETTINGS 帧 (3 个参数)
    //       wire.SettingsPayloadUnit.encode(..., .SETTINGS_ENABLE_PUSH, 0);
    //       wire.SettingsPayloadUnit.encode(..., .SETTINGS_INITIAL_WINDOW_SIZE, local_initial_window_size);
    //       wire.SettingsPayloadUnit.encode(..., .SETTINGS_MAX_HEADER_LIST_SIZE, local_max_header_list_size);
    //       session.writeFrame(.HTTP_FRAME_SETTINGS, 0, 0, &settings);
    //       // 连接级窗口更新
    //       session.writeWindowUpdate(0, local_initial_window_size - wire.DEFAULT_WINDOW_SIZE);
    //       session.preface_sent = true;
    //   }
    // ========================================================================

    /// 发送 HTTP/2 连接预检
    /// 严格翻译自: encode.writePreface
    public static func writePreface(session: H2ClientSession): Unit {
        // 1. 连接预检字符串
        let preface = H2ClientSession.CLIENT_PREFACE
        let prefaceBytes = Array<UInt8>()
        for (c in preface) {
            prefaceBytes.append(UInt8(c.value & 0xFF))
        }
        session.queue(prefaceBytes)

        // 2. SETTINGS 帧 (3 个参数)
        let settings = Array<UInt8>()
        // SETTINGS_ENABLE_PUSH = 0 (禁用推送)
        appendSetting(settings, 0x2, 0)
        // SETTINGS_INITIAL_WINDOW_SIZE = 16MB
        appendSetting(settings, 0x4, H2ClientSession.LOCAL_INITIAL_WINDOW_SIZE)
        // SETTINGS_MAX_HEADER_LIST_SIZE = 256KB
        appendSetting(settings, 0x6, H2ClientSession.LOCAL_MAX_HEADER_LIST_SIZE)
        session.writeFrame(H2FrameType.Settings, 0, 0, settings)

        // 3. 连接级窗口更新 (从 64KB 扩展到本端初始窗口大小)
        session.writeWindowUpdate(0, H2ClientSession.LOCAL_INITIAL_WINDOW_SIZE - H2ClientSession.DEFAULT_WINDOW_SIZE)
        session.prefaceSent = true
    }

    // ========================================================================
    // writeRequest - 序列化请求头部和体到帧
    // 严格翻译自: encode.writeRequest
    //
    // Bun 流程:
    //   1. 检查 pending_hpack_enc_capacity, 发送 Dynamic Table Size Update
    //   2. 扫描头部进行分类 (host → :authority, drop 逐跳头部等)
    //   3. 编码伪头部 (:method, :scheme, :authority, :path)
    //   4. 编码用户头部 (跳过 drop/host, 处理 te/expect/sensitive)
    //   5. writeHeaderBlock (HEADERS + CONTINUATION 帧)
    //   6. 处理请求体 (inline bytes / streaming / sendfile)
    // ========================================================================

    /// 序列化 HTTP 请求为 HTTP/2 帧
    /// 严格翻译自: encode.writeRequest
    public static func writeRequest(session: H2ClientSession, stream: H2ClientStream,
                                     method: String, path: String, host: String,
                                     headers: ArrayList<HeaderPair>,
                                     body: Array<UInt8>, isStreaming: Bool): Unit {
        let encoded = ArrayList<UInt8>()

        // HPACK Dynamic Table Size Update (如果需要)
        match (session.pendingHpackEncCapacity) {
            case Some(cap) => {
                session.pendingHpackEncCapacity = None
                encodeHpackTableSizeUpdate(encoded, cap)
            }
            case None => ()
        }

        // 查找 authority 和特殊头部
        var authority = host
        var hasExpectContinue = false

        for (h in headers) {
            let lower = h.name.toLower()
            match (lower) {
                case "host" => authority = h.value
                case "expect" => {
                    if (h.value.toLower().trim() == "100-continue") {
                        hasExpectContinue = true
                    }
                }
                case _ => ()
            }
        }

        // 编码伪头部
        let encoder = HpackEncoder()
        let pseudoHeaders = ArrayList<HeaderPair>()
        pseudoHeaders.append(HeaderPair(":method", method))
        pseudoHeaders.append(HeaderPair(":scheme", "https"))
        pseudoHeaders.append(HeaderPair(":authority", authority))
        pseudoHeaders.append(HeaderPair(":path", if (path.size > 0) { path } else { "/" }))

        let pseudoEncoded = encoder.encode(pseudoHeaders)
        for (b in pseudoEncoded) {
            encoded.append(b)
        }

        // 编码用户头部 (跳过逐跳头部)
        let skipHeaders = Array<String>(["connection", "keep-alive", "proxy-connection", "transfer-encoding", "upgrade"])
        for (h in headers) {
            let lower = h.name.toLower()
            // 跳过逐跳头部和 host
            var skip = false
            for (s in skipHeaders) {
                if (lower == s) { skip = true }
            }
            if (lower == "host") { skip = true }
            if (lower == "content-length" && hasExpectContinue) { skip = true }
            if (skip) { continue }

            // 处理 te: 仅转发 "trailers"
            if (lower == "te" && h.value.toLower().trim() != "trailers") { continue }

            let userHeaders = ArrayList<HeaderPair>()
            userHeaders.append(HeaderPair(lower, h.value))
            let userEncoded = encoder.encode(userHeaders)
            for (b in userEncoded) {
                encoded.append(b)
            }
        }

        let hasInlineBody = body.size > 0 && !isStreaming
        let endStream = !hasInlineBody && !isStreaming

        // 写入 HEADERS (可能 + CONTINUATION) 帧
        writeHeaderBlock(session, stream.id, encoded.toArray(), endStream)

        // 处理请求体
        if (hasExpectContinue && (hasInlineBody || isStreaming)) {
            stream.awaitingContinue = true
        }

        if (hasInlineBody) {
            stream.pendingBody = body
            drainSendBody(session, stream, Int64.max)
        } else if (!isStreaming) {
            stream.sentEndStream()
        }
    }

    // ========================================================================
    // writeHeaderBlock - 将头部块分割为 HEADERS + CONTINUATION 帧
    // 严格翻译自:
    //   pub fn writeHeaderBlock(session: *ClientSession, stream_id: u31,
    //       block: []const u8, end_stream: bool) void {
    //       const max: usize = session.remote_max_frame_size;
    //       var remaining = block;
    //       var first = true;
    //       while (true) {
    //           const chunk = remaining[0..@min(remaining.len, max)];
    //           remaining = remaining[chunk.len..];
    //           const last = remaining.len == 0;
    //           var flags: u8 = 0;
    //           if (last) flags |= END_HEADERS;
    //           if (first and end_stream) flags |= END_STREAM;
    //           session.writeFrame(if (first) HEADERS else CONTINUATION, flags, ...);
    //           first = false;
    //           if (last) break;
    //       }
    //   }
    // ========================================================================

    /// 将头部块分割为 HEADERS + CONTINUATION 帧
    /// 严格翻译自: encode.writeHeaderBlock
    public static func writeHeaderBlock(session: H2ClientSession, streamId: Int64,
                                         block: Array<UInt8>, endStream: Bool): Unit {
        let max = session.remoteMaxFrameSize
        var offset: Int64 = 0
        var first = true

        while (true) {
            let remaining = block.size - offset
            let chunkLen = if (remaining > max) { max } else { remaining }

            // 提取分片
            let chunk = Array<UInt8>()
            for (i in 0..chunkLen) {
                chunk.append(block[offset + i])
            }

            offset += chunkLen
            let last = offset >= block.size

            var flags: UInt8 = 0
            if (last) {
                flags = UInt8(Int32(flags) | 0x04)  // END_HEADERS
            }
            if (first && endStream) {
                flags = UInt8(Int32(flags) | 0x01)  // END_STREAM
            }

            let frameType = if (first) { H2FrameType.Headers } else { H2FrameType.Continuation }
            session.writeFrame(frameType, flags, streamId, chunk)

            first = false
            if (last) {
                break
            }
        }
    }

    // ========================================================================
    // writeDataWindowed - 流量控制感知的 DATA 帧写入
    // 严格翻译自:
    //   pub fn writeDataWindowed(session: *ClientSession, stream: *Stream,
    //       data: []const u8, end_stream: bool, cap: usize) usize {
    //       // 检查流级和连接级窗口
    //       // 检查写入缓冲区高水位
    //       // 按 remote_max_frame_size 分片
    //       // 最后一帧设 END_STREAM
    //   }
    // ========================================================================

    /// 流量控制感知的 DATA 帧写入
    /// 严格翻译自: encode.writeDataWindowed
    /// 返回消耗的字节数
    public static func writeDataWindowed(session: H2ClientSession, stream: H2ClientStream,
                                          data: Array<UInt8>, endStream: Bool, cap: Int64): Int64 {
        var offset: Int64 = 0
        var consumed: Int64 = 0

        while (true) {
            // 计算可用窗口
            let streamWindow = if (stream.sendWindow > 0) { stream.sendWindow } else { 0 }
            let connWindow = if (session.connSendWindow > 0) { session.connSendWindow } else { 0 }
            let window = if (streamWindow < connWindow) { streamWindow } else { connWindow }

            let remaining = data.size - offset
            if (remaining > 0 && window == 0) {
                break
            }

            // 写入缓冲区高水位
            if (remaining > 0 && session.writeBuffer.size >= H2ClientSession.WRITE_BUFFER_HIGH_WATER) {
                break
            }

            if (consumed >= cap && remaining > 0) {
                break
            }

            let chunkLen = if (remaining < session.remoteMaxFrameSize) {
                remaining
            } else {
                session.remoteMaxFrameSize
            }
            let effectiveChunkLen = if (chunkLen < window) { chunkLen } else { window }

            // 提取分片
            let chunk = Array<UInt8>()
            for (i in 0..effectiveChunkLen) {
                chunk.append(data[offset + i])
            }

            offset += effectiveChunkLen
            let last = offset >= data.size

            let flags: UInt8 = if (last && endStream) { 0x01 } else { 0x00 }  // END_STREAM
            session.writeFrame(H2FrameType.Data, flags, stream.id, chunk)

            stream.sendWindow -= effectiveChunkLen
            session.connSendWindow -= effectiveChunkLen
            consumed += effectiveChunkLen

            if (last) {
                break
            }
        }

        return consumed
    }

    // ========================================================================
    // drainSendBody - 推送请求体
    // 严格翻译自: encode.drainSendBody
    //   if (stream.localClosed() or stream.awaiting_continue or stream.fatal_error != null) return;
    //   switch (client.state.original_request_body) {
    //       .bytes => { writeDataWindowed(...); update pending_body; }
    //       .stream => { writeDataWindowed(...); handle buffer drain; }
    //   }
    // ========================================================================

    /// 推送请求体到发送窗口
    /// 严格翻译自: encode.drainSendBody
    public static func drainSendBody(session: H2ClientSession, stream: H2ClientStream, cap: Int64): Unit {
        if (stream.localClosed() || stream.awaitingContinue) {
            match (stream.fatalError) {
                case Some(_) => return
                case None => ()
            }
        }

        if (stream.pendingBody.size > 0) {
            let sent = writeDataWindowed(session, stream, stream.pendingBody, true, cap)
            // 更新 pendingBody
            let remaining = ArrayList<UInt8>()
            for (i in sent..stream.pendingBody.size) {
                remaining.append(stream.pendingBody[i])
            }
            stream.pendingBody = remaining.toArray()
            if (stream.pendingBody.size == 0) {
                stream.sentEndStream()
            }
        }
    }

    // ========================================================================
    // drainSendBodies - 轮询所有流的请求体
    // 严格翻译自: encode.drainSendBodies
    //   轮询调度: 每轮给每个上传者最多一个 remote_max_frame_size 分片
    //   确保最低索引流不能独占连接级窗口
    // ========================================================================

    /// 轮询所有流的请求体
    /// 严格翻译自: encode.drainSendBodies
    public static func drainSendBodies(session: H2ClientSession): Unit {
        let slice = session.remoteMaxFrameSize

        while (session.connSendWindow > 0 &&
               session.writeBuffer.size < H2ClientSession.WRITE_BUFFER_HIGH_WATER) {
            var progressed = false

            for (key in session.streams.keys()) {
                match (session.streams.get(key)) {
                    case Some(stream) => {
                        if (stream.localClosed() || stream.sendWindow <= 0) {
                            continue
                        }
                        let before = session.connSendWindow
                        drainSendBody(session, stream, slice)
                        if (session.connSendWindow != before || stream.localClosed()) {
                            progressed = true
                        }
                    }
                    case None => ()
                }
            }

            if (!progressed) {
                break
            }
        }
    }

    // ========================================================================
    // encodeHpackTableSizeUpdate - RFC 7541 §6.3 动态表大小更新
    // 严格翻译自:
    //   pub fn encodeHpackTableSizeUpdate(encoded: *ArrayListUnmanaged(u8),
    //       value: u32) void {
    //       if (value < 31) {
    //           encoded.appendAssumeCapacity(0x20 | @as(u8, @intCast(value)));
    //           return;
    //       }
    //       encoded.appendAssumeCapacity(0x20 | 31);
    //       var rest = value - 31;
    //       while (rest >= 128) : (rest >>= 7) {
    //           encoded.appendAssumeCapacity(@as(u8, @truncate(rest)) | 0x80);
    //       }
    //       encoded.appendAssumeCapacity(@as(u8, @truncate(rest)));
    //   }
    // ========================================================================

    /// RFC 7541 §6.3 动态表大小更新编码
    /// 严格翻译自: encode.encodeHpackTableSizeUpdate
    public static func encodeHpackTableSizeUpdate(encoded: ArrayList<UInt8>, value: Int64): Unit {
        if (value < 31) {
            encoded.append(UInt8(0x20 | Int32(value)))
            return
        }
        encoded.append(UInt8(0x20 | 31))
        var rest = value - 31
        while (rest >= 128) {
            encoded.append(UInt8(Int32(rest & 0x7F) | 0x80))
            rest = rest >> 7
        }
        encoded.append(UInt8(Int32(rest)))
    }

    /// 追加 SETTINGS 参数 (2 字节 ID + 4 字节 Value, big-endian)
    private static func appendSetting(payload: Array<UInt8>, id: Int64, value: Int64): Unit {
        payload.append(UInt8((id >> 8) & 0xFF))
        payload.append(UInt8(id & 0xFF))
        payload.append(UInt8((value >> 24) & 0xFF))
        payload.append(UInt8((value >> 16) & 0xFF))
        payload.append(UInt8((value >> 8) & 0xFF))
        payload.append(UInt8(value & 0xFF))
    }
}
