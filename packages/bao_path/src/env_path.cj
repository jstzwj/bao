// bao_path - 环境变量路径解析
// 严格翻译自: src/paths/env_path.zig
//   Bun 使用环境变量来定位 home, cache, temp, config 等目录
//   仓颉通过 C FFI 调用 getenv 实现
package bao_path

import bao_core.*
import bao_sys.*

// ============================================================================
// EnvPath - 环境变量路径解析
// 严格翻译自: src/paths/env_path.zig
//   Bun 通过环境变量和 POSIX 约定定位各种系统目录
// ============================================================================

/// 环境变量路径解析器 - 对应 Bun env_path 模块
/// 解析 HOME, XDG_CACHE_HOME, XDG_CONFIG_HOME, TMPDIR 等
public class EnvPath {
    /// 缓存值
    private static var cachedHome: ?String = None
    private static var cachedCacheDir: ?String = None
    private static var cachedConfigDir: ?String = None
    private static var cachedDataDir: ?String = None
    private static var cachedTempDir: ?String = None

    /// 获取用户 HOME 目录
    /// 对应 Bun: EnvPath.home()
    /// 优先使用 HOME 环境变量, 回退到 getpwuid
    public static func home(): String {
        match (cachedHome) {
            case Some(h) => return h
            case None => ()
        }
        let envHome = OS.getEnv("HOME")
        if (let Some(h) = envHome) {
            cachedHome = Some(h)
            return h
        }
        // 回退: 使用 /etc/passwd 查找 (简化)
        let fallback = "/root"
        cachedHome = Some(fallback)
        return fallback
    }

    /// 获取缓存目录
    /// 对应 Bun: EnvPath.cache()
    /// XDG_CACHE_HOME 或 ~/.cache
    public static func cacheDir(): String {
        match (cachedCacheDir) {
            case Some(d) => return d
            case None => ()
        }
        let xdg = OS.getEnv("XDG_CACHE_HOME")
        if (let Some(d) = xdg) {
            if (Path.isAbsolute(d)) {
                cachedCacheDir = Some(d)
                return d
            }
        }
        let dir = Path.join([home(), ".cache"])
        cachedCacheDir = Some(dir)
        return dir
    }

    /// 获取配置目录
    /// 对应 Bun: EnvPath.config()
    /// XDG_CONFIG_HOME 或 ~/.config
    public static func configDir(): String {
        match (cachedConfigDir) {
            case Some(d) => return d
            case None => ()
        }
        let xdg = OS.getEnv("XDG_CONFIG_HOME")
        if (let Some(d) = xdg) {
            if (Path.isAbsolute(d)) {
                cachedConfigDir = Some(d)
                return d
            }
        }
        let dir = Path.join([home(), ".config"])
        cachedConfigDir = Some(dir)
        return dir
    }

    /// 获取数据目录
    /// 对应 Bun: EnvPath.data()
    /// XDG_DATA_HOME 或 ~/.local/share
    public static func dataDir(): String {
        match (cachedDataDir) {
            case Some(d) => return d
            case None => ()
        }
        let xdg = OS.getEnv("XDG_DATA_HOME")
        if (let Some(d) = xdg) {
            if (Path.isAbsolute(d)) {
                cachedDataDir = Some(d)
                return d
            }
        }
        let dir = Path.join([home(), ".local", "share"])
        cachedDataDir = Some(dir)
        return dir
    }

    /// 获取临时目录
    /// 对应 Bun: EnvPath.tmp()
    /// TMPDIR > TMP > TEMP > /tmp
    public static func tempDir(): String {
        match (cachedTempDir) {
            case Some(d) => return d
            case None => ()
        }
        let tmpdir = OS.getEnv("TMPDIR")
        if (let Some(d) = tmpdir) {
            if (!d.isEmpty) {
                cachedTempDir = Some(d)
                return d
            }
        }
        let tmp = OS.getEnv("TMP")
        if (let Some(d) = tmp) {
            if (!d.isEmpty) {
                cachedTempDir = Some(d)
                return d
            }
        }
        let temp = OS.getEnv("TEMP")
        if (let Some(d) = temp) {
            if (!d.isEmpty) {
                cachedTempDir = Some(d)
                return d
            }
        }
        cachedTempDir = Some("/tmp")
        return "/tmp"
    }

