# 包的导入

## 使用 `import` 语句导入其他包中的声明或定义

在仓颉编程语言中，可以通过 `import orgName::fullPackageName.itemName` 的语法导入其他包中的一个顶层声明或定义，`fullPackageName` 为完整路径包名，`itemName` 为声明的名字。对于无组织名的包，省略组织名和组织名分隔符 `::`。导入语句在源文件中的位置必须在包声明之后，其他声明或定义之前。例如：

<!-- code_check_manual -->

```cangjie
package a
import std.math.*
import package1.foo
import {package1.foo, package2.bar}
import org::package1.foo // 导入组织 org 下 package1 包中的子包 foo
```

如果要导入的多个 `itemName` 同属于一个 `fullPackageName`，可以使用 `import fullPackageName.{itemName[, itemName]*}` 语法，例如：

<!-- code_check_manual -->

```cangjie
import package1.{foo, bar, fuzz}
```

这等价于：

<!-- code_check_manual -->

```cangjie
import package1.foo
import package1.bar
import package1.fuzz
```

除了通过 `import fullPackagename.itemName` 语法导入一个特定的顶层声明或定义外，还可以使用 `import packageName.*` 语法将 `packageName` 包中所有可见的顶层声明或定义全部导入。例如：

<!-- code_check_manual -->

```cangjie
import package1.*
import {package1.*, package2.*}
import org::{package1.*, package2.*}
```

需要注意：

- 导入的成员的作用域级别低于当前包声明的成员。
- 当已导出的包的模块名或者包名被篡改，使其与导出时指定的模块名或包名不一致，在导入时会报错。
- 只允许导入当前文件可见的顶层声明或定义，导入不可见的声明或定义将会在导入处报错。
- 禁止通过 `import` 导入当前源文件所在包的声明或定义。
- 禁止包间的循环依赖导入，如果包之间存在循环依赖，编译器会报错。
- `::` 后必须接包名。
- 使用完整包名访问导入成员时，不能使用组织名。

示例如下：

<!-- code_check_manual -->

```cangjie
// pkga/a.cj
package pkga    // 错误，pkga 和 pkgb 循环依赖
import pkgb.*

class C {}
public struct R {}

// pkgb/b.cj
package pkgb

import pkga.*

// pkgc/c1.cj
package pkgc

import pkga.C // 错误, C 在 pkga 不可访问
import pkga.R // 正确，R 是包 pkga 的 external 的顶层声明
import pkgc.f1 // 错误，包 pkgc 不能导入自己
import org::* // 错误，'*' 后应紧跟包名
import org::pkgf
import pkgf
import org2::{
    pkga.{foo, bar} // 错误，多导入不能嵌套
}

public func f1() {}

func f2() {
    // 正确
    R()

    // 正确，可以使用完整包名访问导入的声明
    pkga.R()

    // 正确，本包声明可以直接访问
    f1()

    // 错误，不能使用组织名前缀访问声明
    org::pkgf.f1()

    // 错误，pkgf 在 pkgf 与 org::pkgf 这两个形式上存在歧义
    pkgf.f1()
}
```

在仓颉编程语言中，导入的声明或定义如果和当前包中的顶层声明或定义重名且不构成函数重载，则导入的声明和定义会被遮盖；导入的声明或定义如果和当前包中的顶层声明或定义重名且构成函数重载，函数调用时将会根据函数重载的规则进行函数决议。

<!-- compile -over_res -->
<!-- cfg="-p pkga --output-type=staticlib"-->

```cangjie
// pkga/a.cj
package pkga

public struct R {}            // R1
public func f(a: Int32) {}    // f1
public func f(a: Bool) {} // f2
```

<!-- compile -over_res -->
<!-- cfg="-p pkgb libpkga.a --output-type=staticlib"-->

```cangjie
// pkgb/b.cj
package pkgb

import pkga.*

func f(a: Int32) {}         // f3
struct R {}                 // R2

func bar() {
    R()     // OK, R2 shadows R1.
    f(1)    // OK, invoke f3 in current package.
    f(true) // OK, invoke f2 in the pkga
}
```

## 隐式导入 core 包

诸如 `String`、`Range` 等类型能直接使用，并不是因为这些类型是内置类型，而是因为编译器会自动为源码隐式的导入 `core` 包中所有的 `public` 修饰的声明。

## 使用 `import as` 对导入的名字重命名

不同包的名字空间是分隔的，因此在不同的包之间可能存在同名的顶层声明。在导入不同包的同名顶层声明时，支持使用 `import packageName.name as newName` 的方式进行重命名来避免冲突。没有名字冲突的情况下仍然可以通过 `import as` 来重命名导入的内容。`import as` 具有如下规则：

