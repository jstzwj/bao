// 严格翻译自: src/runtime/api/YAMLObject.zig
package bao_runtime.api

import bao_jsc.{JsGlobalObject, JsValue, ZigString}
import bao_core.{Allocator, Output}
import bao_io.*
import bao_collections.*

// 本地 stub 类型
public class BlobOrStringOrBuffer {
    public var stringOrBuffer: ?StringOrBuffer = None
    public init() {}
    public init(string_or_buffer!: StringOrBuffer) {
        stringOrBuffer = Some(string_or_buffer)
    }
    public static func fromJS(globalThis: JsGlobalObject, allocator: Allocator, value: JsValue): ?BlobOrStringOrBuffer {
        None
    }
    public func slice(): Array<UInt8> {
        if (let value <- stringOrBuffer) {
            return value.slice()
        }
        return []
    }
    public func deinit(): Unit {}
}
public type JsNodeBlobOrStringOrBuffer = BlobOrStringOrBuffer
public class AnchorAlias { public init() {} }
public class StringHashMap<V> { public init() {} }
public class MarkedArgumentBuffer { public init() {} }
public class JSError { public init() {} }
public class JSTerminated { public init() {} }
public class StackOverflow { public init() {} }

// ============================================================================
// YAMLObject - Bun.YAML 全局对象
// 对应 Bun: src/runtime/api/YAMLObject.zig
// ============================================================================

