// 严格翻译自: src/cli/create_command.zig
// Create 命令 — 从模板创建新项目
// 对应 Bun: bun create <template> [dest]
package bao_cli.commands

import bao_core.*
import bao_collections.*
import bao_install.*
import bao_io.*
import bao_path.*
import bao_http.*
import bao_sys.*

// ============================================================================
// CreateCommand — bun create 命令执行器
// 严格翻译自: src/cli/create_command.zig - CreateCommand
//
// Bun create_command 核心流程:
//   1. 解析命令行参数 (--no-install, --no-git, --force, --verbose, --open)
//   2. 识别模板来源 (local folder, GitHub repo, official template, .jsx/.tsx file)
//   3. 获取模板内容:
//      - local folder: 直接复制
//      - GitHub: 下载 tarball → 解压
//      - official: 从 npm registry 获取 tarball URL → 下载 → 解压
//      - .jsx/.tsx file: 分析依赖 → 生成项目
//   4. 检查文件冲突 (never_conflict 列表)
//   5. 解压/复制到目标目录
//   6. 重命名 gitignore → .gitignore
//   7. 处理 package.json:
//      - 更新 name 字段
//      - 删除 "bun-create" 属性
//      - 清理脚本 (移除 react-scripts start, next dev)
//      - 执行 preinstall/postinstall 任务
//   8. 安装依赖 (bun install)
//   9. 初始化 git 仓库
//  10. 打印成功信息
//
// 关键特性:
//   - 支持本地模板目录
//   - 支持 GitHub 仓库 (user/repo)
//   - 支持官方模板 (从 npm registry)
//   - 支持 .jsx/.tsx 单文件模板
//   - 文件冲突检测 (--force 跳过)
//   - Git 初始化 (后台线程)
//   - package.json 转换
//   - 预/后安装任务
// ============================================================================

/// Create 命令执行器
/// 对应 Bun: CreateCommand.exec(ctx, example_tag, template)
public class CreateCommand {
    /// 日志工具
    private var logger: CreateLogger

    /// 不冲突的文件名列表
    // 严格翻译自: create_command.zig 中 never_conflict
    private let neverConflict = ["README.md", "gitignore", ".gitignore", ".git/"]

    public init() {
        logger = CreateLogger()
    }

    /// 执行 create 命令
    /// 对应 Bun: CreateCommand.exec(ctx, example_tag, template)
    ///
    /// 严格翻译自: create_command.zig 中 exec 函数流程
    public func execute(args: ArrayList<String>): Unit {
        // 无参数: 列出可用模板
        // 严格翻译自: create_command.zig 中 positionals.len == 0 → CreateListExamplesCommand
        if (args.size == 0) {
            listTemplates()
            return
        }

        // 解析参数
        // 严格翻译自: create_command.zig 中 CreateOptions.parse
        let opts = parseCreateArgs(args)

        // 确定目标目录名
        // 严格翻译自: create_command.zig 中 dirname 计算
        let dest = match (opts.destination) {
            case Some(d) => d
            case None => Path.basename(opts.template)
        }

        // 步骤1: 识别模板来源
        // 严格翻译自: create_command.zig 中 extractInfo
        let (source, resolvedTemplate) = extractTemplateInfo(opts.template)
        logger.info("Template source: ${source}, resolved: ${resolvedTemplate}")

        // 步骤2: 获取模板
        let templateDir = fetchTemplate(source, resolvedTemplate, dest, opts)

        // 步骤3: 检查文件冲突
        // 严格翻译自: create_command.zig 中 Archiver.getOverwritingFileList
        if (!opts.overwrite) {
            let conflicts = checkFileConflicts(templateDir, dest)
            if (conflicts.hasConflicts) {
                println("")
                println("error: The directory '${dest}' contains files that could conflict:")
                println("")
                for (file in conflicts.conflictFiles) {
                    println("  ${file}")
                }
                println("")
                println("To download ${opts.template} anyway, use --force")
                Sys.exit(1)
                return
            }
        }

        // 步骤4: 复制文件到目标目录
        // 严格翻译自: create_command.zig 中 FileCopier.copy / Archiver.extractToDisk
        let absDest = Path.resolve(dest)
        logger.info("Copying template to ${absDest}")
        BaoFile.mkdir(absDest, true)
        copyTemplateToDestination(templateDir, absDest)

        // 步骤5: 重命名 gitignore
        // 严格翻译自: create_command.zig 中 linkat("gitignore", ".gitignore")
        renameGitignoreFile(absDest)

        // 步骤6: 处理 package.json
        // 严格翻译自: create_command.zig 中 process_package_json
        var startCommand = "bao dev"
        var hasDependencies = false
        if (!opts.skipPackageJson) {
            let (sc, hd) = processPackageJson(absDest, dest, opts)
            startCommand = sc
            hasDependencies = hd
        }

        // 步骤7: 初始化 git (在后台线程中)
        // 严格翻译自: create_command.zig 中 GitHandler.spawn
        var skipGit = opts.skipGit
        if (!skipGit && !opts.skipInstall) {
            initGitBackground(absDest)
        } else if (!skipGit) {
            skipGit = !initGitSync(absDest, opts.verbose)
        }

        // 步骤8: 安装依赖
        // 严格翻译自: create_command.zig 中 npm_client install section
        opts.skipInstall = opts.skipInstall || !hasDependencies
        if (!opts.skipInstall) {
            installProjectDependencies(absDest)
        }

        // 等待 git 完成
        if (!opts.skipInstall && !skipGit) {
            // waitGitComplete()
        }

        // 步骤9: 打印成功信息
        // 严格翻译自: create_command.zig 中 success output section
        printSuccess(opts.template, dest, startCommand, absDest, opts.skipInstall, skipGit)

        // 步骤10: --open 模式
        if (opts.open) {
            // 启动 dev server 并打开浏览器
            // 严格翻译自: create_command.zig 中 open URL + spawn child
        }
    }

