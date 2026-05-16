// Schema types - enum & struct definitions for the bun.schema.api namespace
// Strict translation from: bun/src/api/schema.d.ts, bun/src/api/schema.peechy
//   All enums map to Cangjie enum with toRaw/fromRaw
//   All interfaces map to Cangjie public class with optional (?Type) fields
//   Types already defined in bao_options.schema are re-exported from package.cj

package bao_api

import bao_options.*
import bao_options.*
import bao_core.*
import bao_collections.*

// ============================================================================
// Re-exports from bao_options.schema
// The following types are canonically defined in bao_options::schema and
// re-exported here so that bao_api.* import paths compile:
//   Loader, ResolveMode, MessageLevel, SourceMapMode, SchemaTarget,
//   CssInJsBehavior, JsxRuntime, DotEnvBehavior, FrameworkEntryPointType,
//   FallbackStep, SchemaImportKind, StringMap, LoaderMap, NpmRegistry,
//   BunInstall, JsxConfig, EnvConfig, LoadedEnvConfig, FrameworkEntryPoint,
//   FrameworkEntryPointMap, LoadedFramework, TransformOptions, SchemaLog,
//   SchemaRouter, Problems, FallbackMessageContainer, JsException,
//   SchemaWriter, UnhandledRejectionMode
// ============================================================================

// ============================================================================
// JSXRuntime - JSX runtime enum
// Strict translation from: schema.d.ts - const enum JSXRuntime
//   automatic = 1, classic = 2, solid = 3
// ============================================================================

/// JSX runtime - corresponding to Bun api::JSXRuntime
public enum ApiJsxRuntime {
    | None       // 0
    | Automatic  // 1
    | Classic    // 2
    | Solid      // 3

    public func toRaw(): UInt8 {
        match (this) {
            case None => 0
            case Automatic => 1
            case Classic => 2
            case Solid => 3
        }
    }

    public static func fromRaw(value: UInt8): ApiJsxRuntime {
        match (value) {
            case 0 => ApiJsxRuntime.None
            case 1 => ApiJsxRuntime.Automatic
            case 2 => ApiJsxRuntime.Classic
            case 3 => ApiJsxRuntime.Solid
            case _ => ApiJsxRuntime.None
        }
    }
}

// ============================================================================
// StackFrameScope - stack frame scope enum
// Strict translation from: schema.d.ts - const enum StackFrameScope
//   Eval = 1, Module = 2, Function = 3, Global = 4, Wasm = 5, Constructor = 6
// ============================================================================

/// Stack frame scope - corresponding to Bun api::StackFrameScope
public enum StackFrameScope {
    | None        // 0
    | Eval        // 1
    | Module      // 2
    | Function    // 3
    | Global      // 4
    | Wasm        // 5
    | Constructor // 6

    public func toRaw(): UInt8 {
        match (this) {
            case None => 0
            case Eval => 1
            case Module => 2
            case Function => 3
            case Global => 4
            case Wasm => 5
            case Constructor => 6
        }
    }

    public static func fromRaw(value: UInt8): StackFrameScope {
        match (value) {
            case 0 => StackFrameScope.None
            case 1 => StackFrameScope.Eval
            case 2 => StackFrameScope.Module
            case 3 => StackFrameScope.Function
            case 4 => StackFrameScope.Global
            case 5 => StackFrameScope.Wasm
            case 6 => StackFrameScope.Constructor
            case _ => StackFrameScope.None
        }
    }
}

// ============================================================================
// ScanDependencyMode - scan dependency mode enum
// Strict translation from: schema.d.ts - const enum ScanDependencyMode
//   app = 1, all = 2
// ============================================================================

/// Scan dependency mode - corresponding to Bun api::ScanDependencyMode
public enum ScanDependencyMode {
    | None  // 0
    | App   // 1
    | All   // 2

    public func toRaw(): UInt8 {
        match (this) {
            case None => 0
            case App => 1
            case All => 2
        }
    }

    public static func fromRaw(value: UInt8): ScanDependencyMode {
        match (value) {
            case 0 => ScanDependencyMode.None
            case 1 => ScanDependencyMode.App
            case 2 => ScanDependencyMode.All
            case _ => ScanDependencyMode.None
        }
    }
}

// ============================================================================
// ModuleImportType - module import type enum
// Strict translation from: schema.d.ts - const enum ModuleImportType
//   import = 1, require = 2
// ============================================================================

/// Module import type - corresponding to Bun api::ModuleImportType
public enum ModuleImportType {
    | None    // 0
    | Import  // 1
    | Require // 2

    public func toRaw(): UInt8 {
        match (this) {
            case None => 0
            case Import => 1
            case Require => 2
        }
    }

    public static func fromRaw(value: UInt8): ModuleImportType {
        match (value) {
            case 0 => ModuleImportType.None
            case 1 => ModuleImportType.Import
            case 2 => ModuleImportType.Require
            case _ => ModuleImportType.None
        }
    }
}

// ============================================================================
// TransformResponseStatus - transform response status enum
// Strict translation from: schema.d.ts - const enum TransformResponseStatus
//   success = 1, fail = 2
// ============================================================================

