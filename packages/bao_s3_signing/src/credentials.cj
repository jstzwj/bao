// 严格翻译自: src/s3_signing/credentials.zig
//   Bun 的 S3 凭证管理和 AWS Signature V4 签名:
//   - S3Credentials: 凭证结构体 (引用计数)
//   - DateResult / getAMZDate(): AWS 日期格式 (YYYYMMDDTHHmmssZ)
//   - SignResult: 签名结果 (headers, authorization, URL)
//   - SignOptions / SignQueryOptions: 签名选项
//   - signRequest(): AWS Signature V4 完整签名流程
//   - encodeURIComponent(): URI 编码
//   - guessBucket() / guessRegion(): 端点推断
//   - S3CredentialsWithOptions: 带选项的凭证
//   - SignedHeaders: 编译期签名头查找表
//   - CanonicalRequest: 规范请求构建
package bao_s3_signing

import bao_core.*
import bao_hash.sha.*
import bao_hash.hmac.*

// ============================================================================
// S3Credentials - S3 凭证
// 严格翻译自: credentials.zig pub const S3Credentials = struct {
//   const RefCount = bun.ptr.RefCount(@This(), "ref_count", deinit, .{});
//   pub const ref = RefCount.ref;
//   pub const deref = RefCount.deref;
//   ref_count: RefCount,
//   accessKeyId: []const u8,
//   secretAccessKey: []const u8,
//   region: []const u8,
//   endpoint: []const u8,
//   bucket: []const u8,
//   sessionToken: []const u8,
//   storage_class: ?StorageClass = null,
//   insecure_http: bool = false,
//   virtual_hosted_style: bool = false,
// };
// ============================================================================

/// S3 凭证
/// 对应 Bun: S3Credentials = struct { ref_count, accessKeyId, ... }
/// AWS S3 访问凭证, 包含所有签名所需的信息
public class S3Credentials {
    /// 引用计数
    /// 对应 Bun: ref_count: RefCount
    ///   const RefCount = bun.ptr.RefCount(@This(), "ref_count", deinit, .{});
    ///   pub const ref = RefCount.ref;
    ///   pub const deref = RefCount.deref;
    private var refCount: Int32

    /// AWS Access Key ID
    /// 对应 Bun: accessKeyId: []const u8
    public var accessKeyId: String
    /// AWS Secret Access Key
    /// 对应 Bun: secretAccessKey: []const u8
    public var secretAccessKey: String
    /// AWS 区域
    /// 对应 Bun: region: []const u8
    public var region: String
    /// S3 端点 (如 s3.amazonaws.com)
    /// 对应 Bun: endpoint: []const u8
    public var endpoint: String
    /// S3 存储桶名
    /// 对应 Bun: bucket: []const u8
    public var bucket: String
    /// AWS Session Token (可选, 用于临时凭证)
    /// 对应 Bun: sessionToken: []const u8
    public var sessionToken: String
    /// 存储类别 (可选)
    /// 对应 Bun: storage_class: ?StorageClass = null
    public var storageClass: ?StorageClass
    /// 是否使用 HTTP (而非 HTTPS)
    /// 对应 Bun: insecure_http: bool = false
    /// 重要: 用于 MinIO 支持
    public var insecureHttp: Bool
    /// 是否使用虚拟主机风格
    /// 对应 Bun: virtual_hosted_style: bool = false
    /// 指示端点是否使用虚拟主机风格存储桶
    public var virtualHostedStyle: Bool

    public init(accessKeyId: String, secretAccessKey: String, region: String,
                endpoint: String, bucket: String) {
        this.refCount = 1
        this.accessKeyId = accessKeyId
        this.secretAccessKey = secretAccessKey
        this.region = region
        this.endpoint = endpoint
        this.bucket = bucket
        this.sessionToken = ""
        this.storageClass = None
        this.insecureHttp = false
        this.virtualHostedStyle = false
    }

    /// 增加引用
    /// 对应 Bun: pub const ref = RefCount.ref
    public func ref(): S3Credentials {
        refCount += 1
        return this
    }

    /// 减少引用, 为 0 时释放
    /// 对应 Bun: pub const deref = RefCount.deref
    public func deref(): Unit {
        refCount -= 1
        if (refCount <= 0) {
            deinit()
        }
    }

    /// 估算内存大小
    /// 对应 Bun:
    ///   pub fn estimatedSize(this: *const @This()) usize {
    ///       return @sizeOf(S3Credentials) + this.accessKeyId.len + this.region.len +
    ///              this.secretAccessKey.len + this.endpoint.len + this.bucket.len;
    ///   }
    public func estimatedSize(): Int64 {
        return 64 + accessKeyId.size + secretAccessKey.size + region.size +
               endpoint.size + bucket.size
    }

    /// 复制凭证
    /// 对应 Bun:
    ///   pub fn dupe(this: *const @This()) *S3Credentials {
    ///       return bun.new(S3Credentials, .{
    ///           .ref_count = .init(),
    ///           .accessKeyId = if (this.accessKeyId.len > 0)
    ///               bun.handleOom(bun.default_allocator.dupe(u8, this.accessKeyId))
    ///           else "",
    ///           ... (所有字段深拷贝)
    ///       });
    ///   }
    /// 深拷贝所有字符串字段
    public func dupe(): S3Credentials {
        let copy = S3Credentials(
            accessKeyId: accessKeyId,
            secretAccessKey: secretAccessKey,
            region: region,
            endpoint: endpoint,
            bucket: bucket
        )
        copy.sessionToken = sessionToken
        copy.storageClass = storageClass
        copy.insecureHttp = insecureHttp
        copy.virtualHostedStyle = virtualHostedStyle
        return copy
    }

    /// 释放资源
    /// 对应 Bun:
    ///   fn deinit(this: *@This()) void {
    ///       if (this.accessKeyId.len > 0) { bun.default_allocator.free(this.accessKeyId); }
    ///       ... (所有字段释放)
    ///       bun.destroy(this);
    ///   }
    private func deinit(): Unit {
        // 仓颉 GC 管理, 不需要手动释放
    }

    // ========================================================================
    // hashConst - ACL 哈希
    // 严格翻译自: credentials.zig
    //   fn hashConst(acl: []const u8) u64 {
    //       var hasher = std.hash.Wyhash.init(0);
    //       var remain = acl;
    //       var buf: [@sizeOf(@TypeOf(hasher.buf))]u8 = undefined;
    //       while (remain.len > 0) {
    //           const end = @min(hasher.buf.len, remain.len);
    //           hasher.update(strings.copyLowercaseIfNeeded(remain[0..end], &buf));
    //           remain = remain[end..];
    //       }
    //       return hasher.final();
    //   }
    // ========================================================================

    /// 使用 WyHash 对 ACL 字符串计算哈希
    /// 对应 Bun: fn hashConst(acl: []const u8) u64
    /// 使用小写化的 ACL 字符串计算 WyHash 值
    public static func hashConst(acl: String): UInt64 {
        return WyHash.hash(acl.toLower())
    }

    // ========================================================================
    // DateResult / getAMZDate - 获取 AWS 日期格式
    // 严格翻译自: credentials.zig
    //   const DateResult = struct {
    //       numeric_day: u64,
    //       date: []const u8,
    //   };
    //   fn getAMZDate(allocator: std.mem.Allocator) DateResult {
    //       const secs: u64 = @intCast(@divFloor(std.time.milliTimestamp(), 1000));
    //       const utc_seconds = std.time.epoch.EpochSeconds{ .secs = secs };
    //       const utc_day = utc_seconds.getEpochDay();
    //       const year_and_day = utc_day.calculateYearDay();
    //       const month_and_day = year_and_day.calculateMonthDay();
    //       const year = year_and_day.year;
    //       const day = @as(u32, month_and_day.day_index) + 1;
    //       const month = month_and_day.month.numeric();
    //       const time = utc_seconds.getDaySeconds();
    //       const hours = time.getHoursIntoDay();
    //       const minutes = time.getMinutesIntoHour();
    //       const seconds = time.getSecondsIntoMinute();
    //       return .{
    //           .numeric_day = secs - time.secs,
    //           .date = std.fmt.allocPrint(allocator,
    //               "{d:0>4}{d:0>2}{d:0>2}T{d:0>2}{d:0>2}{d:0>2}Z", .{
    //                   year, month, day, hours, minutes, seconds,
    //               }),
    //       };
    //   }
    // ========================================================================

    /// 日期计算结果
    /// 对应 Bun: DateResult = struct { numeric_day: u64, date: []const u8 }
    public class DateResult {
        /// 年月日的数值表示 (不含时间部分)
        /// 对应 Bun: numeric_day: u64
        public var numericDay: UInt64
        /// 格式化的日期字符串 (YYYYMMDDTHHmmssZ)
        /// 对应 Bun: date: []const u8
        public var date: String

