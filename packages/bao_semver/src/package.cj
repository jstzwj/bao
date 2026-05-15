// bao_semver - 语义版本号解析与比较
// 严格翻译自: src/semver/semver.zig + src/semver/Version.zig + src/semver/SemverQuery.zig
// 对应 Bun 的 Semver 实现，包括:
//   - SemVer: major, minor, patch, tag (pre-release, build)
//   - VersionTag: pre-release 和 build 元数据解析
//   - Version.parse: 从字符串解析版本号 (含 x/X/* 通配符)
//   - 版本比较: compare, eql, gt, gte, lt, lte
//   - 排序: sort, rsort
//   - satisfies: 版本是否满足范围
//   - coerce: 从任意字符串提取 semver
//   - PinnedVersion: 检测版本固定级别
package bao_semver

import bao_core.*
import bao_collections.*

// ============================================================================
// Wildcard - 通配符级别
// 严格翻译自: src/semver/SemverQuery.zig - Token.Wildcard
//   pub const Wildcard = enum { none, major, minor, patch }
// 表示版本号的通配符粒度:
//   .major -> "x" 或 "*" (完全通配)
//   .minor -> "1.x" (minor 通配)
//   .patch -> "1.2.x" (patch 通配)
// ============================================================================

/// 通配符级别 - 对应 Bun Query.Token.Wildcard
public enum Wildcard {
    | None     // 无通配符 - 完整版本号
    | Major    // major 通配 (x, *, X)
    | Minor    // minor 通配 (1.x, 1.*)
    | Patch    // patch 通配 (1.2.x, 1.2.*)
}

// ============================================================================
// VersionTag - 预发布和构建元数据
// 严格翻译自: src/semver/Version.zig - Tag struct (extern struct)
//   pub const Tag = extern struct {
//       pre: ExternalString = ExternalString{},
//       build: ExternalString = ExternalString{},
//       pub fn hasPre, hasBuild, eql, order, orderPre, parse,
//              parseWithPreCount, cloneInto
//   }
//
// Semver 规范 (https://semver.org):
//   - 预发布: 1.0.0-alpha, 1.0.0-alpha.1, 1.0.0-0.3.7
//     有点号分隔的标识符组成，数字标识符 < 字符串标识符
//     有预发布的版本 < 无预发布的版本 (1.0.0-alpha < 1.0.0)
//   - 构建: 1.0.0+build.001, 1.0.0+20130313144700
//     不参与版本优先级比较
//
// Bun ExternalString 是 SSO (Small String Optimization) 字符串
// 仓颉直接用 String 字段
// ============================================================================

/// 预发布/构建标签 - 对应 Bun Version.Tag
public class VersionTag {
    /// 预发布标识 (如 "alpha.1", "canary.0", "beta.2")
    public var pre: String
    /// 构建元数据 (如 "build.001", "20130313144700")
    public var build: String

    public init() {
        pre = ""
        build = ""
    }

    public init(pre: String, build: String) {
        this.pre = pre
        this.build = build
    }

    /// 是否有预发布标签 - 对应 Bun Tag.hasPre
    /// Bun: pub inline fn hasPre(this: Tag) bool { return !this.pre.isEmpty() }
    public func hasPre(): Bool {
        pre.size > 0
    }

    /// 是否有构建标签 - 对应 Bun Tag.hasBuild
    public func hasBuild(): Bool {
        build.size > 0
    }

    /// 标签相等比较 - 对应 Bun Tag.eql
    /// Bun: pub fn eql(lhs: Tag, rhs: Tag) bool { return lhs.pre.hash == rhs.pre.hash }
    /// 仓颉: 直接比较字符串内容
    public func eql(other: VersionTag): Bool {
        pre == other.pre && build == other.build
    }

