# 条件编译

开发者可以通过预定义或自定义的条件完成条件编译；仓颉目前支持导入和声明的条件编译。

## 导入和声明的条件编译

仓颉支持使用内置编译标记 `@When` 来完成条件编译，编译条件使用 `[]` 括起来，`[]` 内支持输入一组或多组编译条件。`@When` 可以作用于导入节点和除 `package` 外的声明节点。

### 使用方法

以内置 os 编译条件为例，其使用方法如下：

<!-- run -->

```cangjie
@When[os == "Linux"]
class mc{}

main(): Int64 {
    var a = mc()
    return 0
}
```

在上面代码中，开发者在 `Linux` 系统中可以正确编译执行；在`非 Linux` 系统中，则会遇到找不到 `mc` 类定义的编译错误。

值得注意的是：

- 仓颉不支持编译条件嵌套，以下写法均不允许：

    <!-- compile.error -->

    ```cangjie
    @When[os == "Windows"]
    @When[os == "Linux"]    // Error, illegal nested when conditional compilation
    import std.ast.*
    @When[os == "Windows"]
    @When[os == "Linux"]    // Error, illegal nested when conditional compilation
    func A(){}
    ```

- `@When[...]` 作为内置编译标记，在导入前处理，由宏展开生成的代码中含有 `@When[...]` 会编译报错，如：

    <!-- compile.error -->

    ```cangjie
    @Derive[ToString]
    @When[os == "Linux"]    // Error, unexpected when conditional compilation directive
    class A {}
    ```

## 内置编译条件变量

仓颉提供的内置条件变量有: `os`、 `arch`、 `env`、 `backend`、 `cjc_version`、 `debug` 和 `test`。

### os

os 表示目标平台的操作系统。`os` 支持 `==` 和 `!=` 两种操作符。支持的操作系统有：`Windows`、`Linux`、`macOS`、`iOS`。

使用方式如下：

<!-- run -->

```cangjie
@When[os == "Linux"]
func foo() {
    print("Linux, ")
}
@When[os == "Windows"]
func foo() {
    print("Windows, ")
}
@When[os != "Windows"]
func fee() {
    println("NOT Windows")
}
@When[os != "Linux"]
func fee() {
    println("NOT Linux")
}
main() {
    foo()
    fee()
}
```

如果在 `Windows` 环境下编译执行，会得到 `Windows, NOT Linux` 的信息；如果是在 `Linux` 环境下，则会得到 `Linux, NOT Windows` 的信息。

### arch

`arch` 表示目标平台的处理器架构。`arch` 条件支持 `==` 和 `!=` 两种操作符。

支持的处理器架构有：`x86_64`、`aarch64`。

使用方式如下：

<!-- run -->

```cangjie
@When[arch == "aarch64"]
var arch = "aarch64"

@When[arch == "x86_64"]
var arch = "x86_64"

main() {
    println(arch)
}
```

在 `x86_64` 架构的目标平台编译执行，会得到 `x86_64` 的信息；在 `aarch64` 架构的目标平台编译执行，会得到 `aarch64` 的信息。

### env

`env` 在其他条件变量的基础上提供额外信息，比如目标平台的 ABI （Application Binary Interface），用于消除目标平台之间的歧义。`env` 条件支持 `==` 和 `!=` 两种操作符。

支持的 `env` 选项有：`ohos`、`gnu`、`simulator`、`android`以及缺省（空字符串）。

使用方式如下：

<!-- run -->

```cangjie
@When[env == "ohos"]
var env = "ohos"

@When[env != "ohos"]
var env = "other"

main() {
    println(env)
}
```

在 OpenHarmony 目标平台上编译执行，会得到 `ohos` 的信息；在其他目标平台编译执行，会得到 `other` 的信息。

### backend

`backend` 表示目标平台的后端类型，用于支持多种后端条件编译。`backend` 条件支持 `==` 和 `!=` 两种操作符。

当前支持的后端有：`cjnative`。

使用方式如下：

<!-- run -->

```cangjie
@When[backend == "cjnative"]
func foo() {
    print("cjnative backend")
}
@When[backend != "cjnative"]
func foo() {
    print("not cjnative backend")
}
main() {
    foo()
}
```

用 `cjnative` 后端的发布包编译执行，会得到 `cjnative backend` 的信息。

### cjc_version

