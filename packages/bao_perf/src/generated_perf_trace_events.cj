// generated_perf_trace_events - 自动生成的性能追踪事件枚举
// 严格翻译自: bun/src/perf/generated_perf_trace_events.zig (62行)
//   通过 scripts/generate-perf-trace-events.sh 自动生成
//   列出所有可通过 bun.perf.trace() 追踪的性能事件
//
//   Zig: pub const PerfEvent = enum(i32) { @"Bundler.BindImportsToExports", ... }
//   仓颉: public enum PerfEvent { | BundlerBindImportsToExports | ... }
package bao_perf

import bao_core.*

// ============================================================================
// PerfEvent - 性能追踪事件枚举
// 严格翻译自: generated_perf_trace_events.zig - PerfEvent
//   Zig 使用 @"dot.separated.name" 语法表示枚举值
//   仓颉使用 PascalCase 枚举值，保留原始名称通过 name() 方法获取
//   每个 i32 标签值从 0 开始递增
// ============================================================================

/// 性能追踪事件 - 对应 Bun PerfEvent
/// 每个事件对应一个可被 Instruments / perf 追踪的命名称量区间
/// 添加新事件后需运行 scripts/generate-perf-trace-events.sh 更新此列表
public enum PerfEvent {
    // ========================================================================
    // Bundler 事件 - 打包器相关
    // ========================================================================
    | BundlerBindImportsToExports        // @"Bundler.BindImportsToExports"
    | BundlerBreakOutputIntoPieces       // @"Bundler.breakOutputIntoPieces"
    | BundlerCloneAST                    // @"Bundler.cloneAST"
    | BundlerCloneLinkerGraph            // @"Bundler.CloneLinkerGraph"
    | BundlerComputeChunks               // @"Bundler.computeChunks"
    | BundlerCreateNamespaceExports      // @"Bundler.CreateNamespaceExports"
    | BundlerFigureOutCommonJS           // @"Bundler.FigureOutCommonJS"
    | BundlerFindAllImportedPartsInJSOrder  // @"Bundler.findAllImportedPartsInJSOrder"
    | BundlerFindReachableFiles          // @"Bundler.findReachableFiles"
    | BundlerGenerateChunksInParallel    // @"Bundler.generateChunksInParallel"
    | BundlerGenerateCodeForFileInChunkCss  // @"Bundler.generateCodeForFileInChunkCss"
    | BundlerGenerateCodeForFileInChunkJS   // @"Bundler.generateCodeForFileInChunkJS"
    | BundlerGenerateIsolatedHash        // @"Bundler.generateIsolatedHash"
    | BundlerGenerateSourceMapForChunk   // @"Bundler.generateSourceMapForChunk"
    | BundlerMarkFileLiveForTreeShaking  // @"Bundler.markFileLiveForTreeShaking"
    | BundlerMarkFileReachableForCodeSplitting  // @"Bundler.markFileReachableForCodeSplitting"
    | BundlerMatchImportsWithExports     // @"Bundler.MatchImportsWithExports"
    | BundlerOnParseTaskComplete         // @"Bundler.onParseTaskComplete"
    | BundlerParseJS                     // @"Bundler.ParseJS"
    | BundlerParseJSON                   // @"Bundler.ParseJSON"
    | BundlerParseJSON5                  // @"Bundler.ParseJSON5"
    | BundlerParseTOML                   // @"Bundler.ParseTOML"
    | BundlerParseYAML                   // @"Bundler.ParseYAML"
    | BundlerPostProcessJSChunk          // @"Bundler.postProcessJSChunk"
    | BundlerReadFile                    // @"Bundler.readFile"
    | BundlerRenameSymbolsInChunk        // @"Bundler.renameSymbolsInChunk"
    | BundlerResolveExportStarStatements  // @"Bundler.ResolveExportStarStatements"
    | BundlerScanImportsAndExports       // @"Bundler.scanImportsAndExports"
    | BundlerTreeShakingAndCodeSplitting  // @"Bundler.treeShakingAndCodeSplitting"
    | BundlerWorkerCreate                // @"Bundler.Worker.create"
    | BundlerWrapDependencies            // @"Bundler.WrapDependencies"
    | BundlerWriteChunkToDisk            // @"Bundler.writeChunkToDisk"
    | BundlerWriteOutputFilesToDisk      // @"Bundler.writeOutputFilesToDisk"

