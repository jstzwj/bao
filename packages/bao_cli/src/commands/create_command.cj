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
// 常量 — 严格翻译自 create_command.zig 顶层常量
// ============================================================================

// 严格翻译自: create_command.zig 中 skip_dirs
private let skipDirs = ["node_modules", ".git"]

// 严格翻译自: create_command.zig 中 skip_files
private let skipFiles = ["package-lock.json", "yarn.lock", "pnpm-lock.yaml"]

// 严格翻译自: create_command.zig 中 never_conflict
private let neverConflict = ["README.md", "gitignore", ".gitignore", ".git/"]

// 严格翻译自: create_command.zig 中 npm_task_args
private let npmTaskArgs = ["run"]

// 严格翻译自: create_command.zig 中 target_nextjs_version
private let targetNextjsVersion = "12.2.3"

// 严格翻译自: create_command.zig 中 BUN_CREATE_DIR
private let bunCreateDir = ".bun-create"

// 严格翻译自: create_command.zig 中 examples_url
private let examplesUrl = "https://registry.npmjs.org/bun-examples-all/latest"

// ============================================================================
// UnsupportedPackages — 严格翻译自 create_command.zig 中 UnsupportedPackages
//
// 检测不兼容的包并在创建项目后输出警告
// ============================================================================
// 严格翻译自: create_command.zig 中 UnsupportedPackages struct
public class UnsupportedPackages {
    public var styledJsx: Bool

    public init() {
        styledJsx = false
    }

    /// 从依赖列表更新不支持的包标记
    // 严格翻译自: create_command.zig 中 UnsupportedPackages.update
    public func update(properties: ArrayList<JsonProperty>): Unit {
        for (prop in properties) {
            let key = prop.key
            if (key == "styled-jsx") {
                styledJsx = true
            }
        }
    }

    /// 打印不支持包的警告
    // 严格翻译自: create_command.zig 中 UnsupportedPackages.print
    public func print(): Unit {
        if (styledJsx) {
            println("warn: \"styled-jsx\" won't work in bun yet")
        }
    }
}

// ============================================================================
// ProgressBuf — 严格翻译自 create_command.zig 中 ProgressBuf
//
// 双缓冲进度条文本，避免每次分配新内存
// ============================================================================
// 严格翻译自: create_command.zig 中 ProgressBuf struct
public class ProgressBuf {
    private var bufs: Array2<String>
    private var bufIndex: Int64

    public init() {
        bufs = Array2<String>("", "")
        bufIndex = 0
    }

    /// 格式化打印到内部缓冲区
    // 严格翻译自: create_command.zig 中 ProgressBuf.print
    public func print(fmt: String, args: ArrayList<String>): String {
        bufIndex = bufIndex + 1
        val result = String.format(fmt, args)
        bufs.set(bufIndex % 2, result)
        return result
    }

    /// 带 ANSI 颜色支持的格式化
    // 严格翻译自: create_command.zig 中 ProgressBuf.pretty
    public func pretty(fmt: String, args: ArrayList<String>): String {
        // 简化: 始终使用不含颜色版本
        return print(fmt, args)
    }
}

// ============================================================================
// CreateOptions — 严格翻译自 create_command.zig 中 CreateOptions
//
// bun create 命令的选项结构
// ============================================================================
// 严格翻译自: create_command.zig 中 CreateOptions struct
public class CreateOptions {
    public var npmClient: ?NPMClientTag
    public var skipInstall: Bool
    public var overwrite: Bool
    public var skipGit: Bool
    public var skipPackageJson: Bool
    public var positionals: ArrayList<String>
    public var verbose: Bool
    public var open: Bool

    public init() {
        npmClient = None
        skipInstall = false
        overwrite = false
        skipGit = false
        skipPackageJson = false
        positionals = ArrayList<String>()
        verbose = false
        open = false
    }

    /// 解析命令行参数
    // 严格翻译自: create_command.zig 中 CreateOptions.parse
    public static func parse(args: ArrayList<String>): CreateOptions {
        val opts = CreateOptions()
        var positionalIndex = 0

        for (arg in args) {
            match (arg) {
                case "--help" | "-h" => {
                    // 帮助已在外层处理
                }
                case "--force" => opts.overwrite = true
                case "--no-install" => opts.skipInstall = true
                case "--no-git" => opts.skipGit = true
                case "--verbose" => opts.verbose = true
                case "--no-package-json" => opts.skipPackageJson = true
                case "--open" => opts.open = true
                case _ => {
                    if (!arg.startsWith("-")) {
                        opts.positionals.append(arg)
                    }
                }
            }
        }

        // 如果第一个位置参数是 "c" 或 "create"，跳过它
        // 严格翻译自: create_command.zig 中 positionals[0] 检查
        if (opts.positionals.size > 0) {
            val first = opts.positionals[0]
            if (first == "c" || first == "create") {
                if (opts.positionals.size > 1) {
                    opts.positionals = opts.positionals.substring(1)
                } else {
                    opts.positionals = ArrayList<String>()
                }
            }
        }

        return opts
    }
}

// ============================================================================
// NPMClient — 严格翻译自 create_command.zig 中 NPMClient 引用
// ============================================================================
// 严格翻译自: create_command.zig 中 NPMClient 引用
public enum NPMClientTag {
    | Bun
    | Npm
    | Yarn
    | Pnpm
}

/// NPM 客户端信息
// 严格翻译自: create_command.zig 中 NPMClient struct 引用
public class NPMClient {
    public var tag: NPMClientTag
    public var bin: String

    public init(tag: NPMClientTag, bin: String) {
        this.tag = tag
        this.bin = bin
    }
}

// ============================================================================
// 全局初始化标记 — 严格翻译自 create_command.zig 中 initialized_store
// ============================================================================
// 严格翻译自: create_command.zig 中 initialized_store + initializeStore
var initializedStore = false

public func initializeStore(): Unit {
    if (initializedStore) {
        return
    }
    initializedStore = true
    // 对应 Bun 中 js_ast.Expr.Data.Store.create() + js_ast.Stmt.Data.Store.create()
    // 简化: 在 Cangjie 中无需手动初始化 AST store
}

// ============================================================================
// execTask — 严格翻译自 create_command.zig 中 execTask
//
// 执行预安装/后安装任务
// ============================================================================
// 严格翻译自: create_command.zig 中 execTask function
public func execTask(task_: String, cwd: String, npmClient: ?NPMClient): Unit {
    val task = task_.trim()
    if (task.length == 0) {
        return
    }

    // 计算参数数量
    var count = 0
    val parts = task.split(" ")
    for (_ in parts) {
        count = count + 1
    }

    // 构建参数列表
    val npmArgsCount = if (npmClient != None) { 2 } else { 0 }
    var argv = ArrayList<String>()

    // 如果有 npm client，前两个参数是 npm_client + "run"
    // 严格翻译自: create_command.zig 中 npm_client 参数构建
    match (npmClient) {
        case Some(client) => {
            argv.append(client.bin)
            argv.append(npmTaskArgs[0])
        }
        case None => ()
    }

    var i = npmArgsCount
    for (part in parts) {
        argv.append(part)
        i = i + 1
    }

    // 如果任务以 "bun " 开头且有 npm_client，去掉前两个参数
    // 严格翻译自: create_command.zig 中 strings.startsWith(task, "bun ") 检查
    if (npmClient != None && task.startsWith("bun ")) {
        argv = argv.sublist(2)
    }

    // 打印执行的命令
    // 严格翻译自: create_command.zig 中 Output.pretty + for argv
    var cmdStr = "$"
    for (arg in argv) {
        cmdStr = cmdStr + " " + arg
    }
    println(cmdStr)

    // 执行命令
    // 严格翻译自: create_command.zig 中 bun.spawnSync
    Process.spawn(argv.toArray(), cwd)
}

// ============================================================================
// Example — 严格翻译自 create_command.zig 中 Example struct
//
// 模板信息结构体
// ============================================================================
// 严格翻译自: create_command.zig 中 Example struct
public class Example {
    public var name: String
    public var version: String
    public var description: String
    public var local: Bool

    public init(name: String, version: String, description: String, local: Bool) {
        this.name = name
        this.version = version
        this.description = description
        this.local = local
    }

    public init(name: String) {
        this.name = name
        this.version = ""
        this.description = ""
        this.local = false
    }

    // ========================================================================
    // Example.Tag — 模板来源标签
    // ========================================================================

    /// 从文件扩展名判断模板类型
    // 严格翻译自: create_command.zig 中 Example.Tag.fromFileExtension
    public static func fromFileExtension(extension: String): ?CreateTemplateSource {
        if (extension == ".tsx") {
            return CreateTemplateSource.JsLikeFile
        }
        if (extension == ".jsx") {
            return CreateTemplateSource.JsLikeFile
        }
        return None
    }

