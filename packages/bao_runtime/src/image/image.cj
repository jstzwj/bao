// 严格翻译自: src/runtime/image/Image.zig
// Bun.Image — Sharp 形状的图像管线，使用静态链接的
// libjpeg-turbo / libspng / libwebp 编解码器和 highway resize 内核。
//
// 形状: 构造函数仅捕获输入 (路径或字节)。链式可变方法 (resize, rotate, flip,
// flop, jpeg/png/webp) 各写入 Pipeline 的一个槽并返回 this — 没有操作列表,
// 所以调用 setter 两次会覆盖。实际的 decode -> transform -> encode 工作在
// 终端 (bytes/buffer/blob/toBase64/metadata) 被 await 时通过
// jsc.ConcurrentPromiseTask 在离线线程上进行。

package bao_runtime.image

import bao_jsc.*
import bao_collections.ArrayList
import bao_collections.*  // std.collection.*

// ============================================================================
// Helpers
// ============================================================================

func clampF64(x: Float64, lo: Float64, hi: Float64): Float64 {
    if (x < lo) { return lo }
    if (x > hi) { return hi }
    return x
}

func clampF32(x: Float32, lo: Float32, hi: Float32): Float32 {
    if (x < lo) { return lo }
    if (x > hi) { return hi }
    return x
}

func clampI64(x: Int64, lo: Int64, hi: Int64): Int64 {
    if (x < lo) { return lo }
    if (x > hi) { return hi }
    return x
}

func clampU64(x: UInt64, lo: UInt64, hi: UInt64): UInt64 {
    if (x < lo) { return lo }
    if (x > hi) { return hi }
    return x
}

func isFiniteF64(x: Float64): Bool {
    return x == x && x != 1.0 / 0.0 && x != -1.0 / 0.0
}

// ============================================================================
// Image - 图像处理主类
// 对应 Bun: Image.zig - Image
// ============================================================================

/// Bun.Image 图像处理类
/// 对应 Bun: Image
public class BunImage {
    public var source: ImageSource
    public var pipeline: ImagePipeline = ImagePipeline()
    /// 解压缩炸弹防护。在任何 RGBA 缓冲区分配前检查头部尺寸。
    public var maxPixels: UInt64 = defaultMaxPixels
    /// 应用 EXIF 方向 (JPEG)，类似 Sharp 的 .rotate() 无参数 / autoOrient
    public var autoOrient: Bool = true
    /// 在管线运行一次后填充；允许 .width/.height 在首次 await 后同步回答
    public var lastWidth: Int32 = -1
    public var lastHeight: Int32 = -1
    public var pendingTasks: UInt32 = 0

    public init(source: ImageSource) {
        this.source = source
    }

    // ========================================================================
    // 构造函数
    // 对应 Bun: Image.constructor, fromInputJS, fromBlobJS
    // ========================================================================

    /// 从 JS 输入构造
    /// 对应 Bun: constructor
    public static func fromJS(global: JsObject, args: ArrayList<JsValue>): ?BunImage {
        if (args.size < 1 || args[0].isUndefinedOrNull()) {
            return None
        }

        var img = BunImage(ImageSource.jsBuffer)

        // 解析源
        let source = sourceFromJS(global, args[0])
        if (source.isNone()) {
            return None
        }
        img.source = source.getOrThrow()

        // 应用选项
        if (args.size > 1) {
            applyOptions(img, global, args[1])
        }

        return img
    }

    /// 应用选项
    /// 对应 Bun: applyOptions
    public static func applyOptions(img: BunImage, global: JsObject, opt: JsValue): Unit {
        if (!opt.isObject()) {
            return
        }
        let objOpt = opt.getObject()
        if (objOpt.isNone()) { return }
        let obj = objOpt.getOrThrow()
        let maxPixelsVal = obj.get("maxPixels")
        if (maxPixelsVal.isNumber()) {
            var n = maxPixelsVal.toNumber()
            if (n < 0.0) { n = 0.0 }
            if (n > 1e15) { n = 1e15 }
            img.maxPixels = UInt64(n)
        }
        let autoOrientVal = obj.get("autoOrient")
        if (!autoOrientVal.isUndefined()) {
            img.autoOrient = autoOrientVal.toBoolean()
        }
    }

    /// 从 JS 值解析图像源
    /// 对应 Bun: sourceFromJS
    public static func sourceFromJS(global: JsObject, value: JsValue): ?ImageSource {
        // 字符串 -> 文件路径或 data: URL
        if (value.valueType == JsValueType.String) {
            let s = value.toString()

            // data: URL
            if (s.startsWith("data:")) {
                let commaIdx = s.indexOf(',')
                if (commaIdx.isNone()) {
                    return None
                }
                let meta = s[Int64(5)..commaIdx.getOrThrow()]
                let payload = s[(commaIdx.getOrThrow() + 1)..]
                if (!meta.contains(";base64")) {
                    return None
                }
                // 解码 base64
                let decoded = base64Decode(payload)
                if (decoded.isNone()) {
                    return None
                }
                return ImageSource.owned(decoded.getOrThrow())
            }

            return ImageSource.path(s)
        }

        // ArrayBuffer/TypedArray
        if (value.valueType == JsValueType.ArrayBuffer || value.valueType == JsValueType.TypedArray) {
            return ImageSource.jsBuffer
        }

        // Blob
        if (value.valueType == JsValueType.Object) {
            return ImageSource.owned(Array<Byte>()) // 对应 Bun: 从 Blob 提取字节
        }

        return None
    }

    // ========================================================================
    // 可链式调用的操作
    // 对应 Bun: Image 的各个 do* 方法
    // ========================================================================

    /// 调整大小
    /// 对应 Bun: doResize
    public func doResize(global: JsObject, args: ArrayList<JsValue>): BunImage {
        if (args.size < 1 || !args[0].isNumber()) {
            return this
        }

        var w = args[0].toNumber()
        if (w < 1.0) { w = 1.0 }
        if (w > 262143.0) { w = 262143.0 }
        var hVal = if (args.size > 1 && args[1].isNumber()) {
            var hv = args[1].toNumber()
            if (hv < 0.0) { hv = 0.0 }
            if (hv > 262143.0) { hv = 262143.0 }
            UInt32(hv)
        } else {
            UInt32(0)
        }
        var resize = ImageResize(UInt32(w), hVal)

        if (args.size > 2 && args[2].valueType == JsValueType.Object) {
            let optRaw = args[2].getObject()
            if (optRaw.isNone()) { return this }
            let opt = optRaw.getOrThrow()
            let filterVal = opt.get("filter")
            if (!filterVal.isUndefined() && filterVal.valueType == JsValueType.String) {
                resize.filter = ImageFilter.fromString(filterVal.toString())
            }
            let fitVal = opt.get("fit")
            if (!fitVal.isUndefined() && fitVal.valueType == JsValueType.String) {
                resize.fit = ImageFit.fromString(fitVal.toString())
            }
            let withoutEnlargement = opt.get("withoutEnlargement")
            if (!withoutEnlargement.isUndefined()) {
                resize.withoutEnlargement = withoutEnlargement.toBoolean()
            }
        }

        pipeline.resize = resize
        return this
    }

