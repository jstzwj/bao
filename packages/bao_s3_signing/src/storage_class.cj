// 严格翻译自: src/s3_signing/storage_class.zig
//   Bun 的 S3 存储类别:
//   - StorageClass enum: STANDARD, STANDARD_IA, INTELLIGENT_TIERING, ...
//   - toString(): 返回 S3 API 格式字符串
//   - ComptimeStringMap: 字符串反向查找
package bao_s3_signing

// ============================================================================
// StorageClass - S3 存储类别
// 严格翻译自: storage_class.zig pub const StorageClass = enum {
//   STANDARD, STANDARD_IA, INTELLIGENT_TIERING, EXPRESS_ONEZONE,
//   ONEZONE_IA, GLACIER, GLACIER_IR, REDUCED_REDUNDANCY,
//   OUTPOSTS, DEEP_ARCHIVE, SNOW
//
//   pub fn toString(this: @This()) []const u8 { ... }
//   pub const Map = bun.ComptimeStringMap(StorageClass, .{ ... });
// }
// ============================================================================

/// S3 存储类别
/// 对应 Bun: StorageClass = enum {
///   STANDARD, STANDARD_IA, INTELLIGENT_TIERING, EXPRESS_ONEZONE,
///   ONEZONE_IA, GLACIER, GLACIER_IR, REDUCED_REDUNDANCY,
///   OUTPOSTS, DEEP_ARCHIVE, SNOW
/// }
public enum StorageClass {
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
    /// 对应 Bun:
    ///   pub fn toString(this: @This()) []const u8 {
    ///       return switch (this) {
    ///           .STANDARD => "STANDARD",
    ///           .STANDARD_IA => "STANDARD_IA",
    ///           ...
    ///       };
    ///   }
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
    /// 对应 Bun:
    ///   pub const Map = bun.ComptimeStringMap(StorageClass, .{
    ///       .{ "STANDARD", .STANDARD },
    ///       .{ "STANDARD_IA", .STANDARD_IA },
    ///       ...
    ///   });
    /// 字符串反向查找表 (ComptimeStringMap 等价)
    public static func fromString(s: String): ?StorageClass {
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
}
