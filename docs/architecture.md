# Bao 架构设计

> 将 Bun (Rust/Zig) 严格翻译为仓颉 (Cangjie) 语言的 JavaScript/TypeScript 运行时

## 一、总体架构

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

## 二、包依赖关系

```
bao_cli
  ├── bao_bundler
  ├── bao_install
  ├── bao_http
  └── bao_runtime
        ├── bao_parser
        │     ├── bao_collections
        │     │     ├── bao_core
        │     │     └── bao_hash
        │     │           └── bao_core
        │     └── bao_unicode
        │           └── bao_core
        ├── bao_event_loop
        │     ├── bao_threading
        │     │     └── bao_core
        │     └── bao_core
        ├── bao_io
        │     ├── bao_sys
        │     │     ├── bao_path
        │     │     │     └── bao_core
        │     │     └── bao_core
        │     └── bao_core
        ├── bao_sql
        └── bao_core (基础)
```

## 三、核心设计决策

### 3.1 内存管理

- **Bun**: Rust 所有权 + Zig 手动管理 + 自定义分配器
- **Bao**: 仓颉 GC + Arena 分配器 (关键路径手动管理)
- **影响**: 去除所有权/生命周期语义，依赖 GC；关键路径使用 Arena 分配

### 3.2 错误处理

- **Bun**: Rust `Result<T,E>` + `?` 操作符；Zig `anyerror!?T`
- **Bao**: 仓颉异常 `throw/try-catch` + `Option<T>` + `Result<T>`
- **影响**: Result 类型保留用于可恢复错误，异常用于不可恢复错误

### 3.3 异步模型

- **Bun**: libuv 事件循环 + Rust async/await
- **Bao**: C FFI 对接 libuv/epoll + 线程池 + 回调模式
- **影响**: 无 async/await，使用线程+回调或同步阻塞

### 3.4 数据结构

| Bun 类型 | Bao 类型 | 说明 |
|---------|---------|------|
| `StringArrayHashMap<V>` | `StringMap<V>` | 保持插入顺序的字符串映射 |
| `ArrayHashMap<K,V>` | `HashMap<K,V>` | 通用有序哈希映射 |
| `Vec<T>` | `ArrayList<T>` | 动态数组 |
| `SmallVec<[T;N]>` | `SmallList<T>` | 小数组优化 (用 ArrayList 模拟) |
| `Box<[u8]>` | `Array<UInt8>` | 字节数组 |

## 四、C FFI 桥接层

### 4.1 原则

1. **最小化 FFI 调用**: 尽量在仓颉层实现逻辑，减少跨语言调用
2. **安全性**: 所有 FFI 调用包裹在 `unsafe` 块中，检查返回值
3. **类型安全**: 使用 `@C` 结构体和 `foreign func` 声明

### 4.2 桥接目标

| C 库 | 功能 | 绑定位置 |
|------|------|---------|
| libc | POSIX 系统调用 | `bao_sys/src/ffi/libc.cj` |
| libuv | 事件循环/IO | `bao_sys/src/ffi/libuv.cj` |
| JavaScriptCore | JS 引擎 | `bao_runtime/src/jsc/jsc_ffi.cj` |

## 五、解析器设计

### 5.1 Lexer (词法分析器)

- 状态机实现，逐字符扫描
- 支持: 所有 JS/TS token、Unicode 标识符、模板字面量
- 对应 Bun: `src/js_parser/lexer.zig`

### 5.2 Parser (语法分析器)

- Pratt 解析器 (运算符优先级)
- 递归下降 (语句和声明)
- TypeScript 支持: skip-based parsing (与 Bun 一致)
- 对应 Bun: `src/js_parser/p.zig`

### 5.3 AST

- 表达式 (Expr): 27 种节点类型
- 语句 (Stmt): 22 种节点类型
- 绑定 (Binding): 4 种节点类型
- 对应 Bun: `src/js_parser/ast/`

### 5.4 Printer (代码生成器)

- 遍历 AST 生成 JavaScript 代码
- 支持 minify 模式
- TypeScript 类型注解可选输出
- 对应 Bun: `src/js_printer/js_printer.zig`

## 六、性能考量

### 6.1 关键路径

1. **文件 IO**: C FFI 直接调用 POSIX read/write
2. **字符串哈希**: WyHash 算法 (与 Bun 一致)
3. **事件循环**: epoll/kqueue 高效轮询
4. **解析器**: 避免不必要的内存分配

### 6.2 已知限制

1. 仓颉 GC 暂停可能影响延迟敏感场景 → 对象池 + 减少分配
2. Atomic 类型使用 mutex 模拟 → 功能正确但性能受限
3. SIMD 优化通过 C FFI 实现 → 额外调用开销
