// 严格翻译自: src/bundler/defines-table.zig (931行)
// bao_bundler - Define 表: 全局标识符定义表、无副作用属性/函数访问映射
package bao_bundler

import bao_core.*
import bao_collections.*
import bao_parser.*

// ============================================================================
// 全局无副作用属性访问表
// 严格翻译自: defines-table.zig:15 global_no_side_effect_property_accesses
// 这些属性访问被假定为没有副作用，可以被移除或重排
// ============================================================================

/// 全局无副作用属性访问条目
// 严格翻译自: defines-table.zig:15
// 格式: (对象名, 属性名, ...)
public class NoSideEffectPropertyAccess {
    /// 属性访问路径 (例: ["Array", "from"])
    public var path: Array<String>

    public init(path: Array<String>) {
        this.path = path
    }

    /// 匹配表达式链
    // 严格翻译自: defines-table.zig 中匹配逻辑
    public func matches(parts: Array<String>): Bool {
        if (path.size != parts.size) {
            return false
        }
        for (i in 0..path.size) {
            if (path[i] != parts[i]) {
                return false
            }
        }
        return true
    }
}

/// 全局无副作用属性访问表
// 严格翻译自: defines-table.zig:15 global_no_side_effect_property_accesses
// 查询: 给定一个属性访问链，判断是否在无副作用列表中
public class GlobalNoSideEffectPropertyAccesses {
    private var entries: ArrayList<NoSideEffectPropertyAccess>

    public init() {
        entries = ArrayList<NoSideEffectPropertyAccess>()
        initEntries()
    }