        public init(numericDay: UInt64, date: String) {
            this.numericDay = numericDay
            this.date = date
        }
    }

    /// 获取 AWS AMZ 日期格式 (YYYYMMDDTHHmmssZ)
    /// 对应 Bun: fn getAMZDate(allocator) DateResult
    /// 使用 UTC 时间生成 AWS 签名所需的日期字符串
    /// 格式: {YYYY}{MM}{DD}T{HH}{MM}{SS}Z
    public static func getAMZDate(): DateResult {
        // 获取当前 UTC 时间戳 (秒)
        // 对应 Bun: const secs: u64 = @intCast(@divFloor(std.time.milliTimestamp(), 1000));
        let now = DateTime.utcNow()
        let year = now.year
        let month = now.month
        let day = now.dayOfMonth
        let hours = now.hour
        let minutes = now.minute
        let seconds = now.second

        // 计算 numeric_day: 从 Unix epoch 开始的天数
        // 对应 Bun: numeric_day = secs - time.secs
        // 使用简化计算: 从 epoch 开始的秒数 / 86400
        let totalDays = UInt64((now.toUnixSeconds() / 86400))

        // 格式化日期字符串
        // 对应 Bun: std.fmt.allocPrint(allocator,
        //   "{d:0>4}{d:0>2}{d:0>2}T{d:0>2}{d:0>2}{d:0>2}Z", .{
        //       year, month, day, hours, minutes, seconds })
        let date = padInt4(year) + padInt2(month) + padInt2(day) + "T" +
                   padInt2(hours) + padInt2(minutes) + padInt2(seconds) + "Z"

        return DateResult(numericDay: totalDays, date: date)
    }

    /// 数字补零到 4 位
    private static func padInt4(n: Int64): String {
        if (n < 10) { return "000${n}" }
        if (n < 100) { return "00${n}" }
        if (n < 1000) { return "0${n}" }
        return "${n}"
    }

    /// 数字补零到 2 位
    private static func padInt2(n: Int64): String {
        if (n < 10) { return "0${n}" }
        return "${n}"
    }

    // ========================================================================
    // SignResult - 签名结果
    // 严格翻译自: credentials.zig
    //   pub const SignResult = struct {
    //       amz_date: []const u8,
    //       host: []const u8,
    //       authorization: []const u8,
    //       url: []const u8,
    //       content_disposition: []const u8 = "",
    //       content_encoding: []const u8 = "",
    //       content_md5: []const u8 = "",
    //       session_token: []const u8 = "",
    //       acl: ?ACL = null,
    //       storage_class: ?StorageClass = null,
    //       request_payer: bool = false,
    //       _headers: [MAX_HEADERS]picohttp.Header = ...,
    //       _headers_len: u8 = 0,
    //       pub const MAX_HEADERS = 11;
    //       pub fn headers(this) []const picohttp.Header { ... }
    //       pub fn mixWithHeader(this, headers_buffer, header) []const picohttp.Header { ... }
    //       pub fn deinit(this) void { ... }
    //   };
    // ========================================================================

    /// S3 签名结果
    /// 对应 Bun: SignResult = struct
    public class SignResult {
        /// 最大头数量
        /// 对应 Bun: pub const MAX_HEADERS = 11
        public static let MAX_HEADERS: Int64 = 11

        /// AMZ 日期 (YYYYMMDDTHHmmssZ)
        /// 对应 Bun: amz_date: []const u8
        public var amzDate: String
        /// 主机名
        /// 对应 Bun: host: []const u8
        public var host: String
        /// Authorization header 值
        /// 对应 Bun: authorization: []const u8
        public var authorization: String
        /// 签名后的 URL
        /// 对应 Bun: url: []const u8
        public var url: String
        /// Content-Disposition
        /// 对应 Bun: content_disposition: []const u8 = ""
        public var contentDisposition: String
        /// Content-Encoding
        /// 对应 Bun: content_encoding: []const u8 = ""
        public var contentEncoding: String
        /// Content-MD5
        /// 对应 Bun: content_md5: []const u8 = ""
        public var contentMd5: String
        /// Session Token
        /// 对应 Bun: session_token: []const u8 = ""
        public var sessionToken: String
        /// ACL
        /// 对应 Bun: acl: ?ACL = null
        public var acl: ?ACL
        /// 存储类别
        /// 对应 Bun: storage_class: ?StorageClass = null
        public var storageClass: ?StorageClass
        /// 是否请求者付费
        /// 对应 Bun: request_payer: bool = false
        public var requestPayer: Bool
        /// HTTP 头列表 (名称, 值)
        /// 对应 Bun: _headers: [MAX_HEADERS]picohttp.Header
        public var headers: Array<Header>
        /// 头数量
        /// 对应 Bun: _headers_len: u8 = 0
        public var headersLen: Int64

        public init() {
            amzDate = ""
            host = ""
            authorization = ""
            url = ""
            contentDisposition = ""
            contentEncoding = ""
            contentMd5 = ""
            sessionToken = ""
            acl = None
            storageClass = None
            requestPayer = false
            headers = Array<Header>()
            headersLen = 0
        }

        /// 获取头列表
        /// 对应 Bun: pub fn headers(this: *const @This()) []const picohttp.Header
        public func getHeaders(): Array<Header> {
            return headers
        }

        /// 合并一个额外头
        /// 对应 Bun:
        ///   pub fn mixWithHeader(this: *const @This(), headers_buffer: []picohttp.Header,
        ///                        header: picohttp.Header) []const picohttp.Header {
        ///       const len = this._headers_len;
        ///       for (this._headers[0..len], 0..len) |existing_header, i| {
        ///           headers_buffer[i] = existing_header;
        ///       }
        ///       headers_buffer[len] = header;
        ///       return headers_buffer[0 .. len + 1];
        ///   }
        public func mixWithHeader(header: Header): Array<Header> {
            var result = Array<Header>()
            for (h in headers) {
                result.append(h)
            }
            result.append(header)
            return result
        }

        /// 释放资源
        /// 对应 Bun:
        ///   pub fn deinit(this: *const @This()) void {
        ///       if (this.amz_date.len > 0) { bun.freeSensitive(bun.default_allocator, this.amz_date); }
        ///       if (this.session_token.len > 0) { bun.freeSensitive(bun.default_allocator, this.session_token); }
        ///       ... (所有字段释放)
        ///   }
        public func deinit(): Unit {
            // 清除敏感数据
            amzDate = ""
            sessionToken = ""
            host = ""
            authorization = ""
            url = ""
            contentDisposition = ""
            contentEncoding = ""
            contentMd5 = ""
        }
    }

    // ========================================================================
    // Header - HTTP 头
    // 对应 Bun: picohttp.Header = struct { name: []const u8, value: []const u8 }
    // ========================================================================

    /// HTTP 头
    /// 对应 Bun: picohttp.Header = struct { name: []const u8, value: []const u8 }
    public class Header {
        public var name: String
        public var value: String

        public init(name: String, value: String) {
            this.name = name
            this.value = value
        }
    }

    // ========================================================================
    // SignOptions / SignQueryOptions - 签名选项
    // 严格翻译自: credentials.zig
    //   pub const SignQueryOptions = struct { expires: usize = 86400 };
    //   pub const SignOptions = struct {
    //       path: []const u8,
    //       method: bun.http.Method,
    //       content_hash: ?[]const u8 = null,
    //       content_md5: ?[]const u8 = null,
    //       search_params: ?[]const u8 = null,
    //       content_disposition: ?[]const u8 = null,
    //       content_type: ?[]const u8 = null,
    //       content_encoding: ?[]const u8 = null,
    //       acl: ?ACL = null,
    //       storage_class: ?StorageClass = null,
    //       request_payer: bool = false,
    //   };
    // ========================================================================

    /// 签名选项
    /// 对应 Bun: SignOptions = struct
    public class SignOptions {
        /// 请求路径
        /// 对应 Bun: path: []const u8
        public var path: String
        /// HTTP 方法
        /// 对应 Bun: method: bun.http.Method
        public var method: String
        /// 内容哈希 (SHA256 hex)
        /// 对应 Bun: content_hash: ?[]const u8 = null
        public var contentHash: ?String
        /// Content-MD5
        /// 对应 Bun: content_md5: ?[]const u8 = null
        public var contentMd5: ?String
        /// 查询参数字符串
        /// 对应 Bun: search_params: ?[]const u8 = null
        public var searchParams: ?String
        /// Content-Disposition
        /// 对应 Bun: content_disposition: ?[]const u8 = null
        public var contentDisposition: ?String
        /// Content-Type
        /// 对应 Bun: content_type: ?[]const u8 = null
        public var contentType: ?String
        /// Content-Encoding
        /// 对应 Bun: content_encoding: ?[]const u8 = null
        public var contentEncoding: ?String
        /// ACL
        /// 对应 Bun: acl: ?ACL = null
        public var acl: ?ACL
        /// 存储类别
        /// 对应 Bun: storage_class: ?StorageClass = null
        public var storageClass: ?StorageClass
        /// 是否请求者付费
        /// 对应 Bun: request_payer: bool = false
        public var requestPayer: Bool

