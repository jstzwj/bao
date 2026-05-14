# Bun → Bao (仓颉) 翻译总体规划

> 目标：将 `/data2/wangjun/github/bun` 的 Bun 源码一比一严格翻译为仓颉(Cangjie)语言

## 一、项目规模总览

| 指标 | 数据 |
|------|------|
| 源码总量 | ~169万行 (Rust + Zig) |
| Zig 文件 | ~1,290 个 (~142万行) |
| Rust 文件 | ~1,432 个 (~196万行，含生成代码) |
| 源码子模块 | 110+ 个 |
| 测试文件 | 1,536 个 |
| 第三方依赖 | JavaScriptCore, libuv, boringssl, zlib, brotli, SQLite 等 |

## 二、Bun 核心架构分层

```
┌─────────────────────────────────────────┐
│          CLI 层 (命令行入口)              │
├─────────────────────────────────────────┤
│      应用层 (Bundler/HTTP/SQL/Install)   │
├─────────────────────────────────────────┤
│      Runtime层 (Node.js API / Web API)   │
├─────────────────────────────────────────┤
│      JS引擎层 (JSC绑定/JS解析器/打印机)    │
├─────────────────────────────────────────┤
│      平台层 (IO/网络/进程/文件系统/线程)    │
├─────────────────────────────────────────┤
│      基础层 (核心类型/集合/Unicode/Hash)   │
└─────────────────────────────────────────┘
```

各层依赖关系：上层依赖下层，不可反向依赖。

## 三、源码目录与模块映射

### 3.1 Bun src/ 目录完整清单 (85个子模块)

#### 基础层
| Bun 模块 | 路径 | 功能描述 | 预估行数 |
|---------|------|---------|---------|
| bun_core | `src/bun_core/` | 核心工具、类型、内存管理、基础原语 | ~50K |
| string | `src/string/` | 字符串处理 (ZigString, StringBuilder等) | ~40K |
| collections | `src/collections/` | 数据结构 (HashMap, ArrayList等) | ~15K |
| unicode | `src/unicode/` | Unicode 工具和字素表 | ~40K |
| hash | `src/hash/` | 哈希算法 | ~5K |
| wyhash | `src/wyhash/` | WyHash 哈希算法 | ~3K |
| highway | `src/highway/` | HighwayHash 哈希算法 | ~2K |
| bun_alloc | `src/bun_alloc/` | 内存分配器 | ~5K |
| ptr | `src/ptr/` | 指针工具 | ~2K |
| safety | `src/safety/` | 安全工具 | ~2K |

#### 平台层
| Bun 模块 | 路径 | 功能描述 | 预估行数 |
|---------|------|---------|---------|
| sys | `src/sys/` | 系统绑定和FFI | ~90K |
| sys_jsc | `src/sys_jsc/` | 系统绑定JSC桥接 | ~20K |
| io | `src/io/` | 文件IO操作 | ~30K |
| threading | `src/threading/` | 线程同步和池 | ~20K |
| event_loop | `src/event_loop/` | 事件循环实现 | ~15K |
| spawn | `src/spawn/` | 进程创建和管理 | ~15K |
| spawn_sys | `src/spawn_sys/` | 进程系统调用绑定 | ~5K |
| paths | `src/paths/` | 文件路径处理 | ~10K |
| platform | `src/platform/` | 平台特定实现 | ~10K |
| dns | `src/dns/` | DNS 解析 | ~10K |
| cares_sys | `src/cares_sys/` | c-ares DNS库绑定 | ~5K |
| watcher | `src/watcher/` | 文件监视 | ~10K |
| glob | `src/glob/` | Glob 模式匹配 | ~5K |

#### JS引擎层
| Bun 模块 | 路径 | 功能描述 | 预估行数 |
|---------|------|---------|---------|
| jsc | `src/jsc/` | JavaScriptCore 绑定 | ~200K |
| js_parser | `src/js_parser/` | JavaScript/TypeScript 解析器 | ~100K |
| js_printer | `src/js_printer/` | JavaScript 代码生成器 | ~65K |
| ast | `src/ast/` | 抽象语法树定义 | ~50K |
| ast_jsc | `src/ast_jsc/` | AST JSC桥接 | ~20K |
| codegen | `src/codegen/` | 代码生成 | ~30K |
| dispatch | `src/dispatch/` | 调度系统 | ~10K |

