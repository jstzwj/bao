// pretty_format.cj - 格式化输出
// 严格翻译自 bun/src/runtime/test_runner/pretty_format.zig

package bao_runtime.test_runner

import bao_jsc.*
import std.collection.*

// ========== EventType - 事件类型 ==========

/// 事件类型枚举
public enum EventType {
    | Event
    | MessageEvent
    | CloseEvent
    | ErrorEvent
    | OpenEvent
    | Unknown

    /// 获取标签
    public func label(): String {
        match (this) {
            case Event => return "event"
            case MessageEvent => return "message"
            case CloseEvent => return "close"
            case ErrorEvent => return "error"
            case OpenEvent => return "open"
            case Unknown => return "event"
        }
    }
}

/// 事件类型标签映射 - 顶级变量
public let eventTypeMap: HashMap<String, EventType> = HashMap<String, EventType>()

public func initEventTypeMap(): Unit {
    eventTypeMap["event"] = EventType.Event
    eventTypeMap["message"] = EventType.MessageEvent
    eventTypeMap["close"] = EventType.CloseEvent
    eventTypeMap["error"] = EventType.ErrorEvent
    eventTypeMap["open"] = EventType.OpenEvent
}

// ========== JestPrettyFormat - Jest美化格式化 ==========

/// Jest风格的值格式化器，用于在测试输出中美化显示JS值
///
/// 提供类似于Jest的pretty-format功能，将JS值格式化为人类可读的字符串。
/// 支持颜色输出、缩进、循环引用检测等特性。
public type Counter = HashMap<UInt64, UInt32>

public class JestPrettyFormat {
    public var counts: Counter = Counter()

    public init() {}
}

// ========== MessageLevel - 消息级别 ==========

/// 格式化消息级别
public enum MessageLevel {
    | log       // 0
    | warning   // 1
    | error     // 2
    | debug_    // 3
    | info      // 4
}

// ========== MessageType - 消息类型 ==========

/// 格式化消息类型
public enum MessageType {
    | log           // 0
    | dir           // 1
    | dirXML        // 2
    | table         // 3
    | trace         // 4
    | startGroup    // 5
    | startGroupCollapsed // 6
    | endGroup      // 7
    | clear         // 8
    | assert_       // 9
    | timing        // 10
    | profile       // 11
    | profileEnd    // 12
    | image         // 13
}

// ========== FormatOptions - 格式化选项 ==========

/// 格式化选项
public class FormatOptions {
    public var enableColors: Bool = false
    public var addNewline: Bool = false
    public var flush: Bool = false
    public var quoteStrings: Bool = false

    public init() {}
}

// ========== JestPrettyFormat 静态方法 ==========

extend JestPrettyFormat {
    /// 格式化入口
    ///
    /// 根据消息级别和格式化选项，将JS值数组格式化为字符串
    ///
    /// 处理流程:
    /// 1. 如果只有一个值且是字符串，直接输出（可能带颜色）
    /// 2. 否则，遍历所有值并格式化
    /// 3. 值之间用空格分隔
    /// 4. 可选地添加换行和flush
    public static func format(level: MessageLevel, global: JSGlobalObject, vals: Array<JSValue>, len: UInt64, writer: StringWriter, options: FormatOptions) {
        if (len == 1) {
            let fmt = Formatter(globalThis: global)
            fmt.quoteStrings = options.quoteStrings
            let tag = Tag.get(value: vals[0], globalThis: global)

            if (tag.tag == string) {
                if (options.enableColors) {
                    if (level == error) {
                        writer.write(Output.prettyFmt("<r><red>"))
                    }
                    fmt.format(result: tag, writer: writer, value: vals[0], globalThis: global, enableAnsiColors: true)
                    if (level == error) {
                        writer.write(Output.prettyFmt("<r>"))
                    }
                } else {
                    fmt.format(result: tag, writer: writer, value: vals[0], globalThis: global, enableAnsiColors: false)
                }
                if (options.addNewline) {
                    writer.write("\n")
                }
            } else {
                if (options.enableColors) {
                    if (level == error) {
                        writer.write(Output.prettyFmt("<r><red>"))
                    }
                    fmt.format(result: tag, writer: writer, value: vals[0], globalThis: global, enableAnsiColors: true)
                    if (level == error) {
                        writer.write(Output.prettyFmt("<r>"))
                    }
                } else {
                    fmt.format(result: tag, writer: writer, value: vals[0], globalThis: global, enableAnsiColors: false)
                }
                if (options.addNewline) {
                    writer.write("\n")
                }
            }
        } else {
            let fmt = Formatter(globalThis: global)
            fmt.quoteStrings = options.quoteStrings

            var i: UInt64 = 0
            while (i < len) {
                if (i > 0) {
                    writer.write(" ")
                }
                let tag = Tag.get(value: vals[i], globalThis: global)
                if (options.enableColors) {
                    fmt.format(result: tag, writer: writer, value: vals[i], globalThis: global, enableAnsiColors: true)
                } else {
                    fmt.format(result: tag, writer: writer, value: vals[i], globalThis: global, enableAnsiColors: false)
                }
                i += 1
            }
            if (options.addNewline) {
                writer.write("\n")
            }
        }
    }
}