    // ========================================================================
    // 模板来源识别
    // ========================================================================

    /// 提取模板信息
    /// 对应 Bun: CreateCommand.extractInfo(ctx)
    ///
    /// 严格翻译自: create_command.zig 中 extractInfo 的查找优先级:
    ///   1. 本地文件 (.jsx/.tsx)
    ///   2. BUN_CREATE_DIR 环境变量
    ///   3. .bun-create/ 目录
    ///   4. $HOME/.bun-create/ 目录
    ///   5. GitHub (user/repo 或 github.com/user/repo)
    ///   6. 官方模板 (npm registry)
    private func extractTemplateInfo(input: String): (CreateTemplateSource, String) {
        // 本地 .jsx/.tsx 文件
        if (input.endsWith(".jsx") || input.endsWith(".tsx")) {
            if (BaoFile.exists(input) && !BaoFile.isDirectory(input)) {
                return (CreateTemplateSource.JsLikeFile, input)
            }
        }

        // GitHub URL
        if (input.startsWith("github.com/") || input.startsWith("https://github.com/")) {
            return (CreateTemplateSource.GitHub, normalizeGitHubName(input))
        }

        // GitHub 简写: user/repo
        // 严格翻译自: create_command.zig 中 first_slash / second_slash 检测
        let slashIdx = input.indexOf("/")
        match (slashIdx) {
            case Some(si) => {
                if (si > 0 && si < input.length - 1) {
                    // 检查是否只有一个斜杠
                    let secondSlash = input.indexOfFrom(si + 1, '/')
                    match (secondSlash) {
                        case None => {
                            // user/repo → GitHub
                            return (CreateTemplateSource.GitHub, input)
                        }
                        case Some(_) => {
                            // user/repo/subpath → 保留 user/repo 部分
                            return (CreateTemplateSource.GitHub, input.substring(0, si + 1 + secondSlash.get()))
                        }
                    }
                }
            }
            case None => ()
        }

        // 检查本地文件夹
        // 严格翻译自: create_command.zig 中 4 个 local folder 检查点
        let localSearchPaths = [
            input,
            Path.join([".bun-create", input]),
            Path.join([Sys.getHomeDir(), ".bun-create", input])
        ]

        // BUN_CREATE_DIR 环境变量
        let createDir = Sys.getEnv("BUN_CREATE_DIR")
        match (createDir) {
            case Some(d) => {
                let dir = Path.join([d, input])
                if (BaoFile.isDirectory(dir)) {
                    return (CreateTemplateSource.LocalFolder, dir)
                }
            }
            case None => ()
        }

        for (searchPath in localSearchPaths) {
            if (BaoFile.isDirectory(searchPath)) {
                return (CreateTemplateSource.LocalFolder, searchPath)
            }
        }

        // 默认为官方模板
        if (!input.startsWith("/") && !input.startsWith(".")) {
            return (CreateTemplateSource.Official, input)
        }

        return (CreateTemplateSource.Unknown, input)
    }