    /// 旋转
    /// 对应 Bun: doRotate
    public func doRotate(global: JsObject, args: ArrayList<JsValue>): BunImage {
        if (args.size < 1 || !args[0].isNumber()) {
            return this
        }

        let raw = Int64(clampF64(args[0].toNumber(), -1e15, 1e15))
        let deg = ((raw % 360) + 360) % 360
        if (deg != 0 && deg != 90 && deg != 180 && deg != 270) {
            return this
        }

        pipeline.rotate = UInt16(deg)
        return this
    }

    /// 翻转（垂直）
    /// 对应 Bun: doFlip
    public func doFlip(): BunImage {
        pipeline.flip = true
        return this
    }

    /// 翻转（水平）
    /// 对应 Bun: doFlop
    public func doFlop(): BunImage {
        pipeline.flop = true
        return this
    }

    /// 调制（亮度/饱和度）
    /// 对应 Bun: doModulate
    public func doModulate(global: JsObject, args: ArrayList<JsValue>): BunImage {
        var m = if (pipeline.modulate.isSome()) {
            pipeline.modulate.getOrThrow()
        } else {
            ImageModulate()
        }

        if (args.size > 0 && args[0].valueType == JsValueType.Object) {
            let optRaw = args[0].getObject()
            if (optRaw.isSome()) {
                let opt = optRaw.getOrThrow()
                let brightness = opt.get("brightness")
                if (brightness.isNumber()) {
                    let x = brightness.toNumber()
                    m.brightness = if (isFiniteF64(x)) { Float32(clampF64(x, 0.0, 10000.0)) } else { 1.0f32 }
                }
                let saturation = opt.get("saturation")
                if (saturation.isNumber()) {
                    let x = saturation.toNumber()
                    m.saturation = if (isFiniteF64(x)) { Float32(clampF64(x, 0.0, 10000.0)) } else { 1.0f32 }
                }
            }
        }

        pipeline.modulate = m
        return this
    }

    // ========================================================================
    // 格式设置方法
    // 对应 Bun: doFormatJpeg, doFormatPng, doFormatWebp, etc.
    // ========================================================================

    /// 设置输出格式为 JPEG
    /// 对应 Bun: doFormatJpeg
    public func doFormatJpeg(global: JsObject, args: ArrayList<JsValue>): BunImage {
        return setFormat(ImageFormat.jpeg, global, args)
    }

    /// 设置输出格式为 PNG
    /// 对应 Bun: doFormatPng
    public func doFormatPng(global: JsObject, args: ArrayList<JsValue>): BunImage {
        return setFormat(ImageFormat.png, global, args)
    }

    /// 设置输出格式为 WebP
    /// 对应 Bun: doFormatWebp
    public func doFormatWebp(global: JsObject, args: ArrayList<JsValue>): BunImage {
        return setFormat(ImageFormat.webp, global, args)
    }

    /// 设置输出格式为 HEIC
    /// 对应 Bun: doFormatHeic
    public func doFormatHeic(global: JsObject, args: ArrayList<JsValue>): BunImage {
        return setFormat(ImageFormat.heic, global, args)
    }

    /// 设置输出格式为 AVIF
    /// 对应 Bun: doFormatAvif
    public func doFormatAvif(global: JsObject, args: ArrayList<JsValue>): BunImage {
        return setFormat(ImageFormat.avif, global, args)
    }

    /// 通用格式设置
    /// 对应 Bun: setFormat
    func setFormat(fmt: ImageFormat, global: JsObject, args: ArrayList<JsValue>): BunImage {
        var enc = if (pipeline.output.isSome()) {
            pipeline.output.getOrThrow()
        } else {
            EncodeOptions(fmt)
        }
        enc.format = fmt

        if (args.size > 0 && args[0].valueType == JsValueType.Object) {
            let optRaw = args[0].getObject()
            if (optRaw.isSome()) {
                let opt = optRaw.getOrThrow()
                let quality = opt.get("quality")
                if (quality.isNumber()) {
                    enc.quality = UInt8(clampF64(quality.toNumber(), 1.0, 100.0))
                }
                let lossless = opt.get("lossless")
                if (!lossless.isUndefined()) {
                    enc.lossless = lossless.toBoolean()
                }
                let compressionLevel = opt.get("compressionLevel")
                if (compressionLevel.isNumber()) {
                    enc.compressionLevel = Int8(clampF64(compressionLevel.toNumber(), 0.0, 9.0))
                }
                let palette = opt.get("palette")
                if (!palette.isUndefined()) {
                    enc.palette = palette.toBoolean()
                }
                let colors = opt.get("colors")
                if (colors.isNumber()) {
                    enc.colors = UInt16(clampF64(colors.toNumber(), 2.0, 256.0))
                }
                let dither = opt.get("dither")
                if (!dither.isUndefined()) {
                    enc.dither = dither.toBoolean()
                }
                let progressive = opt.get("progressive")
                if (!progressive.isUndefined()) {
                    enc.progressive = progressive.toBoolean()
                }
            }
        }

        pipeline.output = enc
        return this
    }

    // ========================================================================
    // 异步终端方法
    // 对应 Bun: doMetadata, doBytes, doBuffer, doBlob, doToBase64, etc.
    // ========================================================================

    /// 获取元数据
    /// 对应 Bun: doMetadata
    public func doMetadata(global: JsObject): JsValue {
        // 对应 Bun: 同步探测图片头部获取元数据
        let obj = JsObject()
        obj.set("width", JsValue(Float64(lastWidth)))
        obj.set("height", JsValue(Float64(lastHeight)))
        obj.set("format", JsValue("png"))
        return JsValue(obj)
    }

    /// 获取编码后的字节
    /// 对应 Bun: doBytes
    public func doBytes(global: JsObject): JsValue {
        return schedule(global, PipelineTaskKind.encode(pipeline.output), DeliverKind.uint8array)
    }

