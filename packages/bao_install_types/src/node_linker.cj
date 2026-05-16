// bao_install_types - NodeLinker 枚举、npm Registry 常量、PnpmMatcher
// 严格翻译自:
//   src/install_types/NodeLinker.zig - NodeLinker 枚举
//   src/install_types/NodeLinker.rs  - NodeLinker + npm Registry + PnpmMatcher
//
// 提取自 install/PackageManager/PackageManagerOptions.zig, 以便
// options_types/schema.zig, cli/bunfig.zig, ini/ 可以命名链接器模式
// 而不依赖完整的包管理器
package bao_install_types

import bao_core.*
import bao_semver.*
import bao_hash.*
import bao_collections.*

// ============================================================================
// NodeLinker - node_modules 链接模式
// 严格翻译自: src/install_types/NodeLinker.zig
//   pub const NodeLinker = enum(u8) {
//       // If workspaces are used: isolated
//       // If not: hoisted
//       // Used when nodeLinker is absent from package.json/bun.lock/bun.lockb
//       auto,
//       hoisted,
//       isolated,
//       pub fn fromStr(input: []const u8) ?NodeLinker { ... }
//   }
// 及 src/install_types/NodeLinker.rs:
//   #[repr(u8)]
//   #[derive(Copy, Clone, PartialEq, Eq, Debug, Default)]
//   pub enum NodeLinker {
//       #[default]
//       Auto,
//       Hoisted,
//       Isolated,
//   }
//   impl NodeLinker {
//       pub fn from_str(input: &[u8]) -> Option<NodeLinker> { ... }
//   }
// ============================================================================

/// node_modules 链接模式
/// 决定 node_modules 目录如何构建:
///   - Auto:     使用 workspaces 时为 isolated, 否则 hoisted
///               当 nodeLinker 未在 package.json/bun.lock/bun.lockb 中指定时使用
///   - Hoisted:  所有依赖提升到根 node_modules
///   - Isolated: 每个包有自己的 node_modules (类似 pnpm)
public enum NodeLinker {
    | Auto      // 默认值: workspaces -> isolated, 否则 -> hoisted
    | Hoisted   // 所有依赖扁平提升到根 node_modules
    | Isolated  // 每个包有隔离的 node_modules (类似 pnpm 的符号链接结构)

    /// 从字符串解析 NodeLinker
    /// 翻译自: src/install_types/NodeLinker.zig
    ///   pub fn fromStr(input: []const u8) ?NodeLinker {
    ///       if (strings.eqlComptime(input, "hoisted")) return .hoisted;
    ///       if (strings.eqlComptime(input, "isolated")) return .isolated;
    ///       return null;
    ///   }
    /// 及 NodeLinker.rs:
    ///   pub fn from_str(input: &[u8]) -> Option<NodeLinker> {
    ///       if input == b"hoisted" { return Some(NodeLinker::Hoisted); }
    ///       if input == b"isolated" { return Some(NodeLinker::Isolated); }
    ///       None
    ///   }
    public static func fromStr(input: String): ?NodeLinker {
        if (input == "hoisted") {
            return NodeLinker.Hoisted
        }
        if (input == "isolated") {
            return NodeLinker.Isolated
        }
        return None
    }

    /// 从字节数组解析 NodeLinker
    /// 翻译自: NodeLinker.rs from_str(&[u8])
    public static func fromBytes(input: Array<UInt8>): ?NodeLinker {
        var sb = StringBuilder()
        for (b in input) {
            sb.append(Rune(b))
        }
        return fromStr(sb.toString())
    }

    /// 转为字符串表示
    public func toString(): String {
        match (this) {
            case Auto => "auto"
            case Hoisted => "hoisted"
            case Isolated => "isolated"
        }
    }
}

// ============================================================================
// npm::Registry 常量
// 严格翻译自: src/install_types/NodeLinker.rs - npm 模块
//   pub mod npm {
//       pub struct Registry;
//       impl Registry {
//           pub const DEFAULT_URL: &'static str = "https://registry.npmjs.org/";
//           pub fn default_url_hash() -> u64 { ... }
//       }
//   }
//
// ini (T3) 和 options_types 需要默认 registry URL 而不引入完整的
// bun_install 包管理器
// ============================================================================

/// npm Registry 常量
/// 翻译自: src/install_types/NodeLinker.rs - npm::Registry
///   pub struct Registry;
///   impl Registry {
///       pub const DEFAULT_URL: &'static str = "https://registry.npmjs.org/";
///   }
public class NpmRegistry {
    /// 默认 npm registry URL
    /// 翻译自: pub const DEFAULT_URL: &'static str = "https://registry.npmjs.org/"
    public static let DEFAULT_URL: String = "https://registry.npmjs.org/"