    /// 打印模板列表
    // 严格翻译自: create_command.zig 中 Example.print
    public static func print(examples: ArrayList<Example>, defaultAppName: ?String): Unit {
        for (example in examples) {
            val appName = match (defaultAppName) {
                case Some(name) => name
                case None => "./${example.name.substring(0, Math.min(example.name.length, 492))}-app"
            }

            if (example.description.length > 0) {
                println("  # ${example.description}")
                println("  bao create ${example.name} ${appName}")
                println("")
            } else {
                println("  bao create ${example.name} ${appName}")
                println("")
            }
        }
    }

    /// 从本地文件夹和远程仓库获取所有模板
    // 严格翻译自: create_command.zig 中 Example.fetchAllLocalAndRemote
    public static func fetchAllLocalAndRemote(): ArrayList<Example> {
        var examples = ArrayList<Example>()

        // 获取远程模板
        // 严格翻译自: create_command.zig 中 remote_examples = try Example.fetchAll
        val remoteExamples = fetchAll()
        for (ex in remoteExamples) {
            examples.append(ex)
        }

        // 检查本地模板目录
        // 严格翻译自: create_command.zig 中 folders 数组 + 遍历
        var localDirs = ArrayList<String>()

        // BUN_CREATE_DIR 环境变量
        val createDir = Sys.getEnv("BUN_CREATE_DIR")
        match (createDir) {
            case Some(d) => localDirs.append(d)
            case None => ()
        }

        // .bun-create/ 在当前目录
        localDirs.append(Path.join([Sys.getcwd(), bunCreateDir]))

        // $HOME/.bun-create/
        val homeDir = Sys.getHomeDir()
        localDirs.append(Path.join([homeDir, bunCreateDir]))

        // 遍历每个本地模板目录
        // 严格翻译自: create_command.zig 中 for (folders) |folder| 循环
        for (dir in localDirs) {
            if (!BaoFile.isDirectory(dir)) {
                continue
            }

            val entries = BaoFile.readdir(dir)
            for (entry in entries) {
                // 跳过 skip_dirs 中的目录
                var shouldSkip = false
                for (sd in skipDirs) {
                    if (entry == sd) {
                        shouldSkip = true
                    }
                }
                if (shouldSkip) {
                    continue
                }

                // 检查是否是目录且包含 package.json
                val entryPath = Path.join([dir, entry])
                if (BaoFile.isDirectory(entryPath)) {
                    val pkgJsonPath = Path.join([entryPath, "package.json"])
                    if (BaoFile.exists(pkgJsonPath)) {
                        examples.append(Example(entry, "", "", true))
                    }
                }
            }
        }

        return examples
    }

    /// 从 GitHub 下载模板
    // 严格翻译自: create_command.zig 中 Example.fetchFromGitHub
    public static func fetchFromGitHub(name: String): HttpResponse {
        val ownerIdx = name.indexOf("/")
        val owner = name.substring(0, ownerIdx.get())
        var repository = name.substring(ownerIdx.get() + 1)

        // 截断子路径
        val repoSlash = repository.indexOf("/")
        match (repoSlash) {
            case Some(idx) => repository = repository.substring(0, idx)
            case None => ()
        }

        println("[github] GET ${owner}/${repository}")

        // 获取 GitHub API 域名
        var githubApiDomain = "api.github.com"
        val apiDomain = Sys.getEnv("GITHUB_API_DOMAIN")
        match (apiDomain) {
            case Some(d) => {
                if (d.length > 0) {
                    githubApiDomain = d
                }
            }
            case None => ()
        }

        val apiUrl = "https://${githubApiDomain}/repos/${owner}/${repository}/tarball"

        // 设置认证 header
        // 严格翻译自: create_command.zig 中 GITHUB_TOKEN/GITHUB_ACCESS_TOKEN
        var headers = ArrayList<Tuple<String, String>>()
        val token = Sys.getEnv("GITHUB_TOKEN")
        match (token) {
            case Some(t) => {
                if (t.length > 0) {
                    headers.append(Tuple("Authorization", "Bearer ${t}"))
                }
            }
            case None => {
                val accessToken = Sys.getEnv("GITHUB_ACCESS_TOKEN")
                match (accessToken) {
                    case Some(at) => {
                        if (at.length > 0) {
                            headers.append(Tuple("Authorization", "Bearer ${at}"))
                        }
                    }
                    case None => ()
                }
            }
        }

        val client = HttpClient()
        val response = client.getWithHeaders(apiUrl, headers)

        // 检查状态码
        // 严格翻译自: create_command.zig 中 switch (response.status_code)
        match (response) {
            case Some(resp) => {
                if (resp.statusCode == 404) {
                    println("error: '${name}' was not found on GitHub.")
                    Sys.exit(1)
                }
                if (resp.statusCode == 403) {
                    println("error: GitHub returned 403. This usually means GitHub is rate limiting your requests.")
                    println("To fix this, either:")
                    println("  A) pass a GITHUB_ACCESS_TOKEN environment variable to bun")
                    println("  B) Wait a little and try again")
                    Sys.exit(1)
                }
                if (resp.statusCode == 429) {
                    println("error: GitHub returned 429 (too many requests).")
                    Sys.exit(1)
                }
                if (resp.statusCode >= 499 && resp.statusCode <= 599) {
                    println("error: GitHub is currently down (${resp.statusCode}). Please try again later.")
                    Sys.exit(1)
                }
                if (resp.statusCode != 200) {
                    println("error: GitHub returned unexpected status ${resp.statusCode}")
                    Sys.exit(1)
                }

                // 验证 content-type
                // 严格翻译自: create_command.zig 中 content-type 检查
                var contentType = ""
                var isExpectedContentType = false
                for (header in resp.headers) {
                    if (header.name.toLowerCase() == "content-type") {
                        contentType = header.value
                        if (contentType == "application/x-gzip") {
                            isExpectedContentType = true
                        }
                        // GitHub 有时返回 application/gzip 或 application/octet-stream
                        if (contentType.contains("gzip") || contentType.contains("octet-stream")) {
                            isExpectedContentType = true
                        }
                    }
                }

                if (!isExpectedContentType) {
                    if (contentType.length > 0) {
                        println("error: Unexpected content type from GitHub: ${contentType}")
                    } else {
                        println("error: Invalid response from GitHub (missing content type)")
                    }
                    Sys.exit(1)
                }

                if (resp.bodyBytes.length == 0) {
                    println("error: Invalid response from GitHub (missing body)")
                    Sys.exit(1)
                }

                return resp
            }
            case None => {
                println("error: Could not connect to GitHub")
                Sys.exit(1)
            }
        }
    }

    /// 从 npm registry 获取官方模板的 tarball
    // 严格翻译自: create_command.zig 中 Example.fetch
    public static func fetch(name: String): HttpResponse {
        val client = HttpClient()

        // 获取 package.json
        // 严格翻译自: create_command.zig 中 url_buf + registry URL
        val pkgUrl = "https://registry.npmjs.org/@bun-examples/${name}/latest"
        println("Fetching package.json")

        val pkgResponse = client.get(pkgUrl)
        match (pkgResponse) {
            case Some(resp) => {
                if (resp.statusCode == 404) {
                    return resp
                }
                if (resp.statusCode == 403) {
                    println("error: Registry returned 403 (Forbidden)")
                    Sys.exit(1)
                }
                if (resp.statusCode == 429) {
                    println("error: Registry returned 429 (Too Many Requests)")
                    Sys.exit(1)
                }
                if (resp.statusCode >= 499 && resp.statusCode <= 599) {
                    println("error: Registry is currently down (${resp.statusCode})")
                    Sys.exit(1)
                }
                if (resp.statusCode != 200) {
                    println("error: Registry returned ${resp.statusCode}")
                    Sys.exit(1)
                }

                // 解析 tarball URL
                // 严格翻译自: create_command.zig 中 JSON.parseUTF8 + dist.tarball
                println("Parsing package.json")
                initializeStore()

                val parser = JsonParser()
                match (parser.parse(resp.body)) {
                    case Some(root) => {
                        // 提取 dist.tarball
                        val dist = JsonHelper.getObject(root, "dist")
                        match (dist) {
                            case Some(distObj) => {
                                val tarballUrl = JsonHelper.getString(distObj, "tarball")
                                match (tarballUrl) {
                                    case Some(url) => {
                                        if (url.length > 0 &&
                                            (url.startsWith("https://") || url.startsWith("http://"))) {
                                            // 下载 tarball
                                            // 严格翻译自: create_command.zig 中 "Downloading tarball" 部分
                                            println("Downloading tarball")
                                            val tarResp = client.get(url)
                                            match (tarResp) {
                                                case Some(tarResponse) => {
                                                    if (tarResponse.statusCode != 200) {
                                                        println("error: Failed to download tarball: ${tarResponse.statusCode}")
                                                        Sys.exit(1)
                                                    }
                                                    return tarResponse
                                                }
                                                case None => {
                                                    println("error: Could not download tarball")
                                                    Sys.exit(1)
                                                }
                                            }
                                        }
                                    }
                                    case None => ()
                                }
                            }
                            case None => ()
                        }
                    }
                    case None => {
                        println("error: Failed to parse package.json from registry")
                        Sys.exit(1)
                    }
                }

                println("error: package.json is missing tarball url. This is an internal error!")
                Sys.exit(1)
            }
            case None => {
                println("error: Could not fetch from npm registry")
                Sys.exit(1)
            }
        }
    }

