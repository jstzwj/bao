// 严格翻译自: src/paths/Path.zig
//   Path(comptime opts) type - 核心路径操作类型
//   Buf - 路径缓冲区包装
//   Options - 路径类型选项
//   join, dirname, basename, extname, normalize, relative 等核心函数
//
// 本文件是对 Bun Path.zig 的完整翻译，提供 PathBuffer, PathOptions,
// AbsPathBuilder, RelPathBuilder 等核心路径操作类。
package bao_path

import bao_core.*
import bao_collections.*

// ============================================================================
// PathBuf - 路径缓冲区包装
// 严格翻译自: src/paths/Path.zig - Buf
//   pub const Buf = struct {
//       pooled: *PathBuffer,
//       len: usize = 0,
//       pub fn append(self: *Buf, input: []const u8, add_separator: bool) void
//       pub fn slice(self: Buf) []const u8
//       pub fn setLength(self: *Buf, new_len: usize) void
//   }
// ============================================================================

/// 路径缓冲区 - 对应 Bun Path.Buf
/// Bun: Buf 是 Path 的内部可变缓冲区，持有指向池化 PathBuffer 的指针
public class PathBuf {
    private var data: Array<UInt8>
    private var length: Int64

    public init() {
        data = Array<UInt8>(MAX_PATH_BYTES, { _ => UInt8(0) })
        length = 0
    }

    public init(capacity: Int64) {
        let cap = if (capacity > MAX_PATH_BYTES) { MAX_PATH_BYTES } else { capacity }
        data = Array<UInt8>(cap, { _ => UInt8(0) })
        length = 0
    }

    /// 获取有效数据长度
    /// 对应 Bun: pub fn len(self: Buf) usize { return self.len; }
    public func len(): Int64 {
        return length
    }

    /// 设置长度
    /// 对应 Bun: pub fn setLength(self: *Buf, new_len: usize) void { self.len = new_len; }
    public func setLength(newLen: Int64): Unit {
        if (newLen >= 0 && newLen <= data.size) {
            length = newLen
        }
    }

    /// 追加路径片段
    /// 对应 Bun Buf.append:
    ///   pub fn append(self: *Buf, input: []const u8, add_separator: bool) void {
    ///       if (add_separator) { self.pooled[self.len] = sep; self.len += 1; }
    ///       @memcpy(self.pooled[self.len..self.len + input.len], input);
    ///       self.len += input.len;
    ///   }
    public func append(input: String, addSeparator: Bool): Unit {
        if (addSeparator && length > 0) {
            if (length < data.size) {
                data[length] = SEP
                length += 1
            }
        }
        for (i in 0..input.size) {
            if (length < data.size) {
                data[length] = input[Int64(i)]
                length += 1
            }
        }
    }

    /// 追加字节
    /// 对应 Bun Buf.append (字节版本)
    public func appendBytes(bytes: Array<UInt8>, addSeparator: Bool): Unit {
        if (addSeparator && length > 0) {
            if (length < data.size) {
                data[length] = SEP
                length += 1
            }
        }
        for (b in bytes) {
            if (length < data.size) {
                data[length] = b
                length += 1
            }
        }
    }

    /// 获取缓冲区切片
    /// 对应 Bun: pub fn slice(self: Buf) []const u8 { return self.pooled[0..self.len]; }
    public func slice(): String {
        var sb = StringBuilder()
        for (i in 0..length) {
            sb.append(Rune(Int32(data[i])))
        }
        return sb.toString()
    }

    /// 清空缓冲区
    public func clear(): Unit {
        length = 0
    }

    /// 剩余容量
    public func remaining(): Int64 {
        return data.size - length
    }

    /// 获取底层字节数组
    public func bytes(): Array<UInt8> {
        var result = Array<UInt8>(length, { _ => UInt8(0) })
        for (i in 0..length) {
            result[i] = data[i]
        }
        return result
    }

    /// 获取可变字节引用
    public func getBuffer(): Array<UInt8> {
        return data
    }

    /// 是否为空
    public func isEmpty(): Bool {
        return length == 0
    }

    /// 最后一个字节
    public func lastByte(): UInt8 {
        if (length == 0) {
            return UInt8(0)
        }
        return data[length - 1]
    }
}

// ============================================================================
// PathOptions - 路径选项
// 严格翻译自: src/paths/Path.zig - Options
//   pub const Options = struct {
//       kind: Kind = .abs,
//       sep: PathSeparators = .{ .sep = .auto },
//       pub const Kind = enum { abs, rel, any };
//       pub const PathSeparators = struct { sep: Sep = .auto };
//       pub const Sep = enum { auto, any, posix, windows };
//   }
// ============================================================================

/// 路径类型 - 对应 Bun Options.Kind
public enum PathKindOption {
    | Abs   // 绝对路径
    | Rel   // 相对路径
    | Any   // 任意路径
}