    /// 初始化预定义的无副作用属性访问
    private func initEntries(): Unit {
        // Array: Static methods
        add(["Array", "from"])
        add(["Array", "isArray"])
        add(["Array", "of"])

        // JSON: Static methods
        add(["JSON", "parse"])
        add(["JSON", "stringify"])

        // Math: Static properties
        add(["Math", "E"])
        add(["Math", "LN10"])
        add(["Math", "LN2"])
        add(["Math", "LOG10E"])
        add(["Math", "LOG2E"])
        add(["Math", "PI"])
        add(["Math", "SQRT1_2"])
        add(["Math", "SQRT2"])

        // Math: Static methods
        add(["Math", "abs"])
        add(["Math", "acos"])
        add(["Math", "acosh"])
        add(["Math", "asin"])
        add(["Math", "asinh"])
        add(["Math", "atan"])
        add(["Math", "atan2"])
        add(["Math", "atanh"])
        add(["Math", "cbrt"])
        add(["Math", "ceil"])
        add(["Math", "clz32"])
        add(["Math", "cos"])
        add(["Math", "cosh"])
        add(["Math", "exp"])
        add(["Math", "expm1"])
        add(["Math", "floor"])
        add(["Math", "fround"])
        add(["Math", "hypot"])
        add(["Math", "imul"])
        add(["Math", "log"])
        add(["Math", "log10"])
        add(["Math", "log1p"])
        add(["Math", "log2"])
        add(["Math", "max"])
        add(["Math", "min"])
        add(["Math", "pow"])
        add(["Math", "random"])
        add(["Math", "round"])
        add(["Math", "sign"])
        add(["Math", "sin"])
        add(["Math", "sinh"])
        add(["Math", "sqrt"])
        add(["Math", "tan"])
        add(["Math", "tanh"])
        add(["Math", "trunc"])

        // Number: Static methods
        add(["Number", "isFinite"])
        add(["Number", "isInteger"])
        add(["Number", "isNaN"])
        add(["Number", "isSafeInteger"])
        add(["Number", "parseFloat"])
        add(["Number", "parseInt"])

        // Object: Static methods
        add(["Object", "assign"])
        add(["Object", "create"])
        add(["Object", "defineProperties"])
        add(["Object", "defineProperty"])
        add(["Object", "entries"])
        add(["Object", "freeze"])
        add(["Object", "fromEntries"])
        add(["Object", "getOwnPropertyDescriptor"])
        add(["Object", "getOwnPropertyDescriptors"])
        add(["Object", "getOwnPropertyNames"])
        add(["Object", "getOwnPropertySymbols"])
        add(["Object", "getPrototypeOf"])
        add(["Object", "groupBy"])
        add(["Object", "hasOwn"])
        add(["Object", "is"])
        add(["Object", "isExtensible"])
        add(["Object", "isFrozen"])
        add(["Object", "isSealed"])
        add(["Object", "keys"])
        add(["Object", "preventExtensions"])
        add(["Object", "seal"])
        add(["Object", "setPrototypeOf"])
        add(["Object", "values"])

        // Object: Instance methods
        add(["Object", "prototype", "hasOwnProperty"])
        add(["Object", "prototype", "isPrototypeOf"])
        add(["Object", "prototype", "propertyIsEnumerable"])
        add(["Object", "prototype", "toLocaleString"])
        add(["Object", "prototype", "toString"])
        add(["Object", "prototype", "valueOf"])

        // Reflect: Static methods
        add(["Reflect", "apply"])
        add(["Reflect", "construct"])
        add(["Reflect", "defineProperty"])
        add(["Reflect", "deleteProperty"])
        add(["Reflect", "get"])
        add(["Reflect", "getOwnPropertyDescriptor"])
        add(["Reflect", "getPrototypeOf"])
        add(["Reflect", "has"])
        add(["Reflect", "isExtensible"])
        add(["Reflect", "ownKeys"])
        add(["Reflect", "preventExtensions"])
        add(["Reflect", "set"])
        add(["Reflect", "setPrototypeOf"])

        // Symbol: Static properties
        add(["Symbol", "asyncDispose"])
        add(["Symbol", "asyncIterator"])
        add(["Symbol", "dispose"])
        add(["Symbol", "hasInstance"])
        add(["Symbol", "isConcatSpreadable"])
        add(["Symbol", "iterator"])
        add(["Symbol", "match"])
        add(["Symbol", "matchAll"])
        add(["Symbol", "replace"])
        add(["Symbol", "search"])
        add(["Symbol", "species"])
        add(["Symbol", "split"])
        add(["Symbol", "toPrimitive"])
        add(["Symbol", "toStringTag"])
        add(["Symbol", "unscopables"])

        // Symbol: Static methods
        add(["Symbol", "keyFor"])

        // Console method references
        add(["console", "assert"])
        add(["console", "clear"])
        add(["console", "count"])
        add(["console", "countReset"])
        add(["console", "debug"])
        add(["console", "dir"])
        add(["console", "dirxml"])
        add(["console", "error"])
        add(["console", "group"])
        add(["console", "groupCollapsed"])
        add(["console", "groupEnd"])
        add(["console", "info"])
        add(["console", "log"])
        add(["console", "table"])
        add(["console", "time"])
        add(["console", "timeEnd"])
        add(["console", "timeLog"])
        add(["console", "trace"])
        add(["console", "warn"])

        // Promise
        add(["Promise", "resolve"])
        add(["Promise", "reject"])
        add(["Promise", "all"])

        // Crypto
        add(["crypto", "randomUUID"])
    }

    /// 添加条目
    private func add(path: Array<String>): Unit {
        entries.append(NoSideEffectPropertyAccess(path))
    }

    /// 检查属性访问链是否在无副作用列表中
    // 严格翻译自: defines-table.zig 中的查找逻辑
    public func contains(parts: Array<String>): Bool {
        for (entry in entries) {
            if (entry.matches(parts)) {
                return true
            }
        }
        return false
    }

    /// 检查属性访问链是否在无副作用列表中 (变参版本)
    public func contains(vararg parts: String): Bool {
        let arr = Array<String>()
        for (p in parts) {
            arr.append(p)
        }
        return contains(arr)
    }
}

// ============================================================================
// 全局无副作用函数调用表 (可安全用于 toString)
// 严格翻译自: defines-table.zig:192 global_no_side_effect_function_calls_safe_for_to_string
// ============================================================================

/// 全局无副作用函数调用表
// 严格翻译自: defines-table.zig:192
public class GlobalNoSideEffectFunctionCalls {
    private var entries: ArrayList<NoSideEffectPropertyAccess>

