// 严格翻译自: src/cli/ci_info.zig
package bao_cli

import bao_core.*

// ============================================================================
// CIInfo — CI 环境检测
// 严格翻译自: src/cli/ci_info.zig
// A modified port of ci-info@4.0.0 (https://github.com/watson/ci-info)
// Only gets the CI name, `isPR` is not implemented.
// ============================================================================

/// CI 信息缓存
private var cachedIsCI: ?Bool = None
private var cachedCIName: ?String = None

/// 返回当前进程是否运行在 CI 环境中
/// 对应 Bun: isCI()
public func isCI(): Bool {
    match (cachedIsCI) {
        case Some(v) => return v
        case None => {
            let result = isCIUncached()
            cachedIsCI = Some(result)
            return result
        }
    }
}

/// 返回 CI 名称，如果无法确定则返回 None
/// 注意: 即使 isCI() 为 true, 此函数也可能返回 None
/// 对应 Bun: detectCIName()
public func detectCIName(): ?String {
    match (cachedCIName) {
        case Some(v) => return v
        case None => {
            let result = detectUncached()
            cachedCIName = Some(result)
            return result
        }
    }
}

/// 未缓存的 CI 检测实现
private func isCIUncached(): Bool {
    let ciEnv = Env.get("CI")
    let generatedIsCI = CIInfoGenerated.isCIUncachedGenerated()
    return ciEnv != None || generatedIsCI || detectCIName() != None
}

/// 未缓存的 CI 名称检测实现
private func detectUncached(): ?String {
    let ciEnv = Env.get("CI")
    if (ciEnv == None) {
        return None
    }
    return CIInfoGenerated.detectUncachedGenerated()
}