`cjc_version` 是仓颉内置的条件，开发者可以根据当前仓颉编译器的版本选择要编译的代码。`cjc_version` 条件支持 `==`、`!=`、`>`、`<`、`>=`、`<=` 六种操作符，格式为 `xx.xx.xx` 支持每个 `xx` 支持 1-2 位数字，计算规则为补位 (补齐 2 位) 比较，例如：`0.18.8 < 0.18.11`， `0.18.8 == 0.18.08`。

使用方式如下：

<!-- run -->

```cangjie
@When[cjc_version == "0.18.6"]
func foo() {
    println("cjc_version equals 0.18.6")
}
@When[cjc_version != "0.18.6"]
func foo() {
    println("cjc_version is NOT equal to 0.18.6")
}
@When[cjc_version > "0.18.6"]
func fnn() {
    println("cjc_version is greater than 0.18.6")
}
@When[cjc_version <= "0.18.6"]
func fnn() {
    println("cjc_version is less than or equal to 0.18.6")
}
@When[cjc_version < "0.18.6"]
func fee() {
    println("cjc_version is less than 0.18.6")
}
@When[cjc_version >= "0.18.6"]
func fee() {
    println("cjc_version is greater than or equal to 0.18.6")
}
main() {
    foo()
    fnn()
    fee()
}
```

根据 `cjc` 的版本，上面代码的执行输出结果会有不同。

### debug

`debug` 表示当前是否启用了调试模式即开启 `-g` 编译选项, 可以用于在编译代码时进行调试和发布版本之间的切换。`debug` 条件仅支持逻辑非运算符（`!`）。

使用方式如下：

<!-- run -->

```cangjie
@When[debug]
func foo() {
    println("debug")
}
@When[!debug]
func foo() {
    println("NOT debug")
}
main() {
    foo()
}
```

启用 `-g` 编译执行会得到 `cjc debug` 的信息，如果没有启用 `-g` 编译执行会得到 `NOT debug` 的信息。

### test

`test` 表示当前是否启用了单元测试选项 `--test`。`test` 条件仅支持逻辑非运算符（`!`）。可以用于区分测试代码与普通代码。
使用方式如下：

<!-- run -->

```cangjie
@When[test]
@Test
class Tests {
    @TestCase
    public func case1(): Unit {
        @Expect("run", foo())
    }
}

func foo() {
    "run"
}

@When[!test]
main () {
    println(foo())
}
```

使用 `--test` 编译执行得到的测试结果，不使用 `--test` 也可正常完成编译运行得到 `run` 的信息。

## 自定义编译条件变量

仓颉允许开发者自定义编译条件变量和取值，自定义的条件变量必须是一个合法的标识符且不允许和内置条件变量同名，其值是一个字符串字面量。自定义条件支持 `==` 和 `!=` 两种运算符。和内置条件变量不同点在于自定义的条件需要开发者在编译时通过 `--cfg` 编译选项或者在配置文件 `cfg.toml` 中定义。

### 配置自定义条件变量

配置自定义条件变量的方式有两种：在编译选项中直接配置键值对或在配置文件配置键值对。

开发者可以使用 `--cfg <value>` 以键值对的形式向编译器传递自定义编译条件变量或者指定配置文件 `cfg.toml` 的搜索路径。

- 选项值需要使用双引号括起来。

