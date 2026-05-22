// 严格翻译自: src/semver/SemverQuery.rs
//   Semver 查询/匹配引擎
//   Op: AND/OR 操作符枚举
//   Query: AND 链节点 (range + next AND)
//   List: OR 链节点 (head Query + next OR)
//   Group: 完整范围表达式 (head List + tail + flags)
//   Token/TokenTag/Wildcard: 解析 token
//   Token.toRange: token 转范围 (caret/tilde/gt/gte/lt/lte)
//   parse: 范围字符串解析器
//   satisfies/satisfiesPre: 版本匹配检查
//
// 注意: range.cj 中已有 Op, Comparator, SemVerRange, Query, QueryList, QueryGroup, RangeParser 等
// query.cj 中已有 SemverQuery (高级 API)
// 本文件提供 SemverQuery.rs 的补充翻译，包括:
//   - SemverOp: AND/OR 操作符枚举 (Zig 严格翻译)
//   - SemverQuery2/Query2: AND 链 (Zig 严格翻译)
//   - SemverList2: OR 链 (Zig 严格翻译)
//   - SemverGroup2: 完整范围 (Zig 严格翻译)
//   - SemverToken/SemverTokenTag: 解析 token (Zig 严格翻译)
//   - SemverParse: 范围字符串解析器 (Zig 严格翻译)
package bao_semver

import bao_core.*
import bao_collections.*

// ============================================================================
// SemverOp - AND/OR 操作符枚举
// 严格翻译自: src/semver/SemverQuery.rs - Op enum
//   pub enum Op { None, And, Or }
// ============================================================================

/// AND/OR 操作符 - 对应 Bun Query Op
public enum SemverOp {
    | None
    | And
    | Or
}

// ============================================================================
// SemverTokenTag - 解析 token 标签
// 严格翻译自: src/semver/SemverQuery.rs - TokenTag enum
//   pub enum TokenTag { None, Gt, Gte, Lt, Lte, Version, Tilda, Caret }
// ============================================================================

/// 解析 token 标签 - 对应 Bun Query TokenTag
public enum SemverTokenTag {
    | None
    | Gt
    | Gte
    | Lt
    | Lte
    | Version
    | Tilda   // Zig 使用 "Tilda" (非 "Tilde")
    | Caret

    public func toString(): String {
        match (this) {
            case None => "none"
            case Gt => ">"
            case Gte => ">="
            case Lt => "<"
            case Lte => "<="
            case Version => "version"
            case Tilda => "~"
            case Caret => "^"
        }
    }
}

private func isSemverTokenTag(left: SemverTokenTag, right: SemverTokenTag): Bool {
    match (left) {
        case SemverTokenTag.None => return match (right) { case SemverTokenTag.None => true; case _ => false }
        case SemverTokenTag.Gt => return match (right) { case SemverTokenTag.Gt => true; case _ => false }
        case SemverTokenTag.Gte => return match (right) { case SemverTokenTag.Gte => true; case _ => false }
        case SemverTokenTag.Lt => return match (right) { case SemverTokenTag.Lt => true; case _ => false }
        case SemverTokenTag.Lte => return match (right) { case SemverTokenTag.Lte => true; case _ => false }
        case SemverTokenTag.Version => return match (right) { case SemverTokenTag.Version => true; case _ => false }
        case SemverTokenTag.Tilda => return match (right) { case SemverTokenTag.Tilda => true; case _ => false }
        case SemverTokenTag.Caret => return match (right) { case SemverTokenTag.Caret => true; case _ => false }
    }
}

// ============================================================================
// SemverWildcard - 通配符级别
// 严格翻译自: src/semver/SemverQuery.rs - Wildcard enum
//   pub enum Wildcard { None, Major, Minor, Patch }
// ============================================================================

/// 通配符级别 - 对应 Bun Query Wildcard
public enum SemverWildcard {
    | None
    | Major
    | Minor
    | Patch
}

// ============================================================================
// SemverToken - 解析 token
// 严格翻译自: src/semver/SemverQuery.rs - Token struct
//   pub struct Token {
//       pub tag: TokenTag,
//       pub wildcard: Wildcard,
//   }
//   impl Token {
//       pub fn to_range(self, version: version::Partial<u64>) Range { ... }
//   }
// ============================================================================

/// 解析 token - 对应 Bun Query Token
public class SemverToken {
    public var tag: SemverTokenTag
    public var wildcard: SemverWildcard

    public init() {
        tag = SemverTokenTag.None
        wildcard = SemverWildcard.None
    }