    /// 预发布标签比较 - 对应 Bun Tag.orderPre
    /// Bun: 按 '.' 分隔，逐段比较:
    ///   - 都是数字 -> 数值比较
    ///   - 一边数字一边字符串 -> 数字 < 字符串
    ///     (node-semver: "a part that doesn't parse as an integer is greater
    ///      than a part that does")
    ///   - 都是字符串 -> 字典序比较 (strings.order)
    ///   - 长度不同 -> 短的较小 (更多段 > 更少段)
    public func comparePre(other: VersionTag): Int64 {
        if (!hasPre() && !other.hasPre()) {
            return 0
        }
        if (!hasPre()) {
            return 1  // 无 pre > 有 pre (1.0.0 > 1.0.0-alpha)
        }
        if (!other.hasPre()) {
            return -1  // 有 pre < 无 pre
        }

        // 按 '.' 分隔逐段比较
        let lhsParts = pre.split(".")
        let rhsParts = other.pre.split(".")
        let minLen = if (lhsParts.size < rhsParts.size) { lhsParts.size } else { rhsParts.size }

        for (i in 0..minLen) {
            let lhsPart = lhsParts[i]
            let rhsPart = rhsParts[i]
            let lhsNum = tryParseInt64(lhsPart)
            let rhsNum = tryParseInt64(rhsPart)

            // Bun: 数字标识符 < 字符串标识符
            // "a part that doesn't parse as an integer is greater than a part that does"
            // https://github.com/npm/node-semver/blob/816c7b2/.../identifiers.js#L12
            if (lhsNum != None && rhsNum == None) {
                return -1
            }
            if (lhsNum == None && rhsNum != None) {
                return 1
            }
            if (lhsNum != None && rhsNum != None) {
                let ln = lhsNum.getOrThrow()
                let rn = rhsNum.getOrThrow()
                if (ln < rn) {
                    return -1
                }
                if (ln > rn) {
                    return 1
                }
                continue
            }

            // 都是字符串 - 字典序比较
            // Bun: strings.order(lhs_part, rhs_part)
            let cmp = lhsPart <=> rhsPart
            if (cmp != Ordering.equal) {
                return if (cmp == Ordering.less) { -1 } else { 1 }
            }
        }

        // 长度不同 - 更多段 > 更少段
        // "1.0.0-alpha" < "1.0.0-alpha.1" (多一段)
        if (lhsParts.size < rhsParts.size) {
            return -1
        }
        if (lhsParts.size > rhsParts.size) {
            return 1
        }
        return 0
    }

    /// 完整标签比较 (含 build) - 对应 Bun Tag.order
    /// Bun:
    ///   pub fn order(lhs, rhs, lhs_buf, rhs_buf) Order {
    ///       if (!lhs.pre.isEmpty() and !rhs.pre.isEmpty()) return lhs.orderPre(rhs, ...)
    ///       const pre_order = lhs.pre.order(&rhs.pre, ...)
    ///       if (pre_order != .eq) return pre_order
    ///       return lhs.build.order(&rhs.build, ...)
    ///   }
    public func compare(other: VersionTag): Int64 {
        // 两个都有 pre 时用 orderPre 比较
        if (hasPre() && other.hasPre()) {
            let preCmp = comparePre(other)
            if (preCmp != 0) {
                return preCmp
            }
        } else {
            // 一个有 pre 一个没有
            if (hasPre() && !other.hasPre()) {
                return -1
            }
            if (!hasPre() && other.hasPre()) {
                return 1
            }
        }
        // build 标签比较 (字典序)
        let buildCmp = build <=> other.build
        if (buildCmp != Ordering.less) {
            if (buildCmp == Ordering.equal) { return 0 }
            return 1
        }
        return -1
    }

    /// 不含 build 的比较 - 对应 Bun Tag.orderWithoutBuild
    /// Bun:
    ///   pub fn orderWithoutBuild(lhs, rhs, lhs_buf, rhs_buf) Order {
    ///       if (!lhs.pre.isEmpty() and !rhs.pre.isEmpty()) return lhs.orderPre(rhs, ...)
    ///       return lhs.pre.order(&rhs.pre, ...)
    ///   }
    public func compareWithoutBuild(other: VersionTag): Int64 {
        if (hasPre() && other.hasPre()) {
            return comparePre(other)
        }
        if (hasPre() && !other.hasPre()) {
            return -1
        }
        if (!hasPre() && other.hasPre()) {
            return 1
        }
        return 0
    }