    // ========================================================================
    // ExtractTarball 事件 - 解压
    // ========================================================================
    | ExtractTarballExtract              // @"ExtractTarball.extract"

    // ========================================================================
    // FolderResolver 事件 - 模块解析
    // ========================================================================
    | FolderResolverReadPackageJSONFromDiskFolder     // @"FolderResolver.readPackageJSONFromDisk.folder"
    | FolderResolverReadPackageJSONFromDiskWorkspace  // @"FolderResolver.readPackageJSONFromDisk.workspace"

    // ========================================================================
    // JSBundler 事件 - JS 打包器插件
    // ========================================================================
    | JSBundlerAddPlugin                 // @"JSBundler.addPlugin"
    | JSBundlerHasAnyMatches             // @"JSBundler.hasAnyMatches"
    | JSBundlerMatchOnLoad               // @"JSBundler.matchOnLoad"
    | JSBundlerMatchOnResolve            // @"JSBundler.matchOnResolve"

    // ========================================================================
    // JSGlobalObject 事件 - JS 全局对象
    // ========================================================================
    | JSGlobalObjectCreate               // @"JSGlobalObject.create"

    // ========================================================================
    // JSParser 事件 - JS 解析器
    // ========================================================================
    | JSParserAnalyze                    // @"JSParser.analyze"
    | JSParserParse                      // @"JSParser.parse"
    | JSParserPostvisit                  // @"JSParser.postvisit"
    | JSParserVisit                      // @"JSParser.visit"

    // ========================================================================
    // JSPrinter 事件 - JS 代码打印
    // ========================================================================
    | JSPrinterPrint                     // @"JSPrinter.print"
    | JSPrinterPrintWithSourceMap        // @"JSPrinter.printWithSourceMap"

    // ========================================================================
    // ModuleResolver 事件 - 模块解析
    // ========================================================================
    | ModuleResolverResolve              // @"ModuleResolver.resolve"

    // ========================================================================
    // PackageInstaller 事件 - 包安装
    // ========================================================================
    | PackageInstallerInstall            // @"PackageInstaller.install"

    // ========================================================================
    // PackageManifest 事件 - 包清单
    // ========================================================================
    | PackageManifestSerializerLoadByFile  // @"PackageManifest.Serializer.loadByFile"
    | PackageManifestSerializerSave       // @"PackageManifest.Serializer.save"

    // ========================================================================
    // RuntimeTranspilerCache 事件 - 运行时转译缓存
    // ========================================================================
    | RuntimeTranspilerCacheFromFile     // @"RuntimeTranspilerCache.fromFile"
    | RuntimeTranspilerCacheSave         // @"RuntimeTranspilerCache.save"
    | RuntimeTranspilerCacheToFile       // @"RuntimeTranspilerCache.toFile"

    // ========================================================================
    // StandaloneModuleGraph 事件 - 独立模块图
    // ========================================================================
    | StandaloneModuleGraphSerialize     // @"StandaloneModuleGraph.serialize"

    // ========================================================================
    // Symbols 事件 - 符号解析
    // ========================================================================
    | SymbolsFollowAll                   // @"Symbols.followAll"

    // ========================================================================
    // TestCommand 事件 - 测试命令
    // ========================================================================
    | TestCommandPrintCodeCoverageLCov            // @"TestCommand.printCodeCoverageLCov"
    | TestCommandPrintCodeCoverageLCovAndText     // @"TestCommand.printCodeCoverageLCovAndText"
    | TestCommandPrintCodeCoverageText            // @"TestCommand.printCodeCoverageText"

