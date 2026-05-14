// G (Global) - 模块级别的全局类型定义
// 严格翻译自: src/js_parser/ast/G.zig
//
// 此文件定义了与模块导入/导出记录、模块信息、解析信息等相关的全局类型。
// 这些类型贯穿解析器、链接器和代码生成器，用于跟踪模块间的依赖关系。
//
// 对应 Bun 源码中的:
//   src/bundler/bundler.zig - Bun Bundler 中的 Module / Record / Resolver
//   src/resolver/resolver.zig - Bun Resolver
//   src/js_parser/ast/G.zig - 全局类型辅助
package bao_parser

import bao_core.*
import bao_collections.*

// ============================================================================
// ImportKind - 导入类型
// 严格翻译自: src/js_parser/js_parser.zig
//   pub const ImportKind = enum { import_statement, re_export, require }
// ============================================================================

/// 导入类型 - 对应 Bun ImportKind
public enum ImportKind {
    | Import    // import 语句
    | ReExport  // re-export (export { x } from "...")
    | Require   // require() 调用

    /// 是否为导入语句
    public func isImport(): Bool {
        match (this) {
            case Import => true
            case _ => false
        }
    }

    /// 是否为重新导出
    public func isReExport(): Bool {
        match (this) {
            case ReExport => true
            case _ => false
        }
    }

    /// 是否为 require 调用
    public func isRequire(): Bool {
        match (this) {
            case Require => true
            case _ => false
        }
    }
}

// ============================================================================
// ExportKind - 导出类型
// 严格翻译自: src/js_parser/js_parser.zig
//   pub const ExportKind = enum { named, default, star, star_all }
// ============================================================================

/// 导出类型 - 对应 Bun ExportKind
public enum ExportKind {
    | Named     // export { foo, bar }
    | Default   // export default ...
    | Star      // export * as ns from "..."
    | StarAll   // export * from "..."

    /// 是否为命名导出
    public func isNamed(): Bool {
        match (this) {
            case Named => true
            case _ => false
        }
    }

    /// 是否为默认导出
    public func isDefault(): Bool {
        match (this) {
            case Default => true
            case _ => false
        }
    }

    /// 是否为星号导出 (包含 Star 和 StarAll)
    public func isStar(): Bool {
        match (this) {
            case Star | StarAll => true
            case _ => false
        }
    }
}

// ============================================================================
// ResolveKind - 解析类型
// 严格翻译自: src/resolver/resolver.zig
//   pub const ResolveKind = enum {
//       builtin, external, relative, absolute, package
//   }
// ============================================================================

/// 解析类型 - 对应 Bun ResolveKind
public enum ResolveKind {
    | Builtin   // 内置模块 (如 "node:path", "node:fs")
    | External  // 外部模块 (通过 external 配置排除)
    | Relative  // 相对路径 (以 ./ 或 ../ 开头)
    | Absolute  // 绝对路径 (以 / 开头)
    | Package   // 包路径 (如 "lodash", "react")

    /// 是否为内置模块
    public func isBuiltin(): Bool {
        match (this) {
            case Builtin => true
            case _ => false
        }
    }

    /// 是否为外部模块
    public func isExternal(): Bool {
        match (this) {
            case External => true
            case _ => false
        }
    }

    /// 是否为相对路径
    public func isRelative(): Bool {
        match (this) {
            case Relative => true
            case _ => false
        }
    }

    /// 是否为绝对路径
    public func isAbsolute(): Bool {
        match (this) {
            case Absolute => true
            case _ => false
        }
    }

    /// 是否为包路径
    public func isPackage(): Bool {
        match (this) {
            case Package => true
            case _ => false
        }
    }
}

// ============================================================================
// GImport - 导入记录
// 严格翻译自: src/js_parser/js_parser.zig
//   pub const Import = struct {
//       import_kind: ImportKind,
//       path: string,
//       namespace_ref: Ref,
//       default_name: string,
//       items: []ClauseItem,
//       is_type: bool,
//       is_default: bool,
//       star: bool,
//       record_index: Index,
//   }
// ============================================================================

