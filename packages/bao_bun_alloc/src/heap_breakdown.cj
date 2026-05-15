// 严格翻译自: src/bun_alloc/heap_breakdown.zig
// heap_breakdown.cj - macOS 堆内存分区追踪
// 使用 macOS malloc_zone API 按类型追踪堆分配

package bao_bun_alloc

import bao_core.*

// ============================================================================
// HeapBreakdown - macOS 堆内存分区追踪
// 对应 Zig: src/bun_alloc/heap_breakdown.zig
// 仅在 macOS Debug 模式下启用 (Environment.allow_assert and Environment.isMac)
// ============================================================================

/// 是否启用堆分区
/// 对应 Zig: pub const enabled = Environment.allow_assert and Environment.isMac and !Environment.enable_asan
public let HEAP_BREAKDOWN_ENABLED: Bool = Environment.allowAssert && Environment.isMac && !Environment.enableAsan

/// 堆内存分区追踪
/// 对应 Zig: 整个 heap_breakdown.zig 模块
/// 使用 macOS malloc_zone API 为每种类型创建独立的堆区域
public class HeapBreakdown {

    /// 获取类型 T 的堆标签名
    /// 对应 Zig: fn heapLabel(comptime T: type) [:0]const u8
    public static func heapLabel<T>(): String {
        return TypeInfo.shortName<T>()
    }

    /// 获取类型 T 的分配器
    /// 对应 Zig: pub fn allocator(comptime T: type) std.mem.Allocator
    public static func allocator<T>(): Allocator {
        return namedAllocator(heapLabel<T>())
    }

    /// 通过名称获取分配器
    /// 对应 Zig: pub fn namedAllocator(comptime name: [:0]const u8) std.mem.Allocator
    public static func namedAllocator(name: String): Allocator {
        return getZone("Bun__${name}").allocator()
    }

    /// 获取类型 T 的分区
    /// 对应 Zig: pub fn getZoneT(comptime T: type) *Zone
    public static func getZoneT<T>(): Zone {
        return getZone(heapLabel<T>())
    }

    /// 获取或创建命名分区
    /// 对应 Zig: pub fn getZone(comptime name: [:0]const u8) *Zone
    public static func getZone(name: String): Zone {
        Assert.assert(HEAP_BREAKDOWN_ENABLED)
        return Zone.getOrCreate(name)
    }
}

// ============================================================================
// Zone - macOS malloc_zone 封装
// 对应 Zig: pub const Zone = opaque { ... }
// ============================================================================

/// macOS malloc_zone 封装
/// 对应 Zig: Zone (opaque 类型)
public class Zone {
    /// 区域名称
    private var name: String
    /// 底层 malloc_zone 指针
    private var zonePtr: CPointer<Byte>

    /// 缓存已创建的分区
    private static var zoneCache: HashMap<String, Zone> = HashMap<String, Zone>()

    public init(name: String) {
        this.name = name
        this.zonePtr = CPointer<Byte>.null()
    }

    /// 初始化分区
    /// 对应 Zig: pub fn init(comptime name: [:0]const u8) *Zone
    public static func init(name: String): Zone {
        let zone = Zone(name: name)
        // 调用 malloc_create_zone 创建区域
        zone.zonePtr = MallocZoneFFI.mallocCreateZone(0, 0)
        // 设置区域名称
        MallocZoneFFI.mallocSetZoneName(zone.zonePtr, name)
        return zone
    }

    /// 获取或创建分区 (延迟初始化)
    /// 对应 Zig: comptime 中使用 std.once 实现的延迟初始化
    public static func getOrCreate(name: String): Zone {
        if (let existing = zoneCache.get(name)) {
            return existing
        }
        let zone = init(name)
        zoneCache.put(name, zone)
        return zone
    }

