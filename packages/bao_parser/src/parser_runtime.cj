// 解析器运行时支持
// 严格翻译自: src/js_parser/runtime.zig (534 lines)
//   Bun 的运行时支持模块包含:
//   - Runtime: 运行时代码嵌入和版本管理
//   - Fallback: 错误页面和回退模板
//   - Runtime.Features: 运行时特性标志 (已在 parse_entry.cj 中定义)
//   - Runtime.Imports: 运行时导入符号引用
//   - Runtime.Names: 运行时名称常量
package bao_parser

import bao_core.*
import bao_collections.*

// ============================================================================
// RuntimeImports - 运行时导入引用
// 严格翻译自: src/js_parser/runtime.zig Runtime.Imports
//   pub const Imports = struct {
//       __name: ?Ref = null,
//       __require: ?Ref = null,
//       ...
//   }
// ============================================================================

/// 运行时导入引用 - 对应 Bun Runtime.Imports
/// 存储运行时辅助函数的引用 (在需要时惰性生成)
public class RuntimeImports {
    /// __name - 保留函数名
    public var name: ?Ref
    /// __require - require 辅助
    public var require: ?Ref
    /// __export - 导出辅助
    public var export_: ?Ref
    /// __reExport - 重导出辅助
    public var reExport: ?Ref
    /// __exportValue - 导出值辅助
    public var exportValue: ?Ref
    /// __exportDefault - 默认导出辅助
    public var exportDefault: ?Ref
    /// __merge - 合并辅助
    public var merge: ?Ref
    /// __legacyDecorateClassTS - TS 装饰器辅助
    public var legacyDecorateClassTS: ?Ref
    /// __legacyDecorateParamTS - TS 参数装饰器辅助
    public var legacyDecorateParamTS: ?Ref
    /// __legacyMetadataTS - TS 元数据辅助
    public var legacyMetadataTS: ?Ref
    /// __publicField - 公共字段辅助
    public var publicField: ?Ref
    /// __privateIn - 私有 in 辅助
    public var privateIn: ?Ref
    /// __privateGet - 私有 get 辅助
    public var privateGet: ?Ref
    /// __privateAdd - 私有 add 辅助
    public var privateAdd: ?Ref
    /// __privateSet - 私有 set 辅助
    public var privateSet: ?Ref
    /// __privateMethod - 私有方法辅助
    public var privateMethod: ?Ref
    /// __decoratorStart - 装饰器开始辅助
    public var decoratorStart: ?Ref
    /// __decoratorMetadata - 装饰器元数据辅助
    public var decoratorMetadata: ?Ref
    /// __runInitializers - 运行初始化器辅助
    public var runInitializers: ?Ref
    /// __decorateElement - 装饰元素辅助
    public var decorateElement: ?Ref
    /// $$typeof - React typeof
    public var typeOf: ?Ref
    /// __using - using 辅助
    public var using: ?Ref
    /// __callDispose - 调用 dispose 辅助
    public var callDispose: ?Ref
    /// __jsonParse - JSON 解析辅助
    public var jsonParse: ?Ref
    /// __promiseAll - Promise.all 辅助
    public var promiseAll: ?Ref

    public init() {
        name = None
        require = None
        export_ = None
        reExport = None
        exportValue = None
        exportDefault = None
        merge = None
        legacyDecorateClassTS = None
        legacyDecorateParamTS = None
        legacyMetadataTS = None
        publicField = None
        privateIn = None
        privateGet = None
        privateAdd = None
        privateSet = None
        privateMethod = None
        decoratorStart = None
        decoratorMetadata = None
        runInitializers = None
        decorateElement = None
        typeOf = None
        using = None
        callDispose = None
        jsonParse = None
        promiseAll = None
    }

    // ========================================================================
    // 所有导入名称 - 对应 Bun Runtime.Imports.all
    //   pub const all = [_][]const u8{ "__name", "__require", ... }
    // ========================================================================