/// 路径分隔符选项 - 对应 Bun Options.Sep
public enum PathSepOption {
    | Auto     // 平台默认
    | Any      // 保留原有
    | Posix    // '/'
    | Windows  // '\'

    /// 获取分隔符
    public func separator(): UInt8 {
        match (this) {
            case Auto => SEP
            case Any => SEP
            case Posix => SEP
            case Windows => SEP_WINDOWS
        }
    }
}

/// 路径选项 - 对应 Bun Options
public class PathOptions {
    public var kind: PathKindOption
    public var sep: PathSepOption

    public init() {
        kind = PathKindOption.Abs
        sep = PathSepOption.Auto
    }

    public init(kind: PathKindOption, sep: PathSepOption) {
        this.kind = kind
        this.sep = sep
    }

    /// 绝对路径选项
    public static func abs(): PathOptions {
        return PathOptions(PathKindOption.Abs, PathSepOption.Auto)
    }

    /// 相对路径选项
    public static func rel(): PathOptions {
        return PathOptions(PathKindOption.Rel, PathSepOption.Auto)
    }

    /// 任意路径选项
    public static func any(): PathOptions {
        return PathOptions(PathKindOption.Any, PathSepOption.Auto)
    }
}

// ============================================================================
// PathImpl - 路径操作实现
// 严格翻译自: src/paths/Path.zig 中的核心路径操作函数
//   Path(opts) 返回的类型提供:
//     init, from, fromWithAllocator, copy, clone, deinit
//     append, slice, len, label, withSeparator, quasis
//     basename, dirname, unsetBasename
// ============================================================================
//
// 注意: package.cj 中已有 Path 类提供 join/dirname/basename/extname/normalize 等
// 此处补充 PathImpl 类提供 Path(opts) 风格的构建器 API

/// 路径构建器 - 对应 Bun Path(opts) 类型
/// Bun 使用编译时选项生成不同的路径类型 (abs/rel/any)
/// 仓颉使用运行时选项 + PathBuf 实现等价功能
public class PathImpl {
    private var buf: PathBuf
    private var opts: PathOptions

    public init(opts: PathOptions) {
        this.buf = PathBuf()
        this.opts = opts
    }

    public init() {
        this.buf = PathBuf()
        this.opts = PathOptions.abs()
    }

    /// 从字符串创建路径 - 对应 Bun Path.from(input)
    ///   pub fn from(input: anytype) Result(@This()) {
    ///       var this = init();
    ///       const trimmed = trimInput(comptime opts.kind, input);
    ///       this._buf.append(trimmed, false);
    ///       return this;
    ///   }
    public static func from(path: String, opts: PathOptions): PathImpl {
        let impl = PathImpl(opts)
        let trimmed = trimInput(opts.kind, path)
        impl.buf.append(trimmed, false)
        return impl
    }

    /// 从字符串创建绝对路径
    public static func fromAbs(path: String): PathImpl {
        return from(path, PathOptions.abs())
    }

    /// 从字符串创建相对路径
    public static func fromRel(path: String): PathImpl {
        return from(path, PathOptions.rel())
    }

    /// 追加路径片段 - 对应 Bun Path.append(input)
    ///   pub fn append(this: *@This(), input: anytype) Result(void) {
    ///       const needs_sep = this.len() > 0 and !isSeparatorAtEnd();
    ///       const trimmed = trimInput(has_root ? .rel : .abs, input);
    ///       this._buf.append(trimmed, needs_sep);
    ///   }
    public func append(path: String): Unit {
        let trimmed = trimInput(PathKindOption.Rel, path)
        if (trimmed.isEmpty()) {
            return
        }
        let needsSep = buf.len() > 0 && !isSepAnyChar(buf.lastByte())
        buf.append(trimmed, needsSep)
    }

    /// 获取当前路径字符串 - 对应 Bun Path.slice()
    public func slice(): String {
        return buf.slice()
    }

    /// 获取路径长度 - 对应 Bun Path.len()
    public func len(): Int64 {
        return buf.len()
    }

    /// 清空路径 - 对应 Bun Path.clear()
    public func clear(): Unit {
        buf.clear()
    }

    /// 设置长度 - 对应 Bun Path.setLength()
    public func setLength(newLen: Int64): Unit {
        buf.setLength(newLen)
    }

    /// 克隆 - 对应 Bun Path.clone()
    public func clone(): PathImpl {
        let cloned = PathImpl(opts)
        cloned.buf.append(buf.slice(), false)
        return cloned
    }

    /// 获取文件名 - 对应 Bun Path.basename()
    public func basename(): String {
        return Path.basename(slice())
    }

    /// 获取目录名 - 对应 Bun Path.dirname()
    public func dirname(): String {
        return Path.dirname(slice())
    }

