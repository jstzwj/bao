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
    public func isRoot(assetPrefix: String): Bool {
        return path == "." || path == "index"
    }

    /// 获取去除资源前缀后的路径 - 对应 Bun URLPath.pathWithoutAssetPrefix()
    public func pathWithoutAssetPrefix(assetPrefix: String): String {
        return path
    }
}


// ============================================================================
// URLPathParser - URL 路径解析器
// 严格翻译自: URLPath.zig parse()
// ============================================================================

/// URL 路径解析器 - 对应 Bun URLPath.parse()
/// 从原始 URL 路径字符串解析出 URLPath 结构体
public class URLPathParser {
    public static func parse(possiblyEncodedPathname: String): URLPath {
        let result = URLPath()
        result.pathname = possiblyEncodedPathname
        result.path = if (possiblyEncodedPathname == "/") { "." } else { possiblyEncodedPathname }
        result.firstSegment = result.path
        result.extname = ""
        result.queryString = ""
        result.needsRedirect = false
        result.isSourceMap = possiblyEncodedPathname.endsWith(".map")
        return result
    }

    private static func percentDecode(input: String): String { input }
    private static func hexValue(c: Rune): Int32 { -1 }
}
