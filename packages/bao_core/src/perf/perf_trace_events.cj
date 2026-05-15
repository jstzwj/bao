// bao_core - 性能追踪事件定义
// 严格翻译自: src/perf/generated_perf_trace_events.zig
//   由 scripts/generate-perf-trace-events.sh 自动生成
//   Bun 的每个 trace() 调用必须对应此枚举中的一个值
package bao_core.perf

/// 性能追踪事件
/// 严格对应 Bun: PerfEvent = enum(i32)
/// 每个事件对应一个系统探针点 (Instruments/Linux trace)
/// 添加新事件后需重新运行 scripts/generate-perf-trace-events.sh
public enum PerfEvent {
    // ========================================================================
    // Bundler 事件
    // 严格对应 Bun: @"Bundler.*" 枚举值
    // ========================================================================
    | BundlerBindImportsToExports             // Bundler.BindImportsToExports
    | BundlerBreakOutputIntoPieces            // Bundler.breakOutputIntoPieces
    | BundlerCloneAST                         // Bundler.cloneAST
    | BundlerCloneLinkerGraph                 // Bundler.CloneLinkerGraph
    | BundlerComputeChunks                    // Bundler.computeChunks
    | BundlerCreateNamespaceExports           // Bundler.CreateNamespaceExports
    | BundlerFigureOutCommonJS                // Bundler.FigureOutCommonJS
    | BundlerFindAllImportedPartsInJSOrder    // Bundler.findAllImportedPartsInJSOrder
    | BundlerFindReachableFiles               // Bundler.findReachableFiles
    | BundlerGenerateChunksInParallel         // Bundler.generateChunksInParallel
    | BundlerGenerateCodeForFileInChunkCss    // Bundler.generateCodeForFileInChunkCss
    | BundlerGenerateCodeForFileInChunkJS     // Bundler.generateCodeForFileInChunkJS
    | BundlerGenerateIsolatedHash             // Bundler.generateIsolatedHash
    | BundlerGenerateSourceMapForChunk        // Bundler.generateSourceMapForChunk
    | BundlerMarkFileLiveForTreeShaking       // Bundler.markFileLiveForTreeShaking
    | BundlerMarkFileReachableForCodeSplitting // Bundler.markFileReachableForCodeSplitting
    | BundlerMatchImportsWithExports          // Bundler.MatchImportsWithExports
    | BundlerOnParseTaskComplete              // Bundler.onParseTaskComplete
    | BundlerParseJS                          // Bundler.ParseJS
    | BundlerParseJSON                        // Bundler.ParseJSON
    | BundlerParseJSON5                       // Bundler.ParseJSON5
    | BundlerParseTOML                        // Bundler.ParseTOML
    | BundlerParseYAML                        // Bundler.ParseYAML
    | BundlerPostProcessJSChunk               // Bundler.postProcessJSChunk
    | BundlerReadFile                         // Bundler.readFile
    | BundlerRenameSymbolsInChunk             // Bundler.renameSymbolsInChunk
    | BundlerResolveExportStarStatements      // Bundler.ResolveExportStarStatements
    | BundlerScanImportsAndExports            // Bundler.scanImportsAndExports
    | BundlerTreeShakingAndCodeSplitting      // Bundler.treeShakingAndCodeSplitting
    | BundlerWorkerCreate                     // Bundler.Worker.create
    | BundlerWrapDependencies                 // Bundler.WrapDependencies
    | BundlerWriteChunkToDisk                 // Bundler.writeChunkToDisk
    | BundlerWriteOutputFilesToDisk           // Bundler.writeOutputFilesToDisk

    // ========================================================================
    // Install 事件
    // ========================================================================
    | ExtractTarballExtract                   // ExtractTarball.extract

    // ========================================================================
    // Resolver 事件
    // ========================================================================
    | FolderResolverReadPackageJSONFromDiskFolder    // FolderResolver.readPackageJSONFromDisk.folder
    | FolderResolverReadPackageJSONFromDiskWorkspace // FolderResolver.readPackageJSONFromDisk.workspace

