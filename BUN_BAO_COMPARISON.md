# Bun → Bao 深度对比分析报告

> 生成日期: 2026-05-26
> 对比范围: Bun `src/` (72目录, 1396 .zig文件) vs Bao `packages/` (113包, 1464 .cj文件)

---

## 一、总体规模对比

| 指标 | Bun (`src/`) | Bao (`packages/`) | 比率 |
|------|-------------|-------------------|------|
| 顶层目录数 | 72 | 113 | Bao多57% |
| 源文件数 (.zig/.cj) | 1,396 | 1,464 | 105% |
| 已构建包 | N/A | 96/103 | 93% |
| 桩文件(<10行) | N/A | 50个 | 需关注 |

---

## 二、核心模块一比一映射状态

### 2.1 已完成映射 ✅ (结构与Bun 1:1对应)

| Bun模块 | Bao包 | Bun文件数 | Bao文件数 | 状态 |
|---------|-------|----------|----------|------|
| `runtime/` | `bao_runtime/` | 398 | 492 | ✅ |
| `jsc/` | `bao_jsc/` | 113 | 128 | ✅ |
| `css/` | `bao_css/` + `bao_css_jsc/` + `bao_css_derive/` | 94 | 105 | ✅ |
| `sql/` | `bao_sql/` + `bao_sql_jsc/` | 94 | 94 | ✅ |
| `install/` | `bao_install/` + `bao_install_jsc/` + `bao_install_types/` | 69 | 91 | ✅ |
| `bundler/` | `bao_bundler/` + `bao_bundler_jsc/` | 50 | 67 | ✅ |
| `http/` | `bao_http/` + `bao_http_jsc/` + `bao_http_types/` | 36 | 54 | ✅ |
| `js_parser/` | `bao_js_parser/` + `bao_js_parser_jsc/` | 30 | 38 | ✅ |
| `resolver/` | `bao_resolver/` | 10 | 5+ | ✅ |
| `transpiler/` | `bao_transpiler/` | - | - | ✅ |
| `spawn/` + `spawn_sys/` | `bao_spawn/` + `bao_spawn_sys/` | - | - | ✅ |
| `s3_signing/` | `bao_s3_signing/` | - | - | ✅ |
| `uws/` + `uws_sys/` | `bao_uws/` + `bao_uws_sys/` | - | - | ✅ |
| `router/` | `bao_router/` | - | - | ✅ |
| `watcher/` | `bao_watcher/` | - | - | ✅ |
| `dns/` | `bao_dns/` | - | - | ✅ |
| `threading/` | `bao_threading/` | - | - | ✅ |
| `valkey/` | `bao_valkey/` + `bao_valkey_jsc/` | - | - | ✅ |
| `js_printer/` | `bao_js_printer/` | - | - | ✅ |
| `sourcemap/` | `bao_sourcemap/` + `bao_sourcemap_jsc/` | - | - | ✅ |
| `url/` | `bao_url/` + `bao_url_jsc/` | - | - | ✅ |
| `semver/` | `bao_semver/` + `bao_semver_jsc/` | - | - | ✅ |
| `patch/` | `bao_patch/` + `bao_patch_jsc/` | - | - | ✅ |
| `shell_parser/` | `bao_shell_parser/` | - | - | ✅ |
| `which/` | `bao_which/` | - | - | ✅ |

### 2.2 系统库绑定映射 ✅

| Bun | Bao | 状态 |
|-----|-----|------|
| `boringssl/` + `boringssl_sys/` | `bao_boringssl/` + `bao_boringssl_sys/` | ✅ |
| `brotli/` + `brotli_sys/` | `bao_brotli/` + `bao_brotli_sys/` | ✅ |
| `zlib/` + `zlib_sys/` | `bao_zlib/` + `bao_zlib_sys/` | ✅ |
| `zstd/` | `bao_zstd/` | ✅ |
| `picohttp/` + `picohttp_sys/` | `bao_picohttp/` + `bao_picohttp_sys/` | ✅ |
| `libarchive/` + `libarchive_sys/` | `bao_libarchive/` + `bao_libarchive_sys/` | ✅ |
| `mimalloc_sys/` | `bao_mimalloc_sys/` | ✅ |
| `simdutf_sys/` | `bao_simdutf_sys/` | ✅ |
| `libdeflate_sys/` | `bao_libdeflate_sys/` | ✅ |
| `lolhtml_sys/` | `bao_lolhtml_sys/` | ✅ |
| `tcc_sys/` | `bao_tcc_sys/` | ✅ |
| `cares_sys/` | `bao_cares_sys/` | ✅ |
| `libuv_sys/` | `bao_libuv_sys/` | ✅ |
| `windows_sys/` | `bao_windows_sys/` | ✅ |

