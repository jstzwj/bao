// bao_sys - Glob 模式匹配
// 严格翻译自: src/glob/ (Bun 的 glob 模块)
//   Bun 使用 glob 模式匹配文件路径
//   仓颉实现 glob 模式解析和匹配
package bao_sys

import bao_core.*
import bao_collections.*

// ============================================================================
// Glob 模式匹配
// 严格翻译自: src/glob/ glob 模式语法
//   支持: * (任意), ? (单字符), [abc] (字符集), ** (递归)
// ============================================================================

/// Glob 匹配器 - 对应 Bun glob 模块
public class SimpleGlobMatcher {
    /// glob 模式
    private var pattern: String

    public init(pattern: String) {
        this.pattern = pattern
    }

    /// 匹配路径
    /// 对应 Bun: glob.match(pattern, path)
    public func `match`(path: String): Bool {
        return matchGlob(pattern, path, 0, 0)
    }

    /// 静态匹配方法
    public static func matchPattern(pattern: String, path: String): Bool {
        return SimpleGlobMatcher(pattern).`match`(path)
    }

    /// 递归匹配算法
    /// 对应 Bun glob 匹配引擎
    private func matchGlob(pattern: String, path: String,
                            pi: Int64, si: Int64): Bool {
        var pIdx = pi
        var sIdx = si

        while (pIdx < pattern.size) {
            let pc = pattern[Int64(pIdx)]
            if (pIdx + 1 < pattern.size && pattern[Int64(pIdx + 1)] == UInt8(42) && pc == UInt8(42)) {
                // **: 递归通配 (匹配 0 或多个路径组件)
                pIdx += 2
                // 跳过后续的 /
                while (pIdx < pattern.size && pattern[Int64(pIdx)] == UInt8(47)) {
                    pIdx += 1
                }
                if (pIdx >= pattern.size) {
                    return true  // ** 在末尾匹配一切
                }
                // 尝试匹配剩余部分
                var i = sIdx
                while (i <= path.size) {
                    if (matchGlob(pattern, path, pIdx, i)) {
                        return true
                    }
                    // 前进到下一个 /
                    while (i < path.size && path[Int64(i)] != UInt8(47)) {
                        i += 1
                    }
                    i += 1
                }
                return false
            } else if (pc == UInt8(42)) {
                // *: 匹配当前路径组件内的任意字符 (不含 /)
                pIdx += 1
                if (pIdx >= pattern.size) {
                    // * 在末尾: 确保没有剩余的 /
                    while (sIdx < path.size) {
                        if (path[Int64(sIdx)] == UInt8(47)) {
                            return false
                        }
                        sIdx += 1
                    }
                    return true
                }
                // 尝试匹配 0..N 个字符
                var i = sIdx
                while (i <= path.size) {
                    if (i < path.size && path[Int64(i)] == UInt8(47)) {
                        break  // * 不跨越 /
                    }
                    if (matchGlob(pattern, path, pIdx, i)) {
                        return true
                    }
                    i += 1
                }
                return false
            } else if (pc == UInt8(63)) {
                // ?: 匹配任意单个字符 (不含 /)
                if (sIdx >= path.size || path[Int64(sIdx)] == UInt8(47)) {
                    return false
                }
                pIdx += 1
                sIdx += 1
            } else if (pc == UInt8(91)) {
                // [...]: 字符集
                if (sIdx >= path.size) {
                    return false
                }
                pIdx += 1
                var negate = false
                if (pIdx < pattern.size && pattern[Int64(pIdx)] == UInt8(33)) {
                    negate = true
                    pIdx += 1
                }
                var matched = false
                var first = true
                while (pIdx < pattern.size && pattern[Int64(pIdx)] != UInt8(93)) {
                    let c = pattern[Int64(pIdx)]
                    if (first && c == UInt8(93)) { break }
                    first = false
                    // 范围匹配 a-z
                    if (pIdx + 2 < pattern.size && pattern[Int64(pIdx + 1)] == UInt8(45) &&
                        pattern[Int64(pIdx + 2)] != UInt8(93)) {
                        let lo = c
                        let hi = pattern[Int64(pIdx + 2)]
                        let sc = path[Int64(sIdx)]
                        if (sc >= lo && sc <= hi) {
                            matched = true
                        }
                        pIdx += 3
                    } else {
                        if (c == path[Int64(sIdx)]) {
                            matched = true
                        }
                        pIdx += 1
                    }
                }
                // 跳过 ]
                if (pIdx < pattern.size && pattern[Int64(pIdx)] == UInt8(93)) {
                    pIdx += 1
                }
                if (negate) { matched = !matched }
                if (!matched) { return false }
                sIdx += 1
            } else if (pc == UInt8(123)) {
                // {a,b,c}: 选项组
                pIdx += 1
                var options = ArrayList<String>()
                var current = StringBuilder()
                var depth = 1
                while (pIdx < pattern.size && depth > 0) {
                    let c = pattern[Int64(pIdx)]
                    if (c == UInt8(123)) {
                        depth += 1
                        current.append(c)
                    } else if (c == UInt8(125)) {
                        depth -= 1
                        if (depth == 0) {
                            options.append(current.toString())
                        } else {
                            current.append(c)
                        }
                    } else if (c == UInt8(44) && depth == 1) {
                        options.append(current.toString())
                        current = StringBuilder()
                    } else {
                        current.append(c)
                    }
                    pIdx += 1
                }
                // 尝试每个选项
                for (opt in options) {
                    let newPattern = opt + pattern[Int64(pIdx)..]
                    if (matchGlob(newPattern, path, 0, sIdx)) {
                        return true
                    }
                }
                return false
            } else {
                // 字面量匹配
                if (sIdx >= path.size || path[Int64(sIdx)] != pc) {
                    return false
                }
                pIdx += 1
                sIdx += 1
            }
        }
        return sIdx >= path.size
    }
}

