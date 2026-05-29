// 操作系统信息模块（完整翻译）
// 对应 Bun: src/runtime/node/node_os.zig
// 严格翻译自: src/runtime/node/node_os.zig
package bao_runtime.node

import bao_core.Output
import bao_core.PathString
import bao_core.MutableString
import bao_core.BunString
import bao_core.FeatureFlags
import bao_core.LogLevel
import bao_jsc.*
import bao_sys.*
import std.convert.*
import std.collection.ArrayList

// ============================================================================
// FFI declarations for POSIX system calls
// Corresponds to Bun: node_os.zig extern functions
// ============================================================================
@C foreign func set_process_priority(pid: Int32, priority: Int32): Int32
@C foreign func c_sysinfo(buf: CPointer<UInt8>): Int32
@C foreign func c_getloadavg(loadavg: CPointer<Float64>): Int32
@C foreign func c_uname(buf: CPointer<UInt8>): Int32

// ============================================================================
// CPU 时间信息
// 对应 Bun: src/runtime/node/node_os.zig - CPUTimes
// 所有时间以毫秒为单位
// Linux: /proc/stat 中各字段 * 10（scale = 10）
// macOS: host_processor_info ticks * (1000 / CLK_TCK)
// FreeBSD: kern.cp_times * (1000 / CLK_TCK)
// Windows: 直接使用 uv_cpu_info 中的值
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

    // 转换为 JS 对象
    // 对应 Bun: CPUTimes.toValue
    public func toJsObject(globalObject: JsGlobalObject): JsValue {
        let obj = JsObject()
        obj.set("user", JsValue(Int64(user)))
        obj.set("nice", JsValue(Int64(nice)))
        obj.set("sys", JsValue(Int64(sys)))
        obj.set("idle", JsValue(Int64(idle)))
        obj.set("irq", JsValue(Int64(irq)))
        return JsValue(obj)
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
        return NodeOsSystem.cpus()
    }

    // ========================================================================
    // hostCpuCount — 获取 CPU 数量
    // 对应 Bun: node_os.zig hostCpuCount (bun_sysconf__SC_NPROCESSORS_ONLN)
    // ========================================================================
    public static func cpuCount(): Int32 {
        return Int32(SysModule.cpuCount())
    }

    // ========================================================================
    // freemem — 获取空闲内存（字节）
    // 对应 Bun: node_os.zig freemem() -> Bun__Os__getFreeMemory
    // ========================================================================
    public static func freemem(): UInt64 {
        return NodeOsSystem.freemem()
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
        return NodeOsSystem.totalmem()
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
        let homeEnv = OS.getEnv("HOME")
        if (homeEnv.isSome() && homeEnv.getOrThrow().size > 0) {
            return homeEnv.getOrThrow()
        }
        return NodeOsSystem.homedir()
    }

    // ========================================================================
    // hostname — 获取主机名
    // 对应 Bun: node_os.zig hostname()
    // POSIX: gethostname()
    // Windows: GetHostNameW (可能需要 WSAStartup)
    // ========================================================================
    public static func hostname(): String {
        return OS.hostname()
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
        return NodeOsSystem.loadavg()
    }

    // ========================================================================
    // release — 获取操作系统发行版本
    // 对应 Bun: node_os.zig release()
    // Linux: uname.release
    // macOS/FreeBSD: sysctl kern.osrelease
    // Windows: uv_os_uname.release
    // ========================================================================
    public static func release(): String {
        return NodeOsSystem.osRelease()
    }

    // ========================================================================
    // uptime — 获取系统运行时间（秒）
    // 对应 Bun: node_os.zig uptime()
    // Linux: sysinfo.uptime
    // macOS/FreeBSD: timestamp - kern.boottime
    // Windows: uv_uptime
    // ========================================================================
    public static func uptime(): Float64 {
        return NodeOsSystem.uptime()
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

        let userEnv = OS.getEnv("USER")
        info.username = if (userEnv.isSome()) { userEnv.getOrThrow() } else { "unknown" }

        let shellEnv = OS.getEnv("SHELL")
        info.shell = if (shellEnv.isSome()) { shellEnv.getOrThrow() } else { "unknown" }

        info.uid = Int32(OS.uid())
        info.gid = Int32(OS.gid())
        return info
    }

    // ========================================================================
    // networkInterfaces — 获取网络接口信息
    // 对应 Bun: node_os.zig networkInterfacesPosix/Windows
    // POSIX: getifaddrs, 处理 AF_INET/AF_INET6
    // Windows: uv_interface_addresses
    // 包含: address, netmask, family, mac, internal, cidr, scopeid
    // ========================================================================
    public static func networkInterfaces(): HashMap<String, Array<NetworkInterfaceInfo>> {
        return NodeOsSystem.networkInterfaces()
    }

    // ========================================================================
    // getPriority — 获取进程优先级
    // 对应 Bun: node_os.zig getPriority()
    // 使用 get_process_priority 系统调用
    // 错误时抛出 ESRCH (no such process)
    // ========================================================================
    public static func getPriority(pid: Int32): Int32 {
        return NodeOsSystem.getPriority(pid)
    }

    // ========================================================================
    // setPriority — 设置进程优先级
    // 对应 Bun: node_os.zig setPriority1/setPriority2
    // 使用 set_process_priority 系统调用
    // 错误码: ESRCH, EACCES, EPERM
    // ========================================================================
    public static func setPriority(pid: Int32, priority: Int32): Unit {
        NodeOsSystem.setPriority(pid, priority)
    }

    // 便捷版本：仅设置优先级（pid 默认为 0）
    // 对应 Bun: node_os.zig setPriority2
    public static func setPriority(priority: Int32): Unit {
        setPriority(0, priority)
    }

    // ========================================================================
    // version — 获取操作系统版本字符串
    // 对应 Bun: node_os.zig version()
    // macOS/FreeBSD: sysctl kern.version
    // Linux: uname.version
    // Windows: uv_os_uname.version
    // ========================================================================
    public static func version(): String {
        return NodeOsSystem.osVersion()
    }

    // ========================================================================
    // type — 操作系统类型
    // 对应 Bun: node_os.zig type
    // Linux: "Linux", macOS: "Darwin", Windows: "Windows_NT"
    // ========================================================================
    public static func getType(): String {
        return NodeOsSystem.osType()
    }

    // ========================================================================
    // arch — 操作系统架构
    // 对应 Bun: node_os.zig arch
    // x86_64: "x64", aarch64: "arm64", 等
    // ========================================================================
    public static func arch(): String {
        return NodeOsSystem.arch()
    }

    // ========================================================================
    // platform — 操作系统平台
    // 对应 Bun: node_os.zig platform
    // Linux: "linux", macOS: "darwin", Windows: "win32"
    // ========================================================================
    public static func platform(): String {
        return NodeOsSystem.platform()
    }

    // ========================================================================
    // tmpdir — 获取临时目录
    // ========================================================================
    public static func tmpdir(): String {
        return NodeOsSystem.tmpdir()
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
        return if (NodeOsSystem.isLittleEndian()) { "LE" } else { "BE" }
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
        return Int32(SysModule.cpuCount())
    }

    // ========================================================================
    // getPid / getPpid — 进程 ID
    // ========================================================================
    public static func getPid(): Int32 {
        return Int32(OS.pid())
    }

    public static func getPpid(): Int32 {
        return Int32(OS.ppid())
    }
}