    // ========================================================================
    // JS Bundler 插件事件
    // ========================================================================
    | JSBundlerAddPlugin                      // JSBundler.addPlugin
    | JSBundlerHasAnyMatches                  // JSBundler.hasAnyMatches
    | JSBundlerMatchOnLoad                    // JSBundler.matchOnLoad
    | JSBundlerMatchOnResolve                 // JSBundler.matchOnResolve

    // ========================================================================
    // JSC / JSGlobalObject 事件
    // ========================================================================
    | JSGlobalObjectCreate                    // JSGlobalObject.create

    // ========================================================================
    // JS 解析器事件
    // ========================================================================
    | JSParserAnalyze                         // JSParser.analyze
    | JSParserParse                           // JSParser.parse
    | JSParserPostvisit                       // JSParser.postvisit
    | JSParserVisit                           // JSParser.visit

    // ========================================================================
    // JS 打印器事件
    // ========================================================================
    | JSPrinterPrint                          // JSPrinter.print
    | JSPrinterPrintWithSourceMap             // JSPrinter.printWithSourceMap

    // ========================================================================
    // 模块解析器事件
    // ========================================================================
    | ModuleResolverResolve                   // ModuleResolver.resolve

    // ========================================================================
    // 包安装器事件
    // ========================================================================
    | PackageInstallerInstall                 // PackageInstaller.install
    | PackageManifestSerializerLoadByFile     // PackageManifest.Serializer.loadByFile
    | PackageManifestSerializerSave           // PackageManifest.Serializer.save

    // ========================================================================
    // 运行时转译器缓存事件
    // ========================================================================
    | RuntimeTranspilerCacheFromFile           // RuntimeTranspilerCache.fromFile
    | RuntimeTranspilerCacheSave               // RuntimeTranspilerCache.save
    | RuntimeTranspilerCacheToFile             // RuntimeTranspilerCache.toFile

    // ========================================================================
    // 独立模块图事件
    // ========================================================================
    | StandaloneModuleGraphSerialize           // StandaloneModuleGraph.serialize

    // ========================================================================
    // 符号解析事件
    // ========================================================================
    | SymbolsFollowAll                        // Symbols.followAll

    // ========================================================================
    // 测试命令事件
    // ========================================================================
    | TestCommandPrintCodeCoverageLCov            // TestCommand.printCodeCoverageLCov
    | TestCommandPrintCodeCoverageLCovAndText     // TestCommand.printCodeCoverageLCovAndText
    | TestCommandPrintCodeCoverageText            // TestCommand.printCodeCoverageText