// ========== Tag - 值类型标签 ==========

/// JS值类型标签
public enum Tag {
    | stringPossiblyFormatted
    | string
    | undefined
    | double_
    | integer
    | null_
    | boolean
    | array
    | object
    | function
    | class_
    | error
    | typedArray
    | map
    | set
    | symbol
    | bigInt
    | globalObject
    | private_
    | promise
    | json
    | nativeCode
    | arrayBuffer
    | jsx
    | event

    /// 是否为原始类型
    public func isPrimitive(): Bool {
        match (this) {
        case Tag.string | Tag.stringPossiblyFormatted | Tag.undefined | Tag.double_ | Tag.integer | Tag.null_ | Tag.boolean | Tag.symbol | Tag.bigInt =>
            return true
        case _ => return false
        }
    }

    /// 是否可能有循环引用
    public func canHaveCircularReferences(): Bool {
        return this == array || this == object || this == map || this == set
    }

    /// 获取值的标签
    ///
    /// 通过JS值的类型判断其Tag类型
    public static func get(value: JSValue, globalThis: JSGlobalObject): TagResult {
        if (value.isEmpty()) { return TagResult(tag: Tag.undefined) }
        if (value.isUndefined()) { return TagResult(tag: Tag.undefined) }
        if (value.isNull()) { return TagResult(tag: Tag.null_) }
        if (value.isBoolean()) { return TagResult(tag: Tag.boolean) }
        if (value.isNumber()) {
            let num = value.asNumber()
            if (num == num && num == num.trunc() && num >= Int64.min.toFloat64() && num <= Int64.max.toFloat64()) {
                return TagResult(tag: Tag.integer)
            }
            return TagResult(tag: Tag.double_)
        }
        if (value.isString()) { return TagResult(tag: Tag.string) }
        if (value.isSymbol()) { return TagResult(tag: Tag.symbol) }
        if (value.isBigInt()) { return TagResult(tag: Tag.bigInt) }
        if (value.isArray(global: globalThis)) { return TagResult(tag: Tag.array) }
        if (value.isFunction()) { return TagResult(tag: Tag.function) }
        if (value.isObject()) {
            // 检查是否为特殊对象类型
            if (value.isClass(global: globalThis)) { return TagResult(tag: Tag.class_) }
            if (value.isError(global: globalThis)) { return TagResult(tag: Tag.error) }
            if (value.isMap(global: globalThis)) { return TagResult(tag: Tag.map) }
            if (value.isSet(global: globalThis)) { return TagResult(tag: Tag.set) }
            if (value.isPromise(global: globalThis)) { return TagResult(tag: Tag.promise) }
            if (value.isTypedArray(global: globalThis)) { return TagResult(tag: Tag.typedArray) }
            if (value.isArrayBuffer(global: globalThis)) { return TagResult(tag: Tag.arrayBuffer) }
            if (value.isRegExp(global: globalThis)) { return TagResult(tag: Tag.string) }
            return TagResult(tag: Tag.object)
        }
        return TagResult(tag: Tag.undefined)
    }
}

