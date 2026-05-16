// bao_install_types - 模块根
// 严格翻译自: src/install_types/lib.rs
//   lib.rs 是 install_types crate 的根模块, 声明并 re-export 所有子模块
//   bun_install_types 从 bun_install 中提取共享类型, 使得 bun_resolver
//   可以使用这些类型而不产生循环依赖
//
// 模块结构:
//   lib.rs           -> 本文件 (模块根, re-export)
//   resolver_hooks   -> resolver_hooks.cj (核心类型: ExternalSlice, Behavior, Dependency, Resolution, etc.)
//   NodeLinker       -> node_linker.cj (NodeLinker enum, npm Registry, PnpmMatcher)
//   ExternalString   -> external_string.cj (带预计算哈希的字符串)
//   SlicedString     -> sliced_string.cj (零拷贝字符串视图)
//   SemverString     -> semver_string.cj (SSO 字符串类型)
package bao_install_types

import bao_core.*
import bao_semver.*
import bao_hash.*
import bao_collections.*

// ─── Identity / sentinel ─────────────────────────────────────────────────
// 翻译自: resolver_hooks.rs 中的类型别名和常量

/// 包 ID - 翻译自: pub type PackageID = u32
public typealias PackageID = UInt32

/// 依赖 ID - 翻译自: pub type DependencyID = u32
public typealias DependencyID = UInt32

/// 包名哈希 - 翻译自: pub type PackageNameHash = u64
public typealias PackageNameHash = UInt64

/// 截断的包名哈希 - 翻译自: pub type TruncatedPackageNameHash = u32
public typealias TruncatedPackageNameHash = UInt32

/// 无效包 ID - 翻译自: pub const INVALID_PACKAGE_ID: PackageID = PackageID::MAX
public let INVALID_PACKAGE_ID: PackageID = PackageID.MAX

/// 无效依赖 ID - 翻译自: pub const INVALID_DEPENDENCY_ID: DependencyID = DependencyID::MAX
public let INVALID_DEPENDENCY_ID: DependencyID = DependencyID.MAX

// ─── Re-exports from sub-modules ─────────────────────────────────────────
// 翻译自: lib.rs 中的 pub use 语句
//
// 所有类型都在各自的文件中定义, 并在此处重新导出
// 以便下游可以通过 bao_install_types::TypeName 访问
//
// 翻译自 lib.rs:
//   pub use resolver_hooks::{
//       Architecture, AutoInstaller, Behavior, Dependency, DependencyGroup, DependencyID,
//       DependencySlice, DependencyVersion, DependencyVersionTag, DependencyVersionValue,
//       EnqueueResult, ExternalPackageNameHashList, ExternalSlice, ExternalStringList,
//       ExternalStringMap, Features, INVALID_DEPENDENCY_ID, INVALID_PACKAGE_ID, Libc, Negatable,
//       NegatableEnum, NegatableExt, NpmInfo, OldV2VersionedURL, OperatingSystem, PackageID,
//       PackageJsonView, PackageNameHash, PreinstallState, Repository, Resolution, ResolutionSlice,
//       ResolutionTag, ResolutionValue, TagInfo, TarballInfo, TaskCallbackContext,
//       TruncatedPackageNameHash, URI, VersionSlice, VersionedURL, VersionedURLType, WakeHandler,
//   };
//
// 下游代码可通过 bao_install_types.XYZ 直接访问这些类型
