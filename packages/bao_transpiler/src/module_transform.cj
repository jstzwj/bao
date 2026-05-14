// 模块格式转换器
// 严格翻译自: src/bundler/ 中 CJS <-> ESM 转换逻辑
//
// Bun 的模块转换在打包器中处理:
//   1. CJS -> ESM: require() -> import, module.exports -> export
//   2. ESM -> CJS: import -> require, export -> module.exports
//   3. 动态 import() 处理
//
// 参考:
//   src/bundler/graph.zig - 模块图构建
//   src/bundler/linker.zig - 模块链接和代码生成
//   src/js_parser/js_parser.zig - import/export 解析
package bao_transpiler

import bao_core.*
import bao_collections.*

// ============================================================================
// ModuleTransformer - 模块格式转换器
// 严格翻译自: Bun bundler 中 CJS/ESM 互转逻辑
// ============================================================================

/// 模块格式
public enum ModuleFormat {
    | ESM   // ES Module: import/export
    | CJS   // CommonJS: require/module.exports
    | IIFE  // Immediately Invoked Function Expression

    public func label(): String {
        match (this) {
            case ESM => "esm"
            case CJS => "cjs"
            case IIFE => "iife"
        }
    }
}

/// 模块格式转换器 - 对应 Bun bundler 中的模块转换
public class ModuleTransformer {
    private var source: String
    private var pos: Int64
    private var output: StringBuilder
    private var targetFormat: ModuleFormat

    public init(targetFormat: ModuleFormat) {
        source = ""
        pos = 0
        output = StringBuilder()
        this.targetFormat = targetFormat
    }

    /// 转换模块格式 - 主入口
    public func transform(source: String): String {
        match (targetFormat) {
            case ESM => return cjsToESM(source)
            case CJS => return esmToCJS(source)
            case IIFE => return wrapIIFE(esmToCJS(source))
        }
    }

    // ========================================================================
    // CJS -> ESM 转换
    // 严格对应 Bun bundler 中 CommonJS 模块转为 ES Module 的逻辑
    //
    // require("module") -> import ... from "module"
    // module.exports = ... -> export default ...
    // exports.foo = ... -> export ...
    // ========================================================================

    /// CJS 转 ESM - 对应 Bun 中 CJS 模块的 ESM 包装
    public func cjsToESM(source: String): String {
        this.source = source
        this.pos = 0
        this.output = StringBuilder()

        let requires = ArrayList<RequireInfo>()
        let exportsList = ArrayList<ExportInfo>()
        let body = StringBuilder()

        while (pos < source.length) {
            // 检测 require() 调用
            if (isRequireCall()) {
                let reqInfo = parseRequire()
                requires.append(reqInfo)
                // 在原位生成 import 占位符引用
                body.append("_import_${reqInfo.identifier}")
                continue
            }

            // 检测 module.exports = ...
            if (isModuleExports()) {
                let expInfo = parseModuleExports()
                exportsList.append(expInfo)
                continue
            }

            // 检测 exports.xxx = ...
            if (isExportsAssignment()) {
                let expInfo = parseExportsProperty()
                exportsList.append(expInfo)
                continue
            }

            // 检测 Object.defineProperty(exports, ...)
            if (isDefineProperty()) {
                skipDefineProperty()
                continue
            }

            body.append(source[Int64(pos)])
            pos += 1
        }

        // 生成 ESM 代码
        let sb = StringBuilder()

        // 生成 import 声明
        for (req in requires) {
            if (req.isDestructured) {
                // require("mod").foo -> import { foo } from "mod"
                sb.append("import { ${req.property} as _import_${req.identifier} } from \"${req.moduleSpecifier}\";\n")
            } else if (req.isNamespace) {
                // import * as name from "mod"
                sb.append("import * as _import_${req.identifier} from \"${req.moduleSpecifier}\";\n")
            } else {
                // import name from "mod"
                sb.append("import _import_${req.identifier} from \"${req.moduleSpecifier}\";\n")
            }
        }

        if (requires.size > 0) {
            sb.append("\n")
        }

        // 生成 export 声明
        for (exp in exportsList) {
            if (exp.isDefault) {
                sb.append("export default ")
                sb.append(exp.value)
                sb.append(";\n")
            } else {
                sb.append("export const ${exp.name} = ")
                sb.append(exp.value)
                sb.append(";\n")
            }
        }

        if (exportsList.size > 0) {
            sb.append("\n")
        }

        // 生成转换后的模块体
        sb.append(body.toString())

        return sb.toString()
    }