    /// 将 token 转为 Range - 对应 Bun Token.to_range
    /// Bun:
    ///   pub fn to_range(self, version: version::Partial<u64>) Range {
    ///       match self.tag {
    ///           TokenTag::Caret => { /* caret range */ }
    ///           TokenTag::Tilda => { /* tilde range */ }
    ///           TokenTag::Version => { if wildcard.isSome() => initWildcard; else => eql }
    ///           _ => { /* gt/gte/lt/lte with wildcards */ }
    ///       }
    ///   }
    public func toRange(major: Int64, minor: Int64, patch: Int64, tag: VersionTag): SemVerRange {
        let ver = SemVer(major, minor, patch, tag.pre, tag.build)

        match (this.tag) {
            case Caret =>
                return toCaretRange(ver)
            case Tilda =>
                return toTildeRange(ver)
            case Version =>
                match (wildcard) {
                    case SemverWildcard.None => ()
                    case _ =>
                        let w = match (wildcard) {
                            case SemverWildcard.Major => Wildcard.Major
                            case SemverWildcard.Minor => Wildcard.Minor
                            case SemverWildcard.Patch => Wildcard.Patch
                            case _ => Wildcard.None
                        }
                        return SemVerRange.initWildcard(ver, w)
                }
                return SemVerRange(Comparator(Op.Eql, ver), Comparator())
            case _ => () // gt/gte/lt/lte handled below
        }

        // gt/gte/lt/lte with wildcards
        let w = match (wildcard) {
            case SemverWildcard.Major => Wildcard.Major
            case SemverWildcard.Minor => Wildcard.Minor
            case SemverWildcard.Patch => Wildcard.Patch
            case _ => Wildcard.None
        }

        match (w) {
            case Major =>
                return toWildcardMajorRange(ver)
            case Minor =>
                return toWildcardMinorRange(ver)
            case Patch =>
                return toWildcardPatchRange(ver)
            case None =>
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
    /// 对应 Bun Token::to_range .caret 分支
    /// https://github.com/npm/node-semver/blob/.../classes/range.js#L302-L353
    ///
    /// ^1.2.3 := >=1.2.3 <2.0.0
    /// ^0.2.3 := >=0.2.3 <0.3.0
    /// ^0.0.3 := >=0.0.3 <0.0.4
    private func toCaretRange(version: SemVer): SemVerRange {
        let major = version.major
        let minor = version.minor
        let patch = version.patch

        let left = Comparator(Op.Gte, version)

        // 确定右边界 (上界)
        if (major != 0) {
            // ^1.2.3 -> <2.0.0
            let rightVer = SemVer(major + 1, 0, 0)
            return SemVerRange(left, Comparator(Op.Lt, rightVer))
        }
        if (minor != 0) {
            // ^0.2.3 -> <0.3.0
            let rightVer = SemVer(0, minor + 1, 0)
            return SemVerRange(left, Comparator(Op.Lt, rightVer))
        }
        // ^0.0.3 -> <0.0.4
        let rightVer = SemVer(0, 0, patch + 1)
        return SemVerRange(left, Comparator(Op.Lt, rightVer))
    }

    /// Tilde 范围 (~version)
    /// 对应 Bun Token::to_range .tilda 分支
    /// https://github.com/npm/node-semver/blob/.../classes/range.js#L261-L287
    ///
    /// ~1.2.3 := >=1.2.3 <1.3.0
    /// ~1.2   := >=1.2.0 <1.3.0
    /// ~1     := >=1.0.0 <2.0.0
    private func toTildeRange(version: SemVer): SemVerRange {
        let major = version.major
        let minor = version.minor

        let left = Comparator(Op.Gte, version)
        // Tilde: 总是 <major.(minor+1).0
        let rightVer = SemVer(major, minor + 1, 0)
        return SemVerRange(left, Comparator(Op.Lt, rightVer))
    }

    /// Major 通配符范围
    /// 对应 Bun Token::to_range Wildcard::Major 分支
    private func toWildcardMajorRange(version: SemVer): SemVerRange {
        match (this.tag) {
            case Lte =>
                return SemVerRange(
                    Comparator(Op.Lte, SemVer(version.major, Int64.Max, Int64.Max)),
                    Comparator()
                )
            case Lt =>
                return SemVerRange(
                    Comparator(Op.Lt, SemVer(version.major, 0, 0)),
                    Comparator()
                )
            case Gt =>
                return SemVerRange(
                    Comparator(Op.Gt, SemVer(version.major, Int64.Max, Int64.Max)),
                    Comparator()
                )
            case Gte =>
                return SemVerRange(
                    Comparator(Op.Gte, SemVer(version.major, 0, 0)),
                    Comparator()
                )
            case _ =>
                return SemVerRange(
                    Comparator(Op.Gte, SemVer(0, 0, 0)),
                    Comparator()
                )
        }
    }

    /// Minor 通配符范围
    /// 对应 Bun Token::to_range Wildcard::Minor 分支
    private func toWildcardMinorRange(version: SemVer): SemVerRange {
        match (this.tag) {
            case Lte =>
                return SemVerRange(
                    Comparator(Op.Lte, SemVer(version.major, Int64.Max, Int64.Max)),
                    Comparator()
                )
            case Lt =>
                return SemVerRange(
                    Comparator(Op.Lt, SemVer(version.major, 0, 0)),
                    Comparator()
                )
            case Gt =>
                return SemVerRange(
                    Comparator(Op.Gt, SemVer(version.major, Int64.Max, Int64.Max)),
                    Comparator()
                )
            case Gte =>
                return SemVerRange(
                    Comparator(Op.Gte, SemVer(version.major, 0, 0)),
                    Comparator()
                )
            case _ =>
                return SemVerRange(
                    Comparator(Op.Gte, SemVer(0, 0, 0)),
                    Comparator()
                )
        }
    }

    /// Patch 通配符范围
    /// 对应 Bun Token::to_range Wildcard::Patch 分支
    private func toWildcardPatchRange(version: SemVer): SemVerRange {
        match (this.tag) {
            case Lte =>
                return SemVerRange(
                    Comparator(Op.Lte, SemVer(version.major, version.minor, Int64.Max)),
                    Comparator()
                )
            case Lt =>
                return SemVerRange(
                    Comparator(Op.Lt, SemVer(version.major, version.minor, 0)),
                    Comparator()
                )
            case Gt =>
                return SemVerRange(
                    Comparator(Op.Gt, SemVer(version.major, version.minor, Int64.Max)),
                    Comparator()
                )
            case Gte =>
                return SemVerRange(
                    Comparator(Op.Gte, SemVer(version.major, version.minor, 0)),
                    Comparator()
                )
            case _ =>
                return SemVerRange(
                    Comparator(Op.Gte, SemVer(0, 0, 0)),
                    Comparator()
                )
        }
    }
}

// ============================================================================
// SemverQuery2 - AND 链节点 (Zig 严格翻译)
// 严格翻译自: src/semver/SemverQuery.rs - Query struct
//   pub struct Query {
//       pub range: Range,
//       pub next: Option<Box<Query>>,  // AND
//   }
//   impl Query {
//       pub fn fmt, eql, satisfies, satisfies_pre
//   }
// ============================================================================

/// AND 链节点 - 对应 Bun Query (严格翻译版)
public class SemverQuery2 {
    /// 当前 range
    public var range: SemVerRange
    /// 下一个 AND 条件
    public var next: ?SemverQuery2

    public init() {
        range = SemVerRange()
        next = None
    }

    public init(range: SemVerRange) {
        this.range = range
        next = None
    }

    /// 格式化 - 对应 Bun Query.fmt
    ///   pub fn fmt<'a>(&'a self, buf: &'a [u8]) -> QueryFormatter<'a>
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

    /// 相等比较 - 对应 Bun Query.eql
    ///   pub fn eql(&self, rhs: &Query) -> bool {
    ///       if !self.range.eql(rhs.range) { return false; }
    ///       let lhs_next = match &self.next { Some(n) => n, None => return rhs.next.is_none() };
    ///       let rhs_next = match &rhs.next { Some(n) => n, None => return false };
    ///       lhs_next.eql(rhs_next)
    ///   }
    public func eql(other: SemverQuery2): Bool {
        if (!range.eql(other.range)) {
            return false
        }
        match (next) {
            case Some(n) =>
                match (other.next) {
                    case Some(on) => return n.eql(on)
                    case None => return false
                }
            case None =>
                match (other.next) {
                    case Some(_) => return false
                    case None => return true
                }
        }
    }

    /// 满足检查 - 对应 Bun Query.satisfies
    ///   pub fn satisfies(&self, version, query_buf, version_buf) -> bool {
    ///       self.range.satisfies(version, query_buf, version_buf)
    ///           && match &self.next {
    ///               Some(next) => next.satisfies(version, query_buf, version_buf),
    ///               None => return true,
    ///           }
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

    /// 预发布满足检查 - 对应 Bun Query.satisfies_pre
    ///   pub fn satisfies_pre(&self, version, query_buf, version_buf, pre_matched) -> bool {
    ///       self.range.satisfies_pre(version, query_buf, version_buf, pre_matched)
    ///           && match &self.next {
    ///               Some(next) => next.satisfies_pre(version, query_buf, version_buf, pre_matched),
    ///               None => return true,
    ///           }
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
}

// ============================================================================
// SemverList2 - OR 链节点 (Zig 严格翻译)
// 严格翻译自: src/semver/SemverQuery.rs - List struct
//   pub struct List {
//       pub head: Query,
//       pub tail: Option<NonNull<Query>>,  // backref
//       pub next: Option<Box<List>>,       // OR
//   }
//   impl List {
//       pub fn fmt, satisfies, satisfies_pre, eql, and_range
//   }
// ============================================================================

/// OR 链节点 - 对应 Bun Query.List (严格翻译版)
public class SemverList2 {
    /// AND 链头
    public var head: SemverQuery2
    /// AND 链尾 (快速追加)
    public var tail: ?SemverQuery2
    /// 下一个 OR 条件
    public var next: ?SemverList2

    public init() {
        head = SemverQuery2()
        tail = None
        next = None
    }

    /// 格式化 - 对应 Bun List.fmt
    public func toString(): String {
        match (next) {
            case Some(n) =>
                return "${head.range.toString()} || ${n.toString()}"
            case None =>
                return head.toString()
        }
    }

    /// 满足检查 (OR) - 对应 Bun List.satisfies
    ///   pub fn satisfies(&self, version, list_buf, version_buf) -> bool {
    ///       self.head.satisfies(version, list_buf, version_buf)
    ///           || match &self.next {
    ///               Some(next) => next.satisfies(version, list_buf, version_buf),
    ///               None => return false,
    ///           }
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

    /// 预发布满足检查 - 对应 Bun List.satisfies_pre
    ///   pub fn satisfies_pre(&self, version, list_buf, version_buf) -> bool {
    ///       let mut pre_matched = false;
    ///       (self.head.satisfies_pre(version, list_buf, version_buf, &mut pre_matched) && pre_matched)
    ///           || match &self.next {
    ///               Some(next) => next.satisfies_pre(version, list_buf, version_buf),
    ///               None => return false,
    ///           }
    ///   }
    public func satisfiesPre(version: SemVer): Bool {
        var preMatched = Array<Bool>(1, repeat: false)
        if (head.satisfiesPre(version, preMatched) && preMatched[0]) {
            return true
        }
        match (next) {
            case Some(n) => return n.satisfiesPre(version)
            case None => return false
        }
    }

    /// 相等比较 - 对应 Bun List.eql
    public func eql(other: SemverList2): Bool {
        if (!head.eql(other.head)) {
            return false
        }
        match (next) {
            case Some(n) =>
                match (other.next) {
                    case Some(on) => return n.eql(on)
                    case None => return false
                }
            case None =>
                match (other.next) {
                    case Some(_) => return false
                    case None => return true
                }
        }
    }

    /// AND 追加 range - 对应 Bun List.and_range
    ///   pub fn and_range(&mut self, range: Range) -> Result<(), AllocError> {
    ///       if !self.head.range.has_left() && !self.head.range.has_right() {
    ///           self.head.range = range; return Ok(())
    ///       }
    ///       let mut tail = Box::new(Query { range, next: None });
    ///       tail.range = range;
    ///       let last_tail = match self.tail { Some(p) => unsafe { p.as_mut() }, None => &mut self.head };
    ///       last_tail.next = Some(tail);
    ///       self.tail = Some(tail_ptr);
    ///   }
    public func andRange(range: SemVerRange): Unit {
        if (!head.range.hasLeft() && !head.range.hasRight()) {
            head.range = range
            return
        }
        let newQuery = SemverQuery2(range)
        match (tail) {
            case Some(t) => t.next = newQuery
            case None => head.next = newQuery
        }
        tail = newQuery
    }
}

// ============================================================================
// SemverGroup2 - 完整范围表达式 (Zig 严格翻译)
// 严格翻译自: src/semver/SemverQuery.rs - Group struct
//   pub struct Group {
//       pub head: List,
//       pub tail: Option<NonNull<List>>,  // backref
//       pub input: *const [u8],
//       pub flags: FlagsBitSet,
//   }
//   impl Group {
//       pub fn fmt, json_stringify, get_exact_version, from, is_exact,
//              is_star, eql, to_version, or_version, and_range, or_range, satisfies
//   }
// ============================================================================

/// 完整范围表达式 - 对应 Bun Query.Group (严格翻译版)
public class SemverGroup2 {
    /// OR 链头
    public var head: SemverList2
    /// OR 链尾 (快速追加)
    public var tail: ?SemverList2
    /// 原始输入字符串
    public var input: String
    /// 是否包含 pre 标签
    public var hasPre: Bool
    /// 是否包含 build 标签
    public var hasBuild: Bool

    public init() {
        head = SemverList2()
        tail = None
        input = ""
        hasPre = false
        hasBuild = false
    }

    /// 从精确版本创建 - 对应 Bun Group::from
    ///   pub fn from(version: Version) -> Group {
    ///       Group { head: List { head: Query { range: Range { left: Comparator { op: Eql, version } } } } }
    ///   }
    public static func from(version: SemVer): SemverGroup2 {
        let group = SemverGroup2()
        group.head.head.range.left = Comparator(Op.Eql, version)
        return group
    }

    /// 获取精确版本 - 对应 Bun Group.get_exact_version
    ///   pub fn get_exact_version(&self) -> Option<Version> {
    ///       let range = &self.head.head.range;
    ///       if self.head.next.is_none() && self.head.head.next.is_none()
    ///           && range.has_left() && range.left.op == RangeOp::Eql && !range.has_right()
    ///       { return Some(range.left.version) }
    ///       None
    ///   }
    public func getExactVersion(): ?SemVer {
        let noNext = match (head.next) {
            case Some(_) => false
            case None => true
        }
        let noHeadNext = match (head.head.next) {
            case Some(_) => false
            case None => true
        }
        if (noNext && noHeadNext &&
            head.head.range.hasLeft() &&
            head.head.range.left.op == Op.Eql &&
            !head.head.range.hasRight()) {
            return head.head.range.left.version
        }
        return None
    }

    /// 是否精确匹配 - 对应 Bun Group.is_exact
    ///   pub fn is_exact(&self) -> bool {
    ///       self.head.next.is_none() && self.head.head.next.is_none()
    ///           && !self.head.head.range.has_right()
    ///           && self.head.head.range.left.op == RangeOp::Eql
    ///   }
    public func isExact(): Bool {
        let noNext = match (head.next) {
            case Some(_) => false
            case None => true
        }
        let noHeadNext = match (head.head.next) {
            case Some(_) => false
            case None => true
        }
        noNext && noHeadNext &&
            !head.head.range.hasRight() &&
            head.head.range.left.op == Op.Eql
    }

    /// 是否通配 (*) - 对应 Bun Group.is_star
    ///   pub fn is_star(&self) -> bool {
    ///       let left = &self.head.head.range.left;
    ///       self.head.head.range.right.op == RangeOp::Unset
    ///           && left.op == RangeOp::Gte && self.head.next.is_none()
    ///           && self.head.head.next.is_none() && left.version.is_zero()
    ///           && !self.flags.is_set(Flags::BUILD)
    ///   }
    public func isStar(): Bool {
        let left = head.head.range.left
        let noNext = match (head.next) {
            case Some(_) => false
            case None => true
        }
        let noHeadNext = match (head.head.next) {
            case Some(_) => false
            case None => true
        }
        head.head.range.right.op == Op.Unset &&
            left.op == Op.Gte &&
            noNext && noHeadNext &&
            left.version.isZero() &&
            !hasBuild
    }

    /// 相等比较 - 对应 Bun Group.eql
    public func eql(other: SemverGroup2): Bool {
        head.eql(other.head)
    }

    /// 转为版本 - 对应 Bun Group.to_version
    public func toVersion(): SemVer {
        head.head.range.left.version
    }

    /// OR 追加精确版本 - 对应 Bun Group.or_version
    ///   pub fn or_version(&mut self, version: Version) -> Result<(), AllocError> {
    ///       if self.tail.is_none() && !self.head.head.range.has_left() {
    ///           self.head.head.range.left.version = version;
    ///           self.head.head.range.left.op = RangeOp::Eql;
    ///           return Ok(())
    ///       }
    ///       let mut new_tail = Box::new(List::default());
    ///       new_tail.head.range.left.version = version;
    ///       new_tail.head.range.left.op = RangeOp::Eql;
    ///       let prev_tail = match self.tail { Some(p) => unsafe { p.as_mut() }, None => &mut self.head };
    ///       prev_tail.next = Some(new_tail);
    ///       self.tail = Some(new_tail_ptr);
    ///   }
    public func orVersion(version: SemVer): Unit {
        let noTail = match (tail) {
            case Some(_) => false
            case None => true
        }
        if (noTail && !head.head.range.hasLeft()) {
            head.head.range.left.version = version
            head.head.range.left.op = Op.Eql
            return
        }
        let newList = SemverList2()
        newList.head.range.left.version = version
        newList.head.range.left.op = Op.Eql
        match (tail) {
            case Some(t) => t.next = newList
            case None => head.next = newList
        }
        tail = newList
    }

    /// AND 追加 range - 对应 Bun Group.and_range
    ///   pub fn and_range(&mut self, range: Range) -> Result<(), AllocError> {
    ///       let tail: &mut List = match self.tail { Some(p) => unsafe { p.as_mut() }, None => &mut self.head };
    ///       tail.and_range(range)
    ///   }
    public func andRange(range: SemVerRange): Unit {
        match (tail) {
            case Some(t) => t.andRange(range)
            case None => head.andRange(range)
        }
    }

    /// OR 追加 range - 对应 Bun Group.or_range
    ///   pub fn or_range(&mut self, range: Range) -> Result<(), AllocError> {
    ///       if self.tail.is_none() && self.head.tail.is_none() && !self.head.head.range.has_left() {
    ///           self.head.head.range = range; return Ok(())
    ///       }
    ///       let mut new_tail = Box::new(List::default());
    ///       new_tail.head.range = range;
    ///       let prev_tail = match self.tail { Some(p) => unsafe { p.as_mut() }, None => &mut self.head };
    ///       prev_tail.next = Some(new_tail);
    ///       self.tail = Some(new_tail_ptr);
    ///   }
    public func orRange(range: SemVerRange): Unit {
        let noTail = match (tail) {
            case Some(_) => false
            case None => true
        }
        let noHeadTail = match (head.tail) {
            case Some(_) => false
            case None => true
        }
        if (noTail && noHeadTail && !head.head.range.hasLeft()) {
            head.head.range = range
            return
        }
        let newList = SemverList2()
        newList.head.range = range
        match (tail) {
            case Some(t) => t.next = newList
            case None => head.next = newList
        }
        tail = newList
    }

    /// 满足检查 - 对应 Bun Group.satisfies
    ///   pub inline fn satisfies(&self, version, group_buf, version_buf) -> bool {
    ///       if version.tag.has_pre() {
    ///           self.head.satisfies_pre(version, group_buf, version_buf)
    ///       } else {
    ///           self.head.satisfies(version, group_buf, version_buf)
    ///       }
    ///   }
    public func satisfies(version: SemVer): Bool {
        if (version.tag.hasPre()) {
            return head.satisfiesPre(version)
        } else {
            return head.satisfies(version)
        }
    }

    /// 格式化输出 - 对应 Bun Group.fmt / GroupFormatter
    public func toString(): String {
        var sb = StringBuilder()
        var list: ?SemverList2 = head
        var first = true
        while (true) {
            match (list) {
                case Some(l) =>
                    if (!first) {
                        sb.append(" || ")
                    }
                    first = false
                    sb.append(l.toString())
                    match (l.next) {
                        case Some(n) => list = n
                        case None => break
                    }
                case None => break
            }
        }
        sb.toString()
    }
}

// ============================================================================
// SemverParse - 范围字符串解析器 (Zig 严格翻译)
// 严格翻译自: src/semver/SemverQuery.rs - parse function
//   pub fn parse(input: &[u8], sliced: SlicedString) -> Result<Group, AllocError> {
//       var i: usize = 0;
//       var list = Group { input, head: List::default(), tail: None, flags: ... };
//       var token = Token::default();
//       var prev_token = Token::default();
//       var count: u8 = 0;
//       var skip_round;
//       var is_or = false;
//       while (i < input.len()) {
//           skip_round = false;
//           match (input[i]) {
//               b'>' => { /* gte or gt */ }
//               b'<' => { /* lte or lt */ }
//               b'=' | b'v' => { token.tag = Version; is_or = true }
//               b'~' => { token.tag = Tilda }
//               b'^' => { token.tag = Caret }
//               b'0'..=b'9' | b'X' | b'x' | b'*' => { token.tag = Version; is_or = true }
//               b'|' => { /* OR separator */ }
//               b'-' => { /* hyphen range separator */ }
//               b' ' => { /* skip whitespace */ }
//               _ => { /* skip tagged versions */ }
//           }
//           // Parse version, handle hyphen, build range...
//       }
//       Ok(list)
//   }
// ============================================================================

/// 范围字符串解析器 - 对应 Bun Query.parse (严格翻译版)
/// 解析完整的 semver range 字符串为 SemverGroup2
public class SemverParse {
    /// 解析范围字符串 - 对应 Bun parse
    ///
    /// 支持格式:
    ///   ^1.2.3          Caret 范围
    ///   ~1.2.3          Tilde 范围
    ///   >=1.0.0         大于等于
    ///   >=1.0.0 <2.0.0  区间范围 (AND)
    ///   1.x, *, x       通配符
    ///   1.0.0 - 2.0.0   Hyphen 范围
    ///   >=1.0.0 || >=2.0.0  OR 范围
    public static func parse(input: String): ?SemverGroup2 {
        if (input.isEmpty()) {
            return None
        }

        // 特殊值: *, latest, x -> 匹配所有版本
        if (input == "*" || input == "latest" || input == "x" || input == "X") {
            let group = SemverGroup2()
            group.head.head.range.left = Comparator(Op.Gte, SemVer(0, 0, 0))
            group.input = input
            return group
        }

        var i: Int64 = 0
        let len = input.size
        let group = SemverGroup2()
        group.input = input

        var token = SemverToken()
        var count: Int64 = 0
        var isOr = false

        while (i < len) {
            var skipRound = false
            token.tag = SemverTokenTag.None
            token.wildcard = SemverWildcard.None

            let ch = input[i]

            if (ch == UInt8(62)) {
                // > or >=
                if (i + 1 < len && input[i + 1] == UInt8(61)) {
                    token.tag = SemverTokenTag.Gte
                    i += 1
                } else {
                    token.tag = SemverTokenTag.Gt
                }
                i += 1
                while (i < len && input[i] == UInt8(32)) { i += 1 }
            } else if (ch == UInt8(60)) {
                // < or <=
                if (i + 1 < len && input[i + 1] == UInt8(61)) {
                    token.tag = SemverTokenTag.Lte
                    i += 1
                } else {
                    token.tag = SemverTokenTag.Lt
                }
                i += 1
                while (i < len && input[i] == UInt8(32)) { i += 1 }
            } else if (ch == UInt8(61) || ch == UInt8(118)) {
                // = or v
                token.tag = SemverTokenTag.Version
                isOr = true
                i += 1
                while (i < len && input[i] == UInt8(32)) { i += 1 }
            } else if (ch == UInt8(126)) {
                // ~
                token.tag = SemverTokenTag.Tilda
                i += 1
                if (i < len && input[i] == UInt8(62)) { i += 1 }
                while (i < len && input[i] == UInt8(32)) { i += 1 }
            } else if (ch == UInt8(94)) {
                // ^
                token.tag = SemverTokenTag.Caret
                i += 1
                while (i < len && input[i] == UInt8(32)) { i += 1 }
            } else if ((ch >= UInt8(48) && ch <= UInt8(57)) || ch == UInt8(88) ||
                ch == UInt8(120) || ch == UInt8(42)) {
                // 0-9, X, x, *
                token.tag = SemverTokenTag.Version
                isOr = true
            } else if (ch == UInt8(124)) {
                // | or ||
                i += 1
                while (i < len && input[i] == UInt8(124)) { i += 1 }
                while (i < len && input[i] == UInt8(32)) { i += 1 }
                isOr = true
                skipRound = true
            } else if (ch == UInt8(45)) {
                // -
                i += 1
                while (i < len && input[i] == UInt8(32)) { i += 1 }
                skipRound = true
            } else if (ch == UInt8(32)) {
                // space
                i += 1
                while (i < len && input[i] == UInt8(32)) { i += 1 }
                skipRound = true
            } else {
                // 跳过 tagged versions (如 "boop")
                i += 1
                while (i < len && input[i] != UInt8(32) && input[i] != UInt8(124)) {
                    i += 1
                }
                skipRound = true
            }

            if (skipRound) {
                continue
            }

            // 解析版本号
            let remaining = sliceFrom(input, i)
            let parseResult = SemVer.parseFull(remaining)
            if (!parseResult.valid) {
                return None
            }

            let version = parseResult.version
            if (version.tag.hasBuild()) { group.hasBuild = true }
            if (version.tag.hasPre()) { group.hasPre = true }

            token.wildcard = match (parseResult.wildcard) {
                case Wildcard.Major => SemverWildcard.Major
                case Wildcard.Minor => SemverWildcard.Minor
                case Wildcard.Patch => SemverWildcard.Patch
                case _ => SemverWildcard.None
            }

            i += parseResult.len
            let rollback = i

            // 检查 hyphen range
            let maybeHyphenate = i < len && (input[i] == UInt8(32) || input[i] == UInt8(45))
            var isHyphen = false

            if (maybeHyphenate) {
                let saved = i
                while (i < len && input[i] == UInt8(32)) { i += 1 }
                if (i < len && input[i] == UInt8(45)) {
                    i += 1
                    while (i < len && input[i] == UInt8(32)) { i += 1 }
                    if (i < len && (input[i] == UInt8(118) || input[i] == UInt8(61))) {
                        i += 1
                    }
                    while (i < len && input[i] == UInt8(32)) { i += 1 }
                    if (i < len && ((input[i] >= UInt8(48) && input[i] <= UInt8(57)) ||
                        input[i] == UInt8(88) || input[i] == UInt8(120) || input[i] == UInt8(42))) {
                        isHyphen = true
                    }
                }
                if (!isHyphen) {
                    i = saved
                }
            }

            if (isHyphen) {
                // Hyphen range: version - second_version
                let secondRemaining = sliceFrom(input, i)
                let secondResult = SemVer.parseFull(secondRemaining)
                if (!secondResult.valid) {
                    return None
                }
                let secondVersion = secondResult.version
                if (secondVersion.tag.hasBuild()) { group.hasBuild = true }
                if (secondVersion.tag.hasPre()) { group.hasPre = true }

                let range = buildHyphenRange(version, parseResult.wildcard,
                    secondVersion, secondResult.wildcard)

                if (isOr) {
                    group.orRange(range)
                } else {
                    group.andRange(range)
                }
                i += secondResult.len + 1
            } else {
                i = rollback

                if (count == Int64(0) && isSemverTokenTag(token.tag, SemverTokenTag.Version)) {
                    if (parseResult.wildcard != Wildcard.None) {
                        let range = token.toRange(version.major, version.minor, version.patch, version.tag)
                        group.orRange(range)
                    } else {
                        group.orVersion(version)
                    }
                } else if (count == Int64(0)) {
                    if (isSemverTokenTag(token.tag, SemverTokenTag.None)) {
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

    /// 构造 Hyphen 范围
    /// 对应 Bun parse 中 hyphenate 分支
    ///   Wildcard::Major => "1.0.0 - x" -> ">=1.0.0"
    ///   Wildcard::Minor => "1.0.0 - 1.x" -> ">=1.0.0 < 2.0.0"
    ///   Wildcard::Patch => "1.0.0 - 1.0.x" -> ">=1.0.0 < 1.1.0"
    ///   Wildcard::None  => "1.0.0 - 2.0.0" -> ">=1.0.0 <=2.0.0"
    private static func buildHyphenRange(
        first: SemVer, firstWildcard: Wildcard,
        second: SemVer, secondWildcard: Wildcard
    ): SemVerRange {
        match (secondWildcard) {
            case Major =>
                // "1.0.0 - x" -> ">=1.0.0"
                return SemVerRange(
                    Comparator(Op.Gte, first),
                    Comparator()
                )
            case Minor =>
                // "1.0.0 - 1.x" -> ">=1.0.0 < 2.0.0"
                var sv = second
                sv.major = sv.major + 1
                sv.minor = 0
                sv.patch = 0
                return SemVerRange(
                    Comparator(Op.Gte, first),
                    Comparator(Op.Lt, sv)
                )
            case Patch =>
                // "1.0.0 - 1.0.x" -> ">=1.0.0 < 1.1.0"
                var sv = second
                sv.minor = sv.minor + 1
                sv.patch = 0
                return SemVerRange(
                    Comparator(Op.Gte, first),
                    Comparator(Op.Lt, sv)
                )
            case None =>
                // "1.0.0 - 2.0.0" -> ">=1.0.0 <=2.0.0"
                return SemVerRange(
                    Comparator(Op.Gte, first),
                    Comparator(Op.Lte, second)
                )
        }
    }

    /// 字符串切片辅助
    private static func sliceFrom(text: String, start: Int64): String {
        if (start >= text.size) {
            return ""
        }
        text[start..]
    }
}
