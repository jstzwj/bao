// 严格翻译自: src/runtime/cli/test/ChangedFilesFilter.zig
// bun test --changed — 仅运行受变更文件影响的测试
//   使用 git 获取变更文件列表, 然后构建模块图, 反向遍历确定受影响的测试入口
package bao_runtime

import bao_core.*
import bao_collections.*
import bao_path.*
import bao_io.*
import bao_sys.*

// ============================================================================
// ChangedFilesFilterResult — 过滤结果
// 严格翻译自: ChangedFilesFilter.zig Result
// ============================================================================

/// 过滤结果
public class ChangedFilesFilterResult {
    /// 过滤后的测试文件列表
    public var testFiles: ArrayList<String>
    /// git 报告的变更文件数
    public var changedCount: Int64
    /// 过滤前的测试文件总数
    public var totalTests: Int64
    /// 模块图中所有本地源文件的绝对路径
    public var moduleGraphFiles: ArrayList<String>

    public init() {
        testFiles = ArrayList<String>()
        changedCount = 0
        totalTests = 0
        moduleGraphFiles = ArrayList<String>()
    }
}

// ============================================================================
// ChangedFilesFilter — 按变更过滤测试文件
// 严格翻译自: ChangedFilesFilter.zig filter()
// ============================================================================

/// 根据变更文件过滤测试列表
/// 只运行模块图能到达变更文件的测试入口点
public class ChangedFilesFilter {
    /// 环境变量名, 用于传递 watcher 触发文件路径
    public static let TRIGGER_FILE_ENV_VAR: String = "BUN_INTERNAL_TEST_CHANGED_TRIGGER_FILE"

    /// 过滤测试文件, 只保留受变更影响的测试
    public static func filter(
        testFiles: ArrayList<String>,
        changedSince: String
    ): ChangedFilesFilterResult {
        let result = ChangedFilesFilterResult()
        result.totalTests = testFiles.size

        // 1. 获取变更文件列表
        var changedFiles = HashSet<String>()
        if (changedSince.size > 0) {
            changedFiles = getChangedFiles(".", changedSince)
        } else {
            changedFiles = getChangedFiles(".", "")
        }

        result.changedCount = Int64(changedFiles.size)

        if (testFiles.size == 0) {
            return result
        }

        // 如果没有变更文件, 返回空列表
        if (changedFiles.size == 0) {
            return result
        }

        // 2. 构建模块图 (简化: 使用文件依赖关系)
        let graph = ModuleGraph(testFiles)

        // 3. 反向遍历: 从变更文件出发, 找到所有能到达的测试入口
        var affectedSources = HashSet<String>()
        var queue = ArrayList<String>()

        // 初始化: 将所有在模块图中的变更文件加入队列
        let allSources = graph.allSources()
        for (src in allSources) {
            if (changedFiles.contains(src)) {
                if (!affectedSources.contains(src)) {
                    affectedSources.put(src)
                    queue.append(src)
                }
            }
        }

        // BFS 反向遍历
        var qi: Int64 = 0
        while (qi < queue.size) {
            let current = queue[qi]
            qi++

            // 找到所有导入了 current 的文件
            let importers = graph.getImporters(current)
            for (importer in importers) {
                if (!affectedSources.contains(importer)) {
                    affectedSources.put(importer)
                    queue.append(importer)
                }
            }
        }

        // 4. 筛选: 测试文件在受影响集合中, 或本身就是变更文件
        for (tf in testFiles) {
            if (changedFiles.contains(tf) || affectedSources.contains(tf)) {
                result.testFiles.append(tf)
            }
        }

        return result
    }

    /// 初始化 watch 触发器
    public static func initWatchTrigger(): Unit {
        // TODO: implement with proper SysEnv/FileSystem APIs
    }

    /// 消费 watch 触发文件
    public static func consumeWatchTrigger(): ?HashSet<String> {
        // TODO: implement with proper SysEnv/File APIs
        return None
    }

    /// 使用 git 获取变更文件列表
    public static func getChangedFiles(topLevelDir: String, since: String): HashSet<String> {
        // TODO: implement with proper Process/SysEnv/SysFile APIs
        return HashSet<String>()
    }
}

// ============================================================================
// ModuleGraph — 简化的模块图
// 严格翻译自: ChangedFilesFilter.zig 中的模块图遍历
// ============================================================================

/// 模块依赖图 (简化实现)
/// 在完整实现中, 这会使用 bundler 的解析结果构建
private class ModuleGraph {
    /// 源文件到其导入的映射
    private var imports: HashMap<String, ArrayList<String>>
    /// 所有源文件列表
    private var sources: ArrayList<String>

    public init(testFiles: ArrayList<String>) {
        imports = HashMap<String, ArrayList<String>>()
        sources = ArrayList<String>()

        // 简化: 将测试文件作为源文件
        for (tf in testFiles) {
            sources.append(tf)
            if (!imports.contains(tf)) {
                imports.put(tf, ArrayList<String>())
            }
        }
    }

    /// 获取所有源文件
    public func allSources(): ArrayList<String> {
        return sources
    }

    /// 获取导入了指定文件的文件列表 (反向依赖)
    public func getImporters(path: String): ArrayList<String> {
        var result = ArrayList<String>()
        let entries = imports.allEntries()
        for (entry in entries) {
            let source = entry[0]
            let deps = entry[1]
            for (dep in deps) {
                if (dep == path) {
                    result.append(source)
                    break
                }
            }
        }
        return result
    }
}
