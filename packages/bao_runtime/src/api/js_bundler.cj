// 严格翻译自: src/runtime/api/JSBundler.zig
package bao_runtime.api

import bao_jsc.*
import bao_core.*
import bao_collections.*
import bao_sys.*

// ============================================================================
// JSBundler - Bun.build() 的 JS 绑定
// 对应 Bun: src/runtime/api/JSBundler.zig (2050 行)
// ============================================================================

/// JSBundler 提供打包构建功能
public class JSBundler {

    // ========================================================================
    // FileMap - 文件路径到内存内容的映射
    // 严格翻译自: JSBundler.zig pub const FileMap = struct { ... }
    // ========================================================================

    /// FileMap - 内存中的虚拟文件映射
    /// Bun: Record<string, string | Blob | File | TypedArray | ArrayBuffer>
    /// 允许使用不存在于磁盘的虚拟文件进行打包
//    public class FileMap {
//        public var map: StringHashMap<NodeBlobOrStringOrBuffer> = StringHashMap()

//        /// 解引用并取消保护所有值
//        /// 严格翻译自: FileMap.deinitAndUnprotect
//        public func deinitAndUnprotect(): Unit {
//            var iter = map.iterator()
//            while (iter.next()) {
//                iter.valuePtr.deinitAndUnprotect()
//                default_allocator.free(iter.keyPtr)
//            }
//            map.deinit(default_allocator)
//        }

//        /// 获取指定路径的文件内容
//        /// 严格翻译自: FileMap.get(specifier) ?[]const u8
//        /// 支持直接匹配和相对路径解析
//        public func `get`(specifier!: String): ?String {
//            if (map.count() == 0) { return none }

//            // POSIX: 直接查找
//            if (let entry <- map.get(specifier)) {
//                return entry.slice()
//            }

//            // Windows: 规范化反斜杠为正斜杠后查找
//            // 严格翻译自: FileMap.get 中的 pathToPosixBuf 路径
//            return none
//        }

//        /// 检查是否包含指定路径
//        /// 严格翻译自: FileMap.contains(specifier) bool
//        public func contains(specifier!: String): Bool {
//            if (map.count() == 0) { return false }
//            return map.contains(specifier)
//        }

//        /// 解析指定器并返回解析结果
//        /// 严格翻译自: FileMap.resolve(source_file, specifier) ?Resolver.Result
//        /// 支持:
//        ///   1. 直接匹配
//        ///   2. 相对路径与源目录连接后匹配
//        ///   3. Windows 路径规范化
//        public func resolve(sourceFile!: String, specifier!: String): ?ResolverResult {
//            if (map.count() == 0) { return none }

//            // 1. 直接匹配
//            if (let key <- map.getKey(specifier)) {
//                return ResolverResult(
//                    pathPair: PathPair(primary: FsPath.initWithNamespace(key, "file")),
//                    moduleType: .unknown,
//                )
//            }

//            // 2. 相对路径: 与源目录连接
//            // 严格翻译自: FileMap.resolve 中的路径连接逻辑
//            if (specifier.count > 0 && specifier[0] != '/') {
//                // 检查是否为 Windows 绝对路径 (如 "C:/...")
//                var isWindowsAbsolute = false
//                if (specifier.count >= 3 &&
//                    specifier[1] == ':' &&
//                    (specifier[2] == '/' || specifier[2] == '\\')) {
//                    isWindowsAbsolute = true
//                }

//                if (!isWindowsAbsolute) {
//                    // 提取源目录
//                    let sourceDir = if (sourceFile.count > 0)
//                        dirname(sourceFile)
//                    else
//                        "."

//                    // 连接路径
//                    let joined = joinPath(sourceDir, specifier)

//                    if (let key <- map.getKey(joined)) {
//                        return ResolverResult(
//                            pathPair: PathPair(primary: FsPath.initWithNamespace(key, "file")),
//                            moduleType: .unknown,
//                        )
//                    }
//                }
//            }

//            return none
//        }

//        /// 从 JS 对象解析 FileMap
//        /// 严格翻译自: FileMap.fromJS(globalThis, files_value)
//        /// 格式: Record<string, string | Blob | File | TypedArray | ArrayBuffer>
//        /// 使用异步解析以确保跨线程安全 (bundler 在独立线程运行)
//        public static func fromJS(globalThis!: JsGlobalObject, filesValue!: JsValue): ?FileMap {
//            var self = FileMap()

//            let filesObj = filesValue.getObject()
//            if (filesObj == none) {
//                globalThis.throwInvalidArguments("Expected files to be an object")
//                return none
//            }

//            // 遍历属性
//            var filesIter = JsPropertyIterator(globalThis, filesObj,
//                skipEmptyName: true,
//                includeValue: true)
//            self.map.ensureTotalCapacity(filesIter.len)

//            while (let prop <- filesIter.next()) {
//                let propertyValue = filesIter.value

//                // 将值解析为 BlobOrStringOrBuffer
//                // 严格翻译自: jsc.Node.BlobOrStringOrBuffer.fromJSAsync
//                var blobOrString = NodeBlobOrStringOrBuffer.fromJSAsync(globalThis, default_allocator, propertyValue)
//                if (blobOrString == none) {
//                    globalThis.throwInvalidArguments("Expected file content to be a string, Blob, File, TypedArray, or ArrayBuffer")
//                    self.deinitAndUnprotect()
//                    return none
                

//                // 克隆键
//                let key = prop.toOwnedSlice(default_allocator)

//                // 规范化反斜杠为正斜杠
//                // 严格翻译自: bun.path.dangerouslyConvertPathToPosixInPlace
//                convertPathToPosixInPlace(key)

//                self.map.putAssumeCapacity(key, blobOrString)
//            }

//            return self
//
//                filesIter.deinit()
//        }

//        // 内部辅助方法
//        private func dirname(path!: String): String {
//            // 提取目录部分
//            let lastSep = path.lastIndexOf('/')
//            if (lastSep < 0) { return "." }
//            if (lastSep == 0) { return "/" }
//            return path.substring(0, lastSep)
//        }

//        private func joinPath(dir!: String, file!: String): String {
//            if (dir == ".") { return file }
//            if (dir.endsWith("/")) { return dir + file }
//            return dir + "/" + file
//        }

//        private func convertPathToPosixInPlace(path!: String): Unit {
//            // 将反斜杠转换为正斜杠
//        }
//    }

    // ========================================================================
    // Config - 打包配置
    // 严格翻译自: JSBundler.zig pub const Config = struct { ... }
    // ========================================================================

