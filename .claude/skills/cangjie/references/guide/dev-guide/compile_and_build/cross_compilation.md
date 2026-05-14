# 交叉编译

开发者编码的仓颉程序通过交叉编译将其运行于不同体系架构平台上，仓颉支持交叉编译的场景：

- `Linux/macOS` 平台到 `android-aarch64` 平台的交叉编译构建。
- `Linux/macOS` 平台到 `android-x86_64` 平台的交叉编译构建。
- `Linux/macOS` 平台到 `ios-aarch64` 平台的交叉编译构建。
- `Linux/macOS` 平台到 `ios-simulator-aarch64` 平台的交叉编译构建。

仓颉编程语言现已支持交叉编译至 `Android API 31` 和 `iOS`，方便开发者在不同平台上进行应用开发。

## 仓颉交叉编译至 Android API 31

### 安装包下载

开发者可以使用支持交叉编译的仓颉安装包对特定平台（`android-aarch64`、`android-x86_64`）进行交叉编译。仓颉提供了部分支持交叉编译平台的安装包。

**支持交叉编译至 Android API 31 的仓颉安装包：**

- `cangjie-sdk-linux-x64-android.x.y.z.tar.gz`
- `cangjie-sdk-windows-x64-android.x.y.z.zip`
- `cangjie-sdk-windows-x64-android.x.y.z.exe`
- `cangjie-sdk-mac-x64-android.x.y.z.tar.gz`
- `cangjie-sdk-mac-aarch64-android.x.y.z.tar.gz`

例如：若需要在 `linux x64` 平台交叉编译至 `Android API 31`，可以下载安装 `cangjie-sdk-linux-x64-android.x.y.z.tar.gz` 仓颉软件包。

除了支持交叉编译的仓颉软件包，还需要下载支持 `Android API 31` 的 `Android NDK`，请从 `Android` 官方网站下载最新 `NDK` 软件包。

### 编译

仓颉交叉编译至 `Android API 31` 会需要以下两个依赖目录：

1. `sysroot` 目录，该文件由 `Android NDK` 提供，通常位于 `<ndk-path>/toolchains/llvm/prebuilt/<platform>/sysroot` 。

2. `libclang_rt.builtins-aarch64-android.a` 所在的目录，该文件由 `Android NDK` 提供，通常位于 `<ndk-path>/toolchains/llvm/prebuilt/<platform>/lib64/clang/<version>/lib/linux` 。

使用 `cjc` 交叉编译仓颉代码时需要额外指定以下选项（`<>` 部分需要替换为实际目录）：

- `--target=aarch64-linux-android31` 指定目标平台 `Android API 31` 进行交叉编译
- `--sysroot=<sysroot-path>` 指定工具链的根目录路径 `<sysroot-path>`
- `-L<lib-path>` 指定 `libclang_rt.builtins-aarch64-android.a` 所在目录 `<lib-path>`

例如执行命令：

```shell
$ cjc main.cj --target=aarch64-linux-android31 --sysroot /opt/buildtools/android_ndk-r25b/toolchains/llvm/prebuilt/linux-x86_64/sysroot -L /opt/buildtools/android_ndk-r25b/toolchains/llvm/prebuilt/linux-x86_64/lib64/clang/14.0.6/lib/linux
```

`main.cj` 是交叉编译的仓颉代码， `aarch64-linux-android31` 为目标平台，`/opt/buildtools/android_ndk-r25b/toolchains/llvm/prebuilt/linux-x86_64/sysroot` 为工具链的根目录路径 `<sysroot-path>`， `/opt/buildtools/android_ndk-r25b/toolchains/llvm/prebuilt/linux-x86_64/lib64/clang/14.0.6/lib/linux` 为`libclang_rt.builtins-aarch64-android.a` 所在目录 `<lib-path>`。

### 部署和运行

编译完成后需要将以下文件推送到 `Android` 设备：

- 可执行程序以及其依赖的所有动态库： 例如 `main` 和其依赖的 `.so` 动态库文件
- 仓颉运行时依赖：`$CANGJIE_HOME/runtime/lib/linux_android31_aarch64_cjnative/*.so`

通过使用 `Android` 调试桥 `adb` 工具可以将可执行程序以及仓颉库推送至设备，示例如下：

```shell
$ adb push ./main /data/local/tmp/
$ adb push $CANGJIE_HOME/runtime/lib/linux_android31_aarch64_cjnative/* /data/local/tmp/
```

