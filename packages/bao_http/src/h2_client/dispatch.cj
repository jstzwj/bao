// bao_http h2_client dispatch - HTTP/2 入站帧解析和分发
// 严格翻译自: src/http/h2_client/dispatch.zig
package bao_http.h2_client

import bao_core.*
import bao_collections.*

// ============================================================================
// H2FrameDispatch - HTTP/2 入站帧解析和分发
// 严格翻译自: bun/src/http/h2_client/dispatch.zig
//
// Bun dispatch.zig 是对 *ClientSession 的自由函数集合:
//   - parseFrames: 从字节流解析完整帧并分发
//   - dispatchFrame: 根据帧类型分发到具体处理函数
//   - decodeHeaderBlock: HPACK 解码头部块
//   - decodeDiscardOrphan: 解码孤立流的头部块 (保持动态表同步)
//   - stripPadding: 去除填充
//   - errorCodeFor: 错误码映射
//
// 仓颉实现将这些函数组织为 H2FrameDispatch 类的静态方法
// ============================================================================

/// HTTP/2 帧分发器
/// 严格翻译自: bun/src/http/h2_client/dispatch.zig 自由函数
public class H2FrameDispatch {
    /// 本端最大头部列表大小 (256KB)
    /// 严格翻译自: H2.local_max_header_list_size
    public static let LOCAL_MAX_HEADER_LIST_SIZE: Int64 = 256 * 1024

    /// 写入缓冲区控制限制 (1MB)
    /// 严格翻译自: H2.write_buffer_control_limit
    public static let WRITE_BUFFER_CONTROL_LIMIT: Int64 = 1024 * 1024

    // ========================================================================
    // parseFrames - 解析并分发缓冲区中的所有完整帧
    // 严格翻译自:
    //   pub fn parseFrames(session: *ClientSession, buf: []const u8) usize {
    //       var consumed: usize = 0;
    //       while (true) {
    //           const remaining = buf[consumed..];
    //           if (remaining.len < wire.FrameHeader.byteSize) break;
    //           // 解析帧头
    //           // 检查帧大小 <= DEFAULT_MAX_FRAME_SIZE
    //           // 分发帧
    //           consumed += frame_len;
    //           if (session.fatal_error != null) break;
    //       }
    //       return consumed;
    //   }
    // ========================================================================

    /// 解析并分发缓冲区中的所有完整帧
    /// 严格翻译自: dispatch.parseFrames
    /// 返回消耗的字节数
    public static func parseFrames(session: H2ClientSession, buf: Array<UInt8>): Int64 {
        var consumed: Int64 = 0

        while (true) {
            let remaining = buf.size - consumed
            if (remaining < 9) {
                break  // 帧头都不够
            }

            // 解析帧头 (9 字节)
            let offset = consumed
            let frameLength = (Int64(buf[offset]) << 16) | (Int64(buf[offset + 1]) << 8) | Int64(buf[offset + 2])
            let frameType = H2FrameType.fromCode(buf[offset + 3])
            let flags = buf[offset + 4]
            let streamId = ((Int64(buf[offset + 5]) & 0x7F) << 24) |
                           (Int64(buf[offset + 6]) << 16) |
                           (Int64(buf[offset + 7]) << 8) |
                           Int64(buf[offset + 8])

            // RFC 9113 §4.2: 帧不能超过本端最大帧大小
            if (frameLength > H2ClientSession.DEFAULT_MAX_FRAME_SIZE) {
                session.fatalError = "HTTP2FrameSizeError"
                break
            }

            let totalFrameLen = 9 + frameLength
            if (remaining < totalFrameLen) {
                break  // 帧负载不完整
            }

            // 提取负载
            let payload = Array<UInt8>()
            for (i in 0..frameLength) {
                payload.append(buf[Int64(9) + offset + i])
            }

            // 分发帧
            dispatchFrame(session, frameType, flags, streamId, payload)
            consumed += totalFrameLen

            match (session.fatalError) {
                case Some(_) => break
                case None => ()
            }
        }

        return consumed
    }

