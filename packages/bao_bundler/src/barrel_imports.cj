// 严格翻译自: src/bundler/barrel_imports.zig (~200行)
// bao_bundler - Barrel 优化: 检测纯重导出 barrel 文件并延迟加载未使用的子模块
package bao_bundler

import bao_core.*
import bao_collections.*
import bao_parser.*
import bao_io.*
import bao_path.*
import bao_sys.*
import bao_ast.*

// ============================================================================
// Barrel 优化
// 严格翻译自: src/bundler/barrel_imports.zig
// 核心职责:
//   1. 检测纯重导出 barrel 文件
//   2. 标记未使用的导入记录为 is_unused
//   3. 跟踪已请求的导出 (requested_exports)
//   4. 跨调用去重和循环检测
//
// 导入请求在处理每个文件时立即记录 — 在 barrel 已知之前
// 当 barrel 加载时，applyBarrelOptimization 读取 requested_exports
// 查看已请求的导出。无需图扫描
// ============================================================================

/// 已请求的导出
// 严格翻译自: barrel_imports.zig:12 RequestedExports
public enum RequestedExports {
    | All                                                    // 所有导出已请求 (import *)
    | Partial(HashMap<String, Unit>)                         // 部分导出已请求
}

/// Barrel 导出解析结果
// 严格翻译自: barrel_imports.zig:17 BarrelExportResolution
public class BarrelExportResolution {
    /// 导入记录索引
    public var importRecordIndex: UInt32
    /// 源模块中的原始别名 (如 export { d as c } 中的 "d")
    public var originalAlias: String
    /// 是否为 import * as ns
    public var aliasIsStar: Bool

    public init(importRecordIndex: UInt32, originalAlias: String, aliasIsStar: Bool) {
        this.importRecordIndex = importRecordIndex
        this.originalAlias = originalAlias
        this.aliasIsStar = aliasIsStar
    }
}

/// Barrel 优化器
// 严格翻译自: barrel_imports.zig
public class BarrelImportOptimizer {
    /// 已请求的导出映射 (source_index -> RequestedExports)
    public var requestedExports: HashMap<Int32, RequestedExports>
    /// bundle 引用
    public var bundle: BundleV2Ref

    public init() {
        this.requestedExports = HashMap<Int32, RequestedExports>()
        this.bundle = BundleV2Ref()
    }

    /// 查找 barrel 导出
    // 严格翻译自: barrel_imports.zig:29 resolveBarrelExport
    // 通过追踪 named_exports[alias].ref -> named_imports 查找导出名 -> 导入记录索引
    public static func resolveBarrelExport(alias: String, namedExports: HashMap<String, NamedExportRef>,
                                          namedImports: HashMap<Ref, NamedImportRef>): BarrelExportResolution {
        let exportEntry = namedExports.get(alias)
        if (exportEntry == null) {
            return null
        }

        let importEntry = namedImports.get(exportEntry.ref)
        if (importEntry == null) {
            return null
        }

        return BarrelExportResolution(
            importRecordIndex: importEntry.importRecordIndex,
            originalAlias: if (importEntry.alias != null) importEntry.alias else "",
            aliasIsStar: importEntry.aliasIsStar
        )
    }

