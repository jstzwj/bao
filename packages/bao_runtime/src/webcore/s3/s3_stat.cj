// S3Stat - S3 对象元数据
// 严格翻译自: src/runtime/webcore/S3Stat.rs
//   Bun 的 S3Stat 模块:
//   - S3Stat: JS 类, 封装 S3 对象的 size/etag/contentType/lastModified
//   - constructor: 禁止直接构造 (throw IllegalConstructor)
//   - init(): 从 S3 响应头构建实例
//   - getter: getSize/getEtag/getContentType/getLastModified
//   - finalize(): 释放 String 引用
//   仓颉: 提供兼容的 S3 对象元数据接口
package bao_runtime.webcore.s3

import bao_core.*
import bao_jsc.*

// ============================================================================
// S3Stat - S3 对象元数据
// 严格翻译自: src/runtime/webcore/S3Stat.rs
//   #[bun_jsc::JsClass]
//   pub struct S3Stat {
//       pub size: u64,
//       pub etag: BunString,
//       pub content_type: BunString,
//       pub last_modified: f64,
//   }
// ============================================================================

/// S3Stat — S3 对象元数据
/// 对应 Bun: S3Stat struct
///
/// 封装 S3 对象的 size/etag/contentType/lastModified。
/// 不可直接构造 — 只能通过 S3Client.stat() 或内部 init() 创建。
public class S3Stat {
    /// 对象大小 (字节)
    /// 对应 Bun: pub size: u64
    public var size: UInt64

    /// ETag
    /// 对应 Bun: pub etag: BunString
    public var etag: BaoString

    /// Content-Type
    /// 对应 Bun: pub content_type: BunString
    public var contentType: BaoString

    /// 最后修改时间 (JS Date number: days since epoch)
    /// 对应 Bun: pub last_modified: f64
    public var lastModified: Float64

    public init() {
        size = 0
        etag = BaoString()
        contentType = BaoString()
        lastModified = 0.0
    }

    public init(size: UInt64, etag: BaoString, contentType: BaoString, lastModified: Float64) {
        this.size = size
        this.etag = etag
        this.contentType = contentType
        this.lastModified = lastModified
    }

    // ========================================================================
    // JS 构造函数 (禁止)
    // 严格翻译自: S3Stat::constructor
    //   pub fn constructor(global, _frame) -> JsResult<Box<Self>> {
    //       Err(global.throw_illegal_constructor("S3Stat"))
    //   }
    // ========================================================================

    /// JS 构造函数 — 禁止直接构造
    /// 对应 Bun: throwIllegalConstructor("S3Stat is not constructable")
    public static func constructor(global: JSGlobalObject, frame: CallFrame): Result<S3Stat> {
        return Result<S3Stat>.Err(
            BaoError(ErrorCode.IllegalConstructor, "S3Stat is not constructable")
        )
    }

    // ========================================================================
    // 工厂方法
    // 严格翻译自: S3Stat::init
    //   pub fn init(size, etag, content_type, last_modified, global) -> JsResult<Box<Self>>
    // ========================================================================

    /// 从 S3 响应头数据构建 S3Stat
    /// 对应 Bun: pub fn init(
    ///     size: u64,
    ///     etag: &[u8],
    ///     content_type: &[u8],
    ///     last_modified: &[u8],
    ///     global: &JSGlobalObject,
    /// ) -> JsResult<Box<Self>>
    ///
    /// 步骤:
    ///   1. 解析 last_modified 字符串为日期 (JS Date number)
    ///   2. clone_utf8 etag 和 content_type
    ///   3. 构建 S3Stat 实例
    public static func init(
        size: UInt64,
        etag: Array<UInt8>,
        contentType: Array<UInt8>,
        lastModified: Array<UInt8>,
        global: JSGlobalObject
    ): Result<S3Stat> {
        // 解析日期字符串
        let dateStr = BaoString.fromBytes(lastModified)
        let parsedDate = dateStr.parseDate(global)
        match (parsedDate) {
            case Ok(lastMod) => {
                let stat = S3Stat(
                    size: size,
                    etag: BaoString.cloneUtf8(etag),
                    contentType: BaoString.cloneUtf8(contentType),
                    lastModified: lastMod
                )
                return Result<S3Stat>.Ok(stat)
            }
            case Err(e) => return Result<S3Stat>.Err(e)
        }
    }

    // ========================================================================
    // JS Getter 方法
    // 严格翻译自: S3Stat 的 host_fn(getter) 方法
    // ========================================================================

    /// 获取对象大小
    /// 对应 Bun: pub fn get_size(&self, _global) -> JSValue
    ///   JSValue::js_number(self.size as f64)
    public func getSize(global: JSGlobalObject): JSValue {
        return JSValue.jsNumber(Float64(size))
    }

    /// 获取 ETag
    /// 对应 Bun: pub fn get_etag(&self, global) -> JsResult<JSValue>
    ///   self.etag.to_js(global)
    public func getEtag(global: JSGlobalObject): Result<JSValue> {
        return etag.toJs(global)
    }

    /// 获取 Content-Type
    /// 对应 Bun: pub fn get_content_type(&self, global) -> JsResult<JSValue>
    ///   self.content_type.to_js(global)
    public func getContentType(global: JSGlobalObject): Result<JSValue> {
        return contentType.toJs(global)
    }

    /// 获取最后修改时间
    /// 对应 Bun: pub fn get_last_modified(&self, global) -> JSValue
    ///   JSValue::from_date_number(global, self.last_modified)
    public func getLastModified(global: JSGlobalObject): JSValue {
        return JSValue.fromDateNumber(global, lastModified)
    }

    // ========================================================================
    // finalize — 释放资源
    // 严格翻译自: S3Stat::finalize
    //   pub fn finalize(self: Box<Self>) {
    //       self.etag.deref();
    //       self.content_type.deref();
    //   }
    // ========================================================================

    /// 释放资源
    /// 对应 Bun: pub fn finalize(self: Box<Self>)
    ///   BunString is Copy with NO Drop impl, so the +1 refs taken by
    ///   clone_utf8 in init must be released explicitly.
    public func finalize(): Unit {
        etag.deref()
        contentType.deref()
    }
}
