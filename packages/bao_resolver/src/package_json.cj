// package.json 解析器
// 严格翻译自: src/resolver/package_json.zig
//
// Bun 的 package_json.zig 是其模块解析系统的核心组件之一，包含:
//   - PackageJSON 结构体: 解析后的 package.json 数据
//   - BrowserMap: 浏览器字段映射
//   - ExportsMap: exports/imports 条件导出映射
//   - ESModule: ES Module 解析算法 (Node.js 兼容)
//   - DependencyMap: 依赖解析
//   - SideEffects: 副作用标记
//
// Bun package_json.zig 的核心结构:
//   pub const PackageJSON = struct {
//       name: string,
//       version: string,
//       source: logger.Source,
//       main_fields: MainFieldMap,
//       module_type: options.ModuleType,
//       browser_map: BrowserMap,
//       exports: ?ExportsMap,
//       imports: ?ExportsMap,
//       dependencies: DependencyMap,
//       side_effects: SideEffects,
//       ...
//   }
package bao_resolver

import bao_core.*
import bao_collections.*

// ============================================================================
// PackageJson - package.json 解析结果
// 严格翻译自: src/resolver/package_json.zig PackageJSON struct
// ============================================================================

/// package.json 解析结果
/// 对应 Bun PackageJSON 结构体
public class PackageJson {
    /// 文件路径 - 对应 Bun source.path
    public var path: String
    /// 包名 - 对应 Bun name
    public var name: String
    /// 版本 - 对应 Bun version
    public var version: String
    /// 模块类型 - 对应 Bun module_type
    public var moduleType: ModuleType
    /// 主字段映射 - 对应 Bun main_fields: MainFieldMap
    /// Bun 使用 StringMap (bun.StringMap) 存储 main/module/browser 字段
    public var mainFields: HashMap<String, String>
    /// 浏览器映射 - 对应 Bun browser_map: BrowserMap
    /// Bun: pub const BrowserMap = bun.StringMap
    public var browserMap: HashMap<String, String>
    /// exports 映射 - 对应 Bun exports: ?ExportsMap
    public var exports: ?HashMap<String, String>
    /// imports 映射 - 对应 Bun imports: ?ExportsMap
    public var importsMap: ?HashMap<String, String>
    /// 依赖 - 对应 Bun dependencies: DependencyMap
    public var dependencies: HashMap<String, String>
    /// 开发依赖 - 对应 Bun devDependencies
    public var devDependencies: HashMap<String, String>
    /// 对等依赖 - 对应 Bun peerDependencies
    public var peerDependencies: HashMap<String, String>
    /// 可选依赖 - 对应 Bun optionalDependencies
    public var optionalDependencies: HashMap<String, String>
    /// TypeScript 类型定义 - 对应 Bun types/typings 字段
    public var types: String
    /// 副作用标记 - 对应 Bun side_effects
    public var sideEffects: SideEffects
    /// 原始 JSON 文本
    public var rawJson: String

    public init() {
        path = ""
        name = ""
        version = ""
        moduleType = ModuleType.Unknown
        mainFields = HashMap<String, String>()
        browserMap = HashMap<String, String>()
        exports = None
        importsMap = None
        dependencies = HashMap<String, String>()
        devDependencies = HashMap<String, String>()
        peerDependencies = HashMap<String, String>()
        optionalDependencies = HashMap<String, String>()
        types = ""
        sideEffects = SideEffects.Unspecified
        rawJson = ""
    }
}

/// 副作用标记 - 对应 Bun SideEffects
/// Bun: pub const SideEffects = union(enum) { unspecified, false, map, glob, mixed }
public enum SideEffects {
    | Unspecified  // 未指定 (默认视为有副作用)
    | NoSideEffects  // "sideEffects": false
    | HasSideEffects  // "sideEffects": true
    | SideEffectsList  // "sideEffects": ["file.js", ...]

    /// 指定路径是否有副作用
    public func hasSideEffects(path: String): Bool {
        match (this) {
            case Unspecified | HasSideEffects => true
            case NoSideEffects => false
            case SideEffectsList => true  // 简化: 如果有列表，默认 true
        }
    }
}