    public init() {
        entries = ArrayList<NoSideEffectPropertyAccess>()
        // Symbol.for("foo") never throws (unless it's a rope string)
        add(["Symbol", "for"])
    }

    private func add(path: Array<String>): Unit {
        entries.append(NoSideEffectPropertyAccess(path))
    }

    /// 检查是否是无副作用函数调用
    public func contains(parts: Array<String>): Bool {
        for (entry in entries) {
            if (entry.matches(parts)) {
                return true
            }
        }
        return false
    }
}

// ============================================================================
// 纯全局标识符值
// 严格翻译自: defines-table.zig:230 PureGlobalIdentifierValue
// ============================================================================

/// 纯全局标识符值类型
// 严格翻译自: defines-table.zig:230 PureGlobalIdentifierValue
public enum PureGlobalIdentifierValue {
    | NaN
    | Infinity
    | StrictUndefined
    | Other

    /// 获取对应的定义值
    // 严格翻译自: defines-table.zig:236 value()
    public func toDefineValue(): DefineData {
        match (this) {
            case NaN => DefineData(
                value: DefineExpr(tag: DefineExprTag.Number, numberValue: Float64.nan),
                flags: DefineFlags()
            )
            case Infinity => DefineData(
                value: DefineExpr(tag: DefineExprTag.Number, numberValue: Float64.positiveInfinity),
                flags: DefineFlags()
            )
            case StrictUndefined => DefineData(
                value: DefineExpr(tag: DefineExprTag.Undefined),
                flags: DefineFlags(valueless: false, canBeRemovedIfUnused: true, callCanBeUnwrappedIfUnused: false, methodCallMustBeReplacedWithUndefined: false)
            )
            case Other => DefineData(
                value: DefineExpr(tag: DefineExprTag.Undefined),
                flags: DefineFlags(valueless: true, canBeRemovedIfUnused: true, callCanBeUnwrappedIfUnused: false, methodCallMustBeReplacedWithUndefined: false)
            )
        }
    }
}

// ============================================================================
// 纯全局标识符映射
// 严格翻译自: defines-table.zig:246 pure_global_identifier_map
// 所有在 JavaScript 环境中存在的全局标识符
// ============================================================================

/// 纯全局标识符映射表
// 严格翻译自: defines-table.zig:246 pure_global_identifier_map
// 用于快速判断一个标识符是否是已知的全局标识符
public class PureGlobalIdentifierMap {
    private var map: HashMap<String, PureGlobalIdentifierValue>

    public init() {
        map = HashMap<String, PureGlobalIdentifierValue>()
        initMap()
    }

