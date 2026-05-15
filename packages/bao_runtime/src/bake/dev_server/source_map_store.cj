// 翻译自 Bun: src/runtime/bake/DevServer/SourceMapStore.zig
// /_bun/client/{id}.js.map 上的源映射存储。
// 所有源映射都是引用计数的，以便当 WebSocket 断开连接或 bundle 被替换时，
// 不可达的源映射 URL 被撤销。

package bao_runtime.bake.dev_server

/// SourceMapStore - 源映射存储
/// 所有源映射都是引用计数的，以便在 WebSocket 断开或 bundle 替换时撤销不可达的 URL。
public struct Key <: UInt64 {}

public struct SourceId <: UInt64 {
    public var kind: ChunkKind
    public var bits: SourceIdBits
}

public struct SourceIdBits {
    public var initial_response: InitialResponse  // 初始响应
    public var hmr_chunk: HmrChunk                // HMR chunk
}

public struct InitialResponse {
    public var unused: UInt31  // 始终为 0
    public var generation_id: UInt32
}

public struct HmrChunk {
    public var content_hash: UInt63
}

public class Entry {
    public var dev_allocator: DevAllocator
    /// 引用计数
    public var ref_count: UInt32
    /// 文件路径（索引偏移一，因为排除 HMR 运行时）
    public var paths: Array<String>
    /// 文件数据（索引偏移一）
    public var files: MultiArrayList<PackedMap.Shared>
    /// 摊销内存成本
    public var overlapping_memory_cost: UInt32

    /// 渲染映射
    public func renderMappings(kind: ChunkKind, arena: Allocator, gpa: Allocator): Array<Byte> {
        var j: StringJoiner = StringJoiner(allocator: arena)
        j.pushStatic("AAAA")
        joinVLQ(kind, j, arena, .client)
        return j.done(gpa)
    }

    /// 渲染 JSON
    public func renderJSON(dev: DevServer, arena: Allocator, kind: ChunkKind, gpa: Allocator, side: Side): Array<Byte> {
        let map_files = files.slice()
        let paths = paths

        var j: StringJoiner = StringJoiner(allocator: arena)
        j.pushStatic("{\"version\":3,\"sources\":[\"bun://Bun/Bun HMR Runtime\"")

        // 添加源文件路径
        var source_map_strings: ArrayList<Byte> = ArrayList<Byte>.init(arena)

        for (native_file_path in paths) {
            source_map_strings.appendSlice(",")
            if (std.fs.path.isAbsolute(native_file_path)) {
                if (side == .client) {
                    source_map_strings.appendSlice("\"file://")
                } else {
                    source_map_strings.appendSlice("\"")
                }
                // 编码路径
                encodeSourceMapPath(side, native_file_path, source_map_strings)
                source_map_strings.appendSlice("\"")
            } else {
                source_map_strings.appendSlice("\"bun://")
                bun.strings.percentEncodeWrite(native_file_path, source_map_strings)
                source_map_strings.appendSlice("\"")
            }
        }

        j.pushStatic(source_map_strings.items)
        j.pushStatic("],\"sourcesContent\":[\"// (Bun's internal HMR runtime is minified)\"")

        // 添加源内容
        for (i in 0..map_files.length) {
            let chunk = map_files.get(i)
            if (let Some(source_map) = chunk.get()) {
                j.pushStatic(",")
                let quoted_slice = source_map.quotedContents()
                j.pushStatic(quoted_slice)
            } else {
                j.pushStatic(",\"\"")
            }
        }

        j.pushStatic("],\"names\":[],\"mappings\":\"AAAA")
        joinVLQ(kind, j, arena, side)

        return j.doneWithEnd("\"}")
    }

    /// 编码源映射路径
    static func encodeSourceMapPath(side: Side, utf8_input: String, array_list: ArrayList<Byte>): Unit {
        if (side == .client) {
            bun.strings.percentEncodeWrite(utf8_input, array_list)
            return
        }
        // 服务器端使用预引用字符串
        let writer = array_list.writer()
        bun.js_printer.writePreQuotedString(utf8_input, writer, '"', false, true, .utf8)
    }

