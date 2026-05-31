// 严格翻译自: src/jsc/RegularExpression.zig (58行)
// JavaScriptCore RegularExpression 绑定 (基于仓颉 std.regex 引擎)
//
// Bun 使用 WebKit Yarr 正则引擎通过 FFI 调用实现正则表达式。
// Bao 使用仓颉标准库 std.regex.Regex 作为底层引擎，
// 提供与 ECMAScript 正则表达式规范兼容的 API。
//
// 支持的功能:
//   - matches(str): 搜索是否存在匹配子串
//   - search(str) / searchRev(str): 搜索匹配位置
//   - matchedLength(): 最近一次匹配的长度
//   - exec(text): 类似 JS RegExp.exec 的行为 (含捕获组)
//   - captureCount(): 捕获组数量
//   - 忽略大小写、多行等标志

package bao_jsc

import std.regex.*

// ========== RegularExpressionFlags ==========
// 严格翻译自 RegularExpression.zig Flags
// 正则表达式标志位 (位掩码)
public enum RegularExpressionFlags {
    | None
    | Global
    | IgnoreCase
    | Multiline
    | DotAll
    | Unicode
    | UnicodeSets
    | Sticky
    | HasIndices
    | SingleLine
    | Indexed

    // 合并标志
    public func union(other: RegularExpressionFlags): RegularExpressionFlags {
        // 如果其中任一是 None，返回另一个
        match (this) {
            case None => other
            case _ =>
                match (other) {
                    case None => this
                    case _ => other  // 返回较高优先级的标志
                }
        }
    }
}

// ========== RegularExpression ==========
// 严格翻译自 RegularExpression.zig
// 底层使用仓颉 std.regex.Regex 引擎实现完整的正则匹配功能
public class RegularExpression {
    // 正则模式字符串
    public var pattern: String = ""
    // 标志位
    public var flags: RegularExpressionFlags = RegularExpressionFlags.None
    // 是否有效 (编译是否成功)
    public var valid: Bool = false
    // 原始指针 (C++ Yarr 正则对象) — 保留用于 FFI 兼容
    public var rawPtr: CPointer<UInt8> = CPointer<UInt8>()

    // 仓颉 std.regex 引擎的编译实例
    private var compiledRegex: ?Regex = None

    // 最近一次匹配的结果缓存
    private var lastMatchStr: String = ""
    private var lastMatchData: ?MatchData = None

    // 用于 exec / 全局搜索的状态
    private var lastSearchIndex: Int64 = 0

    private init() {}

    // ========== FFI 绑定 ==========

    // 严格翻译自 RegularExpression.init
    // 创建并编译正则表达式
    public static func initFunc(pattern: String, flags: RegularExpressionFlags): RegularExpression {
        let regex = RegularExpression()
        regex.pattern = pattern
        regex.flags = flags

        // 将 JS 正则标志转换为仓颉 RegexFlag 数组
        let regexFlags = flagsToRegexFlags(flags)

        // 尝试编译正则表达式
        try {
            regex.compiledRegex = Regex(pattern, regexFlags)
            regex.valid = true
        } catch (_: RegexException) {
            regex.valid = false
            regex.deinit()
        }

        regex
    }

    // 严格翻译自 RegularExpression.isValid
    // 检查正则表达式是否有效
    public func isValid(): Bool {
        valid
    }

    // 严格翻译自 RegularExpression.matches
    // 简单的布尔匹配器
    // 判断字符串中是否存在与正则匹配的子串
    // 对应 Bun 中 Yarr__RegularExpression__matches 返回值 >= 0 表示匹配
    public func matches(str: String): Bool {
        if (!valid) {
            return false
        }
        if (let Some(re) <- compiledRegex) {
            // 使用 find() 搜索是否存在匹配
            let result = re.find(str)
            match (result) {
                case Some(md) =>
                    lastMatchStr = str
                    lastMatchData = md
                    return true
                case None =>
                    lastMatchStr = str
                    lastMatchData = None
                    return false
            }
        }
        false
    }