    /// 从远程获取所有模板列表
    // 严格翻译自: create_command.zig 中 Example.fetchAll
    public static func fetchAll(): ArrayList<Example> {
        val client = HttpClient()

        println("Fetching manifest")

        val response = client.get(examplesUrl)
        match (response) {
            case Some(resp) => {
                if (resp.statusCode != 200) {
                    println("error: ${resp.statusCode} fetching examples")
                    Sys.exit(1)
                }

                initializeStore()

                val parser = JsonParser()
                match (parser.parse(resp.body)) {
                    case Some(root) => {
                        // 解析 examples 对象
                        // 严格翻译自: create_command.zig 中 examples_object.asProperty("examples")
                        val examplesProp = JsonHelper.getObject(root, "examples")
                        match (examplesProp) {
                            case Some(examplesObj) => {
                                val keys = examplesObj.keys()
                                var list = ArrayList<Example>()

                                for (key in keys) {
                                    // 去掉 scoped prefix: @bun-examples/react → react
                                    // 严格翻译自: create_command.zig 中 name 处理
                                    val exampleName = match (key.indexOf("/")) {
                                        case Some(slash) => key.substring(slash + 1)
                                        case None => key
                                    }

                                    val exampleObj = examplesObj.getObject(key)
                                    var version = ""
                                    var description = ""
                                    match (exampleObj) {
                                        case Some(obj) => {
                                            version = JsonHelper.getString(obj, "version") ?? ""
                                            description = JsonHelper.getString(obj, "description") ?? ""
                                        }
                                        case None => ()
                                    }

                                    list.append(Example(exampleName, version, description, false))
                                }
                                return list
                            }
                            case None => {
                                println("error: Corrupt examples data: expected object")
                                Sys.exit(1)
                            }
                        }
                    }
                    case None => {
                        println("error: Failed to parse examples list")
                        Sys.exit(1)
                    }
                }
            }
            case None => {
                println("error: Request timed out while trying to fetch examples list. Please try again")
                Sys.exit(1)
            }
        }

        return ArrayList<Example>()
    }
}

// ============================================================================
// DownloadedExample — 严格翻译自 create_command.zig 中 DownloadedExample
// ============================================================================
// 严格翻译自: create_command.zig 中 DownloadedExample struct
public class DownloadedExample {
    public var tarballBytes: Array<Byte>
    public var example: Example

    public init(tarballBytes: Array<Byte>, example: Example) {
        this.tarballBytes = tarballBytes
        this.example = example
    }
}

// ============================================================================
// SourceFileProjectGenerator — 严格翻译自 create_command.zig 中引用的
// SourceFileProjectGenerator
//
// 从 .jsx/.tsx 单文件生成完整项目
// ============================================================================
// 严格翻译自: create_command.zig 中 SourceFileProjectGenerator 引用 + runOnEntryPoint
public class SourceFileProjectGenerator {
    /// 从入口文件生成项目
    // 严格翻译自: create_command.zig 中 SourceFileProjectGenerator.generate
    public static func generate(entryPoint: String, destDir: String): Unit {
        val entryBasename = Path.basename(entryPoint)
        val entryName = Path.basenameWithoutExtension(entryPoint)

        // 创建目标目录
        BaoFile.mkdir(destDir, true)

        // 生成 package.json
        // 严格翻译自: SourceFileProjectGenerator 中 package.json 生成
        val packageJson = JsonObject()
        packageJson.setString("name", entryName)
        packageJson.setString("version", "1.0.0")
        packageJson.setString("type", "module")

        val scripts = JsonObject()
        scripts.setString("dev", "bao dev ${entryBasename}")
        scripts.setString("start", "bao run ${entryBasename}")
        packageJson.setObject("scripts", scripts)

        val pkgJsonPath = Path.join([destDir, "package.json"])
        BaoFile.writeAllText(pkgJsonPath, packageJson.serialize())

        // 复制入口文件
        val destEntryPath = Path.join([destDir, entryBasename])
        BaoFile.copy(entryPoint, destEntryPath)

        // 创建 tsconfig.json (如果需要)
        if (entryPoint.endsWith(".tsx") || entryPoint.endsWith(".ts")) {
            val tsconfig = JsonObject()
            val compilerOptions = JsonObject()
            compilerOptions.setString("target", "ESNext")
            compilerOptions.setString("module", "ESNext")
            compilerOptions.setBool("moduleResolution", true)
            compilerOptions.setBool("esModuleInterop", true)
            compilerOptions.setBool("strict", true)
            compilerOptions.setBool("jsx", true)
            compilerOptions.setString("jsxFactory", "react-jsx")
            tsconfig.setObject("compilerOptions", compilerOptions)
            val tsconfigPath = Path.join([destDir, "tsconfig.json"])
            BaoFile.writeAllText(tsconfigPath, tsconfig.serialize())
        }
    }
}

// ============================================================================
// GitHandler — 严格翻译自 create_command.zig 中 GitHandler
//
// Git 仓库初始化 (支持后台线程和同步模式)
// ============================================================================
// 严格翻译自: create_command.zig 中 GitHandler struct
public class GitHandler {
    private var successValue: Int32
    private var backgroundThread: ?Thread

    public init() {
        successValue = 0
        backgroundThread = None
    }

    /// 在后台线程中启动 git 初始化
    // 严格翻译自: create_command.zig 中 GitHandler.spawn
    public func spawn(destination: String, path: String, verbose: Bool): Unit {
        // 严格翻译自: create_command.zig 中 std.Thread.spawn
        successValue = 0
        val self = this
        backgroundThread = Some(Thread.spawn({
            self.spawnThread(destination, path, verbose)
        }))
    }

    /// 后台线程函数
    // 严格翻译自: create_command.zig 中 GitHandler.spawnThread
    private func spawnThread(destination: String, path: String, verbose: Bool): Unit {
        val outcome = run(destination, path, verbose)
        if (outcome) {
            successValue = 1
        } else {
            successValue = 2
        }
    }

    /// 等待后台 git 线程完成
    // 严格翻译自: create_command.zig 中 GitHandler.wait
    public func wait(): Bool {
        match (backgroundThread) {
            case Some(thread) => {
                thread.join()
                val outcome = successValue == 1
                backgroundThread = None
                return outcome
            }
            case None => return false
        }
    }

    /// 同步执行 git 初始化
    // 严格翻译自: create_command.zig 中 GitHandler.run
    public func run(destination: String, path: String, verbose: Bool): Bool {
        val gitStart = Time.nowNanos()

        // 查找 git 可执行文件
        // 严格翻译自: create_command.zig 中 which(&bun_path_buf, PATH, destination, "git")
        val gitPath = Process.which("git")
        match (gitPath) {
            case Some(git) => {
                // 严格翻译自: create_command.zig 中 git_commands tuple
                // git init --quiet
                // git add <destination> --ignore-errors
                // git commit -am "Initial commit (via bun create)" --quiet
                val commands = [
                    [git, "init", "--quiet"],
                    [git, "add", destination, "--ignore-errors"],
                    [git, "commit", "-am", "Initial commit (via bao create)", "--quiet"]
                ]

                if (verbose) {
                    println("git backend: ${git}")
                }

                // 执行每个 git 命令
                // 严格翻译自: create_command.zig 中 inline for + process.spawnAndWait
                for (command in commands) {
                    Process.spawn(command, destination)
                }

                val gitEnd = Time.nowNanos()
                val elapsed = (gitEnd - gitStart) / 1000000
                println("")
                Time.printStartEnd(gitStart, gitEnd)
                println(" git")
                return true
            }
            case None => return false
        }
    }
}

