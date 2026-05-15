// bao_semver.query - Semver 查询/匹配引擎
// 严格翻译自: src/semver/SemverQuery.zig
// 对应 Bun 的 Query + Group 实现，包括:
//   - satisfies: 版本是否满足范围表达式
//   - intersects: 两个范围是否有交集
//   - subset: 一个范围是否是另一个的子集
//   - validRange: 验证范围字符串是否有效
//   - minSatisfying: 找到满足范围的最小版本
//   - maxSatisfying: 找到满足范围的最大版本
//   - outside: 检查版本是否在范围之外
package bao_semver

import bao_core.*
import bao_collections.*

// ============================================================================
// SemverQuery - Semver 查询引擎
// 严格翻译自: src/semver/SemverQuery.zig
//   pub fn parse(allocator, input, sliced) !Group {
//       // 解析范围字符串为 QueryGroup
//       // Group.satisfies 检查版本是否满足
//   }
//
//   pub const Group = struct {
//       head: List = List{},
//       tail: ?*List = null,
//       allocator: Allocator,
//       input: string = "",
//       flags: FlagsBitSet,
//       pub fn satisfies, getExactVersion, isExact, is*, from,
//              orVersion, andRange, orRange, deinit
//   }
// ============================================================================

/// Semver 查询引擎 - 对应 Bun Query + Group 的完整 API
/// 提供高级查询接口
public class SemverQuery {

    /// 解析范围字符串为 QueryGroup
    /// 对应 Bun: pub fn parse(allocator, input, sliced) !Group
    public static func parse(rangeStr: String): ?QueryGroup {
        RangeParser.parse(rangeStr)
    }

    // ========================================================================
    // satisfies - 检查版本是否满足范围
    // 对应 Bun Group.satisfies
    //   pub inline fn satisfies(group, version, ...) bool {
    //       return if (version.tag.hasPre())
    //           group.head.satisfiesPre(version, ...)
    //       else
    //           group.head.satisfies(version, ...)
    //   }
    // ========================================================================

    /// 检查版本是否满足范围表达式
    /// 对应 npm semver.satisfies('1.2.3', '^1.0.0') => true
    public static func satisfies(version: SemVer, range: QueryGroup): Bool {
        range.satisfies(version)
    }

    /// 便捷方法: 直接使用字符串
    public static func satisfies(version: SemVer, rangeStr: String): Bool {
        let group = parse(rangeStr)
        match (group) {
            case Some(g) => return g.satisfies(version)
            case None => return false
        }
    }

    /// 便捷方法: 使用字符串版本和范围
    public static func satisfies(versionStr: String, rangeStr: String): Bool {
        let ver = SemVer.parse(versionStr)
        match (ver) {
            case Some(v) => return satisfies(v, rangeStr)
            case None => return false
        }
    }

    /// 使用 SemVerVersion (值类型)
    public static func satisfies(version: SemVerVersion, range: QueryGroup): Bool {
        let semverObj = version.toSemVer()
        range.satisfies(semverObj)
    }

    /// 使用 SemVerVersion (值类型) + 范围字符串
    public static func satisfies(version: SemVerVersion, rangeStr: String): Bool {
        let semverObj = version.toSemVer()
        satisfies(semverObj, rangeStr)
    }

    // ========================================================================
    // validRange - 验证范围字符串是否有效
    // 对应 npm semver.validRange
    // ========================================================================

    /// 验证范围字符串是否有效
    /// 返回: 规范化的范围字符串，或 None 表示无效
    public static func validRange(rangeStr: String): ?String {
        let group = parse(rangeStr)
        match (group) {
            case Some(g) =>
                // 检查 group 是否有有效的 range
                if (!g.head.head.range.hasLeft() && g.head.next == None) {
                    // 空范围 -> 特殊处理
                    if (rangeStr.trim().size == 0) {
                        return Some("*")
                    }
                    return None
                }
                return Some(g.toString())
            case None => return None
        }
    }