    /// 对齐分配
    /// 对应 Zig: fn alignedAlloc(zone: *Zone, len: usize, alignment: std.mem.Alignment) ?[*]u8
    public func alignedAlloc(len: UInt64, alignment: Alignment): ?Array<Byte> {
        // posix_memalign 只接受指针大小倍数的对齐值
        let effAlignment = Math.max(alignment.toByteUnits(), UInt64(SizeOf.USIZE))
        let ptr = MallocZoneFFI.mallocZoneMemalign(this.zonePtr, effAlignment, len)
        if (ptr == CPointer<Byte>.null()) {
            return None
        }
        return Array<Byte>.fromPointer(ptr, Int64(len))
    }

    /// 获取对齐分配大小
    /// 对应 Zig: fn alignedAllocSize(ptr: [*]u8) usize
    public static func alignedAllocSize(ptr: Array<Byte>): UInt64 {
        return MallocZoneFFI.mallocSize(CPointer<Byte>.fromArray(ptr))
    }

    /// 原始分配
    /// 对应 Zig: fn rawAlloc(zone: *anyopaque, len: usize, alignment: std.mem.Alignment, _: usize) ?[*]u8
    public func rawAlloc(len: UInt64, alignment: Alignment, retAddr: UInt64): ?Array<Byte> {
        return this.alignedAlloc(len, alignment)
    }

    /// 调整大小
    /// 对应 Zig: fn resize(...) bool
    public func resize(buf: Array<Byte>, alignment: Alignment, newLen: UInt64, retAddr: UInt64): Bool {
        if (newLen <= UInt64(buf.size)) {
            return true
        }

        let fullLen = alignedAllocSize(buf)
        if (newLen <= fullLen) {
            return true
        }

        return false
    }

    /// 释放
    /// 对应 Zig: fn rawFree(zone: *anyopaque, buf: []u8, _: std.mem.Alignment, _: usize) void
    public func rawFree(buf: Array<Byte>, alignment: Alignment, retAddr: UInt64): Unit {
        MallocZoneFFI.mallocZoneFree(this.zonePtr, CPointer<Byte>.fromArray(buf))
    }

    /// 获取分配器接口
    /// 对应 Zig: pub fn allocator(zone: *Zone) std.mem.Allocator
    public func allocator(): Allocator {
        return Allocator.fromContext(
            CPointer<Byte>.fromObject(this),
            ZoneVTable.get()
        )
    }

    /// 创建单项指针并初始化数据
    /// 对应 Zig: pub inline fn create(zone: *Zone, comptime T: type, data: T) *T
    public func create<T>(data: T): ?CPointer<T> {
        let size = UInt64(SizeOf.size<T>())
        let align_ = UInt64(SizeOf.align<T>())
        let alignment = Alignment.fromByteUnits(align_)
        let ptr = this.rawAlloc(size, alignment, 0)
        if (ptr == None) {
            return None
        }
        // 将数据写入分配的内存
        let bytes = ptr.getOrThrow()
        MemoryUtils.write(bytes, data)
        return CPointer<T>.fromArray(bytes)
    }

    /// 释放单项指针
    /// 对应 Zig: pub inline fn destroy(zone: *Zone, comptime T: type, ptr: *T) void
    public func destroy<T>(ptr: CPointer<T>): Unit {
        MallocZoneFFI.mallocZoneFree(this.zonePtr, CPointer<Byte>.fromTypedPointer(ptr))
    }

    /// 检查给定分配器是否为 Zone 实例
    /// 对应 Zig: pub fn isInstance(allocator_: std.mem.Allocator) bool
    public static func isInstance(allocator: Allocator): Bool {
        return allocator.getBackend() == AllocatorBackend.heapZone
    }
}

// ============================================================================
// ZoneVTable - Zone 虚表
// 对应 Zig: pub const vtable = std.mem.Allocator.VTable{ ... }
// ============================================================================

/// Zone 虚表
public class ZoneVTable {
    private static let instance: ZoneVTable = ZoneVTable()

    public static func get(): ZoneVTable {
        return instance
    }

    /// 虚表分配
    public static func vtableAlloc(ctx: CPointer<Byte>, len: UInt64, alignment: Alignment, retAddr: UInt64): ?Array<Byte> {
        let zone: Zone = Zone.fromPointer(ctx)
        return zone.rawAlloc(len, alignment, retAddr)
    }

