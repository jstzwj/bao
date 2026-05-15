// bao_collections - IdentityContext 引用相等性比较上下文
// 严格翻译自: src/collections/identity_context.zig
//   pub fn IdentityContext(comptime Key: type) type { ... }
//   pub const ArrayIdentityContext = struct { ... }
//   用于哈希表中以引用相等性 (而非结构相等性) 比较键的场景
package bao_collections

import bao_hash.*

// ============================================================================
// IdentityContext - 引用相等性哈希上下文
// 严格翻译自: src/collections/identity_context.zig
//   Zig:
//     pub fn IdentityContext(comptime Key: type) type {
//         return struct {
//             pub fn hash(_: @This(), key: Key) u64 { ... }
//             pub fn eql(_: @This(), a: Key, b: Key) bool { a == b }
//         }
//     }
//   仓颉: 使用泛型接口 + 默认实现，支持 Hashable + Equatable 的任意键类型
//   对于整数键: hash = key 本身 (Zig: .int => key)
//   对于枚举键: hash = ordinal (Zig: .@"enum" => @intFromEnum(key))
// ============================================================================

/// 引用相等性哈希上下文 - 对应 Bun IdentityContext
/// 用于当哈希表需要直接比较值 (而非深度比较) 的场景
/// 例如: 整数键、枚举键等
///
/// Bun 设计:
///   IdentityContext 用于 HashMap 中不重新哈希的场景
///   ArrayIdentityContext 用于 ArrayHashMap (u32 hash)
///   U64 变体用于 64 位键截断为 32 位 hash 的场景
public class IdentityContext<K> where K <: Equatable<K> {
    /// 默认构造
    public init() {}

    /// 哈希函数 - 对应 Bun IdentityContext.hash
    /// Zig: 根据类型直接返回值 (整数 = 值本身, 枚举 = ordinal)
    /// 仓颉: 使用 WyHash 对键的字符串表示进行哈希
    public func hash(key: K): UInt64 {
        // 对于整数类型，尝试直接使用其值
        // Zig: .int => key, .@"enum" => @intFromEnum(key)
        // 仓颉: 使用 WyHash 统一处理
        return WyHash.hash(key.toString())
    }

    /// 相等比较 - 对应 Bun IdentityContext.eql
    /// Zig: return a == b (直接值比较)
    public func eql(a: K, b: K): Bool {
        return a == b
    }
}

/// Int64 的 IdentityContext - 直接使用值作为哈希
/// 对应 Bun IdentityContext(.int) 优化路径
public class IntIdentityContext {
    public init() {}

    /// 整数哈希 - 直接返回值
    /// Zig: .int => key
    public func hash(key: Int64): UInt64 {
        return UInt64(key)
    }

    /// 相等比较 - 直接值比较
    public func eql(a: Int64, b: Int64): Bool {
        return a == b
    }
}

/// UInt64 的 IdentityContext - 直接使用值作为哈希
public class UInt64IdentityContext {
    public init() {}

    public func hash(key: UInt64): UInt64 {
        return key
    }

    public func eql(a: UInt64, b: UInt64): Bool {
        return a == b
    }
}

// ============================================================================
// ArrayIdentityContext - 数组哈希映射的引用相等性上下文
// 严格翻译自: src/collections/identity_context.zig - ArrayIdentityContext
//   Zig:
//     pub const ArrayIdentityContext = struct {
//         pub fn hash(_: @This(), key: u32) u32 { return key; }
//         pub fn eql(_: @This(), a: u32, b: u32, _: usize) bool { return a == b; }
//         pub const U64 = struct {
//             pub fn hash(_: @This(), key: u64) u32 { return @truncate(key); }
//             pub fn eql(_: @This(), a: u64, b: u64, _: usize) bool { return a == b; }
//         };
//     };
//   Bun 设计:
//     ArrayHashMap 使用 u32 hash，HashMap 使用 u64 hash
//     ArrayIdentityContext 用于以已有 hash 值为键的场景
//     避免对 hash 值再次哈希，减少冲突概率
// ============================================================================

/// 数组哈希映射的引用相等性上下文 - 对应 Bun ArrayIdentityContext
/// 用于当键本身就是哈希值的场景，避免二次哈希
///
/// Zig: hash 直接返回 key (u32)
/// eql 额外接收 b_index 参数 (仓颉中忽略)
public class ArrayIdentityContext {
    public init() {}

    /// 哈希函数 - 直接返回 key (不做二次哈希)
    /// Zig: pub fn hash(_: @This(), key: u32) u32 { return key; }
    /// 用于: 当存储的键已经是哈希值时，避免对哈希值再次哈希
    /// 这可以降低冲突概率并提高性能
    public func hash(key: UInt32): UInt32 {
        return key
    }

    /// 相等比较 - 直接值比较
    /// Zig: pub fn eql(_: @This(), a: u32, b: u32, _: usize) bool { return a == b; }
    /// b_index 参数在仓颉中不使用 (Zig 中用于自适应上下文查找兄弟存储)
    public func eql(a: UInt32, b: UInt32): Bool {
        return a == b
    }
}

/// ArrayIdentityContext.U64 - 64 位键的引用相等性上下文
/// 严格翻译自: src/collections/identity_context.zig - ArrayIdentityContext.U64
/// Zig:
///   pub const U64 = struct {
///       pub fn hash(_: @This(), key: u64) u32 { return @truncate(key); }
///       pub fn eql(_: @This(), a: u64, b: u64, _: usize) bool { return a == b; }
///   };
///
/// 当存储 64 位哈希值作为 ArrayHashMap 的键时使用
/// 将 u64 截断为 u32 (Zig: @truncate)
/// 因为 ArrayHashMap 内部使用 u32 hash
public class ArrayIdentityContextU64 {
    public init() {}

    /// 哈希函数 - 将 u64 截断为 u32
    /// Zig: pub fn hash(_: @This(), key: u64) u32 { return @truncate(key); }
    /// 截断说明: 取低 32 位，用于将 64 位哈希值适配到 32 位哈希表
    public func hash(key: UInt64): UInt32 {
        return UInt32(key & UInt64(0xFFFFFFFF))
    }

    /// 相等比较 - 直接值比较
    /// Zig: pub fn eql(_: @This(), a: u64, b: u64, _: usize) bool { return a == b; }
    public func eql(a: UInt64, b: UInt64): Bool {
        return a == b
    }
}
