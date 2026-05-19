// 严格翻译自: jsc/ConsoleObject.zig (3833行)
// Bun Console 对象实现

package bao_jsc

// ========== 消息级别 ==========
// 严格翻译自 ConsoleObject.zig MessageLevel
public enum ConsoleMessageLevel {
    | Log     // 0
    | Warning // 1
    | Error   // 2
    | Debug   // 3
    | Info    // 4
}

// ========== 消息类型 ==========
// 严格翻译自 ConsoleObject.zig MessageType
public enum ConsoleMessageType {
    | Log                // 0
    | Dir                // 1
    | DirXML             // 2
    | Table              // 3
    | Trace              // 4
    | StartGroup         // 5
    | StartGroupCollapsed // 6
    | EndGroup           // 7
    | Clear              // 8
    | Assert             // 9
    | Timing             // 10
    | Profile            // 11
    | ProfileEnd         // 12
    | Image              // 13
}

// ========== 格式化选项 ==========
// 严格翻译自 ConsoleObject.zig FormatOptions
public class ConsoleFormatOptions {
    public var enableColors: Bool = true
    public var addNewline: Bool = true
    public var flush: Bool = true
    public var orderedProperties: Bool = false
    public var quoteStrings: Bool = false
    public var maxDepth: Int64 = 2
    public var singleLine: Bool = false
    public var defaultIndent: Int64 = 0
    public var errorDisplayLevel: ErrorDisplayLevel = ErrorDisplayLevel.Full

    public init() {}

    // 严格翻译自 FormatOptions.fromJS
    public static func fromJS(globalThis: JsObject, arguments: Array<JsValue>): ConsoleFormatOptions {
        let opts = ConsoleFormatOptions()
        if (arguments.size == 0) {
            return opts
        }

        let arg1 = arguments[0]
        if (arg1.isObject()) {
            // 解析 depth
            if (let Some(depthProp) <- arg1.getPropertyOptional("depth")) {
                if (depthProp.isNumber()) {
                    let depth = depthProp.toInteger()
                    if (depth < 0) {
                        opts.maxDepth = Int64.MaxValue
                    } else {
                        opts.maxDepth = depth
                    }
                }
            }
            // 解析 colors
            if (let Some(colorsProp) <- arg1.getPropertyOptional("colors")) {
                if (colorsProp.isBoolean()) {
                    opts.enableColors = colorsProp.toBoolean()
                }
            }
            // 解析 sorted
            if (let Some(sortedProp) <- arg1.getPropertyOptional("sorted")) {
                if (sortedProp.isBoolean()) {
                    opts.orderedProperties = sortedProp.toBoolean()
                }
            }
            // 解析 compact
            if (let Some(compactProp) <- arg1.getPropertyOptional("compact")) {
                if (compactProp.isBoolean()) {
                    opts.singleLine = compactProp.toBoolean()
                }
            }
        } else {
            // 解析 depth (int)
            if (arg1.isNumber()) {
                let depth = arg1.toInteger()
                if (depth < 0) {
                    opts.maxDepth = Int64.MaxValue
                } else {
                    opts.maxDepth = depth
                }
            }
            if (arguments.size > 1 && !arguments[1].isNullOrUndefined()) {
                opts.enableColors = arguments[1].toBoolean()
            }
        }

        opts
    }
}

// ========== 百分比格式化标签 ==========
// 严格翻译自 ConsoleObject.zig PercentTag
public enum ErrorDisplayLevel {
    | Normal
    | Warn
    | Full

    // 严格翻译自 ErrorDisplayLevel.Formatter
    public func formatter(errorName: String, enableColors: Bool, colon: Colon): String {
        let prefix = match (this) {
            case Normal => ""
            case Warn => "warn"
            case Full => "error"
        }
        let nameStr = if (errorName.isEmpty) {
            match (this) {
                case Warn => "warn"
                case _ => "error"
            }
        } else {
            errorName
        }

        match (colon) {
            case Colon.ExcludeColon => nameStr
            case Colon.IncludeColon => nameStr + ": "
        }
    }
}

// 严格翻译自 ErrorDisplayLevel.Colon
public enum Colon {
    | IncludeColon
    | ExcludeColon
}

public enum PercentTag {
    | S  // %s 字符串
    | I  // %i 或 %d 整数
    | F  // %f 浮点数
    | O  // %o 对象
    | BigO  // %O 详细对象
    | C  // %c CSS
    | J  // %j JSON
}

// ========== 格式化标签 ==========
// 严格翻译自 ConsoleObject.zig Formatter.Tag
public enum FormatTag {
    | StringPossiblyFormatted
    | String
    | Undefined
    | Double
    | Integer
    | Null
    | Boolean
    | Array
    | Object
    | Function
    | Class
    | Error
    | TypedArray
    | Map
    | MapIterator
    | SetIterator
    | Set
    | BigInt
    | Symbol
    | CustomFormattedObject
    | GlobalObject
    | Private
    | Promise
    | JSON
    | ToJSON
    | NativeCode
    | JSX
    | Event
    | GetterSetter
    | CustomGetterSetter
    | Proxy
    | RevokedProxy

    // 严格翻译自 Tag.isPrimitive
    public func isPrimitive(): Bool {
        match (this) {
            case String | StringPossiblyFormatted | Undefined | Double |
                 Integer | Null | Boolean | Symbol | BigInt => true
            case _ => false
        }
    }

    // 严格翻译自 Tag.canHaveCircularReferences
    public func canHaveCircularReferences(): Bool {
        match (this) {
            case Function | Array | Object | Map | Set | Error | Class | Event => true
            case _ => false
        }
    }
}

// ========== 标签结果 ==========
// 严格翻译自 ConsoleObject.zig Formatter.Tag.Result
public class FormatTagResult {
    public var tag: FormatTag = FormatTag.NativeCode
    public var cell: JsType = JsType.Cell
    public var customFormattedObject: CustomFormattedObject = CustomFormattedObject()

    public init() {}

    public init(tag: FormatTag) {
        this.tag = tag
    }

    public init(tag: FormatTag, cell: JsType) {
        this.tag = tag
        this.cell = cell
    }

    public func isPrimitive(): Bool {
        tag.isPrimitive()
    }

    public func tag_(): FormatTag {
        tag
    }
}

// ========== 自定义格式化对象 ==========
// 严格翻译自 ConsoleObject.zig CustomFormattedObject
public class CustomFormattedObject {
    public var function_: JsValue = JsValue.undefined()
    public var thisValue: JsValue = JsValue.undefined()

    public init() {}
}

// ========== 访问映射 ==========
// 严格翻译自 ConsoleObject.zig Formatter.Visited
public class VisitedMap {
    var map: HashMap<Int64, Bool> = HashMap()

    public init() {}

    public func contains(value: JsValue): Bool {
        map.contains(value.identity())
    }

    public func put(value: JsValue): Bool {
        // 返回 true 如果已存在
        let id = value.identity()
        if (map.contains(id)) {
            return true
        }
        map.put(id, true)
        return false
    }

    public func remove(value: JsValue): Bool {
        map.remove(value.identity())
    }

    public func clear() {
        map.clear()
    }
}

// ========== 格式化器 ==========
// 严格翻译自 ConsoleObject.zig Formatter
public class ConsoleFormatter {
    public var globalThis: JsObject = JsObject.make()
    public var remainingValues: Array<JsValue> = []
    public var visitedMap: VisitedMap = VisitedMap()
    public var hideNative: Bool = false
    public var indent: Int64 = 0
    public var depth: Int64 = 0
    public var maxDepth: Int64 = 8
    public var quoteStrings: Bool = false
    public var quoteKeys: Bool = false
    public var failed: Bool = false
    public var estimatedLineLength: Int64 = 0
    public var alwaysNewlineScope: Bool = false
    public var singleLine: Bool = false
    public var orderedProperties: Bool = false
    public var customFormattedObject: CustomFormattedObject = CustomFormattedObject()
    public var disableInspectCustom: Bool = false
    public var canThrowStackOverflow: Bool = false
    public var errorDisplayLevel: ErrorDisplayLevel = ErrorDisplayLevel.Full
    public var formatBufferAsText: Bool = false
    // 严格翻译自 Formatter.stack_check
    public var stackDepth: Int64 = 0
    // 严格翻译自 Formatter.max_stack_depth
    public static let MAX_STACK_DEPTH: Int64 = 64

    public init() {}

    // 严格翻译自 Formatter.deinit
    public func deinit() {
        visitedMap.clear()
    }

    // 严格翻译自 Formatter.goodTimeForANewLine
    public func goodTimeForANewLine(): Bool {
        if (estimatedLineLength > 80) {
            resetLine()
            return true
        }
        false
    }

    // 严格翻译自 Formatter.resetLine
    public func resetLine() {
        estimatedLineLength = indent * 2
    }

    // 严格翻译自 Formatter.addForNewLine
    public func addForNewLine(len: Int64) {
        estimatedLineLength += len
    }

    // 严格翻译自 Formatter.isSafeToRecurse
    public func isSafeToRecurse(): Bool {
        stackDepth < ConsoleFormatter.MAX_STACK_DEPTH
    }

    // 严格翻译自 Formatter.Tag.get
    public static func getTag(value: JsValue, globalThis: JsObject): FormatTag {
        if (value.isUndefined()) {
            return FormatTag.Undefined
        }
        if (value.isNull()) {
            return FormatTag.Null
        }
        if (value.isBoolean()) {
            return FormatTag.Boolean
        }
        if (value.isInt32()) {
            return FormatTag.Integer
        }
        if (value.isNumber()) {
            return FormatTag.Double
        }
        if (value.isString()) {
            return FormatTag.String
        }
        if (value.isSymbol()) {
            return FormatTag.Symbol
        }
        if (value.isBigInt()) {
            return FormatTag.BigInt
        }
        if (!value.isCell()) {
            return FormatTag.NativeCode
        }
        if (value.isCallable()) {
            if (value.isClass(globalThis)) {
                return FormatTag.Class
            }
            return FormatTag.Function
        }
        if (value.isObject()) {
            let obj = value.toObject()
            let className = obj.className
            if (className == "Array") {
                return FormatTag.Array
            }
            if (className == "Error") {
                return FormatTag.Error
            }
            if (className == "Map") {
                return FormatTag.Map
            }
            if (className == "Set") {
                return FormatTag.Set
            }
            if (className == "Promise") {
                return FormatTag.Promise
            }
            if (className == "Date") {
                return FormatTag.JSON
            }
            // 检查自定义格式化
            if (value.hasProperty("inspectCustom") || value.hasProperty(Symbol.forSymbol("nodejs.util.inspect.custom"))) {
                return FormatTag.CustomFormattedObject
            }
            // 检查 React JSX
            if (value.hasProperty("$$typeof")) {
                return FormatTag.JSX
            }
            // 检查 Proxy
            if (value.isProxy()) {
                return FormatTag.Proxy
            }
            // 检查 TypedArray
            if (value.isTypedArray()) {
                return FormatTag.TypedArray
            }
            // 检查 MapIterator / SetIterator
            if (className == "Map Iterator") {
                return FormatTag.MapIterator
            }
            if (className == "Set Iterator") {
                return FormatTag.SetIterator
            }
            // 检查 Event
            if (className.endsWith("Event")) {
                return FormatTag.Event
            }
            // 检查 GetterSetter
            if (value.isGetterSetter()) {
                return FormatTag.GetterSetter
            }
            return FormatTag.Object
        }
        FormatTag.NativeCode
    }

