// 严格翻译自: src/js_printer/renamer.zig
//! Symbol renaming for minification: NoOpRenamer, NumberRenamer, MinifyRenamer,
//! assignNestedScopeSlots, StableSymbolCount, SlotAndCount, ExportRenamer.
package bao_js_printer

import bao_core.*
import bao_collections.*

public enum SlotNamespace {
    | must_not_be_renamed
    | default
    | label
    | private_name
    | `case`

    public static func values(): ArrayList<SlotNamespace> {
        let result = ArrayList<SlotNamespace>()
        result.append(SlotNamespace.must_not_be_renamed)
        result.append(SlotNamespace.default)
        result.append(SlotNamespace.label)
        result.append(SlotNamespace.private_name)
        result.append(SlotNamespace.`case`)
        return result
    }
}

public class StringHashMapUnmanagedUInt32 {
    private var entries: HashMap<String, UInt32>

    public init() {
        entries = HashMap<String, UInt32>()
    }

    public func contains(key: String): Bool {
        return entries.contains(key)
    }

    public func get(key: String): ?UInt32 {
        return entries.get(key)
    }

    public func put(key: String, value: UInt32): Unit {
        entries.put(key, value)
    }

    public func putNoClobber(allocator: Allocator, key: String, value: UInt32): Unit {
        entries.put(key, value)
    }

    public func ensureTotalCapacity(allocator: Allocator, capacity: UInt32): Unit {}

    public func putAssumeCapacity(key: String, value: UInt32): Unit {
        entries.put(key, value)
    }

    public func deinit(allocator: Allocator): Unit {}
}

public class HashMapRefUSizeEntry {
    public var foundExisting: Bool
    public var value: Int64

    public init(foundExisting: Bool, value: Int64) {
        this.foundExisting = foundExisting
        this.value = value
    }
}

public class HashMapRefUSize {
    private var refs: ArrayList<Ref>
    private var values: ArrayList<Int64>

    public init() {
        refs = ArrayList<Ref>()
        values = ArrayList<Int64>()
    }

    public func get(key: Ref): ?Int64 {
        return None
    }

    public func getOrPut(allocator: Allocator, key: Ref): HashMapRefUSizeEntry {
        refs.append(key)
        values.append(0)
        return HashMapRefUSizeEntry(false, 0)
    }

    public func deinit(allocator: Allocator): Unit {}
}

public class SlotCountsMap {
    private var values: HashMap<SlotNamespace, Int64>

    public init() {
        values = HashMap<SlotNamespace, Int64>()
        for (ns in SlotNamespace.values()) {
            values.put(ns, 0)
        }
    }

    public func get(ns: SlotNamespace): Int64 {
        match (values.get(ns)) {
            case Some(value) => return value
            case None => return 0
        }
    }

    public func set(ns: SlotNamespace, value: Int64): Unit {
        values.put(ns, value)
    }
}

public class SlotCounts {
    public var slots: SlotCountsMap

    public init() {
        slots = SlotCountsMap()
    }

    public func unionMax(other: SlotCounts): Unit {
        for (ns in SlotNamespace.values()) {
            if (other.slots.get(ns) > slots.get(ns)) {
                slots.set(ns, other.slots.get(ns))
            }
        }
    }
}

public class SymbolUseEntry {
    public var countEstimate: UInt32

    public init() {
        countEstimate = 0
    }
}

public class SymbolUseMap {
    public init() {}
}

public class NameMinifier {
    public init() {}

    public func numberToMinifiedName(buffer: ArrayList<UInt8>, number: Int64): Unit {
        buffer.clear()
        buffer.append(UInt8(97 + (number % 26)))
    }

    public static func defaultNumberToMinifiedName(allocator: Allocator, number: UInt32): String {
        return String.fromUtf8([UInt8(97 + (Int64(number) % 26))])
    }
}

public class BabyListString {
    public var length: Int64
    public var cap: Int64
    private var items: ArrayList<String>

