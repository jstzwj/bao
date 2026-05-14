# 仓颉-Java 互操作

## 简介

> **注意：**
>
> 仓颉-Java 互操作特性为实验性功能，特性还在持续完善中。

仓颉 SDK 支持仓颉与 Java 的互操作，因此在 Android 应用中可以使用仓颉编程语言开发业务模块。整体调用流程如下：

- 场景一：从 Java 调用仓颉，Java code → (glue code) → 仓颉 code
- 场景二：从仓颉调用 Java，仓颉 code → (glue code) → Java code

**涉及的概念：**

1. Mirror Type：镜像类型，Java 类型使用仓颉语法形式的表达，供开发者使用仓颉的方式调用 Java 方法。
2. CFFI：C Foreign Function Interface，是 Java/Objetive C/仓颉等高级编程语言提供的 C 语言外部接口。
3. 胶水代码：用于弥合不同编程语言差异的中间代码。
4. 互操作代码：Java 调用仓颉方法的实现代码，或仓颉调用 Java 的实现代码。

**涉及的工具：**

1. 仓颉 SDK：仓颉的开发者工具集。
2. java-mirror-generator：仓颉 SDK 中提供的工具，文件名为 java-mirror-gen.jar，用于根据 Java 的.class 文件自动生成仓颉格式的 Mirror Type。
3. cjc：指代仓颉编译器。
4. Android 工具链：Andorid 应用开发所需的工具集合。

仓颉与 Java 之间的调用，通常需要利用 Java 编程语言或仓颉编程语言的处理底层交互的低级互操作特性 CFFI 编写"胶水代码"。然而，人工书写这种胶水代码（Glue Code）对于开发者来说特别繁琐。

仓颉 SDK 中包含的仓颉编译器（cjc）支持自动生成必要的胶水代码，减轻开发者负担。

cjc 自动生成胶水代码需要获取在跨编程语言调用中涉及的 Java 类型（类和接口）的符号信息，该符号信息包含在 Mirror Type 中。Mirror Type 可以通过仓颉 SDK 中提供的 java-mirror-generator（java-mirror-gen.jar） 工具自动生成。

以仓颉调用 Java 为例，整体开发过程描述如下：

1. 开发者进行接口设计，确定函数调用流程和范围。

    开发者 → `确定函数调用流程和范围`

2. 根据步骤 1，为被调用的 Java 类和接口生成 Mirror Type。

    `.class`→ java-mirror-generator → `Mirror Type.cj` 文件

3. 开发互操作代码，使用步骤 2 中生成的 Mirror Type 创建 Java 对象、调用 Java 方法。

    `互操作代码.cj` + `Mirror Type.cj`→ 实现仓颉调用 Java

4. 使用 cjc 编译互操作代码和 `Mirror Type.cj` 文件，cjc 将生成：

    - 胶水代码。
    - 实际进行互操作的 Java 源代码。

    `Mirror Type.cj`\+`互操作代码.cj`→ cjc → `仓颉代码.so`和`互操作.java`

5. 将步骤 4 中生成的文件添加到 Android 项目中：

    - `互操作.java`：cjc 生成的文件
    - `仓颉代码.so`：cjc 生成的文件
    - 仓颉 SDK 包含的运行时库

    在 Java 源代码中插入必要的调用并重新生成该程序。

    Android 项目+`互操作.java` + `仓颉代码.so`→ Android 工具链→`.apk`

**Mirror Type 说明：**

Mirror Type 包含类和接口的声明，向仓颉编译器 cjc 提供 Java 的类和接口的符号信息。

以上述的 Java 类型`com.example.a.A`为例：

```java
// Java 代码
// src/java/com/example/a/A.java
package com.example.a;

public class A {
    private static int lastId = 0;
    private int id = lastId++;
    private String name;
    public A(String name) {
        this.name = name;
    }
    protected final int getId() {
        return id;
    }
    public String getName() {
        return name;
    }
}
```

相应的 Mirror Type 如下所示：

<!-- compile -->
```cangjie
// 仓颉代码
// src/cj/javaworld/src/A.cj
package javaworld

import java.lang.*

@JavaMirror["com.example.a.A"]
open class A {
    public init(arg0: ?JString)
    protected func getId(): Int32
    public open func getName(): ?JString
}
```

如用例所示，Mirror Type 包含对应 Java 类型的非私有成员的签名， 省略函数/构造函数的函数体。

## 环境准备

**系统要求：**

- **硬件/操作系统**：任何能够运行 Android Studio 的系统。
- **软件**：JDK 17，比如 OpenJDK 17。

**环境准备步骤：**

1. 安装仓颉 SDK，具体方法请参考《安装仓颉工具链》章节
2. 安装 JDK 17

    > **注意：**
    >
    > 该 JDK 用作 Java Mirror 生成工具 java-mirror-gen.jar 的执行环境，非构建和运行安卓项目的 JDK。

3. 确认 java-mirror-gen.jar 在仓颉 SDK 中所在位置，例如，`/opt/cj-interop/java-mirror-gen.jar`。
4. 在开发环境的控制台运行以下命令，验证是否安装成功：

    `/path/to/jdk/17/bin/java -jar /path/to/java-mirror-gen.jar`

    例如：

    `/opt/openjdk-17.0.2/bin/java -jar /opt/cj-android-interop/java-mirror-gen.jar`

    如打印 java-mirror-gen.jar 工具的使用方法提醒，则说明安装已经成功。

**版本兼容性：**

- 镜像生成器运行在版本 61 之前的 Java 类文件上，对应于 Java 17，这是 Android 14 中使用的 Java 版本。
- 工具包中包含的 CJNative 仓颉交叉编译器 for Android 的特殊版本对应的主流版本是 0.60.4。

## 使用场景举例

### Java 调用仓颉

**支持的参数类型**：任意 Java 类型

**支持的返回类型**：任意 Java 类型或 `void` 类型

**限制：**

- Java 引用类型的值不能转义为全局变量、静态变量或任何在调用之间持久化的数据结构。
- 不支持 Java 可变长参数的方法和构造函数。
- Java 泛型类型将被擦除。
- 所有涉及的 Java 引用类型必须由同一个类加载器加载。

**步骤：**

1. 正常构建你的 Android 应用程序

2. 生成 Java 类型的 Mirror Type

    如果只需要传递/接收原生类型，则跳过此步骤。原生类型指 `java.lang.Object`，`java.lang.String`或`java.lang.Object`，`java.lang.String` 的数组类型。

    **命令行：**

    ```shell
    /path/to/jdk/17/bin/java \
        -Dpackage.mode -Dpackage.name=<package-name>  \
        -jar /path/to/toolkit/java-mirror-gen.jar \
        -cp <full-application-classpath> \
        -d <output-directory> \
        <names-of-mirrored-types>
    ```

    或

    ```shell
    /path/to/jdk/17/bin/java \
        -Dpackage.mode -Dpackage.name=<package-name> -Djar.mode[=true] \
        -jar /path/to/java-mirror-gen.jar \
        -cp <full-application-classpath> \
        -d <output-directory> \
        <jar-file>
    ```

    其中：

    - `<package-name>`是生成的 Mirror Type.cj 文件的 package 名。
    - `<full-application-classpath>`是安卓应用程序的完整路径依赖，包括`android.jar`。
    - `<output directory>`是生成的 Mirror Type.cj 文件的存放目录，例如`src/cj`。
    - `<names-of-mirrored-types>`是需要生成 Mirror Type.cj 的 Java 类型的全限定名。在未设置 `-Djar.mode` 或者  `-Djar.mode=false` 时生效。
    - `<jar-file>` 是单个 jar 文件的路径名。在设置 `-Djar.mode` 或者  `-Djar.mode=true`时生效。 在该模式下，`<jar-file>` 中包含的所有 `.class` 文件，以及 `<full-application-classpath>` 中找到的所有依赖项都将生成 Mirror Type.cj。

    在 Java 代码中类 Interop 调用一个 Java 函数`f()`，接受的参数类型为 Java 类型`com.example.a.A`、Java 类型`java.lang.String`和 Java 类型`int`，并返回 Java 类型`com.example.b.B`,该类需要调用仓颉定义的方法。最终代码示例如下：

    ```java
    // Java代码

    package cjworld;

    import com.example.a.A;
    import com.example.b.B;

    public class Interop {
        public static B f(A a, String s, int i) {
            /* 自动生成的Glue代码调用仓颉方法 */
        }
    }
    ```

    生成以下 Java 类型的 Mirror Type：

    ```shell
    /opt/jdk/17/bin/java -jar /opt/cj-android-interop/java-mirror-gen.jar \
        -cp /home/user/Android/Sdk/platforms/android-35/android.jar:App.jar \
        -d src/cj \
        com.example.a.A com.example.b.B
    ```

    生成文件`src/cj/com/example/a/A.cj`（com.example.a.A 的 Mirror Type）和`src/cj/com/example/a/B.cj`（com.example.a.B 的 Mirror Type），以及 A 与 B 的所有依赖项类型的 Mirror Type，依赖类型是指参数/返回值/父类型/non-private 字段类型。

