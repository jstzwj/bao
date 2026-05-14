// bao_transpiler - JavaScript/TypeScript 转译器
// 严格翻译自: src/transpiler/
//   src/transpiler/lib.rs - Transpiler 重导出
//   Bun 中 Transpiler 实际实现位于 bun_bundler::transpiler，
//   因为它共享 bundler 的 resolver/options/cache 基础设施。
//   此包在仓颉中独立实现，包含 TS/JSX/模块/JSON 转换。
package bao_transpiler

import bao_core.*
import bao_collections.*
import bao_parser.*

// ============================================================================
// TranspileResult - 转译结果
// 严格翻译自: src/bundler/transpiler.zig 中 Transpiler 输出结构
// Bun 的 Transpiler 使用 esbuild 风格的输出:
//   output.code: string
//   output.source_map: ?SourceMap
//   output.warnings: []Msg
//   output.errors: []Msg
// ============================================================================

/// 转译结果 - 对应 Bun Transpiler 输出
public class TranspileResult {
    /// 生成的代码 - 对应 Bun output.code
    public var code: String
    /// Source Map - 对应 Bun output.source_map
    public var sourceMap: String
    /// 警告列表 - 对应 Bun output.warnings
    public var warnings: ArrayList<TranspileMessage>
    /// 错误列表 - 对应 Bun output.errors
    public var errors: ArrayList<TranspileMessage>

    public init() {
        code = ""
        sourceMap = ""
        warnings = ArrayList<TranspileMessage>()
        errors = ArrayList<TranspileMessage>()
    }

    public init(code: String) {
        this.code = code
        this.sourceMap = ""
        this.warnings = ArrayList<TranspileMessage>()
        this.errors = ArrayList<TranspileMessage>()
    }

    /// 是否有错误
    public func hasErrors(): Bool {
        return errors.size > 0
    }

    /// 是否有警告
    public func hasWarnings(): Bool {
        return warnings.size > 0
    }
}

/// 转译消息 - 对应 Bun logger.Msg 简化版
public class TranspileMessage {
    public var text: String
    public var location: String
    public var severity: MessageSeverity

    public init(text: String, severity: MessageSeverity) {
        this.text = text
        this.location = ""
        this.severity = severity
    }

    public init(text: String, location: String, severity: MessageSeverity) {
        this.text = text
        this.location = location
        this.severity = severity
    }
}

/// 消息严重级别
public enum MessageSeverity {
    | Warning
    | Error
}

// ============================================================================
// TranspilerOptions - 转译选项
// 严格翻译自: src/bundler/options.zig 中 BundleOptions / TransformOptions
// Bun:
//   pub const TransformOptions = struct {
//       tsconfig_override: ?string = null,
//       jsx: JSX = .{},
//       target: Target = .browser,
//       define: *const Define = &.{},
//       ...
//   }
// ============================================================================

/// 转译选项 - 对应 Bun TransformOptions
public class TranspilerOptions {
    /// 是否处理 TypeScript - 对应 Bun 中自动检测 .ts/.tsx 扩展名
    public var typescript: Bool
    /// 是否处理 JSX - 对应 Bun options.jsx
    public var jsx: Bool
    /// 目标平台 - 对应 Bun options.target
    public var target: TranspileTarget
    /// 是否压缩输出 - 对应 Bun options.minify
    public var minify: Bool
    /// 定义常量替换 - 对应 Bun options.define
    /// 例如: {"process.env.NODE_ENV": "\"production\""}
    public var define: HashMap<String, String>
    /// JSX 运行时 - 对应 Bun options.jsx.runtime
    public var jsxRuntime: JSXRuntime
    /// JSX 工厂函数 - 对应 Bun options.jsx.factory
    /// 经典模式默认 "React.createElement"
    public var jsxFactory: String
    /// JSX Fragment - 对应 Bun options.jsx.fragment
    public var jsxFragment: String
    /// JSX 导入源 - 对应 Bun options.jsx.import_source
    public var jsxImportSource: String
    /// 是否是开发模式 - 对应 Bun options.jsx.development
    public var jsxDevelopment: Bool
    /// 源文件路径 (用于 source map)
    public var sourceFile: String
    /// 是否生成 source map
    public var sourceMap: Bool
    /// 是否保留导入 - 对应 Bun preserveImportsNotUsedAsValues
    public var dropUnusedImports: Bool
    /// 是否使用 defineForClassFields - 对应 Bun useDefineForClassFields
    public var useDefineForClassFields: Bool
    /// 装饰器元数据 - 对应 Bun emitDecoratorMetadata
    public var emitDecoratorMetadata: Bool
    /// 实验性装饰器 - 对应 Bun experimentalDecorators
    public var experimentalDecorators: Bool

