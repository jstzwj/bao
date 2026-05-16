// bao_sys - TTY / 终端操作
// 严格翻译自: Bun TTY 相关操作
//   Bun 通过 uv_guess_handle 和 termios 控制终端行为
//   提供 isatty(), 终端大小获取, raw/cooked 模式切换
//   用于 Bun REPL 和交互式终端功能
package bao_sys

import bao_core.*

// ============================================================================
// TTY 相关 C FFI 声明
// ============================================================================

@C
foreign func isatty(fd: Int32): Int32
@C
foreign func tcgetattr(fd: Int32, termios_p: CPointer<Unit>): Int32
@C
foreign func tcsetattr(fd: Int32, optional_actions: Int32, termios_p: CPointer<Unit>): Int32
@C
foreign func ioctl(fd: Int32, request: UIntNative, ...: CPointer<Unit>): Int32

// ============================================================================
// termios 常量
// 对应 Linux termios.h
// ============================================================================

/// tcsetattr 操作常量
public class TcSetAttrFlags {
    /// 立即更改 - TCSANOW = 0
    public static let TCSANOW: Int32 = 0
    /// 排空输出后更改 - TCSADRAIN = 1
    public static let TCSADRAIN: Int32 = 1
    /// 排空输出并丢弃输入后更改 - TCSAFLUSH = 2
    public static let TCSAFLUSH: Int32 = 2
}

/// termios 本地模式标志 (c_lflag)
/// 对应 Linux bits/termios.h c_lflag 常量
public class LocalFlags {
    /// 回显输入 - ECHO = 0x00000008
    public static let ECHO: UInt32 = 0x00000008
    /// 回显擦除字符 - ECHOE = 0x00000010
    public static let ECHOE: UInt32 = 0x00000010
    /// 回显杀死行 - ECHOK = 0x00000020
    public static let ECHOK: UInt32 = 0x00000020
    /// 规范模式 (行缓冲) - ICANON = 0x00000002
    public static let ICANON: UInt32 = 0x00000002
    /// 信号产生 - ISIG = 0x00000001
    public static let ISIG: UInt32 = 0x00000001
    /// 扩展处理 - IEXTEN = 0x00008000
    public static let IEXTEN: UInt32 = 0x00008000
    /// 规范大小写 - XCASE = 0x00000004 (已弃用)
    public static let XCASE: UInt32 = 0x00000004
    /// 无刷新输出 - NOFLSH = 0x00000080
    public static let NOFLSH: UInt32 = 0x00000080
    /// 刷新后挂起 - TOSTOP = 0x00000100
    public static let TOSTOP: UInt32 = 0x00000100
}

/// termios 输入模式标志 (c_iflag)
public class InputFlags {
    /// 中断信号 - BRKINT = 0x00000002
    public static let BRKINT: UInt32 = 0x00000002
    /// 将 CR 映射为 NL - ICRNL = 0x00000100
    public static let ICRNL: UInt32 = 0x00000100
    /// 忽略中断 - IGNBRK = 0x00000001
    public static let IGNBRK: UInt32 = 0x00000001
    /// 忽略 CR - IGNCR = 0x00000080
    public static let IGNCR: UInt32 = 0x00000080
    /// 忽略parity错误 - IGNPAR = 0x00000004
    public static let IGNPAR: UInt32 = 0x00000004
    /// 剥离第8位 - ISTRIP = 0x00000020
    public static let ISTRIP: UInt32 = 0x00000020
    /// IXON - 启动输出控制
    public static let IXON: UInt32 = 0x00000400
    /// IXOFF - 启动输入控制
    public static let IXOFF: UInt32 = 0x00001000
    /// IXANY - 任意字符重启输出
    public static let IXANY: UInt32 = 0x00000800
    /// INLCR - 将 NL 映射为 CR
    public static let INLCR: UInt32 = 0x00000040
}

/// termios 输出模式标志 (c_oflag)
public class OutputFlags {
    /// 输出处理 - OPOST = 0x00000001
    public static let OPOST: UInt32 = 0x00000001
    /// 将 NL 映射为 CR-NL - ONLCR = 0x00000004
    public static let ONLCR: UInt32 = 0x00000004
    /// OCRNL - 将 CR 映射为 NL
    public static let OCRNL: UInt32 = 0x00000008
}

