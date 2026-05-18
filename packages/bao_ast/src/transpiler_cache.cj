// 转译器缓存
// 严格翻译自: src/ast/transpiler_cache.rs (108行)
//   bun.jsc.RuntimeTranspilerCache
//   包含:
//     - RuntimeTranspilerCache: 运行时转译器缓存
//     - 输入/输出哈希、导出类型等缓存字段
package bao_ast

import bao_core.*

// ============================================================================
// RuntimeTranspilerCache - 运行时转译器缓存
// 严格翻译自: transpiler_cache.rs:15-108
//   pub struct RuntimeTranspilerCache {
//       input_hash, input_byte_length, features_hash,
//       exports_kind, output_code, entry, impl
//   }
// ============================================================================

/// 运行时转译器缓存 - 对应 Bun RuntimeTranspilerCache
/// 解析器和打印机共享的转译器缓存，避免重复转译。
/// 具体的磁盘 I/O 和 JS 引擎调度由更高层级的 bun_bundler/cache 实现。
public class RuntimeTranspilerCache {
    /// 输入哈希 - 源文件内容哈希
    public var inputHash: ?UInt64
    /// 输入字节长度
    public var inputByteLength: ?UInt64
    /// 特性哈希 - 编译选项哈希
    public var featuresHash: ?UInt64
    /// 导出类型
    public var exportsKind: ExportsKind
    /// 缓存命中时的输出代码
    public var outputCode: ?String
    /// 是否禁用
    public var isDisabled: Bool

    public init() {
        inputHash = None
        inputByteLength = None
        featuresHash = None
        exportsKind = ExportsKind.None
        outputCode = None
        isDisabled = true
    }

    /// 获取缓存 - 对应 RuntimeTranspilerCache.get()
    /// 返回 true 表示缓存命中
    public func get(source: Source): Bool {
        if (isDisabled) {
            return false
        }
        // 简化: 实际实现需要检查哈希并从磁盘/内存读取
        outputCode.isSome()
    }

    /// 存入缓存 - 对应 RuntimeTranspilerCache.put()
    public func put(outputCode: String): Unit {
        if (inputHash.isNone()) {
            return
        }
        this.outputCode = Some(outputCode)
    }

    /// 检查是否禁用 - 对应 RuntimeTranspilerCache.is_disabled()
    public func checkDisabled(): Bool {
        isDisabled
    }
}

/// 导出类型 - 对应 Bun ExportsKind
public enum ExportsKind {
    | None
    | Cjs
    | Esm
    | EsmWithDynamicFallback
    | EsmWithDynamicFallbackFromCjs

    public operator func ==(right: ExportsKind): Bool {
        ordinal() == right.ordinal()
    }

    public func ordinal(): Int64 {
        match (this) {
            case None => 0
            case Cjs => 1
            case Esm => 2
            case EsmWithDynamicFallback => 3
            case EsmWithDynamicFallbackFromCjs => 4
        }
    }
}

/// 源文件引用 - 简化版本
public class Source {
    public var path: String
    public var contents: String

    public init(path: String, contents: String) {
        this.path = path
        this.contents = contents
    }
}
