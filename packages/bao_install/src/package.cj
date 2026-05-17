// bao_install - 包管理器
// 对应 Bun: src/install/
package bao_install

import bao_core.*
import bao_collections.*
import bao_io.*
import bao_hash.*
import bao_path.*
import bao_http.*

// ============================================================================
// 字节常量 (用于 String[i] 返回 UInt8 的比较)
// ============================================================================

/// 字节常量
let B_QUOTE: UInt8 = UInt8(34)    // "
let B_BACKSLASH: UInt8 = UInt8(92) // \
let B_LBRACE: UInt8 = UInt8(123)  // {
let B_RBRACE: UInt8 = UInt8(125)  // }
let B_LBRACKET: UInt8 = UInt8(91) // [
let B_RBRACKET: UInt8 = UInt8(93) // ]
let B_COLON: UInt8 = UInt8(58)    // :
let B_COMMA: UInt8 = UInt8(44)    // ,
let B_MINUS: UInt8 = UInt8(45)    // -
let B_DOT: UInt8 = UInt8(46)      // .
let B_SPACE: UInt8 = UInt8(32)    // ' '
let B_NEWLINE: UInt8 = UInt8(10)  // \n
let B_CR: UInt8 = UInt8(13)       // \r
let B_TAB: UInt8 = UInt8(9)       // \t
let B_LOWER_N: UInt8 = UInt8(110) // n
let B_LOWER_T: UInt8 = UInt8(116) // t
let B_LOWER_R: UInt8 = UInt8(114) // r
let B_LOWER_F: UInt8 = UInt8(102) // f
let B_AT: UInt8 = UInt8(64)       // @

// ============================================================================
// 版本管理
// 对应 Bun: src/semver/
// ============================================================================

/// 包版本
/// 对应 Bun: src/semver/semver.zig
public class SemVer {
    public let major: Int64
    public let minor: Int64
    public let patch: Int64
    public var prerelease: ?String

    public init(major: Int64, minor: Int64, patch: Int64) {
        this.major = major
        this.minor = minor
        this.patch = patch
        this.prerelease = None
    }

    public func toString(): String {
        var s = "${major}.${minor}.${patch}"
        match (prerelease) {
            case Some(pre) => s = s + "-${pre}"
            case None => ()
        }
        return s
    }

    /// 从字符串解析版本号
    public static func parse(s: String): ?SemVer {
        var version = s
        if (version.startsWith("v") || version.startsWith("^") || version.startsWith("~")) {
            version = version[1..]
        }
        // 去除 prerelease 后缀
        var pre: ?String = None
        match (version.indexOf("-")) {
            case Some(dashIdx) =>
                if (dashIdx >= 0) {
                    pre = Some(version[dashIdx + 1..])
                    version = version[..dashIdx]
                }
            case None => ()
        }
        let parts = version.split(".")
        if (parts.size >= 3) {
            try {
                let maj = IntParser.parseInt(parts[0], 10)
                let min = IntParser.parseInt(parts[1], 10)
                let pat = IntParser.parseInt(parts[2], 10)
                let sv = SemVer(maj, min, pat)
                sv.prerelease = pre
                return Some(sv)
            } catch (_: Exception) {
                return None
            }
        }
        return None
    }

    /// 比较: -1 表示 this < other, 0 表示相等, 1 表示 this > other
    public func compare(other: SemVer): Int64 {
        if (major != other.major) { return if (major > other.major) { 1 } else { -1 } }
        if (minor != other.minor) { return if (minor > other.minor) { 1 } else { -1 } }
        if (patch != other.patch) { return if (patch > other.patch) { 1 } else { -1 } }
        return 0
    }

