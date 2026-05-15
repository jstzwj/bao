// 严格翻译自: src/jsc/ResolvedSource.zig (44行) + ResolvedSourceTag (lib.rs)
// JavaScriptCore ResolvedSource - 解析后的源码结构体

package bao_jsc

// ========== ResolvedSourceTag ==========
// 严格翻译自 ResolvedSourceTag (lib.rs resolved_source_tag)
// 解析源码的类型标签
// 使用 UInt32 透明表示以支持 (1 << 9) | id 的内部模块 ID 编码
public enum ResolvedSourceTag <: UInt32 {
    | Javascript(0)                // 普通 JavaScript 源码
    | PackageJsonTypeModule(1)     // package.json "type": "module"
    | PackageJsonTypeCommonjs(2)   // package.json "type": "commonjs"
    | Wasm(3)                      // WebAssembly 模块
    | Object(4)                    // JSON 对象
    | CommonJS(5)                  // CommonJS 模块
    | InternalModule(512)          // 内部模块基值 (1 << 9)

    public init(value: UInt32) {
        match (value) {
            case 0 => this = Javascript
            case 1 => this = PackageJsonTypeModule
            case 2 => this = PackageJsonTypeCommonjs
            case 3 => this = Wasm
            case 4 => this = Object
            case 5 => this = CommonJS
            case _ => {
                if (value >= 512) {
                    this = InternalModule
                } else {
                    this = Javascript
                }
            }
        }
    }
}

// ========== ResolvedSource ==========
// 严格翻译自 ResolvedSource.zig
// 表示一个已解析的模块源码结果
// 包含源码文本、标识符、URL 和各种标志
//
// 原始 Zig 代码:
//   pub const ResolvedSource = extern struct {
//       specifier: bun.String = bun.String.empty,
//       source_code: bun.String = bun.String.empty,
//       source_url: bun.String = bun.String.empty,
//       is_commonjs_module: bool = false,
//       cjs_custom_extension_index: JSValue = .zero,
//       allocator: ?*anyopaque = null,
//       jsvalue_for_export: JSValue = .zero,
//       tag: Tag = .javascript,
//       source_code_needs_deref: bool = true,
//       already_bundled: bool = false,
//       bytecode_cache: ?[*]u8 = null,
//       bytecode_cache_size: usize = 0,
//       module_info: ?*anyopaque = null,
//       bytecode_origin_path: bun.String = bun.String.empty,
//   };
public class ResolvedSource_ {
    // ========== 字段 - 严格对应 Zig extern struct 布局 ==========

    // 模块说明符 (specifier)，其生命周期由 C++ 侧调用者管理
    // https://github.com/oven-sh/bun/issues/9521
    public var specifier: String = ""

    // 源码内容
    public var sourceCode: String = ""

    // 源码 URL (成功时最终会被 deref)
    public var sourceURL: String = ""

    // 是否为 CommonJS 模块
    public var isCommonjsModule: Bool = false

    // 当 tag 为 .common_js_custom_extension 时，持有 JSFunction 扩展索引
    // 由 JSC::Strong 引用保持存活
    public var cjsCustomExtensionIndex: JsValue = JsValue.undefined()

    // 分配器 (可选)
    public var allocator: CPointer<UInt8> = CPointer<UInt8>()

    // 用于导出的 JSValue
    public var jsvalueForExport: JsValue = JsValue.undefined()

    // 源码类型标签
    public var tag: ResolvedSourceTag = ResolvedSourceTag.Javascript

    // source_code 是否需要 deref
    public var sourceCodeNeedsDeref: Bool = true

    // 是否已经被打包
    public var alreadyBundled: Bool = false

    // ========== 字节码缓存字段 ==========

    // 字节码缓存数据指针
    public var bytecodeCache: CPointer<UInt8> = CPointer<UInt8>()

    // 字节码缓存大小
    public var bytecodeCacheSize: Int64 = 0

    // 模块信息 (opaque)
    public var moduleInfo: CPointer<UInt8> = CPointer<UInt8>()

    // 字节码来源路径
    // JSC 通过检查 origin URL 是否精确匹配构建时的 URL 来验证字节码
    // 如果为空，origin 从 sourceURL 派生
    // 此路径在 C++ 侧被转换为 file:// URL
    public var bytecodeOriginPath: String = ""

    public init() {}

    public init(
        specifier: String,
        sourceCode: String,
        sourceURL: String,
        tag: ResolvedSourceTag
    ) {
        this.specifier = specifier
        this.sourceCode = sourceCode
        this.sourceURL = sourceURL
        this.tag = tag
    }

    // ========== 工厂方法 ==========

    // 创建 JavaScript 源码结果
    public static func javascript(
        specifier: String,
        sourceCode: String,
        sourceURL: String
    ) -> ResolvedSource_ {
        ResolvedSource_(
            specifier: specifier,
            sourceCode: sourceCode,
            sourceURL: sourceURL,
            tag: ResolvedSourceTag.Javascript
        )
    }

    // 创建 CommonJS 源码结果
    public static func commonjs(
        specifier: String,
        sourceCode: String,
        sourceURL: String
    ) -> ResolvedSource_ {
        let rs = ResolvedSource_(
            specifier: specifier,
            sourceCode: sourceCode,
            sourceURL: sourceURL,
            tag: ResolvedSourceTag.CommonJS
        )
        rs.isCommonjsModule = true
        rs
    }

    // 创建 Wasm 源码结果
    public static func wasm(
        specifier: String,
        sourceCode: String,
        sourceURL: String
    ) -> ResolvedSource_ {
        ResolvedSource_(
            specifier: specifier,
            sourceCode: sourceCode,
            sourceURL: sourceURL,
            tag: ResolvedSourceTag.Wasm
        )
    }
}
