// 翻译自 Bun: src/runtime/bake/server/stack-trace-stub.ts
// TypeScript 源文件仅包含 `export let derefMapping = null;`。

package bao_runtime.bake.server

import bao_jsc.JsValue

/// 生产服务器端 stack trace 映射的延迟引用。
public var derefMapping: ?JsValue = None