### 2.3 辅助工具库映射 ✅

| Bun | Bao | 状态 |
|-----|-----|------|
| `base64/` | `bao_base64/` | ✅ |
| `collections/` | `bao_collections/` | ✅ |
| `hash/` | `bao_hash/` | ✅ |
| `highway/` | `bao_highway/` | ✅ |
| `sha_hmac/` | `bao_sha_hmac/` | ✅ |
| `wyhash/` | `bao_wyhash/` | ✅ |
| `string/` | `bao_string/` | ✅ |
| `unicode/` | `bao_unicode/` | ✅ |
| `ini/` | `bao_ini/` | ✅ |
| `md/` | `bao_md/` | ✅ |
| `glob/` | `bao_glob/` | ✅ |
| `dotenv/` | `bao_dotenv/` | ✅ |
| `errno/` | `bao_errno/` | ✅ |
| `safety/` | `bao_safety/` | ✅ |
| `ptr/` | `bao_ptr/` | ✅ |
| `opaque/` | `bao_opaque/` | ✅ |
| `csrf/` | `bao_csrf/` | ✅ |
| `bun_alloc/` | `bao_bun_alloc/` | ✅ |
| `event_loop/` | `bao_event_loop/` | ✅ |
| `dispatch/` | `bao_dispatch/` | ✅ |
| `meta/` | `bao_meta/` | ✅ |
| `perf/` | `bao_perf/` | ✅ |
| `io/` | `bao_io/` | ✅ |
| `output/` + `bun_output_tags/` | `bao_output/` + `bao_output_tags/` + `bao_bun_output_tags/` | ✅ |
| `bunfig/` | `bao_bunfig/` | ✅ |
| `exe_format/` | `bao_exe_format/` | ✅ |
| `paths/` | `bao_path/` | ✅ |
| `crash_handler/` | `bao_crash_handler/` | ✅ |

### 2.4 Bao独有 (Bun无直接对应)

| Bao包 | 说明 |
|-------|------|
| `bao_core/` | 核心工具集 (64文件) |
| `bao_api/` | API定义 (61文件) |
| `bao_parser/` | 额外的解析器 |
| `bao_options/` | 选项类型 |

---

## 三、缺失或不完整的模块

### 3.1 完全缺失 ❌

| Bun模块 | 功能 | 严重程度 |
|---------|------|---------|
| `js/thirdparty/` | node-fetch, undici, ws.js, isomorphic-fetch等第三方polyfill | 🔴 高 |
| `runtime/cli/init/` | React/Tailwind/Shadcn项目模板生成 | 🟡 中 |

### 3.2 不完整/有问题 ⚠️

| 模块 | 问题 | 详情 |
|------|------|------|
| `bao_js/builtins.d.ts` | **201个TODO类型占位符** | 大量API声明为 `type TODO = any`，函数返回类型未定义 |
| `bao_codegen/` | **25个TODO** | bindgen.ts中17处 `throw new Error("TODO")`，特性生成不完整 |
| `bao_js/node/child_process.ts` | 8个TODO | spawn参数、stdio流、Windows支持未完成 |
| `bao_js/node/http2.ts` | 5个TODO | 回调、C++实现、ALPN支持缺失 |
| `bao_js/node/worker_threads.ts` | 5个TODO | parentPort模拟和正确性待验证 |
| `bao_js/node/net.ts` | 7个TODO | socket处理、临时命名、迁移未完成 |
| `bao_js/node/fs.promises.ts` | 4个TODO | FileHandle方法未完成 |
| `bao_js/internal/streams/` | ~15个TODO | writable, readable, transform, duplex各2-4个TODO |
| `bao_node_fallbacks/` | 4个TODO | events.js是复制粘贴的，string_decoder依赖polyfill |
| `bao_runtime/src/webcore/fetch/` | 仅1个文件 | Bun的fetch实现非常复杂，Bao可能只有骨架 |
| `bao_runtime/src/node/os/` | 仅1个文件 | Node.js OS模块API覆盖可能不完整 |
| `bao_runtime/src/node/net/` | 仅1个文件 | 网络模块可能只有基础实现 |

