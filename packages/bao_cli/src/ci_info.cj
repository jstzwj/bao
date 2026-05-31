// 严格翻译自: src/cli/ci_info.zig
package bao_cli

import bao_core.*

// ============================================================================
// CIInfo — CI 环境检测
// 严格翻译自: src/cli/ci_info.zig
// A modified port of ci-info@4.0.0 (https://github.com/watson/ci-info)
// Bun upstream only generates CI name detection here; isPR intentionally returns false.
// ============================================================================

/// CI 信息缓存
private var cachedIsCI: ?Bool = None
private var cachedCIName: ?String = None
private var cachedIsPR: ?Bool = None

/// 返回当前进程是否运行在 CI 环境中
/// 对应 Bun: isCI()
public func isCI(): Bool {
    match (cachedIsCI) {
        case Some(v) => return v
        case None =>
            let result = isCIUncached()
            cachedIsCI = Some(result)
            return result
    }
}

/// 返回 CI 名称，如果无法确定则返回 None
/// 注意: 即使 isCI() 为 true, 此函数也可能返回 None
/// 对应 Bun: detectCIName()
public func detectCIName(): ?String {
    match (cachedCIName) {
        case Some(v) => return v
        case None =>
            let result = detectUncached()
            cachedCIName = result
            return result
    }
}

/// 返回当前 CI 运行是否为 Pull Request
/// Bun 上游 ci_info.zig/codegen 当前只生成 CI 名称检测, 注释明确 `isPR` 未实现。
/// 这里保留同等语义: 不尝试推断 PR, 始终返回 false 并缓存结果。
public func isPR(): Bool {
    match (cachedIsPR) {
        case Some(v) => return v
        case None =>
            let result = false
            cachedIsPR = Some(result)
            return result
    }
}

/// 未缓存的 CI 检测实现
/// 对应 Bun: ci_info.rs is_ci_uncached()
/// 如果 CI env 为 false 字符串则不检测 (与 Bun detect_uncached 一致)
private func isCIUncached(): Bool {
    // 先检查 CI 环境变量是否被显式设为 "false" — 如果是则跳过
    match (Env.get("CI")) {
        case Some(v) =>
            if (v == "false") {
                return false
            }
        case None => ()
    }
    return isCIUncachedGenerated() || detectCIName().isSome()
}