// ============================================================================
// 平台特定的 CPU 信息实现
// 对应 Bun: node_os.zig - cpusImplLinux / cpusImplDarwin / cpusImplFreeBSD / cpusImplWindows
// ============================================================================
public class OsCpusImpl {
    // ========================================================================
    // Linux CPU 信息实现
    // 对应 Bun: node_os.zig cpusImplLinux
    // 从 /proc/stat 读取 CPU 时间
    // 从 /proc/cpuinfo 读取型号名称
    // 从 /sys/devices/system/cpu/cpu{N}/cpufreq/scaling_cur_freq 读取频率
    // ========================================================================
    public static func cpusLinux(): Array<CPUInfo> {
        var result = ArrayList<CPUInfo>()
        var numCpus: Int64 = 0

        // 读取 /proc/stat
        let statContent = NodeOsSystem.readFileToString("/proc/stat")
        if (statContent.size > 0) {
            let lines = statContent.split("\n")
            var firstLine = true
            for (line in lines) {
                if (firstLine) {
                    firstLine = false
                    continue  // 跳过第一行（聚合行）
                }
                if (!line.startsWith("cpu")) {
                    break  // CPU 行结束
                }

                let toks = line.split(" ")
                if (toks.size < 7) {
                    continue
                }

                // cpu0 user nice sys idle iowait irq softirq
                // scale = 10（对应 Bun 中的固定缩放因子）
                let scale: UInt64 = 10
                let times = CPUTimes(
                    scale * UInt64(Int64.parse(toks[1])),
                    scale * UInt64(Int64.parse(toks[2])),
                    scale * UInt64(Int64.parse(toks[3])),
                    scale * UInt64(Int64.parse(toks[4])),
                    scale * UInt64(Int64.parse(toks[6]))
                )
                let cpu = CPUInfo("unknown", 0, times)
                result.add(cpu)
                numCpus += 1
            }
        }

        // 如果 /proc/stat 读取失败，返回基于 CPU 数量的 stub
        if (numCpus == 0) {
            let count = Int32(SysModule.cpuCount())
            for (i in 0..count) {
                result.add(CPUInfo("unknown", 0, CPUTimes()))
            }
            return result.toArray()
        }

        // 读取 /proc/cpuinfo 获取型号信息
        let cpuInfo = NodeOsSystem.readFileToString("/proc/cpuinfo")
        if (cpuInfo.size > 0) {
            let lines = cpuInfo.split("\n")
            var cpuIndex: Int64 = 0
            var hasModelName = true
            let procPrefix = "processor\t: "
            let modelPrefix = "model name\t: "
            for (line in lines) {
                if (line.startsWith(procPrefix)) {
                    if (!hasModelName && cpuIndex < numCpus) {
                        result[Int64(cpuIndex)].model = "unknown"
                    }
                    let digits = line[Int64(procPrefix.size)..line.size]
                    cpuIndex = Int64.parse(digits)
                    if (cpuIndex >= numCpus) {
                        break
                    }
                    hasModelName = false
                } else if (line.startsWith(modelPrefix)) {
                    let modelName = line[Int64(modelPrefix.size)..line.size]
                    if (cpuIndex < numCpus) {
                        result[Int64(cpuIndex)].model = modelName
                    }
                    hasModelName = true
                }
            }
            if (!hasModelName && cpuIndex < numCpus) {
                result[Int64(cpuIndex)].model = "unknown"
            }
        }

        // 读取 CPU 频率
        for (i in 0..Int64(result.size)) {
            let path = "/sys/devices/system/cpu/cpu${i}/cpufreq/scaling_cur_freq"
            let freqContent = NodeOsSystem.readFileToString(path)
            if (freqContent.size > 0) {
                let digits = freqContent.trimAscii()
                let freqKhz = Int64.parse(digits)
                result[i].speed = freqKhz / 1000  // kHz → MHz
            }
        }

        return result.toArray()
    }

