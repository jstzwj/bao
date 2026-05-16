<div align="center">

# Bao

**使用仓颉 (Cangjie) 语言构建的 JavaScript / TypeScript 运行时**

灵感来自 [Bun](https://github.com/oven-sh/bun)，将 Bun 源码使用华为仓颉语言实现。

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](./LICENSE)
[![Language: Cangjie](https://img.shields.io/badge/Language-Cangjie-orange.svg)](https://developer.huawei.com/consumer/cn/cangjie/)

[文档](./docs/) &nbsp;•&nbsp; [架构设计](./docs/architecture.md) &nbsp;•&nbsp; [翻译计划](./docs/plan.md) &nbsp;•&nbsp; [FFI 桥接规范](./docs/ffi-bridge.md)

</div>

---

## Bao 是什么？

Bao 是一个面向 JavaScript 和 TypeScript 应用的**一体化工具链**，以单个可执行文件 `bao` 的形式发布。

它的核心是 Bao 运行时——一个快速的 JavaScript 运行时，设计为 Node.js 的直接替代品。Bao 使用**仓颉 (Cangjie)** 语言编写，底层由 JavaScriptCore 驱动，显著降低启动时间和内存占用。

```bash
bao run index.tsx             # 开箱即用的 TS 和 JSX 支持
```

`bao` 命令行工具还内置了测试运行器、脚本运行器和兼容 Node.js 的包管理器。开发时不再需要一千个 node_modules，只需要 `bao`。Bao 的内置工具比现有方案快得多，并且可以在现有 Node.js 项目中以几乎零改动的方式使用。

```bash
bao test                      # 运行测试
bao run start                 # 运行 package.json 中的 start 脚本
bao install <pkg>             # 安装依赖包
baox cowsay 'Hello, world!'   # 执行一个包
```

Bao 源自 [Bun](https://github.com/oven-sh/bun) 的源码翻译。Bun 使用 Rust 和 Zig 编写，而 Bao 使用仓颉语言重新实现，同时通过 C FFI 桥接 JavaScriptCore、libuv 等底层 C 库。

核心能力包括：

- **JavaScript/TypeScript 运行时** — 基于 JavaScriptCore 引擎执行 JS/TS 代码
- **模块打包器** — 内置 Bundler，支持 tree-shaking 和代码分割
- **包管理器** — npm 兼容的依赖安装与管理
- **HTTP 服务器** — 高性能 HTTP/WebSocket 服务
- **文件 I/O** — 基于 libuv 的高效文件操作
- **SQLite 客户端** — 内置 SQLite 数据库支持

## 架构概览

```
┌─────────────────────────────────────────┐
│          CLI 层 (bao_cli)                │
├─────────────────────────────────────────┤
│    应用层 (Bundler/HTTP/SQL/Install)     │
├─────────────────────────────────────────┤
│    运行时层 (VM/Node API/Web API)        │
├─────────────────────────────────────────┤
│    解析器层 (Lexer/Parser/AST/Printer)   │
├─────────────────────────────────────────┤
│    平台层 (IO/网络/进程/文件系统/线程)     │
├─────────────────────────────────────────┤
│    基础层 (核心类型/集合/Unicode/Hash)    │
└─────────────────────────────────────────┘
```

## 快速开始

### 环境要求

- **仓颉 SDK** — [安装仓颉开发环境](https://developer.huawei.com/consumer/cn/cangjie/)
- **C 编译器** — GCC 或 Clang（用于 C FFI 编译）
- **CMake** — 3.16+（用于构建 C 依赖库）

### 构建

```bash
# 克隆仓库
git clone https://github.com/your-username/bao.git
cd bao

# 使用 cjpm 构建
cjpm build
```

### 运行测试

```bash
# 运行所有测试
cjpm test

# 运行指定包的测试
cjpm test -p bao_core
```

## 技术特点

### 仓颉语言适配

Bun 使用 Rust/Zig 编写，具有所有权系统和 comptime 编译期计算等特性。Bao 在翻译到仓颉语言时做了以下适配：

| 特性 | Bun (Rust/Zig) | Bao (仓颉) |
|------|----------------|------------|
| 内存管理 | 所有权 + 手动分配 | GC + Arena 分配器 |
| 错误处理 | `Result<T,E>` + `?` 操作符 | 异常 `throw/catch` + `Option<T>` |
| 异步模型 | `async/await` | 线程 + 回调模式 |
| 指针操作 | 原生指针 | `CPointer<T>` + `unsafe` |
| 模式匹配 | 穷尽 `match` | `match` (含默认分支) |

### C FFI 桥接

Bao 通过仓颉的 C FFI 机制桥接以下底层 C 库：

- **JavaScriptCore** — JavaScript 引擎 (WebKit)
- **libuv** — 异步 I/O 和事件循环
- **zlib / brotli / zstd** — 压缩算法
- **SQLite** — 嵌入式数据库
- **boringssl** — TLS/SSL 加密

## 贡献

欢迎贡献代码！请阅读以下文档了解如何参与：

- [翻译计划](./docs/plan.md) — 了解整体翻译进度和阶段划分
- [翻译规范](./docs/translation-guide.md) — 仓颉语言翻译约定和编码风格
- [架构设计](./docs/architecture.md) — 项目架构和设计决策

### 贡献流程

1. Fork 本仓库
2. 创建功能分支 (`git checkout -b feature/your-feature`)
3. 提交更改 (`git commit -m 'Add some feature'`)
4. 推送到分支 (`git push origin feature/your-feature`)
5. 创建 Pull Request

## 致谢

- [Bun](https://github.com/oven-sh/bun) — 本项目的灵感来源和翻译蓝本
- [仓颉语言](https://developer.huawei.com/consumer/cn/cangjie/) — 华为开发的现代编程语言
- [JavaScriptCore](https://webkit.org/) — WebKit 的 JavaScript 引擎
- [libuv](https://libuv.org/) — 跨平台异步 I/O 库
- **华为 (Huawei)** — 开发和维护仓颉语言及其工具链
- **南京大学计算机软件新技术全国重点实验室 (The State Key Laboratory for Novel Software Technology, Nanjing University)** — 提供研究支持和基础设施

## 许可证

本项目基于 [MIT 许可证](./LICENSE) 开源。

本项目静态链接了以下第三方库，它们各自拥有独立的许可证：

- **JavaScriptCore / WebKit** — [LGPL-2.1](https://opensource.org/licenses/LGPL-2.1)
- **libuv** — [MIT](https://github.com/libuv/libuv/blob/v1.x/LICENSE)
- **zlib** — [zlib License](https://opensource.org/licenses/Zlib)
- **brotli** — [MIT](https://github.com/google/brotli/blob/main/LICENSE)
- **zstd** — [BSD-3-Clause](https://github.com/facebook/zstd/blob/dev/LICENSE)
- **SQLite** — [Public Domain](https://www.sqlite.org/copyright.html)
