// bao_core - 路径字符串类型
// 严格翻译自: src/string/PathString.zig
//   pub const PathString = packed struct(PathStringBackingIntType) {
//       ptr: PointerIntType = 0,
//       len: PathInt = 0,
//   };
// Bun: 将路径存储为指针+长度的 packed struct (64位或128位)
//       使用指针低位标记实现 clone-on-write
// 仓颉: 使用 struct 实现值语义路径字符串
package bao_core
import std.collection.*

/// 路径字符串 - 严格对应 Bun PathString
/// Bun: packed struct, 指针+长度, 零拷贝借用路径切片
/// 仓颉: struct 值类型, 内部存储路径的 String 引用
/// 对应 Bun PathString 核心语义:
///   - 轻量级路径视图 (不持有数据, 只是借用)
///   - 支持空路径检查
///   - 用于文件系统操作中的路径传递
public struct PathStringView {
    /// 路径数据
    private var path: String
    /// 是否为空
    private var emptyFlag: Bool

    /// 空路径 - 对应 Bun PathString.empty
    /// pub const empty = @This(){ .ptr = 0, .len = 0 };
    public init() {
        path = ""
        emptyFlag = true
    }

    /// 从字符串创建 - 对应 Bun PathString.init
    /// pub inline fn init(str: []const u8) @This() {
    ///     return .{
    ///         .ptr = @truncate(@intFromPtr(str.ptr)),
    ///         .len = @truncate(str.len),
    ///     };
    /// }
    public init(path: String) {
        this.path = path
        this.emptyFlag = path.size == 0
    }

    /// 从字节数组创建
    public init(bytes: Array<UInt8>) {
        var sb = StringBuilder()
        for (b in bytes) {
            sb.append(Rune(Int32(b)))
        }
        this.path = sb.toString()
        this.emptyFlag = bytes.size == 0
    }

    /// 获取路径字符串 - 对应 Bun PathString.slice
    /// pub inline fn slice(this: anytype) []const u8 {
    ///     return @as([*]u8, @ptrFromInt(@as(usize, @intCast(this.ptr))))[0..this.len];
    /// }
    public func slice(): String {
        return path
    }

    /// 是否为空 - 对应 Bun PathString.isEmpty
    /// pub inline fn isEmpty(this: anytype) bool {
    ///     return this.len == 0;
    /// }
    public func isEmpty(): Bool {
        return emptyFlag
    }

    /// 路径长度
    public func len(): Int64 {
        return path.size
    }

    /// 估计内存大小 - 对应 Bun PathString.estimatedSize
    /// pub fn estimatedSize(this: *const PathString) usize {
    ///     return @as(usize, this.len);
    /// }
    public func estimatedSize(): Int64 {
        return path.size
    }

    /// 转为字符串
    public func toString(): String {
        return path
    }

    /// 以 null 终止的路径 - 对应 Bun PathString.sliceAssumeZ
    /// 用于系统调用
    public func toCString(): Array<UInt8> {
        var bytes = ArrayList<UInt8>()
        for (c in path) {
            bytes.add(c)
        }
        bytes.add(UInt8(0))
        return bytes.toArray()
    }

    /// 比较相等
    public func eql(other: PathStringView): Bool {
        return this.path == other.path
    }

    /// 是否以指定前缀开头
    public func hasPrefix(prefix: String): Bool {
        return path.startsWith(prefix)
    }

    /// 是否以指定后缀结尾
    public func hasSuffix(suffix: String): Bool {
        return path.endsWith(suffix)
    }

    /// 获取文件名部分 (最后一个 / 或 \ 之后的部分)
    public func basename(): String {
        let posSlash: Int64 = match (path.lastIndexOf('/')) {
            case Some(v) => v
            case None => Int64(-1)
        }
        let posBackSlash: Int64 = match (path.lastIndexOf('\\')) {
            case Some(v) => v
            case None => Int64(-1)
        }
        let pos = if (posSlash > posBackSlash) { posSlash } else { posBackSlash }
        if (pos < 0) {
            return path
        }
        return path[pos + 1..]
    }

    /// 获取目录部分
    public func dirname(): String {
        let posSlash: Int64 = match (path.lastIndexOf('/')) {
            case Some(v) => v
            case None => Int64(-1)
        }
        let posBackSlash: Int64 = match (path.lastIndexOf('\\')) {
            case Some(v) => v
            case None => Int64(-1)
        }
        let pos = if (posSlash > posBackSlash) { posSlash } else { posBackSlash }
        if (pos < 0) {
            return "."
        }
        return path[0..pos]
    }

    /// 追加子路径
    public func join(child: String): PathStringView {
        if (path.size == 0) {
            return PathStringView(child)
        }
        let lastByte = path[path.size - 1]
        if (lastByte == UInt8(47) || lastByte == UInt8(92)) { // '/' or '\'
            return PathStringView(path + child)
        }
        return PathStringView(path + "/" + child)
    }

    /// 静态工厂: 从字面量创建 - 对应 Bun 静态路径字符串
    public static func fromLiteral(s: String): PathStringView {
        return PathStringView(s)
    }
}