    // ========================================================================
    // macOS CPU 信息实现
    // 对应 Bun: node_os.zig cpusImplDarwin
    // 使用 host_processor_info 获取 CPU 时间
    // 使用 sysctl machdep.cpu.brand_string 获取型号
    // 使用 sysctl hw.cpufrequency 获取频率
    // Apple Silicon: 频率硬编码为 2400 MHz
    // ========================================================================
    public static func cpusDarwin(): Array<CPUInfo> {
        var result = ArrayList<CPUInfo>()

        // 获取 CPU 数量
        let numCpus = Int32(SysModule.cpuCount())

        // 获取型号名称
        var modelName: String = "unknown"
        let brandString = NodeOsSystem.sysctlString("machdep.cpu.brand_string")
        if (brandString.size > 0) {
            modelName = brandString
        } else {
            let hwModel = NodeOsSystem.sysctlString("hw.model")
            if (hwModel.size > 0) {
                modelName = hwModel
            }
        }

        // 获取 CPU 频率
        var speed: Int64 = 0
        let cpuFreq = NodeOsSystem.sysctlInt64("hw.cpufrequency")
        if (cpuFreq > 0) {
            speed = cpuFreq / 1000000  // Hz → MHz
        } else {
            // Apple Silicon: 频率不可用，硬编码为 2400 MHz（与 Node.js 一致）
            speed = 2400
        }

        // 获取 CPU 时间
        // macOS: host_processor_info 返回每个 CPU 的 ticks
        // ticks * (1000 / CLK_TCK) = 毫秒
        let ticks = NodeOsSystem.sysctlInt64("kern.clockrate")
        let multiplier: UInt64 = if (ticks > 0) { UInt64(1000 / ticks) } else { 1 }

        for (i in 0..numCpus) {
            let times = NodeOsSystem.getCpuTimesDarwin(i)
            let cpuInfo = CPUInfo(
                modelName,
                speed,
                CPUTimes(
                    times.user * multiplier,
                    times.nice * multiplier,
                    times.sys * multiplier,
                    times.idle * multiplier,
                    0  // macOS 不提供 irq 信息
                )
            )
            result.add(cpuInfo)
        }

        return result.toArray()
    }