    /// 是否满足范围 (^1.2.3, ~1.2.3, >=1.0.0)
    public static func satisfies(version: SemVer, range: String): Bool {
        if (range == "*" || range == "latest") { return true }

        // 手动 trim
        var rangeStr = range
        while (rangeStr.size > 0 && (rangeStr.toArray()[0] == B_SPACE || rangeStr.toArray()[0] == B_TAB ||
               rangeStr.toArray()[0] == B_NEWLINE || rangeStr.toArray()[0] == B_CR)) {
            rangeStr = rangeStr[1..]
        }
        while (rangeStr.size > 0 && (rangeStr.toArray()[rangeStr.size - 1] == B_SPACE || rangeStr.toArray()[rangeStr.size - 1] == B_TAB ||
               rangeStr.toArray()[rangeStr.size - 1] == B_NEWLINE || rangeStr.toArray()[rangeStr.size - 1] == B_CR)) {
            rangeStr = rangeStr[..rangeStr.size - 1]
        }

        // ^1.2.3 -- 兼容版本 (主版本号相同)
        if (rangeStr.startsWith("^")) {
            let target = parse(rangeStr[1..])
            match (target) {
                case Some(t) => return version.major == t.major && version.compare(t) >= 0
                case None => return false
            }
        }

        // ~1.2.3 -- 近似版本 (主+次版本号相同)
        if (rangeStr.startsWith("~")) {
            let target = parse(rangeStr[1..])
            match (target) {
                case Some(t) => return version.major == t.major && version.minor == t.minor && version.compare(t) >= 0
                case None => return false
            }
        }

        // >=1.0.0
        if (rangeStr.startsWith(">=")) {
            let target = parse(rangeStr[2..])
            match (target) {
                case Some(t) => return version.compare(t) >= 0
                case None => return false
            }
        }

        // <=1.0.0
        if (rangeStr.startsWith("<=")) {
            let target = parse(rangeStr[2..])
            match (target) {
                case Some(t) => return version.compare(t) <= 0
                case None => return false
            }
        }

        // >1.0.0
        if (rangeStr.startsWith(">")) {
            let target = parse(rangeStr[1..])
            match (target) {
                case Some(t) => return version.compare(t) > 0
                case None => return false
            }
        }

        // <1.0.0
        if (rangeStr.startsWith("<")) {
            let target = parse(rangeStr[1..])
            match (target) {
                case Some(t) => return version.compare(t) < 0
                case None => return false
            }
        }

        // 精确版本
        let target = parse(rangeStr)
        match (target) {
            case Some(t) => return version.compare(t) == 0
            case None => return false
        }
    }
}

// ============================================================================
// 包信息
// 对应 Bun: src/install/install.zig
// ============================================================================

/// 包信息
public class PackageInfo {
    public let name: String
    public let version: SemVer
    public var dependencies: HashMap<String, String>
    public var devDependencies: HashMap<String, String>
    public var description: String
    public var `main`: String
    public var module: ?String
    public var types: ?String
    public var scripts: HashMap<String, String>

    public init(name: String, version: SemVer) {
        this.name = name
        this.version = version
        this.dependencies = HashMap<String, String>()
        this.devDependencies = HashMap<String, String>()
        this.description = ""
        this.`main` = "index.js"
        this.module = None
        this.types = None
        this.scripts = HashMap<String, String>()
    }
}

/// 锁文件条目
public class LockfileEntry {
    public let name: String
    public let version: String
    public let resolved: String  // 下载 URL
    public let integrity: String // SHA512 哈希
    public var dependencies: ArrayList<String>

    public init(name: String, version: String, resolved: String, integrity: String) {
        this.name = name
        this.version = version
        this.resolved = resolved
        this.integrity = integrity
        this.dependencies = ArrayList<String>()
    }
}

// ============================================================================
// 简易 JSON 解析器
// 对应 Bun: src/install/ 中读取 package.json 的逻辑
// ============================================================================

/// 简易 JSON 值
public enum JsonValue {
    | Null
    | JsonBool(Bool)
    | Number(Float64)
    | Str(String)
    | Array(ArrayList<JsonValue>)
    | Object(HashMap<String, JsonValue>)
}

/// 简易 JSON 解析器 -- 仅用于 package.json
public class JsonParser {
    private var src: String
    private var pos: Int64

    public init() {
        src = ""
        pos = 0
    }

    /// 解析 JSON 字符串
    public func parse(input: String): ?JsonValue {
        src = input
        pos = 0
        skipWhitespace()
        return parseValue()
    }

    private func parseValue(): ?JsonValue {
        if (pos >= src.size) { return None }
        let c = src[pos]
        if (c == B_QUOTE) { return Some(parseString()) }
        if (c == B_LBRACE) { return Some(parseObject()) }
        if (c == B_LBRACKET) { return Some(parseArray()) }
        if (c == UInt8(116) || c == UInt8(102)) { return Some(parseBool()) }  // 't' or 'f'
        if (c == UInt8(110)) { return Some(parseNull()) }  // 'n'
        if (c == B_MINUS || (c >= UInt8(48) && c <= UInt8(57))) { return Some(parseNumber()) }  // '-' or '0'-'9'
        return None
    }

    private func parseString(): JsonValue {
        pos++  // skip opening "
        let sb = StringBuilder()
        while (pos < src.size && src[pos] != B_QUOTE) {
            if (src[pos] == B_BACKSLASH && pos + 1 < src.size) {
                pos++
                let esc = src[pos]
                if (esc == B_LOWER_N) { sb.append('\n') }
                else if (esc == B_LOWER_T) { sb.append('\t') }
                else if (esc == B_LOWER_R) { sb.append('\r') }
                else if (esc == B_BACKSLASH) { sb.append('\\') }
                else if (esc == B_QUOTE) { sb.append('"') }
                else { sb.append(String(Rune(UInt32(esc)))) }
            } else {
                sb.append(String(Rune(UInt32(src[pos]))))
            }
            pos++
        }
        pos++  // skip closing "
        return JsonValue.Str(sb.toString())
    }

