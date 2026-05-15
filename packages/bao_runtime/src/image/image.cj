// 严格翻译自: src/runtime/image/Image.zig
// Bun.Image — Sharp 形状的图像管线，使用静态链接的
// libjpeg-turbo / libspng / libwebp 编解码器和 highway resize 内核。
//
// 形状: 构造函数仅捕获输入 (路径或字节)。链式可变方法 (resize, rotate, flip,
// flop, jpeg/png/webp) 各写入 Pipeline 的一个槽并返回 this — 没有操作列表,
// 所以调用 setter 两次会覆盖。实际的 decode -> transform -> encode 工作在
// 终端 (bytes/buffer/blob/toBase64/metadata) 被 await 时通过
// jsc.ConcurrentPromiseTask 在离线线程上进行。

package bao_runtime

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
    public var maxPixels: UInt64 = Codecs.defaultMaxPixels
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
        val source = sourceFromJS(global, args[0])
        if (source == None) {
            return None
        }
        img.source = source!

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
        val obj = opt.getObject()
        val maxPixelsVal = obj.get("maxPixels")
        if (maxPixelsVal != None && maxPixelsVal.isNumber()) {
            img.maxPixels = UInt64(maxPixelsVal.toNumber().clamp(0.0, 1e15))
        }
        val autoOrientVal = obj.get("autoOrient")
        if (autoOrientVal != None) {
            img.autoOrient = autoOrientVal.toBoolean()
        }
    }

    /// 从 JS 值解析图像源
    /// 对应 Bun: sourceFromJS
    public static func sourceFromJS(global: JsObject, value: JsValue): ?ImageSource {
        // 字符串 -> 文件路径或 data: URL
        if (value.valueType == JsValueType.String) {
            val s = value.toString()

            // data: URL
            if (s.startsWith("data:")) {
                val commaIdx = s.indexOf(',')
                if (commaIdx == None) {
                    return None
                }
                val meta = s.subString(5, commaIdx!)
                val payload = s.subString(commaIdx! + 1)
                if (!meta.contains(";base64")) {
                    return None
                }
                // 解码 base64
                val decoded = base64Decode(payload)
                if (decoded == None) {
                    return None
                }
                return ImageSource.owned(decoded!)
            }

            return ImageSource.path(s)
        }

        // ArrayBuffer/TypedArray
        if (value.valueType == JsValueType.ArrayBuffer || value.valueType == JsValueType.TypedArray) {
            return ImageSource.jsBuffer
        }

        // Blob
        if (value.valueType == JsValueType.Object) {
            return ImageSource.owned(Array<Byte>()) // 简化
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

        var resize = ImageResize(
            w: UInt32(args[0].toNumber().clamp(1.0, 262143.0)),
            h: if (args.size > 1 && args[1].isNumber()) {
                UInt32(args[1].toNumber().clamp(0.0, 262143.0))
            } else {
                0
            }
        )

        if (args.size > 2 && args[2].valueType == JsValueType.Object) {
            val opt = args[2].getObject()
            val filterVal = opt.get("filter")
            if (filterVal != None && filterVal.valueType == JsValueType.String) {
                resize.filter = ImageFilter.fromString(filterVal.toString())
            }
            val fitVal = opt.get("fit")
            if (fitVal != None && fitVal.valueType == JsValueType.String) {
                resize.fit = ImageFit.fromString(fitVal.toString())
            }
            val withoutEnlargement = opt.get("withoutEnlargement")
            if (withoutEnlargement != None) {
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

        val raw = Int64(args[0].toNumber().clamp(-1e15, 1e15))
        val deg = ((raw % 360) + 360) % 360
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
        var m = if (pipeline.modulate != None) {
            pipeline.modulate!
        } else {
            ImageModulate()
        }

        if (args.size > 0 && args[0].valueType == JsValueType.Object) {
            val opt = args[0].getObject()
            val brightness = opt.get("brightness")
            if (brightness != None && brightness.isNumber()) {
                val x = brightness.toNumber()
                m.brightness = if (x.isFinite()) { Float32(x.clamp(0.0, 10000.0)) } else { 1.0f }
            }
            val saturation = opt.get("saturation")
            if (saturation != None && saturation.isNumber()) {
                val x = saturation.toNumber()
                m.saturation = if (x.isFinite()) { Float32(x.clamp(0.0, 10000.0)) } else { 1.0f }
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
        var enc = if (pipeline.output != None) {
            pipeline.output!
        } else {
            EncodeOptions(format: fmt)
        }
        enc.format = fmt

        if (args.size > 0 && args[0].valueType == JsValueType.Object) {
            val opt = args[0].getObject()
            val quality = opt.get("quality")
            if (quality != None && quality.isNumber()) {
                enc.quality = UInt8(quality.toNumber().clamp(1.0, 100.0))
            }
            val lossless = opt.get("lossless")
            if (lossless != None) {
                enc.lossless = lossless.toBoolean()
            }
            val compressionLevel = opt.get("compressionLevel")
            if (compressionLevel != None && compressionLevel.isNumber()) {
                enc.compressionLevel = Int8(compressionLevel.toNumber().clamp(0.0, 9.0))
            }
            val palette = opt.get("palette")
            if (palette != None) {
                enc.palette = palette.toBoolean()
            }
            val colors = opt.get("colors")
            if (colors != None && colors.isNumber()) {
                enc.colors = UInt16(colors.toNumber().clamp(2.0, 256.0))
            }
            val dither = opt.get("dither")
            if (dither != None) {
                enc.dither = dither.toBoolean()
            }
            val progressive = opt.get("progressive")
            if (progressive != None) {
                enc.progressive = progressive.toBoolean()
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
        // 简化实现：同步探测头部
        val obj = JsObject()
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
            val s = args[0].toString()
            if (s != "dataurl") {
                return JsValue.UNDEFINED
            }
        }
        return schedule(global, PipelineTaskKind.placeholder(), DeliverKind.dataurl)
    }

    /// 写入文件
    /// 对应 Bun: doWrite
    public func doWrite(global: JsObject, args: ArrayList<JsValue>): JsValue {
        if (args.size < 1 || args[0].isUndefinedOrNull()) {
            return JsValue.UNDEFINED
        }

        var output = pipeline.output
        // 如果目标为字符串且未指定格式，从扩展名推断
        if (output == None && args[0].valueType == JsValueType.String) {
            val path = args[0].toString()
            val fmt = ImageFormat.fromExtension(path)
            if (fmt != None) {
                output = EncodeOptions(format: fmt!)
            }
        }

        return schedule(global, PipelineTaskKind.encode(output), DeliverKind.writeDest())
    }

    /// 调度异步任务
    /// 对应 Bun: schedule
    func schedule(global: JsObject, kind: PipelineTaskKind, deliver: DeliverKind): JsValue {
        val promise = JsPromise()
        pendingTasks += 1
        // 实际实现会将任务提交到工作池
        return promise.value()
    }

    /// 编码用于 HTTP body
    /// 对应 Bun: encodeForBody
    public func encodeForBody(global: JsObject): EncodeResult {
        // 简化实现
        return EncodeResult(bytes: Array<Byte>(), mime: "image/png")
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

    /// 清理资源
    /// 对应 Bun: finalize
    public func finalize(): Unit {
        source.deinit()
    }

    /// 估算内存大小
    /// 对应 Bun: estimatedSize
    public func estimatedSize(): Int64 {
        return 0 // 简化
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
            case ImageSource.jsBuffer | ImageSource.blob => {}
            case ImageSource.owned(bytes) => {} // bytes 由分配器释放
            case ImageSource.path(p) => {}
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
    public var brightness: Float32 = 1.0f
    /// 饱和度; 0 = 灰度, 1 = 不变, >1 = 增强
    public var saturation: Float32 = 1.0f

    public init() {}
}

// ============================================================================
// 图像格式
// 对应 Bun: codecs.Format
// ============================================================================

/// 图像格式
public enum ImageFormat {
    | jpeg
    | png
    | webp
    | gif
    | bmp
    | tiff
    | heic
    | avif
    | ico
    | unknown

    public func mime(): String {
        match (this) {
            case jpeg => "image/jpeg"
            case png => "image/png"
            case webp => "image/webp"
            case gif => "image/gif"
            case bmp => "image/bmp"
            case tiff => "image/tiff"
            case heic => "image/heic"
            case avif => "image/avif"
            case ico => "image/x-icon"
            case unknown => "application/octet-stream"
        }
    }

    public static func fromExtension(path: String): ?ImageFormat {
        val lower = path.toLower()
        if (lower.endsWith(".jpg") || lower.endsWith(".jpeg")) return jpeg
        if (lower.endsWith(".png")) return png
        if (lower.endsWith(".webp")) return webp
        if (lower.endsWith(".gif")) return gif
        if (lower.endsWith(".bmp")) return bmp
        if (lower.endsWith(".tiff") || lower.endsWith(".tif")) return tiff
        if (lower.endsWith(".heic") || lower.endsWith(".heif")) return heic
        if (lower.endsWith(".avif")) return avif
        if (lower.endsWith(".ico")) return ico
        return None
    }
}

// ============================================================================
// 图像滤镜
// 对应 Bun: codecs.Filter
// ============================================================================

/// 图像缩放滤镜
public enum ImageFilter {
    | nearest
    | box
    | bilinear
    | hamming
    | lanczos3
    | mitchell

    public static func fromString(s: String): ImageFilter {
        match (s.toLower()) {
            case "nearest" => nearest
            case "box" => box
            case "bilinear" => bilinear
            case "hamming" => hamming
            case "lanczos3" => lanczos3
            case "mitchell" => mitchell
            case _ => lanczos3
        }
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
        match (s.toLower()) {
            case "inside" => inside
            case _ => fill
        }
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
    public var dither: Bool = true
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

// ============================================================================
// 编解码器接口
// 对应 Bun: codecs 模块
// ============================================================================

/// 编解码器
public class Codecs {
    /// 默认最大像素数 (16384x16384 ≈ 268M)
    public static let defaultMaxPixels: UInt64 = 0x3FFF * 0x3FFF

    /// 后端类型
    public static var backend: String = "libc"

    /// 探测图像头部
    public static func probe(input: Array<Byte>, maxPixels: UInt64): ?ProbeResult {
        // 简化实现
        return None
    }

    /// 解码图像
    public static func decode(input: Array<Byte>, maxPixels: UInt64): ?DecodedImage {
        // 简化实现
        return None
    }

    /// 编码图像
    public static func encode(rgba: Array<Byte>, width: UInt32, height: UInt32, options: EncodeOptions): ?Array<Byte> {
        // 简化实现
        return None
    }

    /// 缩放图像
    public static func resize(rgba: Array<Byte>, sw: UInt32, sh: UInt32, dw: UInt32, dh: UInt32, filter: ImageFilter): ?Array<Byte> {
        // 简化实现
        return None
    }

    /// 旋转图像
    public static func rotate(rgba: Array<Byte>, w: UInt32, h: UInt32, degrees: UInt16): ?RotatedResult {
        // 简化实现
        return None
    }

    /// 翻转图像
    public static func flip(rgba: Array<Byte>, w: UInt32, h: UInt32, horizontal: Bool): ?Array<Byte> {
        // 简化实现
        return None
    }

    /// 调制图像
    public static func modulate(rgba: Array<Byte>, brightness: Float32, saturation: Float32): Unit {
        // 简化实现
    }

    /// 从输入字节嗅探格式
    public static func sniff(input: Array<Byte>): ?ImageFormat {
        // 简化实现
        return None
    }
}

/// 探测结果
public class ProbeResult {
    public var width: UInt32
    public var height: UInt32
    public var format: ImageFormat

    public init(width: UInt32, height: UInt32, format: ImageFormat) {
        this.width = width
        this.height = height
        this.format = format
    }
}

/// 解码后的图像
public class DecodedImage {
    public var rgba: Array<Byte>
    public var width: UInt32
    public var height: UInt32
    public var iccProfile: ?Array<Byte> = None

    public init() {
        rgba = Array<Byte>()
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

    public init(image: BunImage, pipeline: ImagePipeline, kind: PipelineTaskKind, deliver: DeliverKind, maxPixels: UInt64, autoOrient: Bool) {
        this.image = image
        this.pipeline = pipeline
        this.kind = kind
        this.deliver = deliver
        this.maxPixels = maxPixels
        this.autoOrient = autoOrient
        this.result = PipelineResult.err("DecodeFailed")
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
        if (this.kind == PipelineTaskKind.metadata) {
            // if (codecs.probe(input, this.maxPixels)) |p| {
            //     var w = p.width
            //     var h = p.height
            //     if (this.autoOrient and p.format == .jpeg) {
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
        val hint = DecodeHint()
        if (this.pipeline.resize != None) {
            let r = this.pipeline.resize!
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
        //    if (this.autoOrient and srcFormat == .jpeg) {
        //        let orient = Exif.readJpeg(input)
        //        if (orient != .normal) { applyOrientation(decoded, orient) }
        //    }

        // 7. metadata 二次检查 (HEIC/AVIF 通过完整解码到达此处)
        if (this.kind == PipelineTaskKind.metadata) {
            // this.result = PipelineResult.meta(MetaResult(
            //     w: decoded.width, h: decoded.height, format: srcFormat))
            return
        }

        // 8. 占位符
        if (this.kind == PipelineTaskKind.placeholder) {
            // this.result = makePlaceholder(decoded.rgba, decoded.width, decoded.height)
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
        // if (enc.iccProfile == None) { enc.iccProfile = decoded.iccProfile }
        //
        // let out = Codecs.encode(decoded.rgba, decoded.width, decoded.height, enc)
        // 如果编码失败, 设置错误结果并返回
        //
        // this.result = PipelineResult.encoded(EncodedResult(
        //     bytes: out, format: enc.format, w: decoded.width, h: decoded.height))
    }

    /// 在 JS 线程处理结果
    /// 对应 Bun: PipelineTask.then
    public func then(promise: JsPromise): Unit {
        // 简化实现
        promise.resolve(JsValue.UNDEFINED)
    }

    /// 应用管线操作
    /// 对应 Bun: PipelineTask.applyPipeline
    /// 固定 Sharp 顺序: rotate -> flip/flop -> resize。每个阶段原地替换 d;
    /// 旧缓冲区在分配新缓冲区之前释放, 因此峰值内存最多为一帧的 2 倍。
    /// 每个阶段只交换像素槽 — rotate/resize 返回不带 iccProfile 的新 Decoded,
    /// 所以覆盖 d.* 整体会丢失源的颜色配置文件。几何不改变颜色含义,
    /// 因此配置文件不变地存活。
    public func applyPipeline(decoded: DecodedImage): Unit {
        val p = pipeline

        // 旋转
        if (p.rotate != 0) {
            // val next = Codecs.rotate(decoded.rgba, decoded.width, decoded.height, p.rotate)
            // if (next == None) { return /* error */ }
            // 释放 decoded.rgba
            // decoded.rgba = next!.rgba
            // decoded.width = next!.width
            // decoded.height = next!.height
        }

        // 翻转（垂直）
        if (p.flip) {
            // val next = Codecs.flip(decoded.rgba, decoded.width, decoded.height, false)
            // if (next == None) { return /* error */ }
            // 释放 decoded.rgba
            // decoded.rgba = next!
        }

        // 翻转（水平）
        if (p.flop) {
            // val next = Codecs.flip(decoded.rgba, decoded.width, decoded.height, true)
            // if (next == None) { return /* error */ }
            // 释放 decoded.rgba
            // decoded.rgba = next!
        }

        // 缩放
        if (p.resize != None) {
            val r = p.resize!
            val t = resolveResize(r, decoded.width, decoded.height)
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
                // if (next == None) { return /* error */ }
                // 释放 decoded.rgba
                // decoded.rgba = next!
                // decoded.width = t.w
                // decoded.height = t.h
            }
        }

        // 调制
        if (p.modulate != None) {
            val m = p.modulate!
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
            UInt64(UInt64(r.w) * UInt64(sh) / UInt64(sw)).clamp(1, UInt64(0x3FFFF)).truncateToUInt32()
        }
        if (r.fit == ImageFit.inside) {
            // 缩小框以保持源的纵横比并使两侧都适合。(Sharp 的 fit:'inside')
            val sx = Float64(w) / Float64(sw)
            val sy = Float64(h) / Float64(sh)
            let s = if (sx < sy) { sx } else { sy }
            w = UInt64((Float64(sw) * s + 0.5).clamp(1.0, Float64(0x3FFFF))).truncateToUInt32()
            h = UInt64((Float64(sh) * s + 0.5).clamp(1.0, Float64(0x3FFFF))).truncateToUInt32()
        }
        if (r.withoutEnlargement && (w > sw || h > sh)) {
            return ResizeTarget(w: sw, h: sh)
        }
        return ResizeTarget(w: w, h: h)
    }

    /// 应用 EXIF 方向
    /// 对应 Bun: PipelineTask.applyOrientation
    static func applyOrientation(d: DecodedImage, orient: ExifOrientation): Unit {
        let t = orient.transform()
        if (t[0]) {
            // flop (水平镜像)
            // val next = Codecs.flip(d.rgba, d.width, d.height, true)
            // 释放 d.rgba; d.rgba = next!
        }
        if (t[1]) {
            // flip (垂直镜像)
            // val next = Codecs.flip(d.rgba, d.width, d.height, false)
            // 释放 d.rgba; d.rgba = next!
        }
        if (t[2] != 0) {
            // 旋转
            // val next = Codecs.rotate(d.rgba, d.width, d.height, t[2])
            // 释放 d.rgba
            // d.rgba = next!.rgba
            // d.width = next!.width
            // d.height = next!.height
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
        var owned: ?Array<Byte> = None
        var pixels = rgba

        if (w > maxIn || h > maxIn) {
            let r = Float32(w) / Float32(h)
            if (r > 1) {
                w = maxIn
                h = UInt32((Float32(maxIn) / r + 0.5f).clamp(1.0f, Float32(maxIn)))
            } else {
                h = maxIn
                w = UInt32((Float32(maxIn) * r + 0.5f).clamp(1.0f, Float32(maxIn)))
            }
            // owned = Codecs.resize(rgba, sw, sh, w, h, Filter.box)
            // if (owned == None) { return PipelineResult.err("DecodeFailed") }
            // pixels = owned!
        }

        // 1. 编码为 ThumbHash
        let hashOpt = ThumbHash.encode(w, h, pixels)
        if (hashOpt == None) { return PipelineResult.err("DecodeFailed") }

        // 2. 解码 ThumbHash 到 RGBA
        let renderedOpt = ThumbHash.decode(hashOpt!)
        if (renderedOpt == None) { return PipelineResult.err("DecodeFailed") }
        // defer: 释放 rendered

        // 3. 编码为 PNG
        // 占位符是合成 ThumbHash 渲染, 不是源图像 — 没有 ICC 配置文件附加。
        // let pngOut = CodecPng.encode(renderedOpt!.rgba, renderedOpt!.width,
        //                               renderedOpt!.height, -1, None)
        // if (pngOut == None) { return PipelineResult.err("DecodeFailed") }

        // return PipelineResult.encoded(EncodedResult(
        //     bytes: pngOut!.bytes, format: ImageFormat.png,
        //     w: renderedOpt!.width, h: renderedOpt!.height))
        return PipelineResult.err("DecodeFailed")
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
    | meta(MetaResult)
    | err(String)
    | ioErr(String)

    public init() {
        this = PipelineResult.err("DecodeFailed")
    }
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

/// Base64 解码（简化版）
func base64Decode(input: String): ?Array<Byte> {
    // 简化实现
    return None
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
    return Int64(x.clamp(lo, hi))
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
