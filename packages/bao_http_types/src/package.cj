// bao_http_types - HTTP 类型定义
// 严格翻译自: src/http_types/
//   Bun 的 HTTP 类型系统:
//   - Method.zig: HTTP 方法枚举 (GET/POST/PUT/DELETE 等 36 种)
//   - MimeType.zig: MIME 类型识别与分类
//   - Encoding.zig: 内容编码 (gzip/brotli/zstd/deflate)
//   - ETag.zig: ETag 生成与比较 (RFC 9110)
//   - URLPath.zig: URL 路径解析
//   - FetchCacheMode.zig: Fetch API 缓存模式
//   - FetchRedirect.zig: Fetch API 重定向策略
//   - FetchRequestMode.zig: Fetch API 请求模式
package bao_http_types

import bao_core.*