    /// 检测 require() 调用
    private func isRequireCall(): Bool {
        if (pos + 7 > source.length) {
            return false
        }
        if (!startsWithAt(source, pos, "require")) {
            return false
        }
        // 确保前面不是标识符字符
        if (pos > 0) {
            let prev = source[Int64(pos - 1)]
            let v = prev.value
            if ((v >= 97 && v <= 122) || (v >= 65 && v <= 90) ||
                v == 95 || v == 36 || (v >= 48 && v <= 57)) {
                return false
            }
        }
        // 检查后面是 '('
        let afterRequire = pos + 7
        if (afterRequire < source.length && source[Int64(afterRequire)] == Char('(')) {
            return true
        }
        return false
    }

    /// 解析 require() 调用
    private func parseRequire(): RequireInfo {
        pos += 7  // skip "require"
        skipWhitespace()

        // 跳过 '('
        if (pos < source.length && source[Int64(pos)] == Char('(')) {
            pos += 1
        }
        skipWhitespace()

        // 读取模块说明符
        let specifier = readStringLiteral()
        skipWhitespace()

        // 跳过 ')'
        if (pos < source.length && source[Int64(pos)] == Char(')')) {
            pos += 1
        }

        // 检查是否有属性访问: require("mod").property
        var property = ""
        var isDestructured = false
        var isNamespace = false

        if (pos < source.length && source[Int64(pos)] == Char('.')) {
            pos += 1
            property = readIdentifier()
        }

        // 生成唯一标识符
        let identifier = makeIdentifier(specifier)

        return RequireInfo(
            moduleSpecifier: specifier,
            identifier: identifier,
            isDestructured: property.length > 0,
            property: property,
            isNamespace: isNamespace
        )
    }

    /// 检测 module.exports
    private func isModuleExports(): Bool {
        return startsWithAt(source, pos, "module.exports")
    }

    /// 解析 module.exports = ...
    private func parseModuleExports(): ExportInfo {
        pos += 14  // skip "module.exports"
        skipWhitespace()

        // 检查是 module.exports = 还是 module.exports.xxx =
        if (pos < source.length && source[Int64(pos)] == Char('.')) {
            pos += 1
            let prop = readIdentifier()
            skipWhitespace()
            if (pos < source.length && source[Int64(pos)] == Char('=')) {
                pos += 1
                skipWhitespace()
                let value = readUntilSemicolon()
                return ExportInfo(name: prop, value: value, isDefault: false)
            }
        }

        // module.exports = ...
        if (pos < source.length && source[Int64(pos)] == Char('=')) {
            pos += 1
            skipWhitespace()
            let value = readUntilSemicolon()
            return ExportInfo(name: "", value: value, isDefault: true)
        }

        return ExportInfo(name: "", value: "", isDefault: false)
    }

    /// 检测 exports.xxx = ...
    private func isExportsAssignment(): Bool {
        if (!startsWithAt(source, pos, "exports.")) {
            return false
        }
        // 确保 "exports" 前面不是标识符字符
        if (pos > 0) {
            let prev = source[Int64(pos - 1)]
            let v = prev.value
            if ((v >= 97 && v <= 122) || (v >= 65 && v <= 90) ||
                v == 95 || v == 36 || (v >= 48 && v <= 57)) {
                return false
            }
        }
        return true
    }

    /// 解析 exports.xxx = ...
    private func parseExportsProperty(): ExportInfo {
        pos += 8  // skip "exports."
        let name = readIdentifier()
        skipWhitespace()

        if (pos < source.length && source[Int64(pos)] == Char('=')) {
            pos += 1
            skipWhitespace()
            let value = readUntilSemicolon()
            return ExportInfo(name: name, value: value, isDefault: false)
        }

        return ExportInfo(name: name, value: "", isDefault: false)
    }

    /// 检测 Object.defineProperty(exports, ...)
    private func isDefineProperty(): Bool {
        return startsWithAt(source, pos, "Object.defineProperty")
    }