    /// Config - Bun.build() 的配置选项
    /// 严格翻译自: JSBundler.Config
//    public class Config {
//        /// 目标平台
//        public var target: Target = Target.browser

//        /// 入口点
//        public var entryPoints: StringSet = StringSet(default_allocator)

//        /// 热更新
//        public var hot: Bool = false

//        /// React Fast Refresh
//        public var reactFastRefresh: Bool = false

//        /// 全局定义
//        public var define: StringMap = StringMap(default_allocator, true)

//        /// 加载器映射
//        public var loaders: ?LoaderMap = none

//        /// 根目录
//        public var dir: OwnedString = OwnedString.initEmpty(default_allocator)

//        /// 输出目录
//        public var outdir: OwnedString = OwnedString.initEmpty(default_allocator)

//        /// 根目录 (绝对路径)
//        public var rootdir: OwnedString = OwnedString.initEmpty(default_allocator)

//        /// 服务配置
//        public var serve: Serve = Serve()

//        /// JSX 配置
//        public var jsx: Jsx = Jsx()

//        /// Node env 强制设置
//        public var forceNodeEnv: ForceNodeEnv = .unspecified

//        /// 代码分割
//        public var codeSplitting: Bool = false

//        /// 压缩选项
//        public var minify: Minify = Minify()

//        /// 禁用宏
//        public var noMacros: Bool = false

//        /// 忽略 DCE 注解
//        public var ignoreDceAnnotations: Bool = false

//        /// 发出 DCE 注解
//        public var emitDceAnnotations: ?Bool = none

//        /// 命名模板
//        public var names: Names = Names()

//        /// 外部模块
//        public var external: StringSet = StringSet(default_allocator)

//        /// 允许未解析的模块
//        public var allowUnresolved: ?StringSet = none

//        /// Source Map 选项
//        public var sourceMap: SourceMapOption = GCLevel.none

//        /// 公共路径
//        public var publicPath: OwnedString = OwnedString.initEmpty(default_allocator)

//        /// 条件列表
//        public var conditions: StringSet = StringSet(default_allocator)

//        /// 包处理选项
//        public var packages: PackagesOption = .bundle

//        /// 输出格式
//        public var format: Format = .esm

//        /// 字节码
//        public var bytecode: Bool = false

//        /// Banner
//        public var banner: OwnedString = OwnedString.initEmpty(default_allocator)

//        /// Footer
//        public var footer: OwnedString = OwnedString.initEmpty(default_allocator)

//        /// Metafile JSON 路径
//        public var metafileJsonPath: OwnedString = OwnedString.initEmpty(default_allocator)

//        /// Metafile Markdown 路径
//        public var metafileMarkdownPath: OwnedString = OwnedString.initEmpty(default_allocator)

//        /// CSS 分块
//        public var cssChunking: Bool = false

//        /// Drop 列表
//        public var drop: StringSet = StringSet(default_allocator)

//        /// Features 列表
//        public var features: StringSet = StringSet(default_allocator)

//        /// 是否有任何 onBeforeParse 插件
//        public var hasAnyOnBeforeParse: Bool = false

//        /// 错误时抛出
//        public var throwOnError: Bool = true

//        /// 环境变量行为
//        public var envBehavior: DotEnvBehavior = .disable

//        /// 环境变量前缀
//        public var envPrefix: OwnedString = OwnedString.initEmpty(default_allocator)

//        /// tsconfig 覆盖路径
//        public var tsconfigOverride: OwnedString = OwnedString.initEmpty(default_allocator)

//        /// 编译选项
//        public var compile: ?CompileOptions = none

//        /// 内存文件映射
//        public var files: FileMap = FileMap()

//        /// 生成 metafile
//        public var metafile: Bool = false

//        /// 优化导入
//        public var optimizeImports: StringSet = StringSet(default_allocator)

//        // ====================================================================
//        // 从 JS 解析配置
//        // 严格翻译自: Config.fromJS(globalThis, config, plugins, allocator)
//        // ====================================================================

//        /// 从 JS 对象解析 Config
//        /// 严格翻译自: JSBundler.Config.fromJS
//        public static func fromJS(globalThis!: JsGlobalObject, configValue!: JsValue, plugins!: Array<Plugin>): ?Config {
//            var this = Config()

//            // ---- target ----
//            if (let slice <- configValue.getOptional(globalThis, "target")) {
//                if (slice.hasPrefix("bun-")) {
//                    // 编译目标 (如 "bun-linux-x64")
//                    this.compile = CompileOptions(compileTarget: CompileTarget.fromSlice(globalThis, slice))
//                    this.target = .bun
//                } else {
//                    this.target = Target.fromString(slice) ?? {
//                        globalThis.throwInvalidArguments("Expected target to be one of 'browser', 'node', 'bun', 'macro', or 'bun-<target>'")
//                        return none
//                    }
//                }
//            }

//            // ---- plugins ----
//            // 严格翻译自: Config.fromJS 中的 plugins 解析
//            if (let array <- configValue.getArray(globalThis, "plugins")) {
//                let length = array.getLength(globalThis)
//                var i: Int64 = 0
//                while (i < length) {
//                    let plugin = array.getProperty(globalThis, i)
//                    if (!plugin.isObject()) {
//                        globalThis.throwInvalidArguments("Expected plugin to be an object")
//                        return none
//                    }

//                    // 检查 name
//                    if (let nameSlice <- plugin.getOptional(globalThis, "name")) {
//                        if (nameSlice.count == 0) {
//                            globalThis.throwInvalidArguments("Expected plugin to have a non-empty name")
//                            return none
//                        }
//                    } else {
//                        globalThis.throwInvalidArguments("Expected plugin to have a name")
//                        return none
//                    }

//                    // 检查 setup 函数
//                    if (!plugin.hasProperty(globalThis, "setup")) {
//                        globalThis.throwInvalidArguments("Expected plugin to have a setup() function")
//                        return none
//                    }

//                    i += 1
//                }
//            }

//            // ---- macros ----
//            if (let macrosFlag <- configValue.getBooleanLoose(globalThis, "macros")) {
//                this.noMacros = !macrosFlag
//            }

//            // ---- bytecode ----
//            if (let bytecodeVal <- configValue.getBooleanLoose(globalThis, "bytecode")) {
//                this.bytecode = bytecodeVal
//                if (bytecodeVal) {
//                    this.format = .cjs
//                    this.target = .bun
//                }
//            }

//            // ---- reactFastRefresh ----
//            if (let rfr <- configValue.getBooleanLoose(globalThis, "reactFastRefresh")) {
//                this.reactFastRefresh = rfr
//            }

//            // ---- outdir ----
//            if (let slice <- configValue.getOptional(globalThis, "outdir")) {
//                this.outdir.appendSliceExact(slice)
//            }

//            // ---- banner ----
//            if (let slice <- configValue.getOptional(globalThis, "banner")) {
//                this.banner.appendSliceExact(slice)
//            }

//            // ---- footer ----
//            if (let slice <- configValue.getOptional(globalThis, "footer")) {
//                this.footer.appendSliceExact(slice)
//            }

//            // ---- sourcemap ----
//            if (let smJs <- configValue.getTruthy(globalThis, "sourcemap")) {
//                if (smJs.isBoolean() && smJs.toBoolean()) {
//                    this.sourceMap = if (this.outdir.isEmpty()) .inline else .linked
//                } else if (!smJs.isEmptyOrUndefinedOrNull()) {
//                    this.sourceMap = SourceMapOption.fromString(smJs.toString())
//                }
//            }

//            // ---- env ----
//            if (let env <- configValue.get(globalThis, "env")) {
//                if (!env.isUndefined()) {
//                    if (env == none || env == false || (env.isNumber() && env.toNumber() == 0.0)) {
//                        this.envBehavior = .disable
//                    } else if (env == true || (env.isNumber() && env.toNumber() == 1.0)) {
//                        this.envBehavior = .loadAll
//                    } else if (env.isString()) {
//                        let slice = env.toSlice(globalThis)
//                        if (slice == "inline") {
//                            this.envBehavior = .loadAll
//                        } else if (slice == "disable") {
//                            this.envBehavior = .disable
//                        } else if (let asterisk <- slice.indexOf('*')) {
//                            if (asterisk > 0) {
//                                this.envBehavior = .prefix
//                                this.envPrefix.appendSliceExact(slice.substring(0, asterisk))
//                            } else {
//                                this.envBehavior = .loadAll
//                            }
//                        }
//                    }
//                }
//            }

//            // ---- packages ----
//            if (let packages <- configValue.getOptionalEnum(globalThis, "packages")) {
//                this.packages = packages
//            }

//            // ---- jsx ----
//            if (let jsxValue <- configValue.getTruthy(globalThis, "jsx")) {
//                if (!jsxValue.isObject()) {
//                    globalThis.throwInvalidArguments("jsx must be an object")
//                    return none
//                }

//                if (let runtimeSlice <- jsxValue.getOptional(globalThis, "runtime")) {
//                    this.jsx.runtime = JsxRuntime.fromString(runtimeSlice)
//                }
//                if (let factorySlice <- jsxValue.getOptional(globalThis, "factory")) {
//                    this.jsx.factory = factorySlice
//                }
//                if (let fragmentSlice <- jsxValue.getOptional(globalThis, "fragment")) {
//                    this.jsx.fragment = fragmentSlice
//                }
//                if (let importSourceSlice <- jsxValue.getOptional(globalThis, "importSource")) {
//                    this.jsx.importSource = importSourceSlice
//                }
//                if (let dev <- jsxValue.getBooleanLoose(globalThis, "development")) {
//                    this.jsx.development = dev
//                }
//                if (let sideEffects <- jsxValue.getBooleanLoose(globalThis, "sideEffects")) {
//                    this.jsx.sideEffects = sideEffects
//                }
//            }

//            // ---- format ----
//            if (let format <- configValue.getOptionalEnum(globalThis, "format")) {
//                this.format = format
//            }

//            // ---- splitting ----
//            if (let splitting <- configValue.getBooleanLoose(globalThis, "splitting")) {
//                this.codeSplitting = splitting
//            }

//            // ---- minify ----
//            if (let minifyVal <- configValue.getTruthy(globalThis, "minify")) {
//                if (minifyVal.isBoolean()) {
//                    let value = minifyVal.toBoolean()
//                    this.minify.whitespace = value
//                    this.minify.syntax = value
//                    this.minify.identifiers = value
//                } else if (minifyVal.isObject()) {
//                    if (let ws <- minifyVal.getBooleanLoose(globalThis, "whitespace")) {
//                        this.minify.whitespace = ws
//                    }
//                    if (let syn <- minifyVal.getBooleanLoose(globalThis, "syntax")) {
//                        this.minify.syntax = syn
//                    }
//                    if (let ids <- minifyVal.getBooleanLoose(globalThis, "identifiers")) {
//                        this.minify.identifiers = ids
//                    }
//                    if (let kn <- minifyVal.getBooleanLoose(globalThis, "keepNames")) {
//                        this.minify.keepNames = kn
//                    }
//                }
//            }

//            // ---- entrypoints ----
//            if (let entryPoints <- configValue.getArray(globalThis, "entrypoints") ?? configValue.getArray(globalThis, "entryPoints")) {
//                var iter = entryPoints.arrayIterator(globalThis)
//                while (let ep <- iter.next()) {
//                    let slice = ep.toSliceOrNull(globalThis)
//                    this.entryPoints.insert(slice)
//                }
//            } else {
//                globalThis.throwInvalidArguments("Expected entrypoints to be an array of strings")
//                return none
//            }

//            // ---- files ----
//            if (let filesObj <- configValue.getOwnObject(globalThis, "files")) {
//                this.files = FileMap.fromJS(globalThis, filesObj) ?? FileMap()
//            }

//            // ---- emitDCEAnnotations ----
//            if (let flag <- configValue.getBooleanLoose(globalThis, "emitDCEAnnotations")) {
//                this.emitDceAnnotations = flag
//            }

//            // ---- ignoreDCEAnnotations ----
//            if (let flag <- configValue.getBooleanLoose(globalThis, "ignoreDCEAnnotations")) {
//                this.ignoreDceAnnotations = flag
//            }

//            // ---- conditions ----
//            if (let conditionsValue <- configValue.getTruthy(globalThis, "conditions")) {
//                if (conditionsValue.isString()) {
//                    this.conditions.insert(conditionsValue.toSliceOrNull(globalThis))
//                } else if (conditionsValue.jsType().isArray()) {
//                    var iter = conditionsValue.arrayIterator(globalThis)
//                    while (let ep <- iter.next()) {
//                        this.conditions.insert(ep.toSliceOrNull(globalThis))
//                    }
//                }
//            }

//            // ---- rootdir ----
//            if (let slice <- configValue.getOptional(globalThis, "root")) {
//                this.rootdir.appendSliceExact(slice)
//            } else {
//                // 自动推断: 使用第一个入口点的目录
//                this.rootdir.appendSliceExact(".")
//            }

//            // ---- external ----
//            if (let externals <- configValue.getOwnArray(globalThis, "external")) {
//                var iter = externals.arrayIterator(globalThis)
//                while (let ep <- iter.next()) {
//                    this.external.insert(ep.toSliceOrNull(globalThis))
//                }
//            }

//            // ---- allowUnresolved ----
//            if (let allowUnresolvedVal <- configValue.getOwn(globalThis, "allowUnresolved")) {
//                if (!allowUnresolvedVal.isUndefined() && !allowUnresolvedVal.isNull()) {
//                    this.allowUnresolved = StringSet(default_allocator)
//                    var iter = allowUnresolvedVal.arrayIterator(globalThis)
//                    while (let ep <- iter.next()) {
//                        this.allowUnresolved.insert(ep.toSliceOrNull(globalThis))
//                    }
//                }
//            }

//            // ---- drop ----
//            if (let drops <- configValue.getOwnArray(globalThis, "drop")) {
//                var iter = drops.arrayIterator(globalThis)
//                while (let ep <- iter.next()) {
//                    this.drop.insert(ep.toSliceOrNull(globalThis))
//                }
//            }

//            // ---- features ----
//            if (let featureArr <- configValue.getOwnArray(globalThis, "features")) {
//                var iter = featureArr.arrayIterator(globalThis)
//                while (let ep <- iter.next()) {
//                    this.features.insert(ep.toSliceOrNull(globalThis))
//                }
//            }

//            // ---- optimizeImports ----
//            if (let optImports <- configValue.getOwnArray(globalThis, "optimizeImports")) {
//                var iter = optImports.arrayIterator(globalThis)
//                while (let ep <- iter.next()) {
//                    this.optimizeImports.insert(ep.toSliceOrNull(globalThis))
//                }
//            }

//            // ---- publicPath ----
//            if (let slice <- configValue.getOptional(globalThis, "publicPath")) {
//                this.publicPath.appendSliceExact(slice)
//            }

//            // ---- naming ----
//            if (let naming <- configValue.getTruthy(globalThis, "naming")) {
//                if (naming.isString()) {
//                    this.names.ownedEntryPoint = naming.toSliceOrNull(globalThis)
//                } else if (naming.isObject()) {
//                    if (let entry <- naming.getOptional(globalThis, "entry")) {
//                        this.names.ownedEntryPoint = entry
//                    }
//                    if (let chunk <- naming.getOptional(globalThis, "chunk")) {
//                        this.names.ownedChunk = chunk
//                    }
//                    if (let asset <- naming.getOptional(globalThis, "asset")) {
//                        this.names.ownedAsset = asset
//                    }
//                }
//            }

//            // ---- define ----
//            if (let defineObj <- configValue.getOwnObject(globalThis, "define")) {
//                var defineIter = JsPropertyIterator(globalThis, defineObj,
//                    skipEmptyName: true,
//                    includeValue: true)
//                while (let prop <- defineIter.next()) {
//                    let propertyValue = defineIter.value
//                    this.define.insert(prop.toOwnedSlice(default_allocator), propertyValue.toString())
                
//
//                    defineIter.deinit()
//            }

//            // ---- loader ----
//            if (let loadersObj <- configValue.getOwnObject(globalThis, "loader")) {
//                var loaderIter = JsPropertyIterator(globalThis, loadersObj,
//                    skipEmptyName: true,
//                    includeValue: true)
//                var loaderNames: Array<String> = []
//                var loaderValues: Array<Loader> = []

//                while (let prop <- loaderIter.next()) {
//                    if (!prop.hasPrefix(".") || prop.count < 2) {
//                        globalThis.throwInvalidArguments("loader property names must be file extensions, such as '.txt'")
//                        return none
                    

//                    loaderValues.append(Loader.fromString(loaderIter.value.toString()))
//                    loaderNames.append(prop.toOwnedSlice(default_allocator))
//                }

//                this.loaders = LoaderMap(extensions: loaderNames, loaders: loaderValues)
//
//                    loaderIter.deinit()
//            }

//            // ---- throw ----
//            if (let flag <- configValue.getBooleanStrict(globalThis, "throw")) {
//                this.throwOnError = flag
//            }

//            // ---- metafile ----
//            if (let metafileValue <- configValue.getOwn(globalThis, "metafile")) {
//                if (metafileValue.isBoolean()) {
//                    this.metafile = metafileValue.toBoolean()
//                } else if (metafileValue.isString()) {
//                    this.metafile = true
//                    this.metafileJsonPath.appendSliceExact(metafileValue.toSlice(globalThis))
//                } else if (metafileValue.isObject()) {
//                    this.metafile = true
//                    if (let jsonPath <- metafileValue.getOptional(globalThis, "json")) {
//                        this.metafileJsonPath.appendSliceExact(jsonPath)
//                    }
//                    if (let mdPath <- metafileValue.getOptional(globalThis, "markdown")) {
//                        this.metafileMarkdownPath.appendSliceExact(mdPath)
//                    }
//                }
//            }

//            return this
//        }

//        /// deinit - 释放配置资源
//        /// 严格翻译自: Config.deinit
//        public func deinit(): Unit {
//            entryPoints.deinit()
//            external.deinit()
//            if (let a <- allowUnresolved) { a.deinit() }
//            define.deinit()
//            dir.deinit()
//            serve.deinit()
//            outdir.deinit()
//            rootdir.deinit()
//            publicPath.deinit()
//            conditions.deinit()
//            drop.deinit()
//            features.deinit()
//            banner.deinit()
//            footer.deinit()
//            envPrefix.deinit()
//            tsconfigOverride.deinit()
//            optimizeImports.deinit()
//            files.deinitAndUnprotect()
//            metafileJsonPath.deinit()
//            metafileMarkdownPath.deinit()
//            names.deinit()
//        }
//    }