/// Transform response status - corresponding to Bun api::TransformResponseStatus
public enum TransformResponseStatus {
    | None    // 0
    | Success // 1
    | Fail    // 2

    public func toRaw(): UInt32 {
        match (this) {
            case None => 0
            case Success => 1
            case Fail => 2
        }
    }

    public static func fromRaw(value: UInt32): TransformResponseStatus {
        match (value) {
            case 0 => TransformResponseStatus.None
            case 1 => TransformResponseStatus.Success
            case 2 => TransformResponseStatus.Fail
            case _ => TransformResponseStatus.None
        }
    }
}

// ============================================================================
// Reloader - reloader mode enum
// Strict translation from: schema.d.ts - const enum Reloader
//   disable = 1, live = 2, fast_refresh = 3
// ============================================================================

/// Reloader mode - corresponding to Bun api::Reloader
public enum Reloader {
    | None         // 0
    | Disable      // 1
    | Live         // 2
    | FastRefresh  // 3

    public func toRaw(): UInt8 {
        match (this) {
            case None => 0
            case Disable => 1
            case Live => 2
            case FastRefresh => 3
        }
    }

    public static func fromRaw(value: UInt8): Reloader {
        match (value) {
            case 0 => Reloader.None
            case 1 => Reloader.Disable
            case 2 => Reloader.Live
            case 3 => Reloader.FastRefresh
            case _ => Reloader.None
        }
    }
}

// ============================================================================
// WebsocketMessageKind - websocket message kind enum
// Strict translation from: schema.d.ts - const enum WebsocketMessageKind
// ============================================================================

/// Websocket message kind - corresponding to Bun api::WebsocketMessageKind
public enum WebsocketMessageKind {
    | None                              // 0
    | Welcome                           // 1
    | FileChangeNotification            // 2
    | BuildSuccess                      // 3
    | BuildFail                         // 4
    | ManifestSuccess                   // 5
    | ManifestFail                      // 6
    | ResolveFile                       // 7
    | FileChangeNotificationWithHint    // 8

    public func toRaw(): UInt8 {
        match (this) {
            case None => 0
            case Welcome => 1
            case FileChangeNotification => 2
            case BuildSuccess => 3
            case BuildFail => 4
            case ManifestSuccess => 5
            case ManifestFail => 6
            case ResolveFile => 7
            case FileChangeNotificationWithHint => 8
        }
    }

    public static func fromRaw(value: UInt8): WebsocketMessageKind {
        match (value) {
            case 0 => WebsocketMessageKind.None
            case 1 => WebsocketMessageKind.Welcome
            case 2 => WebsocketMessageKind.FileChangeNotification
            case 3 => WebsocketMessageKind.BuildSuccess
            case 4 => WebsocketMessageKind.BuildFail
            case 5 => WebsocketMessageKind.ManifestSuccess
            case 6 => WebsocketMessageKind.ManifestFail
            case 7 => WebsocketMessageKind.ResolveFile
            case 8 => WebsocketMessageKind.FileChangeNotificationWithHint
            case _ => WebsocketMessageKind.None
        }
    }
}

// ============================================================================
// WebsocketCommandKind - websocket command kind enum
// Strict translation from: schema.d.ts - const enum WebsocketCommandKind
// ============================================================================

/// Websocket command kind - corresponding to Bun api::WebsocketCommandKind
public enum WebsocketCommandKind {
    | None             // 0
    | Build            // 1
    | Manifest         // 2
    | BuildWithFilePath // 3

    public func toRaw(): UInt8 {
        match (this) {
            case None => 0
            case Build => 1
            case Manifest => 2
            case BuildWithFilePath => 3
        }
    }

    public static func fromRaw(value: UInt8): WebsocketCommandKind {
        match (value) {
            case 0 => WebsocketCommandKind.None
            case 1 => WebsocketCommandKind.Build
            case 2 => WebsocketCommandKind.Manifest
            case 3 => WebsocketCommandKind.BuildWithFilePath
            case _ => WebsocketCommandKind.None
        }
    }
}

// ============================================================================
// TestKind - test kind enum
// Strict translation from: schema.d.ts - const enum TestKind
//   test_fn = 1, describe_fn = 2
// ============================================================================

/// Test kind - corresponding to Bun api::TestKind
public enum TestKind {
    | None        // 0
    | TestFn      // 1
    | DescribeFn  // 2

    public func toRaw(): UInt8 {
        match (this) {
            case None => 0
            case TestFn => 1
            case DescribeFn => 2
        }
    }

    public static func fromRaw(value: UInt8): TestKind {
        match (value) {
            case 0 => TestKind.None
            case 1 => TestKind.TestFn
            case 2 => TestKind.DescribeFn
            case _ => TestKind.None
        }
    }
}

// ============================================================================
// StackFramePosition - stack frame position struct
// Strict translation from: schema.d.ts - interface StackFramePosition
//   line: int32, column: int32
// ============================================================================

/// Stack frame position - corresponding to Bun api::StackFramePosition
public class StackFramePosition {
    public var line: Int32
    public var column: Int32