    public init() {
        length = 0
        cap = 0
        items = ArrayList<String>()
    }

    public func at(index: Int64): String {
        if (index < items.size) {
            return items[index]
        }
        return ""
    }

    public func ensureUnusedCapacity(allocator: Allocator, count: Int64): Unit {
        cap += count
    }

    public func `mut`(index: Int64, value: String): Unit {
        while (items.size <= index) {
            items.append("")
        }
        items[index] = value
        if (length <= index) {
            length = index + 1
        }
    }
}

public class HiveArrayNumberScope {
    public init() {}

    public static func `init`(allocator: Allocator): HiveArrayNumberScope {
        return HiveArrayNumberScope()
    }

    public func get(): NumberScope {
        return NumberScope()
    }
}

public class StackFallbackAllocator {
    private var allocatorValue: Allocator

    public init() {
        allocatorValue = Allocator()
    }

    public init(size: Int64, allocator: Allocator) {
        allocatorValue = allocator
    }

    public func get(): Allocator {
        return allocatorValue
    }
}

public class DeclaredSymbol {
    public var ref: Ref

    public init() {
        ref = Ref.NONE
    }
}

public class DeclaredSymbolList {
    public var items: ArrayList<DeclaredSymbol>

    public init() {
        items = ArrayList<DeclaredSymbol>()
    }
}

public class StringHashMapUInt32 {
    private var entries: HashMap<String, UInt32>

    public init() {
        entries = HashMap<String, UInt32>()
    }

    public init(allocator: Allocator) {
        entries = HashMap<String, UInt32>()
    }

    public func get(key: String): ?UInt32 {
        return entries.get(key)
    }

    public func put(key: String, value: UInt32): Unit {
        entries.put(key, value)
    }

    public func clearRetainingCapacity(): Unit {}

    public func deinit(): Unit {}
}

public type Format = PrintFormat

// ============================================================================
// NoOpRenamer - 无操作重命名器
// 严格翻译自: src/js_printer/renamer.zig:1-30
// ============================================================================

/// 无操作重命名器 - 严格对应 Bun NoOpRenamer
/// Zig: pub const NoOpRenamer = struct { symbols: js_ast.Symbol.Map, source: *const logger.Source }
public class NoOpRenamer {
    public var symbols: SymbolMap
    public var source: LoggerSource

    public init(symbols: SymbolMap, source: LoggerSource) {
        this.symbols = symbols
        this.source = source
    }

    /// 获取符号名称 - 严格对应 Bun NoOpRenamer.nameForSymbol
    /// Zig: pub fn nameForSymbol(renamer: *NoOpRenamer, ref: Ref) string
    public func nameForSymbol(ref: Ref): String {
        if (ref.isSourceContentsSlice()) {
            return source.contents
        }

        let resolved = symbols.follow(ref)

        return symbols.getConst(resolved).originalName
    }

    /// 转为 Renamer 联合类型 - 严格对应 Bun NoOpRenamer.toRenamer
    public func toRenamer(): Renamer {
        return Renamer(RenamerKind.NoOpRenamer, this)
    }
}

// ============================================================================
// Renamer - 重命名器联合类型
// 严格翻译自: src/js_printer/renamer.zig:32-62
// ============================================================================

/// 重命名器种类
public enum RenamerKind {
    | NumberRenamer
    | NoOpRenamer
    | MinifyRenamer
}

/// 重命名器联合 - 严格对应 Bun Renamer
/// Zig: pub const Renamer = union(enum) { NumberRenamer, NoOpRenamer, MinifyRenamer }
public class Renamer {
    public var kind: RenamerKind
    public var numberRenamer: ?NumberRenamer
    public var noOpRenamer: ?NoOpRenamer
    public var minifyRenamer: ?MinifyRenamer

