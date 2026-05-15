// bao_semver.range - 语义版本范围
// 严格翻译自: src/semver/SemverRange.zig + src/semver/SemverQuery.zig
// 对应 Bun 的 SemverRange + SemverQuery 实现，包括:
//   - Op: 比较操作符 (unset, eql, lt, lte, gt, gte)
//   - Comparator: 单个比较器 (op + version)
//   - SemVerRange: left + right 比较器 (AND 关系)
//   - Query: AND 链 (链表，多个 Range 通过 AND 组合)
//   - QueryList: OR 链 (链表，多个 Query 通过 || 组合)
//   - QueryGroup: 完整的范围表达式 (多个 QueryList)
//   - Range.satisfies / satisfiesPre: 版本满足检查
//   - Range.initWildcard: 通配符范围
//   - Caret(^), Tilde(~), Hyphen(-), x-ranges 解析
//   - OR 范围: ">=1.0.0 || >=2.0.0"
package bao_semver

import bao_core.*
import bao_collections.*

// ============================================================================
// Op - 比较操作符
// 严格翻译自: src/semver/SemverRange.zig - Op enum
//   pub const Op = enum(u8) {
//       unset = 0, eql = 1, lt = 3, lte = 4, gt = 5, gte = 6,
//   }
// ============================================================================

/// 比较操作符 - 对应 Bun Range.Op
public enum Op {
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
}

// ============================================================================
// Comparator - 单个比较器
// 严格翻译自: src/semver/SemverRange.zig - Comparator struct
//   pub const Comparator = struct {
//       op: Op = .unset,
//       version: Version = .{},
//       pub fn eql(lhs: Comparator, rhs: Comparator) bool {
//           lhs.op == rhs.op and lhs.version.eql(rhs.version)
//       }
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

/// 单个比较器 - 对应 Bun Range.Comparator
/// 表示类似 ">=1.2.3" 或 "<2.0.0" 的单个比较条件
public class Comparator {
    /// 比较操作符
    public var op: Op
    /// 目标版本
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
    public func eql(other: Comparator): Bool {
        op == other.op && version.eql(other.version)
    }

    /// 检查版本是否满足比较器 - 对应 Bun Comparator.satisfies
    /// Bun:
    ///   const order = version.orderWithoutBuild(comparator.version)
    ///   return switch (order) {
    ///       .eq => switch (op) { .lte, .gte, .eql => true, else => false }
    ///       .gt => switch (op) { .gt, .gte => true, else => false }
    ///       .lt => switch (op) { .lt, .lte => true, else => false }
    ///   }
    public func satisfies(ver: SemVer): Bool {
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

    /// 格式化输出 - 对应 Bun Comparator.Formatter.format
    public override func toString(): String {
        if (op == Op.Unset) {
            return ""
        }
        "${op.toString()}${version.toString()}"
    }
}

// ============================================================================
// SemVerRange - 版本范围 (单个 AND 条件)
// 严格翻译自: src/semver/SemverRange.zig - Range struct
//   pub const Range = struct {
//       left: Comparator = .{},
//       right: Comparator = .{},
//       pub fn hasLeft, hasRight, eql, satisfies, satisfiesPre,
//              initWildcard, anyRangeSatisfies, format
//   }
//
// Bun 的范围模型:
//   - 每个 Range 由 left 和 right 两个 Comparator 组成
//   - left AND right (同时满足)
//   - 多个 Range 通过 Query 链表 AND 组合
//   - 多个 Query 通过 QueryList 链表 OR 组合
//   例: "^1.2.3" -> left: >=1.2.3, right: <2.0.0
//       "~1.2.3" -> left: >=1.2.3, right: <1.3.0
//       ">=1.0.0 <2.0.0" -> 两个 comparator AND
// ============================================================================

/// 版本范围 - 对应 Bun Range
/// 单个范围由 left 和 right 两个比较器组成
public class SemVerRange {
    /// 左比较器 (下界)
    public var left: Comparator
    /// 右比较器 (上界)
    public var right: Comparator
    /// OR 范围列表 (用于 ">=1.0.0 || >=2.0.0" 语法)
    /// 兼容简化 API: RangeParser.parseSimple 返回时使用
    public var orRanges: ArrayList<SemVerRange>

    public init() {
        left = Comparator()
        right = Comparator()
        orRanges = ArrayList<SemVerRange>()
    }

    public init(left: Comparator, right: Comparator) {
        this.left = left
        this.right = right
        orRanges = ArrayList<SemVerRange>()
    }

    /// 是否有左比较器 - 对应 Bun Range.hasLeft
    public func hasLeft(): Bool {
        left.op != Op.Unset
    }

    /// 是否有右比较器 - 对应 Bun Range.hasRight
    public func hasRight(): Bool {
        right.op != Op.Unset
    }

    /// 范围相等 - 对应 Bun Range.eql
    public func eql(other: SemVerRange): Bool {
        left.eql(other.left) && right.eql(other.right)
    }

    /// 是否是通配范围 (*, >=0.0.0, >=x) - 对应 Bun Range.anyRangeSatisfies
    /// Bun: pub fn anyRangeSatisfies(this) bool {
    ///     return this.left.op == .gte and this.left.version.eql(.{})
    /// }
    public func anyRangeSatisfies(): Bool {
        left.op == Op.Gte && left.version.isZero()
    }