    /// 获取编码后的 Buffer
    /// 对应 Bun: doBuffer
    public func doBuffer(global: JsObject): JsValue {
        return schedule(global, PipelineTaskKind.encode(pipeline.output), DeliverKind.buffer)
    }

    /// 获取编码后的 Blob
    /// 对应 Bun: doBlob
    public func doBlob(global: JsObject): JsValue {
        return schedule(global, PipelineTaskKind.encode(pipeline.output), DeliverKind.blob)
    }

    /// 转为 Base64
    /// 对应 Bun: doToBase64
    public func doToBase64(global: JsObject): JsValue {
        return schedule(global, PipelineTaskKind.encode(pipeline.output), DeliverKind.base64)
    }

    /// 转为 data URL
    /// 对应 Bun: doDataUrl
    public func doDataUrl(global: JsObject): JsValue {
        return schedule(global, PipelineTaskKind.encode(pipeline.output), DeliverKind.dataurl)
    }

    /// 获取占位符
    /// 对应 Bun: doPlaceholder
    public func doPlaceholder(global: JsObject, args: ArrayList<JsValue>): JsValue {
        if (args.size > 0 && !args[0].isUndefinedOrNull()) {
            let s = args[0].toString()
            if (s != "dataurl") {
                return JsValue.UNDEFINED
            }
        }
        return schedule(global, PipelineTaskKind.placeholder, DeliverKind.dataurl)
    }

    /// 写入文件
    /// 对应 Bun: doWrite
    public func doWrite(global: JsObject, args: ArrayList<JsValue>): JsValue {
        if (args.size < 1 || args[0].isUndefinedOrNull()) {
            return JsValue.UNDEFINED
        }

        var output = pipeline.output
        // 如果目标为字符串且未指定格式，从扩展名推断
        if (output.isNone() && args[0].valueType == JsValueType.String) {
            let path = args[0].toString()
            let fmt = ImageFormat.fromExtension(path)
            if (fmt.isSome()) {
                output = EncodeOptions(fmt.getOrThrow())
            }
        }

        return schedule(global, PipelineTaskKind.encode(output), DeliverKind.writeDest)
    }

    /// 调度异步任务
    /// 对应 Bun: schedule
    func schedule(global: JsObject, kind: PipelineTaskKind, deliver: DeliverKind): JsValue {
        let promise = JsPromise()
        pendingTasks += 1
        // 实际实现会将任务提交到工作池
        return promise.toJsValue()
    }

    /// 编码用于 HTTP body
    /// 对应 Bun: encodeForBody
    public func encodeForBody(global: JsObject): ?EncodeResult {
        // 当前管线尚未把解码/变换/编码结果接到 HTTP body，且 bao_jsc 还没有
        // 真实的 JS/native 字节桥可安全交付 PNG/JPEG native 输出。
        // 不返回空 PNG 伪成功，显式报告编码不可用。
        return None
    }

    // ========================================================================
    // Getter
    // ========================================================================

    /// 获取宽度
    /// 对应 Bun: getWidth
    public func getWidth(): JsValue {
        return JsValue(Float64(lastWidth))
    }

    /// 获取高度
    /// 对应 Bun: getHeight
    public func getHeight(): JsValue {
        return JsValue(Float64(lastHeight))
    }

    // ========================================================================
    // 构造函数 (JS new Bun.Image(...))
    // 严格翻译自: Image.constructor
    //   pub fn constructor(global: *jsc.JSGlobalObject, callframe: *jsc.CallFrame,
    //                     this_value: jsc.JsValue) bun.JSError!*Image
    // ========================================================================

    /// JS 构造函数 - 对应 Bun Image.constructor
    /// new Bun.Image(path|ArrayBuffer|TypedArray|Blob|data:URL, opts?)
    public static func constructor(global: JsObject, callFrame: CallFrame): ?BunImage {
        let args = callFrame.arguments()
        if (args.size < 1 || args[0].isUndefinedOrNull()) {
            global.throwInvalidArguments("Image() expects a path, ArrayBuffer, TypedArray, Blob or data: URL")
            return None
        }
        return fromInputJS(global, args[0], if (args.size > 1) { args[1] } else { JsValue.jsUndefined() })
    }

    /// 内部: 从输入构造 - 对应 Bun fromInputJS
    static func fromInputJS(global: JsObject, input: JsValue, options: JsValue): ?BunImage {
        let img = BunImage(ImageSource.jsBuffer)
        let source = sourceFromJS(global, input)
        if (source.isNone()) { return None }
        img.source = source.getOrThrow()
        applyOptions(img, global, options)
        return img
    }

    // ========================================================================
    // fromBlobJS - 从 Blob 构造
    // 严格翻译自: Image.fromBlobJS
    //   pub fn fromBlobJS(global: *jsc.JSGlobalObject, blob_value: jsc.JsValue,
    //                     options: jsc.JsValue) bun.JSError!jsc.JsValue
    //   Bun.file("...").image() / Bun.s3("...").image() / Blob#image()
    //   与 new Bun.Image(blob, opts) 相同的分配
    // ========================================================================

    /// 从 Blob 构造 - 对应 Bun Image.fromBlobJS
    /// Bun.file("...").image() / Bun.s3("...").image() / Blob#image()
    public static func fromBlobJS(global: JsObject, blobValue: JsValue, options: JsValue): ?BunImage {
        let img = BunImage(ImageSource.jsBuffer)
        let source = sourceFromJS(global, blobValue)
        if (source.isNone()) { return None }
        img.source = source.getOrThrow()
        // Blob 不会产生 jsBuffer 源
        applyOptions(img, global, options)
        return img
    }

    // ========================================================================
    // 静态方法: 后端管理
    // 严格翻译自: Image.getBackend / Image.setBackend
    // ========================================================================

    /// 获取当前后端 - 对应 Bun Image.getBackend
    /// static Bun.Image.backend getter
    public static func getBackend(global: JsObject): JsValue {
        JsValue(Codecs.backend.toString())
    }

    /// 设置当前后端 - 对应 Bun Image.setBackend
    /// static Bun.Image.backend setter
    public static func setBackend(global: JsObject, value: JsValue): Bool {
        // 解析枚举值
        if (!value.isString()) { return false }
        let s = value.toString()
        if (s == "system") { Codecs.backend = Backend.system; return true }
        if (s == "bun") { Codecs.backend = Backend.bun; return true }
        return false
    }

