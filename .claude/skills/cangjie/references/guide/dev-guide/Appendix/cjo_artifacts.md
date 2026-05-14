# cjo 产物说明

本章介绍仓颉编程语言编译过程中生成的 cjo（Cangjie Object）产物的作用和相关信息。

## 什么是 cjo 产物

cjo（Cangjie Object）是仓颉编译器生成的二进制格式的 AST（抽象语法树）文件，主要承载类似 C 语言头文件的作用。cjo 文件包含了包的接口信息、类型定义、函数声明等元数据，用于在编译时进行语义检查和类型检查。除了接口元数据外，cjo 文件在某些特殊场景下也会包含部分实现内容，如内联函数、部分表达式等需要在编译时展开的代码片段。

## cjo 文件的作用

### 接口描述

cjo 文件记录了包的公共接口信息，包括类型定义、函数签名、常量声明等，类似于 C 语言中的头文件作用。

### 编译时依赖解析

在编译时，编译器通过 cjo 文件获取被导入包的接口信息，进行语义检查和类型检查，而无需重新解析源代码。

### 模块化支持

cjo 文件实现了模块间的解耦，允许包的接口和实现分离，支持独立编译和分发。

### 跨包依赖管理

通过 cjo 文件，编译器可以有效管理包之间的依赖关系，确保类型安全和接口一致性。

## cjo 文件的生成

### 编译包时自动生成

使用 `cjc` 编译包时会自动生成对应的 cjo 文件：

```shell
$ cjc -p mypackage --output-type=staticlib
```

编译器会生成 `mypackage.cjo` 文件和相应的库文件。

### 指定输出目录

可以使用 [`--output-dir`](compile_options.md#--output-dir-value-frontend) 选项指定 cjo 文件的输出目录：

```shell
$ cjc -p mypackage --output-type=staticlib --output-dir ./build
```

### 宏包的 cjo 文件

对于[宏包](../Macro/defining_and_importing_macro_package.md)，编译时会生成带有宏属性的 cjo 文件：

```shell
$ cjc --compile-macro macro_define.cj --output-dir ./target
```

## cjo 文件的使用

### 与 --import-path 配合使用

cjo 文件主要通过 [`--import-path`](compile_options.md#--import-path-value-frontend) 选项来指定搜索路径。假设有以下目录结构：

```text
.
├── libs
|   └── myModule
|       ├── myModule.log.cjo
|       └── libmyModule.log.a
└── main.cj
```

可以通过以下命令使用 cjo 文件：

```shell
$ cjc main.cj --import-path ./libs libmyModule.a
```

编译器会使用 `./libs/myModule/myModule.log.cjo` 文件来对 `main.cj` 文件进行语义检查与编译。

### 在 CJPM 中的使用

在 `cjpm.toml` 配置文件中，可以通过 `bin-dependencies` 配置 cjo 文件依赖：

```toml
[target.x86_64-unknown-linux-gnu.bin-dependencies]
path-option = ["./test/pro0", "./test/pro1"]

[target.x86_64-unknown-linux-gnu.bin-dependencies.package-option]
"pro0.xoo" = "./test/pro0/pro0.xoo.cjo"
"pro0.yoo" = "./test/pro0/pro0.yoo.cjo"
```

### 依赖扫描

可以使用 [`--scan-dependency`](compile_options.md#--scan-dependency-frontend) 选项扫描 cjo 文件的依赖关系：

```shell
$ cjc --scan-dependency mypackage.cjo
```

## cjo 文件的特点

### 二进制 AST 格式

cjo 文件采用二进制格式存储抽象语法树信息，相比文本格式具有更高的解析效率。

### 接口信息完整性

cjo 文件包含完整的包接口信息，包括类型定义、函数签名、可见性等元数据。

### 编译器版本兼容性

自 LTS 版本开始，仓颉编译器承诺向后兼容，后续版本的编译器能够正确处理之前版本生成的 cjo 文件。在 LTS 版本之前，不同版本编译器生成的 cjo 文件可能存在兼容性问题。

### 宏信息支持

对于宏包，cjo 文件会携带宏属性信息，支持宏的编译时展开。

## 使用建议

### 使用 CANGJIE_PATH 环境变量

可以通过设置 [`CANGJIE_PATH`](compile_options.md#--import-path-value-frontend) 环境变量指定 cjo 文件的搜索路径，[`--import-path`](compile_options.md#--import-path-value-frontend) 选项具有更高优先级。

### 二进制库分发

将 cjo 文件与对应的库文件（.a 或 .so）一起分发，提供给其他模块作为二进制依赖。

## 常见问题

### cjo 文件与源文件不同步怎么办

删除过期的 cjo 文件，重新编译对应的包即可。

### 如何查看 cjo 文件的依赖信息

可以使用 [`cjc --scan-dependency`](compile_options.md#--scan-dependency-frontend) `mypackage.cjo` 命令查看依赖关系。

### 为什么找不到 cjo 文件

检查 [`--import-path`](compile_options.md#--import-path-value-frontend) 设置是否正确，确保 cjo 文件在指定的搜索路径中。

### cjo 文件可以跨平台使用吗

当前 cjo 文件暂时不支持跨平台使用，建议在目标平台重新生成对应的 cjo 文件。未来版本计划支持跨平台使用。

## 相关选项

以下编译选项与 cjo 文件生成和使用相关：

- [`--import-path <value>`](compile_options.md#--import-path-value-frontend)：指定导入模块的 AST 文件搜索路径
- [`--output-dir <value>`](compile_options.md#--output-dir-value-frontend)：控制 cjo 文件的保存目录
- [`-p, --package`](compile_options.md#--package--p-frontend)：编译包时自动生成对应的 cjo 文件
- [`--scan-dependency`](compile_options.md#--scan-dependency-frontend)：扫描 cjo 文件的依赖关系
- `--compile-macro`：编译宏包生成带有宏属性的 cjo 文件

## 注意事项

1. **搜索路径**：确保通过 [`--import-path`](compile_options.md#--import-path-value-frontend) 或 [`CANGJIE_PATH`](compile_options.md#--import-path-value-frontend) 正确设置 cjo 文件的搜索路径。

2. **文件同步**：cjo 文件必须与对应的库文件保持同步，版本不匹配可能导致编译错误。

3. **版本兼容性**：自 LTS 版本开始，仓颉编译器承诺向后兼容，新版本能够正确处理之前版本生成的 cjo 文件。在 LTS 之前的版本中，升级编译器后建议重新生成 cjo 文件。

4. **宏包处理**：宏包的 cjo 文件需要与对应的动态库文件配合使用，路径设置要保持一致。

5. **依赖解析**：编译器通过 cjo 文件进行语义检查，确保导入的包接口信息完整准确。