// ============================================================================
// InjectionPrefill — 严格翻译自 create_command.zig 中 InjectionPrefill
//
// 用于在 package.json 中注入依赖的预填充数据
// 当前在 Bun 中大部分功能已被注释掉, 保留结构以备将来使用
// ============================================================================
// 严格翻译自: create_command.zig 中 InjectionPrefill struct
public class InjectionPrefill {
    // 严格翻译自: create_command.zig 中 InjectionPrefill 常量字符串
    public static let dependenciesString = "dependencies"
    public static let devDependenciesString = "devDependencies"
    public static let bunString = "bun"
    public static let macrosString = "macros"
    public static let bunMacrosRelayPath = "bun-macro-relay"

    // 严格翻译自: create_command.zig 中 npx_react_scripts_build_str
    public static let npxReactScriptsBuild = "npx react-scripts build"

    // 严格翻译自: create_command.zig 中 bun_framework_next_string/version
    public static let bunFrameworkNextString = "bun-framework-next"
    public static let bunFrameworkNextVersion = "latest"

    // 严格翻译自: create_command.zig 中 bun_macro_relay_dependency_string/version
    public static let bunMacroRelayDependencyString = "bun-macro-relay"
    public static let bunMacroRelayDependencyVersion = "latest"

    // 严格翻译自: create_command.zig 中 refresh_runtime_string/version
    public static let refreshRuntimeString = "react-refresh"
    public static let refreshRuntimeVersion = "0.10.0"

    // 严格翻译自: create_command.zig 中 bun_bun_for_nextjs_task
    public static let bunBunForNextjsTask = "bun bun --use next"
}

// ============================================================================
// PrunePackages — 严格翻译自 create_command.zig 中 Prune struct (注释块)
//
// 需要裁剪的包列表 (Bun 中此功能大部分被注释掉, 保留结构)
// ============================================================================
// 严格翻译自: create_command.zig 中 Prune struct (注释块)
public class PrunePackages {
    /// 需要裁剪的包名列表
    // 严格翻译自: create_command.zig 中 Prune.packages ComptimeStringMap
    public static let packages = [
        "@parcel/babel-preset",
        "@parcel/core",
        "@swc/cli",
        "@swc/core",
        "@webpack/cli",
        "react-scripts",
        "webpack-cli",
        "webpack",
        "cosmiconfig"
    ]

    public var pruneCount: Int64

    public init() {
        pruneCount = 0
    }

    /// 从依赖列表中裁剪不需要的包
    // 严格翻译自: create_command.zig 中 Prune.prune
    public func prune(properties: ArrayList<JsonProperty>): ArrayList<JsonProperty> {
        var result = ArrayList<JsonProperty>()
        for (prop in properties) {
            val key = prop.key
            var doPrune = false
            for (pkg in PrunePackages.packages) {
                if (key == pkg) {
                    doPrune = true
                }
            }
            if (doPrune) {
                pruneCount = pruneCount + 1
            } else {
                result.append(prop)
            }
        }
        return result
    }
}

// ============================================================================
// ArchiverPlucker — 严格翻译自 create_command.zig 中 Archiver.Plucker 引用
//
// 在 tarball 解压过程中提取 package.json
// ============================================================================
// 严格翻译自: create_command.zig 中 Archiver.Plucker 引用
public class ArchiverPlucker {
    public var found: Bool
    public var contents: String
    public var targetFileName: String
    public var maxLength: Int64

    public init(targetFileName: String, maxLength: Int64) {
        this.targetFileName = targetFileName
        this.maxLength = maxLength
        this.found = false
        this.contents = ""
    }

    /// 检查文件名是否匹配
    public func check(fileName: String, data: String): Unit {
        if (fileName == targetFileName && data.length <= maxLength) {
            found = true
            contents = data
        }
    }
}

// ============================================================================
// CreateListExamplesCommand — 严格翻译自 create_command.zig 中
// CreateListExamplesCommand
//
// 列出所有可用模板的独立命令
// ============================================================================
// 严格翻译自: create_command.zig 中 CreateListExamplesCommand struct
public class CreateListExamplesCommand {
    /// 执行模板列表命令
    // 严格翻译自: create_command.zig 中 CreateListExamplesCommand.exec
    public static func exec(): Unit {
        println("Fetching manifest")

        // 获取所有本地和远程模板
        // 严格翻译自: create_command.zig 中 Example.fetchAllLocalAndRemote
        val examples = Example.fetchAllLocalAndRemote()

        println("Welcome to bao! Create a new project by pasting any of the following:")
        println("")

        Example.print(examples, None)

        println("# You can also paste a GitHub repository:")
        println("")
        println("  bao create ahfarmer/calculator calc")
        println("")

        // 提示本地模板路径
        // 严格翻译自: create_command.zig 中 homedir 提示
        val homeDir = Sys.getHomeDir()
        if (homeDir.length > 0) {
            println("This command is completely optional. To add a new local template, create a folder in ${homeDir}/.bun-create/. To publish a new template, git clone https://github.com/oven-sh/bun, add a new folder to the \"examples\" folder, and submit a PR.")
        } else {
            println("This command is completely optional. To add a new local template, create a folder in $HOME/.bun-create/. To publish a new template, git clone https://github.com/oven-sh/bun, add a new folder to the \"examples\" folder, and submit a PR.")
        }
    }
}

// ============================================================================
// CreateCommand — 严格翻译自 create_command.zig 中 CreateCommand
//
// bun create 命令执行器
// ============================================================================
/// Create 命令执行器
/// 对应 Bun: CreateCommand.exec(ctx, example_tag, template)
public class CreateCommand {
    /// 日志工具
    private var logger: CreateLogger

    /// 不冲突的文件名列表
    private let neverConflictList = neverConflict

    public init() {
        logger = CreateLogger()
    }

