// bao_semver.range - 语义版本范围
// 严格翻译自: src/semver/SemverRange.zig
// 对应 Bun 的 SemverRange 实现，包括:
//   - Range: left + right 比较器
//   - Comparator: op + version
//   - Op: eql, lt, lte, gt, gte
//   - Range.satisfies: 版本是否满足范围
//   - Range.initWildcard: 通配符范围
//   - OR 范围: ">=1.0.0 || >=2.0.0"
//   - Hyphen 范围: "1.0.0 - 2.0.0"
//   - Caret 范围: ^1.2.3
//   - Tilde 范围: ~1.2.3
package bao_semver

import bao_core.*
import bao_collections.*

// ============================================================================
// Op - 比较操作符
// 严格翻译自: src/semver/SemverRange.zig - Op enum
//   pub const Op = enum(u8) {
//       unset = 0,
//       eql = 1,
//       lt = 3,
//       lte = 4,
//       gt = 5,
//       gte = 6,
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
//       pub fn eql, satisfies, fmt
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
// SemVerRange - 版本范围
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
//   - left <= version <= right (AND 关系)
//   - 多个 Range 用 || 分隔 (OR 关系)
//   例: "^1.2.3" -> left: >=1.2.3, right: <2.0.0
//       "~1.2.3" -> left: >=1.2.3, right: <1.3.0
//       ">=1.0.0 <2.0.0" -> left: >=1.0.0, right: <2.0.0
// ============================================================================

/// 版本范围 - 对应 Bun Range
/// 单个范围由 left 和 right 两个比较器组成
/// 多个范围通过 OR 组合
public class SemVerRange {
    /// 左比较器 (下界)
    public var left: Comparator
    /// 右比较器 (上界)
    public var right: Comparator
    /// OR 范围列表 (用于 ">=1.0.0 || >=2.0.0" 语法)
    public var orRanges: ArrayList<SemVerRange>

    public init() {
        left = Comparator()
        right = Comparator()
        orRanges = ArrayList<SemVerRange>()
    }

    public init(left: Comparator, right: Comparator) {
        this.left = left
        this.right = right
        this.orRanges = ArrayList<SemVerRange>()
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
    public func anyRangeSatisfies(): Bool {
        left.op == Op.Gte && left.version.isZero()
    }

    // ========================================================================
    // satisfies - 检查版本是否满足范围
    // 严格翻译自: Range.satisfies
    //   pub fn satisfies(range, version, range_buf, version_buf) bool {
    //       if (!range.hasLeft()) return true
    //       if (!range.left.satisfies(version)) return false
    //       if (has_right and !range.right.satisfies(version)) return false
    //       return true
    //   }
    // ========================================================================

    /// 检查版本是否满足范围 - 对应 Bun Range.satisfies
    /// 对于 OR 范围，只要满足其中任意一个即可
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
        let hasLeft = this.hasLeft()
        let hasRight = this.hasRight()

        if (!hasLeft) {
            return true
        }

        if (!left.satisfies(version)) {
            return false
        }

        if (hasRight && !right.satisfies(version)) {
            return false
        }

        return true
    }

    // ========================================================================
    // parse - 解析范围字符串
    // 支持的格式:
    //   ^1.2.3       - Caret 范围 (兼容版本)
    //   ~1.2.3       - Tilde 范围 (近似版本)
    //   >=1.0.0      - 大于等于
    //   >=1.0.0 <2.0.0 - 区间范围
    //   1.x, *, latest - 通配符
    //   1.0.0 - 2.0.0 - Hyphen 范围
    //   >=1.0.0 || >=2.0.0 - OR 范围
    // ========================================================================

    /// 解析范围字符串
    public static func parse(text: String): ?SemVerRange {
        let input = text.trim()
        if (input.size == 0) {
            return None
        }

        // 特殊值: *, latest, x -> 匹配所有版本
        if (input == "*" || input == "latest" || input == "x" || input == "X") {
            let range = SemVerRange()
            range.left = Comparator(Op.Gte, SemVer(0, 0, 0))
            return range
        }

        // OR 范围: ">=1.0.0 || >=2.0.0"
        // 按 || 分隔，分别解析
        if (input.contains("||")) {
            let parts = input.split("||")
            let mainRange = parseSingle(parts[0].trim())
            if (mainRange == None) {
                return None
            }
            let result = mainRange.getOrThrow()
            for (i in 1..parts.size) {
                let orRange = parseSingle(parts[i].trim())
                if (orRange != None) {
                    result.orRanges.append(orRange.getOrThrow())
                }
            }
            return result
        }

        return parseSingle(input)
    }

    /// 解析单个范围 (不含 ||)
    private static func parseSingle(input: String): ?SemVerRange {
        // Hyphen 范围: "1.0.0 - 2.0.0"
        // 格式: A - B 等价于 >=A <=B
        let hyphenMatch = tryParseHyphen(input)
        if (hyphenMatch != None) {
            return hyphenMatch
        }

        // Caret 范围: ^1.2.3
        if (input.size > 0 && input[0] == '^') {
            return parseCaret(input.substring(1))
        }

        // Tilde 范围: ~1.2.3
        if (input.size > 0 && input[0] == '~') {
            return parseTilde(input.substring(1))
        }

        // 区间范围: ">=1.0.0 <2.0.0" 或 ">=1.0.0"
        return parseComparators(input)
    }