    /// 获取事件名称字符串
    /// 对应 Bun: @tagName(event) 获取枚举标签名
    public func eventName(): String {
        match (this) {
            case BundlerBindImportsToExports => "Bundler.BindImportsToExports"
            case BundlerBreakOutputIntoPieces => "Bundler.breakOutputIntoPieces"
            case BundlerCloneAST => "Bundler.cloneAST"
            case BundlerCloneLinkerGraph => "Bundler.CloneLinkerGraph"
            case BundlerComputeChunks => "Bundler.computeChunks"
            case BundlerCreateNamespaceExports => "Bundler.CreateNamespaceExports"
            case BundlerFigureOutCommonJS => "Bundler.FigureOutCommonJS"
            case BundlerFindAllImportedPartsInJSOrder => "Bundler.findAllImportedPartsInJSOrder"
            case BundlerFindReachableFiles => "Bundler.findReachableFiles"
            case BundlerGenerateChunksInParallel => "Bundler.generateChunksInParallel"
            case BundlerGenerateCodeForFileInChunkCss => "Bundler.generateCodeForFileInChunkCss"
            case BundlerGenerateCodeForFileInChunkJS => "Bundler.generateCodeForFileInChunkJS"
            case BundlerGenerateIsolatedHash => "Bundler.generateIsolatedHash"
            case BundlerGenerateSourceMapForChunk => "Bundler.generateSourceMapForChunk"
            case BundlerMarkFileLiveForTreeShaking => "Bundler.markFileLiveForTreeShaking"
            case BundlerMarkFileReachableForCodeSplitting => "Bundler.markFileReachableForCodeSplitting"
            case BundlerMatchImportsWithExports => "Bundler.MatchImportsWithExports"
            case BundlerOnParseTaskComplete => "Bundler.onParseTaskComplete"
            case BundlerParseJS => "Bundler.ParseJS"
            case BundlerParseJSON => "Bundler.ParseJSON"
            case BundlerParseJSON5 => "Bundler.ParseJSON5"
            case BundlerParseTOML => "Bundler.ParseTOML"
            case BundlerParseYAML => "Bundler.ParseYAML"
            case BundlerPostProcessJSChunk => "Bundler.postProcessJSChunk"
            case BundlerReadFile => "Bundler.readFile"
            case BundlerRenameSymbolsInChunk => "Bundler.renameSymbolsInChunk"
            case BundlerResolveExportStarStatements => "Bundler.ResolveExportStarStatements"
            case BundlerScanImportsAndExports => "Bundler.scanImportsAndExports"
            case BundlerTreeShakingAndCodeSplitting => "Bundler.treeShakingAndCodeSplitting"
            case BundlerWorkerCreate => "Bundler.Worker.create"
            case BundlerWrapDependencies => "Bundler.WrapDependencies"
            case BundlerWriteChunkToDisk => "Bundler.writeChunkToDisk"
            case BundlerWriteOutputFilesToDisk => "Bundler.writeOutputFilesToDisk"
            case ExtractTarballExtract => "ExtractTarball.extract"
            case FolderResolverReadPackageJSONFromDiskFolder => "FolderResolver.readPackageJSONFromDisk.folder"
            case FolderResolverReadPackageJSONFromDiskWorkspace => "FolderResolver.readPackageJSONFromDisk.workspace"
            case JSBundlerAddPlugin => "JSBundler.addPlugin"
            case JSBundlerHasAnyMatches => "JSBundler.hasAnyMatches"
            case JSBundlerMatchOnLoad => "JSBundler.matchOnLoad"
            case JSBundlerMatchOnResolve => "JSBundler.matchOnResolve"
            case JSGlobalObjectCreate => "JSGlobalObject.create"
            case JSParserAnalyze => "JSParser.analyze"
            case JSParserParse => "JSParser.parse"
            case JSParserPostvisit => "JSParser.postvisit"
            case JSParserVisit => "JSParser.visit"
            case JSPrinterPrint => "JSPrinter.print"
            case JSPrinterPrintWithSourceMap => "JSPrinter.printWithSourceMap"
            case ModuleResolverResolve => "ModuleResolver.resolve"
            case PackageInstallerInstall => "PackageInstaller.install"
            case PackageManifestSerializerLoadByFile => "PackageManifest.Serializer.loadByFile"
            case PackageManifestSerializerSave => "PackageManifest.Serializer.save"
            case RuntimeTranspilerCacheFromFile => "RuntimeTranspilerCache.fromFile"
            case RuntimeTranspilerCacheSave => "RuntimeTranspilerCache.save"
            case RuntimeTranspilerCacheToFile => "RuntimeTranspilerCache.toFile"
            case StandaloneModuleGraphSerialize => "StandaloneModuleGraph.serialize"
            case SymbolsFollowAll => "Symbols.followAll"
            case TestCommandPrintCodeCoverageLCov => "TestCommand.printCodeCoverageLCov"
            case TestCommandPrintCodeCoverageLCovAndText => "TestCommand.printCodeCoverageLCovAndText"
            case TestCommandPrintCodeCoverageText => "TestCommand.printCodeCoverageText"
        }
    }

