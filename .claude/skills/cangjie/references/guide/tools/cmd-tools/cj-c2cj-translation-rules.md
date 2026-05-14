# C 语言转换到仓颉胶水代码的规则

HLE 自动生成 C 语言到仓颉的胶水代码，支持函数、结构体、枚举和全局变量的翻译，类型支持：基础类型、结构体类型、指针、数组和字符串。

## 基础类型

工具支持以下几种基础类型：

| C Type             | cangjie Type     |
| -------------------- | ------------------ |
| void               | unit             |
| NULL               | CPointer   |
| bool               | Bool             |
| char               | UInt8            |
| signed char        | Int8             |
| unsigned char      | UInt8            |
| short              | Int64            |
| int                | Int32            |
| unsigned int       | UInt32           |
| long               | Int64            |
| unsigned long      | UInt64           |
| long long          | Int64            |
| unsigned long long | UInt64           |
| float              | Float32          |
| double             | Float64          |
| int arr[10]        | Varry |

## 复杂类型

工具支持的复杂类型有：struct 类型、指针类型、枚举类型、字符串、数组。

### struct 类型

.h 声明文件：

```c
struct Point {
    struct {
        int x;
        int y;
    };
    int z;
};

struct Person {
    int age;
};

typedef struct {
    long long x;
    long long y;
    long long z;
} Point3D;
```

对应生成的胶水代码如下：

<!-- compile -->
```cangjie
@C
public struct _cjbind_ty_1 {
    public let x: Int32
    public let y: Int32

    public init(x: Int32, y: Int32) {
        this.x = x
        this.y = y
    }
}

@C
public struct Point {
    public let __cjbind_anon_1: _cjbind_ty_1
    public let z: Int32

    public init(__cjbind_anon_1: _cjbind_ty_1, z: Int32) {
        this.__cjbind_anon_1 = __cjbind_anon_1
        this.z = z
    }
}

@C
public struct Person {
    public let age: Int32

    public init(age: Int32) {
        this.age = age
    }
}

@C
public struct Point3D {
    public let x: Int64
    public let y: Int64
    public let z: Int64

    public init(x: Int64, y: Int64, z: Int64) {
        this.x = x
        this.y = y
        this.z = z
    }
}
```

### 指针类型

.h 声明文件：

```c
void* testPointer(int a);
```

对应生成的胶水代码如下：

<!-- compile -->
```cangjie
foreign func testPointer(a: Int32): CPointer<Unit>
```

### 函数类型

.h 声明文件：

```c
void test(int a);
```

对应生成的胶水代码如下：

<!-- compile -->
```cangjie
foreign func test(a: Int32): Unit
```

### 枚举类型

.h 声明文件：

```c
enum Color {
RED,
GREEN,
BLUE = 5,
YELLOW
};
```

对应生成的胶水代码如下：

<!-- compile -->
```cangjie
public const Color_RED: Color = 0
public const Color_GREEN: Color = 1
public const Color_BLUE: Color = 5
public const Color_YELLOW: Color = 6

public type Color = UInt32
```

### 字符串

.h 声明文件：

```c
void test(char* a);
```

对应生成的胶水代码如下：

<!-- compile -->
```cangjie
foreign func test(a: CString): Unit
```

### 全局变量

目前只支持 C 语言中的基础类型的常量。

.h 声明文件：

```c
const int GLOBAL_CONST = 42;
```

对应生成的胶水代码如下：

<!-- compile -->
```cangjie
public const GLOBAL_CONST: Int32 = 42
```

### 数组类型

.h 声明文件：

```c
void test(int arr[3]);
```

对应生成的胶水代码如下：

<!-- compile -->
```cangjie
foreign func test(arr: VArray<Int32, $3>): Unit
```

## 不支持的规格

不支持的规格有：位域、联合体、宏、不透明类型、柔性数组、扩展类型。

### 位域

.h 声明文件：

```c
struct X {
    unsigned int isPowerOn : 1;
    unsigned int hasError : 1;
    unsigned int mode : 2;
    unsigned int reserved : 4;
};
```

生成的对应的仓颉代码如下，需要用户手动修改正确：