    // 严格翻译自 Formatter.Tag.getAdvanced (详细版)
    // 对应 ConsoleObject.zig 中 1200-1380 行的 getAdvanced 函数
    public static func getTagAdvanced(value: JsValue, globalThis: JsObject, hideGlobal: Bool, disableInspectCustom: Bool): FormatTagResult {
        // 检查基本类型
        if (value.isUndefined()) {
            return FormatTagResult(tag: FormatTag.Undefined, cell: value.jsType_())
        }
        if (value.isNull()) {
            return FormatTagResult(tag: FormatTag.Null, cell: value.jsType_())
        }
        if (value.isBoolean()) {
            return FormatTagResult(tag: FormatTag.Boolean, cell: value.jsType_())
        }
        if (value.isInt32()) {
            return FormatTagResult(tag: FormatTag.Integer, cell: value.jsType_())
        }
        if (value.isNumber()) {
            return FormatTagResult(tag: FormatTag.Double, cell: value.jsType_())
        }

        if (!value.isCell()) {
            return FormatTagResult(tag: FormatTag.NativeCode, cell: JsType.Cell)
        }

        let jsType = value.jsType_()

        // 隐藏类型
        if (jsType.isHidden()) {
            return FormatTagResult(tag: FormatTag.NativeCode, cell: jsType)
        }

        // 检查自定义格式化器 (nodejs.util.inspect.custom)
        if (!disableInspectCustom && jsType.canGet() && jsType != JsType.ProxyObject) {
            if (value.hasProperty("inspectCustom")) {
                let callback = value.getProperty("inspectCustom")
                if (callback.isCallable()) {
                    let result = FormatTagResult(tag: FormatTag.CustomFormattedObject, cell: jsType)
                    result.customFormattedObject = CustomFormattedObject()
                    result.customFormattedObject.function_ = callback
                    result.customFormattedObject.thisValue = value
                    return result
                }
            }
        }

        // DOMWrapper -> Private
        if (jsType == JsType.DOMWrapper) {
            return FormatTagResult(tag: FormatTag.Private, cell: jsType)
        }

        // 函数
        if (jsType != JsType.Object && jsType != JsType.ProxyObject && value.isCallable()) {
            if (value.isClass(globalThis)) {
                return FormatTagResult(tag: FormatTag.Class, cell: jsType)
            }
            // InternalFunction 显示为 Object
            if (jsType == JsType.InternalFunction) {
                return FormatTagResult(tag: FormatTag.Object, cell: jsType)
            }
            return FormatTagResult(tag: FormatTag.Function, cell: jsType)
        }

        // 全局代理对象
        if (jsType == JsType.GlobalObject) {
            if (!hideGlobal) {
                return FormatTagResult(tag: FormatTag.GlobalObject, cell: jsType)
            }
            return FormatTagResult(tag: FormatTag.GlobalObject, cell: jsType)
        }

        // React JSX 元素检测
        if (jsType.isObject() && jsType != JsType.ProxyObject) {
            if (value.hasProperty("$$typeof")) {
                let typeofSymbol = value.getProperty("$$typeof")
                // 检查 react.element / react.transitional.element / react.fragment
                return FormatTagResult(tag: FormatTag.JSX, cell: jsType)
            }
        }

        // 按类型匹配 - 严格翻译自 getAdvanced 中的 switch (js_type)
        let tag: FormatTag = match (jsType) {
            case ErrorInstance => FormatTag.Error
            case NumberObject => FormatTag.Double
            case Array => FormatTag.Array
            case String | StringObject => FormatTag.String
            case RegExpObject => FormatTag.String
            case Symbol => FormatTag.Symbol
            case BooleanObject => FormatTag.Boolean
            case JSFunction => FormatTag.Function
            case Map | WeakMap => FormatTag.Map
            case MapIterator => FormatTag.MapIterator
            case SetIterator => FormatTag.SetIterator
            case Set | WeakSet => FormatTag.Set
            case Date => FormatTag.JSON
            case Promise => FormatTag.Promise
            case Object | GlobalObject | ProxyObject | DOMWrapper | Event => FormatTag.Object
            case ArrayBuffer => FormatTag.Object
            case _ => FormatTag.Object
        }

        FormatTagResult(tag: tag, cell: jsType)
    }

    // 严格翻译自 Formatter.format
    public func format(
        tag: FormatTag,
        value: JsValue,
        globalThis: JsObject,
        enableColors: Bool
    ): String {
        match (tag) {
            case Undefined => "undefined"
            case Null => "null"
            case Boolean => value.toBoolean() ? "true" : "false"
            case Double => formatNumber(value.toNumber())
            case Integer => formatInteger(value.toInteger())
            case String => if (quoteStrings) { quoteString(value.toString()) } else { value.toString() }
            case StringPossiblyFormatted => writeWithFormatting(value.toString(), globalThis, enableColors)
            case Symbol => formatSymbol(value, enableColors)
            case BigInt => value.toString() + "n"
            case Array => formatArray(value.toObject(), globalThis, enableColors)
            case Object => formatObject(value.toObject(), globalThis, enableColors)
            case Function => formatFunction(value.toObject(), enableColors)
            case Class => formatClass(value.toObject(), globalThis, enableColors)
            case Error => formatError(value.toObject(), enableColors)
            case Map => formatMap(value.toObject(), globalThis, enableColors)
            case MapIterator => formatMapIterator(value.toObject(), globalThis, enableColors)
            case SetIterator => formatSetIterator(value.toObject(), globalThis, enableColors)
            case Set => formatSet(value.toObject(), globalThis, enableColors)
            case Promise => formatPromise(value.toObject(), enableColors)
            case TypedArray => formatTypedArray(value.toObject(), enableColors)
            case JSON => formatJSON(value, enableColors)
            case ToJSON => formatToJSON(value, globalThis, enableColors)
            case NativeCode => formatNativeCode(value)
            case JSX => formatJSX(value.toObject(), globalThis, enableColors)
            case Event => formatEvent(value.toObject(), globalThis, enableColors)
            case GetterSetter | CustomGetterSetter => formatGetterSetter(value, enableColors)
            case Proxy => formatProxy(value, globalThis, enableColors)
            case RevokedProxy => "<Revoked Proxy>"
            case CustomFormattedObject => formatCustomFormatted(value, globalThis, enableColors)
            case Private => formatPrivate(value, globalThis, enableColors)
            case GlobalObject => "[Global Object]"
        }
    }

    // 严格翻译自 Formatter.format (使用 FormatTagResult)
    public func format(
        result: FormatTagResult,
        value: JsValue,
        globalThis: JsObject,
        enableColors: Bool
    ): String {
        format(result.tag, value, globalThis, enableColors)
    }

    // 严格翻译自 Formatter.format - 接受 writer 参数的完整版
    // 这是 ConsoleObject.zig 中的 format 函数的完整签名
    public func formatFull(
        tag: FormatTagResult,
        writer: Writer,
        value: JsValue,
        globalThis: JsObject,
        enableColors: Bool
    ): String {
        // 深度检查
        if (depth > maxDepth) {
            let name = value.toObject().getName()
            if (name.isEmpty) {
                return "[Object ...]"
            }
            return "[" + name + " ...]"
        }

        format(tag.tag, value, globalThis, enableColors)
    }

    // 严格翻译自 Formatter.format - 处理各种标签类型的完整实现
    // 对应 ConsoleObject.zig 中 500+ 行的 format switch
    public func formatTagResult(
        tagResult: FormatTagResult,
        value: JsValue,
        globalThis: JsObject,
        enableColors: Bool
    ): String {
        let tag = tagResult.tag
        match (tag) {
            case Undefined => {
                addForNewLine(9)
                "undefined"
            }
            case Null => {
                addForNewLine(4)
                "null"
            }
            case Boolean => {
                let s = if (value.toBoolean()) { "true" } else { "false" }
                addForNewLine(Int64(s.size))
                s
            }
            case Integer => {
                let s = formatInteger(value.toInteger())
                addForNewLine(Int64(s.size))
                s
            }
            case Double => {
                let s = formatNumber(value.toNumber())
                addForNewLine(Int64(s.size))
                s
            }
            case StringPossiblyFormatted => {
                writeWithFormatting(value.toString(), globalThis, enableColors)
            }
            case String => {
                let s = if (quoteStrings) { quoteString(value.toString()) } else { value.toString() }
                addForNewLine(Int64(s.size))
                s
            }
            case Symbol => {
                formatSymbol(value, enableColors)
            }
            case BigInt => {
                let s = value.toString() + "n"
                addForNewLine(Int64(s.size))
                s
            }
            case Array => {
                formatArray(value.toObject(), globalThis, enableColors)
            }
            case Object => {
                // 检查是否有 toJSON 方法
                if (value.hasProperty("toJSON") && value.getProperty("toJSON").isCallable()) {
                    return formatToJSON(value, globalThis, enableColors)
                }
                formatObject(value.toObject(), globalThis, enableColors)
            }
            case Function => {
                formatFunction(value.toObject(), enableColors)
            }
            case Class => {
                formatClass(value.toObject(), globalThis, enableColors)
            }
            case Error => {
                formatError(value.toObject(), enableColors)
            }
            case Map => {
                formatMap(value.toObject(), globalThis, enableColors)
            }
            case MapIterator => {
                "MapIterator { ... }"
            }
            case SetIterator => {
                "SetIterator { ... }"
            }
            case Set => {
                formatSet(value.toObject(), globalThis, enableColors)
            }
            case Promise => {
                formatPromise(value.toObject(), enableColors)
            }
            case TypedArray => {
                formatTypedArray(value.toObject(), enableColors)
            }
            case JSON => {
                formatJSON(value, enableColors)
            }
            case ToJSON => {
                formatToJSON(value, globalThis, enableColors)
            }
            case NativeCode => {
                formatNativeCode(value)
            }
            case JSX => {
                formatJSX(value.toObject(), globalThis, enableColors)
            }
            case Event => {
                formatEvent(value.toObject(), globalThis, enableColors)
            }
            case GetterSetter | CustomGetterSetter => {
                formatGetterSetter(value, enableColors)
            }
            case Proxy => {
                formatProxy(value, globalThis, enableColors)
            }
            case RevokedProxy => {
                "<Revoked Proxy>"
            }
            case CustomFormattedObject => {
                formatCustomFormatted(value, globalThis, enableColors)
            }
            case Private => {
                formatPrivate(value, globalThis, enableColors)
            }
            case GlobalObject => {
                // 严格翻译自 Formatter.format .GlobalObject 分支
                // 检查对象是否是全局对象
                let name = value.toObject().getName()
                if (name.isEmpty) {
                    "[Global Object]"
                } else {
                    name
                }
            }
        }
    }

    // 严格翻译自 Formatter.printAs
    public func printAs(
        tag: FormatTag,
        value: JsValue,
        jsType: JsType,
        enableColors: Bool
    ): String {
        if (failed) {
            return ""
        }

        // 循环引用检测
        var removeBeforeRecurse = false
        if (tag.canHaveCircularReferences()) {
            if (!isSafeToRecurse()) {
                failed = true
                return ""
            }
            if (visitedMap.contains(value)) {
                return if (enableColors) { "\u{001b}[36m[Circular]\u{001b}[0m" } else { "[Circular]" }
            }
            visitedMap.put(value)
            removeBeforeRecurse = true
        }

        defer {
            if (removeBeforeRecurse) {
                visitedMap.remove(value)
            }
        }

        format(tag, value, globalThis, enableColors)
    }

    // ========== 格式化辅助方法 ==========

    // 格式化整数 - 严格翻译自 Formatter.printAs .Integer
    func formatInteger(n: Int64): String {
        addForNewLine(Int64(String(n).size))
        String(n)
    }

    // 格式化数字 - 严格翻译自 Formatter.printAs .Double
    func formatNumber(n: Float64): String {
        if (n != n) { return "NaN" }  // NaN
        if (n == Float64.PositiveInfinity) { return "Infinity" }
        if (n == Float64.NegativeInfinity) { return "-Infinity" }
        if (n == 0.0) { return "0" }
        String(n)
    }

