# Bao 补全计划 — Bun → Cangjie 1:1 严格翻译

> 生成日期: 2026-05-27
> 当前总代码: 754,288 行 Cangjie (.cj), 1,787 文件, 111 包
> 对照源: Bun src/ (~85 顶级模块)

---

## 一、当前状态总览

### 1.1 包级别完成度

| 状态 | 包数 | 说明 |
|------|------|------|
| **已完成 (0 问题)** | 64 | 无 TODO/FIXME/stub/NotImplemented |
| **基本完成 (1-5 问题)** | 23 | 少量待修复项 |
| **进行中 (6-20 问题)** | 12 | 需要补全部分实现 |
| **严重不足 (20+ 问题)** | 7 | 大量 stub/TODO，需重点攻坚 |

### 1.2 问题数 Top 15 包

| 包名 | .cj文件 | 代码行数 | TODO | Stub | FIXME | NotImplemented | **总问题** |
|------|---------|---------|------|------|-------|----------------|-----------|
| bao_runtime | 465 | 199,803 | 144 | 264 | — | 48 | **456** |
| bao_jsc | 128 | 33,413 | 70 | 47 | — | 3 | **120** |
| bao_cli | 75 | 38,188 | 75 | 19 | — | 6 | **100** |
| bao_css | 105 | 61,423 | — | 72 | — | — | **72** |
| bao_sys | 31 | 14,504 | 20 | — | — | 3 | **23** |
| bao_sql_jsc | 48 | 6,929 | 5 | 15 | — | 1 | **21** |
| bao_install | 91 | 63,678 | 6 | 8 | — | 1 | **15** |
| bao_bundler | 67 | 29,075 | — | 11 | — | — | **11** |
| bao_io | 21 | 10,680 | — | 9 | — | — | **9** |
| bao_sourcemap_jsc | 4 | 722 | — | 7 | — | — | **7** |
| bao_bunfig | 4 | 3,236 | 2 | 2 | — | 3 | **7** |
| bao_http_jsc | 9 | 3,014 | — | 6 | — | — | **6** |
| bao_event_loop | 19 | 7,386 | — | 6 | — | — | **6** |
| bao_core | 64 | 21,238 | — | — | — | 6 | **6** |
| bao_options | 11 | 3,307 | — | 4 | — | — | **4** |

### 1.3 bao_runtime 子模块问题分布

| 子模块 | 文件数 | 代码行数 | 问题数 | 严重程度 |
|--------|-------|---------|--------|---------|
| webcore | 45 | 41,163 | 107 | **极高** |
| bake | 46 | 13,734 | 72 | **极高** |
| server | 15 | 10,362 | 56 | **高** |
| shell | 48 | 11,805 | 41 | **高** |
| node | 38 | 14,493 | 36 | **高** |
| test_runner | 96 | 13,361 | 65 | **高** |
| socket | 16 | 8,348 | 28 | **中** |
| napi | 9 | 4,969 | 5 | **中** |
| webview | 2 | 563 | 3 | **低** |
| image | 12 | 5,117 | 2 | **低** |
| api | 61 | 32,676 | 1 | **低** |
| crypto | 9 | 4,378 | 0 | 完成 |
| dns | 4 | 3,220 | 0 | 完成 |
| timer | 7 | 3,415 | 0 | 完成 |
| valkey | 8 | 6,175 | 0 | 完成 |
| allocators | 2 | 597 | 0 | 完成 |

### 1.4 完全缺失的 Bun 模块 (4个)

| Bun 模块 | 代码量 | 关键内容 |
|----------|--------|---------|
| `src/bun_bin/` | 573行 | 二进制入口点、phase_c_exports |
| `src/node-fallbacks/` | ~6,800行 JS | Node.js 兼容 polyfill (buffer, util, url, events...) |
| `src/options_types/` | ~8,900行 | 编译目标、JSX配置、Schema、CommandTag |
| `src/paths/` | ~9,800行 | 路径解析、Path buffer pool、resolve_path |

---

## 二、核心阻塞项分析

### 阻塞项 #1: JSC FFI 绑定层 (根本性阻塞)

**影响范围**: bao_jsc, bao_runtime 全部子模块, bao_cli, bao_server

Bun 通过 Zig 直接调用 C++ JavaScriptCore API，Bao 用仓颉纯代码模拟。以下核心方法目前全部为 stub/placeholder：

