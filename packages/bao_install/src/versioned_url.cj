// bao_install - 版本化 URL
// 严格翻译自: src/install/versioned_url.zig
//   versioned_url.zig 定义了带版本信息的 URL 数据结构,
//   用于 npm registry 中关联 tarball URL 和语义化版本
package bao_install

import bao_core.*
import bao_collections.*
import bao_io.*
import bao_hash.*
import bao_path.*
import bao_http.*

// ============================================================================
// 版本化 URL
// 严格翻译自: src/install/versioned_url.zig
//   pub const VersionedURL = VersionedURLType(u64)
//   pub fn VersionedURLType(comptime SemverIntType: type) type {
//       return extern struct {
//           url: String,
//           version: Semver.VersionType(SemverIntType),
//       }
//   }
// ============================================================================

/// 版本化 URL
/// 对应 Bun: VersionedURL
/// 关联一个 URL 和对应的语义化版本
public class VersionedURL {
    /// 下载 URL
    public var url: String
    /// 版本信息
    public var version: SemVer

    public init(url: String, version: SemVer) {
        this.url = url
        this.version = version
    }

    public init() {
        url = ""
        version = SemVer(0, 0, 0)
    }

    /// 比较
    /// 翻译自: VersionedURL.order
    public func compare(other: VersionedURL): Int64 {
        return version.compare(other.version)
    }

    /// 是否相等
    /// 翻译自: VersionedURL.eql
    public func eql(other: VersionedURL): Bool {
        return version.compare(other.version) == 0
    }

    /// 克隆
    /// 翻译自: VersionedURL.clone
    public func clone(): VersionedURL {
        return VersionedURL(url: url, version: version)
    }

    /// 格式化为字符串
    public func toString(): String {
        return "${url}@${version.toString()}"
    }
}
