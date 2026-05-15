// bao_s3_signing - AWS S3 请求签名
// 严格翻译自: src/s3_signing/
//   Bun 的 S3 签名模块:
//   - acl.zig: ACL 访问控制列表
//   - credentials.zig: 凭证管理与 AWS Signature V4 签名
//   - error.zig: S3 错误类型
//   - storage_class.zig: 存储类别
package bao_s3_signing

import bao_core.*
import bao_hash.sha.*
import bao_hash.hmac.*

// ============================================================================
// S3 签名模块子模块引用
// ============================================================================

/// ACL (Access Control List) - S3 访问控制列表
/// 对应 Bun: src/s3_signing/acl.zig ACL = enum
/// 用法: ACL.Private, ACL.PublicRead, ACL.fromString("public-read")
public typealias S3Acl = ACL

/// StorageClass - S3 存储类别
/// 对应 Bun: src/s3_signing/storage_class.zig StorageClass = enum
/// 用法: StorageClass.Standard, StorageClass.Glacier, StorageClass.fromString("GLACIER")
// StorageClass 已在 storage_class.cj 中定义

/// S3Credentials - S3 凭证与签名
/// 对应 Bun: src/s3_signing/credentials.zig S3Credentials = struct
/// 包含 AWS Signature V4 签名算法
// S3Credentials 已在 credentials.cj 中定义

/// S3Error - S3 错误
/// 对应 Bun: src/s3_signing/error.zig S3Error = struct
// S3Error 已在 error.cj 中定义

/// S3SignError - S3 签名错误枚举
/// 对应 Bun: error.zig 中的 anyerror
// S3SignError 已在 error.cj 中定义

/// ErrorCodeAndMessage - 错误码和消息对
/// 对应 Bun: ErrorCodeAndMessage = struct
// ErrorCodeAndMessage 已在 error.cj 中定义

/// SignResult - 签名结果
/// 对应 Bun: SignResult = struct
// SignResult 已在 credentials.cj 中定义

/// SignOptions - 签名选项
/// 对应 Bun: SignOptions = struct
// SignOptions 已在 credentials.cj 中定义

/// SignQueryOptions - Presigned URL 选项
/// 对应 Bun: SignQueryOptions = struct
// SignQueryOptions 已在 credentials.cj 中定义

/// S3CredentialsWithOptions - 带选项的凭证
/// 对应 Bun: S3CredentialsWithOptions = struct
// S3CredentialsWithOptions 已在 credentials.cj 中定义

/// SignedHeadersKey - 签名头键
/// 对应 Bun: SignedHeaders.Key = packed struct(u7)
// SignedHeadersKey 已在 credentials.cj 中定义

/// SignedHeaders - 签名头生成器
/// 对应 Bun: SignedHeaders = struct
// SignedHeaders 已在 credentials.cj 中定义

/// CanonicalRequest - 规范请求构建器
/// 对应 Bun: CanonicalRequest = struct
// CanonicalRequest 已在 credentials.cj 中定义

/// Header - HTTP 头 (对应 picohttp.Header)
// Header 已在 credentials.cj 中定义

/// MultiPartUploadOptions - 多部分上传选项
// MultiPartUploadOptions 已在 credentials.cj 中定义

/// DateResult - 日期计算结果
// DateResult 已在 credentials.cj 中定义

// ============================================================================
// 错误处理函数
// ============================================================================

// getSignErrorMessage, getSignErrorCodeAndMessage, containsNewlineOrCR
// 已在 error.cj 中定义

// ============================================================================
// URI 编码
// ============================================================================

// encodeURIComponent 已在 credentials.cj 中定义

// ============================================================================
// 端点推断
// ============================================================================

// guessBucket, guessRegion, normalizeName 已在 credentials.cj 中定义