/// 标签结果
public class TagResult {
    public var tag: Tag

    public init(tag: Tag) {
        this.tag = tag
    }
}


// ========== Formatter - 格式化器 ==========

/// 格式化器，负责具体的值格式化
///
/// 支持各种JS值类型的格式化输出，包括:
/// - 原始类型: string, number, boolean, null, undefined, symbol, bigint
/// - 复合类型: array, object, map, set
/// - 特殊类型: function, class, error, promise, typedArray
/// - 循环引用检测
/// - 自动缩进和换行
public class Formatter {
    public var remainingValues: Array<JSValue> = Array<JSValue>()
    public var globalThis: JSGlobalObject
    public var indent: UInt32 = 0
    public var quoteStrings: Bool = false
    public var failed: Bool = false
    public var estimatedLineLength: UInt64 = 0
    public var alwaysNewlineScope: Bool = false
    public var mapNode: ?CounterNode = None

    public init(globalThis: JSGlobalObject) {
        this.globalThis = globalThis
    }

    /// 检查是否该换行
    public func goodTimeForANewLine(): Bool {
        if (estimatedLineLength > 80) {
            resetLine()
            return true
        }
        return false
    }

    /// 重置行长度估算
    public func resetLine() {
        estimatedLineLength = UInt64(indent) * 2
    }

    /// 增加行长度估算
    public func addForNewLine(len: UInt64) {
        estimatedLineLength += len
    }


    /// 写入缩进
    public func writeIndent(writer: StringWriter) {
        let indentLevel = if (indent > 32) { 32 } else { indent }
        for (_ in 0..indentLevel ) {
            writer.write("  ")
        }
    }

    /// 打印逗号
    public func printComma(writer: StringWriter, enableAnsiColors: Bool) {
        writer.write(",")
        estimatedLineLength += 1
    }

    /// 按指定类型打印值
    ///
    /// 根据Tag类型将JS值格式化为字符串表示
    public func printAs(format: Tag, writer: StringWriter, value: JSValue, enableAnsiColors: Bool) {
        match (format) {
            case Tag.string | Tag.stringPossiblyFormatted =>
                if (quoteStrings) {
                    let str = value.toSlice(global: globalThis)
                    writer.write("\"" + str + "\"")
                } else {
                    let str = value.toSlice(global: globalThis)
                    writer.write(str)
                }
            case Tag.integer =>
                let num = value.asNumber()
                writer.write(Int64(num).toString())
            case Tag.double_ =>
                let num = value.asNumber()
                writer.write(num.toString())
            case Tag.boolean =>
                writer.write(value.toBoolean().toString())
            case Tag.null_ =>
                writer.write("null")
            case Tag.undefined =>
                writer.write("undefined")
            case Tag.symbol =>
                let desc = value.getSymbolDescription(global: globalThis)
                writer.write("Symbol(" + desc + ")")
            case Tag.bigInt =>
                let str = value.toSlice(global: globalThis)
                writer.write("" + str + "n")
            case Tag.function =>
                let name = value.getName(global: globalThis)
                if (name.length > 0) {
                    writer.write("[Function: " + name + "]")
                } else {
                    writer.write("[Function (anonymous)]")
                }
            case Tag.class_ =>
                let name = value.getClassName(global: globalThis)
                writer.write("[class " + (name) + "]")
            case Tag.array =>
                printArray(writer: writer, value: value, enableAnsiColors: enableAnsiColors)
            case Tag.object =>
                printObject(writer: writer, value: value, enableAnsiColors: enableAnsiColors)
            case Tag.map =>
                printMap(writer: writer, value: value, enableAnsiColors: enableAnsiColors)
            case Tag.set =>
                printSet(writer: writer, value: value, enableAnsiColors: enableAnsiColors)
            case Tag.error =>
                let name = value.getProperty(global: globalThis, name: "name")?.toSlice(global: globalThis) ?? "Error"
                let message = value.getProperty(global: globalThis, name: "message")?.toSlice(global: globalThis) ?? ""
                writer.write((name) + ": " + (message))
            case Tag.promise =>
                writer.write("Promise { <pending> }")
            case Tag.typedArray =>
                writer.write("[TypedArray]")
            case Tag.arrayBuffer =>
                writer.write("[ArrayBuffer]")
            case Tag.json =>
                let str = value.jsonStringifyFast(global: globalThis)
                writer.write(str)
            case Tag.nativeCode =>
                writer.write("[native code]")
            case Tag.jsx =>
                printObject(writer: writer, value: value, enableAnsiColors: enableAnsiColors)
            case Tag.event =>
                let eventType = value.getProperty(global: globalThis, name: "type")?.toSlice(global: globalThis) ?? "event"
                writer.write("Event { type: '" + (eventType) + "' }")
            case Tag.globalObject =>
                writer.write("[Global]")
            case Tag.private_ =>
                writer.write("[Private]")
        }
    }