    /// 连接 VLQ 映射
    func joinVLQ(kind: ChunkKind, j: StringJoiner, arena: Allocator, side: Side): Unit {
        let map_files = files.slice()
        let runtime: HmrRuntime = match (kind) {
            case initial_response => bake.getHmrRuntime(.client)
            case hmr_chunk => HmrRuntime.init("self[Symbol.for(\"bun:hmr\")]({\n")
        }

        var prev_end_state: SourceMapState = SourceMapState(
            generated_line: 0,
            generated_column: 0,
            source_index: 0,
            original_line: 0,
            original_column: 0,
        )

        var lines_between: UInt32 = runtime.line_count

        // 连接所有映射
        for (i in 0..map_files.length) {
            match (map_files.get(i)) {
                case some(let source_map) =>
                    let source_index = i + 1
                    let content = source_map.get()
                    lines_between = 0

                    SourceMap.appendSourceMapChunk(j, arena, prev_end_state, content.vlq())

                    prev_end_state = SourceMapState(
                        source_index: source_index,
                        generated_line: 0,
                        generated_column: 0,
                        original_line: content.end_state.original_line,
                        original_column: content.end_state.original_column,
                    )
                case line_count(let count) =>
                    lines_between += count.get()
                case none =>
                    () // 跳过没有行计数的条目
            }
        }
    }

    /// 析构
    public func deinit(): Unit {
        let files = files.slice()
        for (i in 0..files.length) {
            var file = files.get(i)
            file.deinit()
        }
        files.deinit(allocator())
        allocator().free(paths)
    }

    func allocator(): Allocator {
        return dev_allocator.allocator()
    }
}

/// 弱引用
public class WeakRef {
    /// 键的高 32 位
    public var key_top_bits: UInt32
    /// 过期时必须从 refs 减去的数量
    public var count: UInt32
    /// 自纪元以来的秒数
    public var expire: Int64

    /// 获取键
    public func key(): Key {
        return Key.init(UInt64(key_top_bits) << 32)
    }

    /// 初始化
    public static func initFunc(k: Key, count: UInt32, expire: Int64): WeakRef {
        return WeakRef(
            key_top_bits: Int32(k.get() >> 32),
            count: count,
            expire: expire,
        )
    }
}

/// 放入或增加引用计数
public func putOrIncrementRefCount(script_id: Key, ref_count: UInt32): PutOrIncrementRefCount {
    let gop = entries.getOrPut(allocator(), script_id)
    if (!gop.found_existing) {
        assert(ref_count > 0)
        gop.value_ptr = Entry(
            dev_allocator: dev_allocator(),
            ref_count: ref_count,
            overlapping_memory_cost: 0,
            paths: [],
            files: MultiArrayList<PackedMap.Shared>.empty,
        )
        return PutOrIncrementRefCount.uninitialized(gop.value_ptr)
    } else {
        gop.value_ptr.ref_count += ref_count
        return PutOrIncrementRefCount.shared(gop.value_ptr)
    }
}

/// 取消引用
public func unref(key: Key): Unit {
    unrefCount(key, 1)
}

/// 按数量取消引用
public func unrefCount(key: Key, count: UInt32): Unit {
    let index = entries.getIndex(key) ?? return
    unrefAtIndex(index, count)
}

/// 按索引取消引用
func unrefAtIndex(index: UInt64, count: UInt32): Unit {
    let e = entries.values()[index]
    e.ref_count -= count
    if (e.ref_count == 0) {
        e.deinit()
        entries.swapRemoveAt(index)
    }
}

/// 添加弱引用
public func addWeakRef(key: Key): Unit {
    let entry = entries.getPtr(key) ?? return
    entry.ref_count += 1

    var new_weak_ref_count: UInt32 = 1

    // 查找现有的弱引用
    for (i in 0..weak_refs.count) {
        let ref = weak_refs.peekItem(i)
        if (ref.key() == key) {
            new_weak_ref_count += ref.count
            weak_refs.orderedRemoveItem(i)
            break
        }
    }

    // 如果满了，过期一个
    if (weak_refs.count >= weak_ref_entry_max) {
        let first = weak_refs.readItem()
        unrefCount(first.key(), first.count)
    }

    let expire = bun.timespec.msFromNow(.allow_mocked_time, weak_ref_expiry_seconds * 1000)
    weak_refs.writeItem(WeakRef.init(key, new_weak_ref_count, expire.sec))

    if (weak_ref_sweep_timer.state != .ACTIVE) {
        owner().vm.timer.update(weak_ref_sweep_timer, expire)
    }
}

/// 移除或升级弱引用
public func removeOrUpgradeWeakRef(key: Key, mode: WeakRefMode): Bool {
    let entry = entries.getPtr(key) ?? return false
    for (i in 0..weak_refs.count) {
        let ref = weak_refs.peekItemMut(i)
        if (ref.key() == key) {
            ref.count -= 1
            if (mode == .remove) {
                unref(key)
            }
            if (ref.count == 0) {
                weak_refs.orderedRemoveItem(i)
            }
            break
        }
    }
    return true
}

