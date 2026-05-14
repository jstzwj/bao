// bao_semver - 语义版本号解析与比较
// 严格翻译自: src/semver/semver.zig + src/semver/Version.zig
// 对应 Bun 的 Semver 实现，包括:
//   - Version: major, minor, patch, tag (pre-release, build)
//   - Tag: pre-release 和 build 元数据解析
//   - Version.parse: 从字符串解析版本号
//   - 版本比较: order, eql, gt, gte, lt, lte
//   - 排序: sort, rsort
//   - satisfies: 版本是否满足范围
package bao_semver

import bao_core.*
import bao_collections.*

// ============================================================================
// VersionTag - 预发布和构建元数据
// 严格翻译自: src/semver/Version.zig - Tag struct
//   pub const Tag = extern struct {
//       pre: ExternalString = ExternalString{},
//       build: ExternalString = ExternalString{},
//       pub fn hasPre, hasBuild, eql, order, orderPre, parse
//   }
//
// Semver 规范:
//   - 预发布: 1.0.0-alpha, 1.0.0-alpha.1, 1.0.0-0.3.7
//   - 构建: 1.0.0+build.001, 1.0.0+20130313144700
//   - 预发布比较: 按点号分隔，数字比较 > 字符串比较
//     有预发布的版本 < 无预发布的版本 (1.0.0-alpha < 1.0.0)
// ============================================================================

/// 预发布/构建标签 - 对应 Bun Version.Tag
public class VersionTag {
    /// 预发布标识 (如 "alpha.1", "canary.0")
    public var pre: String
    /// 构建元数据 (如 "build.001")
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
    public func eql(other: VersionTag): Bool {
        pre == other.pre && build == other.build
    }