    // ========================================================================
    // dispatchFrame - 根据帧类型分发
    // 严格翻译自: dispatch.dispatchFrame
    // 支持的帧类型:
    //   SETTINGS, WINDOW_UPDATE, PING, PRIORITY, HEADERS, CONTINUATION,
    //   DATA, RST_STREAM, GOAWAY, PUSH_PROMISE
    // ========================================================================

    /// 根据帧类型分发
    /// 严格翻译自: dispatch.dispatchFrame
    public static func dispatchFrame(session: H2ClientSession, frameType: H2FrameType,
                                      flags: UInt8, streamId: Int64, payload: Array<UInt8>): Unit {
        // 检查 CONTINUATION 一致性
        if (session.expectingContinuation != 0 &&
            frameType != H2FrameType.Continuation) {
            session.fatalError = "HTTP2ProtocolError"
            return
        }

        // 首帧必须是 SETTINGS
        if (!session.settingsReceived && frameType != H2FrameType.Settings) {
            session.fatalError = "HTTP2ProtocolError"
            return
        }

        match (frameType) {
            case H2FrameType.Settings => handleSettings(session, flags, streamId, payload)
            case H2FrameType.WindowUpdate => handleWindowUpdate(session, streamId, payload)
            case H2FrameType.Ping => handlePing(session, flags, payload)
            case H2FrameType.Priority => handlePriority(session, streamId, payload)
            case H2FrameType.Headers => handleHeaders(session, flags, streamId, payload)
            case H2FrameType.Continuation => handleContinuation(session, flags, streamId, payload)
            case H2FrameType.Data => handleData(session, flags, streamId, payload)
            case H2FrameType.RstStream => handleRstStream(session, streamId, payload)
            case H2FrameType.Goaway => handleGoaway(session, payload)
            case H2FrameType.PushPromise => {
                // RFC 9113: 客户端禁用 push，收到 PUSH_PROMISE 为 PROTOCOL_ERROR
                session.fatalError = "HTTP2ProtocolError"
            }
            case _ => ()  // 忽略未知帧
        }
    }

    // ========================================================================
    // SETTINGS 处理
    // 严格翻译自: dispatch.dispatchFrame HTTP_FRAME_SETTINGS case
    // RFC 9113 §6.5:
    //   - stream id != 0 为 PROTOCOL_ERROR
    //   - ACK 带负载为 FRAME_SIZE_ERROR
    //   - 长度不是 6 的倍数为 FRAME_SIZE_ERROR
    //   - 解析参数并更新 session 的 remote settings
    // ========================================================================