#### CSS 处理
| Bun 模块 | 路径 | 功能描述 | 预估行数 |
|---------|------|---------|---------|
| css | `src/css/` | CSS 解析器 | ~200K |
| css_jsc | `src/css_jsc/` | CSS JSC桥接 | ~15K |
| css_derive | `src/css_derive/` | CSS 派生宏 | ~10K |

#### 运行时层
| Bun 模块 | 路径 | 功能描述 | 预估行数 |
|---------|------|---------|---------|
| runtime | `src/runtime/` | 运行时核心 | ~500K |
| api | `src/api/` | Web API 实现 | ~100K |
| cli | `src/cli/` | CLI 命令系统 | ~30K |

#### 应用层
| Bun 模块 | 路径 | 功能描述 | 预估行数 |
|---------|------|---------|---------|
| bundler | `src/bundler/` | 打包器 | ~80K |
| bundler_jsc | `src/bundler_jsc/` | 打包器JSC桥接 | ~15K |
| http | `src/http/` | HTTP 服务和客户端 | ~50K |
| http_jsc | `src/http_jsc/` | HTTP JSC桥接 | ~15K |
| http_types | `src/http_types/` | HTTP 类型定义 | ~10K |
| uws | `src/uws/` | uWebSockets | ~30K |
| uws_sys | `src/uws_sys/` | uWS C绑定 | ~10K |
| websocket | `src/websocket/` | WebSocket 实现 | ~20K |
| install | `src/install/` | 包管理器 | ~100K |
| install_jsc | `src/install_jsc/` | 包管理器JSC桥接 | ~15K |
| install_types | `src/install_types/` | 包管理器类型 | ~5K |
| sql | `src/sql/` | 数据库 (SQLite等) | ~50K |
| sql_jsc | `src/sql_jsc/` | 数据库JSC桥接 | ~15K |
| resolver | `src/resolver/` | 模块解析器 | ~100K |
| standalone_graph | `src/standalone_graph/` | 独立构建图 | ~10K |

#### 压缩/加密库绑定
| Bun 模块 | 路径 | 功能描述 | 预估行数 |
|---------|------|---------|---------|
| zlib | `src/zlib/` | zlib 压缩 | ~5K |
| zlib_sys | `src/zlib_sys/` | zlib C绑定 | ~3K |
| brotli | `src/brotli/` | Brotli 压缩 | ~5K |
| brotli_sys | `src/brotli_sys/` | Brotli C绑定 | ~3K |
| zstd | `src/zstd/` | Zstandard 压缩 | ~5K |
| boringssl | `src/boringssl/` | SSL/TLS 实现 | ~10K |
| boringssl_sys | `src/boringssl_sys/` | BoringSSL C绑定 | ~19K |
| base64 | `src/base64/` | Base64 编解码 | ~3K |
| simdutf_sys | `src/simdutf_sys/` | SIMD UTF绑定 | ~2K |
| sha_hmac | `src/sha_hmac/` | SHA/HMAC 实现 | ~5K |
| csrf | `src/csrf/` | CSRF 保护 | ~3K |
| s3_signing | `src/s3_signing/` | S3 签名 | ~5K |

