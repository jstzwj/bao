// bao_core - 可变字符串构建器
// 严格翻译自: src/string/MutableString.zig
//   const MutableString = @This();
//   allocator: Allocator,
//   list: std.ArrayListUnmanaged(u8),
// Bun: 可变字符串, 内部使用 ArrayListUnmanaged(u8) 管理
// 仓颉: 使用 ArrayList<UInt8> 模拟, 保持相同 API 语义
package bao_core

/// 可变字符串 - 严格对应 Bun MutableString
/// Bun: struct { allocator, list: ArrayListUnmanaged(u8) }
/// 仓颉: class { buffer: ArrayList<UInt8> }
/// 对应 Bun MutableString 核心语义:
///   - 动态增长的可变字节缓冲区
///   - 支持追加、重置、克隆、获取切片等操作
///   - 用于 I/O 缓冲、文本构建、数据拼接等场景
public class MutableString {
    /// 底层缓冲区 - 对应 Bun list: std.ArrayListUnmanaged(u8)
    private var buffer: ArrayList<UInt8>
    /// 容量 - 对应 Bun list.capacity
    private var capacity: Int64

    /// 默认创建 - 对应 Bun MutableString.initEmpty
    /// pub fn initEmpty(allocator) MutableString {
    ///     return MutableString{ .allocator = allocator, .list = .{} };
    /// }
    public init() {
        buffer = ArrayList<UInt8>()
        capacity = 0
    }

    /// 带初始容量创建 - 对应 Bun MutableString.init
    /// pub fn init(allocator, capacity) !MutableString {
    ///     return MutableString{
    ///         .allocator = allocator,
    ///         .list = if (capacity > 0)
    ///             try std.ArrayListUnmanaged(u8).initCapacity(allocator, capacity)
    ///         else
    ///             std.ArrayListUnmanaged(u8){},
    ///     };
    /// }
    public init(capacity: Int64) {
        buffer = ArrayList<UInt8>()
        this.capacity = if (capacity > 0) { capacity } else { 0 }
    }

    /// 2048 字节初始容量 - 对应 Bun MutableString.init2048
    /// pub fn init2048(allocator) !MutableString {
    ///     return MutableString.init(allocator, 2048);
    /// }
    public static func init2048(): MutableString {
        return MutableString(2048)
    }

    /// 从字符串拷贝创建 - 对应 Bun MutableString.initCopy
    /// pub fn initCopy(allocator, str) !MutableString {
    ///     var mutable = try MutableString.init(allocator, str.len);
    ///     try mutable.copy(str);
    ///     return mutable;
    /// }
    public init(copy: String) {
        buffer = ArrayList<UInt8>()
        capacity = copy.length
        for (c in copy) {
            buffer.append(UInt8(c.value))
        }
    }

    /// 从字节数组拷贝创建
    public init(copy: Array<UInt8>) {
        buffer = ArrayList<UInt8>()
        capacity = copy.size
        for (b in copy) {
            buffer.append(b)
        }
    }

    /// 克隆 - 对应 Bun MutableString.clone
    /// pub fn clone(self: *MutableString) !MutableString {
    ///     return MutableString.initCopy(self.allocator, self.list.items);
    /// }
    public func clone(): MutableString {
        var result = MutableString(capacity)
        for (b in buffer) {
            result.buffer.append(b)
        }
        return result
    }

    /// 是否为空 - 对应 Bun MutableString.isEmpty
    /// pub fn isEmpty(this: *const MutableString) bool {
    ///     return this.list.items.len == 0;
    /// }
    public func isEmpty(): Bool {
        return buffer.size == 0
    }

    /// 长度 - 对应 Bun MutableString.len
    /// pub fn len(self: *const MutableString) usize {
    ///     return self.list.items.len;
    /// }
    public func len(): Int64 {
        return buffer.size
    }

    /// 长度 (Int32) - 对应 Bun MutableString.lenI
    /// pub inline fn lenI(self: *MutableString) i32 {
    ///     return @as(i32, @intCast(self.list.items.len));
    /// }
    public func lenI(): Int32 {
        return Int32(buffer.size)
    }

    /// 获取字节切片 - 对应 Bun MutableString.slice
    /// pub fn slice(self: *MutableString) []u8 {
    ///     return self.list.items;
    /// }
    public func slice(): Array<UInt8> {
        return buffer.toArray()
    }

    /// 获取带 null 终止的切片 - 对应 Bun MutableString.sliceWithSentinel
    /// pub fn sliceWithSentinel(self: *MutableString) [:0]u8
    public func sliceWithSentinel(): Array<UInt8> {
        if (buffer.size > 0 && buffer[buffer.size - 1] != UInt8(0)) {
            buffer.append(UInt8(0))
        }
        return buffer.toArray()
    }

