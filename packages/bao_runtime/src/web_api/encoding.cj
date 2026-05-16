// Web API Encoding 相关类
// 对应 Bun: src/runtime/webcore/encoding.classes.ts + encoding.zig
// 严格翻译自 Web Encoding API
package bao_runtime.web_api

import bao_core.*
import bao_collections.*

// ============================================================================
// Encoding Labels — 编码标签映射
// 对应 Bun: src/runtime/webcore/EncodingLabel.zig
// ============================================================================

/// EncodingLabel — 编码标签
/// 对应 Bun: src/runtime/webcore/EncodingLabel.zig
/// 将各种编码别名映射到规范名称
public class EncodingLabel {
    /// 将编码标签映射为规范名称
    /// 对应 Bun: EncodingLabel.toEncoding
    public static func canonicalize(label: String): String {
        let lower = label.toLowerCase().trim()

        // UTF-8 别名
        if (lower == "utf-8" || lower == "utf8" || lower == "unicode-1-1-utf-8" ||
            lower == "unicode11utf8" || lower == "unicode20utf8" || lower == "x-unicode20utf8") {
            return "utf-8"
        }

        // UTF-16LE 别名
        if (lower == "utf-16le" || lower == "utf-16" || lower == "ucs-2" ||
            lower == "unicode" || lower == "iso-10646-ucs-2") {
            return "utf-16le"
        }

        // UTF-16BE 别名
        if (lower == "utf-16be") {
            return "utf-16be"
        }

        // ISO-8859-1 / Latin-1 别名
        if (lower == "iso-8859-1" || lower == "iso8859-1" || lower == "iso-88591" ||
            lower == "iso_8859-1" || lower == "iso_8859_1" || lower == "latin1" ||
            lower == "latin-1" || lower == "l1" || lower == "csisolatin1" ||
            lower == "ibm819" || lower == "cp819") {
            return "iso-8859-1"
        }

        // ASCII / US-ASCII 别名
        if (lower == "us-ascii" || lower == "ascii" || lower == "csascii" ||
            lower == "iso-ir-6" || lower == "iso646-us" || lower == "ansi_x3.4-1968") {
            return "us-ascii"
        }

        // Windows-1252 别名
        if (lower == "windows-1252" || lower == "cp1252" || lower == "x-cp1252" ||
            lower == "iso-8859-1-windows-3.0-latin-1") {
            return "windows-1252"
        }

        // Shift_JIS 别名
        if (lower == "shift_jis" || lower == "shift-jis" || lower == "sjis" ||
            lower == "csshiftjis" || lower == "ms_kanji" || lower == "shift-jis") {
            return "shift_jis"
        }

        // EUC-JP 别名
        if (lower == "euc-jp" || lower == "eucjp" || lower == "cseucjp" ||
            lower == "x-euc-jp") {
            return "euc-jp"
        }

        // GBK 别名
        if (lower == "gbk" || lower == "gb2312" || lower == "gb_2312" ||
            lower == "x-gbk" || lower == "chinese" || lower == "csgb2312" ||
            lower == "csiso58gb231280" || lower == "iso-ir-58") {
            return "gbk"
        }

        // GB18030 别名
        if (lower == "gb18030") {
            return "gb18030"
        }

        // Big5 别名
        if (lower == "big5" || lower == "big5-hkscs" || lower == "cn-big5" ||
            lower == "csbig5" || lower == "x-x-big5") {
            return "big5"
        }

        // EUC-KR 别名
        if (lower == "euc-kr" || lower == "euckr" || lower == "cseuckr" ||
            lower == "korean" || lower == "iso-ir-149" || lower == "ks_c_5601-1987") {
            return "euc-kr"
        }

        // 默认返回 UTF-8
        return "utf-8"
    }

    /// 检查编码标签是否受支持
    public static func isSupported(label: String): Bool {
        let canonical = canonicalize(label)
        // 支持的编码列表
        match (canonical) {
            case "utf-8" => true
            case "utf-16le" => true
            case "utf-16be" => true
            case "iso-8859-1" => true
            case "us-ascii" => true
            case "windows-1252" => true
            case _ => false
        }
    }

    /// 获取所有支持的编码名称
    public static func getSupportedEncodings(): ArrayList<String> {
        let encodings = ArrayList<String>()
        encodings.append("utf-8")
        encodings.append("utf-16le")
        encodings.append("utf-16be")
        encodings.append("iso-8859-1")
        encodings.append("us-ascii")
        encodings.append("windows-1252")
        return encodings
    }
}

// ============================================================================
// DOMException — DOM 异常
// 对应 Web API: https://developer.mozilla.org/en-US/docs/Web/API/DOMException
// ============================================================================

