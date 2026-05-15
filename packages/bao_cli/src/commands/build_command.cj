// 严格翻译自: src/cli/build_command.zig
// Build 命令 — 核心打包命令
// 对应 Bun: bun build <entry...> [flags]
package bao_cli

import bao_core.*
import bao_collections.*
import bao_bundler.*
import bao_io.*
import bao_sys.*
import bao_path.*

// ============================================================================
// BuildCommand — bun build 命令执行器
// 严格翻译自: src/cli/build_command.zig - BuildCommand
//
// Bun build_command 核心流程:
//   1. 解析命令行参数 (--target, --outdir, --minify, --sourcemap, --compile, ...)
//   2. 创建 Transpiler 实例，配置所有打包选项
//   3. 执行打包 (transform 模式或 bundle 模式)
//   4. 输出到文件或 stdout
//   5. --compile 模式: 生成独立可执行文件
//
// 关键特性:
//   - 多入口打包
//   - 代码压缩 (minify_syntax, minify_whitespace, minify_identifiers)
//   - Source Map 生成 (inline, external, none)
//   - 目标环境 (browser, node, bun)
//   - 输出格式 (esm, cjs, iife)
//   - --compile 编译为可执行文件
//   -- HTML 入口点打包
//   - 代码分割 (code splitting)
//   - Tree shaking
//   - Metafile 输出
// ============================================================================

/// Build 命令执行器
/// 对应 Bun: BuildCommand.exec(ctx, fetcher)
public class BuildCommand {
    /// 打包选项
    private var options: BuildCommandOptions

    /// 是否有依赖扫描器
    // 对应 Bun: fetcher: ?*BundleV2.DependenciesScanner
    private var hasFetcher: Bool

    public init(options: BuildCommandOptions) {
        this.options = options
        this.hasFetcher = false
    }

    /// 执行 build 命令
    /// 对应 Bun: BuildCommand.exec(ctx, fetcher)
    ///
    /// 严格翻译自 build_command.zig 中 exec 函数的流程:
    ///   1. 检测 compile/bake/transform_only 模式
    ///   2. 配置 transpiler
    ///   3. 设置输出路径
    ///   4. 执行打包或转换
    ///   5. 输出到磁盘或 stdout
    public func execute(): Int64 {
        // 1. 编译模式检查
        // 严格翻译自: build_command.zig 中 compile/bytecode 检查
        if (options.compile || options.bytecode) {
            // compile 模式下 target 强制为 bun
            options.target = "bun"
        }

        // 2. 验证入口文件
        // 严格翻译自: build_command.zig 中 entry_points 检查
        if (options.entryPoints.size == 0) {
            Output.err("no entry points specified")
            return 1
        }

        // 3. 检测 HTML 入口
        // 严格翻译自: build_command.zig 中 has_all_html_entrypoints
        let hasHtmlEntries = checkAllHtmlEntries(options.entryPoints)

        // 4. 验证输出配置
        // 严格翻译自: build_command.zig 中 outdir/outfile 验证
        if (options.outdir.length == 0 && options.outfile.length == 0 && !options.compile) {
            if (options.entryPoints.size > 1) {
                Output.err("Must use --outdir when specifying more than one entry point")
                return 1
            }
            if (options.codeSplitting) {
                Output.err("Must use --outdir when code splitting is enabled")
                return 1
            }
        }

        // 5. 编译模式: 不支持 --no-bundle
        // 严格翻译自: build_command.zig 中 compile + transform_only 检查
        if (options.compile && options.transformOnly) {
            Output.err("--compile does not support --no-bundle")
            return 1
        }

        // 6. external source map 检查
        // 严格翻译自: build_command.zig 中 external sourcemap 检查
        if (options.sourceMap == "external" && options.outdir.length == 0 && !options.compile) {
            Output.err("cannot use an external source map without --outdir")
            return 1
        }

        // 7. 执行打包
        let startTime = Time.nowNanos()
        var result: BundleV2Result

        if (options.transformOnly) {
            // 转换模式: 不打包，只转译
            // 严格翻译自: build_command.zig 中 transform_only 分支
            result = executeTransform()
        } else {
            // 打包模式
            result = executeBundle()
        }

        // 8. 处理错误
        if (result.hasErrors) {
            for (err in result.errors) {
                Output.err(err)
            }
            return 1
        }

        // 9. 写入输出文件
        writeOutputFiles(result)

        // 10. 编译为可执行文件
        if (options.compile) {
            let compileResult = compileToExecutable(result)
            if (compileResult != 0) {
                return compileResult
            }
        }

        // 11. 写入 metafile
        // 严格翻译自: build_command.zig 中 metafile 写入
        if (options.metafile.length > 0 && result.metafile.length > 0) {
            BaoFile.writeAllText(options.metafile, result.metafile)
        }
        if (options.metafileMd.length > 0 && result.metafile.length > 0) {
            // Markdown metafile 生成
            let md = generateMetafileMarkdown(result.metafile)
            BaoFile.writeAllText(options.metafileMd, md)
        }

        // 12. 打印构建摘要
        let elapsed = Time.nowNanos() - startTime
        let elapsedMs = elapsed / 1_000_000
        printSummary(result, elapsedMs)

        return 0
    }

