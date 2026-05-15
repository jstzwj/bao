// bao_clap - 命令行参数解析库
// 严格翻译自: src/clap/
//   Bun 的命令行参数解析库 (类似 Python argparse):
//   - clap.zig: 核心类型 (Names, Values, Param, Diagnostic, Help, help/usage 生成)
//   - comptime.zig: ComptimeClap (编译期参数解析, 运行时结果存储)
//   - streaming.zig: StreamingClap (流式参数解析器)
//   - args.zig: 参数迭代器 (SliceIterator, OsIterator, ShellIterator)
//   此处提供:
//   - ClapParam: 参数定义 (对应 clap.Param)
//   - ClapParser: 参数解析器 (对应 ComptimeClap + StreamingClap)
//   - ParseResult: 解析结果 (对应 ComptimeClap 实例)
//   - formatHelp(): 帮助文本生成 (对应 clap.help/simpleHelp)
//   - formatUsage(): 用法行生成 (对应 clap.usage/usageFull)
package bao.clap

import bao_core.*