`adb` 工具的详细使用方法请参考 `Android` 官网的 `Android` 调试桥（`adb`）相关说明。

`.so` 动态库文件可以直接部署到系统目录，若部署在其他非常规目录，则需要在运行前将目录添加到 `LD_LIBRARY_PATH` 环境变量中。

运行仓颉程序 `main`，示例如下：

```shell
$ adb shell "chmod +x /data/local/tmp/main"
$ adb shell "LD_LIBRARY_PATH=/data/local/tmp /data/local/tmp/main"
```

## 仓颉交叉编译至 iOS

### 安装包下载

支持交叉编译至 `iOS` 的仓颉安装包为：`cangjie-sdk-mac-aarch64-ios.x.y.z.tar.gz`
仓颉运行时以及标准库默认支持运行于 `iOS 11` 及以上系统（对于例外场景，请见《仓颉编程语言库 API》手册）。

除了支持交叉编译的仓颉软件包，还需要下载 `Xcode`。下载完成后，请在 Xcode 中安装 iOS 开发组件。具体步骤可参考 Xcode 手册中的 "Downloading and installing additional Xcode components" 章节。

### 编译

当前仓颉交叉编译至 `iOS` 仅支持编译静态库，交叉编译仓颉代码至 `iOS` 设备时需要额外指定以下选项：

- `--target=aarch64-apple-ios` 指定目标平台 `ios` 进行交叉编译
- `--output-type=staticlib`指定输出文件的类型为静态库

当前仓颉支持从 `aarch64` 架构环境交叉编译生成 iOS 模拟器静态库，既适配 `aarch64` 架构模拟器，也可编译至 x86_64 架构模拟器（该架构产物需依赖 Xcode 的 Rosetta 运行）。若需在 iOS 模拟器上运行，需指定以下选项：

- `--target`
  - `--target=aarch64-apple-ios-simulator` 适用于aarch64目标架构
  - `--target=x86_64-apple-ios-simulator` 适用于x86_64目标架构
- `--output-type=staticlib` 指定输出文件的类型为静态库

编译产物需要添加至 `Xcode` 工程中，并通过 `Xcode` 构建 `iOS` 应用。

编译 `main.cj` 生成 `libmain.a` 静态库，示例如下：

```shell
cjc main.cj --output-type=staticlib --target=aarch64-apple-ios17.5 -o libmain.a
```

`main.cj` 是交叉编译的仓颉代码， `aarch64-apple-ios17.5` 为目标平台，`--output-type=staticlib` 指定输出文件的类型为静态库。

除需要将仓颉代码的编译产物添加到 `Xcode` 工程外，使用 `Xcode` 构建还需要进行以下配置：

1. 根据需要的运行目标（设备或模拟器）选择一个目录：

    - 适用于设备：`$CANGJIE_HOME/lib/ios_aarch64_cjnative`

    - 适用于模拟器：`$CANGJIE_HOME/lib/ios_simulator_aarch64_cjnative`

   将对应目录下的所有 `.a` 文件添加至 `Xcode` 工程中。

2. 在 `Xcode` 项目中配置 `Build Settings > Other Linker Flags` 字段，设置为以下值：

    - `$CANGJIE_HOME/lib/ios_aarch64_cjnative/section.o`

    - `$CANGJIE_HOME/lib/ios_aarch64_cjnative/cjstart.o`

    - `-lc++`

   值得注意的是，必须按照以上列表顺序添加链接选项。`$CANGJIE_HOME` 需要替换为实际的仓颉按照目录。若运行目标是模拟器，请将 `ios_aarch64_cjnative` 替换为 `ios_simulator_aarch64_cjnative` 。此外，若使用 Xcode 15，还需在 `Build Settings > Other Linker Flags` 中额外添加 `-Wl,-ld_classic` 或 `-Wl,-no_compact_unwind` ，否则在某些场景下，Xcode 15 链接器可能会报错：`Assertion failed: (false && "compact unwind compressed function offset doesn't fit in 24 bits")` 。

3. 在 `Xcode` 项目中配置 `Build Settings > Dead Code Stripping` 字段，设置为 `No`。

配置完毕后通过 `Xcode` 直接构建项目即可。

### 部署和运行

通过 `Xcode` 构建并部署至真机或模拟器运行，具体步骤可参考 `Xcode` 手册的 "Build and running an app" 章节。
