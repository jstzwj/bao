// fixtures.cj - 测试夹具工具
// 严格翻译自 bun/src/runtime/test_runner/harness/fixtures.zig

package bao_runtime.test_runner.harness

import std.collection.HashMap

// ========== Fixtures - 测试夹具 ==========

/// 测试夹具映射 - 内嵌文件内容
public class Fixtures {
    /// 包配置文件
    public static let packageJson: String = "{\n  \"name\": \"test-fixture\",\n  \"version\": \"1.0.0\"\n}\n"

    /// TypeScript配置文件
    public static let tsconfigJson: String = "{\n  \"compilerOptions\": {\n    \"target\": \"ESNext\"\n  }\n}\n"

    /// 简单组件JS
    public static let simpleComponentJs: String = "export default function Component() {\n  return \"hello\";\n}\n"

    /// 简单组件TSX
    public static let simpleComponentTsx: String = "export default function Component(): JSX.Element {\n  return <div>hello</div>;\n}\n"

    /// 获取夹具内容
    public static func get(name: String): ?String {
        match (name) {
            case "package.json" => return packageJson
            case "tsconfig.json" => return tsconfigJson
            case "simple-component.js" => return simpleComponentJs
            case "simple-component.tsx" => return simpleComponentTsx
            case _ => return None
        }
    }

    /// 示例路由列表 - 用于测试路由匹配
    public static func getSampleRouteList(): HashMap<String, String> {
        let map = HashMap<String, String>()
        map["pages/[...catch-all-at-root].js"] = "//pages/[...catch-all-at-root].js"
        map["pages/index.js"] = "//pages/index.js"
        map["pages/Foo.js"] = "//pages/Foo.js"
        map["pages/[TitleCaseParam].js"] = "//pages/[TitleCaseParam].js"
        map["pages/[TitleCaseParam]/file.js"] = "//pages/[TitleCaseParam]/file.js"
        map["pages/[TitleCaseParam]/[snake_case_param].js"] = "//pages/[TitleCaseParam]/[snake_case_param].js"
        map["pages/[TitleCaseParam]/[snake_case_param]/file.js"] = "//pages/[TitleCaseParam]/[snake_case_param]/file.js"
        map["pages/[TitleCaseParam]/[snake_case_param]/bacon/index.js"] = "//pages/[TitleCaseParam]/[snake_case_param]/bacon/index.js"
        return map
    }