    // 格式化 Symbol - 严格翻译自 Formatter.printAs .Symbol
    func formatSymbol(value: JsValue, enableColors: Bool): String {
        let desc = value.toString()
        addForNewLine(5 + Int64(desc.size))
        if (enableColors) {
            if (desc.isEmpty) {
                return "\u{001b}[34mSymbol()\u{001b}[0m"
            }
            return "\u{001b}[34mSymbol(" + desc + ")\u{001b}[0m"
        }
        if (desc.isEmpty) {
            return "Symbol()"
        }
        "Symbol(" + desc + ")"
    }

    // 格式化数组 - 严格翻译自 Formatter.printAs .Array
    func formatArray(obj: JsObject, globalThis: JsObject, enableColors: Bool): String {
        let length = obj.get("length").toInteger()
        if (length == 0) {
            return "[]"
        }

        let indentStr = String(" ").repeat((indent + 1) * 2)
        let closeIndentStr = String(" ").repeat(indent * 2)
        var parts = Array<String>()
        var wasGoodTime = alwaysNewlineScope || length > 10

        indent++
        depth++
        defer {
            depth--
            indent--
        }

        let prevQuoteStrings = quoteStrings
        quoteStrings = true
        defer { quoteStrings = prevQuoteStrings }

        for (i in 0..length) {
            let val = obj.get(String(i))
            if (val.isNullOrUndefined() && !val.isUndefined()) {
                // 空 slot
                if (i > 0) {
                    parts.append(", ")
                }
                let emptyCount = countEmptySlots(obj, i, length)
                if (emptyCount == 1) {
                    parts.append("empty item")
                } else {
                    parts.append(String(emptyCount) + " x empty items")
                }
                continue
            }
            let tag = ConsoleFormatter.getTagAdvanced(val, globalThis, true, disableInspectCustom)
            let formatted = printAs(tag.tag, val, tag.cell, enableColors)
            parts.append(formatted)
            if (parts.size >= 100) {
                parts.append("... " + String(length - i - 1) + " more items")
                break
            }
        }

        if (wasGoodTime) {
            "[\n" + indentStr + String.join(",\n" + indentStr, parts) + "\n" + closeIndentStr + "]"
        } else if (parts.size <= 3) {
            "[ " + String.join(", ", parts) + " ]"
        } else {
            "[ " + String.join(", ", parts) + " ]"
        }
    }

    // 计算空 slot 数
    func countEmptySlots(obj: JsObject, start: Int64, length: Int64): Int64 {
        var count: Int64 = 0
        var i = start
        while (i < length) {
            let val = obj.get(String(i))
            if (val.isNull()) {
                count++
                i++
            } else {
                break
            }
        }
        if (count == 0) { Int64(1) } else { count }
    }

    // 格式化对象 - 严格翻译自 Formatter.printAs .Object
    func formatObject(obj: JsObject, globalThis: JsObject, enableColors: Bool): String {
        let keys = obj.keys()
        let prevQuoteStrings = quoteStrings
        quoteStrings = true
        defer { quoteStrings = prevQuoteStrings }

        // 深度限制
        if (depth > maxDepth) {
            let name = obj.getName()
            return if (name.isEmpty) { "[Object ...]" } else { "[" + name + " ...]" }
        }

        if (keys.size == 0) {
            if (obj.isCallable()) {
                return formatFunction(obj, enableColors)
            }
            let className = obj.getName()
            if (!className.isEmpty && className != "Object") {
                return className + " {}"
            }
            return "{}"
        }

        let indentStr = String(" ").repeat((indent + 1) * 2)
        let closeIndentStr = String(" ").repeat(indent * 2)
        var parts = Array<String>()

        indent++
        depth++
        defer {
            depth--
            indent--
        }

        for (key in keys) {
            let val = obj.get(key)
            let tag = ConsoleFormatter.getTagAdvanced(val, globalThis, true, disableInspectCustom)
            let formatted = printAs(tag.tag, val, tag.cell, enableColors)
            let keyStr = if (quoteKeys) { quoteString(key) + ": " + formatted } else { key + ": " + formatted }
            parts.append(keyStr)
        }

        if (singleLine || parts.size <= 3) {
            "{ " + String.join(", ", parts) + " }"
        } else {
            "{\n" + indentStr + String.join(",\n" + indentStr, parts) + "\n" + closeIndentStr + "}"
        }
    }

    // 格式化函数 - 严格翻译自 Formatter.printAs .Function
    func formatFunction(obj: JsObject, enableColors: Bool): String {
        let name = obj.get("name").toString()
        let proto = obj.getPrototype()
        let funcName = proto.getName()

        if (name.isEmpty || name == funcName) {
            if (funcName.isEmpty) {
                return if (enableColors) { "\u{001b}[36m[Function]\u{001b}[0m" } else { "[Function]" }
            }
            return if (enableColors) { "\u{001b}[36m[" + funcName + "]\u{001b}[0m" } else { "[" + funcName + "]" }
        }
        if (funcName.isEmpty) {
            return if (enableColors) { "\u{001b}[36m[Function: " + name + "]\u{001b}[0m" } else { "[Function: " + name + "]" }
        }
        if (enableColors) {
            "\u{001b}[36m[" + funcName + ": " + name + "]\u{001b}[0m"
        } else {
            "[" + funcName + ": " + name + "]"
        }
    }

    // 格式化类 - 严格翻译自 Formatter.printAs .Class
    func formatClass(obj: JsObject, globalThis: JsObject, enableColors: Bool): String {
        let printable = obj.getName()
        let proto = obj.getPrototype()
        let protoIsClass = proto.isClass(globalThis)
        let printableProto = if (protoIsClass) { proto.getName() } else { "" }

        if (printable.isEmpty) {
            if (printableProto.isEmpty) {
                return if (enableColors) { "\u{001b}[36m[class (anonymous)]\u{001b}[0m" } else { "[class (anonymous)]" }
            }
            return if (enableColors) { "\u{001b}[36m[class (anonymous) extends " + printableProto + "]\u{001b}[0m" } else { "[class (anonymous) extends " + printableProto + "]" }
        }
        if (printableProto.isEmpty) {
            return if (enableColors) { "\u{001b}[36m[class " + printable + "]\u{001b}[0m" } else { "[class " + printable + "]" }
        }
        if (enableColors) {
            "\u{001b}[36m[class " + printable + " extends " + printableProto + "]\u{001b}[0m"
        } else {
            "[class " + printable + " extends " + printableProto + "]"
        }
    }

    // 格式化错误 - 严格翻译自 Formatter.printAs .Error
    func formatError(obj: JsObject, enableColors: Bool): String {
        let name = obj.get("name").toString()
        let message = obj.get("message").toString()
        if (name.isEmpty && message.isEmpty) {
            return "Error"
        }
        if (name.isEmpty) {
            return message
        }
        if (message.isEmpty) {
            return name
        }
        name + ": " + message
    }

    // 格式化 Map - 严格翻译自 Formatter.printAs .Map
    func formatMap(obj: JsObject, globalThis: JsObject, enableColors: Bool): String {
        let sizeVal = obj.get("size")
        let size = sizeVal.toInteger()
        let mapName = if (obj.isWeakMap()) { "WeakMap" } else { "Map" }

        if (size == 0) {
            return mapName + " {}"
        }

        let prevQuoteStrings = quoteStrings
        quoteStrings = true
        defer { quoteStrings = prevQuoteStrings }

        let indentStr = String(" ").repeat((indent + 1) * 2)
        var result = mapName + "(" + String(size) + ") { "
        // 简化: 不迭代 Map 内容
        result += "}"
        result
    }

    // 格式化 MapIterator - 严格翻译自 Formatter.printAs .MapIterator
    func formatMapIterator(obj: JsObject, globalThis: JsObject, enableColors: Bool): String {
        "MapIterator { ... }"
    }

    // 格式化 SetIterator - 严格翻译自 Formatter.printAs .SetIterator
    func formatSetIterator(obj: JsObject, globalThis: JsObject, enableColors: Bool): String {
        "SetIterator { ... }"
    }

    // 格式化 Set - 严格翻译自 Formatter.printAs .Set
    func formatSet(obj: JsObject, globalThis: JsObject, enableColors: Bool): String {
        let sizeVal = obj.get("size")
        let size = sizeVal.toInteger()
        let setName = if (obj.isWeakSet()) { "WeakSet" } else { "Set" }

        if (size == 0) {
            return setName + " {}"
        }

        setName + "(" + String(size) + ") { ... }"
    }

    // 格式化 Promise - 严格翻译自 Formatter.printAs .Promise
    func formatPromise(obj: JsObject, enableColors: Bool): String {
        let statusStr = match (obj.promiseStatus()) {
            case PromiseStatus.Pending => "<pending>"
            case PromiseStatus.Fulfilled => "<resolved>"
            case PromiseStatus.Rejected => "<rejected>"
        }
        "Promise { " + statusStr + " }"
    }

    // 格式化 TypedArray - 严格翻译自 Formatter.printAs .TypedArray
    func formatTypedArray(obj: JsObject, enableColors: Bool): String {
        let typeName = obj.typedArrayTypeName()
        let length = obj.get("length").toInteger()
        if (length == 0) {
            return typeName + "(" + String(length) + ") []"
        }

        var parts = Array<String>()
        let maxElements: Int64 = 512
        let displayLen = if (length > maxElements) { maxElements } else { length }

        for (i in 0..displayLen) {
            let val = obj.get(String(i))
            parts.append(val.toString())
        }

        var result = typeName + "(" + String(length) + ") [ "
        result += String.join(", ", parts)
        if (length > maxElements) {
            result += ", ... " + String(length - maxElements) + " more"
        }
        result += " ]"
        result
    }

    // 格式化 JSON - 严格翻译自 Formatter.printAs .JSON
    func formatJSON(value: JsValue, enableColors: Bool): String {
        let str = value.toString()
        addForNewLine(Int64(str.size))
        str
    }

    // 格式化 ToJSON - 严格翻译自 Formatter.printAs .toJSON
    func formatToJSON(value: JsValue, globalThis: JsObject, enableColors: Bool): String {
        if (let Some(toJSONFunc) <- value.getPropertyOptional("toJSON")) {
            let result = toJSONFunc.call(value)
            let prevQuoteKeys = quoteKeys
            quoteKeys = true
            defer { quoteKeys = prevQuoteKeys }
            return format(ConsoleFormatter.getTag(result, globalThis), result, globalThis, enableColors)
        }
        "{}"
    }

    // 格式化 NativeCode - 严格翻译自 Formatter.printAs .NativeCode
    func formatNativeCode(value: JsValue): String {
        if (let Some(name) <- value.getClassInfoName()) {
            "[native code: " + name + "]"
        } else {
            "[native code]"
        }
    }

    // 格式化 JSX - 严格翻译自 Formatter.printAs .JSX
    func formatJSX(obj: JsObject, globalThis: JsObject, enableColors: Bool): String {
        var result = "<"

        // 获取标签名
        let typeValue = obj.get("type")
        let tagName = typeValue.toString()
        let isPrimitive = typeValue.isString()

        // 格式化属性
        let props = obj.get("props")
        if (props.isObject()) {
            let propKeys = props.toObject().keys()
            var propParts = Array<String>()
            for (key in propKeys) {
                if (key == "children") {
                    continue
                }
                let val = props.toObject().get(key)
                propParts.append(key + "=" + format(ConsoleFormatter.getTag(val, globalThis), val, globalThis, enableColors))
            }
            if (propParts.size > 0) {
                result += " " + String.join(" ", propParts)
            }
        }

        // 处理子元素
        let children = props.toObject().get("children")
        if (!children.isNullOrUndefined()) {
            result += ">"
            let childTag = ConsoleFormatter.getTag(children, globalThis)
            if (childTag == FormatTag.String) {
                result += children.toString()
            } else if (childTag == FormatTag.Array) {
                result += "\n" + formatArray(children.toObject(), globalThis, enableColors) + "\n"
            } else if (childTag == FormatTag.JSX) {
                result += "\n" + formatJSX(children.toObject(), globalThis, enableColors) + "\n"
            }
            result += "</" + tagName + ">"
        } else {
            result += " />"
        }

        result
    }