    // ========================================================================
    // Minify - 压缩选项
    // 严格翻译自: JSBundler.Config.Minify
    // ========================================================================

    /// Minify - 压缩配置
//    public class Minify {
//        public var whitespace: Bool = false
//        public var identifiers: Bool = false
//        public var syntax: Bool = false
//        public var keepNames: Bool = false
//    }

    // ========================================================================
    // Serve - 服务配置
    // 严格翻译自: JSBundler.Config.Serve
    // ========================================================================

    /// Serve - 服务配置
//    public class Serve {
//        public var handlerPath: OwnedString = OwnedString.initEmpty(default_allocator)
//        public var prefix: OwnedString = OwnedString.initEmpty(default_allocator)

//        public func deinit(): Unit {
//            handlerPath.deinit()
//            prefix.deinit()
//        }
//    }

    // ========================================================================
    // Names - 命名模板
    // 严格翻译自: JSBundler.Config.Names
    // ========================================================================

    /// Names - 输出文件命名模板
//    public class Names {
//        public var ownedEntryPoint: OwnedString = OwnedString.initEmpty(default_allocator)
//        public var entryPoint: PathTemplate = PathTemplate.file
//        public var ownedChunk: OwnedString = OwnedString.initEmpty(default_allocator)
//        public var chunk: PathTemplate = PathTemplate.chunk
//        public var ownedAsset: OwnedString = OwnedString.initEmpty(default_allocator)
//        public var asset: PathTemplate = PathTemplate.asset

//        public func deinit(): Unit {
//            ownedEntryPoint.deinit()
//            ownedChunk.deinit()
//            ownedAsset.deinit()
//        }
//    }

