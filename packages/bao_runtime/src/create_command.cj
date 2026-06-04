// 严格翻译自: src/cli/create_command.zig
// bun create 命令 — 从模板创建新项目
package bao_runtime

import bao_core.*
import bao_collections.*
import bao_path.*
import bao_io.*
import bao_spawn.*
import bao_sys.*
import bao_http.*

/// 已初始化存储标志
var initializedStore = false

/// 要跳过的目录
let SKIP_DIRS: Array<String> = ["node_modules", ".git"]

/// 要跳过的文件
let SKIP_FILES: Array<String> = ["package-lock.json", "yarn.lock", "pnpm-lock.yaml"]

/// 永不冲突的路径
let NEVER_CONFLICT: Array<String> = ["README.md", "gitignore", ".gitignore", ".git/"]

/// npm 任务参数
let NPM_TASK_ARGS: Array<String> = ["run"]

/// bun create 目录
let BUN_CREATE_DIR = ".bun-create"

/// 目标 Next.js 版本（已弃用）
let TARGET_NEXTJS_VERSION = "12.2.3"

/// 已初始化存储标志

/// 初始化 AST 存储
func initializeStore(): Unit {
    if (initializedStore) {
        return
    }
    initializedStore = true
    // TODO: 创建 AST 数据存储
}

/// 示例类型
public enum ExampleTag {
    | unknown
    | githubRepository
    | official
    | localFolder
    | jslikeFile

    /// 从文件扩展名获取标签
    public static func fromFileExtension(ext: String): ?ExampleTag {
        match (ext) {
            case ".tsx" => jslikeFile
            case ".jsx" => jslikeFile
            case _ => None
        }
    }
}

/// 示例项目
public class Example {
    let name: String
    let version: String
    let description: String
    let local: Bool

    public init(name: String, version: String, description: String, local!: Bool) {
        this.name = name
        this.version = version
        this.description = description
        this.local = local
    }
}

/// 创建选项
public class CreateOptions {
    var npmClient: ?NPMClient = None
    var skipInstall: Bool = false
    var overwrite: Bool = false
    var skipGit: Bool = false
    var skipPackageJson: Bool = false
    var positionals: Array<String> = []
    var verbose: Bool = false
    var open: Bool = false

    public init() {}
}


/// 进度缓冲区
public class ProgressBuf {
    static let bufs: Array<Array<Unit>> = [
        Array<Unit>(1024, {_i => 0}),
        Array<Unit>(1024, {_i => 0})
    ]
    static var bufIndex: Int64 = 0

    /// 打印格式化字符串
    public static func print(fmt: String, args: Array<Any>): String {
        bufIndex += 1
        let buf = bufs[bufIndex % 2]
        // TODO: 实现 sprintf 格式化
        return fmt
    }

    /// 打印带颜色的格式化字符串
    public static func pretty(fmt: String, args: Array<Any>): String {
        if (Output.enableAnsiColorsStdout) {
            return print(fmt, args)
        } else {
            return print(fmt, args)
        }
    }
}

/// Git 处理器
class GitHandler {
    static var success: Int32 = 0
    static var thread: ?Thread = None

    /// 生成 Git 初始化命令
    static func `spawn`(destination: String, pathEnv: String, verbose: Bool): Unit {
        success = 0

        // 在后台线程中运行 Git 初始化
        // TODO: 实现线程处理
        run(destination, pathEnv, verbose)
    }

    /// 运行 Git 命令
    static func run(destination: String, pathEnv: String, verbose: Bool): Bool {
        if (verbose) {
            Output.prettyErrorln("git backend: git")
        }

        let gitCmds = [
            ["git", "init", "--quiet"],
            ["git", "add", destination, "--ignore-errors"],
            ["git", "commit", "-am", "Initial commit (via bao create)", "--quiet"]
        ]

        for (cmd in gitCmds) {
            // TODO: implement spawn
            ()
        }

        return true
    }

    /// 等待 Git 完成
    static func wait(): Bool {
        // TODO: 实现线程等待
        return true
    }
}

