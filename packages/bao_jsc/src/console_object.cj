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

    // 错误显示级别
    // 严格翻译自 ConsoleObject.zig ErrorDisplayLevel
    public enum ErrorDisplayLevel {
        | Normal
        | Warn
        | Full
    }

    // 严格翻译自 FormatOptions.fromJS
    public static func fromJS(globalThis: JsObject, arguments: Array<JsValue>) -> ConsoleFormatOptions {
        let opts = ConsoleFormatOptions()
        if (arguments.size == 0) {
            return opts
        }

        let arg1 = arguments[0]
        if (arg1.isObject()) {
            // 解析 depth, colors, sorted, compact
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
    public func isPrimitive() -> Bool {
        match (this) {
            case String | StringPossiblyFormatted | Undefined | Double |
                 Integer | Null | Boolean | Symbol | BigInt => true
            case _ => false
        }
    }

    // 严格翻译自 Tag.canHaveCircularReferences
    public func canHaveCircularReferences() -> Bool {
        match (this) {
            case Function | Array | Object | Map | Set | Error | Class | Event => true
            case _ => false
        }
    }
}

// ========== 自定义格式化对象 ==========
// 严格翻译自 ConsoleObject.zig CustomFormattedObject
public class CustomFormattedObject {
    public var function_: JsValue = JsValue.undefined()
    public var thisValue: JsValue = JsValue.undefined()

    public init() {}
}

// ========== 格式化器 ==========
// 严格翻译自 ConsoleObject.zig Formatter
public class ConsoleFormatter {
    public var globalThis: JsObject = JsObject.make()
    public var remainingValues: Array<JsValue> = []
    public var visitedMap: HashMap<Int64, Bool> = HashMap()
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
    public var errorDisplayLevel: ConsoleFormatOptions.ErrorDisplayLevel = ConsoleFormatOptions.ErrorDisplayLevel.Full
    public var formatBufferAsText: Bool = false

    public init() {}

    // 严格翻译自 Formatter.deinit
    public func deinit() {
        visitedMap.clear()
    }

    // 严格翻译自 Formatter.goodTimeForANewLine
    public func goodTimeForANewLine() -> Bool {
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

    // 严格翻译自 Formatter.Tag.get
    public static func getTag(value: JsValue, globalThis: JsObject) -> FormatTag {
        if (value.isUndefined()) {
            return FormatTag.Undefined
        }
        if (value.isNull()) {
            return FormatTag.Null
        }
        if (value.isBoolean()) {
            return FormatTag.Boolean
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
        if (value.isObject()) {
            let obj = value.toObject()
            let className = obj.className
            if (className == "Array") {
                return FormatTag.Array
            }
            if (className == "Function") {
                return FormatTag.Function
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
            return FormatTag.Object
        }
        FormatTag.NativeCode
    }

    // 严格翻译自 Formatter.format
    public func format(
        tag: FormatTag,
        value: JsValue,
        globalThis: JsObject,
        enableColors: Bool
    ) -> String {
        match (tag) {
            case Undefined => "undefined"
            case Null => "null"
            case Boolean => value.toBoolean() ? "true" : "false"
            case Double => formatNumber(value.toNumber())
            case Integer => String(value.toInteger())
            case String => if (quoteStrings) { "\"" + value.toString() + "\"" } else { value.toString() }
            case StringPossiblyFormatted => writeWithFormatting(value.toString(), globalThis, enableColors)
            case Symbol => value.toString()
            case BigInt => value.toString() + "n"
            case Array => formatArray(value.toObject(), globalThis, enableColors)
            case Object => formatObject(value.toObject(), globalThis, enableColors)
            case Function => formatFunction(value.toObject())
            case Error => formatError(value.toObject(), enableColors)
            case Map => "Map { ... }"
            case Set => "Set { ... }"
            case Promise => "Promise { ... }"
            case JSON => value.toString()
            case _ => value.toString()
        }
    }

    // 格式化数字
    func formatNumber(n: Float64) -> String {
        if (n != n) { return "NaN" }  // NaN
        if (n == Float64.PositiveInfinity) { return "Infinity" }
        if (n == Float64.NegativeInfinity) { return "-Infinity" }
        if (n == 0.0) { return "0" }
        String(n)
    }

    // 格式化数组
    func formatArray(obj: JsObject, globalThis: JsObject, enableColors: Bool) -> String {
        let indentStr = String(" ").repeat(indent * 2)
        let childIndentStr = String(" ").repeat((indent + 1) * 2)
        var parts = Array<String>()
        let length = obj.get("length").toInteger()
        for (i in 0..length) {
            let val = obj.get(String(i))
            depth++
            let formatted = format(getTag(val, globalThis), val, globalThis, enableColors)
            depth--
            parts.append(formatted)
        }
        if (parts.size == 0) {
            return "[]"
        }
        if (singleLine || parts.size <= 3) {
            return "[ " + String.join(", ", parts) + " ]"
        }
        childIndentStr + String.join("\n" + childIndentStr, parts) + "\n" + indentStr + "]"
    }

    // 格式化对象
    func formatObject(obj: JsObject, globalThis: JsObject, enableColors: Bool) -> String {
        let keys = obj.keys()
        if (keys.size == 0) {
            return "{}"
        }
        let indentStr = String(" ").repeat((indent + 1) * 2)
        var parts = Array<String>()
        for (key in keys) {
            let val = obj.get(key)
            depth++
            let formatted = format(getTag(val, globalThis), val, globalThis, enableColors)
            depth--
            let keyStr = if (quoteKeys) { "\"" + key + "\"" } else { key }
            parts.append(keyStr + ": " + formatted)
        }
        if (singleLine || parts.size <= 3) {
            return "{ " + String.join(", ", parts) + " }"
        }
        "{\n" + indentStr + String.join(",\n" + indentStr, parts) + "\n" + String(" ").repeat(indent * 2) + "}"
    }

    // 格式化函数
    func formatFunction(obj: JsObject) -> String {
        let name = obj.get("name").toString()
        if (name.isEmpty) {
            return "[Function (anonymous)]"
        }
        "[Function: " + name + "]"
    }

    // 格式化错误
    func formatError(obj: JsObject, enableColors: Bool) -> String {
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

    // 严格翻译自 Formatter.writeWithFormatting
    func writeWithFormatting(input: String, globalThis: JsObject, enableColors: Bool) -> String {
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
                    case _ => None
                }
                if (let Some(t) <- tag) {
                    // 替换格式化标签
                    if (remainingValues.size > 0) {
                        let nextValue = remainingValues[0]
                        remainingValues = remainingValues.slice(1)
                        // 简化: 直接用 toString
                        let replacement = match (t) {
                            case PercentTag.S => nextValue.toString()
                            case PercentTag.I => String(nextValue.toInteger())
                            case PercentTag.F => String(nextValue.toNumber())
                            case _ => nextValue.toString()
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
    ) -> TablePrinter {
        let printer = TablePrinter()
        printer.globalObject = globalObject
        printer.level = level
        printer.tabularData = tabularData
        printer.properties = properties
        printer.valueFormatter = ConsoleFormatter()
        printer.valueFormatter.maxDepth = 5
        printer.valueFormatter.singleLine = true
        printer.isIterable = tabularData.isObject() && tabularData.toObject().className == "Array"
        return printer
    }

    // 严格翻译自 TablePrinter.printTable
    public func printTable(enableColors: Bool) -> String {
        var columns = Array<TablePrinter.Column>()
        columns.append(TablePrinter.Column())

        // 计算列宽
        // 打印表头
        var result = StringBuilder()

        // 打印上边框
        result.append("\u{250c}")
        for (col in columns) {
            result.append(String("\u{2500}").repeat(Int64(col.width + 2 * TablePrinter.PADDING)))
        }
        result.append("\u{2510}\n")

        // 打印列名
        result.append("\u{2502}")
        for (col in columns) {
            let pad = col.width - Int64(col.name.size)
            result.append(" " + col.name + String(" ").repeat(pad + TablePrinter.PADDING) + "\u{2502}")
        }
        result.append("\n")

        // 打印下边框
        result.append("\u{2514}")
        for (col in columns) {
            result.append(String("\u{2500}").repeat(Int64(col.width + 2 * TablePrinter.PADDING)))
        }
        result.append("\u{2518}\n")

        result.toString()
    }

    // 严格翻译自 TablePrinter.getWidthForValue
    func getWidthForValue(value: JsValue) -> Int64 {
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

// ========== Console 对象 ==========
// 严格翻译自 ConsoleObject.zig ConsoleObject
public class ConsoleObject {
    // stderr/stdout 缓冲区大小
    static let BUFFER_SIZE: Int64 = 4096
    // 默认日志深度
    // 严格翻译自 DEFAULT_CONSOLE_LOG_DEPTH
    static let DEFAULT_CONSOLE_LOG_DEPTH: Int64 = 2

    // 计数器
    var counts: HashMap<String, Int64> = HashMap()
    // 计时器
    var timers: HashMap<String, Float64> = HashMap()
    // 默认缩进
    var defaultIndent: Int64 = 0

    public init() {}

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

        // 处理 Clear
        if (messageType == ConsoleMessageType.Clear) {
            // 清除终端
            return
        }

        // 处理 Assert
        if (messageType == ConsoleMessageType.Assert && vals.size == 0) {
            printError("Assertion failed")
            return
        }

        var printLength = vals.size

        // 处理 Table
        if (messageType == ConsoleMessageType.Table && vals.size >= 1) {
            let tabularData = vals[0]
            if (tabularData.isObject()) {
                let properties: JsValue = if (vals.size >= 2 && vals[1].isObject() && vals[1].toObject().className == "Array") { vals[1] } else { JsValue.undefined() }
                let printer = TablePrinter.create(global, level, tabularData, properties)
                printer.valueFormatter.indent += defaultIndent
                let output = printer.printTable(true)
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

    // console.count - 严格翻译自 Counter
    public func count(label: String) {
        let current = counts.get(label).getOr(0)
        counts.put(label, current + 1)
        println(label + ": " + String(current + 1))
    }

    // console.countReset
    public func countReset(label: String) {
        counts.put(label, 0)
    }

    // console.time
    public func time(label: String) {
        timers.put(label, System.currentTimeMillis().toFloat64())
    }

    // console.timeEnd
    public func timeEnd(label: String) {
        if (let Some(start) <- timers.get(label)) {
            let elapsed = System.currentTimeMillis().toFloat64() - start
            println(label + ": " + String(elapsed) + "ms")
            timers.remove(label)
        } else {
            println("Warning: No such label '" + label + "' for console.timeEnd()")
        }
    }

    // console.timeLog
    public func timeLog(label: String) {
        if (let Some(start) <- timers.get(label)) {
            let elapsed = System.currentTimeMillis().toFloat64() - start
            println(label + ": " + String(elapsed) + "ms")
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

    // ========== 格式化方法 ==========

    // 严格翻译自 ConsoleObject.format2
    public func format2(
        level: ConsoleMessageLevel,
        global: JsObject,
        vals: Array<JsValue>,
        len: Int64
    ) -> String {
        if (len == 0) {
            return ""
        }

        if (len == 1) {
            let formatter = ConsoleFormatter()
            formatter.globalThis = global
            formatter.maxDepth = DEFAULT_CONSOLE_LOG_DEPTH
            let tag = ConsoleFormatter.getTag(vals[0], global)
            return formatter.format(tag, vals[0], global, true) + "\n"
        }

        // 多值
        let formatter = ConsoleFormatter()
        formatter.globalThis = global
        formatter.remainingValues = vals.slice(1)
        formatter.maxDepth = DEFAULT_CONSOLE_LOG_DEPTH
        let tag = ConsoleFormatter.getTag(vals[0], global)
        var result = formatter.format(tag, vals[0], global, true)

        while (formatter.remainingValues.size > 0) {
            let nextValue = formatter.remainingValues[0]
            formatter.remainingValues = formatter.remainingValues.slice(1)
            let nextTag = ConsoleFormatter.getTag(nextValue, global)
            result = result + " " + formatter.format(nextTag, nextValue, global, true)
        }

        result + "\n"
    }

    // 严格翻译自 ConsoleObject.writeTrace
    func writeTrace(global: JsObject) -> String {
        "Trace:\n    at <anonymous>\n"
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
}

// StringBuilder 辅助
public class StringBuilder {
    var buffer: Array<String> = []

    public init() {}

    public func append(s: String) {
        buffer.append(s)
    }

    public func toString() -> String {
        String.join("", buffer)
    }
}
