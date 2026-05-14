// Node.js os 模块 — 操作系统信息 API
// 对应 Bun: src/runtime/node/os.zig
// 严格翻译自: src/runtime/node/os.zig
// 严格翻译 Bun 的 Node.js os 兼容层
package bao_runtime

import bao_core.*
import bao_collections.*
import bao_sys.*

// ============================================================================
// os 模块 — Node.js 操作系统信息 API
// 对应 Bun: src/runtime/node/os.zig
// ============================================================================

/// os 模块 — 提供 Node.js 兼容的操作系统信息 API
/// 对应 Bun: src/runtime/node/os.zig
public class OsModule {
    /// os.hostname() — 返回主机名
    /// 对应 Bun: os.hostname -> gethostname
    public static func hostname(): String {
        return OS.hostname()
    }

    /// os.platform() — 返回平台标识
    /// 对应 Bun: os.platform -> "linux", "darwin", "win32"
    public static func platform(): String {
        // 仓颉当前主要在 Linux 上运行
        return "linux"
    }

    /// os.arch() — 返回 CPU 架构
    /// 对应 Bun: os.arch -> "x64", "arm64"
    public static func arch(): String {
        // 通过环境变量或编译期确定
        let arch = OS.getEnv("PROCESSOR_ARCHITECTURE")
        match (arch) {
            case Some(a) =>
                if (a.contains("ARM") || a.contains("arm")) {
                    return "arm64"
                }
            case None => ()
        }
        return "x64"
    }

    /// os.type() — 返回操作系统名称
    /// 对应 Bun: os.type -> "Linux", "Darwin", "Windows_NT"
    public static func type_(): String {
        return "Linux"
    }

    /// os.release() — 返回内核版本
    /// 对应 Bun: os.release -> uname.release
    public static func release(): String {
        // 通过 uname 或 /proc/version 获取
        let ver = OS.getEnv("KERNEL_VERSION")
        return ver.getOrElse { "0.0.0" }
    }

    /// os.version() — 返回内核版本字符串
    /// 对应 Bun: os.version
    public static func version(): String {
        return release()
    }

    /// os.homedir() — 返回用户主目录
    /// 对应 Bun: os.homedir -> $HOME
    public static func homedir(): String {
        let home = OS.getEnv("HOME")
        return home.getOrElse { "/root" }
    }

    /// os.tmpdir() — 返回临时目录
    /// 对应 Bun: os.tmpdir -> $TMPDIR or /tmp
    public static func tmpdir(): String {
        let tmp = OS.getEnv("TMPDIR")
        return tmp.getOrElse { "/tmp" }
    }

    /// os.cwd() — 返回当前工作目录
    /// 对应 Bun: os.cwd -> process.cwd
    public static func cwd(): String {
        return OS.getcwd()
    }

    /// os.cpus() — 返回 CPU 信息列表
    /// 对应 Bun: os.cpus -> 读取 /proc/cpuinfo
    public static func cpus(): ArrayList<CpuInfo> {
        let list = ArrayList<CpuInfo>()
        // 简化实现: 返回一个默认 CPU 信息
        let cpu = CpuInfo()
        cpu.model = "Unknown"
        cpu.speed = 0
        cpu.times = CpuTimes()
        list.append(cpu)
        return list
    }

    /// os.totalmem() — 返回总物理内存 (字节)
    /// 对应 Bun: os.totalmem -> sysinfo.totalram
    public static func totalmem(): Int64 {
        // 通过 sysinfo 系统调用获取 — 占位实现
        return Int64(0)
    }

    /// os.freemem() — 返回空闲物理内存 (字节)
    /// 对应 Bun: os.freemem -> sysinfo.freeram
    public static func freemem(): Int64 {
        // 通过 sysinfo 系统调用获取 — 占位实现
        return Int64(0)
    }

    /// os.uptime() — 返回系统运行时间 (秒)
    /// 对应 Bun: os.uptime -> sysinfo.uptime
    public static func uptime(): Float64 {
        // 通过 sysinfo 系统调用获取 — 占位实现
        return 0.0
    }