        public init(path: String, method: String) {
            this.path = path
            this.method = method
            contentHash = None
            contentMd5 = None
            searchParams = None
            contentDisposition = None
            contentType = None
            contentEncoding = None
            acl = None
            storageClass = None
            requestPayer = false
        }
    }

    /// Presigned URL 选项
    /// 对应 Bun: SignQueryOptions = struct { expires: usize = 86400 }
    public class SignQueryOptions {
        /// 过期时间 (秒), 默认 86400 (1天)
        /// 对应 Bun: expires: usize = 86400
        public var expires: Int64

        public init() {
            expires = 86400
        }

        public init(expires: Int64) {
            this.expires = expires
        }
    }

    // ========================================================================
    // S3CredentialsWithOptions - 带 JS 绑定的凭证
    // 严格翻译自: credentials.zig
    //   pub const S3CredentialsWithOptions = struct {
    //       credentials: S3Credentials,
    //       options: MultiPartUploadOptions = .{},
    //       acl: ?ACL = null,
    //       storage_class: ?StorageClass = null,
    //       content_disposition: ?[]const u8 = null,
    //       content_type: ?[]const u8 = null,
    //       content_encoding: ?[]const u8 = null,
    //       request_payer: bool = false,
    //       changed_credentials: bool = false,
    //       virtual_hosted_style: bool = false,
    //       _accessKeyIdSlice: ?jsc.ZigString.Slice = null,
    //       _secretAccessKeySlice: ?jsc.ZigString.Slice = null,
    //       _regionSlice: ?jsc.ZigString.Slice = null,
    //       _endpointSlice: ?jsc.ZigString.Slice = null,
    //       _bucketSlice: ?jsc.ZigString.Slice = null,
    //       _sessionTokenSlice: ?jsc.ZigString.Slice = null,
    //       _contentDispositionSlice: ?jsc.ZigString.Slice = null,
    //       _contentTypeSlice: ?jsc.ZigString.Slice = null,
    //       _contentEncodingSlice: ?jsc.ZigString.Slice = null,
    //       pub fn deinit(this: *@This()) void { ... }
    //   };
    // ========================================================================

    /// 带选项的凭证
    /// 对应 Bun: S3CredentialsWithOptions = struct
    public class S3CredentialsWithOptions {
        /// S3 凭证
        /// 对应 Bun: credentials: S3Credentials
        public var credentials: S3Credentials
        /// 多部分上传选项
        /// 对应 Bun: options: MultiPartUploadOptions = .{}
        public var options: MultiPartUploadOptions
        /// ACL
        /// 对应 Bun: acl: ?ACL = null
        public var acl: ?ACL
        /// 存储类别
        /// 对应 Bun: storage_class: ?StorageClass = null
        public var storageClass: ?StorageClass
        /// Content-Disposition
        /// 对应 Bun: content_disposition: ?[]const u8 = null
        public var contentDisposition: ?String
        /// Content-Type
        /// 对应 Bun: content_type: ?[]const u8 = null
        public var contentType: ?String
        /// Content-Encoding
        /// 对应 Bun: content_encoding: ?[]const u8 = null
        public var contentEncoding: ?String
        /// 是否请求者付费
        /// 对应 Bun: request_payer: bool = false
        public var requestPayer: Bool
        /// 凭证是否已更改
        /// 对应 Bun: changed_credentials: bool = false
        public var changedCredentials: Bool
        /// 是否使用虚拟主机风格
        /// 对应 Bun: virtual_hosted_style: bool = false
        public var virtualHostedStyle: Bool

        // JS 字符串切片 (对应 ZigString.Slice, 仓颉中不需要)
        // _accessKeyIdSlice, _secretAccessKeySlice, _regionSlice, etc.

        public init(credentials: S3Credentials) {
            this.credentials = credentials
            this.options = MultiPartUploadOptions()
            this.acl = None
            this.storageClass = None
            this.contentDisposition = None
            this.contentType = None
            this.contentEncoding = None
            this.requestPayer = false
            this.changedCredentials = false
            this.virtualHostedStyle = false
        }

        /// 释放 JS 字符串切片
        /// 对应 Bun:
        ///   pub fn deinit(this: *@This()) void {
        ///       if (this._accessKeyIdSlice) |slice| slice.deinit();
        ///       ... (所有 Slice 释放)
        ///   }
        public func deinit(): Unit {
            // 仓颉 GC 管理, 不需要手动释放
        }
    }

    /// 多部分上传选项
    /// 对应 Bun: MultiPartUploadOptions (从 multipart_options.zig 导入)
    public class MultiPartUploadOptions {
        /// 分块大小 (字节)
        public var partSize: Int64
        /// 并发上传数
        public var concurrency: Int64

        public init() {
            partSize = 8 * 1024 * 1024  // 8MB
            concurrency = 4
        }
    }

    // ========================================================================
    // SignedHeaders - 签名头查找表
    // 严格翻译自: credentials.zig
    //   const SignedHeaders = struct {
    //       const Key = packed struct(u7) {
    //           content_disposition: bool,
    //           content_encoding: bool,
    //           content_md5: bool,
    //           acl: bool,
    //           request_payer: bool,
    //           session_token: bool,
    //           storage_class: bool,
    //       };
    //       fn generate(comptime key: Key) []const u8 { ... }
    //       const table = init: { ... 128 entries ... };
    //       pub fn get(key: Key) []const u8 { return table[@as(u7, @bitCast(key))]; }
    //   };
    //
    //   Comptime-generated lookup table for signed headers strings.
    //   Headers must be in alphabetical order per AWS Signature V4 spec.
    // ========================================================================

    /// 签名头键
    /// 对应 Bun: SignedHeaders.Key = packed struct(u7)
    /// 7 位标志, 每一位表示一个可选头是否参与签名
    public class SignedHeadersKey {
        /// Content-Disposition 是否存在
        public var contentDisposition: Bool
        /// Content-Encoding 是否存在
        public var contentEncoding: Bool
        /// Content-MD5 是否存在
        public var contentMd5: Bool
        /// ACL 是否存在
        public var acl: Bool
        /// 请求者付费
        public var requestPayer: Bool
        /// Session Token 是否存在
        public var sessionToken: Bool
        /// 存储类别是否存在
        public var storageClass: Bool

        public init() {
            contentDisposition = false
            contentEncoding = false
            contentMd5 = false
            acl = false
            requestPayer = false
            sessionToken = false
            storageClass = false
        }
    }

    /// 签名头生成器
    /// 对应 Bun: SignedHeaders = struct { generate, table, get }
    /// 根据 key 标志位生成按字母序排列的签名头字符串
    public class SignedHeaders {
        /// 根据标志位生成签名头字符串
        /// 对应 Bun:
        ///   fn generate(comptime key: Key) []const u8 {
        ///       return (if (key.content_disposition) "content-disposition;" else "") ++
        ///           (if (key.content_encoding) "content-encoding;" else "") ++
        ///           (if (key.content_md5) "content-md5;" else "") ++
        ///           "host;" ++
        ///           (if (key.acl) "x-amz-acl;" else "") ++
        ///           "x-amz-content-sha256;x-amz-date" ++
        ///           (if (key.request_payer) ";x-amz-request-payer" else "") ++
        ///           (if (key.session_token) ";x-amz-security-token" else "") ++
        ///           (if (key.storage_class) ";x-amz-storage-class" else "");
        ///   }
        /// 头必须按字母序排列 (AWS Signature V4 规范)
        public static func generate(key: SignedHeadersKey): String {
            let sb = StringBuilder()
            if (key.contentDisposition) { sb.append("content-disposition;") }
            if (key.contentEncoding) { sb.append("content-encoding;") }
            if (key.contentMd5) { sb.append("content-md5;") }
            sb.append("host;")
            if (key.acl) { sb.append("x-amz-acl;") }
            sb.append("x-amz-content-sha256;x-amz-date")
            if (key.requestPayer) { sb.append(";x-amz-request-payer") }
            if (key.sessionToken) { sb.append(";x-amz-security-token") }
            if (key.storageClass) { sb.append(";x-amz-storage-class") }
            return sb.toString()
        }
    }