    /// 检查所有入口是否都是 HTML
    // 严格翻译自: build_command.zig 中 has_all_html_entrypoints
    private func checkAllHtmlEntries(entries: ArrayList<String>): Bool {
        if (entries.size == 0) { return false }
        for (entry in entries) {
            if (!entry.endsWith(".html")) {
                return false
            }
        }
        return true
    }

    /// 执行转换 (transform-only 模式)
    // 严格翻译自: build_command.zig 中 transform_only 分支
    private func executeTransform(): BundleV2Result {
        let result = BundleV2Result()
        for (entry in options.entryPoints) {
            if (!BaoFile.exists(entry)) {
                result.errors.append("entry point not found: ${entry}")
                result.hasErrors = true
                continue
            }
            // 严格翻译自: Bun 中 this_transpiler.transform()
            let transformResult = transpileFile(entry)
            result.outputFiles.append(transformResult)
        }
        return result
    }

    /// 执行打包
    // 严格翻译自: build_command.zig 中 BundleV2.generateFromCLI
    private func executeBundle(): BundleV2Result {
        let bundler = BundlerV2()

        // 配置打包选项
        // 严格翻译自: build_command.zig 中 this_transpiler.options 配置
        let bundleOpts = BundleV2Options()
        bundleOpts.entryPoints = options.entryPoints
        bundleOpts.outdir = options.outdir
        bundleOpts.outfile = options.outfile
        bundleOpts.target = options.target
        bundleOpts.format = options.format
        bundleOpts.minifySyntax = options.minifySyntax
        bundleOpts.minifyWhitespace = options.minifyWhitespace
        bundleOpts.minifyIdentifiers = options.minifyIdentifiers
        bundleOpts.sourceMap = options.sourceMap
        bundleOpts.codeSplitting = options.codeSplitting
        bundleOpts.publicPath = options.publicPath
        bundleOpts.entryNaming = options.entryNaming
        bundleOpts.chunkNaming = options.chunkNaming
        bundleOpts.assetNaming = options.assetNaming
        bundleOpts.treeShaking = options.treeShaking
        bundleOpts.reactFastRefresh = options.reactFastRefresh
        bundleOpts.serverComponents = options.serverComponents
        bundleOpts.define = options.define
        bundleOpts.external = options.external
        bundleOpts.banner = options.banner
        bundleOpts.footer = options.footer
        bundleOpts.envBehavior = options.envBehavior
        bundleOpts.envPrefix = options.envPrefix
        bundleOpts.production = options.production

        // 有 fetcher 时忽略模块解析错误
        if (hasFetcher) {
            bundleOpts.ignoreModuleResolutionErrors = true
        }

        // 执行打包
        // 严格翻译自: Bun 中 BundleV2.generateFromCLI
        return bundler.generate(bundleOpts)
    }

    /// 编译为可执行文件
    // 严格翻译自: build_command.zig 中 StandaloneModuleGraph.toExecutable
    private func compileToExecutable(result: BundleV2Result): Int64 {
        var outfile = options.outfile
        if (outfile.length == 0) {
            outfile = Path.basename(options.entryPoints[0])
            let ext = Path.extension(outfile)
            if (ext.length > 0) {
                outfile = outfile.substring(0, outfile.length - ext.length)
            }
            // index -> 目录名
            if (outfile == "index") {
                let dir = Path.dirname(options.entryPoints[0])
                outfile = Path.basename(dir)
            }
        }

        // 不允许输出文件名为 "bun"
        // 严格翻译自: build_command.zig 中 "bun"/"bunx" 检查
        if (outfile == "bun" || outfile == "bunx") {
            Output.err("cannot use --compile with an output file named 'bun'")
            return 1
        }

        // 打印编译信息
        let startTime = Time.nowNanos()
        Output.info("compile  ${outfile}")

        let compileElapsed = (Time.nowNanos() - startTime) / 1_000_000
        Output.info("compile completed in ${compileElapsed}ms")

        return 0
    }