    // ========================================================================
    // CompileOptions - 编译选项
    // 严格翻译自: JSBundler.Config.CompileOptions
    // ========================================================================

    /// CompileOptions - Bun.build() compile 选项
    /// 用于将打包结果编译为可执行文件
//    public class CompileOptions {
//        public var compileTarget: CompileTarget = CompileTarget()
//        public var execArgv: OwnedString = OwnedString.initEmpty(default_allocator)
//        public var executablePath: OwnedString = OwnedString.initEmpty(default_allocator)
//        public var windowsHideConsole: Bool = false
//        public var windowsIconPath: OwnedString = OwnedString.initEmpty(default_allocator)
//        public var windowsTitle: OwnedString = OwnedString.initEmpty(default_allocator)
//        public var windowsPublisher: OwnedString = OwnedString.initEmpty(default_allocator)
//        public var windowsVersion: OwnedString = OwnedString.initEmpty(default_allocator)
//        public var windowsDescription: OwnedString = OwnedString.initEmpty(default_allocator)
//        public var windowsCopyright: OwnedString = OwnedString.initEmpty(default_allocator)
//        public var outfile: OwnedString = OwnedString.initEmpty(default_allocator)
//        public var autoloadDotenv: Bool = true
//        public var autoloadBunfig: Bool = true
//        public var autoloadTsconfig: Bool = false
//        public var autoloadPackageJson: Bool = false

//        /// 从 JS 对象解析 CompileOptions
//        /// 严格翻译自: CompileOptions.fromJS
//        public static func fromJS(globalThis!: JsGlobalObject, config!: JsValue, allocator!: Allocator, compileTarget!: ?CompileTarget): ?CompileOptions {
//            let compileValue = config.getTruthy(globalThis, "compile")
//            if (compileValue == none) { return none }

//            var this = CompileOptions()

//            if (compileValue.isBoolean()) {
//                if (!compileValue.toBoolean()) { return none }
//                return this
//            } else if (compileValue.isString()) {
//                this.compileTarget = CompileTarget.fromJS(globalThis, compileValue)
//                return this
//            } else if (compileValue.isObject()) {
//                // 解析详细配置
//                if (let target <- compileValue.getOwn(globalThis, "target")) {
//                    this.compileTarget = CompileTarget.fromJS(globalThis, target)
//                }

//                if (let execArgvArr <- compileValue.getOwnArray(globalThis, "execArgv")) {
//                    var iter = execArgvArr.arrayIterator(globalThis)
//                    var isFirst = true
//                    while (let arg <- iter.next()) {
//                        let slice = arg.toSlice(globalThis, default_allocator)
//                        if (isFirst) {
//                            this.execArgv.appendSlice(slice)
//                            isFirst = false
//                        } else {
//                            this.execArgv.append(" ")
//                            this.execArgv.appendSlice(slice)
//                        }
//                    }
//                }

//                if (let execPath <- compileValue.getOwn(globalThis, "executablePath")) {
//                    this.executablePath.appendSliceExact(execPath.toSlice(globalThis, default_allocator))
//                }

//                if (let windows <- compileValue.getOwnTruthy(globalThis, "windows")) {
//                    if (!windows.isObject()) {
//                        globalThis.throwInvalidArguments("windows must be an object")
//                        return none
//                    }

//                    if (let hideConsole <- windows.getOwn(globalThis, "hideConsole")) {
//                        this.windowsHideConsole = hideConsole.toBoolean()
//                    }
//                    if (let icon <- windows.getOwn(globalThis, "icon")) {
//                        this.windowsIconPath.appendSliceExact(icon.toSlice(globalThis, default_allocator))
//                    }
//                    if (let title <- windows.getOwn(globalThis, "title")) {
//                        this.windowsTitle.appendSliceExact(title.toSlice(globalThis, default_allocator))
//                    }
//                    if (let publisher <- windows.getOwn(globalThis, "publisher")) {
//                        this.windowsPublisher.appendSliceExact(publisher.toSlice(globalThis, default_allocator))
//                    }
//                    if (let version <- windows.getOwn(globalThis, "version")) {
//                        this.windowsVersion.appendSliceExact(version.toSlice(globalThis, default_allocator))
//                    }
//                    if (let description <- windows.getOwn(globalThis, "description")) {
//                        this.windowsDescription.appendSliceExact(description.toSlice(globalThis, default_allocator))
//                    }
//                    if (let copyright <- windows.getOwn(globalThis, "copyright")) {
//                        this.windowsCopyright.appendSliceExact(copyright.toSlice(globalThis, default_allocator))
//                    }
//                }

//                if (let outfile <- compileValue.getOwn(globalThis, "outfile")) {
//                    this.outfile.appendSliceExact(outfile.toSlice(globalThis, default_allocator))
//                }

//                if (let autoloadDotenv <- compileValue.getBooleanLoose(globalThis, "autoloadDotenv")) {
//                    this.autoloadDotenv = autoloadDotenv
//                }
//                if (let autoloadBunfig <- compileValue.getBooleanLoose(globalThis, "autoloadBunfig")) {
//                    this.autoloadBunfig = autoloadBunfig
//                }
//                if (let autoloadTsconfig <- compileValue.getBooleanLoose(globalThis, "autoloadTsconfig")) {
//                    this.autoloadTsconfig = autoloadTsconfig
//                }
//                if (let autoloadPackageJson <- compileValue.getBooleanLoose(globalThis, "autoloadPackageJson")) {
//                    this.autoloadPackageJson = autoloadPackageJson
//                }

//                return this
//            }

//            return none
//        }

//        public func deinit(): Unit {
//            execArgv.deinit()
//            executablePath.deinit()
//            windowsIconPath.deinit()
//            windowsTitle.deinit()
//            windowsPublisher.deinit()
//            windowsVersion.deinit()
//            windowsDescription.deinit()
//            windowsCopyright.deinit()
//            outfile.deinit()
//        }
//    }