#### 其他工具模块
| Bun 模块 | 路径 | 功能描述 | 预估行数 |
|---------|------|---------|---------|
| transpiler | `src/transpiler/` | 源码转译 (TS, JSX) | ~30K |
| picohttp | `src/picohttp/` | 轻量HTTP解析 | ~10K |
| picohttp_sys | `src/picohttp_sys/` | picohttp C绑定 | ~3K |
| url | `src/url/` | URL 解析 | ~10K |
| url_jsc | `src/url_jsc/` | URL JSC桥接 | ~5K |
| semver | `src/semver/` | 语义版本 | ~10K |
| semver_jsc | `src/semver_jsc/` | 语义版本JSC桥接 | ~3K |
| sourcemap | `src/sourcemap/` | Source Map 处理 | ~15K |
| sourcemap_jsc | `src/sourcemap_jsc/` | Source Map JSC桥接 | ~5K |
| dotenv | `src/dotenv/` | .env 文件解析 | ~5K |
| ini | `src/ini/` | INI 文件解析 | ~3K |
| which | `src/which/` | 可执行文件查找 | ~3K |
| analytics | `src/analytics/` | 分析统计 | ~5K |
| perf | `src/perf/` | 性能监控 | ~5K |
| tcc_sys | `src/tcc_sys/` | TinyCC C编译器绑定 | ~5K |
| exe_format | `src/exe_format/` | 可执行文件格式 | ~10K |
| ini | `src/ini/` | INI配置解析 | ~3K |
| shell_parser | `src/shell_parser/` | Shell语法解析 | ~10K |
| crash_handler | `src/crash_handler/` | 崩溃处理 | ~5K |
| patch | `src/patch/` | 补丁系统 | ~5K |
| patch_jsc | `src/patch_jsc/` | 补丁JSC桥接 | ~3K |
| options_types | `src/options_types/` | 选项类型 | ~5K |
| output | `src/output/` | 输出处理 | ~5K |
| bun_output_tags | `src/bun_output_tags/` | 输出标签 | ~3K |
| resolve_builtins | `src/resolve_builtins/` | 内置模块解析 | ~5K |
| router | `src/router/` | 路由系统 | ~5K |
| opaque | `src/opaque/` | 不透明类型 | ~3K |
| clap | `src/clap/` | 命令行参数解析 | ~10K |
| clap_macros | `src/clap_macros/` | 命令行参数宏 | ~5K |
| bunfig | `src/bunfig/` | Bun配置文件解析 | ~10K |
| bun_core_macros | `src/bun_core_macros/` | 核心宏 | ~5K |
| valkey | `src/valkey/` | Valkey/Redis客户端 | ~10K |

### 3.2 核心数据结构

#### 字符串类型
- `ZigString` - 指针标记的 UTF-8 字符串
- `WTFString` - WebKit风格多编码字符串
- `PathString` - 文件路径表示
- `StringBuilder` - 高效字符串构建器
- `HashedString` - 预哈希字符串

#### 运行时类型
- `JSValue` - JavaScriptCore 值表示
- `VirtualMachine` - JavaScript 执行环境
- `GlobalObject` - 全局 JavaScript 对象
- `JSCell` - JavaScriptCore 基础对象

#### 打包器类型
- `ModuleGraph` - 模块依赖图
- `BundleResult` - 打包结果
- `Chunk` - 输出块

#### 系统类型
- `Fd` - 文件描述符
- `PathBuffer` - 文件路径缓冲区
- `Arena` - 内存竞技场分配器

## 四、仓颉语言适配分析

### 4.1 语言特性对照

| 特性 | Rust/Zig | 仓颉 (Cangjie) | 翻译策略 |
|------|---------|----------------|---------|
| 所有权/生命周期 | `&mut`, 生命周期标注 | GC + 手动管理 | 去除所有权语义，依赖GC |
| 错误处理 | `Result<T,E>`, `?` 操作符 | `Option<T>`, 异常 `throw/try-catch` | Result → 异常或Option |
| 泛型 | 完整泛型 + monomorphization | 泛型支持 | 直接翻译，注意约束差异 |
| 枚举/代数类型 | `enum` (带数据) | `enum` (支持关联值) | 直接翻译 |
| 模式匹配 | `match` (穷尽) | `match` (非穷尽) | 添加默认分支 |
| trait/接口 | `trait`, `impl` | `interface`, `impl` | trait → interface |
| 宏 | `macro_rules!`, 过程宏 | 宏系统 (有限) | 简化或手写生成代码 |
| comptime | Zig comptime | 无直接等价 | 运行时代替或代码生成 |
| async/await | async fn, .await | 无 (使用线程) | 改用线程+回调模式 |
| 指针操作 | 原生指针 | `CPointer<T>`, unsafe | C FFI 桥接 |
| 内存布局 | `#[repr(C)]`, align/pack | `@C` 结构体 | @C 修饰 |
| 闭包 | Fn, FnMut, FnOnce | lambda 表达式 | 直接翻译 |
| 零成本抽象 | 编译期单态化 | 泛型 (可能动态分发) | 关键路径手动特化 |

### 4.2 关键技术挑战