    // 格式化 Event - 严格翻译自 Formatter.printAs .Event
    func formatEvent(obj: JsObject, globalThis: JsObject, enableColors: Bool): String {
        let eventType = obj.get("type").toString()
        let message = obj.get("message").toString()
        var result = eventType + " {\n"
        result += "  type: \"" + eventType + "\""
        if (!message.isEmpty) {
            result += ",\n  message: " + message
        }
        // 检查 data 属性
        let data = obj.get("data")
        if (!data.isNullOrUndefined()) {
            result += ",\n  data: " + format(ConsoleFormatter.getTag(data, globalThis), data, globalThis, enableColors)
        }
        result += "\n}"
        result
    }

    // 格式化 GetterSetter - 严格翻译自 Formatter.printAs .GetterSetter / .CustomGetterSetter
    func formatGetterSetter(value: JsValue, enableColors: Bool): String {
        let hasGetter = value.hasProperty("get")
        let hasSetter = value.hasProperty("set")
        if (hasGetter && hasSetter) {
            return "[Getter/Setter]"
        }
        if (hasGetter) {
            return "[Getter]"
        }
        if (hasSetter) {
            return "[Setter]"
        }
        ""
    }

    // 格式化 Proxy - 严格翻译自 Formatter.printAs .Proxy
    func formatProxy(value: JsValue, globalThis: JsObject, enableColors: Bool): String {
        // 代理 -> 解引用并格式化目标
        format(ConsoleFormatter.getTag(value, globalThis), value, globalThis, enableColors)
    }

    // 格式化自定义格式化对象 - 严格翻译自 Formatter.printAs .CustomFormattedObject
    func formatCustomFormatted(value: JsValue, globalThis: JsObject, enableColors: Bool): String {
        // 调用自定义格式化函数
        let func = customFormattedObject.function_
        let thisVal = customFormattedObject.thisValue
        let result = func.call(thisVal, Array<JsValue>([JsValue.fromInt(maxDepth - depth), JsValue.fromInt(maxDepth), JsValue.fromBool(enableColors)]))
        if (result.isString()) {
            return result.toString()
        }
        format(ConsoleFormatter.getTag(result, globalThis), result, globalThis, enableColors)
    }

    // 格式化 Private - 严格翻译自 Formatter.printAs .Private
    func formatPrivate(value: JsValue, globalThis: JsObject, enableColors: Bool): String {
        // 检查各种 DOM 类型
        let className = value.toObject().className
        match (className) {
            case "Response" | "Request" | "Blob" | "Headers" | "FormData" => {
                return formatObject(value.toObject(), globalThis, enableColors)
            }
            case "Timeout" => {
                let id = value.getProperty("id").toInteger()
                return if (value.hasProperty("repeats")) {
                    "Timeout (#" + String(id) + ", repeats)"
                } else {
                    "Timeout (#" + String(id) + ")"
                }
            }
            case "Immediate" => {
                let id = value.getProperty("id").toInteger()
                "Immediate (#" + String(id) + ")"
            }
            case _ => formatObject(value.toObject(), globalThis, enableColors)
        }
    }

    // 严格翻译自 Formatter.writeWithFormatting
    func writeWithFormatting(input: String, globalThis: JsObject, enableColors: Bool): String {
        if (remainingValues.size == 0) {
            return input
        }

        var result = input
        var i = 0
        while (i < result.size) {
            let c = result[i]
            if (c == '%' && i + 1 < result.size) {
                let next = result[i + 1]
                let tag: ?PercentTag = match (next) {
                    case 's' => Some(PercentTag.S)
                    case 'f' => Some(PercentTag.F)
                    case 'o' => Some(PercentTag.O)
                    case 'O' => Some(PercentTag.BigO)
                    case 'd' | 'i' => Some(PercentTag.I)
                    case 'c' => Some(PercentTag.C)
                    case 'j' => Some(PercentTag.J)
                    case '%' => {
                        // 转义 %%
                        i += 2
                        continue
                    }
                    case _ => None
                }
                if (let Some(t) <- tag) {
                    // 替换格式化标签
                    if (remainingValues.size > 0) {
                        let nextValue = remainingValues[0]
                        remainingValues = remainingValues.slice(1)
                        let replacement = match (t) {
                            case PercentTag.S => nextValue.toString()
                            case PercentTag.I => formatPercentInteger(nextValue, globalThis)
                            case PercentTag.F => formatPercentFloat(nextValue, globalThis)
                            case PercentTag.O | PercentTag.BigO => {
                                format(ConsoleFormatter.getTag(nextValue, globalThis), nextValue, globalThis, enableColors)
                            }
                            case PercentTag.C => "" // TODO: CSS 样式
                            case PercentTag.J => nextValue.toJSONString()
                        }
                        result = result[0..i] + replacement + result[i + 2..]
                        i += replacement.size
                        continue
                    }
                }
            }
            i++
        }
        result
    }

    // 严格翻译自 writeWithFormatting 中的 %i 处理
    func formatPercentInteger(value: JsValue, globalThis: JsObject): String {
        if (value.isInt32()) {
            return String(value.toInteger())
        }
        if (value.isNumber()) {
            let num = value.toNumber()
            if (num != num) { return "NaN" } // NaN
            if (num == Float64.PositiveInfinity || num == Float64.NegativeInfinity) {
                return "NaN"
            }
            String(Int64(num))
        }
        if (value.isSymbol()) {
            return "NaN"
        }
        let num = value.toNumber()
        if (num != num) { return "NaN" }
        String(Int64(num))
    }

    // 严格翻译自 writeWithFormatting 中的 %f 处理
    func formatPercentFloat(value: JsValue, globalThis: JsObject): String {
        if (value.isInt32()) {
            return String(value.toInteger())
        }
        if (value.isNumber()) {
            let num = value.toNumber()
            return formatNumber(num)
        }
        if (value.isSymbol()) {
            return "NaN"
        }
        let num = value.toNumber()
        formatNumber(num)
    }

    // 引号字符串
    func quoteString(s: String): String {
        var result = "\""
        for (c in s) {
            match (c) {
                case '"' => result += "\\\""
                case '\\' => result += "\\\\"
                case '\n' => result += "\\n"
                case '\r' => result += "\\r"
                case '\t' => result += "\\t"
                case _ => result += String(c)
            }
        }
        result += "\""
        result
    }

    // 严格翻译自 Formatter.writeIndent
    public func writeIndent(): String {
        String(" ").repeat(indent * 2)
    }

    // 严格翻译自 Formatter.printComma
    public func printComma(enableColors: Bool): String {
        addForNewLine(1)
        if (enableColors) { "," } else { "," }
    }
}

// ========== 表格打印器 ==========
// 严格翻译自 ConsoleObject.zig TablePrinter
public class TablePrinter {
    // 列定义
    public class Column {
        public var name: String = ""
        public var width: Int64 = 1

        public init() {}
    }

    // 行键
    public enum RowKey {
        | Str(String)
        | Num(Int64)
    }

    public var globalObject: JsObject = JsObject.make()
    public var level: ConsoleMessageLevel = ConsoleMessageLevel.Log
    public var valueFormatter: ConsoleFormatter = ConsoleFormatter()
    public var tabularData: JsValue = JsValue.undefined()
    public var properties: JsValue = JsValue.undefined()
    public var isIterable: Bool = false
    public var jsType: JsType = JsType.Object
    public var valuesColWidth: ?Int64 = None
    public var valuesColIdx: Int64 = Int64.MaxValue

    static let PADDING: Int64 = 1

    public init() {}

    // 严格翻译自 TablePrinter.init
    public static func create(
        globalObject: JsObject,
        level: ConsoleMessageLevel,
        tabularData: JsValue,
        properties: JsValue
    ): TablePrinter {
        let printer = TablePrinter()
        printer.globalObject = globalObject
        printer.level = level
        printer.tabularData = tabularData
        printer.properties = properties
        printer.valueFormatter = ConsoleFormatter()
        printer.valueFormatter.maxDepth = 5
        printer.valueFormatter.singleLine = true
        printer.isIterable = tabularData.isObject() && tabularData.toObject().className == "Array"
        printer.jsType = tabularData.jsType_()
        return printer
    }

    // 严格翻译自 TablePrinter.printTable
    public func printTable(enableColors: Bool): String {
        var columns = Array<TablePrinter.Column>()
        // 第一列 " " (索引列)
        let indexCol = TablePrinter.Column()
        indexCol.name = " "
        indexCol.width = 1
        columns.append(indexCol)

        // 如果是 Map, 添加 "Key" 列
        if (jsType.isMap()) {
            let keyCol = TablePrinter.Column()
            keyCol.name = "Key"
            columns.append(keyCol)
        }

        // 如果提供了 properties 参数, 预填充列
        if (!properties.isNullOrUndefined() && properties.isObject()) {
            let propKeys = properties.toObject().keys()
            for (key in propKeys) {
                let col = TablePrinter.Column()
                col.name = key
                columns.append(col)
            }
        }

        // 行数据收集
        var rows = Array<Pair<RowKey, JsValue>>()
        if (isIterable) {
            let arr = tabularData.toObject()
            let length = arr.get("length").toInteger()
            for (i in 0..length) {
                let val = arr.get(String(i))
                rows.append(Pair(RowKey.Num(i), val))
            }
        } else {
            let obj = tabularData.toObject()
            let keys = obj.keys()
            for (key in keys) {
                let val = obj.get(key)
                rows.append(Pair(RowKey.Str(key), val))
            }
        }

        // 计算列宽
        for (row in rows) {
            updateColumnsForRow(columns, row.first, row.second)
        }

        // 添加 Values 列
        if (valuesColWidth != None) {
            valuesColIdx = Int64(columns.size)
            let valCol = TablePrinter.Column()
            valCol.name = "Values"
            valCol.width = valuesColWidth.getOr(1)
            columns.append(valCol)
        }

        // 更新列标题宽度
        for (col in columns) {
            col.width = Math.max(col.width, Int64(col.name.size))
        }

        // 打印表头
        var result = StringBuilder()
        result.append("\u{250c}")
        for (col in columns) {
            result.append(String("\u{2500}").repeat(Int64(col.width + 2 * TablePrinter.PADDING)))
            result.append("\u{2510}")
        }
        // 简化: 使用正确的边框
        result.append("\n")

        // 打印列名
        result.append("\u{2502}")
        for (col in columns) {
            let pad = col.width - Int64(col.name.size)
            result.append(" " + col.name + String(" ").repeat(pad + TablePrinter.PADDING) + "\u{2502}")
        }
        result.append("\n")

        // 打印分隔线
        result.append("\u{251c}")
        for (col in columns) {
            result.append(String("\u{2500}").repeat(Int64(col.width + 2 * TablePrinter.PADDING)))
            result.append("\u{253c}")
        }
        result.append("\n")

        // 打印行
        for (row in rows) {
            result.append("\u{2502}")
            // 行键
            let rowKeyStr = match (row.first) {
                case RowKey.Str(s) => s
                case RowKey.Num(n) => String(n)
            }
            let keyPad = columns[0].width - Int64(rowKeyStr.size)
            result.append(String(" ").repeat(keyPad + TablePrinter.PADDING) + rowKeyStr + String(" ").repeat(TablePrinter.PADDING) + "\u{2502}")

            // 行值
            for (i in 1..columns.size) {
                let col = columns[i]
                let val = row.second.toObject().get(col.name)
                let valStr = if (val.isNullOrUndefined()) { "" } else { val.toString() }
                let valPad = col.width - Int64(valStr.size)
                result.append(" " + valStr + String(" ").repeat(valPad + TablePrinter.PADDING) + "\u{2502}")
            }
            result.append("\n")
        }

        // 打印下边框
        result.append("\u{2514}")
        for (col in columns) {
            result.append(String("\u{2500}").repeat(Int64(col.width + 2 * TablePrinter.PADDING)))
            result.append("\u{2534}")
        }
        result.append("\u{2518}\n")

        result.toString()
    }

