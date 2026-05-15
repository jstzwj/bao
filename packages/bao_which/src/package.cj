// bao_which - 可执行文件查找工具
// 严格翻译自: bun/src/which/which.zig (173行)
//   类似 /usr/bin/which 但不需要启动子进程
//   在 PATH 环境变量中查找可执行文件
package bao_which

import bao_core.*
import bao_sys.*

// ============================================================================
// Which - 可执行文件查找工具
// 严格翻译自: which.zig - which()
//   pub fn which(buf, path, cwd, bin) ?[:0]const u8
//
// Like /usr/bin/which but without needing to exec a child process
// Remember to resolve the symlink if necessary
// ============================================================================

/// 可执行文件查找工具 - 对应 Bun which
/// 在 PATH 环境变量中查找可执行文件的路径
public class Which {
    /// 最大路径长度
    // 对应 bun.MAX_PATH_BYTES
    public static let MAX_PATH_BYTES: Int64 = 4096

    /// Windows 可执行文件扩展名
    // 严格翻译自: which.zig - win_extensions
    //   const win_extensions = .{ "exe", "cmd", "bat" };
    public static let WIN_EXTENSIONS: Array<String> = ["exe", "cmd", "bat"]

    // ========================================================================
    // which - 在 PATH 中查找可执行文件
    // 严格翻译自: which.zig - pub fn which(buf, path, cwd, bin) ?[:0]const u8
    //   if (bin.len > bun.MAX_PATH_BYTES) return null;
    //   if (bin.len == 0) return null;
    //   // handle absolute paths
    //   if (std.fs.path.isAbsolute(bin)) { ... }
    //   // handle relative paths with slashes
    //   if (bun.strings.containsChar(bin, '/')) { ... }
    //   // iterate over PATH segments
    //   var path_iter = std.mem.tokenizeScalar(u8, path, std.fs.path.delimiter);
    //   while (path_iter.next()) |segment| {
    //       if (isValid(buf, segment, bin)) |len| { return buf[0..len]; }
    //   }
    // ========================================================================

    /// 在 PATH 中查找可执行文件
    /// 对应 Bun which()
    /// - path: PATH 环境变量值 (如 "/usr/local/bin:/usr/bin:/bin")
    /// - cwd: 当前工作目录
    /// - bin: 要查找的可执行文件名
    /// 返回找到的完整路径，或 None
    public static func which(path: String, cwd: String, bin: String): ?String {
        if (bin.size > MAX_PATH_BYTES) {
            return None
        }
        if (bin.size == 0) {
            return None
        }

        // 处理绝对路径
        // 严格翻译自:
        //   if (std.fs.path.isAbsolute(bin)) {
        //       if (bun.sys.isExecutableFilePath(binZ)) return binZ;
        //       return null; // Do not look absolute paths in $PATH
        //   }
        if (Path.isAbsolute(bin)) {
            if (isExecutableFilePath(bin)) {
                return Some(bin)
            }
            return None
        }

        // 处理包含路径分隔符的相对路径
        // 严格翻译自:
        //   if (bun.strings.containsChar(bin, '/')) {
        //       if (cwd.len > 0) {
        //           if (isValid(buf, trimRight(cwd), withoutPrefix(bin, "./"))) |len|
        //               return buf[0..len];
        //       }
        //       return null; // Do not lookup paths with slashes in $PATH
        //   }
        if (bin.contains("/")) {
            if (cwd.size > 0) {
                let trimmedCwd = cwd.trimRight("/")
                let cleanBin = withoutPrefix(bin, "./")
                let fullPath = "${trimmedCwd}/${cleanBin}"
                if (isExecutableFilePath(fullPath)) {
                    return Some(fullPath)
                }
            }
            return None
        }

        // 遍历 PATH 中的每个段
        // 严格翻译自:
        //   var path_iter = std.mem.tokenizeScalar(u8, path, std.fs.path.delimiter);
        //   while (path_iter.next()) |segment| {
        //       if (isValid(buf, segment, bin)) |len| { return buf[0..len]; }
        //   }
        let delimiter = if (Platform.isWindows()) { ";" } else { ":" }
        let segments = path.split(delimiter)
        for (segment in segments) {
            if (segment.size == 0) {
                continue
            }
            let fullPath = "${segment}/${bin}"
            if (isExecutableFilePath(fullPath)) {
                return Some(fullPath)
            }
        }

        return None
    }

    // ========================================================================
    // isValid - 检查路径段中的可执行文件是否存在
    // 严格翻译自: which.zig - fn isValid(buf, segment, bin) ?u16
    //   const prefix_len = segment.len + 1;
    //   const len = prefix_len + bin.len;
    //   if (len_z > bun.MAX_PATH_BYTES) return null;
    //   buf[segment.len] = std.fs.path.sep;
    //   bun.copy(u8, buf[prefix_len..], bin);
    //   if (!bun.sys.isExecutableFilePath(filepath)) return null;
    //   return @intCast(filepath.len);
    // ========================================================================

    /// 检查路径段中是否存在指定的可执行文件
    /// 对应 Bun isValid()
    public static func isValid(segment: String, bin: String): ?String {
        let len = segment.size + 1 + bin.size
        if (len + 1 > MAX_PATH_BYTES) {
            return None
        }
        let fullPath = "${segment}/${bin}"
        if (isExecutableFilePath(fullPath)) {
            return Some(fullPath)
        }
        None
    }

    // ========================================================================
    // endsWithExtension - 检查文件名是否以 Windows 扩展名结尾
    // 严格翻译自: which.zig - pub fn endsWithExtension(str) bool
    //   if (str.len < 4) return false;
    //   if (str[str.len - 4] != '.') return false;
    //   const file_ext = str[str.len - 3 ..];
    //   inline for (win_extensions) |ext| {
    //       if (bun.strings.eqlCaseInsensitiveASCIIICheckLength(file_ext, ext)) return true;
    //   }
    //   return false;
    // ========================================================================

    /// 检查文件名是否以 Windows 可执行扩展名结尾
    /// 对应 Bun endsWithExtension()
    public static func endsWithExtension(str: String): Bool {
        if (str.size < 4) {
            return false
        }
        if (str[str.size - 4] != '.') {
            return false
        }
        let fileExt = str.subString(str.size - 3)
        for (ext in WIN_EXTENSIONS) {
            if (fileExt.toLower() == ext) {
                return true
            }
        }
        false
    }

    // ========================================================================
    // 辅助函数
    // ========================================================================

    /// 检查文件路径是否为可执行文件
    /// 对应 Bun bun.sys.isExecutableFilePath()
    /// 检查文件是否存在且具有执行权限
    static func isExecutableFilePath(path: String): Bool {
        let stat = Fs.stat(path)
        if (stat == None) {
            return false
        }
        if (let Some(s) <- stat) {
            return s.isFile() && s.isExecutable()
        }
        false
    }

    /// 移除前缀
    /// 对应 Bun bun.strings.withoutPrefixComptime()
    static func withoutPrefix(s: String, prefix: String): String {
        if (s.startsWith(prefix)) {
            return s.subString(prefix.size)
        }
        s
    }
}
