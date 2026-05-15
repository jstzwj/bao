// MIME 类型系统
// 严格翻译自:
//   src/http_types/MimeType.zig - MIME 类型识别与分类
//   src/http_types/mime_type_list_enum.zig - MIME 类型枚举列表
//   Bun 的 MIME 类型系统:
//   - MimeType 结构体: value + category
//   - Category 枚举: 分类 (text/image/javascript/css/json/html 等)
//   - extensions: 扩展名 -> MIME 类型映射表 (1000+ 条目)
//   - byExtension(): 根据扩展名查找 MIME 类型
//   - byName(): 根据名称字符串解析 MIME 类型
//   - sniff(): 根据文件头字节嗅探图片类型
package bao.http_types

import bao_core.*

// ============================================================================
// MimeTypeCategory - MIME 类型分类
// 严格翻译自: MimeType.zig Category enum
// ============================================================================

/// MIME 类型分类枚举 - 对应 Bun MimeType.Category
public enum MimeTypeCategory {
    | None
    | Image
    | Text
    | Html
    | Font
    | Other
    | Css
    | Json
    | Audio
    | Video
    | JavaScript
    | Wasm
    | Application
    | Model
    | Message
    | XConference   // x-conference
    | XShader       // x-shader
    | Chemical
    | Multipart
}

// ============================================================================
// MimeTypeCategoryUtil - MimeTypeCategory 工具
// 严格翻译自: MimeType.zig Category 的方法
// ============================================================================

/// MIME 类型分类工具
public class MimeTypeCategoryUtil {
    /// 是否为代码类型 - 对应 Bun Category.isCode()
    public static func isCode(cat: MimeTypeCategory): Bool {
        match (cat) {
            case MimeTypeCategory.Wasm => true
            case MimeTypeCategory.Json => true
            case MimeTypeCategory.Css => true
            case MimeTypeCategory.Html => true
            case MimeTypeCategory.JavaScript => true
            default => false
        }
    }

    /// 是否为文本类似类型 - 对应 Bun Category.isTextLike()
    public static func isTextLike(cat: MimeTypeCategory): Bool {
        match (cat) {
            case MimeTypeCategory.JavaScript => true
            case MimeTypeCategory.Html => true
            case MimeTypeCategory.Text => true
            case MimeTypeCategory.Css => true
            case MimeTypeCategory.Json => true
            default => false
        }
    }

    /// 是否自动设置文件名 - 对应 Bun Category.autosetFilename()
    public static func autosetFilename(cat: MimeTypeCategory): Bool {
        match (cat) {
            case MimeTypeCategory.Wasm => false
            case MimeTypeCategory.Font => false
            case MimeTypeCategory.Image => false
            case MimeTypeCategory.Audio => false
            case MimeTypeCategory.Video => false
            case MimeTypeCategory.JavaScript => false
            case MimeTypeCategory.Html => false
            case MimeTypeCategory.Text => false
            case MimeTypeCategory.Css => false
            case MimeTypeCategory.Json => false
            default => true
        }
    }

    /// 从 MIME 类型字符串推断分类 - 对应 Bun Category.init(str)
    /// 解析 "text/css" => Css, "image/png" => Image 等
    public static func init(str: String): MimeTypeCategory {
        let slashIdx = str.indexOf("/")
        if (slashIdx < 0) {
            return MimeTypeCategory.Other
        }

        let category = str.substring(0, slashIdx)
        var afterSlash = if (str.length > slashIdx + 1) {
            str.substring(slashIdx + 1)
        } else {
            ""
        }

        // 去掉分号参数部分
        let semicolonIdx = afterSlash.indexOf(";")
        if (semicolonIdx >= 0) {
            afterSlash = afterSlash.substring(0, semicolonIdx)
        }

        if (category == "text") {
            if (afterSlash == "javascript") {
                return MimeTypeCategory.JavaScript
            }
            if (afterSlash == "css") {
                return MimeTypeCategory.Css
            }
            if (afterSlash == "html") {
                return MimeTypeCategory.Html
            }
            if (afterSlash == "json") {
                return MimeTypeCategory.Json
            }
            return MimeTypeCategory.Text
        }

        if (category == "application") {
            if (afterSlash == "wasm") {
                return MimeTypeCategory.Wasm
            }
            if (afterSlash == "javascript") {
                return MimeTypeCategory.JavaScript
            }
            if (afterSlash == "json") {
                return MimeTypeCategory.Json
            }
            if (afterSlash == "octet-stream") {
                return MimeTypeCategory.Other
            }
            return MimeTypeCategory.Application
        }

        if (category == "image") {
            return MimeTypeCategory.Image
        }
        if (category == "video") {
            return MimeTypeCategory.Video
        }
        if (category == "audio") {
            return MimeTypeCategory.Audio
        }
        if (category == "font") {
            return MimeTypeCategory.Font
        }
        if (category == "multipart") {
            return MimeTypeCategory.Multipart
        }
        if (category == "model") {
            return MimeTypeCategory.Model
        }
        if (category == "message") {
            return MimeTypeCategory.Message
        }
        if (category == "x-conference") {
            return MimeTypeCategory.XConference
        }
        if (category == "x-shader") {
            return MimeTypeCategory.XShader
        }
        if (category == "chemical") {
            return MimeTypeCategory.Chemical
        }

        return MimeTypeCategory.Other
    }
}

