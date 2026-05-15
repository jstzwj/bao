// bao_semver.comparator - 版本比较器
// 严格翻译自: src/semver/SemverRange.zig - Comparator
//   pub const Comparator = struct {
//       op: Op = .unset,
//       version: Version = .{},
//       pub fn eql, satisfies, format
//   }
//
// 以及 Bun Token.toRange 中的操作符逻辑:
//   - caret (^): ^1.2.3 -> >=1.2.3 <2.0.0
//   - tilde (~): ~1.2.3 -> >=1.2.3 <1.3.0
//   - gt/gte/lt/lte: 直接比较
//   - hyphen (-): 1.0.0 - 2.0.0 -> >=1.0.0 <=2.0.0
//   - x-ranges: 1.x -> >=1.0.0 <2.0.0
package bao_semver

import bao_core.*
import bao_collections.*

// ============================================================================
// ComparatorOp - 比较操作符 (值类型)
// 严格翻译自: src/semver/SemverRange.zig - Op enum
//   pub const Op = enum(u8) {
//       unset = 0, eql = 1, lt = 3, lte = 4, gt = 5, gte = 6,
//   }
// ============================================================================

/// 比较操作符 (值类型) - 对应 Bun Range.Op
public enum ComparatorOp {
    | Unset   // 0 - 未设置
    | Eql     // 1 - = 或 == (精确匹配)
    | Lt      // 3 - <
    | Lte     // 4 - <=
    | Gt      // 5 - >
    | Gte     // 6 - >=

    public func toString(): String {
        match (this) {
            case Unset => ""
            case Eql => "=="
            case Lt => "<"
            case Lte => "<="
            case Gt => ">"
            case Gte => ">="
        }
    }

    /// 从 TokenTag 映射到 ComparatorOp
    public static func fromTokenTag(tag: TokenTag): ComparatorOp {
        match (tag) {
            case Gt => Gt
            case Gte => Gte
            case Lt => Lt
            case Lte => Lte
            case Version => Eql
            case _ => Unset
        }
    }
}

// ============================================================================
// ComparatorVersion - 值类型比较器
// 严格翻译自: src/semver/SemverRange.zig - Comparator struct
//   pub const Comparator = struct {
//       op: Op = .unset,
//       version: Version = .{},
//       pub inline fn eql(lhs, rhs) bool {
//           return lhs.op == rhs.op and lhs.version.eql(rhs.version)
//       }
//       pub fn satisfies(comparator, version, ...) bool {
//           const order = version.orderWithoutBuild(comparator.version, ...)
//           return switch (order) {
//               .eq => switch (comparator.op) { .lte, .gte, .eql => true, else => false }
//               .gt => switch (comparator.op) { .gt, .gte => true, else => false }
//               .lt => switch (comparator.op) { .lt, .lte => true, else => false }
//           }
//       }
//   }
// ============================================================================

/// 值类型比较器 - 对应 Bun Range.Comparator
/// 表示类似 ">=1.2.3" 或 "<2.0.0" 的单个比较条件
public struct ComparatorVersion {
    public var op: ComparatorOp
    public var version: SemVerVersion

    public init() {
        op = ComparatorOp.Unset
        version = SemVerVersion()
    }

    public init(op: ComparatorOp, version: SemVerVersion) {
        this.op = op
        this.version = version
    }

    public init(op: ComparatorOp, major: Int64, minor: Int64, patch: Int64) {
        this.op = op
        this.version = SemVerVersion(major, minor, patch)
    }

    /// 相等比较 - 对应 Bun Comparator.eql
    public func eql(other: ComparatorVersion): Bool {
        op == other.op && version == other.version
    }

    /// 检查版本是否满足比较器 - 对应 Bun Comparator.satisfies
    /// Bun:
    ///   const order = version.orderWithoutBuild(comparator.version)
    ///   return switch (order) {
    ///       .eq => switch (op) { .lte, .gte, .eql => true, else => false }
    ///       .gt => switch (op) { .gt, .gte => true, else => false }
    ///       .lt => switch (op) { .lt, .lte => true, else => false }
    ///   }
    public func satisfies(ver: SemVerVersion): Bool {
        let order = ver.compareWithoutBuild(version)
        match (op) {
            case Eql => order == 0
            case Lt => order < 0
            case Lte => order <= 0
            case Gt => order > 0
            case Gte => order >= 0
            case Unset => true
        }
    }

    /// 格式化输出
    public func toString(): String {
        if (op == ComparatorOp.Unset) {
            return ""
        }
        "${op.toString()}${version.toString()}"
    }