    public init() {
        line = 0
        column = 0
    }

    public init(line: Int32, column: Int32) {
        this.line = line
        this.column = column
    }
}

// ============================================================================
// StackFrame - stack frame struct
// Strict translation from: schema.d.ts - interface StackFrame
//   function_name: string, file: string, position: StackFramePosition,
//   scope: StackFrameScope
// ============================================================================

/// Stack frame - corresponding to Bun api::StackFrame
public class StackFrame {
    public var functionName: String
    public var file: String
    public var position: StackFramePosition
    public var scope: StackFrameScope

    public init() {
        functionName = ""
        file = ""
        position = StackFramePosition()
        scope = StackFrameScope.None
    }
}

// ============================================================================
// SourceLine - source line struct
// Strict translation from: schema.d.ts - interface SourceLine
//   line: int32, text: string
// ============================================================================

/// Source line - corresponding to Bun api::SourceLine
public class SourceLine {
    public var line: Int32
    public var text: String

    public init() {
        line = 0
        text = ""
    }

    public init(line: Int32, text: String) {
        this.line = line
        this.text = text
    }
}

// ============================================================================
// StackTrace - stack trace struct
// Strict translation from: schema.d.ts - interface StackTrace
//   source_lines: SourceLine[], frames: StackFrame[]
// ============================================================================

/// Stack trace - corresponding to Bun api::StackTrace
public class StackTrace {
    public var sourceLines: Array<SourceLine>
    public var frames: Array<StackFrame>

    public init() {
        sourceLines = Array<SourceLine>()
        frames = Array<StackFrame>()
    }
}

// ============================================================================
// ApiJsException - JS exception struct
// Strict translation from: schema.d.ts - interface JSException
//   name?: string, message?: string, runtime_type?: uint16,
//   code?: uint8, stack?: StackTrace
// ============================================================================

/// JS exception - corresponding to Bun api::JSException
public class ApiJsException {
    public var name: ?String
    public var message: ?String
    public var runtimeType: ?UInt16
    public var code: ?UInt8
    public var stack: ?StackTrace

    public init() {
        name = None
        message = None
        runtimeType = None
        code = None
        stack = None
    }
}

// ============================================================================
// ApiProblems - problems struct
// Strict translation from: schema.d.ts - interface Problems
//   code: uint16, name: string, exceptions: JSException[], build: Log
// ============================================================================

/// Problems - corresponding to Bun api::Problems
public class ApiProblems {
    public var code: UInt16
    public var name: String
    public var exceptions: Array<ApiJsException>
    public var build: ApiLog

    public init() {
        code = 0
        name = ""
        exceptions = Array<ApiJsException>()
        build = ApiLog()
    }
}

// ============================================================================
// ApiRouter - router struct
// Strict translation from: schema.d.ts - interface Router
//   routes: StringMap, route: int32, params: StringMap
// ============================================================================

/// Router - corresponding to Bun api::Router
public class ApiRouter {
    public var routes: StringMap
    public var route: Int32
    public var params: StringMap

    public init() {
        routes = StringMap()
        route = 0
        params = StringMap()
    }
}

// ============================================================================
// ApiFallbackMessageContainer - fallback message container struct
// Strict translation from: schema.d.ts - interface FallbackMessageContainer
//   message?: string, router?: Router, reason?: FallbackStep,
//   problems?: Problems, cwd?: string
// ============================================================================

/// Fallback message container - corresponding to Bun api::FallbackMessageContainer
public class ApiFallbackMessageContainer {
    public var message: ?String
    public var router: ?ApiRouter
    public var reason: ?FallbackStep
    public var problems: ?ApiProblems
    public var cwd: ?String

    public init() {
        message = None
        router = None
        reason = None
        problems = None
        cwd = None
    }
}

// ============================================================================
// ApiJsx - JSX config struct
// Strict translation from: schema.d.ts - interface JSX
//   factory: string, runtime: JSXRuntime, fragment: string,
//   development: boolean, import_source: string, react_fast_refresh: boolean
// ============================================================================

/// JSX config - corresponding to Bun api::JSX
public class ApiJsx {
    public var factory: String
    public var runtime: ApiJsxRuntime
    public var fragment: String
    public var development: Bool
    public var importSource: String
    public var reactFastRefresh: Bool

    public init() {
        factory = ""
        runtime = ApiJsxRuntime.None
        fragment = ""
        development = false
        importSource = ""
        reactFastRefresh = false
    }
}

// ============================================================================
// StringPointer - string pointer struct
// Strict translation from: schema.d.ts - interface StringPointer
//   offset: uint32, length: uint32
// ============================================================================

/// String pointer - corresponding to Bun api::StringPointer
public class StringPointer {
    public var offset: UInt32
    public var length: UInt32

    public init() {
        offset = 0
        length = 0
    }

    public init(offset: UInt32, length: UInt32) {
        this.offset = offset
        this.length = length
    }
}

