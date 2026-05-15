// 严格翻译自: src/bun_core/tty.zig
//   pub const Mode = enum(c_int) { normal = 0, raw = 1, io = 2 };
//   pub fn setMode(fd: c_int, mode: Mode) c_int { return Bun__ttySetMode(fd, @intFromEnum(mode)); }
//   extern fn Bun__ttySetMode(fd: c_int, mode: c_int) c_int;
package bao_core

// ============================================================================
// C FFI 声明
// ============================================================================

@C
foreign func Bun__ttySetMode(fd: Int32, mode: Int32): Int32

// ============================================================================
// TtyMode - TTY 模式
// 严格翻译自: src/bun_core/tty.zig:1-5
//   pub const Mode = enum(c_int) { normal = 0, raw = 1, io = 2 };
// ============================================================================

/// TTY 模式枚举 - 对应 Bun Mode
/// pub const Mode = enum(c_int) {
///     normal = 0,
///     raw = 1,
///     io = 2,
/// };
public enum TtyMode {
    | Normal   // 对应 Bun normal = 0
    | Raw      // 对应 Bun raw = 1
    | IO       // 对应 Bun io = 2

    /// 转为整数值 - 对应 Bun @intFromEnum(mode)
    public func toInt32(): Int32 {
        match (this) {
            case Normal => return Int32(0)
            case Raw => return Int32(1)
            case IO => return Int32(2)
        }
    }

    /// 从整数值创建 - 对应反向转换
    public static func fromInt32(value: Int32): ?TtyMode {
        if (value == Int32(0)) { return Some(TtyMode.Normal) }
        if (value == Int32(1)) { return Some(TtyMode.Raw) }
        if (value == Int32(2)) { return Some(TtyMode.IO) }
        return None
    }
}

// ============================================================================
// Tty - TTY 工具函数
// 严格翻译自: src/bun_core/tty.zig:7-11
//   pub fn setMode(fd: c_int, mode: Mode) c_int {
//       return Bun__ttySetMode(fd, @intFromEnum(mode));
//   }
//   extern fn Bun__ttySetMode(fd: c_int, mode: c_int) c_int;
// ============================================================================

/// TTY 工具函数 - 对应 Bun tty 模块
public class Tty {
    /// 设置 TTY 模式 - 对应 Bun setMode()
    /// pub fn setMode(fd: c_int, mode: Mode) c_int {
    ///     return Bun__ttySetMode(fd, @intFromEnum(mode));
    /// }
    public static func setMode(fd: Int32, mode: TtyMode): Int32 {
        return Bun__ttySetMode(fd, mode.toInt32())
    }

    /// 设置 TTY 为正常模式
    public static func setNormal(fd: Int32): Int32 {
        return setMode(fd, TtyMode.Normal)
    }

    /// 设置 TTY 为原始模式
    public static func setRaw(fd: Int32): Int32 {
        return setMode(fd, TtyMode.Raw)
    }

    /// 设置 TTY 为 IO 模式
    public static func setIO(fd: Int32): Int32 {
        return setMode(fd, TtyMode.IO)
    }
}