/// 导入记录 - 对应 Bun Import
/// 表示一个 import 语句或 require 调用的完整信息
public class GImport {
    /// 导入类型 - 对应 Import.import_kind
    public var importKind: ImportKind
    /// 模块路径 - 对应 Import.path
    public var path: String
    /// 命名空间引用 - 对应 Import.namespace_ref
    public var namespaceRef: Ref
    /// 默认导入名称 - 对应 Import.default_name
    public var defaultName: String
    /// 导入条目列表 - 对应 Import.items
    public var items: ArrayList<ClauseItem>
    /// 是否为类型导入 (import type) - 对应 Import.is_type
    public var isType: Bool
    /// 是否为默认导入 - 对应 Import.is_default
    public var isDefault: Bool
    /// 是否为星号导入 (import * as) - 对应 Import.star
    public var star: Bool
    /// 记录索引 - 对应 Import.record_index
    public var recordIndex: Int64

    public init() {
        importKind = ImportKind.Import
        path = ""
        namespaceRef = Ref.NONE
        defaultName = ""
        items = ArrayList<ClauseItem>()
        isType = false
        isDefault = false
        star = false
        recordIndex = -1
    }

    public init(importKind: ImportKind, path: String) {
        this.importKind = importKind
        this.path = path
        namespaceRef = Ref.NONE
        defaultName = ""
        items = ArrayList<ClauseItem>()
        isType = false
        isDefault = false
        star = false
        recordIndex = -1
    }

    public init(importKind: ImportKind, path: String, namespaceRef: Ref,
                defaultName: String, items: ArrayList<ClauseItem>,
                isType: Bool, isDefault: Bool, star: Bool, recordIndex: Int64) {
        this.importKind = importKind
        this.path = path
        this.namespaceRef = namespaceRef
        this.defaultName = defaultName
        this.items = items
        this.isType = isType
        this.isDefault = isDefault
        this.star = star
        this.recordIndex = recordIndex
    }

    /// 获取导入的描述信息
    public func description(): String {
        if (star) {
            return "import * as ... from \"${path}\""
        }
        if (isDefault && items.size > 0) {
            return "import ${defaultName}, { ... } from \"${path}\""
        }
        if (isDefault) {
            return "import ${defaultName} from \"${path}\""
        }
        if (items.size > 0) {
            return "import { ... } from \"${path}\""
        }
        return "import \"${path}\""
    }

    /// 是否为空导入 (仅副作用)
    public func isSideEffectOnly(): Bool {
        return !isDefault && !star && items.size == 0
    }
}

// ============================================================================
// GExport - 导出记录
// 严格翻译自: src/js_parser/js_parser.zig
//   pub const Export = struct {
//       export_kind: ExportKind,
//       name: string,
//       alias: string,
//       ref: Ref,
//       loc: Loc,
//       is_type: bool,
//       source: string,
//       record_index: Index,
//   }
// ============================================================================

/// 导出记录 - 对应 Bun Export
/// 表示一个 export 语句的完整信息
public class GExport {
    /// 导出类型 - 对应 Export.export_kind
    public var exportKind: ExportKind
    /// 导出名称 - 对应 Export.name
    public var name: String
    /// 别名 - 对应 Export.alias
    public var alias: String
    /// 符号引用 - 对应 Export.ref
    public var ref: Ref
    /// 源码位置 - 对应 Export.loc
    public var loc: Loc
    /// 是否为类型导出 - 对应 Export.is_type
    public var isType: Bool
    /// 来源模块路径 - 对应 Export.source
    /// 非 None 时表示 re-export: export { x } from "..."
    public var source: String
    /// 记录索引 - 对应 Export.record_index
    public var recordIndex: Int64

    public init() {
        exportKind = ExportKind.Named
        name = ""
        alias = ""
        ref = Ref.NONE
        loc = Loc.EMPTY
        isType = false
        source = ""
        recordIndex = -1
    }

    public init(exportKind: ExportKind, name: String, alias: String,
                ref: Ref, loc: Loc) {
        this.exportKind = exportKind
        this.name = name
        this.alias = alias
        this.ref = ref
        this.loc = loc
        isType = false
        source = ""
        recordIndex = -1
    }

