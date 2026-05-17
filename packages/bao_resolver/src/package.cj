// bao_resolver - 模块解析器
// 严格翻译自: src/resolver/
//   src/resolver/resolver.zig - 主解析器 (~20000行)
//   src/resolver/package_json.zig - package.json 解析
//   src/resolver/tsconfig_json.zig - tsconfig.json 解析
//   src/resolver/dir_info.zig - 目录信息缓存
//   src/resolver/fs.zig - 文件系统抽象
//   src/resolver/data_url.zig - Data URL 处理
//
// Bun 的解析器是其核心模块之一，负责:
//   1. 将模块说明符 (import specifier) 解析为文件系统路径
//   2. 读取和缓存 package.json / tsconfig.json
//   3. 处理 Node.js 兼容的模块解析算法
//   4. 处理 exports/imports 条件导出
//   5. 处理 browser 字段替换
//   6. 处理 TypeScript 路径映射
package bao_resolver

import bao_core.*
import bao_collections.*
import bao_io.*
import bao_path.*

// ============================================================================
// ResolveResult - 解析结果
// 严格翻译自: src/resolver/resolver.zig 中 ResolveResult
// Bun 的解析结果包含路径、模块类型、以及调试信息

// ============================================================================
// ResolveError - 解析错误
// 严格翻译自: src/resolver/resolver.zig 中的错误类型
// ============================================================================

/// 解析错误类型
public enum ResolveErrorKind {
    | ModuleNotFound        // 模块未找到
    | PackageNotFound       // 包未找到
    | InvalidSpecifier      // 无效说明符
    | InvalidPackageConfig  // 无效包配置
    | PathNotExported       // 路径未导出
    | UnsupportedImport     // 不支持的导入
    | CircularDependency    // 循环依赖
    | IO                    // IO 错误
}

/// 解析错误
public class ResolveError {
    public var kind: ResolveErrorKind
    public var message: String
    public var specifier: String
    public var fromPath: String

    public init(kind: ResolveErrorKind, message: String) {
        this.kind = kind
        this.message = message
        specifier = ""
        fromPath = ""
    }

    public init(kind: ResolveErrorKind, message: String, specifier: String, fromPath: String) {
        this.kind = kind
        this.message = message
        this.specifier = specifier
        this.fromPath = fromPath
    }

    public func toString(): String {
        return "ResolveError: ${message} (specifier=\"${specifier}\", from=\"${fromPath}\")"
    }
}

// ============================================================================
// DirInfo - 目录信息
// 严格翻译自: src/resolver/dir_info.zig
// Bun 使用 DirInfo 缓存目录结构和 package.json 查找结果

/// 简单的二元组
public class Tuple2<A, B> {
    public var first: A
    public var second: B

    public init(first: A, second: B) {
        this.first = first
        this.second = second
    }
}
