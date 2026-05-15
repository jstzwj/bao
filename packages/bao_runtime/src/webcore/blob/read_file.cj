// ReadFile - 文件读取操作
// 对应 Bun: src/runtime/webcore/blob/read_file.zig
// 严格翻译自: src/runtime/webcore/blob/read_file.zig
package bao_runtime

import bao_core.*

// ============================================================================
// ReadFileResultType - 文件读取结果类型
// 对应 Bun: read_file.ReadFileResultType
// ============================================================================

/// 文件读取结果类型
/// 对应 Bun: read_file.ReadFileResultType
public enum ReadFileResultType {
    | Success(ReadFileSuccess)     // 成功
    | Error(ReadFileError)         // 错误

    /// 是否为错误
    public func isError(): Bool {
        match (this) {
            case Error(_) => true
            case _ => false
        }
    }
}

/// 文件读取成功结果
/// 对应 Bun: read_file.ReadFileResult
public class ReadFileSuccess {
    /// 读取的字节
    public var bytes: Array<UInt8>
    /// 是否为临时数据
    public var isTemporary: Bool

    public init(bytes: Array<UInt8>) {
        this.bytes = bytes
        isTemporary = false
    }
}

/// 文件读取错误
/// 对应 Bun: read_file.ReadFileError (SystemError)
public class ReadFileError {
    /// 错误消息
    public var message: String
    /// 错误码
    public var errno: Int64
    /// 系统调用名
    public var syscall: String

    public init(message: String) {
        this.message = message
        errno = -1
        syscall = "read"
    }
}

// ============================================================================
// ReadFile - 文件读取操作
// 对应 Bun: src/runtime/webcore/blob/read_file.zig ReadFile
// ============================================================================

/// ReadFile — 文件读取操作
/// 对应 Bun: src/runtime/webcore/blob/read_file.zig ReadFile
public class ReadFile {
    /// 文件路径
    public var path: String
    /// 偏移量
    public var offset: BlobSizeType
    /// 大小
    public var size: BlobSizeType

    public init(path: String, offset: BlobSizeType, size: BlobSizeType) {
        this.path = path
        this.offset = offset
        this.size = size
    }

    /// 同步读取文件
    /// 对应 Bun: read_file.ReadFile.run()
    public func run(): ReadFileResultType {
        try {
            let bytes = BaoFile.readAllBytes(path)
            // 应用偏移和大小
            let start = offset
            let end = if (size > 0) { offset + size } else { bytes.size }
            if (start >= bytes.size) {
                return ReadFileResultType.Success(ReadFileSuccess(Array<UInt8>()))
            }
            let actualEnd = if (end > bytes.size) { bytes.size } else { end }
            let result = ArrayList<UInt8>()
            for (i in start..actualEnd) {
                result.append(bytes[Int64(i)])
            }
            return ReadFileResultType.Success(ReadFileSuccess(result.toArray()))
        } catch (e: Exception) {
            return ReadFileResultType.Error(ReadFileError(e.message))
        }
    }
}