    /// 执行 create 命令
    /// 对应 Bun: CreateCommand.exec(ctx, example_tag, template)
    ///
    /// 严格翻译自: create_command.zig 中 exec 函数流程
    public func execute(args: ArrayList<String>): Unit {
        // 解析参数
        // 严格翻译自: create_command.zig 中 CreateOptions.parse
        val createOptions = CreateOptions.parse(args)
        val positionals = createOptions.positionals

        // 无参数: 列出可用模板
        // 严格翻译自: create_command.zig 中 positionals.len == 0 → CreateListExamplesCommand
        if (positionals.size == 0) {
            CreateListExamplesCommand.exec()
            return
        }

        // 提取模板信息
        // 严格翻译自: create_command.zig 中 CreateCommand.extractInfo
        val (exampleTag, template) = extractInfo(positionals, createOptions)

        // 确定目标目录名
        // 严格翻译自: create_command.zig 中 dirname 计算
        val dirname = if (positionals.size == 1) {
            Path.basename(template)
        } else {
            positionals[1]
        }

        val destination = Path.resolve(dirname)

        // 进度条
        // 严格翻译自: create_command.zig 中 progress/node
        var progressName = if (exampleTag == CreateTemplateSource.JsLikeFile) {
            "Analyzing ${template}"
        } else {
            "Loading ${template}"
        }
        println(progressName)

        var packageJsonContents = ""
        var packageJsonFile: ?String = None

        if (exampleTag != CreateTemplateSource.LocalFolder) {
            if (createOptions.verbose) {
                println("Downloading as ${exampleTag}")
            }
        }

        // ====================================================================
        // 根据模板类型获取内容
        // 严格翻译自: create_command.zig 中 switch (example_tag)
        // ====================================================================
        match (exampleTag) {
            case JsLikeFile => {
                // .jsx/.tsx 文件 → 分析依赖生成项目
                // 严格翻译自: create_command.zig 中 runOnEntryPoint
                runOnEntryPoint(template, destination)
                return
            }
            case GitHub | Official => {
                // 获取 tarball 字节
                // 严格翻译自: create_command.zig 中 tarball_bytes 获取
                val tarballResponse = if (exampleTag == CreateTemplateSource.Official) {
                    val resp = Example.fetch(template)
                    if (resp.statusCode == 404) {
                        println("error: \"${template}\" was not found. Here are templates you can use:")
                        println("")
                        val examples = Example.fetchAllLocalAndRemote()
                        Example.print(examples, Some(dirname))
                        Sys.exit(1)
                    }
                    resp
                } else {
                    // GitHub
                    Example.fetchFromGitHub(template)
                }

                println("Decompressing ${template}")

                // 解压到目标目录
                // 严格翻译自: create_command.zig 中 Archiver.extractToDisk
                let fileBuf = tarballResponse.bodyBytes

                // 检查文件冲突
                // 严格翻译自: create_command.zig 中 Archiver.getOverwritingFileList
                if (!createOptions.overwrite) {
                    val overwriteList = getOverwritingFileList(fileBuf, destination)
                    // 移除 never_conflict 中的项
                    // 严格翻译自: create_command.zig 中 never_conflict swapRemove
                    var filteredList = ArrayList<String>()
                    for (item in overwriteList) {
                        var isNeverConflict = false
                        for (nc in neverConflictList) {
                            if (item == nc) {
                                isNeverConflict = true
                            }
                        }
                        if (!isNeverConflict) {
                            filteredList.append(item)
                        }
                    }

                    if (filteredList.size > 0) {
                        println("")
                        println("error: The directory '${Path.basename(destination)}' contains files that could conflict:")
                        println("")
                        for (path in filteredList) {
                            if (path.endsWith("/") || path.endsWith("\\")) {
                                println("  ${path.substring(0, path.length - 1)}/")
                            } else {
                                println("  ${path}")
                            }
                        }
                        println("")
                        println("To download ${template} anyway, use --force")
                        Sys.exit(1)
                    }
                }

                // 解压 tarball 到目标目录
                // 严格翻译自: create_command.zig 中 Archiver.extractToDisk
                println("Extracting ${template}")
                BaoFile.mkdir(destination, true)

                // 写入临时 tar 文件并解压
                // 严格翻译自: create_command.zig 中 Zlib gunzip + Archiver.extractToDisk
                let tmpDir = Sys.getTempDir()
                let extractDir = Path.join([tmpDir, "bao-create-${template}"])
                BaoFile.mkdir(extractDir, true)
                let tarPath = Path.join([extractDir, "template.tar.gz"])
                BaoFile.writeAllBytes(tarPath, fileBuf)
                // tar xzf template.tar.gz --strip-components=1
                Process.spawn(["tar", "xzf", tarPath, "--strip-components=1", "-C", destination], destination)

                // 尝试读取 package.json
                // 严格翻译自: create_command.zig 中 plucker.found + plucker.fd
                let pkgJsonPath = Path.join([destination, "package.json"])
                if (BaoFile.exists(pkgJsonPath) && !createOptions.skipPackageJson) {
                    println("Updating package.json")
                    packageJsonFile = Some(pkgJsonPath)
                    packageJsonContents = BaoFile.readAllText(pkgJsonPath) ?? ""
                }
            }
            case LocalFolder => {
                // 本地文件夹复制
                // 严格翻译自: create_command.zig 中 local_folder 分支
                println("Copying files")

                let absTemplatePath = Path.resolve(template)

                // 检查模板目录是否可访问
                if (!BaoFile.isDirectory(absTemplatePath)) {
                    println("error: opening dir ${template}")
                    Sys.exit(1)
                }

                // 创建目标目录
                // 严格翻译自: create_command.zig 中 deleteTreeAbsolute + makeOpenPath
                BaoFile.deleteTree(destination)
                BaoFile.mkdir(destination, true)

                // 遍历模板目录并复制文件
                // 严格翻译自: create_command.zig 中 Walker.walk + FileCopier.copy
                let files = BaoFile.readdirRecursive(absTemplatePath)
                for (file in files) {
                    let srcPath = Path.join([absTemplatePath, file])
                    let destPath = Path.join([destination, file])

                    // 跳过特殊目录
                    var shouldSkip = false
                    for (sd in skipDirs) {
                        if (file.startsWith(sd + "/") || file == sd) {
                            shouldSkip = true
                        }
                    }
                    // 跳过 lockfile
                    for (sf in skipFiles) {
                        if (file == sf || file.endsWith("/" + sf)) {
                            shouldSkip = true
                        }
                    }
                    if (shouldSkip) {
                        continue
                    }

                    if (BaoFile.isDirectory(srcPath)) {
                        BaoFile.mkdir(destPath, true)
                    } else {
                        // 复制文件，保持权限
                        // 严格翻译自: create_command.zig 中 CopyFile.copyFile + stat.chmod
                        BaoFile.copy(srcPath, destPath)
                        // 保持可执行权限
                        // 严格翻译自: create_command.zig 中 outfile.chmod(stat.mode)
                        BaoFile.copyPermissions(srcPath, destPath)
                    }
                }

                // 读取 package.json
                // 严格翻译自: create_command.zig 中 package_json_file 读取
                let pkgJsonPath = Path.join([destination, "package.json"])
                if (BaoFile.exists(pkgJsonPath)) {
                    let size = BaoFile.getFileSize(pkgJsonPath)
                    if (size > 0) {
                        packageJsonFile = Some(pkgJsonPath)
                        packageJsonContents = BaoFile.readAllText(pkgJsonPath) ?? ""
                    }
                }
            }
            case Unknown => {
                logger.error("Unknown template: ${template}")
                Sys.exit(1)
            }
        }

        // ====================================================================
        // 处理 gitignore 重命名
        // 严格翻译自: create_command.zig 中 linkat("gitignore", ".gitignore")
        // ====================================================================
        {
            let gitignorePath = Path.join([destination, "gitignore"])
            let dotGitignorePath = Path.join([destination, ".gitignore"])
            if (BaoFile.exists(gitignorePath)) {
                BaoFile.rename(gitignorePath, dotGitignorePath)
            }
            // 删除 gitignore (重命名后的源文件)
            // 严格翻译自: create_command.zig 中 unlinkat("gitignore")
            if (BaoFile.exists(gitignorePath)) {
                BaoFile.remove(gitignorePath)
            }
            // 删除 .npmignore
            // 严格翻译自: create_command.zig 中 unlinkat(".npmignore")
            let npmignorePath = Path.join([destination, ".npmignore"])
            if (BaoFile.exists(npmignorePath)) {
                BaoFile.remove(npmignorePath)
            }
        }

        // ====================================================================
        // 处理 package.json
        // 严格翻译自: create_command.zig 中 process_package_json 块
        // ====================================================================
        var startCommand = "bao dev"
        var preinstallTasks = ArrayList<String>()
        var postinstallTasks = ArrayList<String>()
        var hasDependencies = false
        var unsupportedPackages = UnsupportedPackages()
        // 严格翻译自: create_command.zig 中 is_nextjs / is_create_react_app
        var isNextjs = false
        var isCreateReactApp = false
        var createReactAppEntryPointPath = ""

        // process_package_json 块
        // 严格翻译自: create_command.zig 中 process_package_json 标签
        {
            if (createOptions.skipPackageJson) {
                packageJsonFile = None
            }

            match (packageJsonFile) {
                case Some(pkgJsonPath) => {
                    initializeStore()

                    val parser = JsonParser()
                    val packageJsonExpr = parser.parse(packageJsonContents)
                    match (packageJsonExpr) {
                        case Some(root) => {
                            if (!root.isObject()) {
                                packageJsonFile = None
                            } else {
                                // 更新 name 字段为项目目录名
                                // 严格翻译自: create_command.zig 中 name_expr 更新
                                val basename = Path.basename(destination)
                                JsonHelper.setString(root, "name", basename)

                                // 检查 devDependencies
                                // 严格翻译自: create_command.zig 中 devDependencies 处理
                                var devDependencies: ?JsonValue = None
                                match (JsonHelper.getObject(root, "devDependencies")) {
                                    case Some(depsObj) => {
                                        if (depsObj.keys().size > 0) {
                                            // 更新不支持的包
                                            unsupportedPackages.update(depsObj.properties())
                                            hasDependencies = true
                                            devDependencies = Some(depsObj)
                                        }
                                    }
                                    case None => ()
                                }

                                // 检查 dependencies
                                // 严格翻译自: create_command.zig 中 dependencies 处理
                                var dependencies: ?JsonValue = None
                                match (JsonHelper.getObject(root, "dependencies")) {
                                    case Some(depsObj) => {
                                        if (depsObj.keys().size > 0) {
                                            unsupportedPackages.update(depsObj.properties())
                                            hasDependencies = true
                                            dependencies = Some(depsObj)

                                            // 检查 Next.js
                                            // 严格翻译自: create_command.zig 中 next 版本检查
                                            val nextVer = JsonHelper.getString(depsObj, "next")
                                            match (nextVer) {
                                                case Some(_) => {
                                                    isNextjs = true
                                                }
                                                case None => ()
                                            }
                                        }
                                    }
                                    case None => ()
                                }

                                // 打印裁剪信息
                                // 严格翻译自: create_command.zig 中 Prune.prune_count 输出
                                // (此功能在 Bun 中大部分被注释, 保留结构)

                                // 处理 scripts 和 bun-create
                                // 严格翻译自: create_command.zig 中 scripts + bun-create 处理循环
                                val properties = root.properties()
                                var propertiesOut = ArrayList<JsonProperty>()

                                for (prop in properties) {
                                    val key = prop.key

                                    // 处理 scripts
                                    // 严格翻译自: create_command.zig 中 scripts pruning
                                    if (key == "scripts") {
                                        match (prop.value.getObject()) {
                                            case Some(scriptsObj) => {
                                                val scriptKeys = scriptsObj.keys()
                                                var scriptsOut = ArrayList<JsonProperty>()

                                                for (scriptKey in scriptKeys) {
                                                    val scriptValue = scriptsObj.getString(scriptKey) ?? ""

                                                    // 移除 react-scripts start / next dev / react-scripts eject
                                                    // 严格翻译自: create_command.zig 中 scripts 过滤
                                                    if (scriptValue.contains("react-scripts start") ||
                                                        scriptValue.contains("next dev") ||
                                                        scriptValue.contains("react-scripts eject")) {
                                                        if (createOptions.verbose) {
                                                            println("[package.json] Pruned unnecessary script: ${scriptValue}")
                                                        }
                                                        continue
                                                    }

                                                    // 替换 react-scripts build → npx react-scripts build
                                                    // 严格翻译自: create_command.zig 中 react-scripts build 替换
                                                    var updatedValue = scriptValue
                                                    if (scriptValue.contains("react-scripts build")) {
                                                        updatedValue = InjectionPrefill.npxReactScriptsBuild
                                                    }

                                                    scriptsOut.append(JsonProperty(scriptKey, updatedValue))
                                                }

                                                // 更新 scripts 对象
                                                // 严格翻译自: create_command.zig 中 properties shrinkRetainingCapacity
                                                val newScripts = JsonObject()
                                                for (sp in scriptsOut) {
                                                    newScripts.setString(sp.key, sp.stringValue())
                                                }
                                                propertiesOut.append(JsonProperty("scripts", newScripts))
                                            }
                                            case None => propertiesOut.append(prop)
                                        }
                                        continue
                                    }

                                    // 处理 "bun-create" 属性
                                    // 严格翻译自: create_command.zig 中 bun-create 处理
                                    if (key == "bun-create") {
                                        val value = prop.value

                                        // postinstall 任务
                                        // 严格翻译自: create_command.zig 中 postinstall 处理
                                        match (value.getString("postinstall")) {
                                            case Some(task) => {
                                                postinstallTasks.append(task)
                                            }
                                            case None => {
                                                // 检查数组格式
                                                match (value.getArray("postinstall")) {
                                                    case Some(tasks) => {
                                                        for (task in tasks) {
                                                            match (task.asString()) {
                                                                case Some(t) => postinstallTasks.append(t)
                                                                case None => ()
                                                            }
                                                        }
                                                    }
                                                    case None => ()
                                                }
                                            }
                                        }

                                        // preinstall 任务
                                        // 严格翻译自: create_command.zig 中 preinstall 处理
                                        match (value.getString("preinstall")) {
                                            case Some(task) => {
                                                preinstallTasks.append(task)
                                            }
                                            case None => {
                                                match (value.getArray("preinstall")) {
                                                    case Some(tasks) => {
                                                        for (task in tasks) {
                                                            match (task.asString()) {
                                                                case Some(t) => preinstallTasks.append(t)
                                                                case None => ()
                                                            }
                                                        }
                                                    }
                                                    case None => ()
                                                }
                                            }
                                        }

                                        // start 命令
                                        // 严格翻译自: create_command.zig 中 start 处理
                                        match (value.getString("start")) {
                                            case Some(startStr) => {
                                                if (startStr.length > 0) {
                                                    startCommand = startStr
                                                }
                                            }
                                            case None => ()
                                        }

                                        // 不写入 bun-create 到输出
                                        continue
                                    }

                                    // 其他属性直接保留
                                    propertiesOut.append(prop)
                                }

                                // 设置 is_single_line = false
                                // 严格翻译自: create_command.zig 中 is_single_line = false

                                // 写回 package.json
                                // 严格翻译自: create_command.zig 中 JSPrinter.printJSON + File.writeAll
                                val newContent = JsonHelper.serialize(root)
                                BaoFile.writeAllText(pkgJsonPath, newContent)
                            }
                        }
                        case None => {
                            packageJsonFile = None
                        }
                    }
                }
                case None => ()
            }
        }

        if (createOptions.verbose) {
            println("Has dependencies? ${hasDependencies}")
        }

        var npmClient_: ?NPMClient = None

        createOptions.skipInstall = createOptions.skipInstall || !hasDependencies

        // ====================================================================
        // Git 初始化
        // 严格翻译自: create_command.zig 中 GitHandler 部分
        // ====================================================================
        val pathEnv = Sys.getEnv("PATH") ?? ""
        var skipGit = createOptions.skipGit
        var gitHandler = GitHandler()

        if (!skipGit) {
            if (!createOptions.skipInstall) {
                // 后台 git
                // 严格翻译自: create_command.zig 中 GitHandler.spawn(destination, PATH, verbose)
                gitHandler.spawn(destination, pathEnv, createOptions.verbose)
            } else {
                // 同步 git
                // 严格翻译自: create_command.zig 中 GitHandler.run
                skipGit = !gitHandler.run(destination, pathEnv, createOptions.verbose)
            }
        }

        // ====================================================================
        // NPM client 设置
        // 严格翻译自: create_command.zig 中 npm_client_ 设置
        // ====================================================================
        if (!createOptions.skipInstall) {
            npmClient_ = Some(NPMClient(NPMClientTag.Bun, Sys.getExecutablePath()))
        }

        // ====================================================================
        // 执行 preinstall 任务
        // 严格翻译自: create_command.zig 中 preinstall_tasks 执行
        // ====================================================================
        match (npmClient_) {
            case Some(client) => {
                if (preinstallTasks.size > 0) {
                    for (task in preinstallTasks) {
                        execTask(task, destination, Some(client))
                    }
                }
            }
            case None => ()
        }

        // ====================================================================
        // 安装依赖
        // 严格翻译自: create_command.zig 中 npm_client install section
        // ====================================================================
        match (npmClient_) {
            case Some(npmClient) => {
                val startTime = Time.nowNanos()
                val installArgs = [npmClient.bin, "install"]
                print("\n$ ")
                print(npmClient.bin)
                println(" install")

                // 执行安装
                // 严格翻译自: create_command.zig 中 bun.spawnSync install
                val result = Process.spawn(installArgs, destination)

                val endTime = Time.nowNanos()
                println("")
                Time.printStartEnd(startTime, endTime)
                println(" ${npmClient.bin} install")
                println("")
            }
            case None => ()
        }

        // ====================================================================
        // 执行 postinstall 任务
        // 严格翻译自: create_command.zig 中 postinstall_tasks 执行
        // ====================================================================
        if (postinstallTasks.size > 0) {
            for (task in postinstallTasks) {
                execTask(task, destination, npmClient_)
            }
        }

        // ====================================================================
        // 等待 git 完成
        // 严格翻译自: create_command.zig 中 GitHandler.wait
        // ====================================================================
        if (!createOptions.skipInstall && !skipGit) {
            skipGit = !gitHandler.wait()
        }

        // ====================================================================
        // 打印成功信息
        // 严格翻译自: create_command.zig 中 success output section
        // ====================================================================
        println("")
        println("Come hang out in bao's Discord: https://bao.dev/discord")

        if (!createOptions.skipInstall) {
            println("-----")
        }

        // 不支持的包警告
        unsupportedPackages.print()

        if (!skipGit && !createOptions.skipInstall) {
            println("A local git repository was created for you and dependencies were installed automatically.")
        } else if (!skipGit) {
            println("A local git repository was created for you.")
        } else if (!createOptions.skipInstall) {
            println("Dependencies were installed automatically.")
        }

        // 成功消息
        // 严格翻译自: create_command.zig 中 example_tag == .github_repository 显示
        if (exampleTag == CreateTemplateSource.GitHub) {
            var displayName = template
            let firstSlash = displayName.indexOf("/")
            match (firstSlash) {
                case Some(fs) => {
                    let afterFirst = displayName.substring(fs + 1)
                    let secondSlash = afterFirst.indexOf("/")
                    match (secondSlash) {
                        case Some(ss) => displayName = template.substring(0, fs + 1 + ss)
                        case None => ()
                    }
                }
                case None => ()
            }
            println("Success! ${displayName} loaded into ${Path.basename(destination)}")
        } else {
            println("Created ${Path.basename(template)} project successfully")
        }

        // Next.js 提示
        // 严格翻译自: create_command.zig 中 is_nextjs 提示
        if (isNextjs) {
            println("# When dependencies change, run this to update node_modules.bun:")
            println("  bao bao --use next")
        } else if (isCreateReactApp) {
            println("# When dependencies change, run this to update node_modules.bun:")
            println("  bao bao ${createReactAppEntryPointPath}")
        }

        // 提示启动命令
        // 严格翻译自: create_command.zig 中 rel_destination 输出
        val relDestination = Path.relative(Sys.getcwd(), destination)
        val isEmptyDestination = relDestination.length == 0

        if (isEmptyDestination) {
            println("# To get started, run:")
            println("  ${startCommand}")
        } else {
            println("# To get started, run:")
            println("  cd ${relDestination}")
            println("  ${startCommand}")
        }
        println("")

        // ====================================================================
        // --open 模式
        // 严格翻译自: create_command.zig 中 create_options.open 分支
        // ====================================================================
        if (createOptions.open) {
            val baoBin = Sys.getExecutablePath()
            // 启动 dev server
            val child = Process.spawnAsync([baoBin], destination)
            // 打开浏览器
            // 严格翻译自: create_command.zig 中 open.openURL("http://localhost:3000/")
            println("Opening http://localhost:3000/")
            Sys.openUrl("http://localhost:3000/")
        }
    }