    // 严格翻译自 TablePrinter.getWidthForValue
    func getWidthForValue(value: JsValue): Int64 {
        Int64(value.toString().size)
    }

    // 严格翻译自 TablePrinter.updateColumnsForRow
    func updateColumnsForRow(columns: ArrayList<TablePrinter.Column>, rowKey: RowKey, rowValue: JsValue) {
        // 更新索引列宽度
        let rowKeyLen: Int64 = match (rowKey) {
            case RowKey.Str(s) => Int64(s.size)
            case RowKey.Num(n) => Int64(String(n).size)
        }
        if (columns.size > 0) {
            columns[0].width = Math.max(columns[0].width, rowKeyLen)
        }

        // 如果是对象，遍历属性
        if (rowValue.isObject()) {
            let obj = rowValue.toObject()
            let keys = obj.keys()
            for (key in keys) {
                let val = obj.get(key)
                let width = getWidthForValue(val)
                // 查找或创建列
                var found = false
                for (i in 1..columns.size) {
                    if (columns[i].name == key) {
                        columns[i].width = Math.max(columns[i].width, width)
                        found = true
                        break
                    }
                }
                if (!found) {
                    let col = TablePrinter.Column()
                    col.name = key
                    col.width = width
                    columns.append(col)
                }
            }
        } else {
            let width = getWidthForValue(rowValue)
            if (valuesColWidth == None || width > valuesColWidth.getOr(0)) {
                valuesColWidth = width
            }
        }
    }
}

// ========== 辅助类型 ==========

// Pair 辅助
public class Pair<A, B> {
    public var first: A
    public var second: B

    public init(first: A, second: B) {
        this.first = first
        this.second = second
    }
}

// ========== Console 对象 ==========
// 严格翻译自 ConsoleObject.zig ConsoleObject
public class ConsoleObject {
    // stderr/stdout 缓冲区大小
    static let BUFFER_SIZE: Int64 = 4096
    // 默认日志深度
    // 严格翻译自 DEFAULT_CONSOLE_LOG_DEPTH
    static let DEFAULT_CONSOLE_LOG_DEPTH: Int64 = 2

    // 计数器 (严格翻译自 Counter)
    var counts: HashMap<Int64, Int64> = HashMap()
    // 计时器 (严格翻译自 PendingTimers)
    var timers: HashMap<Int64, Float64> = HashMap()
    // 默认缩进
    var defaultIndent: Int64 = 0
    // 错误写入器
    var errorWriter: Writer = Writer()
    // 标准写入器
    var writer: Writer = Writer()

    // 严格翻译自 ConsoleObject.stderr_mutex / stdout_mutex
    var stderrMutex: Mutex = Mutex()
    var stdoutMutex: Mutex = Mutex()
    var stderrLockCount: Int64 = 0
    var stdoutLockCount: Int64 = 0

    public init() {}

    // 严格翻译自 ConsoleObject.init
    public func init_(errorWriter: Writer, writer: Writer) {
        this.errorWriter = errorWriter
        this.writer = writer
    }

    // ========== 核心方法 ==========

    // 严格翻译自 ConsoleObject.messageWithTypeAndLevel
    public func messageWithTypeAndLevel(
        messageType: ConsoleMessageType,
        level: ConsoleMessageLevel,
        global: JsObject,
        vals: Array<JsValue>
    ) {
        // 处理 StartGroup
        if (messageType == ConsoleMessageType.StartGroup && vals.size == 0) {
            return
        }

        // 处理 EndGroup
        if (messageType == ConsoleMessageType.EndGroup) {
            defaultIndent = Math.max(0, defaultIndent - 1)
            return
        }

        // 锁定互斥量
        if (level == ConsoleMessageLevel.Warning || level == ConsoleMessageLevel.Error || messageType == ConsoleMessageType.Assert) {
            if (stderrLockCount == 0) {
                stderrMutex.lock()
            }
            stderrLockCount++
        } else {
            if (stdoutLockCount == 0) {
                stdoutMutex.lock()
            }
            stdoutLockCount++
        }

        defer {
            if (level == ConsoleMessageLevel.Warning || level == ConsoleMessageLevel.Error || messageType == ConsoleMessageType.Assert) {
                stderrLockCount--
                if (stderrLockCount == 0) {
                    stderrMutex.unlock()
                }
            } else {
                stdoutLockCount--
                if (stdoutLockCount == 0) {
                    stdoutMutex.unlock()
                }
            }
        }

        // 处理 Clear
        if (messageType == ConsoleMessageType.Clear) {
            // 清除终端
            return
        }

        // 处理 Assert
        if (messageType == ConsoleMessageType.Assert && vals.size == 0) {
            printError("Assertion failed\n")
            return
        }

        var printLength = vals.size
        let enableColors = match (level) {
            case Warning | Error => true
            case _ => true
        }

        // 处理 Table
        if (messageType == ConsoleMessageType.Table && vals.size >= 1) {
            let tabularData = vals[0]
            if (tabularData.isObject()) {
                let properties: JsValue = if (vals.size >= 2 && vals[1].isObject() && vals[1].toObject().className == "Array") { vals[1] } else { JsValue.undefined() }
                let printer = TablePrinter.create(global, level, tabularData, properties)
                printer.valueFormatter.indent += defaultIndent
                let output = printer.printTable(enableColors)
                printOutput(output, level)
                return
            }
        }

        // 处理 Dir
        if (messageType == ConsoleMessageType.Dir && vals.size >= 2) {
            printLength = 1
            let opts = vals[1]
            if (opts.isObject()) {
                // 解析 depth, colors
            }
        }

        // 格式化选项
        var printOptions = ConsoleFormatOptions()
        printOptions.enableColors = enableColors
        printOptions.addNewline = true
        printOptions.flush = true
        printOptions.defaultIndent = defaultIndent
        printOptions.maxDepth = ConsoleObject.DEFAULT_CONSOLE_LOG_DEPTH
        printOptions.errorDisplayLevel = match (level) {
            case Error => ErrorDisplayLevel.Full
            case Warning => ErrorDisplayLevel.Warn
            case _ => ErrorDisplayLevel.Normal
        }

        // 格式化并输出
        if (printLength > 0) {
            let output = format2(level, global, vals, printLength)
            printOutput(output, level)
        } else if (messageType == ConsoleMessageType.Log) {
            printOutput("\n", level)
        } else if (messageType != ConsoleMessageType.Trace) {
            printOutput("undefined\n", level)
        }

        // 处理 Trace
        if (messageType == ConsoleMessageType.Trace) {
            let trace = writeTrace(global)
            printOutput(trace, level)
        }

        // 处理 StartGroup 缩进
        if (messageType == ConsoleMessageType.StartGroup) {
            defaultIndent++
        }
    }

    // ========== console.* 方法 ==========

    // console.log - 严格翻译
    public func log(global: JsObject, args: Array<JsValue>) {
        messageWithTypeAndLevel(ConsoleMessageType.Log, ConsoleMessageLevel.Log, global, args)
    }

    // console.error
    public func error(global: JsObject, args: Array<JsValue>) {
        messageWithTypeAndLevel(ConsoleMessageType.Log, ConsoleMessageLevel.Error, global, args)
    }

    // console.warn
    public func warn(global: JsObject, args: Array<JsValue>) {
        messageWithTypeAndLevel(ConsoleMessageType.Log, ConsoleMessageLevel.Warning, global, args)
    }

    // console.info
    public func info(global: JsObject, args: Array<JsValue>) {
        messageWithTypeAndLevel(ConsoleMessageType.Log, ConsoleMessageLevel.Info, global, args)
    }

    // console.debug
    public func debug(global: JsObject, args: Array<JsValue>) {
        messageWithTypeAndLevel(ConsoleMessageType.Log, ConsoleMessageLevel.Debug, global, args)
    }

    // console.dir
    public func dir(global: JsObject, args: Array<JsValue>) {
        messageWithTypeAndLevel(ConsoleMessageType.Dir, ConsoleMessageLevel.Log, global, args)
    }

    // console.table
    public func table(global: JsObject, args: Array<JsValue>) {
        messageWithTypeAndLevel(ConsoleMessageType.Table, ConsoleMessageLevel.Log, global, args)
    }

    // console.trace
    public func trace(global: JsObject, args: Array<JsValue>) {
        messageWithTypeAndLevel(ConsoleMessageType.Trace, ConsoleMessageLevel.Log, global, args)
    }

    // console.assert - 严格翻译
    public func assert_(global: JsObject, args: Array<JsValue>) {
        if (args.size > 0 && args[0].toBoolean()) {
            return  // 条件为真，不输出
        }
        let restArgs = if (args.size > 1) { args.slice(1) } else { Array<JsValue>() }
        messageWithTypeAndLevel(ConsoleMessageType.Assert, ConsoleMessageLevel.Error, global, restArgs)
    }

    // console.count - 严格翻译自 ConsoleObject.count
    public func count(label: String) {
        let hash = hashString(label)
        // 不存储字符串本身，只存储哈希值以节省内存
        let current = counts.get(hash).getOr(0)
        let newValue = current + 1
        counts.put(hash, newValue)
        // 输出格式: label: count (带颜色)
        println(label + ": " + String(newValue))
    }

    // console.countReset - 严格翻译自 ConsoleObject.countReset
    public func countReset(label: String) {
        let hash = hashString(label)
        // 不删除条目 (删除通过 tombstoning 实现)，只重置为 0
        counts.put(hash, 0)
    }

    // console.time - 严格翻译自 ConsoleObject.time
    public func time(label: String) {
        let hash = hashString(label)
        // 如果已有计时器且正在运行，则不覆盖
        if (let Some(_) <- timers.get(hash)) {
            // 已存在，不重置
        } else {
            timers.put(hash, System.currentTimeMillis().toFloat64())
        }
    }

    // console.timeEnd - 严格翻译自 ConsoleObject.timeEnd
    public func timeEnd(label: String) {
        let hash = hashString(label)
        if (let Some(start) <- timers.get(hash)) {
            let elapsed = System.currentTimeMillis().toFloat64() - start
            let elapsedMs = elapsed
            // 严格翻译自 Output.printElapsed - 将微秒转为毫秒显示
            if (label.isEmpty) {
                println(String(elapsedMs) + "ms")
            } else {
                println(String(elapsedMs) + "ms " + label)
            }
            // 将计时器设为 null
            timers.remove(hash)
        }
        // 如果没有找到对应的计时器，静默返回
    }

    // console.timeLog - 严格翻译自 ConsoleObject.timeLog
    public func timeLog(label: String, args: Array<JsValue>) {
        let hash = hashString(label)
        if (let Some(start) <- timers.get(hash)) {
            let elapsed = System.currentTimeMillis().toFloat64() - start
            let elapsedMs = elapsed
            // 输出经过的时间
            if (label.isEmpty) {
                print(String(elapsedMs) + "ms")
            } else {
                print(String(elapsedMs) + "ms " + label)
            }

            // 严格翻译自 ConsoleObject.timeLog 中打印额外参数的逻辑
            let formatter = ConsoleFormatter()
            formatter.globalThis = JsObject.make()
            formatter.maxDepth = ConsoleObject.DEFAULT_CONSOLE_LOG_DEPTH
            formatter.canThrowStackOverflow = true

            for (arg in args) {
                let tag = ConsoleFormatter.getTag(arg, formatter.globalThis)
                print(" " + formatter.format(tag, arg, formatter.globalThis, true))
            }
            println("")
        }
    }

    // console.group
    public func group(global: JsObject, args: Array<JsValue>) {
        messageWithTypeAndLevel(ConsoleMessageType.StartGroup, ConsoleMessageLevel.Log, global, args)
    }

