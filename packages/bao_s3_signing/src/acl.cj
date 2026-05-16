// bao_http - S3 ACL 权限控制
// 严格翻译自: src/s3_signing/acl.zig
//   Bun 的 S3 ACL (Access Control List):
//   - ACL enum: private, public-read, public-read-write, aws-exec-read, ...
//   - toString(): 返回 S3 API 格式字符串
//   - ComptimeStringMap: 字符串反向查找
package bao_s3_signing

// ============================================================================
// S3Acl - S3 访问控制列表
// 严格翻译自: acl.zig ACL = enum {
//   private, public_read, public_read_write, aws_exec_read,
//   authenticated_read, bucket_owner_read, bucket_owner_full_control,
//   log_delivery_write
// }
// ============================================================================

/// S3 ACL 权限
/// 对应 Bun: ACL = enum
/// S3 预定义的 ACL (Canned ACL)
public enum S3Acl {
    | Private               // private: 所有者获得 FULL_CONTROL, 其他人无权限 (默认)
    | PublicRead            // public-read: 所有者 FULL_CONTROL, AllUsers 组 READ
    | PublicReadWrite       // public-read-write: 所有者 FULL_CONTROL, AllUsers 组 READ+WRITE
    | AwsExecRead           // aws-exec-read: 所有者 FULL_CONTROL, EC2 READ
    | AuthenticatedRead     // authenticated-read: 所有者 FULL_CONTROL, 认证用户 READ
    | BucketOwnerRead       // bucket-owner-read: 对象所有者 FULL_CONTROL, 桶所有者 READ
    | BucketOwnerFullControl // bucket-owner-full-control: 对象和桶所有者都 FULL_CONTROL
    | LogDeliveryWrite      // log-delivery-write: 日志投递组 WRITE+READ_ACP

    /// 转为 S3 API 字符串
    /// 对应 Bun: ACL.toString() -> []const u8
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
    /// 对应 Bun: ACL.Map = bun.ComptimeStringMap(ACL, .{ ... })
    /// 字符串反向查找表
    public static func fromString(s: String): ?S3Acl {
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

    /// 获取 ACL 描述
    public func description(): String {
        match (this) {
            case Private => "Owner gets FULL_CONTROL. No one else has access rights (default)."
            case PublicRead => "Owner gets FULL_CONTROL. The AllUsers group gets READ access."
            case PublicReadWrite => "Owner gets FULL_CONTROL. The AllUsers group gets READ and WRITE access. Granting this on a bucket is generally not recommended."
            case AwsExecRead => "Owner gets FULL_CONTROL. Amazon EC2 gets READ access to GET an Amazon Machine Image (AMI) bundle from Amazon S3."
            case AuthenticatedRead => "Owner gets FULL_CONTROL. The AuthenticatedUsers group gets READ access."
            case BucketOwnerRead => "Object owner gets FULL_CONTROL. Bucket owner gets READ access. If you specify this canned ACL when creating a bucket, Amazon S3 ignores it."
            case BucketOwnerFullControl => "Both the object owner and the bucket owner get FULL_CONTROL over the object. If you specify this canned ACL when creating a bucket, Amazon S3 ignores it."
            case LogDeliveryWrite => "Log delivery group gets WRITE and READ_ACP permissions on the bucket."
        }
    }
}
