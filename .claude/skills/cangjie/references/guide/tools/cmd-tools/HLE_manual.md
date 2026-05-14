# HLE 工具

## 功能简介

`HLE (HyperlangExtension)` 是一个仓颉调用 ArkTS 或者 C 语言的互操作代码模板自动生成工具。
该工具的输入是 ArkTS 或者 C 语言的接口声明文件，例如后缀为 .d.ts，.d.ets 或者 .h 结尾的文件，输出为 cj 文件，其中存放生成的互操作代码。如果生成的是 ArkTS 到仓颉的胶水层代码，工具也会输出包含 ArkTS 文件的所有信息的 json 文件。ArkTS 转换到仓颉的转换规则请参见：[ArkTS 三方模块生成仓颉胶水代码的规则](cj-dts2cj-translation-rules.md)。C 语言转换到仓颉的转换规则请参见：[C 语言转换到仓颉胶水代码的规则](cj-c2cj-translation-rules.md)。

## 使用说明

### 依赖

1. 本工具执行依赖 nodejs：

    版本建议在 v18.14.1 及以上, 低版本可能存在 ArkTS 语法无法解析情况，建议使用新版本 node。

    [如何安装 Node.js](https://dev.nodejs.cn/learn/how-to-install-nodejs/)

    比如可以使用以下的命令安装：

    ```sh
    # Download and install nvm:
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash
    # in lieu of restarting the shell
    \. "$HOME/.nvm/nvm.sh"
    # Download and install Node.js:
    nvm install 22
    # Verify the Node.js version:
    node -v # Should print "v22.17.1".
    nvm current # Should print "v22.17.1".
    # Verify npm version:
    npm -v # Should print "10.9.2".
    ```

2. 本工具执行依赖 typescript 和 cjbind：

    在安装完 nodejs 后，使用以下的命令安装 typescript 和 cjbind：

    ```sh
    cd ${CANGJIE_HOME}/tools/dtsparser/
    npm install
    ```

### 参数含义

| 参数            | 含义                                        | 参数类型 | 说明                 |
| --------------- | ------------------------------------------- | -------- | -------------------- |
| `-i`            | d.ts，d.ets 或者 .h 文件输入的绝对路径             | 可选参数 | 和`-d`参数二选一或者两者同时存在                     |
| `-r`            | typescript 编译器的绝对路径                  | 必选参数 | 只给 ArkTS 生成仓颉 bindings 时使用 |
| `-d`            | d.ts，d.ets 或者 .h 文件输入所在文件夹的绝对路径    | 可选参数 | 和`-i`参数二选一或者两者同时存在                     |
| `-o`            | 输出保存互操作代码的目录                    | 可选参数 | 缺省时输出至当前目录 |
| `-j`            | 分析 d.t 或者 d.ets 文件的路径                 | 可选参数 | 只给 ArkTS 生成仓颉 bindings 时使用 |
| `--module-name` | 自定义生成的仓颉包名                        | 可选参数 | NA |
| `--lib`         | 生成三方库代码                              | 可选参数 | 只给 ArkTS 生成仓颉 bindings 时使用 |
| `-c`            | 生成 C 到仓接的绑定代码                              | 可选参数 | 只给 C 语言生成仓颉 bindings 时使用 |
| `-b`            | 指定 cjbind 二进制的路径                              | 可选参数 | 只给 C 语言生成仓颉 bindings 时使用 |
| `--clang-args`  | 会被直接传递给 clang 的参数                              | 可选参数 | 只给 C 语言生成仓颉 bindings 时使用 |
| `--no-detect-include-path`  | 禁用自动 include 路径检测                              | 可选参数 | 只给 C 语言生成仓颉 bindings 时使用 |
| `--help`        | 帮助选项                                   | 可选参数 | NA |

### 命令行

可使用如下的命令生成 ArkTS 到 Cangjie 绑定代码：

```sh
hle -i /path/to/test.d.ts -o out –j ${CANGJIE_HOME}/tools/dtsparser/analysis.js --module-name="my_module"
```

在 Windows 环境，文件目录当前不支持符号“\\”，仅支持使用“/”。

生成 C 到 Cangjie 绑定代码的命令如下：

```sh
hle -b ${CANGJIE_HOME}/tools/dtsparser/node_modules/.bin/cjbind -c --module-name="my_module" -d ./tests/c_cases -o ./tests/expected/c_module/ --clang-args="-I/usr/lib/llvm-20/lib/clang/20/include/"
```

其中`-b`参数用于指定 cjbind 二进制文件的路径，cjbind 下载地址如下：

- Linux: <https://gitcode.com/Cangjie-SIG/cjbind-cangjie/releases/download/v0.2.7/cjbind-linux-x64>
- Windows: <https://gitcode.com/Cangjie-SIG/cjbind-cangjie/releases/download/v0.2.7/cjbind-windows-x64.exe>
- macOS: <https://gitcode.com/Cangjie-SIG/cjbind-cangjie/releases/download/v0.2.7/cjbind-darwin-arm64>

`--clang-args`参数是会被直接传递给 clang 的参数，在参数值内可用 -I 指定头文件搜索路径。系统头文件路径程序会自动搜索，用户自定义的头文件路径需要显式指定。
