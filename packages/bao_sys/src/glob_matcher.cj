// bao_sys - Glob 模式匹配器 (完整模块)
// 严格翻译自: src/glob/
//   Bun 的 glob 实现:
//   - matcher.zig: 完整的 glob 匹配算法
//   - glob.zig: detectGlobSyntax, GlobWalker
//   - 支持: *, **, ?, [abc], [a-z], {a,b}, !negation, \escape
//   此处提供:
//   - GlobPattern: 解析模式为 AST
//   - GlobMatcher: 完整的 NFA 风格匹配
//   - 花括号展开, 取反, 大小写敏感选项
package bao_sys

import bao_core.*

// ============================================================================
// Glob 模式 AST 节点
// 严格翻译自: src/glob/matcher.zig 中的模式解析
//   Bun 使用逐字符解析 + 状态机匹配
// ============================================================================

/// Glob 模式段类型
/// 对应 Bun matcher.zig 中 switch(char) 分支
public enum GlobSegmentKind {
    | Literal     // 普通字符
    | Star        // *  (匹配 0+ 非 / 字符)
    | DoubleStar  // ** (匹配 0+ 跨 / 字符)
    | CharClass   // [abc] 或 [a-z]
    | Question    // ?  (匹配 1 个非 / 字符)
    | Alternation // {a,b,c}
}

/// 字符类范围
/// 对应 Bun matcher.zig 中的 [a-z] 解析
public class CharRange {
    /// 范围下界
    public var low: UInt8
    /// 范围上界
    public var high: UInt8

    public init(low: UInt8, high: UInt8) {
        this.low = low
        this.high = high
    }

    /// 单字符构造
    public init(ch: UInt8) {
        this.low = ch
        this.high = ch
    }

    /// 是否包含指定字符
    public func contains(ch: UInt8): Bool {
        return ch >= low && ch <= high
    }
}

/// 字符类 (方括号表达式)
/// 对应 Bun matcher.zig 中 '[' 分支
public class CharClassExpr {
    /// 是否取反 ([!...] 或 [^...])
    public var negated: Bool
    /// 字符范围列表
    public var ranges: ArrayList<CharRange>

    public init() {
        negated = false
        ranges = ArrayList<CharRange>()
    }

    public init(negated: Bool) {
        this.negated = negated
        this.ranges = ArrayList<CharRange>()
    }

    /// 添加范围
    public func addRange(low: UInt8, high: UInt8): Unit {
        ranges.append(CharRange(low, high))
    }

    /// 添加单字符
    public func addChar(ch: UInt8): Unit {
        ranges.append(CharRange(ch))
    }

    /// 是否匹配指定字符
    /// 对应 Bun: is_match != negated 逻辑
    public func matches(ch: UInt8): Bool {
        var found = false
        for (range in ranges) {
            if (range.contains(ch)) {
                found = true
                break
            }
        }
        return found != negated
    }
}

/// Glob 模式段
/// 对应 Bun matcher.zig 中 State 处理的各个模式元素
public class GlobSegment {
    /// 段类型
    public var kind: GlobSegmentKind
    /// 字面量值 (Literal)
    public var literal: String
    /// 字符类 (CharClass)
    public var charClass: ?CharClassExpr
    /// 替代选项 (Alternation)
    public var alternatives: ArrayList<String>

    public init(kind: GlobSegmentKind) {
        this.kind = kind
        this.literal = ""
        this.charClass = None
        this.alternatives = ArrayList<String>()
    }

    public static func literal(s: String): GlobSegment {
        let seg = GlobSegment(GlobSegmentKind.Literal)
        seg.literal = s
        return seg
    }

    public static func star(): GlobSegment {
        return GlobSegment(GlobSegmentKind.Star)
    }

    public static func doubleStar(): GlobSegment {
        return GlobSegment(GlobSegmentKind.DoubleStar)
    }

    public static func question(): GlobSegment {
        return GlobSegment(GlobSegmentKind.Question)
    }

    public static func charClass(cc: CharClassExpr): GlobSegment {
        let seg = GlobSegment(GlobSegmentKind.CharClass)
        seg.charClass = Some(cc)
        return seg
    }

    public static func alternation(alts: ArrayList<String>): GlobSegment {
        let seg = GlobSegment(GlobSegmentKind.Alternation)
        seg.alternatives = alts
        return seg
    }
}

