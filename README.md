<div align="center">

# Bao

**使用仓颉 (Cangjie) 语言构建的 JavaScript / TypeScript 运行时**

灵感来自 [Bun](https://github.com/oven-sh/bun)，将 Bun 源码一比一严格翻译为华为仓颉语言实现。

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](./LICENSE)
[![Language: Cangjie](https://img.shields.io/badge/Language-Cangjie-orange.svg)](https://developer.huawei.com/consumer/cn/cangjie/)

[文档](./docs/) &nbsp;•&nbsp; [架构设计](./docs/architecture.md) &nbsp;•&nbsp; [翻译计划](./docs/plan.md) &nbsp;•&nbsp; [FFI 桥接规范](./docs/ffi-bridge.md)

</div>

---

## Bao 是什么？

Bao 是一个将 [Bun](https://github.com/oven-sh/bun)（一个高性能 JavaScript/TypeScript 运行时）的源码严格翻译为 **仓颉 (Cangjie)** 语言的开源项目。目标是在仓颉生态中提供完整的 JavaScript/TypeScript 运行时能力。

Bun 使用 Rust 和 Zig 编写，而 Bao 使用仓颉语言重新实现，同时通过 C FFI 桥接 JavaScriptCore、libuv 等底层 C 库。

核心能力包括：

- **JavaScript/TypeScript 运行时** — 基于 JavaScriptCore 引擎执行 JS/TS 代码
- **模块打包器** — 内置 Bundler，支持 tree-shaking 和代码分割
- **包管理器** — npm 兼容的依赖安装与管理
- **HTTP 服务器** — 高性能 HTTP/WebSocket 服务
- **文件 I/O** — 基于 libuv 的高效文件操作
- **SQLite 客户端** — 内置 SQLite 数据库支持

## 项目状态

Bao 目前处于 **早期开发阶段**，按照 6 个阶段逐步翻译 Bun 源码：

| 阶段 | 内容 | 状态 |
|------|------|------|
| 阶段 0 | 项目骨架搭建 | 已完成 |
| 阶段 1 | 基础库（核心类型 / 集合 / Unicode / Hash） | 开发中 |
| 阶段 2 | 平台层（IO / 网络 / 线程 / 事件循环） | 计划中 |
| 阶段 3 | 解析器（JS/TS 词法 / 语法分析 / AST） | 计划中 |
| 阶段 4 | 运行时（JSC 绑定 / Node.js API / Web API） | 计划中 |
| 阶段 5 | 应用层（Bundler / 包管理器 / CLI） | 计划中 |

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

## 项目结构

```
bao/
├── cjpm.toml                  # 根工作区配置
├── docs/                       # 文档
│   ├── plan.md                 # 翻译总体规划
│   ├── architecture.md         # 架构设计
│   ├── ffi-bridge.md           # FFI 桥接规范
│   └── translation-guide.md    # 翻译规范
├── packages/                   # 55+ 仓颉包
│   ├── bao_core/               # 核心类型和工具
│   ├── bao_collections/        # 集合数据结构
│   ├── bao_unicode/            # Unicode 处理
│   ├── bao_hash/               # 哈希算法 (WyHash, HighwayHash)
│   ├── bao_path/               # 文件路径处理
│   ├── bao_sys/                # 系统调用和 C FFI 绑定
│   ├── bao_io/                 # 文件 I/O 操作
│   ├── bao_threading/          # 线程和并发
│   ├── bao_event_loop/         # 事件循环 (libuv)
│   ├── bao_parser/             # JS/TS 解析器
│   ├── bao_runtime/            # JavaScript 运行时
│   ├── bao_http/               # HTTP 服务和客户端
│   ├── bao_bundler/            # 模块打包器
│   ├── bao_install/            # 包管理器
│   ├── bao_sql/                # SQLite 数据库
│   ├── bao_jsc/                # JavaScriptCore 绑定
│   ├── bao_cli/                # 命令行工具
│   └── ...                     # 更多模块
├── test/                       # 集成测试
└── tools/                      # 开发辅助工具
```

## 包一览

### 基础层
| 包名 | 说明 |
|------|------|
| `bao_core` | 核心类型、错误处理、内存管理 |
| `bao_collections` | HashMap、ArrayList 等数据结构 |
| `bao_unicode` | Unicode 字素分析和字符表 |
| `bao_hash` | WyHash、HighwayHash、SHA 等哈希算法 |
| `bao_path` | 跨平台文件路径处理 |

### 平台层
| 包名 | 说明 |
|------|------|
| `bao_sys` | POSIX 系统调用和 C FFI 绑定 |
| `bao_io` | 文件读写、流、缓冲区 |
| `bao_threading` | 线程池、互斥锁、条件变量 |
| `bao_event_loop` | 基于 libuv 的事件循环 |
| `bao_spawn` | 子进程管理 |

### 解析器层
| 包名 | 说明 |
|------|------|
| `bao_parser` | JavaScript/TypeScript 解析器 |
| `bao_ast` | 抽象语法树 (AST) 定义 |
| `bao_parsers` | 辅助解析器集合 |
| `bao_shell_parser` | Shell 语法解析 |

### 运行时层
| 包名 | 说明 |
|------|------|
| `bao_runtime` | JavaScript 运行时核心 |
| `bao_jsc` | JavaScriptCore C API 绑定 |
| `bao_http` | HTTP/WebSocket 服务端和客户端 |
| `bao_sql` | SQLite 数据库客户端 |
| `bao_url` | URL 解析和处理 |

### 应用层
| 包名 | 说明 |
|------|------|
| `bao_bundler` | JavaScript 模块打包器 |
| `bao_install` | npm 兼容包管理器 |
| `bao_resolver` | 模块解析器 |
| `bao_cli` | 命令行入口 |
| `bao_transpiler` | TypeScript/JSX 转译器 |

### 工具库
| 包名 | 说明 |
|------|------|
| `bao_zlib` | zlib 压缩 |
| `bao_brotli` | Brotli 压缩 |
| `bao_zstd` | Zstandard 压缩 |
| `bao_base64` | Base64 编解码 |
| `bao_semver` | 语义版本号解析 |
| `bao_sourcemap` | Source Map 处理 |
| `bao_dotenv` | .env 文件解析 |
| `bao_ini` | INI 配置文件解析 |
| `bao_router` | 路由系统 |

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

## 许可证

本项目基于 [MIT 许可证](./LICENSE) 开源。

本项目静态链接了以下第三方库，它们各自拥有独立的许可证：

- **JavaScriptCore / WebKit** — [LGPL-2.1](https://opensource.org/licenses/LGPL-2.1)
- **libuv** — [MIT](https://github.com/libuv/libuv/blob/v1.x/LICENSE)
- **zlib** — [zlib License](https://opensource.org/licenses/Zlib)
- **brotli** — [MIT](https://github.com/google/brotli/blob/main/LICENSE)
- **zstd** — [BSD-3-Clause](https://github.com/facebook/zstd/blob/dev/LICENSE)
- **SQLite** — [Public Domain](https://www.sqlite.org/copyright.html)