    /// 获取对应的 Bun 原始名称 (用于 Linux perf 事件名)
    /// 对应 Zig 的 @tagName() - 返回 @"xxx.yyy" 格式的字符串
    public func tagName(): String {
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

    /// 从整数索引获取事件 - 对应 Zig @intToEnum(PerfEvent, i32)
    public static func fromInt(index: Int64): ?PerfEvent {
        match (index) {
            case 0 => Some(BundlerBindImportsToExports)
            case 1 => Some(BundlerBreakOutputIntoPieces)
            case 2 => Some(BundlerCloneAST)
            case 3 => Some(BundlerCloneLinkerGraph)
            case 4 => Some(BundlerComputeChunks)
            case 5 => Some(BundlerCreateNamespaceExports)
            case 6 => Some(BundlerFigureOutCommonJS)
            case 7 => Some(BundlerFindAllImportedPartsInJSOrder)
            case 8 => Some(BundlerFindReachableFiles)
            case 9 => Some(BundlerGenerateChunksInParallel)
            case 10 => Some(BundlerGenerateCodeForFileInChunkCss)
            case 11 => Some(BundlerGenerateCodeForFileInChunkJS)
            case 12 => Some(BundlerGenerateIsolatedHash)
            case 13 => Some(BundlerGenerateSourceMapForChunk)
            case 14 => Some(BundlerMarkFileLiveForTreeShaking)
            case 15 => Some(BundlerMarkFileReachableForCodeSplitting)
            case 16 => Some(BundlerMatchImportsWithExports)
            case 17 => Some(BundlerOnParseTaskComplete)
            case 18 => Some(BundlerParseJS)
            case 19 => Some(BundlerParseJSON)
            case 20 => Some(BundlerParseJSON5)
            case 21 => Some(BundlerParseTOML)
            case 22 => Some(BundlerParseYAML)
            case 23 => Some(BundlerPostProcessJSChunk)
            case 24 => Some(BundlerReadFile)
            case 25 => Some(BundlerRenameSymbolsInChunk)
            case 26 => Some(BundlerResolveExportStarStatements)
            case 27 => Some(BundlerScanImportsAndExports)
            case 28 => Some(BundlerTreeShakingAndCodeSplitting)
            case 29 => Some(BundlerWorkerCreate)
            case 30 => Some(BundlerWrapDependencies)
            case 31 => Some(BundlerWriteChunkToDisk)
            case 32 => Some(BundlerWriteOutputFilesToDisk)
            case 33 => Some(ExtractTarballExtract)
            case 34 => Some(FolderResolverReadPackageJSONFromDiskFolder)
            case 35 => Some(FolderResolverReadPackageJSONFromDiskWorkspace)
            case 36 => Some(JSBundlerAddPlugin)
            case 37 => Some(JSBundlerHasAnyMatches)
            case 38 => Some(JSBundlerMatchOnLoad)
            case 39 => Some(JSBundlerMatchOnResolve)
            case 40 => Some(JSGlobalObjectCreate)
            case 41 => Some(JSParserAnalyze)
            case 42 => Some(JSParserParse)
            case 43 => Some(JSParserPostvisit)
            case 44 => Some(JSParserVisit)
            case 45 => Some(JSPrinterPrint)
            case 46 => Some(JSPrinterPrintWithSourceMap)
            case 47 => Some(ModuleResolverResolve)
            case 48 => Some(PackageInstallerInstall)
            case 49 => Some(PackageManifestSerializerLoadByFile)
            case 50 => Some(PackageManifestSerializerSave)
            case 51 => Some(RuntimeTranspilerCacheFromFile)
            case 52 => Some(RuntimeTranspilerCacheSave)
            case 53 => Some(RuntimeTranspilerCacheToFile)
            case 54 => Some(StandaloneModuleGraphSerialize)
            case 55 => Some(SymbolsFollowAll)
            case 56 => Some(TestCommandPrintCodeCoverageLCov)
            case 57 => Some(TestCommandPrintCodeCoverageLCovAndText)
            case 58 => Some(TestCommandPrintCodeCoverageText)
            case _ => None
        }
    }

    /// 转为整数值 - 对应 Zig @intFromEnum(PerfEvent)
    public func toInt(): Int64 {
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