3. 编写互操作（Interop）类

    互操作类指代被 Java 调用的仓颉类，以 InteropExample 为例 ：

    1. 为仓颉类定义适当的包名和类名（Java wrapper 将具有相同的全限定名）。
    2. 导入`java.lang.*`。
    3. 导入步骤 2 中生成的 Mirror Type，不需要导入 Mirror Type 的依赖类型。
    4. 为类添加 `@JavaImpl` 注解。
    5. 使类继承`JObject`或 Open 类型的 Mirror Type。
    6. 使用`JObject`、`JString`和`JArray<T>`代替`java.lang.Object`、`java.lang.String`和 Java 数组类型，其他类型使用 Java 名称。

    Java 与仓颉类型映射表 (`T'`是表中列出的值类型或 Java Mirror Type)：

    | Java 类型 (`T`) |      仓颉类型 (`T'`)      |
    |:---------------:|:-----------------------------:|
    |    `boolean`    |            `Bool`             |
    |     `byte`      |            `Int8`             |
    |    `short`      |            `Int16`            |
    |     `char`      |            `UInt16`           |
    |     `int`       |            `Int32`            |
    |     `long`      |            `Int64`            |
    |    `float`      |           `Float32`           |
    |    `double`     |           `Float64`           |
    |    `Object`     |    `JObject` or `?JObject`    |
    |    `String`     |    `JString` or `?JString`    |
    |   `class C`     |         `C'` or `?C'`         |
    |  `interface I`  |         `I'` or `?I'`         |
    |     `T[]`       | `JArray<T'>` or `?JArray<T'>` |

    对于可能接收/持有 Java`null`值的仓颉参数、返回值、Mirror Type 和局部变量，需要使用仓颉的`?<T'>`(`Option<T'>`)类型。

    使用`Unit`类型来表示 Java 方法的`void`返回类型。

    **示例：**

    继续上面的例子，InteropExample 类表示如下：

    <!-- compile -->
    ```cangjie
    // 仓颉代码
    package cjworld

    import java.lang.*
    import com.example.a.A // Mirror Type
    import com.example.b.B // Mirror Type

    @JavaImpl
    public class InteropExample <: JObject {
        public static func f(a: ?A, s: ?JString, i: Int32): ?B {
            /* 仓颉代码 */
        }
    }
    ```

    对于确认不为空的类型，可以去除 `?`

4. 编译互操作（Interop）类

    编译步骤 3 中的 InteropExample 类。

    命令行：

    ```shell
    cjc --output-type=dylib \
        -p <source-directory> \
        -ljava.lang -linteroplib.interop \
        --output-javagen-dir=<java-output-directory>
    ```

    其中：

    `<source-directory>`是包含互操作类（步骤 3 中写的代码）和 Mirror Type 声明（步骤 2 中生成的仓颉文件）的源代码的目录的路径名。

    `<java-output-directory>`是将生成的 Java 源文件放置到的目录的路径名。

    输出为 interop 类编译产物（`.so`文件）和 Java wrapper 源码 （`.java` 文件）。

    **示例：**

    ```shell
    cjc --output-type=dylib \
        -p src/cj \
        -ljava.lang -linteroplib.interop \
        --output-javagen-dir=src/java
    ```

    仓颉编译器 cjc 将生成两个文件：`libcjworld.so`和`src/java/cjworld/InteropExample.java`。

5. 集成至安卓应用

    将以下文件添加到你的 Android 项目中：

    - 步骤 4 生成的 Java 源文件 `InteropExample.java`。
    - 步骤 4 生成的`.so`文件 `libcjworld.so`。
    - Android NDK 中的 `libc++_shared.so`
    - `$CANGJIE_HOME/runtime/lib/`目录及子目录下的全部`.so`文件。
    - `$CANGJIE_HOME/lib/library-loader.jar` 文件。

    然后重新构建 Android 项目。

6. 从 Java 中调用仓颉

    通过 InteropExample 类的相应方法添加从 Java 调用仓颉函数的代码，并重新构建你的 Android 项目。

    **示例：**

    ```java
    // Java代码
    import com.example.a.A;
        ...
        B b = InteropExample.f(new A(), "Test", 0);
        ...
    ```

### 仓颉调用 Java

**仓颉调用 Java 支持的函数参数/返回值类型及对应关系：**

|      仓颉类型 (`T'`)      | Java 类型 (`T`) | Remark |
|:-----------------------------:|:---------------:|:------:|
|            `Bool`             |    `boolean`    |        |
|            `Int8`             |     `byte`      |        |
|            `Int16`            |    `short`      |        |
|            `UInt16`           |     `char`      |        |
|            `Int32`            |     `int`       |        |
|            `Int64`            |     `long`      |        |
|           `Float32`           |    `float`      |        |
|           `Float64`           |    `double`     |        |
|    `JObject` or `?JObject`    |    `Object`     |        |
|    `JString` or `?JString`    |    `String`     |        |
|         `T'` or `?T'`         |     _`T`_       |  (\*)  |
| `JArray<T'>` or `?JArray<T'>` |     `T[]`       | (\*\*) |

**(\*)**`T'`必须是 Java 类型的 Mirror Type `T`或互操作类，其 Java 互操作类的源代码`T`是由 cjc 自动生成的。

**(\*\*)**`T'`必须是 Mirror Type、互操作类或表格中列出的值类型之一，例如：`Int32`。

使用 `Unit` 作为返回类型来调用 `void` 的 Java 方法。

**限制：**

- 不支持 Java 可变长参数的方法和构造函数。
- 所有涉及的 Java 引用类型必须由同一个类加载器加载。

**步骤：**

1. 正常构建你的 Android 应用程序

2. 生成 Mirror Type

    如果只需要传递/接收 原生类型，则跳过此步骤。原生类型指 `java.lang.Object`，`java.lang.String` 或 `java.lang.Object`，`java.lang.String` 的数组类型。

    **命令行：**

    ```shell
    /path/to/jdk/17/bin/java \
        -Dpackage.mode -Dpackage.name=<package-name> \
        -jar /path/to/toolkit/java-mirror-gen.jar \
        -cp <full-application-classpath> \
        -d <output-directory> \
        <names-of-mirrored-types>
    ```

    或

    ```shell
    /path/to/jdk/17/bin/java \
        -Dpackage.mode -Dpackage.name=<package-name> -Djar.mode[=true] \
        -jar /path/to/java-mirror-gen.jar \
        -cp <full-application-classpath> \
        -d <output-directory> \
        <jar-file>
    ```

    其中：

    - `<full-application-classpath>`是安卓应用程序的完整路径依赖，包括`android.jar`。
    - `<output directory>`是生成的 Mirror Type.cj 文件的存放目录，例如`src/cj`。
    - `<names-of-mirrored-types>`是需要生成 Mirror Type.cj 的 Java 类型的全限定名。
    - `<package-name>`是生成的 Mirror Type.cj 文件的 package 名。
    - `<jar-file>` 是单个 jar 文件的路径名。在设置 `-Djar.mode` 或者  `-Djar.mode=true`时生效。 在该模式下，`<jar-file>` 中包含的所有 `.class` 文件，以及 `<full-application-classpath>` 中找到的所有依赖项都将生成 Mirror Type.cj。

    **示例：**

    调用 Java 实现的方法`com.example.c.C`，该方法接受两个参数，类型为`com.example.a.A`和`int`，返回类型为`String`，代码示例如下：

    ```java
    // Java code
    package com.example.c;

    import com.example.a.A;

    public class C {
        public static String g(A a, int i) {
            /* 一些返回字符串的Java代码 */
        }
    }
    ```

    命令行：

    ```shell
    /opt/jdk/17/bin/java -jar /opt/cj-android-interop/java-mirror-gen.jar \
        -cp /home/user/Android/Sdk/platforms/android-35/android.jar:App.jar \
        -d src/cj \
        com.example.c.C
    ```

    此命令将生成 C 的 Mirror Type `src/cj/UNNAMED/src/com/example/c/C.cj`，以及所有依赖项类型的 Mirror Type，依赖类型是指参数/返回值/父类型/non-private 字段类型。

    生成的`src/cj/UNNAMED/src/com/example/c/C.cj`如下：

    <!-- compile -->
    ```cangjie
    package com.example.c

    import java.lang.*
    import java.lang.JString

    public open class C {
        public init()

        public static func g(arg0: ?A, arg1: Int32): ?JString
    }
    ```

