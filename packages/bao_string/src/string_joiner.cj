// 严格翻译自: src/string/StringJoiner.zig
// 字符串连接器
//   Rope-like 数据结构,用于将多个小字符串连接成一个大字符串
//   实现为链表,每个节点可能拥有或不拥有其数据
//   用于高效连接大量字符串而无需预计算总长度
package bao_string

import std.collection.*


// ============================================================================
// StringJoiner 节点
// 严格翻译自: src/string/StringJoiner.zig Node
// ============================================================================

/// 链表节点
/// 严格翻译自 StringJoiner.zig Node
class SJNode {
    /// 字符串数据
    public var slice: String
    /// 是否拥有数据
    public var owned: Bool
    /// 下一个节点
    public var next: ?SJNode

    public init(slice: String, owned: Bool) {
        this.slice = slice
        this.owned = owned
        this.next = None
    }

    /// 释放节点
    /// 严格翻译自 Node.deinit
    public func deinit(): Unit {
        // 仓颉 GC 自动回收
        this.slice = ""
        this.next = None
    }
}

// ============================================================================
// Watcher
// 严格翻译自: src/string/StringJoiner.zig Watcher
// ============================================================================

/// 监视器: 跟踪连接器状态
/// 严格翻译自 StringJoiner.zig Watcher
public class Watcher {
    /// 输入字符串
    public var input: String
    /// 估算计数
    public var estimatedCount: UInt32
    /// 是否需要换行
    public var needsNewline: Bool

    public init() {
        this.input = ""
        this.estimatedCount = 0
        this.needsNewline = false
    }
}

// ============================================================================
// StringJoiner
// 严格翻译自: src/string/StringJoiner.zig
// ============================================================================

/// 字符串连接器: Rope-like 链表结构
/// 严格翻译自 StringJoiner.zig StringJoiner
public class StringJoiner {
    /// 所有节点数据的总长度
    public var len: Int64

    /// 头节点
    private var head: ?SJNode

    /// 尾节点
    private var tail: ?SJNode

    /// 监视器
    public var watcher: Watcher

    public init() {
        this.len = 0
        this.head = None
        this.tail = None
        this.watcher = Watcher()
    }

    /// 推入静态数据(不克隆)
    /// 严格翻译自 StringJoiner.pushStatic
    public func pushStatic(data: String): Unit {
        push(data, false)
    }

    /// 推入克隆数据
    /// 严格翻译自 StringJoiner.pushCloned
    public func pushCloned(data: String): Unit {
        if (data.size == 0) {
            return
        }
        push(data, true)
    }

    /// 推入数据
    /// 严格翻译自 StringJoiner.push
    public func push(data: String, owned: Bool): Unit {
        if (data.size == 0) {
            return
        }
        this.len += data.size

        let newTail = SJNode(data, owned)

        if (data.size > 0) {
            if (this.watcher.input.size > 0 && contains(data, this.watcher.input)) {
                this.watcher.estimatedCount += 1
            }
            this.watcher.needsNewline = data[data.size - 1] != UInt8(0x0A)
        }

        match (this.tail) {
            case Some(currentTail) =>
                currentTail.next = Some(newTail)
            case None =>
                this.head = Some(newTail)
        }
        this.tail = Some(newTail)
    }

    /// 完成连接,返回结果字符串
    /// 严格翻译自 StringJoiner.done
    public func done(): String {
        match (this.head) {
            case None =>
                return ""
            case Some(_) =>
                var result = ArrayList<Byte>()
                var current = this.head
                while (true) {
                    match (current) {
                        case Some(node) =>
                            let bytes = node.slice.toArray()
                            for (b in bytes) {
                                result.add(b)
                            }
                            current = node.next
                        case None =>
                            break
                    }
                }
                return String.fromUtf8(result.toArray())
        }
    }

    /// 完成连接并追加额外字符串
    /// 严格翻译自 StringJoiner.doneWithEnd
    public func doneWithEnd(end: String): String {
        match (this.head) {
            case None =>
                if (end.size > 0) {
                    return end
                }
                return ""
            case Some(_) =>
                var result = ArrayList<Byte>()
                var current = this.head
                while (true) {
                    match (current) {
                        case Some(node) =>
                            let bytes = node.slice.toArray()
                            for (b in bytes) {
                                result.add(b)
                            }
                            current = node.next
                        case None =>
                            break
                    }
                }
                // 追加 end
                let endBytes = end.toArray()
                for (b in endBytes) {
                    result.add(b)
                }
                return String.fromUtf8(result.toArray())
        }
    }

    /// 释放所有节点
    /// 严格翻译自 StringJoiner.deinit
    public func deinit(): Unit {
        var current = this.head
        while (true) {
            match (current) {
                case Some(node) =>
                    node.deinit()
                    current = node.next
                case None =>
                    break
            }
        }
        this.head = None
        this.tail = None
        this.len = 0
    }

    /// 获取最后一个字节
    /// 严格翻译自 StringJoiner.lastByte
    public func lastByte(): Byte {
        match (this.tail) {
            case Some(node) =>
                if (node.slice.size == 0) {
                    return UInt8(0)
                }
                return node.slice[node.slice.size - 1]
            case None =>
                return UInt8(0)
        }
    }

    /// 确保末尾有换行符
    /// 严格翻译自 StringJoiner.ensureNewlineAtEnd
    public func ensureNewlineAtEnd(): Unit {
        if (this.watcher.needsNewline) {
            this.watcher.needsNewline = false
            pushStatic("\n")
        }
    }

    /// 判断是否包含指定字符串
    /// 严格翻译自 StringJoiner.contains
    public func contains(slice: String): Bool {
        var el = this.head
        while (true) {
            match (el) {
                case Some(node) =>
                    if (contains(node.slice, slice)) {
                        return true
                    }
                    el = node.next
                case None =>
                    break
            }
        }
        return false
    }
}