// ============================================================================
// Glob 搜索
// 严格翻译自: src/glob/ 文件搜索
// ============================================================================

/// Glob 搜索器 - 对应 Bun glob 搜索
public class GlobSearch {
    /// 在目录中搜索匹配的文件
    /// 对应 Bun: glob.search(pattern, cwd)
    public static func search(pattern: String, cwd: String): ArrayList<String> {
        var results = ArrayList<String>()
        let matcher = SimpleGlobMatcher(pattern)

        // 如果模式包含 **, 需要递归遍历
        let isRecursive = pattern.contains("**")

        if (isRecursive) {
            walkAndMatch(cwd, matcher, results)
        } else {
            // 非递归: 只搜索当前目录
            let entries = DirUtils.listDir(cwd)
            match (entries) {
                case Ok(dirEntries) =>
                    for (entry in dirEntries) {
                        let fullPath = Path.join([cwd, entry.name])
                        if (matcher.`match`(entry.name) || matcher.`match`(fullPath)) {
                            results.append(fullPath)
                        }
                    }
                case Err(_) => ()
            }
        }
        return results
    }

    /// 递归遍历匹配
    private static func walkAndMatch(dir: String, matcher: SimpleGlobMatcher,
                                      results: ArrayList<String>): Unit {
        let entries = DirUtils.listDir(dir)
        match (entries) {
            case Ok(dirEntries) =>
                for (entry in dirEntries) {
                    let fullPath = Path.join([dir, entry.name])
                    if (matcher.`match`(fullPath) || matcher.`match`(entry.name)) {
                        results.append(fullPath)
                    }
                    if (entry.isDirectory()) {
                        walkAndMatch(fullPath, matcher, results)
                    }
                }
            case Err(_) => ()
        }
    }
}

/// fnmatch 风格匹配 - 对应 POSIX fnmatch
public class FnMatch {
    /// 判断字符串是否匹配 shell 模式
    /// 对应: fnmatch(pattern, string, flags)
    public static func `match`(pattern: String, s: String): Bool {
        return SimpleGlobMatcher.matchPattern(pattern, s)
    }
}