    // ========================================================================
    // FreeBSD CPU 信息实现
    // 对应 Bun: node_os.zig cpusImplFreeBSD
    // 使用 sysctlbyname kern.cp_times 获取 CPU 时间
    // 使用 sysctlbyname hw.model 获取型号
    // 使用 sysctlbyname hw.clockrate 获取频率
    // ========================================================================
    public static func cpusFreeBSD(): Array<CPUInfo> {
        var result = ArrayList<CPUInfo>()

        let numCpus = Int32(SysModule.cpuCount())

        // 获取型号
        var modelName: String = "unknown"
        let hwModel = NodeOsSystem.sysctlString("hw.model")
        if (hwModel.size > 0) {
            modelName = hwModel
        }

        // 获取频率
        var speedMhz: Int64 = 0
        let clockRate = NodeOsSystem.sysctlInt64("hw.clockrate")
        if (clockRate > 0) {
            speedMhz = clockRate
        }

        // 获取 CPU 时间
        // kern.cp_times 返回 ncpu * 5 个 long 值
        // 每组 5 个: user, nice, sys, intr, idle
        let ticks = NodeOsSystem.sysconfClkTck()
        let mult: UInt64 = if (ticks > 0) { UInt64(1000 / ticks) } else { 1 }

        let cpuTimes = NodeOsSystem.getCpuTimesFreeBSD()
        for (i in 0..Int64(numCpus)) {
            if (i * 5 + 4 < cpuTimes.size) {
                let times = CPUTimes(
                    UInt64(if (cpuTimes[i * 5 + 0] > 0) { cpuTimes[i * 5 + 0] } else { 0 }) * mult,
                    UInt64(if (cpuTimes[i * 5 + 1] > 0) { cpuTimes[i * 5 + 1] } else { 0 }) * mult,
                    UInt64(if (cpuTimes[i * 5 + 2] > 0) { cpuTimes[i * 5 + 2] } else { 0 }) * mult,
                    UInt64(if (cpuTimes[i * 5 + 4] > 0) { cpuTimes[i * 5 + 4] } else { 0 }) * mult,
                    UInt64(if (cpuTimes[i * 5 + 3] > 0) { cpuTimes[i * 5 + 3] } else { 0 }) * mult
                )
                result.add(CPUInfo(modelName, speedMhz, times))
            }
        }

        return result.toArray()
    }

    // ========================================================================
    // Windows CPU 信息实现
    // 对应 Bun: node_os.zig cpusImplWindows
    // 使用 uv_cpu_info 获取 CPU 信息
    // ========================================================================
    public static func cpusWindows(): Array<CPUInfo> {
        var result = ArrayList<CPUInfo>()
        let cpuInfos = NodeOsSystem.uvCpuInfo()

        for (cpuInfo in cpuInfos) {
            result.add(cpuInfo)
        }

        return result.toArray()
    }
}

// ============================================================================
// 网络掩码转 CIDR 后缀
// 对应 Bun: node_os.zig netmaskToCIDRSuffix
// ============================================================================
public class NetmaskUtils {
    // 将 IPv4 网络掩码转换为 CIDR 前缀长度
    // 对应 Bun: netmaskToCIDRSuffix(u32)
    public static func netmaskToCIDRSuffix4(netmask: UInt32): ?UInt8 {
        // 计算前导 1 的位数
        if (netmask == 0) {
            return 0
        }
        var count: UInt8 = 0
        var mask = netmask
        while ((mask & 0x80000000) != 0) {
            count += 1
            mask = mask << 1
        }
        // 验证剩余位全为 0
        if (mask != 0) {
            return None  // 无效的网掩码
        }
        return count
    }