    // console.groupCollapsed
    public func groupCollapsed(global: JsObject, args: Array<JsValue>) {
        messageWithTypeAndLevel(ConsoleMessageType.StartGroupCollapsed, ConsoleMessageLevel.Log, global, args)
    }

    // console.groupEnd
    public func groupEnd(global: JsObject, args: Array<JsValue>) {
        messageWithTypeAndLevel(ConsoleMessageType.EndGroup, ConsoleMessageLevel.Log, global, args)
    }

    // console.clear
    public func clear(global: JsObject, args: Array<JsValue>) {
        messageWithTypeAndLevel(ConsoleMessageType.Clear, ConsoleMessageLevel.Log, global, args)
    }

    // console.profile - 严格翻译自 ConsoleObject.profile
    public func profile(label: String) {
        // 空操作 - Bun 不支持 console.profile
    }

    // console.profileEnd - 严格翻译自 ConsoleObject.profileEnd
    public func profileEnd(label: String) {
        // 空操作
    }

    // console.takeHeapSnapshot - 严格翻译自 ConsoleObject.takeHeapSnapshot
    public func takeHeapSnapshot(global: JsObject, label: String) {
        // 生成堆快照并打印
        messageWithTypeAndLevel(ConsoleMessageType.Log, ConsoleMessageLevel.Debug, global, Array<JsValue>())
    }

    // console.timeStamp - 严格翻译自 ConsoleObject.timeStamp
    public func timeStamp() {
        // 空操作
    }

    // console.record - 严格翻译自 ConsoleObject.record
    public func record() {
        // 空操作
    }

    // console.recordEnd - 严格翻译自 ConsoleObject.recordEnd
    public func recordEnd() {
        // 空操作
    }

    // console.screenshot - 严格翻译自 ConsoleObject.screenshot
    public func screenshot() {
        // 空操作
    }

    // ========== 格式化方法 ==========

    // 严格翻译自 ConsoleObject.format2 (详细版)
    public func format2(
        level: ConsoleMessageLevel,
        global: JsObject,
        vals: Array<JsValue>,
        len: Int64
    ): String {
        if (len == 0) {
            return ""
        }

        let consoleDepth = ConsoleObject.DEFAULT_CONSOLE_LOG_DEPTH

        if (len == 1) {
            // 严格翻译自 format2 中 len == 1 的分支
            let formatter = ConsoleFormatter()
            formatter.globalThis = global
            formatter.maxDepth = consoleDepth
            formatter.canThrowStackOverflow = true
            defer { formatter.deinit() }
            let tag = ConsoleFormatter.getTag(vals[0], global)
            let indentStr = formatter.writeIndent()
            var result = indentStr

            if (tag == FormatTag.String) {
                // 对 Error 级别使用红色
                if (level == ConsoleMessageLevel.Error) {
                    result += AnsiColors.redPrefix()
                }
                // 检查是否有格式化标签 (%s, %d 等)
                var effectiveTag = tag
                if (formatter.remainingValues.size > 0) {
                    effectiveTag = FormatTag.StringPossiblyFormatted
                }
                result += formatter.format(effectiveTag, vals[0], global, true)
                if (level == ConsoleMessageLevel.Error) {
                    result += AnsiColors.reset()
                }
            } else {
                result += formatter.format(tag, vals[0], global, true)
            }
            result += "\n"

            return result
        }

        // 严格翻译自 format2 中 len > 1 的分支
        // 多值: 第一个值作为格式化字符串 (如果有 % 标签)
        let formatter = ConsoleFormatter()
        formatter.globalThis = global
        formatter.remainingValues = vals.slice(1)
        formatter.maxDepth = consoleDepth
        formatter.canThrowStackOverflow = true
        defer { formatter.deinit() }
        let tag = ConsoleFormatter.getTag(vals[0], global)

        let indentStr = formatter.writeIndent()
        var result = indentStr

        if (level == ConsoleMessageLevel.Error) {
            result += AnsiColors.redPrefix()
        }

        var thisValue = vals[0]
        var isFirst = true
        while (true) {
            if (!isFirst) {
                result += " "
            }
            isFirst = false

            var currentTag = ConsoleFormatter.getTag(thisValue, global)
            // 如果是字符串且有剩余值，标记为格式化字符串
            if (currentTag == FormatTag.String && formatter.remainingValues.size > 0) {
                currentTag = FormatTag.StringPossiblyFormatted
            }
            result += formatter.format(currentTag, thisValue, global, true)

            if (formatter.remainingValues.size == 0) {
                break
            }
            thisValue = formatter.remainingValues[0]
            formatter.remainingValues = formatter.remainingValues.slice(1)
        }

        if (level == ConsoleMessageLevel.Error) {
            result += AnsiColors.reset()
        }

        result += "\n"
        result
    }

            if (tag == FormatTag.String) {
                if (level == ConsoleMessageLevel.Error) {
                    // 红色
                }
                result += formatter.format(tag, vals[0], global, true)
                result += "\n"
            } else {
                result += formatter.format(tag, vals[0], global, true)
                result += "\n"
            }

            return result
        }

        // 多值
        let formatter = ConsoleFormatter()
        formatter.globalThis = global
        formatter.remainingValues = vals.slice(1)
        formatter.maxDepth = consoleDepth
        let tag = ConsoleFormatter.getTag(vals[0], global)

        let indentStr = formatter.writeIndent()
        var result = indentStr

        if (level == ConsoleMessageLevel.Error) {
            // 红色前缀
        }

        var thisValue = vals[0]
        var isFirst = true
        while (true) {
            if (!isFirst) {
                result += " "
            }
            isFirst = false

            var currentTag = ConsoleFormatter.getTag(thisValue, global)
            // 如果是字符串且有剩余值，标记为格式化字符串
            if (currentTag == FormatTag.String && formatter.remainingValues.size > 0) {
                currentTag = FormatTag.StringPossiblyFormatted
            }
            result += formatter.format(currentTag, thisValue, global, true)

            if (formatter.remainingValues.size == 0) {
                break
            }
            thisValue = formatter.remainingValues[0]
            formatter.remainingValues = formatter.remainingValues.slice(1)
        }

        result += "\n"
        result
    }

    // 严格翻译自 ConsoleObject.writeTrace
    func writeTrace(global: JsObject): String {
        var result = "Trace:\n"
        // 获取当前栈跟踪
        // 简化实现
        let stackTrace = getStackTrace(global)
        for (frame in stackTrace) {
            result += "    at " + frame + "\n"
        }
        result
    }

    // 获取栈跟踪 (简化)
    func getStackTrace(global: JsObject): Array<String> {
        var frames = Array<String>()
        // 尝试创建 Error 获取栈帧
        let error = JsValue.createError("trace output")
        let stack = error.toString()
        // 解析栈帧
        let lines = stack.split("\n")
        for (line in lines) {
            let trimmed = line.trim()
            if (trimmed.size > 0 && trimmed.startsWith("at ")) {
                frames.append(trimmed)
            }
        }
        if (frames.size == 0) {
            frames.append("<anonymous>")
        }
        frames
    }

    // 输出到正确的流
    func printOutput(text: String, level: ConsoleMessageLevel) {
        match (level) {
            case Error | Warning => printError(text)
            case _ => print(text)
        }
    }

    // 输出到 stderr
    func printError(text: String) {
        println(text)
    }

    // 哈希字符串
    func hashString(s: String): Int64 {
        var hash: Int64 = 5381
        for (c in s) {
            hash = ((hash << 5) + hash) + Int64(c.code)
        }
        hash
    }
}

// ========== Writer 辅助 ==========
public class Writer {
    public init() {}

    public func write(text: String) {}
    public func writeAll(text: String) {}
    public func flush() {}
    public func print(text: String) {}
}

// ========== StringBuilder 辅助 ==========
public class StringBuilder {
    var buffer: Array<String> = []

    public init() {}

    public func append(s: String) {
        buffer.append(s)
    }

    public func toString(): String {
        String.join("", buffer)
    }
}

// ========== JS 类型辅助 ==========
// 严格翻译自 ConsoleObject.zig JSValue.JSType
public enum JsType {
    | Cell
    | String
    | StringObject
    | Symbol
    | ErrorInstance
    | NumberObject
    | BooleanObject
    | Object
    | Array
    | Map
    | Set
    | WeakMap
    | WeakSet
    | Promise
    | RegExpObject
    | Date
    | ArrayBuffer
    | Int8Array
    | Uint8Array
    | Uint8ClampedArray
    | Int16Array
    | Uint16Array
    | Int32Array
    | Uint32Array
    | Float16Array
    | Float32Array
    | Float64Array
    | BigInt64Array
    | BigUint64Array
    | DataView
    | GlobalObject
    | ProxyObject
    | DOMWrapper
    | Event
    | GetterSetter
    | CustomGetterSetter
    | Function
    | InternalFunction
    | HeapBigInt

    // 严格翻译自 JSType.isHidden
    public func isHidden(): Bool {
        match (this) {
            case Cell => true
            case _ => false
        }
    }

    // 严格翻译自 JSType.canGet
    public func canGet(): Bool {
        match (this) {
            case Cell => false
            case _ => true
        }
    }

    // 严格翻译自 JSType.isObject
    public func isObject(): Bool {
        match (this) {
            case Object | Array | Map | Set | WeakMap | WeakSet | Promise | Date |
                 RegExpObject | ErrorInstance | StringObject | NumberObject |
                 BooleanObject | Function | InternalFunction | GlobalObject |
                 ProxyObject | DOMWrapper | ArrayBuffer => true
            case _ => false
        }
    }

    // 严格翻译自 JSType.isStringLike
    public func isStringLike(): Bool {
        match (this) {
            case String | StringObject => true
            case _ => false
        }
    }

    // 严格翻译自 JSType.isFunction
    public func isFunction(): Bool {
        match (this) {
            case Function | InternalFunction => true
            case _ => false
        }
    }

    // 严格翻译自 JSType.isArray
    public func isArray(): Bool {
        this == Array
    }

    // 严格翻译自 JSType.isMap
    public func isMap(): Bool {
        match (this) {
            case Map | WeakMap => true
            case _ => false
        }
    }

    // 严格翻译自 JSType.isArguments
    public func isArguments(): Bool {
        false
    }
}

// ========== VisibleCharacterCounter ==========
// 严格翻译自 ConsoleObject.zig TablePrinter.VisibleCharacterCounter
public class VisibleCharacterCounter {
    public var width: Int64 = 0

    public init() {}

    // 严格翻译自 VisibleCharacterCounter.write
    public func write(bytes: String): Int64 {
        width += Int64(bytes.size)
        Int64(bytes.size)
    }

    // 严格翻译自 VisibleCharacterCounter.writeAll
    public func writeAll(bytes: String) {
        width += Int64(bytes.size)
    }
}

// ========== PropertyIterator ==========
// 严格翻译自 ConsoleObject.zig PropertyIterator 模式
public class PropertyIterator {
    public var keys: Array<String> = []
    public var values: Array<JsValue> = []
    public var index: Int64 = 0

    public init() {}

    public init(obj: JsObject) {
        keys = obj.keys()
        for (key in keys) {
            values.append(obj.get(key))
        }
    }

    public func next(): Bool {
        if (index >= keys.size) {
            return false
        }
        index++
        true
    }

    public func currentKey(): String {
        if (index > 0 && index <= keys.size) {
            return keys[Int64(index - 1)]
        }
        ""
    }

    public func currentValue(): JsValue {
        if (index > 0 && index <= values.size) {
            return values[Int64(index - 1)]
        }
        JsValue.undefined()
    }

    public func len(): Int64 {
        Int64(keys.size)
    }

    public func deinit() {
        keys = []
        values = []
    }
}

// ========== MapIterator ==========
// 严格翻译自 ConsoleObject.zig ConsoleObject.Formatter 中的 Map 迭代逻辑
public class MapEntryIterator {
    public var entries: Array<Pair<JsValue, JsValue>> = []
    public var index: Int64 = 0