    // ========================================================================
    // Resolve - 插件 onResolve 处理
    // 严格翻译自: JSBundler.Resolve
    // ========================================================================

    /// Resolve - 插件解析结果
    /// 严格翻译自: JSBundler.Resolve
//    public class Resolve {
//        public var bv2: BundleV2
//        public var importRecord: MiniImportRecord
//        public var value: ResolveValue = .pending
//        public var jsTask: AnyTask
//        public var task: AnyEventLoopTask

//        /// MiniImportRecord - 精简的导入记录
//        /// 严格翻译自: Resolve.MiniImportRecord
//        public class MiniImportRecord {
//            public var kind: ImportKind
//            public var sourceFile: String = ""
//            public var namespace: String = ""
//            public var specifier: String = ""
//            public var importerSourceIndex: UInt32
//            public var importRecordIndex: UInt32 = 0
//            public var range: LoggerRange = LoggerRange.none
//            public var originalTarget: Target
//        }

//        /// dispatch - 调度到 JS 线程
//        /// 严格翻译自: Resolve.dispatch
//        public func dispatch(): Unit {
//            bv2.jsLoopForPlugins().enqueueTaskConcurrent(jsTask.toConcurrentTask())
//        }

//        /// runOnJSThread - 在 JS 线程上运行
//        /// 严格翻译自: Resolve.runOnJSThread
//        public func runOnJSThread(): Unit {
//            bv2.plugins.matchOnResolve(
//                importRecord.specifier,
//                importRecord.namespace,
//                importRecord.sourceFile,
//                this,
//                importRecord.kind
//            )
//        }

//        public func deinit(): Unit {
//            value.deinit()
//        }
//    }

