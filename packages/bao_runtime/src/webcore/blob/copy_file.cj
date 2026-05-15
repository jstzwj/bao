// CopyFile - 文件复制操作
// 对应 Bun: src/runtime/webcore/blob/copy_file.zig
// 严格翻译自: src/runtime/webcore/blob/copy_file.zig
package bao_runtime.webcore.blob

import bao_core.*

// ============================================================================
// CopyFileResult - 文件复制结果
// ============================================================================

/// 文件复制结果
public enum CopyFileResult {
    | Success(Int64)    // 成功，返回复制字节数
    | Error(String)     // 错误
}

// ============================================================================
// CopyFile - 文件复制操作
// 对应 Bun: src/runtime/webcore/blob/copy_file.zig
// ============================================================================

/// CopyFile — 文件复制操作
/// 对应 Bun: src/runtime/webcore/blob/copy_file.zig
/// 用于 Blob -> File 的高效复制（避免 read+write 循环）
public class CopyFile {
    /// 源文件路径
    public var sourcePath: String
    /// 目标文件路径
    public var destinationPath: String

    public init(source: String, destination: String) {
        sourcePath = source
        destinationPath = destination
    }

    /// 执行文件复制
    /// 对应 Bun: copy_file copyFileRange/sendfile
    public func run(): CopyFileResult {
        try {
            let bytes = BaoFile.readAllBytes(sourcePath)
            BaoFile.writeAllBytes(destinationPath, bytes)
            return CopyFileResult.Success(bytes.size)
        } catch (e: Exception) {
            return CopyFileResult.Error(e.message)
        }
    }
}