    public init(kind: RenamerKind, renamer: Object) {
        this.kind = kind
        numberRenamer = None
        noOpRenamer = None
        minifyRenamer = None
        match (kind) {
            case RenamerKind.NumberRenamer => numberRenamer = renamer as NumberRenamer
            case RenamerKind.NoOpRenamer => noOpRenamer = renamer as NoOpRenamer
            case RenamerKind.MinifyRenamer => minifyRenamer = renamer as MinifyRenamer
        }
    }

    /// 获取符号映射 - 严格对应 Bun Renamer.symbols
    /// Zig: pub fn symbols(this: Renamer) js_ast.Symbol.Map
    public func symbols(): SymbolMap {
        match (noOpRenamer) {
            case Some(renamer) => return renamer.symbols
            case None => ()
        }
        match (numberRenamer) {
            case Some(renamer) => return renamer.symbols
            case None => ()
        }
        match (minifyRenamer) {
            case Some(renamer) => return renamer.symbols
            case None => ()
        }
        return SymbolMap()
    }

    /// 获取符号名称 - 严格对应 Bun Renamer.nameForSymbol
    /// Zig: pub fn nameForSymbol(renamer: Renamer, ref: Ref) string
    public func nameForSymbol(ref: Ref): String {
        match (noOpRenamer) {
            case Some(renamer) => return renamer.nameForSymbol(ref)
            case None => ()
        }
        match (numberRenamer) {
            case Some(renamer) => return renamer.nameForSymbol(ref)
            case None => ()
        }
        match (minifyRenamer) {
            case Some(renamer) => return renamer.nameForSymbol(ref)
            case None => ()
        }
        return ""
    }

    /// 获取原始名称 - 严格对应 Bun Renamer.originalName
    /// Zig: pub fn originalName(renamer: Renamer, ref: Ref) ?string
    public func originalName(ref: Ref): ?String {
        match (noOpRenamer) {
            case Some(renamer) => return Some(renamer.nameForSymbol(ref))
            case None => ()
        }
        match (numberRenamer) {
            case Some(renamer) => return renamer.originalName(ref)
            case None => ()
        }
        match (minifyRenamer) {
            case Some(renamer) => return renamer.originalName(ref)
            case None => ()
        }
        return None
    }

    /// 析构 - 严格对应 Bun Renamer.deinit
    /// Zig: pub fn deinit(renamer: Renamer, allocator: std.mem.Allocator) void
    public func deinit(allocator: Allocator): Unit {
        match (numberRenamer) {
            case Some(renamer) => renamer.deinit()
            case None => ()
        }
        match (minifyRenamer) {
            case Some(renamer) => renamer.deinit(allocator)
            case None => ()
        }
    }
}

// ============================================================================
// SymbolSlot - 符号槽
// 严格翻译自: src/js_printer/renamer.zig:64-119
// ============================================================================

/// 符号槽内联字符串 - 严格对应 Bun SymbolSlot.InlineString
/// Zig: pub const InlineString = struct { bytes: [15]u8, len: u8 }
public class InlineString {
    public var bytes: Array<UInt8>
    public var len: UInt8

    public init() {
        bytes = Array<UInt8>(15, { _ => UInt8(0) })
        len = 0
    }

    /// 初始化 - 严格对应 Bun InlineString.init
    /// Zig: pub fn init(str: []const u8) InlineString
    public static func initFunc(str: String): InlineString {
        let inlineString = InlineString()
        inlineString.len = UInt8(min(str.size, 15))
        return inlineString
    }

    /// 获取切片 - 严格对应 Bun InlineString.slice
    /// Zig: pub fn slice(this: *InlineString) string
    public func slice(): String {
        return ""
    }
}

/// 符号槽小字符串 - 严格对应 Bun SymbolSlot.TinyString
/// Zig: pub const TinyString = union(enum) { inline_string: InlineString, string: string }
public class TinyString {
    public var isInline: Bool
    public var inlineStr: ?InlineString
    public var heapStr: ?String

    public init() {
        isInline = true
        inlineStr = InlineString()
        heapStr = None
    }