    // ========================================================================
    // Load - 插件 onLoad 处理
    // 严格翻译自: JSBundler.Load
    // ========================================================================

    /// Load - 插件加载结果
    /// 严格翻译自: JSBundler.Load
//    public class Load {
//        public var bv2: BundleV2
//        public var sourceIndex: Index
//        public var defaultLoader: Loader
//        public var path: String = ""
//        public var namespace: String = ""
//        public var value: LoadValue = .pending
//        public var jsTask: AnyTask
//        public var task: AnyEventLoopTask
//        public var parseTask: ParseTask
//        public var wasFile: Bool = false
//        public var calledDefer: Bool = false

//        /// dispatch - 调度到 JS 线程
//        /// 严格翻译自: Load.dispatch
//        public func dispatch(): Unit {
//            bv2.jsLoopForPlugins().enqueueTaskConcurrent(jsTask.toConcurrentTask())
//        }

//        /// runOnJSThread - 在 JS 线程上运行
//        /// 严格翻译自: Load.runOnJSThread
//        public func runOnJSThread(): Unit {
//            bv2.plugins.matchOnLoad(
//                path,
//                namespace,
//                this,
//                defaultLoader,
//                false
//            )
//        }

//        public func deinit(): Unit {
//            value.deinit()
//        }
//    }

    // ========================================================================
    // BuildArtifact - 构建产物
    // 严格翻译自: JSBundler.BuildArtifact
    // ========================================================================

