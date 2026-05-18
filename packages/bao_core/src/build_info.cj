// bao_core - 构建信息常量
// 严格翻译自: src/bun_core/build.rs
//   Bun build.rs 解析构建配置 (sha, version, baseline) 并导出环境变量
//   对应 Bun 的 build_options.rs 中的版本和构建配置信息
// 仓颉: 提供等价的构建信息常量
package bao_core

/// 构建信息 - 对应 Bun build_options.rs
/// Bun: build_options.rs is written at configure time by scripts/build/buildOptionsRs.ts
/// 包含: version, sha, baseline, features 等构建配置
public class BuildInfo {
    /// 版本号 - 对应 Bun VERSION
    public static let VERSION: String = "1.2.0"

    /// 包版本 - 对应 Bun BUN_VERSION
    public static let BUN_VERSION: String = "1.2.0"

    /// Git SHA - 对应 Bun GIT_SHA
    public static let GIT_SHA: String = "unknown"

    /// 基线架构 - 对应 Bun baseline (x86_64/aarch64 等)
    public static let BASELINE: String = "baseline"

    /// 构建类型 - debug / release
    public static let BUILD_TYPE: String = "release"

    /// 代码生成目录 - 对应 Bun BUN_CODEGEN_DIR
    public static let CODEGEN_DIR: String = "build/debug/codegen"

    /// 是否为 debug 构建
    public static func isDebug(): Bool {
        return BUILD_TYPE == "debug"
    }

    /// 是否为 release 构建
    public static func isRelease(): Bool {
        return BUILD_TYPE == "release"
    }

    /// 获取完整版本信息
    public static func fullVersion(): String {
        return "${VERSION}+${GIT_SHA} (${BUILD_TYPE})"
    }

    /// 转为字符串
    public func toString(): String {
        return "BuildInfo{version=${BuildInfo.VERSION}, sha=${BuildInfo.GIT_SHA}, type=${BuildInfo.BUILD_TYPE}}"
    }
}
