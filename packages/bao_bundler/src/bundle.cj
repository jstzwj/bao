// 严格翻译自: src/bundler/bundle_v2.zig, src/bundler/BundleThread.zig, src/bundler/Chunk.zig
// bao_bundler - Bundle 编排器: 协调 parse -> resolve -> tree-shake -> chunk -> codegen 流水线
package bao_bundler

import bao_core.*
import bao_collections.*
import bao_parser.*
import bao_io.*
import bao_path.*
import bao_sys.*
import bao_hash.*

// ============================================================================
// Bundle 编排器
// 严格翻译自: src/bundler/bundle_v2.zig (BundleV2)
// 核心流程:
//   1. 解析入口点
//   2. 链接模块 (构建依赖图)
//   3. Tree-shaking (标记已使用/未使用)
//   4. 分块 (Chunk splitting)
//   5. 代码生成 (Codegen)
//   6. 输出文件
// ============================================================================

/// Bundle 阶段
/// 严格翻译自: src/bundler/bundle_v2.zig BundleStep
public enum BundlePhase {
    | Parse        // 解析源文件为 AST
    | Resolve      // 解析模块路径
    | Link         // 构建依赖图
    | TreeShake    // 标记已使用/未使用
    | Chunk        // 分块
    | CodeGen      // 代码生成
    | Output       // 写入文件
    | Done         // 完成
}

/// Bundle 选项
/// 严格翻译自: src/bundler/options.zig BundleOptions
public class BundleOptions {
    /// 入口点列表
    public var entryPoints: ArrayList<String>
    /// 输出目录
    public var outdir: String
    /// 输出文件名模式 (例: "[name].[hash].js")
    public var naming: String
    /// 目标平台
    public var target: BundleTarget
    /// 输出格式
    public var format: OutputFormat
    /// 是否 minify
    public var minify: Bool
    /// 是否生成 sourcemap
    public var sourcemap: SourcemapOption
    /// 外部依赖列表
    public var externals: ArrayList<String>
    /// define 替换
    public var defines: HashMap<String, String>
    /// 是否分割 chunk
    public var splitting: Bool
    /// 是否打包所有依赖 (不分包)
    public var packages: PackageMode
    /// 入口点命名 (用于 library 模式)
    public var entryNaming: ArrayList<String>
    /// 全局名称 (用于 IIFE/UMD)
    public var globalName: ?String
    /// 是否是 watch 模式
    public var watch: Bool
    /// 插件列表
    public var plugins: ArrayList<Plugin>
    /// 加载器映射
    public var loaders: HashMap<String, Loader>
    /// 条件 (resolve conditions)
    public var conditions: ArrayList<String>
    /// 是否 banner/footer
    public var banner: ?String
    public var footer: ?String
    /// 是否 emit CSS (而不是嵌入 JS)
    public var emitCSS: Bool
    /// 是否 public path
    public var publicPath: ?String
    /// 目标环境
    public var env: BundleEnv

    public init() {
        entryPoints = ArrayList<String>()
        outdir = "./dist"
        naming = "[name].js"
        target = BundleTarget.Browser
        format = OutputFormat.ESM
        minify = false
        sourcemap = SourcemapOption.None
        externals = ArrayList<String>()
        defines = HashMap<String, String>()
        splitting = false
        packages = PackageMode.Bundle
        entryNaming = ArrayList<String>()
        globalName = None
        watch = false
        plugins = ArrayList<Plugin>()
        loaders = HashMap<String, Loader>()
        conditions = ArrayList<String>()
        banner = None
        footer = None
        emitCSS = false
        publicPath = None
        env = BundleEnv()
    }
}

/// Bundle 环境配置
public class BundleEnv {
    public var nodeEnv: String

    public init() {
        nodeEnv = "production"
    }
}

