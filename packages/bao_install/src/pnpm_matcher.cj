// bao_install - Pnpm 风格包名匹配器
// 严格翻译自: src/install/PnpmMatcher.zig
//   https://github.com/pnpm/pnpm/blob/3abd3946237aa6ba7831552310ec371ddd3616c2/config/matcher/src/index.ts
//   PnpmMatcher 用于匹配 pnpm 的 hoist-pattern / public-hoist-pattern 配置
package bao_install

import bao_core.*
import bao_collections.*
import bao_io.*
import bao_hash.*
import bao_path.*
import bao_http.*

// ============================================================================
// 匹配器行为
// 严格翻译自: src/install/PnpmMatcher.zig - Behavior
//   const Behavior = enum {
//       all_matchers_include,
//       all_matchers_exclude,
//       has_exclude_and_include_matchers,
//   }
// ============================================================================

/// 匹配器行为
/// 翻译自: PnpmMatcher.Behavior
public enum MatcherBehavior {
    | AllMatchersInclude                  // 所有匹配器都是包含模式
    | AllMatchersExclude                  // 所有匹配器都是排除模式
    | HasExcludeAndIncludeMatchers        // 同时有包含和排除匹配器
}

// ============================================================================
// 单个匹配器
// 严格翻译自: src/install/PnpmMatcher.zig - Matcher
//   const Matcher = struct {
//       pattern: union(enum) { match_all, regex: *jsc.RegularExpression },
//       is_exclude: bool,
//   }
// ============================================================================

/// 单个匹配器
/// 翻译自: PnpmMatcher.Matcher
public class Matcher {
    /// 匹配模式
    public var pattern: MatcherPattern
    /// 是否是排除模式 (!前缀)
    public var isExclude: Bool

    public init(pattern: MatcherPattern, isExclude: Bool) {
        this.pattern = pattern
        this.isExclude = isExclude
    }
}

/// 匹配模式
/// 翻译自: Matcher.pattern (union)
public enum MatcherPattern {
    | MatchAll                      // 通配符 "*"
    | Regex(String)                 // 正则表达式模式字符串
}

// ============================================================================
// Pnpm 匹配器
// 严格翻译自: src/install/PnpmMatcher.zig - PnpmMatcher
//   const PnpmMatcher = @This();
//   matchers: []const Matcher,
//   behavior: Behavior,
// ============================================================================

/// Pnpm 风格包名匹配器
/// 对应 Bun: PnpmMatcher
/// 用于匹配 pnpm 的 hoist-pattern / public-hoist-pattern 配置
/// 翻译自: src/install/PnpmMatcher.zig
public class PnpmMatcher {
    /// 匹配器列表
    public var matchers: ArrayList<Matcher>
    /// 匹配器行为
    public var behavior: MatcherBehavior

    public init() {
        matchers = ArrayList<Matcher>()
        behavior = MatcherBehavior.AllMatchersInclude
    }

    public init(matchers: ArrayList<Matcher>, behavior: MatcherBehavior) {
        this.matchers = matchers
        this.behavior = behavior
    }

    /// 从字符串模式创建匹配器
    /// 翻译自: PnpmMatcher.createMatcher
    ///   fn createMatcher(raw, buf) CreateMatcherError!Matcher
    public static func createMatcher(raw: String): Matcher {
        var trimmed = raw.trim()
        var isExclude = false

        // 检查排除前缀
        if (trimmed.startsWith("!")) {
            isExclude = true
            trimmed = trimmed.substring(1)
        }

        // 通配符
        if (trimmed == "*") {
            return Matcher(MatcherPattern.MatchAll, isExclude)
        }

        // 构建正则表达式模式
        // 翻译自: strings.escapeRegExpForPackageNameMatching
        // 将 glob 模式转换为正则表达式
        let regex = globToRegex(trimmed)
        return Matcher(MatcherPattern.Regex(regex), isExclude)
    }

    /// 从字符串或字符串数组创建 PnpmMatcher
    /// 翻译自: PnpmMatcher.fromExpr
    ///   pub fn fromExpr(allocator, expr, log, source) FromExprError!PnpmMatcher
    public static func fromPatterns(patterns: ArrayList<String>): PnpmMatcher {
        var matcherList = ArrayList<Matcher>()
        var hasInclude = false
        var hasExclude = false

        for (pattern in patterns) {
            let matcher = createMatcher(pattern)
            if (!matcher.isExclude) {
                hasInclude = true
            } else {
                hasExclude = true
            }
            matcherList.append(matcher)
        }

        let behavior: MatcherBehavior = if (!hasInclude) {
            MatcherBehavior.AllMatchersExclude
        } else if (!hasExclude) {
            MatcherBehavior.AllMatchersInclude
        } else {
            MatcherBehavior.HasExcludeAndIncludeMatchers
        }

        return PnpmMatcher(matcherList, behavior)
    }

    /// 从单个字符串创建 PnpmMatcher
    public static func fromPattern(pattern: String): PnpmMatcher {
        let patterns = ArrayList<String>()
        patterns.append(pattern)
        return fromPatterns(patterns)
    }