    /// 解析标签部分 - 对应 Bun Tag.parse + Tag.parseWithPreCount
    /// Bun:
    ///   pub fn parse(sliced_string: SlicedString) TagResult
    ///   pub fn parseWithPreCount(sliced_string: SlicedString, initial_pre_count: u32) TagResult
    ///
    /// 从 version 后面的部分开始解析, state machine:
    ///   State.none -> '-' -> State.pre (start = i+1)
    ///   State.pre/none -> '+' -> State.build (start = i+1, finalize pre)
    ///   非法字符 -> 结束 (finalize current state)
    public static func parseTag(input: String, start: Int64, initialPreCount: Int64): (String, String, Int64) {
        // 先检查有没有 pre/build 分隔符
        var buildCount: Int64 = 0
        var preCount: Int64 = initialPreCount
        var i: Int64 = start
        while (i < input.size) {
            let ch = input[i]
            if (ch == ' ') {
                break
            }
            if (ch == '+') {
                buildCount += 1
            }
            if (ch == '-') {
                preCount += 1
            }
            i += 1
        }

        if (buildCount == 0 && preCount == 0) {
            return ("", "", start)
        }

        // 状态机解析
        // 0 = none, 1 = pre, 2 = build
        var state = 0
        var partStart = start
        var pre = ""
        var build = ""
        i = start

        while (i < input.size) {
            let ch = input[i]
            if (ch == '+') {
                // qualifier ::= ( '-' pre )? ( '+' build )?
                if (state == 1 || (state == 0 && initialPreCount > 0)) {
                    pre = input.substring(partStart, i)
                }
                if (state != 2) {
                    state = 2
                    partStart = i + 1
                }
                i += 1
                continue
            }
            if (ch == '-') {
                if (state != 1) {
                    if (state == 2) {
                        // build 中遇到 '-', 结束
                        build = input.substring(partStart, i)
                        return (pre, build, i)
                    }
                    state = 1
                    partStart = i + 1
                }
                i += 1
                continue
            }
            // 合法字符: [a-zA-Z0-9.]
            if ((ch >= 'a' && ch <= 'z') || (ch >= 'A' && ch <= 'Z') ||
                (ch >= '0' && ch <= '9') || ch == '.') {
                i += 1
                continue
            }
            // 非法字符 -> 结束
            if (state == 1) {
                pre = input.substring(partStart, i)
            } else if (state == 2) {
                build = input.substring(partStart, i)
            }
            return (pre, build, i)
        }

        // 收集最后一部分
        if (state == 0 && initialPreCount > 0) {
            state = 1
            partStart = start
        }
        if (state == 1) {
            pre = input.substring(partStart, i)
        } else if (state == 2) {
            build = input.substring(partStart, i)
        }

        return (pre, build, i)
    }

    private static func tryParseInt64(s: String): ?Int64 {
        try {
            return Some(Int64.parse(s))
        } catch {
            return None
        }
    }
}

// ============================================================================
// ParseResult - 解析结果
// 严格翻译自: src/semver/Version.zig - ParseResult
//   pub const ParseResult = struct {
//       wildcard: Query.Token.Wildcard = .none,
//       valid: bool = true,
//       version: This.Partial = .{},
//       len: u32 = 0,
//   }
// ============================================================================

/// 版本解析结果 - 对应 Bun ParseResult
public class ParseResult {
    /// 通配符级别
    public var wildcard: Wildcard
    /// 是否有效
    public var valid: Bool
    /// 解析出的版本号
    public var version: SemVer
    /// 消耗的字符数
    public var len: Int64

    public init() {
        wildcard = Wildcard.None
        valid = true
        version = SemVer()
        len = 0
    }
}

// ============================================================================
// SemVer - 语义版本号
// 严格翻译自: src/semver/Version.zig - VersionType
//   pub fn VersionType(comptime IntType: type) type {
//       return extern struct {
//           major: IntType = 0,
//           minor: IntType = 0,
//           patch: IntType = 0,
//           _tag_padding: [if (IntType == u32) 4 else 0]u8,
//           tag: Tag = .{},
//           pub fn parse, eql, order, isZero, parseVersionNumber, ...
//       }
//   }
//
// Bun 使用 extern struct + IntType(u64) 获得紧凑内存布局
// 仓颉使用 class 封装语义等价的版本号结构
//
// Version.Partial 用于范围解析:
//   pub const Partial = struct {
//       major: ?IntType = null,
//       minor: ?IntType = null,
//       patch: ?IntType = null,
//       tag: Tag = .{},
//       pub fn min(this) This {  // 未提供的部分用 0 填充
//       pub fn max(this) This {  // 未提供的部分用 MAX 填充
//   }
// ============================================================================

/// 语义版本号 - 对应 Bun VersionType(u64)
///
/// 格式: major.minor.patch[-prerelease][+buildmetadata]
/// 示例: 1.2.3, 1.2.3-alpha.1, 1.2.3+build.001, 1.2.3-alpha+001
public class SemVer {
    /// 主版本号
    public var major: Int64
    /// 次版本号
    public var minor: Int64
    /// 补丁版本号
    public var patch: Int64
    /// 预发布/构建标签
    public var tag: VersionTag
    /// 原始字符串
    public var raw: String

