// 翻译自 Bun: src/runtime/bake/DevServer/SourceMapStore.zig
// /_bun/client/{id}.js.map 上的源映射存储。
// 所有源映射都是引用计数的。

package bao_runtime.bake.dev_server

import bao_bun_alloc.Allocator

/// SourceMapStore Key
public struct SourceMapStoreKey {
    public var value: UInt64
    public init(value: UInt64) { this.value = value }
    public func get(): UInt64 { value }
}

/// SourceId
public struct SourceId {
    public var value: UInt64
    public var kind: ChunkKind
    public var bits: SourceIdBits

    public init() {
        value = 0
        kind = ChunkKind.initial_response
        bits = SourceIdBits()
    }
}

/// SourceIdBits
public struct SourceIdBits {
    public var initial_response: InitialResponse
    public var hmr_chunk: HmrChunk

    public init() {
        initial_response = InitialResponse()
        hmr_chunk = HmrChunk()
    }
}

/// InitialResponse
public struct InitialResponse {
    public var unused: UInt32
    public var generation_id: UInt32

    public init() {
        unused = 0
        generation_id = 0
    }
}

/// HmrChunk
public struct HmrChunk {
    public var content_hash: UInt64

    public init() {
        content_hash = 0
    }
}

/// Entry - 源映射条目
public class SourceMapEntry {
    public var dev_allocator: DevAllocator
    /// 引用计数
    public var ref_count: UInt32
    /// 文件路径
    public var paths: Array<String>
    /// 文件数据
    public var files: Array<PackedMap>
    /// 摊销内存成本
    public var overlapping_memory_cost: UInt32

    public init() {
        dev_allocator = DevAllocator()
        ref_count = 0
        paths = Array<String>()
        files = Array<PackedMap>()
        overlapping_memory_cost = 0
    }

    /// 渲染映射
    public func renderMappings(kind: ChunkKind, arena: Allocator, gpa: Allocator): Array<Byte> {
        return Array<Byte>()
    }

    /// 渲染 JSON
    public func renderJSON(dev: DevServer, arena: Allocator, kind: ChunkKind, gpa: Allocator, side: Side): Array<Byte> {
        return Array<Byte>()
    }

    /// 析构
    public func deinit(): Unit {
        for (file in files) {
            file.deinit()
        }
    }

    /// 内存成本
    public func memoryCost(): Int64 {
        var cost: Int64 = 0
        for (file in files) {
            cost += file.memoryCost()
        }
        return cost
    }

    func allocator(): Allocator {
        return dev_allocator.allocator()
    }
}

/// WeakRef - 弱引用
public class WeakRef {
    public var key_top_bits: UInt32
    public var count: UInt32
    public var expire: Int64

    public init() {
        key_top_bits = 0
        count = 0
        expire = 0
    }

    public init(key_top_bits: UInt32, count: UInt32, expire: Int64) {
        this.key_top_bits = key_top_bits
        this.count = count
        this.expire = expire
    }

    /// 获取键
    public func key(): UInt64 {
        return UInt64(key_top_bits) << 32
    }
}

/// GetResult - 获取源映射的结果
public class GetResult {
    public var index: UInt32
    public var mappings: SourceMapMappingList
    public var file_paths: Array<String>
    public var entry_files: Array<PackedMap>

    public init() {
        index = 0
        mappings = SourceMapMappingList()
        file_paths = Array<String>()
        entry_files = Array<PackedMap>()
    }

    public func deinit(alloc: Allocator): Unit {
        // mappings.deinit(alloc)
    }

    public func isNone(): Bool { false }
}

/// SourceMapStore - 源映射存储
public class SourceMapStore {
    /// 条目映射
    public var entries: HashMap<UInt64, SourceMapEntry>
    /// 弱引用队列
    public var weak_refs: Array<WeakRef>
    /// 共享的弱引用清理定时器
    public var weak_ref_sweep_timer: EventLoopTimer

    public init() {
        entries = HashMap<UInt64, SourceMapEntry>()
        weak_refs = Array<WeakRef>()
        weak_ref_sweep_timer = EventLoopTimer()
    }

    public static let empty: SourceMapStore = SourceMapStore()

    /// 弱引用过期时间（秒）
    public static let weak_ref_expiry_seconds: UInt64 = 10
    /// 弱引用最大条目数
    public static let weak_ref_entry_max: UInt64 = 16

    /// 放入或增加引用计数
    public func putOrIncrementRefCount(script_id: UInt64, ref_count: UInt32): PutOrIncrementRefCount {
        if (entries.get(script_id).isNone()) {
            assert(ref_count > 0)
            let entry = SourceMapEntry()
            entry.ref_count = ref_count
            entries.put(script_id, entry)
            return PutOrIncrementRefCount.uninitialized(entry)
        } else {
            if (let Some(entry) <- entries.get(script_id)) {
                entry.ref_count += ref_count
            }
            return PutOrIncrementRefCount.shared(SourceMapEntry())
        }
    }

    /// 取消引用
    public func unref(key: UInt64): Unit {
        unrefCount(key, 1)
    }

    /// 按数量取消引用
    public func unrefCount(key: UInt64, count: UInt32): Unit {
        if (let Some(entry) <- entries.get(key)) {
            entry.ref_count -= count
            if (entry.ref_count == 0) {
                entry.deinit()
                entries.remove(key)
            }
        }
    }

    /// 添加弱引用
    public func addWeakRef(key: UInt64): Unit {
        if (let Some(entry) <- entries.get(key)) {
            entry.ref_count += 1
        }
    }

    /// 移除或升级弱引用
    public func removeOrUpgradeWeakRef(key: UInt64, mode: WeakRefMode): Bool {
        if (entries.get(key).isNone()) { return false }
        match (mode) {
            case WeakRefMode.remove => unref(key)
            case WeakRefMode.upgrade => ()
        }
        return true
    }

    /// 扫描弱引用
    public func sweepWeakRefs(timer: EventLoopTimer, now_ts: timespec): Unit {
        // 简化
    }

    /// 获取解析的源映射
    public func getParsedSourceMap(script_id: UInt64, arena: Allocator, gpa: Allocator): ?GetResult {
        if (entries.get(script_id).isNone()) { return None }
        let result = GetResult()
        return result
    }

    func owner(): DevServer {
        DevServer()
    }

    func allocator(): Allocator {
        return owner().allocator()
    }
}

/// 弱引用模式
public enum WeakRefMode {
    | remove
    | upgrade
}

/// 放入或增加引用计数结果
public enum PutOrIncrementRefCount {
    | uninitialized(SourceMapEntry)
    | shared(SourceMapEntry)
}
