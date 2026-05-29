// bao_css - CSS Modules (CSS 模块支持)
// 严格翻译自: bun/src/css/css_modules.zig
//   对应: Config struct - CSS Modules 配置
//   对应: Pattern struct - 类名替换模式
//   对应: Segment union - 模式段 (literal, name, local, hash)
//   对应: CssModule struct - CSS 模块处理器
//   对应: CssModuleExport - 导出映射
//   对应: CssModuleReference - 引用类型 (local, global, dependency)
package bao_css

import bao_core.*
import bao_collections.*
import bao_hash.*

// ============================================================================
// CSS Modules 配置
// 严格翻译自: css_modules.zig Config
// ============================================================================

/// CSS Modules 配置
/// 严格翻译自 Config struct
public class CssModulesConfig {
    /// 类名替换模式
    public var pattern: CssModulePattern
    /// 是否重命名 dashed 标识符 (--custom-property)
    public var dashedIdents: Bool
    /// 是否作用域动画名
    public var animation: Bool
    /// 是否作用域网格名
    public var grid: Bool
    /// 是否作用域自定义标识符
    public var customIdents: Bool

    public init() {
        this.pattern = CssModulePattern()
        this.dashedIdents = false
        this.animation = true
        this.grid = true
        this.customIdents = true
    }

    public static func default(): CssModulesConfig {
        CssModulesConfig()
    }
}

// ============================================================================
// CSS Modules 类名模式
// 严格翻译自: css_modules.zig Pattern
// ============================================================================

/// 模式段类型
/// 严格翻译自 Segment union
public enum PatternSegmentKind {
    | Literal   // 固定文本
    | Name      // 文件名
    | Local     // 原始类名
    | Hash      // 文件哈希
}

/// 模式段
public class PatternSegment {
    public var kind: PatternSegmentKind
    public var text: String

    public init(kind: PatternSegmentKind) {
        this.kind = kind
        this.text = ""
    }

    public init(kind: PatternSegmentKind, text: String) {
        this.kind = kind
        this.text = text
    }

    public static func literal(text: String): PatternSegment {
        PatternSegment(PatternSegmentKind.Literal, text)
    }

    public static func name(): PatternSegment {
        PatternSegment(PatternSegmentKind.Name)
    }

    public static func local(): PatternSegment {
        PatternSegment(PatternSegmentKind.Local)
    }

    public static func hash(): PatternSegment {
        PatternSegment(PatternSegmentKind.Hash)
    }
}

/// CSS Modules 类名替换模式
/// 严格翻译自 Pattern struct
/// 默认模式: [hash]_[local]
public class CssModulePattern {
    /// 段列表
    public var segments: ArrayList<PatternSegment>

    public init() {
        this.segments = ArrayList<PatternSegment>()
        // 默认: hash_literal("_")_local
        segments.append(PatternSegment.hash())
        segments.append(PatternSegment.literal("_"))
        segments.append(PatternSegment.local())
    }

    public init(segments: ArrayList<PatternSegment>) {
        this.segments = segments
    }

    /// 生成替换后的类名
    /// 严格翻译自 Pattern.writeToString
    public func writeToString(hashStr: String, path: String, local: String): String {
        let sb = StringBuilder()
        for (segment in segments) {
            match (segment.kind) {
                case PatternSegmentKind.Literal =>
                    sb.append(segment.text)
                case PatternSegmentKind.Name =>
                    let stem = extractStem(path)
                    sb.append(replaceDots(stem))
                case PatternSegmentKind.Local =>
                    sb.append(local)
                case PatternSegmentKind.Hash =>
                    sb.append(hashStr)
            }
        }
        return sb.toString()
    }