    public init() {
        major = 0
        minor = 0
        patch = 0
        tag = VersionTag()
        raw = ""
    }

    public init(major: Int64, minor: Int64, patch: Int64) {
        this.major = major
        this.minor = minor
        this.patch = patch
        this.tag = VersionTag()
        this.raw = "${major}.${minor}.${patch}"
    }

    public init(major: Int64, minor: Int64, patch: Int64, pre: String, build: String) {
        this.major = major
        this.minor = minor
        this.patch = patch
        this.tag = VersionTag(pre, build)
        var sb = StringBuilder()
        sb.append("${major}.${minor}.${patch}")
        if (pre.size > 0) {
            sb.append("-${pre}")
        }
        if (build.size > 0) {
            sb.append("+${build}")
        }
        this.raw = sb.toString()
    }

    /// 是否为零版本 - 对应 Bun Version.isZero
    /// Bun: pub fn isZero(this: This) bool {
    ///     return this.patch == 0 and this.minor == 0 and this.major == 0
    /// }
    public func isZero(): Bool {
        major == 0 && minor == 0 && patch == 0
    }

    // ========================================================================
    // parse - 解析版本号字符串
    // 严格翻译自: Version.parse
    //   pub fn parse(sliced_string: SlicedString) ParseResult {
    //       // 跳过前导空白和 v= 前缀
    //       // 解析 major.minor.patch (数字部分)
    //       // 支持 x/X/* 通配符
    //       // 解析 pre-release (-xxx) 和 build (+xxx)
    //       // 解析无 '-' 前缀的预发布 (如 "1.0.0rc.1")
    //       // 返回 ParseResult { wildcard, valid, version, len }
    //   }
    // ========================================================================

