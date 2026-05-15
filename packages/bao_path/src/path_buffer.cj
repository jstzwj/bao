// bao_path - 路径缓冲区池
// 严格翻译自:
//   src/paths/path_buffer_pool.zig - PathBufferPoolT
//   src/paths/Path.zig - Buf, Options
package bao_path

import bao_core.*

// ============================================================================
// PathBufferPool - 路径缓冲区池
// 严格翻译自: src/paths/path_buffer_pool.zig
//   fn PathBufferPoolT(comptime T: type) type {
//       return struct {
//           const Pool = ObjectPool(T, null, true, 4);
//           pub fn get() *T { ... }
//           pub fn put(buffer: *const T) void { ... }
//           pub fn deleteAll() void { ... }
//       };
//   }
// Bun 使用线程本地对象池, 每个线程最多保持 4 个缓冲区
// 仓颉使用简单的池化结构实现类似语义
// ============================================================================

/// 路径缓冲区池 - 对应 Bun PathBufferPoolT(PathBuffer)
/// Bun: 保持最多 4 个活跃缓冲区以避免频繁的堆分配
///   const POOL_MAX_SIZE = 4
public class PathBufferPool {
    private let pool: ArrayList<PathBuffer>
    private var index: Int64
    private let maxPoolSize: Int64

    public init() {
        pool = ArrayList<PathBuffer>()
        index = 0
        maxPoolSize = 4  // 对应 Bun 的 ObjectPool max = 4
    }

    public init(maxSize: Int64) {
        pool = ArrayList<PathBuffer>()
        index = 0
        maxPoolSize = maxSize
    }

    /// 获取一个缓冲区 - 对应 Bun path_buffer_pool.get()
    ///   pub fn get() *T {
    ///       return &Pool.get(bun.threadLocalAllocator()).data;
    ///   }
    /// 如果池中有可用缓冲区则复用, 否则创建新的
    public func get(): PathBuffer {
        if (index < pool.size) {
            let buf = pool[Int64(index)]
            buf.clear()
            index += 1
            return buf
        }
        let buf = PathBuffer()
        pool.append(buf)
        index += 1
        return buf
    }

    /// 归还缓冲区 - 对应 Bun path_buffer_pool.put(buffer)
    ///   pub fn put(buffer: *const T) void {
    ///       var node = @alignCast(@fieldParentPtr("data", @constCast(buffer)));
    ///       node.release();
    ///   }
    public func put(buf: PathBuffer): Unit {
        if (index > 0) {
            index -= 1
        }
    }

    /// 清空所有缓冲区 - 对应 Bun path_buffer_pool.deleteAll()
    ///   pub fn deleteAll() void { Pool.deleteAll(); }
    public func deleteAll(): Unit {
        pool.clear()
        index = 0
    }

    /// 当前池中的活跃数
    public func activeCount(): Int64 {
        return index
    }
}

// ============================================================================
// AbsPathBuilder - 绝对路径构建器
// 严格翻译自: src/paths/Path.zig 中 Path(opts) 类型
//   pub fn Path(comptime opts: Options) type {
//       return struct {
//           _buf: opts.Buf(),
//           pub fn init() @This() { ... }
//           pub fn from(input: anytype) Result(@This()) { ... }
//           pub fn append(this: *@This(), input: anytype) Result(void) { ... }
//           pub fn slice(this: *const @This()) []const opts.pathUnit() { ... }
//           ...
//       };
//   }
// Bun 使用编译时选项生成不同的路径类型 (abs/rel/any)
// 仓颉使用运行时类实现
// ============================================================================

/// 路径分隔符选项 - 对应 Bun Options.PathSeparators
public enum PathSeparator {
    | Any      // 保留原有分隔符
    | Auto     // 使用平台分隔符
    | Posix    // 使用 '/'
    | Windows  // 使用 '\'

    /// 获取分隔符字符
    /// 对应 Bun Options.PathSeparators.char()
    public func separatorChar(): Char {
        match (this) {
            case Any => Char('/')     // 默认使用 POSIX
            case Auto => Char('/')    // POSIX 平台
            case Posix => Char('/')
            case Windows => Char('\\')
        }
    }