/// termios 控制模式标志 (c_cflag)
public class ControlFlags {
    /// 字符大小掩码 - CSIZE = 0x00000030
    public static let CSIZE: UInt32 = 0x00000030
    /// 8 位字符 - CS8 = 0x00000030
    public static let CS8: UInt32 = 0x00000030
    /// 启用接收 - CREAD = 0x00000080
    public static let CREAD: UInt32 = 0x00000080
    /// 忽略调制解调器控制线 - CLOCAL = 0x00000800
    public static let CLOCAL: UInt32 = 0x00000800
}

/// 特殊字符索引 (c_cc)
public class SpecialChars {
    /// VMIN = 6
    public static let VMIN: Int32 = 6
    /// VTIME = 5
    public static let VTIME: Int32 = 5
    /// VEOF = 4
    public static let VEOF: Int32 = 4
    /// VINTR = 0
    public static let VINTR: Int32 = 0
    /// VQUIT = 1
    public static let VQUIT: Int32 = 1
    /// VERASE = 2
    public static let VERASE: Int32 = 2
    /// VKILL = 3
    public static let VKILL: Int32 = 3
    /// VSTART = 8
    public static let VSTART: Int32 = 8
    /// VSTOP = 9
    public static let VSTOP: Int32 = 9
    /// VSUSP = 10
    public static let VSUSP: Int32 = 10
}

/// ioctl 请求常量
public class IoctlRequest {
    /// 获取终端窗口大小 - TIOCGWINSZ
    /// Linux x86_64: _IOR('T', 104, struct winsize)
    public static let TIOCGWINSZ: UIntNative = 0x00005413
}

// ============================================================================
// Termios - 终端属性
// 对应 struct termios
//   { c_iflag, c_oflag, c_cflag, c_lflag, c_cc[NCCS], c_ispeed, c_ospeed }
// ============================================================================

/// 终端属性 - 对应 struct termios
/// 保存终端的完整配置状态
/// Linux struct termios 布局:
///   c_iflag: UInt32    offset 0
///   c_oflag: UInt32    offset 4
///   c_cflag: UInt32    offset 8
///   c_lflag: UInt32    offset 12
///   c_cc[32]: Array<UInt8>  offset 16
///   总大小: 48-60 字节 (取决于平台)
public class Termios {
    /// 输入模式标志
    public var iflag: UInt32
    /// 输出模式标志
    public var oflag: UInt32
    /// 控制模式标志
    public var cflag: UInt32
    /// 本地模式标志
    public var lflag: UInt32
    /// 特殊字符数组 (NCCS = 32)
    public var cc: Array<UInt8>

    public init() {
        iflag = 0
        oflag = 0
        cflag = 0
        lflag = 0
        cc = Array<UInt8>(32, item: UInt8(0))
    }

    /// 从文件描述符读取当前属性
    /// 对应: tcgetattr(fd, &termios)
    public static func getattr(fd: Int64): SysMaybe<Termios> {
        unsafe {
            // 分配足够大的缓冲区存放 struct termios
            let buf = malloc(UIntNative(256))
            let rc = tcgetattr(Int32(fd), buf)
            if (rc != 0) {
                free(buf)
                return SysMaybe<Termios>.Err(
                    SysError(UInt16(Int64(OS.errno())), SysTag.Tcgetattr)
                )
            }
            let t = Termios()
            // 读取各字段 (按 Linux x86_64 布局)
            let base = CPointer<UInt32>(buf)
            t.iflag = UInt32(base.read())
            t.oflag = UInt32((base + IntNative(1)).read())
            t.cflag = UInt32((base + IntNative(2)).read())
            t.lflag = UInt32((base + IntNative(3)).read())
            // 读取 c_cc (offset 16)
            let ccBase = CPointer<UInt8>(buf) + IntNative(16)
            for (i in 0..32) {
                t.cc[Int64(i)] = (ccBase + IntNative(i)).read()
            }
            free(buf)
            return SysMaybe<Termios>.Ok(t)
        }
    }

    /// 应用属性到文件描述符
    /// 对应: tcsetattr(fd, TCSANOW, &termios)
    public func setattr(fd: Int64, action: Int32): SysMaybe<Unit> {
        unsafe {
            let buf = malloc(UIntNative(256))
            // 写入各字段
            let base = CPointer<UInt32>(buf)
            base.write(Int32(iflag))
            (base + IntNative(1)).write(Int32(oflag))
            (base + IntNative(2)).write(Int32(cflag))
            (base + IntNative(3)).write(Int32(lflag))
            // 写入 c_cc
            let ccBase = CPointer<UInt8>(buf) + IntNative(16)
            for (i in 0..32) {
                (ccBase + IntNative(i)).write(cc[Int64(i)])
            }
            let rc = tcsetattr(Int32(fd), action, buf)
            free(buf)
            if (rc != 0) {
                return SysMaybe<Unit>.Err(
                    SysError(UInt16(Int64(OS.errno())), SysTag.Tcsetattr)
                )
            }
            return SysMaybe<Unit>.Ok(())
        }
    }