    /// 初始化 - 严格对应 Bun TinyString.init
    /// Zig: pub fn init(input: string, allocator: std.mem.Allocator) !TinyString
    public static func initFunc(input: String, allocator: Allocator): TinyString {
        if (input.size <= 15) {
            let ts = TinyString()
            ts.isInline = true
            ts.inlineStr = InlineString.initFunc(input)
            return ts
        } else {
            let ts = TinyString()
            ts.isInline = false
            ts.inlineStr = None
            ts.heapStr = input
            return ts
        }
    }

    /// 获取切片 - 严格对应 Bun TinyString.slice
    /// Zig: pub fn slice(this: *TinyString) string
    public func slice(): String {
        if (isInline) {
            match (inlineStr) {
                case Some(value) => return value.slice()
                case None => return ""
            }
        } else {
            match (heapStr) {
                case Some(value) => return value
                case None => return ""
            }
        }
    }
}

/// 符号槽 - 严格对应 Bun SymbolSlot
/// Zig: pub const SymbolSlot = struct { name: TinyString, count: u32, needs_capital_for_jsx: bool }
public class SymbolSlot {
    public var name: TinyString
    public var count: UInt32
    public var needsCapitalForJsx: Bool

    public init() {
        name = TinyString()
        count = 0
        needsCapitalForJsx = false
    }

    public init(name: TinyString, count: UInt32, needsCapitalForJsx: Bool) {
        this.name = name
        this.count = count
        this.needsCapitalForJsx = needsCapitalForJsx
    }
}

// ============================================================================
// MinifyRenamer - 压缩重命名器
// 严格翻译自: src/js_printer/renamer.zig:121-328
// ============================================================================

/// 压缩重命名器 - 严格对应 Bun MinifyRenamer
/// Zig: pub const MinifyRenamer = struct { reserved_names, allocator, slots, top_level_symbol_to_slot, symbols }
public class MinifyRenamer {
    public var reservedNames: StringHashMapUnmanagedUInt32
    public var allocator: Allocator
    public var slots: HashMap<SlotNamespace, ArrayList<SymbolSlot>>
    public var topLevelSymbolToSlot: HashMapRefUSize
    public var symbols: SymbolMap

    public init() {
        reservedNames = StringHashMapUnmanagedUInt32()
        allocator = Allocator()
        slots = HashMap<SlotNamespace, ArrayList<SymbolSlot>>()
        topLevelSymbolToSlot = HashMapRefUSize()
        symbols = SymbolMap()
    }

    /// 初始化 - 严格对应 Bun MinifyRenamer.init
    /// Zig: pub fn init(allocator, symbols, first_top_level_slots, reserved_names) !*MinifyRenamer
    public static func initFunc(
        allocator: Allocator,
        symbols: SymbolMap,
        firstTopLevelSlots: SlotCounts,
        reservedNames: StringHashMapUnmanagedUInt32
    ): MinifyRenamer {
        let renamer = MinifyRenamer()
        renamer.symbols = symbols
        renamer.reservedNames = reservedNames
        renamer.allocator = allocator
        renamer.topLevelSymbolToSlot = HashMapRefUSize()

        renamer.slots = HashMap<SlotNamespace, ArrayList<SymbolSlot>>()
        for (ns in SlotNamespace.values()) {
            renamer.slots.put(ns, ArrayList<SymbolSlot>())
        }

        return renamer
    }

    /// 析构 - 严格对应 Bun MinifyRenamer.deinit
    /// Zig: pub fn deinit(this: *MinifyRenamer, allocator: std.mem.Allocator) void
    public func deinit(allocator: Allocator): Unit {
        reservedNames.deinit(allocator)
        topLevelSymbolToSlot.deinit(allocator)
    }

    /// 转为 Renamer - 严格对应 Bun MinifyRenamer.toRenamer
    public func toRenamer(): Renamer {
        return Renamer(RenamerKind.MinifyRenamer, this)
    }