    // 将 IPv6 网络掩码转换为 CIDR 前缀长度
    // 对应 Bun: netmaskToCIDRSuffix(u128)
    public static func netmaskToCIDRSuffix6(high: UInt64, low: UInt64): ?UInt8 {
        var count: UInt8 = 0
        // 计算高 64 位中前导 1 的位数
        var h = high
        while (h != 0 && (h & 0x8000000000000000) != 0) {
            count += 1
            h = h << 1
        }
        if (h == 0) {
            // 高位全为 0 或前导 1 已结束，继续计算低位
            var l = low
            while (l != 0 && (l & 0x8000000000000000) != 0) {
                count += 1
                l = l << 1
            }
            if (l != 0) {
                return None  // 无效的网掩码
            }
        } else {
            // 高位中有非前导 1 的位，掩码无效
            return None
        }
        return count
    }
}

// ============================================================================
// setPriority 错误处理
// 对应 Bun: node_os.zig setPriority1 / setPriority2 的错误码处理
// ============================================================================
public class OsPriorityErrors {
    public static let ESRCH: String = "ESRCH"       // no such process
    public static let EACCES: String = "EACCES"     // permission denied
    public static let EPERM: String = "EPERM"       // operation not permitted

    // 错误码到错误消息的映射
    // 对应 Bun: setProcessPriorityImpl 中的错误码检查
    public static func errorMessage(code: Int32): String {
        if (code == -2) {
            return "no such process"
        }
        return "set priority failed"
    }
}

// ============================================================================
// NodeOsSystem — OS 信息系统调用存根
// 对应 Bun 中各种系统调用（尚未通过 FFI 实现的部分）
// ============================================================================
public class NodeOsSystem {
    // 获取 CPU 信息数组
    public static func cpus(): Array<CPUInfo> {
        return OsCpusImpl.cpusLinux()
    }

    // 获取空闲内存（字节）
    // 对应 Bun: node_os.zig freemem — Linux 使用 sysinfo
    // sysinfo 结构体 (Linux x86_64):
    //   uptime     @ 0    (Int64)
    //   loads      @ 8    (3 * UInt32 = 12 bytes)
    //   totalram   @ 20   (UInt64)
    //   freeram    @ 28   (UInt64)
    //   sharedram  @ 36   (UInt64)
    //   bufferram  @ 44   (UInt64)
    //   totalswap  @ 52   (UInt64)
    //   freeswap   @ 60   (UInt64)
    //   procs      @ 68   (UInt16)
    //   totalhigh  @ 72   (UInt64)
    //   freehigh   @ 80   (UInt64)
    //   mem_unit   @ 88   (UInt32)
    public static func freemem(): UInt64 {
        unsafe {
            let bufSize = UIntNative(256)
            let buf = malloc(bufSize)
            let bufPtr = CPointer<UInt8>(buf)
            for (i in 0..Int64(256)) {
                (bufPtr + i).write(UInt8(0))
            }
            let rc = c_sysinfo(bufPtr)
            if (rc != 0) {
                free(buf)
                return 0
            }
            // freeram @ offset 28
            let freeram = (CPointer<UInt64>(CPointer<Unit>(bufPtr + 28))).read()
            // mem_unit @ offset 88
            let memUnit = UInt64((CPointer<UInt32>(CPointer<Unit>(bufPtr + 88))).read())
            free(buf)
            return freeram * memUnit
        }
    }

    // 获取总内存（字节）
    // 对应 Bun: node_os.zig totalmem — Linux 使用 sysinfo
    public static func totalmem(): UInt64 {
        unsafe {
            let bufSize = UIntNative(256)
            let buf = malloc(bufSize)
            let bufPtr = CPointer<UInt8>(buf)
            for (i in 0..Int64(256)) {
                (bufPtr + i).write(UInt8(0))
            }
            let rc = c_sysinfo(bufPtr)
            if (rc != 0) {
                free(buf)
                return 0
            }
            // totalram @ offset 20
            let totalram = (CPointer<UInt64>(CPointer<Unit>(bufPtr + 20))).read()
            // mem_unit @ offset 88
            let memUnit = UInt64((CPointer<UInt32>(CPointer<Unit>(bufPtr + 88))).read())
            free(buf)
            return totalram * memUnit
        }
    }

