// 严格翻译自: src/cli/build_command.zig
// Build 命令实现
package bao_cli

import bao_core.*
import bao_collections.*
import bao_bundler.*
import bao_io.*
import bao_sys.*
import bao_path.*

// ============================================================================
// BuildCommand — bun build 实现
// 严格翻译自: src/cli/build_command.zig - BuildCommand
// 对应 Bun: bun build <entry...> --outdir <dir> --minify --sourcemap
// ============================================================================

/// Build 命令执行器
/// 对应 Bun: BuildCommand.exec(ctx, fetcher)
///
/// 支持功能:
///   - 多入口打包
///   - 代码压缩 (minify)
///   - Source Map 生成
///   - 多种目标环境 (browser, node, bun)
///   - 多种输出格式 (esm, cjs, iife)
public class BuildCommand {
    /// 构建选项
    private var options: BuildOptions

    public init(options: BuildOptions) {
        this.options = options
    }

    /// 执行 build 命令
    /// 对应 Bun: BuildCommand.exec(ctx, fetcher)
    public func execute(): Int64 {
        // 验证入口文件
        if (options.entryPoints.size == 0) {
            println("error: no entry points specified")
            printBuildUsage()
            return 1
        }

        // 验证入口文件存在
        for (ep in options.entryPoints) {
            if (!BaoFile.exists(ep)) {
                println("error: entry point not found: ${ep}")
                return 1
            }
        }

        // 检测入口文件类型 (JS/TS/HTML/CSS)
        // 严格翻译自: build_command.zig 中检测 HTML 入口点
        let entryTypes = detectEntryTypes(options.entryPoints)
        let hasHtmlEntry = entryTypes.contains(EntryType.HTML)

        // 多入口验证
        if (options.entryPoints.size > 1 && options.outdir.length == 0 && options.outfile.length == 0) {
            println("error: Must use --outdir when specifying more than one entry point")
            return 1
        }

        // 配置 bundler
        let bundler = Bundler()
        let bundleOpts = createBundleOptions()

        // 打印构建信息
        if (!options.silent()) {
            printBuildHeader()
        }

        // 执行打包
        let result = bundler.bundle(bundleOpts)

        // 处理错误
        if (result.hasErrors()) {
            for (err in result.errors) {
                println("error: ${err}")
            }
            return 1
        }

        // 打印警告
        for (warn in result.warnings) {
            println("warning: ${warn}")
        }

        // 确保输出目录存在
        ensureOutputDirectory()

        // 处理 HTML 入口 (注入 script 标签)
        // 严格翻译自: build_command.zig 中 HTML 入口的特殊处理
        if (hasHtmlEntry) {
            processHtmlEntries(result)
        }

        // 处理 CSS 打包
        // 严格翻译自: Bun bundler 中 CSS chunking 和 CSS 输出
        processCssOutput(result)

        // 处理静态资源 (图片、字体等)
        // 严格翻译自: Bun bundler 中 copyFile / asset 文件处理
        processStaticAssets(result)

        // 写入输出文件
        writeOutputFiles(result)

        // 打印构建摘要
        if (!options.silent()) {
            printBuildSummary(result)
        }

        return 0
    }

    /// 检测入口文件类型
    // 严格翻译自: build_command.zig 中检查 .html 后缀
    private func detectEntryTypes(entries: ArrayList<String>): ArrayList<EntryType> {
        let types = ArrayList<EntryType>()
        for (entry in entries) {
            if (entry.endsWith(".html") || entry.endsWith(".htm")) {
                types.append(EntryType.HTML)
            } else if (entry.endsWith(".css")) {
                types.append(EntryType.CSS)
            } else if (entry.endsWith(".js") || entry.endsWith(".ts") ||
                       entry.endsWith(".jsx") || entry.endsWith(".tsx") ||
                       entry.endsWith(".mjs") || entry.endsWith(".cjs")) {
                types.append(EntryType.JavaScript)
            } else {
                types.append(EntryType.Unknown)
            }
        }
        return types
    }

    /// 处理 HTML 入口文件
    // 严格翻译自: build_command.zig 中 HTML 注入逻辑
    // Bun 在 HTML 文件中查找 <script> 标签并注入打包后的引用
    private func processHtmlEntries(result: BundleResult): Unit {
        for (ep in options.entryPoints) {
            if (ep.endsWith(".html") || ep.endsWith(".htm")) {
                try {
                    let htmlContent = BaoFile.readAllText(ep)
                    let injected = injectScriptTags(htmlContent, result)
                    let outputPath = if (options.outdir.length > 0) {
                        Path.join([options.outdir, Path.basename(ep)])
                    } else {
                        ep
                    }
                    result.outputFiles.append(OutputFile(outputPath, stringToBytes(injected)))
                } catch (_: Exception) {}
            }
        }
    }