    /// 从字符串解析语义版本号 - 对应 Bun Version.parse
    /// 返回 ParseResult，包含版本号、通配符级别和消耗字符数
    ///
    /// 支持格式:
    ///   1.2.3           - 标准格式
    ///   v1.2.3          - v 前缀
    ///   =1.2.3          - = 前缀
    ///   1.2.3-alpha     - 预发布
    ///   1.2.3+build     - 构建元数据
    ///   1.2.3-alpha+001 - 预发布 + 构建
    ///   1.x, 1.2.x     - 通配符
    ///   1.0.0rc.1       - 无 '-' 前缀的预发布 (npm 兼容)
    public static func parseFull(text: String): ParseResult {
        let input = text
        var result = ParseResult()
        if (input.size == 0) {
            result.valid = false
            return result
        }

        var i: Int64 = 0
        let len = input.size

        // 跳过前导空白和 v= 前缀
        // Bun: ' ', '\t', '\n', '\r', VT, FF, 'v', '=' => skip
        while (i < len) {
            let ch = input[i]
            if (ch == ' ' || ch == '\t' || ch == '\n' || ch == '\r' ||
                ch == '\u000B' as Int64 || ch == '\u000C' as Int64 ||
                ch == 'v' || ch == '=') {
                i += 1
            } else {
                break
            }
        }

        if (i >= len) {
            result.valid = false
            return result
        }

        var major: Int64 = 0
        var minor: Int64 = 0
        var patch: Int64 = 0
        var partIndex: Int64 = 0
        var wildcard = Wildcard.None
        var pre = ""
        var build = ""
        var isDone = false

        // 主解析循环
        while (i < len) {
            if (isDone) {
                break
            }

            let ch = input[i]

            if (ch == ' ') {
                isDone = true
                break
            }
            // 范围操作符停止解析
            // Bun: '|', '^', '#', '&', '%', '!'
            if (ch == '|' || ch == '^' || ch == '#' || ch == '&' || ch == '%' || ch == '!') {
                isDone = true
                if (i > 0) {
                    i -= 1
                }
                break
            }

            // 数字解析
            if (ch >= '0' && ch <= '9') {
                var numStart = i
                while (i < len) {
                    let c = input[i]
                    if (c >= '0' && c <= '9') {
                        i += 1
                    } else {
                        break
                    }
                }
                let numStr = input.substring(numStart, i)
                let num = parseVersionNumber(numStr)
                if (num == None) {
                    result.valid = false
                    return result
                }
                let val = num.getOrThrow()
                if (partIndex == 0) {
                    major = val
                } else if (partIndex == 1) {
                    minor = val
                } else if (partIndex == 2) {
                    patch = val
                }
                partIndex += 1

                // 跳过分隔符 '.'
                // Bun: '.' is expected only if there are remaining core version numbers
                if (i < len && input[i] == '.' && partIndex < 3) {
                    i += 1
                }
                continue
            }

            // 前导点号 - 无效
            if (ch == '.') {
                result.valid = false
                return result
            }

            // 预发布 (-) 和构建 (+) 标签
            if (ch == '-' || ch == '+') {
                // Just a plain tag with no version is invalid.
                // Bun: if (part_i < 2 and result.wildcard == .none) -> invalid
                if (partIndex < 2 && wildcard == Wildcard.None) {
                    result.valid = false
                    return result
                }
                let tagStart = i
                // 跳过空格
                while (i < len && input[i] == ' ') {
                    i += 1
                }
                let (parsedPre, parsedBuild, tagEnd) = VersionTag.parseTag(input, tagStart, 0)
                pre = parsedPre
                build = parsedBuild
                i = tagEnd
                break
            }

            // 通配符 x/X/*
            if (ch == 'x' || ch == 'X' || ch == '*') {
                while (i < len) {
                    let c = input[i]
                    if (c == 'x' || c == 'X' || c == '*') {
                        i += 1
                    } else {
                        break
                    }
                }
                if (i < len && input[i] == '.') {
                    i += 1
                }
                if (wildcard == Wildcard.None) {
                    if (partIndex == 0) {
                        wildcard = Wildcard.Major
                    } else if (partIndex == 1) {
                        wildcard = Wildcard.Minor
                    } else if (partIndex == 2) {
                        wildcard = Wildcard.Patch
                    }
                }
                partIndex += 1
                continue
            }

            // 后缀字母 (如 "1.0.0rc.1" 这种非标准格式)
            // Bun: "Some weirdo npm packages in the wild have a version like '1.0.0rc.1'"
            //      "npm just expects that to work...even though it has no '-' qualifier."
            if (ch >= 'a' && ch <= 'z' || ch >= 'A' && ch <= 'Z') {
                if (wildcard == Wildcard.None && partIndex >= 2) {
                    // 解析为预发布标签 (带 initial_pre_count = 1)
                    let (parsedPre, parsedBuild, tagEnd) = VersionTag.parseTag(input, i, 1)
                    pre = parsedPre
                    build = parsedBuild
                    i = tagEnd
                    isDone = true
                    break
                }
            }

            // 其他字符 -> 无效
            result.valid = false
            return result
        }

        // 如果没有设置通配符，根据解析的部分数推断
        // Bun: if (result.wildcard == .none) {
        //     switch (part_i) {
        //         0 => result.wildcard = .major
        //         1 => result.wildcard = .minor
        //         2 => result.wildcard = .patch
        //         else => {}
        //     }
        // }
        if (wildcard == Wildcard.None) {
            if (partIndex == 0) {
                wildcard = Wildcard.Major
            } else if (partIndex == 1) {
                wildcard = Wildcard.Minor
            } else if (partIndex == 2) {
                wildcard = Wildcard.Patch
            }
        }

        let ver = SemVer(major, minor, patch, pre, build)
        ver.raw = input.substring(0, i)
        result.version = ver
        result.wildcard = wildcard
        result.len = i
        return result
    }

    /// 简单解析 - 从字符串解析语义版本号 (返回 ?SemVer)
    /// 对应外部 API，不需要通配符信息时使用
    public static func parse(text: String): ?SemVer {
        let result = parseFull(text)
        if (!result.valid) {
            return None
        }
        return Some(result.version)
    }

    /// 解析版本号数字 - 对应 Bun parseVersionNumber
    /// Bun:
    ///   fn parseVersionNumber(input: string) ?IntType {
    ///       var bytes: [20]u8 = undefined;  // max decimal u64 = 18446744073709551615
    ///       var byte_i: u8 = 0;
    ///       for (input) |char| {
    ///           switch (char) {
    ///               'X','x','*' => return null,
    ///               '0'...'9' => { if (byte_i+1 > 20) return null; bytes[byte_i]=char; byte_i+=1 }
    ///               ' ','.' => break,
    ///               else => {}  // ignore invalid
    ///           }
    ///       }
    ///       if (byte_i == 0) return null;
    ///       return std.fmt.parseInt(IntType, bytes[0..byte_i], 10) catch 0;
    ///   }
    private static func parseVersionNumber(input: String): ?Int64 {
        if (input.size == 0) {
            return None
        }
        var sb = StringBuilder()
        for (i in 0..input.size) {
            let ch = input[i]
            if (ch == 'X' || ch == 'x' || ch == '*') {
                return None
            }
            if (ch >= '0' && ch <= '9') {
                if (sb.size() >= 20) {
                    return None  // overflow
                }
                sb.append(ch)
            } else if (ch == ' ' || ch == '.') {
                break
            }
            // ignore invalid characters
        }
        if (sb.size() == 0) {
            return None
        }
        try {
            return Some(Int64.parse(sb.toString()))
        } catch {
            return Some(0)  // Bun: catch 0
        }
    }

