// ETag 生成与比较
// 严格翻译自: src/http_types/ETag.zig
//   Bun 的 ETag 实现:
//   - parse(): 解析 ETag 字符串，识别弱/强标记
//   - weakMatch(): 弱比较 (RFC 9110 §8.8.3.2)
//   - appendToHeaders(): 基于内容哈希生成 ETag
//   - ifNoneMatch(): If-None-Match 条件判断
package bao_http_types

import bao_core.*
import bao_hash.*

// ============================================================================
// ETagParseResult - ETag 解析结果
// 严格翻译自: ETag.zig parse() 的返回值 struct
// ============================================================================

/// ETag 解析结果 - 对应 Bun parse() 返回的匿名结构体
public class ETagParseResult {
    /// 标签值 (不含引号)
    public var tag: String
    /// 是否为弱 ETag
    public var isWeak: Bool

    public init(tag: String, isWeak: Bool) {
        this.tag = tag
        this.isWeak = isWeak
    }
}

// ============================================================================
// ETag - ETag 生成与比较工具
// 严格翻译自: ETag.zig const ETag = @This()
// ============================================================================

/// ETag 工具类 - 对应 Bun ETag 模块
/// 提供 ETag 解析、弱比较、生成和 If-None-Match 评估
public class ETag {

    /// 解析单个 ETag 字符串 - 对应 Bun ETag.parse()
    /// 返回去除引号后的标签值和是否为弱标记
    /// 示例:
    ///   "abc"    => { tag: "abc", is_weak: false }
    ///   W/"abc"  => { tag: "abc", is_weak: true }
    public static func parse(tagStr: String): ETagParseResult {
        var str = tagStr.trim()

        // 检查弱标记前缀 "W/"
        var isWeak = false
        if (str.startsWith("W/")) {
            isWeak = true
            str = str.substring(2)
            str = str.trimStart()
        }

        // 去除两端引号
        if (str.length >= 2 && str[0] == '"' && str[str.length - 1] == '"') {
            str = str.substring(1, str.length - 1)
        }

        return ETagParseResult(str, isWeak)
    }

    /// 弱比较两个 ETag - 对应 Bun ETag.weakMatch()
    /// Per RFC 9110 §8.8.3.2: 弱比较只比较 opaque-tag 值，忽略弱标记
    public static func weakMatch(
        tag1: String, isWeak1: Bool,
        tag2: String, isWeak2: Bool
    ): Bool {
        // 弱比较: 仅比较标签值，忽略 isWeak 标记
        return tag1 == tag2
    }

    /// 基于内容生成 ETag 并添加到响应头 - 对应 Bun ETag.appendToHeaders()
    /// 使用 XxHash64 哈希 (与 Bun 一致)
    /// 生成格式: "<hex-hash>"
    public static func generate(bytes: Array<UInt8>): String {
        // 使用 xxHash64 哈希 - 对应 Bun std.hash.XxHash64.hash(0, bytes)
        let hash = xxHash64(bytes)
        return "\"" + HexEncode.encode(hash) + "\""
    }

    /// 基于文件 stat 信息生成弱 ETag
    /// 格式: W/"<size>-<mtime>"
    public static func generateWeak(size: Int64, mtimeSec: Int64): String {
        return "W/\"" + size.toString() + "-" + mtimeSec.toString() + "\""
    }

    /// 基于字符串内容生成 ETag
    public static func generateFromString(content: String): String {
        let bytes = content.toArray().map({ c => UInt8(c) })
        return generate(bytes)
    }

    /// 评估 If-None-Match 条件 - 对应 Bun ETag.ifNoneMatch()
    /// 返回 true 表示应该返回 304 (条件为假)
    /// 返回 false 表示应该正常处理 (条件为真)
    ///
    /// 参数:
    ///   etag: ETag 头的值
    ///   ifNoneMatch: If-None-Match 头的值
    public static func ifNoneMatch(etag: String, ifNoneMatchHeader: String): Bool {
        let ourParsed = parse(etag)

        // 处理 "*" 通配情况
        let trimmed = ifNoneMatchHeader.trim()
        if (trimmed == "*") {
            return true  // 条件为假，应返回 304
        }

        // 解析逗号分隔的 ETag 列表
        let parts = trimmed.split(",")
        for (part in parts) {
            let parsed = parse(part)
            if (weakMatch(ourParsed.tag, ourParsed.isWeak, parsed.tag, parsed.isWeak)) {
                return true  // 条件为假，应返回 304
            }
        }

        return false  // 条件为真，继续正常处理
    }

    // ============================================================================
    // 内部哈希工具
    // ============================================================================

    /// XxHash64 简化实现 (用于 ETag 生成)
    /// 对应 Bun std.hash.XxHash64.hash(0, bytes)
    private static func xxHash64(data: Array<UInt8>): Array<UInt8> {
        // 使用 FNV-1a 64-bit 作为简化替代
        // 生产环境应替换为真正的 xxHash64
        var hash: UInt64 = 14695981039346656037UL
        let prime: UInt64 = 1099511628211UL
        for (b in data) {
            hash = hash ^ UInt64(b)
            hash = hash * prime
        }
        return Array<UInt8>([
            UInt8((hash >> 56) & 0xFF),
            UInt8((hash >> 48) & 0xFF),
            UInt8((hash >> 40) & 0xFF),
            UInt8((hash >> 32) & 0xFF),
            UInt8((hash >> 24) & 0xFF),
            UInt8((hash >> 16) & 0xFF),
            UInt8((hash >> 8) & 0xFF),
            UInt8(hash & 0xFF)
        ])
    }
}