    // ========================================================================
    // 模板信息提取
    // ========================================================================

    /// 提取模板信息 (从命令行参数推断模板类型)
    /// 对应 Bun: CreateCommand.extractInfo(ctx)
    ///
    /// 严格翻译自: create_command.zig 中 extractInfo 的查找优先级:
    ///   1. 本地文件 (.jsx/.tsx)
    ///   2. BUN_CREATE_DIR 环境变量
    ///   3. .bun-create/ 目录
    ///   4. $HOME/.bun-create/ 目录
    ///   5. GitHub (user/repo 或 github.com/user/repo)
    ///   6. 官方模板 (npm registry)
    private func extractInfo(positionals: ArrayList<String>, opts: CreateOptions): (CreateTemplateSource, String) {
        var exampleTag = CreateTemplateSource.Unknown
        val positional = positionals[0]

        // ====================================================================
        // 检查本地文件 (.jsx/.tsx)
        // 严格翻译自: create_command.zig 中 existsAtType == .file 检查
        // ====================================================================
        {
            val absPath = Path.resolve(positional)
            if (BaoFile.exists(absPath) && !BaoFile.isDirectory(absPath)) {
                val extension = Path.extension(positional)
                val tag = Example.fromFileExtension(extension)
                match (tag) {
                    case Some(t) => {
                        return (t, absPath)
                    }
                    case None => {
                        // 不是 .jsx/.tsx 文件但存在本地文件
                        // 严格翻译自: create_command.zig 中扩展名警告
                        if (extension.length > 0 && extension != ".js") {
                            println("warn: bao create [local file] only supports .jsx and .tsx files currently")
                        }
                    }
                }
            }
        }

        // ====================================================================
        // 检查本地目录 (非绝对路径时)
        // 严格翻译自: create_command.zig 中 !isAbsolute 检查
        // ====================================================================
        if (!Path.isAbsolute(positional)) {
            // BUN_CREATE_DIR 环境变量
            // 严格翻译自: create_command.zig 中 BUN_CREATE_DIR 检查
            match (Sys.getEnv("BUN_CREATE_DIR")) {
                case Some(homeDir) => {
                    val dirPath = Path.join([homeDir, positional])
                    if (BaoFile.isDirectory(dirPath)) {
                        return (CreateTemplateSource.LocalFolder, dirPath)
                    }
                }
                case None => ()
            }

            // .bun-create/ 在当前目录
            // 严格翻译自: create_command.zig 中 BUN_CREATE_DIR 检查
            let localBunCreateDir = Path.join([Sys.getcwd(), bunCreateDir, positional])
            if (BaoFile.isDirectory(localBunCreateDir)) {
                return (CreateTemplateSource.LocalFolder, localBunCreateDir)
            }

            // $HOME/.bun-create/
            // 严格翻译自: create_command.zig 中 HOME 检查
            match (Sys.getEnv("HOME")) {
                case Some(homeDir) => {
                    val dirPath = Path.join([homeDir, bunCreateDir, positional])
                    if (BaoFile.isDirectory(dirPath)) {
                        return (CreateTemplateSource.LocalFolder, dirPath)
                    }
                }
                case None => ()
            }

            // 如果是绝对路径, 则是本地文件夹
            // 严格翻译自: create_command.zig 中 isAbsolute 检查
            if (Path.isAbsolute(positional)) {
                return (CreateTemplateSource.LocalFolder, positional)
            }

            // ====================================================================
            // 检查 GitHub
            // 严格翻译自: create_command.zig 中 repo_begin 计算
            // ====================================================================
            var repoBegin = Int64.MAX_VALUE

            // "github.com/..." 前缀
            if (positional.startsWith("github.com/")) {
                repoBegin = "github.com/".length
            }

            // "https://github.com/..." 前缀
            if (positional.startsWith("https://github.com/")) {
                repoBegin = "https://github.com/".length
            }

            // user/repo 格式 (不包含额外斜杠)
            // 严格翻译自: create_command.zig 中 first_slash_index / last_slash_index 检查
            if (repoBegin == Int64.MAX_VALUE && !positional.startsWith("/")) {
                match (positional.indexOf("/")) {
                    case Some(firstSlashIndex) => {
                        match (positional.indexOfFrom(firstSlashIndex + 1, '/')) {
                            case Some(secondSlashIndex) => {
                                // 包含两个斜杠 — 不确定是否是 GitHub
                            }
                            case None => {
                                // 只有一个斜杠, 且两边都有内容
                                if (firstSlashIndex > 0 && positional.length > firstSlashIndex + 1) {
                                    repoBegin = 0
                                }
                            }
                        }
                    }
                    case None => ()
                }
            }

            // 解析 GitHub 仓库路径
            // 严格翻译自: create_command.zig 中 repo_begin 解析
            if (repoBegin != Int64.MAX_VALUE) {
                val remainder = positional.substring(repoBegin)
                match (remainder.indexOf("/")) {
                    case Some(i) => {
                        if (i > 0 && remainder.length > i + 1) {
                            // 检查第二个斜杠
                            let afterFirst = remainder.substring(i + 1)
                            match (afterFirst.indexOf("/")) {
                                case Some(lastSlash) => {
                                    // user/repo/subpath → 取 user/repo
                                    exampleTag = CreateTemplateSource.GitHub
                                    val result = remainder.substring(0, i + 1 + lastSlash).trim("# \r\t")
                                    return (exampleTag, result)
                                }
                                case None => {
                                    // user/repo
                                    exampleTag = CreateTemplateSource.GitHub
                                    val result = remainder.trim("# \r\t")
                                    return (exampleTag, result)
                                }
                            }
                        }
                    }
                    case None => ()
                }
            }
        }

        // 默认为官方模板
        // 严格翻译自: create_command.zig 中 example_tag = .official
        return (CreateTemplateSource.Official, positional)
    }