    // ========================================================================
    // 比较 - 对应 Bun Version.order / Version.orderWithoutTag
    //   pub fn order(lhs, rhs, lhs_buf, rhs_buf) Order {
    //       const order_without_tag = orderWithoutTag(lhs, rhs)
    //       if (order_without_tag != .eq) return order_without_tag
    //       return lhs.tag.order(rhs.tag, lhs_buf, rhs_buf)
    //   }
    //   pub fn orderWithoutTag(lhs, rhs) Order {
    //       if (lhs.major < rhs.major) return .lt
    //       if (lhs.major > rhs.major) return .gt
    //       ... (minor, patch)
    //       if (lhs.tag.hasPre()) { if (!rhs.tag.hasPre()) return .lt }
    //       else { if (rhs.tag.hasPre()) return .gt }
    //       return .eq
    //   }
    // ========================================================================

    /// 不含标签的版本比较 - 对应 Bun Version.orderWithoutTag
    /// 只比较 major.minor.patch 和 pre 的有无
    public func compareWithoutTag(other: SemVer): Int64 {
        if (major < other.major) { return -1 }
        if (major > other.major) { return 1 }
        if (minor < other.minor) { return -1 }
        if (minor > other.minor) { return 1 }
        if (patch < other.patch) { return -1 }
        if (patch > other.patch) { return 1 }

        // 有 pre < 无 pre (1.0.0-alpha < 1.0.0)
        let hasPreThis = tag.hasPre()
        let hasPreOther = other.tag.hasPre()
        if (hasPreThis && !hasPreOther) { return -1 }
        if (!hasPreThis && hasPreOther) { return 1 }

        return 0
    }

    /// 版本比较 - 对应 Bun Version.order
    /// 返回: -1 (this < other), 0 (相等), 1 (this > other)
    public func compare(other: SemVer): Int64 {
        let orderWithoutTag = compareWithoutTag(other)
        if (orderWithoutTag != 0) {
            return orderWithoutTag
        }
        return tag.compare(other.tag)
    }

    /// 不含 build 的比较 - 对应 Bun Version.orderWithoutBuild
    /// 用于 satisfies 检查时忽略 build 元数据
    public func compareWithoutBuild(other: SemVer): Int64 {
        let orderWithoutTag = compareWithoutTag(other)
        if (orderWithoutTag != 0) {
            return orderWithoutTag
        }
        return tag.compareWithoutBuild(other.tag)
    }

    /// 相等比较 - 对应 Bun Version.eql
    /// Bun: pub fn eql(lhs, rhs) bool {
    ///     lhs.major == rhs.major and lhs.minor == rhs.minor and
    ///     lhs.patch == rhs.patch and rhs.tag.eql(lhs.tag)
    /// }
    public func eql(other: SemVer): Bool {
        major == other.major && minor == other.minor && patch == other.patch &&
            tag.eql(other.tag)
    }

    /// 大于
    public static func gt(a: SemVer, b: SemVer): Bool {
        a.compare(b) > 0
    }

    /// 大于等于
    public static func gte(a: SemVer, b: SemVer): Bool {
        a.compare(b) >= 0
    }

    /// 小于
    public static func lt(a: SemVer, b: SemVer): Bool {
        a.compare(b) < 0
    }

    /// 小于等于
    public static func lte(a: SemVer, b: SemVer): Bool {
        a.compare(b) <= 0
    }

    /// 等于
    public static func equals(a: SemVer, b: SemVer): Bool {
        a.eql(b)
    }

    /// 比较函数 - 返回比较值
    public static func compare(a: SemVer, b: SemVer): Int64 {
        a.compare(b)
    }

    // ========================================================================
    // satisfies - 检查版本是否满足范围
    // 对应 Bun Range.satisfies
    // ========================================================================

    /// 检查版本是否满足给定范围
    /// 委托给 SemVerRange.satisfies
    public static func satisfies(version: SemVer, range: SemVerRange): Bool {
        range.satisfies(version)
    }

