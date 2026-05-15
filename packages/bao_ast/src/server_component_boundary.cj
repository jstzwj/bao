// 严格翻译自: src/ast/server_component_boundary.zig (~120行)
// bao_ast - 服务端组件边界: client/server 代码分割边界
package bao_ast

import bao_core.*
import bao_collections.*

// ============================================================================
// ServerComponentBoundary - 服务端组件边界
// 严格翻译自: src/ast/server_component_boundary.zig:1-120
//
// 表示 client 和 server 代码之间的边界。每个边界被打包两次:
// 1. 一次用于目标平台
// 2. 一次用于生成 "references" 模块
//
// 具体来说, 生成的文件以 canonical Ast 为输入来派生一个 wrapper。
// 参见 Framework.ServerComponents 获取更多关于生成文件的详细信息。
//
// 简称: SCB (Server Component Boundary)
// ============================================================================

/// 服务端组件边界 - 对应 Bun ServerComponentBoundary
/// Bun: pub const ServerComponentBoundary = struct {
///   use_directive: UseDirective,
///   source_index: Index.Int,
///   reference_source_index: Index.Int,
///   ssr_source_index: Index.Int,
/// }
public class ServerComponentBoundary {
    /// 使用指令 ("use client" / "use server")
    public var useDirective: UseDirective
    /// 原始文件的索引
    public var sourceIndex: Int32
    /// 对端平台生成的文件的索引
    /// 对于 client 组件, 这是 server 的代码
    /// 对于 server actions, 这是 client 的代码
    public var referenceSourceIndex: Int32
    /// SSR 源文件索引
    /// 当 bake.Framework.ServerComponents.separate_ssr_graph 启用时,
    /// 指向分离的模块。否则等于 reference_source_index
    public var ssrSourceIndex: Int32

    public init(useDirective: UseDirective, sourceIndex: Int32,
                referenceSourceIndex: Int32, ssrSourceIndex: Int32) {
        this.useDirective = useDirective
        this.sourceIndex = sourceIndex
        this.referenceSourceIndex = referenceSourceIndex
        this.ssrSourceIndex = ssrSourceIndex
    }
}

/// 服务端组件边界列表 - 对应 Bun ServerComponentBoundary.List
/// Bun: pub const List = struct { list: MultiArrayList, map: Map }
///
/// 此数据结构的要求是具有合理的查找速度,
/// 同时能够拉取所有边界的 []const Index.Int 进行迭代。
public class ServerComponentBoundaryList {
    /// 边界列表
    public var list: ArrayList<ServerComponentBoundary>
    /// 源索引到列表索引的映射 (source_index -> list index)
    public var map: HashMap<Int32, Int64>

    public init() {
        this.list = ArrayList<ServerComponentBoundary>()
        this.map = HashMap<Int32, Int64>()
    }

    /// 添加边界 - 对应 Bun ServerComponentBoundary.List.put()
    /// Bun: pub fn put(m: *List, allocator, source_index, use_directive, ...) !void
    public func put(sourceIndex: Int32, useDirective: UseDirective,
                    referenceSourceIndex: Int32, ssrSourceIndex: Int32): Unit {
        let boundary = ServerComponentBoundary(
            useDirective, sourceIndex,
            referenceSourceIndex, ssrSourceIndex
        )
        list.append(boundary)
        map.put(sourceIndex, Int64(list.size) - Int64(1))
    }

    /// 按源索引获取列表中的索引 - 对应 Bun ServerComponentBoundary.List.getIndex()
    /// Bun: pub fn getIndex(l: *const List, real_source_index: Index.Int) ?usize
    public func getIndex(realSourceIndex: Int32): ?Int64 {
        return map.get(realSourceIndex)
    }

    /// 获取引用源索引 - 对应 Bun ServerComponentBoundary.Slice.getReferenceSourceIndex()
    /// Bun: pub fn getReferenceSourceIndex(l: *const Slice, real_source_index: Index.Int) ?u32
    public func getReferenceSourceIndex(realSourceIndex: Int32): ?Int32 {
        let idx = map.get(realSourceIndex)
        match (idx) {
            case Some(i) =>
                if (i < list.size) {
                    return Some(list[Int64(i)].referenceSourceIndex)
                }
                return None
            case None => return None
        }
    }

    /// 构建位集 - 对应 Bun ServerComponentBoundary.Slice.bitSet()
    /// Bun: pub fn bitSet(scbs, alloc, input_file_count) !DynamicBitSetUnmanaged
    /// 返回所有 SCB 源索引的集合
    public func bitSet(inputFileCount: Int64): HashSet<Int32> {
        let bitset = HashSet<Int32>()
        for (boundary in list) {
            bitset.put(boundary.sourceIndex)
        }
        return bitset
    }

    /// 获取所有源索引
    public func sourceIndices(): ArrayList<Int32> {
        let result = ArrayList<Int32>()
        for (boundary in list) {
            result.append(boundary.sourceIndex)
        }
        return result
    }
}

/// "use" 指令 - 对应 Bun UseDirective
/// Bun: pub const UseDirective = enum(u2) { none, client, server }
public enum UseDirective {
    | None    // 无指令
    | Client  // "use client"
    | Server  // "use server"

    /// 是否为边界 - 对应 Bun UseDirective.isBoundary()
    /// Bun: pub fn isBoundary(this: UseDirective, other: UseDirective) bool
    public func isBoundary(other: UseDirective): Bool {
        if (this == other || other == UseDirective.None) {
            return false
        }
        return true
    }

    /// 获取边界类型 - 对应 Bun UseDirective.boundering()
    /// Bun: pub fn boundering(this: UseDirective, other: UseDirective) ?Boundering
    public func boundering(other: UseDirective): ?UseDirective {
        if (this == other || other == UseDirective.None) {
            return None
        }
        return Some(other)
    }

    public func name(): String {
        match (this) {
            case None => "none"
            case Client => "client"
            case Server => "server"
        }
    }
}

/// "use" 指令标志 - 对应 Bun UseDirective.Flags
/// Bun: pub const Flags = struct { has_any_client: bool = false }
public class UseDirectiveFlags {
    public var hasAnyClient: Bool

    public init() {
        this.hasAnyClient = false
    }
}
