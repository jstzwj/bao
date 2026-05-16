// bao_core - 环境变量读取/设置工具
// 严格翻译自: src/bun_core/env_var.zig
//   Bun 使用编译时元编程生成类型安全的环境变量访问器
//   支持三种类型: string, boolean, unsigned (u64)
//   带缓存和默认值支持
// 仓颉: 使用运行时缓存 + 类型推断提供等价功能
package bao_core
import std.convert.*

// ============================================================================
// C FFI 声明 - 对应 Bun 中的 getenv/setenv/unsetenv
// ============================================================================

@C
foreign func getenv(name: CPointer<UInt8>): CPointer<UInt8>
@C
foreign func setenv(name: CPointer<UInt8>, value: CPointer<UInt8>, overwrite: Int32): Int32
@C
foreign func unsetenv(name: CPointer<UInt8>): Int32
@C
foreign func getenvSecure(name: CPointer<UInt8>, len: UIntNative, buf: CPointer<UInt8>, bufLen: UIntNative): CPointer<UInt8>

// ============================================================================
// EnvVarType - 环境变量类型
// 对应 Bun env_var.zig 中的 kind 结构
//   const kind = struct {
//       const string = struct { ... };
//       const boolean = struct { ... };
//       const unsigned = struct { ... };
//   };
// ============================================================================

/// 环境变量值类型 - 对应 Bun kind
public enum EnvVarType {
    | String      // 对应 Bun kind.string
    | Boolean     // 对应 Bun kind.boolean
    | Unsigned    // 对应 Bun kind.unsigned (u64)
}

/// 环境变量缓存状态 - 对应 Bun CacheOutput
/// fn CacheOutput(comptime ValueType: type) type {
///     return union(enum) { unknown, not_set, value: ValueType };
/// }
public enum CacheState<T> {
    | Unknown      // 未加载
    | NotSet       // 已加载但未设置
    | Value(T)     // 已加载且有值
}

// ============================================================================
// EnvVar - 单个环境变量定义
// 对应 Bun env_var.zig 中 New() 生成的类型
//   fn New(VariantType, key, opts) type {
//       return struct {
//           var cache: VariantType.Cache(...) = .{};
//           pub fn get() ReturnType { ... }
//           pub fn key() KeyType { ... }
//           pub const default: ... = ...;
//       };
//   }
// ============================================================================

/// 环境变量定义 - 对应 Bun New(kind, "KEY", opts) 生成的类型
/// 支持缓存、默认值、类型转换
public class EnvVar {
    /// 环境变量名
    public let key: String
    /// 变量类型
    public let varType: EnvVarType
    /// 字符串默认值
    public let defaultString: ?String
    /// 布尔默认值
    public let defaultBool: ?Bool
    /// 无符号整数默认值
    public let defaultUnsigned: ?UInt64
    /// 缓存状态
    private var cachedString: ?String
    private var cachedBool: ?Bool
    private var cachedUnsigned: ?UInt64
    /// 是否已缓存
    private var isCached: Bool

    /// 创建字符串类型环境变量 - 对应 Bun New(kind.string, "KEY", .{ .default = "..." })
    public init(key: String, default: ?String) {
        this.key = key
        this.varType = EnvVarType.String
        this.defaultString = default
        this.defaultBool = None
        this.defaultUnsigned = None
        this.cachedString = None
        this.cachedBool = None
        this.cachedUnsigned = None
        this.isCached = false
    }

    /// 创建布尔类型环境变量 - 对应 Bun New(kind.boolean, "KEY", .{ .default = false })
    public init(key: String, default: Bool) {
        this.key = key
        this.varType = EnvVarType.Boolean
        this.defaultString = None
        this.defaultBool = Some(default)
        this.defaultUnsigned = None
        this.cachedString = None
        this.cachedBool = None
        this.cachedUnsigned = None
        this.isCached = false
    }

    /// 创建无符号整数类型环境变量 - 对应 Bun New(kind.unsigned, "KEY", .{ .default = 30 })
    public init(key: String, default: UInt64) {
        this.key = key
        this.varType = EnvVarType.Unsigned
        this.defaultString = None
        this.defaultBool = None
        this.defaultUnsigned = Some(default)
        this.cachedString = None
        this.cachedBool = None
        this.cachedUnsigned = None
        this.isCached = false
    }

