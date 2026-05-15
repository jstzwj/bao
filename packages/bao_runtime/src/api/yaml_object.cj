// 严格翻译自: src/runtime/api/YAMLObject.zig
package bao_runtime.api

import bao_jsc.*
import bao_core.*
import bao_io.*
import bao_collections.*

// ============================================================================
// YAMLObject - Bun.YAML 全局对象
// 对应 Bun: src/runtime/api/YAMLObject.zig
// ============================================================================

/// 创建 YAML 对象，挂载到 Bun.YAML
public func create(globalThis: JsGlobalObject): JsValue {
    let object = JsValue.createEmptyObject(globalThis, 2)
    object.put(
        globalThis,
        ZigString.static("parse"),
        JsFunction.create(
            globalThis,
            "parse",
            parse,
            1,
        ),
    )
    object.put(
        globalThis,
        ZigString.static("stringify"),
        JsFunction.create(
            globalThis,
            "stringify",
            stringify,
            3,
        ),
    )
    return object
}

/// YAML.parse - 解析 YAML 字符串为 JS 对象
public func parse(globalThis: JsGlobalObject, callFrame: JsCallFrame): JsValue {
    var arena = ArenaAllocator.init(default_allocator)
    defer arena.deinit()
    let allocator = arena.allocator()

    var astMemoryAllocator = handleOom(allocator.create(ASTMemoryAllocator))
    var astScope = astMemoryAllocator.enter(allocator)
    defer astScope.exit()

    let inputValue = callFrame.argumentsAsArray(1)[0]

    let input = try JsNode.BlobOrStringOrBuffer.fromJS(globalThis, arena.allocator(), inputValue) ?? {
        var str = try inputValue.toBunString(globalThis)
        defer str.deref()
        return BlobOrStringOrBuffer{ string_or_buffer: StringOrBuffer{ string: str.toSlice(arena.allocator()) } }
    }()
    defer input.deinit()

    var log = Logger.Log.init(default_allocator)
    defer log.deinit()

    let source = Logger.Source.initPathString("input.yaml", input.slice())

    let root = YAML.parse(source, log, arena.allocator()) catch { err =>
        return switch (err) {
            case .OutOfMemory => oom
            case .StackOverflow => globalThis.throwStackOverflow()
            else => {
                if (log.msgs.items.len > 0) {
                    let firstMsg = log.msgs.items[0]
                    let errorText = firstMsg.data.text
                    return globalThis.throwValue(globalThis.createSyntaxErrorInstance("YAML Parse error: \{errorText}"))
                }
                return globalThis.throwValue(globalThis.createSyntaxErrorInstance("YAML Parse error: Unable to parse YAML string"))
            }
        }
    }

    var ctx = ParserCtx{
        seen_objects = AutoHashMap.init(arena.allocator()),
        stack_check = StackCheck.init(),
        global = globalThis,
        root = root,
        result = JsValue.zero,
    }
    defer ctx.deinit()

    MarkedArgumentBuffer.run(ParserCtx, ctx, ParserCtx.run)

    return ctx.result
}

/// YAML.stringify - 将 JS 值序列化为 YAML 字符串
public func stringify(globalThis: JsGlobalObject, callFrame: JsCallFrame): JsValue {
    let (value, replacer, spaceValue) = callFrame.argumentsAsArray(3)

    value.ensureStillAlive()

    if (value.isUndefined() || value.isSymbol() || value.isFunction()) {
        return JsValue.jsUndefined()
    }

    if (!replacer.isUndefinedOrNull()) {
        return globalThis.throw("YAML.stringify does not support the replacer argument")
    }

    var scope = AllocationScope.init(default_allocator)
    defer scope.deinit()

    var stringifier = try Stringifier.init(scope.allocator(), globalThis, spaceValue)
    defer stringifier.deinit()

    stringifier.findAnchorsAndAliases(globalThis, value, AnchorOrigin.root) catch { err =>
        return switch (err) {
            case .OutOfMemory, .JSError, .JSTerminated => js_err => js_err
            case .StackOverflow => globalThis.throwStackOverflow()
        }
    }

    stringifier.stringify(globalThis, value) catch { err =>
        return switch (err) {
            case .OutOfMemory, .JSError, .JSTerminated => js_err => js_err
            case .StackOverflow => globalThis.throwStackOverflow()
        }
    }

    return stringifier.builder.toString(globalThis)
}