    /// 设置为 raw 模式 - 对应 cfmakeraw()
    /// Raw 模式: 无回显, 无规范处理, 无信号, 无特殊字符处理
    /// Bun REPL 使用 raw 模式读取按键
    public func makeRaw(): Termios {
        let raw = Termios()
        raw.iflag = iflag & ~(InputFlags.BRKINT | InputFlags.ICRNL | InputFlags.INPCK
            | InputFlags.ISTRIP | InputFlags.IXON)
        raw.oflag = oflag & ~(OutputFlags.OPOST)
        raw.cflag = cflag | ControlFlags.CS8
        raw.lflag = lflag & ~(LocalFlags.ECHO | LocalFlags.ICANON | LocalFlags.IEXTEN
            | LocalFlags.ISIG)
        // VMIN=1, VTIME=0: 等待至少一个字符
        raw.cc = Array<UInt8>(cc)
        raw.cc[Int64(SpecialChars.VMIN)] = UInt8(1)
        raw.cc[Int64(SpecialChars.VTIME)] = UInt8(0)
        return raw
    }

    /// 设置为 cooked 模式 (规范模式)
    /// 恢复行缓冲、回显、信号处理等默认行为
    public func makeCooked(): Termios {
        let cooked = Termios()
        cooked.iflag = iflag | InputFlags.BRKINT | InputFlags.ICRNL | InputFlags.IXON
        cooked.oflag = oflag | OutputFlags.OPOST | OutputFlags.ONLCR
        cooked.cflag = cflag | ControlFlags.CS8 | ControlFlags.CREAD
        cooked.lflag = lflag | LocalFlags.ECHO | LocalFlags.ICANON | LocalFlags.ISIG
            | LocalFlags.IEXTEN
        cooked.cc = Array<UInt8>(cc)
        return cooked
    }
}

// ============================================================================
// TerminalSize - 终端窗口大小
// 对应 struct winsize { ws_row, ws_col, ws_xpixel, ws_ypixel }
// ============================================================================

/// 终端窗口大小 - 对应 struct winsize
public class TerminalSize {
    /// 行数 (字符)
    public var rows: Int64
    /// 列数 (字符)
    public var cols: Int64
    /// 宽度 (像素)
    public var xpixel: Int64
    /// 高度 (像素)
    public var ypixel: Int64

    public init(rows: Int64, cols: Int64) {
        this.rows = rows
        this.cols = cols
        this.xpixel = 0
        this.ypixel = 0
    }

    public init(rows: Int64, cols: Int64, xpixel: Int64, ypixel: Int64) {
        this.rows = rows
        this.cols = cols
        this.xpixel = xpixel
        this.ypixel = ypixel
    }

    /// 获取终端大小
    /// 对应: ioctl(fd, TIOCGWINSZ, &ws)
    public static func get(fd: Int64): SysMaybe<TerminalSize> {
        unsafe {
            // struct winsize { unsigned short ws_row, ws_col, ws_xpixel, ws_ypixel }
            // 8 字节总共
            let buf = malloc(UIntNative(8))
            let rc = ioctl(Int32(fd), IoctlRequest.TIOCGWINSZ, buf)
            if (rc != 0) {
                free(buf)
                return SysMaybe<TerminalSize>.Err(
                    SysError(UInt16(Int64(OS.errno())), SysTag.Ioctl)
                )
            }
            // 读取 winsize 字段 (unsigned short = UInt16)
            let base = CPointer<UInt16>(buf)
            let rows = Int64(base.read())
            let cols = Int64((base + IntNative(1)).read())
            let xpixel = Int64((base + IntNative(2)).read())
            let ypixel = Int64((base + IntNative(3)).read())
            free(buf)
            return SysMaybe<TerminalSize>.Ok(TerminalSize(rows, cols, xpixel, ypixel))
        }
    }

    /// 获取标准输出终端大小
    public static func getStdout(): SysMaybe<TerminalSize> {
        return get(1)
    }

