// 严格翻译自: src/cli/filter_arg.zig
package bao_cli

import bao_core.*
import bao_collections.*
import bao_io.*
import bao_sys.*
import bao_parsers.*
import bao_path.Path as BaoPath
import bao_path.withoutTrailingSlash

// ============================================================================
// FilterArg — 工作区过滤参数
// 严格翻译自: src/cli/filter_arg.zig
// ============================================================================

/// 跳过列表: 要跳过的目录名
private let SKIP_LIST: Array<String> = [
    ".",
    "node_modules",
    ".git"
]

/// 检查路径是否在跳过列表中
private func globIgnoreFn(val_: String): Bool {
    if (val_.length == 0) {
        return false
    }
    for (skip in SKIP_LIST) {
        if (val_ == skip) {
            return true
        }
    }
    return false
}

/// 获取候选包模式
/// 对应 Bun: getCandidatePackagePatterns()
public func getCandidatePackagePatterns(
    allocator: Allocator,
    log: Log,
    outPatterns: ArrayList<String>,
    workdir: String,
    rootBuf: StringBuilder
): String {
    var currentDir = workdir

    while (true) {
        let jsonPath = BaoPath.join([currentDir, "package.json"])

        log.clear()

        let jsonSource = BaoFile.readAllText(jsonPath)
        match (jsonSource) {
            case Err(_) =>
                let parent = BaoPath.dirname(currentDir)
                if (parent == currentDir || parent.length == 0) {
                    break
                }
                currentDir = parent
                continue
            case Ok(content) =>
                let parser = JSONParser(content)
                let parseResult = parser.parse()
                match (parseResult.value) {
                    case Some(root) =>
                        // 检查 workspaces 属性
                        let wsProp = root.get("workspaces")
                        match (wsProp) {
                            case Some(workspacesProp) =>
                                // workspaces 可以是数组或对象 { packages: [...] }
                                if (workspacesProp.isArray()) {
                                    for (expr in workspacesProp.arrayValue) {
                                        if (expr.isString()) {
                                            match (expr.asString()) {
                                                case Some(patternExpr) =>
                                                    let pattern = patternExpr + "/package.json"
                                                    outPatterns.append(pattern)
                                                case None => ()
                                            }
                                        }
                                    }
                                } else if (workspacesProp.isObject()) {
                                    let packages = workspacesProp.get("packages")
                                    match (packages) {
                                        case Some(pkgs) =>
                                            if (pkgs.isArray()) {
                                                for (expr in pkgs.arrayValue) {
                                                    if (expr.isString()) {
                                                        match (expr.asString()) {
                                                            case Some(patternExpr) =>
                                                                let pattern = patternExpr + "/package.json"
                                                                outPatterns.append(pattern)
                                                            case None => ()
                                                        }
                                                    }
                                                }
                                            }
                                        case None => ()
                                    }
                                }
                                let parentTrimmed = withoutTrailingSlash(currentDir)
                                rootBuf.append(parentTrimmed)
                                return parentTrimmed
                            case None =>
                                let parent = BaoPath.dirname(currentDir)
                                if (parent == currentDir || parent.length == 0) {
                                    break
                                }
                                currentDir = parent
                                continue
                        }
                    case None =>
                        let parent = BaoPath.dirname(currentDir)
                        if (parent == currentDir || parent.length == 0) {
                            break
                        }
                        currentDir = parent
                        continue
                }
        }
    }

    // 未找到 workspace root, 使用通配符
    outPatterns.append("**/package.json")
    let rootDir = withoutTrailingSlash(workdir)
    rootBuf.append(rootDir)
    return rootDir
}

/// 过滤集合
/// 对应 Bun: FilterSet
public class FilterSet {
    private var allocator: Allocator

    /// 过滤模式列表
    public var filters: ArrayList<Pattern>

    /// 是否有名称过滤器
    public var hasNameFilters: Bool

    /// 是否匹配所有
    public var matchAll: Bool