/// 未缓存的 CI 名称检测实现
/// 严格翻译自 Bun ci_info_generated::detect_uncached_generated()
/// 由 src/codegen/ci_info.ts 生成 (vendors 列表)
private func detectUncached(): ?String {
    let ciEnv = Env.get("CI")
    if (ciEnv.isNone()) {
        return None
    }

    // 严格按 Bun vendors 顺序检测 (与 ci_info.ts / mod.rs ci_info_generated 同步)
    if (envIsSet("AGOLA_GIT_REF"))                          { return "agola-ci" }
    if (envIsSet("AC_APPCIRCLE"))                            { return "appcircle" }
    if (envIsSet("APPVEYOR"))                                { return "appveyor" }
    if (envIsSet("CODEBUILD_BUILD_ARN"))                     { return "aws-codebuild" }
    if (envIsSet("TF_BUILD"))                                { return "azure-pipelines" }
    if (envIsSet("bamboo_planKey"))                          { return "bamboo" }
    if (envIsSet("BITBUCKET_COMMIT"))                        { return "bitbucket-pipelines" }
    if (envIsSet("BITRISE_IO"))                              { return "bitrise" }
    if (envIsSet("BUDDY_WORKSPACE_ID"))                      { return "buddy" }
    if (envIsSet("BUILDKITE"))                               { return "buildkite" }
    if (envIsSet("CIRCLECI"))                                { return "circleci" }
    if (envIsSet("CIRRUS_CI"))                               { return "cirrus-ci" }
    if (envIsSet("CF_PAGES"))                                { return "cloudflare-pages" }
    if (envIsSet("WORKERS_CI"))                              { return "cloudflare-workers" }
    if (envIsSet("CF_BUILD_ID"))                             { return "codefresh" }
    if (envIsSet("CM_BUILD_ID"))                             { return "codemagic" }
    if (envEquals("CI_NAME", "codeship"))                    { return "codeship" }
    if (envIsSet("DRONE"))                                   { return "drone" }
    if (envIsSet("DSARI"))                                   { return "dsari" }
    if (envIsSet("EARTHLY_CI"))                              { return "earthly" }
    if (envIsSet("EAS_BUILD"))                               { return "expo-application-services" }
    if (envIsSet("GERRIT_PROJECT"))                          { return "gerrit" }
    if (envIsSet("GITEA_ACTIONS"))                           { return "gitea-actions" }
    if (envIsSet("GITHUB_ACTIONS"))                          { return "github-actions" }
    if (envIsSet("GITLAB_CI"))                               { return "gitlab-ci" }
    if (envIsSet("GO_PIPELINE_LABEL"))                       { return "gocd" }
    if (envIsSet("BUILDER_OUTPUT"))                          { return "google-cloud-build" }
    if (envIsSet("HARNESS_BUILD_ID"))                        { return "harness-ci" }
    if (envContains("NODE", "/app/.heroku/node/bin/node"))   { return "heroku" }
    if (envIsSet("HUDSON_URL"))                              { return "hudson" }
    if (envIsSet("JENKINS_URL") && envIsSet("BUILD_ID"))     { return "jenkins" }
    if (envIsSet("LAYERCI"))                                 { return "layerci" }
    if (envIsSet("MAGNUM"))                                  { return "magnum-ci" }
    if (envIsSet("NETLIFY"))                                 { return "netlify-ci" }
    if (envIsSet("NEVERCODE"))                               { return "nevercode" }
    if (envIsSet("PROW_JOB_ID"))                             { return "prow" }
    if (envIsSet("RELEASE_BUILD_ID"))                        { return "releasehub" }
    if (envIsSet("RENDER"))                                  { return "render" }
    if (envIsSet("SAILCI"))                                  { return "sail-ci" }
    if (envIsSet("SCREWDRIVER"))                             { return "screwdriver" }
    if (envIsSet("SEMAPHORE"))                               { return "semaphore" }
    if (envEquals("CI_NAME", "sourcehut"))                   { return "sourcehut" }
    if (envIsSet("STRIDER"))                                 { return "strider-cd" }
    if (envIsSet("TASK_ID") && envIsSet("RUN_ID"))           { return "taskcluster" }
    if (envIsSet("TEAMCITY_VERSION"))                        { return "teamcity" }
    if (envIsSet("TRAVIS"))                                  { return "travis-ci" }
    if (envIsSet("VELA"))                                    { return "vela" }
    if (envIsSet("NOW_BUILDER") || envIsSet("VERCEL"))       { return "vercel" }
    if (envIsSet("APPCENTER_BUILD_ID"))                      { return "visual-studio-app-center" }
    if (envEquals("CI", "woodpecker"))                       { return "woodpecker" }
    if (envIsSet("CI_XCODE_PROJECT"))                        { return "xcode-cloud" }
    if (envIsSet("XCS"))                                     { return "xcode-server" }
    return None
}

/// 未缓存的 CI 检测 — 额外 env 变量检测
/// 对应 Bun ci_info_generated::is_ci_uncached_generated()
/// 检测 extras 列表中的环境变量
private func isCIUncachedGenerated(): Bool {
    if (envIsSet("BUILD_ID"))              { return true }
    if (envIsSet("BUILD_NUMBER"))          { return true }
    if (envIsSet("CI"))                    { return true }
    if (envIsSet("CI_APP_ID"))             { return true }
    if (envIsSet("CI_BUILD_ID"))           { return true }
    if (envIsSet("CI_BUILD_NUMBER"))       { return true }
    if (envIsSet("CI_NAME"))               { return true }
    if (envIsSet("CONTINUOUS_INTEGRATION")) { return true }
    if (envIsSet("RUN_ID"))                { return true }
    return false
}

// ============================================================================
// 环境变量辅助函数
// ============================================================================

/// 检查环境变量是否已设置 (非空)
/// 对应 Bun: env_set!("KEY") / bun.getenvZ("KEY") != null
private func envIsSet(key: String): Bool {
    return Env.get(key).isSome()
}

/// 检查环境变量值是否等于指定字符串
/// 对应 Bun: env_eq!("KEY", "VALUE")
private func envEquals(key: String, value: String): Bool {
    match (Env.get(key)) {
        case Some(v) => return v == value
        case None => return false
    }
}

/// 检查环境变量值是否包含指定子串
/// 对应 Bun: env_contains!("KEY", "NEEDLE")
private func envContains(key: String, needle: String): Bool {
    match (Env.get(key)) {
        case Some(v) => return v.contains(needle)
        case None => return false
    }
}