```
缺失的关键 JSC API:
├── JsObject.callMethod()          → JS 函数调用
├── JsObject.isCallable()          → 可调用性检测
├── JsValue.toArray()              → JS Array 提取
├── JsValue.createError()          → JS 错误创建
├── JSGlobalObject.throwTypeError() → JS 异常抛出
├── EventLoop.enqueueTaskConcurrent() → 异步任务入队
├── JsPromise.resolve()/reject()   → Promise 操作
├── JsGlobalObject.bunVM()         → VM 实例获取
└── callWithThis()                 → 带上下文函数调用
```

**解决方案路径**:
- 方案 A: 仓颉 C FFI → 直接调用 JSC C API (最优，需仓颉 C FFI 支持)
- 方案 B: 中间 C/C++ bridge 层 (次优，增加编译复杂度)
- 方案 C: 纯仓颉模拟 JS 引擎 (最慢，但无外部依赖)

### 阻塞项 #2: 系统 FFI 缺失

```
缺失的 POSIX 系统调用:
├── chmod() / fchmod()             → 文件权限
├── umask()                        → 默认权限掩码
├── setuid() / setgid()            → 用户/组切换
├── kill() / raise()               → 信号发送
├── futimes() / utimes()           → 文件时间戳
├── lchown() / chown()             → 文件所有权
├── link() / symlink()             → 文件链接
├── mkdtemp()                      → 临时目录创建
├── statfs()                       → 文件系统信息
├── setpriority() / getpriority()  → 进程优先级
└── gettimeofday()                 → 高精度时间
```

### 阻塞项 #3: 编译错误

当前 4 个包无法通过编译，共 ~3,110 错误:

| 包 | 错误数 | 主要原因 |
|----|--------|---------|
| bao_cli | 1,501 | 缺失类型: ScriptsList, LoadLockfileResult, Source, Sys |
| bao_cli.commands | 654 | 同上，依赖 bao_cli 的类型 |
| bao_runtime.test_runner | 601 | 类型不匹配、import 冲突 |
| bao_runtime.webcore | 354 | API 不匹配、深层依赖缺失 |

---

## 三、分阶段补全计划

### Phase 0: 编译修复 (优先级: P0 | 预估: 1-2 周)

**目标**: 所有 111 个包通过 `cjpm build` 编译，0 错误。

#### 0.1 修复 bao_cli (1,501 错误)
- [ ] 创建缺失类型: `ScriptsList`, `LoadLockfileResult`, `Source`
- [ ] 修复 `===` → `==` 运算符
- [ ] 修复 import 冲突和歧义类型名
- [ ] 替换已废弃 API: `ReentrantMutex` → `Mutex`, `Console` → `std.env`

#### 0.2 修复 bao_cli.commands (654 错误)
- [ ] 修复与 bao_cli 相同的类型依赖问题
- [ ] 对齐 `bao_cli` 的类型导出

#### 0.3 修复 bao_runtime.test_runner (601 错误)
- [ ] 修复 `JsValue` 类型不匹配
- [ ] 解决 import 冲突 (多个包导出同名类型)
- [ ] 补全缺失的 enum `operator func ==`

#### 0.4 修复 bao_runtime.webcore (354 错误)
- [ ] 修复深层 API 不匹配
- [ ] 补全 webcore 依赖的 JSC 类型绑定

---

### Phase 1: 缺失模块翻译 (优先级: P1 | 预估: 2-3 周)

**目标**: 补齐 Bun 中存在但 Bao 中完全缺失的 4 个模块。

#### 1.1 bao_bun_bin (573行 → ~800行 cj)
- [ ] 翻译 `lib.rs` → `lib.cj` (二进制入口点管理)
- [ ] 翻译 `phase_c_exports.rs` → `phase_c_exports.cj` (C 导出阶段)
- [ ] 创建 `cjpm.toml` 包配置

#### 1.2 bao_options_types (~8,900行 → ~12,000行 cj)
- [ ] 翻译 `CompileTarget.zig` → `compile_target.cj` (506行)
- [ ] 翻译 `Schema.zig` → `schema.cj` (3,224行, 最大文件)
- [ ] 翻译 `Context.zig` → `context.cj` (237行)
- [ ] 翻译 `CommandTag.zig` → `command_tag.cj` (214行)
- [ ] 翻译 `BundleEnums.zig` → `bundle_enums.cj` (75行)
- [ ] 翻译 `ImportRecord.zig` → `import_record.cj`
- [ ] 翻译 `JSX.zig` → `jsx.cj`
- [ ] 翻译 `GlobalCache.zig` → `global_cache.cj`
- [ ] 翻译 `OfflineMode.zig` → `offline_mode.cj`
- [ ] 翻译 `CodeCoverageOptions.zig` → `code_coverage_options.cj`