/// Bundle 结果
/// 严格翻译自: src/bundler/bundle_v2.zig BundleResult
public class BundleResult {
    /// 输出文件列表
    public var outputFiles: ArrayList<OutputFile>
    /// 错误列表
    public var errors: ArrayList<BundleError>
    /// 警告列表
    public var warnings: ArrayList<BundleWarning>
    /// 总耗时 (毫秒)
    public var elapsed: Int64
    /// 各阶段耗时
    public var phaseTimings: HashMap<String, Int64>
    /// 入口点数量
    public var entryPointCount: Int64
    /// 模块总数
    public var moduleCount: Int64
    /// chunk 总数
    public var chunkCount: Int64
    /// 总输出大小
    public var totalSize: Int64

    public init() {
        outputFiles = ArrayList<OutputFile>()
        errors = ArrayList<BundleError>()
        warnings = ArrayList<BundleWarning>()
        elapsed = 0
        phaseTimings = HashMap<String, Int64>()
        entryPointCount = 0
        moduleCount = 0
        chunkCount = 0
        totalSize = 0
    }

    public func hasErrors(): Bool {
        return errors.size > 0
    }

    /// 添加输出文件
    public func addOutputFile(file: OutputFile): Unit {
        outputFiles.append(file)
        totalSize += file.content.size
    }
}

/// 输出文件
/// 严格翻译自: src/bundler/OutputFile.zig
public class OutputFile {
    /// 输出路径 (相对 outdir)
    public var path: String
    /// 输出内容
    public var content: Array<Byte>
    /// 是否是 source map
    public var isSourceMap: Bool
    /// 对应的源文件 (用于 source map)
    public var sourcePath: ?String
    /// 内容哈希
    public var hash: String

    public init(path: String, content: Array<Byte>) {
        this.path = path
        this.content = content
        this.isSourceMap = false
        this.sourcePath = None
        this.hash = ""
    }

    /// 内容大小 (字节)
    public func size(): Int64 {
        return content.size
    }
}

/// Bundle 错误
public class BundleError {
    public var message: String
    public var path: ?String
    public var phase: BundlePhase
    public var line: Int64
    public var column: Int64

    public init(message: String) {
        this.message = message
        this.path = None
        this.phase = BundlePhase.Parse
        this.line = 0
        this.column = 0
    }
}

/// Bundle 警告
public class BundleWarning {
    public var message: String
    public var path: ?String

    public init(message: String) {
        this.message = message
        this.path = None
    }
}/// 已解析的模块
public class ParsedModule {
    public var path: String
    public var source: String

    public init(path: String, source: String) {
        this.path = path
        this.source = source
    }
}

/// Tree-shaking 结果
public class ShakeResult {
    /// 被标记为已使用的模块路径集合
    public var usedModules: HashSet<String>
    /// 被移除的模块数量
    public var removedCount: Int64

    public init() {
        usedModules = HashSet<String>()
        removedCount = 0
    }
}/// Hash 辅助
// 严格翻译自: Bun 使用 Wyhash11 对字符串哈希后截取前 8 位 hex
public class Hash {
    private static let hexChars: Array<String> = ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "a", "b", "c", "d", "e", "f"]

    /// 计算字符串的短哈希 (8 字符 hex)
    // 对应 Bun: std.hash.Wyhash.hash(0, input) 截断为 u32 后转 hex
    public static func shortHash(input: String): String {
        let hashValue = Wyhash.hash(input)
        // 取低 32 位，转为 8 字符 hex
        let u32val = UInt32(hashValue & UInt64(0xFFFFFFFF))
        return toHex8(u32val)
    }

    /// UInt32 转 8 字符十六进制字符串
    private static func toHex8(value: UInt32): String {
        var result = ""
        var v = value
        var chars = ArrayList<String>()
        for (_ in 0..8) {
            chars.add(hexChars[Int64(v & UInt32(0xF))])
            v = v >> 4
        }
        // 反转
        var sb = StringBuilder()
        var i = chars.size - 1
        while (i >= 0) {
            sb.append(chars[i])
            i -= 1
        }
        return sb.toString()
    }
}