    /// 默认 URL 的 Wyhash 哈希值 (不带尾部 /)
    /// 翻译自:
    ///   pub fn default_url_hash() -> u64 {
    ///       Wyhash11::hash(0, &Self::DEFAULT_URL.as_bytes()[..Self::DEFAULT_URL.len() - 1])
    ///   }
    /// 计算 b"https://registry.npmjs.org" (无尾部 /) 的哈希
    public static func defaultUrlHash(): UInt64 {
        let urlWithoutSlash = DEFAULT_URL.substring(0, DEFAULT_URL.length - 1)
        return Wyhash11.hash(urlWithoutSlash)
    }
}

// ============================================================================
// PnpmMatcher 匹配器行为
// 严格翻译自: src/install_types/NodeLinker.rs - Behavior
//   #[derive(Clone, Copy, PartialEq, Eq)]
//   pub enum Behavior {
//       AllMatchersInclude,
//       AllMatchersExclude,
//       HasExcludeAndIncludeMatchers,
//   }
// ============================================================================

/// 匹配器行为
/// 翻译自: PnpmMatcher.Behavior (NodeLinker.rs)
///   pub enum Behavior {
///       AllMatchersInclude,
///       AllMatchersExclude,
///       HasExcludeAndIncludeMatchers,
///   }
public enum MatcherBehavior {
    | AllMatchersInclude                  // 所有匹配器都是包含模式
    | AllMatchersExclude                  // 所有匹配器都是排除模式
    | HasExcludeAndIncludeMatchers        // 同时有包含和排除匹配器
}

// ============================================================================
// Pattern - 匹配模式
// 严格翻译自: src/install_types/NodeLinker.rs - Pattern
//   pub enum Pattern {
//       MatchAll,
//       Regex(RegularExpression),
//   }
// ============================================================================

/// 匹配模式
/// 翻译自: Matcher.pattern (union)
///   pub enum Pattern {
///       MatchAll,
///       Regex(RegularExpression),
///   }
/// 注意: Bun 使用 JSC RegularExpression (Yarr FFI), 这里简化为正则表达式模式字符串
public enum MatcherPattern {
    | MatchAll                      // 通配符 "*"
    | Regex(String)                 // 正则表达式模式字符串
}

// ============================================================================
// Matcher - 单个匹配器
// 严格翻译自: src/install_types/NodeLinker.rs - Matcher
//   pub struct Matcher {
//       pub pattern: Pattern,
//       pub is_exclude: bool,
//   }
// ============================================================================

/// 单个匹配器
/// 翻译自: PnpmMatcher.Matcher (NodeLinker.rs)
///   pub struct Matcher {
///       pub pattern: Pattern,
///       pub is_exclude: bool,
///   }
public class Matcher {
    /// 匹配模式
    public var pattern: MatcherPattern
    /// 是否是排除模式 (! 前缀)
    public var isExclude: Bool

    public init(pattern: MatcherPattern, isExclude: Bool) {
        this.pattern = pattern
        this.isExclude = isExclude
    }
}

// ============================================================================
// PnpmMatcher
// 严格翻译自: src/install_types/NodeLinker.rs - PnpmMatcher
//   pub struct PnpmMatcher {
//       pub matchers: Box<[Matcher]>,
//       pub behavior: Behavior,
//   }
//
// Ground truth: src/install/PnpmMatcher.zig
// https://github.com/pnpm/pnpm/blob/3abd3946237aa6ba7831552310ec371ddd3616c2/config/matcher/src/index.ts
//
// ini (T3) 从 .npmrc public-hoist-pattern / hoist-pattern 构建 PnpmMatcher
// ============================================================================

