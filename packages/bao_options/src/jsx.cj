// JSX - JSX 转换选项
// 严格翻译自: bun/src/options_types/jsx.rs
//   以及 bun/src/bundler/options.zig - JSX 命名空间
//   包含 Runtime, Pragma, ImportSource, Defaults 等 JSX 配置类型。
package bao_options

import bao_core.*

// ============================================================================
// JsxRuntime - JSX 运行时模式
// 严格翻译自: jsx.rs - Runtime (及 schema.zig - api.JsxRuntime)
//   #[repr(u8)]
//   pub enum Runtime { _None, Automatic, Classic, Solid }
// ============================================================================

/// JSX 运行时模式 - 对应 Bun JSX.Runtime
public enum JsxRuntime {
    | None         // 未指定
    | Automatic    // 自动运行时 (React 17+, jsx transforms)
    | Classic      // 经典运行时 (React.createElement)
    | Solid        // Solid JSX 运行时

    /// 从原始值解析
    public static func fromRaw(value: UInt8): JsxRuntime {
        match (value) {
            case 0 => JsxRuntime.None
            case 1 => JsxRuntime.Automatic
            case 2 => JsxRuntime.Classic
            case 3 => JsxRuntime.Solid
            case _ => JsxRuntime.None
        }
    }

    /// 转换为原始值
    public func toRaw(): UInt8 {
        match (this) {
            case None => 0
            case Automatic => 1
            case Classic => 2
            case Solid => 3
        }
    }
}

// ============================================================================
// RuntimeDevelopmentPair - 运行时与开发模式配对
// 严格翻译自: jsx.rs - RuntimeDevelopmentPair
//   pub struct RuntimeDevelopmentPair {
//       pub runtime: Runtime,
//       pub development: Option<bool>,
//   };
// ============================================================================

/// 运行时与开发模式配对 - 对应 Bun RuntimeDevelopmentPair
public class RuntimeDevelopmentPair {
    public var runtime: JsxRuntime
    public var development: ?Bool

    public init(runtime: JsxRuntime, development: ?Bool) {
        this.runtime = runtime
        this.development = development
    }
}

// ============================================================================
// RuntimeMap - 运行时名称映射
// 严格翻译自: jsx.rs - RUNTIME_MAP (ComptimeStringMap)
//   "classic" => Classic, "automatic" => Automatic, ...
// ============================================================================

/// 运行时名称映射工具 - 对应 Bun RUNTIME_MAP
public class JsxRuntimeMap {
    private static let MAP: HashMap<String, RuntimeDevelopmentPair> = buildMap()

    private static func buildMap(): HashMap<String, RuntimeDevelopmentPair> {
        let m = HashMap<String, RuntimeDevelopmentPair>()
        m.put("classic", RuntimeDevelopmentPair(JsxRuntime.Classic, None))
        m.put("automatic", RuntimeDevelopmentPair(JsxRuntime.Automatic, Some(true)))
        m.put("react", RuntimeDevelopmentPair(JsxRuntime.Classic, None))
        m.put("react-jsx", RuntimeDevelopmentPair(JsxRuntime.Automatic, Some(true)))
        m.put("react-jsxdev", RuntimeDevelopmentPair(JsxRuntime.Automatic, Some(true)))
        return m
    }

    /// 从字符串查找运行时
    public static func lookup(name: String): ?RuntimeDevelopmentPair {
        MAP.get(name)
    }

    /// 获取所有支持的运行时名称
    public static func names(): Array<String> {
        MAP.keys().toArray()
    }
}

// ============================================================================
// MemberList - 成员列表 (静态或动态)
// 严格翻译自: jsx.rs - MemberList
//   pub enum MemberList {
//       Static(&'static [&'static [u8]]),
//       Owned(Box<[Box<[u8]>]>),
//   }
//   用于 Pragma 的 factory/fragment 字段，常见情况下零堆分配。
// ============================================================================

/// 成员列表 - 对应 Bun MemberList
/// 用于存储 JSX factory/fragment 的成员路径
/// 如 "React.createElement" => ["React", "createElement"]
public class MemberList {
    /// 成员列表项
    public var items: Array<String>

    public init() {
        items = Array<String>()
    }

    public init(items: Array<String>) {
        this.items = items
    }

    /// 从静态数组构造
    public static func fromStatic(values: Array<String>): MemberList {
        MemberList(items: values)
    }