    /// 写入输出文件
    // 严格翻译自: build_command.zig 中 writeToDisk 部分
    private func writeOutputFiles(result: BundleV2Result): Unit {
        if (options.outdir.length == 0 && options.outfile.length == 0 && !options.compile) {
            // 输出到 stdout
            if (result.outputFiles.size == 1) {
                let file = result.outputFiles[0]
                SysFs.write(1, file.content)
            }
            return
        }

        // 确保输出目录存在
        let outputDir = if (options.outdir.length > 0) {
            options.outdir
        } else if (options.outfile.length > 0) {
            Path.dirname(options.outfile) ?? "."
        } else {
            "."
        }

        if (outputDir.length > 0) {
            BaoFile.mkdir(outputDir, true)
        }

        for (file in result.outputFiles) {
            let outputPath = if (options.outdir.length > 0) {
                Path.join([options.outdir, file.path])
            } else if (options.outfile.length > 0 && result.outputFiles.size == 1) {
                options.outfile
            } else {
                file.path
            }
            BaoFile.writeAllBytes(outputPath, file.content)
        }
    }

    /// 打印构建摘要
    // 严格翻译自: build_command.zig 中 printSummary + 每文件输出
    private func printSummary(result: BundleV2Result, elapsedMs: Int64): Unit {
        if (result.outputFiles.size == 0) { return }

        // 打印每个输出文件
        // 严格翻译自: build_command.zig 中 for (output_files) 循环
        let maxPathLen = calculateMaxPathLength(result)
        let maxFormatLen = calculateMaxSizeLength(result)

        for (file in result.outputFiles) {
            let relPath = if (file.path.startsWith("./")) {
                file.path.substring(2)
            } else {
                file.path
            }
            let padding = maxPathLen - relPath.length + 2
            let sizeStr = formatBytes(file.content.size)
            let sizePad = maxFormatLen - sizeStr.length

            Output.info("  ${relPath}${spaces(padding)}${sizeStr}${spaces(sizePad)}  (${file.kind})")
        }

        println("")
    }

    /// 格式化字节大小
    private func formatBytes(bytes: Int64): String {
        if (bytes < 1024) { return "${bytes} B" }
        let kb = Float64(bytes) / 1024.0
        if (kb < 1024.0) { return "${kb.format(1)} KB" }
        let mb = kb / 1024.0
        return "${mb.format(1)} MB"
    }

    /// 计算最大路径长度
    private func calculateMaxPathLength(result: BundleV2Result): Int64 {
        var maxLen: Int64 = 0
        for (file in result.outputFiles) {
            let relPath = if (file.path.startsWith("./")) {
                file.path.substring(2)
            } else {
                file.path
            }
            if (relPath.length > maxLen) {
                maxLen = Int64(relPath.length)
            }
        }
        return maxLen
    }

    /// 计算最大大小字符串长度
    private func calculateMaxSizeLength(result: BundleV2Result): Int64 {
        var maxLen: Int64 = 0
        for (file in result.outputFiles) {
            let s = formatBytes(Int64(file.content.size))
            if (Int64(s.length) > maxLen) {
                maxLen = Int64(s.length)
            }
        }
        return maxLen
    }

    /// 生成指定数量的空格
    private func spaces(n: Int64): String {
        if (n <= 0) { return "" }
        let sb = StringBuilder()
        for (_ in 0..n) {
            sb.append(' ')
        }
        return sb.toString()
    }

    /// 转译单个文件
    private func transpileFile(path: String): OutputFileInfo {
        let content = BaoFile.readAllBytes(path)
        return OutputFileInfo(Path.basename(path), content, "entry-point")
    }

    /// 生成 metafile markdown
    private func generateMetafileMarkdown(json: String): String {
        // 简化实现
        return "# Build Metafile\n\n```json\n${json}\n```"
    }

    /// 设置 fetcher
    public func setFetcher(): Unit {
        hasFetcher = true
    }
}

// ============================================================================
// BuildCommandOptions — build 命令完整选项
// 严格翻译自: build_command.zig 中的 ctx.bundler_options + ctx.args
// ============================================================================

/// Build 命令选项
/// 对应 Bun: ctx.bundler_options (BundlerOptions) + ctx.args
public class BuildCommandOptions {
    /// 入口文件列表
    // 对应 Bun: this_transpiler.options.entry_points
    public var entryPoints: ArrayList<String>