    // ========================================================================
    // intersects - 检查两个范围是否有交集
    // 对应 npm node-semver intersects
    //   如果存在任意版本同时满足两个范围，则返回 true
    // ========================================================================

    /// 检查两个范围字符串是否有交集
    /// 对应 npm semver.intersects('>=1.0.0', '<2.0.0') => true
    /// 实现策略: 检查两个范围的边界是否重叠
    public static func intersects(range1: String, range2: String): Bool {
        let group1 = parse(range1)
        let group2 = parse(range2)

        match (group1) {
            case Some(g1) =>
                match (group2) {
                    case Some(g2) => return checkIntersects(g1, g2)
                    case None => return false
                }
            case None => return false
        }
    }

    /// 检查两个 QueryGroup 是否有交集
    private static func checkIntersects(g1: QueryGroup, g2: QueryGroup): Bool {
        // 如果任一范围是 * (匹配所有)，则一定有交集
        if (g1.isStar() || g2.isStar()) {
            return true
        }

        // 收集两个 group 的所有 OR 分支
        let ranges1 = collectRanges(g1)
        let ranges2 = collectRanges(g2)

        // 检查是否有任意两个 range 有交集
        for (i in 0..ranges1.size) {
            for (j in 0..ranges2.size) {
                if (rangeIntersects(ranges1[i], ranges2[j])) {
                    return true
                }
            }
        }
        return false
    }

    /// 收集 QueryGroup 中所有 OR 分支的范围
    private static func collectRanges(group: QueryGroup): ArrayList<SemVerRange> {
        let ranges = ArrayList<SemVerRange>()
        var list: ?QueryList = group.head
        while (true) {
            match (list) {
                case Some(l) =>
                    // 每个 List 的 head Query 可能包含 AND 链
                    // 我们需要收集完整的 AND 条件作为一个整体
                    ranges.append(l.head.range)
                    match (l.next) {
                        case Some(n) => list = n
                        case None => break
                    }
                case None => break
            }
        }
        return ranges
    }

    /// 检查两个 SemVerRange 是否有交集
    /// 两个范围有交集 = 存在版本同时满足两个范围
    private static func rangeIntersects(r1: SemVerRange, r2: SemVerRange): Bool {
        // 如果任一范围是通配 (*)，则一定有交集
        if (r1.anyRangeSatisfies() || r2.anyRangeSatisfies()) {
            return true
        }

        // 检查两个范围的上界和下界是否重叠
        // 方法: 检查 r1 的下界是否在 r2 的范围内，或 r2 的下界是否在 r1 的范围内
        let r1Left = r1.left
        let r1Right = r1.right
        let r2Left = r2.left
        let r2Right = r2.right

        // 获取两个范围的有效下界版本 (用于比较)
        let r1Lower = r1Left.version
        let r2Lower = r2Left.version

        // 简化: 检查 r1 的下界版本是否 <= r2 的上界版本 AND r2 的下界版本 <= r1 的上界版本
        if (r1.hasRight() && r2.hasRight()) {
            // 两个范围都有上下界
            // r1: [lower1, upper1), r2: [lower2, upper2)
            // 有交集 iff lower1 < upper2 AND lower2 < upper1
            let lower1LessThanUpper2 = r1Lower.compareWithoutTag(r2Right.version) < 0 ||
                (r1Lower.compareWithoutTag(r2Right.version) == 0 && r2Right.op == Op.Lte)
            let lower2LessThanUpper1 = r2Lower.compareWithoutTag(r1Right.version) < 0 ||
                (r2Lower.compareWithoutTag(r1Right.version) == 0 && r1Right.op == Op.Lte)
            return lower1LessThanUpper2 && lower2LessThanUpper1
        }

        if (r1.hasRight() && !r2.hasRight()) {
            // r1 有上界，r2 没有
            let lower2LessThanUpper1 = r2Lower.compareWithoutTag(r1Right.version) < 0 ||
                (r2Lower.compareWithoutTag(r1Right.version) == 0 && r1Right.op == Op.Lte)
            return lower2LessThanUpper1
        }

        if (!r1.hasRight() && r2.hasRight()) {
            // r1 没有上界，r2 有
            let lower1LessThanUpper2 = r1Lower.compareWithoutTag(r2Right.version) < 0 ||
                (r1Lower.compareWithoutTag(r2Right.version) == 0 && r2Right.op == Op.Lte)
            return lower1LessThanUpper2
        }

        // 两个都没有上界 -> 一定有交集 (都是 >= x 形式)
        return true
    }

