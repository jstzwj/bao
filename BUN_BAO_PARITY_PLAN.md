# Bun → Bao 1:1 补全计划

> 生成日期: 2026-05-28
> 基于 Bun src/ (1,262 .zig + 433 .rs + 1,273 C/C++) vs Bao packages/ (1,787 .cj) 深度对比

## 当前状态

| 指标 | 数值 |
|------|------|
| TODO/FIXME/STUB/PLACEHOLDER 总标记数 | ~260 |
| 结构覆盖率 | ~85% |
| 功能完成度（加权平均） | ~50% |
| 关键阻塞点 | JSC FFI 绑定层、事件循环、系统调用 FFI |

## 优先级定义

- **P0**: 阻塞所有上层功能，必须最先修复
- **P1**: 阻塞主要功能路径
- **P2**: 影响用户体验但有 workaround
- **P3**: 高级功能，可延后

---

## P0 — 核心运行时基础设施（阻塞一切）

### P0-1: JSC FFI 绑定补全

**目标**: 让 Cangjie 代码能正确调用 JavaScriptCore C API

| 任务 | 文件 | 具体问题 | 修复方案 |
|------|------|----------|----------|
| callWithThis 绑定 | `bao_jsc/src/static_export.cj:49` | `callWithThis requires JSC runtime binding` | 通过 FFI 绑定 `JSObjectCallAsFunctionWithThis` |
| createError 绑定 | `bao_jsc/src/virtual_machine.cj:1915` | `let error = JsValue.undefined() // TODO: createError` | 通过 FFI 绑定 `JSObjectMakeError` |
| isCallable 绑定 | `bao_jsc/src/console_object.cj:1012` | `obj.isCallable()` 未实现 | 通过 FFI 绑定 `JSObjectIsFunction` |
| type cast Any→JsValue | `bao_jsc/src/strong.cj:194` | `proper type cast from Any to JsValue` | 实现类型标记和指针转换 |
| createTypedArrayFromArrayBuffer | `bao_jsc/src/array_buffer.cj:204` | FFI 未实现 | 绑定 `JSObjectMakeTypedArrayWithBytesNoCopy` |
| makeTypedArrayWithBytesNoCopy | `bao_jsc/src/array_buffer.cj:875` | FFI 未实现 | 同上 |
| str.eqlUTF8 | `bao_jsc/src/virtual_machine_exports.cj:88` | 字符串比较未实现 | 通过 FFI 绑定 `JSStringIsEqualToUTF8CString` |
| promise.unprotect | `bao_jsc/src/virtual_machine_exports.cj:277` | Promise unprotect 未实现 | 通过 FFI 绑定 `JSValueUnprotect` |
| ref() with VM parameter | `bao_jsc/src/concurrent_promise_task.cj:51` | ref() 需要 VM 参数 | 实现 ref/unref 的 VM 感知版本 |
| Proper UTF-8 from pointer | `bao_jsc/src/bindgen.cj:120` | pointer-to-string FFI | 实现 C 指针到 Cangjie String 的安全转换 |

### P0-2: 事件循环真实实现

**目标**: 替换所有 event loop stub，实现真实的异步调度

| 任务 | 文件 | 具体问题 | 修复方案 |
|------|------|----------|----------|
| 替换 StubEventLoop | `bao_io/src/stub_event_loop.cj` | 整个文件是 stub | 基于 libuv 或 epoll 实现真实事件循环 |
| 实现 enqueueTaskConcurrent | `bao_jsc/src/concurrent_promise_task.cj:94` | 并发任务入队未实现 | 在 EventLoop 中实现线程安全的并发任务队列 |
| Timer API | `bao_jsc/src/abort_signal.cj:80` | `vm.timer.remove(eventLoopTimer)` | 实现 EventLoopTimer 的 add/remove/cancel |
| EventLoop enter/exit | `bao_jsc/src/abort_signal.cj:99` | `loop.enter() / exit()` | 实现事件循环的嵌套进入/退出 |
| BlobStore 实现 | `bao_jsc/src/event_loop_handle.cj:41` | stub | 实现 Blob 的异步存储管理 |
| FilePollStore 实现 | `bao_jsc/src/event_loop_handle.cj:54` | stub | 实现文件轮询的存储管理 |
| UwsLoop 绑定 | `bao_jsc/src/event_loop_handle.cj:75` | stub | 绑定到真实的 uWS 事件循环 |
| AsyncLoopStub 替换 | `bao_event_loop/src/event_loop_handle.cj:502` | stub | 实现真实的异步循环句柄 |

### P0-3: 系统调用 FFI

**目标**: 通过 Cangjie FFI 调用 libc 系统调用

