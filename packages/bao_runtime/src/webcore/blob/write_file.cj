// WriteFile - 文件写入操作
// 对应 Bun: src/runtime/webcore/blob/write_file.zig
// 严格翻译自: src/runtime/webcore/blob/write_file.zig
package bao_runtime.webcore.blob

import bao_core.*
import bao_io.*

// ============================================================================
// WriteFileResult - 文件写入结果
// 对应 Bun: write_file result
// ============================================================================

/// 文件写入结果
public enum WriteFileResult {
    | Success(Int64)      // 成功，返回写入字节数
    | Error(String)       // 错误
}

// ============================================================================
// WriteFile - 文件写入操作
// 对应 Bun: src/runtime/webcore/blob/write_file.zig
// ============================================================================

/// WriteFile — 文件写入操作
/// 对应 Bun: src/runtime/webcore/blob/write_file.zig
public class WriteFile {
    /// 目标文件路径
    public var path: String
    /// 是否追加
    public var append: Bool

    public init(path: String) {
        this.path = path
        append = false
    }

    public init(path: String, append: Bool) {
        this.path = path
        this.append = append
    }

    /// 写入数据到文件
    /// 对应 Bun: write_file
    public func write(data: Array<UInt8>): WriteFileResult {
        let result = if (append) {
            BaoFile.appendAllBytes(path, data)
        } else {
            BaoFile.writeAllBytes(path, data)
        }
        match (result) {
            case SysMaybe<Unit>.Ok(_) => return WriteFileResult.Success(data.size)
            case SysMaybe<Unit>.Err(err) => return WriteFileResult.Error(err.message)
        }
    }
}