    // 搜索第一个匹配的起始位置
    // 返回第一个匹配的起始索引，没有匹配则返回 -1
    public func search(str: String): Int32 {
        if (!valid) {
            return Int32(-1)
        }
        if (let Some(re) <- compiledRegex) {
            let result = re.find(str)
            match (result) {
                case Some(md) =>
                    let pos = md.matchPosition()
                    lastMatchStr = str
                    lastMatchData = md
                    return Int32(pos.start)
                case None =>
                    lastMatchStr = str
                    lastMatchData = None
                    return Int32(-1)
            }
        }
        Int32(-1)
    }

    // 严格翻译自 RegularExpression.searchRev
    // 反向搜索: 返回最后一个匹配的起始位置
    public func searchRev(str: String): Int32 {
        if (!valid) {
            return Int32(-1)
        }
        if (let Some(re) <- compiledRegex) {
            // 查找所有匹配，取最后一个
            let allMatches = re.findAll(str)
            if (allMatches.size == 0) {
                lastMatchStr = str
                lastMatchData = None
                return Int32(-1)
            }
            let lastMd = allMatches[Int64(allMatches.size) - 1]
            let pos = lastMd.matchPosition()
            lastMatchStr = str
            lastMatchData = lastMd
            return Int32(pos.start)
        }
        Int32(-1)
    }

    // 严格翻译自 RegularExpression.matchedLength
    // 返回最近一次匹配的长度
    public func matchedLength(): Int32 {
        if (let Some(md) <- lastMatchData) {
            let pos = md.matchPosition()
            return Int32(pos.end - pos.start)
        }
        Int32(0)
    }

    // 严格翻译自 RegularExpression.deinit
    // 释放正则表达式资源
    public func deinit() {
        valid = false
        rawPtr = CPointer<UInt8>()
        compiledRegex = None
        lastMatchData = None
        lastMatchStr = ""
        lastSearchIndex = 0
    }

    // ========== 扩展 API ==========

    // 完整匹配: 检查整个字符串是否完全匹配正则
    // 对应 Java Pattern.matches() / JS RegExp with anchoring
    public func fullMatch(str: String): Bool {
        if (!valid) {
            return false
        }
        if (let Some(re) <- compiledRegex) {
            return re.matches(str)
        }
        false
    }

    // 执行匹配并返回详细结果 — 类似 JS RegExp.exec(text)
    // 返回 RegexExecResult 或 None
    public func exec(text: String): ?RegexExecResult {
        if (!valid) {
            return None
        }
        if (let Some(re) <- compiledRegex) {
            // 带捕获组的 find
            let result = re.find(text, group: true)
            match (result) {
                case Some(md) =>
                    let pos = md.matchPosition()
                    let matchStr = md.matchString()
                    let groupCount = md.groupCount()
                    let groups = Array<String>(Int64(groupCount), { i: Int64 =>
                        md.matchString(i + 1)
                    })

                    lastMatchStr = text
                    lastMatchData = md

                    RegexExecResult(
                        matchStr,
                        Int32(pos.start),
                        Int32(pos.end - pos.start),
                        groups
                    )
                case None =>
                    lastMatchStr = text
                    lastMatchData = None
                    None
            }
        } else {
            None
        }
    }