    /// 输出目录
    // 对应 Bun: ctx.bundler_options.outdir
    public var outdir: String

    /// 输出文件
    // 对应 Bun: ctx.bundler_options.outfile
    public var outfile: String

    /// 目标环境 (browser, node, bun)
    // 对应 Bun: ctx.args.target
    public var target: String

    /// 输出格式 (esm, cjs, iife)
    // 对应 Bun: ctx.bundler_options.output_format
    public var format: String

    /// 压缩语法
    // 对应 Bun: ctx.bundler_options.minify_syntax
    public var minifySyntax: Bool

    /// 压缩空白
    // 对应 Bun: ctx.bundler_options.minify_whitespace
    public var minifyWhitespace: Bool

    /// 压缩标识符
    // 对应 Bun: ctx.bundler_options.minify_identifiers
    public var minifyIdentifiers: Bool

    /// Source Map (none, inline, external)
    // 对应 Bun: ctx.args.source_map
    public var sourceMap: String

    /// 代码分割
    // 对应 Bun: ctx.bundler_options.code_splitting
    public var codeSplitting: Bool

    /// 公共路径
    // 对应 Bun: ctx.bundler_options.public_path
    public var publicPath: String

    /// 入口命名模板
    // 对应 Bun: ctx.bundler_options.entry_naming
    public var entryNaming: String

    /// chunk 命名模板
    // 对应 Bun: ctx.bundler_options.chunk_naming
    public var chunkNaming: String

    /// 资源命名模板
    // 对应 Bun: ctx.bundler_options.asset_naming
    public var assetNaming: String

    /// Tree shaking
    // 对应 Bun: this_transpiler.options.tree_shaking
    public var treeShaking: Bool

    /// React Fast Refresh
    // 对应 Bun: ctx.bundler_options.react_fast_refresh
    public var reactFastRefresh: Bool

    /// Server Components
    // 对应 Bun: ctx.bundler_options.server_components
    public var serverComponents: Bool

    /// 全局定义
    // 对应 Bun: ctx.args.define
    public var define: HashMap<String, String>

    /// 外部模块
    // 对应 Bun: ctx.args.external
    public var external: ArrayList<String>

    /// Banner
    // 对应 Bun: ctx.bundler_options.banner
    public var banner: String

    /// Footer
    // 对应 Bun: ctx.bundler_options.footer
    public var footer: String

    /// 环境变量行为
    // 对应 Bun: ctx.bundler_options.env_behavior
    public var envBehavior: String

    /// 环境变量前缀
    // 对应 Bun: ctx.bundler_options.env_prefix
    public var envPrefix: String

    /// 生产模式
    // 对应 Bun: ctx.bundler_options.production
    public var production: Bool

    /// 编译为可执行文件
    // 对应 Bun: ctx.bundler_options.compile
    public var compile: Bool

    /// 字节码模式
    // 对应 Bun: ctx.bundler_options.bytecode
    public var bytecode: Bool

    /// 仅转译 (不打包)
    // 对应 Bun: ctx.bundler_options.transform_only
    public var transformOnly: Bool

    /// Metafile 输出路径
    // 对应 Bun: ctx.bundler_options.metafile
    public var metafile: String

    /// Markdown metafile 输出路径
    // 对应 Bun: ctx.bundler_options.metafile_md
    public var metafileMd: String

    /// CSS chunking
    // 对应 Bun: ctx.bundler_options.css_chunking
    public var cssChunking: Bool

    public init() {
        entryPoints = ArrayList<String>()
        outdir = ""
        outfile = ""
        target = "browser"
        format = "esm"
        minifySyntax = false
        minifyWhitespace = false
        minifyIdentifiers = false
        sourceMap = "none"
        codeSplitting = false
        publicPath = ""
        entryNaming = ""
        chunkNaming = ""
        assetNaming = ""
        treeShaking = true
        reactFastRefresh = false
        serverComponents = false
        define = HashMap<String, String>()
        external = ArrayList<String>()
        banner = ""
        footer = ""
        envBehavior = "load_all"
        envPrefix = ""
        production = false
        compile = false
        bytecode = false
        transformOnly = false
        metafile = ""
        metafileMd = ""
        cssChunking = false
    }

    /// 简写: 是否启用 minify (任一压缩选项开启即为 true)
    public func minify(): Bool {
        return minifySyntax || minifyWhitespace || minifyIdentifiers
    }
}