#### 1.3 bao_paths (~9,800行 → ~13,000行 cj)
- [ ] 翻译 `Path.zig` / `Path.rs` → `path.cj` (2,537行，核心)
- [ ] 翻译 `resolve_path.zig` / `resolve_path.rs` → `resolve_path.cj` (4,596行，最大)
- [ ] 翻译 `string_paths.zig` / `string_paths.rs` → `string_paths.cj` (972行)
- [ ] 翻译 `component_iterator.rs` → `component_iterator.cj` (421行)
- [ ] 翻译 `path_buffer_pool.zig` → `path_buffer_pool.cj` (188行)
- [ ] 翻译 `EnvPath.zig` → `env_path.cj` (92行)
- [ ] 翻译 `path_char.rs` → `path_char.cj` (147行)

#### 1.4 bao_node_fallbacks (JS polyfill, ~6,800行)
- [ ] 翻译 `build-fallbacks.ts` → `build_fallbacks.cj` (构建脚本)
- [ ] 复制/嵌入 JS polyfill 文件作为资源:
  - `buffer.js` (2,035行), `util.js` (959行), `url.js` (755行)
  - `events.js` (545行), `path.js` (533行)
  - `timers.promises.js` (344行), `constants.js` (208行)
  - 其余 ~15 个小文件
- [ ] 创建包配置和资源嵌入机制

---

### Phase 2: 系统 FFI 补全 (优先级: P1 | 预估: 2-3 周)

**目标**: 补全所有缺失的 POSIX 系统调用 FFI 绑定。

#### 2.1 文件系统 FFI
- [ ] `chmod()` / `fchmod()` — 文件权限修改
- [ ] `umask()` — 权限掩码获取/设置
- [ ] `futimes()` / `utimes()` — 文件时间戳
- [ ] `lchown()` / `chown()` — 文件所有权
- [ ] `link()` / `symlink()` — 文件链接创建
- [ ] `mkdtemp()` — 安全临时目录创建
- [ ] `statfs()` — 文件系统统计信息

#### 2.2 进程/信号 FFI
- [ ] `setuid()` / `setgid()` — 用户/组切换
- [ ] `kill()` / `raise()` — 信号发送
- [ ] `setpriority()` / `getpriority()` — 进程优先级
- [ ] `gettimeofday()` — 高精度时间戳
- [ ] `exit()` / `abort()` — 进程终止

#### 2.3 清理现有 stub
- [ ] 替换 `bao_cli` 中所有 `// TODO: chmod not available` 为实际 FFI 调用
- [ ] 替换 `bao_runtime.node` 中所有系统调用 stub
- [ ] 替换 `umaskValue = 0o022` 硬编码为 `SysFs.getUmask()` 调用

---

### Phase 3: JSC 绑定层修复 (优先级: P0 | 预估: 4-8 周)

**目标**: 让 bao_jsc 的 120 个 stub/TODO 全部变为真实实现。

> 这是整个项目最关键的阶段，决定了 Runtime 能否运行。

#### 3.1 核心 JSC API 实现 (bao_jsc)
- [ ] `JsObject.callMethod(name, args)` → JS 函数调用
- [ ] `JsObject.isCallable()` → 可调用检测
- [ ] `JsValue.toArray()` → Array 提取
- [ ] `JsValue.createError(msg)` → 错误对象创建
- [ ] `JSGlobalObject.throwTypeError(msg)` → 异常抛出
- [ ] `callWithThis(fn, this, args)` → 带上下文调用
- [ ] `JsPromise.resolve(value)` / `JsPromise.reject(err)` → Promise 操作
- [ ] `JsGlobalObject.bunVM()` → VM 实例获取

#### 3.2 事件循环集成 (bao_event_loop)
- [ ] `enqueueTaskConcurrent(task)` → 异步任务入队
- [ ] `runCallbackWithResultAndForcefullyDrainMicrotasks()` → 微任务排空
- [ ] 修复 6 个 stub 实现

#### 3.3 JSC 类型系统 (bao_jsc_values, bao_jsc_types)
- [ ] `EncodedJSValue` 完整位操作支持
- [ ] C 指针 ↔ 仓颉类型转换
- [ ] `JsValue` 类型检查方法族 (isNumber, isString, isObject...)

