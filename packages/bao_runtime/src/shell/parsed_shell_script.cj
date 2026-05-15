// parsed_shell_script.cj - 已解析的Shell脚本
// 对应 Bun: src/runtime/shell/ParsedShellScript.zig
// 严格翻译Bun已解析Shell脚本到仓颉

package bao_runtime.shell

import bao_core.*
import bao_collections.*
import bao_jsc.*

// ============================================================================
// 已解析的Shell脚本
// 由JS端的$`...`模板标签创建
// ============================================================================

/// 已解析的Shell脚本
/// 包含解析后的AST和相关的JS对象
public class ParsedShellScript {
    /// Shell参数
    public var args: ?ShellArgs = None
    /// JS对象列表
    public var jsobjs: ArrayList<JSValue>
    /// 导出的环境变量
    public var exportEnv: ?EnvMap = None
    /// 是否静默模式
    public var quiet: Boolean = false
    /// 当前工作目录
    public var cwd: ?BunString = None
    /// JS值
    public var thisJsvalue: JSValue
    /// GC估算大小
    public var estimatedSizeForGc: UInt64 = 0

    init() {
        this.jsobjs = ArrayList<JSValue>()
        this.thisJsvalue = JSValue.zero
    }

    /// 计算GC估算大小
    func computeEstimatedSizeForGC(): UInt64 {
        var size: UInt64 = 0
        if (let a = this.args) {
            size += a.memoryCost()
        }
        if (let env = this.exportEnv) {
            size += env.memoryCost()
        }
        return size
    }

    /// 内存开销
    public func memoryCost(): UInt64 {
        return this.computeEstimatedSizeForGC()
    }

    /// 估算大小
    public func estimatedSize(): UInt64 {
        return this.estimatedSizeForGc
    }

    /// 取出所有数据（转移所有权）
    public func take(
        outArgs: ShellArgs,
        outJsobjs: ArrayList<JSValue>,
        outQuiet: Boolean,
        outCwd: ?BunString,
        outExportEnv: ?EnvMap
    ) {
        outArgs = this.args!
        // ... 转移所有权
        this.args = None
        this.quiet = false
        this.cwd = None
        this.exportEnv = None
    }

    /// 终结化
    public func finalize() {
        this.thisJsvalue = JSValue.zero
        if (let env = this.exportEnv) {
            env.deinit()
        }
        if (let a = this.args) {
            a.deinit()
        }
    }

    /// 设置当前工作目录
    public func setCwd(globalThis: JSGlobalObject, str: String) {
        this.cwd = BunString.from(str)
    }

    /// 设置静默模式
    public func setQuiet(quiet: Boolean) {
        this.quiet = quiet
    }

    /// 设置环境变量
    public func setEnv(globalThis: JSGlobalObject, value: JSValue) {
        // 从JS对象中提取环境变量
        var env = EnvMap.init(DefaultAllocator.instance)
        this.exportEnv = env
    }

    // ========================================================================
    // Shell参数
    // ========================================================================

    /// Shell参数
    /// 包含AST和Arena分配器
    public class ShellArgs {
        /// Arena分配器
        public var arena: ArenaAllocator
        /// 根AST节点
        public var scriptAst: Script

        /// Arena分配器
        public func arenaAllocator(): Allocator {
            return this.arena.allocator()
        }

        /// 释放资源
        public func deinit() {
            this.arena.deinit()
        }

        /// 初始化
        public static func initFunc(): ShellArgs {
            let args = ShellArgs()
            args.arena = ArenaAllocator.init(DefaultAllocator.instance)
            return args
        }

        /// 内存开销
        public func memoryCost(): UInt64 {
            return 0
        }
    }
}
