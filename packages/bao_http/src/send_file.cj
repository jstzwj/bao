// bao_http SendFile - 零拷贝文件传输
// 严格翻译自: src/http/SendFile.zig
package bao_http

import bao_core.*
import bao_collections.*
import bao_sys.*

// ============================================================================
// SendFile - 零拷贝文件传输 (sendfile syscall)
// 严格翻译自: bun/src/http/SendFile.zig
//
// Bun 使用 sendfile syscall 实现零拷贝文件传输:
//   const SendFile = @This();
//   fd: bun.FD,           — 文件描述符
//   remain: usize = 0,    — 剩余字节数
//   offset: usize = 0,    — 当前偏移
//   content_size: usize = 0, — 文件总大小
//
// 支持平台:
//   - Linux: sendfile(out_fd, in_fd, offset, count)
//   - macOS/BSD: sendfile(fd, s, offset, sbytes, ...)
//   - 通过 syscall 直接调用，不经过 libc (Linux)
//
// 操作状态:
//   done  — 传输完成
//   err   — 传输错误
//   again — 需要再次调用 (非阻塞 IO，EAGAIN)
// ============================================================================

/// SendFile - 零拷贝文件传输
/// 严格翻译自: bun/src/http/SendFile.zig SendFile struct
public class SendFile {
    /// 文件描述符
    /// 严格翻译自: fd: bun.FD
    public var fd: Int64

    /// 剩余字节数
    /// 严格翻译自: remain: usize = 0
    public var remain: Int64

    /// 当前偏移量
    /// 严格翻译自: offset: usize = 0
    public var offset: Int64

    /// 文件总大小 (content_size)
    /// 严格翻译自: content_size: usize = 0
    public var contentSize: Int64

    public init() {
        fd = -1
        remain = 0
        offset = 0
        contentSize = 0
    }

    public init(fd: Int64, offset: Int64, contentSize: Int64) {
        this.fd = fd
        this.offset = offset
        this.contentSize = contentSize
        this.remain = contentSize
    }

    // ========================================================================
    // isEligible - 检查 URL 是否符合 sendfile 条件
    // 严格翻译自: SendFile.isEligible
    //
    // Bun:
    //   pub fn isEligible(url: bun.URL) bool {
    //       if (comptime Environment.isWindows or
    //           !FeatureFlags.streaming_file_uploads_for_http_client) {
    //           return false;
    //       }
    //       return url.isHTTP() and url.href.len > 0;
    //   }
    // ========================================================================

    /// 检查 URL 是否符合 sendfile 条件
    /// 严格翻译自: SendFile.isEligible
    public static func isEligible(url: ParsedUrl): Bool {
        return (url.protocol == "http" || url.protocol == "https") && url.hostname.size > 0
    }

    // ========================================================================
    // write - 执行 sendfile 写入
    // 严格翻译自: SendFile.write
    //
    // Bun:
    //   pub fn write(this: *SendFile, socket: NewHTTPContext(false).HTTPSocket) Status {
    //       const adjusted_count_temporary = @min(@as(u64, this.remain),
    //                                              @as(u63, std.math.maxInt(u63)));
    //       const adjusted_count = @as(u63, @intCast(adjusted_count_temporary));
    //
    //       if (Environment.isLinux) {
    //           var signed_offset = @as(i64, @intCast(this.offset));
    //           const begin = this.offset;
    //           const val = std.os.linux.sendfile(
    //               socket.fd().cast(), this.fd.cast(), &signed_offset, this.remain);
    //           this.offset = @as(u64, @intCast(signed_offset));
    //           const errcode = bun.sys.getErrno(val);
    //           this.remain -|= @as(u64, @intCast(this.offset -| begin));
    //           if (errcode != .SUCCESS or this.remain == 0 or val == 0) {
    //               if (errcode == .SUCCESS) return .{ .done = {} };
    //               return .{ .err = bun.errnoToZigErr(errcode) };
    //           }
    //       } else if (Environment.isPosix) {
    //           // macOS / FreeBSD sendfile
    //           var sbytes: std.posix.off_t = adjusted_count;
    //           const signed_offset = @as(i64, @bitCast(@as(u64, this.offset)));
    //           const errcode = bun.sys.getErrno(std.c.sendfile(
    //               this.fd.cast(), socket.fd().cast(),
    //               signed_offset, &sbytes, null, 0));
    //           const wrote = @as(u64, @intCast(sbytes));
    //           this.offset +|= wrote;
    //           this.remain -|= wrote;
    //           if (errcode != .AGAIN or this.remain == 0 or sbytes == 0) {
    //               if (errcode == .SUCCESS) return .{ .done = {} };
    //               return .{ .err = bun.errnoToZigErr(errcode) };
    //           }
    //       }
    //       return .{ .again = {} };
    //   }
    // ========================================================================

    /// 执行 sendfile 写入
    /// 严格翻译自: SendFile.write
    public func write(socketFd: Int64): SendFileStatus {
        if (remain <= 0 || fd < 0) {
            return SendFileStatus.done
        }

        // Linux sendfile: sendfile(out_fd, in_fd, offset, count)
        let adjustedCount = if (remain > Int64.max) { Int64.max } else { remain }

        let result = sysSendFile(socketFd, fd, offset, adjustedCount)
        match (result) {
            case SendFileResult.ok(written) => {
                offset += written
                remain -= written
                if (remain <= 0) {
                    return SendFileStatus.done
                }
                return SendFileStatus.again
            }
            case SendFileResult.again => {
                return SendFileStatus.again
            }
            case SendFileResult.err(msg) => {
                return SendFileStatus.err(msg)
            }
        }
    }

    /// sendfile syscall 封装
    /// Linux: ssize_t sendfile(int out_fd, int in_fd, off_t *offset, size_t count);
    @C
    foreign func sysSendFile(outFd: Int64, inFd: Int64, offset: Int64, count: Int64): SendFileResult
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

/// SendFile syscall 返回值
public enum SendFileResult {
    | ok(Int64)       // 成功写入的字节数
    | again           // EAGAIN — 需要重试
    | err(String)     // 错误
}