    /// 从点分隔字符串解析
    public static func fromDotSeparated(value: String): MemberList {
        let parts = value.split(".")
        return MemberList(items: parts.toArray())
    }

    /// 获取长度
    public func len(): Int64 {
        items.size
    }

    /// 是否为空
    public func isEmpty(): Bool {
        items.size == 0
    }

    /// 获取指定索引的元素
    public func get(index: Int64): ?String {
        if (index < 0 || index >= items.size) {
            return None
        }
        return Some(items[index])
    }

    /// 获取第一个元素
    public func first(): ?String {
        if (items.size == 0) {
            return None
        }
        return Some(items[0])
    }

    /// 转换为点分隔字符串
    public func toDotSeparated(): String {
        String.join(".", items)
    }
}

// ============================================================================
// ImportSource - JSX 导入源配置
// 严格翻译自: jsx.rs - ImportSource (options.zig:1208)
//   pub struct ImportSource {
//       pub development: Cow<'static, [u8]>,  // "react/jsx-dev-runtime"
//       pub production: Cow<'static, [u8]>,   // "react/jsx-runtime"
//   };
// ============================================================================

/// JSX 导入源配置 - 对应 Bun ImportSource
/// 存储开发和生产环境的导入路径
public class ImportSource {
    /// 开发模式导入路径 (默认 "react/jsx-dev-runtime")
    public var development: String
    /// 生产模式导入路径 (默认 "react/jsx-runtime")
    public var production: String

    public init() {
        development = "react/jsx-dev-runtime"
        production = "react/jsx-runtime"
    }

    public init(development: String, production: String) {
        this.development = development
        this.production = production
    }
}

// ============================================================================
// JsxPragma - JSX Pragma 配置
// 严格翻译自: jsx.rs - Pragma (options.zig:1192)
//   pub struct Pragma {
//       pub factory: MemberList,         // ["React", "createElement"]
//       pub fragment: MemberList,        // ["React", "Fragment"]
//       pub runtime: Runtime,            // .automatic
//       pub import_source: ImportSource,
//       pub classic_import_source: string, // "react"
//       pub package_name: []const u8,    // "react"
//       pub development: bool,           // true
//       pub parse: bool,                 // true
//       pub side_effects: bool,          // false
//   };
// ============================================================================

/// JSX Pragma 配置 - 对应 Bun JSX.Pragma
/// 完整的 JSX 转换配置，每个文件可独立设置
public class JsxPragma {
    /// 工厂函数 (默认 ["React", "createElement"])
    public var factory: MemberList
    /// Fragment 组件 (默认 ["React", "Fragment"])
    public var fragment: MemberList
    /// JSX 运行时模式 (默认 Automatic)
    public var runtime: JsxRuntime
    /// 导入源配置
    public var importSource: ImportSource

    /// Classic 模式下的导入源包名
    /// 逐文件通过 /** @jsxImportSource @emotion/core */ 设置
    public var classicImportSource: String
    /// 包名 (默认 "react")
    public var packageName: String

    /// 是否为开发模式
    /// 配置优先级:
    ///   1. --define=process.env.NODE_ENV=...
    ///   2. NODE_ENV=...
    ///   3. tsconfig.json compilerOptions.jsx (react-jsx 或 react-jsxdev)
    public var development: Bool
    /// 是否解析 JSX
    public var parse: Bool
    /// 是否有副作用
    public var sideEffects: Bool

    public init() {
        factory = MemberList.fromStatic(["React", "createElement"])
        fragment = MemberList.fromStatic(["React", "Fragment"])
        runtime = JsxRuntime.Automatic
        importSource = ImportSource()
        classicImportSource = "react"
        packageName = "react"
        development = true
        parse = true
        sideEffects = false
    }

    /// 获取当前导入源 (根据开发/生产模式)
    public func importSourcePath(): String {
        if (development) {
            importSource.development
        } else {
            importSource.production
        }
    }

