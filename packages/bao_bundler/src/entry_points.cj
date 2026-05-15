// 严格翻译自: src/bundler/entry_points.zig (~375行)
// bao_bundler - 入口点: 管理服务端/客户端/回退/宏入口点的生成
package bao_bundler

import bao_core.*
import bao_collections.*
import bao_parser.*
import bao_io.*
import bao_path.*
import bao_sys.*
import bao_ast.*

// ============================================================================
// 回退入口点
// 严格翻译自: entry_points.zig:1 FallbackEntryPoint
// 用于 bake 框架的简单回退入口:
//   import boot from 'framework';
//   boot(globalThis.__BUN_DATA__);
// ============================================================================

/// 回退入口点
// 严格翻译自: entry_points.zig:1 FallbackEntryPoint
public class FallbackEntryPoint {
    /// 代码缓冲区
    public var codeBuffer: StringBuilder
    /// 路径缓冲区
    public var pathBuffer: StringBuilder
    /// 生成的源文件
    public var source: Source
    /// 构建的代码
    public var builtCode: String

    public init() {
        this.codeBuffer = StringBuilder()
        this.pathBuffer = StringBuilder()
        this.source = Source()
        this.builtCode = ""
    }

    /// 生成回退入口点代码
    // 严格翻译自: entry_points.zig:9 generate
    public func generate(inputPath: String, disableCssImports: Bool): Unit {
        let code = StringBuilder()
        if (disableCssImports) {
            code.append("globalThis.Bun_disableCSSImports = true;\n")
        }
        code.append("import boot from '${inputPath}';\n")
        code.append("boot(globalThis.__BUN_DATA__);\n")

        builtCode = code.toString()
        source = Source(path: inputPath, contents: builtCode, index: -1)
    }
}

// ============================================================================
// 客户端入口点
// 严格翻译自: entry_points.zig:67 ClientEntryPoint
// 用于 bake 框架的客户端入口:
//   import boot from 'framework-client';
//   import * as EntryPoint from 'entry-point';
//   boot(EntryPoint);
// ============================================================================

/// 客户端入口点
// 严格翻译自: entry_points.zig:67 ClientEntryPoint
public class ClientEntryPoint {
    /// 代码缓冲区
    public var codeBuffer: StringBuilder
    /// 路径缓冲区
    public var pathBuffer: StringBuilder
    /// 生成的源文件
    public var source: Source

    public init() {
        this.codeBuffer = StringBuilder()
        this.pathBuffer = StringBuilder()
        this.source = Source()
    }

    /// 判断是否为入口点路径
    // 严格翻译自: entry_points.zig:72 isEntryPointPath
    public static func isEntryPointPath(name: String): Bool {
        return name.startsWith("entry.")
    }

    /// 生成入口点路径
    // 严格翻译自: entry_points.zig:76 generateEntryPointPath
    public static func generateEntryPointPath(originalPath: PathName): String {
        return originalPath.dir + originalPath.base + ".entry" + originalPath.ext
    }

    /// 解码入口点路径
    // 严格翻译自: entry_points.zig:87 decodeEntryPointPath
    public static func decodeEntryPointPath(originalPath: PathName): String {
        var ext = originalPath.ext
        let entryIdx = ext.indexOf("entry")
        if (entryIdx >= 0) {
            ext = ext.substring(Int64(entryIdx + "entry".length))
        }
        return originalPath.dir + originalPath.base + ext
    }

    /// 生成客户端入口点代码
    // 严格翻译自: entry_points.zig:99 generate
    public func generate(originalPath: PathName, client: String, disableCssImports: Bool): Unit {
        let dirToUse = originalPath.dirWithTrailingSlash()
        let code = StringBuilder()

        if (disableCssImports) {
            code.append("globalThis.Bun_disableCSSImports = true;\n")
        }
        code.append("import boot from '${client}';\n")
        code.append("import * as EntryPoint from '${dirToUse}${originalPath.filename}';\n")
        code.append("boot(EntryPoint);\n")

        let generatedPath = generateEntryPointPath(originalPath)
        source = Source(path: generatedPath, contents: code.toString(), index: -1)
    }
}

// ============================================================================
// 服务端入口点
// 严格翻译自: entry_points.zig:151 ServerEntryPoint
// 生成服务端启动代码:
//   import * as start from 'path';
//   const server = Bun.serve(start.default);
// ============================================================================

/// 服务端入口点
// 严格翻译自: entry_points.zig:151 ServerEntryPoint
public class ServerEntryPoint {
    /// 生成的内容
    public var contents: String
    /// 是否已生成
    public var generated: Bool

    public init() {
        this.contents = ""
        this.generated = false
    }

    /// 释放
    public func deinit(): Unit {
        contents = ""
        generated = false
    }

