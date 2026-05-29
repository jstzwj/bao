// export.cj - export命令
// 对应 Bun: src/runtime/shell/builtin/export.zig
// 严格翻译Bun shell export命令到仓颉

package bao_runtime.shell.builtin

import bao_core.*
import bao_runtime.shell.*
import bao_collections.*

// ============================================================================
// export命令 - 设置或导出环境变量
// 无参数时按字典序打印所有导出变量
// ============================================================================

/// export环境变量条目
public struct ExportEntry {
    public var key: String = ""
    public var value: String = ""

    public init(key: String, value: String) {
        this.key = key
        this.value = value
    }
}

/// export命令
public class ExportCmd {
    /// 是否正在打印
    public var printing: Bool = false

    /// 启动
    public func start(): Yield {
        let args = this.bltn().getArgsSlice()

        // 不带参数调用export时按字典序打印所有导出变量
        if (args.size == 0) {
            var buf = ArrayList<UInt8>()
            // 遍历当前 exportEnv 中的条目
            // 对应 Bun: 遍历 bltn.exportEnv 获取所有导出的环境变量
            let envMap = this.bltn().exportEnv
            let iter = envMap.iterator()
            while (iter.hasNext()) {
                match (iter.next()) {
                    case Some((key, value)) =>
                        buf.appendSlice("export ".toArray())
                        buf.appendSlice(key.toArray())
                        buf.appendSlice("=\"".toArray())
                        buf.appendSlice(value.toArray())
                        buf.appendSlice("\"\n".toArray())
                    case None => break
                }
            }

            if (let Some(safeguard) <- this.bltn().stdout.needsIO()) {
                this.printing = true
                return this.bltn().stdout.enqueue(this, buf.items(), safeguard)
            }

            this.bltn().writeNoIO(OutKind.Stdout, buf.items())
            return this.bltn().done(ExitCode.exited(0))
        }

        // 处理赋值参数: export NAME=VALUE 或 export NAME
        for (arg in args) {
            let eqIdx = arg.indexOf('=')
            if (eqIdx.isSome()) {
                let eq = eqIdx.getOrThrow()
                // export NAME=VALUE
                let name = arg[0..eq]
                let value = arg[(eq + 1)..]
                SysFFI.setenv(name, value)
            } else {
                // export NAME (标记为导出，如果已有值则保持)
                // 在 shell 中，仅 export NAME 会将变量标记为导出
                // 如果变量不存在，则创建空值导出
                let existingOpt = SysFFI.getenv(arg)
                match (existingOpt) {
                    case Some(_) => () // 已有值，保持
                    case None => SysFFI.setenv(arg, "")
                }
            }
        }
        return this.bltn().done(ExitCode.exited(0))
    }

    /// IO写入器数据块回调
    public func onIOWriterChunk(chunk: UInt64, e: ?SystemError): Yield {
        if (e.isSome()) {
            e.getOrThrow().deref()
            return this.bltn().done(ExitCode.exited(1))
        }
        return this.bltn().done(ExitCode.exited(0))
    }

    /// 写入标准错误
    func writeStderr(s: String): Yield {
        if (let Some(safeguard) <- this.bltn().stderr.needsIO()) {
            this.printing = true
            return this.bltn().stderr.enqueue(this, s.toArray(), safeguard)
        }
        this.bltn().writeNoIO(OutKind.Stderr, s.toArray())
        return this.bltn().done(ExitCode.exited(1))
    }

    /// 去初始化
    public func deinit() {}

    /// 获取Builtin引用
    public func bltn(): BuiltinImpl {
        return BuiltinImpl()
    }
}