    public init(exportKind: ExportKind, name: String, alias: String,
                ref: Ref, loc: Loc, isType: Bool, source: String,
                recordIndex: Int64) {
        this.exportKind = exportKind
        this.name = name
        this.alias = alias
        this.ref = ref
        this.loc = loc
        this.isType = isType
        this.source = source
        this.recordIndex = recordIndex
    }

    /// 是否为重新导出 (从其他模块导出)
    public func isReExport(): Bool {
        return source.size > 0
    }

    /// 获取有效名称 (优先使用别名)
    public func effectiveName(): String {
        if (alias.size > 0) {
            return alias
        }
        return name
    }

    /// 获取导出的描述信息
    public func description(): String {
        match (exportKind) {
            case Default => "export default ${name}"
            case Star => "export * as ${name} from \"${source}\""
            case StarAll => "export * from \"${source}\""
            case Named => {
                if (alias.size > 0 && alias != name) {
                    return "export { ${name} as ${alias} }"
                }
                return "export { ${name} }"
            }
        }
    }
}

// ============================================================================
// GRecord - 模块记录 (导入/导出追踪)
// 严格翻译自: src/bundler/bundler.zig
//   pub const Record = struct {
//       imports: ArrayList(Import),
//       exports: ArrayList(Export),
//       exports_kind: ExportsKind,
//       has_star_export: bool,
//       has_default_export: bool,
//   }
// ============================================================================

/// 模块记录 - 对应 Bun Record
/// 跟踪单个源文件的所有导入和导出信息
public class GRecord {
    /// 导入列表 - 对应 Record.imports
    public var imports: ArrayList<GImport>
    /// 导出列表 - 对应 Record.exports
    public var exports: ArrayList<GExport>
    /// 模块导出类型 - 对应 Record.exports_kind
    public var exportsKind: ExportsKind
    /// 是否包含星号导出 (export *) - 对应 Record.has_star_export
    public var hasStarExport: Bool
    /// 是否包含默认导出 (export default) - 对应 Record.has_default_export
    public var hasDefaultExport: Bool

    public init() {
        imports = ArrayList<GImport>()
        exports = ArrayList<GExport>()
        exportsKind = ExportsKind.None
        hasStarExport = false
        hasDefaultExport = false
    }

    /// 添加导入记录 - 对应 Record.addImport()
    public func addImport(imp: GImport): Int64 {
        let idx = Int64(imports.size)
        imp.recordIndex = idx
        imports.append(imp)
        return idx
    }

    /// 添加导出记录 - 对应 Record.addExport()
    /// 同时更新 hasStarExport 和 hasDefaultExport 标志
    public func addExport(exp: GExport): Int64 {
        let idx = Int64(exports.size)
        exp.recordIndex = idx
        exports.append(exp)

        // 更新标志
        if (exp.exportKind.isStar()) {
            hasStarExport = true
        }
        if (exp.exportKind.isDefault()) {
            hasDefaultExport = true
        }

        // 更新 exportsKind
        if (exportsKind == ExportsKind.None) {
            exportsKind = ExportsKind.Esm
        }

        return idx
    }

    /// 根据名称查找导出 - 对应 Record.findExport()
    /// 返回匹配的导出记录，或 None
    public func findExport(name: String): ?GExport {
        for (exp in exports) {
            let effectiveName = exp.effectiveName()
            if (effectiveName == name) {
                return Some(exp)
            }
        }
        return None
    }

    /// 根据路径查找导入 - 对应 Record.findImport()
    /// 返回匹配路径的导入记录列表
    public func findImport(path: String): ArrayList<GImport> {
        var result = ArrayList<GImport>()
        for (imp in imports) {
            if (imp.path == path) {
                result.append(imp)
            }
        }
        return result
    }

    /// 查找默认导出 - 便捷方法
    public func findDefaultExport(): ?GExport {
        for (exp in exports) {
            if (exp.exportKind.isDefault()) {
                return Some(exp)
            }
        }
        return None
    }

    /// 查找所有命名导出
    public func findNamedExports(): ArrayList<GExport> {
        var result = ArrayList<GExport>()
        for (exp in exports) {
            if (exp.exportKind.isNamed()) {
                result.append(exp)
            }
        }
        return result
    }