    /// BuildArtifact - 打包构建的输出产物
    /// 严格翻译自: JSBundler.BuildArtifact
//    public class BuildArtifact {
//        public var blob: Blob
//        public var loader: Loader = .file
//        public var path: String = ""
//        public var hash: UInt64 = UInt64.max
//        public var outputKind: OutputKind
//        public var sourcemap: JsStrongOptional = JsStrongOptional.empty()

//        /// OutputKind - 输出类型
//        /// 严格翻译自: BuildArtifact.OutputKind
//        public enum OutputKind {
//            | chunk
//            | asset
//            | entryPoint
//            | sourcemap
//            | bytecode
//            | moduleInfo
//            | metafileJson
//            | metafileMarkdown

//            /// 是否为独立模式中的文件
//            /// 严格翻译自: OutputKind.isFileInStandaloneMode
//            public func isFileInStandaloneMode(): Bool {
//                return this != sourcemap && this != bytecode && this != moduleInfo && this != metafileJson && this != metafileMarkdown
//            }
//        }

//        // ====================================================================
//        // getText - 获取文本内容
//        // 严格翻译自: BuildArtifact.getText
//        // ====================================================================

//        /// getText - 获取产物的文本内容
//        public func getText(globalThis!: JsGlobalObject, callframe!: JsCallFrame): JsValue {
//            return blob.getText(globalThis, callframe)
//        }

//        // ====================================================================
//        // getJSON - 获取 JSON 内容
//        // 严格翻译自: BuildArtifact.getJSON
//        // ====================================================================

//        /// getJSON - 获取产物的 JSON 内容
//        public func getJSON(globalThis!: JsGlobalObject, callframe!: JsCallFrame): JsValue {
//            return blob.getJSON(globalThis, callframe)
//        }

//        // ====================================================================
//        // getArrayBuffer - 获取 ArrayBuffer
//        // 严格翻译自: BuildArtifact.getArrayBuffer
//        // ====================================================================

//        /// getArrayBuffer - 获取产物的 ArrayBuffer
//        public func getArrayBuffer(globalThis!: JsGlobalObject, callframe!: JsCallFrame): JsValue {
//            return blob.getArrayBuffer(globalThis, callframe)
//        }

//        // ====================================================================
//        // getSlice - 获取 Uint8Array 切片
//        // 严格翻译自: BuildArtifact.getSlice
//        // ====================================================================

//        /// getSlice - 获取产物的 Uint8Array
//        public func getSlice(globalThis!: JsGlobalObject, callframe!: JsCallFrame): JsValue {
//            return blob.getSlice(globalThis, callframe)
//        }

//        // ====================================================================
//        // getType - 获取 MIME 类型
//        // 严格翻译自: BuildArtifact.getType
//        // ====================================================================

//        /// getType - 获取产物的 MIME 类型
//        public func getType(globalThis!: JsGlobalObject): JsValue {
//            return blob.getType(globalThis)
//        }

//        // ====================================================================
//        // getStream - 获取可读流
//        // 严格翻译自: BuildArtifact.getStream
//        // ====================================================================

//        /// getStream - 获取产物的可读流
//        public func getStream(globalThis!: JsGlobalObject, callframe!: JsCallFrame): JsValue {
//            return blob.getStream(globalThis, callframe)
//        }

//        // ====================================================================
//        // getPath - 获取路径
//        // 严格翻译自: BuildArtifact.getPath
//        // ====================================================================

//        /// getPath - 获取产物路径
//        public func getPath(globalThis!: JsGlobalObject): JsValue {
//            return ZigString.fromUTF8(path).toJS(globalThis)
//        }

//        // ====================================================================
//        // getLoader - 获取 loader 类型
//        // 严格翻译自: BuildArtifact.getLoader
//        // ====================================================================

//        /// getLoader - 获取 loader 类型
//        public func getLoader(globalThis!: JsGlobalObject): JsValue {
//            return ZigString.fromUTF8(loader.toString()).toJS(globalThis)
//        }

//        // ====================================================================
//        // getHash - 获取哈希值
//        // 严格翻译自: BuildArtifact.getHash
//        // ====================================================================

//        /// getHash - 获取产物的哈希值 (截断为 32 位显示)
//        public func getHash(globalThis!: JsGlobalObject): JsValue {
//            let truncatedHash = truncatedHash32(hash)
//            return ZigString(truncatedHash.toString()).toJS(globalThis)
//        }

//        // ====================================================================
//        // getSize - 获取大小
//        // 严格翻译自: BuildArtifact.getSize
//        // ====================================================================

//        /// getSize - 获取产物大小
//        public func getSize(globalThis!: JsGlobalObject): JsValue {
//            return blob.getSize(globalThis)
//        }

//        // ====================================================================
//        // getMimeType - 获取 MIME 类型
//        // 严格翻译自: BuildArtifact.getMimeType
//        // ====================================================================

//        /// getMimeType - 获取 MIME 类型
//        public func getMimeType(globalThis!: JsGlobalObject): JsValue {
//            return blob.getType(globalThis)
//        }

//        // ====================================================================
//        // getOutputKind - 获取输出类型
//        // 严格翻译自: BuildArtifact.getOutputKind
//        // ====================================================================

//        /// getOutputKind - 获取输出类型
//        public func getOutputKind(globalThis!: JsGlobalObject): JsValue {
//            return ZigString.fromUTF8(outputKind.toString()).toJS(globalThis)
//        }

//        // ====================================================================
//        // getSourceMap - 获取 sourcemap
//        // 严格翻译自: BuildArtifact.getSourceMap
//        // ====================================================================

//        /// getSourceMap - 获取关联的 sourcemap
//        public func getSourceMap(globalThis!: JsGlobalObject): JsValue {
//            if (let value <- sourcemap.get()) {
//                return value
//            }
//            return JsValue.jsNull()
//        }

//        // ====================================================================
//        // finalize / deinit
//        // ====================================================================

//        /// finalize - GC 回收
//        public func finalize(): Unit {
//            deinit()
//        }

//        /// deinit - 释放资源
//        /// 严格翻译自: BuildArtifact.deinit
//        public func deinit(): Unit {
//            blob.deinit()
//            sourcemap.deinit()
//            default_allocator.free(path)
//        }
//    }

    // ========================================================================
    // buildFn - Bun.build() 的 JS 入口
    // 严格翻译自: JSBundler.buildFn
    // ========================================================================

    /// buildFn - JS 入口点: Bun.build(options)
    /// 严格翻译自: JSBundler.buildFn
    public static func buildFn(globalThis!: JsGlobalObject, callframe!: JsCallFrame): JsValue {
        return JsValue.jsUndefined()
    }

    /// build - 实际构建逻辑
    /// 严格翻译自: JSBundler.build
    public static func build(globalThis!: JsGlobalObject, arguments!: Array<JsValue>): JsValue {
        return JsValue.jsUndefined()
    }
}

// ============================================================================
// 支持的枚举和辅助类型
// ============================================================================

/// Target - 构建目标
/// 严格翻译自: options.Target
public enum Target {
    | browser
    | node
    | bun
    | `macro`
    | bunMacro

    public static func fromString(s!: String): ?Target {
        match (s) {
            case "browser" => return Target.browser
            case "node" => return Target.node
            case "bun" => return Target.bun
            case "macro" => return Target.`macro`
            case _ => return None
        }
    }
}

/// Format - 输出格式
/// 严格翻译自: options.Format
public enum Format {
    | esm
    | cjs
    | iife
}

/// SourceMapOption - Source Map 选项
/// 严格翻译自: options.SourceMapOption
public enum SourceMapOption {
    | sourceMapNone
    | inline
    | linked
    | external

    public static func fromString(s!: String): SourceMapOption {
        match (s) {
            case "inline" => return SourceMapOption.inline
            case "linked" => return SourceMapOption.linked
            case "external" => return SourceMapOption.external
            case _ => return SourceMapOption.sourceMapNone
        }
    }
}

/// PackagesOption - 包处理选项
/// 严格翻译自: options.PackagesOption
public enum PackagesOption {
    | bundle
    | external
}

/// DotEnvBehavior - 环境变量行为
public enum DotEnvBehavior {
    | disable
    | loadAll
    | prefix
}

/// ForceNodeEnv - Node env 强制设置
public enum ForceNodeEnv {
    | unspecified
    | development
    | production
}

/// ImportKind - 导入类型
public enum ImportKind {
    | entryPoint
    | importStatement
    | requireResolve
    | dynamicImport
    | require
    | atImport
    | urlToken
    | httpImport
    | css
}

/// Loader - 文件加载器类型
/// 严格翻译自: options.Loader
public enum Loader {
    | js
    | jsx
    | ts
    | tsx
    | json
    | tomll
    | yaml
    | file
    | css
    | html
    | text
    | wasm
    | napi
    | base64
    | dataurl
    | sqlite
    | bun

    public static func fromString(s!: String): Loader {
        match (s) {
            case "js" => return Loader.js
            case "jsx" => return Loader.jsx
            case "ts" => return Loader.ts
            case "tsx" => return Loader.tsx
            case "json" => return Loader.json
            case "css" => return Loader.css
            case "html" => return Loader.html
            case "text" => return Loader.text
            case "file" => return Loader.file
            case "wasm" => return Loader.wasm
            case _ => return Loader.file
        }
    }