// ============================================================================
// Stringifier - YAML 序列化器
// ============================================================================

public class Stringifier {
    var stack_check: StackCheck
    var builder: StringBuilder
    var indent: Int64
    var known_collections: AutoHashMap<JsValue, AnchorAlias>
    var array_item_counter: Int64
    var prop_names: StringHashMap<Int64>
    var space: Space

    // ========================================================================
    // Space - 缩进配置
    // ========================================================================

    public enum Space {
        case minified
        case number(Int64)
        case str(BunString)

        public static func init(global: JsGlobalObject, spaceValue: JsValue): Space {
            let space = try spaceValue.unwrapBoxedPrimitive(global)
            if (space.isNumber()) {
                let numF = space.asNumber()
                if (!(numF >= 1)) { return .minified }
                return .number(if (numF > 10) 10 else Int64(numF))
            }

            if (space.isString()) {
                let str = try space.toBunString(global)
                if (str.length() == 0) {
                    str.deref()
                    return .minified
                }
                return .str(str)
            }

            return .minified
        }

        public func deinit() {
            switch (this) {
                case .minified => {}
                case .number => {}
                case .str(let str) => str.deref()
            }
        }
    }

    // ========================================================================
    // AnchorOrigin / AnchorAlias
    // ========================================================================

    public enum AnchorOrigin {
        case root
        case array_item
        case prop_value(BunString)
    }

    public class AnchorAlias {
        var anchored: Bool
        var used: Bool
        var name: Name

        public static func init(origin: ValueOrigin): AnchorAlias {
            return AnchorAlias{
                anchored = false,
                used = false,
                name = switch (origin) {
                    case .root => .root
                    case .array_item => .array_item(0)
                    case .prop_value(let prop_name) => .prop_value(PropValueName{ prop_name: prop_name, counter: 0 })
                },
            }
        }

        public enum Name {
            case root
            case array_item(Int64)
            case prop_value(PropValueName)
        }

        public class PropValueName {
            var prop_name: BunString
            var counter: Int64
        }
    }

    public typealias ValueOrigin = AnchorOrigin

    public static func init(allocator: Allocator, global: JsGlobalObject, spaceValue: JsValue): Stringifier {
        var propNames = StringHashMap<Int64>.init(allocator)
        // 避免与 root anchor 冲突
        try propNames.put("root", 0)

        return Stringifier{
            stack_check = StackCheck.init(),
            builder = StringBuilder.init(),
            indent = 0,
            known_collections = AutoHashMap.init(allocator),
            array_item_counter = 0,
            prop_names = propNames,
            space = try Space.init(global, spaceValue),
        }
    }

    public func deinit() {
        this.builder.deinit()
        this.known_collections.deinit()
        this.prop_names.deinit()
        this.space.deinit()
    }

    /// 查找锚点和别名
    public func findAnchorsAndAliases(global: JsGlobalObject, value: JsValue, origin: ValueOrigin): Unit {
        if (!this.stack_check.isSafeToRecurse()) {
            throw Error.StackOverflow
        }

        let unwrapped = try value.unwrapBoxedPrimitive(global)

        if (unwrapped.isNull()) { return }
        if (unwrapped.isNumber()) { return }

        if (unwrapped.isBigInt()) {
            return global.throw("YAML.stringify cannot serialize BigInt")
        }
        if (unwrapped.isBoolean()) { return }
        if (unwrapped.isString()) { return }

        let objectEntry = try this.known_collections.getOrPut(unwrapped)
        if (objectEntry.found_existing) {
            if (objectEntry.value_ptr.used) { return }
            objectEntry.value_ptr.used = true

            switch (objectEntry.value_ptr.name) {
                case .root => {
                    // 只有一个可能的 root anchor
                }
                case .array_item(let counter) => {
                    counter = this.array_item_counter
                    this.array_item_counter += 1
                }
                case .prop_value(let propValue) => {
                    let nameEntry = try this.prop_names.getOrPut(propValue.prop_name.byteSlice())
                    if (nameEntry.found_existing) {
                        nameEntry.value_ptr += 1
                    } else {
                        nameEntry.value_ptr = 0
                    }
                    propValue.counter = nameEntry.value_ptr
                }
            }
            return
        }

        objectEntry.value_ptr = AnchorAlias.init(origin)

        if (unwrapped.isArray()) {
            var iter = try unwrapped.arrayIterator(global)
            while (let item = try iter.next()) {
                if (item.isUndefined() || item.isSymbol() || item.isFunction()) { continue }
                try this.findAnchorsAndAliases(global, item, .array_item)
            }
            return
        }

        var iter = JsPropertyIterator.init(
            global,
            try unwrapped.toObject(global),
            skip_empty_name: false,
            include_value: true,
        )
        defer iter.deinit()

        while (let propName = try iter.next()) {
            if (iter.value.isUndefined() || iter.value.isSymbol() || iter.value.isFunction()) { continue }
            try this.findAnchorsAndAliases(global, iter.value, .prop_value(propName))
        }
    }

