// 严格翻译自: src/cli/create_command.zig
// bao create - 从模板创建新项目
package bao_cli

import bao_core.*
import bao_collections.*
import bao_install.*
import bao_io.*
import bao_path.*
import bao_http.*
import bao_sys.*

// ============================================================================
// create 命令 - 对应 bun create <template> [dest]
// 严格翻译自: src/cli/create_command.zig (CreateCommand)
// 核心流程: 解析模板来源 -> 下载/复制 -> 更新 package.json -> 安装依赖 -> 初始化 git
// ============================================================================

/// 模板来源类型
/// 严格翻译自: src/cli/create_command.zig Example.Tag
public enum TemplateSource {
    | Unknown          // 未识别
    | Official         // 官方模板 (从 npm registry 下载)
    | GitHub           // GitHub 仓库 (github.com/user/repo)
    | LocalFolder      // 本地文件夹
    | JsLikeFile       // .jsx/.tsx 单文件模板
}

/// 模板信息
/// 严格翻译自: src/cli/create_command.zig Example struct
public class Template {
    /// 模板名称
    public var name: String
    /// 版本
    public var version: String
    /// 描述
    public var description: String
    /// 是否为本地模板
    public var isLocal: Bool

    public init(name: String) {
        this.name = name
        this.version = ""
        this.description = ""
        this.isLocal = false
    }
}

/// create 命令选项
/// 严格翻译自: src/cli/create_command.zig CreateOptions
public class CreateOptions {
    /// 模板名称/路径
    public var template: String
    /// 目标目录名
    public var destination: ?String
    /// 跳过安装 (--no-install)
    public var skipInstall: Bool
    /// 跳过 git 初始化 (--no-git)
    public var skipGit: Bool
    /// 跳过 package.json 转换 (--no-package-json)
    public var skipPackageJson: Bool
    /// 强制覆盖 (--force)
    public var overwrite: Bool
    /// 详细输出 (--verbose)
    public var verbose: Bool
    /// 完成后启动 (--open)
    public var open: Bool
    /// npm 客户端 (默认 bun)
    public var npmClient: String

    public init(template: String) {
        this.template = template
        this.destination = None
        this.skipInstall = false
        this.skipGit = false
        this.skipPackageJson = false
        this.overwrite = false
        this.verbose = false
        this.open = false
        this.npmClient = "bao"
    }
}

/// 文件冲突检查结果
public class ConflictResult {
    public var hasConflicts: Bool
    public var conflictingFiles: ArrayList<String>

    public init() {
        hasConflicts = false
        conflictingFiles = ArrayList<String>()
    }
}

/// create 命令执行器
/// 严格翻译自: src/cli/create_command.zig CreateCommand.exec
/// 核心流程:
///   1. 识别模板来源 (local/github/official/file)
///   2. 获取模板内容 (下载/复制)
///   3. 检查文件冲突
///   4. 解压/复制到目标目录
///   5. 处理 package.json (改名/删除构建工具)
///   6. 安装依赖
///   7. 初始化 git 仓库
public class CreateCommand {
    private var logger: Logger
    /// 不冲突的文件名
    private let neverConflict = ["README.md", "gitignore", ".gitignore", ".git/"]

    public init() {
        logger = Logger()
    }

    /// 执行 create 命令
    // 严格翻译自: src/cli/create_command.zig CreateCommand.exec
    public func execute(args: ArrayList<String>): Unit {
        if (args.size == 0) {
            // 无参数: 列出可用模板
            listTemplates()
            return
        }

        let opts = parseArgs(args)
        let dest = match (opts.destination) {
            case Some(d) => d
            case None => extractBasename(opts.template)
        }

        // 步骤1: 识别模板来源
        let source = identifyTemplateSource(opts.template)
        logger.info("Template source: ${source}")

        // 步骤2: 获取模板内容
        let templateDir = match (source) {
            case TemplateSource.LocalFolder => opts.template
            case TemplateSource.GitHub => fetchFromGitHub(opts.template)
            case TemplateSource.Official => fetchFromRegistry(opts.template)
            case TemplateSource.JsLikeFile => opts.template
            case TemplateSource.Unknown => {
                logger.error("Unknown template: ${opts.template}")
                return
            }
        }

        // 步骤3: 检查文件冲突
        if (!opts.overwrite) {
            let conflicts = checkConflicts(templateDir, dest)
            if (conflicts.hasConflicts) {
                logger.error("Directory '${dest}' contains files that could conflict:")
                for (file in conflicts.conflictingFiles) {
                    println("  ${file}")
                }
                logger.info("Use --force to overwrite")
                return
            }
        }

        // 步骤4: 复制/解压到目标目录
        let absDest = Path.resolve(dest)
        BaoFile.mkdir(absDest, true)
        copyTemplateFiles(templateDir, absDest)

        // 重命名 gitignore -> .gitignore
        renameGitignore(absDest)

        // 步骤5: 处理 package.json
        if (!opts.skipPackageJson) {
            processPackageJson(absDest, dest)
        }

        // 步骤6: 初始化 git
        if (!opts.skipGit) {
            initGit(absDest)
        }

        // 步骤7: 安装依赖
        if (!opts.skipInstall) {
            installDependencies(absDest)
        }

        // 步骤8: 打印完成信息
        printSuccessMessage(opts.template, dest)
    }

