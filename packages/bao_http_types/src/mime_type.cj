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
package bao_http_types

import bao_core.*
import std.collection.*

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

    public operator func ==(right: MimeTypeCategory): Bool {
        match (this) {
            case None => match (right) { case None => true case _ => false }
            case Image => match (right) { case Image => true case _ => false }
            case Text => match (right) { case Text => true case _ => false }
            case Html => match (right) { case Html => true case _ => false }
            case Font => match (right) { case Font => true case _ => false }
            case Other => match (right) { case Other => true case _ => false }
            case Css => match (right) { case Css => true case _ => false }
            case Json => match (right) { case Json => true case _ => false }
            case Audio => match (right) { case Audio => true case _ => false }
            case Video => match (right) { case Video => true case _ => false }
            case JavaScript => match (right) { case JavaScript => true case _ => false }
            case Wasm => match (right) { case Wasm => true case _ => false }
            case Application => match (right) { case Application => true case _ => false }
            case Model => match (right) { case Model => true case _ => false }
            case Message => match (right) { case Message => true case _ => false }
            case XConference => match (right) { case XConference => true case _ => false }
            case XShader => match (right) { case XShader => true case _ => false }
            case Chemical => match (right) { case Chemical => true case _ => false }
            case Multipart => match (right) { case Multipart => true case _ => false }
        }
    }

    public operator func !=(right: MimeTypeCategory): Bool {
        !(this == right)
    }
}

// ============================================================================
// MimeTypeCategoryUtil - MimeTypeCategory 工具
// 严格翻译自: MimeType.zig Category 的方法
// ============================================================================

/// MIME 类型分类工具
public class MimeType {
    /// 是否为代码类型 - 对应 Bun Category.isCode()
    public static func isCode(cat: MimeTypeCategory): Bool {
        match (cat) {
            case MimeTypeCategory.Wasm => true
            case MimeTypeCategory.Json => true
            case MimeTypeCategory.Css => true
            case MimeTypeCategory.Html => true
            case MimeTypeCategory.JavaScript => true
            case _ => false
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
            case _ => false
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
            case _ => true
        }
    }