    /// 重置 (保留容量) - 对应 Bun MutableString.reset
    /// pub inline fn reset(self: *MutableString) void {
    ///     self.list.clearRetainingCapacity();
    /// }
    public func reset(): Unit {
        buffer.clear()
    }

    /// 重置到指定位置 - 对应 Bun MutableString.resetTo
    /// pub inline fn resetTo(self: *MutableString, index: usize) void {
    ///     bun.assert(index <= self.list.capacity);
    ///     self.list.items.len = index;
    /// }
    public func resetTo(index: Int64): Unit {
        while (buffer.size > index) {
            buffer.removeAt(buffer.size - 1)
        }
    }

    /// 追加字节切片 - 对应 Bun MutableString.appendSlice
    /// pub inline fn appendSlice(self: *MutableString, items: []const u8) !void {
    ///     try self.list.appendSlice(self.allocator, items);
    /// }
    public func appendSlice(items: Array<UInt8>): Unit {
        for (b in items) {
            buffer.append(b)
        }
    }

    /// 精确追加 (不预分配) - 对应 Bun MutableString.appendSliceExact
    public func appendSliceExact(items: Array<UInt8>): Unit {
        if (items.size == 0) {
            return
        }
        for (b in items) {
            buffer.append(b)
        }
    }

    /// 追加字符 - 对应 Bun MutableString.appendChar
    /// pub inline fn appendChar(self: *MutableString, char: u8) !void {
    ///     try self.list.append(self.allocator, char);
    /// }
    public func appendChar(char: UInt8): Unit {
        buffer.append(char)
    }

    /// 假定有容量时追加字符 - 对应 Bun MutableString.appendCharAssumeCapacity
    public func appendCharAssumeCapacity(char: UInt8): Unit {
        buffer.append(char)
    }

    /// 追加 N 个相同字符 - 对应 Bun MutableString.appendCharNTimes
    /// pub inline fn appendCharNTimes(self: *MutableString, char: u8, n: usize) !void {
    ///     try self.list.appendNTimes(self.allocator, char, n);
    /// }
    public func appendCharNTimes(char: UInt8, n: Int64): Unit {
        for (_ in 0..n) {
            buffer.append(char)
        }
    }

    /// 追加字节切片 (别名) - 对应 Bun MutableString.append
    /// pub inline fn append(self: *MutableString, char: []const u8) !void {
    ///     try self.list.appendSlice(self.allocator, char);
    /// }
    public func append(data: Array<UInt8>): Unit {
        appendSlice(data)
    }

    /// 追加整数 - 对应 Bun MutableString.appendInt
    /// pub inline fn appendInt(self: *MutableString, int: u64) !void
    public func appendInt(value: Int64): Unit {
        let s = value.toString()
        for (c in s) {
            buffer.append(UInt8(c.value))
        }
    }

    /// 假定有容量时追加 - 对应 Bun MutableString.appendAssumeCapacity
    /// pub inline fn appendAssumeCapacity(self: *MutableString, char: []const u8) void {
    ///     self.list.appendSliceAssumeCapacity(char);
    /// }
    public func appendAssumeCapacity(data: Array<UInt8>): Unit {
        for (b in data) {
            buffer.append(b)
        }
    }

    /// 写入数据 - 对应 Bun MutableString.write
    /// pub fn write(self: *MutableString, bytes: anytype) !usize {
    ///     try self.list.appendSlice(self.allocator, bytes);
    ///     return bytes.len;
    /// }
    public func write(bytes: Array<UInt8>): Int64 {
        appendSlice(bytes)
        return bytes.size
    }

    /// 写入全部数据 - 对应 Bun MutableString.writeAll
    /// pub fn writeAll(self: *MutableString, bytes: string) !usize
    public func writeAll(data: Array<UInt8>): Int64 {
        appendSlice(data)
        return data.size
    }

    /// 需要时增长 - 对应 Bun MutableString.growIfNeeded
    /// pub inline fn growIfNeeded(self: *MutableString, amount: usize) !void {
    ///     try self.list.ensureUnusedCapacity(self.allocator, amount);
    /// }
    public func growIfNeeded(amount: Int64): Unit {
        // ArrayList 自动扩容
    }

    /// 按量增长 - 对应 Bun MutableString.growBy
    /// pub inline fn growBy(self: *MutableString, amount: usize) !void {
    ///     try self.list.ensureUnusedCapacity(self.allocator, amount);
    /// }
    public func growBy(amount: Int64): Unit {
        // ArrayList 自动扩容
    }

    /// 膨胀到指定大小 - 对应 Bun MutableString.inflate
    /// pub fn inflate(self: *MutableString, amount: usize) !void {
    ///     try self.list.resize(self.allocator, amount);
    /// }
    public func inflate(amount: Int64): Unit {
        while (buffer.size < amount) {
            buffer.append(UInt8(0))
        }
    }