    /// os.loadavg() — 返回系统负载平均值 [1min, 5min, 15min]
    /// 对应 Bun: os.loadavg -> getloadavg() or /proc/loadavg
    public static func loadavg(): Array<Float64> {
        // 通过 getloadavg() 获取 — 占位实现
        return [0.0, 0.0, 0.0]
    }

    /// os.networkInterfaces() — 返回网络接口列表
    /// 对应 Bun: os.networkInterfaces -> 遍历网络接口
    public static func networkInterfaces(): ArrayList<NetworkInterface> {
        let list = ArrayList<NetworkInterface>()
        // 简化实现: 通过 getifaddrs 获取 — 占位
        return list
    }

    /// os.userInfo() — 返回当前用户信息
    /// 对应 Bun: os.userInfo -> getpwuid(getuid())
    public static func userInfo(): UserInfo {
        let info = UserInfo()
        info.uid = Int64(OS.uid())
        info.gid = Int64(OS.gid())
        info.homedir = homedir()
        info.username = OS.getEnv("USER").getOrElse { "root" }
        info.shell = OS.getEnv("SHELL").getOrElse { "/bin/sh" }
        return info
    }

    /// os.devNull — 返回 /dev/null 路径
    /// 对应 Bun: os.devNull
    public static func devNull(): String {
        return "/dev/null"
    }

    /// os.getPriority(pid) — 获取进程优先级
    /// 对应 Bun: os.getPriority -> getpriority()
    public static func priority(pid: Int64): Int64 {
        // 通过 getpriority 系统调用 — 占位实现
        return 0
    }

    /// os.constants — 返回操作系统常量
    /// 对应 Bun: os.constants
    public static func constants(): OsConstants {
        let c = OsConstants()
        // 填充信号常量
        c.signals.put("SIGHUP", 1)
        c.signals.put("SIGINT", 2)
        c.signals.put("SIGQUIT", 3)
        c.signals.put("SIGILL", 4)
        c.signals.put("SIGTRAP", 5)
        c.signals.put("SIGABRT", 6)
        c.signals.put("SIGBUS", 7)
        c.signals.put("SIGFPE", 8)
        c.signals.put("SIGKILL", 9)
        c.signals.put("SIGUSR1", 10)
        c.signals.put("SIGSEGV", 11)
        c.signals.put("SIGUSR2", 12)
        c.signals.put("SIGPIPE", 13)
        c.signals.put("SIGALRM", 14)
        c.signals.put("SIGTERM", 15)
        // 填充 errno 常量
        c.errno.put("EPERM", 1)
        c.errno.put("ENOENT", 2)
        c.errno.put("ESRCH", 3)
        c.errno.put("EINTR", 4)
        c.errno.put("EIO", 5)
        c.errno.put("ENXIO", 6)
        c.errno.put("E2BIG", 7)
        c.errno.put("ENOEXEC", 8)
        c.errno.put("EBADF", 9)
        c.errno.put("ECHILD", 10)
        c.errno.put("EAGAIN", 11)
        c.errno.put("ENOMEM", 12)
        c.errno.put("EACCES", 13)
        c.errno.put("EFAULT", 14)
        // 填充优先级常量
        c.priority.put("PRIORITY_LOW", 19)
        c.priority.put("PRIORITY_BELOW_NORMAL", 10)
        c.priority.put("PRIORITY_NORMAL", 0)
        c.priority.put("PRIORITY_ABOVE_NORMAL", -7)
        c.priority.put("PRIORITY_HIGH", -14)
        c.priority.put("PRIORITY_HIGHEST", -20)
        return c
    }

    /// os.endianness() — 返回字节序
    /// 对应 Bun: os.endianness -> "LE" or "BE"
    public static func endianness(): String {
        // 大多数现代平台为小端
        return "LE"
    }

    /// os.availableParallelism() — 返回可用并行度 (CPU 核心数)
    /// 对应 Bun: os.availableParallelism
    public static func availableParallelism(): Int64 {
        let n = OS.getEnv("NUMBER_OF_PROCESSORS")
        return n.map { v =>
            try {
                Int64.parse(v)
            } catch (_: Exception) {
                Int64(1)
            }
        }.getOrElse { Int64(1) }
    }