    /// 初始化全局标识符映射
    private func initMap(): Unit {
        // 特殊常量
        map.put("NaN", PureGlobalIdentifierValue.NaN)
        map.put("Infinity", PureGlobalIdentifierValue.Infinity)
        map.put("undefined", PureGlobalIdentifierValue.StrictUndefined)

        // ES 内置对象
        map.put("Array", PureGlobalIdentifierValue.Other)
        map.put("Boolean", PureGlobalIdentifierValue.Other)
        map.put("Function", PureGlobalIdentifierValue.Other)
        map.put("Math", PureGlobalIdentifierValue.Other)
        map.put("Number", PureGlobalIdentifierValue.Other)
        map.put("Object", PureGlobalIdentifierValue.Other)
        map.put("RegExp", PureGlobalIdentifierValue.Other)
        map.put("String", PureGlobalIdentifierValue.Other)

        // 通用浏览器/Node 全局对象
        map.put("AbortController", PureGlobalIdentifierValue.Other)
        map.put("AbortSignal", PureGlobalIdentifierValue.Other)
        map.put("AggregateError", PureGlobalIdentifierValue.Other)
        map.put("ArrayBuffer", PureGlobalIdentifierValue.Other)
        map.put("BigInt", PureGlobalIdentifierValue.Other)
        map.put("DataView", PureGlobalIdentifierValue.Other)
        map.put("Date", PureGlobalIdentifierValue.Other)
        map.put("Error", PureGlobalIdentifierValue.Other)
        map.put("EvalError", PureGlobalIdentifierValue.Other)
        map.put("Event", PureGlobalIdentifierValue.Other)
        map.put("EventTarget", PureGlobalIdentifierValue.Other)
        map.put("Float16Array", PureGlobalIdentifierValue.Other)
        map.put("Float32Array", PureGlobalIdentifierValue.Other)
        map.put("Float64Array", PureGlobalIdentifierValue.Other)
        map.put("Int16Array", PureGlobalIdentifierValue.Other)
        map.put("Int32Array", PureGlobalIdentifierValue.Other)
        map.put("Int8Array", PureGlobalIdentifierValue.Other)
        map.put("Intl", PureGlobalIdentifierValue.Other)
        map.put("JSON", PureGlobalIdentifierValue.Other)
        map.put("Map", PureGlobalIdentifierValue.Other)
        map.put("MessageChannel", PureGlobalIdentifierValue.Other)
        map.put("MessageEvent", PureGlobalIdentifierValue.Other)
        map.put("MessagePort", PureGlobalIdentifierValue.Other)
        map.put("Promise", PureGlobalIdentifierValue.Other)
        map.put("Proxy", PureGlobalIdentifierValue.Other)
        map.put("RangeError", PureGlobalIdentifierValue.Other)
        map.put("ReferenceError", PureGlobalIdentifierValue.Other)
        map.put("Reflect", PureGlobalIdentifierValue.Other)
        map.put("Set", PureGlobalIdentifierValue.Other)
        map.put("Symbol", PureGlobalIdentifierValue.Other)
        map.put("SyntaxError", PureGlobalIdentifierValue.Other)
        map.put("TextDecoder", PureGlobalIdentifierValue.Other)
        map.put("TextEncoder", PureGlobalIdentifierValue.Other)
        map.put("TypeError", PureGlobalIdentifierValue.Other)
        map.put("URIError", PureGlobalIdentifierValue.Other)
        map.put("URL", PureGlobalIdentifierValue.Other)
        map.put("URLSearchParams", PureGlobalIdentifierValue.Other)
        map.put("Uint16Array", PureGlobalIdentifierValue.Other)
        map.put("Uint32Array", PureGlobalIdentifierValue.Other)
        map.put("Uint8Array", PureGlobalIdentifierValue.Other)
        map.put("Uint8ClampedArray", PureGlobalIdentifierValue.Other)
        map.put("WeakMap", PureGlobalIdentifierValue.Other)
        map.put("WeakSet", PureGlobalIdentifierValue.Other)
        map.put("WebAssembly", PureGlobalIdentifierValue.Other)

        // 全局函数
        map.put("clearInterval", PureGlobalIdentifierValue.Other)
        map.put("clearTimeout", PureGlobalIdentifierValue.Other)
        map.put("console", PureGlobalIdentifierValue.Other)
        map.put("decodeURI", PureGlobalIdentifierValue.Other)
        map.put("decodeURIComponent", PureGlobalIdentifierValue.Other)
        map.put("encodeURI", PureGlobalIdentifierValue.Other)
        map.put("encodeURIComponent", PureGlobalIdentifierValue.Other)
        map.put("escape", PureGlobalIdentifierValue.Other)
        map.put("globalThis", PureGlobalIdentifierValue.Other)
        map.put("isFinite", PureGlobalIdentifierValue.Other)
        map.put("isNaN", PureGlobalIdentifierValue.Other)
        map.put("parseFloat", PureGlobalIdentifierValue.Other)
        map.put("parseInt", PureGlobalIdentifierValue.Other)
        map.put("queueMicrotask", PureGlobalIdentifierValue.Other)
        map.put("setInterval", PureGlobalIdentifierValue.Other)
        map.put("setTimeout", PureGlobalIdentifierValue.Other)
        map.put("unescape", PureGlobalIdentifierValue.Other)

        // CSSOM APIs
        initCSSOMMap()

        // SVG DOM
        initSVGMap()

        // 其他浏览器 APIs
        initBrowserAPIMap()

        // Node.js 全局对象
        map.put("Buffer", PureGlobalIdentifierValue.Other)
        map.put("process", PureGlobalIdentifierValue.Other)
        map.put("global", PureGlobalIdentifierValue.Other)
        map.put("__dirname", PureGlobalIdentifierValue.Other)
        map.put("__filename", PureGlobalIdentifierValue.Other)
        map.put("exports", PureGlobalIdentifierValue.Other)
        map.put("module", PureGlobalIdentifierValue.Other)
        map.put("require", PureGlobalIdentifierValue.Other)
    }