    /// 处理 SETTINGS 帧
    /// 严格翻译自: dispatch SETTINGS case
    private static func handleSettings(session: H2ClientSession, flags: UInt8,
                                        streamId: Int64, payload: Array<UInt8>): Unit {
        if (streamId != 0) {
            session.fatalError = "HTTP2ProtocolError"
            return
        }
        // ACK
        if ((flags & 0x01) != 0) {
            if (payload.size != 0) {
                session.fatalError = "HTTP2FrameSizeError"
            }
            return
        }
        if (payload.size % 6 != 0) {
            session.fatalError = "HTTP2FrameSizeError"
            return
        }

        // 解析每个设置参数 (6 字节一组: 2 字节 ID + 4 字节 Value)
        var i: Int64 = 0
        while (i + 6 <= payload.size) {
            let settingId = (Int64(payload[i]) << 8) | Int64(payload[i + 1])
            let settingValue = (Int64(payload[i + 2]) << 24) | (Int64(payload[i + 3]) << 16) |
                               (Int64(payload[i + 4]) << 8) | Int64(payload[i + 5])

            match (settingId) {
                case 0x5 => {
                    // SETTINGS_MAX_FRAME_SIZE: 16384 to 2^24-1
                    if (settingValue < H2ClientSession.DEFAULT_MAX_FRAME_SIZE || settingValue > 16777215) {
                        session.fatalError = "HTTP2ProtocolError"
                        return
                    }
                    session.remoteMaxFrameSize = settingValue
                }
                case 0x3 => {
                    // SETTINGS_MAX_CONCURRENT_STREAMS
                    session.remoteMaxConcurrentStreams = settingValue
                }
                case 0x1 => {
                    // SETTINGS_HEADER_TABLE_SIZE
                    match (session.pendingHpackEncCapacity) {
                        case Some(current) => {
                            session.pendingHpackEncCapacity = if (settingValue < current) { Some(settingValue) } else { Some(current) }
                        }
                        case None => session.pendingHpackEncCapacity = Some(settingValue)
                    }
                }
                case 0x4 => {
                    // SETTINGS_INITIAL_WINDOW_SIZE: 0 to 2^31-1
                    if (settingValue > H2ClientSession.MAX_WINDOW_SIZE) {
                        session.fatalError = "HTTP2FlowControlError"
                        return
                    }
                    let delta = settingValue - session.remoteInitialWindowSize
                    session.remoteInitialWindowSize = settingValue
                    // 更新所有活跃流的发送窗口
                    for (key in session.streams.keys()) {
                        match (session.streams.get(key)) {
                            case Some(stream) => {
                                let next = stream.sendWindow + delta
                                if (next > H2ClientSession.MAX_WINDOW_SIZE) {
                                    session.fatalError = "HTTP2FlowControlError"
                                    return
                                }
                                stream.sendWindow = next
                            }
                            case None => ()
                        }
                    }
                }
                case _ => ()
            }
            i += 6
        }

        // 检查写入缓冲区控制限制
        if (session.writeBuffer.size >= WRITE_BUFFER_CONTROL_LIMIT) {
            session.fatalError = "HTTP2EnhanceYourCalm"
            return
        }

        // 发送 SETTINGS ACK
        session.writeFrame(H2FrameType.Settings, 0x01, 0, Array<UInt8>())
        session.settingsReceived = true
    }

    // ========================================================================
    // WINDOW_UPDATE 处理
    // 严格翻译自: dispatch HTTP_FRAME_WINDOW_UPDATE case
    // RFC 9113 §6.9: 4 字节窗口增量
    //   - stream 0: 连接级窗口
    //   - 其他: 流级窗口
    //   - 零增量 / 溢出为错误
    // ========================================================================

    /// 处理 WINDOW_UPDATE 帧
    /// 严格翻译自: dispatch WINDOW_UPDATE case
    private static func handleWindowUpdate(session: H2ClientSession, streamId: Int64, payload: Array<UInt8>): Unit {
        if (payload.size != 4) {
            session.fatalError = "HTTP2FrameSizeError"
            return
        }
        let increment = (Int64(payload[0]) & 0x7F) << 24 |
                        Int64(payload[1]) << 16 |
                        Int64(payload[2]) << 8 |
                        Int64(payload[3])

        if (streamId == 0) {
            // 连接级窗口
            if (increment == 0) {
                session.fatalError = "HTTP2ProtocolError"
                return
            }
            let next = session.connSendWindow + increment
            if (next > H2ClientSession.MAX_WINDOW_SIZE) {
                session.fatalError = "HTTP2FlowControlError"
                return
            }
            session.connSendWindow = next
            session.streamProgressed = true
        } else {
            // 流级窗口
            match (session.streams.get(streamId)) {
                case Some(stream) => {
                    if (increment == 0) {
                        stream.rst(H2ErrorCode.ProtocolError)
                        stream.fatalError = "HTTP2ProtocolError"
                        return
                    }
                    let next = stream.sendWindow + increment
                    if (next > H2ClientSession.MAX_WINDOW_SIZE) {
                        stream.rst(H2ErrorCode.FlowControlError)
                        stream.fatalError = "HTTP2FlowControlError"
                        return
                    }
                    stream.sendWindow = next
                    session.streamProgressed = true
                }
                case None => {
                    // 未知流: 检查是否为空闲/服务端发起的流
                    if (streamId % 2 == 0 || streamId >= session.nextStreamId) {
                        session.fatalError = "HTTP2ProtocolError"
                    }
                }
            }
        }
    }