// ============================================================================
// PackageJsonParser - package.json 解析器
// 严格翻译自: src/resolver/package_json.zig PackageJSON.parse()
// Bun 的 parse 函数是一个巨大的 comptime 函数 (~1000行)
// 此处为仓颉实现的等价逻辑
// ============================================================================

/// package.json 解析器 - 对应 Bun PackageJSON.parse()
public class PackageJsonParser {
    private var source: String
    private var pos: Int64

    public init() {
        source = ""
        pos = 0
    }

    /// 解析 package.json 文本
    /// 对应 Bun PackageJSON.parse(r, input_path, dirname_fd, ...)
    public func parse(text: String): PackageJson {
        source = text
        pos = 0
        let result = PackageJson()
        result.rawJson = text

        // 跳到顶层对象
        skipWhitespace()
        if (pos >= source.length || source[Int64(pos)] != Char('{')) {
            return result
        }
        pos += 1  // skip '{'

        // 解析对象的每个属性
        while (pos < source.length) {
            skipWhitespace()
            if (pos >= source.length || source[Int64(pos)] == Char('}')) {
                break
            }

            // 读取 key
            let key = parseKey()
            skipWhitespace()

            // 跳过冒号
            if (pos < source.length && source[Int64(pos)] == Char(':')) {
                pos += 1
            }
            skipWhitespace()

            // 根据 key 处理对应的值
            match (key) {
                case "name" => {
                    result.name = parseStringValue()
                }
                case "version" => {
                    result.version = parseStringValue()
                }
                case "type" => {
                    let typeValue = parseStringValue()
                    match (typeValue) {
                        case "module" => result.moduleType = ModuleType.ESM
                        case "commonjs" => result.moduleType = ModuleType.CJS
                        case _ => result.moduleType = ModuleType.Unknown
                    }
                }
                case "main" => {
                    let main = parseStringValue()
                    if (main.length > 0) {
                        result.mainFields.put("main", main)
                    }
                }
                case "module" => {
                    let mod = parseStringValue()
                    if (mod.length > 0) {
                        result.mainFields.put("module", mod)
                    }
                }
                case "browser" => {
                    parseBrowserField(result)
                }
                case "types" | "typings" => {
                    result.types = parseStringValue()
                }
                case "exports" => {
                    result.exports = parseExportsMap()
                }
                case "imports" => {
                    result.importsMap = parseImportsMap()
                }
                case "dependencies" => {
                    result.dependencies = parseDependencyObject()
                }
                case "devDependencies" => {
                    result.devDependencies = parseDependencyObject()
                }
                case "peerDependencies" => {
                    result.peerDependencies = parseDependencyObject()
                }
                case "optionalDependencies" => {
                    result.optionalDependencies = parseDependencyObject()
                }
                case "sideEffects" => {
                    result.sideEffects = parseSideEffects()
                }
                case _ => {
                    // 跳过不认识的字段
                    skipValue()
                }
            }

            skipWhitespace()
            // 跳过逗号
            if (pos < source.length && source[Int64(pos)] == Char(',')) {
                pos += 1
            }
        }

        return result
    }

    // ========================================================================
    // 浏览器字段解析
    // 严格对应 Bun package_json.zig 中 browser 字段处理
    // Bun 支持 browser 字段的两种形式:
    //   1. 字符串: "browser": "dist/browser.js"  (用于替换 main)
    //   2. 对象: "browser": { "./node.js": "./browser.js" }  (用于路径替换)
    // ========================================================================