    // ========================================================================
    // Caret 范围: ^1.2.3
    // 对应 Bun initWildcard -> caret 语义
    // ^1.2.3 := >=1.2.3 <2.0.0
    // ^0.2.3 := >=0.2.3 <0.3.0
    // ^0.0.3 := >=0.0.3 <0.0.4
    // ========================================================================

    private static func parseCaret(versionStr: String): ?SemVerRange {
        let ver = SemVer.parse(versionStr)
        if (ver == None) {
            return None
        }
        let v = ver.getOrThrow()
        let left = Comparator(Op.Gte, SemVer(v.major, v.minor, v.patch, v.tag.pre, v.tag.build))

        // Caret 上界计算:
        //   major > 0: <(major+1).0.0
        //   minor > 0: <0.(minor+1).0
        //   else:      <0.0.(patch+1)
        var upperMajor = v.major + 1
        var upperMinor = 0
        var upperPatch = 0
        if (v.major == 0) {
            upperMajor = 0
            upperMinor = v.minor + 1
            if (v.minor == 0) {
                upperMinor = 0
                upperPatch = v.patch + 1
            }
        }
        let right = Comparator(Op.Lt, SemVer(upperMajor, upperMinor, upperPatch))

        return SemVerRange(left, right)
    }

    // ========================================================================
    // Tilde 范围: ~1.2.3
    // 对应 Bun initWildcard -> tilde 语义
    // ~1.2.3 := >=1.2.3 <1.3.0
    // ~1.2   := >=1.2.0 <1.3.0
    // ~1     := >=1.0.0 <2.0.0
    // ========================================================================

    private static func parseTilde(versionStr: String): ?SemVerRange {
        let ver = SemVer.parse(versionStr)
        if (ver == None) {
            return None
        }
        let v = ver.getOrThrow()
        let left = Comparator(Op.Gte, SemVer(v.major, v.minor, v.patch, v.tag.pre, v.tag.build))

        // Tilde 上界: minor + 1
        let right = Comparator(Op.Lt, SemVer(v.major, v.minor + 1, 0))

        return SemVerRange(left, right)
    }

    // ========================================================================
    // 比较器范围: ">=1.0.0 <2.0.0"
    // 解析空格分隔的比较器对
    // ========================================================================

    private static func parseComparators(input: String): ?SemVerRange {
        // 按空格分隔比较器
        let parts = input.split(" ")
        var filteredParts = ArrayList<String>()
        for (i in 0..parts.size) {
            let p = parts[i].trim()
            if (p.size > 0) {
                filteredParts.append(p)
            }
        }

        if (filteredParts.size == 0) {
            return None
        }

        // 单个比较器
        if (filteredParts.size == 1) {
            let (op, ver) = parseComparator(filteredParts[0])
            if (ver == None) {
                return None
            }
            let v = ver.getOrThrow()
            let comp = Comparator(op, v)
            let range = SemVerRange()
            range.left = comp
            return range
        }

        // 两个比较器: ">=1.0.0 <2.0.0"
        if (filteredParts.size >= 2) {
            let (op1, ver1) = parseComparator(filteredParts[0])
            let (op2, ver2) = parseComparator(filteredParts[1])
            if (ver1 == None || ver2 == None) {
                return None
            }
            let left = Comparator(op1, ver1.getOrThrow())
            let right = Comparator(op2, ver2.getOrThrow())
            return SemVerRange(left, right)
        }

        return None
    }

    /// 解析单个比较器 (如 ">=1.0.0", "<2.0.0", "=1.0.0")
    private static func parseComparator(input: String): (Op, ?SemVer) {
        if (input.size == 0) {
            return (Op.Unset, None)
        }

        // 检查操作符前缀
        if (input.size >= 2) {
            let prefix = input.substring(0, 2)
            if (prefix == ">=") {
                let ver = SemVer.parse(input.substring(2))
                return (Op.Gte, ver)
            }
            if (prefix == "<=") {
                let ver = SemVer.parse(input.substring(2))
                return (Op.Lte, ver)
            }
            if (prefix == "==") {
                let ver = SemVer.parse(input.substring(2))
                return (Op.Eql, ver)
            }
        }

        let ch = input[0]
        if (ch == '>') {
            let ver = SemVer.parse(input.substring(1))
            return (Op.Gt, ver)
        }
        if (ch == '<') {
            let ver = SemVer.parse(input.substring(1))
            return (Op.Lt, ver)
        }
        if (ch == '=') {
            let ver = SemVer.parse(input.substring(1))
            return (Op.Eql, ver)
        }

        // 无操作符前缀 -> 精确匹配
        let ver = SemVer.parse(input)
        return (Op.Eql, ver)
    }