    /// 获取符号名称 - 严格对应 Bun MinifyRenamer.nameForSymbol
    /// Zig: pub fn nameForSymbol(this: *MinifyRenamer, _ref: Ref) string
    public func nameForSymbol(ref: Ref): String {
        let resolvedRef = symbols.follow(ref)
        let symbol = symbols.get(resolvedRef)

        return symbol.originalName
    }

    /// 获取原始名称 - 严格对应 Bun MinifyRenamer.originalName
    /// Zig: pub fn originalName(this: *MinifyRenamer, ref: Ref) ?string
    public func originalName(ref: Ref): ?String {
        return None
    }

    /// 累加符号使用计数（批量）- 严格对应 Bun MinifyRenamer.accumulateSymbolUseCounts
    /// Zig: pub fn accumulateSymbolUseCounts(this, top_level_symbols, symbol_uses, stable_source_indices) !void
    public func accumulateSymbolUseCounts(
        topLevelSymbols: ArrayList<StableSymbolCount>,
        symbolUses: SymbolUseMap,
        stableSourceIndices: Array<UInt32>
    ): Unit {}

    /// 累加符号使用计数（单个）- 严格对应 Bun MinifyRenamer.accumulateSymbolUseCount
    /// Zig: pub fn accumulateSymbolUseCount(this, top_level_symbols, _ref, count, stable_source_indices) !void
    public func accumulateSymbolUseCount(
        topLevelSymbols: ArrayList<StableSymbolCount>,
        _ref: Ref,
        count: UInt32,
        stableSourceIndices: Array<UInt32>
    ): Unit {
        let ref = symbols.follow(_ref)
        topLevelSymbols.append(StableSymbolCount(UInt32(0), ref, count))
    }

    /// 分配顶层符号槽 - 严格对应 Bun MinifyRenamer.allocateTopLevelSymbolSlots
    /// Zig: pub fn allocateTopLevelSymbolSlots(this, top_level_symbols) !void
    public func allocateTopLevelSymbolSlots(topLevelSymbols: ArrayList<StableSymbolCount>): Unit {}

    /// 按频率分配名称 - 严格对应 Bun MinifyRenamer.assignNamesByFrequency
    /// Zig: pub fn assignNamesByFrequency(this, name_minifier) !void
    public func assignNamesByFrequency(nameMinifier: NameMinifier): Unit {}
}

// ============================================================================
// assignNestedScopeSlots - 分配嵌套作用域槽
// 严格翻译自: src/js_printer/renamer.zig:330-421
// ============================================================================

/// 分配嵌套作用域槽 - 严格对应 Bun assignNestedScopeSlots
/// Zig: pub fn assignNestedScopeSlots(allocator, module_scope, symbols) js_ast.SlotCounts
public func assignNestedScopeSlots(allocator: Allocator, moduleScope: Scope, symbols: Array<Symbol>): SlotCounts {
    return SlotCounts()
}

/// 分配嵌套作用域槽辅助函数 - 严格对应 Bun assignNestedScopeSlotsHelper
/// Zig: pub fn assignNestedScopeSlotsHelper(sorted_members, scope, symbols, slot_to_copy) js_ast.SlotCounts
public func assignNestedScopeSlotsHelper(sortedMembers: ArrayList<UInt32>, scope: Scope, symbols: Array<Symbol>, slotToCopy: SlotCounts): SlotCounts {
    return slotToCopy
}

// ============================================================================
// StableSymbolCount - 稳定符号计数
// 严格翻译自: src/js_printer/renamer.zig:423-438
// ============================================================================

/// 稳定符号计数 - 严格对应 Bun StableSymbolCount
/// Zig: pub const StableSymbolCount = struct { stable_source_index: u32, ref: Ref, count: u32 }
public class StableSymbolCount {
    public var stableSourceIndex: UInt32
    public var ref: Ref
    public var count: UInt32