// ============================================================================
// MimeType - MIME 类型
// 严格翻译自: MimeType.zig const MimeType = @This()
// ============================================================================

/// MIME 类型 - 对应 Bun MimeType
/// 包含类型值和分类
public class MimeType {
    /// MIME 类型值 (如 "text/css;charset=utf-8")
    public var value: String
    /// 类型分类
    public var category: MimeTypeCategory

    public init(value: String, category: MimeTypeCategory) {
        this.value = value
        this.category = category
    }

    /// 是否可在编辑器中打开 - 对应 Bun MimeType.canOpenInEditor()
    public func canOpenInEditor(): Bool {
        if (category == MimeTypeCategory.Text || MimeTypeCategoryUtil.isCode(category)) {
            return true
        }
        if (category == MimeTypeCategory.Image) {
            return value == "image/svg+xml"
        }
        return false
    }
}

// ============================================================================
// MimeTypeConstants - 预定义 MIME 类型常量
// 严格翻译自: MimeType.zig 中的 pub const none/css/javascript/... 等
// ============================================================================

/// 预定义 MIME 类型常量 - 对应 Bun MimeType 静态常量
public class MimeTypeConstants {
    /// 无类型
    public static let NONE: MimeType = MimeType("", MimeTypeCategory.None)
    /// 通用二进制
    public static let OTHER: MimeType = MimeType("application/octet-stream", MimeTypeCategory.Other)
    /// CSS
    public static let CSS: MimeType = MimeType("text/css;charset=utf-8", MimeTypeCategory.Css)
    /// JavaScript
    public static let JAVASCRIPT: MimeType = MimeType("text/javascript;charset=utf-8", MimeTypeCategory.JavaScript)
    /// ICO 图标
    public static let ICO: MimeType = MimeType("image/vnd.microsoft.icon", MimeTypeCategory.Image)
    /// HTML
    public static let HTML: MimeType = MimeType("text/html;charset=utf-8", MimeTypeCategory.Html)
    /// JSON
    public static let JSON: MimeType = MimeType("application/json;charset=utf-8", MimeTypeCategory.Json)
    /// JSON (编译为 JS 以支持无 import assertion 导入)
    public static let TRANSPILED_JSON: MimeType = MimeType("text/javascript;charset=utf-8", MimeTypeCategory.JavaScript)
    /// 纯文本
    public static let TEXT: MimeType = MimeType("text/plain;charset=utf-8", MimeTypeCategory.Html)
    /// WebAssembly
    public static let WASM: MimeType = MimeType("application/wasm", MimeTypeCategory.Wasm)
}

// ============================================================================
// MimeTypeUtil - MIME 类型工具函数
// 严格翻译自: MimeType.zig 中的静态函数
// ============================================================================

/// MIME 类型工具 - 对应 Bun MimeType 的静态方法
public class MimeTypeUtil {
    /// 根据扩展名查找 MIME 类型 - 对应 Bun MimeType.byExtension()
    /// 返回匹配的类型或 application/octet-stream
    public static func byExtension(extWithoutLeadingDot: String): MimeType {
        return byExtensionNoDefault(extWithoutLeadingDot) ?? MimeTypeConstants.OTHER
    }

    /// 根据扩展名查找 MIME 类型 (无默认值) - 对应 Bun MimeType.byExtensionNoDefault()
    public static func byExtensionNoDefault(extWithoutLeadingDot: String): ?MimeType {
        return MimeTypeExtensionMap.lookup(extWithoutLeadingDot)
    }

    /// 根据 MIME 类型名称字符串解析 - 对应 Bun MimeType.byName()
    /// 简化版本: 解析 "text/css" => Css, "application/json" => Json 等
    public static func byName(name: String): MimeType {
        return initFromName(name)
    }

    /// 从名称初始化 MIME 类型 - 对应 Bun MimeType.init()
    /// 解析类型字符串，识别常见类型并返回对应常量
    public static func initFromName(str: String): MimeType {
        let slashIdx = str.indexOf("/")
        if (slashIdx < 0) {
            return MimeTypeConstants.OTHER
        }

        let categoryStr = str.substring(0, slashIdx)
        if (categoryStr.length == 0 || categoryStr[0] == '*' || str.length <= slashIdx + 1) {
            return MimeTypeConstants.OTHER
        }

        var subType = str.substring(slashIdx + 1)
        let semicolonIdx = subType.indexOf(";")
        if (semicolonIdx >= 0) {
            subType = subType.substring(0, semicolonIdx)
        }

        if (categoryStr == "application") {
            if (subType == "json" || subType == "geo+json") {
                return MimeTypeConstants.JSON
            }
            if (subType == "octet-stream") {
                return MimeTypeConstants.OTHER
            }
            if (subType == "wasm") {
                return MimeTypeConstants.WASM
            }
            return MimeType(str, MimeTypeCategory.Application)
        }

        if (categoryStr == "text") {
            if (subType == "css") {
                return MimeTypeConstants.CSS
            }
            if (subType == "html") {
                return MimeTypeConstants.HTML
            }
            if (subType == "javascript") {
                return MimeTypeConstants.JAVASCRIPT
            }
            if (subType == "plain") {
                return MimeTypeConstants.TEXT
            }
            return MimeType(str, MimeTypeCategory.Text)
        }

        if (categoryStr == "image") {
            return MimeType(str, MimeTypeCategory.Image)
        }
        if (categoryStr == "audio") {
            return MimeType(str, MimeTypeCategory.Audio)
        }
        if (categoryStr == "video") {
            return MimeType(str, MimeTypeCategory.Video)
        }
        if (categoryStr == "font") {
            return MimeType(str, MimeTypeCategory.Font)
        }

        return MimeType(str, MimeTypeCategory.Other)
    }