    private func parseObject(): JsonValue {
        pos++  // skip {
        skipWhitespace()
        let obj = HashMap<String, JsonValue>()
        if (pos < src.size && src[pos] == B_RBRACE) {
            pos++
            return JsonValue.Object(obj)
        }
        while (pos < src.size) {
            skipWhitespace()
            if (src[pos] != B_QUOTE) { () }
            let key = match (parseString()) {
                case JsonValue.Str(s) => s
                case _ => ""
            }
            skipWhitespace()
            if (pos < src.size && src[pos] == B_COLON) { pos++ }
            skipWhitespace()
            let val = parseValue()
            match (val) {
                case Some(v) => obj.put(key, v)
                case None => ()
            }
            skipWhitespace()
            if (pos < src.size && src[pos] == B_COMMA) { pos++ }
            if (pos < src.size && src[pos] == B_RBRACE) { pos++; break }
        }
        return JsonValue.Object(obj)
    }

    private func parseArray(): JsonValue {
        pos++  // skip [
        skipWhitespace()
        let arr = ArrayList<JsonValue>()
        if (pos < src.size && src[pos] == B_RBRACKET) {
            pos++
            return JsonValue.Array(arr)
        }
        while (pos < src.size) {
            skipWhitespace()
            let val = parseValue()
            match (val) {
                case Some(v) => arr.append(v)
                case None => break
            }
            skipWhitespace()
            if (pos < src.size && src[pos] == B_COMMA) { pos++ }
            if (pos < src.size && src[pos] == B_RBRACKET) { pos++; break }
        }
        return JsonValue.Array(arr)
    }

    private func parseBool(): JsonValue {
        if (src[pos..pos + 4] == "true") {
            pos += 4
            return JsonValue.JsonBool(true)
        }
        pos += 5
        return JsonValue.JsonBool(false)
    }

    private func parseNull(): JsonValue {
        pos += 4
        return JsonValue.Null
    }

    private func parseNumber(): JsonValue {
        let start = pos
        if (pos < src.size && src[pos] == B_MINUS) { pos++ }
        while (pos < src.size && src[pos] >= UInt8(48) && src[pos] <= UInt8(57)) { pos++ }
        if (pos < src.size && src[pos] == B_DOT) { pos++ }
        while (pos < src.size && src[pos] >= UInt8(48) && src[pos] <= UInt8(57)) { pos++ }
        let numStr = src[start..pos]
        try {
            return JsonValue.Number(FloatParser.parseDouble(numStr))
        } catch (_: Exception) {
            return JsonValue.Number(0.0)
        }
    }

    private func skipWhitespace(): Unit {
        while (pos < src.size && (src[pos] == B_SPACE || src[pos] == B_NEWLINE || src[pos] == B_CR || src[pos] == B_TAB)) {
            pos++
        }
    }
}

/// JsonValue 工具方法
public class JsonHelper {
    /// 获取对象字段
    public static func getField(obj: JsonValue, key: String): ?JsonValue {
        match (obj) {
            case JsonValue.Object(m) => return m.get(key)
            case _ => return None
        }
    }

    /// 获取字符串字段
    public static func getString(obj: JsonValue, key: String): ?String {
        match (getField(obj, key)) {
            case Some(JsonValue.Str(s)) => return Some(s)
            case _ => return None
        }
    }

    /// 获取对象字段中的字符串映射
    public static func getStringMap(obj: JsonValue, key: String): HashMap<String, String> {
        let result = HashMap<String, String>()
        match (getField(obj, key)) {
            case Some(JsonValue.Object(m)) =>
                for (k in m.keys()) {
                    match (m.get(k)) {
                        case Some(JsonValue.Str(v)) => result.put(k, v)
                        case _ => ()
                    }
                }
            case _ => ()
        }
        return result
    }

    /// 获取字符串数组字段
    public static func getStringArray(obj: JsonValue, key: String): ArrayList<String> {
        let result = ArrayList<String>()
        match (getField(obj, key)) {
            case Some(JsonValue.Array(arr)) =>
                for (item in arr) {
                    match (item) {
                        case JsonValue.Str(s) => result.append(s)
                        case _ => ()
                    }
                }
            case _ => ()
        }
        return result
    }

    /// 获取布尔字段
    public static func getBool(obj: JsonValue, key: String): ?Bool {
        match (getField(obj, key)) {
            case Some(JsonValue.JsonBool(b)) => return Some(b)
            case _ => return None
        }
    }
}

// ============================================================================
// 包管理器
// 对应 Bun: src/install/install.zig
// ============================================================================

/// 安装选项
public class InstallOptions {
    public var production: Bool
    public var frozen: Bool
    public var verbose: Bool

    public init() {
        production = false
        frozen = false
        verbose = false
    }
}