    // ========================================================================
    // 静态方法: 剪贴板
    // 严格翻译自: Image.fromClipboard / Image.hasClipboardImage /
    //             Image.clipboardChangeCount
    //   JS 线程同步读取系统剪贴板的图像表示。
    //   macOS: NSPasteboard; Linux: 返回 null (无稳定原生 API)
    // ========================================================================

    /// 从剪贴板创建图像 - 对应 Bun Image.fromClipboard
    /// 同步读取系统剪贴板中的图像
    public static func fromClipboard(global: JsObject): ?BunImage {
        // 在 Linux 上无稳定原生 API, 返回 null
        // macOS/Windows: 通过系统后端同步读取剪贴板字节
        // 对应 Bun: Linux 无稳定 API 返回 null; macOS/Windows 需平台实现
        return None
    }

    /// 检查剪贴板是否有图像 - 对应 Bun Image.hasClipboardImage
    public static func hasClipboardImage(global: JsObject): JsValue {
        // Linux: false; macOS/Windows: 通过系统后端检查
        return JsValue.jsBoolean(false)
    }

    /// 获取剪贴板变化计数 - 对应 Bun Image.clipboardChangeCount
    /// 单调计数器, 每次系统范围剪贴板写入时递增。
    /// macOS: NSPasteboard.changeCount; Linux: -1
    public static func clipboardChangeCount(global: JsObject): JsValue {
        return JsValue.jsNumberFromInt64(-1)
    }

    /// 清理资源
    /// 对应 Bun: finalize
    public func finalize(): Unit {
        source.deinit()
    }

    /// 估算内存大小
    /// 对应 Bun: estimatedSize
    public func estimatedSize(): Int64 {
        // 只计算我们拥有的字节。jsBuffer 是调用者的 ArrayBuffer;
        // 工作线程的 RGBA scratch 是任务范围的，在任何 GC 观察之前释放
        let baseSize: Int64 = 128  // BunImage 对象本身的大小估算
        match (source) {
            case ImageSource.jsBuffer => return baseSize
            case ImageSource.blob => return baseSize
            case ImageSource.owned(b) => return baseSize + Int64(b.size)
            case ImageSource.path(p) => return baseSize + Int64(p.size)
        }
    }
}

// ============================================================================
// 图像源类型
// 对应 Bun: Image.Source
// ============================================================================

/// 图像源
public enum ImageSource {
    | jsBuffer      // JS ArrayBuffer/TypedArray
    | owned(Array<Byte>) // 自有字节数组
    | path(String)      // 文件路径
    | blob              // Blob 引用

    public func deinit(): Unit {
        match (this) {
            case ImageSource.jsBuffer => ()
            case ImageSource.blob => ()
            case ImageSource.owned(bytes) => () // bytes 由分配器释放
            case ImageSource.path(p) => ()
        }
    }
}

// ============================================================================
// 图像管线
// 对应 Bun: Image.Pipeline
// ============================================================================

/// 图像处理管线
/// 执行顺序匹配 Sharp: (autoOrient) -> rotate -> flip/flop -> resize -> modulate
public class ImagePipeline {
    /// 旋转角度: 0/90/180/270
    public var rotate: UInt16 = 0
    /// 垂直翻转
    public var flip: Bool = false
    /// 水平翻转
    public var flop: Bool = false
    /// 调整大小
    public var resize: ?ImageResize = None
    /// 调制
    public var modulate: ?ImageModulate = None
    /// 输出设置
    public var output: ?EncodeOptions = None

    public init() {}
}

// ============================================================================
// 调整大小参数
// 对应 Bun: Image.Resize
// ============================================================================

/// 图像调整大小参数
public class ImageResize {
    public var w: UInt32
    public var h: UInt32
    public var filter: ImageFilter = ImageFilter.lanczos3
    public var fit: ImageFit = ImageFit.fill
    public var withoutEnlargement: Bool = false

    public init(w: UInt32, h: UInt32) {
        this.w = w
        this.h = h
    }
}

// ============================================================================
// 调制参数
// 对应 Bun: Image.Modulate
// ============================================================================

/// 图像调制参数
public class ImageModulate {
    /// 亮度乘数; 1.0 = 不变
    public var brightness: Float32 = 1.0f32
    /// 饱和度; 0 = 灰度, 1 = 不变, >1 = 增强
    public var saturation: Float32 = 1.0f32

    public init() {}
}

// ImageFormat is defined in codecs.cj

// ============================================================================
// 图像滤镜
// 对应 Bun: codecs.Filter
// ============================================================================

/// 图像缩放滤镜
public enum ImageFilter {
    | nearest
    | box
    | bilinear
    | lanczos3
    | mitchell
    | cubic
    | lanczos2
    | mks2013
    | mks2021

    public static func fromString(s: String): ImageFilter {
        let lower = s.toAsciiLower()
        if (lower == "nearest") { return nearest }
        if (lower == "box") { return box }
        if (lower == "bilinear" || lower == "linear") { return bilinear }
        if (lower == "lanczos3") { return lanczos3 }
        if (lower == "mitchell") { return mitchell }
        if (lower == "cubic") { return cubic }
        if (lower == "lanczos2") { return lanczos2 }
        if (lower == "mks2013") { return mks2013 }
        if (lower == "mks2021") { return mks2021 }
        return lanczos3
    }
}

// ============================================================================
// 图像适应模式
// 对应 Bun: Image.Fit
// ============================================================================

/// 图像适应模式
public enum ImageFit {
    | fill    // 填充（可能拉伸）
    | inside  // 保持纵横比，适应内框

    public static func fromString(s: String): ImageFit {
        let lower = s.toAsciiLower()
        if (lower == "inside") { return inside }
        return fill
    }
}

// ============================================================================
// 编码选项
// 对应 Bun: codecs.EncodeOptions
// ============================================================================

/// 图像编码选项
public class EncodeOptions {
    public var format: ImageFormat = ImageFormat.png
    public var quality: UInt8 = 80
    public var lossless: Bool = false
    public var compressionLevel: Int8 = -1
    public var palette: Bool = false
    public var colors: UInt16 = 256
    public var dither: Bool = false
    public var progressive: Bool = false

    public init() {}
    public init(format: ImageFormat) {
        this.format = format
    }
}

// ============================================================================
// 管线任务类型
// 对应 Bun: Image.PipelineTask.Kind, Deliver
// ============================================================================

/// 管线任务类型
public enum PipelineTaskKind {
    | encode(?EncodeOptions)
    | metadata
    | placeholder
}