3. 导入 Mirror Type 并调用

    导入步骤 2 中生成的 Mirror Type，不需要导入 Mirror Type 的依赖类型。

    按照仓颉语法调用类 C 的函数。

    在[互操作类示例](#使用场景举例) [从 Java 调用仓颉](#java-调用仓颉)一节中：

    <!-- compile -->
    ```cangjie
    // 仓颉代码
    package cjworld

    import interoplib.interop.*
    import java.lang.*
    import javaworld.A
    import javaworld.B
    import javaworld.C

    @JavaImpl
    public class Interop <: JObject {
        public static func f(a: ?A, s: ?JString, i: Int32): ?B {
            let s1: JString = match (a) {
                case Some(aa) => C.g(aa, i) ?? JString("")
            }
            B(s1)
        }
    }
    ```

4. 重新编译仓颉部分

    请参见步骤 4：编译互操作（Interop）类。

5. 更新并重新构建 Android 项目

    复制步骤 4 中生成的 `.so` 文件 和 `.java` 文件至 Android 项目中，并重新构建它。

## Interop 库 API 参考

互操作库包含 `java.lang.Object` 和 `java.lang.String` 和 `java.lang.JArray`。

### java.lang.JObject

<!-- compile -->
```cangjie
package java.lang

import interoplib.interop.*

@JavaMirror["java.lang.Object"]
open class JObject {
    // ...
    public func hashCode(): Int64
    @ForeignName["hashCode"]
    public open func hashCode32(): Int32
    // ...
    public func toString(): String
    @ForeignName["toString"]
    public open func toJString(): JString
    // ...
}
```

上述 `public func hashCode(): Int64` 对应 Java.lang.Object 中的 `hashCode` 方法，返回值类型为 `Int64`。

上述 `public open func hashCode32(): Int32` 对应 Java.lang.Object 中的 `hashCode32` 方法，返回值类型为`Int32`。

上述`public func toString(): String`对应 Java.lang.Object 中的 `toString` 方法，返回值类型为 `String`。

### java.lang.JString

<!-- compile -->
```cangjie
package java.lang

import interoplib.interop.*

@JavaMirror["java.lang.String"]
open class JString {
    // ...
    public init(cjString: String)
    // ...
}
```

上述`public init(cjString: String)`使用仓颉`String`初始化 Java String(`JString`)对象。

> **注意：**
>
> 这个构造函数接受一个仓颉类型的参数`String`，cjc 编译器对该函数有特殊处理。

继承自[`JObject`](#javalangjobject)的方法，包括：`hashCode`，`hashCode32`，`toString`，`toJString`

### java.lang.JArray

<!-- compile -->
```cangjie
package java.lang

import interoplib.interop.*

@JavaMirror["[]"]
public class JArray<T> <: JObject {
    public init(length: Int32)
    public prop length: Int32
    public operator func [](index: Int32): T
    public operator func [](index: Int32, value!: T): Unit
}
```

## 特性和限制

1. 互操作类必须是 Mirror Type 的直接子类。如果 Java 类的父类为 `java.lang.Object`，对应的互操作类的父类需要指定为 [`java.lang.JObject`](#javalangjobject)。
2. 一个互操作类可以实现一个或多个镜像接口，但不能实现非镜像接口。非互操作类不能实现或继承镜像接口。
3. 互操作类不能声明为 `open` 或 `abstract`，且不能使用 `extend`。
4. 互操作类可以增加任何仓颉类型的字段，和重写其父类的成员函数。
5. 互操作类的构造函数可以调用 `super()`。
6. 互操作类的实例成员函数可以调用该互操作类从其镜像超类继承的实例成员函数，和使用 `super.` 来调用 interop 类重写的超类的成员函数。
7. Mirror Type 和互操作类的值：不能转义到仓颉全局变量或静态变量，或全局变量和静态变量引用的变量，否则将引发运行时未定义行为。仓颉编译器 cjc 暂时未对该限制进行编译期检查。

Android/JVM 引入的限制：

1. 任何使用 Mirror Type 或互操作类型的代码都必须在 Java 虚拟机注册的线程中执行。它可以是在 Java 代码中创建的线程，也可以是使用 Java Invocation API 在 JVM 中注册的 O/S 线程。仓颉编译器 cjc 暂时未对该限制进行编译期检查。
2. 所有 Mirror Type 和互操作类的 Java 对应类都必须由同一个类加载器加载。

Java GC 的实现引入的限制：

1. JavaMirror/JavaImpl 对象不能赋值给非 JavaMirror/JavaImpl 类、结构体或枚举中的成员变量。
2. JavaMirror/JavaImpl 对象不能赋值给全局变量。
3. JavaMirror/JavaImpl 对象不能被 Lambda 或 spawn 块捕获。
4. JavaMirror/JavaImpl 对象不能被类型转换为非 JavaMirror/JavaImpl 类型（包含隐式转换）。

## JavaMirror 规格

JavaMirror 为 Java 类型使用仓颉语法形式的表达，由工具自动生成，供开发者使用仓颉的方式调用 Java 方法。

> **注意：**
>
> 本特性尚为实验特性，用户仅可使用文档已说明的特性，若使用了未被提及的特性，将可能出现如编译器崩溃等未知错误。

### 调用构造函数

支持在 JavaImpl 类中调用 JavaMirror 类的构造函数。
<!-- compile -->
```cangjie
import interoplib.interop.*
import java.lang.*

@JavaMirror
public class Mirror {
    public init()
    public init(other: Mirror)
    public init(other: ?Mirror, deepCopy: Bool)
}

// usage:
@JavaImpl
public class Main <: JObject {
    public init() {
        let mirror = Mirror()
        let other = Mirror(mirror)
    }
}
```

### 继承

Java 中的继承关系可被映射。

<!-- compile -->
```cangjie
import java.lang.*
import interoplib.interop.*

@JavaMirror
public open class Logger {
    public func log(msg: JString): Unit
}

@JavaMirror
public class EnhancedLogger <: Logger {
    public func verbose(msg: JString): Unit
}
```

> **注意：**
>
> - JavaMirror 的父类仅能为 JavaMirror 或 JObject，当声明中没有父类时，默认父类类型为 JObject。
> - JavaImpl 的父类仅能为 JavaMirror/JavaImpl 或 JObject，当声明中没有父类时，默认父类类型为 JObject。
> - 纯仓颉类不能继承 JavaMirror/JavaImpl 类。

### 扩展

JavaMirror 类支持被直接扩展，在扩展中，支持使用任意仓颉语义，包括不存在 Java 映射关系的仓颉类型等。示例如下：

<!-- compile -->
```cangjie
import std.random.*
import java.lang.*
import interoplib.interop.*

@JavaMirror
public class M {}

extend M {
    // 注意： `Random` 是纯仓颉类型
    func foo(rand: Random): Int64 {
        return rand.nextInt64()
    }

    func bar(other: M): M {
        return other
    }
}
```

> **注意：**
>
> 不支持接口扩展，包括仓颉接口以及 JavaMirror 接口。

### 属性

JavaMirror 类支持可变属性、静态属性等。

<!-- compile -->
```cangjie
import java.lang.*
import interoplib.interop.*

@JavaMirror
public class Mirror {
    public mut prop self: Mirror
    public mut prop selfOption: ?Mirror
    public static prop default: Mirror
    public static mut prop id: Int64
}
```

对应的 Java 代码如下：

```java
public class Mirror {
    public Mirror self;
    public Mirror selfOption;
    public static final Mirror default;
    public static long id;

    private Mirror() { /*...*/ }
}
```

### 成员函数

支持 JavaMirror 的成员函数可带返回值、参数、可为静态方法。

<!-- compile -->
```cangjie
import java.lang.*
import interoplib.interop.*

@JavaMirror
class B {
    public func foo(): String
    public func modify(broken: Bool, upd: ?Mirror): Unit
    public func combine(other: Mirror): Mirror
    public static func getDefault(): Mirror
    public static func proxy(input: ?Mirror): Mirror
}
```

> **注意：**
>
> 在返回值的类型映射关系中，对于 Java 的 String 类型，可被隐式转换为仓颉的 String 类型。

### 接口

JavaMirror 支持映射 Java 的接口类型。

```Java
public interface I {
    public static long staticMethod() {
        return 1L;
    }
    public I foo();
    public long foo(I i);
}
```

<!-- compile -->
```cangjie
import java.lang.*
import interoplib.interop.*

@JavaMirror
public interface I {
    static func staticMethod(): Int64
    func foo(): I
    func foo(arg: I): Int64
}
```

#### 映射 Default 方法

支持使用 `@JavaHasDefault` 修饰接口中的方法，映射 Java 中的 default 方法。

示例如下：

```java
public interface I {
    default int f() {
        return 1;
    }
}
```

生成的 Mirror 文件如下：

<!-- compile -->
```cangjie
import java.lang.*
import interoplib.interop.*

@JavaMirror
public interface I {
    @JavaHasDefault
    func f(): Int32
}
```

可被 JavaImpl 调用：

<!-- compile -->
```cangjie
import java.lang.*
import interoplib.interop.*

@JavaImpl
public class Impl <: I {
    public init() {
        println(f())
    }
    // 无需实现 f() 函数。因为 I 中有默认实现
}
```

> **注意：**
>
> 不支持处理 Java interface 中的字段。
> 不支持处理在 Mirror Type 中包含属性。

### 抽象类

@JavaMirror 支持映射 Java 的抽象类，但是现在无法区分抽象方法和非抽象方法（未来将支持）。

具体示例如下：

<!-- compile -->
```cangjie
package cj.com

import java.lang.*
import interoplib.interop.*

@JavaMirror["java.com.AbstractMirror"]
abstract class AbstractMirror {
    init()
    public static func staticFunc(): Unit
    protected open abstract func abstractFunc(): Unit
    public open func instanceFunc(): Unit
}

@JavaMirror["java.com.ImplAbstractMirror"]
open class ImplAbstractMirror <: AbstractMirror {
    init()
    public func abstractFunc(): Unit
    public func id(x: AbstractMirror): AbstractMirror
    public func idImpl(x: ImplAbstractMirror): AbstractMirror
}
```

对应的 Java 代码如下：

```java
package java.com;

public abstract class AbstractMirror {
    public static void staticFunc() {
        System.out.println("Java: static func");
    }
    protected abstract void abstractFunc();
    public void instanceFunc() {
        System.out.println("Hello from instance func");
    }
}

public class ImplAbstractMirror extends AbstractMirror {
    public void abstractFunc() {
        System.out.println("abstractFunc()");
    }
    public AbstractMirror id(AbstractMirror x) {
        x.instanceFunc();
        return x;
    }

    public AbstractMirror idImpl(ImplAbstractMirror x) {
        x.instanceFunc();
        return x;
    }
}
```

在仓颉侧使用该抽象类

<!-- compile -->
```cangjie
package cj.com

import java.lang.*
import interoplib.interop.*

@JavaImpl["java.com.Impl"]
class Impl <: JObject {
    init() {
        let i = ImplAbstractMirror()
        let res = i.id(i)
        ImplAbstractMirror.staticFunc()

        match (res) {
            case AbstractMirror => println("id match: ok")
            case ImplAbstractMirror => println("id match: failed")
            case _ => println("id match: unexpected case")
        }

        match (res) {
            case ImplAbstractMirror => println("id match: ok")
            case AbstractMirror => println("id match: failed")
            case _ => println("id match: unexpected match")
        }

        res.abstractFunc()
        print("cast to ImplAbstractMirror: ", flush: true)
        (res as ImplAbstractMirror)?.abstractFunc()

        let res2 = i.idImpl(i)
    }
}
```

```java
package java.com;

class Main {
    public static void main(String[] args) {
         var v = new Impl();
    }
}
```

### 数组

JArray 类型支持在仓颉和 Java 侧做数组数据的映射，支持从 Java 侧转换数组到仓颉侧，或将仓颉数组映射到 Java 侧。

JArray 提供了如下能力：

- 基于特定长度构造数组。
- 基于 index 获取对应数组元素。
- 基于 index 设置对应数组元素。
- 获取数组长度。

示例如下：

```java
package com.java.lib;

import cj.Impl;

public class Main {
    public static void main(String[] args) {
        JImpl impl = new Impl();
    }
}
```

```java
package com.java.lib;

public class JImpl {
    public JImpl() {
        System.out.println("java: JImpl()");
    }

    public void takeArr(long[] arr) {
        for (int i = 0; i < arr.length; i++) {
            System.out.println("java: " + i + "th of long[] - " + arr[i]);
        }
    };

    public long[] getArr() { long[] a = {6, 7, 13}; return a; };

    public void takeArr2(JImpl[] arr) {
        for (int i = 0; i < arr.length; i++) {
            System.out.println("java: " + i + "th of JImpl[] - " + arr[i].getInt());
        }
    };

    public JImpl[] getArr2() { JImpl[] a = {new JImpl(), new JImpl(), new JImpl()}; return a; };

    public long getInt() { return 55312; };
}
```

<!-- compile -->
```cangjie
package cj

import interoplib.interop.*
import java.lang.JObject
import java.lang.JArray

@JavaMirror["com.java.lib.JImpl"]
open class JImpl <: JObject {
    public init()
    public func takeArr(arr: JArray<Int64>): Unit
    public func getArr(): JArray<Int64>
    public func takeArr2(arr: JArray<JImpl>): Unit
    public func getArr2(): JArray<JImpl>
    public func getInt(): Int64
}

@JavaImpl
public class Impl <: JImpl {
    public func foo(): JArray<Int64> {
        JArray<Int64>(44)
    }

    public init() {
        println("cangjie: Impl()")

        let arr0 = JArray<Float64>(5)
        arr0[4] = 1.00033
        arr0[1] = -9.554
        println("cangjie: 5th of F64 array - " + arr0[4].toString())
        println("cangjie: 2nd of F64 array - " + arr0[1].toString())
        println("cangjie: length of F64 array - " + arr0.length.toString())

        let arr1 = JArray<JImpl>(9)
        arr1[1] = JImpl()
        println("cangjie: 2nd of JImpl array - " + arr1[1].getInt().toString())
        println("cangjie: length of JImpl array - " + arr1.length.toString())

        let arr2 = getArr()
        println("cangjie: 1st of I64 array - " + arr2[0].toString())
        println("cangjie: 2nd of I64 array - " + arr2[1].toString())
        println("cangjie: 3rd of I64 array - " + arr2[2].toString())
        arr2[2] = 73
        takeArr(arr2)

        let arr3 = getArr2()
        println("cangjie: 1st of JImpl array from Java - " + arr3[0].getInt().toString())
        println("cangjie: 2nd of JImpl array from Java - " + arr3[1].getInt().toString())
        println("cangjie: 3rd of JImpl array from Java - " + arr3[2].getInt().toString())
        arr3[2] = JImpl()
        takeArr2(arr3)

        let arr4 = this.foo()
        println("cangjie: length of I64 array - " + arr4.length.toString())
    }
}
```

> **注意：**
>
> 暂不支持带有非基础类型的 JArray 在 Android 上运行。

### 字符串

JString 类型支持在仓颉和 Java 侧做字符串数据的映射，支持从 Java 侧转换字符串到仓颉侧，或将仓颉字符串映射到 Java 侧。

例如如下示例，可使用 JString 的方法将仓颉字符串映射至 Java 侧作为函数参数被调用：

<!-- compile -->
```cangjie
import java.lang.*
import interoplib.interop.*

@JavaMirror
class B {
    public func foo(s: JString): Unit
}

func useFoo() {
    let b = B()
    b.foo(JString("smth"))
}
```

在 `@JavaMirror` 类中，`String` 可作为函数返回值类型，隐式将 JString 转换为仓颉的 String 类型。

<!-- compile -->
```cangjie
// ...
class JObject {
    public func toString(): String

    // ...
}
```

由于所有的 @JavaMirror/@JavaImpl 类型都继承自 JObject，因此所有的类型，包括 JString，都有 `toString` 方法。基于该方法，可支持显式将 Java 的 String 转换为仓颉的 String 类型。

## JavaImpl 规格

JavaImpl 为仓颉注解，语义为该类的方法与成员可以被 Java 函数调用。编译期间编译器会为 `@JavaImpl` 的仓颉类生成对应的 java 代码。

> **注意：**
>
> 本特性尚为实验特性，用户仅可使用文档已说明的特性，若使用了未被提及的特性，将可能出现如编译器崩溃等的未知错误。

### 调用 JavaImpl 的构造函数

支持 JavaImpl 类的构造函数被 JavaImpl 类调用。

```cangjie
@JavaMirror
public class Handler {
    public prop isAlive: Bool
    public func enterWorkState(): Unit
}

@JavaImpl
public class Presenter <: JObject {
    public init(log: Bool) {

    }

    public func doLogics() {
        let handler = Handler()
        if (!handler.isAlive) {
            handler.enterWorkState()
        }
    }
}

@JavaImpl
public class Main <: JObject {
    public init() {
        // entry point
        let presenter = Presenter(true)
        presenter.doLogics()
    }
}
```

可在 Java 中调用该构造函数。

```Java
Presenter p = Presenter(true);
```

### 调用 JavaImpl 的成员函数

在仓颉中调用 JavaImpl 的成员函数同普通仓颉方法。在 Java 中调用 JavaImpl 的成员函数如下：

<!-- compile -->
```cangjie
import java.lang.*
import interoplib.interop.*

@JavaMirror
public class Handler {
    public prop isAlive: Bool
    public func enterWorkState(): Unit
}

@JavaImpl
public class Presenter <: JObject {
    public init() {

    }

    public func doLogics(defaultHandler: ?Handler, log: Bool): Bool {
        let handler = defaultHandler ?? Handler()
        if (!handler.isAlive) {
            handler.enterWorkState()
            return true
        }
        return false
    }

    public static func isAlive(p: Presenter): Bool {
        ... // 仓颉侧逻辑
    }
}
```

```java
public class Handler {
    public boolean isAlive;
    ...
}

public class Main {
    public static void main(String[] args) {
        Presenter presenter = new Presenter();
        boolean result = p.doLogics(new Handler(), true);
        if (result) {
            System.out.println("Finished correctly");
        }

        System.out.println("is presenter alive: ");
        System.out.println(Presenter.isAlive(presenter));
    }
}
```

### 定义私有方法

对于 JavaImpl 类，可增加纯仓颉的私有方法（不可被其他类型调用），该方法不需遵守参数和返回值只能为 Java 兼容类型的约束。

<!-- compile -->
```cangjie
import java.lang.*
import interoplib.interop.*

struct PureCangjieEntity {

}

@JavaImpl
public class Impl <: JObject {
    public Impl() {
        let entity = foo()
        ...
    }

    private func foo(): PureCangjieEntity {
        /*...*/ 
        return PureCangjieEntity()
    }
}
```

### 类型匹配和类型强转

`as`、`is` 和类型匹配支持 @JavaMirror 和 @JavaImpl 类作为类型操作数。在这种情况下，可以使用 Java 的 instanceof 函数来检查实际类型。此外，还支持接口或继承链的子类型关系。

<!-- compile -->
```cangjie
import java.lang.*
import interoplib.interop.*

@JavaMirror
public class B {}

@JavaImpl
public class A {}

func foo(b: B) {
    println(b is A)
    println((b as A).isSome())

    match (b) {
        case b : A => println("A")
        case _ => ()
    }

    let c = Some(b)
    match (c) {
        case Some(b : A) => println("A")
        case _ => ()
    }
}
```

### @ForeignName

`@ForeignName[".."]` 注解可应用于 `@JavaMirror` 和 `@JavaImpl` 类中未被重写的方法。

- 在 `@JavaMirror` 类中的原始方法使用 `@ForeignName["name"]` 注解时，该方法及其所有重写都将调用 Java 方法 `name`。因此 `name` 必须与 Java 中的方法的签名一致。
- 在 `@JavaImpl` 类中的原始方法使用 `@ForeignName["name"]` 注解时，将生成名为 `name` 的方法。

<!-- compile -->
```cangjie
import java.lang.*
import interoplib.interop.*

@JavaMirror
public class B {
    @ForeignName["bar"]
    public open func foo() // java 侧的 B.bar()
}

@JavaMirror
public class C <: B {
    public /* override */ func foo() // java 侧的 C.bar()
}

@JavaImpl
public class A <: C {
    // Java 侧可调用 A.bar() , 实际生成为 bar()
    public /* override */ func foo() {
        // ...
    }
}
```

对应的 Java 代码如下：

```java
class B {
    public void bar() {
        // ...
    }
}
```

```java
class C extends B {
    @Override
    public void bar() { /* ... */ }
}
```

### JavaImpl 的扩展

JavaImpl 类型支持直接扩展，规格同 JavaMirror，详见 JavaMirror 章节的[扩展](#扩展)

## Java 使用 Cangjie 规格

### 新增实验编译选项 `--experimental --enable-interop-cjmapping=<Target Languages>`

启用在 FE 中支持非 C 语言的 Cangjie 互操作。<目标外语>的可能值为 Java、ObjC。

### 新增实验编译选项 `--experimental --import-interop-cj-package-config-path <ConfigFile Path(*.toml)>`

功能：在 FE 中启用对非 C 语言的 Cangjie 互操作支持。
参数：需要指定一个 toml 格式的配置文件路径，例如：src/cj/config.toml 或 javaCallCangjie.toml。
> **注意：**
>
> - 此选项必须与 `--experimental --enable-interop-cj-mapping` 同时使用。
> - `--import-interop-cj-package-config-path` 用于指定互操作的配置文件。
> - `--enable-interop-cj-mapping` 用于指定目标语言并启用对应的互操作映射。

### Java 使用 Cangjie 结构体

Cangjie 与 Java 的互操作中，需要支持在 Java 使用 Cangjie 的 struct 数据类型。由于 Java 使用 Cangjie 的特性仍在开发过程中，当前仅覆盖如下场景：

1. 支持 Java 中调用 Cangjie 侧 public struct 的 public 实例方法，静态方法
2. 支持 Cangjie 侧 public struct 可以作为 Java 函数的参数类型，返回值类型
3. 支持 Cangjie 侧将 Lambda 表达式、元组用作函数的参数类型或返回值类型。使用前需在配置文件中配置相关签名和类型信息，具体配置方法请参见类型配置介绍[类型配置介绍](#java-使用-配置文件)
    - Lambda 表达式支持的参数类型和返回值类型包括：Int、Int8、Int16、Int32、Int64、Float32、Float64、Bool、Unit
    - 元组支持的元素类型包括：Int、Int8、Int16、Int32、Int64、Float32、Float64、Bool

示例代码如下所示：

<!-- compile -->

```cangjie
// cangjie code

package cj

public struct Vector {
    private var x: Int32 = 0
    private var y: Int32 = 0

    public init(x: Int32, y: Int32) {
        this.x = x
        this.y = y
    }

    public func dot(v: Vector): Int64 {
        let res: Int64 = Int64(x * v.x  + y * v.y)
        print("cj: Hello from dot (${x}, ${y}) . (${v.x}, ${v.y}) = ${res}\n", flush: true)
        return res;
    }

    public func add(v: Vector): Vector {
       let res = Vector(x + v.x, y + v.y)
       print("cj: Hello from add (${x}, ${y}) + (${v.x}, ${v.y}), new Vector = (${res.x}, ${res.y})\n", flush: true)
       return res
    }

    public static func hello(v: Vector): Unit {
        print("cj: Hello from static func in cj.Vector (${v.x}, ${v.y})\n", flush: true)
    }
}
```

对应的 Java 代码如下：

```java
package com.java.lib;

import cj.Vector;

public class Main {

    public static Vector getVector(int x, int y) {
        return new Vector(x, y);
    }

    public static void valueCheck(long value, long expectedValue) {
        if (value != expectedValue) {
            System.out.println("java: Test Failed, value: " + value + " != expected: " + expectedValue);
            System.exit(1); 
        }
    }

    public static void main(String[] args) {
        Vector.hello(getVector(0, 0));
        Vector u = new Vector(1, 2);
        Vector v = getVector(3, 4);
        long expectedValue = 1 * 3 + 2 * 4;
        valueCheck(u.dot(v), expectedValue);
        Vector w = u.add(v); // w = (4, 6)
        expectedValue = 4 * 1 + 6 * 2;
        valueCheck(w.dot(u), expectedValue);
        expectedValue = 3 * 4 + 4 * 6;
        valueCheck(v.dot(w), expectedValue);
        System.out.println("java: Correct result, dot value Test PASS.");
    }
}
```

#### 规格约束

1. 要求 Cangjie struct 无 interface 实现
2. 暂不支持 Java 侧对 struct 成员变量的访问
3. 暂不支持 mut 函数的调用
4. 暂不支持属性

### Java 使用 Cangjie 的 Enum

仓颉枚举类型需要与 Java 类型建立映射关系，以便用户能够：

1. 在 Java 端通过调用枚举类型的构造函数来创建枚举对象。
2. 在语言边界之间传递枚举对象。
3. 调用枚举中定义的静态或非静态方法。
4. 支持枚举属性的访问。
5. 支持 Cangjie 侧将 Lambda 表达式、元组用作函数的参数类型或返回值类型。使用前需在配置文件中配置相关签名和类型信息，具体配置方法请参见类型配置介绍[类型配置介绍](#java-使用-配置文件)
    - Lambda 表达式支持的参数类型和返回值类型包括：Int、Int8、Int16、Int32、Int64、Float32、Float64、Bool、Unit
    - 元组支持的元素类型包括：Int、Int8、Int16、Int32、Int64、Float32、Float64、Bool

示例代码如下，仓颉的枚举类型会被映射到 Java 的 Class 类型：

<!-- compile -->
```cangjie
// Cangjie
// =============================================
// Enum Definition: Basic Enum (TimeUnit)
// =============================================
public enum TimeUnit {
    | Year(Int64)
    | Month(Int64)
    | Year
    | Month

    // The public method to Calculate how many months.
    public func CalcMonth(): Unit {
        let s = match (this) {
            case Year(n) => "x has ${n * 12} months"
            case Year => "x has 12 months"
            case TimeUnit.Month(n) => "x has ${n} months"
            case Month => "x has 1 month"
        }
        println(s)
    }

    // The static method to return ten years.
    public static func TenYear(): TimeUnit {
        Year(10)
    }
}
```

映射后的 Java 代码如下：

```java
public class TimeUnit {
    static {
        loadLibrary("sampleEnum");
    }

    long self;

    private TimeUnit (long id) {
        self = id;
    }

    public static TimeUnit Year(long p1) {
        return new TimeUnit(YearinitCJObjectl(p1));
    }

    private static native long YearinitCJObjectl(long p1);

    public static TimeUnit Month(long p1) {
        return new TimeUnit(MonthinitCJObjectl(p1));
    }

    private static native long MonthinitCJObjectl(long p1);

    public static TimeUnit Year = new TimeUnit(YearinitCJObject());

    private static native long YearinitCJObject();

    public static TimeUnit Month = new TimeUnit(MonthinitCJObject());

    private static native long MonthinitCJObject();

    public void CalcMonth() {
        CalcMonth(this.self);
    }

    public native void CalcMonth(long self);

    public static native TimeUnit TenYear();

    public native void deleteCJObject(long self);

    @Override
    public void finalize() {
        deleteCJObject(this.self);
    }
}
```

#### 规格约束

目前枚举支持与其他语言特性组合仍在开发过程中，暂不支持如下场景：

1. 要求 Cangjie enum 无 interface 实现
2. 要求 Cangjie enum 中不包含操作符重载
3. 要求 Cangjie enum 中仅使用基础的数据类型
4. 要求 Cangjie 不使用 extend 对 enum 进行拓展
5. 不支持 Option

### Java 使用 Cangjie 的 Class

支持 Java 使用 Cangjie Class, 规格如下：

- 允许 Java 类继承 Cangjie 的 public open Class
- 允许访问父类中的非 private 方法(包括 public、protected 方法)
- 允许重写父类中的非静态非 private open 方法(包括 public、protected 方法)
- 支持基础数据类型作为函数参数类型
- 支持 Cangjie 侧将 Lambda 表达式、元组用作函数的参数类型或返回值类型。使用前需在配置文件中配置相关签名和类型信息，具体配置方法请参见类型配置介绍[类型配置介绍](#java-使用-配置文件)
    - Lambda 表达式支持的参数类型和返回值类型包括：Int、Int8、Int16、Int32、Int64、Float32、Float64、Bool、Unit
    - 元组支持的元素类型包括：Int、Int8、Int16、Int32、Int64、Float32、Float64、Bool

示例代码如下：

Cangjie 侧 Class M 定义

<!-- compile -->
```cangjie
// Cangjie
public open class M 
{
    public init () {}
    public open func goo():Unit {}
    public open func foo(): Unit 
    {
        goo()
    }
}
```

Java 侧继承 class M：

```java
public class A extends M 
{
    public A() {}
    @Override
    public void goo() {
        //Override implementation
    }

}
```

Java 侧实例化 class A：

```java
public class Main 
{
    public static void main (String[] args) {
        M m = new A();
    }

}
```

#### 规格约束

目前 Java 使用 Cangjie Class 暂不支持如下场景：

- 不支持访问继承 Cangjie class 的普通成员变量、静态成员变量、静态成员方法、prop 成员
- 不支持跨包引用

### Java 使用 Cangjie 的 Interface

仓颉接口类型需要与 Java 类型建立映射关系，以便用户能够：

- 将仓颉接口类型作为 Java 函数的参数类型。
- 在 Java 端实现仓颉接口，并作为仓颉接口类型的参数传递。
- 调用仓颉接口中的默认实现。
- 支持 Cangjie 侧将 Lambda 表达式、元组用作函数的参数类型或返回值类型。使用前需在配置文件中配置相关签名和类型信息，具体配置方法请参见类型配置介绍[类型配置介绍](#java-使用-配置文件)
    - Lambda 表达式支持的参数类型和返回值类型包括：Int、Int8、Int16、Int32、Int64、Float32、Float64、Bool、Unit
    - 元组支持的元素类型包括：Int、Int8、Int16、Int32、Int64、Float32、Float64、Bool

示例代码如下，仓颉的接口类型会被映射到 Java 的 interface 类型：

<!-- compile -->

```cangjie
// cangjie code
package UNNAMED

public interface A {
    func foo() : Unit {
        println("Hello World!")
    }

    func goo() : Unit
}
```

映射后的 Java 代码如下：

```Java
package UNNAMED;

public interface A {
    public default void foo() {
        A_fwd.foo_default_impl(this);
    }
    public void goo();
}

final class A_fwd {
    private A_fwd() {}
    static {
        loadLibrary("cj");
    }

    public static native void foo_default_impl(A selfobj);
}
```

#### 规格约束

目前接口支持与其他语言特性组合仍在开发过程中，暂不支持如下场景：

- 要求 Cangjie interface 不继承其他 interface
- 要求 Cangjie interface 成员函数非 static
- 要求 Cangjie interface 中仅使用基础的数据类型
- 要求 Cangjie 不适应 extend 对 interaface 进行扩展
- 不支持 option

### Java 使用 Cangjie 的 Extend

仓颉 extend 语法中定义的非 private 成员需要映射到 Java，以支持用户在 Java 侧调用其中定义的静态或非静态方法及属性。

示例代码如下，仓颉的 extend 语法会被映射到 Java：

<!-- compiler -->
```cangjie
public class User {
    public let id: Int32
    public init(id: Int32) {
        this.id = id
    }
    public var a: Int32 = 0
    public static var b: Int32 = 0
}

extend User {
    public func getId(): Int32 {
        return id
    }
    public static func hello(): Unit {
    }
}

extend User {
    public mut prop pp: Int32 {
        get() {
            a
        }
        set(val) {
            a = val
        }
    }

    public static mut prop sp: Int32 {
        get() {
            b
        }
        set(val) {
            b = val
        }
    }
}
```

映射后的 Java 代码如下：

```java
public class User {
    public int getId() {
        return getId(this.self);
    }

    public native int getId(long self);

    public static native void hello();

    public int getPp() {
        return getPpImpl(this.self);
    }

    public native int getPpImpl(long self);

    public void setPp(int pp) {
        setPpImpl(this.self, pp);
    }

    public native void setPpImpl(long self, int pp);

    public static int getSp() {
        return getSpImpl();
    }

    public static native int getSpImpl();

    public static void setSp(int sp) {
        setSpImpl(sp);
    }

    public static native void setSpImpl(int sp);
}
```

#### 规格约束

- 支持直接扩展和接口扩展
- extend 语法内部定义成员仅支持仓颉基础数据类型
- 接口扩展不支持 @JavaMirror 属性相关接口
- 直接扩展不支持操作符重载
- 直接扩展和接口扩展均不支持泛型

### Java 使用 Cangjie 泛型数据类型

#### Java 使用泛型类/结构体

Java 使用 Cangjie 泛型类（非 open 类）、结构体之前需对泛型类型进行配置，参考[类型配置介绍](#java-使用-配置文件)

- 支持范围
    - 泛型类型支持 Cangjie 大部分基础数值类型，详情请参见`规格限制`
    - 支持多泛型参数用法
    - 支持实例成员函数带有泛型参数和返回值

- class/struct 均参考如下示例：

    - Cangije 侧源码

    <!-- compile -->

    ```cangjie
    package genericClass

    import interoplib.interop.*
    import java.lang.*

    public class GenericClass<T> {

        private var value: T

        public GenericClass(v: T) {
            this.value = v
        }
        public func getValue() : T {
            return this.value
        }

        public func setValue(t: T) {
            value = t
        }
    }
    ```

    - 配置信息

    ```toml
    [[package]]
    name = "genericClass"
    APIStrategy = "Full"
    GenericTypeStrategy = "Partial"
    excluded_apis = [
    ]
    generic_object_configuration = [
        { name = "GenericClass", type_arguments = ["Float64", "Int32"] },
        { name = "GenericClass<Float64>", symbols = [
            "getValue",
            "GenericClass",
            "setValue"
        ]},

        { name = "GenericClass<Int32>", symbols = [
            "getValue",
            "GenericClass",
            "setValue"
        ]}
    ]
    ```

    - 映射后的 Java 代码如下：

    ```java
    public class GenericClassFloat64 {
    static {
        loadLibrary("genericClass");
    }

    long self;

    public GenericClassFloat64(double v) {
        self = initCJObjectG_(v);
    }

    public native long initCJObjectG_(double v);

    public double getValue() {
        return getValue(this.self);
    }

    public native double getValue(long self);

    public void setValue(double t) {
        setValueG_(this.self, t);
    }

    public native void setValueG_(long self, double t);
    }

    public class GenericClassInt32 {
    static {
        loadLibrary("genericClass");
    }

    long self;

    public GenericClassInt32(int v) {
        self = initCJObjectG_(v);
    }

    public native long initCJObjectG_(int v);

    public int getValue() {
        return getValue(this.self);
    }

    public native int getValue(long self);

    public void setValue(int t) {
        setValueG_(this.self, t);
    }

    public native void setValueG_(long self, int t);
    }
    ```

#### Java 使用泛型枚举

Java 使用 Cangjie 泛型枚举之前需对泛型类型进行配置，参考[类型配置介绍](#java-使用-配置文件)

- 支持范围
    - 泛型类型支持 Cangjie 大部分基础数值类型，详情请参见`规格限制`
    - 支持多泛型参数用法
    - 支持实例成员函数、属性带有泛型参数和返回值

- 示例
    - Cangije 侧源码

    <!-- compile -->

    ```cangjie
    package genericEnum

    import interoplib.interop.*
    import java.lang.*

    public enum GenericEnum<T> where T <: ToString {
        | Red(T) | Green(T) | Blue(T)

        public func printValue(): Unit {
            let s = match (this) {
                case Red(n) => "red(${n})"
                case Green(n) => "green(${n})"
                case Blue(n) => "blue(${n})"
            }
            print("cangjie: ${s}\n", flush: true)
        }

        public func setValue(a: T): T {
            print("cangjie: ${a}\n", flush: true)
            a
        }

        public prop value: T {
            get() {
                match (this) {
                    case Red(n) => n
                    case Green(n) => n
                    case Blue(n) => n
                }
            }
        }
    }
    ```

    - 配置信息

    ```toml
    [[package]]
    name = "genericEnum"
    APIStrategy = "Full"
    GenericTypeStrategy = "Partial"
    excluded_apis = [
    ]
    generic_object_configuration = [
        { name = "GenericEnum", type_arguments = ["Int32"] },
        { name = "GenericEnum<Int32>", symbols = [
            "printValue",
            "setValue"
        ]}
    ]
    ```

    - 映射后的 Java 代码如下：

    ```java
    public class GenericEnumInt32 {
    static {
        loadLibrary("genericEnum");
    }

    long self;

    public int getValue() {
        return getValueImpl(this.self);
    }

    public native int getValueImpl(long self);

    private GenericEnumInt32 (long id) {
        self = id;
    }

    public static GenericEnumInt32 Red(int p1) {
        return new GenericEnumInt32(RedinitCJObjectG_(p1));
    }

    private static native long RedinitCJObjectG_(int p1);

    public static GenericEnumInt32 Green(int p1) {
        return new GenericEnumInt32(GreeninitCJObjectG_(p1));
    }

    private static native long GreeninitCJObjectG_(int p1);

    public static GenericEnumInt32 Blue(int p1) {
        return new GenericEnumInt32(BlueinitCJObjectG_(p1));
    }

    private static native long BlueinitCJObjectG_(int p1);

    public void printValue() {
        printValue(this.self);
    }

    public native void printValue(long self);

    public int setValue(int a) {
        return setValueG_(this.self, a);
    }

    public native int setValueG_(long self, int a);
    }
    ```

#### Java 使用泛型接口

Java 使用 Cangjie 泛型接口之前需对泛型类型进行配置，参考[类型配置介绍](#java-使用-配置文件)

- 支持范围
    - 泛型类型支持 Cangjie 大部分基础数值类型，详情请参见`规格限制`
    - 支持多泛型参数用法
    - 支持实例成员函数带有泛型参数和返回值

- 示例
    - Cangije 侧源码

    <!-- compile -->

    ```cangjie
    package genericInterface

    import interoplib.interop.*
    import java.lang.*

    public interface GenericInterface<T> {
    func foo(v:T) : T {
        goo(v)
        return v
    }

    func goo(v:T) : Unit
    }
    ```

    - 配置信息

    ```toml
    [[package]]
    name = "genericInterface"
    APIStrategy = "Full"
    GenericTypeStrategy = "Partial"
    excluded_apis = [   
    ]
    generic_object_configuration = [
    { name = "GenericInterface", type_arguments = ["Int32"] },
    { name = "GenericInterface<Int32>", symbols = [
        "foo",
        "goo"
    ]}
    ]
    ```

    - 映射后的 Java 代码如下：

    ```java
    public interface GenericInterfaceInt32 {
    public default int foo(int v) {
        return GenericInterfaceInt32_fwd.foo_default_impli(this, v);
    }
    public void goo(int v);
    }
    final class GenericInterfaceInt32_fwd {
    private GenericInterfaceInt32_fwd() {}
    static {
        loadLibrary("genericInterface");
    }

    public static native int foo_default_impli(GenericInterfaceInt32 selfobj, int v);
    }
    ```

#### 规格限制

- 暂不支持自定义数据类型
- 支持的基础类型：Int、Int8、Int16、Int32、Int64、Float32、Float64、Bool
- 暂不支持的无符号类型：UInt8、UInt32、UInt64（在 Java 侧存在越界风险）
- 用户自定义类型的泛型形参若有上界，该上界类型不能包含泛型参数
- 暂仅支持无内层类型形参的实例成员函数，其形参类型和返回类型允许使用外层类型形参

### Java 使用 配置文件

配置文件采用 toml 格式进行配置，按照包级别对于符号以及泛型实例化信息进行控制，实例参考如下：

```toml
[default]
APIStrategy = "Full"
GenericTypeStrategy = "None"

[[package]]
name = "genericClass"
APIStrategy = "Full"
GenericTypeStrategy = "Partial"
excluded_apis = [
    "Vector.hello"
]
generic_object_configuration = [
    { name = "GenericClass", type_arguments = ["Int64", "Int32"] },
    { name = "GenericClass<Int64>", symbols = [
        "getValue",
        "GenericClass",
        "setValue"
    ]},

    { name = "GenericClass<Int32>", symbols = [
        "getValue",
        "GenericClass",
        "setValue"
    ]}
]
lambda_patterns = [
    {signature = "(Int32) -> Int32"},
    {signature = "(Int16) -> Float64"}
]
tuple_configuration = [
    "(Int32, Int64)",
    "(Float64, Int32)"
]
```

对应 cangjie 侧源码如下：

<!-- compile -->
```cangjie
package genericClass

import interoplib.interop.*
import java.lang.*

public struct Vector {
    private var x: Int32 = 0
    private var y: Int32 = 0

    public init(x: Int32, y: Int32) {
        this.x = x
        this.y = y
    }

    public func dot(v: Vector): Int64 {
        let res: Int64 = Int64(x * v.x  + y * v.y)
        print("cj: Hello from dot (${x}, ${y}) . (${v.x}, ${v.y}) = ${res}\n", flush: true)
        return res;
    }

    public func add(v: Vector): Vector {
       let res = Vector(x + v.x, y + v.y)
       print("cj: Hello from add (${x}, ${y}) + (${v.x}, ${v.y}), new Vector = (${res.x}, ${res.y})\n", flush: true)
       return res
    }


    public func dotReturnOption(v: Vector): Vector {
        return v;
    }

    public static func hello(v: Vector): Unit {
        print("cj: Hello from static func in cj.Vector (${v.x}, ${v.y})\n", flush: true)
    }
}

public class GenericClass<T> {

    private var value : T

    public GenericClass(v: T) {
        value = v;
    }
    public func getValue() : T {
        return this.value
    }
    public func setValue(t: T) {
        value = t
    }
}
```

- **[default]** 字段：全局默认设置，package 未具体配置信息情况下采用默认设置规则

    - **APIStrategy** 字段：符号可见性策略表示外部配置默认 Cangjie 符号对目标语言的可见性

    - **GenericTypeStrategy** 字段：泛型实例化策略表示外部配置默认 Cangjie 泛型相关 API 对目标语言的实例化范围

- **[[package]]** 字段：包配置信息

    - **name** 字段：package name

    - **APIStrategy** 字段：当前包中配置的符号可见性模式
        - Full : 对应 excluded_apis
        - None : 对应 included_apis

    - **GenericTypeStrategy** 字段：当前包中配置的泛型实例化模式
        - Partial : 需要对泛型进行指定类型的实例化
        - None : 无需使用泛型

    - **included_apis** 字段：
        用户提供的完全限定名称将在目标语言中暴露（前提是满足公开等语法要求，否则将产生告警，
        如果结构体中的符号需要暴露，则必须暴露该结构体；如果该结构体位于此列表中，则会发出警告）

    - **excluded_apis** 字段：与 included_apis 相反，其中符号将被隐藏

    - **generic_object_configuration** 字段：当前包允许进行实例化的一系列类型和符号配置

        - 泛型数据结构 & 实例化类型
            - name 字段：泛型数据类型(struct/class/interface/enum)对象名称
            - type_arguments 字段：配置实例化类型，若多泛型参数则为 "Int32, Int64" 方式对应 <T,U>

            ```toml
            { name = "GenericClass", type_arguments = ["Int64", "Int32"] }
            ```

        - 实例化数据结构 & 实例化符号
            - name 字段：对应实例化后上述泛型数据类型对象名称
            - symbols 字段：实例化数据结构内对应变量以及函数等符号

            ```toml
                { name = "GenericClass<Int64>", symbols = [
                    "getValue",
                    "GenericClass",
                    "setValue"
                ]},

                { name = "GenericClass<Int32>", symbols = [
                    "getValue",
                    "GenericClass",
                    "setValue"
                ]}
            ```

    - **lambda_patterns** 字段：用于配置需映射到 Java 侧的 Lambda 表达式函数签名列表
        - signature 字段：必选字段，用于配置 Lambda 表达式函数签名信息

        示例如下：

        ```toml
        lambda_patterns = [
            {signature = "(Int32) -> Int32"}
        ]
        ```

        以上配置将会被映射成如下 Java 类型：

        ```Java
        @FunctionalInterface
        public interface Int32ToInt32 {
            public int call(int p1);
            public static Int32ToInt32 box(Int32ToInt32 lambda) {       
                if (lambda instanceof Int32ToInt32.Box) {
                return lambda;
            } else {
                return new Box(lambda);
            }
            }
            class Box implements Int32ToInt32 {
                static {
                    loadLibrary("cj");
                }

                long cjLambdaId = 0;
                Int32ToInt32 javaLambda;
                private Box(Int32ToInt32 javaL)
                {
                    javaLambda = javaL;
                }
                private Box(long cjId)
                {
                    cjLambdaId = cjId;
                }
                @Override
                public int call(int p1)
                {
                    return this.javaLambda != null ? javaLambda.call(p1): callImpl(cjLambdaId, p1);
                }
                @Override
                public void finalize()
                {
                    if (cjLambdaId != 0) {
                    deleteCJObject(cjLambdaId);
                }
            }
            private static native int callImpl(long cjLambdaId, int p1);
            private static native void deleteCJObject(long cjLambdaId);
        }
        ```

    - **tuple_configuration** 字段：用于配置需映射到 Java 侧的元组类型信息列表

        示例代码如下：

        ```toml
        tuple_configuration = [
            "(Int32, Int64)"
        ]
        ```

        以上配置将会被映射成如下 Java 类型：

        ```toml
        final public class TupleOfInt32Int64 {
            static {
                loadLibrary("cjworld.cjworld");
            }

            long self;

            public TupleOfInt32Int64(int item0, long item1) {
                self = initCJObjectil(item0, item1);
            }

            private TupleOfInt32Int64(int item0, long item1, $$NativeConstructorMarker __init__) {
            }

            public native long initCJObjectil(int item0, long item1);

            private TupleOfInt32Int64 (long id, $$NativeConstructorMarker __init__) {
                self = id;
            }

            public int item0() {
                return item0(this.self);
            }

            public native int item0(long self);

            public long item1() {
                return item1(this.self);
            }

            public native long item1(long self);

            public native void deleteCJObject(long self);

            @Override
            public void finalize() {
                deleteCJObject(this.self);
            }
        }
        ```

#### 符号控制规格约束

配置文件需要用户保障配置的语法正确性，例如 B.funcA 为 exposed ，则 B 不允许设置为 hiddened（其他场景同理）

## 版本约束限制

当前版本的 Java 互操作方案存在如下约束限制：

- 不支持 Java Mirror 和 Impl 类的实例逃逸出线程范围，即不能作为全局变量、静态变量，或作为这些变量的字段成员
- Java Mirror 和 Impl 类的实例不能作为其他 Java Mirror 或 Impl 对象的字段成员
- Java Mirror 和 Impl 类的实例不能被 Lambda 表达式块或 spawn 线程捕获