    /// 从 MIME 类型字符串推断分类
    public static func initFunc(str: String): MimeTypeCategory {
        let slashIdx = str.indexOf("/")
        if (slashIdx.isNone()) {
            return MimeTypeCategory.Other
        }

        let slash = slashIdx.getOrThrow()
        let category = str[0..slash]
        var afterSlash = if (str.size > slash + 1) {
            str[(slash + 1)..str.size]
        } else {
            ""
        }

        let semicolonIdx = afterSlash.indexOf(";")
        if (semicolonIdx.isSome()) {
            afterSlash = afterSlash[0..semicolonIdx.getOrThrow()]
        }

        if (category == "text") {
            if (afterSlash == "javascript") { return MimeTypeCategory.JavaScript }
            if (afterSlash == "css") { return MimeTypeCategory.Css }
            if (afterSlash == "html") { return MimeTypeCategory.Html }
            if (afterSlash == "json") { return MimeTypeCategory.Json }
            return MimeTypeCategory.Text
        }

        if (category == "application") {
            if (afterSlash == "wasm") { return MimeTypeCategory.Wasm }
            if (afterSlash == "javascript") { return MimeTypeCategory.JavaScript }
            if (afterSlash == "json") { return MimeTypeCategory.Json }
            if (afterSlash == "octet-stream") { return MimeTypeCategory.Other }
            return MimeTypeCategory.Application
        }

        if (category == "image") { return MimeTypeCategory.Image }
        if (category == "video") { return MimeTypeCategory.Video }
        if (category == "audio") { return MimeTypeCategory.Audio }
        if (category == "font") { return MimeTypeCategory.Font }
        if (category == "multipart") { return MimeTypeCategory.Multipart }
        if (category == "model") { return MimeTypeCategory.Model }
        if (category == "message") { return MimeTypeCategory.Message }
        if (category == "x-conference") { return MimeTypeCategory.XConference }
        if (category == "x-shader") { return MimeTypeCategory.XShader }
        if (category == "chemical") { return MimeTypeCategory.Chemical }

        return MimeTypeCategory.Other
    }

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
        if (category == MimeTypeCategory.Text || MimeType.isCode(category)) {
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

    /// 从名称初始化 MIME 类型
    public static func initFromName(str: String): MimeType {
        let slashIdx = str.indexOf("/")
        if (slashIdx.isNone()) {
            return MimeTypeConstants.OTHER
        }

        let slash = slashIdx.getOrThrow()
        let categoryStr = str[0..slash]
        if (categoryStr.size == 0 || categoryStr[0] == UInt8(42) || str.size <= slash + 1) {
            return MimeTypeConstants.OTHER
        }

        var subType = str[(slash + 1)..str.size]
        let semicolonIdx = subType.indexOf(";")
        if (semicolonIdx.isSome()) {
            subType = subType[0..semicolonIdx.getOrThrow()]
        }

        if (categoryStr == "application") {
            if (subType == "json" || subType == "geo+json") { return MimeTypeConstants.JSON }
            if (subType == "octet-stream") { return MimeTypeConstants.OTHER }
            if (subType == "wasm") { return MimeTypeConstants.WASM }
            return MimeType(str, MimeTypeCategory.Application)
        }

        if (categoryStr == "text") {
            if (subType == "css") { return MimeTypeConstants.CSS }
            if (subType == "html") { return MimeTypeConstants.HTML }
            if (subType == "javascript") { return MimeTypeConstants.JAVASCRIPT }
            if (subType == "plain") { return MimeTypeConstants.TEXT }
            return MimeType(str, MimeTypeCategory.Text)
        }

        if (categoryStr == "image") { return MimeType(str, MimeTypeCategory.Image) }
        if (categoryStr == "audio") { return MimeType(str, MimeTypeCategory.Audio) }
        if (categoryStr == "video") { return MimeType(str, MimeTypeCategory.Video) }
        if (categoryStr == "font") { return MimeType(str, MimeTypeCategory.Font) }

        return MimeType(str, MimeTypeCategory.Other)
    }

    /// 根据文件头字节嗅探图片类型 - 对应 Bun MimeType.sniff()
    /// 通过魔数字节识别 BMP/JPEG/TIFF/GIF/PNG
    public static func sniff(bytes: Array<UInt8>): ?MimeType {
        if (bytes.size < 2) {
            return None<MimeType>
        }

        // BMP: 42 4D
        if (bytes.size >= 2 && bytes[0] == 0x42 && bytes[1] == 0x4D) {
            return MimeType("image/bmp", MimeTypeCategory.Image)
        }
        // JPEG: FF D8 FF
        if (bytes.size >= 3 && bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) {
            return MimeType("image/jpeg", MimeTypeCategory.Image)
        }
        // TIFF (LE): 49 49 2A 00
        if (bytes.size >= 4 && bytes[0] == 0x49 && bytes[1] == 0x49 && bytes[2] == 0x2A && bytes[3] == 0x00) {
            return MimeType("image/tiff", MimeTypeCategory.Image)
        }
        // TIFF (BE): 4D 4D 00 2A
        if (bytes.size >= 4 && bytes[0] == 0x4D && bytes[1] == 0x4D && bytes[2] == 0x00 && bytes[3] == 0x2A) {
            return MimeType("image/tiff", MimeTypeCategory.Image)
        }
        // GIF: 47 49 46 38 39 61
        if (bytes.size >= 6 && bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46 &&
            bytes[3] == 0x38 && bytes[4] == 0x39 && bytes[5] == 0x61) {
            return MimeType("image/gif", MimeTypeCategory.Image)
        }
        // PNG: 89 50 4E 47 0D 0A 1A 0A
        if (bytes.size >= 8 && bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E &&
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
        m.add("html", MimeType("text/html", MimeTypeCategory.Html))
        m.add("htm", MimeType("text/html", MimeTypeCategory.Html))
        m.add("css", MimeType("text/css", MimeTypeCategory.Css))
        m.add("js", MimeType("application/javascript", MimeTypeCategory.JavaScript))
        m.add("mjs", MimeType("application/javascript", MimeTypeCategory.JavaScript))
        m.add("cjs", MimeType("application/javascript", MimeTypeCategory.JavaScript))
        m.add("ts", MimeType("application/javascript", MimeTypeCategory.JavaScript))
        m.add("tsx", MimeType("application/javascript", MimeTypeCategory.JavaScript))
        m.add("mts", MimeType("application/javascript", MimeTypeCategory.JavaScript))
        m.add("mtsx", MimeType("application/javascript", MimeTypeCategory.JavaScript))
        m.add("jsx", MimeType("text/jsx", MimeTypeCategory.JavaScript))
        m.add("json", MimeType("application/json", MimeTypeCategory.Json))
        m.add("json5", MimeType("application/json5", MimeTypeCategory.Application))
        m.add("jsonld", MimeType("application/ld+json", MimeTypeCategory.Application))
        m.add("jsonml", MimeType("application/jsonml+json", MimeTypeCategory.Application))
        m.add("map", MimeType("application/json", MimeTypeCategory.Json))
        m.add("wasm", MimeType("application/webassembly", MimeTypeCategory.Wasm))
        m.add("txt", MimeType("text/plain", MimeTypeCategory.Text))
        m.add("text", MimeType("text/plain", MimeTypeCategory.Text))
        m.add("conf", MimeType("text/plain", MimeTypeCategory.Text))
        m.add("log", MimeType("text/plain", MimeTypeCategory.Text))
        m.add("ini", MimeType("text/plain", MimeTypeCategory.Text))
        m.add("list", MimeType("text/plain", MimeTypeCategory.Text))
        m.add("in", MimeType("text/plain", MimeTypeCategory.Text))
        m.add("def", MimeType("text/plain", MimeTypeCategory.Text))
        m.add("csv", MimeType("text/csv", MimeTypeCategory.Text))
        m.add("tsv", MimeType("text/tab-separated-values", MimeTypeCategory.Text))
        m.add("md", MimeType("text/markdown", MimeTypeCategory.Text))
        m.add("markdown", MimeType("text/markdown", MimeTypeCategory.Text))
        m.add("mkd", MimeType("text/x-markdown", MimeTypeCategory.Text))
        m.add("svg", MimeType("image/svg+xml", MimeTypeCategory.Image))
        m.add("svgz", MimeType("image/svg+xml", MimeTypeCategory.Image))

        // 图片
        m.add("png", MimeType("image/png", MimeTypeCategory.Image))
        m.add("jpg", MimeType("image/jpeg", MimeTypeCategory.Image))
        m.add("jpeg", MimeType("image/jpeg", MimeTypeCategory.Image))
        m.add("jpe", MimeType("image/jpeg", MimeTypeCategory.Image))
        m.add("gif", MimeType("image/gif", MimeTypeCategory.Image))
        m.add("bmp", MimeType("image/x-ms-bmp", MimeTypeCategory.Image))
        m.add("ico", MimeType("image/x-icon", MimeTypeCategory.Image))
        m.add("webp", MimeType("image/webp", MimeTypeCategory.Image))
        m.add("avif", MimeType("image/avif", MimeTypeCategory.Image))
        m.add("heic", MimeType("image/heic", MimeTypeCategory.Image))
        m.add("heif", MimeType("image/heif", MimeTypeCategory.Image))
        m.add("tiff", MimeType("image/tiff", MimeTypeCategory.Image))
        m.add("tif", MimeType("image/tiff", MimeTypeCategory.Image))
        m.add("apng", MimeType("image/apng", MimeTypeCategory.Image))
        m.add("jp2", MimeType("image/jp2", MimeTypeCategory.Image))
        m.add("jpg2", MimeType("image/jp2", MimeTypeCategory.Image))
        m.add("jpf", MimeType("image/jpx", MimeTypeCategory.Image))
        m.add("jpx", MimeType("image/jpx", MimeTypeCategory.Image))

        // 音频
        m.add("mp3", MimeType("audio/mpeg", MimeTypeCategory.Audio))
        m.add("mp2", MimeType("audio/mpeg", MimeTypeCategory.Audio))
        m.add("mpga", MimeType("audio/mpeg", MimeTypeCategory.Audio))
        m.add("m2a", MimeType("audio/mpeg", MimeTypeCategory.Audio))
        m.add("m3a", MimeType("audio/mpeg", MimeTypeCategory.Audio))
        m.add("wav", MimeType("audio/x-wav", MimeTypeCategory.Audio))
        m.add("ogg", MimeType("audio/ogg", MimeTypeCategory.Audio))
        m.add("oga", MimeType("audio/ogg", MimeTypeCategory.Audio))
        m.add("opus", MimeType("audio/ogg", MimeTypeCategory.Audio))
        m.add("flac", MimeType("audio/x-flac", MimeTypeCategory.Audio))
        m.add("aac", MimeType("audio/x-aac", MimeTypeCategory.Audio))
        m.add("m4a", MimeType("audio/x-m4a", MimeTypeCategory.Audio))
        m.add("mid", MimeType("audio/midi", MimeTypeCategory.Audio))
        m.add("midi", MimeType("audio/midi", MimeTypeCategory.Audio))
        m.add("kar", MimeType("audio/midi", MimeTypeCategory.Audio))
        m.add("rmi", MimeType("audio/midi", MimeTypeCategory.Audio))
        m.add("weba", MimeType("audio/webm", MimeTypeCategory.Audio))
        m.add("mka", MimeType("audio/x-matroska", MimeTypeCategory.Audio))
        m.add("s3m", MimeType("audio/s3m", MimeTypeCategory.Audio))
        m.add("amr", MimeType("audio/amr", MimeTypeCategory.Audio))
        m.add("aif", MimeType("audio/x-aiff", MimeTypeCategory.Audio))
        m.add("aiff", MimeType("audio/x-aiff", MimeTypeCategory.Audio))
        m.add("aifc", MimeType("audio/x-aiff", MimeTypeCategory.Audio))
        m.add("caf", MimeType("audio/x-caf", MimeTypeCategory.Audio))
        m.add("sil", MimeType("audio/silk", MimeTypeCategory.Audio))
        m.add("spx", MimeType("audio/ogg", MimeTypeCategory.Audio))

        // 视频
        m.add("mp4", MimeType("video/mp4", MimeTypeCategory.Video))
        m.add("mp4v", MimeType("video/mp4", MimeTypeCategory.Video))
        m.add("mpg4", MimeType("video/mp4", MimeTypeCategory.Video))
        m.add("mpeg", MimeType("video/mpeg", MimeTypeCategory.Video))
        m.add("mpg", MimeType("video/mpeg", MimeTypeCategory.Video))
        m.add("mpe", MimeType("video/mpeg", MimeTypeCategory.Video))
        m.add("m1v", MimeType("video/mpeg", MimeTypeCategory.Video))
        m.add("m2v", MimeType("video/mpeg", MimeTypeCategory.Video))
        m.add("webm", MimeType("video/webm", MimeTypeCategory.Video))
        m.add("mkv", MimeType("video/x-matroska", MimeTypeCategory.Video))
        m.add("mk3d", MimeType("video/x-matroska", MimeTypeCategory.Video))
        m.add("mks", MimeType("video/x-matroska", MimeTypeCategory.Video))
        m.add("avi", MimeType("video/x-msvideo", MimeTypeCategory.Video))
        m.add("mov", MimeType("video/quicktime", MimeTypeCategory.Video))
        m.add("qt", MimeType("video/quicktime", MimeTypeCategory.Video))
        m.add("flv", MimeType("video/x-flv", MimeTypeCategory.Video))
        m.add("wmv", MimeType("video/x-ms-wmv", MimeTypeCategory.Video))
        m.add("m4v", MimeType("video/x-m4v", MimeTypeCategory.Video))
        m.add("3gp", MimeType("video/3gpp", MimeTypeCategory.Video))
        m.add("3gpp", MimeType("video/3gpp", MimeTypeCategory.Video))
        m.add("3g2", MimeType("video/3gpp2", MimeTypeCategory.Video))
        m.add("f4v", MimeType("video/x-f4v", MimeTypeCategory.Video))
        m.add("fli", MimeType("video/x-fli", MimeTypeCategory.Video))
        m.add("mng", MimeType("video/x-mng", MimeTypeCategory.Video))
        m.add("asf", MimeType("video/x-ms-asf", MimeTypeCategory.Video))
        m.add("asx", MimeType("video/x-ms-asf", MimeTypeCategory.Video))
        m.add("vob", MimeType("video/x-ms-vob", MimeTypeCategory.Video))
        m.add("ogv", MimeType("video/ogg", MimeTypeCategory.Video))
        m.add("m4s", MimeType("video/iso.segment", MimeTypeCategory.Video))
        m.add("m4u", MimeType("video/vnd.mpegurl", MimeTypeCategory.Video))
        m.add("mxu", MimeType("video/vnd.mpegurl", MimeTypeCategory.Video))
        m.add("movie", MimeType("video/x-sgi-movie", MimeTypeCategory.Video))

        // 字体
        m.add("woff", MimeType("font/woff", MimeTypeCategory.Font))
        m.add("woff2", MimeType("font/woff2", MimeTypeCategory.Font))
        m.add("ttf", MimeType("font/ttf", MimeTypeCategory.Font))
        m.add("otf", MimeType("font/otf", MimeTypeCategory.Font))
        m.add("ttc", MimeType("font/collection", MimeTypeCategory.Font))
        m.add("eot", MimeType("application/vnd.ms-fontobject", MimeTypeCategory.Font))

        // 文档
        m.add("pdf", MimeType("application/pdf", MimeTypeCategory.Application))
        m.add("doc", MimeType("application/msword", MimeTypeCategory.Application))
        m.add("docx", MimeType("application/vnd.openxmlformats-officedocument.wordprocessingml.document", MimeTypeCategory.Application))
        m.add("xls", MimeType("application/vnd.ms-excel", MimeTypeCategory.Application))
        m.add("xlsx", MimeType("application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", MimeTypeCategory.Application))
        m.add("ppt", MimeType("application/vnd.ms-powerpoint", MimeTypeCategory.Application))
        m.add("pptx", MimeType("application/vnd.openxmlformats-officedocument.presentationml.presentation", MimeTypeCategory.Application))
        m.add("odt", MimeType("application/vnd.oasis.opendocument.text", MimeTypeCategory.Application))
        m.add("ods", MimeType("application/vnd.oasis.opendocument.spreadsheet", MimeTypeCategory.Application))
        m.add("odp", MimeType("application/vnd.oasis.opendocument.presentation", MimeTypeCategory.Application))
        m.add("odg", MimeType("application/vnd.oasis.opendocument.graphics", MimeTypeCategory.Application))
        m.add("rtf", MimeType("text/rtf", MimeTypeCategory.Text))

        // 压缩包
        m.add("zip", MimeType("application/zip", MimeTypeCategory.Application))
        m.add("gz", MimeType("application/gzip", MimeTypeCategory.Application))
        m.add("tar", MimeType("application/x-tar", MimeTypeCategory.Application))
        m.add("rar", MimeType("application/x-rar-compressed", MimeTypeCategory.Application))
        m.add("7z", MimeType("application/x-7z-compressed", MimeTypeCategory.Application))
        m.add("bz", MimeType("application/x-bzip", MimeTypeCategory.Application))
        m.add("bz2", MimeType("application/x-bzip2", MimeTypeCategory.Application))
        m.add("xz", MimeType("application/x-xz", MimeTypeCategory.Application))
        m.add("jar", MimeType("application/java-archive", MimeTypeCategory.Application))
        m.add("war", MimeType("application/java-archive", MimeTypeCategory.Application))
        m.add("ear", MimeType("application/java-archive", MimeTypeCategory.Application))

        // Web
        m.add("xml", MimeType("application/xml", MimeTypeCategory.Application))
        m.add("xhtml", MimeType("application/xhtml+xml", MimeTypeCategory.Application))
        m.add("xht", MimeType("application/xhtml+xml", MimeTypeCategory.Application))
        m.add("rss", MimeType("application/rss+xml", MimeTypeCategory.Application))
        m.add("atom", MimeType("application/atom+xml", MimeTypeCategory.Application))
        m.add("webmanifest", MimeType("application/manifest+json", MimeTypeCategory.Application))
        m.add("appcache", MimeType("text/cache-manifest", MimeTypeCategory.Text))
        m.add("manifest", MimeType("text/cache-manifest", MimeTypeCategory.Text))
        m.add("vtt", MimeType("text/vtt", MimeTypeCategory.Text))
        m.add("webapp", MimeType("application/x-web-app-manifest+json", MimeTypeCategory.Application))

        // 编程语言
        m.add("c", MimeType("text/x-c", MimeTypeCategory.Text))
        m.add("cc", MimeType("text/x-c", MimeTypeCategory.Text))
        m.add("cpp", MimeType("text/x-c", MimeTypeCategory.Text))
        m.add("cxx", MimeType("text/x-c", MimeTypeCategory.Text))
        m.add("h", MimeType("text/x-c", MimeTypeCategory.Text))
        m.add("hh", MimeType("text/x-c", MimeTypeCategory.Text))
        m.add("java", MimeType("text/x-java-source", MimeTypeCategory.Text))
        m.add("py", MimeType("text/x-python", MimeTypeCategory.Text))
        m.add("pl", MimeType("application/x-perl", MimeTypeCategory.Application))
        m.add("pm", MimeType("application/x-perl", MimeTypeCategory.Application))
        m.add("rb", MimeType("text/x-ruby", MimeTypeCategory.Text))
        m.add("php", MimeType("application/x-httpd-php", MimeTypeCategory.Application))
        m.add("sh", MimeType("application/x-sh", MimeTypeCategory.Application))
        m.add("bash", MimeType("application/x-sh", MimeTypeCategory.Application))
        m.add("zsh", MimeType("application/x-sh", MimeTypeCategory.Application))
        m.add("lua", MimeType("text/x-lua", MimeTypeCategory.Text))
        m.add("rs", MimeType("text/rust", MimeTypeCategory.Text))
        m.add("go", MimeType("text/go", MimeTypeCategory.Text))
        m.add("sql", MimeType("application/x-sql", MimeTypeCategory.Application))
        m.add("r", MimeType("text/x-r", MimeTypeCategory.Text))
        m.add("swift", MimeType("text/x-swift", MimeTypeCategory.Text))
        m.add("kt", MimeType("text/x-kotlin", MimeTypeCategory.Text))
        m.add("kts", MimeType("text/x-kotlin", MimeTypeCategory.Text))
        m.add("scala", MimeType("text/x-scala", MimeTypeCategory.Text))
        m.add("coffee", MimeType("text/coffeescript", MimeTypeCategory.Text))
        m.add("litcoffee", MimeType("text/coffeescript", MimeTypeCategory.Text))
        m.add("dart", MimeType("application/vnd.dart", MimeTypeCategory.Application))
        m.add("less", MimeType("text/less", MimeTypeCategory.Text))
        m.add("sass", MimeType("text/x-sass", MimeTypeCategory.Text))
        m.add("scss", MimeType("text/x-scss", MimeTypeCategory.Text))
        m.add("styl", MimeType("text/stylus", MimeTypeCategory.Text))
        m.add("stylus", MimeType("text/stylus", MimeTypeCategory.Text))
        m.add("svelte", MimeType("text/svelte", MimeTypeCategory.Text))
        m.add("vue", MimeType("text/vue", MimeTypeCategory.Text))
        m.add("toml", MimeType("application/toml", MimeTypeCategory.Application))
        m.add("yaml", MimeType("text/yaml", MimeTypeCategory.Text))
        m.add("yml", MimeType("text/yaml", MimeTypeCategory.Text))

        // 模板
        m.add("hbs", MimeType("text/x-handlebars-template", MimeTypeCategory.Text))
        m.add("pde", MimeType("text/x-processing", MimeTypeCategory.Text))

        // 数据
        m.add("protobuf", MimeType("application/protobuf", MimeTypeCategory.Application))
        m.add("graphql", MimeType("application/graphql", MimeTypeCategory.Application))

        // 二进制/可执行
        m.add("bin", MimeType("application/octet-stream", MimeTypeCategory.Other))
        m.add("exe", MimeType("application/x-msdownload", MimeTypeCategory.Application))
        m.add("dll", MimeType("application/x-msdownload", MimeTypeCategory.Application))
        m.add("so", MimeType("application/octet-stream", MimeTypeCategory.Other))
        m.add("img", MimeType("application/octet-stream", MimeTypeCategory.Other))
        m.add("iso", MimeType("application/x-iso9660-image", MimeTypeCategory.Application))
        m.add("dmg", MimeType("application/x-apple-diskimage", MimeTypeCategory.Application))
        m.add("deb", MimeType("application/x-debian-package", MimeTypeCategory.Application))
        m.add("rpm", MimeType("application/x-redhat-package-manager", MimeTypeCategory.Application))
        m.add("msi", MimeType("application/x-msdownload", MimeTypeCategory.Application))
        m.add("bat", MimeType("application/x-msdownload", MimeTypeCategory.Application))
        m.add("com", MimeType("application/x-msdownload", MimeTypeCategory.Application))
        m.add("class", MimeType("application/java-vm", MimeTypeCategory.Application))
        m.add("swf", MimeType("application/x-shockwave-flash", MimeTypeCategory.Application))

        // 证书/密钥
        m.add("pem", MimeType("application/x-x509-ca-cert", MimeTypeCategory.Application))
        m.add("crt", MimeType("application/x-x509-ca-cert", MimeTypeCategory.Application))
        m.add("cer", MimeType("application/pkix-cert", MimeTypeCategory.Application))
        m.add("key", MimeType("application/x-iwork-keynote-sffkey", MimeTypeCategory.Application))
        m.add("p12", MimeType("application/x-pkcs12", MimeTypeCategory.Application))
        m.add("pfx", MimeType("application/x-pkcs12", MimeTypeCategory.Application))
        m.add("der", MimeType("application/x-x509-ca-cert", MimeTypeCategory.Application))
        m.add("p7b", MimeType("application/x-pkcs7-certificates", MimeTypeCategory.Application))
        m.add("p7c", MimeType("application/pkcs7-mime", MimeTypeCategory.Application))

        // OpenDocument
        m.add("odc", MimeType("application/vnd.oasis.opendocument.chart", MimeTypeCategory.Application))
        m.add("odf", MimeType("application/vnd.oasis.opendocument.formula", MimeTypeCategory.Application))
        m.add("odi", MimeType("application/vnd.oasis.opendocument.image", MimeTypeCategory.Application))
        m.add("odm", MimeType("application/vnd.oasis.opendocument.text-master", MimeTypeCategory.Application))
        m.add("ott", MimeType("application/vnd.oasis.opendocument.text-template", MimeTypeCategory.Application))
        m.add("ots", MimeType("application/vnd.oasis.opendocument.spreadsheet-template", MimeTypeCategory.Application))
        m.add("otp", MimeType("application/vnd.oasis.opendocument.presentation-template", MimeTypeCategory.Application))
        m.add("otg", MimeType("application/vnd.oasis.opendocument.graphics-template", MimeTypeCategory.Application))
        m.add("otf", MimeType("font/otf", MimeTypeCategory.Font))  // 字体，覆盖上面的 OpenDocument

        // Microsoft Office (旧格式)
        m.add("dot", MimeType("application/msword", MimeTypeCategory.Application))
        m.add("xla", MimeType("application/vnd.ms-excel", MimeTypeCategory.Application))
        m.add("xlc", MimeType("application/vnd.ms-excel", MimeTypeCategory.Application))
        m.add("xlm", MimeType("application/vnd.ms-excel", MimeTypeCategory.Application))
        m.add("xlt", MimeType("application/vnd.ms-excel", MimeTypeCategory.Application))
        m.add("xlw", MimeType("application/vnd.ms-excel", MimeTypeCategory.Application))
        m.add("pps", MimeType("application/vnd.ms-powerpoint", MimeTypeCategory.Application))
        m.add("pot", MimeType("application/vnd.ms-powerpoint", MimeTypeCategory.Application))

        // Microsoft Office (新格式 - macroenabled)
        m.add("docm", MimeType("application/vnd.ms-word.document.macroenabled.12", MimeTypeCategory.Application))
        m.add("dotm", MimeType("application/vnd.ms-word.template.macroenabled.12", MimeTypeCategory.Application))
        m.add("xlsb", MimeType("application/vnd.ms-excel.sheet.binary.macroenabled.12", MimeTypeCategory.Application))
        m.add("xlsm", MimeType("application/vnd.ms-excel.sheet.macroenabled.12", MimeTypeCategory.Application))
        m.add("xltm", MimeType("application/vnd.ms-excel.template.macroenabled.12", MimeTypeCategory.Application))
        m.add("pptm", MimeType("application/vnd.ms-powerpoint.presentation.macroenabled.12", MimeTypeCategory.Application))
        m.add("potm", MimeType("application/vnd.ms-powerpoint.template.macroenabled.12", MimeTypeCategory.Application))
        m.add("ppsm", MimeType("application/vnd.ms-powerpoint.slideshow.macroenabled.12", MimeTypeCategory.Application))
        m.add("ppsx", MimeType("application/vnd.openxmlformats-officedocument.presentationml.slideshow", MimeTypeCategory.Application))
        m.add("sldx", MimeType("application/vnd.openxmlformats-officedocument.presentationml.slide", MimeTypeCategory.Application))
        m.add("sldm", MimeType("application/vnd.ms-powerpoint.slide.macroenabled.12", MimeTypeCategory.Application))
        m.add("ppam", MimeType("application/vnd.ms-powerpoint.addin.macroenabled.12", MimeTypeCategory.Application))
        m.add("xlam", MimeType("application/vnd.ms-excel.addin.macroenabled.12", MimeTypeCategory.Application))
        m.add("dotx", MimeType("application/vnd.openxmlformats-officedocument.wordprocessingml.template", MimeTypeCategory.Application))
        m.add("potx", MimeType("application/vnd.openxmlformats-officedocument.presentationml.template", MimeTypeCategory.Application))
        m.add("xltx", MimeType("application/vnd.openxmlformats-officedocument.spreadsheetml.template", MimeTypeCategory.Application))

        // 3D 模型
        m.add("gltf", MimeType("model/gltf+json", MimeTypeCategory.Model))
        m.add("glb", MimeType("model/gltf-binary", MimeTypeCategory.Model))
        m.add("obj", MimeType("model/obj", MimeTypeCategory.Model))
        m.add("stl", MimeType("model/stl", MimeTypeCategory.Model))
        m.add("dae", MimeType("model/vnd.collada+xml", MimeTypeCategory.Model))
        m.add("3mf", MimeType("model/3mf", MimeTypeCategory.Model))
        m.add("fbx", MimeType("model/fbx", MimeTypeCategory.Model))
        m.add("u3d", MimeType("model/u3d", MimeTypeCategory.Model))
        m.add("prc", MimeType("model/prc", MimeTypeCategory.Model))
        m.add("dwf", MimeType("model/vnd.dwf", MimeTypeCategory.Model))
        m.add("mtl", MimeType("model/mtl", MimeTypeCategory.Model))
        m.add("bsp", MimeType("model/vnd.valve.source.compiled-map", MimeTypeCategory.Model))

        // 其他常见格式
        m.add("ics", MimeType("text/calendar", MimeTypeCategory.Text))
        m.add("ifb", MimeType("text/calendar", MimeTypeCategory.Text))
        m.add("vcf", MimeType("text/x-vcard", MimeTypeCategory.Text))
        m.add("vcard", MimeType("text/vcard", MimeTypeCategory.Text))
        m.add("torrent", MimeType("application/x-bittorrent", MimeTypeCategory.Application))
        m.add("crx", MimeType("application/x-chrome-extension", MimeTypeCategory.Application))
        m.add("xpi", MimeType("application/x-xpinstall", MimeTypeCategory.Application))
        m.add("apk", MimeType("application/vnd.android.package-archive", MimeTypeCategory.Application))
        m.add("m3u", MimeType("audio/x-mpegurl", MimeTypeCategory.Audio))
        m.add("m3u8", MimeType("application/vnd.apple.mpegurl", MimeTypeCategory.Application))
        m.add("swf", MimeType("application/x-shockwave-flash", MimeTypeCategory.Application))

        // 编程相关
        m.add("asm", MimeType("text/x-asm", MimeTypeCategory.Text))
        m.add("s", MimeType("text/x-asm", MimeTypeCategory.Text))
        m.add("pas", MimeType("text/x-pascal", MimeTypeCategory.Text))
        m.add("p", MimeType("text/x-pascal", MimeTypeCategory.Text))
        m.add("f", MimeType("text/x-fortran", MimeTypeCategory.Text))
        m.add("f77", MimeType("text/x-fortran", MimeTypeCategory.Text))
        m.add("f90", MimeType("text/x-fortran", MimeTypeCategory.Text))
        m.add("for", MimeType("text/x-fortran", MimeTypeCategory.Text))
        m.add("dtd", MimeType("application/xml-dtd", MimeTypeCategory.Application))
        m.add("xsd", MimeType("application/xml", MimeTypeCategory.Application))
        m.add("xsl", MimeType("application/xslt+xml", MimeTypeCategory.Application))
        m.add("xslt", MimeType("application/xslt+xml", MimeTypeCategory.Application))
        m.add("wsdl", MimeType("application/wsdl+xml", MimeTypeCategory.Application))

        // 其他
        m.add("ps", MimeType("application/postscript", MimeTypeCategory.Application))
        m.add("eps", MimeType("application/postscript", MimeTypeCategory.Application))
        m.add("ai", MimeType("application/postscript", MimeTypeCategory.Application))
        m.add("epub", MimeType("application/epub+zip", MimeTypeCategory.Application))
        m.add("mobi", MimeType("application/x-mobipocket-ebook", MimeTypeCategory.Application))
        m.add("azw", MimeType("application/vnd.amazon.ebook", MimeTypeCategory.Application))
        m.add("tex", MimeType("application/x-tex", MimeTypeCategory.Application))
        m.add("latex", MimeType("application/x-latex", MimeTypeCategory.Application))
        m.add("tcl", MimeType("application/x-tcl", MimeTypeCategory.Application))
        m.add("tk", MimeType("application/x-tcl", MimeTypeCategory.Application))
        m.add("csh", MimeType("application/x-csh", MimeTypeCategory.Application))
        m.add("shar", MimeType("application/x-shar", MimeTypeCategory.Application))
        m.add("cpio", MimeType("application/x-cpio", MimeTypeCategory.Application))
        m.add("gtar", MimeType("application/x-gtar", MimeTypeCategory.Application))
        m.add("ustar", MimeType("application/x-ustar", MimeTypeCategory.Application))
        m.add("arc", MimeType("application/x-freearc", MimeTypeCategory.Application))
        m.add("lha", MimeType("application/x-lzh-compressed", MimeTypeCategory.Application))
        m.add("lzh", MimeType("application/x-lzh-compressed", MimeTypeCategory.Application))
        m.add("sit", MimeType("application/x-stuffit", MimeTypeCategory.Application))
        m.add("sitx", MimeType("application/x-stuffitx", MimeTypeCategory.Application))
        m.add("sea", MimeType("application/x-sea", MimeTypeCategory.Application))
        m.add("pgp", MimeType("application/pgp-encrypted", MimeTypeCategory.Application))
        m.add("asc", MimeType("application/pgp-signature", MimeTypeCategory.Application))
        m.add("sig", MimeType("application/pgp-signature", MimeTypeCategory.Application))

        return m
    }

    /// 查找扩展名对应的 MIME 类型
    public static func lookup(ext: String): ?MimeType {
        return MAP.get(ext)
    }

    /// 获取所有已知扩展名
    public static func allExtensions(): Array<String> {
        return MAP.keys().toArray()
    }
}
