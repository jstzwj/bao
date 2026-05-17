// 翻译自 Bun: src/runtime/bake/dev_server/mod.rs
// DevServer 子模块入口。Rust 源文件聚合 assets、incremental_graph、lifecycle、packed_map、route_bundle、serialized_failure、source_map_store 等实现。

package bao_runtime.bake.dev_server

// Cangjie packages cannot publicly import themselves from a same-named aggregator.

// ============================================================================
// 共享类型别名
// 这些类型别名在整个 dev_server 包中使用，集中定义在此处避免重复声明
// ============================================================================

public type ArrayListUnmanaged<T> = std.ArrayListUnmanaged<T>
public type AutoArrayHashMapUnmanaged<K, V> = std.AutoArrayHashMapUnmanaged<K, V>
public type StringArrayHashMapUnmanaged<V> = std.StringArrayHashMapUnmanaged<V>
public type Allocator = std.mem.Allocator
public type EventLoopTimer = bun.api.Timer.EventLoopTimer
public type LinearFifo<T> = bun.LinearFifo<T>
public type MultiArrayList<T> = bun.MultiArrayList<T>
public type StringJoiner = bun.StringJoiner
public type GenericIndex<T, P> = bun.GenericIndex<T, P>
