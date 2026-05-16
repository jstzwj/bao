<div align="center">

# Bao

**A JavaScript / TypeScript Runtime Built with Cangjie**

Inspired by [Bun](https://github.com/oven-sh/bun), re-implementing the Bun source code in Huawei's Cangjie language.

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](./LICENSE)
[![Language: Cangjie](https://img.shields.io/badge/Language-Cangjie-orange.svg)](https://developer.huawei.com/consumer/cn/cangjie/)

[Documentation](./docs/) &nbsp;•&nbsp; [Architecture](./docs/architecture.md) &nbsp;•&nbsp; [Translation Plan](./docs/plan.md) &nbsp;•&nbsp; [FFI Bridge Spec](./docs/ffi-bridge.md)

</div>

---

## What is Bao?

Bao is an **all-in-one toolkit** for JavaScript and TypeScript apps. It ships as a single executable called `bao`.

At its core is the Bao runtime, a fast JavaScript runtime designed as a drop-in replacement for Node.js. It's written in **Cangjie** and powered by JavaScriptCore under the hood, dramatically reducing startup times and memory usage.

```bash
bao run index.tsx             # TS and JSX supported out-of-the-box
```

The `bao` command-line tool also implements a test runner, script runner, and Node.js-compatible package manager. Instead of 1,000 node_modules for development, you only need `bao`. Bao's built-in tools are significantly faster than existing options and usable in existing Node.js projects with little to no changes.

```bash
bao test                      # run tests
bao run start                 # run the `start` script in `package.json`
bao install <pkg>             # install a package
baox cowsay 'Hello, world!'   # execute a package
```

Bao originates from a rigorous source translation of [Bun](https://github.com/oven-sh/bun). While Bun is written in Rust and Zig, Bao re-implements it in Cangjie, bridging low-level C libraries such as JavaScriptCore and libuv via C FFI.

Core capabilities include:

- **JavaScript/TypeScript Runtime** — Execute JS/TS code powered by the JavaScriptCore engine
- **Module Bundler** — Built-in bundler with tree-shaking and code splitting support
- **Package Manager** — npm-compatible dependency installation and management
- **HTTP Server** — High-performance HTTP/WebSocket services
- **File I/O** — Efficient file operations based on libuv
- **SQLite Client** — Built-in SQLite database support

## Architecture Overview

```
┌─────────────────────────────────────────┐
│          CLI Layer (bao_cli)             │
├─────────────────────────────────────────┤
│    Application (Bundler/HTTP/SQL/Install)│
├─────────────────────────────────────────┤
│    Runtime (VM/Node API/Web API)         │
├─────────────────────────────────────────┤
│    Parser (Lexer/Parser/AST/Printer)     │
├─────────────────────────────────────────┤
│    Platform (IO/Network/Process/FS/Thread)│
├─────────────────────────────────────────┤
│    Foundation (Core types/Collections/    │
│                Unicode/Hash)              │
└─────────────────────────────────────────┘
```

## Getting Started

### Prerequisites

- **Cangjie SDK** — [Install the Cangjie development environment](https://developer.huawei.com/consumer/cn/cangjie/)
- **C Compiler** — GCC or Clang (for C FFI compilation)
- **CMake** — 3.16+ (for building C dependencies)

### Build

```bash
# Clone the repository
git clone https://github.com/your-username/bao.git
cd bao

# Build with cjpm
cjpm build
```

### Run Tests

```bash
# Run all tests
cjpm test

# Run tests for a specific package
cjpm test -p bao_core
```

## Technical Highlights

### Cangjie Language Adaptation

Bun is written in Rust/Zig, featuring ownership systems and comptime evaluation. When translating to Cangjie, Bao makes the following adaptations:

| Feature | Bun (Rust/Zig) | Bao (Cangjie) |
|---------|----------------|---------------|
| Memory Management | Ownership + Manual allocation | GC + Arena allocator |
| Error Handling | `Result<T,E>` + `?` operator | Exception `throw/catch` + `Option<T>` |
| Async Model | `async/await` | Thread + Callback pattern |
| Pointer Operations | Raw pointers | `CPointer<T>` + `unsafe` |
| Pattern Matching | Exhaustive `match` | `match` (with default branch) |

### C FFI Bridging

Bao bridges the following low-level C libraries through Cangjie's C FFI mechanism:

- **JavaScriptCore** — JavaScript engine (WebKit)
- **libuv** — Async I/O and event loop
- **zlib / brotli / zstd** — Compression algorithms
- **SQLite** — Embedded database
- **boringssl** — TLS/SSL encryption

## Contributing

Contributions are welcome! Please read the following documents to get started:

- [Translation Plan](./docs/plan.md) — Overall translation progress and milestones
- [Translation Guide](./docs/translation-guide.md) — Cangjie translation conventions and coding style
- [Architecture](./docs/architecture.md) — Project architecture and design decisions

### Contribution Workflow

1. Fork this repository
2. Create a feature branch (`git checkout -b feature/your-feature`)
3. Commit your changes (`git commit -m 'Add some feature'`)
4. Push to the branch (`git push origin feature/your-feature`)
5. Create a Pull Request

## Acknowledgments

- [Bun](https://github.com/oven-sh/bun) — The inspiration and source blueprint for this project
- [Cangjie Language](https://developer.huawei.com/consumer/cn/cangjie/) — A modern programming language developed by Huawei
- [JavaScriptCore](https://webkit.org/) — WebKit's JavaScript engine
- [libuv](https://libuv.org/) — Cross-platform async I/O library
- **Huawei** — For developing and maintaining the Cangjie language and its toolchain
- **The State Key Laboratory for Novel Software Technology, Nanjing University** — For research support and infrastructure

## License

This project is licensed under the [MIT License](./LICENSE).

This project statically links the following third-party libraries, each governed by its own license:

- **JavaScriptCore / WebKit** — [LGPL-2.1](https://opensource.org/licenses/LGPL-2.1)
- **libuv** — [MIT](https://github.com/libuv/libuv/blob/v1.x/LICENSE)
- **zlib** — [zlib License](https://opensource.org/licenses/Zlib)
- **brotli** — [MIT](https://github.com/google/brotli/blob/main/LICENSE)
- **zstd** — [BSD-3-Clause](https://github.com/facebook/zstd/blob/dev/LICENSE)
- **SQLite** — [Public Domain](https://www.sqlite.org/copyright.html)
