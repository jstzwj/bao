// 严格翻译自: src/js_printer/renamer.zig
//! Symbol renaming for minification: NoOpRenamer, NumberRenamer, MinifyRenamer,
//! assignNestedScopeSlots, StableSymbolCount, SlotAndCount, ExportRenamer.
package bao_parser

import bao_core.*
import bao_collections.*

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

    /// 获取原始名称 - 严格对应 Bun NoOpRenamer.originalName
    public static let originalName = nameForSymbol

    /// 获取符号名称 - 严格对应 Bun NoOpRenamer.nameForSymbol
    /// Zig: pub fn nameForSymbol(renamer: *NoOpRenamer, ref: Ref) string
    public func nameForSymbol(ref: Ref): String {
        if (ref.isSourceContentsSlice()) {
            return source.contents[ref.sourceIndex()..(ref.sourceIndex() + ref.innerIndex())]
        }

        let resolved = symbols.follow(ref)

        if (let symbol = symbols.getConst(resolved)) {
            return symbol.originalName
        } else {
            Output.panic("Invalid symbol ${ref} in ${source.path.text}")
            return ""
        }
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
        return match (kind) {
            case RenamerKind.NumberRenamer => numberRenamer.symbols
            case RenamerKind.NoOpRenamer => noOpRenamer.symbols
            case RenamerKind.MinifyRenamer => minifyRenamer.symbols
        }
    }

    /// 获取符号名称 - 严格对应 Bun Renamer.nameForSymbol
    /// Zig: pub fn nameForSymbol(renamer: Renamer, ref: Ref) string
    public func nameForSymbol(ref: Ref): String {
        return match (kind) {
            case RenamerKind.NumberRenamer => numberRenamer.nameForSymbol(ref)
            case RenamerKind.NoOpRenamer => noOpRenamer.nameForSymbol(ref)
            case RenamerKind.MinifyRenamer => minifyRenamer.nameForSymbol(ref)
        }
    }

    /// 获取原始名称 - 严格对应 Bun Renamer.originalName
    /// Zig: pub fn originalName(renamer: Renamer, ref: Ref) ?string
    public func originalName(ref: Ref): ?String {
        return match (kind) {
            case RenamerKind.NumberRenamer => numberRenamer.originalName(ref)
            case RenamerKind.NoOpRenamer => noOpRenamer.originalName(ref)
            case RenamerKind.MinifyRenamer => minifyRenamer.originalName(ref)
        }
    }

    /// 析构 - 严格对应 Bun Renamer.deinit
    /// Zig: pub fn deinit(renamer: Renamer, allocator: std.mem.Allocator) void
    public func deinit(allocator: Allocator): Unit {
        match (kind) {
            case RenamerKind.NumberRenamer => numberRenamer.deinit()
            case RenamerKind.MinifyRenamer => minifyRenamer.deinit(allocator)
            default =>
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
        bytes = Array<UInt8>(15, item: 0)
        len = 0
    }

    /// 初始化 - 严格对应 Bun InlineString.init
    /// Zig: pub fn init(str: []const u8) InlineString
    public static func init(str: String): InlineString {
        let this = InlineString()
        this.len = UInt8(min(str.length, 15))
        for (i in 0..this.len) {
            this.bytes[i] = UInt8(str[i])
        }
        return this
    }

    /// 获取切片 - 严格对应 Bun InlineString.slice
    /// Zig: pub fn slice(this: *InlineString) string
    public func slice(): String {
        return String.fromUtf8(bytes[0..len])
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
    public static func init(input: String, allocator: Allocator): TinyString {
        if (input.length <= 15) {
            let ts = TinyString()
            ts.isInline = true
            ts.inlineStr = InlineString.init(input)
            return ts
        } else {
            let ts = TinyString()
            ts.isInline = false
            ts.inlineStr = None
            ts.heapStr = allocator.dupe(input)
            return ts
        }
    }

    /// 获取切片 - 严格对应 Bun TinyString.slice
    /// Zig: pub fn slice(this: *TinyString) string
    public func slice(): String {
        if (isInline) {
            return inlineStr.slice()
        } else {
            return heapStr ?? ""
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
        allocator = Allocator.default
        slots = HashMap<SlotNamespace, ArrayList<SymbolSlot>>()
        topLevelSymbolToSlot = HashMapRefUSize()
        symbols = SymbolMap()
    }

    /// 初始化 - 严格对应 Bun MinifyRenamer.init
    /// Zig: pub fn init(allocator, symbols, first_top_level_slots, reserved_names) !*MinifyRenamer
    public static func init(
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

        // 初始化 slots
        renamer.slots = HashMap<SlotNamespace, ArrayList<SymbolSlot>>()
        for (ns in SlotNamespace.values()) {
            let count = firstTopLevelSlots.slots.get(ns)
            let slotList = ArrayList<SymbolSlot>(count, item: SymbolSlot())
            renamer.slots.put(ns, slotList)
        }

        return renamer
    }

    /// 析构 - 严格对应 Bun MinifyRenamer.deinit
    /// Zig: pub fn deinit(this: *MinifyRenamer, allocator: std.mem.Allocator) void
    public func deinit(allocator: Allocator): Unit {
        for ((ns, val) in slots) {
            // slots 内的列表由 allocator 管理
        }
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

        let ns = symbol.slotNamespace()
        if (ns == SlotNamespace.must_not_be_renamed) {
            return symbol.originalName
        }

        let i = symbol.nestedScopeSlot() ?? topLevelSymbolToSlot.get(resolvedRef) ?? return symbol.originalName

        let slotList = slots.get(ns)
        return slotList[i].name.slice()
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
    ): Unit {
        for ((key, value) in symbolUses) {
            accumulateSymbolUseCount(topLevelSymbols, key, value.countEstimate, stableSourceIndices)
        }
    }

    /// 累加符号使用计数（单个）- 严格对应 Bun MinifyRenamer.accumulateSymbolUseCount
    /// Zig: pub fn accumulateSymbolUseCount(this, top_level_symbols, _ref, count, stable_source_indices) !void
    public func accumulateSymbolUseCount(
        topLevelSymbols: ArrayList<StableSymbolCount>,
        _ref: Ref,
        count: UInt32,
        stableSourceIndices: Array<UInt32>
    ): Unit {
        var ref = symbols.follow(_ref)
        var symbol = symbols.get(ref)

        while (symbol.namespaceAlias != None) {
            let ref_ = symbols.follow(symbol.namespaceAlias.namespaceRef)
            if (ref_.eql(ref)) {
                break
            }
            ref = ref_
            symbol = symbols.get(ref_)
        }

        let ns = symbol.slotNamespace()
        if (ns == SlotNamespace.must_not_be_renamed) {
            return
        }

        if (let i = symbol.nestedScopeSlot()) {
            let slotList = slots.get(ns)
            slotList[i].count += count
            if (symbol.mustStartWithCapitalLetterForJsx) {
                slotList[i].needsCapitalForJsx = true
            }
            return
        }

        topLevelSymbols.append(StableSymbolCount(
            stableSourceIndex: stableSourceIndices[ref.sourceIndex()],
            ref: ref,
            count: count
        ))
    }

    /// 分配顶层符号槽 - 严格对应 Bun MinifyRenamer.allocateTopLevelSymbolSlots
    /// Zig: pub fn allocateTopLevelSymbolSlots(this, top_level_symbols) !void
    public func allocateTopLevelSymbolSlots(topLevelSymbols: ArrayList<StableSymbolCount>): Unit {
        for (stable in topLevelSymbols) {
            let symbol = symbols.get(stable.ref)
            var slotList = slots.get(symbol.slotNamespace())

            let existing = topLevelSymbolToSlot.getOrPut(allocator, stable.ref)
            if (existing.foundExisting) {
                slotList[existing.value].count += stable.count
                if (symbol.mustStartWithCapitalLetterForJsx) {
                    slotList[existing.value].needsCapitalForJsx = true
                }
            } else {
                existing.value = slotList.length
                slotList.append(SymbolSlot(
                    name: TinyString(),
                    count: stable.count,
                    needsCapitalForJsx: symbol.mustStartWithCapitalLetterForJsx
                ))
            }
        }
    }

    /// 按频率分配名称 - 严格对应 Bun MinifyRenamer.assignNamesByFrequency
    /// Zig: pub fn assignNamesByFrequency(this, name_minifier) !void
    public func assignNamesByFrequency(nameMinifier: NameMinifier): Unit {
        var nameBuf = ArrayList<UInt8>()
        nameBuf.capacity = 64

        var sorted = ArrayList<SlotAndCount>()

        for (ns in SlotNamespace.values()) {
            var slotList = slots.get(ns)
            sorted.clear()

            // 填充 sorted
            for (i in 0..slotList.length) {
                sorted.append(SlotAndCount(
                    slot: UInt32(i),
                    count: slotList[i].count
                ))
            }

            // 按频率排序
            sorted.sort(SlotAndCount.lessThan)

            var nextName: Int64 = 0

            for (data in sorted) {
                var slot = slotList[data.slot]

                nameMinifier.numberToMinifiedName(nameBuf, nextName)
                nextName += 1

                // 确保不生成保留名称
                match (ns) {
                    case SlotNamespace.default =>
                        while (reservedNames.contains(nameBuf)) {
                            nameMinifier.numberToMinifiedName(nameBuf, nextName)
                            nextName += 1
                        }

                        if (slot.needsCapitalForJsx) {
                            while (nameBuf[0] >= 'a' && nameBuf[0] <= 'z') {
                                nameMinifier.numberToMinifiedName(nameBuf, nextName)
                                nextName += 1
                            }
                        }
                    case SlotNamespace.label =>
                        while (Lexer.isKeyword(nameBuf)) {
                            nameMinifier.numberToMinifiedName(nameBuf, nextName)
                            nextName += 1
                        }
                    case SlotNamespace.private_name =>
                        nameBuf.insert(0, UInt8('#'))
                    default =>
                }

                slot.name = TinyString.init(String.fromUtf8(nameBuf), allocator)
            }
        }
    }
}

// ============================================================================
// assignNestedScopeSlots - 分配嵌套作用域槽
// 严格翻译自: src/js_printer/renamer.zig:330-421
// ============================================================================

/// 分配嵌套作用域槽 - 严格对应 Bun assignNestedScopeSlots
/// Zig: pub fn assignNestedScopeSlots(allocator, module_scope, symbols) js_ast.SlotCounts
public func assignNestedScopeSlots(allocator: Allocator, moduleScope: Scope, symbols: Array<Symbol>): SlotCounts {
    var slotCounts = SlotCounts()
    var sortedMembers = ArrayList<UInt32>()

    // 临时将顶层符号的嵌套作用域槽设为有效值，防止在嵌套作用域中被重命名
    let validSlot: UInt32 = 0
    for (member in moduleScope.members.values()) {
        symbols[member.ref.innerIndex()].nestedScopeSlot = validSlot
    }
    for (ref in moduleScope.generated.slice()) {
        symbols[ref.innerIndex()].nestedScopeSlot = validSlot
    }

    for (child in moduleScope.children.slice()) {
        slotCounts.unionMax(assignNestedScopeSlotsHelper(sortedMembers, child, symbols, SlotCounts()))
    }

    // 将顶层符号的嵌套作用域槽重置为无效
    for (member in moduleScope.members.values()) {
        symbols[member.ref.innerIndex()].nestedScopeSlot = Symbol.INVALID_NESTED_SCOPE_SLOT
    }
    for (ref in moduleScope.generated.slice()) {
        symbols[ref.innerIndex()].nestedScopeSlot = Symbol.INVALID_NESTED_SCOPE_SLOT
    }

    return slotCounts
}

/// 分配嵌套作用域槽辅助函数 - 严格对应 Bun assignNestedScopeSlotsHelper
/// Zig: pub fn assignNestedScopeSlotsHelper(sorted_members, scope, symbols, slot_to_copy) js_ast.SlotCounts
public func assignNestedScopeSlotsHelper(sortedMembers: ArrayList<UInt32>, scope: Scope, symbols: Array<Symbol>, slotToCopy: SlotCounts): SlotCounts {
    var slot = slotToCopy

    // 排序成员映射键以确保确定性
    sortedMembers.clear()
    for (member in scope.members.values()) {
        sortedMembers.append(member.ref.innerIndex())
    }
    sortedMembers.sort()

    // 为此作用域的符号分配槽
    for (innerIndex in sortedMembers) {
        let symbol = symbols[innerIndex]
        let ns = symbol.slotNamespace()
        if (ns != SlotNamespace.must_not_be_renamed && symbol.nestedScopeSlot() == None) {
            symbol.nestedScopeSlot = slot.slots.get(ns)
            slot.slots.set(ns, slot.slots.get(ns) + 1)
        }
    }

    for (ref in scope.generated.slice()) {
        let symbol = symbols[ref.innerIndex()]
        let ns = symbol.slotNamespace()
        if (ns != SlotNamespace.must_not_be_renamed && symbol.nestedScopeSlot() == None) {
            symbol.nestedScopeSlot = slot.slots.get(ns)
            slot.slots.set(ns, slot.slots.get(ns) + 1)
        }
    }

    // 标签总是在嵌套作用域中声明
    if (let ref = scope.labelRef) {
        let symbol = symbols[ref.innerIndex()]
        let ns = SlotNamespace.label
        symbol.nestedScopeSlot = slot.slots.get(ns)
        slot.slots.set(ns, slot.slots.get(ns) + 1)
    }

    // 为子作用域的符号分配槽
    var slotCounts = slot
    for (child in scope.children.slice()) {
        slotCounts.unionMax(assignNestedScopeSlotsHelper(sortedMembers, child, symbols, slot))
    }

    return slotCounts
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

        return i.ref.innerIndex() < j.ref.innerIndex()
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
        allocator = Allocator.default
        tempAllocator = Allocator.default
        numberScopePool = HiveArrayNumberScope()
        arena = ArenaAllocator()
        root = NumberScope()
        nameStackFallback = StackFallbackAllocator()
        nameTempAllocator = Allocator.default
    }

    /// 析构 - 严格对应 Bun NumberRenamer.deinit
    /// Zig: pub fn deinit(self: *NumberRenamer) void
    public func deinit(): Unit {
        allocator.free(names)
        root.deinit(tempAllocator)
        arena.deinit()
    }

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
    public func assignName(scope: NumberScope, inputRef: Ref): Unit {
        let ref = symbols.follow(inputRef)

        // 不要重命名同一个符号多次
        var inner = names[ref.sourceIndex()]
        if (inner.length > ref.innerIndex() && inner.at(ref.innerIndex()).length > 0) {
            return
        }

        // 不重命名未绑定符号、保留名称、标签或私有名称
        let symbol = symbols.get(ref)
        if (symbol.slotNamespace() != SlotNamespace.default) {
            return
        }

        let nameResult = scope.findUnusedName(allocator, nameTempAllocator, symbol.originalName)
        let name: String = match (nameResult) {
            case .renamed => n => n
            case .no_collision => symbol.originalName
        }
        let newLen = max(inner.length, ref.innerIndex() + 1)
        if (inner.cap <= newLen) {
            inner.ensureUnusedCapacity(allocator, newLen - inner.length)
        }
        inner.length = newLen
        inner.mut(ref.innerIndex(), name)
    }

    /// 初始化 - 严格对应 Bun NumberRenamer.init
    /// Zig: pub fn init(allocator, temp_allocator, symbols, root_names) !*NumberRenamer
    public static func init(
        allocator: Allocator,
        tempAllocator: Allocator,
        symbols: SymbolMap,
        rootNames: StringHashMapUnmanagedUInt32
    ): NumberRenamer {
        let renamer = NumberRenamer()
        renamer.symbols = symbols
        renamer.allocator = allocator
        renamer.tempAllocator = tempAllocator
        renamer.names = allocator.alloc<BabyListString>(symbols.symbolsForSource.length)
        renamer.arena = ArenaAllocator.init(tempAllocator)
        renamer.nameStackFallback = StackFallbackAllocator(512, renamer.arena.allocator())
        renamer.nameTempAllocator = renamer.nameStackFallback.get()
        renamer.numberScopePool = HiveArrayNumberScope.init(renamer.arena.allocator())
        renamer.root = NumberScope()
        renamer.root.nameCounts = rootNames

        return renamer
    }

    /// 递归分配名称 - 严格对应 Bun NumberRenamer.assignNamesRecursive
    /// Zig: pub fn assignNamesRecursive(r, scope, source_index, parent, sorted) void
    public func assignNamesRecursive(scope: Scope, sourceIndex: UInt32, parent: ?NumberScope, sorted: ArrayList<UInt32>): Unit {
        let s = numberScopePool.get()
        s.parent = parent
        s.nameCounts = StringHashMapUnmanagedUInt32()
        defer {
            s.deinit(tempAllocator)
            numberScopePool.put(s)
        }

        assignNamesRecursiveWithNumberScope(s, scope, sourceIndex, sorted)
    }

    /// 在作用域内分配名称 - 严格对应 Bun NumberRenamer.assignNamesInScope
    /// Zig: fn assignNamesInScope(r, s, scope, source_index, sorted) void
    public func assignNamesInScope(s: NumberScope, scope: Scope, sourceIndex: UInt32, sorted: ArrayList<UInt32>): Unit {
        sorted.clear()
        for (valueRef in scope.members.values()) {
            sorted.append(valueRef.ref.innerIndex())
        }
        sorted.sort()

        for (innerIndex in sorted) {
            assignName(s, Ref.init(innerIndex, sourceIndex, false))
        }

        for (ref in scope.generated.slice()) {
            assignName(s, ref)
        }
    }

    /// 使用数字作用域递归分配名称 - 严格对应 Bun NumberRenamer.assignNamesRecursiveWithNumberScope
    /// Zig: pub fn assignNamesRecursiveWithNumberScope(r, initial_scope, scope_, source_index, sorted) void
    public func assignNamesRecursiveWithNumberScope(initialScope: NumberScope, scope_: Scope, sourceIndex: UInt32, sorted: ArrayList<UInt32>): Unit {
        var s = initialScope
        var scope = scope_
        defer {
            if (s != initialScope) {
                s.deinit(tempAllocator)
                numberScopePool.put(s)
            }
        }

        while (true) {
            if (scope.members.count() > 0 || scope.generated.length > 0) {
                let newChildScope = numberScopePool.get()
                newChildScope.parent = s
                newChildScope.nameCounts = StringHashMapUnmanagedUInt32()
                s = newChildScope

                assignNamesInEnv(s, scope, sourceIndex, sorted)
            }

            if (scope.children.length == 1) {
                scope = scope.children[0]
            } else {
                break
            }
        }

        // 子作用域中的符号可能也需要重命名以避免冲突
        for (child in scope.children.slice()) {
            assignNamesRecursiveWithNumberScope(s, child, sourceIndex, sorted)
        }
    }

    /// 添加顶层符号 - 严格对应 Bun NumberRenamer.addTopLevelSymbol
    /// Zig: pub fn addTopLevelSymbol(r: *NumberRenamer, ref: Ref) void
    public func addTopLevelSymbol(ref: Ref): Unit {
        assignName(root, ref)
    }

    /// 添加顶层声明的符号 - 严格对应 Bun NumberRenamer.addTopLevelDeclaredSymbols
    /// Zig: pub fn addTopLevelDeclaredSymbols(r, declared_symbols) void
    public func addTopLevelDeclaredSymbols(declaredSymbols: DeclaredSymbolList): Unit {
        DeclaredSymbol.forEachTopLevelSymbol(declaredSymbols, this, addTopLevelSymbol)
    }

    /// 获取符号名称 - 严格对应 Bun NumberRenamer.nameForSymbol
    /// Zig: pub fn nameForSymbol(renamer: *NumberRenamer, ref: Ref) string
    public func nameForSymbol(ref: Ref): String {
        let resolved = symbols.follow(ref)
        let sourceIndex = resolved.sourceIndex()
        let innerIndex = resolved.innerIndex()

        let renamedList = names[sourceIndex]

        if (renamedList.length > innerIndex) {
            let renamed = renamedList.at(innerIndex)
            if (renamed.length > 0) {
                return renamed
            }
        }

        return symbols.symbolsForSource.at(sourceIndex).at(innerIndex).originalName
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
        if (let count = nameCounts.get(name)) {
            return NameUseResult(NameUseKind.sameScope, count)
        }

        var s: ?NumberScope = parent

        while (let scope = s) {
            if (scope.nameCounts.contains(name)) {
                return NameUseResult(NameUseKind.used, 0)
            }
            s = scope.parent
        }

        return NameUseResult(NameUseKind.unused, 0)
    }

    /// 查找未使用名称 - 严格对应 Bun NumberScope.findUnusedName
    /// Zig: pub fn findUnusedName(this, allocator, temp_allocator, input_name) UnusedName
    public func findUnusedName(allocator: Allocator, tempAllocator: Allocator, inputName: String): UnusedNameResult {
        var name = MutableString.ensureValidIdentifier(inputName, tempAllocator)

        let useResult = find(name)
        match (useResult.kind) {
            case NameUseKind.unused =>
            default =>
                var tries: UInt32 = match (useResult.kind) {
                    case NameUseKind.used => 1
                    case NameUseKind.sameScope => useResult.count
                    default => 1
                }

                let prefix = name

                tries += 1

                var mutableName = MutableString()
                mutableName.growIfNeeded(prefix.length + 4)
                mutableName.appendSlice(prefix)
                mutableName.appendInt(tries)

                let innerResult = find(mutableName.slice())
                match (innerResult.kind) {
                    case NameUseKind.unused =>
                        name = mutableName.slice()

                        if (useResult.kind == NameUseKind.sameScope) {
                            let existing = nameCounts.getOrPut(allocator, prefix)
                            if (!existing.foundExisting) {
                                existing.key = inputName
                            }
                            existing.value = tries
                        }
                    default =>
                        while (true) {
                            mutableName.resetTo(prefix.length)
                            mutableName.appendInt(tries)

                            tries += 1

                            let loopResult = find(mutableName.slice())
                            match (loopResult.kind) {
                                case NameUseKind.unused =>
                                    if (innerResult.kind == NameUseKind.sameScope) {
                                        let existing = nameCounts.getOrPut(allocator, prefix)
                                        if (!existing.foundExisting) {
                                            existing.key = inputName
                                        }
                                        existing.value = tries
                                    }

                                    name = mutableName.slice()
                                    break
                                default =>
                            }
                        }
                }
        }

        // 每个名称以计数 1 开始，这样第一个与 "name" 冲突的名称称为 "name2"
        if (strings.eqlLong(name, inputName, true)) {
            nameCounts.putNoClobber(allocator, inputName, 1)
            return UnusedNameResult.noCollision
        }

        name = allocator.dupe(name)

        nameCounts.putNoClobber(allocator, name, 1)
        return UnusedNameResult.renamed(name)
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
        stringBuffer = MutableString.initEmpty(allocator)
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
        stringBuffer.deinit()
    }

    /// 获取下一个重命名名称 - 严格对应 Bun ExportRenamer.nextRenamedName
    /// Zig: pub fn nextRenamedName(this: *ExportRenamer, input: []const u8) string
    public func nextRenamedName(input: String): String {
        let entry = used.getOrPut(input)
        var tries: UInt32 = 1
        if (entry.foundExisting) {
            while (true) {
                stringBuffer.reset()
                let attempt = "${input}${tries}"
                tries += 1
                let attemptEntry = used.getOrPut(attempt)
                if (!attemptEntry.foundExisting) {
                    let toUse = stringBuffer.allocator.dupe(attempt)
                    attemptEntry.key = toUse
                    attemptEntry.value = tries

                    let inputEntry = used.getOrPut(input)
                    inputEntry.value = tries
                    return toUse
                }
            }
        } else {
            entry.value = tries
        }

        return entry.key
    }

    /// 获取下一个压缩名称 - 严格对应 Bun ExportRenamer.nextMinifiedName
    /// Zig: pub fn nextMinifiedName(this: *ExportRenamer, allocator) !string
    public func nextMinifiedName(allocator: Allocator): String {
        let name = NameMinifier.defaultNumberToMinifiedName(allocator, count)
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
    var names = StringHashMapUnmanagedUInt32()

    let extras: Array<String> = ["Promise", "Require"]

    let cjsNames: Array<String> = ["exports", "module"]

    let cjsNamesLen: UInt32 = if (outputFormat == Format.cjs) UInt32(cjsNames.length) else 0

    names.ensureTotalCapacity(allocator,
        cjsNamesLen +
        UInt32(Lexer.Keywords.length + Lexer.StrictModeReservedWords.length + 1 + extras.length))

    for (keyword in Lexer.Keywords) {
        names.putAssumeCapacity(keyword, 1)
    }

    for (keyword in Lexer.StrictModeReservedWords) {
        names.putAssumeCapacity(keyword, 1)
    }

    // Node.js 在扫描 CommonJS 模块时检测导出名称时不做作用域分析
    // 在 CJS 格式下避免使用这些名称
    if (outputFormat == Format.cjs) {
        for (name in cjsNames) {
            names.putAssumeCapacity(name, 1)
        }
    }

    for (extra in extras) {
        names.putAssumeCapacity(extra, 1)
    }

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
): Unit {
    var names = namesRef

    for (member in scope.members.values()) {
        let symbol = symbols.get(member.ref)
        if (symbol.kind == SymbolKind.unbound || symbol.mustNotBeRenamed) {
            names.put(allocator, symbol.originalName, 1)
        }
    }

    for (ref in scope.generated.slice()) {
        let symbol = symbols.get(ref)
        if (symbol.kind == SymbolKind.unbound || symbol.mustNotBeRenamed) {
            names.put(allocator, symbol.originalName, 1)
        }
    }

    // 如果当前作用域内有直接的 "eval"，继续遍历子作用域获取保留名称
    if (scope.containsDirectEval) {
        for (child in scope.children.slice()) {
            if (child.containsDirectEval) {
                computeReservedNamesForScope(child, symbols, names, allocator)
            }
        }
    }

    namesRef = names
}