    /// 初始化 CSSOM APIs
    private func initCSSOMMap(): Unit {
        map.put("CSSAnimation", PureGlobalIdentifierValue.Other)
        map.put("CSSFontFaceRule", PureGlobalIdentifierValue.Other)
        map.put("CSSImportRule", PureGlobalIdentifierValue.Other)
        map.put("CSSKeyframeRule", PureGlobalIdentifierValue.Other)
        map.put("CSSKeyframesRule", PureGlobalIdentifierValue.Other)
        map.put("CSSMediaRule", PureGlobalIdentifierValue.Other)
        map.put("CSSNamespaceRule", PureGlobalIdentifierValue.Other)
        map.put("CSSPageRule", PureGlobalIdentifierValue.Other)
        map.put("CSSRule", PureGlobalIdentifierValue.Other)
        map.put("CSSRuleList", PureGlobalIdentifierValue.Other)
        map.put("CSSStyleDeclaration", PureGlobalIdentifierValue.Other)
        map.put("CSSStyleRule", PureGlobalIdentifierValue.Other)
        map.put("CSSStyleSheet", PureGlobalIdentifierValue.Other)
        map.put("CSSSupportsRule", PureGlobalIdentifierValue.Other)
        map.put("CSSTransition", PureGlobalIdentifierValue.Other)
    }

    /// 初始化 SVG DOM APIs
    private func initSVGMap(): Unit {
        let svgNames = [
            "SVGAElement", "SVGAngle", "SVGAnimateElement",
            "SVGAnimateMotionElement", "SVGAnimateTransformElement",
            "SVGAnimatedAngle", "SVGAnimatedBoolean", "SVGAnimatedEnumeration",
            "SVGAnimatedInteger", "SVGAnimatedLength", "SVGAnimatedLengthList",
            "SVGAnimatedNumber", "SVGAnimatedNumberList",
            "SVGAnimatedPreserveAspectRatio", "SVGAnimatedRect",
            "SVGAnimatedString", "SVGAnimatedTransformList", "SVGAnimationElement",
            "SVGCircleElement", "SVGClipPathElement",
            "SVGComponentTransferFunctionElement", "SVGDefsElement",
            "SVGDescElement", "SVGElement", "SVGEllipseElement",
            "SVGFEBlendElement", "SVGFEColorMatrixElement",
            "SVGFEComponentTransferElement", "SVGFECompositeElement",
            "SVGFEConvolveMatrixElement", "SVGFEDiffuseLightingElement",
            "SVGFEDisplacementMapElement", "SVGFEDistantLightElement",
            "SVGFEDropShadowElement", "SVGFEFloodElement",
            "SVGFEFuncAElement", "SVGFEFuncBElement", "SVGFEFuncGElement",
            "SVGFEFuncRElement", "SVGFEGaussianBlurElement",
            "SVGFEImageElement", "SVGFEMergeElement", "SVGFEMergeNodeElement",
            "SVGFEMorphologyElement", "SVGFEOffsetElement",
            "SVGFEPointLightElement", "SVGFESpecularLightingElement",
            "SVGFESpotLightElement", "SVGFETileElement",
            "SVGFETurbulenceElement", "SVGFilterElement",
            "SVGForeignObjectElement", "SVGGElement", "SVGGeometryElement",
            "SVGGradientElement", "SVGGraphicsElement", "SVGImageElement",
            "SVGLength", "SVGLengthList", "SVGLineElement",
            "SVGLinearGradientElement", "SVGMPathElement", "SVGMarkerElement",
            "SVGMaskElement", "SVGMatrix", "SVGMetadataElement",
            "SVGNumber", "SVGNumberList", "SVGPathElement",
            "SVGPatternElement", "SVGPoint", "SVGPointList",
            "SVGPolygonElement", "SVGPolylineElement",
            "SVGPreserveAspectRatio", "SVGRadialGradientElement",
            "SVGRect", "SVGRectElement", "SVGSVGElement",
            "SVGScriptElement", "SVGSetElement", "SVGStopElement",
            "SVGStringList", "SVGStyleElement", "SVGSwitchElement",
            "SVGSymbolElement", "SVGTSpanElement", "SVGTextContentElement",
            "SVGTextElement", "SVGTextPathElement",
            "SVGTextPositioningElement", "SVGTitleElement", "SVGTransform",
            "SVGTransformList", "SVGUnitTypes", "SVGUseElement",
            "SVGViewElement"
        ]
        for (name in svgNames) {
            map.put(name, PureGlobalIdentifierValue.Other)
        }
    }