// ============================================================================
// JavascriptBundledModule - bundled module struct
// Strict translation from: schema.d.ts - interface JavascriptBundledModule
//   path: StringPointer, code: StringPointer, package_id: uint32,
//   id: uint32, path_extname_length: byte
// ============================================================================

/// Bundled JavaScript module - corresponding to Bun api::JavascriptBundledModule
public class JavascriptBundledModule {
    public var path: StringPointer
    public var code: StringPointer
    public var packageId: UInt32
    public var id: UInt32
    public var pathExtnameLength: UInt8

    public init() {
        path = StringPointer()
        code = StringPointer()
        packageId = 0
        id = 0
        pathExtnameLength = 0
    }
}

// ============================================================================
// JavascriptBundledPackage - bundled package struct
// Strict translation from: schema.d.ts - interface JavascriptBundledPackage
//   name: StringPointer, version: StringPointer, hash: uint32,
//   modules_offset: uint32, modules_length: uint32
// ============================================================================

/// Bundled JavaScript package - corresponding to Bun api::JavascriptBundledPackage
public class JavascriptBundledPackage {
    public var name: StringPointer
    public var version: StringPointer
    public var hash: UInt32
    public var modulesOffset: UInt32
    public var modulesLength: UInt32

    public init() {
        name = StringPointer()
        version = StringPointer()
        hash = 0
        modulesOffset = 0
        modulesLength = 0
    }
}

// ============================================================================
// JavascriptBundle - JavaScript bundle struct
// Strict translation from: schema.d.ts - interface JavascriptBundle
//   modules: JavascriptBundledModule[], packages: JavascriptBundledPackage[],
//   etag: Uint8Array, generated_at: uint32,
//   app_package_json_dependencies_hash: Uint8Array,
//   import_from_name: Uint8Array, manifest_string: Uint8Array
// ============================================================================

/// JavaScript bundle - corresponding to Bun api::JavascriptBundle
public class JavascriptBundle {
    public var modules: Array<JavascriptBundledModule>
    public var packages: Array<JavascriptBundledPackage>
    public var etag: Array<UInt8>
    public var generatedAt: UInt32
    public var appPackageJsonDependenciesHash: Array<UInt8>
    public var importFromName: Array<UInt8>
    public var manifestString: Array<UInt8>

    public init() {
        modules = Array<JavascriptBundledModule>()
        packages = Array<JavascriptBundledPackage>()
        etag = Array<UInt8>()
        generatedAt = 0
        appPackageJsonDependenciesHash = Array<UInt8>()
        importFromName = Array<UInt8>()
        manifestString = Array<UInt8>()
    }
}

// ============================================================================
// LoadedRouteConfig - loaded route config struct
// Strict translation from: schema.d.ts - interface LoadedRouteConfig
//   dir: string, extensions: string[], static_dir: string,
//   asset_prefix: string
// ============================================================================

/// Loaded route config - corresponding to Bun api::LoadedRouteConfig
public class ApiLoadedRouteConfig {
    public var dir: String
    public var extensions: Array<String>
    public var staticDir: String
    public var assetPrefix: String

    public init() {
        dir = ""
        extensions = Array<String>()
        staticDir = ""
        assetPrefix = ""
    }
}

// ============================================================================
// JavascriptBundleContainer - bundle container struct
// Strict translation from: schema.d.ts - interface JavascriptBundleContainer
//   bundle_format_version?: uint32, routes?: LoadedRouteConfig,
//   framework?: LoadedFramework, bundle?: JavascriptBundle,
//   code_length?: uint32
// ============================================================================

/// Bundle container - corresponding to Bun api::JavascriptBundleContainer
public class JavascriptBundleContainer {
    public var bundleFormatVersion: ?UInt32
    public var routes: ?ApiLoadedRouteConfig
    public var framework: ?LoadedFramework
    public var bundle: ?JavascriptBundle
    public var codeLength: ?UInt32

    public init() {
        bundleFormatVersion = None
        routes = None
        framework = None
        bundle = None
        codeLength = None
    }
}

// ============================================================================
// ModuleImportRecord - module import record struct
// Strict translation from: schema.d.ts - interface ModuleImportRecord
//   kind: ModuleImportType, path: string, dynamic: boolean
// ============================================================================

/// Module import record - corresponding to Bun api::ModuleImportRecord
public class ApiModuleImportRecord {
    public var kind: ModuleImportType
    public var path: String
    public var dynamic: Bool

    public init() {
        kind = ModuleImportType.None
        path = ""
        dynamic = false
    }
}

// ============================================================================
// ApiModule - module struct
// Strict translation from: schema.d.ts - interface Module
//   path: string, imports: ModuleImportRecord[]
// ============================================================================

/// Module - corresponding to Bun api::Module
public class ApiModule {
    public var path: String
    public var imports: Array<ApiModuleImportRecord>

    public init() {
        path = ""
        imports = Array<ApiModuleImportRecord>()
    }
}

// ============================================================================
// FrameworkEntryPointMessage - framework entry point message struct
// Strict translation from: schema.d.ts - interface FrameworkEntryPointMessage
//   path?: string, env?: EnvConfig
// ============================================================================