    // ========================================================================
    // subset - 检查一个范围是否是另一个的子集
    // 对应 npm node-semver subset
    //   如果 range1 的所有满足版本都被 range2 包含，则返回 true
    // ========================================================================

    /// 检查 range1 是否是 range2 的子集
    /// 对应 npm semver.subset('>=1.0.0', '>=0.0.0') => true
    public static func subset(range1: String, range2: String): Bool {
        let group1 = parse(range1)
        let group2 = parse(range2)

        match (group1) {
            case Some(g1) =>
                match (group2) {
                    case Some(g2) => return checkSubset(g1, g2)
                    case None => return false
                }
            case None => return false
        }
    }

    /// 检查 g1 是否是 g2 的子集
    /// g1 的每个 OR 分支都必须被 g2 的至少一个 OR 分支包含
    private static func checkSubset(g1: QueryGroup, g2: QueryGroup): Bool {
        // * 是所有范围的子集 (除了更严格的范围)
        if (g1.isStar()) {
            return g2.isStar()
        }

        // 如果 g2 是 *，则 g1 一定是其子集
        if (g2.isStar()) {
            return true
        }

        let ranges1 = collectRanges(g1)
        let ranges2 = collectRanges(g2)

        // g1 的每个范围都必须是 g2 的某个范围的子集
        for (i in 0..ranges1.size) {
            var found = false
            for (j in 0..ranges2.size) {
                if (rangeSubset(ranges1[i], ranges2[j])) {
                    found = true
                    break
                }
            }
            if (!found) {
                return false
            }
        }
        return true
    }

    /// 检查 r1 是否是 r2 的子集
    private static func rangeSubset(r1: SemVerRange, r2: SemVerRange): Bool {
        // r1 是 r2 的子集 iff:
        //   r1 的下界 >= r2 的下界 AND r1 的上界 <= r2 的上界
        if (r1.anyRangeSatisfies()) {
            return r2.anyRangeSatisfies()
        }

        if (r2.anyRangeSatisfies()) {
            return true
        }

        let r1Lower = r1.left.version
        let r2Lower = r2.left.version
        let r1LeftOp = r1.left.op
        let r2LeftOp = r2.left.op

        // r1 的下界 >= r2 的下界
        var lowerOk = false
        let lowerCmp = r1Lower.compareWithoutTag(r2Lower)
        if (lowerCmp > 0) {
            lowerOk = true
        } else if (lowerCmp == 0) {
            // r1 的下界和 r2 相同
            // 如果 r2 是 >= 而 r1 是 >，则 r1 不一定是子集
            // 如果都是 >= 或都是 >，或 r2 更宽松
            lowerOk = r2LeftOp == Op.Gte || (r2LeftOp == Op.Gt && r1LeftOp == Op.Gt)
        }

        if (!lowerOk) {
            return false
        }

        // r1 的上界 <= r2 的上界
        if (!r1.hasRight()) {
            // r1 没有上界，r2 也必须没有上界
            return !r2.hasRight()
        }

        if (!r2.hasRight()) {
            // r2 没有上界，r1 有上界 -> r1 是子集
            return true
        }

        let r1Upper = r1.right.version
        let r2Upper = r2.right.version
        let r1RightOp = r1.right.op
        let r2RightOp = r2.right.op

        let upperCmp = r1Upper.compareWithoutTag(r2Upper)
        if (upperCmp < 0) {
            return true
        }
        if (upperCmp == 0) {
            // r1 的上界和 r2 相同
            return r2RightOp == Op.Lte || (r2RightOp == Op.Lt && r1RightOp == Op.Lt)
        }
        return false
    }