    /// 预发布标签比较 - 对应 Bun Tag.orderPre
    /// Bun: 按 '.' 分隔，逐段比较:
    ///   - 都是数字 -> 数值比较
    ///   - 一边数字一边字符串 -> 数字 < 字符串
    ///   - 都是字符串 -> 字典序比较
    ///   - 长度不同 -> 短的较小
    public func comparePre(other: VersionTag): Int64 {
        if (!hasPre() && !other.hasPre()) {
            return 0
        }
        if (!hasPre()) {
            return 1  // 有 pre < 无 pre (1.0.0 > 1.0.0-alpha)
        }
        if (!other.hasPre()) {
            return -1
        }

        // 按 '.' 分隔逐段比较
        let lhsParts = pre.split(".")
        let rhsParts = other.pre.split(".")
        let minLen = if (lhsParts.size < rhsParts.size) { lhsParts.size } else { rhsParts.size }

        for (i in 0..minLen) {
            let lhsPart = lhsParts[i]
            let rhsPart = rhsParts[i]
            let lhsNum = tryParseInt(lhsPart)
            let rhsNum = tryParseInt(rhsPart)

            // Bun: 数字标识符 < 字符串标识符
            // "a part that doesn't parse as an integer is greater than a part that does"
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

        // 长度不同 - 短的较小
        if (lhsParts.size < rhsParts.size) {
            return -1
        }
        if (lhsParts.size > rhsParts.size) {
            return 1
        }
        return 0
    }

    /// 完整标签比较 (含 build) - 对应 Bun Tag.order
    public func compare(other: VersionTag): Int64 {
        let preCmp = comparePre(other)
        if (preCmp != 0) {
            return preCmp
        }
        return build <=> other.build
    }

    /// 不含 build 的比较 - 对应 Bun Tag.orderWithoutBuild
    public func compareWithoutBuild(other: VersionTag): Int64 {
        comparePre(other)
    }

    private static func tryParseInt(s: String): Option<Int64> {
        try {
            return Some(Int64.parse(s))
        } catch {
            return None
        }
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
//           tag: Tag = .{},
//           pub fn parse, eql, order, isZero, ...
//       }
//   }
//
// Bun 使用 extern struct + IntType(u64) 获得紧凑内存布局
// 仓颉使用 class 封装语义等价的版本号结构
// ============================================================================

/// 语义版本号 - 对应 Bun VersionType(u64)
///
/// 格式: major.minor.patch[-prerelease][+buildmetadata]
/// 示例: 1.2.3, 1.2.3-alpha.1, 1.2.3+build.001
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
        var s = StringBuilder()
        s.append("${major}.${minor}.${patch}")
        if (pre.size > 0) {
            s.append("-${pre}")
        }
        if (build.size > 0) {
            s.append("+${build}")
        }
        this.raw = s.toString()
    }

    /// 是否为零版本 - 对应 Bun Version.isZero
    public func isZero(): Bool {
        major == 0 && minor == 0 && patch == 0 && !tag.hasPre() && !tag.hasBuild()
    }

    // ========================================================================
    // parse - 解析版本号字符串
    // 严格翻译自: Version.parse -> Version._parse
    //   pub fn parse(sliced_string: SlicedString) ParseResult {
    //       // 跳过前导空白和 v= 前缀
    //       // 解析 major.minor.patch
    //       // 解析 pre-release (-xxx) 和 build (+xxx)
    //       // 支持 x/X/* 通配符
    //   }
    // ========================================================================

    /// 从字符串解析语义版本号
    /// 对应 Bun Version.parse
    ///
    /// 支持格式:
    ///   1.2.3           - 标准格式
    ///   v1.2.3          - v 前缀
    ///   =1.2.3          - = 前缀
    ///   1.2.3-alpha     - 预发布
    ///   1.2.3+build     - 构建元数据
    ///   1.2.3-alpha+001 - 预发布 + 构建
    ///   1.x, 1.2.x     - 通配符
    public static func parse(text: String): ?SemVer {
        let input = text.trim()
        if (input.size == 0) {
            return None
        }

        var i = 0
        let len = input.size

        // 跳过前导空白和 v= 前缀
        // Bun: ' ', '\t', '\n', '\r', 'v', '=' => skip
        while (i < len) {
            let ch = input[i]
            if (ch == ' ' || ch == '\t' || ch == '\n' || ch == '\r' || ch == 'v' || ch == '=') {
                i += 1
            } else {
                break
            }
        }

        if (i >= len) {
            return None
        }

        var major: Int64 = 0
        var minor: Int64 = 0
        var patch: Int64 = 0
        var partIndex = 0
        var pre = ""
        var build = ""

        while (i < len) {
            let ch = input[i]

            if (ch == ' ') {
                break
            }
            // 范围操作符停止解析
            if (ch == '|' || ch == '^' || ch == '#' || ch == '&' || ch == '%' || ch == '!') {
                break
            }

            // 通配符
            if (ch == 'x' || ch == 'X' || ch == '*') {
                i += 1
                if (i < len && input[i] == '.') {
                    i += 1
                }
                partIndex += 1
                continue
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
                let num = tryParseInt64(numStr)
                if (num == None) {
                    return None
                }
                let val = num.getOrThrow()

                // 丢弃前导零 (除非是 "0" 本身)
                match (partIndex) {
                    case 0 => major = val
                    case 1 => minor = val
                    case 2 => patch = val
                    case _ => ()
                }
                partIndex += 1

                // 跳过分隔符 '.'
                if (i < len && input[i] == '.' && partIndex < 3) {
                    i += 1
                }
                continue
            }

            // 预发布 (-) 和构建 (+) 标签
            if (ch == '-' || ch == '+') {
                if (partIndex < 2) {
                    return None  // 无效: 没有足够的版本号部分
                }
                let (parsedPre, parsedBuild, tagEnd) = parseTag(input, i)
                pre = parsedPre
                build = parsedBuild
                i = tagEnd
                break
            }

            // 点号
            if (ch == '.') {
                i += 1
                continue
            }

            // 后缀字母 (如 "1.0.0rc.1" 这种非标准格式)
            // Bun: "Some weirdo npm packages in the wild have a version like '1.0.0rc.1'"
            if (ch >= 'a' && ch <= 'z' || ch >= 'A' && ch <= 'Z') {
                if (partIndex >= 2) {
                    let (parsedPre, parsedBuild, tagEnd) = parseTag(input, i)
                    pre = parsedPre
                    build = parsedBuild
                    i = tagEnd
                    break
                }
            }

            return None
        }

        let ver = SemVer(major, minor, patch, pre, build)
        ver.raw = input.substring(0, i)
        return ver
    }

    /// 解析标签部分 - 对应 Bun Tag.parse
    private static func parseTag(input: String, start: Int64): (String, String, Int64) {
        var state = 0  // 0=none, 1=pre, 2=build
        var preStart = start
        var buildStart = start
        var pre = ""
        var build = ""
        var i = start

        while (i < input.size) {
            let ch = input[i]
            if (ch == '+') {
                if (state == 1) {
                    pre = input.substring(preStart, i)
                }
                state = 2
                buildStart = i + 1
                i += 1
                continue
            }
            if (ch == '-') {
                if (state == 0) {
                    state = 1
                    preStart = i + 1
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
            break
        }

        // 收集最后一部分
        if (state == 1) {
            pre = input.substring(preStart, i)
        } else if (state == 2) {
            build = input.substring(buildStart, i)
        }

        return (pre, build, i)
    }

    // ========================================================================
    // 比较 - 对应 Bun Version.order / Version.orderWithoutTag
    // ========================================================================

    /// 版本比较 - 对应 Bun Version.order
    /// 返回: -1 (this < other), 0 (相等), 1 (this > other)
    public func compare(other: SemVer): Int64 {
        // 比较 major.minor.patch
        if (major < other.major) { return -1 }
        if (major > other.major) { return 1 }
        if (minor < other.minor) { return -1 }
        if (minor > other.minor) { return 1 }
        if (patch < other.patch) { return -1 }
        if (patch > other.patch) { return 1 }

        // 比较 pre-release 标签
        // Bun: 有 pre < 无 pre (1.0.0-alpha < 1.0.0)
        let hasPreThis = tag.hasPre()
        let hasPreOther = other.tag.hasPre()
        if (hasPreThis && !hasPreOther) { return -1 }
        if (!hasPreThis && hasPreOther) { return 1 }

        let preCmp = tag.comparePre(other.tag)
        if (preCmp != 0) { return preCmp }

        // 比较 build 标签
        return tag.compare(other.tag)
    }

    /// 不含 build 的比较 - 对应 Bun Version.orderWithoutBuild
    public func compareWithoutBuild(other: SemVer): Int64 {
        if (major < other.major) { return -1 }
        if (major > other.major) { return 1 }
        if (minor < other.minor) { return -1 }
        if (minor > other.minor) { return 1 }
        if (patch < other.patch) { return -1 }
        if (patch > other.patch) { return 1 }

        let hasPreThis = tag.hasPre()
        let hasPreOther = other.tag.hasPre()
        if (hasPreThis && !hasPreOther) { return -1 }
        if (!hasPreThis && hasPreOther) { return 1 }

        return tag.compareWithoutBuild(other.tag)
    }

    /// 相等比较 - 对应 Bun Version.eql
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

    /// 比较函数 - 返回 Ordering
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

    /// 格式化输出 - 对应 Bun Version.Formatter.format
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