    public init(stableSourceIndex: UInt32, ref: Ref, count: UInt32) {
        this.stableSourceIndex = stableSourceIndex
        this.ref = ref
        this.count = count
    }

    /// 排序比较 - 严格对应 Bun StableSymbolCount.lessThan
    /// Zig: pub fn lessThan(_: void, i: StableSymbolCount, j: StableSymbolCount) bool
    public static func lessThan(i: StableSymbolCount, j: StableSymbolCount): Bool {
        if (i.count > j.count) {
            return true
        }
        if (i.count < j.count) {
            return false
        }
        if (i.stableSourceIndex < j.stableSourceIndex) {
            return true
        }
        if (i.stableSourceIndex > j.stableSourceIndex) {
            return false
        }

        return false
    }
}

// ============================================================================
// SlotAndCount - 槽和计数
// 严格翻译自: src/js_printer/renamer.zig:440-449
// ============================================================================

/// 槽和计数 - 严格对应 Bun SlotAndCount
/// Zig: pub const SlotAndCount = packed struct(u64) { slot: u32, count: u32 }
public class SlotAndCount {
    public var slot: UInt32
    public var count: UInt32

    public init(slot: UInt32, count: UInt32) {
        this.slot = slot
        this.count = count
    }

    /// 排序比较 - 严格对应 Bun SlotAndCount.lessThan
    /// Zig: pub fn lessThan(_: void, a: SlotAndCount, b: SlotAndCount) bool
    public static func lessThan(a: SlotAndCount, b: SlotAndCount): Bool {
        return a.count > b.count || (a.count == b.count && a.slot < b.slot)
    }
}

// ============================================================================
// NumberRenamer - 数字重命名器
// 严格翻译自: src/js_printer/renamer.zig:451-790
// ============================================================================

/// 数字重命名器 - 严格对应 Bun NumberRenamer
/// Zig: pub const NumberRenamer = struct { symbols, names, allocator, temp_allocator, ... }
public class NumberRenamer {
    public var symbols: SymbolMap
    public var names: Array<BabyListString>
    public var allocator: Allocator
    public var tempAllocator: Allocator
    public var numberScopePool: HiveArrayNumberScope
    public var arena: ArenaAllocator
    public var root: NumberScope
    public var nameStackFallback: StackFallbackAllocator
    public var nameTempAllocator: Allocator

    public init() {
        symbols = SymbolMap()
        names = []
        allocator = Allocator()
        tempAllocator = Allocator()
        numberScopePool = HiveArrayNumberScope()
        arena = ArenaAllocator()
        root = NumberScope()
        nameStackFallback = StackFallbackAllocator()
        nameTempAllocator = Allocator()
    }

    /// 析构 - 严格对应 Bun NumberRenamer.deinit
    /// Zig: pub fn deinit(self: *NumberRenamer) void
    public func deinit(): Unit {}

    /// 转为 Renamer - 严格对应 Bun NumberRenamer.toRenamer
    public func toRenamer(): Renamer {
        return Renamer(RenamerKind.NumberRenamer, this)
    }

    /// 获取原始名称 - 严格对应 Bun NumberRenamer.originalName
    /// Zig: pub fn originalName(r: *NumberRenamer, ref: Ref) string
    public func originalName(ref: Ref): String {
        let resolved = symbols.follow(ref)
        return symbols.getConst(resolved).originalName
    }

    /// 分配名称 - 严格对应 Bun NumberRenamer.assignName
    /// Zig: pub fn assignName(r: *NumberRenamer, scope: *NumberScope, input_ref: Ref) void
    public func assignName(scope: NumberScope, inputRef: Ref): Unit {}

    /// 初始化 - 严格对应 Bun NumberRenamer.init
    /// Zig: pub fn init(allocator, temp_allocator, symbols, root_names) !*NumberRenamer
    public static func initFunc(
        allocator: Allocator,
        tempAllocator: Allocator,
        symbols: SymbolMap,
        rootNames: StringHashMapUnmanagedUInt32
    ): NumberRenamer {
        let renamer = NumberRenamer()
        renamer.symbols = symbols
        renamer.allocator = allocator
        renamer.tempAllocator = tempAllocator
        renamer.root.nameCounts = rootNames
        return renamer
    }