#### 3.4 SavedSourceMap / BakeSourceProvider
- [ ] 替换 JSSourceMap stub 为真实 source map 解析
- [ ] 替换 BakeSourceProvider stub 为 bake 源码提供实现
- [ ] 替换 InternalSourceMapTestingAPIs stub

---

### Phase 4: Runtime 核心补全 (优先级: P1 | 预估: 6-10 周)

**目标**: bao_runtime 的 456 个问题降至 < 20 个。

#### 4.1 webcore (107 问题 → 0)
- [ ] S3 操作真实实现 (当前全部 NotImplemented: uploadStream, downloadStream)
- [ ] HTTP 流处理 (AsyncHTTP streaming callbacks)
- [ ] ReadableStream / WritableStream JS 绑定
- [ ] FormData / Blob / File JS 绑定
- [ ] Fetch API 完整实现
- [ ] 替换所有 `JsValue.undefined()` 占位返回

#### 4.2 bake (72 问题 → 0)
- [ ] DevServer 生命周期 (启动、热重载、关闭)
- [ ] 生产构建路径
- [ ] HTML bundle 路由注册
- [ ] CSS/JS chunk 生成
- [ ] 框架路由 (Next.js, Remix 兼容)
- [ ] Tailwind 插件 hack → 正式实现

#### 4.3 server (56 问题 → 0)
- [ ] 替换 30+ stub 类型 (BlobStore, UwsRequest, JSStrong, JSPromise...)
- [ ] HTTP 请求/响应完整处理链
- [ ] WebSocket 升级和数据帧
- [ ] 静态文件服务
- [ ] S3 文件响应流
- [ ] 代理 (proxy) 请求转发

#### 4.4 test_runner (65 问题 → 0)
- [ ] Promise resolve/reject 绑定 (当前 8 处 TODO)
- [ ] Done callback 创建和绑定 (当前 6 处 TODO)
- [ ] VM 错误处理器 (runErrorHandler, 当前 5 处 TODO)
- [ ] 事件循环微任务排空
- [ ] 定时器管理
- [ ] 测试结果收集和报告

#### 4.5 shell (41 问题 → 0)
- [ ] 子进程 spawn 真实实现 (当前 stub)
- [ ] 管道 (pipe) 数据流
- [ ] 环境变量操作
- [ ] glob 展开
- [ ] 重定向 (stdout/stderr/stdin)

#### 4.6 node (36 问题 → 0)
- [ ] Node.js API 逐个补全:
  - `process` — 系统信息、环境变量、退出码
  - `fs` — 文件系统操作
  - `os` — 操作系统信息
  - `net` — 网络操作
  - `path` — 路径处理
  - `zlib` — 压缩解压
  - `util` — 工具函数
  - `assert` — 断言
- [ ] 替换所有 `// TODO: FFI call` 为实际系统调用

#### 4.7 socket (28 问题 → 0)
- [ ] TCP/UDP socket 连接管理
- [ ] TLS 握手 (依赖 BoringSSL FFI)
- [ ] socket 事件分发
- [ ] 连接池管理

---

### Phase 5: CLI 命令补全 (优先级: P2 | 预估: 3-4 周)

**目标**: bao_cli 的 100 个问题降至 < 10 个。

#### 5.1 commands/ 子目录 (73 问题)
- [ ] `build_command.cj` — 构建命令 (bun build)
- [ ] `create_command.cj` — 项目创建 (bun create)
- [ ] `install_command.cj` — 包安装 (bun install)
- [ ] `add.cj` — 添加依赖 (bun add)
- [ ] `link_command.cj` — 包链接 (bun link)
- [ ] `pack_command.cj` — 打包 (bun pack)
- [ ] `completions.cj` — 命令补全
- [ ] `cli_stubs.cj` — 替换所有 stub 为真实实现

#### 5.2 核心功能
- [ ] 文件权限操作 (依赖 Phase 2 FFI)
- [ ] 包管理器集成 (依赖 bao_install)
- [ ] 配置文件解析 (bunfig)
- [ ] 进程管理

---

### Phase 6: Bundler 补全 (优先级: P2 | 预估: 3-4 周)

**目标**: bao_bundler 的关键文件达到 Bun 对等完成度。

#### 6.1 低完成度文件修复

| 文件 | 当前行数 | Bun 行数 | 目标行数 | 完成度 |
|------|---------|---------|---------|--------|
| bundle_v2.cj | 2,131 | 7,594 | ~7,500 | 28% |
| transpiler.cj | 657 | 3,315 | ~3,200 | 20% |
| barrel_imports.cj | 191 | 824 | ~800 | 23% |
| analyze_transpiled_module.cj | 186 | 565 | ~550 | 33% |
| entry_points.cj | 242 | 545 | ~530 | 44% |