    /// 识别模板来源
    // 严格翻译自: src/cli/create_command.zig extractInfo
    private func identifyTemplateSource(input: String): TemplateSource {
        // 本地文件 .jsx/.tsx
        if (input.endsWith(".jsx") || input.endsWith(".tsx")) {
            if (BaoFile.exists(input)) {
                return TemplateSource.JsLikeFile
            }
        }

        // GitHub URL
        if (input.startsWith("github.com/") || input.startsWith("https://github.com/")) {
            return TemplateSource.GitHub
        }

        // GitHub 简写 user/repo
        let slashCount = input.countOf("/")
        if (slashCount == 1 && !input.startsWith("@") && !input.startsWith("/") && !input.startsWith(".")) {
            let slashIdx = input.indexOf("/")
            match (slashIdx) {
                case Some(idx) => {
                    if (idx > 0 && idx < input.length - 1) {
                        return TemplateSource.GitHub
                    }
                }
                case None => {}
            }
        }

        // 本地文件夹
        let localDirs = [
            input,
            Path.join([".bun-create", input]),
            Path.join([Sys.getHomeDir(), ".bun-create", input])
        ]
        for (dir in localDirs) {
            if (BaoFile.isDirectory(dir)) {
                return TemplateSource.LocalFolder
            }
        }

        // 环境变量 BUN_CREATE_DIR
        let createDir = Sys.getEnv("BUN_CREATE_DIR")
        match (createDir) {
            case Some(d) => {
                let dir = Path.join([d, input])
                if (BaoFile.isDirectory(dir)) {
                    return TemplateSource.LocalFolder
                }
            }
            case None => {}
        }

        // 默认为官方模板
        if (!input.startsWith("/") && !input.startsWith(".")) {
            return TemplateSource.Official
        }

        return TemplateSource.Unknown
    }

    /// 从 GitHub 仓库获取模板
    // 严格翻译自: src/cli/create_command.zig Example.fetchFromGitHub
    private func fetchFromGitHub(name: String): String {
        let client = HttpClient()
        let apiDomain = Sys.getEnv("GITHUB_API_DOMAIN") ?? "api.github.com"

        // 解析 owner/repo
        var repoName = name
        if (repoName.startsWith("github.com/")) {
            repoName = repoName.substring("github.com/".length)
        } else if (repoName.startsWith("https://github.com/")) {
            repoName = repoName.substring("https://github.com/".length)
        }

        // 限制为 owner/repo
        let slashIdx = repoName.indexOf("/")
        match (slashIdx) {
            case Some(idx) => {
                let afterSlash = repoName.substring(idx + 1)
                let secondSlash = afterSlash.indexOf("/")
                match (secondSlash) {
                    case Some(i) => repoName = repoName.substring(0, idx + 1 + i)
                    case None => {}
                }
            }
            case None => {}
        }

        // 下载 tarball
        let url = "https://${apiDomain}/repos/${repoName}/tarball"
        logger.info("Fetching from GitHub: ${repoName}")

        let tmpDir = Sys.getTempDir()
        let tmpName = "bao-create-${repoName.replace("/", "-")}"
        let extractDir = Path.join([tmpDir, tmpName])
        BaoFile.mkdir(extractDir, true)

        // 简化: 下载并解压
        let response = client.get(url)
        match (response) {
            case Some(resp) => {
                if (resp.statusCode == 200) {
                    let tarPath = Path.join([extractDir, "template.tar.gz"])
                    BaoFile.writeAllBytes(tarPath, resp.bodyBytes)
                    Process.spawn(["tar", "xzf", tarPath, "--strip-components=1"], extractDir)
                    return extractDir
                }
                logger.error("GitHub returned ${resp.statusCode}")
            }
            case None => logger.error("Could not fetch from GitHub")
        }
        return name
    }

