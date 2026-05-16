// 严格翻译自: src/bun_core/deprecated.zig
//   pub fn BufferedReader(comptime buffer_size: usize, comptime ReaderType: type) type
//   pub fn bufferedReader(reader: anytype) ...
//   pub fn bufferedReaderSize(comptime size: usize, reader: anytype) ...
//   pub fn SinglyLinkedList(comptime T: type) type
//   pub fn DoublyLinkedList(comptime T: type) type
//   pub const RapidHash = struct { ... }
//   pub fn jsErrorToWriteError(e: bun.JSError) std.Io.Writer.Error
//   pub fn autoFormatLabelFallback(...) ...
//   pub fn autoFormatLabel(...) ...
package bao_core

import std.collection.*

// ============================================================================
// BufferedReader - 带缓冲的读取器
// 严格翻译自: src/bun_core/deprecated.zig:1-49
//   pub fn BufferedReader(comptime buffer_size: usize, comptime ReaderType: type) type {
//       return struct {
//           unbuffered_reader: ReaderType,
//           buf: [buffer_size]u8,
//           start: usize = 0,
//           end: usize = 0,
//           ...
//       };
//   }
// ============================================================================

/// 带缓冲的读取器 - 对应 Bun BufferedReader
/// pub const Error = ReaderType.Error;
/// pub const Reader = std.Io.GenericReader(*Self, Error, read);
/// pub fn read(self: *Self, dest: []u8) Error!usize { ... }
public class BufferedReader {
    /// 内部缓冲区大小 - 对应 Bun buf: [buffer_size]u8
    public static let DEFAULT_BUFFER_SIZE: Int64 = 4096

    private let buffer: Array<UInt8>
    private var startPos: Int64
    private var endPos: Int64

    public init(bufferSize: Int64) {
        this.buffer = Array<UInt8>(bufferSize, { _ => UInt8(0) })
        this.startPos = 0
        this.endPos = 0
    }

    public init() {
        this.buffer = Array<UInt8>(DEFAULT_BUFFER_SIZE, { _ => UInt8(0) })
        this.startPos = 0
        this.endPos = 0
    }

    /// 从缓冲区读取到目标数组 - 对应 Bun BufferedReader.read()
    /// pub fn read(self: *Self, dest: []u8) Error!usize {
    ///     const current = self.buf[self.start..self.end];
    ///     if (current.len != 0) {
    ///         const to_transfer = @min(current.len, dest.len);
    ///         @memcpy(dest[0..to_transfer], current[0..to_transfer]);
    ///         self.start += to_transfer;
    ///         return to_transfer;
    ///     }
    ///     if (dest.len >= buffer_size) {
    ///         return self.unbuffered_reader.read(dest);
    ///     }
    ///     self.end = try self.unbuffered_reader.read(&self.buf);
    ///     const to_transfer = @min(self.end, dest.len);
    ///     @memcpy(dest[0..to_transfer], self.buf[0..to_transfer]);
    ///     self.start = to_transfer;
    ///     return to_transfer;
    /// }
    public func read(dest: Array<UInt8>, destOffset: Int64, maxLen: Int64): Int64 {
        // 先尝试从缓冲区读取
        let currentLen = endPos - startPos
        if (currentLen > 0) {
            let toTransfer = if (maxLen < currentLen) { maxLen } else { currentLen }
            for (i in 0..toTransfer) {
                dest[destOffset + i] = buffer[startPos + i]
            }
            startPos += toTransfer
            return toTransfer
        }
        return 0
    }

    /// 向缓冲区写入数据
    public func writeToBuffer(data: Array<UInt8>, offset: Int64, len: Int64): Unit {
        for (i in 0..len) {
            buffer[i] = data[offset + i]
        }
        startPos = 0
        endPos = len
    }

    /// 获取可用数据量
    public func available(): Int64 {
        return endPos - startPos
    }