    /// 获取分隔符字节
    public func separatorByte(): UInt8 {
        match (this) {
            case Any => SEP
            case Auto => SEP
            case Posix => SEP
            case Windows => SEP_WINDOWS
        }
    }
}

/// 路径类型 - 对应 Bun Options.Kind
public enum PathKind {
    | Abs   // 绝对路径
    | Rel   // 相对路径
    | Any   // 任意路径

    /// 是否需要绝对路径断言
    public func isAbs(): Bool {
        match (this) {
            case Abs => true
            case Rel => false
            case Any => false
        }
    }
}

/// 绝对路径构建器 - 对应 Bun Path(.{ .kind = .abs })
/// 支持从缓冲区池构建绝对路径, 自动处理分隔符和尾斜杠
public class AbsPathBuilder {
    private var buffer: PathBuffer
    private var separator: PathSeparator
    private let pool: PathBufferPool

    /// 初始化 - 对应 Bun Path.init()
    ///   pub fn init() @This() {
    ///       return .{ ._buf = .{ .pooled = bun.path_buffer_pool.get(), .len = 0 } };
    ///   }
    public init(pool: PathBufferPool) {
        this.pool = pool
        this.buffer = pool.get()
        this.separator = PathSeparator.Auto
    }

    public init() {
        this.pool = pathBufferPool
        this.buffer = pathBufferPool.get()
        this.separator = PathSeparator.Auto
    }

    /// 从已有路径创建 - 对应 Bun Path.from(input)
    ///   pub fn from(input: anytype) Result(@This()) {
    ///       var this = init();
    ///       this._buf.append(trimmed, false);
    ///       return this;
    ///   }
    public static func from(path: String): AbsPathBuilder {
        let builder = AbsPathBuilder()
        builder.buffer.append(trimAbs(path), false)
        return builder
    }

    /// 追加路径片段 - 对应 Bun Path.append(input)
    ///   pub fn append(this: *@This(), input: anytype) Result(void) {
    ///       const needs_sep = this.len() > 0 and ...;
    ///       const trimmed = trimInput(if (has_root) .rel else .abs, input);
    ///       this._buf.append(trimmed, needs_sep);
    ///   }
    public func append(path: String): Unit {
        let trimmed = trimRelative(path)
        if (trimmed.isEmpty) {
            return
        }
        let needsSep = buffer.len() > 0 &&
            !isSepAnyChar(buffer.toString()[Int64(buffer.len() - 1)])
        buffer.append(trimmed, needsSep)
    }

    /// 获取当前路径字符串 - 对应 Bun Path.slice()
    ///   pub fn slice(this: *const @This()) []const opts.pathUnit() {
    ///       return this._buf.pooled[0..this._buf.len];
    ///   }
    public func slice(): String {
        return buffer.toString()
    }

    /// 克隆 - 对应 Bun Path.clone()
    ///   pub fn clone(this: *const @This()) @This() {
    ///       var cloned = init();
    ///       @memcpy(cloned._buf.pooled[0..this._buf.len], this._buf.pooled[0..this._buf.len]);
    ///       cloned._buf.len = this._buf.len;
    ///       return cloned;
    ///   }
    public func clone(): AbsPathBuilder {
        let cloned = AbsPathBuilder(pool)
        cloned.buffer = PathBuffer()
        let current = buffer.toString()
        cloned.buffer.append(current, false)
        return cloned
    }

    /// 清空 - 对应 Bun Path.clear()
    public func clear(): Unit {
        buffer.clear()
    }

    /// 获取路径长度 - 对应 Bun Path.len()
    public func len(): Int64 {
        return buffer.len()
    }

    /// 获取文件名 - 对应 Bun Path.basename()
    public func basename(): String {
        return Path.basename(slice())
    }

    /// 获取目录名 - 对应 Bun Path.dirname()
    public func dirname(): ?String {
        return Path.dirname(slice())
    }