    /// 从 npm registry 获取官方模板
    // 严格翻译自: src/cli/create_command.zig Example.fetch
    private func fetchFromRegistry(name: String): String {
        let client = HttpClient()
        let url = "https://registry.npmjs.org/@bao-examples/${name}/latest"

        let response = client.get(url)
        match (response) {
            case Some(resp) => {
                if (resp.statusCode == 200) {
                    // 解析 tarball URL
                    let parser = JsonParser()
                    let json = parser.parse(resp.body)
                    match (json) {
                        case Some(root) => {
                            // dist.tarball
                            match (JsonHelper.getString(JsonHelper.getField(root, "dist"), "tarball")) {
                                case Some(tarballUrl) => {
                                    // 下载 tarball
                                    let tarResp = client.get(tarballUrl)
                                    match (tarResp) {
                                        case Some(tarResp2) => {
                                            if (tarResp2.statusCode == 200) {
                                                let tmpDir = Sys.getTempDir()
                                                let extractDir = Path.join([tmpDir, "bao-create-${name}"])
                                                BaoFile.mkdir(extractDir, true)
                                                let tarPath = Path.join([extractDir, "template.tgz"])
                                                BaoFile.writeAllBytes(tarPath, tarResp2.bodyBytes)
                                                Process.spawn(["tar", "xzf", tarPath, "--strip-components=1"], extractDir)
                                                return extractDir
                                            }
                                        }
                                        case None => {}
                                    }
                                }
                                case None => {}
                            }
                        }
                        case None => {}
                    }
                } else if (resp.statusCode == 404) {
                    logger.error("Template '${name}' not found")
                }
            }
            case None => {}
        }
        return name
    }

    /// 检查文件冲突
    // 严格翻译自: src/cli/create_command.zig Archiver.getOverwritingFileList
    private func checkConflicts(templateDir: String, dest: String): ConflictResult {
        let result = ConflictResult()
        if (!BaoFile.isDirectory(dest)) {
            return result
        }

        let templateFiles = BaoFile.readdirRecursive(templateDir)
        for (file in templateFiles) {
            let targetPath = Path.join([dest, file])
            if (BaoFile.exists(targetPath)) {
                // 检查是否在 never_conflict 列表
                var skip = false
                for (nc in neverConflict) {
                    if (file == nc) { skip = true }
                }
                if (!skip) {
                    result.hasConflicts = true
                    result.conflictingFiles.append(file)
                }
            }
        }
        return result
    }

    /// 复制模板文件到目标目录
    // 严格翻译自: src/cli/create_command.zig FileCopier.copy
    private func copyTemplateFiles(src: String, dest: String): Unit {
        let files = BaoFile.readdirRecursive(src)
        for (file in files) {
            let srcPath = Path.join([src, file])
            let destPath = Path.join([dest, file])

            // 跳过 node_modules 和 .git
            if (file.startsWith("node_modules/") || file.startsWith(".git/")) {
                continue
            }
            // 跳过 lockfile
            if (file == "package-lock.json" || file == "yarn.lock" || file == "pnpm-lock.yaml") {
                continue
            }

            if (BaoFile.isDirectory(srcPath)) {
                BaoFile.mkdir(destPath, true)
            } else {
                BaoFile.copy(srcPath, destPath)
            }
        }
    }

    /// 重命名 gitignore -> .gitignore
    // 严格翻译自: src/cli/create_command.zig gitignore rename section
    private func renameGitignore(dest: String): Unit {
        let gitignorePath = Path.join([dest, "gitignore"])
        let dotGitignorePath = Path.join([dest, ".gitignore"])
        if (BaoFile.exists(gitignorePath)) {
            BaoFile.rename(gitignorePath, dotGitignorePath)
        }
        // 删除 .npmignore
        let npmignorePath = Path.join([dest, ".npmignore"])
        if (BaoFile.exists(npmignorePath)) {
            BaoFile.remove(npmignorePath)
        }
    }

    /// 处理 package.json
    // 严格翻译自: src/cli/create_command.zig process_package_json
    private func processPackageJson(dest: String, projectName: String): Unit {
        let pkgPath = Path.join([dest, "package.json"])
        let content = BaoFile.readAllText(pkgPath)
        match (content) {
            case Some(text) => {
                let parser = JsonParser()
                let json = parser.parse(text)
                match (json) {
                    case Some(root) => {
                        // 更新 name 字段为项目目录名
                        JsonHelper.setString(root, "name", projectName)

                        // 移除 "bun-create" 字段
                        JsonHelper.removeField(root, "bun-create")

                        // 清理不必要的脚本
                        cleanScripts(root)

                        // 写回
                        let newContent = JsonHelper.serialize(root)
                        BaoFile.writeAllText(pkgPath, newContent)
                    }
                    case None => {}
                }
            }
            case None => {}
        }
    }