    /// 重置缓冲区
    public func reset(): Unit {
        startPos = 0
        endPos = 0
    }
}

/// 创建默认缓冲读取器 - 对应 Bun bufferedReader()
/// pub fn bufferedReader(reader: anytype) BufferedReader(4096, @TypeOf(reader)) {
///     return .{ .unbuffered_reader = reader, .buf = undefined };
/// }
public func bufferedReader(): BufferedReader {
    return BufferedReader()
}

/// 创建指定大小的缓冲读取器 - 对应 Bun bufferedReaderSize()
/// pub fn bufferedReaderSize(comptime size: usize, reader: anytype) BufferedReader(size, @TypeOf(reader)) {
///     return .{ .unbuffered_reader = reader, .buf = undefined };
/// }
public func bufferedReaderSize(bufferSize: Int64): BufferedReader {
    return BufferedReader(bufferSize)
}

// ============================================================================
// SinglyLinkedList<T> - 单向链表
// 严格翻译自: src/bun_core/deprecated.zig:58-172
//   pub fn SinglyLinkedList(comptime T: type) type {
//       return struct {
//           pub const Node = struct {
//               next: ?*Node = null,
//               data: T,
//               pub fn insertAfter(...) ...
//               pub fn removeNext(...) ...
//               pub fn findLast(...) ...
//               pub fn countChildren(...) ...
//               pub fn reverse(...) ...
//           };
//           first: ?*Node = null,
//           pub fn prepend(...) ...
//           pub fn remove(...) ...
//           pub fn popFirst(...) ...
//           pub fn len(...) ...
//       };
//   }
// ============================================================================

/// 单向链表节点 - 对应 Bun SinglyLinkedList.Node
public class SinglyLinkedNode<T> {
    /// 下一个节点 - 对应 Bun next: ?*Node = null
    public var next: ?SinglyLinkedNode<T>
    /// 数据 - 对应 Bun data: T
    public var data: T

    /// Unique identity for reference comparison
    private static var nextId: Int64 = 0
    private let uid: Int64

    public init(data: T) {
        this.data = data
        this.next = None
        this.uid = nextId
        nextId = nextId + 1
    }

    public func equals(other: SinglyLinkedNode<T>): Bool {
        return this.uid == other.uid
    }

    /// 在当前节点后插入 - 对应 Bun Node.insertAfter()
    /// pub fn insertAfter(node: *Node, new_node: *Node) void {
    ///     new_node.next = node.next;
    ///     node.next = new_node;
    /// }
    public func insertAfter(newNode: SinglyLinkedNode<T>): Unit {
        newNode.next = next
        next = Some(newNode)
    }

    /// 移除下一个节点 - 对应 Bun Node.removeNext()
    /// pub fn removeNext(node: *Node) ?*Node {
    ///     const next_node = node.next orelse return null;
    ///     node.next = next_node.next;
    ///     return next_node;
    /// }
    public func removeNext(): ?SinglyLinkedNode<T> {
        match (next) {
            case Some(nextNode) =>
                next = nextNode.next
                return Some(nextNode)
            case None =>
                return None
        }
    }

    /// 找到最后一个节点 - 对应 Bun Node.findLast()
    /// pub fn findLast(node: *Node) *Node {
    ///     var it = node;
    ///     while (true) { it = it.next orelse return it; }
    /// }
    public func findLast(): SinglyLinkedNode<T> {
        var it: SinglyLinkedNode<T> = this
        while (true) {
            match (it.next) {
                case Some(n) => it = n
                case None => break
            }
        }
        return it
    }

    /// 计算子节点数量 - 对应 Bun Node.countChildren()
    /// pub fn countChildren(node: *const Node) usize {
    ///     var count: usize = 0;
    ///     var it: ?*const Node = node.next;
    ///     while (it) |n| : (it = n.next) { count += 1; }
    ///     return count;
    /// }
    public func countChildren(): Int64 {
        var count = Int64(0)
        var it = next
        while (true) {
            match (it) {
                case Some(n) =>
                    count += 1
                    it = n.next
                case None =>
                    break
            }
        }
        return count
    }