    /// 初始化其他浏览器 APIs
    // 严格翻译自: defines-table.zig:463+
    private func initBrowserAPIMap(): Unit {
        let browserNames = [
            "AnalyserNode", "Animation", "AnimationEffect",
            "AnimationEvent", "AnimationPlaybackEvent", "AnimationTimeline",
            "Attr", "Audio", "AudioBuffer", "AudioBufferSourceNode",
            "AudioDestinationNode", "AudioListener", "AudioNode",
            "AudioParam", "AudioProcessingEvent", "AudioScheduledSourceNode",
            "BarProp", "BeforeUnloadEvent", "BiquadFilterNode",
            "Blob", "BlobEvent", "ByteLengthQueuingStrategy",
            "CDATASection", "CSS", "CanvasGradient", "CanvasPattern",
            "CanvasRenderingContext2D", "ChannelMergerNode",
            "ChannelSplitterNode", "CharacterData", "ClipboardEvent",
            "CloseEvent", "Comment", "CompositionEvent", "ConvolverNode",
            "CountQueuingStrategy", "Crypto", "CustomElementRegistry",
            "CustomEvent", "DOMException", "DOMImplementation",
            "DOMMatrix", "DOMMatrixReadOnly", "DOMParser", "DOMPoint",
            "DOMPointReadOnly", "DOMQuad", "DOMRect", "DOMRectList",
            "DOMRectReadOnly", "DOMStringList", "DOMStringMap",
            "DOMTokenList", "DataTransfer", "DataTransferItem",
            "DataTransferItemList", "DelayNode", "Document",
            "DocumentFragment", "DocumentTimeline", "DocumentType",
            "DragEvent", "DynamicsCompressorNode", "Element",
            "ErrorEvent", "EventSource", "File", "FileList",
            "FileReader", "FocusEvent", "FontFace", "FormData",
            "GainNode", "Gamepad", "GamepadButton", "GamepadEvent",
            "Geolocation", "GeolocationPositionError",
            "HTMLAllCollection", "HTMLAnchorElement", "HTMLAreaElement",
            "HTMLAudioElement", "HTMLBRElement", "HTMLBaseElement",
            "HTMLBodyElement", "HTMLButtonElement", "HTMLCanvasElement",
            "HTMLCollection", "HTMLDListElement", "HTMLDataElement",
            "HTMLDataListElement", "HTMLDetailsElement",
            "HTMLDirectoryElement", "HTMLDivElement", "HTMLDocument",
            "HTMLElement", "HTMLEmbedElement", "HTMLFieldSetElement",
            "HTMLFontElement", "HTMLFormControlsCollection",
            "HTMLFormElement", "HTMLFrameElement", "HTMLFrameSetElement",
            "HTMLHRElement", "HTMLHeadElement", "HTMLHeadingElement",
            "HTMLHtmlElement", "HTMLIFrameElement", "HTMLImageElement",
            "HTMLInputElement", "HTMLLIElement", "HTMLLabelElement",
            "HTMLLegendElement", "HTMLLinkElement", "HTMLMapElement",
            "HTMLMarqueeElement", "HTMLMediaElement", "HTMLMenuElement",
            "HTMLMetaElement", "HTMLMeterElement", "HTMLModElement",
            "HTMLOListElement", "HTMLObjectElement", "HTMLOptGroupElement",
            "HTMLOptionElement", "HTMLOptionsCollection", "HTMLOutputElement",
            "HTMLParagraphElement", "HTMLParamElement", "HTMLPictureElement",
            "HTMLPreElement", "HTMLProgressElement", "HTMLQuoteElement",
            "HTMLScriptElement", "HTMLSelectElement", "HTMLSlotElement",
            "HTMLSourceElement", "HTMLSpanElement", "HTMLStyleElement",
            "HTMLTableCaptionElement", "HTMLTableCellElement",
            "HTMLTableColElement", "HTMLTableElement", "HTMLTableRowElement",
            "HTMLTableSectionElement", "HTMLTemplateElement",
            "HTMLTextAreaElement", "HTMLTimeElement", "HTMLTitleElement",
            "HTMLTrackElement", "HTMLUListElement", "HTMLUnknownElement",
            "HTMLVideoElement",
            "HashChangeEvent", "Headers", "History",
            "IDBCursor", "IDBCursorWithValue", "IDBDatabase",
            "IDBFactory", "IDBIndex", "IDBKeyRange", "IDBObjectStore",
            "IDBOpenDBRequest", "IDBRequest", "IDBTransaction",
            "IDBVersionChangeEvent",
            "IIRFilterNode", "Image", "ImageBitmap",
            "ImageBitmapRenderingContext", "ImageData",
            "InputEvent", "KeyboardEvent",
            "Location", "MediaDeviceInfo", "MediaDevices",
            "MediaElementAudioSourceNode", "MediaEncryptedEvent",
            "MediaError", "MediaKeyError", "MediaKeyEvent",
            "MediaKeyMessageEvent", "MediaKeySession",
            "MediaKeyStatusMap", "MediaKeySystemAccess",
            "MediaKeys", "MediaList", "MediaQueryList",
            "MediaQueryListEvent", "MediaRecorder",
            "MediaSettingsRange", "MediaSource",
            "MediaStream", "MediaStreamAudioDestinationNode",
            "MediaStreamAudioSourceNode", "MediaStreamEvent",
            "MediaStreamTrack", "MediaStreamTrackEvent",
            "MessageEvent", "MimeType", "MimeTypeArray",
            "MouseEvent", "MutationEvent", "MutationObserver",
            "MutationRecord",
            "NamedNodeMap", "Navigator", "Node", "NodeFilter",
            "NodeIterator", "NodeList", "Notification",
            "OfflineAudioCompletionEvent", "OfflineAudioContext",
            "OffscreenCanvas", "OffscreenCanvasRenderingContext2D",
            "Option", "OscillatorNode", "OverconstrainedError",
            "PageTransitionEvent", "PannerNode",
            "Path2D", "Performance", "PerformanceEntry",
            "PerformanceMark", "PerformanceMeasure",
            "PerformanceNavigation", "PerformanceObserver",
            "PerformanceObserverEntryList", "PerformanceResourceTiming",
            "PerformanceTiming", "PeriodicWave", "PermissionStatus",
            "Permissions", "Plugin", "PluginArray", "PointerEvent",
            "PopStateEvent", "Presentation",
            "ProcessingInstruction", "ProgressEvent", "PublicKeyCredential",
            "PushManager", "PushSubscription",
            "RTCCertificate", "RTCDataChannel", "RTCDataChannelEvent",
            "RTCDtlsTransport", "RTCIceCandidate", "RTCIceTransport",
            "RTCPeerConnection", "RTCPeerConnectionIceEvent",
            "RTCRtpReceiver", "RTCRtpSender", "RTCRtpTransceiver",
            "RTCSctpTransport", "RTCSessionDescription",
            "RTCStatsReport", "RTCTrackEvent",
            "RadioNodeList", "Range", "ReadableStream",
            "Request", "ResizeObserver", "ResizeObserverEntry",
            "Response",
            "SVGSVGElement", "Screen", "ScriptProcessorNode",
            "SecurityPolicyViolationEvent", "Selection",
            "ServiceWorker", "ServiceWorkerContainer",
            "ServiceWorkerRegistration", "ShadowRoot", "SharedWorker",
            "SourceBuffer", "SourceBufferList", "SpeechSynthesisEvent",
            "SpeechSynthesisUtterance", "StaticRange",
            "StereoPannerNode", "Storage", "StorageEvent",
            "StyleMedia", "StyleSheet", "StyleSheetList",
            "SubtleCrypto", "SyncManager",
            "TaskAttributionTiming", "Text", "TextDecoderStream",
            "TextEncoderStream", "TextEvent", "TextMetrics",
            "TextTrack", "TextTrackCue", "TextTrackCueList",
            "TextTrackList", "TimeRanges", "ToggleEvent",
            "Touch", "TouchEvent", "TouchList",
            "TrackEvent", "Transferable", "TransformStream",
            "TransitionEvent", "TreeWalker",
            "UIEvent", "URL", "URLSearchParams",
            "VTTCue", "ValidityState", "VideoPlaybackQuality",
            "VisualViewport", "WaveShaperNode", "WebGL2RenderingContext",
            "WebGLActiveInfo", "WebGLBuffer",
            "WebGLFramebuffer", "WebGLProgram", "WebGLQuery",
            "WebGLRenderbuffer", "WebGLRenderingContext",
            "WebGLSampler", "WebGLShader", "WebGLShaderPrecisionFormat",
            "WebGLSync", "WebGLTexture", "WebGLTransformFeedback",
            "WebGLUniformLocation", "WebGLVertexArrayObject",
            "WebSocket", "WheelEvent", "Window", "Worker",
            "WritableStream", "XMLDocument", "XMLHttpRequest",
            "XMLHttpRequestEventTarget", "XMLHttpRequestUpload",
            "XMLSerializer", "XPathEvaluator", "XPathExpression",
            "XPathResult", "XSLTProcessor"
        ]
        for (name in browserNames) {
            map.put(name, PureGlobalIdentifierValue.Other)
        }
    }