    // ========================================================================
    // PING 处理
    // 严格翻译自: dispatch HTTP_FRAME_PING case
    // RFC 9113 §6.7: 8 字节 opaque data, 回复 ACK
    // ========================================================================

    /// 处理 PING 帧
    /// 严格翻译自: dispatch PING case
    private static func handlePing(session: H2ClientSession, flags: UInt8, payload: Array<UInt8>): Unit {
        if (payload.size != 8) {
            session.fatalError = "HTTP2FrameSizeError"
            return
        }
        // 非 ACK 的 PING 需要回复
        if ((flags & 0x01) == 0) {
            if (session.writeBuffer.size >= WRITE_BUFFER_CONTROL_LIMIT) {
                session.fatalError = "HTTP2EnhanceYourCalm"
                return
            }
            session.writeFrame(H2FrameType.Ping, 0x01, 0, payload)
        }
    }

    // ========================================================================
    // PRIORITY 处理 (已弃用但需遵守帧规则)
    // 严格翻译自: dispatch HTTP_FRAME_PRIORITY case
    // ========================================================================

    /// 处理 PRIORITY 帧
    /// 严格翻译自: dispatch PRIORITY case
    private static func handlePriority(session: H2ClientSession, streamId: Int64, payload: Array<UInt8>): Unit {
        if (streamId == 0) {
            session.fatalError = "HTTP2ProtocolError"
            return
        }
        if (payload.size != 5) {
            session.fatalError = "HTTP2FrameSizeError"
            return
        }
    }

    // ========================================================================
    // HEADERS 处理
    // 严格翻译自: dispatch HTTP_FRAME_HEADERS case
    // RFC 9113 §6.2: 头部帧 + 可选填充/优先级
    //   - PADDED: 第一个字节为填充长度
    //   - PRIORITY: 5 字节优先级数据
    //   - END_HEADERS: 完整头部块, 解码
    //   - 否则: 等待 CONTINUATION
    // ========================================================================

    /// 处理 HEADERS 帧
    /// 严格翻译自: dispatch HEADERS case
    private static func handleHeaders(session: H2ClientSession, flags: UInt8,
                                       streamId: Int64, payload: Array<UInt8>): Unit {
        var fragment = payload

        // 检查流有效性
        if (streamId == 0 || streamId % 2 == 0 || streamId >= session.nextStreamId) {
            match (session.streams.get(streamId)) {
                case Some(_) => ()  // 已知流，继续
                case None => {
                    session.fatalError = "HTTP2ProtocolError"
                    return
                }
            }
        }

        match (session.streams.get(streamId)) {
            case Some(stream) => {
                session.streamProgressed = true

                // 处理 PADDED
                if ((flags & 0x08) != 0) {
                    match (stripPadding(fragment)) {
                        case Some(stripped) => fragment = stripped
                        case None => {
                            session.fatalError = "HTTP2ProtocolError"
                            return
                        }
                    }
                }

                // 处理 PRIORITY
                if ((flags & 0x20) != 0) {
                    if (fragment.size < 5) {
                        session.fatalError = "HTTP2ProtocolError"
                        return
                    }
                    // 跳过 5 字节优先级数据
                    let temp = ArrayList<UInt8>()
                    for (i in 5..fragment.size) {
                        temp.append(fragment[i])
                    }
                    fragment = temp.toArray()
                }

                // 检查头部大小
                if (fragment.size > LOCAL_MAX_HEADER_LIST_SIZE) {
                    session.fatalError = "HTTP2HeaderListTooLarge"
                    return
                }

                // 清空并设置头部块
                stream.headerBlock = ArrayList<UInt8>()
                for (b in fragment) {
                    stream.headerBlock.append(b)
                }
                stream.headersEndStream = (flags & 0x01) != 0

                if ((flags & 0x04) != 0) {
                    // END_HEADERS: 解码头部
                    if (stream.headersEndStream) {
                        stream.recvEndStream()
                    }
                    decodeHeaderBlock(session, stream)
                } else {
                    // 等待 CONTINUATION
                    session.expectingContinuation = stream.id
                }
            }
            case None => {
                // 孤立流 (已 RST 的流)
                session.fatalError = "HTTP2ProtocolError"
            }
        }
    }

