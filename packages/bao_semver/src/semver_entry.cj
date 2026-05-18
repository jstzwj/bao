// 严格翻译自: src/semver/semver.zig
//   Bun semver 模块入口文件
//   pub const String = @import("../install_types/SemverString.zig").String;
//   pub const ExternalString = @import("../install_types/ExternalString.zig").ExternalString;
//   pub const Version = @import("./Version.zig").Version;
//   pub const VersionType = @import("./Version.zig").VersionType;
//   pub const SlicedString = @import("../install_types/SlicedString.zig");
//   pub const Range = @import("./SemverRange.zig");
//   pub const Query = @import("./SemverQuery.zig");
//   pub const SemverObject = @import("../semver_jsc/SemverObject.zig");
//
// 本文件提供 semver 模块的类型别名和入口
package bao_semver

import bao_core.*

// ============================================================================
// Semver 类型别名
// 严格翻译自: src/semver/semver.zig
//   pub const String = @import("...").String;
//   pub const Version = @import("./Version.zig").Version;
//   pub const Range = @import("./SemverRange.zig");
//   pub const Query = @import("./SemverQuery.zig");
// ============================================================================

/// 版本字符串类型 - 对应 Bun SemverString.String
/// Bun 使用专门优化的字符串类型; 仓颉使用标准 String
public type SemverString = String

/// 外部字符串类型 - 对应 Bun SemverString.ExternalString
/// Bun 使用带偏移量的字符串视图; 仓颉使用标准 String
public type ExternalSemverString = String

/// 版本类型 - 对应 Bun Version.VersionType
/// 详细实现见 package.cj 中的 SemVer
public type SemverVersion = SemVer

/// 范围类型 - 对应 Bun Range (SemverRange.zig)
/// 详细实现见 range.cj 中的 SemVerRange
public type SemverRange = SemVerRange

/// 查询类型 - 对应 Bun Query (SemverQuery.zig)
/// 详细实现见 query.cj 中的 SemverQuery
public type SemverQueryType = SemverQuery

/// 查询组类型 - 对应 Bun Group (SemverQuery.zig)
/// 详细实现见 range.cj 中的 QueryGroup
public type SemverGroup = QueryGroup