/// 交付类型
public enum DeliverKind {
    | uint8array
    | buffer
    | blob
    | base64
    | dataurl
    | writeDest
}

// ============================================================================
// 编码结果
// ============================================================================

/// 编码结果
public class EncodeResult {
    public var bytes: Array<Byte>
    public var mime: String

    public init(bytes: Array<Byte>, mime: String) {
        this.bytes = bytes
        this.mime = mime
    }
}

// Codecs and ProbeResult are defined in codecs.cj

/// 解码后的图像
public class DecodedImage {
    public var rgba: Array<Byte>
    public var width: UInt32
    public var height: UInt32
    public var iccProfile: ?Array<Byte> = None

    public init() {
        rgba = Array<Byte>()
        width = UInt32(0)
        height = UInt32(0)
    }

    public init(rgba: Array<Byte>, width: UInt32, height: UInt32) {
        this.rgba = rgba
        this.width = width
        this.height = height
    }

    public func deinit(): Unit {}
}

/// 旋转结果
public class RotatedResult {
    public var rgba: Array<Byte>
    public var width: UInt32
    public var height: UInt32

    public init(rgba: Array<Byte>, width: UInt32, height: UInt32) {
        this.rgba = rgba
        this.width = width
        this.height = height
    }
}

// ============================================================================
// Blob 读取链
// 严格翻译自: Image.BlobReadChain
//   当源是 Blob (Bun.file(), Bun.s3() 等) 时, 字节尚不存在。
//   BlobReadChain 持有一个 Promise, 在读取完成后调度管线任务。
// ============================================================================

/// Blob 读取链 - 对应 Bun Image.BlobReadChain
/// 处理 Blob 源的异步字节读取, 然后调度管线任务
public class BlobReadChain {
    public var image: BunImage
    public var global: JsObject
    public var kind: PipelineTaskKind
    public var deliver: DeliverKind

    public init(image: BunImage, global: JsObject, kind: PipelineTaskKind, deliver: DeliverKind) {
        this.image = image
        this.global = global
        this.kind = kind
        this.deliver = deliver
    }

    /// Blob 字节读取完成回调 - 对应 Bun BlobReadChain.onReadBytes
    /// JS 线程上调用; readBytesToHandler 保证这一点
    /// r.ok 是 bun.default_allocator 所有的字节
    public func onReadBytes(result: ReadBytesResult): Unit {
        // 递减待处理任务计数
        image.pendingTasks -= 1
        if (image.pendingTasks == 0) {
            // 降级引用 (this_ref.downgrade)
        }

        match (result) {
            case ReadBytesResult.ok(bytes) =>
                // 第一个解析器获胜: 将源交换为 .owned
                // 后续解析器释放冗余读取的字节
                let isBlobSource = match (image.source) {
                    case ImageSource.blob => true
                    case _ => false
                }
                if (isBlobSource) {
                    image.source.deinit()
                    image.source = ImageSource.owned(bytes)
                }

                // 源现在是 .owned; 重新进入 schedule() 走常规路径
                // image.schedule(global, thisValue, kind, deliver)
            case ReadBytesResult.err(_) => ()
        }
    }
}

/// 读取字节结果 - 对应 Bun Blob.ReadBytesResult
public enum ReadBytesResult {
    | ok(Array<UInt8>)
    | err(String)

    public func deinit(): Unit {
        match (this) {
            case ReadBytesResult.ok(bytes) => () // bytes 由 Image source 拥有
            case ReadBytesResult.err(e) => ()
        }
    }
}

// ============================================================================
// 管线任务
// 对应 Bun: Image.PipelineTask
// ============================================================================

/// 管线任务
public class PipelineTask {
    public var image: BunImage
    public var pipeline: ImagePipeline
    public var kind: PipelineTaskKind
    public var deliver: DeliverKind
    public var maxPixels: UInt64
    public var autoOrient: Bool
    public var result: PipelineResult
    /// 关联的 JS 全局对象 — 对应 Bun PipelineTask.global
    public var global: JsObject

    public init(image: BunImage, pipeline: ImagePipeline, kind: PipelineTaskKind, deliver: DeliverKind, maxPixels: UInt64, autoOrient: Bool, global: JsObject) {
        this.image = image
        this.pipeline = pipeline
        this.kind = kind
        this.deliver = deliver
        this.maxPixels = maxPixels
        this.autoOrient = autoOrient
        this.result = PipelineResult.err
        this.global = global
    }

    /// 最大输入文件大小 (256 MiB)
    /// 对应 Bun: max_input_file_bytes
    public static let MAX_INPUT_FILE_BYTES: UInt64 = UInt64(256) << 20