    // ========================================================================
    // CanonicalRequest - 规范请求
    // 严格翻译自: credentials.zig
    //   const CanonicalRequest = struct {
    //       fn fmtString(comptime key: SignedHeaders.Key) []const u8 {
    //           return "{s}\n{s}\n{s}\n" ++
    //               (if (key.content_disposition) "content-disposition:{s}\n" else "") ++
    //               (if (key.content_encoding) "content-encoding:{s}\n" else "") ++
    //               (if (key.content_md5) "content-md5:{s}\n" else "") ++
    //               "host:{s}\n" ++
    //               (if (key.acl) "x-amz-acl:{s}\n" else "") ++
    //               "x-amz-content-sha256:{s}\nx-amz-date:{s}\n" ++
    //               (if (key.request_payer) "x-amz-request-payer:requester\n" else "") ++
    //               (if (key.session_token) "x-amz-security-token:{s}\n" else "") ++
    //               (if (key.storage_class) "x-amz-storage-class:{s}\n" else "") ++
    //               "\n{s}\n{s}";
    //       }
    //       inline fn formatForKey(comptime key, buf, ...) ![]u8 { ... }
    //       pub fn format(buf, key, method, path, query, ...) ![]u8 {
    //           return switch (@as(u7, @bitCast(key))) {
    //               inline 0...127 => |idx| formatForKey(@bitCast(idx), ...),
    //           };
    //       }
    //   };
    // ========================================================================

    /// 规范请求构建器
    /// 对应 Bun: CanonicalRequest = struct
    /// 根据 key 选择正确的格式字符串并填充参数
    public class CanonicalRequest {
        /// 构建规范请求
        /// 对应 Bun: CanonicalRequest.format(buf, key, method, path, query, ...)
        /// 方法 + 路径 + 查询 + 头 (按字母序) + 空行 + 签名头 + 哈希
        public static func format(
            key: SignedHeadersKey,
            method: String, path: String, queryString: String,
            contentDisposition: ?String, contentEncoding: ?String, contentMd5: ?String,
            host: String, acl: ?String,
            hash: String, date: String,
            sessionToken: ?String, storageClass: ?String,
            signedHeaders: String
        ): String {
            let sb = StringBuilder()
            // 方法 + 路径 + 查询
            // 对应 Bun: "{s}\n{s}\n{s}\n"
            sb.append("${method}\n${path}\n${queryString}\n")

            // 头 (按字母序)
            // 对应 Bun: (if (key.content_disposition) "content-disposition:{s}\n" else "")
            if (key.contentDisposition) {
                match (contentDisposition) {
                    case Some(cd) => sb.append("content-disposition:${cd}\n")
                    case None => ()
                }
            }
            if (key.contentEncoding) {
                match (contentEncoding) {
                    case Some(ce) => sb.append("content-encoding:${ce}\n")
                    case None => ()
                }
            }
            if (key.contentMd5) {
                match (contentMd5) {
                    case Some(md5) => sb.append("content-md5:${md5}\n")
                    case None => ()
                }
            }
            // 对应 Bun: "host:{s}\n"
            sb.append("host:${host}\n")
            if (key.acl) {
                match (acl) {
                    case Some(a) => sb.append("x-amz-acl:${a}\n")
                    case None => ()
                }
            }
            // 对应 Bun: "x-amz-content-sha256:{s}\nx-amz-date:{s}\n"
            sb.append("x-amz-content-sha256:${hash}\n")
            sb.append("x-amz-date:${date}\n")
            if (key.requestPayer) {
                // 对应 Bun: "x-amz-request-payer:requester\n"
                sb.append("x-amz-request-payer:requester\n")
            }
            if (key.sessionToken) {
                match (sessionToken) {
                    case Some(t) => sb.append("x-amz-security-token:${t}\n")
                    case None => ()
                }
            }
            if (key.storageClass) {
                match (storageClass) {
                    case Some(sc) => sb.append("x-amz-storage-class:${sc}\n")
                    case None => ()
                }
            }

            // 空行 + 签名头 + 哈希
            // 对应 Bun: "\n{s}\n{s}"  // signed_headers, hash
            sb.append("\n${signedHeaders}\n${hash}")

            return sb.toString()
        }
    }

    // ========================================================================
    // toHexChar - hex 字符转换
    // 严格翻译自: credentials.zig
    //   fn toHexChar(value: u8) !u8 {
    //       return switch (value) {
    //           0...9 => value + '0',
    //           10...15 => (value - 10) + 'A',
    //           else => error.InvalidHexChar,
    //       };
    //   }
    // ========================================================================

    /// hex 字符转换
    /// 对应 Bun: fn toHexChar(value: u8) !u8
    private static func toHexChar(v: Int64): Char {
        if (v >= 0 && v <= 9) { return Char(Int64('0') + v) }
        return Char(Int64('A') + v - 10)
    }

    // ========================================================================
    // encodeURIComponent - URI 编码
    // 严格翻译自: credentials.zig
    //   pub fn encodeURIComponent(input: []const u8, buffer: []u8,
    //                             comptime encode_slash: bool) ![]const u8 {
    //       var written: usize = 0;
    //       for (input) |c| {
    //           switch (c) {
    //               'A'...'Z', 'a'...'z', '0'...'9', '-', '_', '.', '~' => {
    //                   if (written >= buffer.len) return error.BufferTooSmall;
    //                   buffer[written] = c;
    //                   written += 1;
    //               },
    //               else => {
    //                   if (!encode_slash and (c == '/' or c == '\\')) {
    //                       if (written >= buffer.len) return error.BufferTooSmall;
    //                       buffer[written] = if (c == '\\') '/' else c;
    //                       written += 1;
    //                       continue;
    //                   }
    //                   if (written + 3 > buffer.len) return error.BufferTooSmall;
    //                   buffer[written] = '%';
    //                   const high_nibble: u8 = (c >> 4) & 0xF;
    //                   const low_nibble: u8 = c & 0xF;
    //                   buffer[written + 1] = try toHexChar(high_nibble);
    //                   buffer[written + 2] = try toHexChar(low_nibble);
    //                   written += 3;
    //               },
    //           }
    //       }
    //       return buffer[0..written];
    //   }
    // ========================================================================

    /// URI 编码
    /// 对应 Bun: pub fn encodeURIComponent(input, buffer, encode_slash) ![]const u8
    /// RFC 3986 非保留字符: A-Z a-z 0-9 - _ . ~
    /// 其他字符百分号编码, 可选编码斜杠
    public static func encodeURIComponent(input: String, encodeSlash: Bool): String {
        let sb = StringBuilder()
        for (i in 0..input.size) {
            let c = input[Int64(i)]
            let v = Int64(c.value)
            // RFC 3986 Unreserved Characters (do not encode)
            if ((v >= Int64('A') && v <= Int64('Z')) ||
                (v >= Int64('a') && v <= Int64('z')) ||
                (v >= Int64('0') && v <= Int64('9')) ||
                v == Int64('-') || v == Int64('_') || v == Int64('.') || v == Int64('~')) {
                sb.append(c)
            } else if (!encodeSlash && (c == Char('/') || c == Char('\\'))) {
                // 不编码斜杠, 反斜杠转为正斜杠
                sb.append(if (c == Char('\\')) { "/" } else { c })
            } else {
                // 百分号编码: %HH
                let high = (v >> 4) & 0x0F
                let low = v & 0x0F
                sb.append("%")
                sb.append(toHexChar(high))
                sb.append(toHexChar(low))
            }
        }
        return sb.toString()
    }

    // ========================================================================
    // normalizeName - 规范化路径名
    // 严格翻译自: credentials.zig
    //   fn normalizeName(name: []const u8) []const u8 {
    //       if (name.len == 0) return name;
    //       return std.mem.trim(u8, name, "/\\");
    //   }
    // ========================================================================

    /// 规范化路径名
    /// 对应 Bun: fn normalizeName(name: []const u8) []const u8
    /// 去除首尾的 / 和 \
    public static func normalizeName(name: String): String {
        if (name.size == 0) { return name }
        var result = name
        while (result.startsWith("/") || result.startsWith("\\")) {
            result = result.substring(1)
        }
        while (result.endsWith("/") || result.endsWith("\\")) {
            result = result.substring(0, result.size - 1)
        }
        return result
    }

    // ========================================================================
    // guessBucket - 猜测存储桶名
    // 严格翻译自: credentials.zig
    //   pub fn guessBucket(endpoint: []const u8) ?[]const u8 {
    //       if (strings.indexOf(endpoint, ".amazonaws.com")) |_| {
    //           if (strings.indexOf(endpoint, ".s3.")) |end| {
    //               const start = strings.indexOf(endpoint, "/") orelse {
    //                   return endpoint[0..end];
    //               };
    //               return endpoint[start + 1 .. end];
    //           }
    //       } else if (strings.indexOf(endpoint, ".r2.cloudflarestorage.com")) |r2_start| {
    //           const end = strings.indexOf(endpoint, ".") orelse return null;
    //           if (end > 0 and r2_start == end) { return null; }
    //           const start = strings.indexOf(endpoint, "/") orelse {
    //               return endpoint[0..end];
    //           };
    //           return endpoint[start + 1 .. end];
    //       }
    //       return null;
    //   }
    // ========================================================================