- 使用 `import as` 对导入的声明进行重命名后，当前包只能使用重命名后的新名字，原名无法使用。
- 如果重命名后的名字与当前包顶层作用域的其他名字存在冲突，且这些名字对应的声明均为函数类型，则参与函数重载，否则报重定义的错误。
- 支持 `import pkg as newPkgName` 的形式对包名进行重命名，以解决不同模块中同名包的命名冲突问题。
    <!-- compile.error -import3-->
    <!-- cfg="-p p1 --output-type=staticlib" -->

    ```cangjie
    // a.cj
    package p1
    public func f1() {}
    ```

    <!-- compile.error -import3-->
    <!-- cfg="-p p2 --output-type=staticlib" -->

    ```cangjie
    // d.cj
    package p2
    public func f3() {}
    ```

    <!-- compile.error -import3-->
    <!-- cfg="-p p1 --output-type=staticlib" -->

    ```cangjie
    // b.cj
    package p1
    public func f2() {}
    ```

    <!-- compile.error -import3-->
    <!-- cfg="-p pkgc --output-type=staticlib" -->

    ```cangjie
    // c.cj
    package pkgc
    public func f1() {}
    ```

    <!-- compile.error -import3-->
    <!-- cfg="libp1.a libpkgc.a libp1.a" -->

    ```cangjie
    // main.cj
    import p1 as A
    import p1 as B
    import p2.f3 as f  // 正确
    import pkgc.f1 as a
    import pkgc.f1 as b // 正确
    import org::pkgc as org_pkgc

    func f(a: Int32) {}

    main() {
        A.f1()  // 正确
        B.f2()  // 正确
        p1.f1() // 错误，p1 是用别名导入的，不能使用原包名
        a()     // 正确
        b()     // 正确
        pkgc.f1()    // 错误，pkgc.f1 被别名导入，不能使用原名字
        org_pkgc.f1() // 正确
    }
    ```

- 如果没有对导入的存在冲突的名字进行重命名，在 `import` 语句处不报错；在使用处，会因为无法导入唯一的名字而报错。这种情况可以通过 `import as` 定义别名或者 `import fullPackageName` 导入包作为命名空间。

    <!-- compile -import1 -->
    <!-- cfg="-p p1 --output-type=staticlib"-->

    ```cangjie
    // a.cj
    package p1
    public class C {}
    ```

    <!-- compile -import1 -->
    <!-- cfg="-p p2 --output-type=staticlib"-->

    ```cangjie
    // b.cj
    package p2
    public class C {}
    ```

    <!-- code_check_manual -->

    ```cangjie
    // main1.cj
    package pkga
    import p1.C
    import p2.C

    main() {
        let _ = C() // Error
    }
    ```

    <!-- compile -import1 -->
    <!-- cfg="-p pkgb libp1.a libp2.a"-->

    ```cangjie
    // main2.cj
    package pkgb
    import p1.C as C1
    import p2.C as C2

    main() {
        let _ = C1() // OK
        let _ = C2() // OK
    }
    ```

    <!-- compile -import1 -->
    <!-- cfg="-p pkgc libp1.a libp2.a"-->

    ```cangjie
    // main3.cj
    package pkgc
    import p1
    import p2

    main() {
        let _ = p1.C() // OK
        let _ = p2.C() // OK
    }
    ```

## 重导出一个导入的名字

在功能繁多的大型项目的开发过程中，这样的场景是非常常见的：包 `p2` 大量地使用从包 `p1` 中导入的声明，当包 `p3` 导入包 `p2` 并使用其中的功能时，`p1` 中的声明同样需要对包 `p3` 可见。如果要求包 `p3` 自行导入 `p2` 中使用到的 `p1` 中的声明，这个过程将过于繁琐。因此希望能够在 `p2` 被导入时一并导入 `p2` 使用到的 `p1` 中的声明。

在仓颉编程语言中，`import` 可以被 `private`、`internal`、`protected`、`public` 访问修饰符修饰。其中，被 `public`、`protected` 或者 `internal` 修饰的 `import` 可以把导入的成员重导出（如果这些导入的成员没有因为名称冲突或者被遮盖导致在本包中不可用）。其他包可以根据可见性直接导入并使用本包中用重导出的内容，无需从原包中导入这些内容。

- `private import` 表示导入的内容仅当前文件内可访问，`private` 是 `import` 的默认修饰符，不写访问修饰符的 `import` 等价于 `private import`。
- `internal import` 表示导入的内容在当前包及其子包（包括子包的子包）均可访问。非当前包访问需要显式 `import`。
- `protected import` 表示导入的内容在当前 module 内都可访问。非当前包访问需要显式 `import`。
- `public import` 表示导入的内容外部都可访问。非当前包访问需要显式 `import`。

在下面的例子中，`b` 是 `a` 的子包，在 `a` 中通过 `public import` 重导出了 `b` 中定义的函数 `f`。

<!-- compile -reimport1 -->
<!-- cfg="-p a/b --output-type=staticlib"-->

```cangjie
internal package a.b

public func f() { 0 }
```

<!-- compile -reimport1 -->
<!-- cfg="-p a --output-type=staticlib"-->

```cangjie
package a
public import a.b.f

public let x = 0
```

<!-- compile -reimport1 -->
<!-- cfg="liba.a liba.b.a"-->

```cangjie
import a.f  // OK
let _ = f() // OK
```

需要注意的是，包不可以被重导出：如果被 `import` 导入的是包，那么该 `import` 不允许被 `public`、`protected` 或者 `internal` 修饰。

<!-- compile.error -->

```cangjie
public import a.b // Error, cannot re-export package
```