    /// 测试包名是否匹配
    /// 翻译自: PnpmMatcher.isMatch
    ///   pub fn isMatch(this, name) bool
    public func isMatch(name: String): Bool {
        if (matchers.size == 0) {
            return false
        }

        match (behavior) {
            case AllMatchersInclude => {
                // 任一匹配器命中即匹配
                for (matcher in matchers) {
                    match (matcher.pattern) {
                        case MatcherPattern.MatchAll => return true
                        case MatcherPattern.Regex(regex) => {
                            if (matchRegex(regex, name)) {
                                return true
                            }
                        }
                    }
                }
                return false
            }
            case AllMatchersExclude => {
                // 任一匹配器命中即排除
                for (matcher in matchers) {
                    match (matcher.pattern) {
                        case MatcherPattern.MatchAll => return false
                        case MatcherPattern.Regex(regex) => {
                            if (matchRegex(regex, name)) {
                                return false
                            }
                        }
                    }
                }
                return true
            }
            case HasExcludeAndIncludeMatchers => {
                // 最后一个命中的匹配器决定结果
                var matches = false
                for (matcher in matchers) {
                    match (matcher.pattern) {
                        case MatcherPattern.MatchAll => {
                            matches = !matcher.isExclude
                        }
                        case MatcherPattern.Regex(regex) => {
                            if (matchRegex(regex, name)) {
                                matches = !matcher.isExclude
                            }
                        }
                    }
                }
                return matches
            }
        }
    }

    // 将 glob 模式转换为正则表达式
    // 翻译自: strings.escapeRegExpForPackageNameMatching
    private static func globToRegex(pattern: String): String {
        let sb = StringBuilder()
        sb.append("^")
        for (c in pattern) {
            let v = c.value
            if (v == CharCode.ASTERISK) {
                // * -> [^/]*  (匹配除 / 外的任意字符)
                sb.append("[^/]*")
            } else if (v == CharCode.QUESTION) {
                // ? -> [^/]   (单个非 / 字符)
                sb.append("[^/]")
            } else if (isRegexSpecial(c)) {
                sb.append("\\")
                sb.append(c)
            } else {
                sb.append(c)
            }
        }
        sb.append("$")
        return sb.toString()
    }

    // 检查是否是正则表达式特殊字符
    private static func isRegexSpecial(c: Rune): Bool {
        let v = c.value
        return v == CharCode.BACKSLASH || v == CharCode.DOT ||
               v == CharCode.PLUS || v == CharCode.LPAREN ||
               v == CharCode.RPAREN || v == CharCode.LBRACKET ||
               v == CharCode.RBRACKET || v == CharCode.LBRACE ||
               v == CharCode.RBRACE || v == CharCode.PIPE ||
               v == CharCode.CARET || v == CharCode.DOLLAR
    }

    // 简单正则匹配 (支持 ^, $, *, [^/]*, \\.)
    // 翻译自: jsc.RegularExpression.matches
    private static func matchRegex(pattern: String, input: String): Bool {
        // 简化实现: 使用通配符匹配逻辑
        // 实际 Bun 使用 JSC 正则引擎
        return globMatch(pattern, input)
    }

    // 通配符匹配
    private static func globMatch(pattern: String, input: String): Bool {
        let pLen = pattern.length
        let iLen = input.length
        var pi: Int64 = 0
        var ii: Int64 = 0

        // 跳过 ^ 前缀
        if (pLen > 0 && pattern[0].value == CharCode.CARET) {
            pi = 1
        }

        while (pi < pLen && ii < iLen) {
            let pc = pattern[pi].value
            if (pc == CharCode.BACKSLASH && pi + 1 < pLen) {
                // 转义字符
                pi += 1
                if (pattern[pi].value != input[ii].value) { return false }
                pi += 1
                ii += 1
            } else if (pc == CharCode.DOLLAR) {
                // 结束
                pi += 1
            } else if (pattern[pi] == '[' && pi + 2 < pLen && pattern[Int64(pi) + 1] == '^' && pattern[Int64(pi) + 2] == '/') && pi + 3 < pLen && pattern[Int64(pi) + 3] == ']' && pi + 4 < pLen && pattern[Int64(pi) + 4] == '*') {
                // [^/]* -> 匹配任意非 / 字符序列
                pi += 5
                while (ii < iLen && input[ii].value != CharCode.SLASH) {
                    ii += 1
                }
            } else if (pattern[pi] == '[' && pi + 2 < pLen && pattern[Int64(pi) + 1] == '^' && pattern[Int64(pi) + 2] == '/') && pi + 3 < pLen && pattern[Int64(pi) + 3] == ']' {
                // [^/] -> 匹配单个非 / 字符
                pi += 4
                if (ii < iLen && input[ii].value != CharCode.SLASH) {
                    ii += 1
                } else {
                    return false
                }
            } else if (pc == CharCode.DOT) {
                // 在模式中的 . 匹配输入中的 .
                if (input[ii].value == CharCode.DOT) {
                    pi += 1
                    ii += 1
                } else {
                    return false
                }
            } else {
                if (pattern[pi] == input[ii]) {
                    pi += 1
                    ii += 1
                } else {
                    return false
                }
            }
        }

        // 跳过尾部的 $
        while (pi < pLen && (pattern[pi].value == CharCode.DOLLAR || pattern[pi].value == CharCode.CARET)) {
            pi += 1
        }

        return pi >= pLen && ii >= iLen
    }
}

// ============================================================================
// 字符码常量
// ============================================================================

public class CharCode {
    public static let ASTERISK: Int64 = 42     // *
    public static let QUESTION: Int64 = 63     // ?
    public static let BACKSLASH: Int64 = 92    // \
    public static let DOT: Int64 = 46          // .
    public static let PLUS: Int64 = 43         // +
    public static let LPAREN: Int64 = 40       // (
    public static let RPAREN: Int64 = 41       // )
    public static let LBRACKET: Int64 = 91     // [
    public static let RBRACKET: Int64 = 93     // ]
    public static let LBRACE: Int64 = 123      // {
    public static let RBRACE: Int64 = 125      // }
    public static let PIPE: Int64 = 124        // |
    public static let CARET: Int64 = 94        // ^
    public static let DOLLAR: Int64 = 36        // $
    public static let SLASH: Int64 = 47        // /
    public static let AT: Int64 = 64           // @
}