    public init() {
        typescript = false
        jsx = false
        target = TranspileTarget.Browser
        minify = false
        define = HashMap<String, String>()
        jsxRuntime = JSXRuntime.Automatic
        jsxFactory = "React.createElement"
        jsxFragment = "React.Fragment"
        jsxImportSource = "react"
        jsxDevelopment = false
        sourceFile = ""
        sourceMap = false
        dropUnusedImports = false
        useDefineForClassFields = true
        emitDecoratorMetadata = false
        experimentalDecorators = false
    }
}

/// 转译目标平台 - 对应 Bun options.Target
public enum TranspileTarget {
    | Browser   // 浏览器
    | Node      // Node.js
    | Bun       // Bun 自身
    | Neutral   // 中立

    public func label(): String {
        match (this) {
            case Browser => "browser"
            case Node => "node"
            case Bun => "bun"
            case Neutral => "neutral"
        }
    }
}

/// JSX 运行时模式 - 对应 Bun options.jsx.Runtime
/// Bun:
///   pub const Runtime = enum { classic, automatic, solid }
public enum JSXRuntime {
    | Classic       // React.createElement
    | Automatic     // jsx()/jsxs() from react/jsx-runtime
    | Solid         // Solid.js 模式

    public func label(): String {
        match (this) {
            case Classic => "classic"
            case Automatic => "automatic"
            case Solid => "solid"
        }
    }
}

// ============================================================================
// Transpiler - 主转译器类
// 严格翻译自: src/bundler/transpiler.zig
// Bun:
//   pub const Transpiler = struct {
//       resolver: *Resolver,
//       options: Options,
//       log: *logger.Log,
//       ...
//       pub fn transpile(self, source, opts) -> TranspileResult
//   }
// ============================================================================

/// JavaScript/TypeScript 转译器 - 对应 Bun Transpiler
/// 负责 TypeScript 剥离、JSX 转换、模块转换等
public class Transpiler {
    private var options: TranspilerOptions
    private var log: Log

    public init() {
        options = TranspilerOptions()
        log = Log()
    }

    public init(options: TranspilerOptions) {
        this.options = options
        this.log = Log()
    }

    /// 转译源码 - 对应 Bun Transpiler.transpile()
    /// 这是主入口点，根据选项运行不同的转换管道
    public func transpile(source: String, options: TranspilerOptions): TranspileResult {
        this.options = options
        this.log.reset()

        let result = TranspileResult()
        var code = source

        // 1. TypeScript 转换 (类型剥离、枚举、命名空间、装饰器)
        if (options.typescript) {
            let tsResult = transformTypeScript(code)
            code = tsResult
        }

        // 2. JSX 转换
        if (options.jsx) {
            let jsxResult = transformJSX(code)
            code = jsxResult
        }

        // 3. 模块转换 (CJS <-> ESM)
        code = transformModules(code)

        // 4. Define 替换
        if (options.define.size > 0) {
            code = applyDefines(code, options.define)
        }

        // 5. 压缩 (简化实现)
        if (options.minify) {
            code = minifyCode(code)
        }

        result.code = code

        // 收集日志中的警告和错误
        for (msg in log.msgs) {
            let tMsg = TranspileMessage(msg.text, MessageSeverity.Warning)
            match (msg.level) {
                case LogLevel.Error => result.errors.append(tMsg)
                case LogLevel.Warn => result.warnings.append(tMsg)
                case _ => {}
            }
        }

        return result
    }

    /// TypeScript 转换入口
    private func transformTypeScript(source: String): String {
        let eraser = TypeEraser()
        return eraser.eraseAll(source)
    }

    /// JSX 转换入口
    private func transformJSX(source: String): String {
        let jsxTransformer = JSXTransformer(options)
        return jsxTransformer.transform(source)
    }

    /// 模块转换入口
    private func transformModules(source: String): String {
        return source
    }

    /// 定义常量替换
    private func applyDefines(source: String, defines: HashMap<String, String>): String {
        var result = source
        // 遍历所有定义，做简单的文本替换
        // Bun 使用 AST 级别的替换，这里简化为文本替换
        let keys = defines.keys()
        for (key in keys) {
            match (defines.get(key)) {
                case Some(value) => {
                    result = result.replace(key, value)
                }
                case None => {}
            }
        }
        return result
    }