    /// 执行序列化
    public func stringify(global: JsGlobalObject, value: JsValue): Unit {
        if (!this.stack_check.isSafeToRecurse()) {
            throw Error.StackOverflow
        }

        let unwrapped = try value.unwrapBoxedPrimitive(global)

        if (unwrapped.isNull()) {
            this.builder.append(.latin1, "null")
            return
        }

        if (unwrapped.isNumber()) {
            if (unwrapped.isInt32()) {
                this.builder.append(.int, unwrapped.asInt32())
                return
            }

            let num = unwrapped.asNumber()
            if (Math.isNegativeInf(num)) {
                this.builder.append(.latin1, "-.inf")
            } else if (Math.isInf(num)) {
                this.builder.append(.latin1, ".inf")
            } else if (Math.isNan(num)) {
                this.builder.append(.latin1, ".nan")
            } else if (Math.isNegativeZero(num)) {
                this.builder.append(.latin1, "-0")
            } else if (Math.isPositiveZero(num)) {
                this.builder.append(.latin1, "+0")
            } else {
                this.builder.append(.double, num)
            }
            return
        }

        if (unwrapped.isBigInt()) {
            return global.throw("YAML.stringify cannot serialize BigInt")
        }

        if (unwrapped.isBoolean()) {
            if (unwrapped.asBoolean()) {
                this.builder.append(.latin1, "true")
            } else {
                this.builder.append(.latin1, "false")
            }
            return
        }

        if (unwrapped.isString()) {
            let valueStr = try unwrapped.toBunString(global)
            defer valueStr.deref()
            this.appendString(valueStr)
            return
        }

        // 处理锚点/别名
        let hasAnchor = this.known_collections.getPtr(unwrapped).flatMap { anchor =>
            if (!anchor.used) { return null }
            return anchor
        }

        if (let anchor = hasAnchor) {
            this.builder.append(.lchar, if (anchor.anchored) '*' else '&')

            switch (anchor.name) {
                case .root => {
                    this.builder.append(.latin1, "root")
                }
                case .array_item => {
                    this.builder.append(.latin1, "item")
                    this.builder.append(.usize, anchor.name.array_item)
                }
                case .prop_value(let propValue) => {
                    if (propValue.prop_name.length() == 0) {
                        this.builder.append(.latin1, "value")
                        this.builder.append(.usize, propValue.counter)
                    } else {
                        this.builder.append(.string, anchor.name.prop_value.prop_name)
                        if (anchor.name.prop_value.counter != 0) {
                            this.builder.append(.usize, anchor.name.prop_value.counter)
                        }
                    }
                }
            }

            if (anchor.anchored) { return }

            switch (this.space) {
                case .minified => {
                    this.builder.append(.lchar, ' ')
                }
                case .number, .str => {
                    this.newline()
                }
            }
            anchor.anchored = true
        }

        if (unwrapped.isArray()) {
            var iter = try unwrapped.arrayIterator(global)

            if (iter.len == 0) {
                this.builder.append(.latin1, "[]")
                return
            }

            switch (this.space) {
                case .minified => {
                    this.builder.append(.lchar, '[')
                    var first = true
                    while (let item = try iter.next()) {
                        if (item.isUndefined() || item.isSymbol() || item.isFunction()) { continue }
                        if (!first) { this.builder.append(.lchar, ',') }
                        first = false
                        try this.stringify(global, item)
                    }
                    this.builder.append(.lchar, ']')
                }
                case .number, .str => {
                    this.builder.ensureUnusedCapacity(iter.len * "- ".length)
                    var first = true
                    while (let item = try iter.next()) {
                        if (item.isUndefined() || item.isSymbol() || item.isFunction()) { continue }
                        if (!first) { this.newline() }
                        first = false
                        this.builder.append(.latin1, "- ")
                        this.indent += 1
                        try this.stringify(global, item)
                        this.indent -= 1
                    }
                }
            }
            return
        }

        // 对象
        var iter = JsPropertyIterator.init(
            global,
            try unwrapped.toObject(global),
            skip_empty_name: false,
            include_value: true,
        )
        defer iter.deinit()

        if (iter.len == 0) {
            this.builder.append(.latin1, "{}")
            return
        }

        switch (this.space) {
            case .minified => {
                this.builder.append(.lchar, '{')
                var first = true
                while (let propName = try iter.next()) {
                    if (iter.value.isUndefined() || iter.value.isSymbol() || iter.value.isFunction()) { continue }
                    if (!first) { this.builder.append(.lchar, ',') }
                    first = false
                    this.appendString(propName)
                    this.builder.append(.latin1, ": ")
                    try this.stringify(global, iter.value)
                }
                this.builder.append(.lchar, '}')
            }
            case .number, .str => {
                this.builder.ensureUnusedCapacity(iter.len * ": ".length)
                var first = true
                while (let propName = try iter.next()) {
                    if (iter.value.isUndefined() || iter.value.isSymbol() || iter.value.isFunction()) { continue }
                    if (!first) { this.newline() }
                    first = false
                    this.appendString(propName)
                    this.builder.append(.latin1, ": ")
                    this.indent += 1
                    if (propValueNeedsNewline(iter.value)) {
                        this.newline()
                    }
                    try this.stringify(global, iter.value)
                    this.indent -= 1
                }
                if (first) {
                    this.builder.append(.latin1, "{}")
                }
            }
        }
    }

