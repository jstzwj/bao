// 严格翻译自: src/s3_signing/acl.zig
//   Bun 的 S3 ACL (Access Control List):
//   - ACL enum: private, public-read, public-read-write, aws-exec-read, ...
//   - toString(): 返回 S3 API 格式字符串
//   - ComptimeStringMap: 字符串反向查找
package bao_s3_signing

// ============================================================================
// ACL - S3 访问控制列表
// 严格翻译自: acl.zig pub const ACL = enum {
//   private, public_read, public_read_write, aws_exec_read,
//   authenticated_read, bucket_owner_read, bucket_owner_full_control,
//   log_delivery_write
// }
//
//   pub fn toString(this: @This()) []const u8 { ... }
//   pub const Map = bun.ComptimeStringMap(ACL, .{ ... });
// ============================================================================

/// S3 ACL 权限
/// 对应 Bun: ACL = enum
/// S3 预定义的 ACL (Canned ACL)
/// Owner gets FULL_CONTROL. No one else has access rights (default).
public enum ACL {
    | Private               // private: 所有者获得 FULL_CONTROL, 其他人无权限 (默认)
    | PublicRead            // public-read: 所有者 FULL_CONTROL, AllUsers 组 READ
    | PublicReadWrite       // public-read-write: 所有者 FULL_CONTROL, AllUsers 组 READ+WRITE
    | AwsExecRead           // aws-exec-read: 所有者 FULL_CONTROL, EC2 READ
    | AuthenticatedRead     // authenticated-read: 所有者 FULL_CONTROL, 认证用户 READ
    | BucketOwnerRead       // bucket-owner-read: 对象所有者 FULL_CONTROL, 桶所有者 READ
    | BucketOwnerFullControl // bucket-owner-full-control: 对象和桶所有者都 FULL_CONTROL
    | LogDeliveryWrite      // log-delivery-write: 日志投递组 WRITE+READ_ACP

    /// 转为 S3 API 字符串
    /// 对应 Bun:
    ///   pub fn toString(this: @This()) []const u8 {
    ///       return switch (this) {
    ///           .private => "private",
    ///           .public_read => "public-read",
    ///           ...
    ///       };
    ///   }
    /// 返回 S3 REST API 使用的 x-amz-acl 头值
    public func toString(): String {
        match (this) {
            case Private => "private"
            case PublicRead => "public-read"
            case PublicReadWrite => "public-read-write"
            case AwsExecRead => "aws-exec-read"
            case AuthenticatedRead => "authenticated-read"
            case BucketOwnerRead => "bucket-owner-read"
            case BucketOwnerFullControl => "bucket-owner-full-control"
            case LogDeliveryWrite => "log-delivery-write"
        }
    }

    /// 从 S3 API 字符串解析
    /// 对应 Bun:
    ///   pub const Map = bun.ComptimeStringMap(ACL, .{
    ///       .{ "private", .private },
    ///       .{ "public-read", .public_read },
    ///       ...
    ///   });
    /// 字符串反向查找表 (ComptimeStringMap 等价)
    public static func fromString(s: String): ?ACL {
        match (s) {
            case "private" => Private
            case "public-read" => PublicRead
            case "public-read-write" => PublicReadWrite
            case "aws-exec-read" => AwsExecRead
            case "authenticated-read" => AuthenticatedRead
            case "bucket-owner-read" => BucketOwnerRead
            case "bucket-owner-full-control" => BucketOwnerFullControl
            case "log-delivery-write" => LogDeliveryWrite
            case _ => None
        }
    }
}