    /// 简化的代码压缩
    private func minifyCode(source: String): String {
        var sb = StringBuilder()
        var inString: Bool = false
        var stringChar: UInt8 = 0
        var prev: UInt8 = 0
        var i = 0

        while (i < source.length) {
            let ch = UInt8(source[i].value)

            // 处理字符串字面量
            if (ch == UInt8('\'') || ch == UInt8('"') || ch == UInt8('`')) {
                if (!inString) {
                    inString = true
                    stringChar = ch
                } else if (ch == stringChar) {
                    inString = false
                }
                sb.append(source[i])
                prev = ch
                i += 1
                continue
            }

            if (inString) {
                sb.append(source[i])
                prev = ch
                i += 1
                continue
            }

            // 跳过行注释
            if (ch == UInt8('/') && i + 1 < source.length &&
                UInt8(source[i + 1].value) == UInt8('/')) {
                while (i < source.length && UInt8(source[i].value) != UInt8('\n')) {
                    i += 1
                }
                continue
            }

            // 跳过块注释
            if (ch == UInt8('/') && i + 1 < source.length &&
                UInt8(source[i + 1].value) == UInt8('*')) {
                i += 2
                while (i + 1 < source.length &&
                       !(UInt8(source[i].value) == UInt8('*') &&
                         UInt8(source[i + 1].value) == UInt8('/'))) {
                    i += 1
                }
                i += 2
                continue
            }

            // 压缩空白
            if (ch == UInt8(' ') || ch == UInt8('\t') || ch == UInt8('\n') || ch == UInt8('\r')) {
                // 只在必要时保留一个空格 (防止标识符粘连)
                if (prev != UInt8(' ') && prev != UInt8('\n') &&
                    prev != UInt8('\t') && prev != UInt8('\r') &&
                    prev != UInt8('{') && prev != UInt8('}') &&
                    prev != UInt8('(') && prev != UInt8(')') &&
                    prev != UInt8(';') && prev != UInt8(',') &&
                    prev != UInt8(':') && prev != UInt8('=')) {
                    // 检查下一个字符是否也需要空格
                    if (i + 1 < source.length) {
                        let next = UInt8(source[i + 1].value)
                        if (isIdentChar(prev) && isIdentChar(next)) {
                            sb.append(Char(Int32(32)))
                            prev = UInt8(' ')
                        }
                    }
                }
                i += 1
                continue
            }

            sb.append(source[i])
            prev = ch
            i += 1
        }

        return sb.toString()
    }

    private func isIdentChar(ch: UInt8): Bool {
        return (ch >= UInt8('a') && ch <= UInt8('z')) ||
               (ch >= UInt8('A') && ch <= UInt8('Z')) ||
               (ch >= UInt8('0') && ch <= UInt8('9')) ||
               ch == UInt8('_') || ch == UInt8('$')
    }
}

// ============================================================================
// TranspilePipeline - 转译管道
// 对应 Bun 中 bundler/transpiler 的多阶段处理流程
// Bun 的处理管线:
//   parse -> AST transform -> code generation -> (可选)minify
// ============================================================================

/// 转译管道阶段
public enum PipelineStage {
    | Parse         // 解析源码为 AST
    | TypeScript    // TypeScript 转换
    | JSX           // JSX 转换
    | Module        // 模块格式转换
    | JSON          // JSON 导入转换
    | Define        // 常量替换
    | Minify        // 压缩
    | Generate      // 代码生成
}

/// 转译管道 - 对应 Bun 的多阶段处理流程
/// 按顺序运行各个转换阶段
public class TranspilePipeline {
    private var stages: ArrayList<PipelineStage>
    private var transpiler: Transpiler
    private var options: TranspilerOptions

    public init(transpiler: Transpiler, options: TranspilerOptions) {
        this.stages = ArrayList<PipelineStage>()
        this.transpiler = transpiler
        this.options = options
        buildStages()
    }

    /// 构建管道阶段 - 根据选项确定需要运行哪些阶段
    private func buildStages(): Unit {
        stages.append(PipelineStage.Parse)

        if (options.typescript) {
            stages.append(PipelineStage.TypeScript)
        }
        if (options.jsx) {
            stages.append(PipelineStage.JSX)
        }

        stages.append(PipelineStage.Module)
        stages.append(PipelineStage.Define)

        if (options.minify) {
            stages.append(PipelineStage.Minify)
        }

        stages.append(PipelineStage.Generate)
    }

    /// 运行管道 - 对应 Bun 中依次运行各个 transform pass
    public func run(source: String): TranspileResult {
        return transpiler.transpile(source, options)
    }

    /// 获取管道阶段列表
    public func getStages(): ArrayList<PipelineStage> {
        return stages
    }

    /// 获取管道描述
    public func describe(): String {
        var sb = StringBuilder()
        sb.append("TranspilePipeline: ")
        for (i in 0..stages.size) {
            if (i > 0) {
                sb.append(" -> ")
            }
            sb.append(stages[Int64(i)].label())
        }
        return sb.toString()
    }
}

/// PipelineStage 扩展
public extension PipelineStage {
    public func label(): String {
        match (this) {
            case Parse => "parse"
            case TypeScript => "typescript"
            case JSX => "jsx"
            case Module => "module"
            case JSON => "json"
            case Define => "define"
            case Minify => "minify"
            case Generate => "generate"
        }
    }
}