    /// 猜测存储桶名
    /// 对应 Bun: pub fn guessBucket(endpoint: []const u8) ?[]const u8
    /// 从端点 URL 推断存储桶名称
    public static func guessBucket(endpoint: String): ?String {
        let awsIdx = endpoint.indexOf(".amazonaws.com")
        if (awsIdx >= 0) {
            let s3Idx = endpoint.indexOf(".s3.")
            if (s3Idx >= 0) {
                let start = endpoint.indexOf("/")
                if (start >= 0) {
                    return endpoint.substring(Int64(start + 1), Int64(s3Idx))
                }
                return endpoint.substring(0, Int64(s3Idx))
            }
        }
        let r2Idx = endpoint.indexOf(".r2.cloudflarestorage.com")
        if (r2Idx >= 0) {
            let dotIdx = endpoint.indexOf(".")
            if (dotIdx >= 0 && r2Idx == dotIdx) { return None }
            let start = endpoint.indexOf("/")
            if (start >= 0) {
                return endpoint.substring(Int64(start + 1), Int64(dotIdx))
            }
            return endpoint.substring(0, Int64(dotIdx))
        }
        return None
    }

    // ========================================================================
    // guessRegion - 猜测区域
    // 严格翻译自: credentials.zig
    //   pub fn guessRegion(endpoint: []const u8) []const u8 {
    //       if (endpoint.len > 0) {
    //           if (strings.endsWith(endpoint, ".r2.cloudflarestorage.com")) return "auto";
    //           if (strings.indexOf(endpoint, ".amazonaws.com")) |end| {
    //               if (strings.indexOf(endpoint, "s3.")) |start| {
    //                   return endpoint[start + 3 .. end];
    //               }
    //           }
    //           return "auto";
    //       }
    //       return "us-east-1";
    //   }
    // ========================================================================

    /// 猜测区域
    /// 对应 Bun: pub fn guessRegion(endpoint: []const u8) []const u8
    /// 从端点 URL 推断 AWS 区域
    public static func guessRegion(endpoint: String): String {
        if (endpoint.size > 0) {
            if (endpoint.endsWith(".r2.cloudflarestorage.com")) { return "auto" }
            let awsIdx = endpoint.indexOf(".amazonaws.com")
            if (awsIdx >= 0) {
                let s3Idx = endpoint.indexOf("s3.")
                if (s3Idx >= 0) {
                    return endpoint.substring(Int64(s3Idx + 3), Int64(awsIdx))
                }
            }
            // endpoint is informed but is not s3 so auto detect
            return "auto"
        }
        // no endpoint so we default to us-east-1
        return "us-east-1"
    }

    // ========================================================================
    // HMAC 签名缓存
    // 对应 Bun: jsc.VirtualMachine.get().rareData().awsCache()
    // 用于缓存 Date+Region+Service 的 HMAC 派生密钥
    // ========================================================================

    /// AWS 签名缓存
    /// 对应 Bun: rareData().awsCache() -- 缓存 HMAC 签名密钥
    /// key: "region+serviceName+secretAccessKey" 的哈希
    /// value: 派生签名密钥 (32字节)
    private static var awsSignatureCache: HashMap<String, Array<UInt8>>

    /// HMAC-SHA256 摘要长度
    /// 对应 Bun: const DIGESTED_HMAC_256_LEN = 32;
    private static let DIGESTED_HMAC_256_LEN: Int64 = 32

    /// 获取缓存的签名密钥
    /// 对应 Bun: cache.get(date_result.numeric_day, key)
    private static func getCachedSignature(numericDay: UInt64, key: String): ?Array<UInt8> {
        let cacheKey = "${numericDay}|${key}"
        return awsSignatureCache.get(cacheKey)
    }

    /// 设置缓存的签名密钥
    /// 对应 Bun: cache.set(date_result.numeric_day, key, hmac_sig_service2[0..DIGESTED_HMAC_256_LEN].*)
    private static func setCachedSignature(numericDay: UInt64, key: String, value: Array<UInt8>): Unit {
        let cacheKey = "${numericDay}|${key}"
        awsSignatureCache.put(cacheKey, value)
    }

    // ========================================================================
    // signRequest - AWS Signature V4 签名
    // 严格翻译自: credentials.zig
    //   pub fn signRequest(
    //       this: *const @This(),
    //       signOptions: SignOptions,
    //       comptime allow_empty_path: bool,
    //       signQueryOption: ?SignQueryOptions
    //   ) !SignResult { ... }
    //
    // 完整的 AWS Signature V4 签名流程:
    // 1. 验证凭证
    // 2. 解析路径/桶/区域
    // 3. 计算 AMZ 日期
    // 4. 构建签名密钥 (HMAC 链: Date -> Region -> Service -> aws4_request)
    // 5. 构建规范请求 (方法 + 路径 + 查询 + 头 + hash)
    // 6. 计算签名
    // 7. 构建 Authorization 头或 Presigned URL
    // ========================================================================