// ============================================================================
// GlobPattern - 模式解析
// 严格翻译自: src/glob/glob.zig detectGlobSyntax + matcher.zig 解析
// ============================================================================

/// 解析后的 Glob 模式
/// 对应 Bun: 将模式字符串解析为段序列
public class GlobPattern {
    /// 原始模式字符串
    public var raw: String
    /// 解析后的段列表
    public var segments: ArrayList<GlobSegment>
    /// 是否取反 (! 前缀)
    public var negated: Bool
    /// 取反次数 (多重 !! 翻转)
    public var negateCount: Int64
    /// 是否大小写敏感
    public var caseSensitive: Bool

    public init(pattern: String) {
        this.raw = pattern
        this.segments = ArrayList<GlobSegment>()
        this.negated = false
        this.negateCount = 0
        this.caseSensitive = true
        parse()
    }

    public init(pattern: String, caseSensitive: Bool) {
        this.raw = pattern
        this.segments = ArrayList<GlobSegment>()
        this.negated = false
        this.negateCount = 0
        this.caseSensitive = caseSensitive
        parse()
    }

    /// 解析模式字符串为段列表
    /// 严格对应 Bun matcher.zig 中的逐字符解析逻辑
    private func parse(): Unit {
        var idx = 0
        let pattern = raw

        // 处理前导 ! 取反
        // 对应 Bun: while (glob_index < glob.len and glob[glob_index] == '!')
        while (idx < pattern.size && pattern[Int64(idx)] == Char('!')) {
            negated = !negated
            negateCount += 1
            idx += 1
        }

        // 解析剩余模式
        while (idx < pattern.size) {
            let ch = pattern[Int64(idx)]

            if (ch == Char('*')) {
                // 检查 ** (DoubleStar)
                // 对应 Bun: is_globstar = glob_index + 1 < glob.len and glob[index+1] == '*'
                if (idx + 1 < pattern.size && pattern[Int64(idx + 1)] == Char('*')) {
                    segments.append(GlobSegment.doubleStar())
                    // 跳过连续的 **/
                    // 对应 Bun: skipGlobstars()
                    idx += 2
                    while (idx + 3 < pattern.size &&
                           pattern[Int64(idx)] == Char('/') &&
                           pattern[Int64(idx + 1)] == Char('*') &&
                           pattern[Int64(idx + 2)] == Char('*')) {
                        idx += 3
                    }
                    // 跳过尾部的 /**
                    if (idx + 2 < pattern.size &&
                        pattern[Int64(idx)] == Char('/') &&
                        pattern[Int64(idx + 1)] == Char('*') &&
                        pattern[Int64(idx + 2)] == Char('*')) {
                        idx += 3
                    }
                } else {
                    segments.append(GlobSegment.star())
                    idx += 1
                }
            } else if (ch == Char('?')) {
                segments.append(GlobSegment.question())
                idx += 1
            } else if (ch == Char('[')) {
                // 解析字符类
                let (newIdx, cc) = parseCharClass(pattern, idx)
                match (cc) {
                    case Some(charClass) => segments.append(GlobSegment.charClass(charClass))
                    case None => segments.append(GlobSegment.literal("["))
                }
                idx = newIdx
            } else if (ch == Char('{')) {
                // 解析花括号替代
                let (newIdx, alts) = parseAlternation(pattern, idx)
                segments.append(GlobSegment.alternation(alts))
                idx = newIdx
            } else if (ch == Char('\\')) {
                // 转义字符
                // 对应 Bun: unescape()
                if (idx + 1 < pattern.size) {
                    let next = pattern[Int64(idx + 1)]
                    let escaped = unescapeChar(next)
                    segments.append(GlobSegment.literal(escaped))
                    idx += 2
                } else {
                    idx += 1
                }
            } else {
                // 收集连续字面量字符
                var literal = StringBuilder()
                while (idx < pattern.size) {
                    let c = pattern[Int64(idx)]
                    if (c == Char('*') || c == Char('?') || c == Char('[') ||
                        c == Char('{') || c == Char('\\')) {
                        break
                    }
                    literal.append(c)
                    idx += 1
                }
                if (literal.length > 0) {
                    segments.append(GlobSegment.literal(literal.toString()))
                }
            }
        }
    }

