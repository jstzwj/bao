// 严格翻译自: src/cli/filter_arg.zig
// 过滤参数处理
package bao_runtime

import bao_core.*
import bao_collections.*

/// 过滤器类型
public enum FilterType {
    | script
    | bin
    | all
    | bunJs
    | allPlusBunJs
    | scriptAndDescriptions
    | scriptExclude
}

/// 过滤参数解析器
public class FilterArgParser {
    let filters: ArrayList<FilterType>
    let rejectList: ArrayList<String>

    public init() {
        this.filters = ArrayList()
        this.rejectList = ArrayList()
    }

    /// 解析过滤参数
    public static func parse(args: Array<String>): FilterArgParser {
        let parser = FilterArgParser()

        for (arg in args) {
            if (arg.startsWith("--filter=")) {
                // TODO: parse filter from arg
            } else if (arg.startsWith("--reject=")) {
                let reject = ""  // TODO: parse reject from arg
                parser.rejectList.append(reject)
            }
        }

        return parser
    }

    /// 解析过滤器类型
    static func parseFilterType(`type`: String): ?FilterType {
        match (`type`) {
            case "script" => return FilterType.script
            case "bin" => return FilterType.bin
            case "all" => return FilterType.all
            case "bun-js" => return FilterType.bunJs
            case "all-plus-bun-js" => return FilterType.allPlusBunJs
            case "script-and-descriptions" => return FilterType.scriptAndDescriptions
            case "script-exclude" => return FilterType.scriptExclude
            case _ => return None
        }
    }

    /// 检查是否应该过滤
    public func shouldFilter(item: String): Bool {
        if (filters.isEmpty()) {
            return false
        }

        for (filter in filters) {
            if (match(filter) { case scriptExclude => true case _ => false }) {
                for (reject in rejectList) {
                    if (item == reject) {
                        return true
                    }
                }
            }
        }

        return false
    }

    /// 获取过滤器列表
    public func getFilters(): Array<FilterType> {
        var filterArr = Array<FilterType>(filters.size, {i => filters[i]})
        return filterArr
    }

    /// 获取拒绝列表
    public func getRejectList(): Array<String> {
        var rejectArr = Array<String>(rejectList.size, {i => rejectList[i]})
        return rejectArr
    }
}

/// 过滤结果
public class FilterResult {
    let items: ArrayList<String>
    let descriptions: HashMap<String, String>

    public init() {
        this.items = ArrayList()
        this.descriptions = HashMap()
    }

    /// 添加项目
    public func addItem(item: String): Unit {
        items.append(item)
    }

    /// 添加带描述的项目
    public func addItemWithDescription(item: String, description: String): Unit {
        items.append(item)
        descriptions.put(item, description)
    }

    /// 获取项目列表
    public func getItems(): Array<String> {
        var itemArr = Array<String>(items.size, {i => items[i]})
        return itemArr
    }

    /// 获取描述
    public func getDescription(item: String): ?String {
        return descriptions.get(item)
    }

    /// 检查是否包含项目
    public func contains(item: String): Bool {
        return items.contains(item)
    }

    /// 获取大小
    public func size(): Int64 {
        return items.size
    }
}