| 挑战 | 说明 | 应对策略 |
|------|------|---------|
| JavaScriptCore 绑定 | Bun 深度绑定 JSC C++ API | 通过 C FFI 桥接 JSC C API |
| 所有权系统差异 | Rust 编译期保证内存安全 | 依赖GC + 关键路径手动管理 |
| 异步 IO 模型 | libuv 事件循环 + async | C FFI 对接 libuv + 线程池 |
| comptime 编译期 | Zig 大量使用 comptime | 运行时代替 + 手写生成 |
| 零分配设计 | 自定义分配器 | Arena 分配器通过 C FFI |
| 第三方 C 库 | 大量 patched C 依赖 | C FFI 直接使用 |
| SIMD 优化 | 大量 SIMD 内联 | C FFI 调用 C SIMD 代码 |
| 过程宏 | Rust 过程宏生成代码 | 手动展开或仓颉宏 |

## 五、翻译阶段规划

### 阶段 0：项目骨架搭建

**目标：** 建立仓颉项目结构和构建基础设施

**工作内容：**
1. 创建 `cjpm` 多包项目结构
2. 设计包间依赖关系
3. 搭建 C FFI 基础桥接层
4. 建立测试框架骨架
5. 编写构建脚本

**项目结构：**
```
bao/
├── cjpm.toml                         # 根项目配置
├── docs/                              # 文档
│   ├── plan.md                        # 本文件
│   ├── architecture.md                # 架构设计
│   ├── ffi-bridge.md                  # FFI桥接规范
│   └── translation-guide.md           # 翻译规范
├── packages/
│   ├── bao_core/                      # [阶段1] 核心类型
│   │   ├── cjpm.toml
│   │   └── src/
│   │       ├── types.cj               # 基础类型定义
│   │       ├── string.cj              # 字符串处理
│   │       ├── result.cj              # Result 类型
│   │       └── error.cj               # 错误类型
│   │
│   ├── bao_collections/               # [阶段1] 集合类型
│   │   ├── cjpm.toml
│   │   └── src/
│   │       ├── hash_map.cj
│   │       ├── hash_set.cj
│   │       ├── array_list.cj
│   │       └── linked_list.cj
│   │
│   ├── bao_unicode/                   # [阶段1] Unicode
│   │   ├── cjpm.toml
│   │   └── src/
│   │       ├── grapheme.cj
│   │       └── unicode_tables.cj
│   │
│   ├── bao_hash/                      # [阶段1] 哈希算法
│   │   ├── cjpm.toml
│   │   └── src/
│   │       ├── wyhash.cj
│   │       ├── highway.cj
│   │       └── sha.cj
│   │
│   ├── bao_path/                      # [阶段2] 路径处理
│   │   ├── cjpm.toml
│   │   └── src/
│   │       ├── path.cj
│   │       ├── path_buffer.cj
│   │       └── platform_path.cj
│   │
│   ├── bao_sys/                       # [阶段2] 系统绑定
│   │   ├── cjpm.toml
│   │   └── src/
│   │       ├── ffi/
│   │       │   ├── libc.cj            # C标准库绑定
│   │       │   ├── posix.cj           # POSIX接口
│   │       │   └── libuv.cj           # libuv绑定
│   │       ├── os.cj                  # 操作系统接口
│   │       └── process.cj             # 进程管理
│   │
│   ├── bao_io/                        # [阶段2] IO操作
│   │   ├── cjpm.toml
│   │   └── src/
│   │       ├── file.cj
│   │       ├── stream.cj
│   │       ├── buffered_reader.cj
│   │       └── buffered_writer.cj
│   │
│   ├── bao_threading/                 # [阶段2] 线程并发
│   │   ├── cjpm.toml
│   │   └── src/
│   │       ├── thread_pool.cj
│   │       ├── mutex.cj
│   │       ├── condition.cj
│   │       └── atomic.cj
│   │
│   ├── bao_event_loop/                # [阶段2] 事件循环
│   │   ├── cjpm.toml
│   │   └── src/
│   │       ├── event_loop.cj
│   │       ├── timer.cj
│   │       └── poll.cj
│   │
│   ├── bao_parser/                    # [阶段3] JS/TS解析器
│   │   ├── cjpm.toml
│   │   └── src/
│   │       ├── lexer.cj               # 词法分析
│   │       ├── parser.cj              # 语法解析
│   │       ├── ast.cj                 # AST定义
│   │       └── printer.cj             # 代码生成
│   │
│   ├── bao_runtime/                   # [阶段4] 运行时
│   │   ├── cjpm.toml
│   │   └── src/
│   │       ├── vm.cj                  # 虚拟机
│   │       ├── module.cj              # 模块系统
│   │       ├── jsc/                   # JSC绑定
│   │       │   ├── js_value.cj
│   │       │   ├── global_object.cj
│   │       │   └── jsc_ffi.cj
│   │       ├── node_api/              # Node.js API
│   │       │   ├── fs.cj
│   │       │   ├── path.cj
│   │       │   ├── http.cj
│   │       │   └── ...
│   │       └── web_api/               # Web API
│   │           ├── fetch.cj
│   │           ├── url.cj
│   │           └── ...
│   │
│   ├── bao_http/                      # [阶段5] HTTP
│   │   ├── cjpm.toml
│   │   └── src/
│   │       ├── server.cj
│   │       ├── client.cj
│   │       ├── request.cj
│   │       ├── response.cj
│   │       └── headers.cj
│   │
│   ├── bao_bundler/                   # [阶段5] 打包器
│   │   ├── cjpm.toml
│   │   └── src/
│   │       ├── bundler.cj
│   │       ├── resolver.cj
│   │       ├── chunk.cj
│   │       └── module_graph.cj
│   │
│   ├── bao_install/                   # [阶段5] 包管理器
│   │   ├── cjpm.toml
│   │   └── src/
│   │       ├── install.cj
│   │       ├── registry.cj
│   │       ├── lockfile.cj
│   │       └── resolution.cj
│   │
│   ├── bao_sql/                       # [阶段5] 数据库
│   │   ├── cjpm.toml
│   │   └── src/
│   │       ├── sqlite.cj
│   │       └── postgres.cj
│   │
│   └── bao_cli/                       # [阶段5] CLI
│       ├── cjpm.toml
│       └── src/
│           ├── main.cj                # 入口
│           ├── commands/              # 子命令
│           │   ├── run.cj
│           │   ├── build.cj
│           │   ├── install.cj
│           │   ├── test.cj
│           │   └── init.cj
│           └── args.cj                # 参数解析
│
├── test/                              # 集成测试
│   ├── test_core/
│   ├── test_parser/
│   ├── test_runtime/
│   └── test_bundler/
│
└── tools/                             # 工具脚本
    ├── translate.py                   # 翻译辅助脚本
    └── validate.py                    # 验证脚本
```