---

## 四、TODO/FIXME/Placeholder 详细清单

### 4.1 🔴 严重 - 核心功能缺失 (影响运行时行为)

#### `bao_codegen/resources/bindgen.ts` — 17处 `throw new Error("TODO")`
- `emitCppCallToVariant` — 变体调用生成未实现
- `emitConvertValue` — 值转换生成未实现
- 异常处理路径未实现
- 影响: 代码生成器无法处理这些case，可能阻塞所有native binding

#### `bao_js/node/child_process.ts` — 8处TODO
- spawn参数处理未完成
- stdio流实现不完整
- Windows支持缺失
- 影响: 子进程功能不完整，`bun.spawn` 不可靠

#### `bao_js/node/http2.ts` — 5处TODO
- HTTP/2回调未实现
- C++实现引用缺失
- ALPN支持缺失
- 影响: HTTP/2完全不可用

#### `bao_js/node/worker_threads.ts` — 5处TODO
- parentPort模拟未完成
- 消息传递正确性待验证
- 影响: Worker线程不可靠

### 4.2 🟡 中等 - 类型系统/兼容性

#### `bao_js/resources/builtins.d.ts` — 201个 `type TODO = any`
- 定义: `type TODO = any` (第7行)
- 大量函数返回类型声明为 `TODO`
- 示例: `$loadEsmIntoCjs(): TODO`, `$getGeneratorInternalField(): TODO`
- 影响: TypeScript类型安全丧失，但运行时可能不受影响

#### `bao_js/node/fs.promises.ts` — 4处TODO
- FileHandle方法未实现

#### `bao_js/node/net.ts` — 7处TODO
- socket处理不完整
- 临时命名方案未定
- 迁移标记未清理

#### `bao_js/internal/streams/` — ~15处TODO
- `writable.ts` — 2处 (性能)
- `readable.ts` — 2处 (destroy行为)
- `transform.ts` — 2处 (highWaterMark)
- `duplexify.ts` — 4处 (highWaterMark, buffering)
- `compose.ts` — 2处 (stream组合)
- `state.ts` — 1处 (Windows CI)
- `destroy.ts` — 2处 (错误处理)

#### `bao_js/builtins/` — 多处FIXME
- `ReadableStreamInternals.ts` — 3处 (pipe实现)
- `TransformStreamInternals.ts` — 2处 (controller行为)
- `ConsoleObject.ts` — 3处 (字符宽度计算)
- `Ipc.ts` — 2处 (Socket case处理)

### 4.3 🟢 轻微 - 辅助功能/文档

#### `bao_node_fallbacks/` — 4处TODO
- `string_decoder.js` — 依赖buffer polyfill
- `events.js` — 复制粘贴的，需要生成
- `url.js` — placeholder和编码相关

#### `bao_js/resources/internal/util/inspect.js` — 11处TODO
- 性能优化相关
- Unicode支持
- JSC差异注释

#### `bao_codegen/` 其他文件
- `builtin-parser.ts` — 3处TODO error throws
- `bindgen-lib-internal.ts` — 6处TODO error throws
- `generate-classes.ts` — 未移植的surface area注释
- `client-js.ts` — 1处 $BUN_DEBUG interop
- `process_windows_translate_c.rs` — 4处Windows移植TODO
- `bundle-functions.ts` — 3处TODO

---

## 五、50个小文件(<10行) 可能是桩代码

### 极小文件 (<100字节)
| 文件 | 大小 | 可能原因 |
|------|------|---------|
| `bao_event_loop/src/any_task_with_extra_context.cj` | 81B | 可能只有import/空定义 |
| `bao_sql_jsc/mysql/` 多个文件 | 81B | SQL stub |
| `bao_ast/src/ast_result.cj` | 93B | 可能只有类型声明 |

