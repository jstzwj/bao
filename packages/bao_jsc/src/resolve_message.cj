// 严格翻译自: src/jsc/ResolveMessage.zig (250行)
// 模块解析消息 (解析失败的错误)

package bao_jsc

// ========== ResolveMessage ==========
// 严格翻译自 ResolveMessage.zig ResolveMessage
// 表示模块解析失败的错误消息
// 注意: ResolveMessage 不可构造 (constructor 抛出异常)
public class ResolveMessage {
    // 底层日志消息
    public var msg: LoggerMsg = LoggerMsg()
    // 分配器标识
    public var allocator: String = ""
    // 引用者路径
    public var referrer: ?FsPath = None
    // 是否已记录
    public var logged: Bool = false

    public init() {}

    public init(msg: LoggerMsg, allocator: String, referrer: String) {
        this.msg = msg
        this.allocator = allocator
        this.referrer = FsPath(referrer)
    }

    // 严格翻译自 ResolveMessage.constructor
    // ResolveMessage 不可构造
    public static func constructor(globalThis: JsObject) -> ?ResolveMessage {
        // 对应 Zig 中 throw "ResolveMessage is not constructable"
        None
    }

    // 严格翻译自 ResolveMessage.getCode
    // 获取解析错误码
    public func getCode(globalObject: JsObject) -> JsValue {
        if (msg.metadata.resolve != None) {
            let resolve = msg.metadata.resolve.getOrThrow()
            let specifier = resolve.specifier.slice(msg.data.text)

            let code: String = match (resolve.importKind) {
                // 匹配 Node.js 错误码
                case ImportKind_.Require => {
                    if (specifier.startsWith("node:")) {
                        "ERR_UNKNOWN_BUILTIN_MODULE"
                    } else {
                        "MODULE_NOT_FOUND"
                    }
                }
                // require resolve 没有 UNKNOWN_BUILTIN_MODULE 错误码
                case ImportKind_.RequireResolve => "MODULE_NOT_FOUND"
                case ImportKind_.Stmt | ImportKind_.Dynamic => {
                    if (specifier.startsWith("node:")) {
                        "ERR_UNKNOWN_BUILTIN_MODULE"
                    } else {
                        "ERR_MODULE_NOT_FOUND"
                    }
                }
                case _ => "RESOLVE_ERROR"
            }
            return JsValue(s: code)
        }
        JsValue.undefined()
    }

    // 严格翻译自 ResolveMessage.getColumn
    // 获取列号 (0-based)
    public func getColumn() -> JsValue {
        if (let Some(location) <- msg.data.location) {
            let col = location.column - 1
            return JsValue(n: Float64(if (col < 0) { 0 } else { col }))
        }
        JsValue(n: 0.0)
    }

    // 严格翻译自 ResolveMessage.getLine
    // 获取行号 (0-based)
    public func getLine() -> JsValue {
        if (let Some(location) <- msg.data.location) {
            let line = location.line - 1
            return JsValue(n: Float64(if (line < 0) { 0 } else { line }))
        }
        JsValue(n: 0.0)
    }

    // 严格翻译自 ResolveMessage.fmt
    // 格式化解析错误消息
    public static func fmt(
        specifier: String,
        referrer: String,
        err: ResolveError,
        importKind: ImportKind_
    ) -> String {
        if (importKind != ImportKind_.RequireResolve && specifier.startsWith("node:")) {
            // 完全匹配 Node.js 行为
            return "No such built-in module: " + specifier
        }
        match (err) {
            case ModuleNotFound => {
                if (referrer == "bun:main") {
                    "Module not found '" + specifier + "'"
                } else if (isPackagePath(specifier) && !specifier.contains("/")) {
                    "Cannot find package '" + specifier + "' from '" + referrer + "'"
                } else {
                    "Cannot find module '" + specifier + "' from '" + referrer + "'"
                }
            }
            case InvalidDataURL => {
                "Cannot resolve invalid data URL '" + specifier + "' from '" + referrer + "'"
            }
            case InvalidURL => {
                "Cannot resolve invalid URL '" + specifier + "' from '" + referrer + "'"
            }
            case _ => {
                if (isPackagePath(specifier)) {
                    err.name() + " while resolving package '" + specifier + "' from '" + referrer + "'"
                } else {
                    err.name() + " while resolving '" + specifier + "' from '" + referrer + "'"
                }
            }
        }
    }

    // 严格翻译自 ResolveMessage.toStringFn
    public func toStringFn(globalThis: JsObject) -> JsValue {
        JsValue(s: "ResolveMessage: " + msg.data.text)
    }

    // 严格翻译自 ResolveMessage.toString
    public func toString(globalThis: JsObject) -> JsValue {
        toStringFn(globalThis)
    }

    // 严格翻译自 ResolveMessage.toPrimitive
    public func toPrimitive(globalThis: JsObject, hint: JsValue) -> JsValue {
        if (hint.isString()) {
            let str = hint.toString()
            if (str == "default" || str == "string") {
                return toStringFn(globalThis)
            }
        }
        JsValue.null()
    }