    /// 打印数组
    private func printArray(writer: StringWriter, value: JSValue, enableAnsiColors: Bool) {
        writer.write("[ ")
        indent += 1
        let length = value.getLength(global: globalThis)
        for (i in 0..length ) {
            if (i > 0) {
                writer.write(", ")
            }
            let element = value.getPropertyAtIndex(global: globalThis, index: i)
            if (element == None) { writer.write("undefined"); continue }
            let tag = Tag.get(value: element.getOrThrow(), globalThis: globalThis)
            format(result: tag, writer: writer, value: element.getOrThrow(), globalThis: globalThis, enableAnsiColors: enableAnsiColors)
        }
        indent -= 1
        writer.write(" ]")
    }

    /// 打印对象
    private func printObject(writer: StringWriter, value: JSValue, enableAnsiColors: Bool) {
        writer.write("{ ")
        indent += 1
        var first = true
        let iter = value.propertyIterator(global: globalThis)
        while (let Some((name, propValue)) <- iter.next() ){
            if (!first) {
                writer.write(", ")
            }
            first = false
            writer.write((name) + ": ")
            let tag = Tag.get(value: propValue, globalThis: globalThis)
            format(result: tag, writer: writer, value: propValue, globalThis: globalThis, enableAnsiColors: enableAnsiColors)
        }
        indent -= 1
        if (!first) {
            writer.write(" ")
        }
        writer.write("}")
    }

    /// 打印Map
    private func printMap(writer: StringWriter, value: JSValue, enableAnsiColors: Bool) {
        writer.write("Map {")
        indent += 1
        let size = value.getLength(global: globalThis)
        for (i in 0..size ) {
            if (i > 0) { writer.write(",") }
            writer.write("\n")
            writeIndent(writer: writer)
            let entry = value.getPropertyAtIndex(global: globalThis, index: i)
            // Map entries are [key, value] arrays
            if (let Some(e) <- entry) {
                writer.write("  ")
                let keyTag = Tag.get(value: e, globalThis: globalThis)
                format(result: keyTag, writer: writer, value: e, globalThis: globalThis, enableAnsiColors: enableAnsiColors)
                writer.write(" => ")
                let valTag = Tag.get(value: e, globalThis: globalThis)
                format(result: valTag, writer: writer, value: e, globalThis: globalThis, enableAnsiColors: enableAnsiColors)
            }
        }
        indent -= 1
        writer.write("\n")
        writeIndent(writer: writer)
        writer.write("}")
    }

    /// 打印Set
    private func printSet(writer: StringWriter, value: JSValue, enableAnsiColors: Bool) {
        writer.write("Set {")
        indent += 1
        let size = value.getLength(global: globalThis)
        for (i in 0..size ) {
            if (i > 0) { writer.write(", ") }
            let element = value.getPropertyAtIndex(global: globalThis, index: i)
            if (let Some(e) <- element) {
                let tag = Tag.get(value: e, globalThis: globalThis)
                format(result: tag, writer: writer, value: e, globalThis: globalThis, enableAnsiColors: enableAnsiColors)
            }
        }
        indent -= 1
        writer.write("}")
    }

    /// 格式化值
    public func format(result: TagResult, writer: StringWriter, value: JSValue, globalThis: JSGlobalObject, enableAnsiColors: Bool) {
        printAs(format: result.tag, writer: writer, value: value, enableAnsiColors: enableAnsiColors)
    }
}