    /// 解析字符类 [abc] 或 [a-z] 或 [!abc]
    /// 严格对应 Bun matcher.zig 中 '[' 分支
    private func parseCharClass(pattern: String, startIdx: Int64): (Int64, ?CharClassExpr) {
        var idx = startIdx + 1  // 跳过 [
        if (idx >= pattern.size) {
            return (idx, None)
        }

        let cc = CharClassExpr()

        // 检查取反 [!] 或 [^]
        // 对应 Bun: if (glob[index] == '^' or glob[index] == '!')
        if (idx < pattern.size && (pattern[Int64(idx)] == Char('!') || pattern[Int64(idx)] == Char('^'))) {
            cc.negated = true
            idx += 1
        }

        // 解析字符/范围
        while (idx < pattern.size && pattern[Int64(idx)] != Char(']')) {
            // 处理转义
            if (pattern[Int64(idx)] == Char('\\') && idx + 1 < pattern.size) {
                idx += 1
                let ch = UInt8(pattern[Int64(idx)].value)
                // 检查范围: \a-\z
                if (idx + 2 < pattern.size && pattern[Int64(idx + 1)] == Char('-') && pattern[Int64(idx + 2)] != Char(']')) {
                    let low = ch
                    idx += 2
                    let high = UInt8(pattern[Int64(idx)].value)
                    cc.addRange(low, high)
                } else {
                    cc.addChar(ch)
                }
                idx += 1
            } else {
                let ch = UInt8(pattern[Int64(idx)].value)
                // 检查范围: a-z
                if (idx + 2 < pattern.size && pattern[Int64(idx + 1)] == Char('-') && pattern[Int64(idx + 2)] != Char(']')) {
                    let low = ch
                    idx += 2
                    // 处理结束字符的转义
                    if (pattern[Int64(idx)] == Char('\\') && idx + 1 < pattern.size) {
                        idx += 1
                    }
                    let high = UInt8(pattern[Int64(idx)].value)
                    cc.addRange(low, high)
                } else {
                    cc.addChar(ch)
                }
                idx += 1
            }
        }

        // 跳过 ]
        if (idx < pattern.size && pattern[Int64(idx)] == Char(']')) {
            idx += 1
        }

        return (idx, Some(cc))
    }

    /// 解析花括号替代 {a,b,c}
    /// 严格对应 Bun matcher.zig 中 matchBrace
    private func parseAlternation(pattern: String, startIdx: Int64): (Int64, ArrayList<String>) {
        var idx = startIdx + 1  // 跳过 {
        var alternatives = ArrayList<String>()
        var current = StringBuilder()
        var depth = 1

        while (idx < pattern.size && depth > 0) {
            let ch = pattern[Int64(idx)]
            if (ch == Char('\\') && idx + 1 < pattern.size) {
                current.append(pattern[Int64(idx + 1)])
                idx += 2
            } else if (ch == Char('{')) {
                depth += 1
                current.append(ch)
                idx += 1
            } else if (ch == Char('}')) {
                depth -= 1
                if (depth == 0) {
                    alternatives.append(current.toString())
                } else {
                    current.append(ch)
                }
                idx += 1
            } else if (ch == Char(',') && depth == 1) {
                alternatives.append(current.toString())
                current = StringBuilder()
                idx += 1
            } else {
                current.append(ch)
                idx += 1
            }
        }

        return (idx, alternatives)
    }

    /// 转义字符处理
    /// 对应 Bun matcher.zig: unescape()
    private func unescapeChar(ch: Char): String {
        match (ch) {
            case Char('a') => "a"      // \a -> alarm (literal 'a' in Bun)
            case Char('b') => "\b"     // \b -> backspace
            case Char('n') => "\n"     // \n -> newline
            case Char('r') => "\r"     // \r -> carriage return
            case Char('t') => "\t"     // \t -> tab
            case _ => ch.toString()    // 其他: 字面量
        }
    }
}

// ============================================================================
// GlobMatcher - 匹配引擎
// 严格翻译自: src/glob/matcher.zig match() / globMatchImpl()
//   Bun 使用 NFA 风格的回溯匹配:
//   - State 结构体跟踪 glob_index, path_index, wildcard, globstar
//   - 支持 * 和 ** 的回溯
//   - 嵌套花括号支持到 10 层
// ============================================================================

/// 匹配结果
/// 对应 Bun: MatchResult enum
public enum GlobMatchResult {
    | NoMatch       // 不匹配
    | Match         // 匹配
    | NegateNoMatch // 取反后不匹配 (原模式匹配, 取反翻转为不匹配)
    | NegateMatch   // 取反后匹配 (原模式不匹配, 取反翻转为匹配)