    // ========================================================================
    // 排序 - 对应 Bun Version.sortGt
    //   pub fn sortGt(ctx: []const u8, lhs: This, rhs: This) bool {
    //       return orderFn(ctx, lhs, rhs) == .gt
    //   }
    // ========================================================================

    /// 升序排序 - 从小到大
    public static func sort(versions: Array<SemVer>): Array<SemVer> {
        let arr = ArrayList<SemVer>()
        for (i in 0..versions.size) {
            arr.append(versions[i])
        }
        arr.sortWith({ a, b -> a.compare(b) < 0 })
        return arr.toArray()
    }

    /// 降序排序 - 从大到小
    public static func rsort(versions: Array<SemVer>): Array<SemVer> {
        let arr = ArrayList<SemVer>()
        for (i in 0..versions.size) {
            arr.append(versions[i])
        }
        arr.sortWith({ a, b -> a.compare(b) > 0 })
        return arr.toArray()
    }

    // ========================================================================
    // coerce - 从任意字符串提取 semver
    // 对应 npm node-semver coerce 行为:
    ///   从非标准字符串中提取第一个匹配的版本号
    // ========================================================================

    /// 从任意字符串中提取语义版本号
    /// 对应 npm coerce: 从字符串中提取第一个 major.minor.patch 模式
    /// 例: "foo/bar@1.2.3" -> 1.2.3
    ///     "v2.0.0-beta" -> 2.0.0-beta
    ///     "no version" -> None
    public static func coerce(text: String): ?SemVer {
        let len = text.size
        var i: Int64 = 0

        while (i < len) {
            // 查找数字开头
            let ch = text[i]
            if (ch < '0' || ch > '9') {
                i += 1
                continue
            }

            // 尝试从这里解析版本号
            let attempt = parse(text.substring(i))
            if (attempt != None) {
                return attempt
            }

            // 跳过当前数字段
            while (i < len && text[i] >= '0' && text[i] <= '9') {
                i += 1
            }
            // 如果下一个是 '.', 跳过继续找
            if (i < len && text[i] == '.') {
                i += 1
            }
        }
        return None
    }

    // ========================================================================
    // PinnedVersion - 检测版本固定级别
    // 严格翻译自: Version.whichVersionIsPinned
    //   Modified version of pnpm's whichVersionIsPinned
    //   Differences: not used for workspaces, npm: already removed,
    //   invalid input considered major pinned
    // ========================================================================

    /// 版本固定级别 - 对应 Bun PinnedVersion
    public enum PinnedVersion {
        | Major    // ^ -> 固定主版本
        | Minor    // ~ -> 固定次版本
        | Patch    // = 或精确版本 -> 固定补丁
    }