    /// 判断属性值是否需要换行
    static func propValueNeedsNewline(value: JsValue): Bool {
        return !value.isNumber() && !value.isBoolean() && !value.isNull() && !value.isString()
    }

    /// 输出换行符和缩进
    func newline() {
        let indentCount = this.indent
        switch (this.space) {
            case .minified => {}
            case .number(let spaceNum) => {
                this.builder.append(.lchar, '\n')
                this.builder.ensureUnusedCapacity(indentCount * spaceNum)
                for (_ in 0..<indentCount * spaceNum) {
                    this.builder.append(.lchar, ' ')
                }
            }
            case .str(let spaceStr) => {
                this.builder.append(.lchar, '\n')
                let clamped = if (spaceStr.length() > 10) spaceStr.substringWithLen(0, 10) else spaceStr
                this.builder.ensureUnusedCapacity(indentCount * clamped.length())
                for (_ in 0..<indentCount) {
                    this.builder.append(.string, clamped)
                }
            }
        }
    }

    /// 追加双引号字符串
    func appendDoubleQuotedString(str: BunString) {
        this.builder.append(.lchar, '"')
        for (i in 0..<str.length()) {
            let c = str.charAt(i)
            // YAML 双引号转义规则
            if (c == 0x00) { this.builder.append(.latin1, "\\0") }
            else if (c == 0x07) { this.builder.append(.latin1, "\\a") }
            else if (c == 0x08) { this.builder.append(.latin1, "\\b") }
            else if (c == 0x09) { this.builder.append(.latin1, "\\t") }
            else if (c == 0x0a) { this.builder.append(.latin1, "\\n") }
            else if (c == 0x0b) { this.builder.append(.latin1, "\\v") }
            else if (c == 0x0c) { this.builder.append(.latin1, "\\f") }
            else if (c == 0x0d) { this.builder.append(.latin1, "\\r") }
            else if (c == 0x1b) { this.builder.append(.latin1, "\\e") }
            else if (c == 0x22) { this.builder.append(.latin1, "\\\"") }
            else if (c == 0x5c) { this.builder.append(.latin1, "\\\\") }
            else if (c == 0x7f) { this.builder.append(.latin1, "\\x7f") }
            else if (c == 0x85) { this.builder.append(.latin1, "\\N") }
            else if (c == 0xa0) { this.builder.append(.latin1, "\\_") }
            else if (c == 0xa8) { this.builder.append(.latin1, "\\L") }
            else if (c == 0xa9) { this.builder.append(.latin1, "\\P") }
            else if (c < 0x20 || c == 0x22 || c == 0x7f) {
                this.builder.appendFormat(.latin1, "\\x\{c:02x}")
            } else {
                this.builder.append(.uchar, c)
            }
        }
        this.builder.append(.lchar, '"')
    }

