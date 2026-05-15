// bao_semver.version - 语义版本号解析、比较与工具函数
// 严格翻译自: src/semver/Version.zig + src/semver/semver.zig
// 对应 Bun 的 Version 实现，包括:
//   - SemVerVersion: struct 版本 (值语义，用于 operator 重载)
//   - operator 重载: <, >, <=, >=, ==, !=
//   - inc/dec: 版本号递增/递减
//   - clean: 清理版本字符串
//   - diff: 检测两个版本间的差异部分
//   - major/minor/patch: 提取各部分
//   - compareBuild: 含 build 元数据的比较
package bao_semver

import bao_core.*
import bao_collections.*

// ============================================================================
// SemVerVersion - 值类型语义版本号 (用于 operator 重载)
// 严格翻译自: src/semver/Version.zig - VersionType(u64)
//   pub fn VersionType(comptime IntType: type) type {
//       return extern struct {
//           major: IntType = 0, minor: IntType = 0, patch: IntType = 0,
//           tag: Tag = .{}, ...
//       }
//   }
//
// 仓颉使用 struct 实现值语义，支持 operator 重载
// 注意: SemVer (class) 已在 package.cj 中定义，此处 SemVerVersion (struct)
// 是其值类型镜像，用于需要值语义和操作符重载的场景
// ============================================================================

/// 值类型语义版本号 - 用于需要值语义和操作符重载的场景
/// 对应 Bun VersionType(u64)
public struct SemVerVersion {
    public var major: Int64
    public var minor: Int64
    public var patch: Int64
    public var pre: String
    public var build: String

    public init() {
        major = 0
        minor = 0
        patch = 0
        pre = ""
        build = ""
    }

    public init(major: Int64, minor: Int64, patch: Int64) {
        this.major = major
        this.minor = minor
        this.patch = patch
        pre = ""
        build = ""
    }

    public init(major: Int64, minor: Int64, patch: Int64, pre: String, build: String) {
        this.major = major
        this.minor = minor
        this.patch = patch
        this.pre = pre
        this.build = build
    }

    /// 从 SemVer (class) 构造
    public init(ver: SemVer) {
        major = ver.major
        minor = ver.minor
        patch = ver.patch
        pre = ver.tag.pre
        build = ver.tag.build
    }

    /// 转为 SemVer (class)
    public func toSemVer(): SemVer {
        SemVer(major, minor, patch, pre, build)
    }

    /// 是否有预发布标签
    public func hasPre(): Bool {
        pre.size > 0
    }

    /// 是否有构建标签
    public func hasBuild(): Bool {
        build.size > 0
    }

    /// 是否为零版本 - 对应 Bun Version.isZero
    public func isZero(): Bool {
        major == 0 && minor == 0 && patch == 0
    }

    // ========================================================================
    // operator 重载 - 版本比较
    // 严格翻译自 Bun Version.order / Version.eql
    //   pub fn order(lhs, rhs, lhs_buf, rhs_buf) Order {
    //       const order_without_tag = orderWithoutTag(lhs, rhs)
    //       if (order_without_tag != .eq) return order_without_tag
    //       return lhs.tag.order(rhs.tag, lhs_buf, rhs_buf)
    //   }
    // ========================================================================

    /// 核心比较函数 - 对应 Bun Version.order
    /// 返回: -1 (this < other), 0 (相等), 1 (this > other)
    public func compare(other: SemVerVersion): Int64 {
        // 先比较 major.minor.patch
        if (major < other.major) { return -1 }
        if (major > other.major) { return 1 }
        if (minor < other.minor) { return -1 }
        if (minor > other.minor) { return 1 }
        if (patch < other.patch) { return -1 }
        if (patch > other.patch) { return 1 }

        // pre 标签比较
        // 有 pre < 无 pre (1.0.0-alpha < 1.0.0)
        let thisHasPre = hasPre()
        let otherHasPre = other.hasPre()

        if (thisHasPre && !otherHasPre) { return -1 }
        if (!thisHasPre && otherHasPre) { return 1 }

        // 两个都有 pre -> 按 semver pre 比较规则
        if (thisHasPre && otherHasPre) {
            let preCmp = comparePreIdentifiers(pre, other.pre)
            if (preCmp != 0) { return preCmp }
        }

        // build 标签比较 (字典序)
        if (build < other.build) { return -1 }
        if (build > other.build) { return 1 }

        return 0
    }