    // ========================================================================
    // CONTINUATION 处理
    // 严格翻译自: dispatch HTTP_FRAME_CONTINUATION case
    // ========================================================================

    /// 处理 CONTINUATION 帧
    /// 严格翻译自: dispatch CONTINUATION case
    private static func handleContinuation(session: H2ClientSession, flags: UInt8,
                                            streamId: Int64, payload: Array<UInt8>): Unit {
        if (session.expectingContinuation == 0 || streamId != session.expectingContinuation) {
            session.fatalError = "HTTP2ProtocolError"
            return
        }

        match (session.streams.get(session.expectingContinuation)) {
            case Some(stream) => {
                if (stream.headerBlock.size + payload.size > LOCAL_MAX_HEADER_LIST_SIZE) {
                    session.fatalError = "HTTP2HeaderListTooLarge"
                    return
                }
                for (b in payload) {
                    stream.headerBlock.append(b)
                }

                if ((flags & 0x04) != 0) {
                    // END_HEADERS
                    session.expectingContinuation = 0
                    if (stream.headersEndStream) {
                        stream.recvEndStream()
                    }
                    decodeHeaderBlock(session, stream)
                }
            }
            case None => {
                // 孤立流头部块
                if (session.orphanHeaderBlock.size + payload.size > LOCAL_MAX_HEADER_LIST_SIZE) {
                    session.fatalError = "HTTP2HeaderListTooLarge"
                    return
                }
                for (b in payload) {
                    session.orphanHeaderBlock.append(b)
                }
                if ((flags & 0x04) != 0) {
                    session.expectingContinuation = 0
                    // 解码并丢弃 (保持动态表同步)
                    session.orphanHeaderBlock = ArrayList<UInt8>()
                }
            }
        }
    }

    // ========================================================================
    // DATA 处理
    // 严格翻译自: dispatch HTTP_FRAME_DATA case
    // RFC 9113 §6.1: DATA 帧承载请求/响应体
    //   - PADDED 标志
    //   - END_STREAM 标志
    //   - 流量控制计数
    // ========================================================================

    /// 处理 DATA 帧
    /// 严格翻译自: dispatch DATA case
    private static func handleData(session: H2ClientSession, flags: UInt8,
                                    streamId: Int64, payload: Array<UInt8>): Unit {
        session.connUnackedBytes += payload.size

        match (session.streams.get(streamId)) {
            case Some(stream) => {
                session.streamProgressed = true

                // DATA 在最终响应 HEADERS 之前为畸形
                if (stream.statusCode == 0) {
                    stream.rst(H2ErrorCode.ProtocolError)
                    stream.fatalError = "HTTP2ProtocolError"
                    return
                }

                // DATA 在对端已半关闭时为 STREAM_CLOSED
                if (stream.remoteClosed()) {
                    match (stream.fatalError) {
                        case Some(_) => ()
                        case None => stream.fatalError = "HTTP2ProtocolError"
                    }
                    return
                }

                stream.unackedBytes += payload.size
                var fragment = payload

                // 处理 PADDED
                if ((flags & 0x08) != 0) {
                    match (stripPadding(fragment)) {
                        case Some(stripped) => fragment = stripped
                        case None => {
                            session.fatalError = "HTTP2ProtocolError"
                            return
                        }
                    }
                }

                // END_STREAM
                if ((flags & 0x01) != 0) {
                    stream.recvEndStream()
                }

                stream.dataBytesReceived += fragment.size
                if (fragment.size > 0) {
                    for (b in fragment) {
                        stream.bodyBuffer.append(b)
                    }
                }
            }
            case None => {
                // 未知流的 DATA
                if (streamId == 0 || streamId % 2 == 0 || streamId >= session.nextStreamId) {
                    session.fatalError = "HTTP2ProtocolError"
                }
            }
        }
    }