    // ========================================================================
    // minSatisfying / maxSatisfying
    // 对应 npm semver.minSatisfying / semver.maxSatisfying
    // ========================================================================

    /// 找到满足范围的最小版本
    /// 对应 npm semver.minSatisfying(['1.2.3', '2.0.0'], '>=1.0.0') => '1.2.3'
    public static func minSatisfying(versions: Array<String>, rangeStr: String): ?String {
        let group = parse(rangeStr)
        match (group) {
            case Some(g) =>
                var minVer: ?SemVer = None
                for (i in 0..versions.size) {
                    let ver = SemVer.parse(versions[i])
                    match (ver) {
                        case Some(v) =>
                            if (g.satisfies(v)) {
                                match (minVer) {
                                    case Some(mv) =>
                                        if (v.compare(mv) < 0) {
                                            minVer = Some(v)
                                        }
                                    case None =>
                                        minVer = Some(v)
                                }
                            }
                        case None => continue
                    }
                }
                match (minVer) {
                    case Some(v) => return Some(v.toString())
                    case None => return None
                }
            case None => return None
        }
    }

    /// 找到满足范围的最大版本
    /// 对应 npm semver.maxSatisfying(['1.2.3', '2.0.0'], '>=1.0.0') => '2.0.0'
    public static func maxSatisfying(versions: Array<String>, rangeStr: String): ?String {
        let group = parse(rangeStr)
        match (group) {
            case Some(g) =>
                var maxVer: ?SemVer = None
                for (i in 0..versions.size) {
                    let ver = SemVer.parse(versions[i])
                    match (ver) {
                        case Some(v) =>
                            if (g.satisfies(v)) {
                                match (maxVer) {
                                    case Some(mv) =>
                                        if (v.compare(mv) > 0) {
                                            maxVer = Some(v)
                                        }
                                    case None =>
                                        maxVer = Some(v)
                                }
                            }
                        case None => continue
                    }
                }
                match (maxVer) {
                    case Some(v) => return Some(v.toString())
                    case None => return None
                }
            case None => return None
        }
    }

    /// 找到满足范围的最小版本 (SemVerVersion 值类型)
    public static func minSatisfying(versions: Array<SemVerVersion>, rangeStr: String): ?SemVerVersion {
        let group = parse(rangeStr)
        match (group) {
            case Some(g) =>
                var minVer: ?SemVerVersion = None
                for (i in 0..versions.size) {
                    let v = versions[i]
                    let semverObj = v.toSemVer()
                    if (g.satisfies(semverObj)) {
                        match (minVer) {
                            case Some(mv) =>
                                if (v < mv) {
                                    minVer = Some(v)
                                }
                            case None =>
                                minVer = Some(v)
                        }
                    }
                }
                return minVer
            case None => return None
        }
    }

    /// 找到满足范围的最大版本 (SemVerVersion 值类型)
    public static func maxSatisfying(versions: Array<SemVerVersion>, rangeStr: String): ?SemVerVersion {
        let group = parse(rangeStr)
        match (group) {
            case Some(g) =>
                var maxVer: ?SemVerVersion = None
                for (i in 0..versions.size) {
                    let v = versions[i]
                    let semverObj = v.toSemVer()
                    if (g.satisfies(semverObj)) {
                        match (maxVer) {
                            case Some(mv) =>
                                if (v > mv) {
                                    maxVer = Some(v)
                                }
                            case None =>
                                maxVer = Some(v)
                        }
                    }
                }
                return maxVer
            case None => return None
        }
    }

    // ========================================================================
    // outside - 检查版本是否在范围之外
    // 对应 npm semver.outside
    // ========================================================================