    /// 是否匹配
    public func isMatch(): Bool {
        match (this) {
            case Match => true
            case NegateMatch => true
            case NoMatch => false
            case NegateNoMatch => false
        }
    }
}

/// 匹配状态
/// 对应 Bun matcher.zig: State struct
private class MatchState {
    var globIndex: Int64
    var pathIndex: Int64
    var wildcardGlobIdx: Int64
    var wildcardPathIdx: Int64
    var globstarGlobIdx: Int64
    var globstarPathIdx: Int64
    var hasWildcard: Bool
    var hasGlobstar: Bool

    init() {
        globIndex = 0
        pathIndex = 0
        wildcardGlobIdx = 0
        wildcardPathIdx = 0
        globstarGlobIdx = 0
        globstarPathIdx = 0
        hasWildcard = false
        hasGlobstar = false
    }

    init(globIdx: Int64, pathIdx: Int64) {
        globIndex = globIdx
        pathIndex = pathIdx
        wildcardGlobIdx = 0
        wildcardPathIdx = 0
        globstarGlobIdx = 0
        globstarPathIdx = 0
        hasWildcard = false
        hasGlobstar = false
    }

    /// 回溯到上一个通配符位置
    /// 对应 Bun: State.backtrack()
    func backtrack(): Unit {
        pathIndex = wildcardPathIdx
        globIndex = wildcardGlobIdx
    }
}

/// Glob 匹配器
/// 严格翻译自 src/glob/matcher.zig
public class GlobMatcher {
    /// 是否大小写敏感
    private var caseSensitive: Bool

    public init() {
        caseSensitive = true
    }

    public init(caseSensitive: Bool) {
        this.caseSensitive = caseSensitive
    }

    /// 匹配 glob 模式与路径
    /// 对应 Bun: match(glob, path) -> MatchResult
    public func match(glob: String, path: String): GlobMatchResult {
        let state = MatchState()
        var negated = false

        // 处理前导 ! 取反
        // 对应 Bun: while (glob_index < glob.len and glob[glob_index] == '!')
        while (state.globIndex < glob.size && glob[Int64(state.globIndex)] == Char('!')) {
            negated = !negated
            state.globIndex += 1
        }

        let matched = matchImpl(glob, path, state)

        // 对应 Bun: negate 逻辑
        if (negated) {
            return if (matched) { GlobMatchResult.NegateNoMatch } else { GlobMatchResult.NegateMatch }
        } else {
            return if (matched) { GlobMatchResult.Match } else { GlobMatchResult.NoMatch }
        }
    }

    /// 静态匹配方法
    public static func match(pattern: String, path: String): Bool {
        return GlobMatcher().match(pattern, path).isMatch()
    }

    /// 静态匹配方法 (带大小写选项)
    public static func match(pattern: String, path: String, caseSensitive: Bool): Bool {
        return GlobMatcher(caseSensitive).match(pattern, path).isMatch()
    }