    /// 将 os 模块导出为 JsValue 对象
    /// 用于在解释器中注册 require('os')
    public static func toJsValue(): JsValue {
        let obj = JsObject()

        obj.set("hostname", JsValue.nativeFunction(JsNativeFunction("hostname") { _ =>
            JsValue(BaoString(hostname()))
        }))

        obj.set("platform", JsValue.nativeFunction(JsNativeFunction("platform") { _ =>
            JsValue(BaoString(platform()))
        }))

        obj.set("arch", JsValue.nativeFunction(JsNativeFunction("arch") { _ =>
            JsValue(BaoString(arch()))
        }))

        obj.set("type", JsValue.nativeFunction(JsNativeFunction("type") { _ =>
            JsValue(BaoString(type_()))
        }))

        obj.set("release", JsValue.nativeFunction(JsNativeFunction("release") { _ =>
            JsValue(BaoString(release()))
        }))

        obj.set("version", JsValue.nativeFunction(JsNativeFunction("version") { _ =>
            JsValue(BaoString(version()))
        }))

        obj.set("homedir", JsValue.nativeFunction(JsNativeFunction("homedir") { _ =>
            JsValue(BaoString(homedir()))
        }))

        obj.set("tmpdir", JsValue.nativeFunction(JsNativeFunction("tmpdir") { _ =>
            JsValue(BaoString(tmpdir()))
        }))

        obj.set("cwd", JsValue.nativeFunction(JsNativeFunction("cwd") { _ =>
            JsValue(BaoString(cwd()))
        }))

        obj.set("totalmem", JsValue.nativeFunction(JsNativeFunction("totalmem") { _ =>
            JsValue(Float64(totalmem()))
        }))

        obj.set("freemem", JsValue.nativeFunction(JsNativeFunction("freemem") { _ =>
            JsValue(Float64(freemem()))
        }))

        obj.set("uptime", JsValue.nativeFunction(JsNativeFunction("uptime") { _ =>
            JsValue(uptime())
        }))

        obj.set("loadavg", JsValue.nativeFunction(JsNativeFunction("loadavg") { _ =>
            let arr = ArrayList<JsValue>()
            for (v in loadavg()) {
                arr.append(JsValue(v))
            }
            JsValue.array(arr)
        }))

        obj.set("cpus", JsValue.nativeFunction(JsNativeFunction("cpus") { _ =>
            let cpuList = cpus()
            let arr = ArrayList<JsValue>()
            for (cpu in cpuList) {
                let cpuObj = JsObject()
                cpuObj.set("model", JsValue(BaoString(cpu.model)))
                cpuObj.set("speed", JsValue(Float64(cpu.speed)))
                let timesObj = JsObject()
                timesObj.set("user", JsValue(Float64(cpu.times.user)))
                timesObj.set("nice", JsValue(Float64(cpu.times.nice)))
                timesObj.set("sys", JsValue(Float64(cpu.times.sys)))
                timesObj.set("idle", JsValue(Float64(cpu.times.idle)))
                timesObj.set("irq", JsValue(Float64(cpu.times.irq)))
                cpuObj.set("times", JsValue(timesObj))
                arr.append(JsValue(cpuObj))
            }
            JsValue.array(arr)
        }))

        obj.set("networkInterfaces", JsValue.nativeFunction(JsNativeFunction("networkInterfaces") { _ =>
            let ifaces = networkInterfaces()
            let arr = ArrayList<JsValue>()
            for (iface in ifaces) {
                let ifaceObj = JsObject()
                ifaceObj.set("name", JsValue(BaoString(iface.name)))
                ifaceObj.set("address", JsValue(BaoString(iface.address)))
                ifaceObj.set("netmask", JsValue(BaoString(iface.netmask)))
                ifaceObj.set("family", JsValue(BaoString(iface.family)))
                ifaceObj.set("mac", JsValue(BaoString(iface.mac)))
                ifaceObj.set("internal", JsValue(iface.internal))
                arr.append(JsValue(ifaceObj))
            }
            JsValue.array(arr)
        }))

        obj.set("userInfo", JsValue.nativeFunction(JsNativeFunction("userInfo") { _ =>
            let info = userInfo()
            let infoObj = JsObject()
            infoObj.set("username", JsValue(BaoString(info.username)))
            infoObj.set("uid", JsValue(Float64(info.uid)))
            infoObj.set("gid", JsValue(Float64(info.gid)))
            infoObj.set("shell", JsValue(BaoString(info.shell)))
            infoObj.set("homedir", JsValue(BaoString(info.homedir)))
            JsValue(infoObj)
        }))

        obj.set("devNull", JsValue(BaoString(devNull())))
        obj.set("EOL", JsValue(BaoString("\n")))
        obj.set("endianness", JsValue.nativeFunction(JsNativeFunction("endianness") { _ =>
            JsValue(BaoString(endianness()))
        }))

        obj.set("availableParallelism", JsValue.nativeFunction(JsNativeFunction("availableParallelism") { _ =>
            JsValue(Float64(availableParallelism()))
        }))

        obj.set("getPriority", JsValue.nativeFunction(JsNativeFunction("getPriority") { args =>
            let p = if (args.size > 0) { Int64(Interpreter.jsToNumber(args[0])) } else { OS.pid() }
            JsValue(Float64(priority(p)))
        }))

        // constants 对象
        let c = constants()
        let constantsObj = JsObject()
        let signalsObj = JsObject()
        for (key in c.signals.keys()) {
            match (c.signals.get(key)) {
                case Some(v) => signalsObj.set(key, JsValue(Float64(v)))
                case None => ()
            }
        }
        constantsObj.set("signals", JsValue(signalsObj))
        let errnoObj = JsObject()
        for (key in c.errno.keys()) {
            match (c.errno.get(key)) {
                case Some(v) => errnoObj.set(key, JsValue(Float64(v)))
                case None => ()
            }
        }
        constantsObj.set("errno", JsValue(errnoObj))
        let priorityObj = JsObject()
        for (key in c.priority.keys()) {
            match (c.priority.get(key)) {
                case Some(v) => priorityObj.set(key, JsValue(Float64(v)))
                case None => ()
            }
        }
        constantsObj.set("priority", JsValue(priorityObj))
        obj.set("constants", JsValue(constantsObj))

        return JsValue(obj)
    }
}