    /// 操作符: 两个比较器相等
    public operator func ==(other: ComparatorVersion): Bool {
        eql(other)
    }

    /// 操作符: 两个比较器不等
    public operator func !=(other: ComparatorVersion): Bool {
        !eql(other)
    }
}

// ============================================================================
// ComparatorRange - 值类型范围 (两个比较器 AND)
// 严格翻译自: src/semver/SemverRange.zig - Range struct
//   pub const Range = struct {
//       left: Comparator = .{},
//       right: Comparator = .{},
//       pub fn hasLeft, hasRight, eql, satisfies, satisfiesPre,
//              initWildcard, anyRangeSatisfies
//   }
// ============================================================================

/// 值类型版本范围 - 对应 Bun Range
public struct ComparatorRange {
    public var left: ComparatorVersion
    public var right: ComparatorVersion

    public init() {
        left = ComparatorVersion()
        right = ComparatorVersion()
    }

    public init(left: ComparatorVersion, right: ComparatorVersion) {
        this.left = left
        this.right = right
    }

    /// 是否有左比较器
    public func hasLeft(): Bool {
        left.op != ComparatorOp.Unset
    }

    /// 是否有右比较器
    public func hasRight(): Bool {
        right.op != ComparatorOp.Unset
    }

    /// 范围相等
    public func eql(other: ComparatorRange): Bool {
        left.eql(other.left) && right.eql(other.right)
    }

    /// 是否是通配范围
    public func anyRangeSatisfies(): Bool {
        left.op == ComparatorOp.Gte && left.version.isZero()
    }

    /// 检查版本是否满足范围 - 对应 Bun Range.satisfies
    public func satisfies(version: SemVerVersion): Bool {
        let hasL = hasLeft()
        let hasR = hasRight()

        if (!hasL) {
            return true
        }

        if (!left.satisfies(version)) {
            return false
        }

        if (hasR && !right.satisfies(version)) {
            return false
        }

        return true
    }

    /// 检查预发布版本是否满足范围 - 对应 Bun Range.satisfiesPre
    /// preMatched: 传入 [false]，函数会在 major.minor.patch 匹配时设为 true
    public func satisfiesPre(version: SemVerVersion, preMatched: Array<Bool>): Bool {
        let hasL = hasLeft()
        let hasR = hasRight()

        if (!hasL) {
            return true
        }

        // 检查 pre-matched: 如果范围边界有 pre 标签且 major.minor.patch 匹配
        var matched = preMatched[0]
        matched = matched ||
            (left.version.hasPre() &&
                version.patch == left.version.patch &&
                version.minor == left.version.minor &&
                version.major == left.version.major) ||
            (hasR &&
                right.version.hasPre() &&
                version.patch == right.version.patch &&
                version.minor == right.version.minor &&
                version.major == right.version.major)
        preMatched[0] = matched

        if (!left.satisfies(version)) {
            return false
        }

        if (hasR && !right.satisfies(version)) {
            return false
        }

        return true
    }

    // ========================================================================
    // 通配符范围 - 对应 Bun Range.initWildcard
    //   switch (wildcard) {
    //       .none => { .left = .{ .op = .eql, .version = version } }
    //       .major => { .left = .{ .op = .gte, .version = .{} } }
    //       .minor => { .left = .{ .op = .lt, lhs }, .right = .{ .op = .gte, rhs } }
    //       .patch => { .left = .{ .op = .lt, lhs }, .right = .{ .op = .gte, rhs } }
    //   }
    // ========================================================================

    /// 创建通配符范围 - 对应 Bun Range.initWildcard
    public static func initWildcard(version: SemVerVersion, wildcard: Wildcard): ComparatorRange {
        match (wildcard) {
            case None =>
                // 无通配符 -> 精确匹配
                ComparatorRange(
                    ComparatorVersion(ComparatorOp.Eql, version),
                    ComparatorVersion()
                )
            case Major =>
                // major 通配符 (x) -> >=0.0.0 (匹配所有)
                ComparatorRange(
                    ComparatorVersion(ComparatorOp.Gte, SemVerVersion(0, 0, 0)),
                    ComparatorVersion()
                )
            case Minor =>
                // minor 通配符 (1.x) -> <(major+1).0.0 >=major.0.0
                ComparatorRange(
                    ComparatorVersion(ComparatorOp.Lt, SemVerVersion(version.major + 1, 0, 0)),
                    ComparatorVersion(ComparatorOp.Gte, SemVerVersion(version.major, 0, 0))
                )
            case Patch =>
                // patch 通配符 (1.2.x) -> <major.(minor+1).0 >=major.minor.0
                ComparatorRange(
                    ComparatorVersion(ComparatorOp.Lt, SemVerVersion(version.major, version.minor + 1, 0)),
                    ComparatorVersion(ComparatorOp.Gte, SemVerVersion(version.major, version.minor, 0))
                )
        }
    }