    /// 不含 build 的比较 - 对应 Bun Version.orderWithoutBuild
    public func compareWithoutBuild(other: SemVerVersion): Int64 {
        if (major < other.major) { return -1 }
        if (major > other.major) { return 1 }
        if (minor < other.minor) { return -1 }
        if (minor > other.minor) { return 1 }
        if (patch < other.patch) { return -1 }
        if (patch > other.patch) { return 1 }

        let thisHasPre = hasPre()
        let otherHasPre = other.hasPre()

        if (thisHasPre && !otherHasPre) { return -1 }
        if (!thisHasPre && otherHasPre) { return 1 }

        if (thisHasPre && otherHasPre) {
            return comparePreIdentifiers(pre, other.pre)
        }

        return 0
    }

    /// 不含 tag 的比较 - 对应 Bun Version.orderWithoutTag
    public func compareWithoutTag(other: SemVerVersion): Int64 {
        if (major < other.major) { return -1 }
        if (major > other.major) { return 1 }
        if (minor < other.minor) { return -1 }
        if (minor > other.minor) { return 1 }
        if (patch < other.patch) { return -1 }
        if (patch > other.patch) { return 1 }

        let thisHasPre = hasPre()
        let otherHasPre = other.hasPre()
        if (thisHasPre && !otherHasPre) { return -1 }
        if (!thisHasPre && otherHasPre) { return 1 }

        return 0
    }

    /// 相等比较 - 对应 Bun Version.eql
    public func eql(other: SemVerVersion): Bool {
        major == other.major && minor == other.minor && patch == other.patch &&
            pre == other.pre && build == other.build
    }

    // ========================================================================
    // operator 重载
    // ========================================================================

    /// 小于
    public operator func <(other: SemVerVersion): Bool {
        compare(other) < 0
    }

    /// 大于
    public operator func >(other: SemVerVersion): Bool {
        compare(other) > 0
    }

    /// 小于等于
    public operator func <=(other: SemVerVersion): Bool {
        compare(other) <= 0
    }

    /// 大于等于
    public operator func >=(other: SemVerVersion): Bool {
        compare(other) >= 0
    }

    /// 等于
    public operator func ==(other: SemVerVersion): Bool {
        eql(other)
    }

    /// 不等于
    public operator func !=(other: SemVerVersion): Bool {
        !eql(other)
    }

    // ========================================================================
    // 版本号递增/递减 - 对应 npm node-semver inc API
    // node-semver: semver.inc('1.2.3', 'major') => '2.0.0'
    //   semver.inc('1.2.3', 'minor') => '1.3.0'
    //   semver.inc('1.2.3', 'patch') => '1.2.4'
    //   semver.inc('1.2.3-alpha.1', 'minor') => '1.3.0'
    //   semver.inc('1.2.3', 'premajor') => '2.0.0-0'
    //   semver.inc('1.2.3', 'preminor') => '1.3.0-0'
    //   semver.inc('1.2.3', 'prepatch') => '1.2.4-0'
    //   semver.inc('1.2.3-alpha.1', 'prerelease') => '1.2.3-alpha.2'
    // ========================================================================

    /// 版本递增类型
    public enum ReleaseType {
        | Major      // 递增主版本号: 1.2.3 -> 2.0.0
        | Minor      // 递增次版本号: 1.2.3 -> 1.3.0
        | Patch      // 递增补丁号: 1.2.3 -> 1.2.4
        | PreMajor   // 递增主版本号并加预发布: 1.2.3 -> 2.0.0-0
        | PreMinor   // 递增次版本号并加预发布: 1.2.3 -> 1.3.0-0
        | PrePatch   // 递增补丁号并加预发布: 1.2.3 -> 1.2.4-0
        | PreRelease // 递增预发布号: 1.2.3-alpha.1 -> 1.2.3-alpha.2
    }