    /// 生成替换后的类名 (带前缀, 用于 --custom-property)
    /// 严格翻译自 Pattern.writeToStringWithPrefix
    public func writeToStringWithPrefix(prefix: String, hashStr: String, path: String, local: String): String {
        let sb = StringBuilder()
        sb.append(prefix)
        for (segment in segments) {
            match (segment.kind) {
                case PatternSegmentKind.Literal =>
                    sb.append(segment.text)
                case PatternSegmentKind.Name =>
                    let stem = extractStem(path)
                    sb.append(replaceDots(stem))
                case PatternSegmentKind.Local =>
                    sb.append(local)
                case PatternSegmentKind.Hash =>
                    sb.append(hashStr)
            }
        }
        return sb.toString()
    }

    /// 提取文件名 (去除目录和扩展名)
    /// 严格翻译自 Pattern.write 中 std.fs.path.stem
    private static func extractStem(path: String): String {
        // 找到最后一个 / 或 \
        var lastSlash: Int64 = -1
        for (i in 0..path.size) {
            if (path[i] == UInt8(47) || path[i] == UInt8(92)) {
                lastSlash = i
            }
        }
        let fileName = if (lastSlash >= 0) { path[(lastSlash + 1)..] } else { path }
        // 找到最后一个 .
        var lastDot: Int64 = -1
        for (i in 0..fileName.size) {
            if (fileName[i] == UInt8(46)) {
                lastDot = i
            }
        }
        if (lastDot > 0) {
            fileName[0..lastDot]
        } else {
            fileName
        }
    }

    /// 替换文件名中的 . 为 -
    /// 严格翻译自 Pattern.write 中 replace_dots 逻辑
    private static func replaceDots(s: String): String {
        let sb = StringBuilder()
        for (c in s) {
            if (c == UInt8(46)) {
                sb.append("-")
            } else {
                sb.append(c)
            }
        }
        sb.toString()
    }
}

// ============================================================================
// CSS Modules 导出和引用
// 严格翻译自: css_modules.zig CssModuleExport, CssModuleReference
// ============================================================================

/// 引用类型
/// 严格翻译自 CssModuleReference union
public enum CssModuleRefKind {
    | Local       // 本地引用
    | Global      // 全局引用
    | Dependency  // 依赖引用
}

/// CSS Modules 引用
/// 严格翻译自 CssModuleReference
public class CssModuleReference {
    public var kind: CssModuleRefKind
    public var name: String
    public var specifier: String

    public init(kind: CssModuleRefKind, name: String) {
        this.kind = kind
        this.name = name
        this.specifier = ""
    }

    public init(kind: CssModuleRefKind, name: String, specifier: String) {
        this.kind = kind
        this.name = name
        this.specifier = specifier
    }

    public static func local(name: String): CssModuleReference {
        CssModuleReference(CssModuleRefKind.Local, name)
    }

    public static func global(name: String): CssModuleReference {
        CssModuleReference(CssModuleRefKind.Global, name)
    }

    public static func dependency(name: String, specifier: String): CssModuleReference {
        CssModuleReference(CssModuleRefKind.Dependency, name, specifier)
    }

    public func equals(other: CssModuleReference): Bool {
        return name == other.name && specifier == other.specifier
    }
}

/// CSS Modules 导出
/// 严格翻译自 CssModuleExport
public class CssModuleExport {
    /// 编译后的类名
    public var name: String
    /// 组合引用列表
    public var composes: ArrayList<CssModuleReference>
    /// 是否被引用
    public var isReferenced: Bool

    public init(name: String) {
        this.name = name
        this.composes = ArrayList<CssModuleReference>()
        this.isReferenced = false
    }

    public init(name: String, composes: ArrayList<CssModuleReference>, isReferenced: Bool) {
        this.name = name
        this.composes = composes
        this.isReferenced = isReferenced
    }
}

// ============================================================================
// CSS Modules 处理器
// 严格翻译自: css_modules.zig CssModule
// ============================================================================

