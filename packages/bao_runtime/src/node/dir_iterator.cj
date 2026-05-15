// 目录迭代器
// 对应 Bun: src/runtime/node/dir_iterator.zig
// 严格翻译自: src/runtime/node/dir_iterator.zig
package bao_runtime

// ============================================================================
// 目录迭代结果
// 对应 Bun: src/runtime/node/dir_iterator.zig - IteratorResult
// ============================================================================
public class DirIteratorResult {
    public var name: String = ""
    public var kind: EntryKind = EntryKind.unknown

    public init() {}

    public init(name: String, kind: EntryKind) {
        this.name = name
        this.kind = kind
    }
}

// ============================================================================
// 目录迭代器
// 对应 Bun: src/runtime/node/dir_iterator.zig - Iterator
// ============================================================================
public class DirIterator {
    private var fd: Int32 = -1
    private var finished: Bool = false

    public init(fd: Int32) {
        this.fd = fd
    }

    // 读取下一个目录项
    // 对应 Bun: src/runtime/node/dir_iterator.zig - next (nextDarwin/nextLinux)
    public func next(): ?DirIteratorResult {
        if (finished || fd < 0) {
            return None
        }

        // 调用系统 readdir
        let entry = System.readdirEntry(fd)
        if (entry == None) {
            finished = true
            return None
        }
        return entry
    }

    // 关闭迭代器
    public func close(): Unit {
        if (fd >= 0) {
            System.close(fd)
            fd = -1
        }
        finished = true
    }
}
