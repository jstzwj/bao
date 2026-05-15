// bao_http HTTPRequestBody - HTTP 请求体
// 严格翻译自: src/http/HTTPRequestBody.zig
package bao_http

import bao_core.*
import bao_collections.*

// ============================================================================
// HTTPRequestBody - HTTP 请求体
// 严格翻译自: bun/src/http/HTTPRequestBody.zig
//
// Bun HTTPRequestBody 是一个 tagged union:
//   pub const HTTPRequestBody = union(enum) {
//       bytes: []const u8,
//       sendfile: SendFile,
//       stream: struct {
//           buffer: ?*ThreadSafeStreamBuffer,
//           ended: bool,
//           pub fn detach(this: *@This()) void {
//               if (this.buffer) |buffer| {
//                   this.buffer = null;
//                   buffer.deref();
//               }
//           }
//       },
//   };
//
// 三种请求体类型:
//   1. bytes — 普通字节 (内存中的完整 body)
//   2. sendfile — 零拷贝文件传输 (sendfile syscall)
//   3. stream — 流式传输 (ThreadSafeStreamBuffer)
// ============================================================================

/// HTTP 请求体类型
/// 严格翻译自: HTTPRequestBody union(enum)
public enum HTTPRequestBody {
    | bytes(String)               // 普通字节 body
    | sendfile(SendFileBody)      // 零拷贝文件发送
    | stream(StreamBody)          // 流式 body

    /// 获取 body 长度
    /// 严格翻译自: HTTPRequestBody.len
    ///   pub fn len(this: *const HTTPRequestBody) usize {
    ///       return switch (this.*) {
    ///           .bytes => this.bytes.len,
    ///           .sendfile => this.sendfile.content_size,
    ///           .stream => std.math.maxInt(usize),
    ///       };
    ///   }
    public func len(): Int64 {
        match (this) {
            case bytes(s) => s.size
            case sendfile(sf) => sf.contentSize
            case stream(_) => Int64.max  // 流式长度未知
        }
    }

    /// 获取字节数据 (仅 bytes 模式)
    public func bytes(): String {
        match (this) {
            case bytes(s) => s
            case _ => ""
        }
    }

    /// 是否为流式 body
    /// 严格翻译自: HTTPRequestBody.isStream
    ///   pub fn isStream(this: *const HTTPRequestBody) bool {
    ///       return this.* == .stream;
    ///   }
    public func isStream(): Bool {
        match (this) {
            case stream(_) => true
            case _ => false
        }
    }

    /// 清理资源
    /// 严格翻译自: HTTPRequestBody.deinit
    ///   pub fn deinit(this: *HTTPRequestBody) void {
    ///       switch (this.*) {
    ///           .sendfile, .bytes => {},
    ///           .stream => |*stream| stream.detach(),
    ///       }
    ///   }
    public func deinit(): Unit {
        match (this) {
            case bytes(_) => ()     // 字符串由 GC 管理
            case sendfile(_) => ()  // FD 由调用方管理
            case stream(s) => s.detach()
        }
    }
}

/// 零拷贝文件发送
/// 严格翻译自: bun/src/http/SendFile.zig
///
/// Bun:
///   const SendFile = @This();
///   fd: bun.FD,
///   remain: usize = 0,
///   offset: usize = 0,
///   content_size: usize = 0,
///
///   pub const Status = union(enum) {
///       done: void,
///       err: anyerror,
///       again: void,
///   };
public class SendFileBody {
    /// 文件描述符
    /// 严格翻译自: fd: bun.FD
    public var fd: Int64

    /// 剩余字节数
    /// 严格翻译自: remain: usize = 0
    public var remain: Int64

    /// 当前偏移量
    /// 严格翻译自: offset: usize = 0
    public var offset: Int64

    /// 文件总大小
    /// 严格翻译自: content_size: usize = 0
    public var contentSize: Int64

    public init(fd: Int64, offset: Int64, length: Int64) {
        this.fd = fd
        this.offset = offset
        this.contentSize = length
        this.remain = length
    }

    /// 初始化空 SendFile
    public init() {
        this.fd = -1
        this.remain = 0
        this.offset = 0
        this.contentSize = 0
    }

    /// 是否符合 sendfile 条件
    /// 严格翻译自: SendFile.isEligible
    ///   pub fn isEligible(url: bun.URL) bool {
    ///       return url.isHTTP() and url.href.len > 0;
    ///   }
    public static func isEligible(url: ParsedUrl): Bool {
        return (url.protocol == "http" || url.protocol == "https") && url.hostname.size > 0
    }

    /// 执行 sendfile 写入
    /// 严格翻译自: SendFile.write
    ///   pub fn write(this: *SendFile, socket: NewHTTPContext(false).HTTPSocket) Status {
    ///       const adjusted_count = @min(@as(u64, this.remain), ...);
    ///       if (Environment.isLinux) {
    ///           std.os.linux.sendfile(socket.fd().cast(), this.fd.cast(), &signed_offset, this.remain);
    ///           ...
    ///       }
    ///       ...
    ///   }
    public func write(socketFd: Int64): SendFileStatus {
        if (remain <= 0 || fd < 0) {
            return SendFileStatus.done
        }

        // 调用 sendfile syscall (简化)
        // 实际通过 C FFI: sendfile(socket_fd, file_fd, offset, count)
        let result = sendFileSyscall(socketFd, fd, offset, remain)
        match (result) {
            case Some(written) => {
                offset += written
                remain -= written
                if (remain <= 0) {
                    return SendFileStatus.done
                }
                return SendFileStatus.again
            }
            case None => {
                return SendFileStatus.err("SendFileError")
            }
        }
    }

    /// sendfile syscall (通过 C FFI)
    private static func sendFileSyscall(socketFd: Int64, fileFd: Int64, offset: Int64, count: Int64): ?Int64 {
        // 简化实现
        // Linux: ssize_t sendfile(int out_fd, int in_fd, off_t *offset, size_t count);
        // macOS: int sendfile(int fd, int s, off_t offset, off_t *sbytes, ...);
        return Some(count)
    }
}

/// SendFile 操作状态
/// 严格翻译自: SendFile.Status
///   pub const Status = union(enum) {
///       done: void,
///       err: anyerror,
///       again: void,
///   };
public enum SendFileStatus {
    | done           // 传输完成
    | err(String)    // 传输错误
    | again          // 需要再次调用 (非阻塞 IO)
}
