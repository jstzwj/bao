// 严格翻译自: src/runtime/webcore/s3/multipart_options.zig
// MultiPartUploadOptions - S3 多部分上传选项
package bao_runtime

import bao_core.*

// ============================================================================
// MultiPartUploadOptions - 多部分上传选项
// 严格翻译自: MultiPartUploadOptions struct
// Bun: pub const MultiPartUploadOptions = struct {
//   pub const OneMiB: usize = 1048576;
//   pub const MAX_SINGLE_UPLOAD_SIZE: usize = 5120 * OneMiB;
//   pub const MIN_SINGLE_UPLOAD_SIZE: usize = 5 * OneMiB;
//   pub const DefaultPartSize = MIN_SINGLE_UPLOAD_SIZE;
//   pub const MAX_QUEUE_SIZE = 64;
//   queueSize: u8 = 5,
//   partSize: u64 = DefaultPartSize,
//   retry: u8 = 3,
// }
// ============================================================================

/// 多部分上传选项
/// 对应 Bun: MultiPartUploadOptions struct
/// 配置 S3 多部分上传的队列大小、分块大小和重试次数
public class MultiPartUploadOptions {
    /// 1 MiB 的字节数
    /// 对应 Bun: pub const OneMiB: usize = 1048576
    public static let ONE_MIB: Int64 = 1048576

    /// 最大单次上传大小 (5 GiB)
    /// 对应 Bun: pub const MAX_SINGLE_UPLOAD_SIZE: usize = 5120 * OneMiB
    public static let MAX_SINGLE_UPLOAD_SIZE: Int64 = 5120 * ONE_MIB

    /// 最小单次上传大小 (5 MiB)
    /// 对应 Bun: pub const MIN_SINGLE_UPLOAD_SIZE: usize = 5 * OneMiB
    public static let MIN_SINGLE_UPLOAD_SIZE: Int64 = 5 * ONE_MIB

    /// 默认分块大小 (5 MiB)
    /// 对应 Bun: pub const DefaultPartSize = MIN_SINGLE_UPLOAD_SIZE
    public static let DEFAULT_PART_SIZE: Int64 = MIN_SINGLE_UPLOAD_SIZE

    /// 最大队列大小
    /// 对应 Bun: pub const MAX_QUEUE_SIZE = 64
    public static let MAX_QUEUE_SIZE: UInt8 = 64

    /// 队列大小 (默认 5)
    /// 对应 Bun: queueSize: u8 = 5
    /// 不超过 64，因为 HTTP 线程无法处理更多
    public var queueSize: UInt8 = 5

    /// 分块大小 (字节, 默认 5 MiB)
    /// 对应 Bun: partSize: u64 = DefaultPartSize
    /// S3 SDK 中以字节为单位设置，但最小值仍为 5 MiB
    /// 参考: https://docs.aws.amazon.com/AWSJavaScriptSDK/latest/AWS/S3.html#upload-property
    /// 值以 MiB 为单位，最小 5，最大 5120（但我们限制到 4 GiB = 4096）
    public var partSize: Int64 = DEFAULT_PART_SIZE

    /// 重试次数 (默认 3, 最大 255)
    /// 对应 Bun: retry: u8 = 3
    /// 超过 255 无意义，HTTP 线程无法处理更多
    public var retry: UInt8 = 3

    public init() {}

    public init(queueSize: UInt8, partSize: Int64, retry: UInt8) {
        this.queueSize = queueSize
        this.partSize = partSize
        this.retry = retry
    }

    /// 验证选项是否有效
    /// 检查 partSize 是否在合法范围内
    public func isValid(): Bool {
        return partSize >= MIN_SINGLE_UPLOAD_SIZE &&
               partSize <= MAX_SINGLE_UPLOAD_SIZE &&
               queueSize >= 1 &&
               queueSize <= MAX_QUEUE_SIZE &&
               retry >= 0 &&
               retry <= 255
    }

    /// 钳制选项值到合法范围
    /// 确保 partSize, queueSize, retry 在允许范围内
    public func clamp(): Unit {
        if (partSize < MIN_SINGLE_UPLOAD_SIZE) {
            partSize = MIN_SINGLE_UPLOAD_SIZE
        }
        if (partSize > MAX_SINGLE_UPLOAD_SIZE) {
            partSize = MAX_SINGLE_UPLOAD_SIZE
        }
        if (queueSize < 1) {
            queueSize = 1
        }
        if (queueSize > MAX_QUEUE_SIZE) {
            queueSize = MAX_QUEUE_SIZE
        }
        if (retry > 255) {
            retry = 255
        }
    }
}