    /// 查找所有星号导出
    public func findStarExports(): ArrayList<GExport> {
        var result = ArrayList<GExport>()
        for (exp in exports) {
            if (exp.exportKind.isStar()) {
                result.append(exp)
            }
        }
        return result
    }

    /// 获取所有导出的名称
    public func exportNames(): ArrayList<String> {
        var names = ArrayList<String>()
        for (exp in exports) {
            let effectiveName = exp.effectiveName()
            if (effectiveName.size > 0) {
                names.append(effectiveName)
            }
        }
        return names
    }

    /// 获取所有导入的路径 (去重)
    public func importPaths(): ArrayList<String> {
        var paths = ArrayList<String>()
        for (imp in imports) {
            var found = false
            for (p in paths) {
                if (p == imp.path) {
                    found = true
                    break
                }
            }
            if (!found && imp.path.size > 0) {
                paths.append(imp.path)
            }
        }
        return paths
    }

    /// 是否有任何导出
    public func hasExports(): Bool {
        return exports.size > 0
    }

    /// 是否有任何导入
    public func hasImports(): Bool {
        return imports.size > 0
    }

    /// 重置记录
    public func reset(): Unit {
        imports.clear()
        exports.clear()
        exportsKind = ExportsKind.None
        hasStarExport = false
        hasDefaultExport = false
    }
}

// ============================================================================
// GModule - 模块信息
// 严格翻译自: src/bundler/bundler.zig
//   pub const Module = struct {
//       path: string,
//       source: Source,
//       record: Record,
//       ast: ?Stmt,
//       exports_kind: ExportsKind,
//       is_entry_point: bool,
//   }
// ============================================================================

/// 模块信息 - 对应 Bun Module
/// 表示一个完整的模块，包含源码、AST、导入/导出记录等
public class GModule {
    /// 模块文件路径 - 对应 Module.path
    public var path: String
    /// 源文件 - 对应 Module.source
    public var source: Source
    /// 导入/导出记录 - 对应 Module.record
    public var record: GRecord
    /// 根 AST 节点 - 对应 Module.ast
    /// 解析完成后为模块顶层语句，解析前为 None
    public var ast: ?Stmt
    /// 模块导出类型 - 对应 Module.exports_kind
    public var exportsKind: ExportsKind
    /// 是否为入口点 - 对应 Module.is_entry_point
    public var isEntryPoint: Bool

    public init(path: String) {
        this.path = path
        this.source = Source(path, "")
        this.record = GRecord()
        ast = None
        exportsKind = ExportsKind.None
        isEntryPoint = false
    }

    public init(path: String, source: Source) {
        this.path = path
        this.source = source
        this.record = GRecord()
        ast = None
        exportsKind = ExportsKind.None
        isEntryPoint = false
    }

    public init(path: String, source: Source, isEntryPoint: Bool) {
        this.path = path
        this.source = source
        this.record = GRecord()
        ast = None
        exportsKind = ExportsKind.None
        this.isEntryPoint = isEntryPoint
    }

    /// 是否已解析 (AST 存在)
    public func isParsed(): Bool {
        match (ast) {
            case Some(_) => true
            case None => false
        }
    }

    /// 获取导入路径列表 (便捷方法)
    public func importPaths(): ArrayList<String> {
        return record.importPaths()
    }

    /// 获取导出名称列表 (便捷方法)
    public func exportNames(): ArrayList<String> {
        return record.exportNames()
    }

    /// 是否有默认导出
    public func hasDefaultExport(): Bool {
        return record.hasDefaultExport
    }

    /// 是否为 ESM 模块
    public func isEsm(): Bool {
        match (exportsKind) {
            case ExportsKind.Esm | ExportsKind.EsmWithDynamicFallback |
                 ExportsKind.EsmWithDynamicFallbackFromCjs => true
            case _ => false
        }
    }

    /// 是否为 CommonJS 模块
    public func isCjs(): Bool {
        match (exportsKind) {
            case ExportsKind.Cjs => true
            case _ => false
        }
    }
}