    /// 递增版本号 - 对应 npm semver.inc
    /// release: 递增类型
    /// preId: 预发布标识符 (如 "alpha", "beta")
    public func inc(release: ReleaseType, preId: String): ?SemVerVersion {
        match (release) {
            case Major =>
                Some(SemVerVersion(major + 1, 0, 0))
            case Minor =>
                Some(SemVerVersion(major, minor + 1, 0))
            case Patch =>
                Some(SemVerVersion(major, minor, patch + 1))
            case PreMajor =>
                let newPre = if (preId.size > 0) { "${preId}.0" } else { "0" }
                Some(SemVerVersion(major + 1, 0, 0, newPre, ""))
            case PreMinor =>
                let newPre = if (preId.size > 0) { "${preId}.0" } else { "0" }
                Some(SemVerVersion(major, minor + 1, 0, newPre, ""))
            case PrePatch =>
                let newPre = if (preId.size > 0) { "${preId}.0" } else { "0" }
                Some(SemVerVersion(major, minor, patch + 1, newPre, ""))
            case PreRelease =>
                // 如果当前有预发布标签，递增最后一个数字部分
                if (hasPre()) {
                    let parts = pre.split(".")
                    let lastIdx = parts.size - 1
                    if (lastIdx >= 0) {
                        let lastPart = parts[lastIdx]
                        let lastNum = tryParseInt64(lastPart)
                        match (lastNum) {
                            case Some(n) =>
                                // 递增数字部分
                                var newParts = ArrayList<String>()
                                for (i in 0..lastIdx) {
                                    newParts.append(parts[i])
                                }
                                newParts.append("${n + 1}")
                                var sb = StringBuilder()
                                for (i in 0..newParts.size) {
                                                    if (i > 0) { sb.append(".") }
                                    sb.append(newParts[i])
                                }
                                Some(SemVerVersion(major, minor, patch, sb.toString(), ""))
                            case None =>
                                // 最后部分不是数字，追加 ".0"
                                Some(SemVerVersion(major, minor, patch, "${pre}.0", ""))
                        }
                    } else {
                        None
                    }
                } else {
                    // 没有预发布标签，递增 patch 并加 "-0"
                    let newPre = if (preId.size > 0) { "${preId}.0" } else { "0" }
                    Some(SemVerVersion(major, minor, patch + 1, newPre, ""))
                }
        }
    }

    // ========================================================================
    // diff - 检测两个版本之间的差异部分
    // 严格翻译自: Version.whichVersionIsDifferent
    //   pub fn whichVersionIsDifferent(left, right, ...) ?ChangedVersion {
    //       if (left.major != right.major) return .major
    //       if (left.minor != right.minor) return .minor
    //       if (left.patch != right.patch) return .patch
    //       if (left.tag.hasPre() != right.tag.hasPre()) return .pre
    //       if (!left.tag.hasPre() and !right.tag.hasPre()) return null
    //       if (left.tag.orderPre(right.tag, ...) != .eq) return .pre
    //       if (left.tag.hasBuild() != right.tag.hasBuild()) return .build
    //       ...
    //   }
    // ========================================================================

    /// 差异类型 - 对应 Bun ChangedVersion
    public enum ChangedVersion {
        | Major   // 主版本号不同
        | Minor   // 次版本号不同
        | Patch   // 补丁号不同
        | Pre     // 预发布标签不同
        | Build   // 构建标签不同
        | None    // 完全相同
    }

