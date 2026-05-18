// 严格翻译自: src/semver/SemverRange.zig
//   Semver 范围数据结构
//   Range: left + right 比较器 (AND 关系)
//   Comparator: op + version (单个比较条件)
//   Range.satisfies / satisfiesPre: 版本满足检查
//   Range.initWildcard: 通配符范围
//   Range.format / Comparator.Formatter: 格式化输出
//
// 注意: range.cj 中已有 Op, Comparator, SemVerRange, Query, QueryList, QueryGroup, RangeParser 等
// 本文件提供 SemverRange.zig 的补充翻译，包括:
//   - SemverRange2: 更严格的 Zig 翻译 (字段命名与 Zig 一致)
//   - Comparator2: 独立比较器 (与 range.cj 中 Comparator 互补)
//   - satisfies/satisfiesPre 的精确翻译
package bao_semver

import bao_core.*
import bao_collections.*

// ============================================================================
// Comparator2 - 独立比较器 (严格 Zig 翻译)
// 严格翻译自: src/semver/SemverRange.zig - Comparator struct
//   pub const Comparator = struct {
//       op: Op = .unset,
//       version: Version = .{},
//       pub inline fn eql(lhs: Comparator, rhs: Comparator) bool { ... }
//       pub fn satisfies(comparator, version, comparator_buf, version_buf) bool {
//           const order = version.orderWithoutBuild(comparator.version, ...)
//           return switch (order) {
//               .eq => switch (comparator.op) { .lte, .gte, .eql => true, else => false }
//               .gt => switch (comparator.op) { .gt, .gte => true, else => false }
//               .lt => switch (comparator.op) { .lt, .lte => true, else => false }
//           }
//       }
//   }
// ============================================================================

/// 独立比较器 - 对应 Bun Range.Comparator (严格 Zig 翻译版)
/// 表示 ">=1.2.3" 或 "<2.0.0" 等单个比较条件
public class Comparator2 {
    /// 比较操作符 - 对应 Bun op: Op
    public var op: Op
    /// 目标版本 - 对应 Bun version: Version
    public var version: SemVer

    public init() {
        op = Op.Unset
        version = SemVer()
    }

    public init(op: Op, version: SemVer) {
        this.op = op
        this.version = version
    }

    /// 相等比较 - 对应 Bun Comparator.eql
    ///   pub inline fn eql(lhs: Comparator, rhs: Comparator) bool {
    ///       return lhs.op == rhs.op and lhs.version.eql(rhs.version);
    ///   }
    public func eql(other: Comparator2): Bool {
        op == other.op && version.eql(other.version)
    }

    /// 检查版本是否满足比较器 - 对应 Bun Comparator.satisfies
    ///   pub fn satisfies(comparator, version, comparator_buf, version_buf) bool {
    ///       const order = version.orderWithoutBuild(comparator.version, version_buf, comparator_buf);
    ///       return switch (order) {
    ///           .eq => switch (comparator.op) { .lte, .gte, .eql => true, else => false },
    ///           .gt => switch (comparator.op) { .gt, .gte => true, else => false },
    ///           .lt => switch (comparator.op) { .lt, .lte => true, else => false },
    ///       };
    ///   }
    public func satisfies(ver: SemVer): Bool {
        let order = ver.compareWithoutBuild(version)
        if (order == 0) {
            match (op) {
                case Lte | Gte | Eql => true
                case _ => false
            }
        } else if (order > 0) {
            match (op) {
                case Gt | Gte => true
                case _ => false
            }
        } else {
            match (op) {
                case Lt | Lte => true
                case _ => false
            }
        }
    }

    /// 格式化输出 - 对应 Bun Comparator.Formatter.format
    ///   pub fn format(this: @This(), writer: *std.Io.Writer) !void {
    ///       if (this.comparator.op == .unset) return;
    ///       switch (this.comparator.op) {
    ///           .eql => try writer.writeAll("=="),
    ///           .lt => try writer.writeAll("<"),
    ///           .lte => try writer.writeAll("<="),
    ///           .gt => try writer.writeAll(">"),
    ///           .gte => try writer.writeAll(">="),
    ///           else => unreachable,
    ///       }
    ///       try writer.print("{}", .{this.comparator.version.fmt(this.buffer)});
    ///   }
    public func toString(): String {
        if (op == Op.Unset) {
            return ""
        }
        "${op.toString()}${version.toString()}"
    }
}

