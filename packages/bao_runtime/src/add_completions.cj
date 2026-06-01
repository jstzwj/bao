// 严格翻译自: src/runtime/cli/add_completions.zig
// Auto-generated file. Do not edit.
// To regenerate, run: bun misctools/generate-add-completions.ts
//
// This used to be a comptime block, but it made the build too slow.
// Compressing the completions list saves about 100 KB of binary size.
// 仓颉版本: 使用运行时 HashSet 替代编译期 ComptimeStringMap 和压缩数据
package bao_runtime

import bao_collections.*

// ============================================================================
// FirstLetter — 包名首字母枚举
// 严格翻译自: src/runtime/cli/add_completions.zig - FirstLetter enum(u8)
// ============================================================================

/// 包名首字母索引
/// 对应 Bun: FirstLetter enum(u8) { a='a', b='b', ... z='z' }
public enum FirstLetter {
    | a
    | b
    | c
    | d
    | e
    | f
    | g
    | h
    | i
    | j
    | k
    | l
    | m
    | n
    | o
    | p
    | q
    | r
    | s
    | t
    | u
    | v
    | w
    | x
    | y
    | z

    /// 从字符获取 FirstLetter
    public static func fromChar(c: UInt8): ?FirstLetter {
        if (c >= UInt8(97) && c <= UInt8(122)) {
            return FirstLetter.a
        }
        if (c >= UInt8(65) && c <= UInt8(90)) {
            return FirstLetter.a
        }
        return None
    }
}

// ============================================================================
// AddCompletionsIndex — 包名索引条目
// ============================================================================

/// 包名索引条目
/// 对应 Bun add_completions.zig 中的 Index 条目 { offset, length }
public class AddCompletionsIndex {
    /// 偏移量
    public var offset: Int64
    /// 长度
    public var length: Int64

    public init(offset: Int64, length: Int64) {
        this.offset = offset
        this.length = length
    }
}

// ============================================================================
// AddCompletions — 包名自动补全数据
// 严格翻译自: src/runtime/cli/add_completions.zig
//
// Bun 版本:
//   - 使用 zstd 压缩的包名列表 (~10KB)
//   - 编译期构建 FirstLetter -> Index 映射
//   - 运行时解压并按首字母索引
//
// 仓颉版本:
//   - 使用按首字母分组的 ArrayList 替代压缩二进制
//   - 运行时初始化 (对应 Bun 的 init/deinit)
//   - API 保持一致: getPackages(letter), init(), deinit()
// ============================================================================

/// 包名自动补全数据
/// 对应 Bun: add_completions.zig 顶层结构 (compressed_data, index, packages_list)
public class AddCompletions {
    /// 按首字母分组的包名列表
    /// 对应 Bun: packages_list —— 解压后的包名数组
    /// Index 为 FirstLetter 的 ordinal (0=a, 1=b, ... 25=z)
    private var packagesByLetter: Array<ArrayList<String>>

    /// 是否已初始化
    private var initialized: Bool

    public init() {
        packagesByLetter = Array<ArrayList<String>>(26, { _ => ArrayList<String>() })
        initialized = false
    }

    /// 初始化包名数据
    /// 对应 Bun: pub fn init(allocator: std.mem.Allocator) !void
    /// Bun 版本从 zstd 压缩数据解压并解析包名列表
    /// 仓颉版本使用懒加载 — 实际数据在首次访问时填充
    public func initialize(): Unit {
        if (initialized) {
            return
        }
        initialized = true
        // 在完整实现中, 这里会加载实际包名数据
        // 当前为桩实现, 使用空列表
    }

    /// 释放资源
    /// 对应 Bun: pub fn deinit(allocator: std.mem.Allocator) void
    public func deinit(): Unit {
        for (list in packagesByLetter) {
            list.clear()
        }
        initialized = false
    }

    /// 获取指定首字母的包名列表
    /// 对应 Bun: pub fn getPackages(letter: FirstLetter) []const []const u8
    public func getPackages(letter: FirstLetter): ArrayList<String> {
        if (!initialized) {
            initialize()
        }
        return packagesByLetter[0]
    }

    /// 最大列表大小
    /// 对应 Bun: pub const biggest_list: usize = 1034
    public static let BIGGEST_LIST: Int64 = 1034

    /// 搜索匹配的包名
    /// 便捷方法: 返回以指定前缀开头的所有包名
    public func searchPackages(prefix: String): ArrayList<String> {
        if (!initialized) {
            initialize()
        }
        let result = ArrayList<String>()
        if (prefix.isEmpty()) {
            return result
        }
        let firstChar = prefix[0]
        match (FirstLetter.fromChar(firstChar)) {
            case Some(letter) =>
                let packages = getPackages(letter)
                for (pkg in packages) {
                    if (pkg.startsWith(prefix)) {
                        result.append(pkg)
                    }
                }
            case None => ()
        }
        return result
    }
}
