// bao_url_jsc - JSC 绑定层: JSValue <-> URL 转换
// 严格翻译自: src/url_jsc/lib.rs, src/url_jsc/url_jsc.zig
//   Bun 中此 crate 负责 JavaScriptCore (JSC) 和 URL 解析器之间的桥接
//   核心功能: urlFromJS - 从 JS 值提取 href 字符串并解析为 URL
//
// 在仓颉版本中:
//   - JSValue 对应仓颉的 JS 运行时值类型
//   - JSGlobalObject 对应仓颉的 JS 全局上下文
//   - URL 解析委托给 bao_url 包
//   - 此包仅负责 JS <-> Native 类型转换
package bao_url_jsc

import bao_url.*
import bao_core.*

// ============================================================================
// JSCValue - JS 运行时值的简化表示
// 对应 Bun: jsc.JSValue (Rust) / jsc.JSValue (Zig)
// 在仓颉中，这代表从 JS 引擎传递过来的值的抽象
// ============================================================================

/// JS 值的简化表示
/// 对应 Bun: jsc.JSValue - Zig 中是 extern struct { asInt: i64 }
/// 用于类型安全的 JS <-> Native 转换
public class JSCValue {
    /// 值的内部表示
    private var value: ?String
    /// 标签 (用于区分类型)
    private var tag: JSCValueTag

    public init() {
        this.value = None
        this.tag = JSCValueTag.Dead
    }

    public init(str: String) {
        this.value = str
        this.tag = JSCValueTag.String
    }

    /// 从 JS 值获取字符串
    public func asString(): ?String {
        return value
    }

    /// 是否为 Dead 标签 (无效值)
    /// 对应 Zig: href.tag == .Dead
    public func isDead(): Bool {
        return tag == JSCValueTag.Dead
    }

    /// 获取标签
    public func getTag(): JSCValueTag {
        return tag
    }
}

/// JS 值标签
/// 对应 Bun: jsc.Tag (Zig: pub const Tag = enum { Dead, ... })
public enum JSCValueTag {
    | Dead       // 无效值
    | String     // 字符串值
    | Object     // 对象值
    | Number     // 数字值
    | Boolean    // 布尔值
    | Null       // null
    | Undefined  // undefined
}

// ============================================================================
// JSGlobalContext - JS 全局上下文的简化表示
// 对应 Bun: *jsc.JSGlobalObject (Rust) / *jsc.JSGlobalObject (Zig)
// ============================================================================

/// JS 全局上下文
/// 对应 Bun: jsc.JSGlobalObject - 在仓颉中简化为上下文 ID
public class JSGlobalContext {
    /// 上下文标识
    private var contextId: Int64

    public init(contextId: Int64) {
        this.contextId = contextId
    }

    public func getId(): Int64 {
        return contextId
    }
}

// ============================================================================
// URLJsc - JS <-> URL 转换桥接
// 严格翻译自: src/url_jsc/lib.rs + src/url_jsc/url_jsc.zig
//   Zig 版本:
//     pub fn urlFromJS(js_value: jsc.JSValue, globalObject: *jsc.JSGlobalObject, allocator: std.mem.Allocator) !URL {
//         var href = jsc.URL.hrefFromJS(globalObject, js_value);
//         if (href.tag == .Dead) return error.InvalidURL;
//         return URL.parse(try href.toOwnedSlice(allocator));
//     }
//   Rust 版本:
//     pub fn url_from_js(js_value: JSValue, global: &JSGlobalObject) -> Result<OwnedURL, bun_core::Error>
// ============================================================================

/// URL JSC 桥接工具
/// 对应 Bun: url_jsc::url_from_js
/// 从 JS 值中提取 href 字符串并解析为 URL
public class URLJsc {

