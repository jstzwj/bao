// 严格翻译自: src/jsc/BuildMessage.zig (204行)
// 构建消息 (编译/转译时的错误/警告)

package bao_jsc

// ========== BuildMessage ==========
// 严格翻译自 BuildMessage.zig BuildMessage
// 表示构建/转译过程中的消息 (错误、警告、注释)
// 注意: BuildMessage 不可构造 (constructor 抛出异常)
public class BuildMessage {
    // 底层日志消息
    public var msg: LoggerMsg = LoggerMsg()
    // 分配器标识
    public var allocator: String = ""
    // 是否已记录
    public var logged: Bool = false

    public init() {}

    public init(text: String) {
        this.msg = LoggerMsg()
        this.msg.data = MsgData()
        this.msg.data.text = text
    }

    public init(msg: LoggerMsg, allocator: String) {
        this.msg = msg
        this.allocator = allocator
    }

    // 严格翻译自 BuildMessage.constructor
    // BuildMessage 不可构造
    public static func constructor(globalThis: JsObject) -> ?BuildMessage {
        // 对应 Zig 中 throw "BuildMessage is not constructable"
        None
    }

    // 严格翻译自 BuildMessage.getNotes
    // 获取附属的注释列表
    public func getNotes(globalThis: JsObject) -> Array<BuildMessage> {
        var notes: Array<BuildMessage> = []
        for (note in msg.notes) {
            let cloned = note.clone()
            let buildMsg = BuildMessage()
            buildMsg.msg = LoggerMsg(data: cloned, kind: MsgKind.Note)
            notes.append(buildMsg)
        }
        notes
    }

    // 严格翻译自 BuildMessage.toStringFn
    // 转为字符串
    public func toStringFn(globalThis: JsObject) -> JsValue {
        let text = "BuildMessage: " + msg.data.text
        JsValue(s: text)
    }

    // 严格翻译自 BuildMessage.toString
    public func toString(globalThis: JsObject) -> JsValue {
        toStringFn(globalThis)
    }

    // 严格翻译自 BuildMessage.toPrimitive
    public func toPrimitive(globalThis: JsObject, hint: JsValue) -> JsValue {
        if (hint.isString()) {
            let str = hint.toString()
            if (str == "default" || str == "string") {
                return toStringFn(globalThis)
            }
        }
        JsValue.null()
    }

    // 严格翻译自 BuildMessage.toJSON
    public func toJSON(globalThis: JsObject) -> JsValue {
        let obj = JsObject.make()
        obj.className = "BuildMessage"
        obj.set("name", JsValue(s: "BuildMessage"))
        obj.set("position", getPosition(globalThis))
        obj.set("message", getMessage(globalThis))
        obj.set("level", getLevel(globalThis))
        JsValue(obj: obj)
    }

    // 严格翻译自 BuildMessage.getColumn
    // 获取列号 (0-based)
    public func getColumn() -> JsValue {
        if (let Some(location) <- msg.data.location) {
            let col = location.column - 1
            return JsValue(n: Float64(if (col < 0) { 0 } else { col }))
        }
        JsValue(n: 0.0)
    }

    // 严格翻译自 BuildMessage.getLine
    // 获取行号 (0-based)
    public func getLine() -> JsValue {
        if (let Some(location) <- msg.data.location) {
            let line = location.line - 1
            return JsValue(n: Float64(if (line < 0) { 0 } else { line }))
        }
        JsValue(n: 0.0)
    }

    // 严格翻译自 BuildMessage.getPosition
    // 获取位置对象
    public func getPosition(globalThis: JsObject) -> JsValue {
        generatePositionObject(msg, globalThis)
    }

    // 严格翻译自 BuildMessage.getMessage
    public func getMessage(globalThis: JsObject) -> JsValue {
        JsValue(s: msg.data.text)
    }

    // 严格翻译自 BuildMessage.getLevel
    public func getLevel(globalThis: JsObject) -> JsValue {
        JsValue(s: msg.kind.toString())
    }

    // 严格翻译自 BuildMessage.generatePositionObject
    // 生成位置对象
    public static func generatePositionObject(msg: LoggerMsg, globalThis: JsObject) -> JsValue {
        if (msg.data.location == None) {
            return JsValue.null()
        }
        let location = msg.data.location.getOrThrow()
        let obj = JsObject.make()
        obj.set("lineText", JsValue(s: location.lineText))
        obj.set("file", JsValue(s: location.file))
        obj.set("namespace", JsValue(s: location.namespace))
        obj.set("line", JsValue(n: Float64(location.line)))
        obj.set("column", JsValue(n: Float64(location.column)))
        obj.set("length", JsValue(n: Float64(location.length_)))
        obj.set("offset", JsValue(n: Float64(location.offset)))
        JsValue(obj: obj)
    }

    // 严格翻译自 BuildMessage.create
    // 创建 BuildMessage 实例
    public static func create(globalThis: JsObject, msg: LoggerMsg) -> BuildMessage {
        let buildMsg = BuildMessage()
        buildMsg.msg = msg.clone()
        buildMsg
    }

    // 严格翻译自 BuildMessage.finalize
    public func finalize() {
        msg = LoggerMsg()
    }
}

// ========== LoggerMsg ==========
// 严格翻译自 logger.Msg
public class LoggerMsg {
    public var data: MsgData = MsgData()
    public var kind: MsgKind = MsgKind.Err
    public var notes: Array<MsgData> = []

    public init() {}

    public func clone() -> LoggerMsg {
        let cloned = LoggerMsg()
        cloned.data = data.clone()
        cloned.kind = kind
        cloned.notes = notes
        cloned
    }
}

// ========== MsgData ==========
// 严格翻译自 logger.Msg.Data
public class MsgData {
    public var text: String = ""
    public var location: ?MsgLocation = None

    public init() {}

    public func clone() -> MsgData {
        let cloned = MsgData()
        cloned.text = text
        cloned.location = location
        cloned
    }
}

// ========== MsgLocation ==========
// 严格翻译自 logger.Msg.Data.Location
public class MsgLocation {
    public var file: String = ""
    public var namespace: String = ""
    public var line: Int64 = 0
    public var column: Int64 = 0
    public var length_: Int64 = 0
    public var offset: Int64 = 0
    public var lineText: String = ""

    public init() {}
}

// ========== MsgKind ==========
// 严格翻译自 logger.Msg.Kind
public enum MsgKind {
    | Err
    | Warning
    | Note
    | Debug
    | Verbose

    public func toString() -> String {
        match (this) {
            case Err => "error"
            case Warning => "warning"
            case Note => "note"
            case Debug => "debug"
            case Verbose => "verbose"
        }
    }
}