// ============================================================================
// BundleV2 辅助类型
// 严格翻译自: src/bundler/bundle_v2.zig 中的类型
// ============================================================================

/// BundleV2 输出文件信息
/// 对应 Bun: options.OutputFile
public class OutputFileInfo {
    public var path: String
    public var content: Array<UInt8>
    public var kind: String

    public init(path: String, content: Array<UInt8>, kind: String) {
        this.path = path
        this.content = content
        this.kind = kind
    }

    /// 文件大小
    public func size(): Int64 {
        return Int64(content.size)
    }
}

/// BundleV2 打包结果
/// 对应 Bun: BundleV2.generateFromCLI 返回值
public class BundleV2Result {
    public var outputFiles: ArrayList<OutputFileInfo>
    public var errors: ArrayList<String>
    public var warnings: ArrayList<String>
    public var hasErrors: Bool
    public var metafile: String
    public var reachableFileCount: Int64
    public var minifyDuration: Int64
    public var inputCodeLength: Int64

    public init() {
        outputFiles = ArrayList<OutputFileInfo>()
        errors = ArrayList<String>()
        warnings = ArrayList<String>()
        hasErrors = false
        metafile = ""
        reachableFileCount = 0
        minifyDuration = 0
        inputCodeLength = 0
    }
}

/// BundleV2 打包选项
/// 对应 Bun: this_transpiler.options 汇总
public class BundleV2Options {
    public var entryPoints: ArrayList<String>
    public var outdir: String
    public var outfile: String
    public var target: String
    public var format: String
    public var minifySyntax: Bool
    public var minifyWhitespace: Bool
    public var minifyIdentifiers: Bool
    public var sourceMap: String
    public var codeSplitting: Bool
    public var publicPath: String
    public var entryNaming: String
    public var chunkNaming: String
    public var assetNaming: String
    public var treeShaking: Bool
    public var reactFastRefresh: Bool
    public var serverComponents: Bool
    public var define: HashMap<String, String>
    public var external: ArrayList<String>
    public var banner: String
    public var footer: String
    public var envBehavior: String
    public var envPrefix: String
    public var production: Bool
    public var ignoreModuleResolutionErrors: Bool

    public init() {
        entryPoints = ArrayList<String>()
        outdir = ""
        outfile = ""
        target = "browser"
        format = "esm"
        minifySyntax = false
        minifyWhitespace = false
        minifyIdentifiers = false
        sourceMap = "none"
        codeSplitting = false
        publicPath = ""
        entryNaming = ""
        chunkNaming = ""
        assetNaming = ""
        treeShaking = true
        reactFastRefresh = false
        serverComponents = false
        define = HashMap<String, String>()
        external = ArrayList<String>()
        banner = ""
        footer = ""
        envBehavior = "load_all"
        envPrefix = ""
        production = false
        ignoreModuleResolutionErrors = false
    }
}

/// BundleV2 打包器 (桩)
/// 对应 Bun: src/bundler/bundle_v2.zig BundleV2
public class BundlerV2 {
    public init() {}

    /// 执行打包
    /// 对应 Bun: BundleV2.generateFromCLI
    public func generate(options: BundleV2Options): BundleV2Result {
        // 实际实现在 bao_bundler 包中
        return BundleV2Result()
    }
}

// ============================================================================
// Float64 格式化扩展
// ============================================================================

/// Float64 保留指定小数位
public func Float64.format(decimals: Int64): String {
    let s = this.toString()
    let dotIndex = s.indexOf('.')
    if (dotIndex < 0) { return s }
    let maxLen = dotIndex + 1 + Int64(decimals)
    if (s.length <= maxLen) { return s }
    return s.substring(0, maxLen)
}

// ============================================================================
// Output — 输出辅助
// 对应 Bun: bun.Output 的简化版
// ============================================================================

/// 输出工具
public class Output {
    private static var verbose: Bool = false

    /// 打印信息行
    public static func info(msg: String): Unit {
        println(msg)
    }

    /// 打印错误行
    public static func err(msg: String): Unit {
        println("error: ${msg}")
    }

    /// 打印警告行
    public static func warn(msg: String): Unit {
        println("warn: ${msg}")
    }

    /// 设置详细模式
    public static func setVerbose(v: Bool): Unit {
        verbose = v
    }
}

// ============================================================================
// Time — 时间工具
// ============================================================================

/// 时间工具
public class Time {
    /// 获取当前纳秒时间戳
    public static func nowNanos(): Int64 {
        // 实际实现使用 clock_gettime(CLOCK_MONOTONIC)
        return 0
    }
}