    /// 追加字符串，根据需要加引号
    func appendString(str: BunString) {
        if (stringNeedsQuotes(str)) {
            this.appendDoubleQuotedString(str)
            return
        }
        this.builder.append(.string, str)
    }

    /// 判断字符串是否需要引号
    static func stringNeedsQuotes(str: BunString): Bool {
        if (str.isEmpty()) { return true }

        // 检查尾部字符
        let lastChar = str.charAt(str.length() - 1)
        if (lastChar == ' ' || lastChar == '\t' || lastChar == '\n' || lastChar == '\r' || lastChar == ':') {
            return true
        }

        // 检查起始字符
        let firstChar = str.charAt(0)
        let indicatorChars = "&*?|<>!%:@,[]{}#'\"` \t\n\r"
        if (indicatorChars.contains(firstChar)) { return true }

        // 检查 YAML 关键字
        let keywords = [
            "true", "True", "TRUE", "false", "False", "FALSE",
            "yes", "Yes", "YES", "no", "No", "NO",
            "on", "On", "ON", "off", "Off", "OFF",
            "n", "N", "y", "Y",
            "null", "Null", "NULL", "~",
            ".inf", ".Inf", ".INF", ".nan", ".NaN", ".NAN",
        ]
        for (keyword in keywords) {
            if (str.eqlComptime(keyword)) { return true }
        }

        // 扫描中间字符
        var i: Int64 = 0
        while (i < str.length()) {
            let c = str.charAt(i)
            switch (c) {
                case '{', '}', '[', ']', ',' => return true
                case ':' => {
                    if (i + 1 < str.length()) {
                        let next = str.charAt(i + 1)
                        if (next == ' ' || next == '\t' || next == '\n' || next == '\r') { return true }
                    }
                    i += 1
                }
                case '#', '`', '\'' => return true
                case '-' => {
                    // 检查文档分隔符 ---
                    if (i + 2 < str.length() && str.charAt(i + 1) == '-' && str.charAt(i + 2) == '-') {
                        if (i + 3 >= str.length()) { return true }
                        let after = str.charAt(i + 3)
                        if (after == ' ' || after == '\t' || after == '\r' || after == '\n' ||
                            after == '[' || after == ']' || after == '{' || after == '}' || after == ',') {
                            return true
                        }
                    }
                    if (i == 0 && stringIsNumber(str)) { return true }
                    i += 1
                }
                case '.' => {
                    if (i + 2 < str.length() && str.charAt(i + 1) == '.' && str.charAt(i + 2) == '.') {
                        if (i + 3 >= str.length()) { return true }
                        let after = str.charAt(i + 3)
                        if (after == ' ' || after == '\t' || after == '\r' || after == '\n' ||
                            after == '[' || after == ']' || after == '{' || after == '}' || after == ',') {
                            return true
                        }
                    }
                    if (i == 0 && stringIsNumber(str)) { return true }
                    i += 1
                }
                case '0'...'9' => {
                    if (i == 0 && stringIsNumber(str)) { return true }
                    i += 1
                }
                case '+' => {
                    if (i == 0 && stringIsNumber(str)) { return true }
                    i += 1
                }
                else => {
                    if (c <= 0x1f || c == 0x22 || c == 0x7f || c == 0x85 || c == 0xa0 || c == 0xa8 || c == 0xa9) {
                        return true
                    }
                    i += 1
                }
            }
        }
        return false
    }