    public init(allocator: Allocator, filters: ArrayList<String>, cwd: String) {
        this.allocator = allocator
        this.filters = ArrayList<Pattern>()
        this.hasNameFilters = false
        this.matchAll = false

        for (filterUtf8 in filters) {
            if (filterUtf8 == "*" || filterUtf8 == "**") {
                this.matchAll = true
                continue
            }

            let isPath = filterUtf8.size > 0 && filterUtf8[0] == UInt8(0x2E)
            if (isPath) {
                let resolved = BaoPath.resolve(cwd, filterUtf8).replace('\\', '/')
                this.filters.append(Pattern(resolved, PatternKind.path))
            } else {
                this.hasNameFilters = true
                this.filters.append(Pattern(filterUtf8, PatternKind.name))
            }
        }
    }

    /// 检查是否匹配
    public func matches(path: String, name: String): Bool {
        if (matchAll) {
            if (name.length > 0) {
                return true
            }
        }

        if (hasNameFilters) {
            return matchesPathName(path, name)
        }

        return matchesPath(path)
    }

    /// 匹配路径
    public func matchesPath(path: String): Bool {
        for (filter in filters) {
            if (GlobMatcher.matchPattern(filter.pattern, path)) {
                return true
            }
        }
        return false
    }

    /// 匹配路径或名称
    public func matchesPathName(path: String, name: String): Bool {
        for (filter in filters) {
            let target = match (filter.kind) {
                case PatternKind.name => name
                case PatternKind.path => path
            }
            if (GlobMatcher.matchPattern(filter.pattern, target)) {
                return true
            }
        }
        return false
    }

    /// 释放资源
    public func deinit(): Unit {
        // 路径类型的模式在仓颉中由 GC 管理, 无需手动释放
    }
}

/// 过滤模式类型
public enum PatternKind {
    | name
    | path  // 此模式在堆上分配, 需要释放

    public operator func ==(right: PatternKind): Bool {
        match (this) {
            case PatternKind.name => match (right) { case PatternKind.name => true; case _ => false }
            case PatternKind.path => match (right) { case PatternKind.path => true; case _ => false }
        }
    }
}

/// 过滤模式
public class Pattern {
    public var pattern: String
    public var kind: PatternKind

    public init(pattern: String, kind: PatternKind) {
        this.pattern = pattern
        this.kind = kind
    }
}

/// 包过滤器迭代器
/// 对应 Bun: PackageFilterIterator
public class PackageFilterIterator {
    private var patterns: ArrayList<String>
    private var patternIdx: Int64
    private var rootDir: String
    private var walker: ?GlobWalker
    private var valid: Bool
    private var allocator: Allocator

    public init(allocator: Allocator, patterns: ArrayList<String>, rootDir: String) {
        this.patterns = patterns
        this.patternIdx = 0
        this.rootDir = rootDir
        this.walker = None
        this.valid = false
        this.allocator = allocator
    }

    /// 释放资源
    public func deinit(): Unit {
        if (valid) {
            deinitWalker()
        }
    }

    /// 获取下一个匹配的路径
    public func next(): ?String {
        while (true) {
            if (!valid) {
                if (patternIdx < patterns.size) {
                    initWalker()
                    valid = true
                } else {
                    return None
                }
            }

            let nextPath = walkerNext()
            if (nextPath.isSome()) {
                return nextPath
            } else {
                valid = false
                patternIdx++
                deinitWalker()
            }
        }
        return None
    }

    /// 初始化 walker
    private func initWalker(): Unit {
        let pattern = patterns[patternIdx]
        walker = GlobWalker(rootDir, pattern, true, true, false, true, true)
        walker.getOrThrow().`init`()
    }

    /// 释放 walker
    private func deinitWalker(): Unit {
        if (walker.isSome()) {
            walker.getOrThrow().deinit()
            walker = None
        }
    }

    /// walker 的下一个结果
    private func walkerNext(): ?String {
        if (walker.isNone()) {
            return None
        }
        while (true) {
            let result = walker.getOrThrow().next()
            match (result) {
                case Some(matched) => return matched
                case None => return None
            }
        }
        return None
    }
}

/// Glob 遍历器 (本地占位实现)
/// 对应 Bun: bun.glob.BunGlobWalkerZ
/// 完整实现在 bao_runtime.shell.dispatch_tasks.GlobWalker
public class GlobWalker {
    private var rootDir: String
    private var pattern: String

    public init(rootDir: String, pattern: String, a: Bool, b: Bool, c: Bool, d: Bool, e: Bool) {
        this.rootDir = rootDir
        this.pattern = pattern
    }

    public func `init`(): Unit {}

    public func next(): ?String {
        return None
    }

    public func deinit(): Unit {}
}