| 任务 | 文件 | 具体问题 | 修复方案 |
|------|------|----------|----------|
| chmod | `bao_install/src/bin.cj:832,845,858` | Cangjie 无直接 API | `@C("chmod") extern func chmod(path: CString, mode: UInt32): Int32` |
| umask | `bao_install/src/bin.cj:1077` | getUmask 不可用 | `@C("umask") extern func umask(mask: UInt32): UInt32` |
| exit | `bao_runtime/src/node/node_process.cj:461` | FFI call TODO | `@C("exit") extern func c_exit(status: Int32): Nothing` |
| setuid/setgid | `bao_runtime/src/node/node_process.cj:476,481` | FFI call TODO | `@C("setuid") / @C("setgid")` |
| abort | `bao_runtime/src/node/node_process.cj:486` | FFI call TODO | `@C("abort") extern func c_abort(): Nothing` |
| kill | `bao_runtime/src/node/node_process.cj:491` | FFI call TODO | `@C("kill") extern func c_kill(pid: Int32, sig: Int32): Int32` |
| futimes | `bao_runtime/src/node/node_fs.cj:1934` | syscall stub | `@C("futimes")` |
| lchown | `bao_runtime/src/node/node_fs.cj:1939` | syscall stub | `@C("lchown")` |
| link | `bao_runtime/src/node/node_fs.cj:1943` | syscall stub | `@C("link")` |
| lutimes | `bao_runtime/src/node/node_fs.cj:1955` | syscall stub | `@C("lutimes")` |
| mkdtemp | `bao_runtime/src/node/node_fs.cj:1961` | syscall stub | `@C("mkdtemp")` |
| statfs | `bao_runtime/src/node/node_fs.cj:2064` | syscall stub | `@C("statfs")` |
| utimes | `bao_runtime/src/node/node_fs.cj:2081` | syscall stub | `@C("utimes")` |
| 随机数/CSPRNG | `bao_runtime/src/node/node_crypto_binding.cj:163,192` | TODO FFI | `@C("getrandom") / 读取 /dev/urandom` |

### P0-4: 时间 API 接入

**目标**: 替换所有硬编码的时间值

| 任务 | 文件 | 具体问题 | 修复方案 |
|------|------|----------|----------|
| DateTime.now() | `bao_runtime/src/webcore/crypto.cj:51` | `timestamp = Int64(0)` | 通过 FFI 调用 `clock_gettime` 或 Cangjie 时间 API |
| epochMicroseconds | `bao_jsc/src/bun_cpu_profiler.cj:80` | `UInt64(0) * 1000` | 同上 |
| proper time API | `bao_jsc/src/task.cj:253` | `startTime = 0.0` | 同上 |
| lastModified | `bao_runtime/src/webcore/blob.cj:1767` | `Float64(0)` | stat.st_mtime |
| real timestamp | `bao_jsc/src/console_object.cj:1936,1944,1962` | TODO | 同上 |

---

## P1 — 主要功能路径

### P1-1: node:fs 补全
- futimes, lchown, link, lutimes, mkdtemp, statfs, utimes (已在 P0-3 覆盖)
- watchers.remove(idx) — `node_fs_stat_watcher.cj:101`
- list.getOrThrow().append() — `node_fs_watcher.cj:366`

### P1-2: node:process 补全
- exit/setuid/setgid/abort/kill (已在 P0-3 覆盖)
- Process→SubProcess 转换 — `virtual_machine.cj:574,579`

### P1-3: ReadableStream/WritableStream 完整实现
- ReadableStream.source — `body.cj:216`
- ReadableStream.done/deinit — `body.cj:277`
- FileSink.writeFromStream — `blob.cj:2338`
- Stream 的 JsFunction→JsValue 转换 — 多处

### P1-4: Crypto 随机数
- 真实 CSPRNG — `node_crypto_binding.cj:163,192`
- toHexString() — `crypto.cj:108`

### P1-5: 测试运行器核心功能
- vm.runErrorHandler — `core_types.cj:375`
- DoneCallback 绑定 — `core_types.cj:401`
- 事件循环排空 — `core_types.cj:403`
- expect JSC binding — `expect.cj:19,24,75`

---

## P2 — 用户体验

### P2-1: Shell 子 shell 支持
### P2-2: Bake (dev server) 核心功能
### P2-3: S3 基础操作
### P2-4: SQL 查询回调
### P2-5: CSS minify 和关键帧解析

---

## P3 — 高级功能

### P3-1: Web Worker
### P3-2: IPC serialize/deserialize
### P3-3: NAPI 完整实现
### P3-4: Windows named pipe TLS
### P3-5: H3 (HTTP/3) 客户端