    /// 清理脚本
    // 严格翻译自: src/cli/create_command.zig scripts pruning
    private func cleanScripts(root: JsonValue): Unit {
        match (JsonHelper.getField(root, "scripts")) {
            case Some(JsonValue.Object(scripts)) => {
                // 移除 react-scripts start, next dev 等不必要的脚本
                let keysToRemove = ArrayList<String>()
                for (key in scripts.keys()) {
                    match (scripts.get(key)) {
                        case Some(JsonValue.Str(value)) => {
                            if (value.contains("react-scripts start") ||
                                value.contains("next dev") ||
                                value.contains("react-scripts eject")) {
                                keysToRemove.append(key)
                            }
                        }
                        case _ => {}
                    }
                }
                for (key in keysToRemove) {
                    scripts.remove(key)
                }
            }
            case _ => {}
        }
    }

    /// 初始化 git
    // 严格翻译自: src/cli/create_command.zig GitHandler.run
    private func initGit(dir: String): Unit {
        // 查找 git
        let gitPath = Process.which("git")
        match (gitPath) {
            case Some(_) => {
                Process.spawn(["git", "init", "--quiet"], dir)
                Process.spawn(["git", "add", dir, "--ignore-errors"], dir)
                Process.spawn(["git", "commit", "-am", "Initial commit (via bao create)", "--quiet"], dir)
            }
            case None => logger.info("git not found, skipping repository initialization")
        }
    }

    /// 安装依赖
    // 严格翻译自: src/cli/create_command.zig npm_client install section
    private func installDependencies(dir: String): Unit {
        let baoExe = Sys.getExecutablePath()
        logger.info("$ bao install")
        let result = Process.spawn([baoExe, "install"], dir)
        match (result) {
            case Some(exitCode) => {
                if (exitCode != 0) {
                    logger.warn("Install exited with code ${exitCode}")
                }
            }
            case None => logger.warn("Could not run install")
        }
    }

    /// 打印成功消息
    // 严格翻译自: src/cli/create_command.zig success output section
    private func printSuccessMessage(template: String, dest: String): Unit {
        println("")
        logger.success("Created project successfully from '${template}'")
        println("")
        println("To get started, run:")
        println("  cd ${dest}")
        println("  bao dev")
        println("")
        println("Come hang out in bao's Discord: https://bao.dev/discord")
    }

    /// 列出可用模板
    // 严格翻译自: src/cli/create_command.zig CreateListExamplesCommand.exec
    private func listTemplates(): Unit {
        println("Welcome to Bao! Create a new project by pasting any of the following:")
        println("")

        let templates = [
            Template("react"),
            Template("next"),
            Template("express"),
            Template("happy"),
        ]
        for (t in templates) {
            println("  bao create ${t.name} ./${t.name}-app")
        }
        println("")
        println("You can also paste a GitHub repository:")
        println("  bao create user/repo my-app")
    }

    /// 解析命令行参数
    private func parseArgs(args: ArrayList<String>): CreateOptions {
        let opts = CreateOptions(args[0])
        var i = 0

        // 第一个非 flag 是模板名
        var foundTemplate = false
        while (i < args.size) {
            let arg = args[i]
            match (arg) {
                case "--no-install" => opts.skipInstall = true
                case "--no-git" => opts.skipGit = true
                case "--no-package-json" => opts.skipPackageJson = true
                case "--force" => opts.overwrite = true
                case "--verbose" => opts.verbose = true
                case "--open" => opts.open = true
                case "--help" | "-h" => {
                    printCreateHelp()
                    return opts
                }
                case _ => {
                    if (!arg.startsWith("-")) {
                        if (!foundTemplate) {
                            opts.template = arg
                            foundTemplate = true
                        } else {
                            opts.destination = Some(arg)
                        }
                    }
                }
            }
            i++
        }
        return opts
    }

    /// 从模板名提取基本名称
    private func extractBasename(template: String): String {
        let lastSlash = template.lastIndexOf("/")
        match (lastSlash) {
            case Some(idx) => return template.substring(idx + 1)
            case None => return template
        }
    }

    /// 打印 create 命令帮助
    private func printCreateHelp(): Unit {
        println("Usage: bao create <template> [destination] [options]")
        println("")
        println("Create a new project from a template")
        println("")
        println("Options:")
        println("  --no-install       Don't install dependencies")
        println("  --no-git           Don't create a git repository")
        println("  --no-package-json  Don't transform package.json")
        println("  --force            Overwrite existing files")
        println("  --verbose          Verbose output")
        println("  --open             Open in browser after creation")
        println("  --help, -h         Print this help")
        println("")
        println("Examples:")
        println("  bao create react my-app")
        println("  bao create user/repo my-project")
        println("  bao create ./local-template my-project")
    }
}