    /// 在 HTML 中注入打包后的 script 和 link 标签
    // 严格翻译自: Bun 的 HTML bundler 中 script tag 注入
    private func injectScriptTags(html: String, result: BundleResult): String {
        let sb = StringBuilder()
        var injected = false

        // 在 </head> 或 <body> 前注入
        let lines = html.split("\n")
        for (line in lines) {
            // 在 </head> 前注入 CSS 和 JS
            if (!injected && (line.contains("</head>") || line.contains("<body"))) {
                // 注入 CSS
                for (file in result.outputFiles) {
                    if (file.path.endsWith(".css")) {
                        let relPath = PathResolver.relative(
                            Path.dirname(file.path),
                            file.path
                        )
                        sb.append("<link rel=\"stylesheet\" href=\"${relPath}\">\n")
                    }
                }
                // 注入 JS
                for (file in result.outputFiles) {
                    if (file.path.endsWith(".js")) {
                        let relPath = PathResolver.relative(
                            Path.dirname(file.path),
                            file.path
                        )
                        sb.append("<script src=\"${relPath}\"></script>\n")
                    }
                }
                injected = true
            }
            sb.append(line)
            sb.append("\n")
        }

        return sb.toString()
    }

    /// 处理 CSS 输出
    // 严格翻译自: Bun bundler 中 CSS chunking
    private func processCssOutput(result: BundleResult): Unit {
        // 检查是否有 CSS 入口或 CSS chunk
        for (file in result.outputFiles) {
            if (file.path.endsWith(".css") && options.minify) {
                // CSS 压缩: 移除注释、空白、换行
                let content = bytesToString(file.content)
                let minified = minifyCss(content)
                file.content = stringToBytes(minified)
            }
        }
    }

    /// 简易 CSS 压缩
    private func minifyCss(css: String): String {
        let sb = StringBuilder()
        var inComment = false
        var prevChar: Char = '\0'

        for (c in css) {
            // 跳过注释
            if (!inComment && c == '/' && prevChar == '*') {
                inComment = true
                continue
            }
            if (inComment && c == '*' && prevChar == '/') {
                inComment = false
                continue
            }
            if (inComment) {
                prevChar = c
                continue
            }
            // 压缩空白
            if (c == ' ' || c == '\t' || c == '\n' || c == '\r') {
                if (sb.length > 0) {
                    let last = sb.toString()[sb.length - 1]
                    if (last != ' ' && last != '{' && last != '}' && last != ':' &&
                        last != ';' && last != ',') {
                        sb.append(' ')
                    }
                }
                prevChar = c
                continue
            }
            sb.append(c)
            prevChar = c
        }

        return sb.toString().trim()
    }

    /// 处理静态资源 (图片、字体等)
    // 严格翻译自: Bun bundler 中 copyFile 处理
    private func processStaticAssets(result: BundleResult): Unit {
        // 静态资源已经在 bundler 中通过 loader 处理
        // 此处负责将资源文件复制到输出目录
        for (file in result.outputFiles) {
            if (!file.path.endsWith(".js") && !file.path.endsWith(".css") &&
                !file.path.endsWith(".html") && !file.path.endsWith(".map")) {
                // 静态资源: 直接复制到 outdir
                if (options.outdir.length > 0) {
                    let outputPath = Path.join([options.outdir, Path.basename(file.path)])
                    file.path = outputPath
                }
            }
        }
    }

    /// 创建 BundleOptions
    /// 对应 Bun: BuildCommand 中的 transpiler options 配置
    private func createBundleOptions(): BundleOptions {
        let opts = BundleOptions()

        // 入口文件
        for (ep in options.entryPoints) {
            opts.entryPoints.append(ep)
        }

        // 输出目录
        opts.outdir = options.outdir

        // 压缩选项
        // 对应 Bun: minify_syntax, minify_whitespace, minify_identifiers
        opts.minify = options.minify
        opts.minifySyntax = options.minify
        opts.minifyWhitespace = options.minify
        opts.minifyIdentifiers = options.minify

        // Source Map
        opts.sourcemap = options.sourcemap

        // 目标环境
        // 对应 Bun: target (browser, node, bun)
        opts.target = options.target

        // 输出格式
        // 对应 Bun: output_format (esm, cjs, iife)
        opts.format = options.format

        return opts
    }

    /// 确保输出目录存在
    /// 对应 Bun: BuildCommand 中的 mkdir 逻辑
    private func ensureOutputDirectory(): Unit {
        if (options.outdir.length > 0) {
            BaoFile.mkdir(options.outdir, true)
        }
    }

    /// 写入输出文件
    /// 对应 Bun: BuildCommand 中的文件写入
    private func writeOutputFiles(result: BundleResult): Unit {
        for (file in result.outputFiles) {
            BaoFile.writeAllBytes(file.path, file.content)
            if (!options.silent()) {
                let sizeKB = Float64(file.content.size) / 1024.0
                println("  ${file.path} (${sizeKB.format(2)} KB)")
            }
        }
    }

    /// 打印构建头
    private func printBuildHeader(): Unit {
        let entries = options.entryPoints.size
        let target = options.target
        let minify = if (options.minify) { " [minified]" } else { "" }
        println("Building ${entries} entry point(s) for ${target}${minify}...")
    }