**验收标准：**
- [ ] cjpm 项目可以成功编译
- [ ] 包间依赖关系正确
- [ ] C FFI 可以调用基础 C 函数
- [ ] 测试框架可以运行

---

### 阶段 1：基础工具库

**目标：** 翻译核心类型、集合、字符串、Unicode、哈希等基础模块

**源文件映射：**

| Bun 源文件 | 目标仓颉文件 | 说明 |
|-----------|-------------|------|
| `src/bun_core/*.zig` | `packages/bao_core/src/*.cj` | 核心类型和工具 |
| `src/string/*.zig` | `packages/bao_core/src/string/*.cj` | 字符串类型 |
| `src/collections/*.zig` | `packages/bao_collections/src/*.cj` | 集合数据结构 |
| `src/unicode/*.zig` | `packages/bao_unicode/src/*.cj` | Unicode处理 |
| `src/hash/*.zig` | `packages/bao_hash/src/*.cj` | 哈希算法 |
| `src/wyhash/*.zig` | `packages/bao_hash/src/wyhash.cj` | WyHash算法 |
| `src/highway/*.zig` | `packages/bao_hash/src/highway.cj` | HighwayHash |
| `src/bun_alloc/*.zig` | `packages/bao_core/src/alloc.cj` | 内存分配器 |
| `src/ptr/*.zig` | `packages/bao_core/src/ptr.cj` | 指针工具 |

**翻译要点：**
1. `ZigString` → `BaoString`：重新设计为仓颉字符串包装
2. `StringBuilder` → 直接使用仓颉 `StringBuilder` 或自定义
3. Rust `Result<T,E>` → 仓颉异常或 `Option<T>`
4. Rust `Vec<T>` → 仓颉 `ArrayList<T>`
5. Rust `HashMap<K,V>` → 仓颉 `HashMap<K,V>`
6. Zig `comptime` → 运行时常量或手动生成