/// CSS Modules 处理器
/// 严格翻译自 CssModule struct
/// 管理类名映射和引用
public class CssModule {
    /// CSS Modules 配置
    public var config: CssModulesConfig
    /// 源文件路径列表
    public var sources: ArrayList<String>
    /// 文件哈希列表
    public var hashes: ArrayList<String>
    /// 按源文件索引的导出映射
    public var exportsBySourceIndex: ArrayList<HashMap<String, CssModuleExport>>
    /// 引用映射 (placeholder -> reference)
    public var references: HashMap<String, CssModuleReference>
    /// 项目根路径
    public var projectRoot: ?String

    public init(config: CssModulesConfig) {
        this.config = config
        this.sources = ArrayList<String>()
        this.hashes = ArrayList<String>()
        this.exportsBySourceIndex = ArrayList<HashMap<String, CssModuleExport>>()
        this.references = HashMap<String, CssModuleReference>()
        this.projectRoot = None
    }

    /// 初始化 CSS Modules 处理器
    /// 严格翻译自 CssModule.new
    public init(config: CssModulesConfig, sources: ArrayList<String>, projectRoot: ?String) {
        this.config = config
        this.sources = sources
        this.projectRoot = projectRoot
        this.hashes = ArrayList<String>()
        this.exportsBySourceIndex = ArrayList<HashMap<String, CssModuleExport>>()
        this.references = HashMap<String, CssModuleReference>()

        // 为每个源文件计算哈希
        for (path in sources) {
            let source = match (projectRoot) {
                case Some(root) =>
                    if (isAbsolute(root)) {
                        relativePath(root, path)
                    } else {
                        path
                    }
                case None => path
            }
            hashes.append(computeHash(source))
        }

        // 初始化导出映射
        for (_ in sources) {
            exportsBySourceIndex.append(HashMap<String, CssModuleExport>())
        }
    }

    /// 获取或创建引用
    /// 严格翻译自 CssModule.getReference
    public func getReference(name: String, sourceIndex: Int64): CssModuleExport {
        let exports = exportsBySourceIndex[Int64(sourceIndex)]
        let existing = exports.get(name)
        match (existing) {
            case Some(export) =>
                export.isReferenced = true
                return export
            case None =>
                let hashStr = hashes[Int64(sourceIndex)]
                let path = sources[Int64(sourceIndex)]
                let compiledName = config.pattern.writeToString(hashStr, path, name)
                let export = CssModuleExport(compiledName)
                export.isReferenced = true
                exports.put(name, export)
                return export
        }
    }

    /// 添加本地导出
    /// 严格翻译自 CssModule.addLocal
    public func addLocal(exported: String, local: String, sourceIndex: Int64): Unit {
        let exports = exportsBySourceIndex[Int64(sourceIndex)]
        if (!exports.contains(exported)) {
            let hashStr = hashes[Int64(sourceIndex)]
            let path = sources[Int64(sourceIndex)]
            let compiledName = config.pattern.writeToString(hashStr, path, local)
            let export = CssModuleExport(compiledName)
            exports.put(exported, export)
        }
    }

    /// 添加 dashed 标识符导出
    /// 严格翻译自 CssModule.addDashed
    public func addDashed(local: String, sourceIndex: Int64): Unit {
        let exports = exportsBySourceIndex[Int64(sourceIndex)]
        if (!exports.contains(local)) {
            let hashStr = hashes[Int64(sourceIndex)]
            let path = sources[Int64(sourceIndex)]
            let compiledName = config.pattern.writeToStringWithPrefix(
                "--", hashStr, path, local
            )
            let export = CssModuleExport(compiledName)
            exports.put(local, export)
        }
    }

    /// 获取指定文件的所有导出
    public func getExports(sourceIndex: Int64): HashMap<String, CssModuleExport> {
        exportsBySourceIndex[Int64(sourceIndex)]
    }