/// DOMException 错误名称常量
public class DOMExceptionName {
    public static let INDEX_SIZE_ERR: String = "IndexSizeError"
    public static let DOMSTRING_SIZE_ERR: String = "DOMStringSizeError"
    public static let HIERARCHY_REQUEST_ERR: String = "HierarchyRequestError"
    public static let WRONG_DOCUMENT_ERR: String = "WrongDocumentError"
    public static let INVALID_CHARACTER_ERR: String = "InvalidCharacterError"
    public static let NO_DATA_ALLOWED_ERR: String = "NoDataAllowedError"
    public static let NO_MODIFICATION_ALLOWED_ERR: String = "NoModificationAllowedError"
    public static let NOT_FOUND_ERR: String = "NotFoundError"
    public static let NOT_SUPPORTED_ERR: String = "NotSupportedError"
    public static let INUSE_ATTRIBUTE_ERR: String = "InUseAttributeError"
    public static let INVALID_STATE_ERR: String = "InvalidStateError"
    public static let SYNTAX_ERR: String = "SyntaxError"
    public static let INVALID_MODIFICATION_ERR: String = "InvalidModificationError"
    public static let NAMESPACE_ERR: String = "NamespaceError"
    public static let INVALID_ACCESS_ERR: String = "InvalidAccessError"
    public static let VALIDATION_ERR: String = "ValidationError"
    public static let TYPE_MISMATCH_ERR: String = "TypeMismatchError"
    public static let SECURITY_ERR: String = "SecurityError"
    public static let NETWORK_ERR: String = "NetworkError"
    public static let ABORT_ERR: String = "AbortError"
    public static let URL_MISMATCH_ERR: String = "URLMismatchError"
    public static let QUOTA_EXCEEDED_ERR: String = "QuotaExceededError"
    public static let TIMEOUT_ERR: String = "TimeoutError"
    public static let INVALID_NODE_TYPE_ERR: String = "InvalidNodeTypeError"
    public static let DATA_CLONE_ERR: String = "DataCloneError"
    public static let ENCODING_ERR: String = "EncodingError"
    public static let NOT_READABLE_ERR: String = "NotReadableError"
    public static let UNKNOWN_ERR: String = "UnknownError"
    public static let CONSTRAINT_ERR: String = "ConstraintError"
    public static let TRANSACTION_ERR: String = "TransactionError"
    public static let VERSION_ERR: String = "VersionError"
    public static let OPERATION_ERR: String = "OperationError"
    public static let NOT_ALLOWED_ERR: String = "NotAllowedError"
}

/// DOMException — DOM 异常类
/// 对应 Web API: DOMException
public class DOMException {
    /// 错误消息
    public var message: String
    /// 错误名称
    public var name: String
    /// 错误代码
    public var code: Int64

    public init(message: String, name: String) {
        this.message = message
        this.name = name
        this.code = codeFromName(name)
    }

    public init(message: String) {
        this.message = message
        this.name = "Error"
        this.code = 0
    }

    /// 从名称获取错误代码
    public static func codeFromName(name: String): Int64 {
        match (name) {
            case "IndexSizeError" => 1
            case "HierarchyRequestError" => 3
            case "WrongDocumentError" => 4
            case "InvalidCharacterError" => 5
            case "NoModificationAllowedError" => 7
            case "NotFoundError" => 8
            case "NotSupportedError" => 9
            case "InUseAttributeError" => 10
            case "InvalidStateError" => 11
            case "SyntaxError" => 12
            case "InvalidModificationError" => 13
            case "NamespaceError" => 14
            case "InvalidAccessError" => 15
            case "SecurityError" => 18
            case "NetworkError" => 19
            case "AbortError" => 20
            case "URLMismatchError" => 21
            case "QuotaExceededError" => 22
            case "TimeoutError" => 23
            case "InvalidNodeTypeError" => 24
            case "DataCloneError" => 25
            case "EncodingError" => 0
            case "NotReadableError" => 0
            case "UnknownError" => 0
            case "ConstraintError" => 0
            case "TransactionError" => 0
            case "VersionError" => 0
            case "OperationError" => 0
            case "NotAllowedError" => 0
            case _ => 0
        }
    }

    /// 转为字符串
    public func toString(): String {
        return "${name}: ${message}"
    }

    /// 转为 JsValue (作为 Error 对象)
    public func toJsValue(): JsValue {
        let obj = JsObject()
        obj.set("message", JsValue(BaoString(message)))
        obj.set("name", JsValue(BaoString(name)))
        obj.set("code", JsValue(Float64(code)))
        obj.set("toString", JsValue.nativeFunction(JsNativeFunction("toString") { _ =>
            JsValue(BaoString(toString()))
        }))
        // 标记为 Error 类型
        obj.set("__proto__", JsValue(BaoString("DOMError")))
        return JsValue(obj)
    }

    /// 作为 JsError 抛出
    public func toJsError(): JsError {
        return JsError(toJsValue())
    }
}

// ============================================================================
// TextEncoder Common Labels
// ============================================================================

/// 编码检测辅助类
public class EncodingDetector {
    /// 检测字节数组的编码
    /// 通过 BOM (Byte Order Mark) 检测
    public static func detectBOM(bytes: Array<UInt8>): String {
        if (bytes.size >= 3) {
            // UTF-8 BOM: EF BB BF
            if (bytes[0] == UInt8(0xEF) && bytes[1] == UInt8(0xBB) && bytes[2] == UInt8(0xBF)) {
                return "utf-8"
            }
        }
        if (bytes.size >= 2) {
            // UTF-16LE BOM: FF FE
            if (bytes[0] == UInt8(0xFF) && bytes[1] == UInt8(0xFE)) {
                return "utf-16le"
            }
            // UTF-16BE BOM: FE FF
            if (bytes[0] == UInt8(0xFE) && bytes[1] == UInt8(0xFF)) {
                return "utf-16be"
            }
        }
        // 默认不检测
        return ""
    }

    /// 检测字节数组是否为有效 UTF-8
    public static func isUTF8(bytes: Array<UInt8>): Bool {
        return Utf8Codec.isValidUtf8(bytes)
    }
}

// ============================================================================
// EncodingModule — Encoding 模块导出
// ============================================================================

/// Encoding 模块导出 — 将 DOMException 等注册到全局
public class EncodingApiModule {
    /// 将 DOMException 注册到全局
    public static func registerGlobals(env: Environment): Unit {
        // DOMException 构造函数
        env.define("DOMException", Interpreter.makeNativeFn("DOMException") { args =>
            let message = if (args.size >= 1) { Interpreter.jsToString(args[0]) } else { "" }
            let name = if (args.size >= 2) { Interpreter.jsToString(args[1]) } else { "Error" }
            let ex = DOMException(message, name)
            return ex.toJsValue()
        }, false)
    }
}