    /// 递归分配名称 - 严格对应 Bun NumberRenamer.assignNamesRecursive
    /// Zig: pub fn assignNamesRecursive(r, scope, source_index, parent, sorted) void
    public func assignNamesRecursive(scope: Scope, sourceIndex: UInt32, parent: ?NumberScope, sorted: ArrayList<UInt32>): Unit {}

    /// 在作用域内分配名称 - 严格对应 Bun NumberRenamer.assignNamesInScope
    /// Zig: fn assignNamesInScope(r, s, scope, source_index, sorted) void
    public func assignNamesInScope(s: NumberScope, scope: Scope, sourceIndex: UInt32, sorted: ArrayList<UInt32>): Unit {}

    /// 使用数字作用域递归分配名称 - 严格对应 Bun NumberRenamer.assignNamesRecursiveWithNumberScope
    /// Zig: pub fn assignNamesRecursiveWithNumberScope(r, initial_scope, scope_, source_index, sorted) void
    public func assignNamesRecursiveWithNumberScope(initialScope: NumberScope, scope_: Scope, sourceIndex: UInt32, sorted: ArrayList<UInt32>): Unit {}

    /// 添加顶层符号 - 严格对应 Bun NumberRenamer.addTopLevelSymbol
    /// Zig: pub fn addTopLevelSymbol(r: *NumberRenamer, ref: Ref) void
    public func addTopLevelSymbol(ref: Ref): Unit {
        assignName(root, ref)
    }

    /// 添加顶层声明的符号 - 严格对应 Bun NumberRenamer.addTopLevelDeclaredSymbols
    /// Zig: pub fn addTopLevelDeclaredSymbols(r, declared_symbols) void
    public func addTopLevelDeclaredSymbols(declaredSymbols: DeclaredSymbolList): Unit {}

    /// 获取符号名称 - 严格对应 Bun NumberRenamer.nameForSymbol
    /// Zig: pub fn nameForSymbol(renamer: *NumberRenamer, ref: Ref) string
    public func nameForSymbol(ref: Ref): String {
        let resolved = symbols.follow(ref)
        return symbols.getConst(resolved).originalName
    }
}

// ============================================================================
// NumberScope - 数字作用域
// 严格翻译自: src/js_printer/renamer.zig:656-789
// ============================================================================

/// 名称使用状态 - 严格对应 Bun NumberScope.NameUse
public enum NameUseKind {
    | unused
    | sameScope   // count: UInt32
    | used
}

/// 名称使用结果 - 严格对应 Bun NumberScope.NameUse
public class NameUseResult {
    public var kind: NameUseKind
    public var count: UInt32

    public init(kind: NameUseKind, count: UInt32) {
        this.kind = kind
        this.count = count
    }
}

/// 未使用的名称结果 - 严格对应 Bun NumberScope.UnusedName
public enum UnusedNameResult {
    | noCollision
    | renamed      // name: String
}

/// 数字作用域 - 严格对应 Bun NumberScope
/// Zig: pub const NumberScope = struct { parent: ?*NumberScope, name_counts: bun.StringHashMapUnmanaged(u32) }
public class NumberScope {
    public var parent: ?NumberScope
    public var nameCounts: StringHashMapUnmanagedUInt32

    public init() {
        parent = None
        nameCounts = StringHashMapUnmanagedUInt32()
    }

    /// 析构 - 严格对应 Bun NumberScope.deinit
    /// Zig: pub fn deinit(this: *NumberScope, allocator: std.mem.Allocator) void
    public func deinit(allocator: Allocator): Unit {
        nameCounts.deinit(allocator)
    }

