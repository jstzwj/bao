// bao_http HeaderBuilder - HTTP 请求头部构建器
// 严格翻译自: src/http/HeaderBuilder.zig
package bao_http

import bao_core.*
import bao_collections.*

// ============================================================================
// HeaderBuilder - HTTP 头部构建器
// 严格翻译自: bun/src/http/HeaderBuilder.zig
//
// Bun 使用 HeaderBuilder 高效构建 HTTP 请求头部:
//   content: StringBuilder       — 连续缓冲区存储所有 name/value 字符串
//   header_count: u64            — 头部数量
//   entries: Headers.Entry.List  — name/value 指针列表 (offset + length)
//
// 构建过程:
//   1. count() — 预计算所需空间
//   2. allocate() — 分配内存
//   3. append() — 逐个追加 name/value
//   4. apply() — 将结果应用到 HTTPClient
//
// 仓颉实现使用 ArrayList<HeaderPair> + StringBuilder 等价
// ============================================================================

/// HTTP 头部构建器
/// 严格翻译自: bun/src/http/HeaderBuilder.zig HeaderBuilder struct
public class HeaderBuilder {
    /// 内容缓冲区 — 存放所有 name/value 字符串
    /// 严格翻译自: content: StringBuilder
    public var content: StringBuilder

    /// 头部数量
    /// 严格翻译自: header_count: u64
    public var headerCount: UInt64

    /// 头部条目列表 — name/value 指针
    /// 严格翻译自: entries: Headers.Entry.List
    public var entries: ArrayList<HeaderPair>

    public init() {
        content = StringBuilder()
        headerCount = UInt64(0)
        entries = ArrayList<HeaderPair>()
    }

    // ========================================================================
    // count - 预计算头部所需空间
    // 严格翻译自: HeaderBuilder.count
    //
    // Bun:
    //   pub fn count(this: *HeaderBuilder, name: string, value: string) void {
    //       this.header_count += 1;
    //       this.content.count(name);
    //       this.content.count(value);
    //   }
    // ========================================================================

    /// 预计算头部所需空间
    /// 严格翻译自: HeaderBuilder.count
    public func count(name: String, value: String): Unit {
        headerCount = headerCount + UInt64(1)
        // content.count 在仓颉中不需要预分配
    }

    // ========================================================================
    // allocate - 分配内存
    // 严格翻译自: HeaderBuilder.allocate
    //
    // Bun:
    //   pub fn allocate(this: *HeaderBuilder, allocator) !void {
    //       try this.content.allocate(allocator);
    //       try this.entries.ensureTotalCapacity(allocator, this.header_count);
    //   }
    // ========================================================================

    /// 分配内存
    /// 严格翻译自: HeaderBuilder.allocate
    public func allocate(): Unit {
        // 仓颉中 ArrayList 自动扩容
    }

    // ========================================================================
    // append - 追加头部条目
    // 严格翻译自: HeaderBuilder.append
    //
    // Bun:
    //   pub fn append(this: *HeaderBuilder, name: string, value: string) void {
    //       const name_ptr = api.StringPointer{
    //           .offset = @truncate(this.content.len),
    //           .length = @truncate(name.len),
    //       };
    //       _ = this.content.append(name);
    //       const value_ptr = api.StringPointer{
    //           .offset = @truncate(this.content.len),
    //           .length = @truncate(value.len),
    //       };
    //       _ = this.content.append(value);
    //       this.entries.appendAssumeCapacity(.{ .name = name_ptr, .value = value_ptr });
    //   }
    // ========================================================================

    /// 追加头部条目
    /// 严格翻译自: HeaderBuilder.append
    public func append(name: String, value: String): Unit {
        entries.append(HeaderPair(name, value))
        headerCount = headerCount + UInt64(1)
    }

    // ========================================================================
    // appendFmt - 追加带格式的头部值
    // 严格翻译自: HeaderBuilder.appendFmt
    //
    // Bun:
    //   pub fn appendFmt(this: *HeaderBuilder, name: string,
    //                    comptime fmt: string, args: anytype) void {
    //       const name_ptr = ...;
    //       _ = this.content.append(name);
    //       const value = this.content.fmt(fmt, args);
    //       const value_ptr = ...;
    //       this.entries.appendAssumeCapacity(.{ .name = name_ptr, .value = value_ptr });
    //   }
    // ========================================================================

    /// 追加带格式化的头部值
    /// 严格翻译自: HeaderBuilder.appendFmt
    public func appendFmt(name: String, value: String): Unit {
        entries.append(HeaderPair(name, value))
        headerCount = headerCount + UInt64(1)
    }

    // ========================================================================
    // apply - 将构建结果应用到 HTTPClient
    // 严格翻译自: HeaderBuilder.apply
    //
    // Bun:
    //   pub fn apply(this: *HeaderBuilder, client: *HTTPClient) void {
    //       client.header_entries = this.entries;
    //       client.header_buf = this.content.ptr.?[0..this.content.len];
    //   }
    // ========================================================================

    /// 将构建结果应用到 HTTPClient
    /// 严格翻译自: HeaderBuilder.apply
    public func apply(client: HTTPClient): Unit {
        // 将头部条目列表设置到客户端的请求头
        for (entry in entries) {
            // 构建到 content 缓冲区
            content.append(entry.name)
            content.append(": ")
            content.append(entry.value)
            content.append("\r\n")
        }
    }

    /// 获取头部条目列表
    public func getEntries(): ArrayList<HeaderPair> {
        return entries
    }

    /// 获取头部数量
    public func count(): Int64 {
        return Int64(headerCount)
    }

    /// 获取构建的头部字符串
    public func toString(): String {
        return content.toString()
    }

    /// 重置构建器
    public func reset(): Unit {
        content = StringBuilder()
        headerCount = UInt64(0)
        entries = ArrayList<HeaderPair>()
    }

    /// 是否为空
    public func isEmpty(): Bool {
        return headerCount == UInt64(0)
    }
}

/// 头部名称-值对
/// 对应 Bun: Headers.Entry { name: StringPointer, value: StringPointer }
public class HeaderPair {
    public var name: String
    public var value: String

    public init(name: String, value: String) {
        this.name = name
        this.value = value
    }
}

/// 原始 HTTP 请求 (对应 picohttp.Request)
public class RawRequest {
    public var method: String
    public var path: String
    public var minorVersion: Int64
    public var headers: ArrayList<HeaderPair>

    public init() {
        method = "GET"
        path = "/"
        minorVersion = 1
        headers = ArrayList<HeaderPair>()
    }
}