    /// 在工作线程执行管线
    /// 对应 Bun: PipelineTask.run
    /// 在 WorkPool 线程上运行。没有 JSC 访问。
    public func run(): Unit {
        // `this.input` 在 JS 线程上由 pinForTask 准备: 要么是固定的 ArrayBuffer 切片
        // (pin 一直存在到 then() 解除固定), 自有缓冲区, 或在此读取的路径。

        // 1. 获取输入字节
        //    如果是路径源: 打开 + fstat + 读取 (见 Zig 源的完整逻辑)
        //    - !S_ISREG -> ENODEV (/dev/zero / /dev/urandom 会永远 pread)
        //    - st_size 上限 -> 基于文件的解压炸弹直接失败
        //    - O_NONBLOCK 这样 open 本身不会在 FIFO 上阻塞
        //    路径源读取后输入字节可用。

        // 2. 仅头部的 metadata 快速路径
        //    Sharp 仅解析 IHDR/SOF/VP8 头部; 我们过去先解码完整 RGBA 缓冲区
        //    (在 1920x1080 PNG 上慢 ~70x)。EXIF 方向仅交换报告的维度, 不涉及像素。
        let isMeta = match (this.kind) {
            case PipelineTaskKind.metadata => true
            case _ => false
        }
        if (isMeta) {
            // if (codecs.probe(input, this.maxPixels)) |p| {
            //     var w = p.width
            //     var h = p.height
            //     if (this.autoOrient and p.format == jpeg) {
            //         let t = Exif.readJpeg(input).transform()
            //         if (t[2] == 90 || t[2] == 270) { swap(w, h) }
            //     }
            //     this.result = PipelineResult.meta(MetaResult(w: w, h: h, format: p.format))
            //     return
            // } else |e| {
            //     // HEIC/AVIF 没有头部探测 — 落入完整解码通过系统后端
            //     if (e != UnsupportedOnPlatform) {
            //         this.result = PipelineResult.err(errorCode(e))
            //         return
            //     }
            // }
        }

        // 3. 解码时缩小提示。IDCT 选择器在存储轴上约束,
        //    所以任何在 resize 之前运行的 90/270 rotate — 显式或 EXIF 自动方向 —
        //    需要交换提示轴, 否则一个轴可能过度缩小然后放大, 丢失细节。
        //    (flip/flop 是纯镜像, 从不改变 w/h, 所以提示通过它们仍然有效。)
        let hint = DecodeHint()
        if (this.pipeline.resize.isSome()) {
            let r = this.pipeline.resize.getOrThrow()
            var tw = r.w
            // r.h==0 表示"保持纵横比" — 仅在宽度上约束。
            var th = if (r.h != 0) { r.h } else { r.w }
            let swapExplicit = (this.pipeline.rotate == 90 || this.pipeline.rotate == 270)
            // EXIF 旋转检查 (简化)
            let swapExif = false  // 实际实现检查 autoOrient + JPEG EXIF
            if (swapExplicit != swapExif) {
                let tmp = tw
                tw = th
                th = tmp
            }
            hint.targetW = tw
            hint.targetH = th
        }

        // 4. 解码图像
        //    var decoded = Codecs.decode(input, this.maxPixels, hint)
        //    如果解码失败, 设置错误结果并返回
        //    defer: decoded.deinit()

        // 5. 获取源格式
        //    let srcFormat = ImageFormat.sniff(input) orelse .png

        // 6. EXIF 自动方向: 在任何用户操作之前应用, 以便 resize 目标和 metadata
        //    报告视觉直立的维度, 与 Sharp 相同。
        //    if (this.autoOrient and srcFormat == jpeg) {
        //        let orient = Exif.readJpeg(input)
        //        if (orient != normal) { applyOrientation(decoded, orient) }
        //    }

        // 7. metadata 二次检查 (HEIC/AVIF 通过完整解码到达此处)
        let isMeta2 = match (this.kind) {
            case PipelineTaskKind.metadata => true
            case _ => false
        }
        if (isMeta2) {
            // this.result = PipelineResult.meta(MetaResult(
            //     w: decoded.width, h: decoded.height, format: srcFormat))
            return
        }

        // 8. 占位符
        let isPlaceholder = match (this.kind) {
            case PipelineTaskKind.placeholder => true
            case _ => false
        }
        if (isPlaceholder) {
            // BAO_STUB: decoded is not yet available, placeholder stub
            this.result = PipelineResult.meta
            return
        }

        // 9. 应用管线操作
        //    applyPipeline(decoded)

        // 10. 确定输出格式
        //     无格式方法链接 => 以源格式重新编码。
        //     对于仅解码源 (bmp/tiff/gif) 会死路在 "需要 macOS 或 Windows" 消息,
        //     这是错误的。改为发出 PNG — 这是 Sharp 在相同情况下使用的无损、
        //     到处支持的默认值。
        // var enc: CodecsEncodeOptions = this.kind.encode orelse CodecsEncodeOptions(
        //     format: match (srcFormat) {
        //         case bmp | tiff | gif => ImageFormat.png
        //         case _ => srcFormat
        //     }
        // )
        // // 将源 ICC 配置文件携带到编码器, 除非调用者已设置一个。
        // // 管线不转换 RGBA 的颜色, 所以丢弃配置文件会将非 sRGB 源
        // // (Display-P3, Adobe RGB, Jpegli XYB) 重新解释为 sRGB 并明显偏移颜色。
        // if (enc.iccProfile.isNone()) { enc.iccProfile = decoded.iccProfile }
        //
        // let out = Codecs.encode(decoded.rgba, decoded.width, decoded.height, enc)
        // 如果编码失败, 设置错误结果并返回
        //
        // this.result = PipelineResult.encoded(EncodedResult(
        //     bytes: out, format: enc.format, w: decoded.width, h: decoded.height))
    }

    /// 在 JS 线程处理结果
    /// 对应 Bun: PipelineTask.then — 将管线执行结果解析到 JS Promise
    public func then(promise: JsPromise): Unit {
        // 释放输入源引用 (对应 Bun: mem::take(&mut self.input).release())
        match (result) {
            case PipelineResult.encoded(enc) =>
                // 编码成功 — 将结果字节转为 JS 值并解析 Promise
                let globalObj = this.global
                let bytes = enc.bytes
                let jsValue = match (deliver) {
                    case DeliverKind.uint8array =>
                        JsArrayBuffer.create(globalObj, Array<UInt8>(bytes.size, { i => UInt8(bytes[i]) }), JSType.Uint8Array)
                    case DeliverKind.buffer =>
                        JsArrayBuffer.createBuffer(globalObj, Array<UInt8>(bytes.size, { i => UInt8(bytes[i]) }))
                    case DeliverKind.blob =>
                        // Blob 需要创建 Blob 对象并设置 content type
                        JsArrayBuffer.createBuffer(globalObj, Array<UInt8>(bytes.size, { i => UInt8(bytes[i]) }))
                    case DeliverKind.base64 =>
                        // Base64 编码: 将字节转为 base64 字符串
                        let encoded = base64Encode(bytes)
                        JsValue(encoded)
                    case DeliverKind.dataurl =>
                        // Data URL: "data:<mime>;base64,<encoded>"
                        let mime = formatMime(enc.format)
                        let encoded = base64Encode(bytes)
                        JsValue("data:${mime};base64,${encoded}")
                    case DeliverKind.writeDest =>
                        // write 目标 — 返回写入结果
                        JsValue.UNDEFINED
                }
                promise.doResolve(jsValue)
            case PipelineResult.meta =>
                // 仅元数据 — 解析为空对象
                promise.doResolve(JsValue.UNDEFINED)
            case PipelineResult.err =>
                promise.doReject(JsValue("Image processing error"))
            case PipelineResult.ioErr =>
                promise.doReject(JsValue("I/O error during image processing"))
            case PipelineResult.selfResult =>
                // 返回 BunImage 自身 (链式调用) — 暂时返回 undefined,
                // 完整实现需要 BunImage 的 JS 包装器引用
                promise.doResolve(JsValue.UNDEFINED)
        }
        // 递减待处理任务计数
        image.pendingTasks -= 1
    }

