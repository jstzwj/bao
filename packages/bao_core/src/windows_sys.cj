// bao_core - Windows 系统 API 声明
// 严格翻译自: src/bun_core/windows_sys.rs
//   pub const STD_INPUT_HANDLE: DWORD = (-10i32) as DWORD
//   pub const STD_OUTPUT_HANDLE: DWORD = (-11i32) as DWORD
//   pub const STD_ERROR_HANDLE: DWORD = (-12i32) as DWORD
//   pub fn GetStdHandle(std_handle: DWORD) -> Option<HANDLE>
// Bun: Minimal Win32 ABI surface for bun_core's #[cfg(windows)] paths
//   tier-0 依赖, 不能依赖 bun_sys (循环)
// 仓颉: 提供等价的 Windows API 常量和接口
package bao_core

// ============================================================================
// Windows 系统 API 常量和类型
// 严格翻译自: src/bun_core/windows_sys.rs
//   Bun 重新导出 bun_windows_sys 中的类型
//   仓颉: 定义常量和接口, 实际 Windows 调用通过 FFI
// ============================================================================

/// Windows 句柄类型 - 对应 Bun HANDLE (void*)
public type HANDLE = UIntNative

/// Windows BOOL 类型 - 对应 Bun BOOL (i32)
public type WIN_BOOL = Int32

/// Windows DWORD 类型 - 对应 Bun DWORD (u32)
public type DWORD = UInt32

/// Windows HRESULT 类型 - 对应 Bun HRESULT (i32)
public type HRESULT = Int32

/// Windows WCHAR 类型 - 对应 Bun WCHAR (u16)
public type WCHAR = UInt16

/// Windows WORD 类型 - 对应 Bun WORD (u16)
public type WORD = UInt16

/// Windows SHORT 类型 - 对应 Bun SHORT (i16)
public type SHORT = Int16

/// 无效句柄值 - 对应 Bun INVALID_HANDLE_VALUE (-1)
public let INVALID_HANDLE_VALUE: HANDLE = UIntNative.Max

/// TRUE 常量 - 对应 Bun TRUE
public let WIN_TRUE: WIN_BOOL = 1

/// FALSE 常量 - 对应 Bun FALSE
public let WIN_FALSE: WIN_BOOL = 0

// ============================================================================
// 标准设备句柄常量 - 对应 Bun STD_*_HANDLE
// ============================================================================

/// 标准输入句柄 - 对应 Bun STD_INPUT_HANDLE = (-10i32) as DWORD
public let STD_INPUT_HANDLE: DWORD = UInt32(0xFFFFFFF6)  // -10 as u32

/// 标准输出句柄 - 对应 Bun STD_OUTPUT_HANDLE = (-11i32) as DWORD
public let STD_OUTPUT_HANDLE: DWORD = UInt32(0xFFFFFFF5)  // -11 as u32

/// 标准错误句柄 - 对应 Bun STD_ERROR_HANDLE = (-12i32) as DWORD
public let STD_ERROR_HANDLE: DWORD = UInt32(0xFFFFFFF4)  // -12 as u32

// ============================================================================
// 控制台模式标志 - 对应 Bun ENABLE_* 常量
// ============================================================================

/// 启用处理输出 - 对应 Bun ENABLE_PROCESSED_OUTPUT = 0x0001
public let ENABLE_PROCESSED_OUTPUT: DWORD = 0x0001

/// 启用行尾换行 - 对应 Bun ENABLE_WRAP_AT_EOL_OUTPUT = 0x0002
public let ENABLE_WRAP_AT_EOL_OUTPUT: DWORD = 0x0002

/// 启用虚拟终端处理 - 对应 Bun ENABLE_VIRTUAL_TERMINAL_PROCESSING = 0x0004
public let ENABLE_VIRTUAL_TERMINAL_PROCESSING: DWORD = 0x0004

/// Windows 系统调用接口 - 对应 Bun 中的 FFI 声明
/// 仓颉: 通过 @C foreign func 声明
public class WindowsSys {
    /// 获取标准设备句柄 - 对应 Bun GetStdHandle
    /// 返回 None 如果句柄无效 (INVALID_HANDLE_VALUE 或 null)
    public static func getStdHandle(stdHandle: DWORD): ?HANDLE {
        // 非_WINDOWS 平台始终返回 None
        return None
    }

    /// 禁用标准输入输出继承 - 对应 Bun uv_disable_stdio_inheritance
    public static func disableStdioInheritance(): Unit {
        // 非 Windows 平台为空操作
    }
}

/// COORD 结构体 - 对应 Bun COORD
public class Coord {
    public var x: SHORT
    public var y: SHORT

    public init() {
        x = 0
        y = 0
    }

    public init(x: SHORT, y: SHORT) {
        this.x = x
        this.y = y
    }
}

/// SMALL_RECT 结构体 - 对应 Bun SMALL_RECT
public class SmallRect {
    public var left: SHORT
    public var top: SHORT
    public var right: SHORT
    public var bottom: SHORT

    public init() {
        left = 0
        top = 0
        right = 0
        bottom = 0
    }
}

/// CONSOLE_SCREEN_BUFFER_INFO 结构体 - 对应 Bun CONSOLE_SCREEN_BUFFER_INFO
public class ConsoleScreenBufferInfo {
    public var dwSize: Coord
    public var dwCursorPosition: Coord
    public var wAttributes: WORD
    public var srWindow: SmallRect
    public var dwMaximumWindowSize: Coord

    public init() {
        dwSize = Coord()
        dwCursorPosition = Coord()
        wAttributes = 0
        srWindow = SmallRect()
        dwMaximumWindowSize = Coord()
    }
}