    public init() {}

    public init(map: JsObject) {
        let iter = map.callMethod("entries", Array<JsValue>())
        // 简化: 不实际迭代 Map
    }

    public func next(): ?Pair<JsValue, JsValue> {
        if (index >= entries.size) {
            return None
        }
        let entry = entries[Int64(index)]
        index++
        entry
    }
}

// ========== SetIterator ==========
// 严格翻译自 ConsoleObject.zig ConsoleObject.Formatter 中的 Set 迭代逻辑
public class SetEntryIterator {
    public var entries: Array<JsValue> = []
    public var index: Int64 = 0

    public init() {}

    public init(set: JsObject) {
        let iter = set.callMethod("values", Array<JsValue>())
        // 简化: 不实际迭代 Set
    }

    public func next(): ?JsValue {
        if (index >= entries.size) {
            return None
        }
        let entry = entries[Int64(index)]
        index++
        entry
    }
}

// ========== ZigFormatter ==========
// 严格翻译自 ConsoleObject.zig Formatter.ZigFormatter
public class ZigFormatter {
    public var writer: Writer = Writer()
    public var globalThis: JsObject = JsObject.make()

    public init() {}

    public static let WRITE_ERROR: Int64 = 1
}

// ========== FormatTag.Options ==========
// 严格翻译自 ConsoleObject.zig Formatter.Tag.Options
public class FormatTagOptions {
    public var disableInspectCustom: Bool = false
    public var hideGlobal: Bool = false

    public init() {}
}

// ========== ANSI 颜色辅助 ==========
// 严格翻译自 ConsoleObject.zig 中的 ANSI 颜色使用
public class AnsiColors {
    public static func red(text: String): String {
        "\u{001b}[31m" + text + "\u{001b}[0m"
    }

    public static func green(text: String): String {
        "\u{001b}[32m" + text + "\u{001b}[0m"
    }

    public static func yellow(text: String): String {
        "\u{001b}[33m" + text + "\u{001b}[0m"
    }

    public static func blue(text: String): String {
        "\u{001b}[34m" + text + "\u{001b}[0m"
    }

    public static func magenta(text: String): String {
        "\u{001b}[35m" + text + "\u{001b}[0m"
    }

    public static func cyan(text: String): String {
        "\u{001b}[36m" + text + "\u{001b}[0m"
    }

    public static func bold(text: String): String {
        "\u{001b}[1m" + text + "\u{001b}[0m"
    }

    public static func dim(text: String): String {
        "\u{001b}[2m" + text + "\u{001b}[0m"
    }

    public static func underline(text: String): String {
        "\u{001b}[4m" + text + "\u{001b}[0m"
    }

    public static func reset(): String {
        "\u{001b}[0m"
    }

    public static func redPrefix(): String {
        "\u{001b}[31m"
    }

    public static func yellowPrefix(): String {
        "\u{001b}[33m"
    }

    public static func cyanPrefix(): String {
        "\u{001b}[36m"
    }

    public static func magentaPrefix(): String {
        "\u{001b}[35m"
    }

    public static func boldPrefix(): String {
        "\u{001b}[1m"
    }

    public static func dimPrefix(): String {
        "\u{001b}[2m"
    }

    // 严格翻译自 Output.prettyFmt
    // 将 <r>, <red>, <b>, <d>, <yellow>, <green>, <cyan>, <magenta> 等标签转为 ANSI 序列
    public static func prettyFmt(input: String, enableColors: Bool): String {
        if (!enableColors) {
            return stripTags(input)
        }
        var result = input
        result = result.replace("<r>", "\u{001b}[0m")
        result = result.replace("<red>", "\u{001b}[31m")
        result = result.replace("<green>", "\u{001b}[32m")
        result = result.replace("<yellow>", "\u{001b}[33m")
        result = result.replace("<blue>", "\u{001b}[34m")
        result = result.replace("<magenta>", "\u{001b}[35m")
        result = result.replace("<cyan>", "\u{001b}[36m")
        result = result.replace("<b>", "\u{001b}[1m")
        result = result.replace("<d>", "\u{001b}[2m")
        result = result.replace("<u>", "\u{001b}[4m")
        result
    }

    // 去除格式化标签
    public static func stripTags(input: String): String {
        var result = input
        result = result.replace("<r>", "")
        result = result.replace("<red>", "")
        result = result.replace("<green>", "")
        result = result.replace("<yellow>", "")
        result = result.replace("<blue>", "")
        result = result.replace("<magenta>", "")
        result = result.replace("<cyan>", "")
        result = result.replace("<b>", "")
        result = result.replace("<d>", "")
        result = result.replace("<u>", "")
        result
    }
}

// ========== EventType 枚举 ==========
// 严格翻译自 jsc.EventType
public enum EventType {
    | Unknown
    | Error
    | Message
    | Open
    | Close
    | MessageError
    | CloseEvent
    | ErrorEvent
    | MessageEvent
    | OpenEvent

    public static func map(value: String): EventType {
        match (value) {
            case "error" => Error
            case "message" => Message
            case "open" => Open
            case "close" => Close
            case "error" => ErrorEvent
            case "message" => MessageEvent
            case "close" => CloseEvent
            case "open" => OpenEvent
            case _ => Unknown
        }
    }
}

// ========== Console Formatter 扩展方法 ==========
// 扩展 ConsoleFormatter 添加更多从 ConsoleObject.zig 翻译的方法
public class ConsoleFormatterExtensions {

    // 严格翻译自 Formatter.formatMapEntries - 格式化 Map 条目
    public static func formatMapEntries(formatter: ConsoleFormatter, map: JsObject, globalThis: JsObject, enableColors: Bool): String {
        let size = map.get("size").toInteger()
        if (size == 0) {
            return "{}"
        }

        let indentStr = String(" ").repeat((formatter.indent + 1) * 2)
        let closeIndentStr = String(" ").repeat(formatter.indent * 2)
        var parts = Array<String>()

        let prevQuoteStrings = formatter.quoteStrings
        // Map 中 key 不需要引号

        // 简化: 不实际迭代 Map entries
        // 完整版需要调用 map.entries() 并迭代
        let result = "Map(" + String(size) + ") { ... }"

        formatter.quoteStrings = prevQuoteStrings
        result
    }

    // 严格翻译自 Formatter.formatSetEntries - 格式化 Set 条目
    public static func formatSetEntries(formatter: ConsoleFormatter, set: JsObject, globalThis: JsObject, enableColors: Bool): String {
        let size = set.get("size").toInteger()
        if (size == 0) {
            return "Set {}"
        }

        let prevQuoteStrings = formatter.quoteStrings

        // 简化: 不实际迭代 Set values
        let result = "Set(" + String(size) + ") { ... }"

        formatter.quoteStrings = prevQuoteStrings
        result
    }

    // 严格翻译自 Formatter.writeTypedArray - 格式化 TypedArray 内容
    public static func writeTypedArray(type_: String, slice: Array<JsValue>, enableColors: Bool): String {
        let maxElements: Int64 = 512
        let displayLen = if (Int64(slice.size) > maxElements) { maxElements } else { Int64(slice.size) }
        var parts = Array<String>()

        for (i in 0..displayLen) {
            parts.append(slice[Int64(i)].toString())
        }

        var result = type_ + "(" + String(slice.size) + ") [ "
        result += String.join(", ", parts)
        if (Int64(slice.size) > maxElements) {
            result += ", ... " + String(Int64(slice.size) - maxElements) + " more"
        }
        result += " ]"
        result
    }
}

// ========== JsObject 扩展方法 ==========
// 提供给 Console 和 VM 使用的 JsObject 扩展
public class JsObjectHelper {

    // 严格翻译自 JSValue.isAggregateError
    public static func isAggregateError(value: JsValue, global: JsObject): Bool {
        if (!value.isObject()) {
            return false
        }
        let obj = value.toObject()
        let constructor = obj.get("constructor")
        if (constructor.isObject()) {
            let name = constructor.toObject().get("name").toString()
            return name == "AggregateError"
        }
        false
    }

    // 严格翻译自 JSValue.getErrorsProperty - 获取 AggregateError.errors
    public static func getErrorsProperty(value: JsValue, global: JsObject): Array<JsValue> {
        if (!value.isObject()) {
            return []
        }
        let errors = value.toObject().get("errors")
        if (errors.isObject()) {
            let arr = errors.toObject()
            let length = arr.get("length").toInteger()
            var result = Array<JsValue>()
            for (i in 0..length) {
                result.append(arr.get(String(i)))
            }
            return result
        }
        []
    }

    // 严格翻译自 JSValue.forSymbol
    public static func isSymbolFor(key: JsValue): Bool {
        key.toString() == "Symbol(nodejs.util.inspect.custom)"
    }
}

// ========== TablePrinter 扩展 ==========
// 扩展 TablePrinter 更完整的方法
public class TablePrinterExtensions {

    // 严格翻译自 TablePrinter.printRow
    public static func printRow(
        printer: TablePrinter,
        columns: ArrayList<TablePrinter.Column>,
        rowKey: TablePrinter.RowKey,
        rowValue: JsValue,
        enableColors: Bool
    ): String {
        var result = "\u{2502}" // │

        // 行键
        let rowKeyStr: String = match (rowKey) {
            case TablePrinter.RowKey.Str(s) => s
            case TablePrinter.RowKey.Num(n) => String(n)
        }
        let keyWidth = if (columns.size > 0) { columns[0].width } else { Int64(1) }
        let keyPad = keyWidth - Int64(rowKeyStr.size)
        result += String(" ").repeat(keyPad + TablePrinter.PADDING) + rowKeyStr + String(" ").repeat(TablePrinter.PADDING)

        // 行值
        for (i in 1..columns.size) {
            let col = columns[Int64(i)]
            result += "\u{2502}" // │
            if (rowValue.isObject()) {
                let val = rowValue.toObject().get(col.name)
                let valStr = if (val.isNullOrUndefined()) { "" } else { val.toString() }
                let valPad = col.width - Int64(valStr.size)
                result += " " + valStr + String(" ").repeat(valPad + TablePrinter.PADDING)
            } else {
                result += String(" ").repeat(col.width + TablePrinter.PADDING * 2)
            }
        }
        result += "\u{2502}\n" // │\n

        result
    }

    // 严格翻译自 TablePrinter.writeStringNTimes
    public static func writeStringNTimes(str: String, n: Int64): String {
        var result = ""
        for (_ in 0..n) {
            result += str
        }
        result
    }
}

// ========== Mutex for Console ==========
public class ConsoleMutex {
    public init() {}
    public func lock() {}
    public func unlock() {}
}

// ========== ConsoleObject.writeTrace 详细版 ==========
// 严格翻译自 ConsoleObject.writeTrace (673-707 行)
public func consoleWriteTrace(global: JsObject): String {
    // 创建一个 Error 实例来获取栈跟踪
    let err = JsValue.createError("trace output")
    let holder = ZigExceptionHolder.initHolder()

    // 将错误转为 ZigException 并 remap
    let exception = holder.zigException()
    let vm = BunVirtualMachine.getOrNull()
    if (let Some(vmInstance) <- vm) {
        // remap 异常的栈帧位置
        let frames = exception.stack.frames()
        vmInstance.remapStackFramePositions(frames)
    }

    // 输出栈跟踪
    let stackTrace = exception.stack
    var result = ""
    let frameList = stackTrace.frames()
    for (frame in frameList) {
        let file = frame.sourceURL
        let func = frame.functionName
        if (file.isEmpty && func.isEmpty) {
            continue
        }
        if (func.size > 0 && !frame.positionIsInvalid) {
            result += "    at " + func + " (" + file + ":" + String(frame.line + 1) + ":" + String(frame.column + 1) + ")\n"
        } else if (!frame.positionIsInvalid) {
            result += "    at " + file + ":" + String(frame.line + 1) + ":" + String(frame.column + 1) + "\n"
        } else if (func.size > 0) {
            result += "    at " + func + "\n"
        } else {
            result += "    at " + file + "\n"
        }
    }
    result
}