    /// 检测版本字符串的固定级别
    /// 对应 Bun Version.whichVersionIsPinned
    /// Bun: Modified version of pnpm's whichVersionIsPinned
    ///  ^1.2.3 -> Major, ~1.2.3 -> Minor, 1.2.3 -> Patch
    public static func whichVersionIsPinned(input: String): PinnedVersion {
        let trimmed = input.trim()
        if (trimmed.size == 0) {
            return PinnedVersion.Major
        }

        var i: Int64 = 0
        let len = trimmed.size

        // 跳过前导空白/v=/等
        // 寻找第一个有意义的字符
        var pinned = PinnedVersion.Patch
        var foundFirst = false

        while (i < len) {
            let ch = trimmed[i]
            if (ch == ' ' || ch == '\t' || ch == '\n' || ch == '\r' ||
                ch == '\u000B' as Int64 || ch == '\u000C' as Int64 ||
                ch == 'v' || ch == '=') {
                i += 1
                continue
            }

            if (!foundFirst) {
                foundFirst = true
                if (ch == '~') {
                    pinned = PinnedVersion.Minor
                    i += 1
                    // 跳过空白找到数字
                    while (i < len) {
                        let c = trimmed[i]
                        if (c == ' ' || c == '\t' || c == '\n' || c == '\r' ||
                            c == '\u000B' as Int64 || c == '\u000C' as Int64) {
                            i += 1
                            continue
                        }
                        break
                    }
                    if (i >= len) { return PinnedVersion.Major }
                    continue
                }
                if (ch == '^') {
                    pinned = PinnedVersion.Major
                    i += 1
                    while (i < len) {
                        let c = trimmed[i]
                        if (c == ' ' || c == '\t' || c == '\n' || c == '\r' ||
                            c == '\u000B' as Int64 || c == '\u000C' as Int64) {
                            i += 1
                            continue
                        }
                        break
                    }
                    if (i >= len) { return PinnedVersion.Major }
                    continue
                }
                if (ch >= '0' && ch <= '9') {
                    pinned = PinnedVersion.Patch
                    // 继续解析版本号各部分
                } else {
                    return PinnedVersion.Major
                }
            }

            // 解析 major
            if (i >= len || trimmed[i] < '0' || trimmed[i] > '9') {
                return PinnedVersion.Major
            }
            while (i < len && trimmed[i] >= '0' && trimmed[i] <= '9') {
                i += 1
            }
            if (i >= len) {
                return if (pinned == PinnedVersion.Patch) { PinnedVersion.Major } else { pinned }
            }
            if (trimmed[i] != '.') {
                return PinnedVersion.Major
            }

            // 解析 minor
            i += 1
            if (i >= len || trimmed[i] < '0' || trimmed[i] > '9') {
                return PinnedVersion.Major
            }
            while (i < len && trimmed[i] >= '0' && trimmed[i] <= '9') {
                i += 1
            }
            if (i >= len) {
                return if (pinned == PinnedVersion.Patch) { PinnedVersion.Minor } else { pinned }
            }
            if (trimmed[i] != '.') {
                return PinnedVersion.Major
            }

            // 解析 patch
            i += 1
            if (i >= len || trimmed[i] < '0' || trimmed[i] > '9') {
                return PinnedVersion.Major
            }
            while (i < len && trimmed[i] >= '0' && trimmed[i] <= '9') {
                i += 1
            }
            if (i >= len) {
                return pinned
            }

            // 跳过 pre/build 标签有效字符
            let c = trimmed[i]
            if (!validPreOrBuildTagChar(c)) {
                return PinnedVersion.Major
            }
            i += 1
            while (i < len) {
                let ch2 = trimmed[i]
                if (!validPreOrBuildTagChar(ch2)) {
                    break
                }
                i += 1
            }
            if (i >= len) {
                return pinned
            }
            return PinnedVersion.Major
        }

        return PinnedVersion.Major
    }

    /// 检查字符是否是合法的 pre/build 标签字符
    /// Bun: fn validPreOrBuildTagCharacter(c: u8) bool {
    ///     return switch (c) { '-', '+', '.', 'A'...'Z', 'a'...'z', '0'...'9' => true, else => false }
    /// }
    private static func validPreOrBuildTagChar(c: Int64): Bool {
        (c == '-'.codePointAt(0)) || (c == '+'.codePointAt(0)) || (c == '.'.codePointAt(0)) ||
            (c >= 'A'.codePointAt(0) && c <= 'Z'.codePointAt(0)) ||
            (c >= 'a'.codePointAt(0) && c <= 'z'.codePointAt(0)) ||
            (c >= '0'.codePointAt(0) && c <= '9'.codePointAt(0))
    }

    /// 检查字符串是否是纯标签版本 (如 "latest", "canary")
    /// Bun: pub fn isTaggedVersionOnly(input: []const u8) bool
    public static func isTaggedVersionOnly(input: String): Bool {
        let trimmed = input.trim()
        if (trimmed.size == 0) {
            return false
        }
        let first = trimmed[0]
        if (first < 'a' || first > 'z') {
            if (first < 'A' || first > 'Z') {
                return false
            }
        }
        for (i in 1..trimmed.size) {
            let ch = trimmed[i]
            if ((ch < 'a' || ch > 'z') && (ch < 'A' || ch > 'Z') &&
                (ch < '0' || ch > '9')) {
                return false
            }
        }
        return true
    }

    /// 格式化输出 - 对应 Bun Version.Formatter.format
    /// Bun:
    ///   try writer.print("{d}.{d}.{d}", .{ self.major, self.minor, self.patch })
    ///   if (self.tag.hasPre()) { try writer.writeAll("-"); try writer.writeAll(pre) }
    ///   if (self.tag.hasBuild()) { try writer.writeAll("+"); try writer.writeAll(build) }
    public override func toString(): String {
        var sb = StringBuilder()
        sb.append("${major}.${minor}.${patch}")
        if (tag.hasPre()) {
            sb.append("-${tag.pre}")
        }
        if (tag.hasBuild()) {
            sb.append("+${tag.build}")
        }
        return sb.toString()
    }

    private static func tryParseInt64(s: String): ?Int64 {
        try {
            return Some(Int64.parse(s))
        } catch {
            return None
        }
    }
}