    /// GitHub API路由列表 - 用于测试复杂路由匹配
    public static func getGithubApiRoutesList(): HashMap<String, String> {
        let map = HashMap<String, String>()
        map["pages/index.js"] = "//pages/index.js"
        map["pages/app.js"] = "//pages/app.js"
        map["pages/app/installations.js"] = "//pages/app/installations.js"
        map["pages/app/installations/[installation_id].js"] = "//pages/app/installations/[installation_id].js"
        map["pages/apps/[app_slug].js"] = "//pages/apps/[app_slug].js"
        map["pages/codes_of_conduct.js"] = "//pages/codes_of_conduct.js"
        map["pages/codes_of_conduct/[key].js"] = "//pages/codes_of_conduct/[key].js"
        map["pages/emojis.js"] = "//pages/emojis.js"
        map["pages/events.js"] = "//pages/events.js"
        map["pages/feeds.js"] = "//pages/feeds.js"
        map["pages/gitignore/templates.js"] = "//pages/gitignore/templates.js"
        map["pages/gitignore/templates/[name].js"] = "//pages/gitignore/templates/[name].js"
        map["pages/installation/repositories.js"] = "//pages/installation/repositories.js"
        map["pages/licenses.js"] = "//pages/licenses.js"
        map["pages/licenses/[license].js"] = "//pages/licenses/[license].js"
        map["pages/meta.js"] = "//pages/meta.js"
        map["pages/octocat.js"] = "//pages/octocat.js"
        map["pages/organizations.js"] = "//pages/organizations.js"
        map["pages/rate_limit.js"] = "//pages/rate_limit.js"
        map["pages/repositories.js"] = "//pages/repositories.js"
        map["pages/search/code.js"] = "//pages/search/code.js"
        map["pages/search/commits.js"] = "//pages/search/commits.js"
        map["pages/search/issues.js"] = "//pages/search/issues.js"
        map["pages/search/labels.js"] = "//pages/search/labels.js"
        map["pages/search/repositories.js"] = "//pages/search/repositories.js"
        map["pages/search/topics.js"] = "//pages/search/topics.js"
        map["pages/search/users.js"] = "//pages/search/users.js"
        map["pages/zen.js"] = "//pages/zen.js"
        map["pages/repos/[owner]/[repo].js"] = "//pages/repos/[owner]/[repo].js"
        map["pages/repos/[owner]/[repo]/contents/[path].js"] = "//pages/repos/[owner]/[repo]/contents/[path].js"
        map["pages/repos/[owner]/[repo]/issues.js"] = "//pages/repos/[owner]/[repo]/issues.js"
        map["pages/repos/[owner]/[repo]/pulls.js"] = "//pages/repos/[owner]/[repo]/pulls.js"
        map["pages/repos/[owner]/[repo]/commits.js"] = "//pages/repos/[owner]/[repo]/commits.js"
        map["pages/repos/[owner]/[repo]/branches.js"] = "//pages/repos/[owner]/[repo]/branches.js"
        map["pages/repos/[owner]/[repo]/tags.js"] = "//pages/repos/[owner]/[repo]/tags.js"
        map["pages/repos/[owner]/[repo]/releases.js"] = "//pages/repos/[owner]/[repo]/releases.js"
        map["pages/repos/[owner]/[repo]/hooks.js"] = "//pages/repos/[owner]/[repo]/hooks.js"
        map["pages/repos/[owner]/[repo]/deployments.js"] = "//pages/repos/[owner]/[repo]/deployments.js"
        map["pages/repos/[owner]/[repo]/stargazers.js"] = "//pages/repos/[owner]/[repo]/stargazers.js"
        map["pages/repos/[owner]/[repo]/contributors.js"] = "//pages/repos/[owner]/[repo]/contributors.js"
        return map
    }

    /// Vercel路由列表
    public static func getVercelRoutesList(): HashMap<String, String> {
        let map = HashMap<String, String>()
        map["pages/index.js"] = "// pages/index.js"
        map["pages/404.js"] = "// pages/404.js"
        map["pages/_app.js"] = "// pages/_app.js"
        map["pages/_error.js"] = "// pages/_error.js"
        map["pages/_flags.js"] = "// pages/_flags.js"
        map["pages/about.js"] = "// pages/about.js"
        map["pages/blog.js"] = "// pages/blog.js"
        map["pages/careers.js"] = "// pages/careers.js"
        map["pages/contact.js"] = "// pages/contact.js"
        map["pages/dashboard.js"] = "// pages/dashboard.js"
        map["pages/domains.js"] = "// pages/domains.js"
        map["pages/home.js"] = "// pages/home.js"
        map["pages/login/[[...mode]].js"] = "// pages/login/[[...mode]].js"
        map["pages/new.js"] = "// pages/new.js"
        map["pages/pricing.js"] = "// pages/pricing.js"
        map["pages/teams.js"] = "// pages/teams.js"
        map["pages/teams/connect.js"] = "// pages/teams/connect.js"
        map["pages/teams/create.js"] = "// pages/teams/create.js"
        map["pages/teams/invite.js"] = "// pages/teams/invite.js"
        map["pages/support/request.js"] = "// pages/support/request.js"
        map["pages/[teamSlug].js"] = "// pages/[teamSlug].js"
        map["pages/[teamSlug]/[project].js"] = "// pages/[teamSlug]/[project].js"
        map["pages/[teamSlug]/[project]/[id].js"] = "// pages/[teamSlug]/[project]/[id].js"
        map["pages/[teamSlug]/[project]/deployments.js"] = "// pages/[teamSlug]/[project]/deployments.js"
        map["pages/[teamSlug]/[project]/domains.js"] = "// pages/[teamSlug]/[project]/domains.js"
        map["pages/[teamSlug]/[project]/insights.js"] = "// pages/[teamSlug]/[project]/insights.js"
        map["pages/[teamSlug]/[project]/settings.js"] = "// pages/[teamSlug]/[project]/settings.js"
        return map
    }
}