    /// 回退 n 个组件 - 对应 Bun Path.undo(n_components)
    ///   pub fn undo(this: *@This(), n_components: usize) void {
    ///       var i: usize = 0;
    ///       while (i < n_components) {
    ///           const slash = std.mem.lastIndexOfScalar(...) orelse { ... };
    ///           this._buf.setLength(slash);
    ///           i += 1;
    ///       };
    ///   }
    public func undo(nComponents: Int64): Unit {
        var s = slice()
        var i: Int64 = 0
        while (i < nComponents) {
            let lastSlash = s.lastIndexOf('/')
            if (lastSlash < 0) {
                buffer.setLength(0)
                return
            }
            // 保留根: 如果是绝对路径不能回退到根之前
            let minLen: Int64 = if (s.startsWith("/")) { 1 } else { 0 }
            if (Int64(lastSlash) < minLen) {
                buffer.setLength(minLen)
                return
            }
            s = s.substring(0, Int64(lastSlash))
            buffer.setLength(Int64(lastSlash))
            i += 1
        }
    }

    /// 保存当前长度以便恢复 - 对应 Bun Path.save() / ResetScope
    ///   pub fn save(this: *@This()) ResetScope {
    ///       return .{ .path = this, .saved_len = this.len() };
    ///   }
    public func save(): PathResetScope {
        return PathResetScope(builder: this, savedLen: buffer.len())
    }

    /// 释放缓冲区到池 - 对应 Bun Path.deinit()
    ///   pub fn deinit(this: *const @This()) void {
    ///       bun.path_buffer_pool.put(this._buf.pooled);
    ///   }
    public func deinit(): Unit {
        pool.put(buffer)
    }

    // ---------------------------------------------------------------------------
    // 内部辅助
    // ---------------------------------------------------------------------------

    /// 去除绝对路径尾部分隔符
    /// 对应 Bun trimInput(.abs, input):
    ///   while (trimmed.len > root_len and trimmed[trimmed.len - 1] == '/') {
    ///       trimmed = trimmed[0 .. trimmed.len - 1];
    ///   }
    private static func trimAbs(input: String): String {
        if (input.isEmpty) {
            return input
        }
        var end = input.size
        let rootLen: Int64 = if (input.startsWith("/")) { 1 } else { 0 }
        while (end > rootLen && isSepAnyChar(input[Int64(end - 1)])) {
            end -= 1
        }
        return input.substring(0, Int64(end))
    }

    /// 去除相对路径的前导 "./" 和尾部分隔符
    /// 对应 Bun trimInput(.rel, input):
    ///   if (trimmed.len > 1 and trimmed[0] == '.' and trimmed[1] == '/')
    ///       trimmed = trimmed[2..];
    ///   while (trimmed.len > 0 and trimmed[0] == '/') trimmed = trimmed[1..];
    ///   while (trimmed.len > 0 and trimmed[trimmed.len - 1] == '/') trimmed = trimmed[0..trimmed.len - 1];
    private static func trimRelative(input: String): String {
        var trimmed = input
        // 去除前导 "./"
        if (trimmed.size > 1 && trimmed[0] == Char('.') && trimmed[1] == Char('/')) {
            trimmed = trimmed.substring(2)
        }
        // 去除前导分隔符
        while (trimmed.size > 0 && isSepAnyChar(trimmed[0])) {
            trimmed = trimmed.substring(1)
        }
        // 去除尾部分隔符
        while (trimmed.size > 0 && isSepAnyChar(trimmed[Int64(trimmed.size - 1)])) {
            trimmed = trimmed.substring(0, Int64(trimmed.size - 1))
        }
        return trimmed
    }
}

/// 路径重置范围 - 对应 Bun Path.ResetScope
///   const ResetScope = struct {
///       path: *Path(opts),
///       saved_len: usize,
///       pub fn restore(this: *const ResetScope) void {
///           this.path._buf.setLength(this.saved_len);
///       }
///   };
public class PathResetScope {
    private let builder: AbsPathBuilder
    private let savedLen: Int64

    public init(builder: AbsPathBuilder, savedLen: Int64) {
        this.builder = builder
        this.savedLen = savedLen
    }

    /// 恢复到保存时的长度
    public func restore(): Unit {
        builder.buffer.setLength(savedLen)
    }
}
