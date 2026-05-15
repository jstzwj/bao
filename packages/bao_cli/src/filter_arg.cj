// 严格翻译自: src/cli/filter_arg.zig
package bao_cli

import bao_core.*

// ============================================================================
// FilterArg — 工作区过滤参数
// 严格翻译自: src/cli/filter_arg.zig
// ============================================================================

/// 跳过列表: 要跳过的目录名
private val SKIP_LIST: Array<String> = [
    ".",
    "node_modules",
    ".git",
]

/// 检查路径是否在跳过列表中
private func globIgnoreFn(val: String): Bool {
    if (val.length == 0) {
        return false
    }
    for (skip in SKIP_LIST) {
        if (val == skip) {
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
        let jsonPath = Path.join(currentDir, "package.json")

        log.clear()

        let jsonSource = BaoFile.readAllText(jsonPath)
        if (jsonSource == None) {
            let parent = Path.dirname(currentDir)
            if (parent == currentDir || parent.length == 0) {
                break
            }
            currentDir = parent
            continue
        }

        let json = JsonParser.parse(jsonSource!!)

        let workspacesProp = json?.getProperty("workspaces")
        if (workspacesProp == None) {
            let parent = Path.dirname(currentDir)
            if (parent == currentDir || parent.length == 0) {
                break
            }
            currentDir = parent
            continue
        }

        // workspaces 可以是数组或对象 { packages: [...] }
        var jsonArr: ?Array<JsonValue> = None
        if (workspacesProp!!.isArray()) {
            jsonArr = workspacesProp!!.asArray()
        } else if (workspacesProp!!.isObject()) {
            let packages = workspacesProp!!.getProperty("packages")
            if (packages != None && packages!!.isArray()) {
                jsonArr = packages!!.asArray()
            }
        }

        if (jsonArr != None) {
            for (expr in jsonArr!!) {
                if (expr.isString()) {
                    let patternExpr = expr.asString()
                    let pattern = patternExpr + "/package.json"
                    outPatterns.append(pattern)
                } else {
                    Output.prettyErrorLn("error: Failed to parse \"workspaces\" property: all items must be strings")
                    Global.exit(1)
                }
            }
        }

        let parentTrimmed = Strings.withoutTrailingSlash(currentDir)
        rootBuf.append(parentTrimmed)
        return parentTrimmed
    }

    // 未找到 workspace root, 使用通配符
    outPatterns.append("**/package.json")
    let rootDir = Strings.withoutTrailingSlash(workdir)
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

            let isPath = filterUtf8.length > 0 && filterUtf8[0] == '.'
            if (isPath) {
                let resolved = Path.resolve(cwd, filterUtf8).replace('\\', '/')
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
            if (Glob.match(filter.pattern, path).matches()) {
                return true
            }
        }
        return false
    }

    /// 匹配路径或名称
    public func matchesPathName(path: String, name: String): Bool {
        for (filter in filters) {
            let target = when (filter.kind) {
                case PatternKind.name => name
                case PatternKind.path => path
            }
            if (Glob.match(filter.pattern, target).matches()) {
                return true
            }
        }
        return false
    }

    /// 释放资源
    public func deinit(): Unit {
        // 路径类型的模式是在堆上分配的
        for (filter in filters) {
            if (filter.kind == PatternKind.path) {
                allocator.free(filter.pattern)
            }
        }
    }
}

/// 过滤模式类型
public enum PatternKind {
    | name
    | path  // 此模式在堆上分配, 需要释放
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

            let path = walkerNext()
            if (path != None) {
                return path
            } else {
                valid = false
                patternIdx++
                deinitWalker()
            }
        }
    }

    /// 初始化 walker
    private func initWalker(): Unit {
        let pattern = patterns[patternIdx.toInt()]
        walker = GlobWalker(rootDir, pattern, true, true, false, true, true)
        walker!!.init()
    }

    /// 释放 walker
    private func deinitWalker(): Unit {
        if (walker != None) {
            walker!!.deinit()
            walker = None
        }
    }

    /// walker 的下一个结果
    private func walkerNext(): ?String {
        if (walker == None) {
            return None
        }
        while (true) {
            let result = walker!!.next()
            when (result) {
                case Some(path) => return path
                case None => return None
            }
        }
    }
}