    /// 跳过 Object.defineProperty 调用
    private func skipDefineProperty(): Unit {
        // 找到匹配的右括号
        while (pos < source.length && source[Int64(pos)] != Char('(')) {
            pos += 1
        }
        if (pos < source.length) {
            pos += 1
            var depth = 1
            while (pos < source.length && depth > 0) {
                if (source[Int64(pos)] == Char('(')) { depth += 1 }
                else if (source[Int64(pos)] == Char(')')) { depth -= 1 }
                pos += 1
            }
        }
        // 跳过分号
        if (pos < source.length && source[Int64(pos)] == Char(';')) {
            pos += 1
        }
    }

    // ========================================================================
    // ESM -> CJS 转换
    // 严格对应 Bun bundler 中 ES Module 转为 CommonJS 的逻辑
    //
    // import x from "mod" -> const x = require("mod")
    // import { a, b } from "mod" -> const { a, b } = require("mod")
    // import * as x from "mod" -> const x = require("mod")
    // export default x -> exports.default = x
    // export const x = ... -> exports.x = ...
    // export { a, b } -> exports.a = a; exports.b = b
    // export function foo() {} -> exports.foo = foo
    // ========================================================================

    /// ESM 转 CJS - 对应 Bun 中 ESM 模块的 CJS 包装
    public func esmToCJS(source: String): String {
        this.source = source
        this.pos = 0
        this.output = StringBuilder()

        // 收集所有 import 和 export 声明
        let imports = ArrayList<ImportDecl>()
        let exports = ArrayList<ExportDecl>()
        let body = StringBuilder()

        while (pos < source.length) {
            // 检测 import 声明
            if (isImportStatement()) {
                let imp = parseImportStatement()
                imports.append(imp)
                continue
            }

            // 检测 export 声明
            if (isExportStatement()) {
                let exp = parseExportStatement()
                exports.append(exp)
                continue
            }

            body.append(source[Int64(pos)])
            pos += 1
        }

        // 生成 CJS 代码
        let sb = StringBuilder()
        sb.append("\"use strict\";\n\n")

        // 生成 require() 调用
        for (imp in imports) {
            if (imp.isDefault) {
                if (imp.defaultName.length > 0) {
                    sb.append("const ${imp.defaultName} = require(\"${imp.moduleSpecifier}\").default;\n")
                }
            } else if (imp.isNamespace) {
                sb.append("const ${imp.namespaceName} = require(\"${imp.moduleSpecifier}\");\n")
            } else if (imp.names.size > 0) {
                let names = ArrayList<String>()
                for (n in imp.names) {
                    names.append(n)
                }
                sb.append("const { ${String.fromCString(names.toArray())} } = require(\"${imp.moduleSpecifier}\");\n")
            } else if (imp.defaultName.length > 0) {
                sb.append("const ${imp.defaultName} = require(\"${imp.moduleSpecifier}\");\n")
            }
        }

        if (imports.size > 0) {
            sb.append("\n")
        }

        // 生成 module.exports
        sb.append(body.toString())
        sb.append("\n")

        // 生成 export 赋值
        for (exp in exports) {
            if (exp.isDefault) {
                sb.append("module.exports.default = ${exp.name};\n")
            } else if (exp.isDeclaration) {
                // export const/let/var/function/class 已在 body 中声明
                sb.append("exports.${exp.name} = ${exp.name};\n")
            } else {
                // export { a, b }
                for (name in exp.names) {
                    sb.append("exports.${name} = ${name};\n")
                }
            }
        }

        return sb.toString()
    }

    /// 检测 import 语句
    private func isImportStatement(): Bool {
        if (!startsWithAt(source, pos, "import ")) {
            return false
        }
        // 确保 "import" 前面不是标识符字符
        if (pos > 0) {
            let prev = source[Int64(pos - 1)]
            let v = prev.value
            if ((v >= 97 && v <= 122) || (v >= 65 && v <= 90) ||
                v == 95 || v == 36 || (v >= 48 && v <= 57)) {
                return false
            }
        }
        // 排除 dynamic import: import("mod") 或 import.meta
        let afterImport = pos + 7
        if (afterImport < source.length) {
            let ch = source[Int64(afterImport)]
            if (ch == Char('(') || (ch == Char('.') && afterImport + 4 < source.length &&
                startsWithAt(source, afterImport, ".meta"))) {
                return false
            }
        }
        return true
    }