/// Framework entry point message - corresponding to Bun api::FrameworkEntryPointMessage
public class FrameworkEntryPointMessage {
    public var path: ?String
    public var env: ?EnvConfig

    public init() {
        path = None
        env = None
    }
}

// ============================================================================
// ApiFrameworkConfig - framework config struct
// Strict translation from: schema.d.ts - interface FrameworkConfig
//   package?: string, client?: FrameworkEntryPointMessage,
//   server?: FrameworkEntryPointMessage, fallback?: FrameworkEntryPointMessage,
//   development?: boolean, client_css_in_js?: CSSInJSBehavior,
//   display_name?: string, overrideModules?: StringMap
// ============================================================================

/// Framework config - corresponding to Bun api::FrameworkConfig
public class ApiFrameworkConfig {
    public var packageName: ?String
    public var client: ?FrameworkEntryPointMessage
    public var server: ?FrameworkEntryPointMessage
    public var fallback: ?FrameworkEntryPointMessage
    public var development: ?Bool
    public var clientCssInJs: ?CssInJsBehavior
    public var displayName: ?String
    public var overrideModules: ?StringMap

    public init() {
        packageName = None
        client = None
        server = None
        fallback = None
        development = None
        clientCssInJs = None
        displayName = None
        overrideModules = None
    }
}

// ============================================================================
// RouteConfig - route config struct
// Strict translation from: schema.d.ts - interface RouteConfig
//   dir?: string[], extensions?: string[],
//   static_dir?: string, asset_prefix?: string
// ============================================================================

/// Route config - corresponding to Bun api::RouteConfig
public class ApiRouteConfig {
    public var dir: ?Array<String>
    public var extensions: ?Array<String>
    public var staticDir: ?String
    public var assetPrefix: ?String

    public init() {
        dir = None
        extensions = None
        staticDir = None
        assetPrefix = None
    }
}

// ============================================================================
// ApiTransformOptions - transform options struct (message-style, optional fields)
// Strict translation from: schema.d.ts - interface TransformOptions
//   All fields optional, matching the peechy message layout
// ============================================================================

/// Transform options (message-style) - corresponding to Bun api::TransformOptions
public class ApiTransformOptions {
    public var jsx: ?ApiJsx
    public var tsconfigOverride: ?String
    public var resolve: ?ResolveMode
    public var origin: ?String
    public var absoluteWorkingDir: ?String
    public var define: ?StringMap
    public var preserveSymlinks: ?Bool
    public var entryPoints: ?Array<String>
    public var write: ?Bool
    public var inject: ?Array<String>
    public var outputDir: ?String
    public var external: ?Array<String>
    public var loaders: ?LoaderMap
    public var mainFields: ?Array<String>
    public var target: ?SchemaTarget
    public var serve: ?Bool
    public var envFiles: ?Array<String>
    public var extensionOrder: ?Array<String>
    public var framework: ?ApiFrameworkConfig
    public var router: ?ApiRouteConfig
    public var noSummary: ?Bool
    public var disableHmr: ?Bool
    public var port: ?UInt16
    public var logLevel: ?MessageLevel
    public var sourceMap: ?SourceMapMode

    public init() {
        jsx = None
        tsconfigOverride = None
        resolve = None
        origin = None
        absoluteWorkingDir = None
        define = None
        preserveSymlinks = None
        entryPoints = None
        write = None
        inject = None
        outputDir = None
        external = None
        loaders = None
        mainFields = None
        target = None
        serve = None
        envFiles = None
        extensionOrder = None
        framework = None
        router = None
        noSummary = None
        disableHmr = None
        port = None
        logLevel = None
        sourceMap = None
    }
}

// ============================================================================
// FileHandle - file handle struct
// Strict translation from: schema.d.ts - interface FileHandle
//   path: string, size: uint, fd: uint
// ============================================================================

/// File handle - corresponding to Bun api::FileHandle
public class FileHandle {
    public var path: String
    public var size: UInt64
    public var fd: UInt64

    public init() {
        path = ""
        size = 0
        fd = 0
    }
}

// ============================================================================
// ApiTransform - transform message struct
// Strict translation from: schema.d.ts - interface Transform
//   handle?: FileHandle, path?: string, contents?: Uint8Array,
//   loader?: Loader, options?: TransformOptions
// ============================================================================

/// Transform - corresponding to Bun api::Transform
public class ApiTransform {
    public var handle: ?FileHandle
    public var path: ?String
    public var contents: ?Array<UInt8>
    public var loader: ?Loader
    public var options: ?ApiTransformOptions

    public init() {
        handle = None
        path = None
        contents = None
        loader = None
        options = None
    }
}

// ============================================================================
// ApiScan - scan message struct
// Strict translation from: schema.d.ts - interface Scan
//   path?: string, contents?: Uint8Array, loader?: Loader
// ============================================================================

/// Scan - corresponding to Bun api::Scan
public class ApiScan {
    public var path: ?String
    public var contents: ?Array<UInt8>
    public var loader: ?Loader

    public init() {
        path = None
        contents = None
        loader = None
    }
}

