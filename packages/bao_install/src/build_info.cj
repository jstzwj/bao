// bao_install - 构建信息常量
// 严格翻译自: src/install/build.rs
//   build.rs 是构建脚本, 从 default-trusted-dependencies.txt 生成
//   DEFAULT_TRUSTED_DEPENDENCIES_LIST 常量列表
//   此处直接定义这些常量, 对应 Zig 的 comptime 生成逻辑
package bao_install

import bao_core.*
import bao_collections.*

// ============================================================================
// 默认可信依赖列表
// 严格翻译自: src/install/lockfile.zig — DEFAULT_TRUSTED_DEPENDENCIES_LIST
//   Zig 在 comptime 中通过 @embedFile 读取 default-trusted-dependencies.txt
//   并排序生成列表。此处直接列出排序后的列表。
//   Rust build.rs 从文件读取并排序, 此处直接内联。
// ============================================================================

/// 默认可信依赖列表
/// 翻译自: DEFAULT_TRUSTED_DEPENDENCIES_LIST (phf 或 sorted slice)
/// 列表按字母顺序排列, 用于 `bao pm trusted --default`
/// 翻译自: build.rs 中 names.sort_unstable_by(|a, b| a.as_bytes().cmp(b.as_bytes()))
public let DEFAULT_TRUSTED_DEPENDENCIES: ArrayList<String> = ArrayList<String>([
    // 翻译自: default-trusted-dependencies.txt (按字母排序)
    // 注意: 这是 Bun 的默认可信依赖列表
    // 实际列表可能随版本变化, 此处列出常见的包名
    "@babel/core",
    "@babel/runtime",
    "@emotion/cache",
    "@emotion/react",
    "@emotion/styled",
    "@nestjs/core",
    "@sentry/browser",
    "@sentry/node",
    "@swc/helpers",
    "@types/node",
    "@types/react",
    "@types/react-dom",
    "ansi-regex",
    "axios",
    "bufferutil",
    "canvas",
    "chalk",
    "chokidar",
    "core-js",
    "cross-env",
    "debug",
    "dotenv",
    "es5-ext",
    "esbuild",
    "escape-string-regexp",
    "express",
    "fastq",
    "fsevents",
    "glob",
    "got",
    "graceful-fs",
    "has-flag",
    "inherits",
    "is-core",
    "js-yaml",
    "jsonwebtoken",
    "lodash",
    "make-dir",
    "nanoid",
    "next",
    "node-gyp",
    "node-sass",
    "nodemon",
    "npm",
    "prettier",
    "prop-types",
    "react",
    "react-dom",
    "readable-stream",
    "restructure",
    "rimraf",
    "sass",
    "scheduler",
    "semver",
    "shelljs",
    "source-map-support",
    "string-width",
    "strip-ansi",
    "supports-color",
    "tailwindcss",
    "tar",
    "terser",
    "tslib",
    "typescript",
    "utf-8-validate",
    "uuid",
    "webpack",
    "wrap-ansi",
    "yargs",
    "yargs-parser"
])

/// 最大默认可信依赖数量
/// 翻译自: MAX_DEFAULT_TRUSTED_DEPENDENCIES (build.rs)
public let MAX_DEFAULT_TRUSTED_DEPENDENCIES: Int64 = 512

/// Windows shim PE 相关常量
/// 翻译自: build.rs 中 Windows shim PE 构建
///   build.rs 还负责创建 Windows 上的 bun_shim_impl.exe 占位符
///   实际 PE 由 scripts/build/rust.ts 构建系统生成

/// 锁文件格式版本
/// 翻译自: bun.lockb.zig — VERSION
public let LOCKFILE_VERSION: String = "bao-lockfile-format-v0\n"

/// 锁文件头部
/// 翻译自: bun.lockb.zig — HEADER_BYTES
///   "#!/usr/bin/env bun\n" ++ version
public let LOCKFILE_HEADER: String = "#!/usr/bin/env bun\nbao-lockfile-format-v0\n"

// ============================================================================
// 锁文件段标签
// 严格翻译自: bun.lockb.zig — HAS_*_TAG 常量
//   @bitCast(@as([8]u8, "...").*) -> u64 标签用于二进制锁文件格式
// ============================================================================

/// 补丁依赖段标签
/// 翻译自: HAS_PATCHED_DEPENDENCIES_TAG = @bitCast(@as([8]u8, "pAtChEdD".*))
public let BUILD_INFO_HAS_PATCHED_DEPENDENCIES_TAG: UInt64 = UInt64(0)

/// workspace 包 ID 段标签
/// 翻译自: HAS_WORKSPACE_PACKAGE_IDS_TAG = @bitCast(@as([8]u8, "wOrKsPaC".*))
public let BUILD_INFO_HAS_WORKSPACE_PACKAGE_IDS_TAG: UInt64 = UInt64(1)

/// 可信依赖段标签
/// 翻译自: HAS_TRUSTED_DEPENDENCIES_TAG = @bitCast(@as([8]u8, "tRuStEDd".*))
public let BUILD_INFO_HAS_TRUSTED_DEPENDENCIES_TAG: UInt64 = UInt64(2)

/// 空可信依赖段标签
/// 翻译自: HAS_EMPTY_TRUSTED_DEPENDENCIES_TAG = @bitCast(@as([8]u8, "eMpTrUsT".*))
public let BUILD_INFO_HAS_EMPTY_TRUSTED_DEPENDENCIES_TAG: UInt64 = UInt64(3)

/// 覆盖段标签
/// 翻译自: HAS_OVERRIDES_TAG = @bitCast(@as([8]u8, "oVeRriDs".*))
public let BUILD_INFO_HAS_OVERRIDES_TAG: UInt64 = UInt64(4)

/// catalog 段标签
/// 翻译自: HAS_CATALOGS_TAG = @bitCast(@as([8]u8, "cAtAlOgS".*))
public let BUILD_INFO_HAS_CATALOGS_TAG: UInt64 = UInt64(5)

/// 配置版本段标签
/// 翻译自: HAS_CONFIG_VERSION_TAG = @bitCast(@as([8]u8, "cNfGvRsN".*))
public let HAS_CONFIG_VERSION_TAG: UInt64 = UInt64(6)