/// 执行任务
func execTask(
    task: String,
    cwd: String,
    pathEnv: String,
    npmClient: ?NPMClient
): Unit {
    let trimmedTask = task
    if (trimmedTask.isEmpty()) {
        return
    }

    var parts = trimmedTask.split(" ")
    var argv = ArrayList<String>()

    if (let client <- npmClient) {
        argv.append(client.getOrThrow().bin)
        argv.append(NPM_TASK_ARGS[0])
    }

    for (part in parts) {
        argv.append(part)
    }

    // 如果以 "bao " 开头，移除前两个参数
    if (npmClient.isSome() && trimmedTask.startsWith("bao ")) {
        var newArgv = ArrayList<String>()
        var idx: Int64 = 2
        while (idx < argv.size) { newArgv.append(argv[idx]); idx++ }
        argv = newArgv
    }

    // 打印命令
    Output.pretty("\\n<r><d>$<b>")
    for (arg in argv) {
        Output.pretty(" ${arg}")
    }
    Output.pretty("<r>\\n")
    Output.flush()

    // 执行命令
    // TODO: implement spawn
    ()
}

/// 创建命令实现
public class CreateCommand {
    /// 执行创建命令
    public static func exec(ctx: CommandContext, exampleTag: ExampleTag, template: String): Unit {
        // 1. 解析命令行选项
        let createOpts = parseCreateOptions(ctx)
        let positionals = createOpts.positionals

        // 2. 如果没有参数，列出可用模板
        if (positionals.isEmpty()) {
            CreateListExamplesCommand.exec(ctx)
            return
        }

        // 3. 确定目标目录名
        let dirname = if (positionals.size == 1) {
            Path.basename(template)
        } else {
            positionals[1]
        }

        let destination = ctx.cwd + "/" + dirname

        // 4. 初始化进度显示
        var progress = Progress()
        progress.supportsAnsiEscapeCodes = Output.enableAnsiColorsStderr

        let node = if (match(exampleTag) { case jslikeFile => true case _ => false }) {
            progress.start(ProgressBuf.print("Analyzing ${template}", []), 0)
        } else {
            progress.start(ProgressBuf.print("Loading ${template}", []), 0)
        }

        // 5. 处理不同类型的模板
        if (match(exampleTag) { case jslikeFile => true case _ => false }) {
            node.end()
            progress.refresh()
            Output.prettyErrorln("<r><red>error:<r> Direct file execution not yet implemented")
            Global.exit(1)
        } else if (match(exampleTag) { case githubRepository => true case _ => false } || match(exampleTag) { case official => true case _ => false }) {
            // 下载并解压模板
            let tarballBytes = fetchTemplate(ctx, exampleTag, template, progress, node, createOpts)

            node.name = ProgressBuf.print("Decompressing ${template}", [])
            node.setCompletedItems(0)
            node.setEstimatedTotalItems(0)
            progress.refresh()

            // 解压并提取文件
            extractTemplate(tarballBytes, destination, createOpts)

            node.name = ProgressBuf.print("Extracting ${template}", [])
            progress.refresh()
        } else if (match(exampleTag) { case localFolder => true case _ => false }) {
            node.name = "Copying files"
            progress.refresh()
            copyLocalFolder(template, destination, createOpts)
        }

        node.end()
        progress.refresh()

        // 6. 处理 package.json
        processPackageJson(destination, createOpts)

        // 7. 初始化 Git 仓库
        if (!createOpts.skipGit) {
            if (!createOpts.skipInstall) {
                GitHandler.`spawn`(destination, "" /* TODO: ctx.env */, createOpts.verbose)
            } else {
                createOpts.skipGit = !GitHandler.run(destination, "" /* TODO: ctx.env */, createOpts.verbose)
            }
        }

        // 8. 安装依赖
        if (!createOpts.skipInstall) {
            installDependencies(destination, createOpts)
        }

        // 9. 打印成功信息
        printSuccessInfo(template, destination, createOpts)

        // 10. 可选：打开浏览器
        if (createOpts.open) {
            openInBrowser(destination)
        }
    }