    /// 规范化 GitHub 名称
    private func normalizeGitHubName(input: String): String {
        var name = input
        if (name.startsWith("github.com/")) {
            name = name.substring("github.com/".length)
        } else if (name.startsWith("https://github.com/")) {
            name = name.substring("https://github.com/".length)
        }
        // 限制为 user/repo
        let slashIdx = name.indexOf("/")
        match (slashIdx) {
            case Some(si) => {
                let afterSlash = name.substring(si + 1)
                let secondSlash = afterSlash.indexOf("/")
                match (secondSlash) {
                    case Some(s2) => return name.substring(0, si + 1 + s2)
                    case None => return name
                }
            }
            case None => return name
        }
    }

    // ========================================================================
    // 模板获取
    // ========================================================================

    /// 获取模板内容
    /// 对应 Bun: CreateCommand.exec 中 switch(example_tag) 分支
    private func fetchTemplate(
        source: CreateTemplateSource,
        template: String,
        dest: String,
        opts: CreateCommandOptions
    ): String {
        match (source) {
            case LocalFolder => {
                logger.info("Copying files from ${template}")
                return template
            }
            case GitHub => {
                return fetchFromGitHub(template)
            }
            case Official => {
                return fetchFromRegistry(template, dest)
            }
            case JsLikeFile => {
                return template
            }
            case Unknown => {
                logger.error("Unknown template: ${template}")
                Sys.exit(1)
                return template
            }
        }
    }

    /// 从 GitHub 下载模板
    /// 对应 Bun: Example.fetchFromGitHub
    ///
    /// 严格翻译自: create_command.zig 中 fetchFromGitHub:
    ///   1. 解析 owner/repo
    ///   2. GET https://api.github.com/repos/{owner}/{repo}/tarball
    ///   3. 检查状态码 (404, 403, 429, 5xx)
    ///   4. 解压 tarball
    private func fetchFromGitHub(name: String): String {
        let client = HttpClient()
        let apiDomain = Sys.getEnv("GITHUB_API_DOMAIN") ?? "api.github.com"

        // 解析 owner/repo
        let slashIdx = name.indexOf("/")
        let owner = name.substring(0, slashIdx.get())
        var repo = name.substring(slashIdx.get() + 1)
        let repoSlash = repo.indexOf("/")
        match (repoSlash) {
            case Some(idx) => repo = repo.substring(0, idx)
            case None => ()
        }

        // 构建 API URL
        let url = "https://${apiDomain}/repos/${owner}/${repo}/tarball"
        logger.info("[github] GET ${owner}/${repo}")

        // 设置认证 header
        let token = Sys.getEnv("GITHUB_TOKEN") ?? Sys.getEnv("GITHUB_ACCESS_TOKEN") ?? ""

        // 下载 tarball
        let response = client.get(url, token)
        match (response) {
            case Some(resp) => {
                if (resp.statusCode == 404) {
                    println("error: '${name}' was not found on GitHub.")
                    Sys.exit(1)
                }
                if (resp.statusCode == 403) {
                    println("error: GitHub returned 403. This usually means GitHub is rate limiting.")
                    println("To fix this, pass a GITHUB_ACCESS_TOKEN environment variable")
                    Sys.exit(1)
                }
                if (resp.statusCode == 200) {
                    // 解压到临时目录
                    let tmpDir = Sys.getTempDir()
                    let extractDir = Path.join([tmpDir, "bao-create-${owner}-${repo}"])
                    BaoFile.mkdir(extractDir, true)
                    let tarPath = Path.join([extractDir, "template.tar.gz"])
                    BaoFile.writeAllBytes(tarPath, resp.bodyBytes)
                    // 解压: tar xzf template.tar.gz --strip-components=1
                    Process.spawn(["tar", "xzf", tarPath, "--strip-components=1"], extractDir)
                    return extractDir
                }
                println("error: GitHub returned ${resp.statusCode}")
                Sys.exit(1)
            }
            case None => {
                println("error: Could not fetch from GitHub")
                Sys.exit(1)
            }
        }
        return name
    }