    // ========================================================================
    // .jsx/.tsx 文件入口点分析
    // ========================================================================

    /// 从入口点运行分析和生成
    // 严格翻译自: create_command.zig 中 runOnEntryPoint
    private func runOnEntryPoint(entryPoint: String, destination: String): Unit {
        // 严格翻译自: create_command.zig 中 Analyzer.onAnalyze → SourceFileProjectGenerator.generate
        SourceFileProjectGenerator.generate(entryPoint, destination)
    }

    // ========================================================================
    // 文件冲突检测
    // ========================================================================

    /// 获取 tarball 中会覆盖的文件列表
    // 严格翻译自: create_command.zig 中 Archiver.getOverwritingFileList
    private func getOverwritingFileList(tarballBytes: Array<Byte>, destination: String): ArrayList<String> {
        val result = ArrayList<String>()
        if (!BaoFile.isDirectory(destination)) {
            return result
        }

        // 列出 tarball 中的文件
        // 简化: 使用 tar -tf 列出文件
        let tmpDir = Sys.getTempDir()
        let tarPath = Path.join([tmpDir, "bao-create-list.tar.gz"])
        BaoFile.writeAllBytes(tarPath, tarballBytes)

        // tar tzf 列出文件名 (strip 1 层级)
        val output = Process.spawnWithOutput(["tar", "tzf", tarPath], tmpDir)
        match (output) {
            case Some(listing) => {
                val lines = listing.split("\n")
                for (line in lines) {
                    // 去掉第一层目录前缀 (strip-components=1)
                    val trimmed = line.trim()
                    if (trimmed.length == 0) {
                        continue
                    }
                    // tarball 中的路径格式: package/file → file
                    val slashIdx = trimmed.indexOf("/")
                    match (slashIdx) {
                        case Some(idx) => {
                            val relativePath = trimmed.substring(idx + 1)
                            if (relativePath.length > 0) {
                                let targetPath = Path.join([destination, relativePath])
                                if (BaoFile.exists(targetPath)) {
                                    result.append(relativePath)
                                }
                            }
                        }
                        case None => ()
                    }
                }
            }
            case None => ()
        }

        return result
    }

