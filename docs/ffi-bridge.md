# FFI 桥接规范

> 仓颉 (Cangjie) 与 C 语言的互操作规范

## 一、基本规则

### 1.1 声明 C 函数

```cangjie
@C
foreign func malloc(size: UIntNative): CPointer<Unit>
@C
foreign func free(ptr: CPointer<Unit>): Unit
```

### 1.2 结构体映射

```cangjie
// C 结构体
// struct stat { dev_t st_dev; ino_t st_ino; mode_t st_mode; ... }

// 仓颉映射
@C
struct CStat {
    var st_dev: UInt64
    var st_ino: UInt64
    var st_mode: UInt32
    // ...
}
```

### 1.3 指针处理

```cangjie
// C 指针 → 仓颉 CPointer<T>
let ptr: CPointer<UInt8> = ...

// 检查空指针
if (ptr.isNull()) { ... }

// 读写指针指向的值
let value = ptr.dereference()  // 读取
ptr.write(newValue)              // 写入
```

## 二、POSIX 系统调用绑定

### 2.1 文件操作

```cangjie
@C foreign func open(path: CPointer<UInt8>, flags: Int32, mode: UInt32): Int32
@C foreign func read(fd: Int32, buf: CPointer<Unit>, count: UIntNative): Int64
@C foreign func write(fd: Int32, buf: CPointer<Unit>, count: UIntNative): Int64
@C foreign func close(fd: Int32): Int32
@C foreign func stat(path: CPointer<UInt8>, buf: CPointer<CStat>): Int32
```

### 2.2 进程管理

```cangjie
@C foreign func getpid(): Int32
@C foreign func fork(): Int32
@C foreign func execve(path: CPointer<UInt8>, argv: CPointer<CPointer<UInt8>>,
                       envp: CPointer<CPointer<UInt8>>): Int32
@C foreign func waitpid(pid: Int32, status: CPointer<Int32>, options: Int32): Int32
```

### 2.3 内存管理

```cangjie
@C foreign func malloc(size: UIntNative): CPointer<Unit>
@C foreign func calloc(count: UIntNative, size: UIntNative): CPointer<Unit>
@C foreign func realloc(ptr: CPointer<Unit>, size: UIntNative): CPointer<Unit>
@C foreign func free(ptr: CPointer<Unit): Unit
@C foreign func memcpy(dest: CPointer<Unit>, src: CPointer<Unit>, n: UIntNative): CPointer<Unit>
@C foreign func memset(ptr: CPointer<Unit>, value: Int32, n: UIntNative): CPointer<Unit>
```

## 三、libuv 绑定

### 3.1 事件循环

```cangjie
@C foreign func uv_loop_new(): CPointer<Unit>
@C foreign func uv_loop_delete(loop: CPointer<Unit>): Unit
@C foreign func uv_run(loop: CPointer<Unit>, mode: Int32): Int32
@C foreign func uv_stop(loop: CPointer<Unit>): Unit
```

### 3.2 定时器

```cangjie
@C foreign func uv_timer_init(loop: CPointer<Unit>, handle: CPointer<Unit>): Int32
@C foreign func uv_timer_start(handle: CPointer<Unit>, cb: CPointer<Unit>,
                                timeout: UInt64, repeat: UInt64): Int32
@C foreign func uv_timer_stop(handle: CPointer<Unit>): Int32
```

## 四、JavaScriptCore 绑定

### 4.1 全局上下文

```cangjie
@C foreign func JSGlobalContextCreate(jsClass: CPointer<Unit>): CPointer<Unit>
@C foreign func JSGlobalContextRelease(ctx: CPointer<Unit>): Unit
@C foreign func JSEvaluateScript(ctx: CPointer<Unit>, script: CPointer<Unit>,
                                  sourceURL: CPointer<Unit>, startingLineNumber: Int32,
                                  exception: CPointer<CPointer<Unit>>): CPointer<Unit>
```

### 4.2 JSValue 操作

```cangjie
@C foreign func JSValueMakeUndefined(ctx: CPointer<Unit>): CPointer<Unit>
@C foreign func JSValueMakeNull(ctx: CPointer<Unit>): CPointer<Unit>
@C foreign func JSValueMakeBoolean(ctx: CPointer<Unit>, value: Bool): CPointer<Unit>
@C foreign func JSValueMakeNumber(ctx: CPointer<Unit>, value: Float64): CPointer<Unit>
```

## 五、安全规范

1. **所有 FFI 调用必须在 `unsafe` 块中**
2. **必须检查返回值**（特别是 -1/NULL 错误指示）
3. **指针传递前验证非空**
4. **C 字符串与仓颉字符串转换使用工具函数**
5. **资源释放必须使用 `try-finally` 确保执行**

## 六、字符串转换工具

```cangjie
/// 仓颉 String → C 字符串 (需要手动释放)
public func baoStringToCString(s: String): CPointer<UInt8> {
    let bytes = s.toArray()
    let ptr = unsafe { malloc(UIntNative(bytes.size + 1)) }
    // ... 复制字节并添加 null 终止符
    return ptr
}

/// C 字符串 → 仓颉 String
public func cStringToBaoString(ptr: CPointer<UInt8>): String {
    // ... 计算长度，读取字节，构造 String
}
```
