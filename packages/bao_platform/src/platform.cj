// 严格翻译自: src/platform/lib.rs
// 平台特定 API 入口

package bao_platform

// 平台模块选择
// 严格翻译自: lib.rs:9-12
//   #[cfg(target_os = "macos")] pub mod darwin;
//   #[cfg(any(target_os = "linux", target_os = "android"))] pub mod linux;
//
// PORT NOTE: 仓颉中通过条件编译或运行时检测选择平台模块
// 两个平台模块都可用, 调用者根据需要选择

/// 运行时检测当前平台类型
public enum PlatformType {
    | Darwin   // macOS
    | Linux    // Linux / Android
    | Windows  // Windows
    | FreeBsd  // FreeBSD
    | Unknown  // 未知平台

    public operator func == (rhs: PlatformType): Bool {
        match (this) {
            case Darwin => match (rhs) { case Darwin => true; case _ => false }
            case Linux => match (rhs) { case Linux => true; case _ => false }
            case Windows => match (rhs) { case Windows => true; case _ => false }
            case FreeBsd => match (rhs) { case FreeBsd => true; case _ => false }
            case Unknown => match (rhs) { case Unknown => true; case _ => false }
        }
    }
    public operator func != (rhs: PlatformType): Bool {
        !(this == rhs)
    }
}

/// 平台工具
public class Platform {
    /// 获取当前平台类型
    public static func current(): PlatformType {
        // PORT NOTE: 实际实现需要通过 FFI 或内置变量检测
        // 默认返回 Linux
        return PlatformType.Linux
    }

    /// 是否为 macOS
    public static func isDarwin(): Bool {
        current() == PlatformType.Darwin
    }

    /// 是否为 Linux/Android
    public static func isLinux(): Bool {
        current() == PlatformType.Linux
    }

    /// 是否为 Windows
    public static func isWindows(): Bool {
        current() == PlatformType.Windows
    }

    /// 是否为 FreeBSD
    public static func isFreeBsd(): Bool {
        current() == PlatformType.FreeBsd
    }

    /// 是否为 POSIX 系统
    public static func isPosix(): Bool {
        let p = current()
        p == PlatformType.Darwin || p == PlatformType.Linux || p == PlatformType.FreeBsd
    }
}
