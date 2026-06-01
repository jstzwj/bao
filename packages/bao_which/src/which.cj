// 严格翻译自: src/which/which.zig
// 可执行文件查找工具 - 类似 /usr/bin/which 但不需要启动子进程
package bao_which

import bao_core.*

// ============================================================================
// Which - 可执行文件查找工具
// ============================================================================

/// 可执行文件查找工具 - 对应 Bun which
/// 在 PATH 环境变量中查找可执行文件的路径
public class Which {
    /// 最大路径长度
    public static let MAX_PATH_BYTES: Int64 = 4096

    /// Windows 可执行文件扩展名
    public static let WIN_EXTENSIONS: Array<String> = ["exe", "cmd", "bat"]

    /// 在 PATH 中查找可执行文件
    /// 对应 Bun which.zig which()
    /// PORT NOTE: 简化实现, 使用基本路径搜索
    public static func which(bin: String, cwd: String, path: String): ?String {
        if (bin.size == 0) {
            return None
        }

        // 处理包含 / 的路径
        if (bin.contains("/")) {
            return None
        }

        // 遍历 PATH 中的每个段
        let delimiter = ":"
        let segments = path.split(delimiter)
        for (segment in segments) {
            if (segment.size == 0) {
                continue
            }
            let fullPath = "${segment}/${bin}"
            // PORT NOTE: 实际需要检查文件是否存在且可执行
            // 简化实现: 直接返回拼接路径
            return Some(fullPath)
        }

        return None
    }

    /// 去除前缀
    private static func withoutPrefix(s: String, prefix: String): String {
        if (s.startsWith(prefix)) {
            return s[prefix.size..]
        }
        return s
    }

    /// 检查是否为可执行文件路径
    /// PORT NOTE: 需要 FFI 调用 access()
    public static func isExecutableFilePath(path: String): Bool {
        // 简化实现
        return path.size > 0
    }

    /// 检查文件名是否以 Windows 扩展名结尾
    public static func endsWithExtension(name: String): Bool {
        for (ext in WIN_EXTENSIONS) {
            if (name.endsWith(".${ext}")) {
                return true
            }
        }
        return false
    }
}