// ============================================================================
// ScannedImport - scanned import struct
// Strict translation from: schema.d.ts - interface ScannedImport
//   path: string, kind: ImportKind
// ============================================================================

/// Scanned import - corresponding to Bun api::ScannedImport
public class ScannedImport {
    public var path: String
    public var kind: SchemaImportKind

    public init() {
        path = ""
        kind = SchemaImportKind.None
    }
}

// ============================================================================
// Location - source location struct
// Strict translation from: schema.d.ts - interface Location
//   file: string, namespace: string, line: int32, column: int32,
//   line_text: string, suggestion: string, offset: uint
// ============================================================================

/// Source location - corresponding to Bun api::Location
public class ApiLocation {
    public var file: String
    public var namespace: String
    public var line: Int32
    public var column: Int32
    public var lineText: String
    public var suggestion: String
    public var offset: UInt64

    public init() {
        file = ""
        namespace = ""
        line = 0
        column = 0
        lineText = ""
        suggestion = ""
        offset = 0
    }
}

// ============================================================================
// MessageData - message data struct
// Strict translation from: schema.d.ts - interface MessageData
//   text?: string, location?: Location
// ============================================================================

/// Message data - corresponding to Bun api::MessageData
public class ApiMessageData {
    public var text: ?String
    public var location: ?ApiLocation

    public init() {
        text = None
        location = None
    }
}

// ============================================================================
// MessageMeta - message meta struct
// Strict translation from: schema.d.ts - interface MessageMeta
//   resolve?: string, build?: boolean
// ============================================================================

/// Message meta - corresponding to Bun api::MessageMeta
public class ApiMessageMeta {
    public var resolve: ?String
    public var build: ?Bool

    public init() {
        resolve = None
        build = None
    }
}

// ============================================================================
// ApiMessage - message struct
// Strict translation from: schema.d.ts - interface Message
//   level: MessageLevel, data: MessageData, notes: MessageData[],
//   on: MessageMeta
// ============================================================================

/// Message - corresponding to Bun api::Message
public class ApiMessage {
    public var level: MessageLevel
    public var data: ApiMessageData
    public var notes: Array<ApiMessageData>
    public var on: ApiMessageMeta

    public init() {
        level = MessageLevel.None
        data = ApiMessageData()
        notes = Array<ApiMessageData>()
        on = ApiMessageMeta()
    }
}

// ============================================================================
// ScanResult - scan result struct
// Strict translation from: schema.d.ts - interface ScanResult
//   exports: string[], imports: ScannedImport[], errors: Message[]
// ============================================================================

/// Scan result - corresponding to Bun api::ScanResult
public class ScanResult {
    public var exports: Array<String>
    public var imports: Array<ScannedImport>
    public var errors: Array<ApiMessage>

    public init() {
        exports = Array<String>()
        imports = Array<ScannedImport>()
        errors = Array<ApiMessage>()
    }
}

// ============================================================================
// OutputFile - output file struct
// Strict translation from: schema.d.ts - interface OutputFile
//   data: Uint8Array, path: string
// ============================================================================

/// Output file - corresponding to Bun api::OutputFile
public class OutputFile {
    public var data: Array<UInt8>
    public var path: String

    public init() {
        data = Array<UInt8>()
        path = ""
    }
}

// ============================================================================
// TransformResponse - transform response struct
// Strict translation from: schema.d.ts - interface TransformResponse
//   status: TransformResponseStatus, files: OutputFile[], errors: Message[]
// ============================================================================

/// Transform response - corresponding to Bun api::TransformResponse
public class TransformResponse {
    public var status: TransformResponseStatus
    public var files: Array<OutputFile>
    public var errors: Array<ApiMessage>

    public init() {
        status = TransformResponseStatus.None
        files = Array<OutputFile>()
        errors = Array<ApiMessage>()
    }
}

// ============================================================================
// ApiLog - log struct
// Strict translation from: schema.d.ts - interface Log
//   warnings: uint32, errors: uint32, msgs: Message[]
// ============================================================================

/// Log - corresponding to Bun api::Log
public class ApiLog {
    public var warnings: UInt32
    public var errors: UInt32
    public var msgs: Array<ApiMessage>

    public init() {
        warnings = 0
        errors = 0
        msgs = Array<ApiMessage>()
    }
}

// ============================================================================
// WebsocketMessage - websocket message struct
// Strict translation from: schema.d.ts - interface WebsocketMessage
//   timestamp: uint32, kind: WebsocketMessageKind
// ============================================================================

/// Websocket message - corresponding to Bun api::WebsocketMessage
public class WebsocketMessage {
    public var timestamp: UInt32
    public var kind: WebsocketMessageKind

    public init() {
        timestamp = 0
        kind = WebsocketMessageKind.None
    }
}

// ============================================================================
// WebsocketMessageWelcome - websocket welcome message struct
// Strict translation from: schema.d.ts - interface WebsocketMessageWelcome
//   epoch: uint32, javascriptReloader: Reloader, cwd: string,
//   assetPrefix: string
// ============================================================================

