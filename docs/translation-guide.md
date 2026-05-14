# 翻译规范

> Bun (Rust/Zig) → Bao (仓颉) 代码翻译规范

## 一、命名约定

| Bun (Rust/Zig) | Bao (仓颉) | 示例 |
|----------------|-----------|------|
| `snake_case` 函数/变量 | `camelCase` | `read_file` → `readFile` |
| `PascalCase` 类型 | `PascalCase` | `JsParser` → `JsParser` |
| `SCREAMING_SNAKE` 常量 | `SCREAMING_SNAKE` | `MAX_SIZE` → `MAX_SIZE` |
| `fn` 关键字 | `func` | `fn main()` → `func main()` |
| `pub` 可见性 | `public` | `pub fn` → `public func` |
| `struct` | `class` 或 `struct` | 视值/引用语义决定 |
| `enum` | `enum` | 直接翻译 |
| `impl` 块 | `extends` / `impl` | class 内实现或扩展 |

### 包命名

- Bun 模块 `bun_xxx` → Bao 包 `bao_xxx`
- 文件名保持 `snake_case.cj`

## 二、类型映射

### 2.1 基础类型

| Rust/Zig | 仓颉 | 说明 |
|---------|------|------|
| `u8` / `u8` | `UInt8` | 无符号 8 位 |
| `i32` / `i32` | `Int32` | 有符号 32 位 |
| `i64` / `i64` | `Int64` | 有符号 64 位 |
| `u64` / `u64` | `UInt64` | 无符号 64 位 |
| `f64` / `f64` | `Float64` | 双精度浮点 |
| `bool` / `bool` | `Bool` | 布尔 |
| `void` | `Unit` | 空类型 |
| `?T` (optional) | `?T` (Option) | 可选值 |
| `usize` | `UIntNative` | 平台相关大小 |

### 2.2 字符串类型

| Bun | Bao | 说明 |
|-----|-----|------|
| `ZigString` | `BaoString` | UTF-8 字符串包装 |
| `[]const u8` | `Array<UInt8>` | 字节数组 |
| `std.ArrayList(u8)` | `StringBuilder` | 字符串构建器 |

### 2.3 集合类型

| Bun | Bao | 说明 |
|-----|-----|------|
| `Vec<T>` | `ArrayList<T>` | 动态数组 |
| `HashMap<K,V>` | `HashMap<K,V>` | 哈希映射 |
| `HashSet<T>` | `HashSet<T>` | 哈希集合 |
| `SmallVec<[T;N]>` | `SmallList<T>` | 小数组优化 |

## 三、错误处理

### 3.1 Result → Option/异常

```rust
// Rust
fn read_file(path: &str) -> Result<String, IoError> {
    let content = std::fs::read_to_string(path)?;
    Ok(content)
}
```

```cangjie
// 仓颉
func readFile(path: String): String {
    try {
        return File(path).readToEnd()
    } catch (e: IOException) {
        throw BaoError(ErrorCode.EIO, e.message)
    }
}
```

### 3.2 Option 保持

```rust
// Rust
fn find(items: &[i32], target: i32) -> Option<usize>
```

```cangjie
// 仓颉
func find(items: Array<Int32>, target: Int32): ?Int64
```

## 四、所有权处理

```rust
// Rust - 所有权转移
fn process(data: Vec<u8>) -> Vec<u8> {
    let mut result = data;
    result.push(1);
    result
}
```

```cangjie
// 仓颉 - GC 管理
func process(data: ArrayList<UInt8>): ArrayList<UInt8> {
    let result = data  // 引用，GC 管理
    result.append(1)
    return result
}
```

## 五、异步转同步

```rust
// Rust/Zig - async
async fn fetch(url: &str) -> Result<Response, Error> {
    let resp = http_client.get(url).await?;
    Ok(resp)
}
```

```cangjie
// 仓颉 - 线程 + 回调
func fetch(url: String, callback: (Response) -> Unit): Unit {
    spawn {
        let resp = httpClient.get(url)
        callback(resp)
    }
}

// 简单场景 - 同步阻塞
func fetchSync(url: String): Response {
    return httpClient.get(url)
}
```

## 六、模式匹配

```rust
// Rust - 穷尽 match
match expr {
    Expr::Number(n) => print_number(n),
    Expr::String(s) => print_string(s),
    _ => {}
}
```

```cangjie
// 仓颉 - 非穷尽 match，需默认分支
match (expr.tag) {
    case ExprTag.Number => printNumber(expr.numberValue)
    case ExprTag.String => printString(expr.stringValue.toString())
    case _ => {}  // 默认分支
}
```

## 七、翻译检查清单

对每个翻译的文件，确认：

- [ ] 包声明正确 (`package bao_xxx`)
- [ ] 导入正确 (`import bao_core.*` 等)
- [ ] 所有 public API 保持与 Bun 等价的语义
- [ ] 错误处理已适配 (Result → 异常/Option)
- [ ] 所有权已去除，依赖 GC
- [ ] comptime 已转换为运行时
- [ ] C FFI 调用包裹在 unsafe 中
- [ ] 注释标注了对应的 Bun 源文件路径