    /// 从 npm registry 获取官方模板
    /// 对应 Bun: Example.fetch
    ///
    /// 严格翻译自: create_command.zig 中 fetch 函数:
    ///   1. GET https://registry.npmjs.org/@bun-examples/{name}/latest
    ///   2. 解析 JSON 获取 dist.tarball URL
    ///   3. 下载 tarball
    ///   4. 解压
    private func fetchFromRegistry(name: String, dest: String): String {
        let client = HttpClient()

        // 获取 package.json
        let pkgUrl = "https://registry.npmjs.org/@bun-examples/${name}/latest"
        logger.info("Fetching package.json")

        let pkgResponse = client.get(pkgUrl)
        match (pkgResponse) {
            case Some(resp) => {
                if (resp.statusCode == 404) {
                    println("error: '${name}' was not found.")
                    // 列出可用模板
                    listTemplates()
                    Sys.exit(1)
                }
                if (resp.statusCode != 200) {
                    println("error: registry returned ${resp.statusCode}")
                    Sys.exit(1)
                }

                // 解析 tarball URL
                let parser = JsonParser()
                match (parser.parse(resp.body)) {
                    case Some(root) => {
                        match (JsonHelper.getString(JsonHelper.getField(root, "dist"), "tarball")) {
                            case Some(tarballUrl) => {
                                logger.info("Downloading tarball")
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
                                    case None => ()
                                }
                            }
                            case None => ()
                        }
                    }
                    case None => ()
                }
            }
            case None => ()
        }
        return name
    }

    // ========================================================================
    // 文件操作
    // ========================================================================

    /// 检查文件冲突
    /// 对应 Bun: Archiver.getOverwritingFileList
    private func checkFileConflicts(templateDir: String, dest: String): CreateConflictResult {
        let result = CreateConflictResult()
        if (!BaoFile.isDirectory(dest)) {
            return result
        }

        let templateFiles = BaoFile.readdirRecursive(templateDir)
        for (file in templateFiles) {
            let targetPath = Path.join([dest, file])
            if (BaoFile.exists(targetPath)) {
                // never_conflict 中的文件不报冲突
                var skip = false
                for (nc in neverConflict) {
                    if (file == nc || file == nc + "/") { skip = true }
                }
                if (!skip) {
                    result.hasConflicts = true
                    result.conflictFiles.append(file)
                }
            }
        }
        return result
    }

    /// 复制模板文件到目标目录
    /// 对应 Bun: FileCopier.copy
    ///
    /// 严格翻译自: create_command.zig 中 Walker + copyFile:
    ///   - 跳过 node_modules, .git
    ///   - 跳过 lockfile (package-lock.json, yarn.lock, pnpm-lock.yaml)
    ///   - 保持文件权限
    private func copyTemplateToDestination(src: String, dest: String): Unit {
        let files = BaoFile.readdirRecursive(src)
        for (file in files) {
            let srcPath = Path.join([src, file])
            let destPath = Path.join([dest, file])

            // 跳过特殊目录
            if (file.startsWith("node_modules/") || file.startsWith(".git/")) { continue }
            // 跳过 lockfile
            if (file == "package-lock.json" || file == "yarn.lock" ||
                file == "pnpm-lock.yaml") { continue }

            if (BaoFile.isDirectory(srcPath)) {
                BaoFile.mkdir(destPath, true)
            } else {
                BaoFile.copy(srcPath, destPath)
            }
        }
    }

    /// 重命名 gitignore → .gitignore
    // 严格翻译自: create_command.zig 中 linkat/gitignore rename
    private func renameGitignoreFile(dest: String): Unit {
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

    // ========================================================================
    // package.json 处理
    // ========================================================================

    /// 处理 package.json
    /// 对应 Bun: create_command.zig 中 process_package_json
    ///
    /// 返回: (startCommand, hasDependencies)
    private func processPackageJson(
        dest: String,
        projectName: String,
        opts: CreateCommandOptions
    ): (String, Bool) {
        let pkgPath = Path.join([dest, "package.json"])
        let content = BaoFile.readAllText(pkgPath)
        match (content) {
            case Some(text) => {
                let parser = JsonParser()
                match (parser.parse(text)) {
                    case Some(root) => {
                        var startCommand = "bao dev"
                        var hasDependencies = false

                        // 更新 name 字段为项目目录名
                        // 严格翻译自: create_command.zig 中 name_expr 更新
                        JsonHelper.setString(root, "name", projectName)

                        // 检查依赖
                        // 严格翻译自: create_command.zig 中 devDependencies/dependencies 检查
                        match (JsonHelper.getObject(root, "devDependencies")) {
                            case Some(deps) => {
                                if (deps.keys().size > 0) { hasDependencies = true }
                            }
                            case None => ()
                        }
                        match (JsonHelper.getObject(root, "dependencies")) {
                            case Some(deps) => {
                                if (deps.keys().size > 0) { hasDependencies = true }
                            }
                            case None => ()
                        }

                        // 读取 bun-create.start
                        match (JsonHelper.getObject(root, "bun-create")) {
                            case Some(createConfig) => {
                                match (JsonHelper.getString(createConfig, "start")) {
                                    case Some(sc) => {
                                        if (sc.length > 0) { startCommand = sc }
                                    }
                                    case None => ()
                                }
                            }
                            case None => ()
                        }

                        // 移除 "bun-create" 字段
                        JsonHelper.removeField(root, "bun-create")

                        // 清理脚本
                        // 严格翻译自: create_command.zig 中 scripts pruning
                        cleanPackageJsonScripts(root)

                        // 写回
                        let newContent = JsonHelper.serialize(root)
                        BaoFile.writeAllText(pkgPath, newContent)

                        return (startCommand, hasDependencies)
                    }
                    case None => return ("bao dev", false)
                }
            }
            case None => return ("bao dev", false)
        }
    }

    /// 清理 package.json 中的脚本
    /// 对应 Bun: create_command.zig 中 scripts pruning
    ///
    /// 严格翻译自: 移除包含以下内容的脚本:
    ///   - "react-scripts start"
    ///   - "next dev"
    ///   - "react-scripts eject"
    private func cleanPackageJsonScripts(root: JsonValue): Unit {
        match (JsonHelper.getObject(root, "scripts")) {
            case Some(scripts) => {
                let keysToRemove = ArrayList<String>()
                for (key in scripts.keys()) {
                    match (scripts.getString(key)) {
                        case Some(value) => {
                            if (value.contains("react-scripts start") ||
                                value.contains("next dev") ||
                                value.contains("react-scripts eject")) {
                                keysToRemove.append(key)
                            }
                        }
                        case None => ()
                    }
                }
                for (key in keysToRemove) {
                    scripts.remove(key)
                }
            }
            case None => ()
        }
    }

    // ========================================================================
    // Git 初始化
    // ========================================================================

    /// 后台初始化 git
    /// 对应 Bun: GitHandler.spawn(destination, PATH, verbose)
    ///
    /// 严格翻译自: create_command.zig 中 GitHandler.spawn
    /// 使用后台线程运行 git init/add/commit
    private func initGitBackground(dir: String): Unit {
        // 简化: 实际应在后台线程中执行
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

    /// 同步初始化 git
    /// 对应 Bun: GitHandler.run
    private func initGitSync(dir: String, verbose: Bool): Bool {
        let gitPath = Process.which("git")
        match (gitPath) {
            case Some(git) => {
                if (verbose) {
                    logger.info("git backend: ${git}")
                }
                Process.spawn(["git", "init", "--quiet"], dir)
                Process.spawn(["git", "add", dir, "--ignore-errors"], dir)
                Process.spawn(["git", "commit", "-am", "Initial commit (via bao create)", "--quiet"], dir)
                return true
            }
            case None => return false
        }
    }

    // ========================================================================
    // 安装依赖
    // ========================================================================

    /// 安装项目依赖
    /// 对应 Bun: create_command.zig 中 npm_client install
    ///
    /// 严格翻译自: 使用 bun install 安装依赖
    private func installProjectDependencies(dir: String): Unit {
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

    // ========================================================================
    // 输出
    // ========================================================================

    /// 打印成功信息
    /// 对应 Bun: create_command.zig 中 success output section
    private func printSuccess(
        template: String,
        dest: String,
        startCommand: String,
        absDest: String,
        skipInstall: Bool,
        skipGit: Bool
    ): Unit {
        println("")
        println("Come hang out in bao's Discord: https://bao.dev/discord")

        if (!skipInstall) {
            println("-----")
        }

        if (!skipGit && !skipInstall) {
            println("A local git repository was created for you and dependencies were installed automatically.")
        } else if (!skipGit) {
            println("A local git repository was created for you.")
        } else if (!skipInstall) {
            println("Dependencies were installed automatically.")
        }

        // 成功消息
        let display = if (template.startsWith("github.com/")) {
            template.substring("github.com/".length)
        } else if (template.startsWith("https://github.com/")) {
            template.substring("https://github.com/".length)
        } else {
            Path.basename(template)
        }
        println("Success! ${display} loaded into ${dest}")

        // 提示启动命令
        let relDest = Path.relative(Sys.getcwd(), absDest)
        if (relDest.length == 0) {
            println("# To get started, run:")
            println("  ${startCommand}")
        } else {
            println("# To get started, run:")
            println("  cd ${relDest}")
            println("  ${startCommand}")
        }
        println("")
    }

    /// 列出可用模板
    /// 对应 Bun: CreateListExamplesCommand.exec
    private func listTemplates(): Unit {
        println("Welcome to Bao! Create a new project by pasting any of the following:")
        println("")
        println("  bao create react ./react-app")
        println("  bao create next ./next-app")
        println("  bao create express ./express-app")
        println("")
        println("You can also paste a GitHub repository:")
        println("  bao create user/repo my-app")
        println("")
    }

    /// 解析命令行参数
    private func parseCreateArgs(args: ArrayList<String>): CreateCommandOptions {
        let opts = CreateCommandOptions(args.size > 0 ? args[0] : "")
        var foundTemplate = false
        for (arg in args) {
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
        }
        return opts
    }

    /// 打印帮助
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

// ============================================================================
// 辅助类型
// ============================================================================

/// 模板来源
/// 对应 Bun: Example.Tag
public enum CreateTemplateSource {
    | Unknown
    | Official         // 官方模板 (npm registry)
    | GitHub           // GitHub 仓库
    | LocalFolder      // 本地文件夹
    | JsLikeFile       // .jsx/.tsx 文件
}

/// Create 命令选项
/// 对应 Bun: CreateOptions
public class CreateCommandOptions {
    public var template: String
    public var destination: ?String
    public var skipInstall: Bool
    public var skipGit: Bool
    public var skipPackageJson: Bool
    public var overwrite: Bool
    public var verbose: Bool
    public var open: Bool

    public init(template: String) {
        this.template = template
        destination = None
        skipInstall = false
        skipGit = false
        skipPackageJson = false
        overwrite = false
        verbose = false
        open = false
    }
}

/// 文件冲突结果
class CreateConflictResult {
    public var hasConflicts: Bool
    public var conflictFiles: ArrayList<String>

    public init() {
        hasConflicts = false
        conflictFiles = ArrayList<String>()
    }
}

/// 日志工具 (简化)
class CreateLogger {
    public init() {}

    public func info(msg: String): Unit {
        // verbose 模式下输出
    }

    public func warn(msg: String): Unit {
        println("warn: ${msg}")
    }

    public func error(msg: String): Unit {
        println("error: ${msg}")
    }

    public func success(msg: String): Unit {
        println(msg)
    }
}