    /// 检测与另一个版本的差异部分
    /// 对应 Bun Version.whichVersionIsDifferent
    public func diff(other: SemVerVersion): ChangedVersion {
        if (major != other.major) { return ChangedVersion.Major }
        if (minor != other.minor) { return ChangedVersion.Minor }
        if (patch != other.patch) { return ChangedVersion.Patch }

        if (hasPre() != other.hasPre()) { return ChangedVersion.Pre }
        if (!hasPre() && !other.hasPre()) {
            // 两个都没有 pre -> 检查 build
            if (hasBuild() != other.hasBuild()) { return ChangedVersion.Build }
            if (!hasBuild() && !other.hasBuild()) { return ChangedVersion.None }
            if (build != other.build) { return ChangedVersion.Build }
            return ChangedVersion.None
        }

        // 两个都有 pre
        let preCmp = comparePreIdentifiers(pre, other.pre)
        if (preCmp != 0) { return ChangedVersion.Pre }

        if (hasBuild() != other.hasBuild()) { return ChangedVersion.Build }
        if (!hasBuild() && !other.hasBuild()) { return ChangedVersion.None }
        if (build != other.build) { return ChangedVersion.Build }
        return ChangedVersion.None
    }

    /// 格式化输出 - 对应 Bun Version.Formatter.format
    public func toString(): String {
        var sb = StringBuilder()
        sb.append("${major}.${minor}.${patch}")
        if (hasPre()) {
            sb.append("-${pre}")
        }
        if (hasBuild()) {
            sb.append("+${build}")
        }
        return sb.toString()
    }

    /// 含 build 元数据的比较 - 对应 npm node-semver compareBuild
    /// 用于排序时考虑 build 元数据
    public static func compareBuild(a: SemVerVersion, b: SemVerVersion): Int64 {
        a.compare(b)
    }

    /// 解析版本号字符串
    public static func parse(text: String): ?SemVerVersion {
        let result = SemVer.parseFull(text)
        if (!result.valid) {
            return None
        }
        return Some(SemVerVersion(
            result.version.major,
            result.version.minor,
            result.version.patch,
            result.version.tag.pre,
            result.version.tag.build
        ))
    }

    /// 从任意字符串中提取版本号
    public static func coerce(text: String): ?SemVerVersion {
        let result = SemVer.coerce(text)
        match (result) {
            case Some(v) => return Some(SemVerVersion(v))
            case None => return None
        }
    }

    /// 清理版本字符串 - 对应 npm semver.clean
    /// 去除前导 v/= 和空白
    public static func clean(text: String): ?String {
        let result = SemVer.parseFull(text)
        if (!result.valid) {
            return None
        }
        return Some(result.version.toString())
    }