    public func toString(): String {
        return "${rows}x${cols}"
    }
}

// ============================================================================
// TTY - TTY 操作封装
// 严格翻译自: Bun TTY 相关功能
//   Bun 使用 libuv uv_tty_t 和 termios 控制 TTY
//   用于 REPL、交互式 CLI、进度条等
// ============================================================================

/// TTY 操作封装 - 对应 Bun TTY 功能
/// 提供终端状态查询和模式切换
public class TTY {
    /// 文件描述符
    public var fd: Int64
    /// 原始终端属性 (用于恢复)
    private var originalTermios: ?Termios
    /// 是否处于 raw 模式
    private var inRawMode: Bool

    public init(fd: Int64) {
        this.fd = fd
        this.originalTermios = None
        this.inRawMode = false
    }

    /// 是否为 TTY
    /// 对应: isatty(fd) != 0
    /// Bun: uv_guess_handle(fd) == UV_TTY
    public func isTty(): Bool {
        return isatty(Int32(fd)) != 0
    }

    /// 获取终端大小
    /// 对应 Bun: process.stdout.columns / process.stdout.rows
    public func getSize(): SysMaybe<TerminalSize> {
        return TerminalSize.get(fd)
    }

    /// 进入 raw 模式
    /// 对应 Bun: process.stdin.setRawMode(true)
    /// 保存当前属性，然后切换到 raw 模式
    public func setRawMode(raw: Bool): SysMaybe<Unit> {
        if (raw) {
            // 保存当前属性
            match (Termios.getattr(fd)) {
                case Err(e) => return SysMaybe<Unit>.Err(e)
                case Ok(t) =>
                    originalTermios = Some(t)
                    let rawTermios = t.makeRaw()
                    match (rawTermios.setattr(fd, TcSetAttrFlags.TCSAFLUSH)) {
                        case Err(e) => return SysMaybe<Unit>.Err(e)
                        case Ok(_) =>
                            inRawMode = true
                            return SysMaybe<Unit>.Ok(())
                    }
            }
        } else {
            // 恢复原始属性
            match (originalTermios) {
                case Some(t) =>
                    match (t.setattr(fd, TcSetAttrFlags.TCSAFLUSH)) {
                        case Err(e) => return SysMaybe<Unit>.Err(e)
                        case Ok(_) =>
                            inRawMode = false
                            return SysMaybe<Unit>.Ok(())
                    }
                case None =>
                    return SysMaybe<Unit>.Ok(())
            }
        }
    }

    /// 是否处于 raw 模式
    public func isInRawMode(): Bool {
        return inRawMode
    }

    /// 恢复终端到原始状态
    /// 对应 Bun: 进程退出前恢复终端
    public func restore(): SysMaybe<Unit> {
        if (inRawMode) {
            return setRawMode(false)
        }
        return SysMaybe<Unit>.Ok(())
    }

    /// 获取当前终端属性
    public func getAttr(): SysMaybe<Termios> {
        return Termios.getattr(fd)
    }

    /// 设置终端属性
    public func setAttr(termios: Termios): SysMaybe<Unit> {
        return termios.setattr(fd, TcSetAttrFlags.TCSANOW)
    }

    // ===== 静态便捷方法 =====

    /// 标准输入是否为 TTY
    public static func isStdinTty(): Bool {
        return isatty(0) != 0
    }

    /// 标准输出是否为 TTY
    public static func isStdoutTty(): Bool {
        return isatty(1) != 0
    }

    /// 标准错误是否为 TTY
    public static func isStderrTty(): Bool {
        return isatty(2) != 0
    }

    /// 检查任意 FD 是否为 TTY
    public static func isTty(fd: Int64): Bool {
        return isatty(Int32(fd)) != 0
    }

    /// 获取标准输出终端大小
    public static func getStdoutSize(): SysMaybe<TerminalSize> {
        return TerminalSize.getStdout()
    }

    /// 获取标准输出列数 (用于进度条等)
    /// 对应 Bun: process.stdout.columns
    public static func getStdoutColumns(): Int64 {
        match (TerminalSize.getStdout()) {
            case Ok(size) => size.cols
            case Err(_) => 80  // 默认 80 列
        }
    }

    /// 获取标准输出行数
    /// 对应 Bun: process.stdout.rows
    public static func getStdoutRows(): Int64 {
        match (TerminalSize.getStdout()) {
            case Ok(size) => size.rows
            case Err(_) => 24  // 默认 24 行
        }
    }
}