    /// 检测字符串是否为数字
    static func stringIsNumber(str: BunString): Bool {
        let len = str.length()
        if (len == 0) { return false }
        var i: Int64 = 0

        let first = str.charAt(0)
        let signed = first == '+' || first == '-'
        if (signed) {
            i = 1
            if (i >= len) { return false }
            if (str.charAt(i) == '.' && isInfSuffix(str, i)) { return true }
        }

        var base = "dec"
        if (i + 1 < len && str.charAt(i) == '0') {
            let next = str.charAt(i + 1)
            if (next == 'x' || next == 'X') {
                base = "hex"
                i += 2
                if (i >= len) { return false }
            } else if (next == 'o' || next == 'O') {
                base = "oct"
                i += 2
                if (i >= len) { return false }
            }
        }

        var sawDot = false
        var sawExp = false
        var sawMinusAfterSign = false

        while (i < len) {
            let c = str.charAt(i)
            if (c >= '0' && c <= '9') {
                // OK
            } else if ((c >= 'a' && c <= 'd') || c == 'f' || (c >= 'A' && c <= 'D') || c == 'F') {
                if (base != "hex") { return false }
            } else if (c == 'e' || c == 'E') {
                if (base == "dec") {
                    if (sawExp) { return false }
                    sawExp = true
                }
            } else if (c == '.') {
                if (sawDot || base != "dec") { return false }
                sawDot = true
            } else if (c == '+') {
                if (base == "hex") { return false }
            } else if (c == '-') {
                if (sawMinusAfterSign) { return false }
                sawMinusAfterSign = true
            } else {
                return false
            }
            i += 1
        }
        return true
    }

    /// 检查是否为 .inf 后缀
    static func isInfSuffix(str: BunString, i: Int64): Bool {
        if (i + 4 > str.length()) { return false }
        let a = str.charAt(i + 1)
        let b = str.charAt(i + 2)
        let c = str.charAt(i + 3)
        return (a == 'i' && b == 'n' && c == 'f') ||
               (a == 'I' && b == 'n' && c == 'f') ||
               (a == 'I' && b == 'N' && c == 'F')
    }
}

// ============================================================================
// ParserCtx - YAML 解析上下文
// ============================================================================

public class ParserCtx {
    var seen_objects: AutoHashMap<UnsafeRawPointer, JsValue>
    var stack_check: StackCheck
    var global: JsGlobalObject
    var root: Expr
    var result: JsValue

    public func deinit() {
        this.seen_objects.deinit()
    }

    public static func run(ctx: ParserCtx, args: MarkedArgumentBuffer) {
        ctx.result = ctx.toJS(args, ctx.root) catch { err =>
            return switch (err) {
                case .OutOfMemory => { ctx.result = ctx.global.throwOutOfMemoryValue(); return }
                case .JSError, .JSTerminated => { ctx.result = JsValue.zero; return }
                case .StackOverflow => { ctx.result = ctx.global.throwStackOverflow() ?? JsValue.zero; return }
            }
        }
    }

    public func toJS(args: MarkedArgumentBuffer, expr: Expr): JsValue {
        if (!this.stack_check.isSafeToRecurse()) {
            throw Error.StackOverflow
        }

        switch (expr.data) {
            case .e_null => return JsValue.null()
            case .e_boolean(let boolean) => return JsValue.jsBoolean(boolean.value)
            case .e_number(let number) => return JsValue.jsNumber(number.value)
            case .e_string(let str) => {
                return str.toJS(default_allocator, this.global)
            }
            case .e_array => {
                if (let arr = this.seen_objects.get(expr.data.e_array)) { return arr }

                var arr = try JsValue.createEmptyArray(this.global, expr.data.e_array.items.len)
                args.append(arr)
                try this.seen_objects.put(expr.data.e_array, arr)

                for ((item, _i) in expr.data.e_array.slice().enumerated()) {
                    let i: Int64 = Int64(_i)
                    let value = try this.toJS(args, item)
                    try arr.putIndex(this.global, i, value)
                }
                return arr
            }
            case .e_object => {
                if (let obj = this.seen_objects.get(expr.data.e_object)) { return obj }

                var obj = JsValue.createEmptyObject(this.global, expr.data.e_object.properties.len)
                args.append(obj)
                try this.seen_objects.put(expr.data.e_object, obj)

                for (prop in expr.data.e_object.properties.slice()) {
                    let keyExpr = prop.key
                    let valueExpr = prop.value

                    let key = try this.toJS(args, keyExpr)
                    let value = try this.toJS(args, valueExpr)

                    let keyStr = try key.toBunString(this.global)
                    defer keyStr.deref()

                    try obj.putMayBeIndex(this.global, keyStr, value)
                }
                return obj
            }
            else => return JsValue.jsUndefined()
        }
    }
}

// ============================================================================
// 类型别名
// ============================================================================

public typealias BunString = BunString
public typealias YAML = YAML
public typealias ASTMemoryAllocator = ASTMemoryAllocator
public typealias Logger = Logger
public let default_allocator = default_allocator