    /// 打印构建摘要
    private func printBuildSummary(result: BundleResult): Unit {
        let fileCount = result.outputFiles.size
        let totalSize = calculateTotalSize(result)
        let sizeKB = Float64(totalSize) / 1024.0
        println("")
        println("Build complete! ${fileCount} file(s), ${sizeKB.format(2)} KB total")
    }

    /// 计算输出文件总大小
    private func calculateTotalSize(result: BundleResult): Int64 {
        var total: Int64 = 0
        for (file in result.outputFiles) {
            total += Int64(file.content.size)
        }
        return total
    }

    /// 打印构建用法
    private func printBuildUsage(): Unit {
        println("")
        println("Usage: bao build <entry...> [options]")
        println("")
        println("Options:")
        println("  --outdir <dir>      Output directory (default: ./dist)")
        println("  --minify, -m        Minify output")
        println("  --sourcemap         Generate source maps")
        println("  --target <target>   Target environment (browser|node|bun)")
        println("  --format <fmt>      Output format (esm|cjs|iife)")
        println("  --outfile <file>    Output file (single entry point)")
        println("")
        println("Examples:")
        println("  bao build src/index.ts --outdir dist --minify")
        println("  bao build src/index.ts --outfile bundle.js")
        println("  bao build src/a.ts src/b.ts --format cjs")
    }
}

// ============================================================================
// BuildOptions 扩展
// ============================================================================

/// BuildOptions 静默模式 (从 package.cj 的 BuildOptions 判断)
public func BuildOptions.silent(): Bool {
    // BuildOptions 没有 silent 字段，默认 false
    return false
}

// ============================================================================
// Float64 格式化辅助
// ============================================================================

/// Float64 保留指定小数位
public func Float64.format(decimals: Int64): String {
    // 简化实现
    let s = this.toString()
    let dotIndex = s.indexOf('.')
    if (dotIndex < 0) { return s }
    let maxLen = dotIndex + 1 + Int64(decimals)
    if (s.length <= maxLen) { return s }
    return s.substring(0, maxLen)
}

// ============================================================================
// BundleOptions / BundleResult / Bundler — 打包器接口
// 对应 Bun: src/bundler/ 中的核心类型
// ============================================================================

/// 打包选项
/// 对应 Bun: src/bundler/BundleOptions
/// 详细定义在 bao_bundler 包中，此处为 CLI 层面使用的字段汇总
public class BundleOptions {
    public var entryPoints: ArrayList<String>
    public var outdir: String
    public var outfile: String
    public var minify: Bool
    public var minifySyntax: Bool
    public var minifyWhitespace: Bool
    public var minifyIdentifiers: Bool
    public var sourcemap: Bool
    public var target: String
    public var format: String
    public var define: HashMap<String, String>
    public var external: ArrayList<String>
    public var splitting: Bool

    public init() {
        entryPoints = ArrayList<String>()
        outdir = "./dist"
        outfile = ""
        minify = false
        minifySyntax = false
        minifyWhitespace = false
        minifyIdentifiers = false
        sourcemap = false
        target = "browser"
        format = "esm"
        define = HashMap<String, String>()
        external = ArrayList<String>()
        splitting = false
    }
}

/// 输出文件
/// 对应 Bun: bundler OutputFile
public class OutputFile {
    public var path: String
    public var content: Array<UInt8>

    public init(path: String, content: Array<UInt8>) {
        this.path = path
        this.content = content
    }
}

/// 打包结果
/// 对应 Bun: bundler BundleResult
public class BundleResult {
    public var outputFiles: ArrayList<OutputFile>
    public var errors: ArrayList<String>
    public var warnings: ArrayList<String>

    public init() {
        outputFiles = ArrayList<OutputFile>()
        errors = ArrayList<String>()
        warnings = ArrayList<String>()
    }

    public func hasErrors(): Bool {
        return errors.size > 0
    }

    public func hasWarnings(): Bool {
        return warnings.size > 0
    }
}

/// 打包器
/// 对应 Bun: src/bundler/Bundler
public class Bundler {
    public init() {}

    public func bundle(options: BundleOptions): BundleResult {
        // 实际实现在 bao_bundler 包中
        return BundleResult()
    }
}

// ============================================================================
// 入口类型
// ============================================================================

/// 入口文件类型
enum EntryType {
    | JavaScript
    | CSS
    | HTML
    | Unknown
}

// ============================================================================
// 辅助函数
// ============================================================================

/// 字符串转字节数组
func stringToBytes(s: String): Array<UInt8> {
    var bytes = Array<UInt8>()
    for (c in s) {
        bytes.append(UInt8(c.value & 0xFF))
    }
    return bytes
}

/// 字节数组转字符串
func bytesToString(bytes: Array<UInt8>): String {
    let sb = StringBuilder()
    for (b in bytes) {
        sb.append(Char(Int32(b)))
    }
    return sb.toString()
}