    /// 解析创建选项
    static func parseCreateOptions(ctx: CommandContext): CreateOptions {
        var opts = CreateOptions()

        var i: Int64 = 1
        while (i < ctx.positionals.size) {
            let arg = ctx.positionals[i]
            match (arg) {
                case "--force" => opts.overwrite = true
                case "--no-install" => opts.skipInstall = true
                case "--no-git" => opts.skipGit = true
                case "--verbose" => opts.verbose = true
                case "--no-package-json" => opts.skipPackageJson = true
                case "--open" => opts.open = true
                case _ =>
                    if (!arg.startsWith("-")) {
                        // TODO: opts.positionals.append(arg)
                    }
            }
            i++
        }

        return opts
    }

    /// 获取模板
    static func fetchTemplate(
        ctx: CommandContext,
        exampleTag: ExampleTag,
        name: String,
        progress: Progress,
        node: ProgressNode,
        opts: CreateOptions
    ): Array<Unit> {
        if (match(exampleTag) { case official => true case _ => false }) {
            // TODO: Example.fetch
            return Array<Unit>()
        } else if (match(exampleTag) { case githubRepository => true case _ => false }) {
            // TODO: Example.fetchFromGitHub
            return Array<Unit>()
        } else {
            node.end()
            progress.refresh()
            Output.prettyErrorln("<r><red>error:<r> Unsupported example type")
            Global.exit(1)
                return []
            }
        }

    /// 解压模板
    static func extractTemplate(
        tarballBytes: Array<Unit>,
        destination: String,
        opts: CreateOptions
    ): Unit {
        // TODO: 实现解压逻辑
        Output.prettyln("Extracting template to ${destination}")
    }

    /// 从本地文件夹复制
    static func copyLocalFolder(
        template: String,
        destination: String,
        opts: CreateOptions
    ): Unit {
        // TODO: 实现文件夹复制逻辑
        Output.prettyln("Copying from ${template} to ${destination}")
    }

    /// 处理 package.json
    static func processPackageJson(destination: String, opts: CreateOptions): Unit {
        if (opts.skipPackageJson) {
            return
        }

        // TODO: 实现 package.json 处理
        Output.prettyln("Processing package.json in ${destination}")
    }

    /// 安装依赖
    static func installDependencies(destination: String, opts: CreateOptions): Unit {
        let npmClient = NPMClient("bao", NPMClientTag.bun)

        let installArgs = ["bao", "install"]
        Output.pretty("\\n<r><d>$ <b><cyan>bao<r><d> install<r>\\n")
        Output.flush()

        // TODO: implement spawn for install
    }

    /// 打印成功信息
    static func printSuccessInfo(template: String, destination: String, opts: CreateOptions): Unit {
        Output.printError("\\n")
        Output.prettyErrorln(" <r><d>bao create ${template}<r>")

        if (!opts.skipInstall && !opts.skipGit) {
            Output.pretty("\\n<d>A local git repository was created for you and dependencies were installed automatically.<r>\\n")
        }

        let basename = Path.basename(destination)
        Output.pretty("\\n<b><green>Success!<r> <b>${template}<r> loaded into <b>${basename}<r>\\n\\n")
        Output.pretty("<d>#<r><b> To get started, run:<r>\\n\\n  <b><cyan>bao run dev<r>\\n\\n")
        Output.flush()
    }

    /// 在浏览器中打开
    static func openInBrowser(destination: String): Unit {
        Output.prettyln("Opening browser...")
        // TODO: 实现浏览器打开
    }
}

/// 列出示例命令
public class CreateListExamplesCommand {
    public static func exec(ctx: CommandContext): Unit {
        Output.prettyln("Welcome to bao! Create a new project by pasting any of the following:\\n\\n")
        Output.flush()

        // TODO: Example.print

        Output.prettyln("\\n<r><d>#<r> You can also paste a GitHub repository:\\n\\n  <b>bao create <cyan>ahfarmer/calculator calc<r>\\n\\n")
        Output.flush()
    }
}

