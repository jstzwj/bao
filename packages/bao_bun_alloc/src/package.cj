// 严格翻译自: src/bun_alloc/bun_alloc.zig + 相关模块
// bao_bun_alloc 包入口 - 重新导出所有公共类型

package bao_bun_alloc

// ============================================================================
// 基础分配器
// ============================================================================

// c_allocator 和 z_allocator 在 bun_alloc.cj 中定义
// freeWithoutSize 在 fallback.cj 中定义

// ============================================================================
// 类型重新导出
// ============================================================================

// 分配作用域
public type AllocScope = AllocationScope

// 可空分配器
public type NullableAlloc_ = NullableAllocator

// 最大堆分配器
public type MaxHeapAlloc = MaxHeapAllocator

// Linux memfd 分配器
public type LinuxMemFdAlloc = LinuxMemFdAllocator

// 缓冲区回退分配器
public type BufferFallbackAlloc = BufferFallbackAllocator

// "可能拥有"分配器
public type MaybeOwnedAlloc = MaybeOwnedAllocator

// mimalloc 堆区域
public type MimallocArena_ = MimallocArena
public type MimallocBorrowed = MimallocArenaBorrowed
public type MimallocDefault = MimallocArenaDefault

// 内存工具
public type MemUtils = MemoryUtils

// 堆内存分区 (macOS)
public type HeapBreakdown_ = HeapBreakdown
public type HeapZone = Zone

// 单次分配器
public type SingleAlloc = SingleAllocation

// 默认分配器
public type DefaultAlloc = DefaultAllocator

// ============================================================================
// 核心数据结构导出
// ============================================================================

// 索引类型
public type IdxType = IndexType
public type AllocResult_ = AllocResult
public type ItemStatus_ = ItemStatus
public type IdxMap = IndexMap
public type IdxMapManaged = IndexMapManaged

// 溢出列表
public type OverflowList_<T> = OverflowList<T>
public type OverflowGroup_<T> = OverflowGroup<T>

// BSS 数据结构
public type BSSList_<T> = BSSList<T>
public type BSSStringList_ = BSSStringList
public type BSSMap_<T> = BSSMap<T>

// 分配作用域类型
public type AllocScopeState_ = AllocScopeState
public type AllocScopeStats_ = AllocScopeStats
public type AllocScopeBorrowed = AllocationScopeBorrowed

// 内存相关
public type MemFdBytes_ = MemFdBytes

// 包版本
public let BAO_BUN_ALLOC_VERSION = "0.1.0"