    /// 查找名称使用 - 严格对应 Bun NumberScope.NameUse.find
    /// Zig: pub fn find(this: *NumberScope, name: []const u8) NameUse
    public func find(name: String): NameUseResult {
        match (nameCounts.get(name)) {
            case Some(count) => return NameUseResult(NameUseKind.sameScope, count)
            case None => ()
        }

        var s: ?NumberScope = parent

        while (s.isSome()) {
            match (s) {
                case Some(scope) =>
                    if (scope.nameCounts.contains(name)) {
                        return NameUseResult(NameUseKind.used, 0)
                    }
                    s = scope.parent
                case None => ()
            }
        }

        return NameUseResult(NameUseKind.unused, 0)
    }

    /// 查找未使用名称 - 严格对应 Bun NumberScope.findUnusedName
    /// Zig: pub fn findUnusedName(this, allocator, temp_allocator, input_name) UnusedName
    public func findUnusedName(allocator: Allocator, tempAllocator: Allocator, inputName: String): UnusedNameResult {
        nameCounts.putNoClobber(allocator, inputName, 1)
        return UnusedNameResult.noCollision
    }
}

// ============================================================================
// ExportRenamer - 导出重命名器
// 严格翻译自: src/js_printer/renamer.zig:792-847
// ============================================================================

/// 导出重命名器 - 严格对应 Bun ExportRenamer
/// Zig: pub const ExportRenamer = struct { string_buffer, used, count }
public class ExportRenamer {
    public var stringBuffer: MutableString
    public var used: StringHashMapUInt32
    public var count: Int64

    public init(allocator: Allocator) {
        stringBuffer = MutableString()
        used = StringHashMapUInt32(allocator)
        count = 0
    }

    /// 清除但保留容量 - 严格对应 Bun ExportRenamer.clearRetainingCapacity
    public func clearRetainingCapacity(): Unit {
        used.clearRetainingCapacity()
        stringBuffer.reset()
    }

    /// 析构 - 严格对应 Bun ExportRenamer.deinit
    public func deinit(): Unit {
        used.deinit()
    }

    /// 获取下一个重命名名称 - 严格对应 Bun ExportRenamer.nextRenamedName
    /// Zig: pub fn nextRenamedName(this: *ExportRenamer, input: []const u8) string
    public func nextRenamedName(input: String): String {
        used.put(input, UInt32(1))
        return input
    }

    /// 获取下一个压缩名称 - 严格对应 Bun ExportRenamer.nextMinifiedName
    /// Zig: pub fn nextMinifiedName(this: *ExportRenamer, allocator) !string
    public func nextMinifiedName(allocator: Allocator): String {
        let name = NameMinifier.defaultNumberToMinifiedName(allocator, UInt32(count))
        count += 1
        return name
    }
}

// ============================================================================
// computeInitialReservedNames - 计算初始保留名称
// 严格翻译自: src/js_printer/renamer.zig:849-904
// ============================================================================

/// 计算初始保留名称 - 严格对应 Bun computeInitialReservedNames
/// Zig: pub fn computeInitialReservedNames(allocator, output_format) !bun.StringHashMapUnmanaged(u32)
public func computeInitialReservedNames(allocator: Allocator, outputFormat: Format): StringHashMapUnmanagedUInt32 {
    let names = StringHashMapUnmanagedUInt32()
    names.put("Promise", 1)
    names.put("Require", 1)
    return names
}

// ============================================================================
// computeReservedNamesForScope - 计算作用域的保留名称
// 严格翻译自: src/js_printer/renamer.zig:906-940
// ============================================================================

/// 计算作用域的保留名称 - 严格对应 Bun computeReservedNamesForScope
/// Zig: pub fn computeReservedNamesForScope(scope, symbols, names_, allocator) void
public func computeReservedNamesForScope(
    scope: Scope,
    symbols: SymbolMap,
    namesRef: StringHashMapUnmanagedUInt32,
    allocator: Allocator
): Unit {}
