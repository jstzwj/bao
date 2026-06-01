// 严格翻译自: src/runtime/webcore.zig
//   Web APIs implemented in Zig live here
package bao_runtime

import bao_core.*
import bao_collections.*
import bao_sys.*

// ============================================================================
// WebCore — Web API 核心模块
// 严格翻译自: src/runtime/webcore.zig
//
// Bun 的 webcore.zig 是一个聚合模块, 导出所有 Web API 的子模块:
//   Crypto, AbortSignal, WebWorker, EncodingLabel, Fetch, Response,
//   TextDecoder, TextEncoder, ReadableStream, Blob, Request, Body,
//   CookieMap, ObjectURLRegistry, Sink, FileSink, FetchHeaders, etc.
//
// 仓颉版本: 作为导入聚合, 提供统一入口点
// 实际实现在 webcore/ 子目录中的各个 .cj 文件
// ============================================================================

/// 路径或文件描述符的联合类型
/// 对应 Bun: PathOrFileDescriptor union(enum) { path: ZigString.Slice, fd: bun.FD }
public enum PathOrFileDescriptor {
    | path(String)
    | fd(Int64)

    /// 释放资源
    /// 对应 Bun: pub fn deinit(this: *const PathOrFileDescriptor) void
    public func deinit(): Unit {
        match (this) {
            case PathOrFileDescriptor.path(_) => ()
            case PathOrFileDescriptor.fd(_) => ()
        }
    }
}

/// 管道回调函数类型
/// 对应 Bun: Pipe.Function = *const fn (ctx: *anyopaque, stream: streams.Result, allocator: std.mem.Allocator) void
public type PipeCallback = (Any, StreamResult, Allocator) -> Unit

/// 管道结构
/// 对应 Bun: Pipe struct { ctx, onPipe }
public class Pipe {
    /// 上下文
    /// 翻译自: ctx: ?*anyopaque = null
    public var ctx: ?Any

    /// 管道回调
    /// 翻译自: onPipe: ?Function = null
    public var onPipe: ?PipeCallback

    public init() {
        ctx = None
        onPipe = None
    }

    public init(ctx: Any, onPipe: PipeCallback) {
        this.ctx = Some(ctx)
        this.onPipe = Some(onPipe)
    }

    /// 管道是否为空
    /// 翻译自: pub inline fn isEmpty(this: *const Pipe) bool
    public func isEmpty(): Bool {
        return ctx.isNone() && onPipe.isNone()
    }
}

/// 排空结果
/// 对应 Bun: DrainResult union(enum) { owned, estimated_size, empty, aborted }
public enum DrainResult {
    | owned(ByteList, Int64)     // list, size_hint
    | estimatedSize(Int64)
    | empty
    | aborted

    public operator func ==(right: DrainResult): Bool {
        match (this) {
            case DrainResult.owned(_, _) =>
                match (right) {
                    case DrainResult.owned(_, _) => true
                    case _ => false
                }
            case DrainResult.estimatedSize(s1) =>
                match (right) {
                    case DrainResult.estimatedSize(s2) => s1 == s2
                    case _ => false
                }
            case DrainResult.empty =>
                match (right) {
                    case DrainResult.empty => true
                    case _ => false
                }
            case DrainResult.aborted =>
                match (right) {
                    case DrainResult.aborted => true
                    case _ => false
                }
        }
    }

    public operator func !=(right: DrainResult): Bool {
        return !(this == right)
    }
}

/// 生命周期类型
/// 对应 Bun: Lifetime enum { clone, transfer, share, temporary }
public enum Lifetime {
    | clone       // 克隆数据
    | transfer    // 转移所有权
    | share       // 共享数据
    | temporary   // 临时数据 (如从 STDIN/STDERR 读取)

    public operator func ==(right: Lifetime): Bool {
        match (this) {
            case Lifetime.clone =>
                match (right) { case Lifetime.clone => true case _ => false }
            case Lifetime.transfer =>
                match (right) { case Lifetime.transfer => true case _ => false }
            case Lifetime.share =>
                match (right) { case Lifetime.share => true case _ => false }
            case Lifetime.temporary =>
                match (right) { case Lifetime.temporary => true case _ => false }
        }
    }

    public operator func !=(right: Lifetime): Bool {
        return !(this == right)
    }
}

/// DOMException 错误码
/// 对应 Bun: DOMExceptionCode (from JSErrorCode.zig)
public enum DOMExceptionCode {
    | unknown
    | indexSizeError
    | domstringSizeError
    | hierarchyRequestError
    | wrongDocumentError
    | invalidCharacterError
    | noDataAllowedError
    | noModificationAllowedError
    | notFoundError
    | notSupportedError
    | inUseAttributeError
    | invalidStateError
    | syntaxError
    | invalidModificationError
    | namespaceError
    | invalidAccessError
    | securityError
    | networkError
    | abortError
    | urlMismatchError
    | quotaExceededError
    | timeoutError
    | invalidNodeTypeError
    | dataCloneError
    | encodingError
    | notReadableError
    | unknownError
    | constraintError
    | transactionInactiveError
    | readonlyError
    | versionError
    | operationError

    public operator func ==(right: DOMExceptionCode): Bool {
        return this == right
    }

    public operator func !=(right: DOMExceptionCode): Bool {
        return !(this == right)
    }
}

/// 字节列表 (简化, 用于 DrainResult.owned)
public class ByteList {
    public var data: ArrayList<UInt8>
    public var size: Int64

    public init() {
        data = ArrayList<UInt8>()
        size = 0
    }
}

/// 流结果 (简化)
public class StreamResult {}