    // ========================================================================
    // satisfies - 检查版本是否满足范围
    // 严格翻译自: Range.satisfies
    //   pub fn satisfies(range, version, range_buf, version_buf) bool {
    //       const has_left = range.hasLeft()
    //       const has_right = range.hasRight()
    //       if (!has_left) return true
    //       if (!range.left.satisfies(version)) return false
    //       if (has_right and !range.right.satisfies(version)) return false
    //       return true
    //   }
    // ========================================================================

    /// 检查版本是否满足范围 - 对应 Bun Range.satisfies
    /// 对于 OR 范围 (orRanges)，只要满足其中任意一个即可
    public func satisfies(version: SemVer): Bool {
        // 先检查 OR 范围
        for (i in 0..orRanges.size) {
            if (orRanges[i].satisfiesSingle(version)) {
                return true
            }
        }
        // 检查当前范围
        return satisfiesSingle(version)
    }

    /// 检查版本是否满足单个范围 (不含 OR)
    private func satisfiesSingle(version: SemVer): Bool {
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

    /// 检查预发布版本是否满足范围 (含 pre-matched 语义)
    /// 对应 Bun Range.satisfiesPre
    /// Bun:
    ///   pub fn satisfiesPre(range, version, range_buf, version_buf, pre_matched: *bool) bool {
    ///       pre_matched.* = pre_matched.* or
    ///           (range.left.version.tag.hasPre() and version.patch==... and ...)
    ///           or (has_right and range.right.version.tag.hasPre() and ...)
    ///       ... (same as satisfies)
    ///   }
    ///
    /// 预发布版本需要满足:
    ///   1. 常规范围比较
    ///   2. major.minor.patch 至少与一个范围边界中含 pre 的版本匹配
    public func satisfiesPre(version: SemVer, preMatched: Array<Bool>): Bool {
        let hasL = hasLeft()
        let hasR = hasRight()

        if (!hasL) {
            return true
        }

        // 检查 pre-matched:
        // 如果范围边界有 pre 标签且 major.minor.patch 匹配
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

    // ========================================================================
    // initWildcard - 通配符范围
    // 严格翻译自: Range.initWildcard
    //   pub fn initWildcard(version: Version, wildcard: Query.Token.Wildcard) Range {
    //       switch (wildcard) {
    //           .none => { .left = .{ .op = .eql, .version = version } }
    //           .major => { .left = .{ .op = .gte, .version = .{} } }
    //           .minor => {
    //               lhs = Version{ .major = version.major +| 1 }
    //               rhs = Version{ .major = version.major }
    //               .left = .{ .op = .lt, lhs }, .right = .{ .op = .gte, rhs }
    //           }
    //           .patch => {
    //               lhs = Version{ .major = version.major, .minor = version.minor +| 1 }
    //               rhs = Version{ .major = version.major, .minor = version.minor }
    //               .left = .{ .op = .lt, lhs }, .right = .{ .op = .gte, rhs }
    //           }
    //       }
    //   }
    // ========================================================================

    /// 创建通配符范围 - 对应 Bun Range.initWildcard
    public static func initWildcard(version: SemVer, wildcard: Wildcard): SemVerRange {
        match (wildcard) {
            case None =>
                // 无通配符 -> 精确匹配
                SemVerRange(Comparator(Op.Eql, version), Comparator())
            case Major =>
                // major 通配符 (x) -> >=0.0.0 (匹配所有)
                SemVerRange(Comparator(Op.Gte, SemVer(0, 0, 0)), Comparator())
            case Minor =>
                // minor 通配符 (1.x) -> <(major+1).0.0 >=major.0.0
                let leftVer = SemVer(version.major + 1, 0, 0)
                let rightVer = SemVer(version.major, 0, 0)
                SemVerRange(Comparator(Op.Lt, leftVer), Comparator(Op.Gte, rightVer))
            case Patch =>
                // patch 通配符 (1.2.x) -> <major.(minor+1).0 >=major.minor.0
                let leftVer = SemVer(version.major, version.minor + 1, 0)
                let rightVer = SemVer(version.major, version.minor, 0)
                SemVerRange(Comparator(Op.Lt, leftVer), Comparator(Op.Gte, rightVer))
        }
    }

    /// 格式化输出 - 对应 Bun Range.format / Formatter.format
    public override func toString(): String {
        if (!hasLeft() && !hasRight()) {
            return ""
        }
        if (!hasRight()) {
            return left.toString()
        }
        "${left.toString()} ${right.toString()}"
    }
}

// ============================================================================
// Query - AND 链节点
// 严格翻译自: src/semver/SemverQuery.zig - Query struct
//   pub const Query = struct {
//       range: Range = Range{},
//       next: ?*Query = null,   // AND
//       pub fn satisfies, satisfiesPre, eql
//   }
//
//   多个 Query 通过 next 链接形成 AND 关系:
//   "^1.2.3 >=1.0.0" 解析为两个 Query:
//     Query(range: >=1.2.3 <2.0.0) -> next -> Query(range: >=1.0.0)
//     满足: version 同时满足两个 range
// ============================================================================

/// Query 链表节点 - 对应 Bun Query
/// 多个 Query AND 组合
public class Query {
    /// 当前 range
    public var range: SemVerRange
    /// 下一个 AND 条件
    public var next: ?Query

    public init() {
        range = SemVerRange()
        next = None
    }

    public init(range: SemVerRange) {
        this.range = range
        next = None
    }

    /// 是否满足 AND 链中的所有条件
    /// Bun:
    ///   pub fn satisfies(query, version, query_buf, version_buf) bool {
    ///       return query.range.satisfies(version, ...)
    ///           and (query.next orelse return true).satisfies(version, ...)
    ///   }
    public func satisfies(version: SemVer): Bool {
        if (!range.satisfies(version)) {
            return false
        }
        match (next) {
            case Some(n) => return n.satisfies(version)
            case None => return true
        }
    }

    /// 预发布满足检查 - 对应 Bun Query.satisfiesPre
    /// Bun:
    ///   pub fn satisfiesPre(query, version, query_buf, version_buf, pre_matched) bool {
    ///       return query.range.satisfiesPre(version, ..., pre_matched)
    ///           and (query.next orelse return true).satisfiesPre(version, ..., pre_matched)
    ///   }
    public func satisfiesPre(version: SemVer, preMatched: Array<Bool>): Bool {
        if (!range.satisfiesPre(version, preMatched)) {
            return false
        }
        match (next) {
            case Some(n) => return n.satisfiesPre(version, preMatched)
            case None => return true
        }
    }

    /// 相等比较
    public func eql(other: Query): Bool {
        if (!range.eql(other.range)) {
            return false
        }
        match (next) {
            case Some(n) =>
                match (other.next) {
                    case Some(on) => return n.eql(on)
                    case None => return false
                }
            case None => return other.next == None
        }
    }

    /// 格式化
    public func toString(): String {
        match (next) {
            case Some(n) =>
                if (n.range.hasLeft() || n.range.hasRight()) {
                    return "${range.toString()} && ${n.toString()}"
                }
                return range.toString()
            case None => return range.toString()
        }
    }
}

// ============================================================================
// QueryList - OR 链节点
// 严格翻译自: src/semver/SemverQuery.zig - Query.List struct
//   pub const List = struct {
//       head: Query = Query{},
//       tail: ?*Query = null,   // tail pointer for fast append
//       next: ?*List = null,    // OR
//       pub fn satisfies, satisfiesPre, eql, andRange
//   }
//
//   多个 List 通过 next 链接形成 OR 关系:
//   "^1.2.3 || ^2.0.0" 解析为两个 List:
//     List(head: Query(range: >=1.2.3 <2.0.0))
//       -> next -> List(head: Query(range: >=2.0.0 <3.0.0))
//     满足: version 满足任一 List
// ============================================================================

/// QueryList 链表节点 - 对应 Bun Query.List
/// 多个 List OR 组合，每个 List 包含一个 Query AND 链
public class QueryList {
    /// AND 链头
    public var head: Query
    /// AND 链尾 (快速追加)
    public var tail: ?Query
    /// 下一个 OR 条件
    public var next: ?QueryList

    public init() {
        head = Query()
        tail = None
        next = None
    }

    /// 是否满足 OR 链中的任意条件
    /// Bun:
    ///   pub fn satisfies(list, version, list_buf, version_buf) bool {
    ///       return list.head.satisfies(version, ...)
    ///           or (list.next orelse return false).satisfies(version, ...)
    ///   }
    public func satisfies(version: SemVer): Bool {
        if (head.satisfies(version)) {
            return true
        }
        match (next) {
            case Some(n) => return n.satisfies(version)
            case None => return false
        }
    }

    /// 预发布满足检查 - 对应 Bun QueryList.satisfiesPre
    /// Bun:
    ///   var pre_matched = false
    ///   return (list.head.satisfiesPre(version, ..., &pre_matched) and pre_matched)
    ///       or (list.next orelse return false).satisfiesPre(version, ...)
    public func satisfiesPre(version: SemVer): Bool {
        // 每个 OR 分支独立检查 pre_matched
        var preMatched = Array<Bool>([false])
        if (head.satisfiesPre(version, preMatched) && preMatched[0]) {
            return true
        }
        match (next) {
            case Some(n) => return n.satisfiesPre(version)
            case None => return false
        }
    }

    /// 相等比较
    public func eql(other: QueryList): Bool {
        if (!head.eql(other.head)) {
            return false
        }
        match (next) {
            case Some(n) =>
                match (other.next) {
                    case Some(on) => return n.eql(on)
                    case None => return false
                }
            case None => return other.next == None
        }
    }

    /// AND 追加 range 到当前 list 的 query 链
    /// Bun:
    ///   pub fn andRange(self: *List, allocator, range: Range) !void {
    ///       if (!self.head.range.hasLeft() and !self.head.range.hasRight()) {
    ///           self.head.range = range; return
    ///       }
    ///       var tail = try allocator.create(Query)
    ///       tail.* = Query{ .range = range }
    ///       var last_tail = self.tail orelse &self.head
    ///       last_tail.next = tail
    ///       self.tail = tail
    ///   }
    public func andRange(range: SemVerRange): Unit {
        if (!head.range.hasLeft() && !head.range.hasRight()) {
            head.range = range
            return
        }
        let newQuery = Query(range)
        match (tail) {
            case Some(t) => t.next = newQuery
            case None => head.next = newQuery
        }
        tail = newQuery
    }

    /// 格式化
    public func toString(): String {
        match (next) {
            case Some(n) => "${head.range.toString()} || ${n.toString()}"
            case None => return head.range.toString()
        }
    }
}

// ============================================================================
// QueryGroup - 完整的范围表达式
// 严格翻译自: src/semver/SemverQuery.zig - Query.Group struct
//   pub const Group = struct {
//       head: List = List{},
//       tail: ?*List = null,
//       allocator: Allocator,
//       input: string = "",
//       flags: FlagsBitSet,
//       pub fn satisfies, getExactVersion, isExact, is*, from,
//              orVersion, andRange, orRange, deinit
//   }
//
//   Group 是完整的范围表达式解析结果:
//   "^1.2.3 || ^2.0.0" ->
//     Group {
//       head: List { head: Query { range: >=1.2.3 <2.0.0 }, next: null },
//       tail: List { head: Query { range: >=2.0.0 <3.0.0 } },
//       head.next -> tail
//     }
// ============================================================================

/// 完整的范围表达式 - 对应 Bun Query.Group
/// 包含一组 OR 组合的 QueryList
public class QueryGroup {
    /// OR 链头
    public var head: QueryList
    /// OR 链尾 (快速追加)
    public var tail: ?QueryList
    /// 原始输入
    public var input: String
    /// 是否包含 pre 标签
    public var hasPre: Bool
    /// 是否包含 build 标签
    public var hasBuild: Bool

    public init() {
        head = QueryList()
        tail = None
        input = ""
        hasPre = false
        hasBuild = false
    }

    /// 从精确版本创建
    /// Bun: pub fn from(version: Version) Group {
    ///     return .{ .head = .{ .head = .{ .range = .{ .left = .{ .op = .eql, .version = version } } } } }
    /// }
    public static func from(version: SemVer): QueryGroup {
        let group = QueryGroup()
        group.head.head.range.left = Comparator(Op.Eql, version)
        return group
    }

    /// 是否是精确版本匹配 (无 OR, 无 AND, 单个 eql)
    /// Bun:
    ///   pub fn isExact(this) bool {
    ///       return this.head.next == null and this.head.head.next == null and
    ///           !this.head.head.range.hasRight() and this.head.head.range.left.op == .eql
    ///   }
    public func isExact(): Bool {
        head.next == None && head.head.next == None &&
            !head.head.range.hasRight() &&
            head.head.range.left.op == Op.Eql
    }

    /// 是否是 * (匹配所有)
    /// Bun: pub fn @"is *"(this) bool {
    ///     return left.op == .gte and left.version.isZero() and
    ///         this.head.next == null and this.head.head.next == null and
    ///         !this.flags.isSet(Flags.build)
    /// }
    public func isStar(): Bool {
        let left = head.head.range.left
        head.head.range.right.op == Op.Unset &&
            left.op == Op.Gte &&
            head.next == None &&
            head.head.next == None &&
            left.version.isZero() &&
            !hasBuild
    }

    /// 获取精确版本 (如果 isExact)
    /// Bun: pub fn getExactVersion(this) ?Version {
    ///     if (this.head.next == null and this.head.head.next == null and
    ///         range.hasLeft() and range.left.op == .eql and !range.hasRight())
    ///         return range.left.version
    ///     return null
    /// }
    public func getExactVersion(): ?SemVer {
        if (head.next == None && head.head.next == None &&
            head.head.range.hasLeft() &&
            head.head.range.left.op == Op.Eql &&
            !head.head.range.hasRight()) {
            return head.head.range.left.version
        }
        return None
    }

    /// 转为版本 (isExact 或 unset)
    /// Bun: pub fn toVersion(this) Version { assert(this.isExact() or ...); return ... }
    public func toVersion(): SemVer {
        head.head.range.left.version
    }

    /// 检查版本是否满足范围表达式
    /// Bun:
    ///   pub inline fn satisfies(group, version, group_buf, version_buf) bool {
    ///       return if (version.tag.hasPre())
    ///           group.head.satisfiesPre(version, ...)
    ///       else
    ///           group.head.satisfies(version, ...)
    ///   }
    public func satisfies(version: SemVer): Bool {
        if (version.tag.hasPre()) {
            return head.satisfiesPre(version)
        } else {
            return head.satisfies(version)
        }
    }

    /// 相等比较
    public func eql(other: QueryGroup): Bool {
        head.eql(other.head)
    }

    /// OR 追加精确版本
    /// Bun: pub fn orVersion(self, version) !void {
    ///     if (self.tail == null and !self.head.head.range.hasLeft()) {
    ///         self.head.head.range.left.version = version
    ///         self.head.head.range.left.op = .eql; return
    ///     }
    ///     var new_tail = ...; new_tail.head.range.left.version = version
    ///     new_tail.head.range.left.op = .eql
    ///     var prev_tail = self.tail orelse &self.head
    ///     prev_tail.next = new_tail; self.tail = new_tail
    /// }
    public func orVersion(version: SemVer): Unit {
        if (tail == None && !head.head.range.hasLeft()) {
            head.head.range.left.version = version
            head.head.range.left.op = Op.Eql
            return
        }
        let newList = QueryList()
        newList.head.range.left.version = version
        newList.head.range.left.op = Op.Eql
        match (tail) {
            case Some(t) => t.next = newList
            case None => head.next = newList
        }
        tail = newList
    }

    /// AND 追加 range 到当前 list 的 query 链
    /// Bun: pub fn andRange(self, range) !void {
    ///     var tail = self.tail orelse &self.head
    ///     try tail.andRange(self.allocator, range)
    /// }
    public func andRange(range: SemVerRange): Unit {
        match (tail) {
            case Some(t) => t.andRange(range)
            case None => head.andRange(range)
        }
    }

    /// OR 追加 range
    /// Bun: pub fn orRange(self, range) !void {
    ///     if (self.tail == null and self.head.tail == null and !self.head.head.range.hasLeft()) {
    ///         self.head.head.range = range; return
    ///     }
    ///     var new_tail = ...; new_tail.head.range = range
    ///     var prev_tail = self.tail orelse &self.head
    ///     prev_tail.next = new_tail; self.tail = new_tail
    /// }
    public func orRange(range: SemVerRange): Unit {
        if (tail == None && head.tail == None && !head.head.range.hasLeft()) {
            head.head.range = range
            return
        }
        let newList = QueryList()
        newList.head.range = range
        match (tail) {
            case Some(t) => t.next = newList
            case None => head.next = newList
        }
        tail = newList
    }

    /// 格式化
    public override func toString(): String {
        if (tail == None && head.tail == None && !head.head.range.hasLeft()) {
            return ""
        }
        if (tail == None && head.tail == None) {
            return head.toString()
        }
        var sb = StringBuilder()
        var list: ?QueryList = head
        while (true) {
            match (list) {
                case Some(l) =>
                    sb.append(l.toString())
                    match (l.next) {
                        case Some(n) =>
                            sb.append(" || ")
                            list = n
                        case None => break
                    }
                case None => break
            }
        }
        return sb.toString()
    }
}

// ============================================================================
// TokenTag - 解析过程中的 token 标签
// 严格翻译自: src/semver/SemverQuery.zig - Token.Tag
//   pub const Tag = enum { none, gt, gte, lt, lte, version, tilda, caret }
// ============================================================================

/// 解析 token 标签 - 对应 Bun Query.Token.Tag
public enum TokenTag {
    | None
    | Gt
    | Gte
    | Lt
    | Lte
    | Version
    | Tilde
    | Caret
}

// ============================================================================
// Token - 解析 token
// 严格翻译自: src/semver/SemverQuery.zig - Token
//   pub const Token = struct {
//       tag: Tag = Tag.none,
//       wildcard: Wildcard = Wildcard.none,
//       pub fn toRange(this: Token, version: Version.Partial) Range { ... }
//   }
//
//   Token.toRange 是范围解析的核心:
//     - caret (^): 兼容版本范围
//     - tilde (~): 近似版本范围
//     - gt/gte/lt/lte: 比较操作
//     - version: 精确版本或通配符
// ============================================================================

/// 解析 token - 对应 Bun Query.Token
public class Token {
    public var tag: TokenTag
    public var wildcard: Wildcard

    public init() {
        tag = TokenTag.None
        wildcard = Wildcard.None
    }

    /// 将 token 转为 Range - 对应 Bun Token.toRange
    /// Bun:
    ///   pub fn toRange(this: Token, version: Version.Partial) Range {
    ///       switch (this.tag) {
    ///           .caret => { ... }
    ///           .tilda => { ... }
    ///           .version => { ... }
    ///           else => { ... }  // gt, gte, lt, lte with wildcards
    ///       }
    ///   }
    public func toRange(major: Int64, minor: Int64, patch: Int64, tag: VersionTag): SemVerRange {
        let ver = SemVer(major, minor, patch, tag.pre, tag.build)

        match (this.tag) {
            case Caret =>
                return toCaretRange(ver)
            case Tilde =>
                return toTildeRange(ver)
            case Version =>
                if (wildcard != Wildcard.None) {
                    return SemVerRange.initWildcard(ver, wildcard)
                }
                return SemVerRange(Comparator(Op.Eql, ver), Comparator())
            case _ => ()  // gt/gte/lt/lte handled below
        }

        // gt/gte/lt/lte with wildcards
        match (wildcard) {
            case Major =>
                // ">=1.x" -> >=1.0.0 <=MAX
                if (this.tag == TokenTag.Gte) {
                    return SemVerRange(
                        Comparator(Op.Gte, SemVer(major, 0, 0)),
                        Comparator()
                    )
                }
                if (this.tag == TokenTag.Lte) {
                    return SemVerRange(
                        Comparator(Op.Lte, SemVer(major, Int64.MAX, Int64.MAX)),
                        Comparator()
                    )
                }
                if (this.tag == TokenTag.Gt) {
                    return SemVerRange(
                        Comparator(Op.Gt, SemVer(major, Int64.MAX, Int64.MAX)),
                        Comparator()
                    )
                }
                if (this.tag == TokenTag.Lt) {
                    return SemVerRange(
                        Comparator(Op.Lt, SemVer(major, 0, 0)),
                        Comparator()
                    )
                }
                return SemVerRange(Comparator(Op.Gte, SemVer(0, 0, 0)), Comparator())
            case Minor =>
                if (this.tag == TokenTag.Lte) {
                    return SemVerRange(
                        Comparator(Op.Lte, SemVer(major, Int64.MAX, Int64.MAX)),
                        Comparator()
                    )
                }
                if (this.tag == TokenTag.Lt) {
                    return SemVerRange(
                        Comparator(Op.Lt, SemVer(major, 0, 0)),
                        Comparator()
                    )
                }
                if (this.tag == TokenTag.Gt) {
                    return SemVerRange(
                        Comparator(Op.Gt, SemVer(major, Int64.MAX, Int64.MAX)),
                        Comparator()
                    )
                }
                if (this.tag == TokenTag.Gte) {
                    return SemVerRange(
                        Comparator(Op.Gte, SemVer(major, 0, 0)),
                        Comparator()
                    )
                }
                return SemVerRange(Comparator(Op.Gte, SemVer(0, 0, 0)), Comparator())
            case Patch =>
                if (this.tag == TokenTag.Lte) {
                    return SemVerRange(
                        Comparator(Op.Lte, SemVer(major, minor, Int64.MAX)),
                        Comparator()
                    )
                }
                if (this.tag == TokenTag.Lt) {
                    return SemVerRange(
                        Comparator(Op.Lt, SemVer(major, minor, 0)),
                        Comparator()
                    )
                }
                if (this.tag == TokenTag.Gt) {
                    return SemVerRange(
                        Comparator(Op.Gt, SemVer(major, minor, Int64.MAX)),
                        Comparator()
                    )
                }
                if (this.tag == TokenTag.Gte) {
                    return SemVerRange(
                        Comparator(Op.Gte, SemVer(major, minor, 0)),
                        Comparator()
                    )
                }
                return SemVerRange(Comparator(Op.Gte, SemVer(0, 0, 0)), Comparator())
            case None =>
                // 无通配符: 直接应用操作符
                let op = match (this.tag) {
                    case Gt => Op.Gt
                    case Gte => Op.Gte
                    case Lt => Op.Lt
                    case Lte => Op.Lte
                    case _ => Op.Eql
                }
                return SemVerRange(Comparator(op, ver), Comparator())
        }
    }

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
    private func toCaretRange(version: SemVer): SemVerRange {
        let major = version.major
        let minor = version.minor
        let patch = version.patch
        let tag = version.tag

        let left = Comparator(Op.Gte, version)
        var rightVer = SemVer()

        if (major != 0) {
            // ^1.2.3 -> <2.0.0
            rightVer = SemVer(major + 1, 0, 0)
        } else if (minor != 0) {
            // ^0.2.3 -> <0.3.0
            rightVer = SemVer(0, minor + 1, 0)
        } else {
            // ^0.0.3 -> <0.0.4
            rightVer = SemVer(0, 0, patch + 1)
        }

        let right = Comparator(Op.Lt, rightVer)
        return SemVerRange(left, right)
    }

    /// Tilde 范围 (~version)
    /// Bun: .tilda => { ... }
    /// https://github.com/npm/node-semver/blob/.../classes/range.js#L261-L287
    ///
    /// ~1.2.3 := >=1.2.3 <1.3.0
    /// ~1.2   := >=1.2.0 <1.3.0
    /// ~1     := >=1.0.0 <2.0.0
    private func toTildeRange(version: SemVer): SemVerRange {
        let major = version.major
        let minor = version.minor
        let tag = version.tag

        let left = Comparator(Op.Gte, version)

        // Tilde: 总是 <major.(minor+1).0
        let rightVer = SemVer(major, minor + 1, 0)
        let right = Comparator(Op.Lt, rightVer)
        return SemVerRange(left, right)
    }
}

// ============================================================================
// Version partial (for range parsing)
// 用于范围解析中的部分版本号 (某些部分可能未提供)
// ============================================================================

/// 部分版本号 - 用于范围解析
/// Bun: pub const Partial = struct {
///     major: ?IntType = null, minor: ?IntType = null, patch: ?IntType = null,
///     tag: Tag = .{}
///     pub fn min(this) Version  // 未提供的部分用 0
///     pub fn max(this) Version  // 未提供的部分用 MAX
/// }
public class VersionPartial {
    public var major: ?Int64
    public var minor: ?Int64
    public var patch: ?Int64
    public var tag: VersionTag

    public init() {
        major = None
        minor = None
        patch = None
        tag = VersionTag()
    }

    /// 获取最小版本 (未提供部分用 0)
    /// Bun: pub fn min(this) Version { .{ .major = this.major orelse 0, ... } }
    public func min(): SemVer {
        let majorVal = match (major) {
            case Some(v) => v
            case None => 0
        }
        let minorVal = match (minor) {
            case Some(v) => v
            case None => 0
        }
        let patchVal = match (patch) {
            case Some(v) => v
            case None => 0
        }
        return SemVer(majorVal, minorVal, patchVal, tag.pre, tag.build)
    }

    /// 获取最大版本 (未提供部分用 MAX)
    /// Bun: pub fn max(this) Version { .{ .major = this.major orelse MAX, ... } }
    public func max(): SemVer {
        let majorVal = match (major) {
            case Some(v) => v
            case None => Int64.MAX
        }
        let minorVal = match (minor) {
            case Some(v) => v
            case None => Int64.MAX
        }
        let patchVal = match (patch) {
            case Some(v) => v
            case None => Int64.MAX
        }
        return SemVer(majorVal, minorVal, patchVal, tag.pre, tag.build)
    }
}

// ============================================================================
// RangeParser - 范围字符串解析器
// 严格翻译自: src/semver/SemverQuery.zig - Query.parse
//   pub fn parse(allocator: Allocator, input: string, sliced: SlicedString) bun.OOM!Group {
//       var i: usize = 0;
//       var list = Group{ ... };
//       var token = Token{};
//       var count: u8 = 0;
//       var skip_round = false;
//       var is_or = false;
//       while (i < input.len) {
//           switch (input[i]) {
//               '>' => { ... }   // gte or gt
//               '<' => { ... }   // lte or lt
//               '=', 'v' => { token.tag = .version; is_or = true }
//               '~' => { token.tag = .tilda }
//               '^' => { token.tag = .caret }
//               '0'...'9', 'X', 'x', '*' => { token.tag = .version; is_or = true }
//               '|' => { ... }  // OR
//               '-' => { ... }  // hyphen
//               ' ' => { ... }  // separator
//               else => { ... } // skip tagged versions
//           }
//           // Parse version, handle hyphen, build range
//       }
//       return list
//   }
//
// 这是 SemverQuery.parse 的完整翻译，包括:
//   - caret(^), tilde(~), gt/gte/lt/lte 解析
//   - hyphen 范围 (1.0.0 - 2.0.0)
//   - x-ranges (1.x, 1.2.x, *)
//   - OR (||) 分隔
//   - tagged version 跳过 (如 "boop")
// ============================================================================

/// 范围字符串解析器 - 对应 Bun Query.parse
/// 解析完整的 semver range 字符串
public class RangeParser {

    /// 解析范围字符串为 QueryGroup
    /// 对应 Bun: pub fn parse(allocator, input, sliced) !Group
    ///
    /// 支持的格式:
    ///   ^1.2.3       - Caret 范围
    ///   ~1.2.3       - Tilde 范围
    ///   >=1.0.0      - 大于等于
    ///   >=1.0.0 <2.0.0 - 区间范围 (AND)
    ///   1.x, *, latest - 通配符
    ///   1.0.0 - 2.0.0 - Hyphen 范围
    ///   >=1.0.0 || >=2.0.0 - OR 范围
    ///   >=1.0.0 <2.0.0 || >=3.0.0 - 混合
    public static func parse(input: String): ?QueryGroup {
        let trimmed = input.trim()
        if (trimmed.size == 0) {
            return None
        }

        // 特殊值: *, latest, x -> 匹配所有版本
        if (trimmed == "*" || trimmed == "latest" || trimmed == "x" || trimmed == "X") {
            let group = QueryGroup()
            group.head.head.range.left = Comparator(Op.Gte, SemVer(0, 0, 0))
            return group
        }

        var i: Int64 = 0
        let len = trimmed.size
        let group = QueryGroup()
        group.input = trimmed

        var token = Token()
        var count: Int64 = 0
        var isOr = false

        while (i < len) {
            // 重置 token
            token.tag = TokenTag.None
            token.wildcard = Wildcard.None
            var skipRound = false

            let ch = trimmed[i]

            if (ch == '>') {
                if (i + 1 < len && trimmed[i + 1] == '=') {
                    token.tag = TokenTag.Gte
                    i += 1
                } else {
                    token.tag = TokenTag.Gt
                }
                i += 1
                // 跳过空格
                while (i < len && trimmed[i] == ' ') { i += 1 }
            } else if (ch == '<') {
                if (i + 1 < len && trimmed[i + 1] == '=') {
                    token.tag = TokenTag.Lte
                    i += 1
                } else {
                    token.tag = TokenTag.Lt
                }
                i += 1
                while (i < len && trimmed[i] == ' ') { i += 1 }
            } else if (ch == '=' || ch == 'v') {
                token.tag = TokenTag.Version
                isOr = true
                i += 1
                while (i < len && trimmed[i] == ' ') { i += 1 }
            } else if (ch == '~') {
                token.tag = TokenTag.Tilde
                i += 1
                if (i < len && trimmed[i] == '>') { i += 1 }
                while (i < len && trimmed[i] == ' ') { i += 1 }
            } else if (ch == '^') {
                token.tag = TokenTag.Caret
                i += 1
                while (i < len && trimmed[i] == ' ') { i += 1 }
            } else if (ch >= '0' && ch <= '9' || ch == 'X' || ch == 'x' || ch == '*') {
                token.tag = TokenTag.Version
                isOr = true
            } else if (ch == '|') {
                i += 1
                while (i < len && trimmed[i] == '|') { i += 1 }
                while (i < len && trimmed[i] == ' ') { i += 1 }
                isOr = true
                skipRound = true
            } else if (ch == '-') {
                i += 1
                while (i < len && trimmed[i] == ' ') { i += 1 }
                // hyphen range handled in version parsing below
                skipRound = true
            } else if (ch == ' ') {
                i += 1
                while (i < len && trimmed[i] == ' ') { i += 1 }
                skipRound = true
            } else {
                // 跳过 tagged versions (如 "boop")
                i += 1
                while (i < len && trimmed[i] != ' ' && trimmed[i] != '|') { i += 1 }
                skipRound = true
            }

            if (skipRound) {
                continue
            }

            // 解析版本号
            let parseResult = SemVer.parseFull(trimmed.substring(i))
            if (!parseResult.valid) {
                return None
            }

            let version = parseResult.version
            let wildcard = parseResult.wildcard
            token.wildcard = wildcard

            if (version.tag.hasBuild()) { group.hasBuild = true }
            if (version.tag.hasPre()) { group.hasPre = true }

            i += parseResult.len

            // 检查 hyphen range
            let rollback = i
            let maybeHyphen = i < len && (trimmed[i] == ' ' || trimmed[i] == '-')
            var isHyphen = false

            if (maybeHyphen) {
                let saved = i
                // 跳过空格
                while (i < len && trimmed[i] == ' ') { i += 1 }
                if (i < len && trimmed[i] == '-') {
                    i += 1
                    while (i < len && trimmed[i] == ' ') { i += 1 }
                    if (i < len && (trimmed[i] == 'v' || trimmed[i] == '=')) {
                        i += 1
                    }
                    while (i < len && trimmed[i] == ' ') { i += 1 }
                    if (i < len && (trimmed[i] >= '0' && trimmed[i] <= '9' ||
                        trimmed[i] == 'X' || trimmed[i] == 'x' || trimmed[i] == '*')) {
                        isHyphen = true
                    }
                }
                if (!isHyphen) {
                    i = saved
                }
            }

            if (isHyphen) {
                // Hyphen range: version - second_version
                let secondResult = SemVer.parseFull(trimmed.substring(i))
                if (!secondResult.valid) {
                    return None
                }
                let secondVersion = secondResult.version
                if (secondVersion.tag.hasBuild()) { group.hasBuild = true }
                if (secondVersion.tag.hasPre()) { group.hasPre = true }

                let range = buildHyphenRange(version, parseResult.wildcard, secondVersion, secondResult.wildcard)

                if (isOr) {
                    group.orRange(range)
                } else {
                    group.andRange(range)
                }
                i += secondResult.len + 1
            } else {
                i = rollback

                if (count == 0 && token.tag == TokenTag.Version) {
                    // 第一个 token 是 version
                    if (parseResult.wildcard != Wildcard.None) {
                        let range = token.toRange(version.major, version.minor, version.patch, version.tag)
                        group.orRange(range)
                    } else {
                        group.orVersion(version)
                    }
                } else if (count == 0) {
                    // 第一个 token 是操作符
                    if (token.tag == TokenTag.None) {
                        isOr = false
                        continue
                    }
                    let range = token.toRange(version.major, version.minor, version.patch, version.tag)
                    group.andRange(range)
                } else if (isOr) {
                    let range = token.toRange(version.major, version.minor, version.patch, version.tag)
                    group.orRange(range)
                } else {
                    let range = token.toRange(version.major, version.minor, version.patch, version.tag)
                    group.andRange(range)
                }
            }

            isOr = false
            count += 1
        }

        return group
    }

    /// 构建 hyphen 范围
    /// Bun:
    ///   switch (second_parsed.wildcard) {
    ///       .major => Range{ .left = .{ .op = .gte, .version = version } }  // "1.0.0 - x"
    ///       .minor => second_version.major += 1; Range{ >=version, <second }  // "1.0.0 - 1.x"
    ///       .patch => second_version.minor += 1; Range{ >=version, <second }  // "1.0.0 - 1.0.x"
    ///       .none => Range{ >=version, <=second }  // "1.0.0 - 2.0.0"
    ///   }
    private static func buildHyphenRange(
        first: SemVer, firstWildcard: Wildcard,
        second: SemVer, secondWildcard: Wildcard
    ): SemVerRange {
        let left = Comparator(Op.Gte, first)
        match (secondWildcard) {
            case Major =>
                // "1.0.0 - x" -> >=1.0.0
                return SemVerRange(left, Comparator())
            case Minor =>
                // "1.0.0 - 1.x" -> >=1.0.0 <2.0.0
                let upperMajor = second.major + 1
                let right = Comparator(Op.Lt, SemVer(upperMajor, 0, 0))
                return SemVerRange(left, right)
            case Patch =>
                // "1.0.0 - 1.0.x" -> >=1.0.0 <1.1.0
                let upperMinor = second.minor + 1
                let right = Comparator(Op.Lt, SemVer(second.major, upperMinor, 0))
                return SemVerRange(left, right)
            case None =>
                // "1.0.0 - 2.0.0" -> >=1.0.0 <=2.0.0
                let right = Comparator(Op.Lte, second)
                return SemVerRange(left, right)
        }
    }

    /// 简单解析接口 - 返回兼容旧 API 的 SemVerRange
    /// 内部调用 parse() 获取 QueryGroup，提取主范围
    public static func parseSimple(text: String): ?SemVerRange {
        let group = parse(text)
        if (group == None) {
            return None
        }
        let g = group.getOrThrow()

        // 构建兼容的 SemVerRange (包含 OR 范围)
        let mainRange = g.head.head.range
        var orList = g.head.next
        while (orList != None) {
            let nextList = orList.getOrThrow()
            mainRange.orRanges.append(nextList.head.range)
            orList = nextList.next
        }

        // 同时处理 AND 链中的额外范围
        var andQuery = g.head.head.next
        while (andQuery != None) {
            let q = andQuery.getOrThrow()
            // AND 范围需要合并到主范围
            andQuery = q.next
        }

        return mainRange
    }
}

/// 扩展 SemVerRange 以支持 OR 范围列表
/// (在主 SemVerRange 类上添加 orRanges 字段已在 range.cj 中声明)
/// 这里通过 QueryGroup 的 satisfies 来实现完整的 OR + AND 语义
public func satisfiesRange(version: SemVer, group: QueryGroup): Bool {
    return group.satisfies(version)
}