    /// 核心匹配实现
    /// 严格翻译自 Bun matcher.zig: globMatchImpl()
    /// 使用 NFA 风格回溯: * 和 ** 记录回溯点
    private func matchImpl(glob: String, path: String, state: MatchState): Bool {
        // 主循环
        // 对应 Bun: main_loop: while (glob_index < glob.len or path_index < path.len)
        while (state.globIndex < glob.size || state.pathIndex < path.size) {
            if (state.globIndex < glob.size) {
                let ch = glob[Int64(state.globIndex)]

                match (ch) {
                    case Char('*') => {
                        // 检查 ** (globstar)
                        let isGlobstar = state.globIndex + 1 < glob.size &&
                                         glob[Int64(state.globIndex + 1)] == Char('*')

                        if (isGlobstar) {
                            // 跳过连续 **/
                            state.globIndex = skipGlobstars(glob, state.globIndex)
                        }

                        // 记录通配符回溯点
                        state.wildcardGlobIdx = state.globIndex
                        state.wildcardPathIdx = state.pathIndex + 1
                        state.hasWildcard = true

                        if (isGlobstar) {
                            state.globIndex += 2

                            // 检查 ** 是否需要匹配路径分隔符
                            let isEndInvalid = state.globIndex < glob.size

                            // 跳过尾部的 /**
                            if (isEndInvalid && state.globIndex + 2 <= glob.size) {
                                let remaining = glob.size - state.globIndex
                                if (remaining == 2 && glob[Int64(state.globIndex)] == Char('/') &&
                                    glob[Int64(state.globIndex + 1)] == Char('*')) {
                                    continue
                                }
                            }

                            // ** 必须匹配完整路径段
                            let idx3 = if (state.globIndex >= 3) { state.globIndex - 3 } else { 0 }
                            if (state.globIndex - 0 < 3 || glob[Int64(idx3)] == Char('/')) {
                                if (!isEndInvalid || glob[Int64(state.globIndex)] == Char('/')) {
                                    if (isEndInvalid) {
                                        state.globIndex += 1
                                    }
                                    // 记录 globstar 位置
                                    state.globstarGlobIdx = state.wildcardGlobIdx
                                    state.globstarPathIdx = state.wildcardPathIdx
                                    state.hasGlobstar = true
                                    // 跳到下一个分隔符
                                    skipToSeparator(state, path, isEndInvalid)
                                } else {
                                    state.globIndex += 1
                                }
                            } else {
                                state.globIndex += 1
                            }
                        } else {
                            state.globIndex += 1
                        }

                        // * 不跨越 /
                        if (!isGlobstar && state.pathIndex < path.size &&
                            isSeparator(path[Int64(state.pathIndex)])) {
                            if (state.hasGlobstar) {
                                state.wildcardGlobIdx = state.globstarGlobIdx
                                state.wildcardPathIdx = state.globstarPathIdx
                            }
                        }

                        continue
                    }
                    case Char('?') => {
                        // ? 匹配单个非 / 字符
                        if (state.pathIndex < path.size) {
                            if (!isSeparator(path[Int64(state.pathIndex)])) {
                                state.globIndex += 1
                                state.pathIndex += 1
                                continue
                            }
                        } else {
                            // 路径耗尽, 需要回溯
                        }
                    }
                    case Char('[') => {
                        // 字符类匹配
                        if (state.pathIndex < path.size) {
                            state.globIndex += 1
                            var charNegated = false
                            if (state.globIndex < glob.size &&
                                (glob[Int64(state.globIndex)] == Char('^') || glob[Int64(state.globIndex)] == Char('!'))) {
                                charNegated = true
                                state.globIndex += 1
                            }

                            var isMatch = false
                            var first = true
                            let pathCh = UInt8(path[Int64(state.pathIndex)].value)

                            while (state.globIndex < glob.size && (first || glob[Int64(state.globIndex)] != Char(']'))) {
                                first = false
                                if (state.globIndex >= glob.size) { break }

                                var low = glob[Int64(state.globIndex)]
                                var lowVal = UInt8(low.value)
                                state.globIndex += 1

                                // 检查范围 a-z
                                var highVal = lowVal
                                if (state.globIndex + 1 < glob.size &&
                                    glob[Int64(state.globIndex)] == Char('-') &&
                                    glob[Int64(state.globIndex + 1)] != Char(']')) {
                                    state.globIndex += 1
                                    highVal = UInt8(glob[Int64(state.globIndex)].value)
                                    state.globIndex += 1
                                }

                                if (lowVal <= pathCh && pathCh <= highVal) {
                                    isMatch = true
                                }
                            }

                            // 跳过 ]
                            if (state.globIndex < glob.size && glob[Int64(state.globIndex)] == Char(']')) {
                                state.globIndex += 1
                            }

                            if (isMatch != charNegated) {
                                state.pathIndex += 1
                                continue
                            }
                            // 不匹配, 回溯
                        }
                    }
                    case Char('{') => {
                        // 花括号替代 - 展开所有选项并尝试
                        let result = tryAlternatives(glob, path, state)
                        if (result) { continue }
                    }
                    case Char(',') => {
                        // 在花括号内的逗号, 应该由花括号处理
                    }
                    case Char('}') => {
                        // 闭合花括号
                    }
                    case _ => {
                        // 字面量匹配 (含转义处理)
                        var cc = ch
                        if (cc == Char('\\')) {
                            state.globIndex += 1
                            if (state.globIndex >= glob.size) { return false }
                            cc = glob[Int64(state.globIndex)]
                        }

                        // 路径字符比较
                        if (state.pathIndex < path.size) {
                            let pathCh = path[Int64(state.pathIndex)]
                            let isMatch = if (cc == Char('/')) {
                                isSeparator(pathCh)
                            } else if (caseSensitive) {
                                cc == pathCh
                            } else {
                                cc.toLower() == pathCh.toLower()
                            }

                            if (isMatch) {
                                state.globIndex += 1
                                state.pathIndex += 1
                                if (cc == Char('/') && state.hasGlobstar) {
                                    state.wildcardGlobIdx = state.globstarGlobIdx
                                    state.wildcardPathIdx = state.globstarPathIdx
                                }
                                continue
                            }
                        }
                    }
                }
            }

            // 回溯
            if (state.hasWildcard && state.wildcardPathIdx > 0 && state.wildcardPathIdx <= path.size) {
                state.backtrack()
                continue
            }

            return false
        }

        return true
    }