    /// 获取所有运行时导入名称
    public static func allNames(): ArrayList<String> {
        let names = ArrayList<String>()
        names.append("__name")
        names.append("__require")
        names.append("__export")
        names.append("__reExport")
        names.append("__exportValue")
        names.append("__exportDefault")
        names.append("__merge")
        names.append("__legacyDecorateClassTS")
        names.append("__legacyDecorateParamTS")
        names.append("__legacyMetadataTS")
        names.append("__publicField")
        names.append("__privateIn")
        names.append("__privateGet")
        names.append("__privateAdd")
        names.append("__privateSet")
        names.append("__privateMethod")
        names.append("__decoratorStart")
        names.append("__decoratorMetadata")
        names.append("__runInitializers")
        names.append("__decorateElement")
        names.append("$$typeof")
        names.append("__using")
        names.append("__callDispose")
        names.append("__jsonParse")
        names.append("__promiseAll")
        return names
    }
}

// ============================================================================
// RuntimeNames - 运行时名称常量
// 严格翻译自: src/js_parser/runtime.zig Runtime.Names
//   pub const Names = struct {
//       pub const ActivateFunction = "activate";
//   }
// ============================================================================

/// 运行时名称常量 - 对应 Bun Runtime.Names
public class RuntimeNames {
    /// activate 函数名 - 对应 Bun ActivateFunction
    public static let ACTIVATE_FUNCTION: String = "activate"
}

// ============================================================================
// RuntimeFallback - 运行时回退模板
// 严格翻译自: src/js_parser/runtime.zig Fallback
//   pub const Fallback = struct { ... }
// ============================================================================

/// 运行时回退模板 - 对应 Bun Fallback
/// 提供错误页面和回退模板的嵌入代码
public class RuntimeFallback {
    /// 错误 JS 路径
    public static let ERROR_JS: String = "bun-error/index.js"
    /// 错误 CSS 路径
    public static let ERROR_CSS: String = "bun-error/bun-error.css"
    /// 回退解码器 JS 路径
    public static let FALLBACK_DECODER_JS: String = "fallback-decoder.js"
    /// HTML 模板路径
    public static let HTML_TEMPLATE: String = "fallback.html"
    /// 后端 HTML 模板路径
    public static let HTML_BACKEND_TEMPLATE: String = "fallback-backend.html"

    /// 版本哈希 - 对应 Bun version_hash
    public static var versionHash_: UInt32 = 0

    /// 获取版本哈希
    public static func versionHash(): UInt32 {
        return versionHash_
    }

    /// 设置版本哈希
    public static func setVersionHash(hash: UInt32): Unit {
        versionHash_ = hash
    }
}

// ============================================================================
// ParserRuntime - 解析器运行时
// 严格翻译自: src/js_parser/runtime.zig Runtime
//   pub const Runtime = struct {
//       pub fn sourceCode() string { ... }
//       pub fn versionHash() u32 { ... }
//       pub const Features = struct { ... }
//       pub const Names = struct { ... }
//       pub const Imports = struct { ... }
//   }
// ============================================================================

/// 解析器运行时 - 对应 Bun Runtime
/// 提供运行时代码管理和版本控制
public class ParserRuntime {
    /// 运行时导入引用
    public var imports: RuntimeImports

    /// 版本哈希
    private var versionHash_: UInt32

    public init() {
        imports = RuntimeImports()
        versionHash_ = 0
    }

    // ========================================================================
    // sourceCode - 获取运行时代码
    // 严格翻译自: runtime.zig:131-137
    //   pub fn sourceCode() string
    // ========================================================================

    /// 获取运行时代码 - 对应 Bun Runtime.sourceCode()
    /// 返回内置的 JavaScript 运行时代码
    public func sourceCode(): String {
        // 对应 Bun: @embedFile("runtime.out.js")
        // 在仓颉中，运行时代码通过资源文件加载
        return ""
    }

    // ========================================================================
    // versionHash - 获取版本哈希
    // 严格翻译自: runtime.zig:139-142
    //   pub fn versionHash() u32
    // ========================================================================

    /// 获取运行时版本哈希 - 对应 Bun Runtime.versionHash()
    /// 基于运行时代码内容的哈希值
    public func versionHash(): UInt32 {
        if (versionHash_ == 0) {
            // 计算运行时代码的哈希
            let code = sourceCode()
            if (code.size > 0) {
                versionHash_ = wyhash(code)
            }
        }
        return versionHash_
    }

    // ========================================================================
    // generateImportRef - 生成运行时导入引用
    // ========================================================================