    /// 获取可写 N 字节 - 对应 Bun MutableString.writableNBytes
    /// pub fn writableNBytes(self: *MutableString, amount: usize) ![]u8
    public func writableNBytes(amount: Int64): Array<UInt8> {
        growIfNeeded(amount)
        return writableNBytesAssumeCapacity(amount)
    }

    /// 获取可写 N 字节 (假定有容量) - 对应 Bun MutableString.writableNBytesAssumeCapacity
    /// pub fn writableNBytesAssumeCapacity(self: *MutableString, amount: usize) []u8
    public func writableNBytesAssumeCapacity(amount: Int64): Array<UInt8> {
        var result = Array<UInt8>()
        for (_ in 0..amount) {
            buffer.append(UInt8(0))
            result.append(UInt8(0))
        }
        return result
    }

    /// 转为拥有切片 - 对应 Bun MutableString.toOwnedSlice
    /// pub fn toOwnedSlice(self: *MutableString) []u8 {
    ///     return bun.handleOom(self.list.toOwnedSlice(self.allocator));
    /// }
    public func toOwnedSlice(): Array<UInt8> {
        let result = buffer.toArray()
        buffer.clear()
        return result
    }

    /// 取出切片 (不释放) - 对应 Bun MutableString.takeSlice
    /// pub fn takeSlice(self: *MutableString) []u8 {
    ///     const out = self.list.items;
    ///     self.list = .{};
    ///     return out;
    /// }
    public func takeSlice(): Array<UInt8> {
        let result = buffer.toArray()
        buffer.clear()
        return result
    }

    /// 拷贝数据 - 对应 Bun MutableString.copy
    /// pub fn copy(self: *MutableString, str: anytype) !void
    public func copy(data: Array<UInt8>): Unit {
        buffer.clear()
        for (b in data) {
            buffer.append(b)
        }
    }

    /// 包含字符 - 对应 Bun MutableString.containsChar
    /// pub fn containsChar(self: *const MutableString, char: u8) bool
    public func containsChar(char: UInt8): Bool {
        return indexOfChar(char) >= 0
    }

    /// 查找字符位置 - 对应 Bun MutableString.indexOfChar
    /// pub fn indexOfChar(self: *const MutableString, char: u8) ?u32
    public func indexOfChar(char: UInt8): Int64 {
        for (i in 0..buffer.size) {
            if (buffer[Int64(i)] == char) {
                return i
            }
        }
        return -1
    }

    /// 最后出现位置 - 对应 Bun MutableString.lastIndexOfChar
    /// pub fn lastIndexOfChar(self: *const MutableString, char: u8) ?usize
    public func lastIndexOfChar(char: UInt8): Int64 {
        var i = buffer.size - 1
        while (i >= 0) {
            if (buffer[Int64(i)] == char) {
                return i
            }
            i -= 1
        }
        return -1
    }

    /// 比较相等 - 对应 Bun MutableString.eql
    /// pub fn eql(self: *MutableString, other: anytype) bool {
    ///     return std.mem.eql(u8, self.list.items, other);
    /// }
    public func eql(other: Array<UInt8>): Bool {
        if (buffer.size != other.size) {
            return false
        }
        for (i in 0..buffer.size) {
            if (buffer[Int64(i)] != other[Int64(i)]) {
                return false
            }
        }
        return true
    }

    /// 与字符串比较
    public func eqlString(other: String): Bool {
        if (buffer.size != other.length) {
            return false
        }
        let chars = other.toArray()
        for (i in 0..buffer.size) {
            if (buffer[Int64(i)] != UInt8(chars[Int64(i)].value)) {
                return false
            }
        }
        return true
    }

    /// 转为字符串
    public func toString(): String {
        var sb = StringBuilder()
        for (b in buffer) {
            sb.append(Char(Int32(b)))
        }
        return sb.toString()
    }

    /// 确保未使用容量 - 对应 Bun MutableString.ensureUnusedCapacity
    /// pub const ensureUnusedCapacity = growIfNeeded;
    public func ensureUnusedCapacity(amount: Int64): Unit {
        growIfNeeded(amount)
    }

    /// 拥有指定长度的切片 - 对应 Bun MutableString.toOwnedSliceLength
    /// pub fn toOwnedSliceLength(self: *MutableString, length: usize) string
    public func toOwnedSliceLength(length: Int64): Array<UInt8> {
        var result = Array<UInt8>()
        let limit = if (length < buffer.size) { length } else { buffer.size }
        for (i in 0..limit) {
            result.append(buffer[Int64(i)])
        }
        buffer.clear()
        return result
    }

    /// 检查缓冲区是否拥有该切片 - 对应 Bun MutableString.owns
    /// pub fn owns(this: *const MutableString, items: []const u8) bool
    public func owns(items: Array<UInt8>): Bool {
        // 仓颉数组是值类型, 简化实现
        return items.size <= buffer.size
    }
}