#### 6.2 具体补全任务
- [ ] `bundle_v2.cj` — Tree shaking、code splitting、chunk 边界分析
- [ ] `transpiler.cj` — TypeScript/JSX 转译、decorator 支持、target 降级
- [ ] `barrel_imports.cj` — Barrel 文件检测和优化
- [ ] `analyze_transpiled_module.cj` — 模块依赖分析完整实现
- [ ] `entry_points.cj` — 入口点发现和验证
- [ ] 11 个 stub 标记修复

---

### Phase 7: 其他包问题修复 (优先级: P3 | 预估: 2-3 周)

**目标**: 所有问题数 > 3 的包降至 0。

#### 7.1 bao_css (72 问题)
- [ ] CSS parser 中的 placeholder/stub 替换
- [ ] 大部分是 "placeholder" CSS 特性名 (PlaceholderShown, ::placeholder) — 确认是正确命名而非 TODO
- [ ] 检查并修复实际 stub 实现

#### 7.2 bao_sys (23 问题)
- [ ] 20 个 TODO — 系统调用相关的待实现功能
- [ ] 3 个 NotImplemented — 需要平台特定实现

#### 7.3 bao_sql_jsc (21 问题)
- [ ] 15 个 stub — MySQL/PostgreSQL JS 绑定
- [ ] 5 个 TODO — 查询结果 JS 转换
- [ ] 1 个 NotImplemented

#### 7.4 bao_install (15 问题)
- [ ] 8 个 stub — 包解析器占位
- [ ] 6 个 TODO — 生命周期脚本、安全检查
- [ ] 1 个 NotImplemented

#### 7.5 bao_io (9 问题)
- [ ] 9 个 stub — I/O 操作占位实现

#### 7.6 其余包 (各 < 7 问题)
- [ ] bao_sourcemap_jsc (7) — source map JS 绑定
- [ ] bao_bunfig (7) — 配置文件解析
- [ ] bao_http_jsc (6) — HTTP JS 绑定
- [ ] bao_event_loop (6) — 事件循环 stub
- [ ] bao_core (6) — 核心类型 NotImplemented
- [ ] bao_options (4) — 选项类型 stub

---

### Phase 8: 翻译质量审计 (优先级: P3 | 预估: 2-3 周)

**目标**: 确保 1:1 严格对等，无遗漏逻辑。

#### 8.1 行数对等审计
对每个翻译文件与 Bun 原始文件做行数/函数数对比:
- [ ] 标记所有 Bao 行数 < Bun 50% 的文件
- [ ] 逐文件检查遗漏的函数/方法
- [ ] 检查遗漏的 enum variant / struct field
- [ ] 检查遗漏的 error 处理路径

#### 8.2 语义对等审计
- [ ] 检查所有 `// 简化` / `// simplified` 注释处，恢复完整逻辑
- [ ] 检查所有 `throw Exception("unimplemented")` → 替换为实际实现
- [ ] 检查所有硬编码值 (如 `umask = 0o022`) → 替换为动态获取
- [ ] 检查所有 `if (false)` 死代码块 → 恢复为真实条件判断

#### 8.3 测试对等
- [ ] 确保 Bun test suite 中每个测试都有对应 Bao 测试
- [ ] 运行 Bun test fixtures 验证行为一致性

---

## 四、工作量估算与时间线

### 4.1 工作量汇总

| 阶段 | 描述 | 预估人周 | 前置依赖 |
|------|------|---------|---------|
| Phase 0 | 编译修复 | 1-2 周 | 无 |
| Phase 1 | 缺失模块翻译 | 2-3 周 | Phase 0 |
| Phase 2 | 系统 FFI 补全 | 2-3 周 | Phase 0 |
| Phase 3 | JSC 绑定层 | 4-8 周 | Phase 0 |
| Phase 4 | Runtime 核心 | 6-10 周 | Phase 2+3 |
| Phase 5 | CLI 命令 | 3-4 周 | Phase 2+3 |
| Phase 6 | Bundler 补全 | 3-4 周 | Phase 3 |
| Phase 7 | 其他包修复 | 2-3 周 | Phase 3 |
| Phase 8 | 质量审计 | 2-3 周 | Phase 4-7 |
| **合计** | | **25-40 人周** | |

### 4.2 关键路径

