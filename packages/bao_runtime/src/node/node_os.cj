// 操作系统信息模块
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
// 对应 Bun: src/runtime/node/node_os.zig - cpusImplLinux/Darwin
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
// 对应 Bun: src/runtime/node/node_os.zig - networkInterfacesPosix
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
// ============================================================================
public class NodeOs {
    // 获取 CPU 数量
    // 对应 Bun: src/runtime/node/node_os.zig - hostCpuCount
    public static func cpus(): Array<CPUInfo> {
        return System.cpus()
    }

    // 获取 CPU 数量
    public static func cpuCount(): Int32 {
        return System.cpuCount()
    }

    // 获取空闲内存（字节）
    // 对应 Bun: src/runtime/node/node_os.zig - freemem
    public static func freemem(): UInt64 {
        return System.freemem()
    }

    // 获取总内存（字节）
    // 对应 Bun: src/runtime/node/node_os.zig - totalmem
    public static func totalmem(): UInt64 {
        return System.totalmem()
    }

    // 获取主机名
    // 对应 Bun: src/runtime/node/node_os.zig - hostname
    public static func hostname(): String {
        return System.hostname()
    }

    // 获取系统负载平均值
    // 对应 Bun: src/runtime/node/node_os.zig - loadavg
    public static func loadavg(): Array<Float64> {
        return System.loadavg()
    }

    // 获取操作系统版本
    // 对应 Bun: src/runtime/node/node_os.zig - release
    public static func release(): String {
        return System.osRelease()
    }

    // 获取系统运行时间（秒）
    // 对应 Bun: src/runtime/node/node_os.zig - uptime
    public static func uptime(): Float64 {
        return System.uptime()
    }

    // 获取用户信息
    // 对应 Bun: src/runtime/node/node_os.zig - userInfo
    public static func userInfo(): UserInfo {
        let info = UserInfo()
        info.homedir = System.homedir()
        info.username = System.getUsername()
        info.shell = System.getShell()
        info.uid = Int32(System.getuid())
        info.gid = Int32(System.getgid())
        return info
    }

    // 获取网络接口信息
    // 对应 Bun: src/runtime/node/node_os.zig - networkInterfaces
    public static func networkInterfaces(): Map<String, Array<NetworkInterfaceInfo>> {
        return System.networkInterfaces()
    }

    // 获取进程优先级
    // 对应 Bun: src/runtime/node/node_os.zig - getPriority
    public static func getPriority(pid: Int32): Int32 {
        return System.getPriority(pid)
    }

    // 设置进程优先级
    // 对应 Bun: src/runtime/node/node_os.zig - setPriority
    public static func setPriority(pid: Int32, priority: Int32): Unit {
        System.setPriority(pid, priority: priority)
    }

    // 操作系统类型
    public static func getType(): String {
        return System.osType()
    }

    // 操作系统架构
    public static func arch(): String {
        return System.arch()
    }

    // 操作系统平台
    public static func platform(): String {
        return System.platform()
    }

    // 获取操作系统版本字符串
    // 对应 Bun: src/runtime/node/node_os.zig - version
    public static func version(): String {
        return System.osVersion()
    }

    // 获取临时目录
    public static func tmpdir(): String {
        return System.tmpdir()
    }

    // 获取行尾符
    public static func eol(): String {
        return "\n"
    }

    // 获取字符顺序
    public static func endianness(): String {
        return if (System.isLittleEndian()) { "LE" } else { "BE" }
    }
}
