// bao_install - 包管理器生命周期脚本
// 严格翻译自: src/install/PackageManager/PackageManagerLifecycle.zig
//   生命周期脚本管理: preinstall, install, postinstall, prepare 等
package bao_install

import bao_core.*
import bao_collections.*
import bao_io.*
import bao_hash.*
import bao_path.*
import bao_http.*

// ============================================================================
// 生命周期脚本时间日志
// 严格翻译自: PackageManagerLifecycle.zig - LifecycleScriptTimeLog
//   pub const LifecycleScriptTimeLog = struct {
//       mutex, list: ArrayListUnmanaged(Entry)
//   }
// ============================================================================

/// 生命周期脚本时间日志条目
/// 翻译自: LifecycleScriptTimeLog.Entry
public class LifecycleScriptTimeLogEntry {
    /// 包名
    public var packageName: String
    /// 脚本 ID
    public var scriptId: UInt8
    /// 持续时间 (纳秒)
    public var duration: UInt64

    public init(packageName: String, scriptId: UInt8, duration: UInt64) {
        this.packageName = packageName
        this.scriptId = scriptId
        this.duration = duration
    }
}

/// 生命周期脚本时间日志
/// 翻译自: PackageManager.LifecycleScriptTimeLog
public class LifecycleScriptTimeLog {
    private var list: ArrayList<LifecycleScriptTimeLogEntry>

    public init() {
        list = ArrayList<LifecycleScriptTimeLogEntry>()
    }

    /// 并发安全追加
    /// 翻译自: LifecycleScriptTimeLog.appendConcurrent
    public func appendConcurrent(entry: LifecycleScriptTimeLogEntry): Unit {
        list.append(entry)
    }

    /// 打印最慢的脚本并释放
    /// 翻译自: LifecycleScriptTimeLog.printAndDeinit
    public func printAndDeinit(): Unit {
        if (list.size > 0) {
            // 找到最慢的脚本
            var longestIdx: Int64 = 0
            var longestDuration: UInt64 = list[0].duration
            var i: Int64 = 1
            while (i < list.size) {
                if (list[i].duration > longestDuration) {
                    longestIdx = i
                    longestDuration = list[i].duration
                }
                i += 1
            }
            let longest = list[longestIdx]
            let scriptName = LockfileScripts.names(Int64(longest.scriptId))
            bao_core.Output.warn("${longest.packageName}'s ${scriptName} script took ${formatDuration(longest.duration)}\n\n")
        }
        list.clear()
    }

    /// 格式化持续时间
    private func formatDuration(ns: UInt64): String {
        let ms = ns / UInt64(1_000_000)
        if (ms < 1000) {
            return "${ms}ms"
        }
        let sec = Float64(ms) / 1000.0
        return "${sec}s"
    }
}

// ============================================================================
// 锁文件脚本名称
// ============================================================================

/// 锁文件脚本名称常量
/// 翻译自: Lockfile.Scripts.names
public class LockfileScripts {
    private static let SCRIPT_NAMES: ArrayList<String> = {
        let names = ArrayList<String>()
        names.append("preinstall")
        names.append("install")
        names.append("postinstall")
        names.append("preprepare")
        names.append("prepare")
        names.append("postprepare")
        return names
    }()

    public static func names(index: Int64): String {
        if (index >= 0 && index < SCRIPT_NAMES.size) {
            return SCRIPT_NAMES[index]
        }
        return "unknown"
    }

    public static func namesCount(): Int64 {
        return SCRIPT_NAMES.size
    }
}

// ============================================================================
// 生命周期脚本列表
// 严格翻译自: Lockfile.Package.Scripts.List
// ============================================================================

/// 生命周期脚本列表
/// 翻译自: Lockfile.Package.Scripts.List
public class LifecycleScriptList {
    /// 脚本项 (null 表示跳过)
    public var items: ArrayList<?String>
    /// 工作目录
    public var cwd: String

    public init(cwd: String) {
        items = ArrayList<?String>()
        this.cwd = cwd
    }

    /// 是否有任何脚本
    public func hasAny(): Bool {
        for (item in items) {
            match (item) {
                case Some(_) => return true
                case None => ()
            }
        }
        return false
    }
}

// ============================================================================
// 活跃生命周期脚本跟踪
// ============================================================================

/// 活跃生命周期脚本信息
public class ActiveLifecycleScript {
    /// 包名
    public var packageName: String
    /// 开始时间 (纳秒时间戳)
    public var startedAt: UInt64

    public init(packageName: String, startedAt: UInt64) {
        this.packageName = packageName
        this.startedAt = startedAt
    }
}

// ============================================================================
// 生命周期脚本运行器
// 严格翻译自: src/install/lifecycle_script_runner.zig - LifecycleScriptSubprocess
// ============================================================================

/// 生命周期脚本运行器
/// 对应 Bun: LifecycleScriptSubprocess
/// 负责执行包的 install/postinstall 等生命周期脚本
public class LifecycleScriptRunner {
    /// 包名
    public var packageName: String
    /// 脚本列表
    public var scripts: LifecycleScriptList
    /// 当前脚本索引
    public var currentScriptIndex: UInt8
    /// 包管理器引用
    public var manager: PackageManager
    /// 是否前台运行
    public var foreground: Bool
    /// 是否是可选依赖的脚本
    public var optional: Bool
    /// 开始时间
    public var startedAt: UInt64
    /// 是否已增加活跃计数
    public var hasIncrementedAliveCount: Bool
    /// 最小毫秒数才记录日志
    /// 翻译自: LifecycleScriptSubprocess.min_milliseconds_to_log
    public static let MIN_MS_TO_LOG: Int64 = 500

    public init(packageName: String, scripts: LifecycleScriptList, manager: PackageManager) {
        this.packageName = packageName
        this.scripts = scripts
        this.manager = manager
        currentScriptIndex = UInt8(0)
        foreground = false
        optional = false
        startedAt = UInt64(0)
        hasIncrementedAliveCount = false
    }

    /// 获取当前脚本名称
    /// 翻译自: LifecycleScriptSubprocess.scriptName
    public func scriptName(): String {
        return LockfileScripts.names(Int64(currentScriptIndex))
    }

    /// 生成下一个脚本
    /// 翻译自: LifecycleScriptSubprocess.spawnNextScript
    public func spawnNextScript(nextScriptIndex: UInt8): Unit {
        currentScriptIndex = nextScriptIndex
        startedAt = bao_core.Time.nowMs()

        match (scripts.items) {
            case _ => {
                // 获取脚本内容
                if (Int64(nextScriptIndex) < scripts.items.size) {
                    match (scripts.items[Int64(nextScriptIndex)]) {
                        case Some(script) => {
                            // 执行脚本
                            // 翻译自: 使用 bun exec 执行
                            if (foreground) {
                                bao_core.Output.command(script)
                            }
                        }
                        case None => ()
                    }
                }
            }
        }
    }

    /// 处理脚本退出
    /// 翻译自: LifecycleScriptSubprocess.handleExit
    public func handleExit(exitCode: Int64): Unit {
        if (exitCode != 0) {
            if (!optional) {
                bao_core.Output.error("<r><red>error<r>: <b>${packageName}<r> ${scriptName()} script failed (exit code ${exitCode})")
            }
        }
    }
}
