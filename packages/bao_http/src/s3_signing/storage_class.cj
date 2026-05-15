// bao_http - S3 存储类别
// 严格翻译自: src/s3_signing/storage_class.zig
//   Bun 的 S3 存储类别:
//   - StorageClass enum: STANDARD, STANDARD_IA, INTELLIGENT_TIERING, ...
//   - toString(): 返回 S3 API 格式字符串
//   - ComptimeStringMap: 字符串反向查找
package bao_http

// ============================================================================
// S3StorageClass - S3 存储类别
// 严格翻译自: storage_class.zig StorageClass = enum
//   对应 AWS S3 的所有存储类别
// ============================================================================

/// S3 存储类别
/// 对应 Bun: StorageClass = enum {
///   STANDARD, STANDARD_IA, INTELLIGENT_TIERING, EXPRESS_ONEZONE,
///   ONEZONE_IA, GLACIER, GLACIER_IR, REDUCED_REDUNDANCY,
///   OUTPOSTS, DEEP_ARCHIVE, SNOW
/// }
public enum S3StorageClass {
    | Standard            // STANDARD - 标准存储, 适用于频繁访问的数据
    | StandardIa          // STANDARD_IA - 标准低频访问, 适用于不频繁访问的数据
    | IntelligentTiering  // INTELLIGENT_TIERING - 智能分层, 自动优化存储成本
    | ExpressOnezone      // EXPRESS_ONEZONE - 单区快速存储
    | OnezoneIa           // ONEZONE_IA - 单区低频访问
    | Glacier             // GLACIER - 冰川归档, 检索时间分钟到小时
    | GlacierIr           // GLACIER_IR - 冰川即时检索, 毫秒级检索
    | ReducedRedundancy   // REDUCED_REDUNDANCY - 降低冗余, 适用于可重建的数据
    | Outposts            // OUTPOSTS - AWS Outposts 本地存储
    | DeepArchive         // DEEP_ARCHIVE - 深度归档, 检索时间 12-48 小时
    | Snow                // SNOW - AWS Snow 设备存储

    /// 转为 S3 API 字符串
    /// 对应 Bun: StorageClass.toString() -> []const u8
    /// 返回 x-amz-storage-class 头使用的字符串值
    public func toString(): String {
        match (this) {
            case Standard => "STANDARD"
            case StandardIa => "STANDARD_IA"
            case IntelligentTiering => "INTELLIGENT_TIERING"
            case ExpressOnezone => "EXPRESS_ONEZONE"
            case OnezoneIa => "ONEZONE_IA"
            case Glacier => "GLACIER"
            case GlacierIr => "GLACIER_IR"
            case ReducedRedundancy => "REDUCED_REDUNDANCY"
            case Outposts => "OUTPOSTS"
            case DeepArchive => "DEEP_ARCHIVE"
            case Snow => "SNOW"
        }
    }

    /// 从 S3 API 字符串解析
    /// 对应 Bun: StorageClass.Map = bun.ComptimeStringMap(StorageClass, .{ ... })
    /// 字符串反向查找表
    public static func fromString(s: String): ?S3StorageClass {
        match (s) {
            case "STANDARD" => Standard
            case "STANDARD_IA" => StandardIa
            case "INTELLIGENT_TIERING" => IntelligentTiering
            case "EXPRESS_ONEZONE" => ExpressOnezone
            case "ONEZONE_IA" => OnezoneIa
            case "GLACIER" => Glacier
            case "GLACIER_IR" => GlacierIr
            case "REDUCED_REDUNDANCY" => ReducedRedundancy
            case "OUTPOSTS" => Outposts
            case "DEEP_ARCHIVE" => DeepArchive
            case "SNOW" => Snow
            case _ => None
        }
    }

    /// 获取存储类别描述
    public func description(): String {
        match (this) {
            case Standard => "Standard storage class for frequently accessed data"
            case StandardIa => "Standard-Infrequent Access for less frequently accessed data"
            case IntelligentTiering => "Intelligent-Tiering auto-optimizes storage costs"
            case ExpressOnezone => "Single-zone express storage"
            case OnezoneIa => "Single-zone Infrequent Access"
            case Glacier => "Glacier archival storage (minute-to-hour retrieval)"
            case GlacierIr => "Glacier Instant Retrieval (millisecond retrieval)"
            case ReducedRedundancy => "Reduced Redundancy for reproducible data"
            case Outposts => "AWS Outposts on-premises storage"
            case DeepArchive => "Deep Archive (12-48 hour retrieval)"
            case Snow => "AWS Snow device storage"
        }
    }

    /// 是否为归档类别 (需要恢复才能访问)
    public func isArchive(): Bool {
        match (this) {
            case Glacier => true
            case DeepArchive => true
            case _ => false
        }
    }

    /// 是否支持即时检索
    public func supportsInstantRetrieval(): Bool {
        match (this) {
            case Standard => true
            case StandardIa => true
            case IntelligentTiering => true
            case ExpressOnezone => true
            case OnezoneIa => true
            case GlacierIr => true
            case ReducedRedundancy => true
            case Outposts => true
            case Snow => true
            case _ => false  // Glacier, DeepArchive 需要恢复
        }
    }
}
