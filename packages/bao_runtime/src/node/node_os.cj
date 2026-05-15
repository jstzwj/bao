// 操作系统信息模块（完整翻译）
// 对应 Bun: src/runtime/node/node_os.zig
// 严格翻译自: src/runtime/node/node_os.zig
package bao_runtime

import bao_core.*
import bao_sys.*

// ============================================================================
// CPU 时间信息
// 对应 Bun: src/runtime/node/node_os.zig - CPUTimes
// ============================================================================
public class CPUTimes {
    public var user: UInt64 = 0
    public var nice: UInt64 = 0
    public var sys: UInt64 = 0
    public var idle: UInt64 = 0
    public var irq: UInt64 = 0

    public init() {}

    public init(user: UInt64, nice: UInt64, sys: UInt64, idle: UInt64, irq: UInt64) {
        this.user = user
        this.nice = nice
        this.sys = sys
        this.idle = idle
        this.irq = irq
    }
}

// ============================================================================
// CPU 信息
// 对应 Bun: src/runtime/node/node_os.zig - cpusImplLinux/Darwin/FreeBSD/Windows
// ============================================================================
public class CPUInfo {
    public var model: String = "unknown"
    public var speed: Int64 = 0  // MHz
    public var times: CPUTimes = CPUTimes()

    public init() {}

    public init(model: String, speed: Int64, times: CPUTimes) {
        this.model = model
        this.speed = speed
        this.times = times
    }
}

// ============================================================================
// 网络接口信息
// 对应 Bun: src/runtime/node/node_os.zig - networkInterfacesPosix/Windows
// ============================================================================
public class NetworkInterfaceInfo {
    public var address: String = ""
    public var netmask: String = ""
    public var family: String = "IPv4"
    public var mac: String = "00:00:00:00:00:00"
    public var internal: Bool = false
    public var cidr: ?String = None
    public var scopeid: Int32 = 0

    public init() {}
}

// ============================================================================
// 用户信息
// 对应 Bun: src/runtime/node/node_os.zig - userInfo
// ============================================================================
public class UserInfo {
    public var homedir: String = ""
    public var username: String = "unknown"
    public var shell: String = "unknown"
    public var uid: Int32 = -1
    public var gid: Int32 = -1

    public init() {}
}

// ============================================================================
// OS 绑定 — 操作系统信息查询
// 对应 Bun: src/runtime/node/node_os.zig - createNodeOsBinding
// 包含: cpus, freemem, totalmem, hostname, loadavg, release, uptime,
//       userInfo, networkInterfaces, getPriority, setPriority, version,
//       homedir, type, arch, platform, tmpdir, eol, endianness
// ============================================================================
public class NodeOs {
    // ========================================================================
    // cpus — 获取 CPU 信息数组
    // 对应 Bun: node_os.zig cpus() -> cpusImplLinux/Darwin/FreeBSD/Windows
    // Linux: 读取 /proc/stat 和 /proc/cpuinfo
    // macOS: 使用 host_processor_info 和 sysctl
    // FreeBSD: 使用 sysctlbyname kern.cp_times
    // Windows: 使用 uv_cpu_info
    // ========================================================================
    public static func cpus(): Array<CPUInfo> {
        return System.cpus()
    }

    // ========================================================================
    // hostCpuCount — 获取 CPU 数量
    // 对应 Bun: node_os.zig hostCpuCount (bun_sysconf__SC_NPROCESSORS_ONLN)
    // ========================================================================
    public static func cpuCount(): Int32 {
        return System.cpuCount()
    }

    // ========================================================================
    // freemem — 获取空闲内存（字节）
    // 对应 Bun: node_os.zig freemem() -> Bun__Os__getFreeMemory
    // ========================================================================
    public static func freemem(): UInt64 {
        return System.freemem()
    }

    // ========================================================================
    // totalmem — 获取总内存（字节）
    // 对应 Bun: node_os.zig totalmem()
    // macOS: sysctl hw.memsize
    // Linux: sysinfo.totalram * mem_unit
    // FreeBSD: sysctl hw.physmem
    // Windows: uv_get_total_memory
    // ========================================================================
    public static func totalmem(): UInt64 {
        return System.totalmem()
    }

    // ========================================================================
    // homedir — 获取用户主目录
    // 对应 Bun: node_os.zig homedir()
    // POSIX: 检查 HOME 环境变量，然后 getpwuid_r
    // Windows: uv_os_homedir
    // Android 特殊处理: /data/local/tmp
    // ========================================================================
    public static func homedir(): String {
        // 先检查 HOME 环境变量（POSIX 实现）
        let homeEnv = System.getenv("HOME")
        if (homeEnv != None && homeEnv!.size > 0) {
            return homeEnv!
        }
        return System.homedir()
    }

    // ========================================================================
    // hostname — 获取主机名
    // 对应 Bun: node_os.zig hostname()
    // POSIX: gethostname()
    // Windows: GetHostNameW (可能需要 WSAStartup)
    // ========================================================================
    public static func hostname(): String {
        return System.hostname()
    }

    // ========================================================================
    // loadavg — 获取系统负载平均值
    // 对应 Bun: node_os.zig loadavg()
    // Linux: sysinfo.loads / 65536.0
    // macOS: sysctl vm.loadavg / fscale
    // FreeBSD: getloadavg
    // Windows: 返回 [0, 0, 0]
    // ========================================================================
    public static func loadavg(): Array<Float64> {
        return System.loadavg()
    }