- 若选项值中包含 `=` 则会按照键值对的形式直接进行配置（若路径中包含 `=` 则需要通过 `\` 转义），多个键值对可以使用逗号 `,` 分隔。如：

    ```shell
    $ cjc --cfg "feature = lion, platform = dsp" source.cj
    ```

- 允许多次使用 `--cfg` 编译选项配置，例如：

    ```shell
    $ cjc --cfg "feature = lion" --cfg "platform = dsp" source.cj
    ```

- 不允许多次定义同一个条件变量，例如：

    ```shell
    $ cjc --cfg "feature = lion" --cfg "feature = meta" source.cj
    ```

    ```shell
    $ cjc --cfg "feature = lion, feature = meta" source.cj
    ```

    上述两条编译指令都会报错。

- 若选项值中不包含 `=` 或存在通过 `\` 转义的 `=` 则将选项值作为配置文件 `cfg.toml` 的搜索路径传递给编译器，例如：

    ```shell
    $ cjc --cfg "./cfg" source.cj
    ```

    若 `./cfg` 目录下存在 `cfg.toml`，则编译器会在编译时自动获取 `./cfg/cfg.toml` 中配置的自定义编译条件。`cfg.toml` 文件中应采用键值对的方式配置自定义条件变量，每个键值对独占一行，键名是一个合法的仓颉普通标识符，键值是一个双引号括起来的字符串，字符串不支持转义。`cfg.toml` 文件中也支持全行注释和行末注释，例如：

    ```toml
    feature = "lion"
    platform = "dsp"
    # 全行注释
    feature = "meta" # 行末注释
    ```

- 多次使用 `--cfg` 配置 `cfg.toml` 文件的搜索路径时，按照传入的顺序依次搜索`cfg.toml` 文件，若在所有传入的搜索路径下都没有找到 `cfg.toml` 文件，则在默认路径下搜索配置文件 `cfg.toml`。

- 多次使用 `--cfg` 编译选项进行配置时，若某次以键值对的形式直接进行配置，则会忽略配置文件 `cfg.toml` 中的配置。

- 若未使用 `--cfg` 编译选项，编译器会在默认路径（通过 `--package` 或 `-p` 指定的 `package` 目录或 `cjc` 执行目录）下搜索配置文件 `cfg.toml`。

## 多条件编译

仓颉条件编译允许开发者自由组合多个条件编译选项。支持逻辑运算符组合多个条件，支持括号运算符明确优先级。

使用方式示例一：

<!-- verify -->
<!-- cfg="--cfg='feature=lion'" -->

```cangjie
//source.cj
@When[(test || feature == "lion") && !debug]
func fee() {
    println("feature lion")
}
main() {
    fee()
}
```

使用如下编译命令编译运行上段代码：

```shell
$ cjc --cfg="feature=lion" source.cj -o runner.out
```

会得到输出结果如下：

```text
feature lion
```

使用方式示例二：

仓颉交叉编译至目标平台 `aarch64-linux-android31`，条件变量设置如下面代码所示，若需交叉编译至其他平台，请参考 [目标平台和条件编译映射表](#目标平台和条件编译映射表) 配置相应的条件编译选项。

<!-- run -->

```cangjie
@When[os == "Linux" && arch == "aarch64" && env == "android"]
func foo() {
    "target aarch64-linux-android31 run"
}

main() {
    println(foo())
}
```

## 附录

### 目标平台和条件编译映射表

仓颉交叉编译支持的目标平台由内置条件变量 `os`、 `arch`、 `env` 共同确定，三者与目标平台的对应关系如下表所示：

| 目标平台                      | arch      | os        | env         |
| ----------------------------- | --------- | --------- | ----------- |
| x86_64-windows-gnu            | "x86_64"  | "Windows" | "gnu"       |
| x86_64-linux-gnu              | "x86_64"  | "Linux"   | "gnu"       |
| x86_64-apple-darwin           | "x86_64"  | "macOS"   | ""            |
| x86_64-linux-ohos             | "x86_64"  | "Linux"   | "ohos"      |
| x86_64-w64-mingw32            | "x86_64"  | "Windows" | "gnu"       |
| x86_64-linux-android[26+]<sup>[android target]</sup>     | "x86_64"  | "Linux"   | "android"   |
| aarch64-linux-gnu             | "aarch64" | "Linux"   | "gnu"       |
| aarch64-linux-android[26+]<sup>[android target]</sup>    | "aarch64" | "Linux"   | "android"   |
| aarch64-apple-darwin          | "aarch64" | "macOS"   | ""            |
| aarch64-linux-ohos            | "aarch64" | "Linux"   | "ohos"      |
| arm64-apple-ios[11+]<sup>[ios target]</sup>           | "aarch64" | "iOS"     |    ""         |
| arm64-apple-ios[11+]-simulator<sup>[ios target]</sup> | "aarch64" | "iOS"     | "simulator" |

<sup>[android target]</sup> x86_64-linux-android[26+] 中 android 后缀的数字用于指定 Android API Level。未指定数字时，默认 API Level 为 26；指定数字（如 x86_64-linux-android33）表示 Android API Level 为 33，指定的数字应大于等于 26。
<sup>[ios target]</sup> arm64-apple-ios[11+] 中 ios 后缀的数字用于指定 ios 版本信息。未指定数字时，默认为 11；指定数字（如 arm64-apple-ios26）表示 ios 版本为 26，指定的数字应大于等于 11。