// ============================================================================
// SemverRange2 - 范围 (严格 Zig 翻译)
// 严格翻译自: src/semver/SemverRange.zig - Range struct
//   const Range = @This();
//   left: Comparator = .{},
//   right: Comparator = .{},
//
//   pub fn format(this, writer) !void { ... }
//   pub fn anyRangeSatisfies(this) bool { ... }
//   pub fn initWildcard(version, wildcard) Range { ... }
//   pub inline fn hasLeft(this) bool { this.left.op != .unset }
//   pub inline fn hasRight(this) bool { this.right.op != .unset }
//   pub inline fn eql(lhs, rhs) bool { ... }
//   pub fn satisfies(range, version, ...) bool { ... }
//   pub fn satisfiesPre(range, version, ..., pre_matched) bool { ... }
// ============================================================================

/// 范围 - 对应 Bun Range (严格 Zig 翻译版)
/// 由 left 和 right 两个比较器组成 (AND 关系)
public class SemverRange2 {
    /// 左比较器 (下界) - 对应 Bun left: Comparator
    public var left: Comparator2
    /// 右比较器 (上界) - 对应 Bun right: Comparator
    public var right: Comparator2

    public init() {
        left = Comparator2()
        right = Comparator2()
    }

    public init(left: Comparator2, right: Comparator2) {
        this.left = left
        this.right = right
    }

    /// 格式化输出 - 对应 Bun Range.format
    ///   pub fn format(this: Range, writer: *std.Io.Writer) !void {
    ///       if (this.left.op == .unset and this.right.op == .unset) return;
    ///       if (this.right.op == .unset) {
    ///           try writer.print("{}", .{this.left});
    ///       } else {
    ///           try writer.print("{} {}", .{ this.left, this.right });
    ///       }
    ///   }
    public func toString(): String {
        if (left.op == Op.Unset && right.op == Op.Unset) {
            return ""
        }
        if (right.op == Op.Unset) {
            return left.toString()
        }
        "${left.toString()} ${right.toString()}"
    }

    /// 是否为通配范围 (*, >=0.0.0, >=x) - 对应 Bun Range.anyRangeSatisfies
    ///   pub fn anyRangeSatisfies(this: *const Range) bool {
    ///       return this.left.op == .gte and this.left.version.eql(.{});
    ///   }
    public func anyRangeSatisfies(): Bool {
        left.op == Op.Gte && left.version.isZero()
    }

    /// 创建通配符范围 - 对应 Bun Range.initWildcard
    ///   pub fn initWildcard(version: Version, wildcard: Query.Token.Wildcard) Range {
    ///       switch (wildcard) {
    ///           .none => { .left = .{ .op = .eql, .version = version } }
    ///           .major => { .left = .{ .op = .gte, .version = .{} } }
    ///           .minor => { left = .lt, lhs }, right = .gte, rhs } (flip!)
    ///           .patch => { left = .lt, lhs }, right = .gte, rhs } (flip!)
    ///       }
    ///   }
    ///
    /// 注意: Zig 的 Range.initWildcard 中 .minor 和 .patch 的 left 是 .lt (上界),
    /// right 是 .gte (下界), 与直觉相反! 这是 Zig 源码中的实际实现
    public static func initWildcard(version: SemVer, wildcard: Wildcard): SemverRange2 {
        match (wildcard) {
            case None =>
                // 精确匹配
                return SemverRange2(
                    Comparator2(Op.Eql, version),
                    Comparator2()
                )
            case Major =>
                // >=0.0.0 (匹配所有)
                return SemverRange2(
                    Comparator2(Op.Gte, SemVer()),
                    Comparator2()
                )
            case Minor =>
                // <(major+1).0.0 >=major.0.0
                // 注意 Zig 源码: left = .lt (lhs=major+1), right = .gte (rhs=major)
                let lhs = SemVer(version.major + 1, 0, 0)
                let rhs = SemVer(version.major, 0, 0)
                return SemverRange2(
                    Comparator2(Op.Lt, lhs),
                    Comparator2(Op.Gte, rhs)
                )
            case Patch =>
                // <major.(minor+1).0 >=major.minor.0
                let lhs = SemVer(version.major, version.minor + 1, 0)
                let rhs = SemVer(version.major, version.minor, 0)
                return SemverRange2(
                    Comparator2(Op.Lt, lhs),
                    Comparator2(Op.Gte, rhs)
                )
        }
    }