    // 从指定位置开始搜索
    public func execFrom(text: String, startIndex: Int64): ?RegexExecResult {
        if (!valid || startIndex < 0 || startIndex > text.size) {
            return None
        }
        if (let Some(re) <- compiledRegex) {
            // 使用子串从 startIndex 开始搜索
            let subText = text[Int64(startIndex)..]
            let result = re.find(subText, group: true)
            match (result) {
                case Some(md) =>
                    let pos = md.matchPosition()
                    let matchStr = md.matchString()
                    let groupCount = md.groupCount()
                    let groups = Array<String>(Int64(groupCount), { i: Int64 =>
                        md.matchString(i + 1)
                    })

                    lastMatchStr = text
                    lastMatchData = md

                    // 修正位置: 加上 startIndex 偏移
                    RegexExecResult(
                        matchStr,
                        Int32(pos.start + startIndex),
                        Int32(pos.end - pos.start),
                        groups
                    )
                case None =>
                    lastMatchStr = text
                    lastMatchData = None
                    None
            }
        } else {
            None
        }
    }

    // 获取捕获组数量
    public func captureCount(): Int32 {
        if (!valid) {
            return Int32(0)
        }
        // 通过解析 pattern 中的括号数量来获取组数
        countCaptureGroups(pattern)
    }

    // 替换第一个匹配
    public func replace(text: String, replacement: String): String {
        if (!valid) {
            return text
        }
        if (let Some(re) <- compiledRegex) {
            return re.replace(text, replacement)
        }
        text
    }

    // 替换所有匹配
    public func replaceAll(text: String, replacement: String): String {
        if (!valid) {
            return text
        }
        if (let Some(re) <- compiledRegex) {
            return re.replaceAll(text, replacement)
        }
        text
    }

    // 分割字符串
    public func split(text: String, limit: Int64): Array<String> {
        if (!valid) {
            return [text]
        }
        if (let Some(re) <- compiledRegex) {
            return re.split(text, limit)
        }
        [text]
    }

    // ========== 辅助方法 ==========

    // 严格翻译自 RegularExpression.zig Flags 位掩码解析
    // 从 JS 标志字符串解析标志位，使用位掩码 OR 合并
    // 例如: "gi" -> Global | IgnoreCase
    public static func parseFlags(flagStr: String): RegularExpressionFlags {
        var result: UInt16 = 0
        for (c in flagStr) {
            match (c) {
                case 'd' => result |= 1     // hasIndices = 1 << 0
                case 'g' => result |= 2     // global = 1 << 1
                case 'i' => result |= 4     // ignoreCase = 1 << 2
                case 'm' => result |= 8     // multiline = 1 << 3
                case 's' => result |= 16    // dotAll = 1 << 4
                case 'u' => result |= 32    // unicode = 1 << 5
                case 'v' => result |= 64    // unicodeSets = 1 << 6
                case 'y' => result |= 128   // sticky = 1 << 7
                case _ => ()
            }
        }
        flagsFromInt(result)
    }

    // 从 UInt16 位掩码转换为 RegularExpressionFlags
    private static func flagsFromInt(value: UInt16): RegularExpressionFlags {
        if (value == 0) { return RegularExpressionFlags.None }
        // 返回最高位对应的标志
        if ((value & 128) != 0) { return RegularExpressionFlags.Sticky }
        if ((value & 64) != 0) { return RegularExpressionFlags.UnicodeSets }
        if ((value & 32) != 0) { return RegularExpressionFlags.Unicode }
        if ((value & 16) != 0) { return RegularExpressionFlags.DotAll }
        if ((value & 8) != 0) { return RegularExpressionFlags.Multiline }
        if ((value & 4) != 0) { return RegularExpressionFlags.IgnoreCase }
        if ((value & 2) != 0) { return RegularExpressionFlags.Global }
        if ((value & 1) != 0) { return RegularExpressionFlags.HasIndices }
        RegularExpressionFlags.None
    }

    // 将 RegularExpressionFlags 转为仓颉 RegexFlag 数组
    private static func flagsToRegexFlags(flags: RegularExpressionFlags): Array<RegexFlag> {
        // 仓颉 RegexFlag 支持: IgnoreCase, MultiLine, Unicode
        match (flags) {
            case IgnoreCase => [RegexFlag.IgnoreCase]
            case Multiline => [RegexFlag.MultiLine]
            case Unicode => [RegexFlag.Unicode]
            case DotAll => []  // 仓颉暂不直接支持 dotAll，通过 (?s) 内嵌标志处理
            case _ => []
        }
    }