    /// 检查版本是否在范围之外
    /// 对应 npm semver.outside('1.0.0', '>=2.0.0') => true
    public static func outside(versionStr: String, rangeStr: String): Bool {
        !satisfies(versionStr, rangeStr)
    }

    /// 检查版本是否在范围之外 (SemVer 对象)
    public static func outside(version: SemVer, rangeStr: String): Bool {
        !satisfies(version, rangeStr)
    }

    /// 检查版本是否在范围之外 (SemVerVersion 对象)
    public static func outside(version: SemVerVersion, rangeStr: String): Bool {
        !satisfies(version, rangeStr)
    }

    // ========================================================================
    // valid - 验证版本字符串是否有效
    // 对应 npm semver.valid
    // ========================================================================

    /// 验证版本字符串是否有效
    /// 返回: 规范化的版本字符串，或 None 表示无效
    public static func valid(versionStr: String): ?String {
        let result = SemVer.parseFull(versionStr)
        if (!result.valid) {
            return None
        }
        // 只有完整版本号 (3 部分) 才算有效
        if (result.wildcard != Wildcard.None) {
            return None
        }
        return Some(result.version.toString())
    }

    // ========================================================================
    // inc - 版本递增
    // 对应 npm semver.inc
    // ========================================================================

    /// 递增版本号
    /// 对应 npm semver.inc('1.2.3', 'major') => '2.0.0'
    public static func inc(versionStr: String, release: SemVerVersion.ReleaseType): ?String {
        inc(versionStr, release, "")
    }

    /// 递增版本号 (带预发布标识符)
    public static func inc(versionStr: String, release: SemVerVersion.ReleaseType, preId: String): ?String {
        let v = SemVerVersion.parse(versionStr)
        match (v) {
            case Some(ver) =>
                let result = ver.inc(release, preId)
                match (result) {
                    case Some(r) => return Some(r.toString())
                    case None => return None
                }
            case None => return None
        }
    }

    // ========================================================================
    // diff - 检测版本差异
    // 对应 npm semver.diff
    // ========================================================================

    /// 检测两个版本之间的差异类型
    /// 对应 npm semver.diff('1.2.3', '2.0.0') => 'major'
    public static func diff(v1: String, v2: String): ?SemVerVersion.ChangedVersion {
        let ver1 = SemVerVersion.parse(v1)
        let ver2 = SemVerVersion.parse(v2)
        match (ver1) {
            case Some(v1Obj) =>
                match (ver2) {
                    case Some(v2Obj) => return Some(v1Obj.diff(v2Obj))
                    case None => return None
                }
            case None => return None
        }
    }

    // ========================================================================
    // coerce - 从任意字符串提取版本号
    // 对应 npm semver.coerce
    // ========================================================================

    /// 从任意字符串中提取语义版本号
    /// 对应 npm semver.coerce('v2.0.0-beta') => '2.0.0-beta'
    public static func coerce(text: String): ?String {
        let result = SemVer.coerce(text)
        match (result) {
            case Some(v) => return Some(v.toString())
            case None => return None
        }
    }

    // ========================================================================
    // clean - 清理版本字符串
    // 对应 npm semver.clean
    // ========================================================================

    /// 清理版本字符串
    /// 对应 npm semver.clean(' =v1.2.3 ') => '1.2.3'
    public static func clean(versionStr: String): ?String {
        SemVerVersion.clean(versionStr)
    }

    // ========================================================================
    // compareBuild - 含 build 元数据的比较
    // 对应 npm semver.compareBuild
    // ========================================================================

    /// 含 build 元数据的比较
    /// 对应 npm semver.compareBuild('1.2.3', '1.2.3+build') => -1
    public static func compareBuild(a: String, b: String): ?Int64 {
        let va = SemVerVersion.parse(a)
        let vb = SemVerVersion.parse(b)
        match (va) {
            case Some(v1) =>
                match (vb) {
                    case Some(v2) => return Some(SemVerVersion.compareBuild(v1, v2))
                    case None => return None
                }
            case None => return None
        }
    }
}