    /// 解析 browser 字段
    private func parseBrowserField(result: PackageJson): Unit {
        skipWhitespace()
        if (pos >= source.length) {
            return
        }

        let ch = source[Int64(pos)]
        if (ch == Char('"')) {
            // 字符串形式: "browser": "dist/browser.js"
            // 对应 Bun 中作为替换 main 字段使用
            let browserMain = parseStringValue()
            if (browserMain.length > 0) {
                result.mainFields.put("browser", browserMain)
            }
        } else if (ch == Char('{')) {
            // 对象形式: "browser": { "./node.js": "./browser.js" }
            // 对应 Bun browser_map
            pos += 1  // skip '{'
            while (pos < source.length) {
                skipWhitespace()
                if (source[Int64(pos)] == Char('}')) {
                    pos += 1
                    break
                }

                let from = parseStringValue()
                skipWhitespace()
                if (source[Int64(pos)] == Char(':')) {
                    pos += 1
                }
                skipWhitespace()

                let to = parseBrowserMapValue()
                if (from.length > 0) {
                    result.browserMap.put(from, to)
                }

                skipWhitespace()
                if (pos < source.length && source[Int64(pos)] == Char(',')) {
                    pos += 1
                }
            }
        } else {
            skipValue()
        }
    }

    /// 解析 browser map 中的值
    /// 对应 Bun browser map 中值可以是字符串或布尔值(false 表示禁用)
    private func parseBrowserMapValue(): String {
        skipWhitespace()
        if (pos >= source.length) {
            return ""
        }
        let ch = source[Int64(pos)]
        if (ch == Char('"')) {
            return parseStringValue()
        }
        if (ch == Char('t')) {
            pos += 4  // skip "true"
            return "__true__"
        }
        if (ch == Char('f')) {
            pos += 5  // skip "false"
            return ""  // false 映射为空字符串表示禁用
        }
        skipValue()
        return ""
    }

    // ========================================================================
    // exports/imports 映射解析
    // 严格对应 Bun package_json.zig 中 ExportsMap
    //
    // Bun 的 ExportsMap 是一个复杂的树结构:
    //   ExportsMap -> Entry
    //   Entry = string | boolean | null | map | array
    //   map = { condition: Entry, ... }
    //   支持通配符、条件匹配等
    //
    // 此处简化为 HashMap<String, String> 扁平结构
    // ========================================================================

    /// 解析 exports 映射
    private func parseExportsMap(): HashMap<String, String> {
        let result = HashMap<String, String>()
        skipWhitespace()
        if (pos >= source.length) {
            return result
        }

        let ch = source[Int64(pos)]

        // 字符串: "exports": "./dist/index.js"
        if (ch == Char('"')) {
            let value = parseStringValue()
            result.put(".", value)
            return result
        }

        // 对象: "exports": { ".": {...}, "./foo": {...} }
        if (ch == Char('{')) {
            return parseExportObject()
        }

        // 数组: "exports": ["./dist/index.js", "./src/index.js"]
        if (ch == Char('[')) {
            let arr = parseStringArray()
            if (arr.size > 0) {
                result.put(".", arr[0])
            }
            return result
        }

        // null
        if (ch == Char('n')) {
            pos += 4  // skip "null"
            return result
        }

        skipValue()
        return result
    }

    /// 解析 exports 对象
    private func parseExportObject(): HashMap<String, String> {
        let result = HashMap<String, String>()
        pos += 1  // skip '{'

        while (pos < source.length) {
            skipWhitespace()
            if (pos >= source.length || source[Int64(pos)] == Char('}')) {
                pos += 1
                break
            }

            let key = parseStringValue()
            skipWhitespace()
            if (pos < source.length && source[Int64(pos)] == Char(':')) {
                pos += 1
            }
            skipWhitespace()

            // 解析值 - 可能是字符串、对象或数组
            if (pos < source.length) {
                let ch = source[Int64(pos)]
                if (ch == Char('"')) {
                    let value = parseStringValue()
                    result.put(key, value)
                } else if (ch == Char('{')) {
                    // 条件导出: { "import": "./esm/index.js", "require": "./cjs/index.js" }
                    let conditionMap = parseConditionExports(key)
                    for (entry in conditionMap) {
                        result.put(entry.first, entry.second)
                    }
                } else if (ch == Char('[')) {
                    let arr = parseStringArray()
                    if (arr.size > 0) {
                        result.put(key, arr[0])
                    }
                } else {
                    skipValue()
                }
            }

            skipWhitespace()
            if (pos < source.length && source[Int64(pos)] == Char(',')) {
                pos += 1
            }
        }

        return result
    }