    /// 反转链表 - 对应 Bun Node.reverse()
    /// pub fn reverse(indirect: *?*Node) void { ... }
    public static func reverse(head: ?SinglyLinkedNode<T>): ?SinglyLinkedNode<T> {
        match (head) {
            case None => return None
            case Some(first) =>
                var current: SinglyLinkedNode<T> = first
                var newHead: ?SinglyLinkedNode<T> = Some(first)
                while (true) {
                    match (current.next) {
                        case Some(nextNode) =>
                            current.next = nextNode.next
                            nextNode.next = newHead
                            newHead = Some(nextNode)
                        case None =>
                            break
                    }
                }
                return newHead
        }
    }
}

/// 单向链表 - 对应 Bun SinglyLinkedList
/// pub fn SinglyLinkedList(comptime T: type) type {
///     return struct {
///         first: ?*Node = null,
///         pub fn prepend(...) ...
///         pub fn remove(...) ...
///         pub fn popFirst(...) ...
///         pub fn len(...) ...
///     };
/// }
public class SinglyLinkedList<T> {
    /// 头节点 - 对应 Bun first: ?*Node = null
    private var first: ?SinglyLinkedNode<T>

    public init() {
        first = None
    }

    /// 在头部插入 - 对应 Bun prepend()
    /// pub fn prepend(list: *Self, new_node: *Node) void {
    ///     new_node.next = list.first;
    ///     list.first = new_node;
    /// }
    public func prepend(newNode: SinglyLinkedNode<T>): Unit {
        newNode.next = first
        first = Some(newNode)
    }

    /// 移除指定节点 - 对应 Bun remove()
    /// pub fn remove(list: *Self, node: *Node) void {
    ///     if (list.first == node) { list.first = node.next; }
    ///     else { var current_elm = list.first.?; while (current_elm.next != node) { current_elm = current_elm.next.?; } current_elm.next = node.next; }
    /// }
    public func remove(node: SinglyLinkedNode<T>): Unit {
        match (first) {
            case Some(f) =>
                if (f.equals(node)) {
                    first = node.next
                    return
                }
                var current = f
                while (true) {
                    match (current.next) {
                        case Some(nextNode) =>
                            if (nextNode.equals(node)) {
                                current.next = node.next
                                return
                            }
                            current = nextNode
                        case None =>
                            return
                    }
                }
            case None => return
        }
    }

    /// 弹出第一个节点 - 对应 Bun popFirst()
    /// pub fn popFirst(list: *Self) ?*Node {
    ///     const first = list.first orelse return null;
    ///     list.first = first.next;
    ///     return first;
    /// }
    public func popFirst(): ?SinglyLinkedNode<T> {
        match (first) {
            case Some(f) =>
                first = f.next
                return Some(f)
            case None =>
                return None
        }
    }

    /// 获取长度 - 对应 Bun len()
    /// pub fn len(list: Self) usize {
    ///     if (list.first) |n| { return 1 + n.countChildren(); }
    ///     else { return 0; }
    /// }
    public func len(): Int64 {
        match (first) {
            case Some(n) => return 1 + n.countChildren()
            case None => return 0
        }
    }

    /// 是否为空
    public func isEmpty(): Bool {
        match (first) {
            case Some(_) => return false
            case None => return true
        }
    }

    /// 获取头节点
    public func getFirst(): ?SinglyLinkedNode<T> {
        return first
    }
}