    /// 获取标识符的纯度值
    // 严格翻译自: defines-table.zig 中查询逻辑
    public func get(name: String): ?PureGlobalIdentifierValue {
        return map.get(name)
    }

    /// 是否包含该标识符
    public func contains(name: String): Bool {
        return map.contains(name)
    }

    /// 标识符数量
    public func size(): Int64 {
        return map.size
    }
}

// ============================================================================
// Define 标志位
// 简化版 DefineData / DefineFlags (引用 defines.cj 中的定义)
// ============================================================================

/// Define 表达式
public class DefineExpr {
    public var tag: DefineExprTag
    public var numberValue: Float64
    public var stringValue: String
    public var boolValue: Bool

    public init(tag: DefineExprTag) {
        this.tag = tag
        this.numberValue = 0.0
        this.stringValue = ""
        this.boolValue = false
    }

    public init(tag: DefineExprTag, numberValue: Float64) {
        this.tag = tag
        this.numberValue = numberValue
        this.stringValue = ""
        this.boolValue = false
    }
}

/// Define 表达式标签
public enum DefineExprTag {
    | Undefined
    | Number
    | String
    | Boolean
    | Identifier
}

/// Define 标志位
public class DefineFlags {
    public var valueless: Bool
    public var canBeRemovedIfUnused: Bool
    public var callCanBeUnwrappedIfUnused: Bool
    public var methodCallMustBeReplacedWithUndefined: Bool

    public init() {
        valueless = false
        canBeRemovedIfUnused = false
        callCanBeUnwrappedIfUnused = false
        methodCallMustBeReplacedWithUndefined = false
    }

    public init(valueless: Bool, canBeRemovedIfUnused: Bool,
                callCanBeUnwrappedIfUnused: Bool,
                methodCallMustBeReplacedWithUndefined: Bool) {
        this.valueless = valueless
        this.canBeRemovedIfUnused = canBeRemovedIfUnused
        this.callCanBeUnwrappedIfUnused = callCanBeUnwrappedIfUnused
        this.methodCallMustBeReplacedWithUndefined = methodCallMustBeReplacedWithUndefined
    }
}

/// Define 数据
public class DefineData {
    public var value: DefineExpr
    public var flags: DefineFlags

    public init() {
        value = DefineExpr(tag: DefineExprTag.Undefined)
        flags = DefineFlags()
    }

    public init(value: DefineExpr, flags: DefineFlags) {
        this.value = value
        this.flags = flags
    }
}