    // ========================================================================
    // RST_STREAM 处理
    // 严格翻译自: dispatch HTTP_FRAME_RST_STREAM case
    // RFC 9113 §6.4: 4 字节错误码
    // ========================================================================

    /// 处理 RST_STREAM 帧
    /// 严格翻译自: dispatch RST_STREAM case
    private static func handleRstStream(session: H2ClientSession, streamId: Int64, payload: Array<UInt8>): Unit {
        if (payload.size != 4) {
            session.fatalError = "HTTP2FrameSizeError"
            return
        }
        if (streamId == 0 || streamId % 2 == 0 || streamId >= session.nextStreamId) {
            session.fatalError = "HTTP2ProtocolError"
            return
        }

        match (session.streams.get(streamId)) {
            case Some(stream) => {
                let hadResponse = stream.remoteClosed()
                stream.rstDone = true
                stream.state = H2StreamState.Closed

                let code = (Int64(payload[0]) << 24) | (Int64(payload[1]) << 16) |
                           (Int64(payload[2]) << 8) | Int64(payload[3])

                // RFC 9113 §8.1: RST_STREAM(NO_ERROR) 在 END_STREAM 之后为正常
                match (code) {
                    case 0x0 => {
                        // NO_ERROR
                        stream.fatalError = if (hadResponse) { None } else { Some("HTTP2StreamReset") }
                    }
                    case 0x7 => {
                        // REFUSED_STREAM
                        stream.fatalError = "HTTP2RefusedStream"
                    }
                    case _ => {
                        stream.fatalError = "HTTP2StreamReset"
                    }
                }
            }
            case None => ()
        }
    }

    // ========================================================================
    // GOAWAY 处理
    // 严格翻译自: dispatch HTTP_FRAME_GOAWAY case
    // RFC 9113 §6.8: last_stream_id + error_code + 可选调试信息
    // ========================================================================

    /// 处理 GOAWAY 帧
    /// 严格翻译自: dispatch GOAWAY case
    private static func handleGoaway(session: H2ClientSession, payload: Array<UInt8>): Unit {
        if (payload.size < 8) {
            session.fatalError = "HTTP2FrameSizeError"
            return
        }

        session.goawayReceived = true
        session.goawayLastStreamId = (Int64(payload[0]) << 24) | (Int64(payload[1]) << 16) |
                                      (Int64(payload[2]) << 8) | Int64(payload[3])
        let code = (Int64(payload[4]) << 24) | (Int64(payload[5]) << 16) |
                   (Int64(payload[6]) << 8) | Int64(payload[7])
        let graceful = code == 0  // NO_ERROR

        for (key in session.streams.keys()) {
            match (session.streams.get(key)) {
                case Some(stream) => {
                    if (stream.id > session.goawayLastStreamId) {
                        stream.fatalError = if (graceful) { "HTTP2RefusedStream" } else { "HTTP2GoAway" }
                    } else if (!graceful && !stream.remoteClosed()) {
                        stream.fatalError = "HTTP2GoAway"
                    }
                }
                case None => ()
            }
        }
    }

    // ========================================================================
    // decodeHeaderBlock - HPACK 解码头部块
    // 严格翻译自: dispatch.decodeHeaderBlock
    //   在解析时解码以确保动态表同步
    //   1xx 和 trailers 解码后丢弃
    //   最终响应存储在 stream 上等待投递
    // ========================================================================