```
Phase 0 (编译修复)
    ├──→ Phase 1 (缺失模块) ──→ Phase 4 (Runtime) ──→ Phase 8 (审计)
    ├──→ Phase 2 (系统FFI) ──┬→ Phase 4 (Runtime)
    │                        └→ Phase 5 (CLI)
    └──→ Phase 3 (JSC绑定) ──┬→ Phase 4 (Runtime)
                             ├→ Phase 5 (CLI)
                             ├→ Phase 6 (Bundler)
                             └→ Phase 7 (其他包)
```

### 4.3 里程碑

| 里程碑 | 达成条件 | 预估时间 |
|--------|---------|---------|
| **M1: 零编译错误** | `cjpm build` 通过 | 第 2 周 |
| **M2: 模块齐全** | 4 个缺失模块翻译完毕 | 第 5 周 |
| **M3: FFI 就绪** | 系统 FFI + JSC 绑定可用 | 第 10-15 周 |
| **M4: Runtime 可运行** | `bao run hello.js` 成功执行 | 第 18-25 周 |
| **M5: 包管理器可用** | `bao install` / `bao add` 正常工作 | 第 22-28 周 |
| **M6: Bundler 可用** | `bao build index.ts` 产出正确 bundle | 第 25-32 周 |
| **M7: 全功能对等** | Bun test suite 通过率 > 80% | 第 35-45 周 |

### 4.4 团队规模与时间线

| 团队规模 | 到 M4 (可运行) | 到 M7 (对等) |
|----------|---------------|-------------|
| 1 人 | 9-12 个月 | 18-24 个月 |
| 2 人 | 5-7 个月 | 10-14 个月 |
| 3 人 | 4-5 个月 | 7-10 个月 |
| 5 人 | 3-4 个月 | 5-7 个月 |

---

## 五、风险与缓解

| 风险 | 概率 | 影响 | 缓解措施 |
|------|------|------|---------|
| 仓颉 C FFI 能力不足，无法绑定 JSC | **高** | 致命 | 提前验证 POC；准备方案 B (C++ bridge) |
| 仓颉语言版本更新导致 API 不兼容 | **中** | 中 | 锁定仓颉版本；建立回归测试 |
| Bun 大版本更新导致差异扩大 | **中** | 低 | 定期 rebase；跟踪 Bun changelog |
| 内存管理语义差异 (Zig manual vs 仓颉 GC) | **中** | 中 | 性能测试；内存泄漏检测 |
| 关键依赖包 (BoringSSL, libuv) FFI 复杂度超预期 | **中** | 高 | 优先验证核心 FFI；降低不常用功能优先级 |

---

## 六、已完成包清单 (64个，0 问题)

以下包已严格完成翻译，无 TODO/FIXME/stub/NotImplemented:

```
bao_api, bao_ast_jsc, bao_base64, bao_bin, bao_boringssl, bao_boringssl_sys,
bao_brotli, bao_brotli_sys, bao_bun_alloc, bao_bun_core_macros,
bao_bundler_jsc, bao_bun_output_tags, bao_cares_sys, bao_clap, bao_clap_macros,
bao_codegen, bao_crash_handler, bao_csrf, bao_css_derive, bao_dispatch,
bao_dns, bao_dotenv, bao_errno, bao_exe_format, bao_glob, bao_hash,
bao_highway, bao_http_types, bao_ini, bao_install_jsc, bao_jsc_macros,
bao_js_parser, bao_js_parser_jsc, bao_js_printer, bao_libarchive,
bao_libarchive_sys, bao_libdeflate_sys, bao_libuv_sys, bao_lolhtml_sys,
bao_md, bao_meta, bao_mimalloc_sys, bao_node_fallbacks, bao_opaque,
bao_output, bao_output_tags, bao_parser, bao_parsers, bao_patch, bao_path,
bao_perf, bao_picohttp_sys, bao_platform, bao_ptr, bao_resolve_builtins,
bao_resolver, bao_router, bao_s3_signing, bao_semver, bao_sha_hmac,
bao_simdutf_sys, bao_sourcemap, bao_spawn, bao_sql, bao_standalone_graph,
bao_string, bao_sys_jsc, bao_tcc_sys, bao_threading, bao_transpiler,
bao_unicode, bao_url, bao_url_jsc, bao_uws, bao_uws_sys, bao_valkey,
bao_watcher, bao_which, bao_windows_sys, bao_wyhash, bao_zlib, bao_zlib_sys,
bao_zstd
```
