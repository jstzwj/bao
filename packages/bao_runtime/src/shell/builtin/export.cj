// export.cj - export命令
// 对应 Bun: src/runtime/shell/builtin/export.zig
// 严格翻译Bun shell export命令到仓颉

package bao_runtime.shell.builtin

import bao_core.*

// ============================================================================
// export命令 - 设置或导出环境变量
// 无参数时按字典序打印所有导出变量
// ============================================================================

/// export命令
public class ExportCmd {
    /// 是否正在打印
    public var printing: Boolean = false

    /// 环境变量条目
    public struct Entry {
        public var key: EnvStr
        public var value: EnvStr

        /// 比较函数
        public static func compare(a: Entry, b: Entry): Int {
            return String.compare(a.key.slice(), b.key.slice())
        }
    }

    /// 写入输出
    public func writeOutput(fmt: String, args: Array<Any>): Yield {
        if (let safeguard = this.bltn().stdout.needsIO()) {
            this.printing = true
            return this.bltn().stdout.enqueueFmtBltn(this, "export", fmt, args, safeguard)
        }

        let buf = this.bltn().fmtErrorArena("export", fmt, args)
        this.bltn().writeNoIO(.stdout, buf.toByteArray())
        return this.bltn().done(0)
    }

    /// IO写入器数据块回调
    public func onIOWriterChunk(amount: UInt64, e: ?SystemError): Yield {
        let exitCode: ExitCode = if (let err = e) {
            defer { err.deref() }
            err.getErrno()
        } else 0

        return this.bltn().done(exitCode)
    }

    /// 启动
    public func start(): Yield {
        let args = this.bltn().argsSlice()

        // 不带参数调用`export`时按字典序打印所有导出的变量
        if (args.length == 0) {
            var keys = ArrayList<Entry>()
            var iter = this.bltn().exportEnv.iterator()
            while (let entry = iter.next()) {
                keys.append(Entry(key: entry.key, value: entry.value))
            }

            // 按字典序排序
            keys.sortWith({ a, b => Entry.compare(a, b) })

            // 计算总长度
            var totalLen: UInt32 = 0
            for (entry in keys) {
                totalLen += "${entry.key.slice()}=${entry.value.slice()}\n".length
            }

            var buf = ArrayList<Byte>()
            for (entry in keys) {
                let line = "${entry.key.slice()}=${entry.value.slice()}\n"
                buf.appendAll(line.toByteArray())
            }

            if (let safeguard = this.bltn().stdout.needsIO()) {
                this.printing = true
                return this.bltn().stdout.enqueue(this, buf.toArray(), safeguard)
            }

            this.bltn().writeNoIO(.stdout, buf.toArray())
            return this.bltn().done(0)
        }

        // 处理赋值参数
        for (argRaw in args) {
            let arg = argRaw
            if (arg.length == 0) {
                continue
            }

            let eqSignIdx = arg.indexOf('=')
            if (eqSignIdx < 0) {
                if (!ShellUtils.isValidVarName(arg)) {
                    let buf = this.bltn().fmtErrorArena("export", "`${arg}`: not a valid identifier", [])
                    return this.writeStderr("${buf}\n")
                }

                let labelEnvStr = EnvStr.dupeRefCounted(arg)
                defer { labelEnvStr.deref() }
                this.bltn().parentCmd().base.shell.assignVar(
                    this.bltn().parentCmd().base.interpreter,
                    labelEnvStr,
                    EnvStr.initSlice(""),
                    .exported
                )
                continue
            }

            let label = arg.substring(0, eqSignIdx)
            let value = arg.substring(eqSignIdx + 1)

            let labelEnvStr = EnvStr.dupeRefCounted(label)
            let valueEnvStr = EnvStr.dupeRefCounted(value)
            defer { labelEnvStr.deref() }
            defer { valueEnvStr.deref() }

            this.bltn().parentCmd().base.shell.assignVar(
                this.bltn().parentCmd().base.interpreter,
                labelEnvStr,
                valueEnvStr,
                .exported
            )
        }

        return this.bltn().done(0)
    }

    /// 写入标准错误
    func writeStderr(msg: String): Yield {
        if (let safeguard = this.bltn().stderr.needsIO()) {
            this.printing = true
            return this.bltn().stderr.enqueue(this, msg.toByteArray(), safeguard)
        }
        this.bltn().writeNoIO(.stderr, msg.toByteArray())
        return this.bltn().done(1)
    }

    /// 去初始化
    public func deinit() {}

    /// 获取Builtin引用
    public func bltn(): Builtin {
        return Builtin.fromImpl(this, "export")
    }
}