// ============================================================================
// DoublyLinkedList<T> - 双向链表
// 严格翻译自: src/bun_core/deprecated.zig:229-386
//   pub fn DoublyLinkedList(comptime T: type) type {
//       return struct {
//           pub const Node = struct {
//               prev: ?*Node = null,
//               next: ?*Node = null,
//               data: T,
//           };
//           first: ?*Node = null,
//           last: ?*Node = null,
//           len: usize = 0,
//           pub fn insertAfter(...) ...
//           pub fn insertBefore(...) ...
//           pub fn concatByMoving(...) ...
//           pub fn append(...) ...
//           pub fn prepend(...) ...
//           pub fn remove(...) ...
//           pub fn pop(...) ...
//           pub fn popFirst(...) ...
//       };
//   }
// ============================================================================

/// 双向链表节点 - 对应 Bun DoublyLinkedList.Node
/// pub const Node = struct {
///     prev: ?*Node = null,
///     next: ?*Node = null,
///     data: T,
/// };
public class DoublyLinkedNode<T> {
    /// 前驱节点 - 对应 Bun prev: ?*Node = null
    public var prev: ?DoublyLinkedNode<T>
    /// 后继节点 - 对应 Bun next: ?*Node = null
    public var next: ?DoublyLinkedNode<T>
    /// 数据 - 对应 Bun data: T
    public var data: T

    public init(data: T) {
        this.data = data
        this.prev = None
        this.next = None
    }
}

/// 双向链表 - 对应 Bun DoublyLinkedList
/// first: ?*Node = null, last: ?*Node = null, len: usize = 0
public class DoublyLinkedList<T> {
    /// 头节点 - 对应 Bun first: ?*Node = null
    private var first: ?DoublyLinkedNode<T>
    /// 尾节点 - 对应 Bun last: ?*Node = null
    private var last: ?DoublyLinkedNode<T>
    /// 长度 - 对应 Bun len: usize = 0
    public var len: Int64

    public init() {
        first = None
        last = None
        len = 0
    }

    /// 在指定节点后插入 - 对应 Bun insertAfter()
    /// pub fn insertAfter(list: *Self, node: *Node, new_node: *Node) void {
    ///     new_node.prev = node;
    ///     if (node.next) |next_node| {
    ///         new_node.next = next_node;
    ///         next_node.prev = new_node;
    ///     } else {
    ///         new_node.next = null;
    ///         list.last = new_node;
    ///     }
    ///     node.next = new_node;
    ///     list.len += 1;
    /// }
    public func insertAfter(node: DoublyLinkedNode<T>, newNode: DoublyLinkedNode<T>): Unit {
        newNode.prev = Some(node)
        match (node.next) {
            case Some(nextNode) =>
                newNode.next = Some(nextNode)
                nextNode.prev = Some(newNode)
            case None =>
                newNode.next = None
                last = Some(newNode)
        }
        node.next = Some(newNode)
        len += 1
    }

    /// 在指定节点前插入 - 对应 Bun insertBefore()
    /// pub fn insertBefore(list: *Self, node: *Node, new_node: *Node) void {
    ///     new_node.next = node;
    ///     if (node.prev) |prev_node| {
    ///         new_node.prev = prev_node;
    ///         prev_node.next = new_node;
    ///     } else {
    ///         new_node.prev = null;
    ///         list.first = new_node;
    ///     }
    ///     node.prev = new_node;
    ///     list.len += 1;
    /// }
    public func insertBefore(node: DoublyLinkedNode<T>, newNode: DoublyLinkedNode<T>): Unit {
        newNode.next = Some(node)
        match (node.prev) {
            case Some(prevNode) =>
                newNode.prev = Some(prevNode)
                prevNode.next = Some(newNode)
            case None =>
                newNode.prev = None
                first = Some(newNode)
        }
        node.prev = Some(newNode)
        len += 1
    }