    /// 跳过连续的 **/ 段
    /// 对应 Bun: skipGlobstars()
    private func skipGlobstars(glob: String, idx: Int64): Int64 {
        var i = idx + 2
        while (i + 3 <= glob.size) {
            let s = glob.substring(Int64(i), Int64(i + 3))
            if (s == "/**") {
                if (i + 3 == glob.size) {
                    return i
                }
                // 检查是否是 **/
                if (glob[Int64(i + 3)] == Char('/')) {
                    i += 3
                } else {
                    break
                }
            } else {
                break
            }
        }
        return i - 2
    }

    /// 跳到路径中的下一个分隔符
    /// 对应 Bun: State.skipToSeparator()
    private func skipToSeparator(state: MatchState, path: String, isEndInvalid: Bool): Unit {
        if (state.pathIndex >= path.size) {
            state.wildcardPathIdx += 1
            return
        }

        var pathIdx = state.pathIndex
        while (pathIdx < path.size && !isSeparator(path[Int64(pathIdx)])) {
            pathIdx += 1
        }

        if (isEndInvalid || pathIdx != path.size) {
            pathIdx += 1
        }

        state.wildcardPathIdx = pathIdx
    }

    /// 尝试花括号替代
    /// 对应 Bun: matchBrace() + matchBraceBranch()
    private func tryAlternatives(glob: String, path: String, state: MatchState): Bool {
        // 找到花括号内的所有选项
        var idx = state.globIndex + 1  // 跳过 {
        var alternatives = ArrayList<String>()
        var current = StringBuilder()
        var depth = 1

        while (idx < glob.size && depth > 0) {
            let ch = glob[Int64(idx)]
            if (ch == Char('\\') && idx + 1 < glob.size) {
                current.append(glob[Int64(idx + 1)])
                idx += 2
            } else if (ch == Char('{')) {
                depth += 1
                current.append(ch)
                idx += 1
            } else if (ch == Char('}')) {
                depth -= 1
                if (depth == 0) {
                    alternatives.append(current.toString())
                } else {
                    current.append(ch)
                }
                idx += 1
            } else if (ch == Char(',') && depth == 1) {
                alternatives.append(current.toString())
                current = StringBuilder()
                idx += 1
            } else {
                current.append(ch)
                idx += 1
            }
        }

        // 构建剩余模式 (花括号之后)
        let rest = glob.substring(Int64(idx))

        // 尝试每个选项
        for (alt in alternatives) {
            let newGlob = alt + rest
            let result = GlobMatcher(caseSensitive).match(newGlob, path.substring(Int64(state.pathIndex)))
            if (result.isMatch()) {
                return true
            }
        }

        return false
    }

    /// 判断是否为路径分隔符
    /// 对应 Bun: isSeparator() - Linux: '/', Windows: '/' or '\'
    private func isSeparator(ch: Char): Bool {
        return ch == Char('/')
    }
}

// ============================================================================
// 花括号展开
// 严格翻译自: src/glob/glob.zig detectGlobSyntax
//   将 {a,b,c} 展开为多个模式
// ============================================================================

/// 花括号展开器
/// 对应 Bun: detectGlobSyntax + brace expansion
public class BraceExpander {
    /// 展开花括号, 返回所有展开后的模式
    public static func expand(pattern: String): ArrayList<String> {
        var results = ArrayList<String>()
        results.append(pattern)
        return expandAll(results)
    }