    /// 解析 import 声明
    private func parseImportStatement(): ImportDecl {
        pos += 7  // skip "import "
        skipWhitespace()

        let decl = ImportDecl()

        // 检测: import "mod" (副作用导入)
        if (source[Int64(pos)] == Char('"') || source[Int64(pos)] == Char('\'')) {
            decl.moduleSpecifier = readStringLiteral()
            skipWhitespace()
            skipSemicolon()
            return decl
        }

        // 检测: import defaultExport from "mod"
        // 检测: import { a, b } from "mod"
        // 检测: import * as name from "mod"
        // 检测: import name, { a, b } from "mod"

        if (source[Int64(pos)] == Char('{')) {
            // 命名导入: import { a, b as c } from "mod"
            pos += 1  // skip '{'
            skipWhitespace()
            let names = ArrayList<String>()
            while (pos < source.length && source[Int64(pos)] != Char('}')) {
                skipWhitespace()
                let name = readIdentifier()
                names.append(name)
                skipWhitespace()
                // 检查 as 别名
                if (startsWithAt(source, pos, "as ")) {
                    pos += 3
                    skipWhitespace()
                    let alias = readIdentifier()
                    // 保留原始名称用于 import
                    skipWhitespace()
                }
                if (pos < source.length && source[Int64(pos)] == Char(',')) {
                    pos += 1
                }
                skipWhitespace()
            }
            if (pos < source.length && source[Int64(pos)] == Char('}')) {
                pos += 1
            }
            decl.names = names
        } else if (startsWithAt(source, pos, "*")) {
            // 命名空间导入: import * as name from "mod"
            pos += 1  // skip '*'
            skipWhitespace()
            if (startsWithAt(source, pos, "as ")) {
                pos += 3
                skipWhitespace()
                decl.namespaceName = readIdentifier()
                decl.isNamespace = true
            }
        } else {
            // 默认导入: import name from "mod"
            decl.defaultName = readIdentifier()
            decl.isDefault = true
            skipWhitespace()

            // 检查是否有额外的命名导入: import name, { a, b } from "mod"
            if (pos < source.length && source[Int64(pos)] == Char(',')) {
                pos += 1
                skipWhitespace()
                if (source[Int64(pos)] == Char('{')) {
                    pos += 1
                    skipWhitespace()
                    let names = ArrayList<String>()
                    while (pos < source.length && source[Int64(pos)] != Char('}')) {
                        skipWhitespace()
                        let name = readIdentifier()
                        names.append(name)
                        skipWhitespace()
                        if (startsWithAt(source, pos, "as ")) {
                            pos += 3
                            skipWhitespace()
                            readIdentifier()
                            skipWhitespace()
                        }
                        if (pos < source.length && source[Int64(pos)] == Char(',')) {
                            pos += 1
                        }
                        skipWhitespace()
                    }
                    if (pos < source.length && source[Int64(pos)] == Char('}')) {
                        pos += 1
                    }
                    decl.names = names
                } else if (startsWithAt(source, pos, "*")) {
                    pos += 1
                    skipWhitespace()
                    if (startsWithAt(source, pos, "as ")) {
                        pos += 3
                        skipWhitespace()
                        decl.namespaceName = readIdentifier()
                        decl.isNamespace = true
                    }
                }
            }
        }

        skipWhitespace()

        // "from" 关键字
        if (startsWithAt(source, pos, "from")) {
            pos += 4
            skipWhitespace()
        }

        // 模块说明符
        decl.moduleSpecifier = readStringLiteral()
        skipWhitespace()
        skipSemicolon()

        return decl
    }

    /// 检测 export 语句
    private func isExportStatement(): Bool {
        if (!startsWithAt(source, pos, "export ")) {
            return false
        }
        if (pos > 0) {
            let prev = source[Int64(pos - 1)]
            let v = prev.value
            if ((v >= 97 && v <= 122) || (v >= 65 && v <= 90) ||
                v == 95 || v == 36 || (v >= 48 && v <= 57)) {
                return false
            }
        }
        return true
    }