    /// 连接另一个链表 - 对应 Bun concatByMoving()
    /// pub fn concatByMoving(list1: *Self, list2: *Self) void {
    ///     const l2_first = list2.first orelse return;
    ///     if (list1.last) |l1_last| {
    ///         l1_last.next = list2.first;
    ///         l2_first.prev = list1.last;
    ///         list1.len += list2.len;
    ///     } else {
    ///         list1.first = list2.first;
    ///         list1.len = list2.len;
    ///     }
    ///     list1.last = list2.last;
    ///     list2.first = null;
    ///     list2.last = null;
    ///     list2.len = 0;
    /// }
    public func concatByMoving(other: DoublyLinkedList<T>): Unit {
        match (other.first) {
            case None => return
            case Some(l2First) =>
                match (last) {
                    case Some(l1Last) =>
                        l1Last.next = other.first
                        l2First.prev = Some(l1Last)
                        len += other.len
                    case None =>
                        first = other.first
                        len = other.len
                }
                last = other.last
                other.first = None
                other.last = None
                other.len = 0
        }
    }

    /// 追加到末尾 - 对应 Bun append()
    /// pub fn append(list: *Self, new_node: *Node) void {
    ///     if (list.last) |last| { list.insertAfter(last, new_node); }
    ///     else { list.prepend(new_node); }
    /// }
    public func append(newNode: DoublyLinkedNode<T>): Unit {
        match (last) {
            case Some(l) => insertAfter(l, newNode)
            case None => prepend(newNode)
        }
    }

    /// 追加到头部 - 对应 Bun prepend()
    /// pub fn prepend(list: *Self, new_node: *Node) void {
    ///     if (list.first) |first| { list.insertBefore(first, new_node); }
    ///     else {
    ///         list.first = new_node;
    ///         list.last = new_node;
    ///         new_node.prev = null;
    ///         new_node.next = null;
    ///         list.len = 1;
    ///     }
    /// }
    public func prepend(newNode: DoublyLinkedNode<T>): Unit {
        match (first) {
            case Some(f) => insertBefore(f, newNode)
            case None =>
                first = Some(newNode)
                last = Some(newNode)
                newNode.prev = None
                newNode.next = None
                len = 1
        }
    }

    /// 移除节点 - 对应 Bun remove()
    /// pub fn remove(list: *Self, node: *Node) void {
    ///     if (node.prev) |prev_node| { prev_node.next = node.next; }
    ///     else { list.first = node.next; }
    ///     if (node.next) |next_node| { next_node.prev = node.prev; }
    ///     else { list.last = node.prev; }
    ///     list.len -= 1;
    /// }
    public func remove(node: DoublyLinkedNode<T>): Unit {
        match (node.prev) {
            case Some(prevNode) => prevNode.next = node.next
            case None => first = node.next
        }
        match (node.next) {
            case Some(nextNode) => nextNode.prev = node.prev
            case None => last = node.prev
        }
        len -= 1
    }

    /// 弹出末尾节点 - 对应 Bun pop()
    /// pub fn pop(list: *Self) ?*Node {
    ///     const last = list.last orelse return null;
    ///     list.remove(last);
    ///     return last;
    /// }
    public func pop(): ?DoublyLinkedNode<T> {
        match (last) {
            case Some(l) =>
                remove(l)
                return Some(l)
            case None =>
                return None
        }
    }

    /// 弹出头节点 - 对应 Bun popFirst()
    /// pub fn popFirst(list: *Self) ?*Node {
    ///     const first = list.first orelse return null;
    ///     list.remove(first);
    ///     return first;
    /// }
    public func popFirst(): ?DoublyLinkedNode<T> {
        match (first) {
            case Some(f) =>
                remove(f)
                return Some(f)
            case None =>
                return None
        }
    }

    /// 获取头节点
    public func getFirst(): ?DoublyLinkedNode<T> {
        return first
    }

    /// 获取尾节点
    public func getLast(): ?DoublyLinkedNode<T> {
        return last
    }

    /// 是否为空
    public func isEmpty(): Bool {
        return len == 0
    }
}