    /// 创建无默认值的环境变量
    public init(key: String, `type`: EnvVarType) {
        this.key = key
        this.varType = `type`
        this.defaultString = None
        this.defaultBool = None
        this.defaultUnsigned = None
        this.cachedString = None
        this.cachedBool = None
        this.cachedUnsigned = None
        this.isCached = false
    }

    /// 获取字符串值 - 对应 Bun .get() for string
    /// pub fn get() ReturnType {
    ///     switch (cache.getCached()) {
    ///         .unknown => { return getForceReload(); },
    ///         .not_set => { if (opts.default) |d| return d; return null; },
    ///         .value => |v| { return v; },
    ///     }
    /// }
    public func getString(): ?String {
        if (isCached) {
            match (cachedString) {
                case Some(v) => return Some(v)
                case None => return defaultString
            }
        }
        let raw = getRawEnv(key)
        if (raw.size > 0) {
            cachedString = Some(raw)
            isCached = true
            return Some(raw)
        }
        // 检查环境变量是否存在 (空字符串 vs 不存在)
        let exists = envExists(key)
        if (exists) {
            cachedString = Some("")
            isCached = true
            return Some("")
        }
        cachedString = None
        isCached = true
        return defaultString
    }

    /// 获取非空字符串值 - 对应 Bun .getNotEmpty()
    /// pub fn getNotEmpty() ReturnType {
    ///     if (Self.get()) |v| { if (v.len == 0) return null; return v; }
    ///     return null;
    /// }
    public func getStringNotEmpty(): ?String {
        match (getString()) {
            case Some(v) =>
                if (v.size == 0) { return None }
                return Some(v)
            case None => return None
        }
    }

    /// 获取布尔值 - 对应 Bun .get() for boolean
    /// 布尔值判断规则 (对应 Bun stringIsTruthy):
    ///   "", "0", "false", "no", "off" -> false
    ///   其他 -> true
    /// fn stringIsTruthy(s: []const u8) bool {
    ///     const false_values = .{ "", "0", "false", "no", "off" };
    ///     inline for (false_values) |tv| {
    ///         if (std.ascii.eqlIgnoreCase(s, tv)) return false;
    ///     }
    ///     return true;
    /// }
    public func getBool(): ?Bool {
        if (isCached && cachedBool.isSome()) {
            return cachedBool
        }
        let raw = getRawEnv(key)
        if (raw.size > 0) {
            let truthy = stringIsTruthy(raw)
            cachedBool = Some(truthy)
            isCached = true
            return Some(truthy)
        }
        let exists = envExists(key)
        if (exists) {
            let truthy = stringIsTruthy(raw)
            cachedBool = Some(truthy)
            isCached = true
            return Some(truthy)
        }
        cachedBool = defaultBool
        isCached = true
        return defaultBool
    }

    /// 获取无符号整数值 - 对应 Bun .get() for unsigned
    public func getUnsigned(): ?UInt64 {
        if (isCached && cachedUnsigned.isSome()) {
            return cachedUnsigned
        }
        let raw = getRawEnv(key)
        if (raw.size > 0) {
            try {
                let value = UInt64.parse(raw)
                cachedUnsigned = Some(value)
                isCached = true
                return Some(value)
            } catch (_: Exception) {
                // 解析失败, 返回默认值
                cachedUnsigned = defaultUnsigned
                isCached = true
                return defaultUnsigned
            }
        }
        cachedUnsigned = defaultUnsigned
        isCached = true
        return defaultUnsigned
    }

    /// 强制重新加载 - 对应 Bun getForceReload()
    public func forceReload(): Unit {
        isCached = false
        cachedString = None
        cachedBool = None
        cachedUnsigned = None
    }

    /// 获取键名 - 对应 Bun .key()
    public func getKey(): String {
        return key
    }

    /// 获取默认值 (字符串形式)
    public func getDefault(): ?String {
        return defaultString
    }

    // ========================================================================
    // 静态方法 - 直接访问环境变量 (不缓存)
    // ========================================================================

    /// 直接获取环境变量 - 对应 Bun bun.getenvZ
    public static func get(name: String): ?String {
        let raw = getRawEnv(name)
        if (raw.size > 0) {
            return Some(raw)
        }
        if (envExists(name)) {
            return Some("")
        }
        return None
    }