    /// 虚表 resize
    public static func vtableResize(ctx: CPointer<Byte>, buf: Array<Byte>, alignment: Alignment, newLen: UInt64, retAddr: UInt64): Bool {
        let zone: Zone = Zone.fromPointer(ctx)
        return zone.resize(buf, alignment, newLen, retAddr)
    }

    /// 虚表 free
    public static func vtableFree(ctx: CPointer<Byte>, buf: Array<Byte>, alignment: Alignment, retAddr: UInt64): Unit {
        let zone: Zone = Zone.fromPointer(ctx)
        zone.rawFree(buf, alignment, retAddr)
    }
}

// ============================================================================
// MallocZoneFFI - macOS malloc_zone FFI 声明
// 对应 Zig: Zone 内的 pub extern fn 声明
// ============================================================================

/// macOS malloc_zone FFI 互操作
/// 对应 Zig 中 Zone 结构体内的 extern 函数声明
public class MallocZoneFFI {
    /// malloc_default_zone
    /// 对应 Zig: pub extern fn malloc_default_zone() *Zone
    public static func mallocDefaultZone(): CPointer<Byte> {
        return ForeignFunc.malloc_default_zone()
    }

    /// malloc_create_zone
    /// 对应 Zig: pub extern fn malloc_create_zone(start_size: vm_size_t, flags: c_uint) *Zone
    public static func mallocCreateZone(startSize: UInt64, flags: UInt32): CPointer<Byte> {
        return ForeignFunc.malloc_create_zone(startSize, flags)
    }

    /// malloc_destroy_zone
    /// 对应 Zig: pub extern fn malloc_destroy_zone(zone: *Zone) void
    public static func mallocDestroyZone(zone: CPointer<Byte>): Unit {
        ForeignFunc.malloc_destroy_zone(zone)
    }

    /// malloc_zone_malloc
    /// 对应 Zig: pub extern fn malloc_zone_malloc(zone: *Zone, size: usize) ?*anyopaque
    public static func mallocZoneMalloc(zone: CPointer<Byte>, size: UInt64): ?CPointer<Byte> {
        return ForeignFunc.malloc_zone_malloc(zone, size)
    }

    /// malloc_zone_calloc
    /// 对应 Zig: pub extern fn malloc_zone_calloc(zone: *Zone, num_items: usize, size: usize) ?*anyopaque
    public static func mallocZoneCalloc(zone: CPointer<Byte>, numItems: UInt64, size: UInt64): ?CPointer<Byte> {
        return ForeignFunc.malloc_zone_calloc(zone, numItems, size)
    }

    /// malloc_zone_valloc
    /// 对应 Zig: pub extern fn malloc_zone_valloc(zone: *Zone, size: usize) ?*anyopaque
    public static func mallocZoneValloc(zone: CPointer<Byte>, size: UInt64): ?CPointer<Byte> {
        return ForeignFunc.malloc_zone_valloc(zone, size)
    }

    /// malloc_zone_free
    /// 对应 Zig: pub extern fn malloc_zone_free(zone: *Zone, ptr: ?*anyopaque) void
    public static func mallocZoneFree(zone: CPointer<Byte>, ptr: CPointer<Byte>): Unit {
        ForeignFunc.malloc_zone_free(zone, ptr)
    }

    /// malloc_zone_realloc
    /// 对应 Zig: pub extern fn malloc_zone_realloc(zone: *Zone, ptr: ?*anyopaque, size: usize) ?*anyopaque
    public static func mallocZoneRealloc(zone: CPointer<Byte>, ptr: CPointer<Byte>, size: UInt64): ?CPointer<Byte> {
        return ForeignFunc.malloc_zone_realloc(zone, ptr, size)
    }

    /// malloc_zone_from_ptr
    /// 对应 Zig: pub extern fn malloc_zone_from_ptr(ptr: ?*const anyopaque) *Zone
    public static func mallocZoneFromPtr(ptr: CPointer<Byte>): CPointer<Byte> {
        return ForeignFunc.malloc_zone_from_ptr(ptr)
    }

