// bao_standalone_graph - 独立模块图
// 严格翻译自: bun/src/standalone_graph/StandaloneModuleGraph.zig
//   用于 `bun build --compile` 的单文件可执行打包
//   将所有源文件、sourcemap、元数据序列化为二进制格式，追加到可执行文件末尾
//
// 核心数据结构:
//   StandaloneModuleGraph   - 模块图主结构，包含文件哈希表和二进制数据
//   ModuleEntry             - 单个模块条目 (路径、源码、loader、sourcemap)
//   BinaryFormatHeader      - 二进制格式头部 (magic bytes, version, entry count)
//   StandaloneReader/Writer - 二进制格式的读写器
//
// 二进制布局:
//   [modules array bytes] [string data] [Offsets struct] ["\n---- Bun! ----\n"]
//
// 运行时通过 MachO/ELF/PE 段加载，通过 trailer 验证完整性
package bao.standalone_graph

import bao_core.*
import bao_sourcemap.*