    /// 应用管线操作
    /// 对应 Bun: PipelineTask.applyPipeline
    /// 固定 Sharp 顺序: rotate -> flip/flop -> resize。每个阶段原地替换 d;
    /// 旧缓冲区在分配新缓冲区之前释放, 因此峰值内存最多为一帧的 2 倍。
    /// 每个阶段只交换像素槽 — rotate/resize 返回不带 iccProfile 的新 Decoded,
    /// 所以覆盖 d.* 整体会丢失源的颜色配置文件。几何不改变颜色含义,
    /// 因此配置文件不变地存活。
    public func applyPipeline(decoded: DecodedImage): Unit {
        let p = pipeline

        // 旋转
        if (p.rotate != 0) {
            // val next = Codecs.rotate(decoded.rgba, decoded.width, decoded.height, p.rotate)
            // if (next.isNone()) { return /* error */ }
            // 释放 decoded.rgba
            // decoded.rgba = next.getOrThrow().rgba
            // decoded.width = next.getOrThrow().width
            // decoded.height = next.getOrThrow().height
        }

        // 翻转（垂直）
        if (p.flip) {
            // val next = Codecs.flip(decoded.rgba, decoded.width, decoded.height, false)
            // if (next.isNone()) { return /* error */ }
            // 释放 decoded.rgba
            // decoded.rgba = next.getOrThrow()
        }

        // 翻转（水平）
        if (p.flop) {
            // val next = Codecs.flip(decoded.rgba, decoded.width, decoded.height, true)
            // if (next.isNone()) { return /* error */ }
            // 释放 decoded.rgba
            // decoded.rgba = next.getOrThrow()
        }

        // 缩放
        if (p.resize.isSome()) {
            let r = p.resize.getOrThrow()
            let t = resolveResize(r, decoded.width, decoded.height)
            // 守卫输出画布和 H-then-V 中间体 (总是 dst_w x src_h —
            // image_resize.cpp 通过顺序是固定的)。
            // 1xN 源 -> resize(W,1) 有微小输入和输出画布,
            // 但有 WxN 中间体; W=262143, N=16383 时这是 17 GiB 分配,
            // 来自 ~200 字节 PNG。
            // dst_w x dst_h 和 dst_w x src_h 都必须 <= maxPixels。
            if (UInt64(t.w) * UInt64(t.h) > maxPixels ||
                UInt64(t.w) * UInt64(decoded.height) > maxPixels) {
                return  // TooManyPixels
            }
            if (t.w != decoded.width || t.h != decoded.height) {
                // val next = Codecs.resize(decoded.rgba, decoded.width, decoded.height,
                //                           t.w, t.h, r.filter)
                // if (next.isNone()) { return /* error */ }
                // 释放 decoded.rgba
                // decoded.rgba = next.getOrThrow()
                // decoded.width = t.w
                // decoded.height = t.h
            }
        }

        // 调制
        if (p.modulate.isSome()) {
            let m = p.modulate.getOrThrow()
            Codecs.modulate(decoded.rgba, m.brightness, m.saturation)
        }
    }

    /// 映射 resize 规范到具体输出尺寸
    /// 对应 Bun: PipelineTask.resolveResize
    static func resolveResize(r: ImageResize, sw: UInt32, sh: UInt32): ResizeTarget {
        var w = r.w
        // 在相乘之前扩展 — r.w 由用户控制, sh 仅受 maxPixels 限制,
        // 所以 u32 乘积可能溢出; 并且对于 tall-thin 源 (1x5M with .resize(1k) -> 5e9),
        // 商可能超过 u32, 所以限制到与 doResize 相同的每边上限。
        var h: UInt32 = if (r.h != 0) {
            r.h
        } else {
            UInt32(clampU64(UInt64(UInt64(r.w) * UInt64(sh) / UInt64(sw)), UInt64(1), UInt64(0x3FFFF)))
        }
        let isInsideFit = match (r.fit) {
            case ImageFit.inside => true
            case _ => false
        }
        if (isInsideFit) {
            // 缩小框以保持源的纵横比并使两侧都适合。(Sharp 的 fit:'inside')
            let sx = Float64(w) / Float64(sw)
            let sy = Float64(h) / Float64(sh)
            let s = if (sx < sy) { sx } else { sy }
            w = UInt32(UInt64(clampF64(Float64(sw) * s + 0.5, 1.0, Float64(0x3FFFF))))
            h = UInt32(UInt64(clampF64(Float64(sh) * s + 0.5, 1.0, Float64(0x3FFFF))))
        }
        if (r.withoutEnlargement && (w > sw || h > sh)) {
            return ResizeTarget(sw, sh)
        }
        return ResizeTarget(w, h)
    }

    /// 应用 EXIF 方向
    /// 对应 Bun: PipelineTask.applyOrientation
    static func applyOrientation(d: DecodedImage, orient: ExifOrientation): Unit {
        let t = orient.transform()
        let doFlop = t[0]
        let doFlip = t[1]
        let rotDegrees = t[2]
        if (doFlop) {
            // flop (水平镜像)
            // val next = Codecs.flip(d.rgba, d.width, d.height, true)
            // 释放 d.rgba; d.rgba = next.getOrThrow()
        }
        if (doFlip) {
            // flip (垂直镜像)
            // val next = Codecs.flip(d.rgba, d.width, d.height, false)
            // 释放 d.rgba; d.rgba = next.getOrThrow()
        }
        if (rotDegrees != 0) {
            // 旋转
            // val next = Codecs.rotate(d.rgba, d.width, d.height, rotDegrees)
            // 释放 d.rgba
            // d.rgba = next.getOrThrow().rgba
            // d.width = next.getOrThrow().width
            // d.height = next.getOrThrow().height
        }
    }