    // ========================================================================
    // 预发布标识符比较 - 对应 Bun Tag.orderPre
    // 按 '.' 分隔，逐段比较:
    //   - 都是数字 -> 数值比较
    //   - 一边数字一边字符串 -> 数字 < 字符串
    //   - 都是字符串 -> 字典序比较
    //   - 长度不同 -> 短的较小
    // ========================================================================
    private static func comparePreIdentifiers(lhsPre: String, rhsPre: String): Int64 {
        if (lhsPre.size == 0 && rhsPre.size == 0) { return 0 }
        if (lhsPre.size == 0) { return 1 }  // 无 pre > 有 pre
        if (rhsPre.size == 0) { return -1 }  // 有 pre < 无 pre

        let lhsParts = lhsPre.split(".")
        let rhsParts = rhsPre.split(".")
        let minLen = if (lhsParts.size < rhsParts.size) { lhsParts.size } else { rhsParts.size }

        for (i in 0..minLen) {
            let lhsPart = lhsParts[i]
            let rhsPart = rhsParts[i]
            let lhsNum = tryParseInt64(lhsPart)
            let rhsNum = tryParseInt64(rhsPart)

            // 数字标识符 < 字符串标识符
            if (lhsNum != None && rhsNum == None) { return -1 }
            if (lhsNum == None && rhsNum != None) { return 1 }
            if (lhsNum != None && rhsNum != None) {
                let ln = lhsNum.getOrThrow()
                let rn = rhsNum.getOrThrow()
                if (ln < rn) { return -1 }
                if (ln > rn) { return 1 }
                continue
            }

            // 都是字符串 - 字典序比较
            let cmp = lhsPart <=> rhsPart
            if (cmp != Ordering.equal) {
                return if (cmp == Ordering.less) { -1 } else { 1 }
            }
        }

        // 更多段 > 更少段
        if (lhsParts.size < rhsParts.size) { return -1 }
        if (lhsParts.size > rhsParts.size) { return 1 }
        return 0
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
// 版本号提取工具函数
// 严格翻译自 Bun 的外部 API (对应 npm node-semver 的 functions)
// ============================================================================

/// 提取主版本号 - 对应 npm semver.major('1.2.3') => 1
public func major(version: String): ?Int64 {
    let v = SemVerVersion.parse(version)
    match (v) {
        case Some(ver) => Some(ver.major)
        case None => None
    }
}

/// 提取次版本号 - 对应 npm semver.minor('1.2.3') => 2
public func minor(version: String): ?Int64 {
    let v = SemVerVersion.parse(version)
    match (v) {
        case Some(ver) => Some(ver.minor)
        case None => None
    }
}

/// 提取补丁号 - 对应 npm semver.patch('1.2.3') => 3
public func patch(version: String): ?Int64 {
    let v = SemVerVersion.parse(version)
    match (v) {
        case Some(ver) => Some(ver.patch)
        case None => None
    }
}

/// 比较两个版本字符串 - 对应 npm semver.compare('1.2.3', '2.0.0') => -1
/// 返回: -1 (a < b), 0 (a == b), 1 (a > b)
public func compareVersions(a: String, b: String): ?Int64 {
    let va = SemVerVersion.parse(a)
    let vb = SemVerVersion.parse(b)
    match (va) {
        case Some(v1) =>
            match (vb) {
                case Some(v2) => Some(v1.compare(v2))
                case None => None
            }
        case None => None
    }
}

/// 大于比较 - 对应 npm semver.gt('1.2.3', '2.0.0') => false
public func gt(a: String, b: String): ?Bool {
    let result = compareVersions(a, b)
    match (result) {
        case Some(r) => Some(r > 0)
        case None => None
    }
}

/// 大于等于 - 对应 npm semver.gte
public func gte(a: String, b: String): ?Bool {
    let result = compareVersions(a, b)
    match (result) {
        case Some(r) => Some(r >= 0)
        case None => None
    }
}

/// 小于比较 - 对应 npm semver.lt
public func lt(a: String, b: String): ?Bool {
    let result = compareVersions(a, b)
    match (result) {
        case Some(r) => Some(r < 0)
        case None => None
    }
}

/// 小于等于 - 对应 npm semver.lte
public func lte(a: String, b: String): ?Bool {
    let result = compareVersions(a, b)
    match (result) {
        case Some(r) => Some(r <= 0)
        case None => None
    }
}

/// 相等比较 - 对应 npm semver.eq
public func eq(a: String, b: String): ?Bool {
    let result = compareVersions(a, b)
    match (result) {
        case Some(r) => Some(r == 0)
        case None => None
    }
}

/// 不等于 - 对应 npm semver.neq
public func neq(a: String, b: String): ?Bool {
    let result = compareVersions(a, b)
    match (result) {
        case Some(r) => Some(r != 0)
        case None => None
    }
}

/// 版本比较排序 (用于数组排序) - 对应 npm semver.compare
/// 返回比较函数
public func sortVersions(versions: Array<String>): Array<String> {
    let arr = ArrayList<String>()
    for (i in 0..versions.size) {
        arr.append(versions[i])
    }
    arr.sortWith({ a, b ->
        let va = SemVerVersion.parse(a)
        let vb = SemVerVersion.parse(b)
        match (va) {
            case Some(v1) =>
                match (vb) {
                    case Some(v2) => v1.compare(v2) < 0
                    case None => false
                }
            case None => false
        }
    })
    return arr.toArray()
}

/// 降序排序
public func rsortVersions(versions: Array<String>): Array<String> {
    let arr = ArrayList<String>()
    for (i in 0..versions.size) {
        arr.append(versions[i])
    }
    arr.sortWith({ a, b ->
        let va = SemVerVersion.parse(a)
        let vb = SemVerVersion.parse(b)
        match (va) {
            case Some(v1) =>
                match (vb) {
                    case Some(v2) => v1.compare(v2) > 0
                    case None => false
                }
            case None => false
        }
    })
    return arr.toArray()
}
