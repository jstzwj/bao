// URL 路径解析
// 严格翻译自: src/http_types/URLPath.zig
//   Bun 的 URL 路径解析:
//   - URLPath 结构体: path/pathname/extname/first_segment/query_string 等
//   - parse(): 从 URL 路径字符串解析各字段
//   - isRoot(): 判断是否为根路径
//   - pathWithoutAssetPrefix(): 去除资源前缀路径
// 注意: Bun 使用 PercentEncoding.decodeFaultTolerant 进行 URL 解码
//       此处提供简化实现
package bao_http_types

import bao_core.*

// ============================================================================
// URLPath - URL 路径结构体
// 严格翻译自: URLPath.zig const URLPath = @This()
// ============================================================================

/// URL 路径解析结果 - 对应 Bun URLPath
/// 包含从 URL 路径中解析出的各个组成部分
public class URLPath {
    /// 文件扩展名 (不含点号)
    public var extname: String
    /// 路径 (不含前导斜杠和查询字符串)
    public var path: String
    /// 完整路径名
    public var pathname: String
    /// 第一个路径段
    public var firstSegment: String
    /// 查询字符串 (含问号)
    public var queryString: String
    /// 是否需要重定向 (URL 编码差异导致)
    public var needsRedirect: Bool
    /// 是否为 source map URL
    public var isSourceMap: Bool

    public init() {
        extname = ""
        path = ""
        pathname = ""
        firstSegment = ""
        queryString = ""
        needsRedirect = false
        isSourceMap = false
    }

    /// 判断是否为根路径 - 对应 Bun URLPath.isRoot()
    /// 根路径: "." 或 "index"
    public func isRoot(assetPrefix: String): Bool {
        let without = pathWithoutAssetPrefix(assetPrefix)
        if (without.length == 1 && without[0] == '.') {
            return true
        }
        return without == "index"
    }

    /// 获取去除资源前缀后的路径 - 对应 Bun URLPath.pathWithoutAssetPrefix()
    /// 用于处理 /_next/ 等框架前缀
    public func pathWithoutAssetPrefix(assetPrefix: String): String {
        if (assetPrefix.length == 0) {
            return path
        }

        let leadingSlashOffset = if (assetPrefix[0] == '/') { 1 } else { 0 }
        let base = path
        let origin = assetPrefix.substring(leadingSlashOffset)

        let out = if (base.length >= origin.length && base.substring(0, origin.length) == origin) {
            base.substring(origin.length)
        } else {
            base
        }

        if (isSourceMap && out.endsWith(".map")) {
            return out.substring(0, out.length - 4)
        }

        return out
    }
}

// ============================================================================
// URLPathParser - URL 路径解析器
// 严格翻译自: URLPath.zig parse()
// ============================================================================

/// URL 路径解析器 - 对应 Bun URLPath.parse()
/// 从原始 URL 路径字符串解析出 URLPath 结构体
public class URLPathParser {