**验收标准：**
- [ ] bao_core 编译通过
- [ ] bao_collections 编译通过
- [ ] bao_unicode 编译通过 (含完整字素表)
- [ ] bao_hash 编译通过
- [ ] 哈希算法正确性测试通过
- [ ] 字符串操作正确性测试通过
- [ ] 集合操作正确性测试通过

---

### 阶段 2：平台层

**目标：** 翻译系统绑定、IO、线程、事件循环、进程管理等

**源文件映射：**

| Bun 源文件 | 目标仓颉文件 | 说明 |
|-----------|-------------|------|
| `src/sys/*.zig,*.rs` | `packages/bao_sys/src/*.cj` | 系统调用绑定 |
| `src/io/*.zig,*.rs` | `packages/bao_io/src/*.cj` | 文件IO |
| `src/threading/*.zig` | `packages/bao_threading/src/*.cj` | 线程和同步 |
| `src/event_loop/*.zig` | `packages/bao_event_loop/src/*.cj` | 事件循环 |
| `src/spawn/*.zig,*.rs` | `packages/bao_sys/src/spawn.cj` | 进程管理 |
| `src/paths/*.zig` | `packages/bao_path/src/*.cj` | 路径处理 |
| `src/dns/*.zig` | `packages/bao_sys/src/dns.cj` | DNS解析 |
| `src/watcher/*.zig` | `packages/bao_sys/src/watcher.cj` | 文件监视 |
| `src/glob/*.zig` | `packages/bao_sys/src/glob.cj` | Glob匹配 |

**翻译要点：**
1. 大量使用 `@C` 和 `foreign` 进行 C FFI 绑定
2. libuv 绑定：创建 C 桥接层
3. 事件循环：基于仓颉线程 + C FFI (epoll/kqueue)
4. 文件系统：部分使用仓颉标准库 `std.fs`，部分 C FFI
5. 进程管理：POSIX 调用通过 C FFI

**验收标准：**
- [ ] bao_sys 编译通过
- [ ] bao_io 编译通过，文件读写测试通过
- [ ] bao_threading 编译通过，并发测试通过
- [ ] bao_event_loop 编译通过
- [ ] bao_path 编译通过，路径操作测试通过
- [ ] 文件读写性能基准测试

---

### 阶段 3：解析器

**目标：** 翻译 JS/TS 解析器、AST、代码生成器

**源文件映射：**

| Bun 源文件 | 目标仓颉文件 | 说明 |
|-----------|-------------|------|
| `src/js_parser/p.zig` | `packages/bao_parser/src/parser.cj` | JS 解析器主文件 |
| `src/js_parser/*.zig` | `packages/bao_parser/src/*.cj` | 解析器辅助 |
| `src/js_printer/js_printer.zig` | `packages/bao_parser/src/printer.cj` | 代码生成器 |
| `src/ast/*.zig` | `packages/bao_parser/src/ast/*.cj` | AST 节点定义 |
| `src/transpiler/*.zig` | `packages/bao_parser/src/transpiler.cj` | 转译器 |
| `src/shell_parser/*.zig` | `packages/bao_parser/src/shell_parser.cj` | Shell解析 |

**翻译要点：**
1. 解析器是最复杂的模块之一，需要严格按原文翻译
2. AST 节点：大量 enum 类型，直接映射到仓颉 enum
3. 词法分析器：状态机实现，注意字符处理差异
4. 语法分析器：递归下降，逻辑复杂但结构清晰
5. 代码生成器：按 AST 节点生成代码