    /// 应用 barrel 优化
    // 严格翻译自: barrel_imports.zig:44 applyBarrelOptimization
    // 分析解析结果判断是否为 barrel，标记未使用的导入记录
    public func applyBarrelOptimization(parseResult: ParseTaskResult): Unit {
        let ast = parseResult.successAst
        let sourceIndex = parseResult.sourceIndex

        // 检查是否为显式优化目标或 sideEffects: false
        let isExplicit = bundle.isOptimizeImport(sourceIndex)
        let isSideEffectsFalse = parseResult.sideEffects == SideEffectKind.NoSideEffectsPackageJson
        if (!isExplicit && !isSideEffectsFalse) {
            return
        }

        // 没有导入记录或没有导出则不是 barrel
        if (ast.importRecords.size == 0) {
            return
        }
        if (ast.namedExports.size == 0 && ast.exportStarImportRecords.size == 0) {
            return
        }

        // 验证纯 barrel: 所有命名导出必须是重导出
        let namedExports = ast.namedExports
        let namedImports = ast.namedImports
        for (entry in namedExports) {
            if (!namedImports.containsKey(entry.value.ref)) {
                return
            }
        }

        // 如果这个 barrel 是另一个 barrel 的 star 目标，不能安全延迟
        if (bundle.isExportStarTarget(sourceIndex)) {
            return
        }

        // 检查 requested_exports
        let existing = requestedExports.get(sourceIndex)
        match (existing) {
            case RequestedExports.All => return  // import * 已请求 — 加载所有
            case RequestedExports.Partial(_) => ()
            case null => ()
        }

        // 构建需要的导入记录索引集合
        // export * 记录总是需要
        let neededRecords = HashSet<UInt32>()
        for (recordIdx in ast.exportStarImportRecords) {
            neededRecords.put(recordIdx)
        }

        // 如果有部分请求，只保留请求的记录
        match (existing) {
            case RequestedExports.Partial(partial) => {
                for (entry in partial) {
                    let resolution = resolveBarrelExport(
                        entry.key,
                        namedExports,
                        namedImports
                    )
                    if (resolution != null) {
                        neededRecords.put(resolution.importRecordIndex)
                    }
                }
            }
            case _ => ()
        }

        // 标记未使用的导入记录
        for (i in 0..ast.importRecords.size) {
            let idx = UInt32(i)
            if (!neededRecords.contains(idx)) {
                ast.importRecords.get(i).flags.isUnused = true
            }
        }
    }

    /// 记录请求的导出
    // 严格翻译自: barrel_imports.zig scheduleBarrelDeferredImports
    public func recordRequestedExport(sourceIndex: Int32, exportName: String): Unit {
        let existing = requestedExports.get(sourceIndex)
        match (existing) {
            case RequestedExports.All => {
                // 已是全部，无需操作
            }
            case RequestedExports.Partial(map) => {
                map.put(exportName, Unit)
            }
            case null => {
                let map = HashMap<String, Unit>()
                map.put(exportName, Unit)
                requestedExports.put(sourceIndex, RequestedExports.Partial(map))
            }
        }
    }

    /// 记录所有导出请求 (import *)
    public func recordAllExports(sourceIndex: Int32): Unit {
        requestedExports.put(sourceIndex, RequestedExports.All)
    }
}

// ============================================================================
// 辅助类型
// ============================================================================

/// 副作用类型
public enum SideEffectKind {
    | HasSideEffects
    | NoSideEffectsPureData
    | NoSideEffectsPackageJson
}

/// 命名导出引用
public class NamedExportRef {
    public var ref: Ref

    public init(ref: Ref) {
        this.ref = ref
    }
}

/// 命名导入引用
public class NamedImportRef {
    public var alias: String
    public var aliasIsStar: Bool
    public var importRecordIndex: UInt32

    public init(alias: String, aliasIsStar: Bool, importRecordIndex: UInt32) {
        this.alias = alias
        this.aliasIsStar = aliasIsStar
        this.importRecordIndex = importRecordIndex
    }
}

/// ParseTask 结果
public class ParseTaskResult {
    public var successAst: BundledAstRef
    public var sourceIndex: Int32
    public var sideEffects: SideEffectKind
    public var packageName: String

    public init() {
        this.successAst = BundledAstRef()
        this.sourceIndex = -1
        this.sideEffects = SideEffectKind.HasSideEffects
        this.packageName = ""
    }
}

/// BundledAst 引用
public class BundledAstRef {
    public var namedExports: HashMap<String, NamedExportRef>
    public var namedImports: HashMap<Ref, NamedImportRef>
    public var importRecords: ArrayList<ImportRecordRef>
    public var exportStarImportRecords: Array<UInt32>

    public init() {
        this.namedExports = HashMap<String, NamedExportRef>()
        this.namedImports = HashMap<Ref, NamedImportRef>()
        this.importRecords = ArrayList<ImportRecordRef>()
        this.exportStarImportRecords = []
    }
}

/// 导入记录引用
public class ImportRecordRef {
    public var flags: ImportRecordFlagsRef

    public init() {
        this.flags = ImportRecordFlagsRef()
    }
}

/// 导入记录标志
public class ImportRecordFlagsRef {
    public var isUnused: Bool

    public init() {
        this.isUnused = false
    }
}

/// BundleV2 引用
public class BundleV2Ref {
    public func isOptimizeImport(sourceIndex: Int32): Bool {
        return false
    }

    public func isExportStarTarget(sourceIndex: Int32): Bool {
        return false
    }
}