    /// 从名称字符串解析事件
    /// 对应 Bun: ComptimeStringMap 查找
    public static func fromName(name: String): ?PerfEvent {
        // Bundler 事件
        if (name == "Bundler.BindImportsToExports") { return BundlerBindImportsToExports }
        if (name == "Bundler.breakOutputIntoPieces") { return BundlerBreakOutputIntoPieces }
        if (name == "Bundler.cloneAST") { return BundlerCloneAST }
        if (name == "Bundler.CloneLinkerGraph") { return BundlerCloneLinkerGraph }
        if (name == "Bundler.computeChunks") { return BundlerComputeChunks }
        if (name == "Bundler.CreateNamespaceExports") { return BundlerCreateNamespaceExports }
        if (name == "Bundler.FigureOutCommonJS") { return BundlerFigureOutCommonJS }
        if (name == "Bundler.findAllImportedPartsInJSOrder") { return BundlerFindAllImportedPartsInJSOrder }
        if (name == "Bundler.findReachableFiles") { return BundlerFindReachableFiles }
        if (name == "Bundler.generateChunksInParallel") { return BundlerGenerateChunksInParallel }
        if (name == "Bundler.generateCodeForFileInChunkCss") { return BundlerGenerateCodeForFileInChunkCss }
        if (name == "Bundler.generateCodeForFileInChunkJS") { return BundlerGenerateCodeForFileInChunkJS }
        if (name == "Bundler.generateIsolatedHash") { return BundlerGenerateIsolatedHash }
        if (name == "Bundler.generateSourceMapForChunk") { return BundlerGenerateSourceMapForChunk }
        if (name == "Bundler.markFileLiveForTreeShaking") { return BundlerMarkFileLiveForTreeShaking }
        if (name == "Bundler.markFileReachableForCodeSplitting") { return BundlerMarkFileReachableForCodeSplitting }
        if (name == "Bundler.MatchImportsWithExports") { return BundlerMatchImportsWithExports }
        if (name == "Bundler.onParseTaskComplete") { return BundlerOnParseTaskComplete }
        if (name == "Bundler.ParseJS") { return BundlerParseJS }
        if (name == "Bundler.ParseJSON") { return BundlerParseJSON }
        if (name == "Bundler.ParseJSON5") { return BundlerParseJSON5 }
        if (name == "Bundler.ParseTOML") { return BundlerParseTOML }
        if (name == "Bundler.ParseYAML") { return BundlerParseYAML }
        if (name == "Bundler.postProcessJSChunk") { return BundlerPostProcessJSChunk }
        if (name == "Bundler.readFile") { return BundlerReadFile }
        if (name == "Bundler.renameSymbolsInChunk") { return BundlerRenameSymbolsInChunk }
        if (name == "Bundler.ResolveExportStarStatements") { return BundlerResolveExportStarStatements }
        if (name == "Bundler.scanImportsAndExports") { return BundlerScanImportsAndExports }
        if (name == "Bundler.treeShakingAndCodeSplitting") { return BundlerTreeShakingAndCodeSplitting }
        if (name == "Bundler.Worker.create") { return BundlerWorkerCreate }
        if (name == "Bundler.WrapDependencies") { return BundlerWrapDependencies }
        if (name == "Bundler.writeChunkToDisk") { return BundlerWriteChunkToDisk }
        if (name == "Bundler.writeOutputFilesToDisk") { return BundlerWriteOutputFilesToDisk }
        // Install 事件
        if (name == "ExtractTarball.extract") { return ExtractTarballExtract }
        // Resolver 事件
        if (name == "FolderResolver.readPackageJSONFromDisk.folder") { return FolderResolverReadPackageJSONFromDiskFolder }
        if (name == "FolderResolver.readPackageJSONFromDisk.workspace") { return FolderResolverReadPackageJSONFromDiskWorkspace }
        // JS Bundler 插件事件
        if (name == "JSBundler.addPlugin") { return JSBundlerAddPlugin }
        if (name == "JSBundler.hasAnyMatches") { return JSBundlerHasAnyMatches }
        if (name == "JSBundler.matchOnLoad") { return JSBundlerMatchOnLoad }
        if (name == "JSBundler.matchOnResolve") { return JSBundlerMatchOnResolve }
        // JSC 事件
        if (name == "JSGlobalObject.create") { return JSGlobalObjectCreate }
        // JS 解析器事件
        if (name == "JSParser.analyze") { return JSParserAnalyze }
        if (name == "JSParser.parse") { return JSParserParse }
        if (name == "JSParser.postvisit") { return JSParserPostvisit }
        if (name == "JSParser.visit") { return JSParserVisit }
        // JS 打印器事件
        if (name == "JSPrinter.print") { return JSPrinterPrint }
        if (name == "JSPrinter.printWithSourceMap") { return JSPrinterPrintWithSourceMap }
        // 模块解析器事件
        if (name == "ModuleResolver.resolve") { return ModuleResolverResolve }
        // 包安装器事件
        if (name == "PackageInstaller.install") { return PackageInstallerInstall }
        if (name == "PackageManifest.Serializer.loadByFile") { return PackageManifestSerializerLoadByFile }
        if (name == "PackageManifest.Serializer.save") { return PackageManifestSerializerSave }
        // 运行时转译器缓存事件
        if (name == "RuntimeTranspilerCache.fromFile") { return RuntimeTranspilerCacheFromFile }
        if (name == "RuntimeTranspilerCache.save") { return RuntimeTranspilerCacheSave }
        if (name == "RuntimeTranspilerCache.toFile") { return RuntimeTranspilerCacheToFile }
        // 独立模块图事件
        if (name == "StandaloneModuleGraph.serialize") { return StandaloneModuleGraphSerialize }
        // 符号解析事件
        if (name == "Symbols.followAll") { return SymbolsFollowAll }
        // 测试命令事件
        if (name == "TestCommand.printCodeCoverageLCov") { return TestCommandPrintCodeCoverageLCov }
        if (name == "TestCommand.printCodeCoverageLCovAndText") { return TestCommandPrintCodeCoverageLCovAndText }
        if (name == "TestCommand.printCodeCoverageText") { return TestCommandPrintCodeCoverageText }
        return None
    }