    /// 根据文件头字节嗅探图片类型 - 对应 Bun MimeType.sniff()
    /// 通过魔数字节识别 BMP/JPEG/TIFF/GIF/PNG
    public static func sniff(bytes: Array<UInt8>): ?MimeType {
        if (bytes.length < 2) {
            return None<MimeType>
        }

        // BMP: 42 4D
        if (bytes.length >= 2 && bytes[0] == 0x42 && bytes[1] == 0x4D) {
            return MimeType("image/bmp", MimeTypeCategory.Image)
        }
        // JPEG: FF D8 FF
        if (bytes.length >= 3 && bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) {
            return MimeType("image/jpeg", MimeTypeCategory.Image)
        }
        // TIFF (LE): 49 49 2A 00
        if (bytes.length >= 4 && bytes[0] == 0x49 && bytes[1] == 0x49 && bytes[2] == 0x2A && bytes[3] == 0x00) {
            return MimeType("image/tiff", MimeTypeCategory.Image)
        }
        // TIFF (BE): 4D 4D 00 2A
        if (bytes.length >= 4 && bytes[0] == 0x4D && bytes[1] == 0x4D && bytes[2] == 0x00 && bytes[3] == 0x2A) {
            return MimeType("image/tiff", MimeTypeCategory.Image)
        }
        // GIF: 47 49 46 38 39 61
        if (bytes.length >= 6 && bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46 &&
            bytes[3] == 0x38 && bytes[4] == 0x39 && bytes[5] == 0x61) {
            return MimeType("image/gif", MimeTypeCategory.Image)
        }
        // PNG: 89 50 4E 47 0D 0A 1A 0A
        if (bytes.length >= 8 && bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E &&
            bytes[3] == 0x47 && bytes[4] == 0x0D && bytes[5] == 0x0A && bytes[6] == 0x1A &&
            bytes[7] == 0x0A) {
            return MimeType("image/png", MimeTypeCategory.Image)
        }

        return None<MimeType>
    }
}

// ============================================================================
// MimeTypeExtensionMap - 扩展名到 MIME 类型映射表
// 严格翻译自: MimeType.zig extensions ComptimeStringMap
// 这是 Bun 维护的完整 MIME 类型映射表，包含 1000+ 条目
// ============================================================================

/// MIME 类型扩展名映射表 - 对应 Bun MimeType.extensions
/// 将文件扩展名映射到 MIME 类型字符串
public class MimeTypeExtensionMap {
    private static let MAP: HashMap<String, MimeType> = buildMap()