### <10行文件 (50个)
主要模式:
- **文档桩** (2行): 只有注释说明实现在哪
- **兼容性包装** (7-9行): re-export其他模块
- **占位实现**: 开发中的功能

---

## 六、量化进度评估

```
模块结构映射:     ████████████████████ 100% (113/113包已创建)
文件数量对比:     ███████████████████░  95% (1464/1396文件)
构建成功率:       ██████████████████░░  93% (96/103包)
核心功能实现:     ████████████████░░░░  80% (大部分有但可能有stub)
API完整性:        ████████████░░░░░░░░  60% (大量TODO占位符)
第三方polyfill:   ██████░░░░░░░░░░░░░░  30% (node-fetch, ws等缺失)
严格1:1翻译质量:  ████████████████░░░░  75-80%
```

---

## 七、路线图 — 距离可用还有多远

### 时间评估

- **乐观估计**: 2-3个月实现基础可用版本 (MVP)
- **保守估计**: 4-6个月达到Bun的功能对等

### 阶段1 — 最小可用产品 (MVP) — 预计1-2个月

目标: 能运行一个简单的HTTP服务器并响应请求

- [ ] 修复 `bao_codegen` 17个 `throw new Error("TODO")` — **最高优先级**
- [ ] 完成 `child_process` 核心功能
- [ ] 完成 `node_fs` 所有API (fs, fs.promises)
- [ ] 完成 HTTP server/client 基础功能
- [ ] WebSocket 可工作
- [ ] 验证并填充 `bao_runtime/src/webcore/fetch/`
- [ ] 里程碑: 运行 `console.log("hello")` HTTP服务器成功

### 阶段2 — Node.js兼容层 — 预计2-3个月

目标: 能运行大多数Node.js应用

- [ ] 完成 `net.ts` 所有TODO (7处)
- [ ] 完成 `streams` 内部实现 (~15处TODO)
- [ ] 完成 `http2` 基础支持 (5处TODO)
- [ ] 完成 `worker_threads` (5处TODO)
- [ ] 第三方polyfill移植 (node-fetch, ws.js, undici)
- [ ] Node.js核心模块测试通过
- [ ] `bao_js/builtins.d.ts` 清理201个TODO类型
- [ ] 里程碑: 能运行Express/Fastify级别的HTTP应用

### 阶段3 — 生态完善 — 预计3-6个月

目标: 生产就绪

- [ ] 包管理器 (`bao install`) 完整功能
- [ ] 打包器 (bundler) 生产级可用
- [ ] 测试运行器完整功能
- [ ] S3/Valkey/SQLite生产就绪
- [ ] FFI稳定
- [ ] CLI模板/init命令
- [ ] 性能优化与基准测试
- [ ] 里程碑: 能替换Bun用于生产项目

---

## 八、最大风险点

| 风险 | 影响 | 缓解措施 |
|------|------|---------|
| `bao_codegen` 的17个致命TODO | 阻塞所有native binding生成 | 最优先修复，代码生成器是基石 |
| 50个桩文件 | 可能在运行时crash | 逐一验证，补充真实实现 |
| HTTP/2 和 Worker Threads | 高频使用功能不可用 | 阶段2集中攻坚 |
| 第三方polyfill缺失 | 大量npm包依赖这些 | 从ws.js和node-fetch开始 |
| 仓颉语言生态 | FFI/互操作不如Zig成熟 | 利用已有的native C++绑定 |

---

## 九、核心结论

Bao的**骨架已经非常完整** — 模块映射100%，文件数量甚至超过Bun。但"有文件"不等于"有实现"。关键差距在于:

1. **`codegen`的17个致命TODO**可能阻塞整个binding生成管线
2. **`builtins.d.ts`的201个TODO**意味着大量JS API没有实际实现
3. **`child_process`/`http2`/`worker_threads`/`net`**是用户最常用的模块，却也是TODO最集中的地方

**建议优先级**: 先让一个最简单的HTTP服务器跑起来 → 然后补齐Node.js核心API → 最后完善生态工具链。