    /// 回退 n 个组件 - 对应 Bun Path.undo(n_components)
    ///   pub fn undo(this: *@This(), n_components: usize) void {
    ///       var i: usize = 0;
    ///       while (i < n_components) {
    ///           const slash = std.mem.lastIndexOfScalar(u8, this.slice(), '/') orelse { ... };
    ///           this._buf.setLength(slash);
    ///           i += 1;
    ///       }
    ///   }
    public func undo(nComponents: Int64): Unit {
        var s = slice()
        var i: Int64 = 0
        while (i < nComponents) {
            match (s.lastIndexOf('/')) {
                case Some(lastSlash) =>
                    let minLen: Int64 = if (s.startsWith("/")) { 1 } else { 0 }
                    if (lastSlash < minLen) {
                        buf.setLength(minLen)
                        return
                    }
                    s = s[0..lastSlash]
                    buf.setLength(lastSlash)
                    i += 1
                case None =>
                    buf.setLength(0)
                    return
            }
        }
    }

    /// 保存当前长度以便恢复 - 对应 Bun Path.save() / ResetScope
    ///   pub fn save(this: *@This()) ResetScope {
    ///       return .{ .path = this, .saved_len = this.len() };
    ///   }
    public func save(): PathImplResetScope {
        return PathImplResetScope(this, buf.len())
    }

    /// 恢复到保存时的路径长度
    public func restoreLength(savedLen: Int64): Unit {
        buf.setLength(savedLen)
    }

    /// 转换分隔符 - 对应 Bun Path.withSeparator()
    /// 将路径中的分隔符替换为指定字符
    public func withSeparator(sep: UInt8): String {
        var sb = StringBuilder()
        let s = slice()
        for (i in 0..s.size) {
            let c = s[Int64(i)]
            if (isSepAnyChar(c)) {
                sb.append(Rune(Int32(sep)))
            } else {
                sb.append(Rune(Int32(c)))
            }
        }
        return sb.toString()
    }

    /// 释放资源 - 对应 Bun Path.deinit()
    public func deinit(): Unit {
        buf.clear()
    }

    // ========================================================================
    // 内部辅助
    // ========================================================================

    /// 根据路径类型裁剪输入
    /// 对应 Bun trimInput:
    ///   .abs => 去除尾部分隔符 (保留根前缀)
    ///   .rel => 去除前导 "./" 和尾部分隔符
    private static func trimInput(kind: PathKindOption, input: String): String {
        if (input.isEmpty()) {
            return input
        }
        match (kind) {
            case Abs =>
                var end = input.size
                let rootLen: Int64 = if (input.startsWith("/")) { 1 } else { 0 }
                while (end > rootLen && isSepAnyChar(input[Int64(end - 1)])) {
                    end -= 1
                }
                return input[0..end]
            case Rel =>
                var trimmed = input
                // 去除前导 "./"
                if (trimmed.size > 1 && trimmed[0] == UInt8(46) && trimmed[1] == UInt8(47)) {
                    trimmed = trimmed[2..]
                }
                // 去除前导分隔符
                while (trimmed.size > 0 && isSepAnyChar(trimmed[0])) {
                    trimmed = trimmed[1..]
                }
                // 去除尾部分隔符
                while (trimmed.size > 0 && isSepAnyChar(trimmed[Int64(trimmed.size - 1)])) {
                    trimmed = trimmed[0..trimmed.size - 1]
                }
                return trimmed
            case Any =>
                var end = input.size
                while (end > 0 && isSepAnyChar(input[Int64(end - 1)])) {
                    end -= 1
                }
                return input[0..end]
        }
    }
}

public class PathImplResetScope {
    private let builder: PathImpl
    private let savedLen: Int64

    public init(builder: PathImpl, savedLen: Int64) {
        this.builder = builder
        this.savedLen = savedLen
    }

    public func restore(): Unit {
        builder.restoreLength(savedLen)
    }
}

// ============================================================================
// AutoAbsPath - 自动绝对路径类型别名
// 严格翻译自: src/paths/paths.zig
//   pub const AbsPath = Path(.{ .kind = .abs });
//   pub const AutoAbsPath = Path(.{ .kind = .abs, .sep = .{ .sep = .auto } });
//   pub const RelPath = Path(.{ .kind = .rel });
//   pub const AutoRelPath = Path(.{ .kind = .rel, .sep = .{ .sep = .auto } });
// ============================================================================

/// 创建绝对路径构建器
/// 对应 Bun AbsPath / AutoAbsPath
public func absPathBuilder(): PathImpl {
    return PathImpl(PathOptions.abs())
}

/// 从字符串创建绝对路径
/// 对应 Bun AutoAbsPath.from(path)
public func absPathFrom(path: String): PathImpl {
    return PathImpl.fromAbs(path)
}

/// 创建相对路径构建器
/// 对应 Bun RelPath / AutoRelPath
public func relPathBuilder(): PathImpl {
    return PathImpl(PathOptions.rel())
}

/// 从字符串创建相对路径
/// 对应 Bun AutoRelPath.from(path)
public func relPathFrom(path: String): PathImpl {
    return PathImpl.fromRel(path)
}