/// 扫描弱引用
public static func sweepWeakRefs(timer: EventLoopTimer, now_ts: timespec): Unit {
    let store: SourceMapStore = fieldParentPtr(timer)
    let now: UInt64 = max(now_ts.sec, 0)

    while (let Some(item) = store.weak_refs.readItem()) {
        if (item.expire <= now) {
            store.unrefCount(item.key(), item.count)
        } else {
            store.weak_refs.unget(item)
            store.weak_ref_sweep_timer.state = .FIRED
            store.owner().vm.timer.update(store.weak_ref_sweep_timer, timespec(sec: item.expire + 1, nsec: 0))
            return
        }
    }
    store.weak_ref_sweep_timer.state = .CANCELLED
}

/// GetResult - 获取源映射的结果
public class GetResult {
    public var index: GenericIndex<UInt32, Entry>
    public var mappings: SourceMapMappingList
    public var file_paths: Array<String>
    public var entry_files: MultiArrayList<PackedMap.Shared>

    public func deinit(alloc: Allocator): Unit {
        mappings.deinit(alloc)
    }
}

/// 获取解析的源映射
public func getParsedSourceMap(script_id: Key, arena: Allocator, gpa: Allocator): ?GetResult {
    let index = entries.getIndex(script_id) ?? return None
    let entry = entries.values()[index]

    let vlq_bytes = entry.renderMappings(/* kind */, arena, arena)

    match (SourceMap.Mapping.parse(gpa, vlq_bytes, null, entry.paths.length, 0)) {
        case success(let psm) =>
            return GetResult(
                index: GenericIndex<UInt32, Entry>.init(index),
                mappings: psm.mappings,
                file_paths: entry.paths,
                entry_files: entry.files,
            )
        case fail(_) =>
            return None
    }
}

func owner(): DevServer {
    // 通过 fieldParentPtr 获取父 DevServer
}

func allocator(): Allocator {
    return owner().allocator()
}

func dev_allocator(): DevAllocator {
    return owner().dev_allocator()
}
}

public class SourceMapStore {
    /// Key - 源映射键类型

    public var entries: AutoArrayHashMapUnmanaged<Key, Entry>
    /// 当 HTML bundle 加载时，它放置一个"弱引用"到脚本的源映射
    public var weak_refs: LinearFifo<WeakRef>
    /// 共享的弱引用清理定时器
    public var weak_ref_sweep_timer: EventLoopTimer

    public static let empty: SourceMapStore = SourceMapStore(
        entries: AutoArrayHashMapUnmanaged<Key, Entry>.empty,
        weak_ref_sweep_timer: EventLoopTimer.initPaused(.DevServerSweepSourceMaps),
        weak_refs: LinearFifo<WeakRef>.init(),
    )

    /// 弱引用过期时间（秒）
    public static let weak_ref_expiry_seconds: UInt64 = 10
    /// 弱引用最大条目数
    public static let weak_ref_entry_max: UInt64 = 16

    /// SourceId - 源映射 ID 结构

    /// 源 ID 位

    /// 初始响应

    /// HMR chunk

    /// Entry - 源映射条目

/// 弱引用模式
public enum WeakRefMode {
    | remove     // 完全移除弱引用
    | upgrade    // 将弱引用转换为强引用
}

/// 放入或增加引用计数结果
public enum PutOrIncrementRefCount {
    | uninitialized(Entry)  // 需要初始化
    | shared(Entry)         // 已存在，引用计数已增加
}

// 类型别名
public type DevAllocator = dev_server.DevAllocator
public type PackedMap = dev_server.PackedMap
public type ChunkKind = dev_server.ChunkKind
public type EventLoopTimer = bun.api.Timer.EventLoopTimer
public type AutoArrayHashMapUnmanaged<K, V> = std.AutoArrayHashMapUnmanaged<K, V>
public type LinearFifo<T> = bun.LinearFifo<T>
public type MultiArrayList<T> = bun.MultiArrayList<T>
public type StringJoiner = bun.StringJoiner
public type Allocator = std.mem.Allocator
public type GenericIndex<T, P> = bun.GenericIndex<T, P>
public type SourceMapMappingList = bun.SourceMap.Mapping.List
public type SourceMapState = bun.SourceMap.SourceMapState