    /// 生成服务端入口点代码
    // 严格翻译自: entry_points.zig:166 generate
    public func generate(isHotReloadEnabled: Bool, pathToUse: String): Unit {
        let code = StringBuilder()
        code.append("// @bun\n")
        code.append("import * as start from '${pathToUse}';\n")
        code.append("var entryNamespace = start;\n")
        code.append("function isServerConfig(def) {\n")
        code.append("  return def && def !== globalThis && (typeof def.fetch === 'function' || def.app != undefined) && typeof def.stop !== 'function';\n")
        code.append("}\n")

        if (isHotReloadEnabled) {
            code.append("var hmrSymbol = Symbol(\"BunServerHMR\");\n")
            code.append("if (isServerConfig(entryNamespace?.default)) {\n")
            code.append("  var server = globalThis[hmrSymbol];\n")
            code.append("  if (server) {\n")
            code.append("    server.reload(entryNamespace.default);\n")
            code.append("  } else {\n")
            code.append("    server = globalThis[hmrSymbol] = Bun.serve(entryNamespace.default);\n")
            code.append("  }\n")
            code.append("}\n")
        } else {
            code.append("if (isServerConfig(entryNamespace?.default)) {\n")
            code.append("  const server = Bun.serve(entryNamespace.default);\n")
            code.append("}\n")
        }

        contents = code.toString()
        generated = true
    }
}

// ============================================================================
// 宏入口点
// 严格翻译自: entry_points.zig:260 MacroEntryPoint
// 为宏函数导出生成入口点:
//   import Macros from 'path';
//   Bun.registerMacro(id, Macros['functionName']);
// ============================================================================

/// 宏入口点
// 严格翻译自: entry_points.zig:260 MacroEntryPoint
public class MacroEntryPoint {
    /// 代码缓冲区
    public var codeBuffer: StringBuilder
    /// 输出代码缓冲区
    public var outputCodeBuffer: StringBuilder
    /// 生成的源文件
    public var source: Source

    public init() {
        this.codeBuffer = StringBuilder()
        this.outputCodeBuffer = StringBuilder()
        this.source = Source()
    }

    /// 生成宏 ID
    // 严格翻译自: entry_points.zig:265 generateID
    public static func generateID(entryPath: String, functionName: String): Int32 {
        let specifier = "bun://macro#" + hashHex(entryPath + functionName) + ".js"
        return generateIDFromSpecifier(specifier)
    }

    /// 从说明符生成 ID
    // 严格翻译自: entry_points.zig:279 generateIDFromSpecifier
    public static func generateIDFromSpecifier(specifier: String): Int32 {
        return Int32(hash(specifier) & 0xFFFFFFFF)
    }

    /// 生成宏入口点代码
    // 严格翻译自: entry_points.zig:283 generate
    public func generate(importPath: PathName, functionName: String,
                         macroId: Int32, macroLabel: String): Unit {
        let dirToUse = if (importPath.dir.length == 0) "" else importPath.dirWithTrailingSlash()
        let code = StringBuilder()

        code.append("//Auto-generated file\n")
        code.append("var Macros;\n")
        code.append("try {\n")
        code.append("  Macros = await import('${dirToUse}${importPath.filename}');\n")
        code.append("} catch (err) {\n")
        code.append("   console.error(\"Error importing macro\");\n")
        code.append("   throw err;\n")
        code.append("}\n")
        code.append("if (!('${functionName}' in Macros)) {\n")
        code.append("  throw new Error(\"Macro '${functionName}' not found in '${dirToUse}${importPath.filename}'\");\n")
        code.append("}\n")
        code.append("\n")
        code.append("Bun.registerMacro(${macroId}, Macros['${functionName}']);\n")

        source = Source(path: macroLabel, contents: code.toString(), index: -1)
    }
}

// ============================================================================
// 辅助类型
// ============================================================================

/// 路径名称
public class PathName {
    /// 目录
    public var dir: String
    /// 基础名
    public var base: String
    /// 文件名
    public var filename: String
    /// 扩展名
    public var ext: String

    public init(dir: String, base: String, filename: String, ext: String) {
        this.dir = dir
        this.base = base
        this.filename = filename
        this.ext = ext
    }

    public init() {
        this.dir = ""
        this.base = ""
        this.filename = ""
        this.ext = ""
    }

    /// 带尾部斜杠的目录
    public func dirWithTrailingSlash(): String {
        if (dir.length > 0 && !dir.endsWith("/")) {
            return dir + "/"
        }
        return dir
    }
}

/// 哈希工具
private func hash(input: String): UInt64 {
    var h: UInt64 = 5381
    for (c in input) {
        h = ((h << 5) + h) + UInt64(c.value)
    }
    return h
}

private func hashHex(input: String): String {
    return hash(input).toHexString()
}