**验收标准：**
- [ ] bao_parser 编译通过
- [ ] JS 词法分析正确性测试通过
- [ ] JS 语法分析正确性测试通过
- [ ] TypeScript 解析测试通过
- [ ] JSX 解析测试通过
- [ | 代码生成器测试通过
- [ ] 与 Bun 解析器输出对比测试

---

### 阶段 4：运行时

**目标：** 翻译 JavaScript 运行时，包括 JSC 绑定、Node.js API、Web API

**源文件映射：**

| Bun 源文件 | 目标仓颉文件 | 说明 |
|-----------|-------------|------|
| `src/jsc/*.zig` | `packages/bao_runtime/src/jsc/*.cj` | JSC 绑定 |
| `src/runtime/*.zig,*.rs` | `packages/bao_runtime/src/*.cj` | 运行时核心 |
| `src/runtime/node/*.zig` | `packages/bao_runtime/src/node_api/*.cj` | Node API |
| `src/api/*.zig` | `packages/bao_runtime/src/web_api/*.cj` | Web API |
| `src/http/*.zig` | `packages/bao_http/src/*.cj` | HTTP |
| `src/websocket/*.zig` | `packages/bao_http/src/websocket.cj` | WebSocket |
| `src/sql/*.zig` | `packages/bao_sql/src/*.cj` | 数据库 |
| `src/url/*.zig` | `packages/bao_runtime/src/url.cj` | URL解析 |

**翻译要点：**
1. JSC 绑定：通过 C FFI 调用 JavaScriptCore C API
2. Node.js API 兼容：逐一翻译每个 API
3. Web API：Fetch, Response, Request, Headers 等
4. HTTP：基于 uWebSockets 的 HTTP 实现
5. 这是最大的翻译阶段，需要最多人力

**验收标准：**
- [ ] bao_runtime 编译通过
- [ ] JS 脚本可以执行
- [ ] console.log 等基础 API 工作正常
- [ ] fs 模块基本操作正常
- [ ] http 模块可以启动服务器
- [ ] fetch API 可以发起请求
- [ ] Node.js 兼容性测试套件通过

---

### 阶段 5：应用层

**目标：** 翻译 Bundler、包管理器、CLI 等上层功能

**源文件映射：**

| Bun 源文件 | 目标仓颉文件 | 说明 |
|-----------|-------------|------|
| `src/bundler/*.zig,*.rs` | `packages/bao_bundler/src/*.cj` | 打包器 |
| `src/resolver/*.zig,*.rs` | `packages/bao_bundler/src/resolver.cj` | 模块解析 |
| `src/install/*.zig,*.rs` | `packages/bao_install/src/*.cj` | 包管理器 |
| `src/cli/*.zig,*.rs` | `packages/bao_cli/src/*.cj` | CLI 命令 |
| `src/clap/*.zig,*.rs` | `packages/bao_cli/src/args.cj` | 参数解析 |
| `src/semver/*.zig` | `packages/bao_install/src/semver.cj` | 版本管理 |
| `src/css/*.zig` | `packages/bao_parser/src/css/*.cj` | CSS解析 |

**翻译要点：**
1. Bundler 核心算法：模块图构建、tree-shaking、chunk 分割
2. 包管理器：网络请求、缓存、依赖解析
3. CLI：命令分发、参数解析、帮助信息
4. CSS 解析器：翻译 CSS AST 和解析逻辑

**验收标准：**
- [ ] bao_bundler 编译通过
- [ ] bao_install 编译通过
- [ ] bao_cli 编译通过
- [ ] `bao run` 命令可以执行 JS 文件
- [ ] `bao build` 命令可以打包
- [ ] `bao install` 命令可以安装依赖
- [ ] `bao test` 命令可以运行测试
- [ ] 端到端集成测试通过

## 六、翻译规范

### 6.1 命名约定

| Bun (Rust/Zig) | 仓颉 (Cangjie) | 示例 |
|----------------|----------------|------|
| `snake_case` 函数/变量 | `camelCase` 或 `snake_case` | `read_file` → `readFile` |
| `PascalCase` 类型 | `PascalCase` 类型 | `JsParser` → `JsParser` |
| `SCREAMING_SNAKE` 常量 | `SCREAMING_SNAKE` 或 `camelCase` | `MAX_SIZE` → `MAX_SIZE` |
| `fn` 关键字 | `func` 关键字 | `fn main()` → `func main()` |
| `pub` 可见性 | `public` 可见性 | `pub fn` → `public func` |
| `struct` | `class` 或 `struct` | 视值/引用语义决定 |
| `enum` | `enum` | 直接翻译 |
| `impl` 块 | `extends` / `impl` | class 内实现或扩展 |

### 6.2 错误处理映射

```
// Rust
fn read_file(path: &str) -> Result<String, IoError> {
    let content = std::fs::read_to_string(path)?;
    Ok(content)
}

// 仓颉
func readFile(path: String): String {
    try {
        return File(path).readToEnd()
    } catch (e: IOException) {
        throw IoError(path, e.message)
    }
}
```

### 6.3 所有权/生命周期处理

```
// Rust - 所有权
fn process(data: Vec<u8>) -> Vec<u8> {
    let mut result = data;  // 所有权转移
    result.push(1);
    result
}

// 仓颉 - GC管理
func process(data: ArrayList<UInt8>): ArrayList<UInt8> {
    let result = data  // 引用，GC管理
    result.append(1)
    return result
}
```

### 6.4 异步转同步策略

```
// Rust/Zig - async
async fn fetch(url: &str) -> Result<Response, Error> {
    let resp = http_client.get(url).await?;
    Ok(resp)
}

// 仓颉 - 线程 + 回调
func fetch(url: String, callback: (Response) -> Unit): Unit {
    spawn {
        let resp = httpClient.get(url)
        callback(resp)
    }
}

// 或者同步阻塞（简单场景）
func fetchSync(url: String): Response {
    return httpClient.get(url)
}
```

### 6.5 C FFI 绑定模板

```
// 仓颉 FFI 声明
@C
foreign func malloc(size: UIntNative): CPointer<Unit>
@C
foreign func free(ptr: CPointer<Unit>): Unit

@C
foreign func uv_loop_new(): CPointer<Unit>
@C
foreign func uv_run(loop: CPointer<Unit>, mode: Int32): Int32

// 使用
func createEventLoop(): CPointer<Unit> {
    unsafe {
        let loop = uv_loop_new()
        if (loop.isNull()) {
            throw OOMError()
        }
        return loop
    }
}
```

## 七、测试策略

### 7.1 测试层次

1. **单元测试** - 每个模块独立测试，随翻译进度编写
2. **对比测试** - 与 Bun 原版输出对比，确保行为一致
3. **集成测试** - 跨模块功能测试
4. **性能测试** - 关键路径性能基准
5. **兼容性测试** - Node.js API 兼容性验证

### 7.2 测试覆盖率目标

| 阶段 | 覆盖率目标 |
|------|-----------|
| 阶段 1 基础层 | 90%+ |
| 阶段 2 平台层 | 80%+ |
| 阶段 3 解析器 | 95%+ (必须严格正确) |
| 阶段 4 运行时 | 70%+ |
| 阶段 5 应用层 | 70%+ |

### 7.3 测试来源

1. 移植 Bun 原有测试 (`test/` 目录)
2. 新增仓颉特定测试
3. Node.js 兼容性测试套件
4. 社区 JavaScript 测试套件

## 八、风险与缓解

| 风险 | 影响 | 缓解措施 |
|------|------|---------|
| JSC C API 功能不足 | 运行时能力受限 | 评估替代 JS 引擎 (QuickJS, V8) |
| 仓颉性能不足 | 整体性能下降 | 关键路径用 C 实现，仓颉调用 |
| 仓颉标准库缺失 | 开发效率低 | 先用 C FFI 补齐，后续替换 |
| 仓颉 GC 暂停 | 延迟敏感场景受阻 | 对象池 + 减少分配 |
| 翻译量过大 | 周期过长 | 优先翻译核心路径，渐进式 |
| Rust 宏展开复杂 | 翻译困难 | 手动展开后翻译 |

## 九、里程碑

| 里程碑 | 内容 | 依赖 |
|--------|------|------|
| M0 | 项目骨架，Hello World | 无 |
| M1 | 基础库翻译完成，可通过单元测试 | M0 |
| M2 | 平台层完成，可读写文件、创建进程 | M1 |
| M3 | 解析器完成，可解析 JS/TS | M1 |
| M4 | 运行时 MVP，可执行简单 JS 脚本 | M2, M3 |
| M5 | 运行时完整，支持 Node.js API 子集 | M4 |
| M6 | HTTP 服务可用 | M5 |
| M7 | Bundler 可用 | M5 |
| M8 | 包管理器可用 | M5 |
| M9 | CLI 完整，可替代 Bun 基本功能 | M6, M7, M8 |
| M10 | 全面测试、性能优化、发布 | M9 |
