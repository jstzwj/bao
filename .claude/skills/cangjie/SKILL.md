---
name: cangjie
description: 仓颉(Cangjie)编程语言专家助手。提供仓颉语言语法解释、代码示例、标准库API查询、调试帮助和最佳实践指导。支持并发编程、FFI互操作、宏编程、单元测试、HarmonyOS开发等场景。当用户询问仓颉语言相关问题、需要仓颉代码示例、或使用仓颉进行HarmonyOS开发时使用此技能。
---

# Cangjie Programming Language Skill

仓颉(Cangjie)是华为为HarmonyOS打造的全新编程语言。本技能提供仓颉语言的完整开发参考。

## Reference Documentation

本技能包含389个中文参考文档，分为两大类：

### 1. 开发指南 (guide/)

**开发指南** - 语言核心概念与语法
- `first_understanding/` - 快速入门（安装、Hello World、基础语法）
- `basic_data_type/` - 基本数据类型（整型、浮点、布尔、字符串、数组、元组等）
- `basic_programming_concepts/` - 基础编程概念（表达式、函数、标识符、程序结构）
- `struct/` - 结构体（定义、实例创建、mutability）
- `function/` - 函数（定义、调用、闭包、Lambda、函数重载、操作符重载）
- `enum_and_pattern_match/` - 枚举与模式匹配
- `class_and_interface/` - 类与接口（class、interface、属性、子类型、类型转换）
- `generic/` - 泛型（泛型类、函数、接口、约束、类型别名）
- `extension/` - 扩展（直接扩展、接口扩展、访问规则）
- `package/` - 包管理（包名、导入、顶层作用域、包管理）
- `concurrency/` - 并发（线程创建、同步、sleep、线程管理）
- `error_handle/` - 错误处理（异常概述、处理方式、Option类型）
- `Basic_IO/` - 基础IO（流、源流、处理流）
- `Net/` - 网络（HTTP、Socket、WebSocket）
- `Macro/` - 宏编程（宏定义、语法节点、Token类型、编译标志）
- `reflect_and_annotation/` - 反射与注解
- `FFI/` - FFI互操作（与C语言互操作）
- `multiplatform/` - 多平台（Android、iOS）
- `compile_and_build/` - 编译构建（cjc、cjpm、条件编译、交叉编译）
- `deploy_and_run/` - 部署运行
- `Appendix/` - 附录（关键词、操作符、编译选项、工具链安装等）

**工具文档** (tools/)
- `cmd-tools/` - 命令行工具手册（cjpm、cjfmt、cjlint、cjdb、cjcov等）
- `cangjie-language-server/` - LSP语言服务协议
- `command_line_overview.md` - 命令行工具概览

**中心仓库** (central-repo/)
- 仓库客户端配置、上传下载、API文档等

### 2. 标准库API文档 (runtime/)

仓颉标准库(std)完整API参考，包含36个包：

**核心包**
- `core/` - 核心类型与内置函数（Unit、Nothing、Boolean、Integer、Float、String、Array等）
- `collection/` - 集合（ArrayList、HashMap、HashSet、TreeNode等）
- `collection_concurrent/` - 并发集合（ConcurrentHashMap、ConcurrentLinkedQueue）
- `io/` - IO操作（流、读写、缓冲、文件操作）
- `fs/` - 文件系统（文件、目录、路径操作）

**网络与通信**
- `net/` - 网络编程（HTTP、TCP、UDP）
- `console/` - 控制台操作

**加密与安全**
- `crypto/` - 加密算法
- `convert/` - 数据类型转换

**数学与数值**
- `math/` - 数学函数
- `math_numeric/` - 数值运算
- `random/` - 随机数生成
- `overflow/` - 溢出检查

**并发与同步**
- `sync/` - 同步原语（Mutex、Condvar、RWLock等）
- `runtime/` - 运行时支持

**系统编程**
- `process/` - 进程管理
- `posix/` - POSIX接口
- `env/` - 环境变量
- `time/` - 时间日期

**文本处理**
- `regex/` - 正则表达式
- `unicode/` - Unicode支持

**开发工具**
- `unittest/` - 单元测试框架
  - `unittest_common/` - 通用测试工具
  - `unittest_diff/` - 差异比较
  - `unittest_mock/` - Mock支持
  - `unittest_prop_test/` - 属性测试
  - `unittest_testmacro/` - 测试宏
- `reflect/` - 反射
- `ast/` - 抽象语法树

**工具库**
- `argopt/` - 命令行参数解析
- `sort/` - 排序算法
- `ref/` - 引用类型
- `objectpool/` - 对象池
- `database_sql/` - SQL数据库
- `binary/` - 二进制操作
- `deriving/` - 派生宏
- `interop/` - 互操作

## Usage Guidelines

当用户需要以下帮助时，查阅相应参考文档：

1. **语法与概念** - 查阅 `guide/dev-guide/` 中相关章节
2. **API使用** - 查阅 `runtime/` 中对应包的API文档
3. **代码示例** - 查看 `runtime/*/*_samples/` 目录下的示例代码
4. **构建与运行** - 查看 `guide/dev-guide/compile_and_build/` 和 `tools/cmd-tools/`
5. **调试与测试** - 查看 `guide/dev-guide/` 和 `runtime/unittest/`

每个包的结构：
- `*_package_overview.md` - 包概述
- `*_package_api/` - API详细文档（类、接口、函数、枚举、异常等）
- `*_samples/` - 代码示例