    /// 从 JS 值解析 URL
    /// 对应 Bun (Zig): urlFromJS(js_value, globalObject, allocator) !URL
    /// 对应 Bun (Rust): url_from_js(js_value, global) -> Result<OwnedURL, Error>
    ///
    /// 步骤:
    ///   1. 从 JS 值获取 href 字符串 (通过 JSC URL.hrefFromJS)
    ///   2. 检查是否为 Dead 标签 (无效 URL)
    ///   3. 解析 href 字符串为 URL
    ///
    /// 在仓颉中，JS 值的 href 提取通过 JS 运行时的 FFI 调用实现
    public static func urlFromJS(
        jsValue: JSCValue,
        global: JSGlobalContext
    ): ?URL {
        // 步骤 1: 从 JS 值获取 href
        // 对应 Zig: var href = jsc.URL.hrefFromJS(globalObject, js_value);
        let href = hrefFromJS(jsValue, global)

        // 步骤 2: 检查 Dead 标签
        // 对应 Zig: if (href.tag == .Dead) return error.InvalidURL;
        if (href == None || href.getOrThrow().isEmpty()) {
            return None
        }

        // 步骤 3: 解析 href 为 URL
        // 对应 Zig: return URL.parse(try href.toOwnedSlice(allocator));
        return URL.parse(href.getOrThrow())
    }

    /// 从 JS 值中提取 href 字符串
    /// 对应 Bun (Zig): jsc.URL.hrefFromJS(globalObject, js_value)
    /// 在 Bun 中，这调用 JSC 内置的 URL 构造器获取 href 属性
    /// 如果 JS 值已经是字符串，直接返回
    /// 如果 JS 值是 URL 对象，读取其 href 属性
    ///
    /// 在仓颉中:
    ///   - 如果 jsValue 是字符串，直接返回
    ///   - 如果是 JS URL 对象，需要通过 JS 运行时 FFI 读取 href
    private static func hrefFromJS(
        jsValue: JSCValue,
        global: JSGlobalContext
    ): ?String {
        // 检查 Dead 标签
        if (jsValue.isDead()) {
            return None
        }

        // 如果值本身就是字符串，直接作为 href
        let str = jsValue.asString()
        if (str != None) {
            return str
        }

        // 否则: 在完整实现中，需要通过 JS 运行时 FFI:
        // 1. 获取 jsValue 的 "href" 属性
        // 2. 将属性值转为字符串
        // 对应 Zig: jsc.URL.hrefFromJS 调用 JSC::JSValue::toZigString
        return None
    }

    /// 从 JS 值解析 URL (返回 OwnedURL)
    /// 对应 Bun (Rust): url_from_js -> Result<OwnedURL, Error>
    /// OwnedURL 是拥有 href 字符串所有权的 URL
    public static func ownedUrlFromJS(
        jsValue: JSCValue,
        global: JSGlobalContext
    ): ?OwnedURL {
        let url = urlFromJS(jsValue, global)
        if (url == None) {
            return None
        }
        return OwnedURL(url.getOrThrow())
    }
}

// ============================================================================
// OwnedURL - 拥有字符串所有权的 URL
// 对应 Bun (Rust): bun_url::OwnedURL
//   Zig 版本的 URL 借用调用者提供的缓冲区
//   Rust 版本使用 OwnedURL 拥有 href 字符串，通过 Drop 释放
//   仓颉版本使用 String 值类型 (自动管理内存)
// ============================================================================

/// 拥有字符串所有权的 URL
/// 对应 Bun: bun_url::OwnedURL
/// 仓颉中 String 为不可变值类型，自动内存管理
public class OwnedURL {
    /// 底层 URL
    public var url: URL
    /// 拥有的 href 字符串
    public var ownedHref: String

    public init(href: String) {
        this.ownedHref = href
        this.url = URL.parse(href)
    }

    /// 获取 URL 引用
    public func getUrl(): URL {
        return url
    }

    /// 获取 href
    public func getHref(): String {
        return ownedHref
    }

    /// 从已有的 URL 创建 OwnedURL
    public static func fromHref(href: String): OwnedURL {
        return OwnedURL(href)
    }
}