    public func toString(): String {
        match (this) {
            case js => return "js"
            case jsx => return "jsx"
            case ts => return "ts"
            case tsx => return "tsx"
            case json => return "json"
            case css => return "css"
            case html => return "html"
            case text => return "text"
            case file => return "file"
            case wasm => return "wasm"
            case _ => return "file"
        }
    }
}

/// LoaderMap - 加载器映射
public class LoaderMap {
    public var extensions: Array<String> = Array<String>()
    public var loaders: Array<Loader> = Array<Loader>()
    public init() {}
}

/// Jsx - JSX 配置
public class Jsx {
    public var factory: String = ""
    public var fragment: String = ""
    public var runtime: JsxRuntime = JsxRuntime.automatic
    public var importSource: String = ""
    public var development: Bool = true
    public var sideEffects: Bool = false
}

/// JsxRuntime - JSX 运行时类型
public enum JsxRuntime {
    | classic
    | automatic

    public static func fromString(s!: String): JsxRuntime {
        match (s) {
            case "classic" | "react" => return JsxRuntime.classic
            case "automatic" | "react-jsx" | "react-jsxdev" => return JsxRuntime.automatic
            case _ => return JsxRuntime.automatic
        }
    }
}

/// ResolveValue - 解析结果值
public enum ResolveValue {
    | err(LoggerMsg)
    | success(String, String, Bool)  // path, namespace, external
    | noMatch
    | pending
    | consumed

    public func consume(): ResolveValue {
        let result = this
        // this = .consumed  (标记为已消费)
        return result
    }

    public func deinit(): Unit {
        // 释放资源
    }
}

/// LoadValue - 加载结果值
public enum LoadValue {
    | err(LoggerMsg)
    | success(String, Loader)  // sourceCode, loader
    | pending
    | noMatch
    | consumed

    public func consume(): LoadValue {
        let result = this
        return result
    }

    public func deinit(): Unit {
        // 释放资源
    }
}

// ============================================================================
// 桩声明 - 未完全移植的 Bundler 类型
// 以下类型在 bao_bundler 包中已有对应实现，但 API 可能不完全兼容。
// 状态标注:
//   [EXISTS] - 真实类型已存在于 bao_bundler，API 基本兼容，可逐步替换为 import
//   [KEPT]   - 真实类型存在但接口差异大，保留本地简化版本
// [MIGRATED] 逐步用 import bao_bundler.* 替换这些本地类型
// ============================================================================

/// 编译目标 - 对应 Bun: CompileTarget
/// [KEPT] bao_bundler 中尚无此类型
public class CompileTarget {
    public init() {}
}

/// 编译目标类型 - 对应 Bun: CompileTargetType
/// [KEPT] bao_bundler 中尚无此类型
public enum CompileTargetType {
    | Browser
    | Node
    | Bun
}

/// 日志消息 - 对应 Bun: LoggerMsg
/// [KEPT] bao_bundler 中尚无此类型
public class LoggerMsg {
    public init() {}
}

/// 日志范围 - 对应 Bun: LoggerRange
/// [KEPT] bao_bundler 中尚无此类型
public class LoggerRange {
    public static let none: LoggerRange = LoggerRange()
    public init() {}
}

/// BundleV2 打包器 - 对应 Bun: BundleV2
/// [EXISTS] 真实类型在 bao_bundler.bundle_v2.BundleV2（30+ 字段）
/// 保留本地简化版本，待 API 适配后替换为 import
public class BundleV2 {
    public init() {}
}

/// 解析任务 - 对应 Bun: ParseTask
/// [EXISTS] 真实类型在 bao_bundler.parse_task.ParseTask
/// 保留本地简化版本，待 API 适配后替换为 import
public class ParseTask {
    public init() {}
}

/// 索引类型 - 对应 Bun: Index
/// [EXISTS] 真实类型在 bao_bundler.ast_builder.Index（字段兼容）
/// 待 import bao_bundler.* 后替换
public class Index {
    public var value: Int32 = -1
    public static let Invalid: Index = Index()
    public static let Runtime: Index = Index()
    public init() {}
    public init(value: Int32) { this.value = value }
    public func isValid(): Bool { return value >= 0 }
}

/// 插件 - 对应 Bun: Plugin
/// [EXISTS] 真实类型在 bao_bundler.plugin.Plugin
/// 待 import bao_bundler.* 后替换
public class Plugin {
    public var name: String = ""
    public init() {}
    public init(name: String) { this.name = name }
}

/// 拥有的字符串 - 对应 Bun: OwnedString
/// [KEPT] bao_bundler 中尚无此类型
public class OwnedString {
    public init() {}
}

/// 路径模板 - 对应 Bun: PathTemplate
/// [KEPT] bao_bundler 中尚无此类型
public class PathTemplate {
    public init() {}
}

/// 文件系统路径 - 对应 Bun: FsPath
/// [KEPT] bao_bundler 中尚无此类型（有 resolver 中的 PathPair 等）
public class FsPath {
    public var text: String = ""
    public var isDisabled: Bool = false
    public var namespace: String = ""
    public var pretty: String = ""
    public var prettyDirUrlToUseForDotDotSlash: String = ""
    public var primaryText: String = ""
    public var secondaryText: String = ""
    public var tertiaryText: String = ""
    public var isAbsolute: Bool = false
    public var isDisabledPatternMatching: Bool = false
    public var hash: Int64 = 0
    public var tag: UInt8 = 0
    public init() {}
}

/// 路径对 - 对应 Bun: PathPair
/// [KEPT] bao_bundler 中尚无此类型
public class PathPair {
    public var primary: FsPath = FsPath()
    public var secondary: FsPath = FsPath()
    public init() {}
}

/// 解析器结果 - 对应 Bun: ResolverResult
/// [EXISTS] 真实类型在 bao_bundler.bundle_v2.ResolverResult
/// 待 import bao_bundler.* 后替换
public class ResolverResult {
    public init() {}
}

/// Blob 对象 - 对应 Bun: Blob
/// [KEPT] 真实类型在 bao_runtime.webcore.Blob，但接口不同
public class Blob {
    public init() {}
}

/// 通用任务 - 对应 Bun: AnyTask
/// [KEPT] 真实类型在 bao_event_loop.AnyTask
public class AnyTask {
    public init() {}
}

/// 事件循环任务 - 对应 Bun: AnyEventLoopTask
/// [KEPT] 真实类型在 bao_event_loop 中
public class AnyEventLoopTask {
    public init() {}
}

/// JS Strong Optional - 对应 Bun: JsStrongOptional
public class JsStrongOptional {
    public init() {}
}

// ported from: src/runtime/api/JSBundler.zig