    /// 解析包名 — 从完整模块路径中提取包名
    /// "@emotion/react/jsx-runtime" => "@emotion/react"
    /// "react/jsx-runtime" => "react"
    public static func parsePackageName(path: String): String {
        if (path.size == 0) {
            return path
        }
        // @scope/package 形式
        if (path[0] == '@') {
            let rest = path.substring(1)
            let firstSlash = rest.indexOfChar('/')
            if (firstSlash >= 0) {
                let afterScope = rest.substring(firstSlash + 1)
                let lastSlash = afterScope.indexOfChar('/')
                if (lastSlash >= 0) {
                    return path.substring(0, 1 + firstSlash + 1 + lastSlash + 1)
                }
            }
        }
        // 普通包名
        let firstSlash = path.indexOfChar('/')
        if (firstSlash >= 0) {
            return path.substring(0, firstSlash)
        }
        return path
    }

    /// 判断是否为 React 类运行时
    public func isReactLike(): Bool {
        packageName == "react" ||
        packageName == "@emotion/jsx" ||
        packageName == "@emotion/react"
    }

    /// 根据包名设置导入源
    /// 当包名为默认 "react" 时直接使用预定义字符串，避免分配
    public func setImportSource(): Unit {
        importSource.development = concatOrInterned(
            packageName, "/jsx-dev-runtime",
            "react/jsx-dev-runtime"
        )
        importSource.production = concatOrInterned(
            packageName, "/jsx-runtime",
            "react/jsx-runtime"
        )
    }

    /// 连接或使用预定义字符串
    /// 当包名为默认 react 时复用预定义字符串
    private func concatOrInterned(pkg: String, suffix: String, interned: String): String {
        if (pkg == "react" && suffix == "/jsx-dev-runtime" && interned == "react/jsx-dev-runtime") {
            return interned
        }
        if (pkg == "react" && suffix == "/jsx-runtime" && interned == "react/jsx-runtime") {
            return interned
        }
        pkg + suffix
    }

    /// 设置生产/开发模式
    public func setProduction(isProduction: Bool): Unit {
        development = !isProduction
    }

    /// 将点分隔的成员列表转换为组件数组
    /// "React.createElement" => ["React", "createElement"]
    /// 如果与原始列表相同则不重新分配
    public static func memberListToComponentsIfDifferent(
        original: MemberList, newValue: String
    ): MemberList {
        let parts = newValue.split(".").toArray()
        var needsAlloc: Bool = false
        var currentI: Int64 = 0

        for (part in parts) {
            if (part.size == 0) {
                continue
            }
            let orig = original.get(currentI)
            match (orig) {
                case Some(v) =>
                    if (v == part) {
                        currentI++
                    } else {
                        needsAlloc = true
                    }
                case None =>
                    needsAlloc = true
            }
            if (needsAlloc) {
                break
            }
        }

        if (!needsAlloc) {
            return original
        }

        let result = Array<String>()
        for (part in parts) {
            if (part.size > 0) {
                result.append(part)
            }
        }
        return MemberList(items: result)
    }
}

// ============================================================================
// JsxDefaults - JSX 默认常量
// 严格翻译自: jsx.rs - defaults (options.zig - JSX.Pragma.Defaults)
//   pub const FACTORY: &[&[u8]] = &[b"React", b"createElement"];
//   pub const FRAGMENT: &[&[u8]] = &[b"React", b"Fragment"];
//   pub const IMPORT_SOURCE_DEV: &[u8] = b"react/jsx-dev-runtime";
//   pub const IMPORT_SOURCE: &[u8] = b"react/jsx-runtime";
//   pub const JSX_FUNCTION: &[u8] = b"jsx";
//   pub const JSX_STATIC_FUNCTION: &[u8] = b"jsxs";
//   pub const JSX_FUNCTION_DEV: &[u8] = b"jsxDEV";
// ============================================================================

/// JSX 默认常量 - 对应 Bun JSX.Defaults
public class JsxDefaults {
    /// 默认工厂函数路径
    public static let FACTORY: Array<String> = ["React", "createElement"]
    /// 默认 Fragment 路径
    public static let FRAGMENT: Array<String> = ["React", "Fragment"]
    /// 默认开发模式导入源
    public static let IMPORT_SOURCE_DEV: String = "react/jsx-dev-runtime"
    /// 默认生产模式导入源
    public static let IMPORT_SOURCE: String = "react/jsx-runtime"
    /// JSX 函数名 (Automatic runtime)
    public static let JSX_FUNCTION: String = "jsx"
    /// JSX 静态函数名 (Automatic runtime, 多子节点)
    public static let JSX_STATIC_FUNCTION: String = "jsxs"
    /// JSX 开发模式函数名
    public static let JSX_FUNCTION_DEV: String = "jsxDEV"
}