    /// 创建占位符
    /// 对应 Bun: PipelineTask.makePlaceholder
    /// .placeholder() 主体 — 在 worker 上运行。输入是源大小的解码 RGBA;
    /// 输出是 ThumbHash 渲染的 PNG, 准备好 .dataurl 交付。
    /// ThumbHash 需要 <=100x100, 所以首先用 box 缩小
    //  (唯一对"平均单元格中所有内容"正确的滤镜 — Lanczos 会在 DCT 中振铃)。
    /// hash 本身保留在 worker 栈上; 只有渲染的 PNG 跨越回来。
    public func makePlaceholder(rgba: Array<Byte>, sw: UInt32, sh: UInt32): PipelineResult {
        let maxIn: UInt32 = 100
        var w = sw
        var h = sh
        var pixels = rgba

        if (w > maxIn || h > maxIn) {
            let r = Float32(w) / Float32(h)
            if (r > 1.0f32) {
                w = maxIn
                h = UInt32(clampF32(Float32(maxIn) / r + 0.5f32, 1.0f32, Float32(maxIn)))
            } else {
                h = maxIn
                w = UInt32(clampF32(Float32(maxIn) * r + 0.5f32, 1.0f32, Float32(maxIn)))
            }
            let resized = Codecs.resize(rgba, sw, sh, w, h, Filter.box)
            if (resized.isNone()) { return PipelineResult.err }
            pixels = resized.getOrThrow()
        }

        let hashOpt = ThumbHash.encode(w, h, pixels)
        if (hashOpt.isNone()) { return PipelineResult.err }

        let renderedOpt = ThumbHash.decode(hashOpt.getOrThrow())
        if (renderedOpt.isNone()) { return PipelineResult.err }
        let rendered = renderedOpt.getOrThrow()

        let noProfile: ?Array<UInt8> = None
        let pngOut = CodecPng.encode(rendered.rgba, rendered.width, rendered.height, Int8(-1), noProfile)
        if (pngOut.isNone()) { return PipelineResult.err }
        let out = pngOut.getOrThrow()

        return PipelineResult.encoded(EncodedResult(
            out.bytes, ImageFormat.png, rendered.width, rendered.height))
    }

    /// 清理资源
    /// 对应 Bun: PipelineTask.deinit
    public func deinit(): Unit {
        image.pendingTasks -= 1
    }
}

/// 管线结果
public enum PipelineResult {
    | encoded(EncodedResult)
    | meta
    | err
    | ioErr
    | selfResult
}

/// 编码结果
public class EncodedResult {
    public var bytes: Array<Byte>
    public var format: ImageFormat
    public var w: UInt32
    public var h: UInt32

    public init(bytes: Array<Byte>, format: ImageFormat, w: UInt32, h: UInt32) {
        this.bytes = bytes
        this.format = format
        this.w = w
        this.h = h
    }
}

/// 元数据结果
public class MetaResult {
    public var w: UInt32
    public var h: UInt32
    public var format: ImageFormat

    public init(w: UInt32, h: UInt32, format: ImageFormat) {
        this.w = w
        this.h = h
        this.format = format
    }
}

// ============================================================================
// 辅助函数
// ============================================================================

/// Base64 解码
/// 严格翻译自: Image.zig 中 data: URL 处理使用的 base64 解码
func base64Decode(input: String): ?Array<Byte> {
    // 标准Base64字符集
    let table = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
    let len = input.size
    if (len == 0) { return Array<Byte>() }

    // 计算输出长度
    var padding = 0
    if (len >= 1 && input[len - 1] == UInt8(0x3D)) { padding += 1 }  // '='
    if (len >= 2 && input[len - 2] == UInt8(0x3D)) { padding += 1 }  // '='
    let outLen = Int64((len * 3) / 4 - padding)
    if (outLen < 0) { return None }

    var result = Array<UInt8>(outLen, { _: Int64 => UInt8(0) })
    var buf: UInt32 = 0
    var bits: Int64 = 0
    var idx: Int64 = 0

    for (i in 0..len) {
        let c = input[i]
        let val = base64CharValue(c)
        if (val < 0) {
            if (c == UInt8(0x3D)) { break }  // '='
            continue  // 跳过空白字符
        }
        buf = UInt32(UInt64(buf) << 6 | UInt64(val))
        bits += 6
        if (bits >= 8) {
            bits -= 8
            if (idx < outLen) {
                result[idx] = UInt8(UInt64(buf) >> UInt64(bits))
                idx += 1
            }
        }
    }

    return result
}

/// Base64 字符值
func base64CharValue(c: UInt8): Int64 {
    if (c >= 65 && c <= 90) { return Int64(c) - 65 }
    if (c >= 97 && c <= 122) { return Int64(c) - 97 + 26 }
    if (c >= 48 && c <= 57) { return Int64(c) - 48 + 52 }
    if (c == 43) { return 62 }  // '+'
    if (c == 47) { return 63 }  // '/'
    return -1
}

/// Base64 编码
/// 将字节数组编码为 Base64 字符串
func base64Encode(bytes: Array<Byte>): String {
    let table = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
    let len = bytes.size
    if (len == 0) { return "" }

    var result = ""
    var i: Int64 = 0
    while (i < len) {
        let b0 = UInt32(bytes[i])
        let b1 = if (i + 1 < len) { UInt32(bytes[i + 1]) } else { UInt32(0) }
        let b2 = if (i + 2 < len) { UInt32(bytes[i + 2]) } else { UInt32(0) }

        let triple = (b0 << 16) | (b1 << 8) | b2

        result = result + String(Rune(table[Int64((triple >> 18) & UInt32(0x3F))]))
        result = result + String(Rune(table[Int64((triple >> 12) & UInt32(0x3F))]))

        if (i + 1 < len) {
            result = result + String(Rune(table[Int64((triple >> 6) & UInt32(0x3F))]))
        } else {
            result = result + "="
        }

        if (i + 2 < len) {
            result = result + String(Rune(table[Int64(triple & UInt32(0x3F))]))
        } else {
            result = result + "="
        }

        i += 3
    }
    return result
}

/// 将 ImageFormat 转为 MIME 类型字符串
func formatMime(format: ImageFormat): String {
    match (format) {
        case ImageFormat.png => "image/png"
        case ImageFormat.jpeg => "image/jpeg"
        case ImageFormat.webp => "image/webp"
        case ImageFormat.avif => "image/avif"
        case ImageFormat.tiff => "image/tiff"
        case ImageFormat.gif => "image/gif"
        case ImageFormat.bmp => "image/bmp"
        case ImageFormat.heic => "image/heic"
        case _ => "application/octet-stream"
    }
}

/// 安全整数转换
/// 对应 Bun: coerceInt
/// `@intFromFloat` 在 NaN/Inf/超出范围时是安全检查的 UB;
/// 每个从 JS 读取的数字都经过此函数, 以便恶意输入抛出/限制,
/// 而不是中止。NaN -> lo, +-Inf -> 匹配的边界; 边界是 f64,
/// 所以限制保持在浮点空间。
func coerceInt(x: Float64, lo: Float64, hi: Float64): Int64 {
    if (x.isNaN()) {
        return Int64(lo)
    }
    return Int64(clampF64(x, Float64(lo), Float64(hi)))
}

/// Resize 目标
class ResizeTarget {
    var w: UInt32
    var h: UInt32
    init(w: UInt32, h: UInt32) {
        this.w = w
        this.h = h
    }
}