/// Websocket welcome message - corresponding to Bun api::WebsocketMessageWelcome
public class WebsocketMessageWelcome {
    public var epoch: UInt32
    public var javascriptReloader: Reloader
    public var cwd: String
    public var assetPrefix: String

    public init() {
        epoch = 0
        javascriptReloader = Reloader.None
        cwd = ""
        assetPrefix = ""
    }
}

// ============================================================================
// WebsocketMessageFileChangeNotification - file change notification struct
// Strict translation from: schema.d.ts - interface WebsocketMessageFileChangeNotification
//   id: uint32, loader: Loader
// ============================================================================

/// Websocket file change notification
/// Corresponding to Bun api::WebsocketMessageFileChangeNotification
public class WebsocketMessageFileChangeNotification {
    public var id: UInt32
    public var loader: Loader

    public init() {
        id = 0
        loader = Loader.None
    }
}

// ============================================================================
// WebsocketCommand - websocket command struct
// Strict translation from: schema.d.ts - interface WebsocketCommand
//   kind: WebsocketCommandKind, timestamp: uint32
// ============================================================================

/// Websocket command - corresponding to Bun api::WebsocketCommand
public class WebsocketCommand {
    public var kind: WebsocketCommandKind
    public var timestamp: UInt32

    public init() {
        kind = WebsocketCommandKind.None
        timestamp = 0
    }
}

// ============================================================================
// WebsocketCommandBuild - websocket build command struct
// Strict translation from: schema.d.ts - interface WebsocketCommandBuild
//   id: uint32
// ============================================================================

/// Websocket build command - corresponding to Bun api::WebsocketCommandBuild
public class WebsocketCommandBuild {
    public var id: UInt32

    public init() {
        id = 0
    }
}

// ============================================================================
// WebsocketCommandManifest - websocket manifest command struct
// Strict translation from: schema.d.ts - interface WebsocketCommandManifest
//   id: uint32
// ============================================================================

/// Websocket manifest command - corresponding to Bun api::WebsocketCommandManifest
public class WebsocketCommandManifest {
    public var id: UInt32

    public init() {
        id = 0
    }
}

// ============================================================================
// WebsocketMessageBuildSuccess - build success message struct
// Strict translation from: schema.d.ts - interface WebsocketMessageBuildSuccess
//   id: uint32, from_timestamp: uint32, loader: Loader,
//   module_path: string, blob_length: uint32
// ============================================================================

/// Websocket build success message
/// Corresponding to Bun api::WebsocketMessageBuildSuccess
public class WebsocketMessageBuildSuccess {
    public var id: UInt32
    public var fromTimestamp: UInt32
    public var loader: Loader
    public var modulePath: String
    public var blobLength: UInt32

    public init() {
        id = 0
        fromTimestamp = 0
        loader = Loader.None
        modulePath = ""
        blobLength = 0
    }
}

// ============================================================================
// WebsocketMessageBuildFailure - build failure message struct
// Strict translation from: schema.d.ts - interface WebsocketMessageBuildFailure
//   id: uint32, from_timestamp: uint32, loader: Loader,
//   module_path: string, log: Log
// ============================================================================

/// Websocket build failure message
/// Corresponding to Bun api::WebsocketMessageBuildFailure
public class WebsocketMessageBuildFailure {
    public var id: UInt32
    public var fromTimestamp: UInt32
    public var loader: Loader
    public var modulePath: String
    public var log: ApiLog

    public init() {
        id = 0
        fromTimestamp = 0
        loader = Loader.None
        modulePath = ""
        log = ApiLog()
    }
}

// ============================================================================
// WebsocketCommandBuildWithFilePath - build with file path command struct
// Strict translation from: schema.d.ts - interface WebsocketCommandBuildWithFilePath
//   id: uint32, file_path: string
// ============================================================================

/// Websocket build with file path command
/// Corresponding to Bun api::WebsocketCommandBuildWithFilePath
public class WebsocketCommandBuildWithFilePath {
    public var id: UInt32
    public var filePath: String

    public init() {
        id = 0
        filePath = ""
    }
}

// ============================================================================
// WebsocketMessageResolveID - resolve ID message struct
// Strict translation from: schema.d.ts - interface WebsocketMessageResolveID
//   id: uint32
// ============================================================================

/// Websocket resolve ID message
/// Corresponding to Bun api::WebsocketMessageResolveID
public class WebsocketMessageResolveID {
    public var id: UInt32

    public init() {
        id = 0
    }
}

// ============================================================================
// ApiNpmRegistry - NPM registry struct (for codec serialization)
// Strict translation from: schema.d.ts - interface NPMRegistry
//   url: string, username: string, password: string, token: string
// ============================================================================

/// NPM registry - corresponding to Bun api::NPMRegistry
public class ApiNpmRegistry {
    public var url: String
    public var username: String
    public var password: String
    public var token: String

    public init() {
        url = ""
        username = ""
        password = ""
        token = ""
    }
}

// ============================================================================
// ApiNpmRegistryMap - NPM registry map struct (for codec serialization)
// Strict translation from: schema.d.ts - interface NPMRegistryMap
//   scopes: string[], registries: NPMRegistry[]
// ============================================================================

