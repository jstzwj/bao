// Node.js 回退模块
// 严格翻译自: src/resolver/node_fallbacks.zig
//
// Bun 的 node_fallbacks 提供内置的 Node.js 核心模块 polyfill:
//   1. 当目标环境缺少 Node.js 核心模块时提供替代实现
//   2. 每个回退模块对应一个 JS 文件 (node-fallbacks/*.js)
//   3. 使用虚拟路径前缀 /bun-vfs$$/node_modules/ 避免与真实文件冲突
//   4. 包含简化的 PackageJSON (name, version="0.0.0-polyfill", moduleType=ESM)
//
// Bun 源码结构:
//   pub const import_path = "/bun-vfs$$/node_modules/"
//   pub const FallbackModule = struct {
//       path: Fs.Path,
//       package_json: *const PackageJSON,
//       code: *const fn () string,
//   }
//   pub const Map = bun.ComptimeStringMap(FallbackModule, .{
//       .{ "assert", FallbackModule.init("assert") },
//       .{ "buffer", FallbackModule.init("buffer") },
//       ... // 23 个核心模块
//   })
package bao_resolver

import bao_core.*
import bao_collections.*

// ============================================================================
// FallbackModule - 回退模块
// 严格翻译自: src/resolver/node_fallbacks.zig FallbackModule
// 对应 Bun: 当目标环境缺少 Node.js 核心模块时提供替代实现
// ============================================================================

/// 回退模块信息 - 对应 Bun FallbackModule
/// Bun:
///   pub const FallbackModule = struct {
///       path: Fs.Path,
///       package_json: *const PackageJSON,
///       code: *const fn () string,
///   }
public class FallbackModule {
    /// 虚拟路径 - 对应 Bun FallbackModule.path
    /// 格式: /bun-vfs$$/node_modules/{name}/index.js
    public var path: String
    /// 关联的 package.json - 对应 Bun FallbackModule.package_json
    public var packageName: String
    /// 模块版本 (固定为 "0.0.0-polyfill")
    public var version: String
    /// 模块代码加载器
    /// 对应 Bun FallbackModule.code - 返回源代码的函数指针
    public var codeLoader: () -> String

    public init(name: String, codeLoader: () -> String) {
        this.path = IMPORT_PATH + name + "/index.js"
        this.packageName = name
        this.version = POLYFILL_VERSION
        this.codeLoader = codeLoader
    }
}

// ============================================================================
// NodeFallbackModules - Node.js 回退模块查找表
// 严格翻译自: src/resolver/node_fallbacks.zig Map
// 对应 Bun: ComptimeStringMap(FallbackModule, ...)
// 使用 HashMap 替代 Bun 的编译时完美哈希表
//
// Bun 使用 ComptimeStringMap 进行 O(1) 查找:
//   pub const Map = bun.ComptimeStringMap(FallbackModule, .{
//       .{ "assert", FallbackModule.init("assert") },
//       .{ "buffer", FallbackModule.init("buffer") },
//       ... // 23 个模块
//   })
// ============================================================================

/// Node.js 回退模块查找表 - 对应 Bun node_fallbacks.zig Map
public class NodeFallbackModules {
    /// 虚拟路径前缀 - 对应 Bun import_path
    /// Bun: pub const import_path = "/bun-vfs$$/node_modules/"
    public static let IMPORT_PATH: String = "/bun-vfs$$/node_modules/"

    /// Polyfill 版本 - 对应 Bun "0.0.0-polyfill"
    public static let POLYFILL_VERSION: String = "0.0.0-polyfill"

    /// 回退模块映射表 - 对应 Bun ComptimeStringMap
    /// 键为模块裸名 (如 "assert")，值为 FallbackModule
    private static var moduleMap: HashMap<String, FallbackModule> = initModuleMap()

    /// 初始化模块映射表
    /// 对应 Bun ComptimeStringMap 初始化中的所有条目
    private static func initModuleMap(): HashMap<String, FallbackModule> {
        let m = HashMap<String, FallbackModule>()

        // 所有 23 个 Node.js 核心模块回退
        // 严格对应 Bun node_fallbacks.zig Map 中的条目
        m.put("assert", FallbackModule("assert", { "" }))
        m.put("buffer", FallbackModule("buffer", { "" }))
        m.put("console", FallbackModule("console", { "" }))
        m.put("constants", FallbackModule("constants", { "" }))
        m.put("crypto", FallbackModule("crypto", { "" }))
        m.put("domain", FallbackModule("domain", { "" }))
        m.put("events", FallbackModule("events", { "" }))
        m.put("http", FallbackModule("http", { "" }))
        m.put("https", FallbackModule("https", { "" }))
        m.put("net", FallbackModule("net", { "" }))
        m.put("os", FallbackModule("os", { "" }))
        m.put("path", FallbackModule("path", { "" }))
        m.put("process", FallbackModule("process", { "" }))
        m.put("punycode", FallbackModule("punycode", { "" }))
        m.put("querystring", FallbackModule("querystring", { "" }))
        m.put("stream", FallbackModule("stream", { "" }))
        m.put("string_decoder", FallbackModule("string_decoder", { "" }))
        m.put("sys", FallbackModule("sys", { "" }))
        m.put("timers", FallbackModule("timers", { "" }))
        m.put("tty", FallbackModule("tty", { "" }))
        m.put("url", FallbackModule("url", { "" }))
        m.put("util", FallbackModule("util", { "" }))
        m.put("zlib", FallbackModule("zlib", { "" }))

        return m
    }

    /// 根据路径获取回退模块的源代码
    /// 对应 Bun node_fallbacks.zig contentsFromPath()
    /// Bun:
    ///   pub fn contentsFromPath(path: string) ?string {
    ///       var module_name = path[import_path.len..];
    ///       module_name = module_name[0 .. std.mem.indexOfScalar(u8, module_name, '/') orelse module_name.len];
    ///       if (Map.get(module_name)) |mod| {
    ///           return mod.code();
    ///       }
    ///       return null;
    ///   }
    ///
    /// 参数:
    ///   path: 虚拟路径 (如 "/bun-vfs$$/node_modules/assert/index.js")
    /// 返回: 模块源代码，如果路径不匹配则返回 None
    public static func contentsFromPath(path: String): ?String {
        // 检查前缀
        if (!path.startsWith(IMPORT_PATH)) {
            return None
        }

        // 提取模块名: 路径中前缀之后到第一个 '/' 之前的部分
        // /bun-vfs$$/node_modules/assert/index.js
        //                       ^^^^^^
        let afterPrefix = path.substring(Int64(IMPORT_PATH.length), Int64(path.length))
        let slashIndex = afterPrefix.indexOf('/')
        let moduleName = if (slashIndex >= 0) {
            afterPrefix.substring(Int64(0), Int64(slashIndex))
        } else {
            afterPrefix
        }

        // 查找模块
        match (moduleMap.get(moduleName)) {
            case Some(mod) => return Some(mod.codeLoader())
            case None => return None
        }
    }

    /// 根据模块名获取回退模块
    /// 对应 Bun Map.get(name)
    ///
    /// 参数:
    ///   name: 模块裸名 (如 "assert", "buffer")
    /// 返回: 回退模块信息，如果不存在返回 None
    public static func get(name: String): ?FallbackModule {
        return moduleMap.get(name)
    }

    /// 判断给定模块名是否有回退实现
    /// 对应 Bun Map 中是否存在该键
    public static func has(name: String): Bool {
        return moduleMap.get(name) != None
    }
}