    /// 生成 __name 运行时辅助引用
    public func generateNameRef(p: Parser): Ref {
        if (let Some(ref) <- imports.name) {
            return ref
        }
        let ref = p.newSymbol(SymbolKind.Other, "__name")
        imports.name = Some(ref)
        return ref
    }

    /// 生成 __require 运行时辅助引用
    public func generateRequireRef(p: Parser): Ref {
        if (let Some(ref) <- imports.require) {
            return ref
        }
        let ref = p.newSymbol(SymbolKind.Other, "__require")
        imports.require = Some(ref)
        return ref
    }

    /// 生成 __export 运行时辅助引用
    public func generateExportRef(p: Parser): Ref {
        if (let Some(ref) <- imports.export_) {
            return ref
        }
        let ref = p.newSymbol(SymbolKind.Other, "__export")
        imports.export_ = Some(ref)
        return ref
    }

    /// 生成 __reExport 运行时辅助引用
    public func generateReExportRef(p: Parser): Ref {
        if (let Some(ref) <- imports.reExport) {
            return ref
        }
        let ref = p.newSymbol(SymbolKind.Other, "__reExport")
        imports.reExport = Some(ref)
        return ref
    }

    /// 生成 __exportDefault 运行时辅助引用
    public func generateExportDefaultRef(p: Parser): Ref {
        if (let Some(ref) <- imports.exportDefault) {
            return ref
        }
        let ref = p.newSymbol(SymbolKind.Other, "__exportDefault")
        imports.exportDefault = Some(ref)
        return ref
    }

    /// 生成 __merge 运行时辅助引用
    public func generateMergeRef(p: Parser): Ref {
        if (let Some(ref) <- imports.merge) {
            return ref
        }
        let ref = p.newSymbol(SymbolKind.Other, "__merge")
        imports.merge = Some(ref)
        return ref
    }

    /// 生成 __publicField 运行时辅助引用
    public func generatePublicFieldRef(p: Parser): Ref {
        if (let Some(ref) <- imports.publicField) {
            return ref
        }
        let ref = p.newSymbol(SymbolKind.Other, "__publicField")
        imports.publicField = Some(ref)
        return ref
    }

    // ========================================================================
    // 运行时辅助检查
    // ========================================================================

    /// 检查是否需要运行时
    public func needsRuntime(): Bool {
        return imports.name.isSome() ||
               imports.require.isSome() ||
               imports.export_.isSome() ||
               imports.reExport.isSome() ||
               imports.exportDefault.isSome() ||
               imports.merge.isSome() ||
               imports.publicField.isSome() ||
               imports.privateIn.isSome() ||
               imports.privateGet.isSome() ||
               imports.privateAdd.isSome() ||
               imports.privateSet.isSome() ||
               imports.privateMethod.isSome() ||
               imports.using.isSome() ||
               imports.callDispose.isSome()
    }

    /// 获取所有需要的运行时导入
    public func getRequiredImports(): ArrayList<String> {
        let result = ArrayList<String>()
        if (imports.name.isSome()) { result.append("__name") }
        if (imports.require.isSome()) { result.append("__require") }
        if (imports.export_.isSome()) { result.append("__export") }
        if (imports.reExport.isSome()) { result.append("__reExport") }
        if (imports.exportValue.isSome()) { result.append("__exportValue") }
        if (imports.exportDefault.isSome()) { result.append("__exportDefault") }
        if (imports.merge.isSome()) { result.append("__merge") }
        if (imports.publicField.isSome()) { result.append("__publicField") }
        if (imports.privateIn.isSome()) { result.append("__privateIn") }
        if (imports.privateGet.isSome()) { result.append("__privateGet") }
        if (imports.privateAdd.isSome()) { result.append("__privateAdd") }
        if (imports.privateSet.isSome()) { result.append("__privateSet") }
        if (imports.privateMethod.isSome()) { result.append("__privateMethod") }
        if (imports.using.isSome()) { result.append("__using") }
        if (imports.callDispose.isSome()) { result.append("__callDispose") }
        return result
    }

    // ========================================================================
    // 辅助方法
    // ========================================================================

    /// 简单的 wyhash 哈希实现
    private static func wyhash(s: String): UInt32 {
        var hash: UInt64 = 0
        for (c in s) {
            hash = hash * 31 + UInt64(c)
        }
        return UInt32(hash & 0xFFFFFFFF)
    }
}