    /// 获取 Bao 缓存目录
    /// 对应 Bun: bun.install.cache_dir (默认 ~/.bun)
    public static func baoCacheDir(): String {
        let envDir = OS.getEnv("BAO_INSTALL_CACHE_DIR")
        if (let Some(d) = envDir) {
            return d
        }
        // 回退到 ~/.bao
        return Path.join([home(), ".bao"])
    }

    /// 获取全局 module 目录
    /// 对应 Bun: bun.install.globalModulesDir
    public static func globalModulesDir(): String {
        return Path.join([baoCacheDir(), "install", "global", "node_modules"])
    }

    /// 获取 Bao 配置文件路径
    /// 对应 Bun: bunfig.toml 查找路径
    public static func baofigPath(cwd: String): ?String {
        // 在 cwd 及其父目录查找 baofig.toml
        var dir = cwd
        var depth = 0
        while (depth < 32) {
            let candidate = Path.join([dir, "baofig.toml"])
            if (SysFs.exists(candidate)) {
                return Some(candidate)
            }
            let parent = Path.dirname(dir)
            if (parent == dir) {
                break
            }
            dir = parent
            depth += 1
        }
        return None
    }

    /// 清除缓存 - 用于测试
    public static func clearCache(): Unit {
        cachedHome = None
        cachedCacheDir = None
        cachedConfigDir = None
        cachedDataDir = None
        cachedTempDir = None
    }
}

// ============================================================================
// 平台特定路径处理
// 严格翻译自: src/paths/strings_path.zig
//   Bun 处理 Windows/POSIX 路径差异
//   仓颉当前仅支持 POSIX
// ============================================================================

/// 平台路径工具 - 对应 Bun strings_path
public class PlatformPath {
    /// 检测路径是否为 UNC 路径 (Windows)
    /// \\server\share → true
    public static func isUnc(path: String): Bool {
        return path.size >= 2 &&
               path[0] == Char('\\') &&
               path[1] == Char('\\')
    }

    /// 检测路径是否为 Windows 设备路径
    /// \\.\ or \\?\ → true
    public static func isDevicePath(path: String): Bool {
        return path.size >= 4 &&
               path[0] == Char('\\') &&
               path[1] == Char('\\') &&
               (path[2] == Char('.') || path[2] == Char('?')) &&
               path[3] == Char('\\')
    }

    /// 处理长路径前缀
    /// Windows: 如果路径 > 260 字符, 添加 \\?\ 前缀
    /// POSIX: 直接返回
    public static func handleLongPath(path: String): String {
        return path  // POSIX 无需特殊处理
    }

    /// 规范化路径分隔符
    /// 将所有反斜杠替换为正斜杠 (POSIX)
    public static func normalizeSeparators(path: String): String {
        var result = StringBuilder()
        for (i in 0..path.size) {
            let c = path[Int64(i)]
            if (c == Char('\\')) {
                result.append(Char('/'))
            } else {
                result.append(c)
            }
        }
        return result.toString()
    }

    /// 判断路径是否可能为目录
    /// 以分隔符结尾的路径
    public static func looksLikeDirectory(path: String): Bool {
        if (path.isEmpty) {
            return false
        }
        return path[Int64(path.size - 1)] == Char('/')
    }

    /// 确保路径以分隔符结尾
    public static func ensureTrailingSeparator(path: String): String {
        if (path.isEmpty) {
            return "/"
        }
        if (path[Int64(path.size - 1)] == Char('/')) {
            return path
        }
        return path + "/"
    }

    /// 去除尾部分隔符
    public static func stripTrailingSeparator(path: String): String {
        if (path.size <= 1) {
            return path
        }
        var end = path.size
        while (end > 1 && path[Int64(end - 1)] == Char('/')) {
            end -= 1
        }
        return path.substring(0, Int64(end))
    }

    /// 判断路径是否包含 node_modules 组件
    /// 对应 Bun resolver 检测
    public static func isNodeModules(path: String): Bool {
        return path.contains("/node_modules/")
    }

    /// 从路径中提取 node_modules 的深度
    /// 返回路径中 node_modules 出现的次数
    public static func nodeModulesDepth(path: String): Int64 {
        var depth: Int64 = 0
        var i: Int64 = 0
        while (i < path.size - 14) {
            if (path.substring(Int64(i), Int64(i + 15)) == "/node_modules/") {
                depth += 1
                i += 15
            } else {
                i += 1
            }
        }
        return depth
    }
}
