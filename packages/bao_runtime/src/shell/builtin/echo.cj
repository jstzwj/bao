// echo.cj - echo命令
// 对应 Bun: src/runtime/shell/builtin/echo.zig
// 严格翻译Bun shell echo命令到仓颉

package bao_runtime.shell.builtin

import bao_core.*

// ============================================================================
// echo命令 - 输出文本到标准输出
// 支持 -n (无换行), -e (转义序列), -E (禁用转义)
// ============================================================================

/// echo命令
public class EchoCmd {
    /// 输出缓冲区
    public var output: ArrayList<Byte> = ArrayList<Byte>()
    /// 状态
    public var state: EchoState = EchoState.idle

    /// 状态类型
    public enum EchoState {
        case idle
        case waiting
        case waitingWriteErr
        case done
    }

    /// 启动
    public func start(): Yield {
        var args = this.bltn().argsSlice()

        // 解析标志: echo接受-n, -e, -E的任意组合
        // 标志解析在第一个不以'-'开头或包含无效标志字符的参数处停止
        var noNewline = false
        var escapeSequences = false
        var flagsDone = false
        var argsStart: UInt32 = 0

        for (i in 0..args.length) {
            if (flagsDone) {
                break
            }
            let flag = args[i]
            if (flag.length < 2 || flag[0] != '-') {
                flagsDone = true
                break
            }
            // 验证所有字符是否为有效的echo标志
            var valid = true
            for (c in flag) {
                if (c != 'n' && c != 'e' && c != 'E') {
                    valid = false
                    break
                }
            }
            if (!valid) {
                flagsDone = true
                break
            }
            // 应用标志 (最后一个 -e/-E 生效)
            for (c in flag) {
                if (c == 'n') {
                    noNewline = true
                } else if (c == 'e') {
                    escapeSequences = true
                } else if (c == 'E') {
                    escapeSequences = false
                }
            }
            argsStart++
        }

        // 跳过标志参数
        var remainingArgs = ArrayList<String>()
        for (i in argsStart..args.length) {
            remainingArgs.append(args[i])
        }

        let argsLen = remainingArgs.length
        var hasLeadingNewline = false
        var stopOutput = false

        for (i in 0..argsLen) {
            if (stopOutput) {
                break
            }
            let theArg = remainingArgs[i]
            let isLast = (i == argsLen - 1)

            if (escapeSequences) {
                stopOutput = appendWithEscapes(this.output, theArg.toByteArray())
            } else {
                if (isLast) {
                    if (theArg.length > 0 && theArg[theArg.length - 1] == '\n') {
                        hasLeadingNewline = true
                    }
                    let trimmed = trimSubsequentLeadingChars(theArg, '\n')
                    this.output.appendAll(trimmed.toByteArray())
                } else {
                    this.output.appendAll(theArg.toByteArray())
                }
            }

            if (!stopOutput && !isLast) {
                this.output.append(' '.toByte())
            }
        }

        if (!stopOutput && !hasLeadingNewline && !noNewline) {
            this.output.append('\n'.toByte())
        }

        if (let safeguard = this.bltn().stdout.needsIO()) {
            this.state = EchoState.waiting
            return this.bltn().stdout.enqueue(this, this.output.toArray(), safeguard)
        }
        this.bltn().writeNoIO(.stdout, this.output.toArray())
        this.state = EchoState.done
        return this.bltn().done(0)
    }

    /// 追加带转义序列的内容
    /// 返回true如果遇到\c转义（表示停止所有输出）
    public static func appendWithEscapes(output: ArrayList<Byte>, input: Array<Byte>): Boolean {
        var i: UInt32 = 0
        while (i < input.length) {
            if (input[i] == '\\'.toByte() && i + 1 < input.length) {
                let next = input[i + 1]
                if (next == '\\'.toByte()) {
                    output.append('\\'.toByte())
                    i += 2
                } else if (next == 'a'.toByte()) {
                    output.append(0x07.toByte())
                    i += 2
                } else if (next == 'b'.toByte()) {
                    output.append(0x08.toByte())
                    i += 2
                } else if (next == 'c'.toByte()) {
                    // \c: 不再产生输出
                    return true
                } else if (next == 'e'.toByte() || next == 'E'.toByte()) {
                    output.append(0x1b.toByte())
                    i += 2
                } else if (next == 'f'.toByte()) {
                    output.append(0x0c.toByte())
                    i += 2
                } else if (next == 'n'.toByte()) {
                    output.append('\n'.toByte())
                    i += 2
                } else if (next == 'r'.toByte()) {
                    output.append('\r'.toByte())
                    i += 2
                } else if (next == 't'.toByte()) {
                    output.append('\t'.toByte())
                    i += 2
                } else if (next == 'v'.toByte()) {
                    output.append(0x0b.toByte())
                    i += 2
                } else if (next == '0'.toByte()) {
                    // \0nnn: 八进制值（最多3个八进制数字）
                    i += 2
                    var val: Byte = 0.toByte()
                    var digits: UInt32 = 0
                    while (digits < 3 && i < input.length &&
                           input[i] >= '0'.toByte() && input[i] <= '7'.toByte()) {
                        val = ((val.toInt() * 8) + (input[i] - '0'.toByte())).toByte()
                        i++
                        digits++
                    }
                    output.append(val)
                } else if (next == 'x'.toByte()) {
                    // \xHH: 十六进制值（最多2个十六进制数字）
                    i += 2
                    var val: Byte = 0.toByte()
                    var digits: UInt32 = 0
                    while (digits < 2 && i < input.length) {
                        if (let Some(hv) <- hexDigitValue(input[i])) {
                            val = ((val.toInt() * 16) + hv.toInt()).toByte()
                            i++
                            digits++
                        } else {
                            break
                        }
                    }
                    if (digits > 0) {
                        output.append(val)
                    } else {
                        // 没有有效的十六进制数字：原样输出\x
                        output.appendAll("\\x".toByteArray())
                    }
                } else {
                    // 未知转义：原样输出反斜杠和字符
                    output.append('\\'.toByte())
                    output.append(next)
                    i += 2
                }
            } else {
                output.append(input[i])
                i++
            }
        }
        return false
    }

    /// 十六进制数字值
    public static func hexDigitValue(c: Byte): ?Byte {
        if (c >= '0'.toByte() && c <= '9'.toByte()) {
            return (c.toInt() - '0'.toInt()).toByte()
        }
        if (c >= 'a'.toByte() && c <= 'f'.toByte()) {
            return (c.toInt() - 'a'.toInt() + 10).toByte()
        }
        if (c >= 'A'.toByte() && c <= 'F'.toByte()) {
            return (c.toInt() - 'A'.toInt() + 10).toByte()
        }
        return None
    }

    /// IO写入器数据块回调
    public func onIOWriterChunk(amount: UInt64, e: ?SystemError): Yield {
        if (let err = e) {
            err.deref()
            return this.bltn().done(err.getErrno())
        }

        this.state = EchoState.done
        let exitCode: ExitCode = if (this.state == .waitingWriteErr) 1 else 0
        return this.bltn().done(exitCode)
    }

    /// 去初始化
    public func deinit() {
        this.output.clear()
    }

    /// 获取Builtin引用
    public func bltn(): Builtin {
        return Builtin.fromImpl(this, "echo")
    }

    /// 修剪连续前导字符
    func trimSubsequentLeadingChars(s: String, c: Char): String {
        var result = s
        while (result.length > 0 && result[0] == c) {
            result = result.substring(1)
        }
        return result
    }
}