    /// 是否有左比较器 - 对应 Bun Range.hasLeft
    ///   pub inline fn hasLeft(this: Range) bool {
    ///       return this.left.op != .unset;
    ///   }
    public func hasLeft(): Bool {
        left.op != Op.Unset
    }

    /// 是否有右比较器 - 对应 Bun Range.hasRight
    ///   pub inline fn hasRight(this: Range) bool {
    ///       return this.right.op != .unset;
    ///   }
    public func hasRight(): Bool {
        right.op != Op.Unset
    }

    /// 范围相等 - 对应 Bun Range.eql
    ///   pub inline fn eql(lhs: Range, rhs: Range) bool {
    ///       return lhs.left.eql(rhs.left) and lhs.right.eql(rhs.right);
    ///   }
    public func eql(other: SemverRange2): Bool {
        left.eql(other.left) && right.eql(other.right)
    }

    /// 检查版本是否满足范围 - 对应 Bun Range.satisfies
    ///   pub fn satisfies(range: Range, version: Version, range_buf, version_buf) bool {
    ///       const has_left = range.hasLeft();
    ///       const has_right = range.hasRight();
    ///       if (!has_left) return true;
    ///       if (!range.left.satisfies(version, range_buf, version_buf)) return false;
    ///       if (has_right and !range.right.satisfies(version, range_buf, version_buf)) return false;
    ///       return true;
    ///   }
    public func satisfies(version: SemVer): Bool {
        if (!hasLeft()) {
            return true
        }
        if (!left.satisfies(version)) {
            return false
        }
        if (hasRight() && !right.satisfies(version)) {
            return false
        }
        return true
    }

    /// 检查预发布版本是否满足范围 - 对应 Bun Range.satisfiesPre
    ///   pub fn satisfiesPre(range: Range, version: Version, range_buf, version_buf, pre_matched: *bool) bool {
    ///       assert(version.tag.hasPre());
    ///       const has_left = range.hasLeft();
    ///       const has_right = range.hasRight();
    ///       if (!has_left) return true;
    ///       pre_matched.* = pre_matched.* or
    ///           (range.left.version.tag.hasPre() and
    ///               version.patch == range.left.version.patch and
    ///               version.minor == range.left.version.minor and
    ///               version.major == range.left.version.major) or
    ///           (has_right and
    ///               range.right.version.tag.hasPre() and
    ///               version.patch == range.right.version.patch and
    ///               version.minor == range.right.version.minor and
    ///               version.major == range.right.version.major);
    ///       if (!range.left.satisfies(version, range_buf, version_buf)) return false;
    ///       if (has_right and !range.right.satisfies(version, range_buf, version_buf)) return false;
    ///       return true;
    ///   }
    public func satisfiesPre(version: SemVer, preMatched: Array<Bool>): Bool {
        let hasL = hasLeft()
        let hasR = hasRight()

        if (!hasL) {
            return true
        }

        // 更新 pre_matched 标志
        var matched = preMatched[0]
        matched = matched ||
            (left.version.tag.hasPre() &&
                version.patch == left.version.patch &&
                version.minor == left.version.minor &&
                version.major == left.version.major) ||
            (hasR &&
                right.version.tag.hasPre() &&
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
}