// ============================================================================
// RapidHash - 快速哈希算法
// 严格翻译自: src/bun_core/deprecated.zig:502-621
//   pub const RapidHash = struct {
//       const RAPID_SEED: u64 = 0xbdd89aa982704029;
//       const RAPID_SECRET: [3]u64 = .{ 0x2d358dccaa6c78a5, 0x8bb84b93962eacc9, 0x4b33a62ed433d4a3 };
//       pub fn hash(seed: u64, input: []const u8) u64 { ... }
//       inline fn mum(a: *u64, b: *u64) void { ... }
//       inline fn mix(a: u64, b: u64) u64 { ... }
//       inline fn r64(p: []const u8) u64 { ... }
//       inline fn r32(p: []const u8) u64 { ... }
//   };
// ============================================================================

/// RapidHash 快速哈希 - 对应 Bun RapidHash
/// const RAPID_SEED: u64 = 0xbdd89aa982704029;
/// const RAPID_SECRET: [3]u64 = .{ 0x2d358dccaa6c78a5, 0x8bb84b93962eacc9, 0x4b33a62ed433d4a3 };
public class RapidHash {
    /// 默认种子 - 对应 Bun RAPID_SEED
    public static const RAPID_SEED: UInt64 = 0xbdd89aa982704029u64
    /// 秘钥 - 对应 Bun RAPID_SECRET
    public static let RAPID_SECRET: Array<UInt64> = [0x2d358dccaa6c78a5u64, 0x8bb84b93962eacc9u64, 0x4b33a62ed433d4a3u64]

    /// 哈希函数 - 对应 Bun RapidHash.hash()
    /// pub fn hash(seed: u64, input: []const u8) u64 { ... }
    public static func hash(seed: UInt64, input: Array<UInt8>): UInt64 {
        let sc = RAPID_SECRET
        let inputLen = input.size
        var a: UInt64 = UInt64(0)
        var b: UInt64 = UInt64(0)
        var k = input
        var kOffset = Int64(0)
        var remaining = inputLen

        var is0 = mix(seed ^ sc[0], sc[1]) ^ UInt64(inputLen)

        if (inputLen <= 16) {
            if (inputLen >= 4) {
                let d = (inputLen & 24) >> (inputLen >> 3)
                let e = inputLen - 4
                a = (r32At(input, kOffset) << 32) | r32At(input, kOffset + e)
                b = (r32At(input, kOffset + d) << 32) | r32At(input, kOffset + (e - d))
            } else if (inputLen > 0) {
                a = (UInt64(input[kOffset]) << 56) | (UInt64(input[kOffset + (inputLen >> 1)]) << 32) | UInt64(input[kOffset + inputLen - 1])
            }
        } else {
            if (inputLen > 48) {
                var is1 = is0
                var is2 = is0
                while (remaining >= 96) {
                    for (i in 0..6) {
                        let m1 = r64At(input, kOffset + 8 * i * 2)
                        let m2 = r64At(input, kOffset + 8 * (i * 2 + 1))
                        let idx = Int64(i % 3)
                        if (idx == 0) { is0 = mix(m1 ^ sc[0], m2 ^ is0) }
                        else if (idx == 1) { is1 = mix(m1 ^ sc[1], m2 ^ is1) }
                        else { is2 = mix(m1 ^ sc[2], m2 ^ is2) }
                    }
                    kOffset += 96
                    remaining -= 96
                }
                if (remaining >= 48) {
                    for (i in 0..3) {
                        let m1 = r64At(input, kOffset + 8 * i * 2)
                        let m2 = r64At(input, kOffset + 8 * (i * 2 + 1))
                        if (i == 0) { is0 = mix(m1 ^ sc[0], m2 ^ is0) }
                        else if (i == 1) { is0 = mix(m1 ^ sc[1], m2 ^ is0) }
                        else { is0 = mix(m1 ^ sc[2], m2 ^ is0) }
                    }
                    kOffset += 48
                    remaining -= 48
                }
                is0 = is0 ^ is1 ^ is2
            }

            if (remaining > 16) {
                is0 = mix(r64At(input, kOffset) ^ sc[2], r64At(input, kOffset + 8) ^ is0 ^ sc[1])
                if (remaining > 32) {
                    is0 = mix(r64At(input, kOffset + 16) ^ sc[2], r64At(input, kOffset + 24) ^ is0)
                }
            }

            a = r64At(input, inputLen - 16)
            b = r64At(input, inputLen - 8)
        }

        a = a ^ sc[1]
        b = b ^ is0
        let (ra, rb) = mum(a, b)
        return mix(ra ^ sc[0] ^ UInt64(inputLen), rb ^ sc[1])
    }