    // ========================================================================
    // 预定义范围构造器
    // 严格翻译自 Bun Token.toRange 中的 caret/tilde 逻辑
    // ========================================================================

    /// Caret 范围 (^version)
    /// Bun: .caret => { ... }
    /// https://github.com/npm/node-semver/blob/.../classes/range.js#L302-L353
    ///
    /// ^1.2.3 := >=1.2.3 <2.0.0
    /// ^0.2.3 := >=0.2.3 <0.3.0
    /// ^0.0.3 := >=0.0.3 <0.0.4
    /// ^1.2.x := >=1.2.0 <2.0.0
    /// ^0.0.x := >=0.0.0 <0.1.0
    /// ^0.0   := >=0.0.0 <0.1.0
    public static func caret(version: SemVerVersion): ComparatorRange {
        let left = ComparatorVersion(ComparatorOp.Gte, version)
        var rightVer = SemVerVersion()

        if (version.major != 0) {
            // ^1.2.3 -> <2.0.0
            rightVer = SemVerVersion(version.major + 1, 0, 0)
        } else if (version.minor != 0) {
            // ^0.2.3 -> <0.3.0
            rightVer = SemVerVersion(0, version.minor + 1, 0)
        } else {
            // ^0.0.3 -> <0.0.4
            rightVer = SemVerVersion(0, 0, version.patch + 1)
        }

        let right = ComparatorVersion(ComparatorOp.Lt, rightVer)
        return ComparatorRange(left, right)
    }

    /// Caret 范围 (支持部分版本号)
    /// 严格翻译自 Bun Token.toRange .caret 分支
    /// Bun:
    ///   if (version.major) |major| done: {
    ///       range.left = .{ .op = .gte, .version = .{ .major = major } }
    ///       range.right = .{ .op = .lt }
    ///       if (version.minor) |minor| {
    ///           range.left.version.minor = minor
    ///           if (version.patch) |patch| {
    ///               range.left.version.patch = patch
    ///               range.left.version.tag = version.tag
    ///               if (major == 0) {
    ///                   if (minor == 0) { range.right.version.patch = patch + 1 }
    ///                   else { range.right.version.minor = minor + 1 }
    ///                   break :done
    ///               }
    ///           } else if (major == 0) {
    ///               range.right.version.minor = minor + 1; break :done
    ///           }
    ///       }
    ///       range.right.version.major = major + 1
    ///   }
    public static func caretPartial(
        major: ?Int64,
        minor: ?Int64,
        patch: ?Int64,
        pre: String,
        build: String
    ): ComparatorRange {
        var range = ComparatorRange()

        match (major) {
            case Some(maj) =>
                let leftVer = SemVerVersion(maj, 0, 0, pre, build)
                range.left = ComparatorVersion(ComparatorOp.Gte, leftVer)
                range.right = ComparatorVersion(ComparatorOp.Lt, SemVerVersion())

                match (minor) {
                    case Some(min) =>
                        range.left.version.minor = min
                        match (patch) {
                            case Some(p) =>
                                range.left.version.patch = p
                                range.left.version.pre = pre
                                range.left.version.build = build
                                if (maj == 0) {
                                    if (min == 0) {
                                        range.right.version = SemVerVersion(0, 0, p + 1)
                                    } else {
                                        range.right.version = SemVerVersion(0, min + 1, 0)
                                    }
                                    return range
                                }
                            case None =>
                                if (maj == 0) {
                                    range.right.version = SemVerVersion(0, min + 1, 0)
                                    return range
                                }
                        }
                    case None => ()
                }
                range.right.version = SemVerVersion(maj + 1, 0, 0)
            case None => ()
        }

        return range
    }

    /// Tilde 范围 (~version)
    /// Bun: .tilda => { ... }
    /// https://github.com/npm/node-semver/blob/.../classes/range.js#L261-L287
    ///
    /// ~1.2.3 := >=1.2.3 <1.3.0
    /// ~1.2   := >=1.2.0 <1.3.0
    /// ~1     := >=1.0.0 <2.0.0
    public static func tilde(version: SemVerVersion): ComparatorRange {
        let left = ComparatorVersion(ComparatorOp.Gte, version)
        // Tilde: 总是 <major.(minor+1).0
        let rightVer = SemVerVersion(version.major, version.minor + 1, 0)
        let right = ComparatorVersion(ComparatorOp.Lt, rightVer)
        return ComparatorRange(left, right)
    }