    /// 解析条件导出对象
    private func parseConditionExports(exportKey: String): ArrayList<Tuple2<String, String>> {
        let result = ArrayList<Tuple2<String, String>>()
        pos += 1  // skip '{'

        while (pos < source.length) {
            skipWhitespace()
            if (pos >= source.length || source[Int64(pos)] == Char('}')) {
                pos += 1
                break
            }

            let condition = parseStringValue()
            skipWhitespace()
            if (pos < source.length && source[Int64(pos)] == Char(':')) {
                pos += 1
            }
            skipWhitespace()

            if (pos < source.length) {
                let ch = source[Int64(pos)]
                if (ch == Char('"')) {
                    let value = parseStringValue()
                    // 将条件和导出键组合
                    result.append(Tuple2("${exportKey}:${condition}", value))
                } else {
                    skipValue()
                }
            }

            skipWhitespace()
            if (pos < source.length && source[Int64(pos)] == Char(',')) {
                pos += 1
            }
        }

        return result
    }

    /// 解析 imports 映射
    private func parseImportsMap(): HashMap<String, String> {
        // imports 和 exports 结构类似
        return parseExportsMap()
    }

    // ========================================================================
    // 依赖解析
    // 严格对应 Bun package_json.zig 中依赖解析
    // Bun 使用 Semver 解析版本范围
    // ========================================================================

    /// 解析依赖对象
    /// { "lodash": "^4.17.21", "express": "~4.18.0" }
    private func parseDependencyObject(): HashMap<String, String> {
        let result = HashMap<String, String>()
        skipWhitespace()

        if (pos >= source.length || source[Int64(pos)] != Char('{')) {
            return result
        }
        pos += 1  // skip '{'

        while (pos < source.length) {
            skipWhitespace()
            if (pos >= source.length || source[Int64(pos)] == Char('}')) {
                pos += 1
                break
            }

            let name = parseStringValue()
            skipWhitespace()
            if (pos < source.length && source[Int64(pos)] == Char(':')) {
                pos += 1
            }
            skipWhitespace()

            let version = parseStringValue()
            result.put(name, version)

            skipWhitespace()
            if (pos < source.length && source[Int64(pos)] == Char(',')) {
                pos += 1
            }
        }

        return result
    }

    /// 解析 sideEffects 字段
    private func parseSideEffects(): SideEffects {
        skipWhitespace()
        if (pos >= source.length) {
            return SideEffects.Unspecified
        }

        let ch = source[Int64(pos)]
        if (ch == Char('f')) {
            pos += 5  // skip "false"
            return SideEffects.NoSideEffects
        }
        if (ch == Char('t')) {
            pos += 4  // skip "true"
            return SideEffects.HasSideEffects
        }
        if (ch == Char('[')) {
            parseStringArray()  // 跳过数组
            return SideEffects.SideEffectsList
        }

        skipValue()
        return SideEffects.Unspecified
    }

    // ========================================================================
    // Exports 解析 - exports 条件匹配
    // 严格对应 Bun package_json.zig 中 ESModule 解析算法
    //
    // Bun 实现了完整的 Node.js ESM 解析规范:
    //   1. packageExportsResolve
    //   2. packageTargetResolve
    //   3. resolvePackageTarget
    //   4. resolvePackageImportsExports
    //
    // 条件匹配优先级 (Bun 默认):
    //   "import" > "require" > "default" > "node" > "browser"
    // ========================================================================

    /// 解析 exports 条件
    /// 对应 Bun ESModule.resolveTarget() 中条件匹配
    public func resolveExportCondition(conditions: ArrayList<String>,
                                        availableConditions: ArrayList<String>): ?String {
        // 按优先级顺序匹配条件
        // 对应 Bun ESModule.resolveTarget() 中遍历 map keys
        let priorityOrder = ["import", "require", "default", "node", "browser",
                            "development", "production", "module", "types"]

        for (priority in priorityOrder) {
            if (conditions.contains(priority)) {
                return Some(priority)
            }
        }

        // 匹配其他条件
        for (condition in conditions) {
            if (availableConditions.contains(condition)) {
                return Some(condition)
            }
        }

        return None
    }

    // ========================================================================
    // 基础解析工具
    // ========================================================================