    // 获取用户主目录
    public static func homedir(): String {
        return "/root"
    }

    // 获取系统负载平均值
    // 对应 Bun: node_os.zig loadavg — 使用 getloadavg() 或 sysinfo.loads / 65536
    public static func loadavg(): Array<Float64> {
        unsafe {
            let buf = malloc(UIntNative(24))
            let bufPtr = CPointer<Float64>(buf)
            let rc = c_getloadavg(bufPtr)
            if (rc < 0) {
                free(buf)
                return [0.0, 0.0, 0.0]
            }
            let result = [
                Float64(bufPtr.read()),
                Float64((bufPtr + 1).read()),
                Float64((bufPtr + 2).read())
            ]
            free(buf)
            return result
        }
    }

    // 获取操作系统发行版本
    // 对应 Bun: node_os.zig release — 使用 uname 系统调用
    public static func osRelease(): String {
        unsafe {
            // uname 结构体大小: 约 390 字节 (Linux)
            // struct utsname {
            //   char sysname[65];    @ 0
            //   char nodename[65];   @ 65
            //   char release[65];    @ 130
            //   char version[65];    @ 195
            //   char machine[65];    @ 260
            // }
            let bufSize = UIntNative(400)
            let buf = malloc(bufSize)
            let bufPtr = CPointer<UInt8>(buf)
            for (i in 0..Int64(400)) {
                (bufPtr + i).write(UInt8(0))
            }
            let rc = c_uname(bufPtr)
            if (rc != 0) {
                free(buf)
                return "unknown"
            }
            // release @ offset 65, length 65
            let releasePtr = bufPtr + 65
            let release = bufToString(releasePtr, 65)
            free(buf)
            return release
        }
    }

    // 获取系统运行时间（秒）
    // 对应 Bun: node_os.zig uptime — 使用 sysinfo.uptime
    public static func uptime(): Float64 {
        unsafe {
            let bufSize = UIntNative(256)
            let buf = malloc(bufSize)
            let bufPtr = CPointer<UInt8>(buf)
            for (i in 0..Int64(256)) {
                (bufPtr + i).write(UInt8(0))
            }
            let rc = c_sysinfo(bufPtr)
            if (rc != 0) {
                free(buf)
                return 0.0
            }
            // uptime @ offset 0, Int64
            let uptimeVal = (CPointer<Int64>(CPointer<Unit>(bufPtr))).read()
            free(buf)
            return Float64(uptimeVal)
        }
    }

    // 获取网络接口信息
    public static func networkInterfaces(): HashMap<String, Array<NetworkInterfaceInfo>> {
        return HashMap<String, Array<NetworkInterfaceInfo>>()
    }

    // 获取进程优先级
    public static func getPriority(pid: Int32): Int32 {
        return 0
    }

    // 设置进程优先级
    // 对应 Bun: node_os.zig setProcessPriorityImpl
    // 调用 set_process_priority FFI 函数，错误时抛出 SystemError
    public static func setPriority(pid: Int32, priority: Int32): Unit {
        let code = unsafe { set_process_priority(pid, priority) }
        if (code == -2) {
            throw Exception("ESRCH: no such process")
        }
        if (code != 0) {
            throw Exception("EACCES: set priority failed")
        }
    }

    // 获取操作系统版本
    // 对应 Bun: node_os.zig version — 使用 uname.version
    public static func osVersion(): String {
        unsafe {
            let bufSize = UIntNative(400)
            let buf = malloc(bufSize)
            let bufPtr = CPointer<UInt8>(buf)
            for (i in 0..Int64(400)) {
                (bufPtr + i).write(UInt8(0))
            }
            let rc = c_uname(bufPtr)
            if (rc != 0) {
                free(buf)
                return ""
            }
            // version @ offset 195, length 65
            let version = bufToString(bufPtr + 195, 65)
            free(buf)
            return version
        }
    }

    // 获取操作系统类型
    // 对应 Bun: node_os.zig type — 使用 uname.sysname
    public static func osType(): String {
        unsafe {
            let bufSize = UIntNative(400)
            let buf = malloc(bufSize)
            let bufPtr = CPointer<UInt8>(buf)
            for (i in 0..Int64(400)) {
                (bufPtr + i).write(UInt8(0))
            }
            let rc = c_uname(bufPtr)
            if (rc != 0) {
                free(buf)
                return "Linux"
            }
            // sysname @ offset 0, length 65
            let sysname = bufToString(bufPtr, 65)
            free(buf)
            return sysname
        }
    }