    /// 设置环境变量 - 对应 Bun bun.setenv
    public static func set(name: String, value: String): Bool {
        unsafe {
            let namePtr = stringToCPtr(name)
            let valuePtr = stringToCPtr(value)
            let result = setenv(namePtr, valuePtr, Int32(1))
            return result == 0
        }
    }

    /// 删除环境变量 - 对应 Bun bun.unsetenv
    public static func unset(name: String): Bool {
        unsafe {
            let namePtr = stringToCPtr(name)
            let result = unsetenv(namePtr)
            return result == 0
        }
    }

    /// 判断字符串是否为真 - 对应 Bun kind.boolean.stringIsTruthy
    /// fn stringIsTruthy(s: []const u8) bool {
    ///     const false_values = .{ "", "0", "false", "no", "off" };
    ///     inline for (false_values) |tv| {
    ///         if (std.ascii.eqlIgnoreCase(s, tv)) return false;
    ///     }
    ///     return true;
    /// }
    public static func stringIsTruthy(s: String): Bool {
        let lower = s.toAsciiLower()
        if (lower == "" || lower == "0" || lower == "false" || lower == "no" || lower == "off") {
            return false
        }
        return true
    }

    // ========================================================================
    // 内部辅助
    // ========================================================================

    /// 获取原始环境变量值
    private static func getRawEnv(name: String): String {
        unsafe {
            let namePtr = stringToCPtr(name)
            let valuePtr = getenv(namePtr)
            if (valuePtr.isNull()) {
                return ""
            }
            return cPtrToString(valuePtr)
        }
    }

    /// 检查环境变量是否存在
    private static func envExists(name: String): Bool {
        unsafe {
            let namePtr = stringToCPtr(name)
            let valuePtr = getenv(namePtr)
            return !valuePtr.isNull()
        }
    }

    /// String -> C 指针 (null 终止)
    private static func stringToCPtr(s: String): CPointer<UInt8> {
        unsafe {
            let arr = s.toArray()
            let len = Int64(arr.size)
            let ptr = malloc(UIntNative(len + 1))
            let bytePtr = CPointer<UInt8>(ptr)
            for (i in 0..len) {
                (bytePtr + i).write(arr[i])
            }
            (bytePtr + len).write(UInt8(0))
            return bytePtr
        }
    }

    /// C 指针 -> String (读到 null 终止)
    private static func cPtrToString(ptr: CPointer<UInt8>): String {
        unsafe {
            var sb = StringBuilder()
            var i = 0
            while (true) {
                let b = (ptr + Int64(i)).read()
                if (b == UInt8(0)) {
                    break
                }
                sb.append(Rune(Int32(b)))
                i += 1
            }
            return sb.toString()
        }
    }
}

// ============================================================================
// Env - 全局环境变量访问器
// 对应 Bun env_var.zig 中导出的常量
//   pub const HOME = PlatformSpecificNew(kind.string, "HOME", "USERPROFILE", .{});
//   pub const PATH = New(kind.string, "PATH", .{});
//   pub const CI = New(kind.boolean, "CI", .{});
//   ...
// ============================================================================

/// 全局环境变量访问器 - 对应 Bun env_var 模块导出
/// 提供常用环境变量的类型安全访问
public class Env {
    // 字符串类型环境变量 - 对应 Bun New(kind.string, "KEY", .{})

    /// PATH 环境变量
    public static let PATH = EnvVar("PATH", EnvVarType.String)
    /// HOME 环境变量 (POSIX) / USERPROFILE (Windows)
    /// 对应 Bun: pub const HOME = PlatformSpecificNew(kind.string, "HOME", "USERPROFILE", .{});
    public static let HOME = EnvVar("HOME", EnvVarType.String)
    /// 用户名 - 对应 Bun USER
    public static let USER = EnvVar("USER", EnvVarType.String)
    /// SHELL
    public static let SHELL = EnvVar("SHELL", EnvVarType.String)
    /// 临时目录 - 对应 Bun TMPDIR
    public static let TMPDIR = EnvVar("TMPDIR", EnvVarType.String)
    /// 终端类型
    public static let TERM = EnvVar("TERM", EnvVarType.String)
    /// 终端程序
    public static let TERM_PROGRAM = EnvVar("TERM_PROGRAM", EnvVarType.String)
    /// BUN 安装路径
    public static let BAO_INSTALL = EnvVar("BAO_INSTALL", EnvVarType.String)
    /// BAO 调试
    public static let BAO_DEBUG = EnvVar("BAO_DEBUG", EnvVarType.String)
    /// 编辑器
    public static let EDITOR = EnvVar("EDITOR", EnvVarType.String)
    /// 语言
    public static let LANG = EnvVar("LANG", EnvVarType.String)
    /// Node 相关
    public static let NODE_ENV = EnvVar("NODE_ENV", EnvVarType.String)

