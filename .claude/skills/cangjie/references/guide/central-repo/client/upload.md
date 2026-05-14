# 制品包发布

`cjpm` 可以将开发的源码模块打包并发布到中心仓库。发布前用户须配置 token 以进行用户认证。

## 中心仓相关配置项

`cjpm.toml` 中与制品包制作与发布有关的字段如下：

| 字段名 | 字段描述 | 是否必填 |
| --- | --- | --- |
| `cjc-version` | 仓颉 SDK 最低版本号 | 是 |
| `name` | 模块名，与模块内 `root` 包名一致 | 是 |
| `organization` | 组织名，为空则为无组织模块 | 否 |
| `description` | 描述信息 | 仅打包时必填 |
| `version` | 模块版本信息 | 是 |
| `output-type` | 编译输出产物类型，取值为静态库/动态库/可执行 (static/dynamic/executable) | 是 |
| `authors` | 作者 ID 列表 | 否 |
| `repository` | 制品仓代码 url | 否 |
| `homepage` | 制品主页 url | 否 |
| `documentation` | 制品文档页 url | 否 |
| `tag` | 制品标签 | 否 |
| `category` | 官方提供的制品分类，取值范围详见 cjpm 文档相关章节 | 否 |
| `license` | 协议列表 | 否 |
| `include` | 指定打包范围 | 否 |
| `exclude` | 指定打包排除范围 | 否 |
| `dependencies` | 项目依赖，格式如：`aoo = "1.0.0"` 或 `“org::boo” = { version = “2.0.0” }` | 否 |
| `test-dependencies` | 测试依赖，格式和 `dependencies` 相同 | 否 |
| `script-dependencies` | 脚本依赖，格式和 `dependencies` 相同 | 否 |

如下是一个具体的 `cjpm.toml` 例子：

```toml
[package]
  cjc-version = "1.0.0"
  name = "demo"
  organization = "cangjie"
  description = "demo of cangjie central repository"
  version = "1.0.0"
  output-type = "executable"
  authors = ["Tom", "Joan"]
  repository = "https://cangjie-demo.git"
  homepage = "https://cangjie-demo.com"
  documentation = "https://cangjie-demo.com/docs"
  tag = ["cangjie", "demo"]
  category = ["Network", "UI"]
  license = ["Apache-2.0"]
  include = ["src"]
  exclude = ["*.txt"]

[dependencies]
  aoo = "1.0.0"

[test-dependencies]
  boo = "2.0.0"

[script-dependencies]
  "org::coo" = "3.0.0"
```

## 制品包打包

`cjpm` 提供 `bundle` 命令，将本地开发的源码模块打包成符合中心仓制品包格式的制品包，用于后续的上传操作。

`bundle` 打包范围由 `cjpm.toml` 中的 `include` 和 `exclude` 两个字段决定。`include` 和 `exclude` 均为字符串数组形式，每个字符串代表一条匹配规则，匹配规则格式符合 `gitignore` 屏蔽格式。

`bundle` 命令仅会检查并打包当前项目目录下的文件。基于开发者配置的 `include` 和 `exclude` 字段，最终 `bundle` 命令的打包范围确定规则如下：

- 无关配置，默认会被打包的文件：项目根目录下的 `cjpm.toml`, `README.md` 和 `README_zh.md`
- 无关配置，默认不会被打包的文件：
    - 项目根目录下的 `cjpm.lock` 和 `cangjie-repo.toml`
    - 编译产物目录和构建脚本产物目录
    - 所有二进制文件
- 除了上述文件范围，其他的文件遵循以下规则：
    - 若文件匹配任意 `include` 规则，且不匹配任意 `exclude` 规则，则该文件会被打包
    - 若 `include` 中没有配置，则会打包当前目录下所有不匹配任意 `exclude` 规则的文件

例如，有以下的待打包模块 `demo`：

```text
demo
├── src
│    ├── demo.cj
│    ├── demo-config.txt
│    └── aoo
│         ├── aoo.cj
│         └── aoo-config.txt
├── test
│    ├── test.cj
│    └── test-config.txt
├── README.md
└── cjpm.toml
```

则基于不同的配置，打包范围示例如下：

示例一：

```toml
[package]
  include = []
  exclude = []
```

结果：打包上述文件列表中的所有文件。

示例二：

```toml
[package]
  include = ["src"]
  exclude = []
```

结果：打包 `cjpm.toml`, `README.md` 和 `src` 目录。

示例三：

```toml
[package]
  include = []
  exclude = ["*.txt"]
```

结果：排除所有 `txt` 文件，打包其余文件。

示例四：

```toml
[package]
  include = ["src"]
  exclude = ["*.txt"]
```

结果：打包 `cjpm.toml`, `README.md` 和 `src` 目录中除了 `txt` 文件以外的其他文件。

`bundle` 打包流程如下：

1. 模块检查

    一个可以被成功打包的 `cjpm` 模块，需要满足以下条件：

    - 模块名、组织名满足规格要求：
        - 长度范围为 [3, 64]，且符合模块名和组织名规格；
        - 不能为任何仓颉语法中的关键字（大小写不敏感）；
        - 组织名不能为 `default`；
    - `cjpm.toml` 中包含模块说明 `description`；
    - 根目录下包含中文文档 `README_zh.md` 或英文文档 `README.md`；
    - 模块的依赖项均为中心仓形式。

    若模块不满足上述条件，则打包失败。

2. 编译检查：进行编译检查，确保模块能够编译通过；如果未配置 `--skip-test`，则会运行单元测试。编译和测试失败均会导致打包失败。
3. 代码静态检查：如果未配置 `--skip-lint`，则会调用 `cjlint` 进行代码静态检查，出现 `error` 级别的错误则会导致打包失败。
4. 打包：基于 `include` 和 `exclude` 字段，将当前模块打包成 `tar.gz` 格式的制品源码包。制品源码包位于编译产物目录中，文件名为 `模块名-版本号.cjp`。同时，生成制品包对应的元数据文件，也位于编译产物目录中，文件名为 `meta-data.json`。

继续以上文中待打包模块 `demo` 为例，假设其 `cjpm.toml` 中配置的版本号 `version = "1.0.0"`。由于未配置编译产物目录，因此默认编译产物目录为 `target`。执行 `cjpm bundle` 后，`target` 目录中会有如下内容：

```text
target
├── demo-1.0.0.cjp  # 制品源码包
├── meta-data.json  # 制品元数据
└── 其他编译产物
```

`demo-1.0.0.cjp` 可以按 `tar.gz` 格式被解压。

> **注意：**
>
> 元数据文件记录了本地模块的一些关键信息，供中心仓网页进行制品信息展示。请参阅[中心仓元数据规格](../appendix/meta_data.md)以获取更多信息。

## 制品包发布

`cjpm` 提供 `publish` 命令，用于将 `bundle` 命令生成的制品源码包发布到中心仓。

执行 `publish` 命令时，`cjpm` 会检查编译产物目录中是否有名为 `模块名-版本号.cjp` 的制品源码包和元数据文件 `meta-data.json`，若任意一个文件不存在，或者元数据中的制品包校验码与制品包不匹配，则重新执行默认 `bundle` 流程。随后，`cjpm` 会将有效的制品源码包和元数据发布到中心仓。

`publish` 发布成功需要满足如下条件：

1. 已在 `cangjie-repo.toml` 中配置有效的用户 token；
2. 上传的制品包唯一，即仓库中不存在另一个制品包与新上传制品包的组织名、制品名和版本号均相同；
3. 若制品包隶属于某个组织，则 token 对应的用户需要是该组织的成员；
4. 发布的制品包通过中心仓的安全扫描。