    /// 整数值 (对应 Bun: @intFromEnum(event))
    /// 用于传递给系统探针 API
    public func toInt(): Int32 {
        match (this) {
            case BundlerBindImportsToExports => 0
            case BundlerBreakOutputIntoPieces => 1
            case BundlerCloneAST => 2
            case BundlerCloneLinkerGraph => 3
            case BundlerComputeChunks => 4
            case BundlerCreateNamespaceExports => 5
            case BundlerFigureOutCommonJS => 6
            case BundlerFindAllImportedPartsInJSOrder => 7
            case BundlerFindReachableFiles => 8
            case BundlerGenerateChunksInParallel => 9
            case BundlerGenerateCodeForFileInChunkCss => 10
            case BundlerGenerateCodeForFileInChunkJS => 11
            case BundlerGenerateIsolatedHash => 12
            case BundlerGenerateSourceMapForChunk => 13
            case BundlerMarkFileLiveForTreeShaking => 14
            case BundlerMarkFileReachableForCodeSplitting => 15
            case BundlerMatchImportsWithExports => 16
            case BundlerOnParseTaskComplete => 17
            case BundlerParseJS => 18
            case BundlerParseJSON => 19
            case BundlerParseJSON5 => 20
            case BundlerParseTOML => 21
            case BundlerParseYAML => 22
            case BundlerPostProcessJSChunk => 23
            case BundlerReadFile => 24
            case BundlerRenameSymbolsInChunk => 25
            case BundlerResolveExportStarStatements => 26
            case BundlerScanImportsAndExports => 27
            case BundlerTreeShakingAndCodeSplitting => 28
            case BundlerWorkerCreate => 29
            case BundlerWrapDependencies => 30
            case BundlerWriteChunkToDisk => 31
            case BundlerWriteOutputFilesToDisk => 32
            case ExtractTarballExtract => 33
            case FolderResolverReadPackageJSONFromDiskFolder => 34
            case FolderResolverReadPackageJSONFromDiskWorkspace => 35
            case JSBundlerAddPlugin => 36
            case JSBundlerHasAnyMatches => 37
            case JSBundlerMatchOnLoad => 38
            case JSBundlerMatchOnResolve => 39
            case JSGlobalObjectCreate => 40
            case JSParserAnalyze => 41
            case JSParserParse => 42
            case JSParserPostvisit => 43
            case JSParserVisit => 44
            case JSPrinterPrint => 45
            case JSPrinterPrintWithSourceMap => 46
            case ModuleResolverResolve => 47
            case PackageInstallerInstall => 48
            case PackageManifestSerializerLoadByFile => 49
            case PackageManifestSerializerSave => 50
            case RuntimeTranspilerCacheFromFile => 51
            case RuntimeTranspilerCacheSave => 52
            case RuntimeTranspilerCacheToFile => 53
            case StandaloneModuleGraphSerialize => 54
            case SymbolsFollowAll => 55
            case TestCommandPrintCodeCoverageLCov => 56
            case TestCommandPrintCodeCoverageLCovAndText => 57
            case TestCommandPrintCodeCoverageText => 58
        }
    }
}