    // 严格翻译自 ResolveMessage.toJSON
    public func toJSON(globalThis: JsObject) -> JsValue {
        let obj = JsObject.make()
        obj.className = "ResolveMessage"
        obj.set("name", JsValue(s: "ResolveMessage"))
        obj.set("position", getPosition(globalThis))
        obj.set("message", getMessage(globalThis))
        obj.set("level", getLevel(globalThis))
        obj.set("specifier", getSpecifier(globalThis))
        obj.set("importKind", getImportKind(globalThis))
        obj.set("referrer", getReferrer(globalThis))
        JsValue(obj: obj)
    }

    // 严格翻译自 ResolveMessage.create
    public static func create(
        globalThis: JsObject,
        msg: LoggerMsg,
        referrer: String
    ) -> ResolveMessage {
        ResolveMessage(msg: msg.clone(), allocator: "", referrer: referrer)
    }

    // 严格翻译自 ResolveMessage.getPosition
    public func getPosition(globalThis: JsObject) -> JsValue {
        BuildMessage.generatePositionObject(msg, globalThis)
    }

    // 严格翻译自 ResolveMessage.getMessage
    public func getMessage(globalThis: JsObject) -> JsValue {
        JsValue(s: msg.data.text)
    }

    // 严格翻译自 ResolveMessage.getLevel
    public func getLevel(globalThis: JsObject) -> JsValue {
        JsValue(s: msg.kind.toString())
    }

    // 严格翻译自 ResolveMessage.getSpecifier
    public func getSpecifier(globalThis: JsObject) -> JsValue {
        if (msg.metadata.resolve != None) {
            let resolve = msg.metadata.resolve.getOrThrow()
            return JsValue(s: resolve.specifier.slice(msg.data.text))
        }
        JsValue.undefined()
    }

    // 严格翻译自 ResolveMessage.getImportKind
    public func getImportKind(globalThis: JsObject) -> JsValue {
        if (msg.metadata.resolve != None) {
            let resolve = msg.metadata.resolve.getOrThrow()
            return JsValue(s: resolve.importKind.label())
        }
        JsValue.undefined()
    }

    // 严格翻译自 ResolveMessage.getReferrer
    public func getReferrer(globalThis: JsObject) -> JsValue {
        if (let Some(ref) <- referrer) {
            return JsValue(s: ref.text)
        }
        JsValue.null()
    }

    // 严格翻译自 ResolveMessage.finalize
    public func finalize() {
        msg = LoggerMsg()
        referrer = None
    }

    // 辅助: 判断是否为包路径
    static func isPackagePath(specifier: String) -> Bool {
        specifier.startsWith("@") || (!specifier.startsWith("/") && !specifier.startsWith("./") && !specifier.startsWith("../"))
    }
}

// ========== ImportKind_ ==========
// 严格翻译自 resolver ImportKind (ResolveMessage 使用的版本)
public enum ImportKind_ {
    | Stmt
    | Require
    | RequireResolve
    | Dynamic
    | HtmlManifest
    | EntryPointRun
    | EntryPointBuild
    | At
    | AtConditional
    | Url
    | Internal
    | Composes

    public func label() -> String {
        match (this) {
            case Stmt => "import"
            case Require => "require"
            case RequireResolve => "require.resolve"
            case Dynamic => "dynamic import"
            case HtmlManifest => "html manifest"
            case EntryPointRun => "entry point (run)"
            case EntryPointBuild => "entry point (build)"
            case At => "@import"
            case AtConditional => "@import (conditional)"
            case Url => "url"
            case Internal => "internal"
            case Composes => "composes"
        }
    }
}

// ========== ResolveError ==========
// 严格翻译自解析错误类型
public enum ResolveError {
    | ModuleNotFound
    | InvalidDataURL
    | InvalidURL
    | PackageImportNotDefined
    | PackagePathNotExported
    | UnexpectedToken
    | Unknown

    public func name() -> String {
        match (this) {
            case ModuleNotFound => "ModuleNotFound"
            case InvalidDataURL => "InvalidDataURL"
            case InvalidURL => "InvalidURL"
            case PackageImportNotDefined => "PackageImportNotDefined"
            case PackagePathNotExported => "PackagePathNotExported"
            case UnexpectedToken => "UnexpectedToken"
            case Unknown => "UnknownError"
        }
    }
}

// ========== MsgMetadata ==========
// 严格翻译自 logger.Msg metadata
public class MsgMetadata {
    public var resolve: ?MsgResolve = None

    public init() {}
}

// ========== MsgResolve ==========
// 严格翻译自 logger.Msg metadata.resolve
public class MsgResolve {
    public var specifier: MsgSpecifier = MsgSpecifier()
    public var importKind: ImportKind_ = ImportKind_.Stmt

    public init() {}
}

// ========== MsgSpecifier ==========
// 严格翻译自 logger.Msg metadata.resolve.specifier
public class MsgSpecifier {
    public var start: Int64 = 0
    public var end: Int64 = 0

    public init() {}

    // 从源文本切片
    public func slice(text: String) -> String {
        let s = if (start >= 0 && start < Int64(text.size)) { start } else { 0 }
        let e = if (end <= Int64(text.size)) { end } else { Int64(text.size) }
        if (s < e) {
            text[Int64(s)..Int64(e)]
        } else {
            ""
        }
    }
}

// ========== FsPath ==========
// 严格翻译自 fs.Path
public class FsPath {
    public var text: String = ""

    public init() {}

    public init(text: String) {
        this.text = text
    }
}