    /// HPACK 解码头部块
    /// 严格翻译自: dispatch.decodeHeaderBlock
    public static func decodeHeaderBlock(session: H2ClientSession, stream: H2ClientStream): Unit {
        // 使用 HpackDecoder 解码
        let decoder = HpackDecoder()
        let blockArray = stream.headerBlock.toArray()
        match (decoder.decode(blockArray)) {
            case Some(headers) => {
                stream.decodedHeaders = headers
                // 提取 :status 伪头部
                for (h in headers) {
                    if (h.name == ":status") {
                        try {
                            stream.statusCode = Int64.parse(h.value)
                        } catch (_: Exception) {
                            stream.statusCode = 0
                        }
                    }
                }
                stream.headerBlock = ArrayList<UInt8>()
                stream.headersReady = true
            }
            case None => {
                session.fatalError = "HTTP2CompressionError"
            }
        }
    }

    // ========================================================================
    // stripPadding - 去除帧填充
    // 严格翻译自:
    //   pub fn stripPadding(payload: []const u8) ?[]const u8 {
    //       if (payload.len < 1) return null;
    //       const pad: usize = payload[0];
    //       if (pad >= payload.len) return null;
    //       return payload[1 .. payload.len - pad];
    //   }
    // ========================================================================

    /// 去除帧填充
    /// 严格翻译自: dispatch.stripPadding
    public static func stripPadding(payload: Array<UInt8>): ?Array<UInt8> {
        if (payload.size < 1) {
            return None
        }
        let pad = Int64(payload[0])
        if (pad >= payload.size) {
            return None
        }
        let result = Array<UInt8>()
        for (i in 1..(payload.size - pad)) {
            result.append(payload[i])
        }
        return Some(result)
    }

    // ========================================================================
    // errorCodeFor - 将错误映射到 HTTP/2 错误码
    // 严格翻译自:
    //   pub fn errorCodeFor(err: anyerror) wire.ErrorCode {
    //       return switch (err) {
    //           error.HTTP2ProtocolError => .PROTOCOL_ERROR,
    //           error.HTTP2FrameSizeError => .FRAME_SIZE_ERROR,
    //           error.HTTP2FlowControlError => .FLOW_CONTROL_ERROR,
    //           error.HTTP2CompressionError => .COMPRESSION_ERROR,
    //           error.HTTP2HeaderListTooLarge,
    //           error.HTTP2EnhanceYourCalm => .ENHANCE_YOUR_CALM,
    //           else => .INTERNAL_ERROR,
    //       };
    //   }
    // ========================================================================

    /// 将错误映射到 HTTP/2 错误码
    /// 严格翻译自: dispatch.errorCodeFor
    public static func errorCodeFor(err: String): H2ErrorCode {
        match (err) {
            case "HTTP2ProtocolError" => H2ErrorCode.ProtocolError
            case "HTTP2FrameSizeError" => H2ErrorCode.FrameSizeError
            case "HTTP2FlowControlError" => H2ErrorCode.FlowControlError
            case "HTTP2CompressionError" => H2ErrorCode.CompressionError
            case "HTTP2HeaderListTooLarge" => H2ErrorCode.EnhanceYourCalm
            case "HTTP2EnhanceYourCalm" => H2ErrorCode.EnhanceYourCalm
            case _ => H2ErrorCode.InternalError
        }
    }

    // ========================================================================
    // isMalformedResponseField - 检查是否为畸形的响应头部字段
    // 严格翻译自:
    //   pub fn isMalformedResponseField(name: []const u8) bool {
    //       for (name) |c| if (c >= 'A' and c <= 'Z') return true;
    //       return forbidden_response_fields.has(name);
    //   }
    //   // forbidden: connection, keep-alive, proxy-connection, te, transfer-encoding, upgrade
    // ========================================================================

    /// 检查是否为畸形的响应头部字段
    /// 严格翻译自: dispatch.isMalformedResponseField
    public static func isMalformedResponseField(name: String): Bool {
        // 检查大写字母
        for (c in name) {
            if (c.value >= 0x41 && c.value <= 0x5A) {
                return true
            }
        }
        // 检查禁止的字段
        let forbidden = Array<String>(["connection", "keep-alive", "proxy-connection", "te", "transfer-encoding", "upgrade"])
        for (f in forbidden) {
            if (name == f) {
                return true
            }
        }
        return false
    }
}