    // 布尔类型环境变量 - 对应 Bun New(kind.boolean, "KEY", .{ .default = false })

    /// CI 环境 - 对应 Bun pub const CI = New(kind.boolean, "CI", .{});
    public static let CI = EnvVar("CI", false)
    /// 不使用颜色 - 对应 Bun NO_COLOR
    public static let NO_COLOR = EnvVar("NO_COLOR", false)
    /// 强制颜色
    public static let FORCE_COLOR = EnvVar("FORCE_COLOR", UInt64(0))
    /// GitHub Actions
    public static let GITHUB_ACTIONS = EnvVar("GITHUB_ACTIONS", false)
    /// 跟踪
    public static let DO_NOT_TRACK = EnvVar("DO_NOT_TRACK", false)

    // ========================================================================
    // 便捷方法
    // ========================================================================

    /// 获取字符串环境变量 - 对应 Bun bun.getenvZ
    public static func get(name: String): ?String {
        return EnvVar.get(name)
    }

    /// 获取字符串环境变量 (带默认值)
    public static func get(name: String, defaultValue: String): String {
        match (EnvVar.get(name)) {
            case Some(v) =>
                if (v.size == 0) { return defaultValue }
                return v
            case None => return defaultValue
        }
    }

    /// 获取布尔环境变量
    public static func getBool(name: String): Bool {
        let raw = Env.get(name)
        match (raw) {
            case Some(v) => return EnvVar.stringIsTruthy(v)
            case None => return false
        }
    }

    /// 获取布尔环境变量 (带默认值)
    public static func getBool(name: String, defaultValue: Bool): Bool {
        let raw = Env.get(name)
        match (raw) {
            case Some(v) => return EnvVar.stringIsTruthy(v)
            case None => return defaultValue
        }
    }

    /// 获取整数环境变量
    public static func getInt(name: String): ?Int64 {
        let raw = Env.get(name)
        match (raw) {
            case Some(v) =>
                try {
                    return Some(Int64.parse(v))
                } catch (_: Exception) {
                    return None
                }
            case None => return None
        }
    }

    /// 获取整数环境变量 (带默认值)
    public static func getInt(name: String, defaultValue: Int64): Int64 {
        match (getInt(name)) {
            case Some(v) => return v
            case None => return defaultValue
        }
    }

    /// 设置环境变量 - 对应 Bun bun.setenv
    public static func set(name: String, value: String): Bool {
        return EnvVar.set(name, value)
    }

    /// 删除环境变量 - 对应 Bun bun.unsetenv
    public static func unset(name: String): Bool {
        return EnvVar.unset(name)
    }

    /// 获取 HOME 目录 - 便捷方法
    public static func getHome(): String {
        return get("HOME", "")
    }

    /// 获取 PATH - 便捷方法
    public static func getPath(): String {
        return get("PATH", "")
    }

    /// 获取临时目录 - 便捷方法
    /// 对应 Bun: 依次检查 TMPDIR, TMP, TEMP
    public static func getTmpDir(): String {
        let tmpdir = get("TMPDIR", "")
        if (tmpdir.size > 0) { return tmpdir }
        let tmp = get("TMP", "")
        if (tmp.size > 0) { return tmp }
        let temp = get("TEMP", "")
        if (temp.size > 0) { return temp }
        return "/tmp"
    }

    /// 是否在 CI 环境中运行
    public static func isCI(): Bool {
        return CI.getBool().getOrThrow()
    }

    /// 是否支持颜色输出
    public static func isColorSupported(): Bool {
        let noColor = getBool("NO_COLOR", false)
        if (noColor) { return false }
        let forceColor = get("FORCE_COLOR")
        if (forceColor.isSome()) { return true }
        let term = get("TERM", "")
        return term != "dumb"
    }

    /// 是否在 DEBUG 模式
    public static func isDebug(): Bool {
        return getBool("BAO_DEBUG", false)
    }
}