/// Pnpm 风格包名匹配器
/// 用于匹配 pnpm 的 hoist-pattern / public-hoist-pattern 配置
/// 翻译自: src/install_types/NodeLinker.rs - PnpmMatcher
///   pub struct PnpmMatcher {
///       pub matchers: Box<[Matcher]>,
///       pub behavior: Behavior,
///   }
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
    /// 翻译自: NodeLinker.rs - create_matcher
    ///   pub fn create_matcher(raw: &[u8], buf: &mut Vec<u8>) -> Result<Matcher, CreateMatcherError>
    ///   1. trim 输入
    ///   2. 检查 ! 前缀 -> is_exclude
    ///   3. "*" -> MatchAll
    ///   4. 否则转义为正则表达式
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
    /// 翻译自: NodeLinker.rs - PnpmMatcher::from_expr
    ///   pub fn from_expr(expr: &ast::Expr, log: &mut Log, source: &Source) -> Result<PnpmMatcher, FromExprError>
    ///   处理 EString 和 EArray 两种 AST 节点
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
    /// 翻译自: NodeLinker.rs - PnpmMatcher::is_match
    ///   pub fn is_match(&self, name: &[u8]) -> bool
    ///   三种行为模式:
    ///     AllMatchersInclude: 任一匹配器命中即匹配
    ///     AllMatchersExclude: 任一匹配器命中即排除
    ///     HasExcludeAndIncludeMatchers: 最后一个命中的匹配器决定结果
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

    /// 测试字节数组包名是否匹配
    /// 翻译自: NodeLinker.rs - PnpmMatcher::is_match(&[u8])
    public func isMatchBytes(name: Array<UInt8>): Bool {
        var sb = StringBuilder()
        for (b in name) {
            sb.append(Rune(b))
        }
        return isMatch(sb.toString())
    }

    // 将 glob 模式转换为正则表达式
    // 翻译自: strings.escapeRegExpForPackageNameMatching
    //   pnpm 的 hoist-pattern 使用 glob 风格模式:
    //     * -> [^/]*  (匹配除 / 外的任意字符)
    //     ? -> [^/]   (单个非 / 字符)
    //     其他正则特殊字符 -> 转义
    private static func globToRegex(pattern: String): String {
        let sb = StringBuilder()
        sb.append("^")
        for (c in pattern) {
            let v = c.value
            if (v == CharCodes.ASTERISK) {
                // * -> [^/]*  (匹配除 / 外的任意字符)
                sb.append("[^/]*")
            } else if (v == CharCodes.QUESTION) {
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
        return v == CharCodes.BACKSLASH || v == CharCodes.DOT ||
               v == CharCodes.PLUS || v == CharCodes.LPAREN ||
               v == CharCodes.RPAREN || v == CharCodes.LBRACKET ||
               v == CharCodes.RBRACKET || v == CharCodes.LBRACE ||
               v == CharCodes.RBRACE || v == CharCodes.PIPE ||
               v == CharCodes.CARET || v == CharCodes.DOLLAR
    }

    // 简单正则匹配
    // 翻译自: JSC RegularExpression.matches (Yarr FFI)
    private static func matchRegex(pattern: String, input: String): Bool {
        return globMatch(pattern, input)
    }

    // 通配符匹配
    private static func globMatch(pattern: String, input: String): Bool {
        let pLen = pattern.length
        let iLen = input.length
        var pi: Int64 = 0
        var ii: Int64 = 0

        // 跳过 ^ 前缀
        if (pLen > 0 && pattern[0].value == CharCodes.CARET) {
            pi = 1
        }

        while (pi < pLen && ii < iLen) {
            let pc = pattern[pi].value
            if (pc == CharCodes.BACKSLASH && pi + 1 < pLen) {
                // 转义字符
                pi += 1
                if (pattern[pi].value != input[ii].value) { return false }
                pi += 1
                ii += 1
            } else if (pc == CharCodes.DOLLAR) {
                // 结束
                pi += 1
            } else if (pi + 4 < pLen && pattern[pi].value == CharCodes.LBRACKET &&
                       pattern[Int64(pi) + 1].value == CharCodes.CARET &&
                       pattern[Int64(pi) + 2].value == CharCodes.SLASH &&
                       pattern[Int64(pi) + 3].value == CharCodes.RBRACKET &&
                       pi + 5 <= pLen && pattern[Int64(pi) + 4].value == CharCodes.ASTERISK) {
                // [^/]* -> 匹配任意非 / 字符序列
                pi += 5
                while (ii < iLen && input[ii].value != CharCodes.SLASH) {
                    ii += 1
                }
            } else if (pi + 3 < pLen && pattern[pi].value == CharCodes.LBRACKET &&
                       pattern[Int64(pi) + 1].value == CharCodes.CARET &&
                       pattern[Int64(pi) + 2].value == CharCodes.SLASH &&
                       pattern[Int64(pi) + 3].value == CharCodes.RBRACKET) {
                // [^/] -> 匹配单个非 / 字符
                pi += 4
                if (ii < iLen && input[ii].value != CharCodes.SLASH) {
                    ii += 1
                } else {
                    return false
                }
            } else if (pc == CharCodes.DOT) {
                // . 匹配 .
                if (input[ii].value == CharCodes.DOT) {
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
        while (pi < pLen && (pattern[pi].value == CharCodes.DOLLAR || pattern[pi].value == CharCodes.CARET)) {
            pi += 1
        }

        return pi >= pLen && ii >= iLen
    }
}

// ============================================================================
// 字符码常量
// 翻译自: Bun 中 strings 模块的字符比较
// ============================================================================

/// 字符码常量
public class CharCodes {
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
    public static let EXCLAMATION: Int64 = 33  // !
}