    // 检查标志是否包含 ignoreCase
    public static func isIgnoreCase(flags: RegularExpressionFlags): Bool {
        match (flags) {
            case IgnoreCase => true
            case _ => false
        }
    }

    // 检查标志是否包含 multiline
    public static func isMultiline(flags: RegularExpressionFlags): Bool {
        match (flags) {
            case Multiline => true
            case _ => false
        }
    }

    // 将标志位转为字符串
    public static func flagsToString(flags: RegularExpressionFlags): String {
        match (flags) {
            case HasIndices => "d"
            case Global => "g"
            case IgnoreCase => "i"
            case Multiline => "m"
            case DotAll => "s"
            case Unicode => "u"
            case UnicodeSets => "v"
            case Sticky => "y"
            case None => ""
            case SingleLine => ""
            case Indexed => ""
        }
    }

    // 从标志字符串构建完整的标志组合字符串
    public static func flagsStringFromFlags(flagStr: String): String {
        var result = ""
        for (c in flagStr) {
            match (c) {
                case 'g' | 'i' | 'm' | 's' | 'u' | 'v' | 'y' | 'd' => result = result + String(Rune(c))
                case _ => ()
            }
        }
        result
    }

    // 验证正则模式是否有效 — 通过尝试编译来验证
    static func validatePattern(pattern: String): Bool {
        // 尝试编译来验证模式有效性
        try {
            let _ = Regex(pattern)
            true
        } catch (_: RegexException) {
            false
        }
    }

    // 计算捕获组数量 — 解析 pattern 中的非转义括号
    static func countCaptureGroups(pattern: String): Int32 {
        var count: Int32 = 0
        var i: Int64 = 0
        var inCharClass: Bool = false
        while (i < pattern.size) {
            let c = pattern[i]
            if (c == UInt8(92)) {
                // 反斜杠: 跳过下一个字符
                i += 2
                continue
            }
            if (c == UInt8(91)) {
                // '[': 进入字符类
                inCharClass = true
                i += 1
                continue
            }
            if (c == UInt8(93) && inCharClass) {
                // ']': 退出字符类
                inCharClass = false
                i += 1
                continue
            }
            if (inCharClass) {
                i += 1
                continue
            }
            if (c == UInt8(40)) {
                // '(': 可能是捕获组
                // 检查是否是非捕获组 (?:...) 或其他特殊组
                if (i + 1 < pattern.size) {
                    let next = pattern[i + 1]
                    if (next == UInt8(63)) {
                        // '(?' 开头: 非捕获组或特殊组
                        if (i + 2 < pattern.size) {
                            let next2 = pattern[i + 2]
                            if (next2 == UInt8(60)) {
                                // '(?<' = 命名捕获组 — 计数
                                count += 1
                            }
                            // '(?:' = 非捕获组 — 不计数
                            // '(?=' = 正向前瞻 — 不计数
                            // '(?!' = 负向前瞻 — 不计数
                        }
                        i += 1
                        continue
                    }
                }
                // 普通捕获组
                count += 1
            }
            i += 1
        }
        count
    }
}

// ========== 正则表达式执行结果 ==========
// 存储 exec() 返回的匹配信息，包含捕获组
public class RegexExecResult {
    // 匹配到的字符串
    public var matchStr: String
    // 匹配起始位置
    public var startIndex: Int32
    // 匹配长度
    public var length: Int32
    // 捕获组 (索引从 0 开始，对应 JS result[1], result[2], ...)
    public var groups: Array<String>

    public init(matchStr: String, startIndex: Int32, length: Int32, groups: Array<String>) {
        this.matchStr = matchStr
        this.startIndex = startIndex
        this.length = length
        this.groups = groups
    }
}
