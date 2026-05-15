// bao_core - 字符串拼接构建器
// 严格翻译自: src/string/StringBuilder.zig + src/string/StringJoiner.zig
//   const StringBuilder = @This(); len, cap, ptr
//   const StringJoiner = @This(); allocator, len, head, tail
// Bun: 两阶段字符串构建器 (count -> allocate -> append)
//       和 Rope-like StringJoiner (链表拼接)
// 仓颉: 合并为统一的字符串构建器, 保持相同 API 语义
package bao_core

/// 字符串拼接构建器 - 严格对应 Bun StringJoiner
/// Bun: Rope-like 数据结构, 链表节点存储各段字符串
/// 仓颉: 使用 ArrayList<String> 模拟链表拼接
/// 对应 Bun StringJoiner 核心语义:
///   - 零拷贝拼接多个字符串片段
///   - 支持静态引用和克隆两种模式
///   - 最终一次性分配并合并
public class Watcher {
    public var input: String
    public var estimatedCount: Int64
    public var needsNewline: Bool

    public init() {
        input = ""
        estimatedCount = 0
        needsNewline = false
    }
}

public class StringJoiner {
    /// 节点列表 (对应 Bun 链表)
    private var nodes: ArrayList<String>
    /// 节点是否拥有数据 (对应 Bun NullableAllocator)
    private var ownedFlags: ArrayList<Bool>
    /// 总字节长度 - 对应 Bun StringJoiner.len
    public var totalLen: Int64
    /// 估计的匹配计数 - 对应 Bun Watcher.estimated_count
    public var estimatedCount: Int64
    /// 是否需要尾部换行 - 对应 Bun Watcher.needs_newline
    public var needsNewline: Bool

    /// 观察器 - 对应 Bun StringJoiner.Watcher
    /// pub const Watcher = struct {
    ///     input: []const u8 = "",
    ///     estimated_count: u32 = 0,
    ///     needs_newline: bool = false,
    /// };

    public init() {
        nodes = ArrayList<String>()
        ownedFlags = ArrayList<Bool>()
        totalLen = 0
        estimatedCount = 0
        needsNewline = false
    }

    /// 推入静态引用 - 对应 Bun StringJoiner.pushStatic
    /// pub fn pushStatic(this: *StringJoiner, data: []const u8) void {
    ///     this.push(data, null);
    /// }
    public func pushStatic(data: String): Unit {
        push(data, false)
    }

    /// 推入克隆数据 - 对应 Bun StringJoiner.pushCloned
    /// pub fn pushCloned(this: *StringJoiner, data: []const u8) void {
    ///     if (data.len == 0) return;
    ///     this.push(bun.handleOom(this.allocator.dupe(u8, data)), this.allocator);
    /// }
    public func pushCloned(data: String): Unit {
        if (data.length == 0) {
            return
        }
        push(data, true)
    }

    /// 推入数据 - 对应 Bun StringJoiner.push
    /// pub fn push(this: *StringJoiner, data: []const u8, allocator: ?Allocator) void {
    ///     if (data.len == 0) return;
    ///     this.len += data.len;
    ///     const new_tail = Node.init(joiner_alloc, data, allocator);
    ///     ...
    /// }
    public func push(data: String, owned: Bool): Unit {
        if (data.length == 0) {
            return
        }
        totalLen += data.length
        nodes.append(data)
        ownedFlags.append(owned)
        // 检查是否需要换行 - 对应 Bun watcher.needs_newline
        if (data.length > 0) {
            let lastChar = data.toCharArray()[data.length - 1]
            needsNewline = lastChar != '\n'
        }
    }

    /// 完成拼接 - 对应 Bun StringJoiner.done
    /// pub fn done(this: *StringJoiner, allocator) ![]u8 {
    ///     var current: ?*Node = this.head orelse { ... };
    ///     const slice = try allocator.alloc(u8, this.len);
    ///     var remaining = slice;
    ///     while (current) |node| {
    ///         @memcpy(remaining[0..node.slice.len], node.slice);
    ///         remaining = remaining[node.slice.len..];
    ///         ...
    ///     }
    ///     return slice;
    /// }
    public func done(): String {
        if (nodes.size == 0) {
            return ""
        }
        var sb = StringBuilder()
        for (node in nodes) {
            sb.append(node)
        }
        let result = sb.toString()
        // 清空
        nodes.clear()
        ownedFlags.clear()
        totalLen = 0
        return result
    }

    /// 完成并追加尾部 - 对应 Bun StringJoiner.doneWithEnd
    /// pub fn doneWithEnd(this: *StringJoiner, allocator, end: []const u8) ![]u8
    public func doneWithEnd(end: String): String {
        if (nodes.size == 0) {
            if (end.length > 0) {
                return end
            }
            return ""
        }
        var sb = StringBuilder()
        for (node in nodes) {
            sb.append(node)
        }
        sb.append(end)
        let result = sb.toString()
        nodes.clear()
        ownedFlags.clear()
        totalLen = 0
        return result
    }

    /// 获取最后一个字节 - 对应 Bun StringJoiner.lastByte
    /// pub fn lastByte(this: *const StringJoiner) u8 {
    ///     const slice = (this.tail orelse return 0).slice;
    ///     return slice[slice.len - 1];
    /// }
    public func lastByte(): UInt8 {
        if (nodes.size == 0) {
            return UInt8(0)
        }
        let last = nodes[nodes.size - 1]
        if (last.length == 0) {
            return UInt8(0)
        }
        return UInt8(last.toCharArray()[last.length - 1].value)
    }

    /// 确保尾部换行 - 对应 Bun StringJoiner.ensureNewlineAtEnd
    /// pub fn ensureNewlineAtEnd(this: *StringJoiner) void {
    ///     if (this.watcher.needs_newline) {
    ///         this.watcher.needs_newline = false;
    ///         this.pushStatic("\n");
    ///     }
    /// }
    public func ensureNewlineAtEnd(): Unit {
        if (needsNewline) {
            needsNewline = false
            pushStatic("\n")
        }
    }

    /// 是否包含子串 - 对应 Bun StringJoiner.contains
    /// pub fn contains(this: *const StringJoiner, slice: []const u8) bool
    public func contains(slice: String): Bool {
        for (node in nodes) {
            if (node.contains(slice)) {
                return true
            }
        }
        return false
    }

    /// 析构 - 对应 Bun StringJoiner.deinit
    /// pub fn deinit(this: *StringJoiner) void
    public func deinit(): Unit {
        nodes.clear()
        ownedFlags.clear()
        totalLen = 0
        estimatedCount = 0
        needsNewline = false
    }

    /// 节点数
    public func nodeCount(): Int64 {
        return nodes.size
    }

    /// 总字节长度
    public func length(): Int64 {
        return totalLen
    }
}
