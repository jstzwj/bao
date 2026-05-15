// Streams - 流 API 基础设施
// 对应 Bun: src/runtime/webcore/streams.zig
// 严格翻译自: src/runtime/webcore/streams.zig
package bao_runtime

import bao_core.*
import bao_collections.*

// ============================================================================
// StreamResult - 流结果
// 对应 Bun: streams.Result
// ============================================================================

/// 流结果
/// 对应 Bun: streams.Result
public enum StreamResult {
    | Empty                                  // 空
    | Ready                                  // 就绪
    | ChunkSize(BlobSizeType)                // 块大小
    | Owned(Array<UInt8>)                    // 拥有的数据
    | OwnedAndDone(Array<UInt8>)             // 拥有的数据且完成
    | Done(Array<UInt8>)                     // 完成
    | Temporary(Array<UInt8>)                // 临时数据
    | TemporaryAndDone(Array<UInt8>)         // 临时数据且完成
    | Error(String)                          // 错误
    | Aborted                                // 中止

    /// 获取数据切片
    /// 对应 Bun: streams.Result.slice()
    public func slice(): Array<UInt8> {
        match (this) {
            case Owned(bytes) => bytes
            case OwnedAndDone(bytes) => bytes
            case Done(bytes) => bytes
            case Temporary(bytes) => bytes
            case TemporaryAndDone(bytes) => bytes
            case _ => Array<UInt8>()
        }
    }

    /// 是否完成
    /// 对应 Bun: streams.Result.isDone()
    public func isDone(): Bool {
        match (this) {
            case OwnedAndDone(_) => true
            case Done(_) => true
            case TemporaryAndDone(_) => true
            case Empty => true
            case _ => false
        }
    }
}

// ============================================================================
// StreamResultWritable - 流可写结果
// 对应 Bun: streams.Result.Writable
// ============================================================================

/// 流可写结果
/// 对应 Bun: streams.Result.Writable
public enum StreamResultWritable {
    | Done
    | ChunkSize(Int64)
    | Error(String)

    /// 是否为错误
    public func isError(): Bool {
        match (this) {
            case Error(_) => true
            case _ => false
        }
    }
}

// ============================================================================
// StreamResultPending - 流结果待处理
// 对应 Bun: streams.Result.Pending
// ============================================================================

/// 流结果待处理
/// 对应 Bun: streams.Result.Pending
public class StreamResultPending {
    /// 结果
    public var result: StreamResult

    public init() {
        result = StreamResult.Done(Array<UInt8>())
    }
}

// ============================================================================
// DrainResult - 消耗结果
// 对应 Bun: jsc.WebCore.DrainResult
// ============================================================================

/// 消耗结果
/// 对应 Bun: jsc.WebCore.DrainResult
public enum DrainResult {
    | Empty
    | Aborted
    | EstimatedSize(Int64)
    | Owned(DrainedData)
}

/// 已消耗的数据
public class DrainedData {
    /// 数据列表
    public var list: ArrayList<UInt8>
    /// 大小提示
    public var sizeHint: Int64

    public init() {
        list = ArrayList<UInt8>()
        sizeHint = 0
    }
}
