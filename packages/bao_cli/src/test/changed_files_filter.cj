// 严格翻译自: src/cli/test/ChangedFilesFilter.zig
package bao_cli.test

import bao_core.*

// ============================================================================
// ChangedFilesFilter — 基于变更文件的测试过滤器
// 严格翻译自: src/cli/test/ChangedFilesFilter.zig
//
// 实现 bun test --changed (兼容 vitest):
// 1. 请求 git 获取相对于 HEAD 的变更文件集
// 2. 运行 bundler 扫描所有测试文件, 构建模块图
// 3. 从每个变更文件出发, 沿反向 import 边查找可达的测试入口点
// ============================================================================

/// 过滤结果
/// 对应 Bun: ChangedFilesFilter.Result
public class ChangedFilesResult {
    /// 过滤后的测试文件列表
    public var testFiles: ArrayList<PathString>

    /// git 报告的变更文件数
    public var changedCount: Int64

    /// 过滤前的测试文件总数
    public var totalTests: Int64

    /// 参与模块图的所有本地源文件的绝对路径
    public var moduleGraphFiles: ArrayList<String>

    public init() {
        testFiles = ArrayList<PathString>()
        changedCount = 0
        totalTests = 0
        moduleGraphFiles = ArrayList<String>()
    }
}

/// 基于变更文件的测试过滤器
/// 对应 Bun: ChangedFilesFilter
public class ChangedFilesFilter {
    /// 环境变量: 触发文件的临时路径
    public static let TRIGGER_FILE_ENV_VAR = "BUN_INTERNAL_TEST_CHANGED_TRIGGER_FILE"

    /// 过滤测试文件, 只保留模块图可达变更文件的条目
    /// 对应 Bun: ChangedFilesFilter.filter()
    public static func filter(
        ctx: CommandContext,
        vm: VirtualMachine,
        testFiles: ArrayList<PathString>,
        changedSince: String
    ): ChangedFilesResult {
        val result = ChangedFilesResult()
        val topLevelDir = vm.transpiler.fs.topLevelDir

        // 获取变更文件集
        var changedFiles = consumeWatchTrigger(ctx.allocator)
        if (changedFiles == None) {
            changedFiles = getChangedFiles(ctx.allocator, topLevelDir, changedSince)
        }
        val changed = changedFiles!!

        result.changedCount = changed.size
        result.totalTests = testFiles.size

        if (testFiles.size == 0) {
            return result
        }

        // 干净的工作树且非 watch 模式: 跳过模块图扫描
        if (changed.size == 0 && ctx.debug.hotReload != HotReloadKind.watch) {
            return result
        }

        // 构建模块图
        val scanTranspiler = Transpiler(ctx.allocator, ctx.log, ctx.args, vm.transpiler.env)
        scanTranspiler.options.target = TargetKind.bun
        scanTranspiler.options.packages = PackageKind.external
        scanTranspiler.options.ignoreModuleResolutionErrors = true
        scanTranspiler.options.outputDir = ""
        scanTranspiler.options.treeShaking = false
        scanTranspiler.configureLinker()
        scanTranspiler.configureDefines()

        val bundle = BundleV2.scanModuleGraphFromCLI(
            scanTranspiler,
            ctx.allocator,
            entryPoints
        )

        // 构建路径 -> 索引映射和反向 import 图
        val pathToIndex = HashMap<String, Int64>()
        val importers = ArrayList<ArrayList<Int64>>()
        val graphFiles = ArrayList<String>()

        for (idx in 0..bundle.sourceCount) {
            val source = bundle.getSource(idx)
            val pathText = source.path.text
            if (pathText.length == 0 || !source.path.isFile()) {
                continue
            }
            pathToIndex.put(pathText, idx)
            graphFiles.append(pathText)
        }

        for (idx in 0..bundle.sourceCount) {
            val records = bundle.getImportRecords(idx)
            for (record in records) {
                val dep = record.sourceIndex
                if (!dep.isValid() || dep.isRuntime()) {
                    continue
                }
                if (importers[dep.get()] == None) {
                    importers[dep.get()] = ArrayList<Int64>()
                }
                importers[dep.get()].append(idx)
            }
        }

        // 映射测试文件到 bundler 源索引
        val slotToSource = ArrayList<Int64>(testFiles.size)
        for (tf in testFiles) {
            slotToSource.append(pathToIndex.getOrDefault(tf.slice(), -1))
        }

        // 从变更文件反向 BFS
        val affected = DynamicBitSet(bundle.sourceCount)
        val queue = ArrayList<Int64>()

        for (changedPath in changed) {
            val idx = pathToIndex.get(changedPath)
            if (idx != None && !affected.isSet(idx!!)) {
                affected.set(idx!!)
                queue.append(idx!!)
            }
        }

        while (queue.size > 0) {
            val idx = queue.removeAt(0)
            if (importers[idx] != None) {
                for (importer in importers[idx]) {
                    if (!affected.isSet(importer)) {
                        affected.set(importer)
                        queue.append(importer)
                    }
                }
            }
        }

        // 过滤测试文件
        var write = 0
        for (i in 0..testFiles.size) {
            val tf = testFiles[i]
            val maybeSource = slotToSource[i]
            val keep = changed.contains(tf.slice()) ||
                       (maybeSource >= 0 && affected.isSet(maybeSource))

            if (keep) {
                result.testFiles.append(tf)
                write += 1
            }
        }

        result.moduleGraphFiles = graphFiles
        return result
    }