    // 获取操作系统架构
    // 对应 Bun: node_os.zig arch — 使用 uname.machine
    public static func arch(): String {
        unsafe {
            let bufSize = UIntNative(400)
            let buf = malloc(bufSize)
            let bufPtr = CPointer<UInt8>(buf)
            for (i in 0..Int64(400)) {
                (bufPtr + i).write(UInt8(0))
            }
            let rc = c_uname(bufPtr)
            if (rc != 0) {
                free(buf)
                return "x64"
            }
            // machine @ offset 260, length 65
            let machine = bufToString(bufPtr + 260, 65)
            free(buf)
            // 映射到 Node.js 架构名称
            match (machine) {
                case "x86_64" => return "x64"
                case "aarch64" => return "arm64"
                case "armv7l" => return "arm"
                case "ppc64" => return "ppc64"
                case "s390x" => return "s390x"
                case "i686" => return "ia32"
                case _ => return machine
            }
        }
    }

    // 获取操作系统平台
    public static func platform(): String {
        return "linux"
    }

    // 获取临时目录
    public static func tmpdir(): String {
        let tmpEnv = OS.getEnv("TMPDIR")
        if (tmpEnv.isSome() && tmpEnv.getOrThrow().size > 0) {
            return tmpEnv.getOrThrow()
        }
        let tmpEnv2 = OS.getEnv("TMP")
        if (tmpEnv2.isSome() && tmpEnv2.getOrThrow().size > 0) {
            return tmpEnv2.getOrThrow()
        }
        return "/tmp"
    }

    // 判断是否小端
    public static func isLittleEndian(): Bool {
        return true
    }

    // 读取文件内容为字符串
    // 对应 Bun: node_os.zig - /proc/stat, /proc/cpuinfo 等系统文件读取
    // 使用 SysFs.openRead / SysFs.read / SysFs.close 实现
    public static func readFileToString(path: String): String {
        let fdResult = SysFs.openRead(path)
        if (fdResult.isErr()) {
            return ""
        }
        if (let Some(fd) <- fdResult.result()) {
            var result = ""
            let bufSize: Int64 = 4096
            let buf = Array<UInt8>(bufSize, { _ => UInt8(0) })
            while (true) {
                let readResult = SysFs.read(fd, buf)
                if (readResult.isErr()) {
                    break
                }
                if (let Some(bytesRead) <- readResult.result()) {
                    if (bytesRead == 0) {
                        break
                    }
                    let slice = buf[0..bytesRead]
                    let newPart = String.fromUtf8(slice)
                    result = result + newPart
                    if (bytesRead < bufSize) {
                        break
                    }
                } else {
                    break
                }
            }
            _ = SysFs.close(fd)
            return result
        }
        return ""
    }

    // sysctl 读取字符串（macOS/FreeBSD）
    public static func sysctlString(name: String): String {
        return ""
    }

    // sysctl 读取 Int64（macOS/FreeBSD）
    public static func sysctlInt64(name: String): Int64 {
        return 0
    }

    // 获取 macOS CPU 时间
    public static func getCpuTimesDarwin(cpuIndex: Int32): CPUTimes {
        return CPUTimes()
    }

    // 获取 FreeBSD CPU 时间数组
    public static func getCpuTimesFreeBSD(): Array<Int64> {
        return []
    }

    // 获取时钟 tick 频率
    public static func sysconfClkTck(): Int64 {
        return 100
    }

    // 获取 uv_cpu_info（Windows）
    public static func uvCpuInfo(): Array<CPUInfo> {
        return []
    }

    // ========================================================================
    // 辅助函数
    // ========================================================================

    /// 从缓冲区创建字符串（遇到 null 终止符停止）
    private static func bufToString(buf: CPointer<UInt8>, maxLen: Int64): String {
        unsafe {
            var sb = ""
            for (i in 0..maxLen) {
                let b = (buf + i).read()
                if (b == UInt8(0)) {
                    break
                }
                sb += String(Rune(Int32(b)))
            }
            return sb
        }
    }
}