    /// 解析 export 声明
    private func parseExportStatement(): ExportDecl {
        pos += 7  // skip "export "
        skipWhitespace()

        let decl = ExportDecl()

        // export default ...
        if (startsWithAt(source, pos, "default")) {
            pos += 7
            skipWhitespace()
            let value = readUntilSemicolon()
            decl.isDefault = true
            decl.name = value
            decl.isDeclaration = false
            return decl
        }

        // export { a, b, c }
        if (source[Int64(pos)] == Char('{')) {
            pos += 1
            skipWhitespace()
            while (pos < source.length && source[Int64(pos)] != Char('}')) {
                skipWhitespace()
                let name = readIdentifier()
                decl.names.append(name)
                skipWhitespace()
                if (startsWithAt(source, pos, "as ")) {
                    pos += 3
                    skipWhitespace()
                    readIdentifier()
                    skipWhitespace()
                }
                if (pos < source.length && source[Int64(pos)] == Char(',')) {
                    pos += 1
                }
                skipWhitespace()
            }
            if (pos < source.length && source[Int64(pos)] == Char('}')) {
                pos += 1
            }
            skipWhitespace()
            // export { ... } from "mod"
            if (startsWithAt(source, pos, "from")) {
                pos += 4
                skipWhitespace()
                decl.reexportFrom = readStringLiteral()
            }
            skipSemicolon()
            return decl
        }

        // export const/let/var/function/class/async
        let keyword = readIdentifier()
        skipWhitespace()
        let name = readIdentifier()
        decl.name = name
        decl.isDeclaration = true
        skipWhitespace()

        // 输出声明 (去掉 export 关键字)
        output.append("${keyword} ${name}")
        if (pos < source.length && source[Int64(pos)] == Char('=')) {
            pos += 1
            skipWhitespace()
            let value = readUntilSemicolon()
            output.append(" = ${value}")
        } else if (keyword == "function" || keyword == "class") {
            // 函数/类体
            let bodyStart = pos
            while (pos < source.length && source[Int64(pos)] != Char('{')) {
                pos += 1
            }
            if (pos < source.length) {
                let endBrace = findMatchingBrace(pos + 1)
                output.append(source.substring(Int64(bodyStart), Int64(endBrace + 1)))
                pos = endBrace + 1
            }
        }

        return decl
    }

    // ========================================================================
    // IIFE 包装
    // ========================================================================

    /// IIFE 包装 - 对应 Bun 的 IIFE 输出格式
    public func wrapIIFE(code: String): String {
        let sb = StringBuilder()
        sb.append("(function() {\n")
        sb.append("\"use strict\";\n")
        sb.append(code)
        sb.append("\n})();\n")
        return sb.toString()
    }

    // ========================================================================
    // 动态 import 处理
    // ========================================================================

    /// 处理动态 import() - 对应 Bun 的 dynamic import 支持
    /// 在 CJS 输出中，import() 无法直接转换，保留原样或转为 Promise
    public func transformDynamicImport(source: String): String {
        var result = source
        // 简化: 动态 import 在 CJS 中保持原样
        // 实际 Bun 使用自己的 module 要求系统来处理
        return result
    }

    // ========================================================================
    // 基础工具方法
    // ========================================================================

    private func skipWhitespace(): Unit {
        while (pos < source.length) {
            let ch = source[Int64(pos)]
            if (ch == Char(' ') || ch == Char('\t') || ch == Char('\n') || ch == Char('\r')) {
                pos += 1
            } else {
                break
            }
        }
    }

    private func readIdentifier(): String {
        let sb = StringBuilder()
        while (pos < source.length) {
            let ch = source[Int64(pos)]
            let v = ch.value
            if ((v >= 97 && v <= 122) || (v >= 65 && v <= 90) ||
                v == 95 || v == 36 || (v >= 48 && v <= 57)) {
                sb.append(ch)
                pos += 1
            } else {
                break
            }
        }
        return sb.toString()
    }

    private func readStringLiteral(): String {
        if (pos >= source.length) {
            return ""
        }
        let quote = source[Int64(pos)]
        pos += 1
        let sb = StringBuilder()
        while (pos < source.length) {
            let ch = source[Int64(pos)]
            if (ch == Char('\\') && pos + 1 < source.length) {
                sb.append(ch)
                pos += 1
                sb.append(source[Int64(pos)])
                pos += 1
            } else if (ch == quote) {
                pos += 1
                break
            } else {
                sb.append(ch)
                pos += 1
            }
        }
        return sb.toString()
    }