<!-- compile -->
```cangjie
@C
public struct X {
    let _cjbind_opaque_blob: UInt32

    public init() {
        this._cjbind_opaque_blob = unsafe { zeroValue<UInt32>() }
    }
}
```

### 联合体

.h 声明文件：

```c
union X {
    int a;
    void* ptr;
};
```

生成的对应的仓颉代码如下，需要用户手动修改正确：

<!-- compile -->
```cangjie
@C
public struct X {
    let _cjbind_opaque_blob: UInt64

    public init() {
        this._cjbind_opaque_blob = unsafe { zeroValue<UInt64>() }
    }
}
```

### 宏

仓颉目前没有合适的表达式解析库，因此无法直接计算宏的值。在遇到宏时，当前会跳过整个 #define。

### 不透明类型

.h 声明文件：

```c
typedef struct OpaqueType OpaqueType;

OpaqueType* create_opaque(int initial_value);
void set_value(OpaqueType* obj, int value);
int get_value(OpaqueType* obj);
void destroy_opaque(OpaqueType* obj);
```

生成的对应的仓颉代码如下，需要用户手动修改正确：

<!-- compile -->
```cangjie
@C
public struct OpaqueType {
    init() {
        throw Exception("This type should be implemented by user")
    }
}

foreign func create_opaque(initial_value: Int32): CPointer<OpaqueType>

foreign func set_value(obj: CPointer<OpaqueType>, value: Int32): Unit

foreign func get_value(obj: CPointer<OpaqueType>): Int32

foreign func destroy_opaque(obj: CPointer<OpaqueType>): Unit
```

### 柔性数组

.h 声明文件：

```c
typedef struct {
    int length;
    char data[];
} FlexibleString;
```

生成的对应的仓颉代码如下，需要用户手动修改正确：

<!-- compile -->
```cangjie
@C
public struct FlexibleString {
    public let length: Int32
    public let data: CPointer<UInt8>

    public init(length: Int32, data: CPointer<UInt8>) {
        this.length = length
        this.data = data
    }
}
```

### 扩展类型

.h 声明文件：

```c
#include <complex.h> // C 标准复数头文件
#include <stdatomic.h>

float _Complex c_float; // float 复数类型
double _Complex c_double; // double 复数类型
long double _Complex c_ld; // long double 复数类型

long double pi_high = 3.14159265358979323846264338327950288L; // 后缀 L 表示 long double 字面量
long double Planck_constant = 6.62607015e-34L; // 普朗克常数（高精度需求）

// 用 _Atomic 关键字声明原子类型（int 的原子封装）
_Atomic(int) counter = 0;
```

生成的对应的仓颉代码如下，需要用户手动修改正确：

<!-- compile -->
```cangjie
/*FIXME: Non-constant global variable details need to be verified and rewritten by user.*/
/* float _Complex c_float */

/*FIXME: Non-constant global variable details need to be verified and rewritten by user.*/
/* double _Complex c_double */

/*FIXME: Non-constant global variable details need to be verified and rewritten by user.*/
/* long double _Complex c_ld */

/*FIXME: Non-constant global variable details need to be verified and rewritten by user.*/
/* long double pi_high = 3.14159265358979323846264338327950288L */

/*FIXME: Non-constant global variable details need to be verified and rewritten by user.*/
/* long double Planck_constant = 6.62607015e-34L */

/*FIXME: Non-constant global variable details need to be verified and rewritten by user.*/
/* _Atomic ( int ) counter = 0 */
```

> 说明：
>
> 1. 内存对齐：仓颉没有提供对齐控制的语法，因此 HLE 工具使用 C 默认的对齐方式。如果 C 代码中使用了 `#pragma pack` 或者 `__attribute__((packed))` 等方式来控制对齐，生成的绑定代码不保证正确性。
> 2. 调用约定：仓颉文档中对于调用约定描述不清晰，其实是采用了默认的调用约定，目前 HLE 工具会尝试根据 C 代码中的函数签名推断调用约定，但是不保证正确性。
> 3. 使用限制：HLE 自动生成 C 语言到仓颉的胶水代码受到系统 glibc 版本 限制，当前仅支持 Ubuntu 22.04 及以上系统。