// ============================================================================
// GResolver - 解析信息
// 严格翻译自: src/resolver/resolver.zig
//   pub const Resolver = struct {
//       path: string,
//       package_name: string,
//       is_external: bool,
//       resolve_kind: ResolveKind,
//       diff_to_absolute: fn(from: string) -> string,
//   }
// ============================================================================

/// 解析信息 - 对应 Bun Resolver
/// 记录模块路径的解析结果
public class GResolver {
    /// 解析后的路径 - 对应 Resolver.path
    public var path: String
    /// 所属包名 - 对应 Resolver.package_name
    public var packageName: String
    /// 是否为外部模块 - 对应 Resolver.is_external
    public var isExternal: Bool
    /// 解析类型 - 对应 Resolver.resolve_kind
    public var resolveKind: ResolveKind

    public init() {
        path = ""
        packageName = ""
        isExternal = false
        resolveKind = ResolveKind.Package
    }

    public init(path: String, resolveKind: ResolveKind) {
        this.path = path
        packageName = ""
        isExternal = false
        this.resolveKind = resolveKind
    }

    public init(path: String, packageName: String, isExternal: Bool,
                resolveKind: ResolveKind) {
        this.path = path
        this.packageName = packageName
        this.isExternal = isExternal
        this.resolveKind = resolveKind
    }

    /// 计算从指定路径到此路径的相对路径差异，再转为绝对路径
    /// 对应 Bun Resolver.diffToAbsolute(from)
    /// 例如: diffToAbsolute("/project/src") 从 "/project/lib/module.cj"
    ///       返回 "/project/lib/module.cj" (已是绝对路径)
    public func diffToAbsolute(from: String): String {
        // 如果当前路径已经是绝对路径，直接返回
        if (path.size > 0 && path[0] == '/') {
            return path
        }

        // 如果当前路径为空，返回 from
        if (path.size == 0) {
            return from
        }

        // 基于 from 构建绝对路径
        var base = from
        // 去掉末尾的文件名，保留目录部分
        var lastSlash = -1
        for (i in 0..base.size) {
            if (base[Int64(i)] == '/') {
                lastSlash = Int64(i)
            }
        }
        if (lastSlash >= 0) {
            base = base[0..lastSlash]
        }

        // 拼接路径
        if (base.size > 0 && base[Int64(base.size) - 1] == '/') {
            return base + path
        }
        return base + "/" + path
    }

    /// 是否解析成功
    public func isResolved(): Bool {
        return path.size > 0
    }

    /// 获取解析结果的描述
    public func description(): String {
        var kindStr = match (resolveKind) {
            case Builtin => "builtin"
            case External => "external"
            case Relative => "relative"
            case Absolute => "absolute"
            case Package => "package"
        }
        return "[${kindStr}] ${path}"
    }
}

// ============================================================================
// GPart - 源文件部分
// 严格翻译自: src/bundler/bundler.zig
//   pub const Part = struct {
//       source: Source,
//       record: Record,
//       module: Module,
//       ast: ?Stmt,
//   }
// ============================================================================

/// 源文件部分 - 对应 Bun Part
/// 表示源文件的一个逻辑部分，用于代码分割和 tree shaking
public class GPart {
    /// 源文件 - 对应 Part.source
    public var source: Source
    /// 导入/导出记录 - 对应 Part.record
    public var record: GRecord
    /// 所属模块 - 对应 Part.module
    public var module: GModule
    /// AST 节点 - 对应 Part.ast
    public var ast: ?Stmt

    public init() {
        source = Source("", "")
        record = GRecord()
        module = GModule("")
        ast = None
    }

    public init(source: Source, record: GRecord, module: GModule) {
        this.source = source
        this.record = record
        this.module = module
        ast = None
    }

    public init(source: Source, record: GRecord, module: GModule, ast: Stmt) {
        this.source = source
        this.record = record
        this.module = module
        this.ast = Some(ast)
    }

    /// 是否已解析
    public func isParsed(): Bool {
        match (ast) {
            case Some(_) => true
            case None => false
        }
    }

    /// 获取源文件路径
    public func filePath(): String {
        return source.path
    }
}