    private func readUntilSemicolon(): String {
        let sb = StringBuilder()
        var depth = 0
        while (pos < source.length) {
            let ch = source[Int64(pos)]
            if (ch == Char('(') || ch == Char('[') || ch == Char('{')) {
                depth += 1
                sb.append(ch)
                pos += 1
            } else if (ch == Char(')') || ch == Char(']') || ch == Char('}')) {
                if (depth > 0) { depth -= 1 }
                sb.append(ch)
                pos += 1
            } else if (depth == 0 && (ch == Char(';') || ch == Char('\n'))) {
                if (ch == Char(';')) { pos += 1 }
                break
            } else {
                sb.append(ch)
                pos += 1
            }
        }
        return sb.toString().trim()
    }

    private func skipSemicolon(): Unit {
        if (pos < source.length && source[Int64(pos)] == Char(';')) {
            pos += 1
        }
    }

    private func findMatchingBrace(start: Int64): Int64 {
        var depth = 1
        var i = start
        while (i < source.length && depth > 0) {
            let ch = source[Int64(i)]
            if (ch == Char('{')) { depth += 1 }
            else if (ch == Char('}')) { depth -= 1 }
            else if (ch == Char('\'') || ch == Char('"') || ch == Char('`')) {
                // 跳过字符串
                let q = ch
                i += 1
                while (i < source.length && source[Int64(i)] != q) {
                    if (source[Int64(i)] == Char('\\')) { i += 1 }
                    i += 1
                }
            }
            i += 1
        }
        return i - 1
    }

    private func makeIdentifier(specifier: String): String {
        // 从模块说明符生成有效标识符
        let sb = StringBuilder()
        var capitalize = true
        for (ch in specifier) {
            let v = ch.value
            if ((v >= 97 && v <= 122) || (v >= 65 && v <= 90) ||
                (v >= 48 && v <= 57)) {
                if (capitalize) {
                    sb.append(ch.toUpperCase())
                    capitalize = false
                } else {
                    sb.append(ch)
                }
            } else {
                capitalize = true
            }
        }
        return sb.toString()
    }

    private static func startsWithAt(s: String, index: Int64, prefix: String): Bool {
        if (index + prefix.length > s.length) {
            return false
        }
        for (i in 0..prefix.length) {
            if (s[Int64(index + i)] != prefix[Int64(i)]) {
                return false
            }
        }
        return true
    }
}

// ============================================================================
// 辅助数据类型
// ============================================================================

/// require() 调用信息
public class RequireInfo {
    public var moduleSpecifier: String
    public var identifier: String
    public var isDestructured: Bool
    public var property: String
    public var isNamespace: Bool

    public init(moduleSpecifier: String, identifier: String,
                isDestructured: Bool, property: String, isNamespace: Bool) {
        this.moduleSpecifier = moduleSpecifier
        this.identifier = identifier
        this.isDestructured = isDestructured
        this.property = property
        this.isNamespace = isNamespace
    }
}

/// export 信息
public class ExportInfo {
    public var name: String
    public var value: String
    public var isDefault: Bool

    public init(name: String, value: String, isDefault: Bool) {
        this.name = name
        this.value = value
        this.isDefault = isDefault
    }
}

/// import 声明
public class ImportDecl {
    public var moduleSpecifier: String
    public var defaultName: String
    public var namespaceName: String
    public var isDefault: Bool
    public var isNamespace: Bool
    public var names: ArrayList<String>

    public init() {
        moduleSpecifier = ""
        defaultName = ""
        namespaceName = ""
        isDefault = false
        isNamespace = false
        names = ArrayList<String>()
    }
}

/// export 声明
public class ExportDecl {
    public var name: String
    public var names: ArrayList<String>
    public var isDefault: Bool
    public var isDeclaration: Bool
    public var reexportFrom: String

    public init() {
        name = ""
        names = ArrayList<String>()
        isDefault = false
        isDeclaration = false
        reexportFrom = ""
    }
}