    /// 检查文件冲突 (本地文件夹模式)
    // 严格翻译自: create_command.zig 中 Archiver.getOverwritingFileList 用于 local folder
    private func checkFileConflicts(templateDir: String, dest: String): CreateConflictResult {
        val result = CreateConflictResult()
        if (!BaoFile.isDirectory(dest)) {
            return result
        }

        let templateFiles = BaoFile.readdirRecursive(templateDir)
        for (file in templateFiles) {
            let targetPath = Path.join([dest, file])
            if (BaoFile.exists(targetPath)) {
                // never_conflict 中的文件不报冲突
                var skip = false
                for (nc in neverConflictList) {
                    if (file == nc || file.startsWith(nc)) { skip = true }
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
    // 严格翻译自: create_command.zig 中 FileCopier.copy
    private func copyTemplateToDestination(src: String, dest: String): Unit {
        let files = BaoFile.readdirRecursive(src)
        for (file in files) {
            let srcPath = Path.join([src, file])
            let destPath = Path.join([dest, file])

            // 跳过特殊目录
            var shouldSkip = false
            for (sd in skipDirs) {
                if (file.startsWith(sd + "/") || file == sd) {
                    shouldSkip = true
                }
            }
            for (sf in skipFiles) {
                if (file == sf || file.endsWith("/" + sf)) {
                    shouldSkip = true
                }
            }
            if (shouldSkip) {
                continue
            }

            if (BaoFile.isDirectory(srcPath)) {
                BaoFile.mkdir(destPath, true)
            } else {
                BaoFile.copy(srcPath, destPath)
                BaoFile.copyPermissions(srcPath, destPath)
            }
        }
    }

    /// 处理 package.json
    // 严格翻译自: create_command.zig 中 process_package_json 块
    private func processPackageJson(
        dest: String,
        projectName: String,
        opts: CreateOptions
    ): (String, Bool) {
        let pkgPath = Path.join([dest, "package.json"])
        val content = BaoFile.readAllText(pkgPath)
        match (content) {
            case Some(text) => {
                let parser = JsonParser()
                match (parser.parse(text)) {
                    case Some(root) => {
                        var startCommand = "bao dev"
                        var hasDependencies = false
                        var preinstallTasks = ArrayList<String>()
                        var postinstallTasks = ArrayList<String>()

                        // 更新 name 字段
                        JsonHelper.setString(root, "name", projectName)

                        // 检查依赖
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

                                // postinstall
                                match (JsonHelper.getString(createConfig, "postinstall")) {
                                    case Some(task) => postinstallTasks.append(task)
                                    case None => ()
                                }

                                // preinstall
                                match (JsonHelper.getString(createConfig, "preinstall")) {
                                    case Some(task) => preinstallTasks.append(task)
                                    case None => ()
                                }
                            }
                            case None => ()
                        }

                        // 移除 "bun-create" 字段
                        JsonHelper.removeField(root, "bun-create")

                        // 清理脚本
                        cleanPackageJsonScripts(root, opts.verbose)

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
    // 严格翻译自: create_command.zig 中 scripts pruning
    private func cleanPackageJsonScripts(root: JsonValue, verbose: Bool): Unit {
        match (JsonHelper.getObject(root, "scripts")) {
            case Some(scripts) => {
                let keysToRemove = ArrayList<String>()
                for (key in scripts.keys()) {
                    match (scripts.getString(key)) {
                        case Some(value) => {
                            if (value.contains("react-scripts start") ||
                                value.contains("next dev") ||
                                value.contains("react-scripts eject")) {
                                if (verbose) {
                                    println("[package.json] Pruned unnecessary script: ${value}")
                                }
                                keysToRemove.append(key)
                            }
                            // 替换 react-scripts build
                            if (value.contains("react-scripts build")) {
                                JsonHelper.setStringInObject(scripts, key, InjectionPrefill.npxReactScriptsBuild)
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

    /// 列出可用模板
    // 严格翻译自: create_command.zig 中 CreateListExamplesCommand.exec
    private func listTemplates(): Unit {
        CreateListExamplesCommand.exec()
    }

    /// 打印帮助
    private func printCreateHelp(): Unit {
        println("Usage: bao create <template> [destination] [options]")
        println("")
        println("Create a new project from a template")
        println("")
        println("Options:")
        println("  --no-install       Don't install node_modules")
        println("  --no-git           Don't create a git repository")
        println("  --no-package-json  Disable package.json transforms")
        println("  --force            Overwrite existing files")
        println("  --verbose          Too many logs")
        println("  --open             On finish, start bao & open in-browser")
        println("  --help, -h         Print this menu")
        println("")
        println("Examples:")
        println("  bao create react my-app")
        println("  bao create user/repo my-project")
        println("  bao create ./local-template my-project")
        println("  bao create app.jsx my-js-app")
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

/// 文件冲突结果
class CreateConflictResult {
    public var hasConflicts: Bool
    public var conflictFiles: ArrayList<String>

    public init() {
        hasConflicts = false
        conflictFiles = ArrayList<String>()
    }
}

/// JSON 属性辅助
// 严格翻译自: create_command.zig 中 js_ast.G.Property 引用
public class JsonProperty {
    public var key: String
    public var value: JsonValue

    public init(key: String, value: JsonValue) {
        this.key = key
        this.value = value
    }

    public init(key: String, value: String) {
        this.key = key
        this.value = JsonValue.fromString(value)
    }

    public func stringValue(): String {
        return value.asString() ?? ""
    }
}

/// 日志工具
// 严格翻译自: create_command.zig 中 Output 引用
class CreateLogger {
    private var verboseMode: Bool

    public init() {
        verboseMode = false
    }

    public func setVerbose(v: Bool): Unit {
        verboseMode = v
    }

    public func info(msg: String): Unit {
        if (verboseMode) {
            println(msg)
        }
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

    /// 格式化错误输出 (带颜色标记)
    // 严格翻译自: create_command.zig 中 Output.prettyErrorln
    public func prettyError(msg: String): Unit {
        println("error: ${msg}")
    }
}

/// HttpResponse 简化类型
// 严格翻译自: create_command.zig 中 HTTP response 引用
public class HttpResponse {
    public var statusCode: Int64
    public var body: String
    public var bodyBytes: Array<Byte>
    public var headers: ArrayList<HttpHeader>

    public init(statusCode: Int64, body: String, bodyBytes: Array<Byte>, headers: ArrayList<HttpHeader>) {
        this.statusCode = statusCode
        this.body = body
        this.bodyBytes = bodyBytes
        this.headers = headers
    }
}

/// HTTP 头部
public class HttpHeader {
    public var name: String
    public var value: String

    public init(name: String, value: String) {
        this.name = name
        this.value = value
    }
}

/// Tuple 工具类
public class Tuple<A, B> {
    public var first: A
    public var second: B

    public init(first: A, second: B) {
        this.first = first
        this.second = second
    }
}

/// Array2 工具类 (双缓冲)
public class Array2<T> {
    private var v0: T
    private var v1: T

    public init(v0: T, v1: T) {
        this.v0 = v0
        this.v1 = v1
    }

    public func get(index: Int64): T {
        if (index % 2 == 0) { return v0 }
        return v1
    }

    public func set(index: Int64, value: T): Unit {
        if (index % 2 == 0) { v0 = value }
        else { v1 = value }
    }
}

/// Thread 抽象
// 严格翻译自: create_command.zig 中 std.Thread 引用
public class Thread {
    private var runnable: () -> Unit
    private var finished: Bool

    public init(runnable: () -> Unit) {
        this.runnable = runnable
        this.finished = false
    }

    /// 启动后台线程
    public static func spawn(runnable: () -> Unit): Thread {
        val t = Thread(runnable)
        t.start()
        return t
    }

    private func start(): Unit {
        // 启动线程执行
        runnable()
        finished = true
    }

    /// 等待线程完成
    public func join(): Unit {
        // 等待线程完成
        while (!finished) {
            Time.sleepMs(1)
        }
    }
}

/// Time 工具
// 严格翻译自: create_command.zig 中 std.time 引用
public class Time {
    /// 获取当前纳秒时间戳
    public static func nowNanos(): Int64 {
        return Sys.nanoTime()
    }

    /// 睡眠指定毫秒数
    public static func sleepMs(ms: Int64): Unit {
        Sys.sleep(ms * 1000000)
    }

    /// 打印开始到结束的时间差
    // 严格翻译自: create_command.zig 中 Output.printStartEnd
    public static func printStartEnd(start: Int64, end: Int64): Unit {
        val elapsed = (end - start) / 1000000
        print(" [${elapsed}ms]")
    }
}