    /// AWS Signature V4 签名
    /// 对应 Bun: pub fn signRequest(this, signOptions, allow_empty_path, signQueryOption) !SignResult
    /// 完整的 AWS Signature V4 签名流程
    ///
    /// - allowEmptyPath: 是否允许空路径 (列出桶)
    /// - signQueryOption: 如果非 None, 生成 Presigned URL; 否则生成 Authorization header
    public func signRequest(
        signOptions: SignOptions,
        allowEmptyPath: Bool,
        signQueryOption: ?SignQueryOptions
    ): SignResult {
        let method = signOptions.method
        let requestPath = signOptions.path
        var contentMd5 = signOptions.contentMd5

        // 对应 Bun:
        //   if (content_md5) |content_md5_val| {
        //       const len = bun.base64.encodeLen(content_md5_val);
        //       const content_md5_as_base64 = bun.handleOom(bun.default_allocator.alloc(u8, len));
        //       content_md5 = content_md5_as_base64[0..bun.base64.encode(content_md5_as_base64, content_md5_val)];
        //   }
        // 将 content_md5 从原始字节转为 Base64
        if (contentMd5 != None) {
            match (contentMd5) {
                case Some(md5Bytes) => {
                    contentMd5 = Some(Base64Encode.encode(stringToBytes(md5Bytes)))
                }
                case None => ()
            }
        }

        let searchParams = signOptions.searchParams

        // 对应 Bun:
        //   var content_disposition = signOptions.content_disposition;
        //   if (content_disposition != null and content_disposition.?.len == 0) { content_disposition = null; }
        var contentDisposition = signOptions.contentDisposition
        if (contentDisposition != None) {
            match (contentDisposition) {
                case Some(cd) => if (cd.size == 0) { contentDisposition = None }
                case None => ()
            }
        }
        var contentType = signOptions.contentType
        if (contentType != None) {
            match (contentType) {
                case Some(ct) => if (ct.size == 0) { contentType = None }
                case None => ()
            }
        }
        var contentEncoding = signOptions.contentEncoding
        if (contentEncoding != None) {
            match (contentEncoding) {
                case Some(ce) => if (ce.size == 0) { contentEncoding = None }
                case None => ()
            }
        }

        // 对应 Bun: const session_token: ?[]const u8 = if (this.sessionToken.len == 0) null else this.sessionToken;
        let sessionToken: ?String = if (sessionToken.size == 0) { None } else { Some(sessionToken) }

        // 对应 Bun: const acl: ?[]const u8 = if (signOptions.acl) |acl_value| acl_value.toString() else null;
        let acl: ?String = match (signOptions.acl) {
            case Some(aclValue) => Some(aclValue.toString())
            case None => None
        }

        // 对应 Bun: const storage_class: ?[]const u8 = if (signOptions.storage_class) |storage_class| storage_class.toString() else null;
        let storageClassStr: ?String = match (signOptions.storageClass) {
            case Some(sc) => Some(sc.toString())
            case None => None
        }

        // 对应 Bun: if (this.accessKeyId.len == 0 or this.secretAccessKey.len == 0) return error.MissingCredentials;
        if (accessKeyId.size == 0 || secretAccessKey.size == 0) {
            return signError(S3SignError.MissingCredentials)
        }

        let signQuery = signQueryOption != None
        // 对应 Bun: const expires = if (signQueryOption) |options| options.expires else 0;
        let expires = match (signQueryOption) {
            case Some(opts) => opts.expires
            case None => Int64(0)
        }

        // 对应 Bun:
        //   const method_name = switch (method) {
        //       .GET => "GET", .POST => "POST", .PUT => "PUT",
        //       .DELETE => "DELETE", .HEAD => "HEAD",
        //       else => return error.InvalidMethod,
        //   };
        let methodName = match (method.toUpper()) {
            case "GET" => "GET"
            case "POST" => "POST"
            case "PUT" => "PUT"
            case "DELETE" => "DELETE"
            case "HEAD" => "HEAD"
            case _ => return signError(S3SignError.InvalidMethod)
        }

        // 对应 Bun: const region = if (this.region.len > 0) this.region else guessRegion(this.endpoint);
        let region = if (region.size > 0) { region } else { S3Credentials.guessRegion(endpoint) }

        var fullPath = requestPath
        // 对应 Bun:
        //   if (strings.startsWith(full_path, "/")) { full_path = full_path[1..]; }
        //   else if (strings.startsWith(full_path, "\\")) { full_path = full_path[1..]; }
        if (fullPath.startsWith("/")) {
            fullPath = fullPath.substring(1)
        } else if (fullPath.startsWith("\\")) {
            fullPath = fullPath.substring(1)
        }

        var path: String = fullPath
        var bucket: String = bucket

        // 对应 Bun:
        //   if (!this.virtual_hosted_style) {
        //       if (bucket.len == 0) {
        //           if (strings.indexOf(full_path, "/")) |end| {
        //               if (strings.indexOf(full_path, "\\")) |backslash_index| {
        //                   if (backslash_index < end) {
        //                       bucket = full_path[0..backslash_index];
        //                       path = full_path[backslash_index + 1 ..];
        //                   }
        //               }
        //               bucket = full_path[0..end];
        //               path = full_path[end + 1 ..];
        //           } else if (strings.indexOf(full_path, "\\")) |backslash_index| {
        //               bucket = full_path[0..backslash_index];
        //               path = full_path[backslash_index + 1 ..];
        //           } else {
        //               return error.InvalidPath;
        //           }
        //       }
        //   }
        if (!virtualHostedStyle) {
            if (bucket.size == 0) {
                let slashIdx = fullPath.indexOf("/")
                let backslashIdx = fullPath.indexOf("\\")
                if (slashIdx >= 0) {
                    if (backslashIdx >= 0 && backslashIdx < slashIdx) {
                        bucket = fullPath.substring(0, Int64(backslashIdx))
                        path = fullPath.substring(Int64(backslashIdx + 1))
                    }
                    bucket = fullPath.substring(0, Int64(slashIdx))
                    path = fullPath.substring(Int64(slashIdx + 1))
                } else if (backslashIdx >= 0) {
                    bucket = fullPath.substring(0, Int64(backslashIdx))
                    path = fullPath.substring(Int64(backslashIdx + 1))
                } else {
                    return signError(S3SignError.InvalidPath)
                }
            }
        }

        // 对应 Bun:
        //   path = normalizeName(path);
        //   bucket = normalizeName(bucket);
        path = S3Credentials.normalizeName(path)
        bucket = S3Credentials.normalizeName(bucket)

        // 对应 Bun: if (!allow_empty_path and path.len == 0) return error.InvalidPath;
        if (!allowEmptyPath && path.size == 0) {
            return signError(S3SignError.InvalidPath)
        }

        // 对应 Bun:
        //   bucket = encodeURIComponent(bucket, &bucket_buffer, false) catch return error.InvalidPath;
        //   path = encodeURIComponent(path, &path_buffer, false) catch return error.InvalidPath;
        let encodedBucket = S3Credentials.encodeURIComponent(bucket, false)
        let encodedPath = S3Credentials.encodeURIComponent(path, false)

        // 对应 Bun: const protocol = if (this.insecure_http) "http" else "https";
        let protocol = if (insecureHttp) { "http" } else { "https" }

        // 对应 Bun:
        //   var endpoint = this.endpoint;
        //   var extra_path: []const u8 = "";
        //   const host = brk_host: { ... };
        var endpointStr = endpoint
        var extraPath = ""
        let host: String
        if (endpoint.size > 0) {
            if (endpoint.size >= 2048) {
                return signError(S3SignError.InvalidEndpoint)
            }
            var hostPart = endpoint
            let slashInEndpoint = endpoint.indexOf("/")
            if (slashInEndpoint >= 0) {
                hostPart = endpoint.substring(0, Int64(slashInEndpoint))
                extraPath = endpoint.substring(Int64(slashInEndpoint))
            }
            host = hostPart
        } else {
            if (virtualHostedStyle) {
                if (encodedBucket.size == 0) {
                    return signError(S3SignError.InvalidEndpoint)
                }
                // default to https://<BUCKET_NAME>.s3.<REGION>.amazonaws.com/
                endpointStr = "${encodedBucket}.s3.${region}.amazonaws.com"
                host = endpointStr
            } else {
                endpointStr = "s3.${region}.amazonaws.com"
                host = endpointStr
            }
        }

        // 对应 Bun:
        //   const normalizedPath = brk: {
        //       if (this.virtual_hosted_style) {
        //           break :brk std.fmt.bufPrint(&normalized_path_buffer, "{s}/{s}", .{ extra_path, path });
        //       } else {
        //           break :brk std.fmt.bufPrint(&normalized_path_buffer, "{s}/{s}/{s}", .{ extra_path, bucket, path });
        //       }
        //   };
        let normalizedPath = if (virtualHostedStyle) {
            "${extraPath}/${encodedPath}"
        } else {
            "${extraPath}/${encodedBucket}/${encodedPath}"
        }

        // 对应 Bun:
        //   const date_result = getAMZDate(bun.default_allocator);
        //   const amz_date = date_result.date;
        //   const amz_day = amz_date[0..8];
        let dateResult = S3Credentials.getAMZDate()
        let amzDate = dateResult.date
        let amzDay = amzDate.substring(0, 8)
        let requestPayer = signOptions.requestPayer

        // 对应 Bun:
        //   const header_key = SignedHeaders.Key{
        //       .content_disposition = content_disposition != null,
        //       .content_encoding = content_encoding != null,
        //       .content_md5 = content_md5 != null,
        //       .acl = acl != null,
        //       .request_payer = request_payer,
        //       .session_token = session_token != null,
        //       .storage_class = storage_class != null,
        //   };
        let headerKey = SignedHeadersKey()
        headerKey.contentDisposition = contentDisposition != None
        headerKey.contentEncoding = contentEncoding != None
        headerKey.contentMd5 = contentMd5 != None
        headerKey.acl = acl != None
        headerKey.requestPayer = requestPayer
        headerKey.sessionToken = sessionToken != None
        headerKey.storageClass = storageClassStr != None

        // 对应 Bun: const signed_headers = if (signQuery) "host" else SignedHeaders.get(header_key);
        let signedHeaders = if (signQuery) { "host" } else { SignedHeaders.generate(headerKey) }

        // 对应 Bun: const service_name = "s3";
        let serviceName = "s3"

        // 对应 Bun: const aws_content_hash = if (content_hash) |hash| hash else ("UNSIGNED-PAYLOAD");
        let awsContentHash = match (signOptions.contentHash) {
            case Some(h) => h
            case None => "UNSIGNED-PAYLOAD"
        }

        // ====================================================================
        // 签名密钥生成 (HMAC 链)
        // 严格翻译自: credentials.zig signRequest 中的 brk_sign 块
        //   const sigDateRegionServiceReq = brk_sign: {
        //       const key = try std.fmt.bufPrint(&tmp_buffer, "{s}{s}{s}", .{ region, service_name, this.secretAccessKey });
        //       var cache = ...rareData().awsCache();
        //       if (cache.get(date_result.numeric_day, key)) |cached| { break :brk_sign cached; }
        //       const sigDate = bun.hmac.generate("AWS4" + secretAccessKey, amz_day, .sha256);
        //       const sigDateRegion = bun.hmac.generate(sigDate, region, .sha256);
        //       const sigDateRegionService = bun.hmac.generate(sigDateRegion, service_name, .sha256);
        //       const result = bun.hmac.generate(sigDateRegionService, "aws4_request", .sha256);
        //       cache.set(date_result.numeric_day, key, result[0..32].*);
        //       break :brk_sign result;
        //   };
        // ====================================================================

        let cacheKey = "${region}${serviceName}${secretAccessKey}"
        let sigDateRegionServiceReq = match (S3Credentials.getCachedSignature(dateResult.numericDay, cacheKey)) {
            case Some(cached) => cached
            case None => {
                // HMAC 链: Date -> Region -> Service -> aws4_request
                // 对应 Bun:
                //   const sigDate = bun.hmac.generate(try std.fmt.bufPrint("AWS4{s}", .{this.secretAccessKey}), amz_day, .sha256);
                let sigDate = HmacSha256.hmac(
                    stringToBytes("AWS4" + secretAccessKey),
                    stringToBytes(amzDay)
                )
                // 对应 Bun: const sigDateRegion = bun.hmac.generate(sigDate, region, .sha256);
                let sigDateRegion = HmacSha256.hmac(sigDate, stringToBytes(region))
                // 对应 Bun: const sigDateRegionService = bun.hmac.generate(sigDateRegion, service_name, .sha256);
                let sigDateRegionService = HmacSha256.hmac(sigDateRegion, stringToBytes(serviceName))
                // 对应 Bun: const result = bun.hmac.generate(sigDateRegionService, "aws4_request", .sha256);
                let result = HmacSha256.hmac(sigDateRegionService, stringToBytes("aws4_request"))
                // 缓存
                S3Credentials.setCachedSignature(dateResult.numericDay, cacheKey, result)
                result
            }
        }

        // ====================================================================
        // 构建 Authorization 或 Presigned URL
        // 严格翻译自: credentials.zig signRequest 中的 brk 块
        // ====================================================================

        if (signQuery) {
            // === Presigned URL 模式 ===
            // 严格翻译自: credentials.zig signRequest 中的 signQuery 分支

            // 对应 Bun:
            //   var token_encoded_buffer: [2048]u8 = undefined;
            //   var encoded_session_token: ?[]const u8 = null;
            //   if (session_token) |token| {
            //       encoded_session_token = encodeURIComponent(token, &token_encoded_buffer, true);
            //   }
            let encodedSessionToken: ?String = match (sessionToken) {
                case Some(token) => Some(S3Credentials.encodeURIComponent(token, true))
                case None => None
            }

            // 对应 Bun:
            //   var encoded_content_md5: ?[]const u8 = null;
            //   if (content_md5) |content_md5_value| {
            //       encoded_content_md5 = encodeURIComponent(content_md5_value, ...);
            //   }
            let encodedContentMd5: ?String = match (contentMd5) {
                case Some(md5) => Some(S3Credentials.encodeURIComponent(md5, true))
                case None => None
            }

            // 对应 Bun:
            //   var encoded_content_disposition: ?[]const u8 = null;
            //   if (content_disposition) |cd| {
            //       encoded_content_disposition = encodeURIComponent(cd, ...);
            //   }
            let encodedContentDisposition: ?String = match (contentDisposition) {
                case Some(cd) => Some(S3Credentials.encodeURIComponent(cd, true))
                case None => None
            }

            // 对应 Bun:
            //   var encoded_content_type: ?[]const u8 = null;
            //   if (content_type) |ct| {
            //       encoded_content_type = encodeURIComponent(ct, ...);
            //   }
            let encodedContentType: ?String = match (contentType) {
                case Some(ct) => Some(S3Credentials.encodeURIComponent(ct, true))
                case None => None
            }

            // 对应 Bun:
            //   // Build query parameters in alphabetical order for AWS Signature V4 canonical request
            //   var query_parts: bun.BoundedArray([]const u8, 13) = .{};
            //   // Add parameters in alphabetical order:
            //   // Content-MD5, X-Amz-Acl, X-Amz-Algorithm, X-Amz-Credential,
            //   // X-Amz-Date, X-Amz-Expires, X-Amz-Security-Token, X-Amz-SignedHeaders,
            //   // response-content-disposition, response-content-type,
            //   // x-amz-request-payer, x-amz-storage-class
            var queryParts = Array<String>()

            if (encodedContentMd5 != None) {
                match (encodedContentMd5) {
                    case Some(v) => queryParts.append("Content-MD5=${v}")
                    case None => ()
                }
            }
            if (acl != None) {
                match (acl) {
                    case Some(v) => queryParts.append("X-Amz-Acl=${v}")
                    case None => ()
                }
            }
            queryParts.append("X-Amz-Algorithm=AWS4-HMAC-SHA256")
            queryParts.append("X-Amz-Credential=${accessKeyId}%2F${amzDay}%2F${region}%2F${serviceName}%2Faws4_request")
            queryParts.append("X-Amz-Date=${amzDate}")
            queryParts.append("X-Amz-Expires=${expires}")
            if (encodedSessionToken != None) {
                match (encodedSessionToken) {
                    case Some(t) => queryParts.append("X-Amz-Security-Token=${t}")
                    case None => ()
                }
            }
            queryParts.append("X-Amz-SignedHeaders=host")
            if (encodedContentDisposition != None) {
                match (encodedContentDisposition) {
                    case Some(cd) => queryParts.append("response-content-disposition=${cd}")
                    case None => ()
                }
            }
            if (encodedContentType != None) {
                match (encodedContentType) {
                    case Some(ct) => queryParts.append("response-content-type=${ct}")
                    case None => ()
                }
            }
            if (requestPayer) {
                queryParts.append("x-amz-request-payer=requester")
            }
            if (storageClassStr != None) {
                match (storageClassStr) {
                    case Some(v) => queryParts.append("x-amz-storage-class=${v}")
                    case None => ()
                }
            }

            // 对应 Bun:
            //   var query_string = std.array_list.Managed(u8).init(allocator);
            //   for (query_parts.slice(), 0..) |part, i| {
            //       if (i > 0) try query_string.append('&');
            //       try query_string.appendSlice(part);
            //   }
            let queryString = joinStrings(queryParts, "&")

            // 对应 Bun:
            //   break :brk_canonical try std.fmt.bufPrint(&tmp_buffer,
            //       "{s}\n{s}\n{s}\nhost:{s}\n\nhost\n{s}", .{
            //           method_name, normalizedPath, query_string.items, host, aws_content_hash });
            let canonical = "${methodName}\n${normalizedPath}\n${queryString}\nhost:${host}\n\nhost\n${awsContentHash}"

            // 对应 Bun:
            //   var sha_digest = std.mem.zeroes(bun.sha.SHA256.Digest);
            //   bun.sha.SHA256.hash(canonical, &sha_digest, ...);
            let shaDigest = Sha256.hash(stringToBytes(canonical))
            let shaHex = HexEncode.encode(shaDigest)

            // 对应 Bun:
            //   const signValue = try std.fmt.bufPrint(&tmp_buffer,
            //       "AWS4-HMAC-SHA256\n{s}\n{s}/{s}/{s}/aws4_request\n{s}", .{
            //           amz_date, amz_day, region, service_name,
            //           std.fmt.bytesToHex(sha_digest[0..digest], .lower) });
            let signValue = "AWS4-HMAC-SHA256\n${amzDate}\n${amzDay}/${region}/${serviceName}/aws4_request\n${shaHex}"

            // 对应 Bun:
            //   const signature = bun.hmac.generate(sigDateRegionServiceReq, signValue, .sha256, &hmac_sig_service);
            let signature = HmacSha256.hmac(sigDateRegionServiceReq, stringToBytes(signValue))
            let signatureHex = HexEncode.encode(signature)

            // 对应 Bun:
            //   // Build final URL with query parameters in alphabetical order
            //   var url_query_parts: bun.BoundedArray([]const u8, 14) = .{};
            var urlQueryParts = Array<String>()

            if (encodedContentMd5 != None) {
                match (encodedContentMd5) {
                    case Some(v) => urlQueryParts.append("Content-MD5=${v}")
                    case None => ()
                }
            }
            if (acl != None) {
                match (acl) {
                    case Some(v) => urlQueryParts.append("X-Amz-Acl=${v}")
                    case None => ()
                }
            }
            urlQueryParts.append("X-Amz-Algorithm=AWS4-HMAC-SHA256")
            urlQueryParts.append("X-Amz-Credential=${accessKeyId}%2F${amzDay}%2F${region}%2F${serviceName}%2Faws4_request")
            urlQueryParts.append("X-Amz-Date=${amzDate}")
            urlQueryParts.append("X-Amz-Expires=${expires}")
            if (encodedSessionToken != None) {
                match (encodedSessionToken) {
                    case Some(t) => urlQueryParts.append("X-Amz-Security-Token=${t}")
                    case None => ()
                }
            }
            urlQueryParts.append("X-Amz-Signature=${signatureHex}")
            urlQueryParts.append("X-Amz-SignedHeaders=host")
            if (encodedContentDisposition != None) {
                match (encodedContentDisposition) {
                    case Some(cd) => urlQueryParts.append("response-content-disposition=${cd}")
                    case None => ()
                }
            }
            if (encodedContentType != None) {
                match (encodedContentType) {
                    case Some(ct) => urlQueryParts.append("response-content-type=${ct}")
                    case None => ()
                }
            }
            if (requestPayer) {
                urlQueryParts.append("x-amz-request-payer=requester")
            }
            if (storageClassStr != None) {
                match (storageClassStr) {
                    case Some(v) => urlQueryParts.append("x-amz-storage-class=${v}")
                    case None => ()
                }
            }

            let urlQueryString = joinStrings(urlQueryParts, "&")

            // 对应 Bun:
            //   break :brk try std.fmt.allocPrint(bun.default_allocator,
            //       "{s}://{s}{s}?{s}", .{ protocol, host, normalizedPath, url_query_string.items });
            let presignedUrl = "${protocol}://${host}${normalizedPath}?${urlQueryString}"

            // 对应 Bun: signQuery 返回
            var result = SignResult()
            result.amzDate = ""
            result.host = ""
            result.authorization = ""
            result.acl = signOptions.acl
            result.url = presignedUrl
            result.storageClass = signOptions.storageClass
            return result

        } else {
            // === Authorization header 模式 ===
            // 严格翻译自: credentials.zig signRequest 中的 else 分支

            // 对应 Bun:
            //   const canonical = try CanonicalRequest.format(
            //       &tmp_buffer, header_key, method_name, normalizedPath,
            //       if (search_params) |p| p[1..] else "",
            //       content_disposition, content_encoding, content_md5,
            //       host, acl, aws_content_hash, amz_date,
            //       session_token, storage_class, signed_headers);
            let queryStringForCanonical = match (searchParams) {
                case Some(p) => if (p.size > 0 && p.startsWith("?")) { p.substring(1) } else { p }
                case None => ""
            }

            let canonical = CanonicalRequest.format(
                headerKey,
                methodName, normalizedPath, queryStringForCanonical,
                contentDisposition, contentEncoding, contentMd5,
                host, acl,
                awsContentHash, amzDate,
                sessionToken, storageClassStr,
                signedHeaders
            )

            // 对应 Bun:
            //   var sha_digest = std.mem.zeroes(bun.sha.SHA256.Digest);
            //   bun.sha.SHA256.hash(canonical, &sha_digest, ...);
            let shaDigest = Sha256.hash(stringToBytes(canonical))
            let shaHex = HexEncode.encode(shaDigest)

            // 对应 Bun:
            //   const signValue = try std.fmt.bufPrint(&tmp_buffer,
            //       "AWS4-HMAC-SHA256\n{s}\n{s}/{s}/{s}/aws4_request\n{s}", .{
            //           amz_date, amz_day, region, service_name,
            //           std.fmt.bytesToHex(sha_digest[0..digest], .lower) });
            let signValue = "AWS4-HMAC-SHA256\n${amzDate}\n${amzDay}/${region}/${serviceName}/aws4_request\n${shaHex}"

            // 对应 Bun:
            //   const signature = bun.hmac.generate(sigDateRegionServiceReq, signValue, .sha256, ...);
            let signature = HmacSha256.hmac(sigDateRegionServiceReq, stringToBytes(signValue))
            let signatureHex = HexEncode.encode(signature)

            // 对应 Bun:
            //   break :brk try std.fmt.allocPrint(bun.default_allocator,
            //       "AWS4-HMAC-SHA256 Credential={s}/{s}/{s}/{s}/aws4_request, SignedHeaders={s}, Signature={s}",
            //       .{ accessKeyId, amz_day, region, service_name, signed_headers, signature_hex });
            let authorization = "AWS4-HMAC-SHA256 Credential=${accessKeyId}/${amzDay}/${region}/${serviceName}/aws4_request, SignedHeaders=${signedHeaders}, Signature=${signatureHex}"

            // 对应 Bun: 构建 SignResult
            var result = SignResult()
            result.amzDate = amzDate
            result.host = host
            result.authorization = authorization
            result.acl = signOptions.acl
            result.storageClass = signOptions.storageClass
            result.requestPayer = requestPayer
            result.url = "${protocol}://${host}${normalizedPath}${match (searchParams) { case Some(s) => s case None => "" }}"

            // 对应 Bun:
            //   result._headers = [_]picohttp.Header{
            //       .{ .name = "x-amz-content-sha256", .value = aws_content_hash },
            //       .{ .name = "x-amz-date", .value = amz_date },
            //       .{ .name = "Host", .value = host },
            //       .{ .name = "Authorization", .value = authorization[0..] },
            //       ... (7 empty)
            //   };
            //   result._headers_len = 4;
            result.headers.append(Header("x-amz-content-sha256", awsContentHash))
            result.headers.append(Header("x-amz-date", amzDate))
            result.headers.append(Header("Host", host))
            result.headers.append(Header("Authorization", authorization))
            result.headersLen = 4

            // 对应 Bun:
            //   if (acl) |acl_value| {
            //       result._headers[result._headers_len] = .{ .name = "x-amz-acl", .value = acl_value };
            //       result._headers_len += 1;
            //   }
            if (acl != None) {
                match (acl) {
                    case Some(v) => {
                        result.headers.append(Header("x-amz-acl", v))
                        result.headersLen += 1
                    }
                    case None => ()
                }
            }

            // 对应 Bun:
            //   if (session_token) |token| {
            //       const session_token_value = bun.handleOom(bun.default_allocator.dupe(u8, token));
            //       result.session_token = session_token_value;
            //       result._headers[result._headers_len] = .{ .name = "x-amz-security-token", .value = session_token_value };
            //       result._headers_len += 1;
            //   }
            if (sessionToken != None) {
                match (sessionToken) {
                    case Some(t) => {
                        result.sessionToken = t
                        result.headers.append(Header("x-amz-security-token", t))
                        result.headersLen += 1
                    }
                    case None => ()
                }
            }

            // 对应 Bun:
            //   if (storage_class) |storage_class_value| {
            //       result._headers[result._headers_len] = .{ .name = "x-amz-storage-class", .value = storage_class_value };
            //       result._headers_len += 1;
            //   }
            if (storageClassStr != None) {
                match (storageClassStr) {
                    case Some(v) => {
                        result.headers.append(Header("x-amz-storage-class", v))
                        result.headersLen += 1
                    }
                    case None => ()
                }
            }

            // 对应 Bun:
            //   if (content_disposition) |cd| {
            //       const content_disposition_value = bun.handleOom(bun.default_allocator.dupe(u8, cd));
            //       result.content_disposition = content_disposition_value;
            //       result._headers[result._headers_len] = .{ .name = "content-disposition", .value = content_disposition_value };
            //       result._headers_len += 1;
            //   }
            if (contentDisposition != None) {
                match (contentDisposition) {
                    case Some(cd) => {
                        result.contentDisposition = cd
                        result.headers.append(Header("content-disposition", cd))
                        result.headersLen += 1
                    }
                    case None => ()
                }
            }

            // 对应 Bun:
            //   if (content_encoding) |ce| {
            //       const content_encoding_value = bun.handleOom(bun.default_allocator.dupe(u8, ce));
            //       result.content_encoding = content_encoding_value;
            //       result._headers[result._headers_len] = .{ .name = "content-encoding", .value = content_encoding_value };
            //       result._headers_len += 1;
            //   }
            if (contentEncoding != None) {
                match (contentEncoding) {
                    case Some(ce) => {
                        result.contentEncoding = ce
                        result.headers.append(Header("content-encoding", ce))
                        result.headersLen += 1
                    }
                    case None => ()
                }
            }

            // 对应 Bun:
            //   if (content_md5) |c_md5| {
            //       const content_md5_value = bun.handleOom(bun.default_allocator.dupe(u8, c_md5));
            //       result.content_md5 = content_md5_value;
            //       result._headers[result._headers_len] = .{ .name = "content-md5", .value = content_md5_value };
            //       result._headers_len += 1;
            //   }
            if (contentMd5 != None) {
                match (contentMd5) {
                    case Some(md5) => {
                        result.contentMd5 = md5
                        result.headers.append(Header("content-md5", md5))
                        result.headersLen += 1
                    }
                    case None => ()
                }
            }

            // 对应 Bun:
            //   if (request_payer) {
            //       result._headers[result._headers_len] = .{ .name = "x-amz-request-payer", .value = "requester" };
            //       result._headers_len += 1;
            //   }
            if (requestPayer) {
                result.headers.append(Header("x-amz-request-payer", "requester"))
                result.headersLen += 1
            }

            return result
        }
    }

    /// 创建错误 SignResult
    private func signError(err: S3SignError): SignResult {
        let result = SignResult()
        result.authorization = "[ERROR] ${err.code()}: ${getSignErrorMessage(err)}"
        return result
    }
}

// ============================================================================
// 工具函数
// ============================================================================

/// 字符串转字节数组
private func stringToBytes(s: String): Array<UInt8> {
    var bytes = Array<UInt8>()
    for (c in s) { bytes.append(UInt8(c.value)) }
    return bytes
}

/// 用分隔符连接字符串数组
private func joinStrings(parts: Array<String>, separator: String): String {
    let sb = StringBuilder()
    for (i in 0..parts.size) {
        if (Int64(i) > 0) { sb.append(separator) }
        sb.append(parts[Int64(i)])
    }
    return sb.toString()
}