    // ========================================================================
    // release — 获取操作系统发行版本
    // 对应 Bun: node_os.zig release()
    // Linux: uname.release
    // macOS/FreeBSD: sysctl kern.osrelease
    // Windows: uv_os_uname.release
    // ========================================================================
    public static func release(): String {
        return System.osRelease()
    }

    // ========================================================================
    // uptime — 获取系统运行时间（秒）
    // 对应 Bun: node_os.zig uptime()
    // Linux: sysinfo.uptime
    // macOS/FreeBSD: timestamp - kern.boottime
    // Windows: uv_uptime
    // ========================================================================
    public static func uptime(): Float64 {
        return System.uptime()
    }

    // ========================================================================
    // userInfo — 获取用户信息
    // 对应 Bun: node_os.zig userInfo()
    // POSIX: homedir, USER, SHELL, getuid/getgid
    // Windows: homedir, USERNAME, uid=-1, gid=-1, shell=null
    // ========================================================================
    public static func userInfo(): UserInfo {
        let info = UserInfo()
        info.homedir = homedir()

        let userEnv = System.getenv("USER")
        info.username = if (userEnv != None) { userEnv! } else { "unknown" }

        let shellEnv = System.getenv("SHELL")
        info.shell = if (shellEnv != None) { shellEnv! } else { "unknown" }

        info.uid = Int32(System.getuid())
        info.gid = Int32(System.getgid())
        return info
    }

    // ========================================================================
    // networkInterfaces — 获取网络接口信息
    // 对应 Bun: node_os.zig networkInterfacesPosix/Windows
    // POSIX: getifaddrs, 处理 AF_INET/AF_INET6
    // Windows: uv_interface_addresses
    // 包含: address, netmask, family, mac, internal, cidr, scopeid
    // ========================================================================
    public static func networkInterfaces(): Map<String, Array<NetworkInterfaceInfo>> {
        return System.networkInterfaces()
    }

    // ========================================================================
    // getPriority — 获取进程优先级
    // 对应 Bun: node_os.zig getPriority()
    // 使用 get_process_priority 系统调用
    // 错误时抛出 ESRCH (no such process)
    // ========================================================================
    public static func getPriority(pid: Int32): Int32 {
        return System.getPriority(pid)
    }

    // ========================================================================
    // setPriority — 设置进程优先级
    // 对应 Bun: node_os.zig setPriority1/setPriority2
    // 使用 set_process_priority 系统调用
    // 错误码: ESRCH, EACCES, EPERM
    // ========================================================================
    public static func setPriority(pid: Int32, priority: Int32): Unit {
        System.setPriority(pid, priority: priority)
    }

    // 便捷版本：仅设置优先级（pid 默认为 0）
    // 对应 Bun: node_os.zig setPriority2
    public static func setPriority(priority: Int32): Unit {
        setPriority(0, priority: priority)
    }

    // ========================================================================
    // version — 获取操作系统版本字符串
    // 对应 Bun: node_os.zig version()
    // macOS/FreeBSD: sysctl kern.version
    // Linux: uname.version
    // Windows: uv_os_uname.version
    // ========================================================================
    public static func version(): String {
        return System.osVersion()
    }

    // ========================================================================
    // type — 操作系统类型
    // 对应 Bun: node_os.zig type
    // Linux: "Linux", macOS: "Darwin", Windows: "Windows_NT"
    // ========================================================================
    public static func getType(): String {
        return System.osType()
    }

    // ========================================================================
    // arch — 操作系统架构
    // 对应 Bun: node_os.zig arch
    // x86_64: "x64", aarch64: "arm64", 等
    // ========================================================================
    public static func arch(): String {
        return System.arch()
    }

    // ========================================================================
    // platform — 操作系统平台
    // 对应 Bun: node_os.zig platform
    // Linux: "linux", macOS: "darwin", Windows: "win32"
    // ========================================================================
    public static func platform(): String {
        return System.platform()
    }

    // ========================================================================
    // tmpdir — 获取临时目录
    // ========================================================================
    public static func tmpdir(): String {
        return System.tmpdir()
    }

    // ========================================================================
    // eol — 获取行尾符
    // POSIX: "\n", Windows: "\r\n"
    // ========================================================================
    public static func eol(): String {
        return "\n"
    }

    // ========================================================================
    // endianness — 获取字符顺序
    // ========================================================================
    public static func endianness(): String {
        return if (System.isLittleEndian()) { "LE" } else { "BE" }
    }

    // ========================================================================
    // devNull — 空设备路径
    // POSIX: "/dev/null", Windows: "\\\\.\\NUL"
    // ========================================================================
    public static func devNull(): String {
        return "/dev/null"
    }

    // ========================================================================
    // availableParallelism — 可用并行度
    // 对应 Bun: node_os.zig hostCpuCount
    // ========================================================================
    public static func availableParallelism(): Int32 {
        return System.cpuCount()
    }

    // ========================================================================
    // getPid / getPpid — 进程 ID
    // ========================================================================
    public static func getPid(): Int32 {
        return System.getpid()
    }

    public static func getPpid(): Int32 {
        return System.getppid()
    }
}