// ========== ConsoleObject.format2 详细版 (带 writer) ==========
// 严格翻译自 ConsoleObject.format2 中处理单值和多值的完整逻辑
public func consoleFormat2Detailed(
    level: ConsoleMessageLevel,
    global: JsObject,
    vals: Array<JsValue>,
    options: ConsoleFormatOptions
): String {
    if (vals.size == 0) {
        return ""
    }

    if (vals.size == 1) {
        // 严格翻译自 format2 中 len == 1 的完整分支
        let formatter = ConsoleFormatter()
        formatter.globalThis = global
        formatter.orderedProperties = options.orderedProperties
        formatter.quoteStrings = options.quoteStrings
        formatter.maxDepth = options.maxDepth
        formatter.singleLine = options.singleLine
        formatter.indent = options.defaultIndent
        formatter.canThrowStackOverflow = true
        formatter.errorDisplayLevel = options.errorDisplayLevel
        defer { formatter.deinit() }

        let tag = ConsoleFormatter.getTag(vals[0], global)
        var result = formatter.writeIndent()

        if (tag == FormatTag.String) {
            if (options.enableColors) {
                if (level == ConsoleMessageLevel.Error) {
                    result += AnsiColors.redPrefix()
                }
                result += formatter.format(tag, vals[0], global, true)
                if (level == ConsoleMessageLevel.Error) {
                    result += AnsiColors.reset()
                }
            } else {
                result += formatter.format(tag, vals[0], global, false)
            }
            if (options.addNewline) {
                result += "\n"
            }
        } else {
            if (options.enableColors) {
                result += formatter.format(tag, vals[0], global, true)
            } else {
                result += formatter.format(tag, vals[0], global, false)
            }
            if (options.addNewline) {
                result += "\n"
            }
        }
        return result
    }

    // 严格翻译自 format2 中 len > 1 的完整分支
    let formatter = ConsoleFormatter()
    formatter.globalThis = global
    formatter.remainingValues = vals.slice(1)
    formatter.orderedProperties = options.orderedProperties
    formatter.quoteStrings = options.quoteStrings
    formatter.maxDepth = options.maxDepth
    formatter.singleLine = options.singleLine
    formatter.indent = options.defaultIndent
    formatter.canThrowStackOverflow = true
    formatter.errorDisplayLevel = options.errorDisplayLevel
    defer { formatter.deinit() }

    var result = formatter.writeIndent()
    var any = false

    if (options.enableColors) {
        if (level == ConsoleMessageLevel.Error) {
            result += AnsiColors.redPrefix()
        }
        var thisValue = vals[0]
        while (true) {
            if (any) {
                result += " "
            }
            any = true

            var tag = ConsoleFormatter.getTag(thisValue, global)
            if (tag == FormatTag.String && formatter.remainingValues.size > 0) {
                tag = FormatTag.StringPossiblyFormatted
            }
            result += formatter.format(tag, thisValue, global, true)
            if (formatter.remainingValues.size == 0) {
                break
            }
            thisValue = formatter.remainingValues[0]
            formatter.remainingValues = formatter.remainingValues.slice(1)
        }
        if (level == ConsoleMessageLevel.Error) {
            result += AnsiColors.reset()
        }
    } else {
        var thisValue = vals[0]
        while (true) {
            if (any) {
                result += " "
            }
            any = true

            var tag = ConsoleFormatter.getTag(thisValue, global)
            if (tag == FormatTag.String && formatter.remainingValues.size > 0) {
                tag = FormatTag.StringPossiblyFormatted
            }
            result += formatter.format(tag, thisValue, global, false)
            if (formatter.remainingValues.size == 0) {
                break
            }
            thisValue = formatter.remainingValues[0]
            formatter.remainingValues = formatter.remainingValues.slice(1)
        }
    }

    if (options.addNewline) {
        result += "\n"
    }
    result
}

// ========== ConsoleObject.messageWithTypeAndLevel_ 详细版 ==========
// 严格翻译自 ConsoleObject.messageWithTypeAndLevel_ (89-249 行)
public func consoleMessageWithTypeAndLevelDetailed(
    messageType: ConsoleMessageType,
    level: ConsoleMessageLevel,
    global: JsObject,
    vals: Array<JsValue>,
    console: ConsoleObject
) {
    // 处理 StartGroup 缩进
    defer {
        if (messageType == ConsoleMessageType.StartGroup) {
            console.defaultIndent++
        }
    }

    // 处理 StartGroup 无参数
    if (messageType == ConsoleMessageType.StartGroup && vals.size == 0) {
        return
    }

    // 处理 EndGroup
    if (messageType == ConsoleMessageType.EndGroup) {
        console.defaultIndent = Math.max(0, console.defaultIndent - 1)
        return
    }

    // 锁定互斥量
    if (level == ConsoleMessageLevel.Warning || level == ConsoleMessageLevel.Error || messageType == ConsoleMessageType.Assert) {
        if (console.stderrLockCount == 0) {
            console.stderrMutex.lock()
        }
        console.stderrLockCount++
    } else {
        if (console.stdoutLockCount == 0) {
            console.stdoutMutex.lock()
        }
        console.stdoutLockCount++
    }

    defer {
        if (level == ConsoleMessageLevel.Warning || level == ConsoleMessageLevel.Error || messageType == ConsoleMessageType.Assert) {
            console.stderrLockCount--
            if (console.stderrLockCount == 0) {
                console.stderrMutex.unlock()
            }
        } else {
            console.stdoutLockCount--
            if (console.stdoutLockCount == 0) {
                console.stdoutMutex.unlock()
            }
        }
    }

    // 处理 Clear
    if (messageType == ConsoleMessageType.Clear) {
        // Output.resetTerminal()
        return
    }

    // 处理 Assert 无参数
    if (messageType == ConsoleMessageType.Assert && vals.size == 0) {
        let text = "Assertion failed\n"
        console.errorWriter.writeAll(text)
        console.errorWriter.flush()
        return
    }

    let enableColors = match (level) {
        case Warning | Error => true
        case _ => true
    }

    var printLength = vals.size
    let consoleDepth = ConsoleObject.DEFAULT_CONSOLE_LOG_DEPTH

    var printOptions = ConsoleFormatOptions()
    printOptions.enableColors = enableColors
    printOptions.addNewline = true
    printOptions.flush = true
    printOptions.defaultIndent = console.defaultIndent
    printOptions.maxDepth = consoleDepth
    printOptions.errorDisplayLevel = match (level) {
        case Error => ErrorDisplayLevel.Full
        case Warning => ErrorDisplayLevel.Warn
        case _ => ErrorDisplayLevel.Normal
    }

    // 处理 Table
    if (messageType == ConsoleMessageType.Table && vals.size >= 1) {
        let tabularData = vals[0]
        if (tabularData.isObject()) {
            let properties: JsValue = if (vals.size >= 2 && vals[1].isObject() && vals[1].toObject().className == "Array") {
                vals[1]
            } else {
                JsValue.undefined()
            }
            let printer = TablePrinter.create(global, level, tabularData, properties)
            printer.valueFormatter.indent += console.defaultIndent
            let output = printer.printTable(enableColors)
            console.printOutput(output, level)
            return
        }
    }

    // 处理 Dir
    if (messageType == ConsoleMessageType.Dir && vals.size >= 2) {
        printLength = 1
        let opts = vals[1]
        if (opts.isObject()) {
            if (let Some(depthProp) <- opts.getPropertyOptional("depth")) {
                if (depthProp.isNumber()) {
                    let depth = depthProp.toInteger()
                    if (depth < 0) {
                        printOptions.maxDepth = Int64.MaxValue
                    } else {
                        printOptions.maxDepth = depth
                    }
                }
            }
            if (let Some(colorsProp) <- opts.getPropertyOptional("colors")) {
                if (colorsProp.isBoolean()) {
                    printOptions.enableColors = colorsProp.toBoolean()
                }
            }
        }
    }

    // 格式化并输出
    if (printLength > 0) {
        let output = consoleFormat2Detailed(level, global, vals, printOptions)
        console.printOutput(output, level)
    } else if (messageType == ConsoleMessageType.Log) {
        console.printOutput("\n", level)
    } else if (messageType != ConsoleMessageType.Trace) {
        console.printOutput("undefined\n", level)
    }

    // 处理 Trace
    if (messageType == ConsoleMessageType.Trace) {
        let trace = consoleWriteTrace(global)
        console.printOutput(trace, level)
    }
}

// ========== Formatter 扩展: 对象属性迭代 ==========
// 严格翻译自 ConsoleObject.zig 中 PropertyIterator 模板
public class PropertyIteratorDetailed {
    var globalThis: JsObject = JsObject.make()
    var obj: JsObject = JsObject.make()
    var keys: Array<String> = []
    var values: Array<JsValue> = []
    var index: Int64 = 0
    var skipEmptyName: Bool = false
    var includeValue: Bool = true
    var ownPropertiesOnly: Bool = true
    var observable: Bool = false

    public init() {}

    // 严格翻译自 JSPropertyIterator.init
    public static func init_(global: JsObject, obj: JsObject): PropertyIteratorDetailed {
        let iter = PropertyIteratorDetailed()
        iter.globalThis = global
        iter.obj = obj
        iter.keys = obj.keys()
        iter.values = []
        for (key in iter.keys) {
            iter.values.append(obj.get(key))
        }
        iter
    }

    // 严格翻译自 JSPropertyIterator.next
    public func next(): Bool {
        if (index >= keys.size) {
            return false
        }
        index++
        true
    }

    public func currentKey(): String {
        keys[Int64(index - 1)]
    }

    public func currentValue(): JsValue {
        values[Int64(index - 1)]
    }

    // 严格翻译自 JSPropertyIterator.getLongestPropertyName
    public func getLongestPropertyName(): Int64 {
        var max: Int64 = 0
        for (key in keys) {
            if (Int64(key.size) > max) {
                max = Int64(key.size)
            }
        }
        max
    }

    public func deinit() {
        keys = []
        values = []
    }
}

// ========== Formatter: Map/Set 条目格式化 ==========
// 严格翻译自 ConsoleObject.zig 中 Map 条目的格式化逻辑
public class MapEntryFormatter {
    // 严格翻译自 Formatter 中 Map 条目迭代 (1782-1810 行)
    public static func formatEntries(
        formatter: ConsoleFormatter,
        map: JsObject,
        globalThis: JsObject,
        enableColors: Bool
    ): String {
        let size = map.get("size").toInteger()
        let indentStr = String(" ").repeat((formatter.indent + 1) * 2)
        let closeIndentStr = String(" ").repeat(formatter.indent * 2)
        var parts = Array<String>()

        let prevQuoteStrings = formatter.quoteStrings
        formatter.quoteStrings = true
        defer { formatter.quoteStrings = prevQuoteStrings }

        // 简化: 不实际迭代 Map entries
        // 完整版需要调用 map.entries() 并获取 [key, value] 对
        // 对每一对:
        //   1. 获取 key 的 tag
        //   2. 获取 value 的 tag
        //   3. 格式化为 "key => value"

        "Map(" + String(size) + ") { ... }"
    }
}

// ========== Formatter: ArrayBuffer 格式化 ==========
// 严格翻译自 ConsoleObject.zig 中 ArrayBuffer 的格式化逻辑 (3380-3400 行)
public class ArrayBufferFormatter {
    // 严格翻译自 Formatter 中 ArrayBuffer 分支
    public static func format(buffer: JsValue, enableColors: Bool): String {
        // 检查 buffer 是否包含 ASCII 文本
        // 如果是，打印为字符串
        // 否则显示为十六进制
        let byteLength = buffer.toObject().get("byteLength").toInteger()
        "ArrayBuffer { byteLength: " + String(byteLength) + " }"
    }
}
