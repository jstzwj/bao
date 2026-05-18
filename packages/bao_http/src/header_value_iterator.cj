// bao_http header_value_iterator - HTTP 头部值迭代器
// 严格翻译自: src/http/HeaderValueIterator.rs (44 行)
package bao_http

import bao_core.*
import bao_collections.*

// ============================================================================
// HeaderValueIterator - HTTP 头部值迭代器
// 严格翻译自: bun/src/http/HeaderValueIterator.rs
//
// Rust HeaderValueIterator:
//   pub struct HeaderValueIterator<'a> {
//       remaining: &'a [u8],
//   }
//   impl<'a> HeaderValueIterator<'a> {
//       pub fn init(input: &'a [u8]) -> HeaderValueIterator<'a>
//       pub fn next(&mut self) -> Option<&'a [u8]>
//   }
//
// 使用逗号分割头部值 (例如 "gzip, deflate, br"),
// 跳过空白和前导逗号, 每次返回一个 token。
// 对应 RFC 7230 的 header field value 列表语义。
// ============================================================================

/// HTTP 头部值迭代器 — 按逗号分割头部值
/// 严格翻译自: HeaderValueIterator.rs HeaderValueIterator<'a>
public class HeaderValueIterator {
    /// 剩余未处理的输入
    /// 严格翻译自: remaining: &'a [u8]
    private var remaining: String

    public init(input: String) {
        // 严格翻译自:
        //   remaining: strings::trim(input, b" \t")
        this.remaining = trimWhitespace(input)
    }

    // ========================================================================
    // next - 获取下一个 token
    // 严格翻译自:
    //   pub fn next(&mut self) -> Option<&'a [u8]> {
    //       // 跳过前导逗号
    //       while let Some((&b',', rest)) = self.remaining.split_first() {
    //           self.remaining = rest;
    //       }
    //       if self.remaining.is_empty() { return None; }
    //       // 找到下一个逗号
    //       let end = self.remaining.iter().position(|&b| b == b',')
    //           .unwrap_or(self.remaining.len());
    //       let token = &self.remaining[..end];
    //       self.remaining = &self.remaining[end..];
    //       let slice = strings::trim(token, b" \t");
    //       if slice.is_empty() { return self.next(); }
    //       Some(slice)
    //   }
    // ========================================================================

    /// 获取下一个 token
    /// 严格翻译自: HeaderValueIterator.next
    public func next(): ?String {
        // 跳过前导逗号
        while (remaining.size > 0 && remaining[0] == UInt8(44)) {  // ','
            remaining = if (remaining.size > 1) { remaining[1..] } else { "" }
        }

        if (remaining.size == 0) {
            return None
        }

        // 找到下一个逗号的位置
        var end: Int64 = -1
        for (i in 0..remaining.size) {
            if (remaining[i] == UInt8(44)) {  // ','
                end = i
                break
            }
        }
        if (end < 0) {
            end = remaining.size
        }

        let token = remaining[0..end]
        remaining = if (end < remaining.size) { remaining[end..] } else { "" }

        let slice = trimWhitespace(token)
        if (slice.size == 0) {
            return next()
        }

        return Some(slice)
    }

    /// 收集所有 token
    public func collect(): ArrayList<String> {
        let result = ArrayList<String>()
        var token = next()
        while (token.isSome()) {
            result.append(token.getOrThrow())
            token = next()
        }
        return result
    }

    /// 是否还有更多 token
    public func hasNext(): Bool {
        return remaining.size > 0
    }
}

/// 去除首尾空白字符 (空格和制表符)
/// 严格翻译自: strings::trim(input, b" \t")
private func trimWhitespace(s: String): String {
    var start: Int64 = 0
    var end = s.size
    while (start < end && isWhitespace(s[start])) {
        start += 1
    }
    while (end > start && isWhitespace(s[end - 1])) {
        end -= 1
    }
    return s[start..end]
}

private func isWhitespace(c: UInt8): Bool {
    return c == UInt8(32) || c == UInt8(9)  // 空格或制表符
}