    /// 解析 URL 路径 - 对应 Bun URLPath.parse()
    ///
    /// 解析流程:
    /// 1. URL 百分号解码
    /// 2. 从后向前扫描，识别 ? (查询字符串)、. (扩展名)、/ (路径分隔)
    /// 3. 提取 extname、path、firstSegment、queryString
    /// 4. 处理 .map (source map) 特殊情况
    public static func parse(possiblyEncodedPathname: String): URLPath {
        var decodedPathname = possiblyEncodedPathname
        var needsRedirect = false

        // URL 百分号解码 - 对应 Bun PercentEncoding.decodeFaultTolerant
        if (decodedPathname.contains("%")) {
            decodedPathname = percentDecode(decodedPathname)
            if (decodedPathname != possiblyEncodedPathname) {
                needsRedirect = true
            }
        }

        var questionMarkI = -1
        var periodI = -1
        var firstSegmentEnd = Int64.MAX_VALUE
        var lastSlash = -1

        // 从后向前扫描 - 对应 Bun 从 i = len-1 到 0 的循环
        var i = decodedPathname.length - 1
        while (i >= 0) {
            let c = decodedPathname[i]

            if (c == '?') {
                if (questionMarkI < i) {
                    questionMarkI = i
                }
                if (questionMarkI < periodI) {
                    periodI = -1
                }
                if (lastSlash > questionMarkI) {
                    lastSlash = -1
                }
            } else if (c == '.') {
                if (periodI < i) {
                    periodI = i
                }
            } else if (c == '/') {
                if (lastSlash < i) {
                    lastSlash = i
                }
                if (i > 0) {
                    if (firstSegmentEnd > i) {
                        firstSegmentEnd = i
                    }
                }
            }
            i = i - 1
        }

        if (lastSlash > periodI) {
            periodI = -1
        }

        // 提取扩展名 - 对应 Bun extname brk 块
        let extname: String
        if (questionMarkI > -1 && periodI > -1) {
            periodI = periodI + 1
            extname = decodedPathname.substring(periodI, questionMarkI)
        } else if (periodI > -1) {
            periodI = periodI + 1
            extname = decodedPathname.substring(periodI)
        } else {
            extname = ""
        }

        // 提取 path (跳过前导 '/')
        let pathStr: String
        if (questionMarkI < 0) {
            pathStr = if (decodedPathname.length > 1) {
                decodedPathname.substring(1)
            } else {
                "."
            }
        } else {
            pathStr = if (questionMarkI > 1) {
                decodedPathname.substring(1, questionMarkI)
            } else {
                "."
            }
        }

        // 提取第一个路径段
        let segEnd = if (Int64(firstSegmentEnd) < Int64(decodedPathname.length)) {
            firstSegmentEnd
        } else {
            Int64(decodedPathname.length)
        }
        let firstSegment = if (decodedPathname.length > 1 && segEnd > 1) {
            decodedPathname.substring(1, Int64(segEnd))
        } else {
            ""
        }

        // 处理 source map 特殊情况 (.js.map)
        let isSourceMap = (extname == "map")
        var backupExtname = extname
        var finalPath = pathStr

        if (isSourceMap && finalPath.length > 4) {
            // 查找 .map 前的扩展名
            let pathWithoutMap = finalPath.substring(0, finalPath.length - 4)
            let lastDot = pathWithoutMap.lastIndexOf(".")
            if (lastDot >= 0) {
                backupExtname = pathWithoutMap.substring(lastDot + 1)
                finalPath = finalPath.substring(0, lastDot + backupExtname.length + 1)
            }
        }

        // 构建结果
        let result = URLPath()
        result.extname = if (!isSourceMap) { extname } else { backupExtname }
        result.isSourceMap = isSourceMap
        result.pathname = decodedPathname
        result.firstSegment = firstSegment
        result.path = if (decodedPathname.length == 1) { "." } else { finalPath }
        result.queryString = if (questionMarkI > -1) {
            decodedPathname.substring(questionMarkI)
        } else {
            ""
        }
        result.needsRedirect = needsRedirect

        return result
    }

    // ============================================================================
    // 百分号解码 - 对应 Bun PercentEncoding.decodeFaultTolerant
    // ============================================================================

    /// URL 百分号解码 - 简化实现
    /// Bun 使用专门的 PercentEncoding 模块，此处为内联简化版
    private static func percentDecode(input: String): String {
        let sb = StringBuilder()
        var i = 0
        let chars = input.toArray()
        while (i < chars.length) {
            if (chars[i] == Char('%') && i + 2 < chars.length) {
                let hex1 = hexValue(chars[i + 1])
                let hex2 = hexValue(chars[i + 2])
                if (hex1 >= 0 && hex2 >= 0) {
                    sb.append(Char((hex1 << 4) | hex2))
                    i = i + 3
                    continue
                }
            }
            sb.append(chars[i])
            i = i + 1
        }
        return sb.toString()
    }

    /// 十六进制字符转数值
    private static func hexValue(c: Char): Int32 {
        if (c >= Char('0') && c <= Char('9')) {
            return Int32(c) - Int32(Char('0'))
        }
        if (c >= Char('a') && c <= Char('f')) {
            return Int32(c) - Int32(Char('a')) + 10
        }
        if (c >= Char('A') && c <= Char('F')) {
            return Int32(c) - Int32(Char('A')) + 10
        }
        return -1
    }
}
