// which.cj - which命令
// 对应 Bun: src/runtime/shell/builtin/which.zig
// 严格翻译Bun shell which命令到仓颉
// 1个参数 => 返回参数的绝对路径 (未找到则退出码1)
// N个参数 => 返回每个参数的绝对路径，用换行符分隔

package bao_runtime.shell.builtin

import bao_core.*

// ============================================================================
// which命令 - 查找可执行文件的路径
// ============================================================================

/// which命令
public class WhichCmd {
    /// 状态
    public var state: WhichState = WhichState.idle

    /// 状态类型
    public enum WhichState {
        case idle
        case oneArg
        case multiArgs(MultiArgsState)
        case done
    }

    /// 多参数状态
    /// 对应 Bun: multi_args struct in Which state
    public struct MultiArgsState {
        public var argsSlice: Array<String>
        public var argIdx: UInt32 = 0
        public var hadNotFound: Boolean = false
        public var innerState: MultiArgsInnerState = .none
    }

    /// 多参数内部状态
    public enum MultiArgsInnerState {
        case none
        case waitingWrite
    }

    /// 启动
    public func start(): Yield {
        let args = this.bltn().argsSlice()
        if (args.length == 0) {
            if (let safeguard = this.bltn().stdout.needsIO()) {
                this.state = WhichState.oneArg
                return this.bltn().stdout.enqueue(this, "\n".toByteArray(), safeguard)
            }
            this.bltn().writeNoIO(.stdout, "\n".toByteArray())
            return this.bltn().done(1)
        }

        if (this.bltn().stdout.needsIO() == None) {
            let pathBuf = PathBuffer()
            let PATH = this.bltn().exportEnv.get(EnvStr.initSlice("PATH")) ?? EnvStr.initSlice("")
            defer { PATH.deref() }
            var hadNotFound = false
            for (arg in args) {
                let resolved = WhichUtils.which(pathBuf, PATH.slice(), this.bltn().parentCmd().base.shell.cwdZ(), arg)
                if (resolved == None) {
                    hadNotFound = true
                    let buf = this.bltn().fmtErrorArena("which", "${arg} not found\n", [])
                    this.bltn().writeNoIO(.stdout, buf.toByteArray())
                    continue
                }
                this.bltn().writeNoIO(.stdout, resolved)
            }
            return this.bltn().done(if (hadNotFound) 1 else 0)
        }

        this.state = WhichState.multiArgs(MultiArgsState(
            argsSlice: args,
            argIdx: 0,
            innerState: .none
        ))
        return this.next()
    }

    /// 下一步
    public func next(): Yield {
        if (let multiArgs = this.state.getMultiArgs()) {
            if (multiArgs.argIdx >= multiArgs.argsSlice.length) {
                return this.bltn().done(if (multiArgs.hadNotFound) 1 else 0)
            }

            let arg = multiArgs.argsSlice[multiArgs.argIdx]
            let pathBuf = PathBuffer()
            let PATH = this.bltn().exportEnv.get(EnvStr.initSlice("PATH")) ?? EnvStr.initSlice("")
            defer { PATH.deref() }

            let resolved = WhichUtils.which(pathBuf, PATH.slice(), this.bltn().parentCmd().base.shell.cwdZ(), arg)
            if (resolved == None) {
                // 需要修改state中的hadNotFound
                this.state = WhichState.multiArgs(MultiArgsState(
                    argsSlice: multiArgs.argsSlice,
                    argIdx: multiArgs.argIdx,
                    hadNotFound: true,
                    innerState: .none
                ))
                if (let safeguard = this.bltn().stdout.needsIO()) {
                    this.state = WhichState.multiArgs(MultiArgsState(
                        argsSlice: multiArgs.argsSlice,
                        argIdx: multiArgs.argIdx,
                        hadNotFound: true,
                        innerState: .waitingWrite
                    ))
                    return this.bltn().stdout.enqueueFmtBltn(this, "", "${arg} not found\n", [], safeguard)
                }
                let buf = this.bltn().fmtErrorArena("", "${arg} not found\n", [])
                this.bltn().writeNoIO(.stdout, buf.toByteArray())
                return this.argComplete()
            }

            if (let safeguard = this.bltn().stdout.needsIO()) {
                this.state = WhichState.multiArgs(MultiArgsState(
                    argsSlice: multiArgs.argsSlice,
                    argIdx: multiArgs.argIdx,
                    hadNotFound: multiArgs.hadNotFound,
                    innerState: .waitingWrite
                ))
                return this.bltn().stdout.enqueueFmtBltn(this, "", "${resolved}\n", [], safeguard)
            }

            let buf = this.bltn().fmtErrorArena("", "${resolved}\n", [])
            this.bltn().writeNoIO(.stdout, buf.toByteArray())
            return this.argComplete()
        }

        return this.bltn().done(0)
    }

    /// 参数处理完成
    func argComplete(): Yield {
        if (let multiArgs = this.state.getMultiArgs()) {
            this.state = WhichState.multiArgs(MultiArgsState(
                argsSlice: multiArgs.argsSlice,
                argIdx: multiArgs.argIdx + 1,
                hadNotFound: multiArgs.hadNotFound,
                innerState: .none
            ))
            return this.next()
        }
        return this.bltn().done(0)
    }

    /// IO写入器数据块回调
    public func onIOWriterChunk(amount: UInt64, e: ?SystemError): Yield {
        if (let err = e) {
            defer { err.deref() }
            return this.bltn().done(err.getErrno())
        }

        if (this.state == .oneArg) {
            // 不带参数调用which返回退出码1
            return this.bltn().done(1)
        }

        return this.argComplete()
    }

    /// 去初始化
    public func deinit() {}

    /// 获取Builtin引用
    public func bltn(): Builtin {
        return Builtin.fromImpl(this, "which")
    }
}