/// NPM registry map - corresponding to Bun api::NPMRegistryMap
public class ApiNpmRegistryMap {
    public var scopes: Array<String>
    public var registries: Array<ApiNpmRegistry>

    public init() {
        scopes = Array<String>()
        registries = Array<ApiNpmRegistry>()
    }
}

// ============================================================================
// ApiBunInstall - Bun install config struct (message-style for codec)
// Strict translation from: schema.d.ts - interface BunInstall
//   All fields optional, matching the peechy message layout
// ============================================================================

/// Bun install config (message-style) - corresponding to Bun api::BunInstall
public class ApiBunInstall {
    public var defaultRegistry: ?ApiNpmRegistry
    public var scoped: ?ApiNpmRegistryMap
    public var lockfilePath: ?String
    public var saveLockfilePath: ?String
    public var cacheDirectory: ?String
    public var dryRun: ?Bool
    public var force: ?Bool
    public var saveDev: ?Bool
    public var saveOptional: ?Bool
    public var savePeer: ?Bool
    public var saveLockfile: ?Bool
    public var production: ?Bool
    public var saveYarnLockfile: ?Bool
    public var nativeBinLinks: ?Array<String>
    public var disableCache: ?Bool
    public var disableManifestCache: ?Bool
    public var globalDir: ?String
    public var globalBinDir: ?String
    public var frozenLockfile: ?Bool
    public var exact: ?Bool
    public var concurrentScripts: ?UInt32

    public init() {
        defaultRegistry = None
        scoped = None
        lockfilePath = None
        saveLockfilePath = None
        cacheDirectory = None
        dryRun = None
        force = None
        saveDev = None
        saveOptional = None
        savePeer = None
        saveLockfile = None
        production = None
        saveYarnLockfile = None
        nativeBinLinks = None
        disableCache = None
        disableManifestCache = None
        globalDir = None
        globalBinDir = None
        frozenLockfile = None
        exact = None
        concurrentScripts = None
    }
}

// ============================================================================
// ClientServerModule - client/server module struct
// Strict translation from: schema.d.ts - interface ClientServerModule
//   moduleId: uint32, inputName: StringPointer, assetName: StringPointer,
//   exportNames: StringPointer
// ============================================================================

/// Client/server module - corresponding to Bun api::ClientServerModule
public class ClientServerModule {
    public var moduleId: UInt32
    public var inputName: StringPointer
    public var assetName: StringPointer
    public var exportNames: StringPointer

    public init() {
        moduleId = 0
        inputName = StringPointer()
        assetName = StringPointer()
        exportNames = StringPointer()
    }
}

// ============================================================================
// ClientServerModuleManifest - module manifest struct
// Strict translation from: schema.d.ts - interface ClientServerModuleManifest
//   version: uint32, clientModules: ClientServerModule[],
//   serverModules: ClientServerModule[], ssrModules: ClientServerModule[],
//   exportNames: StringPointer[], contents: Uint8Array
// ============================================================================

/// Client/server module manifest
/// Corresponding to Bun api::ClientServerModuleManifest
public class ClientServerModuleManifest {
    public var version: UInt32
    public var clientModules: Array<ClientServerModule>
    public var serverModules: Array<ClientServerModule>
    public var ssrModules: Array<ClientServerModule>
    public var exportNames: Array<StringPointer>
    public var contents: Array<UInt8>

    public init() {
        version = 0
        clientModules = Array<ClientServerModule>()
        serverModules = Array<ClientServerModule>()
        ssrModules = Array<ClientServerModule>()
        exportNames = Array<StringPointer>()
        contents = Array<UInt8>()
    }
}

// ============================================================================
// GetTestsRequest - get tests request struct
// Strict translation from: schema.d.ts - interface GetTestsRequest
//   path: string, contents: Uint8Array
// ============================================================================

/// Get tests request - corresponding to Bun api::GetTestsRequest
public class GetTestsRequest {
    public var path: String
    public var contents: Array<UInt8>

    public init() {
        path = ""
        contents = Array<UInt8>()
    }
}

// ============================================================================
// TestResponseItem - test response item struct
// Strict translation from: schema.d.ts - interface TestResponseItem
//   byteOffset: int32, label: StringPointer, kind: TestKind
// ============================================================================

/// Test response item - corresponding to Bun api::TestResponseItem
public class TestResponseItem {
    public var byteOffset: Int32
    public var label: StringPointer
    public var kind: TestKind

    public init() {
        byteOffset = 0
        label = StringPointer()
        kind = TestKind.None
    }
}

// ============================================================================
// GetTestsResponse - get tests response struct
// Strict translation from: schema.d.ts - interface GetTestsResponse
//   tests: TestResponseItem[], contents: Uint8Array
// ============================================================================

/// Get tests response - corresponding to Bun api::GetTestsResponse
public class GetTestsResponse {
    public var tests: Array<TestResponseItem>
    public var contents: Array<UInt8>

    public init() {
        tests = Array<TestResponseItem>()
        contents = Array<UInt8>()
    }
}