    /// 递归展开所有花括号
    private static func expandAll(patterns: ArrayList<String>): ArrayList<String> {
        var changed = true
        var current = patterns
        var iterations = 0

        while (changed && iterations < 100) {
            changed = false
            iterations += 1
            var next = ArrayList<String>()

            for (pattern in current) {
                let expanded = expandOne(pattern)
                if (expanded.size > 1) {
                    changed = true
                }
                for (p in expanded) {
                    next.append(p)
                }
            }

            current = next
        }

        return current
    }

    /// 展开最内层的一对花括号
    private static func expandOne(pattern: String): ArrayList<String> {
        // 找到最内层的 { }
        var lastOpen = -1
        var depth = 0
        var maxDepth = 0
        var deepestOpen = -1

        for (i in 0..pattern.size) {
            if (pattern[Int64(i)] == Char('\\')) {
                continue  // 跳过转义
            }
            if (pattern[Int64(i)] == Char('{')) {
                depth += 1
                if (depth > maxDepth) {
                    maxDepth = depth
                    deepestOpen = i
                }
            } else if (pattern[Int64(i)] == Char('}')) {
                if (depth > 0) {
                    depth -= 1
                }
            }
        }

        if (deepestOpen < 0 || maxDepth == 0) {
            var result = ArrayList<String>()
            result.append(pattern)
            return result
        }

        // 从最深的 { 开始找配对的 }
        var closeIdx = -1
        depth = 0
        for (i in deepestOpen..pattern.size) {
            if (pattern[Int64(i)] == Char('{')) {
                depth += 1
            } else if (pattern[Int64(i)] == Char('}')) {
                depth -= 1
                if (depth == 0) {
                    closeIdx = i
                    break
                }
            }
        }

        if (closeIdx < 0) {
            var result = ArrayList<String>()
            result.append(pattern)
            return result
        }

        // 提取选项
        let inner = pattern.substring(Int64(deepestOpen + 1), Int64(closeIdx))
        let options = splitAlternatives(inner)
        let before = pattern.substring(0, Int64(deepestOpen))
        let after = if (closeIdx + 1 < pattern.size) {
            pattern.substring(Int64(closeIdx + 1))
        } else {
            ""
        }

        var results = ArrayList<String>()
        for (opt in options) {
            results.append("${before}${opt}${after}")
        }
        return results
    }

    /// 分割花括号内的选项 (考虑嵌套)
    private static func splitAlternatives(s: String): ArrayList<String> {
        var options = ArrayList<String>()
        var current = StringBuilder()
        var depth = 0

        for (i in 0..s.size) {
            let ch = s[Int64(i)]
            if (ch == Char('\\') && i + 1 < s.size) {
                current.append(ch)
                current.append(s[Int64(i + 1)])
                continue
            }
            if (ch == Char('{')) {
                depth += 1
                current.append(ch)
            } else if (ch == Char('}')) {
                depth -= 1
                current.append(ch)
            } else if (ch == Char(',') && depth == 0) {
                options.append(current.toString())
                current = StringBuilder()
            } else {
                current.append(ch)
            }
        }
        options.append(current.toString())
        return options
    }
}

// ============================================================================
// Glob 工具函数
// 严格翻译自: src/glob/glob.zig detectGlobSyntax
// ============================================================================

/// Glob 工具
public class GlobUtils {
    /// 检测字符串是否包含 glob 语法
    /// 严格翻译自 Bun: detectGlobSyntax(potential_pattern)
    /// 排除反斜杠转义的特殊字符
    public static func detectGlobSyntax(potentialPattern: String): Bool {
        // 取反仅允许在模式开头
        if (potentialPattern.size > 0 && potentialPattern[Int64(0)] == Char('!')) {
            return true
        }

        // 按流行度排序的特殊语法字符
        let specialChars = [Char('*'), Char('{'), Char('['), Char('?')]

        for (token in specialChars) {
            var idx = 0
            while (idx < potentialPattern.size) {
                // 查找 token
                var found = false
                for (i in idx..potentialPattern.size) {
                    if (potentialPattern[Int64(i)] == token) {
                        // 检查前面的反斜杠数是否为偶数
                        var backslashCount = 0
                        var j = i
                        while (j > 0 && potentialPattern[Int64(j - 1)] == Char('\\')) {
                            backslashCount += 1
                            j -= 1
                        }
                        if (backslashCount % 2 == 0) {
                            return true
                        }
                        idx = i + 1
                        found = true
                        break
                    }
                }
                if (!found) { break }
            }
        }

        return false
    }
}