    /// 转为 JSON 兼容的导出映射 (用于 JS 互操作)
    public func toJsonExports(sourceIndex: Int64): HashMap<String, Array<String>> {
        let exports = getExports(sourceIndex)
        let result = HashMap<String, Array<String>>()
        exports.forEach({ name, export =>
            // 收集 composes
            let composedNames = ArrayList<String>()
            composedNames.append(export.name)
            for (ref_ in export.composes) {
                match (ref_.kind) {
                    case CssModuleRefKind.Local | CssModuleRefKind.Global =>
                        composedNames.append(ref_.name)
                    case CssModuleRefKind.Dependency =>
                        composedNames.append(ref_.name)
                }
            }
            result.put(name, Array<String>())
        })
        return result
    }

    // ========================================================================
    // 内部辅助
    // ========================================================================

    /// 计算文件哈希
    /// 严格翻译自 css_modules.hash (Wyhash11 + base64url)
    private static func computeHash(source: String): String {
        let h = Wyhash11.hash(source)
        // 将 u32 哈希转为 base64url 编码 (6 字符)
        // 翻译自: std.mem.writeInt(u32, &h_bytes, h, .little) + base64 url-safe encode
        let b0 = UInt8(h & 0xFF)
        let b1 = UInt8((h >> 8) & 0xFF)
        let b2 = UInt8((h >> 16) & 0xFF)
        let b3 = UInt8((h >> 24) & 0xFF)
        // base64url 编码表
        let table = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"
        let sb = StringBuilder()
        // 3 字节 -> 4 字符 base64
        sb.append(table[Int64((b0 >> 2)) & 0x3F])
        sb.append(table[Int64(((b0 & 0x3) << 4) | (b1 >> 4)) & 0x3F])
        sb.append(table[Int64(((b1 & 0xF) << 2) | (b2 >> 6)) & 0x3F])
        sb.append(table[Int64(b2 & 0x3F)])
        sb.append(table[Int64((b3 >> 2)) & 0x3F])
        sb.append(table[Int64(((b3 & 0x3) << 4)) & 0x3F])
        var result = sb.toString()
        // 如果以数字开头, 添加 _ 前缀 (CSS 标识符不能以数字开头)
        if (!result.isEmpty() && result[0] >= UInt8(48) && result[0] <= UInt8(57)) {
            result = "_${result}"
        }
        result
    }

    /// 判断路径是否为绝对路径
    /// 严格翻译自 bun.path.Platform.auto.isAbsolute
    private static func isAbsolute(path: String): Bool {
        if (path.isEmpty()) { return false }
        // Unix: 以 / 开头
        if (path[0] == UInt8(47)) { return true }
        // Windows: 以盘符开头 (C:\)
        if (path.size >= 3 && path[1] == UInt8(58) && path[2] == UInt8(92)) { return true }
        false
    }

    /// 计算相对路径
    /// 严格翻译自 bun.path.relative
    private static func relativePath(from: String, to: String): String {
        if (from == to) { return "" }
        // 简化: 去除公共前缀
        var commonLen: Int64 = 0
        let minLen = if (from.size < to.size) { from.size } else { to.size }
        var lastSep: Int64 = -1
        for (i in 0..minLen) {
            if (from[i] == to[i]) {
                if (from[i] == UInt8(47) || from[i] == UInt8(92)) {
                    lastSep = i
                }
            } else {
                break
            }
            commonLen = i + 1
        }
        if (lastSep >= 0) {
            // 计算需要回退的 ../ 数量
            let remaining = from[(lastSep + 1)..]
            var upCount: Int64 = 0
            for (i in 0..remaining.size) {
                if (remaining[i] == UInt8(47) || remaining[i] == UInt8(92)) {
                    upCount++
                }
            }
            let sb = StringBuilder()
            var j: Int64 = 0
            while (j <= upCount) {
                if (j > 0) { sb.append("/") }
                sb.append("..")
                j++
            }
            let rest = to[(lastSep + 1)..]
            if (!rest.isEmpty()) {
                sb.append("/")
                sb.append(rest)
            }
            sb.toString()
        } else {
            to
        }
    }
}