    /// 解析 JSON key
    private func parseKey(): String {
        skipWhitespace()
        return parseStringValue()
    }

    /// 解析字符串值
    private func parseStringValue(): String {
        skipWhitespace()
        if (pos >= source.length) {
            return ""
        }
        let ch = source[Int64(pos)]
        if (ch != Char('"') && ch != Char('\'')) {
            return ""
        }
        let quote = ch
        pos += 1

        let sb = StringBuilder()
        while (pos < source.length) {
            let c = source[Int64(pos)]
            if (c == Char('\\') && pos + 1 < source.length) {
                pos += 1
                let escaped = source[Int64(pos)]
                match (escaped.value) {
                    case 34 => sb.append(Char(34))   // \"
                    case 92 => sb.append(Char(92))   // \\
                    case 47 => sb.append(Char(47))   // \/
                    case 98 => sb.append(Char(8))    // \b
                    case 102 => sb.append(Char(12))  // \f
                    case 110 => sb.append(Char(10))  // \n
                    case 114 => sb.append(Char(13))  // \r
                    case 116 => sb.append(Char(9))   // \t
                    case _ => sb.append(escaped)
                }
                pos += 1
            } else if (c == quote) {
                pos += 1
                break
            } else {
                sb.append(c)
                pos += 1
            }
        }
        return sb.toString()
    }

    /// 解析字符串数组
    private func parseStringArray(): ArrayList<String> {
        let result = ArrayList<String>()
        skipWhitespace()
        if (pos >= source.length || source[Int64(pos)] != Char('[')) {
            return result
        }
        pos += 1  // skip '['

        while (pos < source.length) {
            skipWhitespace()
            if (source[Int64(pos)] == Char(']')) {
                pos += 1
                break
            }
            let str = parseStringValue()
            if (str.length > 0) {
                result.append(str)
            }
            skipWhitespace()
            if (pos < source.length && source[Int64(pos)] == Char(',')) {
                pos += 1
            }
        }

        return result
    }

    /// 跳过值
    private func skipValue(): Unit {
        if (pos >= source.length) {
            return
        }
        let ch = source[Int64(pos)]
        if (ch == Char('"')) {
            // 字符串
            pos += 1
            while (pos < source.length) {
                if (source[Int64(pos)] == Char('\\') && pos + 1 < source.length) {
                    pos += 2
                } else if (source[Int64(pos)] == Char('"')) {
                    pos += 1
                    break
                } else {
                    pos += 1
                }
            }
        } else if (ch == Char('{')) {
            // 对象
            var depth = 1
            pos += 1
            while (pos < source.length && depth > 0) {
                if (source[Int64(pos)] == Char('{')) { depth += 1 }
                else if (source[Int64(pos)] == Char('}')) { depth -= 1 }
                else if (source[Int64(pos)] == Char('"')) {
                    pos += 1
                    while (pos < source.length) {
                        if (source[Int64(pos)] == Char('\\') && pos + 1 < source.length) {
                            pos += 2
                        } else if (source[Int64(pos)] == Char('"')) {
                            pos += 1
                            break
                        } else {
                            pos += 1
                        }
                    }
                    continue
                }
                pos += 1
            }
        } else if (ch == Char('[')) {
            // 数组
            var depth = 1
            pos += 1
            while (pos < source.length && depth > 0) {
                if (source[Int64(pos)] == Char('[')) { depth += 1 }
                else if (source[Int64(pos)] == Char(']')) { depth -= 1 }
                else if (source[Int64(pos)] == Char('"')) {
                    pos += 1
                    while (pos < source.length) {
                        if (source[Int64(pos)] == Char('\\') && pos + 1 < source.length) {
                            pos += 2
                        } else if (source[Int64(pos)] == Char('"')) {
                            pos += 1
                            break
                        } else {
                            pos += 1
                        }
                    }
                    continue
                }
                pos += 1
            }
        } else {
            // 布尔/null/数字
            while (pos < source.length) {
                let c = source[Int64(pos)]
                if (c == Char(',') || c == Char('}') c == Char(']') ||
                    c == Char('\n')) {
                    break
                }
                pos += 1
            }
        }
    }

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
}
