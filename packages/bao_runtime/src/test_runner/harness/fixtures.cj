// fixtures.cj - 测试夹具工具
// 严格翻译自 bun/src/runtime/test_runner/harness/fixtures.zig

package bao_runtime.test_runner.harness

import bao_collections.*  // HashMap

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
        map.put("pages/[...catch-all-at-root].js", "//pages/[...catch-all-at-root].js")
        map.put("pages/index.js", "//pages/index.js")
        map.put("pages/Foo.js", "//pages/Foo.js")
        map.put("pages/[TitleCaseParam].js", "//pages/[TitleCaseParam].js")
        map.put("pages/[TitleCaseParam]/file.js", "//pages/[TitleCaseParam]/file.js")
        map.put("pages/[TitleCaseParam]/[snake_case_param].js", "//pages/[TitleCaseParam]/[snake_case_param].js")
        map.put("pages/[TitleCaseParam]/[snake_case_param]/file.js", "//pages/[TitleCaseParam]/[snake_case_param]/file.js")
        map.put("pages/[TitleCaseParam]/[snake_case_param]/bacon/index.js", "//pages/[TitleCaseParam]/[snake_case_param]/bacon/index.js")
        return map
    }

    /// GitHub API路由列表 - 用于测试复杂路由匹配
    public static func getGithubApiRoutesList(): HashMap<String, String> {
        let map = HashMap<String, String>()
        map.put("pages/index.js", "//pages/index.js")
        map.put("pages/app.js", "//pages/app.js")
        map.put("pages/app/installations.js", "//pages/app/installations.js")
        map.put("pages/app/installations/[installation_id].js", "//pages/app/installations/[installation_id].js")
        map.put("pages/apps/[app_slug].js", "//pages/apps/[app_slug].js")
        map.put("pages/codes_of_conduct.js", "//pages/codes_of_conduct.js")
        map.put("pages/codes_of_conduct/[key].js", "//pages/codes_of_conduct/[key].js")
        map.put("pages/emojis.js", "//pages/emojis.js")
        map.put("pages/events.js", "//pages/events.js")
        map.put("pages/feeds.js", "//pages/feeds.js")
        map.put("pages/gitignore/templates.js", "//pages/gitignore/templates.js")
        map.put("pages/gitignore/templates/[name].js", "//pages/gitignore/templates/[name].js")
        map.put("pages/installation/repositories.js", "//pages/installation/repositories.js")
        map.put("pages/licenses.js", "//pages/licenses.js")
        map.put("pages/licenses/[license].js", "//pages/licenses/[license].js")
        map.put("pages/meta.js", "//pages/meta.js")
        map.put("pages/octocat.js", "//pages/octocat.js")
        map.put("pages/organizations.js", "//pages/organizations.js")
        map.put("pages/rate_limit.js", "//pages/rate_limit.js")
        map.put("pages/repositories.js", "//pages/repositories.js")
        map.put("pages/search/code.js", "//pages/search/code.js")
        map.put("pages/search/commits.js", "//pages/search/commits.js")
        map.put("pages/search/issues.js", "//pages/search/issues.js")
        map.put("pages/search/labels.js", "//pages/search/labels.js")
        map.put("pages/search/repositories.js", "//pages/search/repositories.js")
        map.put("pages/search/topics.js", "//pages/search/topics.js")
        map.put("pages/search/users.js", "//pages/search/users.js")
        map.put("pages/zen.js", "//pages/zen.js")
        map.put("pages/repos/[owner]/[repo].js", "//pages/repos/[owner]/[repo].js")
        map.put("pages/repos/[owner]/[repo]/contents/[path].js", "//pages/repos/[owner]/[repo]/contents/[path].js")
        map.put("pages/repos/[owner]/[repo]/issues.js", "//pages/repos/[owner]/[repo]/issues.js")
        map.put("pages/repos/[owner]/[repo]/pulls.js", "//pages/repos/[owner]/[repo]/pulls.js")
        map.put("pages/repos/[owner]/[repo]/commits.js", "//pages/repos/[owner]/[repo]/commits.js")
        map.put("pages/repos/[owner]/[repo]/branches.js", "//pages/repos/[owner]/[repo]/branches.js")
        map.put("pages/repos/[owner]/[repo]/tags.js", "//pages/repos/[owner]/[repo]/tags.js")
        map.put("pages/repos/[owner]/[repo]/releases.js", "//pages/repos/[owner]/[repo]/releases.js")
        map.put("pages/repos/[owner]/[repo]/hooks.js", "//pages/repos/[owner]/[repo]/hooks.js")
        map.put("pages/repos/[owner]/[repo]/deployments.js", "//pages/repos/[owner]/[repo]/deployments.js")
        map.put("pages/repos/[owner]/[repo]/stargazers.js", "//pages/repos/[owner]/[repo]/stargazers.js")
        map.put("pages/repos/[owner]/[repo]/contributors.js", "//pages/repos/[owner]/[repo]/contributors.js")
        return map
    }

    /// Vercel路由列表
    public static func getVercelRoutesList(): HashMap<String, String> {
        let map = HashMap<String, String>()
        map.put("pages/index.js", "// pages/index.js")
        map.put("pages/404.js", "// pages/404.js")
        map.put("pages/_app.js", "// pages/_app.js")
        map.put("pages/_error.js", "// pages/_error.js")
        map.put("pages/_flags.js", "// pages/_flags.js")
        map.put("pages/about.js", "// pages/about.js")
        map.put("pages/blog.js", "// pages/blog.js")
        map.put("pages/careers.js", "// pages/careers.js")
        map.put("pages/contact.js", "// pages/contact.js")
        map.put("pages/dashboard.js", "// pages/dashboard.js")
        map.put("pages/domains.js", "// pages/domains.js")
        map.put("pages/home.js", "// pages/home.js")
        map.put("pages/login/[[...mode]].js", "// pages/login/[[...mode]].js")
        map.put("pages/new.js", "// pages/new.js")
        map.put("pages/pricing.js", "// pages/pricing.js")
        map.put("pages/teams.js", "// pages/teams.js")
        map.put("pages/teams/connect.js", "// pages/teams/connect.js")
        map.put("pages/teams/create.js", "// pages/teams/create.js")
        map.put("pages/teams/invite.js", "// pages/teams/invite.js")
        map.put("pages/support/request.js", "// pages/support/request.js")
        map.put("pages/[teamSlug].js", "// pages/[teamSlug].js")
        map.put("pages/[teamSlug]/[project].js", "// pages/[teamSlug]/[project].js")
        map.put("pages/[teamSlug]/[project]/[id].js", "// pages/[teamSlug]/[project]/[id].js")
        map.put("pages/[teamSlug]/[project]/deployments.js", "// pages/[teamSlug]/[project]/deployments.js")
        map.put("pages/[teamSlug]/[project]/domains.js", "// pages/[teamSlug]/[project]/domains.js")
        map.put("pages/[teamSlug]/[project]/insights.js", "// pages/[teamSlug]/[project]/insights.js")
        map.put("pages/[teamSlug]/[project]/settings.js", "// pages/[teamSlug]/[project]/settings.js")
        return map
    }
}