/// 创建 YAML 对象，挂载到 Bun.YAML
public func createYAML(globalThis!: JsGlobalObject): JsValue {
    let object = JsValue.createEmptyObject(globalThis, 2)
    object.put(
        globalThis,
        ZigString.`static`("parse"),
        JsFunction.create(
            globalThis,
            "parse",
            parseYAML,
            1,
        ),
    )
    object.put(
        globalThis,
        ZigString.`static`("stringify"),
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
public func parseYAML(globalThis!: JsGlobalObject, callFrame!: JsCallFrame): JsValue {
    var arena = ArenaAllocator(default_allocator)
    let allocator = arena.allocator()

    var astMemoryAllocator = handleOom(allocator.create(ASTMemoryAllocator))
    var astScope = astMemoryAllocator.enter(allocator)

    let inputValue = callFrame.argumentsAsArray(1)[0]

    var input: JsNodeBlobOrStringOrBuffer
    let inputOpt = JsNodeBlobOrStringOrBuffer.fromJS(globalThis, arena.allocator(), inputValue)
    if (let someInput <- inputOpt) {
        input = someInput
    } else {
        let str = inputValue.toBunString(globalThis)
        input = BlobOrStringOrBuffer(string_or_buffer: StringOrBuffer(string: str.toSlice(arena.allocator())))
        str.deref()
    }
    var log = Logger.Log(default_allocator)

    let source = Logger.Source.initPathString("input.yaml", input.slice())

    let root = try {
        YAML.parse(source, log, arena.allocator())
    } catch (err: Exception) {
        if (log.msgs.items.len > 0) {
            let firstMsg = log.msgs.items[0]
            let errorText = firstMsg.data.text
            return globalThis.throwValue(globalThis.createSyntaxErrorInstance("YAML Parse error: ${errorText}"))
        }
        return globalThis.throwValue(globalThis.createSyntaxErrorInstance("YAML Parse error: Unable to parse YAML string"))
    }

    var ctx = ParserCtx{
        seen_objects = AutoHashMap(arena.allocator())
        stack_check = StackCheck()
        global = globalThis
        root = root
        result = JsValue.jsUndefined()
    }
    MarkedArgumentBuffer.run(ParserCtx, ctx, ParserCtx.run)

    ctx.deinit()
    let parseResult = ctx.result
    log.deinit()
    input.deinit()
    astScope.exit()
    arena.deinit()
    return parseResult
}

/// YAML.stringify - 将 JS 值序列化为 YAML 字符串
public func stringify(globalThis!: JsGlobalObject, callFrame!: JsCallFrame): JsValue {
    let (value, replacer, spaceValue) = callFrame.argumentsAsArray(3)

    value.ensureStillAlive()

    if (value.isUndefined() || value.isSymbol() || value.isFunction()) {
        return JsValue.jsUndefined()
    }

    if (!replacer.isUndefinedOrNull()) {
        return globalThis.`throw`("YAML.stringify does not support the replacer argument")
    }

    var scope = AllocationScope(default_allocator)
    var stringifier = YamlStringifier(scope.allocator() , globalThis, spaceValue)

    try {
        stringifier.findAnchorsAndAliases(globalThis, value, AnchorOrigin.root)
    } catch (err: Exception) {
        stringifier.deinit()
        scope.deinit()
        return globalThis.throwStackOverflow()
    }

    try {
        stringifier.stringify(globalThis, value)
    } catch (err: Exception) {
        stringifier.deinit()
        scope.deinit()
        return globalThis.throwStackOverflow()
    }

    stringifier.deinit()
    scope.deinit()
    return stringifier.builder.toString(globalThis)
}

// ============================================================================
// AnchorOrigin / ValueOrigin - YAML 锚点来源类型
// ============================================================================

public enum AnchorOrigin {
    | root
    | array_item
    | prop_value(BunString)
}

public type ValueOrigin = AnchorOrigin

// ============================================================================
// Stringifier - YAML 序列化器
// ============================================================================

public class YamlStringifier {
    var stack_check: StackCheck
    var builder: ApiStringBuilder
    var indent: Int64
    var known_collections: AutoHashMap<JsValue, AnchorAlias>
    var array_item_counter: Int64
    var prop_names: StringHashMap<Int64>
    var space: Space

    // ========================================================================
    // Space - 缩进配置
    // ========================================================================

//    public enum Space {
//        | minified
//        | number(Int64)
//        | str(BunString)

//        public static func initFunc(global!: JsGlobalObject, spaceValue!: JsValue): Space {
//            let space = spaceValue.unwrapBoxedPrimitive(global) 
//            if (space.isNumber()) {
//                let numF = space.asNumber()
//                if (!(numF >= 1)) { return .minified }
//                return .number(if (numF > 10) 10 else Int64(numF))
//            }

//            if (space.isString()) {
//                let str = space.toBunString(global) 
//                if (str.size() == 0) {
//                    str.deref()
//                    return .minified
//                }
//                return .str(str)
//            }

//            return .minified
//        }

//        public func deinit() {
//            match (this) {
//                case minified => ()
//                case number => ()
//                case str(str) => str.deref()
//            }
//        }
//    }

    public static func initFunc(allocator!: Allocator, global!: JsGlobalObject, spaceValue!: JsValue): YamlStringifier {
        var propNames = StringHashMap<Int64>.`init`(allocator)
        // 避免与 root anchor 冲突
        propNames.put("root", 0) 

        return YamlStringifier{
            stack_check = StackCheck()
            builder = ApiStringBuilder()
            indent = 0
            known_collections = AutoHashMap(allocator)
            array_item_counter = 0
            prop_names = propNames
            space = Space(global, spaceValue)
        }
    }

    public func deinit() {
        this.builder.deinit()
        this.known_collections.deinit()
        this.prop_names.deinit()
        this.space.deinit()
    }

    /// 查找锚点和别名
    public func findAnchorsAndAliases(global!: JsGlobalObject, value!: JsValue, origin!: ValueOrigin): Unit {
        if (!this.stack_check.isSafeToRecurse()) {
            throw Error.StackOverflow
        }

        let unwrapped = value.unwrapBoxedPrimitive(global) 

        if (unwrapped.isNull()) { return }
        if (unwrapped.isNumber()) { return }

        if (unwrapped.isBigInt()) {
            return global.`throw`("YAML.stringify cannot serialize BigInt")
        }
        if (unwrapped.isBoolean()) { return }
        if (unwrapped.isString()) { return }

        let objectEntry = this.known_collections.getOrPut(unwrapped) 
        if (objectEntry.found_existing) {
            if (objectEntry.value_ptr.used) { return }
            objectEntry.value_ptr.used = true

            match (objectEntry.value_ptr.name) {
                case root =>
                    () // 只有一个可能的 root anchor
                case array_item(counter) =>
                    counter = this.array_item_counter
                    this.array_item_counter += 1
                case prop_value(propValue) =>
                    let nameEntry = this.prop_names.getOrPut(propValue.prop_name.byteSlice() )
                    if (nameEntry.found_existing) {
                        nameEntry.value_ptr += 1
                    } else {
                        nameEntry.value_ptr = 0
                    }
                    propValue.counter = nameEntry.value_ptr
            }
            return
        }

        objectEntry.value_ptr = AnchorAlias(origin)

        if (unwrapped.isArray()) {
            var iter = unwrapped.arrayIterator(global) 
            while (let item <- iter.next() ) {
                if (item.isUndefined() || item.isSymbol() || item.isFunction()) { continue }
                this.findAnchorsAndAliases(global, item, AnchorOrigin.array_item)
            }
            return
        }

        var iter = JsPropertyIterator(
            global,
            unwrapped.toObject(global) ,
            skip_empty_name: false,
            include_value: true,
        )
        while (let propName <- iter.next()) {
            if (iter.value.isUndefined() || iter.value.isSymbol() || iter.value.isFunction()) { continue }
            this.findAnchorsAndAliases(global, iter.value, AnchorOrigin.prop_value(propName))
        }
        iter.deinit()
    }

    /// 执行序列化
    public func stringify(global!: JsGlobalObject, value!: JsValue): Unit {
        if (!this.stack_check.isSafeToRecurse()) {
            throw Error.StackOverflow
        }

        let unwrapped = value.unwrapBoxedPrimitive(global) 

        if (unwrapped.isNull()) {
            this.builder.append("null")
            return
        }

        if (unwrapped.isNumber()) {
            if (unwrapped.isInt32()) {
                this.builder.append("${unwrapped.asInt32()}")
                return
            }

            let num = unwrapped.asNumber()
            if (Math.isNegativeInf(num)) {
                this.builder.append("-.inf")
            } else if (Math.isInf(num)) {
                this.builder.append(".inf")
            } else if (Math.isNan(num)) {
                this.builder.append(".nan")
            } else if (Math.isNegativeZero(num)) {
                this.builder.append("-0")
            } else if (Math.isPositiveZero(num)) {
                this.builder.append("+0")
            } else {
                this.builder.append("${num}")
            }
            return
        }

        if (unwrapped.isBigInt()) {
            return global.`throw`("YAML.stringify cannot serialize BigInt")
        }

        if (unwrapped.isBoolean()) {
            if (unwrapped.asBoolean()) {
                this.builder.append("true")
            } else {
                this.builder.append("false")
            }
            return
        }

        if (unwrapped.isString()) {
            let valueStr = unwrapped.toBunString(global) 
            this.appendString(valueStr)
            valueStr.deref()
            return
        }

        // 处理锚点/别名
        let hasAnchor = this.known_collections.getPtr(unwrapped).flatMap { anchor =>
            if (!anchor.used) { return none }
            return anchor
        }

        if (let anchor <- hasAnchor) {
            this.builder.appendChar(if (anchor.anchored) { '*'.toUInt8() } else { '&'.toUInt8() })

            match (anchor.name) {
                case root =>
                    this.builder.append("root")
                case array_item =>
                    this.builder.append("item")
                    this.builder.append(anchor.name.array_item.toString())
                case prop_value(propValue) =>
                    if (propValue.prop_name.size() == 0) {
                        this.builder.append("value")
                        this.builder.append(propValue.counter.toString())
                    } else {
                        this.builder.append(anchor.name.prop_value.prop_name)
                        if (anchor.name.prop_value.counter != 0) {
                            this.builder.append(anchor.name.prop_value.counter.toString())
                        }
                    }
            }

            if (anchor.anchored) { return }

            match (this.space) {
                case minified =>
                    this.builder.appendChar(' ')
                case number =>
                    this.newline()
                case str =>
                    this.newline()
            }
            anchor.anchored = true
        }

        if (unwrapped.isArray()) {
            var iter = unwrapped.arrayIterator(global) 

            if (iter.len == 0) {
                this.builder.append("[]")
                return
            }

            match (this.space) {
                case minified =>
                    this.builder.appendChar('[')
                    var first = true
                    while (let item <- iter.next() ) {
                        if (item.isUndefined() || item.isSymbol() || item.isFunction()) { continue }
                        if (!first) { this.builder.appendChar(',') }
                        first = false
                        this.stringify(global, item) 
                    }
                    this.builder.appendChar(']')
                case number =>
                    this.builder.ensureUnusedCapacity(iter.len * "- ".size)
                    var first = true
                    while (let item <- iter.next() ) {
                        if (item.isUndefined() || item.isSymbol() || item.isFunction()) { continue }
                        if (!first) { this.newline() }
                        first = false
                        this.builder.append("- ")
                        this.indent += 1
                        this.stringify(global, item) 
                        this.indent -= 1
                    }
                case str =>
                    this.builder.ensureUnusedCapacity(iter.len * "- ".size)
                    var first = true
                    while (let item <- iter.next() ) {
                        if (item.isUndefined() || item.isSymbol() || item.isFunction()) { continue }
                        if (!first) { this.newline() }
                        first = false
                        this.builder.append("- ")
                        this.indent += 1
                        this.stringify(global, item) 
                        this.indent -= 1
                    }
            }
            return
        }

        // 对象
        var iter = JsPropertyIterator(
            global,
            unwrapped.toObject(global) ,
            skip_empty_name: false,
            include_value: true,
        )
        if (iter.len == 0) {
            this.builder.append("{")
            return
        }

        match (this.space) {
            case minified =>
                this.builder.appendChar('{')
                var first = true
                while (let propName <- iter.next() ) {
                    if (iter.value.isUndefined() || iter.value.isSymbol() || iter.value.isFunction()) { continue }
                    if (!first) { this.builder.appendChar(',') }
                    first = false
                    this.appendString(propName)
                    this.builder.append(": ")
                    this.stringify(global, iter.value) 
                }
                this.builder.appendChar('}')
            case number =>
                this.builder.ensureUnusedCapacity(iter.len * ": ".size)
                var first = true
                while (let propName <- iter.next() ) {
                    if (iter.value.isUndefined() || iter.value.isSymbol() || iter.value.isFunction()) { continue }
                    if (!first) { this.newline() }
                    first = false
                    this.appendString(propName)
                    this.builder.append(": ")
                    this.stringify(global, iter.value) 
                }
            case str =>
                this.builder.ensureUnusedCapacity(iter.len * ": ".size)
                var first = true
                while (let propName <- iter.next() ) {
                    if (iter.value.isUndefined() || iter.value.isSymbol() || iter.value.isFunction()) { continue }
                    if (!first) { this.newline() }
                    first = false
                    this.appendString(propName)
                    this.builder.append(": ")
                    this.indent += 1
                    if (propValueNeedsNewline(iter.value)) {
                        this.newline()
                    }
                    this.stringify(global, iter.value) 
                    this.indent -= 1
                }
                if (first) {
                    this.builder.append("{}")
                }
        }
        iter.deinit()
    }

    /// 判断属性值是否需要换行
    static func propValueNeedsNewline(value!: JsValue): Bool {
        return !value.isNumber() && !value.isBoolean() && !value.isNull() && !value.isString()
    }

    /// 输出换行符和缩进
    func newline() {
        let indentCount = this.indent
        match (this.space) {
            case minified => ()
            case number(spaceNum) =>
                this.builder.appendChar('\n')
                this.builder.ensureUnusedCapacity(indentCount * spaceNum)
                for (_ in 0..indentCount * spaceNum) {
                    this.builder.appendChar(' ')
                }
            case str(spaceStr) =>
                this.builder.appendChar('\n')
                let clamped = if (spaceStr.size() > 10) { spaceStr.substringWithLen(0, 10) } else { spaceStr }
                this.builder.ensureUnusedCapacity(indentCount * clamped.size())
                for (_ in 0..indentCount) {
                    this.builder.append(clamped)
                }
        }
    }

    /// 追加双引号字符串
    func appendDoubleQuotedString(str!: BunString) {
        this.builder.appendChar('"')
        for (i in 0..str.size()) {
            let c = str.charAt(i)
            // YAML 双引号转义规则
            if (c == 0x00) { this.builder.append("\\0") }
            else if (c == 0x07) { this.builder.append("\\a") }
            else if (c == 0x08) { this.builder.append("\\b") }
            else if (c == 0x09) { this.builder.append("\\t") }
            else if (c == 0x0a) { this.builder.append("\\n") }
            else if (c == 0x0b) { this.builder.append("\\v") }
            else if (c == 0x0c) { this.builder.append("\\f") }
            else if (c == 0x0d) { this.builder.append("\\r") }
            else if (c == 0x1b) { this.builder.append("\\e") }
            else if (c == 0x22) { this.builder.append("\\\"") }
            else if (c == 0x5c) { this.builder.append("\\\\") }
            else if (c == 0x7f) { this.builder.append("\u{7f}") }
            else if (c == 0x85) { this.builder.append("\\N") }
            else if (c == 0xa0) { this.builder.append("\\_") }
            else if (c == 0xa8) { this.builder.append("\\L") }
            else if (c == 0xa9) { this.builder.append("\\P") }
            else if (c < 0x20 || c == 0x22 || c == 0x7f) {
                this.builder.appendFormat("\\x{}", c.toHex(2))
            } else {
                this.builder.appendChar(c)
            }
        }
        this.builder.appendChar('"')
    }

    /// 追加字符串，根据需要加引号
    func appendString(str!: BunString) {
        if (stringNeedsQuotes(str)) {
            this.appendDoubleQuotedString(str)
            return
        }
        this.builder.append(str)
    }

    /// 判断字符串是否需要引号
    static func stringNeedsQuotes(str!: BunString): Bool {
        if (str.isEmpty()) { return true }

        // 检查尾部字符
        let lastChar = str.charAt(str.size() - 1)
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
            ".inf", ".Inf", ".INF", ".nan", ".NaN", ".NAN"
        ]
        for (keyword in keywords) {
            if (str.eqlComptime(keyword)) { return true }
        }

        // 扫描中间字符
        var i: Int64 = 0
        while (i < str.size()) {
            let c = str.charAt(i)
            match (c) {
                case '{' => return true
                case '}' => return true
                case '[' => return true
                case ']' => return true
                case ',' => return true
                case ':' =>
                    if (i + 1 < str.size()) {
                        let next = str.charAt(i + 1)
                        if (next == ' ' || next == '\t' || next == '\n' || next == '\r') { return true }
                    }
                    i += 1
                case '#' => return true
                case '`' => return true
                case '\'' => return true
                case '-' =>
                    // 检查文档分隔符 ---
                    if (i + 2 < str.size() && str.charAt(i + 1) == '-' && str.charAt(i + 2) == '-') {
                        if (i + 3 >= str.size()) { return true }
                        let after = str.charAt(i + 3)
                        if (after == ' ' || after == '\t' || after == '\r' || after == '\n' ||
                            after == '[' || after == ']' || after == '{' || after == '}' || after == ',') {
                            return true
                        }
                    }
                    if (i == 0 && stringIsNumber(str)) { return true }
                    i += 1
                case '.' =>
                    if (i + 2 < str.size() && str.charAt(i + 1) == '.' && str.charAt(i + 2) == '.') {
                        if (i + 3 >= str.size()) { return true }
                        let after = str.charAt(i + 3)
                        if (after == ' ' || after == '\t' || after == '\r' || after == '\n' ||
                            after == '[' || after == ']' || after == '{' || after == '}' || after == ',') {
                            return true
                        }
                    }
                    if (i == 0 && stringIsNumber(str)) { return true }
                    i += 1
                case '0' | '1' | '2' | '3' | '4' | '5' | '6' | '7' | '8' | '9' =>
                    if (i == 0 && stringIsNumber(str)) { return true }
                    i += 1
                case '+' =>
                    if (i == 0 && stringIsNumber(str)) { return true }
                    i += 1
                case _ =>
                    if (c <= 0x1f || c == 0x22 || c == 0x7f || c == 0x85 || c == 0xa0 || c == 0xa8 || c == 0xa9) {
                        return true
                    }
                    i += 1
            }
        }
        return false
    }

    /// 检测字符串是否为数字
    static func stringIsNumber(str!: BunString): Bool {
        let len = str.size()
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
    static func isInfSuffix(str!: BunString, i!: Int64): Bool {
        if (i + 4 > str.size()) { return false }
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

    public static func run(ctx!: ParserCtx, args!: MarkedArgumentBuffer) {
        ctx.result = try { ctx.toJS(args, ctx.root) } catch(err: Exception) {
            match (err) {
                case _: OutOfMemory =>
                    ctx.result = ctx.global.throwOutOfMemoryValue()
                    return
                case _: JSError =>
                    ctx.result = JsValue.jsUndefined()
                    return
                case _: JSTerminated =>
                    ctx.result = JsValue.jsUndefined()
                    return
                case _: StackOverflow =>
                    ctx.result = ctx.global.throwStackOverflow() ?? JsValue.jsUndefined()
                    return
            }
        }
    }

    public func toJS(args!: MarkedArgumentBuffer, expr!: Expr): JsValue {
        if (!this.stack_check.isSafeToRecurse()) {
            throw Error.StackOverflow
        }

        match (expr.data) {
            case e_null => return JsValue.null()
            case e_boolean(boolean) => return JsValue.jsBoolean(boolean.value)
            case e_number(number) => return JsValue.jsNumber(number.value)
            case e_string(str) =>
                return str.toJS(default_allocator, this.global)
            case e_array =>
                if (let arr <- this.seen_objects.get(expr.data.e_array)) { return arr }

                var arr = JsValue.createEmptyArray(this.global, expr.data.e_array.items.len) 
                args.append(arr)
                this.seen_objects.put(expr.data.e_array, arr) 

                for ((item, _i) in expr.data.e_array.slice().enumerated()) {
                    let i: Int64 = Int64(_i)
                    let value = this.toJS(args, item) 
                    arr.putIndex(this.global, i, value) 
                }
                return arr
            case e_object =>
                if (let obj <- this.seen_objects.get(expr.data.e_object)) { return obj }

                var obj = JsValue.createEmptyObject(this.global, expr.data.e_object.properties.len)
                args.append(obj)
                this.seen_objects.put(expr.data.e_object, obj) 

                for (p in expr.data.e_object.properties.slice()) {
                    let keyExpr = p.key
                    let valueExpr = p.value

                    let key = this.toJS(args, keyExpr) 
                    let value = this.toJS(args, valueExpr) 

                    let keyStr = key.toBunString(this.global)
                    try { obj.putMayBeIndex(this.global, keyStr, value) } catch(_: Exception) {}
                    keyStr.deref()
                }
                return obj
            case _ => return JsValue.jsUndefined()
        }
    }
}

// ============================================================================
// 类型别名
// ============================================================================

// BunString, YAML, ASTMemoryAllocator, Logger, default_allocator 已通过 import 导入，无需重复定义