    /// 初始化 watch 触发器
    /// 对应 Bun: ChangedFilesFilter.initWatchTrigger()
    public static func initWatchTrigger(allocator: Allocator): Unit {
        if (Environment.isWindows) {
            return
        }

        val path = if (Env.get(TRIGGER_FILE_ENV_VAR) != None) {
            Env.get(TRIGGER_FILE_ENV_VAR)!!
        } else {
            val rng = Random()
            val tmpdir = FileSystem.RealFS.tmpdirPath()
            val fresh = "${Strings.withoutTrailingSlash(tmpdir)}/.bao-test-changed-${rng.nextUInt64()}.trigger"
            Env.set(TRIGGER_FILE_ENV_VAR, fresh)
            fresh
        }

        val set = StringSet(allocator)
        HotReloader.watchChangedPaths = set
        HotReloader.watchChangedTriggerFile = path
    }

    /// 消费 watch 触发器
    /// 对应 Bun: ChangedFilesFilter.consumeWatchTrigger()
    private static func consumeWatchTrigger(allocator: Allocator): ?StringSet {
        if (Environment.isWindows) {
            return None
        }

        val triggerPathRaw = Env.get(TRIGGER_FILE_ENV_VAR)
        if (triggerPathRaw == None || triggerPathRaw!!.length == 0) {
            return None
        }
        val triggerPath = triggerPathRaw!!

        val contents = BaoFile.readAllText(triggerPath)
        if (contents == None) {
            return None
        }

        // 消费一次: 删除触发文件
        BaoFile.remove(triggerPath)

        val set = StringSet(allocator)
        val lines = contents!!.split('\n')
        for (path in lines) {
            val trimmed = path.trim()
            if (trimmed.length == 0) {
                continue
            }
            if (!BaoFile.exists(trimmed)) {
                continue
            }
            set.insert(trimmed)
        }

        if (set.count() == 0) {
            return None
        }
        return set
    }

    /// 获取变更文件集
    /// 对应 Bun: ChangedFilesFilter.getChangedFiles()
    private static func getChangedFiles(allocator: Allocator, topLevelDir: String, since: String): StringSet {
        val gitPath = Which.which(Env.get("PATH") ?: "", topLevelDir, "git")
            ?: throw GitError.GitNotFound

        // 查找 git 仓库根目录
        val gitRootResult = runGit(allocator, gitPath, topLevelDir, ["rev-parse", "--show-toplevel"])
        if (!gitRootResult.ok) {
            throw GitError.GitFailed
        }
        val gitRoot = gitRootResult.stdout.trim()

        val set = StringSet(allocator)

        if (since.length == 0) {
            // 未提交 (未暂存 + 已暂存)
            val diff = runGit(allocator, gitPath, topLevelDir, ["diff", "--name-only", "HEAD", "--"])
            if (diff.ok) {
                appendPaths(set, gitRoot, diff.stdout)
            } else {
                // 无提交时的回退
                val unstaged = runGit(allocator, gitPath, topLevelDir, ["diff", "--name-only", "--"])
                if (unstaged.ok) {
                    appendPaths(set, gitRoot, unstaged.stdout)
                }
                val staged = runGit(allocator, gitPath, topLevelDir, ["diff", "--name-only", "--cached", "--"])
                if (staged.ok) {
                    appendPaths(set, gitRoot, staged.stdout)
                }
            }
        } else {
            val diff = runGit(allocator, gitPath, topLevelDir, ["diff", "--name-only", since, "--"])
            if (!diff.ok) {
                throw GitError.GitFailed
            }
            appendPaths(set, gitRoot, diff.stdout)
        }

        // 未跟踪文件始终被视为变更
        val untracked = runGit(allocator, gitPath, topLevelDir, ["ls-files", "--others", "--exclude-standard", "--full-name"])
        if (untracked.ok) {
            appendPaths(set, gitRoot, untracked.stdout)
        }

        return set
    }

    /// 执行 git 命令
    /// 对应 Bun: ChangedFilesFilter.runGit()
    private static func runGit(allocator: Allocator, gitPath: String, cwd: String, args: ArrayList<String>): GitResult {
        val allArgs = ArrayList<String>()
        allArgs.append(gitPath)
        allArgs.append("-c")
        allArgs.append("core.quotePath=off")
        for (arg in args) {
            allArgs.append(arg)
        }

        val proc = Sys.spawnSyncArgs(allArgs, cwd, Stdio.buffer, Stdio.buffer, Stdio.ignore)
        when (proc) {
            case Some(result) => {
                return GitResult(
                    result.isOK(),
                    false,
                    result.stdout ?: "",
                    result.stderr ?: ""
                )
            }
            case None => {
                return GitResult(false, true, "", "")
            }
        }
    }

    /// 解析 git 输出中的路径并加入集合
    /// 对应 Bun: ChangedFilesFilter.appendPaths()
    private static func appendPaths(set: StringSet, gitRoot: String, stdout: String): Unit {
        val lines = stdout.split('\n')
        for (line in lines) {
            val rel = line.trim(' ', '\t', '\r')
            if (rel.length == 0) {
                continue
            }
            val abs = Path.join(gitRoot, rel)
            if (!BaoFile.exists(abs)) {
                continue
            }
            set.insert(abs)
        }
    }
}

/// Git 执行结果
public class GitResult {
    public var ok: Bool
    public var spawnFailed: Bool
    public var stdout: String
    public var stderr: String

    public init(ok: Bool, spawnFailed: Bool, stdout: String, stderr: String) {
        this.ok = ok
        this.spawnFailed = spawnFailed
        this.stdout = stdout
        this.stderr = stderr
    }
}

/// Git 错误
public enum GitError {
    | GitNotFound
    | GitFailed
}