/// CPU 信息 — 对应 Node.js os.cpus() 返回的对象
public class CpuInfo {
    public var model: String
    public var speed: Int64  // MHz
    public var times: CpuTimes

    public init() {
        model = ""
        speed = 0
        times = CpuTimes()
    }
}

/// CPU 时间统计 — 对应 Node.js os.cpus()[].times
public class CpuTimes {
    public var user: Int64
    public var nice: Int64
    public var sys: Int64
    public var idle: Int64
    public var irq: Int64

    public init() {
        user = 0
        nice = 0
        sys = 0
        idle = 0
        irq = 0
    }
}

/// 网络接口信息 — 对应 Node.js os.networkInterfaces() 返回的对象
public class NetworkInterface {
    public var name: String
    public var address: String
    public var netmask: String
    public var family: String  // "IPv4" or "IPv6"
    public var mac: String
    public var internal: Bool

    public init() {
        name = ""
        address = ""
        netmask = ""
        family = "IPv4"
        mac = ""
        internal = false
    }
}

/// 用户信息 — 对应 Node.js os.userInfo() 返回的对象
public class UserInfo {
    public var username: String
    public var uid: Int64
    public var gid: Int64
    public var shell: String
    public var homedir: String

    public init() {
        username = ""
        uid = 0
        gid = 0
        shell = ""
        homedir = ""
    }
}

/// 操作系统常量 — 对应 Node.js os.constants
public class OsConstants {
    public var signals: HashMap<String, Int64>
    public var errno: HashMap<String, Int64>
    public var priority: HashMap<String, Int64>

    public init() {
        signals = HashMap<String, Int64>()
        errno = HashMap<String, Int64>()
        priority = HashMap<String, Int64>()
    }
}