    /// 使用默认种子的哈希
    public static func hash(input: Array<UInt8>): UInt64 {
        return hash(RAPID_SEED, input)
    }

    /// mum 乘法混合 - 对应 Bun RapidHash.mum()
    /// inline fn mum(a: *u64, b: *u64) void {
    ///     const r = @as(u128, a.*) * b.*;
    ///     a.* = @truncate(r);
    ///     b.* = @truncate(r >> 64);
    /// }
    public static func mum(a: UInt64, b: UInt64): (UInt64, UInt64) {
        // 128-bit multiplication: use upper and lower 64 bits
        let (hi, lo) = mul128(a, b)
        return (lo, hi)
    }

    /// mix 混合 - 对应 Bun RapidHash.mix()
    /// inline fn mix(a: u64, b: u64) u64 {
    ///     var copy_a = a; var copy_b = b;
    ///     mum(&copy_a, &copy_b);
    ///     return copy_a ^ copy_b;
    /// }
    public static func mix(a: UInt64, b: UInt64): UInt64 {
        let (ra, rb) = mum(a, b)
        return ra ^ rb
    }

    /// 读取小端 64 位 - 对应 Bun RapidHash.r64()
    /// inline fn r64(p: []const u8) u64 { return readInt(u64, p[0..8], .little); }
    public static func r64At(data: Array<UInt8>, offset: Int64): UInt64 {
        var result = UInt64(0)
        for (i in 0..8) {
            result = result | (UInt64(data[offset + i]) << (i * 8))
        }
        return result
    }

    /// 读取小端 32 位 - 对应 Bun RapidHash.r32()
    /// inline fn r32(p: []const u8) u64 { return readInt(u32, p[0..4], .little); }
    public static func r32At(data: Array<UInt8>, offset: Int64): UInt64 {
        var result = UInt64(0)
        for (i in 0..4) {
            result = result | (UInt64(data[offset + i]) << (i * 8))
        }
        return result
    }

    /// 128 位乘法辅助
    private static func mul128(a: UInt64, b: UInt64): (UInt64, UInt64) {
        // 使用 Karatsuba 分解: a*b = hi*2^64 + lo
        let aLo = a & UInt64(0xFFFFFFFF)
        let aHi = a >> 32
        let bLo = b & UInt64(0xFFFFFFFF)
        let bHi = b >> 32

        let p0 = aLo * bLo
        let p1 = aLo * bHi
        let p2 = aHi * bLo
        let p3 = aHi * bHi

        let carry = (p0 >> 32) + (p1 & UInt64(0xFFFFFFFF)) + (p2 & UInt64(0xFFFFFFFF))
        let lo = (p0 & UInt64(0xFFFFFFFF)) | (carry << 32)
        let hi = p3 + (p1 >> 32) + (p2 >> 32) + (carry >> 32)

        return (hi, lo)
    }
}

// ============================================================================
// 辅助函数
// 严格翻译自: src/bun_core/deprecated.zig:623-650
// ============================================================================

/// JS 错误转写入错误 - 对应 Bun jsErrorToWriteError()
/// pub fn jsErrorToWriteError(e: bun.JSError) std.Io.Writer.Error
public func jsErrorToWriteError(): BaoError {
    return BaoError(ErrorCode.WriteFailed)
}