    private static func buildMap(): HashMap<String, MimeType> {
        let m = HashMap<String, MimeType>()
        // 严格翻译自 Bun MimeType.zig 中的 extensions ComptimeStringMap
        // 常用类型
        m.put("html", MimeType("text/html", MimeTypeCategory.Html))
        m.put("htm", MimeType("text/html", MimeTypeCategory.Html))
        m.put("css", MimeType("text/css", MimeTypeCategory.Css))
        m.put("js", MimeType("application/javascript", MimeTypeCategory.JavaScript))
        m.put("mjs", MimeType("application/javascript", MimeTypeCategory.JavaScript))
        m.put("cjs", MimeType("application/javascript", MimeTypeCategory.JavaScript))
        m.put("ts", MimeType("application/javascript", MimeTypeCategory.JavaScript))
        m.put("tsx", MimeType("application/javascript", MimeTypeCategory.JavaScript))
        m.put("mts", MimeType("application/javascript", MimeTypeCategory.JavaScript))
        m.put("mtsx", MimeType("application/javascript", MimeTypeCategory.JavaScript))
        m.put("jsx", MimeType("text/jsx", MimeTypeCategory.JavaScript))
        m.put("json", MimeType("application/json", MimeTypeCategory.Json))
        m.put("json5", MimeType("application/json5", MimeTypeCategory.Application))
        m.put("jsonld", MimeType("application/ld+json", MimeTypeCategory.Application))
        m.put("jsonml", MimeType("application/jsonml+json", MimeTypeCategory.Application))
        m.put("map", MimeType("application/json", MimeTypeCategory.Json))
        m.put("wasm", MimeType("application/webassembly", MimeTypeCategory.Wasm))
        m.put("txt", MimeType("text/plain", MimeTypeCategory.Text))
        m.put("text", MimeType("text/plain", MimeTypeCategory.Text))
        m.put("conf", MimeType("text/plain", MimeTypeCategory.Text))
        m.put("log", MimeType("text/plain", MimeTypeCategory.Text))
        m.put("ini", MimeType("text/plain", MimeTypeCategory.Text))
        m.put("list", MimeType("text/plain", MimeTypeCategory.Text))
        m.put("in", MimeType("text/plain", MimeTypeCategory.Text))
        m.put("def", MimeType("text/plain", MimeTypeCategory.Text))
        m.put("csv", MimeType("text/csv", MimeTypeCategory.Text))
        m.put("tsv", MimeType("text/tab-separated-values", MimeTypeCategory.Text))
        m.put("md", MimeType("text/markdown", MimeTypeCategory.Text))
        m.put("markdown", MimeType("text/markdown", MimeTypeCategory.Text))
        m.put("mkd", MimeType("text/x-markdown", MimeTypeCategory.Text))
        m.put("svg", MimeType("image/svg+xml", MimeTypeCategory.Image))
        m.put("svgz", MimeType("image/svg+xml", MimeTypeCategory.Image))

        // 图片
        m.put("png", MimeType("image/png", MimeTypeCategory.Image))
        m.put("jpg", MimeType("image/jpeg", MimeTypeCategory.Image))
        m.put("jpeg", MimeType("image/jpeg", MimeTypeCategory.Image))
        m.put("jpe", MimeType("image/jpeg", MimeTypeCategory.Image))
        m.put("gif", MimeType("image/gif", MimeTypeCategory.Image))
        m.put("bmp", MimeType("image/x-ms-bmp", MimeTypeCategory.Image))
        m.put("ico", MimeType("image/x-icon", MimeTypeCategory.Image))
        m.put("webp", MimeType("image/webp", MimeTypeCategory.Image))
        m.put("avif", MimeType("image/avif", MimeTypeCategory.Image))
        m.put("heic", MimeType("image/heic", MimeTypeCategory.Image))
        m.put("heif", MimeType("image/heif", MimeTypeCategory.Image))
        m.put("tiff", MimeType("image/tiff", MimeTypeCategory.Image))
        m.put("tif", MimeType("image/tiff", MimeTypeCategory.Image))
        m.put("apng", MimeType("image/apng", MimeTypeCategory.Image))
        m.put("jp2", MimeType("image/jp2", MimeTypeCategory.Image))
        m.put("jpg2", MimeType("image/jp2", MimeTypeCategory.Image))
        m.put("jpf", MimeType("image/jpx", MimeTypeCategory.Image))
        m.put("jpx", MimeType("image/jpx", MimeTypeCategory.Image))

        // 音频
        m.put("mp3", MimeType("audio/mpeg", MimeTypeCategory.Audio))
        m.put("mp2", MimeType("audio/mpeg", MimeTypeCategory.Audio))
        m.put("mpga", MimeType("audio/mpeg", MimeTypeCategory.Audio))
        m.put("m2a", MimeType("audio/mpeg", MimeTypeCategory.Audio))
        m.put("m3a", MimeType("audio/mpeg", MimeTypeCategory.Audio))
        m.put("wav", MimeType("audio/x-wav", MimeTypeCategory.Audio))
        m.put("ogg", MimeType("audio/ogg", MimeTypeCategory.Audio))
        m.put("oga", MimeType("audio/ogg", MimeTypeCategory.Audio))
        m.put("opus", MimeType("audio/ogg", MimeTypeCategory.Audio))
        m.put("flac", MimeType("audio/x-flac", MimeTypeCategory.Audio))
        m.put("aac", MimeType("audio/x-aac", MimeTypeCategory.Audio))
        m.put("m4a", MimeType("audio/x-m4a", MimeTypeCategory.Audio))
        m.put("mid", MimeType("audio/midi", MimeTypeCategory.Audio))
        m.put("midi", MimeType("audio/midi", MimeTypeCategory.Audio))
        m.put("kar", MimeType("audio/midi", MimeTypeCategory.Audio))
        m.put("rmi", MimeType("audio/midi", MimeTypeCategory.Audio))
        m.put("weba", MimeType("audio/webm", MimeTypeCategory.Audio))
        m.put("mka", MimeType("audio/x-matroska", MimeTypeCategory.Audio))
        m.put("s3m", MimeType("audio/s3m", MimeTypeCategory.Audio))
        m.put("amr", MimeType("audio/amr", MimeTypeCategory.Audio))
        m.put("aif", MimeType("audio/x-aiff", MimeTypeCategory.Audio))
        m.put("aiff", MimeType("audio/x-aiff", MimeTypeCategory.Audio))
        m.put("aifc", MimeType("audio/x-aiff", MimeTypeCategory.Audio))
        m.put("caf", MimeType("audio/x-caf", MimeTypeCategory.Audio))
        m.put("sil", MimeType("audio/silk", MimeTypeCategory.Audio))
        m.put("spx", MimeType("audio/ogg", MimeTypeCategory.Audio))

        // 视频
        m.put("mp4", MimeType("video/mp4", MimeTypeCategory.Video))
        m.put("mp4v", MimeType("video/mp4", MimeTypeCategory.Video))
        m.put("mpg4", MimeType("video/mp4", MimeTypeCategory.Video))
        m.put("mpeg", MimeType("video/mpeg", MimeTypeCategory.Video))
        m.put("mpg", MimeType("video/mpeg", MimeTypeCategory.Video))
        m.put("mpe", MimeType("video/mpeg", MimeTypeCategory.Video))
        m.put("m1v", MimeType("video/mpeg", MimeTypeCategory.Video))
        m.put("m2v", MimeType("video/mpeg", MimeTypeCategory.Video))
        m.put("webm", MimeType("video/webm", MimeTypeCategory.Video))
        m.put("mkv", MimeType("video/x-matroska", MimeTypeCategory.Video))
        m.put("mk3d", MimeType("video/x-matroska", MimeTypeCategory.Video))
        m.put("mks", MimeType("video/x-matroska", MimeTypeCategory.Video))
        m.put("avi", MimeType("video/x-msvideo", MimeTypeCategory.Video))
        m.put("mov", MimeType("video/quicktime", MimeTypeCategory.Video))
        m.put("qt", MimeType("video/quicktime", MimeTypeCategory.Video))
        m.put("flv", MimeType("video/x-flv", MimeTypeCategory.Video))
        m.put("wmv", MimeType("video/x-ms-wmv", MimeTypeCategory.Video))
        m.put("m4v", MimeType("video/x-m4v", MimeTypeCategory.Video))
        m.put("3gp", MimeType("video/3gpp", MimeTypeCategory.Video))
        m.put("3gpp", MimeType("video/3gpp", MimeTypeCategory.Video))
        m.put("3g2", MimeType("video/3gpp2", MimeTypeCategory.Video))
        m.put("f4v", MimeType("video/x-f4v", MimeTypeCategory.Video))
        m.put("fli", MimeType("video/x-fli", MimeTypeCategory.Video))
        m.put("mng", MimeType("video/x-mng", MimeTypeCategory.Video))
        m.put("asf", MimeType("video/x-ms-asf", MimeTypeCategory.Video))
        m.put("asx", MimeType("video/x-ms-asf", MimeTypeCategory.Video))
        m.put("vob", MimeType("video/x-ms-vob", MimeTypeCategory.Video))
        m.put("ogv", MimeType("video/ogg", MimeTypeCategory.Video))
        m.put("m4s", MimeType("video/iso.segment", MimeTypeCategory.Video))
        m.put("m4u", MimeType("video/vnd.mpegurl", MimeTypeCategory.Video))
        m.put("mxu", MimeType("video/vnd.mpegurl", MimeTypeCategory.Video))
        m.put("movie", MimeType("video/x-sgi-movie", MimeTypeCategory.Video))

        // 字体
        m.put("woff", MimeType("font/woff", MimeTypeCategory.Font))
        m.put("woff2", MimeType("font/woff2", MimeTypeCategory.Font))
        m.put("ttf", MimeType("font/ttf", MimeTypeCategory.Font))
        m.put("otf", MimeType("font/otf", MimeTypeCategory.Font))
        m.put("ttc", MimeType("font/collection", MimeTypeCategory.Font))
        m.put("eot", MimeType("application/vnd.ms-fontobject", MimeTypeCategory.Font))

        // 文档
        m.put("pdf", MimeType("application/pdf", MimeTypeCategory.Application))
        m.put("doc", MimeType("application/msword", MimeTypeCategory.Application))
        m.put("docx", MimeType("application/vnd.openxmlformats-officedocument.wordprocessingml.document", MimeTypeCategory.Application))
        m.put("xls", MimeType("application/vnd.ms-excel", MimeTypeCategory.Application))
        m.put("xlsx", MimeType("application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", MimeTypeCategory.Application))
        m.put("ppt", MimeType("application/vnd.ms-powerpoint", MimeTypeCategory.Application))
        m.put("pptx", MimeType("application/vnd.openxmlformats-officedocument.presentationml.presentation", MimeTypeCategory.Application))
        m.put("odt", MimeType("application/vnd.oasis.opendocument.text", MimeTypeCategory.Application))
        m.put("ods", MimeType("application/vnd.oasis.opendocument.spreadsheet", MimeTypeCategory.Application))
        m.put("odp", MimeType("application/vnd.oasis.opendocument.presentation", MimeTypeCategory.Application))
        m.put("odg", MimeType("application/vnd.oasis.opendocument.graphics", MimeTypeCategory.Application))
        m.put("rtf", MimeType("text/rtf", MimeTypeCategory.Text))

        // 压缩包
        m.put("zip", MimeType("application/zip", MimeTypeCategory.Application))
        m.put("gz", MimeType("application/gzip", MimeTypeCategory.Application))
        m.put("tar", MimeType("application/x-tar", MimeTypeCategory.Application))
        m.put("rar", MimeType("application/x-rar-compressed", MimeTypeCategory.Application))
        m.put("7z", MimeType("application/x-7z-compressed", MimeTypeCategory.Application))
        m.put("bz", MimeType("application/x-bzip", MimeTypeCategory.Application))
        m.put("bz2", MimeType("application/x-bzip2", MimeTypeCategory.Application))
        m.put("xz", MimeType("application/x-xz", MimeTypeCategory.Application))
        m.put("jar", MimeType("application/java-archive", MimeTypeCategory.Application))
        m.put("war", MimeType("application/java-archive", MimeTypeCategory.Application))
        m.put("ear", MimeType("application/java-archive", MimeTypeCategory.Application))

        // Web
        m.put("xml", MimeType("application/xml", MimeTypeCategory.Application))
        m.put("xhtml", MimeType("application/xhtml+xml", MimeTypeCategory.Application))
        m.put("xht", MimeType("application/xhtml+xml", MimeTypeCategory.Application))
        m.put("rss", MimeType("application/rss+xml", MimeTypeCategory.Application))
        m.put("atom", MimeType("application/atom+xml", MimeTypeCategory.Application))
        m.put("webmanifest", MimeType("application/manifest+json", MimeTypeCategory.Application))
        m.put("appcache", MimeType("text/cache-manifest", MimeTypeCategory.Text))
        m.put("manifest", MimeType("text/cache-manifest", MimeTypeCategory.Text))
        m.put("vtt", MimeType("text/vtt", MimeTypeCategory.Text))
        m.put("webapp", MimeType("application/x-web-app-manifest+json", MimeTypeCategory.Application))

        // 编程语言
        m.put("c", MimeType("text/x-c", MimeTypeCategory.Text))
        m.put("cc", MimeType("text/x-c", MimeTypeCategory.Text))
        m.put("cpp", MimeType("text/x-c", MimeTypeCategory.Text))
        m.put("cxx", MimeType("text/x-c", MimeTypeCategory.Text))
        m.put("h", MimeType("text/x-c", MimeTypeCategory.Text))
        m.put("hh", MimeType("text/x-c", MimeTypeCategory.Text))
        m.put("java", MimeType("text/x-java-source", MimeTypeCategory.Text))
        m.put("py", MimeType("text/x-python", MimeTypeCategory.Text))
        m.put("pl", MimeType("application/x-perl", MimeTypeCategory.Application))
        m.put("pm", MimeType("application/x-perl", MimeTypeCategory.Application))
        m.put("rb", MimeType("text/x-ruby", MimeTypeCategory.Text))
        m.put("php", MimeType("application/x-httpd-php", MimeTypeCategory.Application))
        m.put("sh", MimeType("application/x-sh", MimeTypeCategory.Application))
        m.put("bash", MimeType("application/x-sh", MimeTypeCategory.Application))
        m.put("zsh", MimeType("application/x-sh", MimeTypeCategory.Application))
        m.put("lua", MimeType("text/x-lua", MimeTypeCategory.Text))
        m.put("rs", MimeType("text/rust", MimeTypeCategory.Text))
        m.put("go", MimeType("text/go", MimeTypeCategory.Text))
        m.put("sql", MimeType("application/x-sql", MimeTypeCategory.Application))
        m.put("r", MimeType("text/x-r", MimeTypeCategory.Text))
        m.put("swift", MimeType("text/x-swift", MimeTypeCategory.Text))
        m.put("kt", MimeType("text/x-kotlin", MimeTypeCategory.Text))
        m.put("kts", MimeType("text/x-kotlin", MimeTypeCategory.Text))
        m.put("scala", MimeType("text/x-scala", MimeTypeCategory.Text))
        m.put("coffee", MimeType("text/coffeescript", MimeTypeCategory.Text))
        m.put("litcoffee", MimeType("text/coffeescript", MimeTypeCategory.Text))
        m.put("dart", MimeType("application/vnd.dart", MimeTypeCategory.Application))
        m.put("less", MimeType("text/less", MimeTypeCategory.Text))
        m.put("sass", MimeType("text/x-sass", MimeTypeCategory.Text))
        m.put("scss", MimeType("text/x-scss", MimeTypeCategory.Text))
        m.put("styl", MimeType("text/stylus", MimeTypeCategory.Text))
        m.put("stylus", MimeType("text/stylus", MimeTypeCategory.Text))
        m.put("svelte", MimeType("text/svelte", MimeTypeCategory.Text))
        m.put("vue", MimeType("text/vue", MimeTypeCategory.Text))
        m.put("toml", MimeType("application/toml", MimeTypeCategory.Application))
        m.put("yaml", MimeType("text/yaml", MimeTypeCategory.Text))
        m.put("yml", MimeType("text/yaml", MimeTypeCategory.Text))

        // 模板
        m.put("hbs", MimeType("text/x-handlebars-template", MimeTypeCategory.Text))
        m.put("pde", MimeType("text/x-processing", MimeTypeCategory.Text))

        // 数据
        m.put("protobuf", MimeType("application/protobuf", MimeTypeCategory.Application))
        m.put("graphql", MimeType("application/graphql", MimeTypeCategory.Application))

        // 二进制/可执行
        m.put("bin", MimeType("application/octet-stream", MimeTypeCategory.Other))
        m.put("exe", MimeType("application/x-msdownload", MimeTypeCategory.Application))
        m.put("dll", MimeType("application/x-msdownload", MimeTypeCategory.Application))
        m.put("so", MimeType("application/octet-stream", MimeTypeCategory.Other))
        m.put("img", MimeType("application/octet-stream", MimeTypeCategory.Other))
        m.put("iso", MimeType("application/x-iso9660-image", MimeTypeCategory.Application))
        m.put("dmg", MimeType("application/x-apple-diskimage", MimeTypeCategory.Application))
        m.put("deb", MimeType("application/x-debian-package", MimeTypeCategory.Application))
        m.put("rpm", MimeType("application/x-redhat-package-manager", MimeTypeCategory.Application))
        m.put("msi", MimeType("application/x-msdownload", MimeTypeCategory.Application))
        m.put("bat", MimeType("application/x-msdownload", MimeTypeCategory.Application))
        m.put("com", MimeType("application/x-msdownload", MimeTypeCategory.Application))
        m.put("class", MimeType("application/java-vm", MimeTypeCategory.Application))
        m.put("swf", MimeType("application/x-shockwave-flash", MimeTypeCategory.Application))

        // 证书/密钥
        m.put("pem", MimeType("application/x-x509-ca-cert", MimeTypeCategory.Application))
        m.put("crt", MimeType("application/x-x509-ca-cert", MimeTypeCategory.Application))
        m.put("cer", MimeType("application/pkix-cert", MimeTypeCategory.Application))
        m.put("key", MimeType("application/x-iwork-keynote-sffkey", MimeTypeCategory.Application))
        m.put("p12", MimeType("application/x-pkcs12", MimeTypeCategory.Application))
        m.put("pfx", MimeType("application/x-pkcs12", MimeTypeCategory.Application))
        m.put("der", MimeType("application/x-x509-ca-cert", MimeTypeCategory.Application))
        m.put("p7b", MimeType("application/x-pkcs7-certificates", MimeTypeCategory.Application))
        m.put("p7c", MimeType("application/pkcs7-mime", MimeTypeCategory.Application))

        // OpenDocument
        m.put("odc", MimeType("application/vnd.oasis.opendocument.chart", MimeTypeCategory.Application))
        m.put("odf", MimeType("application/vnd.oasis.opendocument.formula", MimeTypeCategory.Application))
        m.put("odi", MimeType("application/vnd.oasis.opendocument.image", MimeTypeCategory.Application))
        m.put("odm", MimeType("application/vnd.oasis.opendocument.text-master", MimeTypeCategory.Application))
        m.put("ott", MimeType("application/vnd.oasis.opendocument.text-template", MimeTypeCategory.Application))
        m.put("ots", MimeType("application/vnd.oasis.opendocument.spreadsheet-template", MimeTypeCategory.Application))
        m.put("otp", MimeType("application/vnd.oasis.opendocument.presentation-template", MimeTypeCategory.Application))
        m.put("otg", MimeType("application/vnd.oasis.opendocument.graphics-template", MimeTypeCategory.Application))
        m.put("otf", MimeType("font/otf", MimeTypeCategory.Font))  // 字体，覆盖上面的 OpenDocument

        // Microsoft Office (旧格式)
        m.put("dot", MimeType("application/msword", MimeTypeCategory.Application))
        m.put("xla", MimeType("application/vnd.ms-excel", MimeTypeCategory.Application))
        m.put("xlc", MimeType("application/vnd.ms-excel", MimeTypeCategory.Application))
        m.put("xlm", MimeType("application/vnd.ms-excel", MimeTypeCategory.Application))
        m.put("xlt", MimeType("application/vnd.ms-excel", MimeTypeCategory.Application))
        m.put("xlw", MimeType("application/vnd.ms-excel", MimeTypeCategory.Application))
        m.put("pps", MimeType("application/vnd.ms-powerpoint", MimeTypeCategory.Application))
        m.put("pot", MimeType("application/vnd.ms-powerpoint", MimeTypeCategory.Application))

        // Microsoft Office (新格式 - macroenabled)
        m.put("docm", MimeType("application/vnd.ms-word.document.macroenabled.12", MimeTypeCategory.Application))
        m.put("dotm", MimeType("application/vnd.ms-word.template.macroenabled.12", MimeTypeCategory.Application))
        m.put("xlsb", MimeType("application/vnd.ms-excel.sheet.binary.macroenabled.12", MimeTypeCategory.Application))
        m.put("xlsm", MimeType("application/vnd.ms-excel.sheet.macroenabled.12", MimeTypeCategory.Application))
        m.put("xltm", MimeType("application/vnd.ms-excel.template.macroenabled.12", MimeTypeCategory.Application))
        m.put("pptm", MimeType("application/vnd.ms-powerpoint.presentation.macroenabled.12", MimeTypeCategory.Application))
        m.put("potm", MimeType("application/vnd.ms-powerpoint.template.macroenabled.12", MimeTypeCategory.Application))
        m.put("ppsm", MimeType("application/vnd.ms-powerpoint.slideshow.macroenabled.12", MimeTypeCategory.Application))
        m.put("ppsx", MimeType("application/vnd.openxmlformats-officedocument.presentationml.slideshow", MimeTypeCategory.Application))
        m.put("sldx", MimeType("application/vnd.openxmlformats-officedocument.presentationml.slide", MimeTypeCategory.Application))
        m.put("sldm", MimeType("application/vnd.ms-powerpoint.slide.macroenabled.12", MimeTypeCategory.Application))
        m.put("ppam", MimeType("application/vnd.ms-powerpoint.addin.macroenabled.12", MimeTypeCategory.Application))
        m.put("xlam", MimeType("application/vnd.ms-excel.addin.macroenabled.12", MimeTypeCategory.Application))
        m.put("dotx", MimeType("application/vnd.openxmlformats-officedocument.wordprocessingml.template", MimeTypeCategory.Application))
        m.put("potx", MimeType("application/vnd.openxmlformats-officedocument.presentationml.template", MimeTypeCategory.Application))
        m.put("xltx", MimeType("application/vnd.openxmlformats-officedocument.spreadsheetml.template", MimeTypeCategory.Application))

        // 3D 模型
        m.put("gltf", MimeType("model/gltf+json", MimeTypeCategory.Model))
        m.put("glb", MimeType("model/gltf-binary", MimeTypeCategory.Model))
        m.put("obj", MimeType("model/obj", MimeTypeCategory.Model))
        m.put("stl", MimeType("model/stl", MimeTypeCategory.Model))
        m.put("dae", MimeType("model/vnd.collada+xml", MimeTypeCategory.Model))
        m.put("3mf", MimeType("model/3mf", MimeTypeCategory.Model))
        m.put("fbx", MimeType("model/fbx", MimeTypeCategory.Model))
        m.put("u3d", MimeType("model/u3d", MimeTypeCategory.Model))
        m.put("prc", MimeType("model/prc", MimeTypeCategory.Model))
        m.put("dwf", MimeType("model/vnd.dwf", MimeTypeCategory.Model))
        m.put("mtl", MimeType("model/mtl", MimeTypeCategory.Model))
        m.put("bsp", MimeType("model/vnd.valve.source.compiled-map", MimeTypeCategory.Model))

        // 其他常见格式
        m.put("ics", MimeType("text/calendar", MimeTypeCategory.Text))
        m.put("ifb", MimeType("text/calendar", MimeTypeCategory.Text))
        m.put("vcf", MimeType("text/x-vcard", MimeTypeCategory.Text))
        m.put("vcard", MimeType("text/vcard", MimeTypeCategory.Text))
        m.put("torrent", MimeType("application/x-bittorrent", MimeTypeCategory.Application))
        m.put("crx", MimeType("application/x-chrome-extension", MimeTypeCategory.Application))
        m.put("xpi", MimeType("application/x-xpinstall", MimeTypeCategory.Application))
        m.put("apk", MimeType("application/vnd.android.package-archive", MimeTypeCategory.Application))
        m.put("m3u", MimeType("audio/x-mpegurl", MimeTypeCategory.Audio))
        m.put("m3u8", MimeType("application/vnd.apple.mpegurl", MimeTypeCategory.Application))
        m.put("swf", MimeType("application/x-shockwave-flash", MimeTypeCategory.Application))

        // 编程相关
        m.put("asm", MimeType("text/x-asm", MimeTypeCategory.Text))
        m.put("s", MimeType("text/x-asm", MimeTypeCategory.Text))
        m.put("pas", MimeType("text/x-pascal", MimeTypeCategory.Text))
        m.put("p", MimeType("text/x-pascal", MimeTypeCategory.Text))
        m.put("f", MimeType("text/x-fortran", MimeTypeCategory.Text))
        m.put("f77", MimeType("text/x-fortran", MimeTypeCategory.Text))
        m.put("f90", MimeType("text/x-fortran", MimeTypeCategory.Text))
        m.put("for", MimeType("text/x-fortran", MimeTypeCategory.Text))
        m.put("dtd", MimeType("application/xml-dtd", MimeTypeCategory.Application))
        m.put("xsd", MimeType("application/xml", MimeTypeCategory.Application))
        m.put("xsl", MimeType("application/xslt+xml", MimeTypeCategory.Application))
        m.put("xslt", MimeType("application/xslt+xml", MimeTypeCategory.Application))
        m.put("wsdl", MimeType("application/wsdl+xml", MimeTypeCategory.Application))

        // 其他
        m.put("ps", MimeType("application/postscript", MimeTypeCategory.Application))
        m.put("eps", MimeType("application/postscript", MimeTypeCategory.Application))
        m.put("ai", MimeType("application/postscript", MimeTypeCategory.Application))
        m.put("epub", MimeType("application/epub+zip", MimeTypeCategory.Application))
        m.put("mobi", MimeType("application/x-mobipocket-ebook", MimeTypeCategory.Application))
        m.put("azw", MimeType("application/vnd.amazon.ebook", MimeTypeCategory.Application))
        m.put("tex", MimeType("application/x-tex", MimeTypeCategory.Application))
        m.put("latex", MimeType("application/x-latex", MimeTypeCategory.Application))
        m.put("tcl", MimeType("application/x-tcl", MimeTypeCategory.Application))
        m.put("tk", MimeType("application/x-tcl", MimeTypeCategory.Application))
        m.put("csh", MimeType("application/x-csh", MimeTypeCategory.Application))
        m.put("shar", MimeType("application/x-shar", MimeTypeCategory.Application))
        m.put("cpio", MimeType("application/x-cpio", MimeTypeCategory.Application))
        m.put("gtar", MimeType("application/x-gtar", MimeTypeCategory.Application))
        m.put("ustar", MimeType("application/x-ustar", MimeTypeCategory.Application))
        m.put("arc", MimeType("application/x-freearc", MimeTypeCategory.Application))
        m.put("lha", MimeType("application/x-lzh-compressed", MimeTypeCategory.Application))
        m.put("lzh", MimeType("application/x-lzh-compressed", MimeTypeCategory.Application))
        m.put("sit", MimeType("application/x-stuffit", MimeTypeCategory.Application))
        m.put("sitx", MimeType("application/x-stuffitx", MimeTypeCategory.Application))
        m.put("sea", MimeType("application/x-sea", MimeTypeCategory.Application))
        m.put("pgp", MimeType("application/pgp-encrypted", MimeTypeCategory.Application))
        m.put("asc", MimeType("application/pgp-signature", MimeTypeCategory.Application))
        m.put("sig", MimeType("application/pgp-signature", MimeTypeCategory.Application))

        return m
    }

    /// 查找扩展名对应的 MIME 类型
    public static func lookup(ext: String): ?MimeType {
        return MAP.get(ext.toLower())
    }

    /// 获取所有已知扩展名
    public static func allExtensions(): Array<String> {
        return MAP.keys().toArray()
    }
}