    /// Tilde 范围 (支持部分版本号)
    /// 严格翻译自 Bun Token.toRange .tilda 分支
    public static func tildePartial(
        major: ?Int64,
        minor: ?Int64,
        patch: ?Int64,
        pre: String,
        build: String
    ): ComparatorRange {
        var range = ComparatorRange()

        match (major) {
            case Some(maj) =>
                let leftVer = SemVerVersion(maj, 0, 0)
                range.left = ComparatorVersion(ComparatorOp.Gte, leftVer)
                range.right = ComparatorVersion(ComparatorOp.Lt, SemVerVersion())

                match (minor) {
                    case Some(min) =>
                        range.left.version.minor = min
                        match (patch) {
                            case Some(p) =>
                                range.left.version.patch = p
                                range.left.version.pre = pre
                                range.left.version.build = build
                            case None => ()
                        }
                        range.right.version = SemVerVersion(maj, min + 1, 0)
                    case None =>
                        range.right.version = SemVerVersion(maj + 1, 0, 0)
                }
            case None => ()
        }

        return range
    }

    // ========================================================================
    // Hyphen 范围构造器
    // 严格翻译自 Bun Query.parse 中的 hyphenate 逻辑
    //   "1.0.0 - 2.0.0" -> >=1.0.0 <=2.0.0
    //   "1.0.0 - 2.x"   -> >=1.0.0 <3.0.0
    //   "1.0.0 - 2.0.x" -> >=1.0.0 <2.1.0
    // ========================================================================

    /// 构建 hyphen 范围
    /// Bun:
    ///   switch (second_parsed.wildcard) {
    ///       .major => Range{ .left = .{ .op = .gte, .version = version } }
    ///       .minor => second_version.major +|= 1; Range{ >=version, <second }
    ///       .patch => second_version.minor +|= 1; Range{ >=version, <second }
    ///       .none => Range{ >=version, <=second }
    ///   }
    public static func hyphen(
        first: SemVerVersion,
        second: SemVerVersion,
        secondWildcard: Wildcard
    ): ComparatorRange {
        let left = ComparatorVersion(ComparatorOp.Gte, first)
        match (secondWildcard) {
            case Major =>
                // "1.0.0 - x" -> >=1.0.0
                ComparatorRange(left, ComparatorVersion())
            case Minor =>
                // "1.0.0 - 1.x" -> >=1.0.0 <2.0.0
                let upperMajor = second.major + 1
                let right = ComparatorVersion(ComparatorOp.Lt, SemVerVersion(upperMajor, 0, 0))
                ComparatorRange(left, right)
            case Patch =>
                // "1.0.0 - 1.0.x" -> >=1.0.0 <1.1.0
                let upperMinor = second.minor + 1
                let right = ComparatorVersion(ComparatorOp.Lt, SemVerVersion(second.major, upperMinor, 0))
                ComparatorRange(left, right)
            case None =>
                // "1.0.0 - 2.0.0" -> >=1.0.0 <=2.0.0
                let right = ComparatorVersion(ComparatorOp.Lte, second)
                ComparatorRange(left, right)
        }
    }

    /// 格式化输出
    public func toString(): String {
        if (!hasLeft() && !hasRight()) {
            return ""
        }
        if (!hasRight()) {
            return left.toString()
        }
        "${left.toString()} ${right.toString()}"
    }

    /// 操作符: 两个范围相等
    public operator func ==(other: ComparatorRange): Bool {
        eql(other)
    }

    /// 操作符: 两个范围不等
    public operator func !=(other: ComparatorRange): Bool {
        !eql(other)
    }
}

// ============================================================================
// 版本比较操作符的便捷函数
// 对应 Bun Range.satisfies 的简化接口
// ============================================================================

/// 检查版本字符串是否满足范围字符串
/// 对应 npm semver.satisfies('1.2.3', '^1.0.0') => true
public func satisfiesVersion(versionStr: String, rangeStr: String): Bool {
    let ver = SemVerVersion.parse(versionStr)
    if (ver == None) {
        return false
    }
    let v = ver.getOrThrow()

    let group = RangeParser.parse(rangeStr)
    if (group == None) {
        return false
    }
    let g = group.getOrThrow()

    // 使用 QueryGroup 的 satisfies
    let semverObj = v.toSemVer()
    return g.satisfies(semverObj)
}