    /// malloc_zone_memalign
    /// 对应 Zig: pub extern fn malloc_zone_memalign(zone: *Zone, alignment: usize, size: usize) ?*anyopaque
    public static func mallocZoneMemalign(zone: CPointer<Byte>, alignment: UInt64, size: UInt64): ?CPointer<Byte> {
        return ForeignFunc.malloc_zone_memalign(zone, alignment, size)
    }

    /// malloc_zone_batch_malloc
    /// 对应 Zig: pub extern fn malloc_zone_batch_malloc(...) c_uint
    public static func mallocZoneBatchMalloc(zone: CPointer<Byte>, size: UInt64, results: Array<CPointer<Byte>>, numRequested: UInt32): UInt32 {
        return ForeignFunc.malloc_zone_batch_malloc(zone, size, results, numRequested)
    }

    /// malloc_zone_batch_free
    /// 对应 Zig: pub extern fn malloc_zone_batch_free(...) void
    public static func mallocZoneBatchFree(zone: CPointer<Byte>, toBeFreed: Array<CPointer<Byte>>, num: UInt32): Unit {
        ForeignFunc.malloc_zone_batch_free(zone, toBeFreed, num)
    }

    /// malloc_default_purgeable_zone
    /// 对应 Zig: pub extern fn malloc_default_purgeable_zone() *Zone
    public static func mallocDefaultPurgeableZone(): CPointer<Byte> {
        return ForeignFunc.malloc_default_purgeable_zone()
    }

    /// malloc_make_purgeable
    /// 对应 Zig: pub extern fn malloc_make_purgeable(ptr: ?*anyopaque) void
    public static func mallocMakePurgeable(ptr: CPointer<Byte>): Unit {
        ForeignFunc.malloc_make_purgeable(ptr)
    }

    /// malloc_make_nonpurgeable
    /// 对应 Zig: pub extern fn malloc_make_nonpurgeable(ptr: ?*anyopaque) c_int
    public static func mallocMakeNonpurgeable(ptr: CPointer<Byte>): Int32 {
        return ForeignFunc.malloc_make_nonpurgeable(ptr)
    }

    /// malloc_zone_register
    /// 对应 Zig: pub extern fn malloc_zone_register(zone: *Zone) void
    public static func mallocZoneRegister(zone: CPointer<Byte>): Unit {
        ForeignFunc.malloc_zone_register(zone)
    }

    /// malloc_zone_unregister
    /// 对应 Zig: pub extern fn malloc_zone_unregister(zone: *Zone) void
    public static func mallocZoneUnregister(zone: CPointer<Byte>): Unit {
        ForeignFunc.malloc_zone_unregister(zone)
    }

    /// malloc_set_zone_name
    /// 对应 Zig: pub extern fn malloc_set_zone_name(zone: *Zone, name: ?[*:0]const u8) void
    public static func mallocSetZoneName(zone: CPointer<Byte>, name: String): Unit {
        ForeignFunc.malloc_set_zone_name(zone, name)
    }

    /// malloc_get_zone_name
    /// 对应 Zig: pub extern fn malloc_get_zone_name(zone: *Zone) ?[*:0]const u8
    public static func mallocGetZoneName(zone: CPointer<Byte>): String {
        return ForeignFunc.malloc_get_zone_name(zone)
    }

    /// malloc_zone_pressure_relief
    /// 对应 Zig: pub extern fn malloc_zone_pressure_relief(zone: *Zone, goal: usize) usize
    public static func mallocZonePressureRelief(zone: CPointer<Byte>, goal: UInt64): UInt64 {
        return ForeignFunc.malloc_zone_pressure_relief(zone, goal)
    }

    /// malloc_size
    /// 对应 Zig: 引用的 std.c.malloc_size
    public static func mallocSize(ptr: CPointer<Byte>): UInt64 {
        return ForeignFunc.malloc_size(ptr)
    }
}