    // ========================================================================
    // Hyphen 范围: "1.0.0 - 2.0.0"
    // 等价于 >=1.0.0 <=2.0.0
    // ========================================================================

    private static func tryParseHyphen(input: String): ?SemVerRange {
        // 查找 " - " 分隔符 (空格-横线-空格)
        let idx = input.indexOf(" - ")
        if (idx < 0) {
            return None
        }

        // 确保 " - " 不是版本号中预发布标签的一部分 (以 - 开头的预发布不会被 " - " 匹配)
        let leftStr = input.substring(0, idx).trim()
        let rightStr = input.substring(idx + 3).trim()

        let leftVer = SemVer.parse(leftStr)
        let rightVer = SemVer.parse(rightStr)
        if (leftVer == None || rightVer == None) {
            return None
        }

        let left = Comparator(Op.Gte, leftVer.getOrThrow())
        let right = Comparator(Op.Lte, rightVer.getOrThrow())
        return SemVerRange(left, right)
    }

    // ========================================================================
    // initWildcard - 通配符范围
    // 严格翻译自: Range.initWildcard
    //   pub fn initWildcard(version: Version, wildcard: Query.Token.Wildcard) Range {
    //       switch (wildcard) {
    //           .none => { .left = .{ .op = .eql, .version = version } }
    //           .major => { .left = .{ .op = .gte, .version = .{} } }
    //           .minor => { .left = .{ .op = .lt, lhs }, .right = .{ .op = .gte, rhs } }
    //           .patch => { .left = .{ .op = .lt, lhs }, .right = .{ .op = .gte, rhs } }
    //       }
    //   }
    // ========================================================================

    /// 创建通配符范围 - 对应 Bun Range.initWildcard
    /// major: x 或 * -> >=0.0.0 (匹配所有)
    /// minor: 1.x -> >=1.0.0 <2.0.0
    /// patch: 1.2.x -> >=1.2.0 <1.3.0
    public static func initWildcard(version: SemVer, wildcardLevel: Int64): SemVerRange {
        match (wildcardLevel) {
            case 0 =>
                // 无通配符 -> 精确匹配
                SemVerRange(Comparator(Op.Eql, version), Comparator())
            case 1 =>
                // major 通配符 (x) -> >=0.0.0
                SemVerRange(Comparator(Op.Gte, SemVer(0, 0, 0)), Comparator())
            case 2 =>
                // minor 通配符 (1.x) -> >=1.0.0 <2.0.0
                let left = Comparator(Op.Lt, SemVer(version.major + 1, 0, 0))
                let right = Comparator(Op.Gte, SemVer(version.major, 0, 0))
                SemVerRange(left, right)
            case 3 =>
                // patch 通配符 (1.2.x) -> >=1.2.0 <1.3.0
                let left = Comparator(Op.Lt, SemVer(version.major, version.minor + 1, 0))
                let right = Comparator(Op.Gte, SemVer(version.major, version.minor, 0))
                SemVerRange(left, right)
            case _ =>
                SemVerRange(Comparator(Op.Gte, SemVer(0, 0, 0)), Comparator())
        }
    }

    /// 格式化输出 - 对应 Bun Range.format
    public override func toString(): String {
        if (!hasLeft() && !hasRight()) {
            return ""
        }
        if (!hasRight()) {
            return left.toString()
        }
        "${left.toString()} ${right.toString()}"
    }

    /// 范围交集 - 两个范围的交集
    /// 取更大的下界和更小的上界
    public static func intersection(a: SemVerRange, b: SemVerRange): ?SemVerRange {
        // 确定新下界: 取两个 left 中更严格的
        var newLeft = a.left
        if (b.hasLeft()) {
            if (!a.hasLeft() || b.left.version.compare(a.left.version) > 0) {
                newLeft = b.left
            } else if (a.left.version.compare(b.left.version) == 0) {
                // 同版本取更严格操作符
                if ((a.left.op == Op.Gt && b.left.op == Op.Gte) ||
                    (a.left.op == Op.Eql)) {
                    newLeft = a.left
                } else {
                    newLeft = b.left
                }
            }
        }

        // 确定新上界: 取两个 right 中更严格的
        var newRight = a.right
        if (b.hasRight()) {
            if (!a.hasRight() || b.right.version.compare(a.right.version) < 0) {
                newRight = b.right
            }
        }

        // 检查范围是否有效
        if (newLeft.op != Op.Unset && newRight.op != Op.Unset) {
            if (newLeft.version.compare(newRight.version) > 0) {
                return None  // 空集
            }
        }

        return SemVerRange(newLeft, newRight)
    }

    /// 范围并集 - 创建包含多个 OR 范围的范围
    public static func union(ranges: ArrayList<SemVerRange>): SemVerRange {
        if (ranges.size == 0) {
            return SemVerRange()
        }
        let result = ranges[0]
        for (i in 1..ranges.size) {
            result.orRanges.append(ranges[i])
        }
        return result
    }
}
