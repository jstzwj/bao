// 严格翻译自: src/runtime/webcore/s3/list_objects.zig
// S3 ListObjectsV2 - 列出 S3 对象的实现
// 包括 XML 解析、JS 选项解析和结果转换
package bao_runtime

import bao_core.*
import bao_collections.*

// ============================================================================
// ObjectOwner - S3 对象所有者
// 严格翻译自: ObjectOwner struct
// Bun: const ObjectOwner = struct { id: ?[]const u8, display_name: ?[]const u8 }
// ============================================================================

/// S3 对象所有者
/// 对应 Bun: ObjectOwner struct
public class ObjectOwner {
    /// 所有者 ID
    /// 对应 Bun: id: ?[]const u8
    public var id: String

    /// 显示名称
    /// 对应 Bun: display_name: ?[]const u8
    public var displayName: String

    public init() {
        id = ""
        displayName = ""
    }

    public init(id: String, displayName: String) {
        this.id = id
        this.displayName = displayName
    }
}

// ============================================================================
// ObjectRestoreStatus - 对象恢复状态
// 严格翻译自: ObjectRestoreStatus struct
// Bun: const ObjectRestoreStatus = struct {
//   is_restore_in_progress: ?bool, restore_expiry_date: ?[]const u8 }
// ============================================================================

/// 对象恢复状态
/// 对应 Bun: ObjectRestoreStatus struct
public class ObjectRestoreStatus {
    /// 是否正在恢复
    /// 对应 Bun: is_restore_in_progress: ?bool
    public var isRestoreInProgress: Bool

    /// 恢复过期时间
    /// 对应 Bun: restore_expiry_date: ?[]const u8
    public var restoreExpiryDate: String

    public init() {
        isRestoreInProgress = false
        restoreExpiryDate = ""
    }

    public init(isRestoreInProgress: Bool, restoreExpiryDate: String) {
        this.isRestoreInProgress = isRestoreInProgress
        this.restoreExpiryDate = restoreExpiryDate
    }
}

// ============================================================================
// S3ListObjectsContents - 列出对象的内容项
// 严格翻译自: S3ListObjectsContents struct
// Bun: const S3ListObjectsContents = struct { key, etag, checksum_type,
//   checksum_algorithme, last_modified, object_size, storage_class, owner,
//   restore_status }
// ============================================================================

/// S3 列出对象的内容项
/// 对应 Bun: S3ListObjectsContents struct
public class S3ListObjectsContents {
    /// 对象键
    /// 对应 Bun: key: []const u8
    public var key: String

    /// ETag
    /// 对应 Bun: etag: ?bun.ptr.OwnedIn([]const u8, ...)
    public var etag: String

    /// 校验和类型
    /// 对应 Bun: checksum_type: ?[]const u8
    public var checksumType: String

    /// 校验和算法
    /// 对应 Bun: checksum_algorithme: ?[]const u8
    public var checksumAlgorithme: String

    /// 最后修改时间
    /// 对应 Bun: last_modified: ?[]const u8
    public var lastModified: String

    /// 对象大小
    /// 对应 Bun: object_size: ?i64
    public var objectSize: Int64

    /// 存储类别
    /// 对应 Bun: storage_class: ?[]const u8
    public var storageClass: String

    /// 所有者
    /// 对应 Bun: owner: ?ObjectOwner
    public var owner: ?ObjectOwner

    /// 恢复状态
    /// 对应 Bun: restore_status: ?ObjectRestoreStatus
    public var restoreStatus: ?ObjectRestoreStatus

    /// ETag 是否拥有
    private var etagOwned: Bool

    public init() {
        key = ""
        etag = ""
        checksumType = ""
        checksumAlgorithme = ""
        lastModified = ""
        objectSize = 0
        storageClass = ""
        owner = None
        restoreStatus = None
        etagOwned = false
    }

    // ========================================================================
    // deinit - 释放资源
    // 严格翻译自: pub fn deinit(self: *S3ListObjectsContents) void
    // ========================================================================

    /// 释放资源
    /// 对应 Bun: pub fn deinit(self: *S3ListObjectsContents) void
    public func deinit(): Unit {
        // 仓颉 GC 管理字符串
    }
}

// ============================================================================
// S3ListObjectsV2Result - ListObjectsV2 结果
// 严格翻译自: S3ListObjectsV2Result struct
// Bun: pub const S3ListObjectsV2Result = struct {
//   name, prefix, key_count, max_keys, delimiter, encoding_type,
//   is_truncated, continuation_token, next_continuation_token,
//   start_after, common_prefixes, contents }
// ============================================================================

/// ListObjectsV2 结果
/// 对应 Bun: S3ListObjectsV2Result struct
public class S3ListObjectsV2Result {
    /// 桶名
    /// 对应 Bun: name: ?[]const u8
    public var name: String

    /// 前缀
    /// 对应 Bun: prefix: ?[]const u8
    public var prefix: String

    /// 键数量
    /// 对应 Bun: key_count: ?i64
    public var keyCount: Int64

    /// 最大键数
    /// 对应 Bun: max_keys: ?i64
    public var maxKeys: Int64

    /// 分隔符
    /// 对应 Bun: delimiter: ?[]const u8
    public var delimiter: String

    /// 编码类型
    /// 对应 Bun: encoding_type: ?[]const u8
    public var encodingType: String

    /// 是否截断
    /// 对应 Bun: is_truncated: ?bool
    public var isTruncated: Bool

    /// 续 token
    /// 对应 Bun: continuation_token: ?[]const u8
    public var continuationToken: String

    /// 下一个续 token
    /// 对应 Bun: next_continuation_token: ?[]const u8
    public var nextContinuationToken: String

    /// 起始之后
    /// 对应 Bun: start_after: ?[]const u8
    public var startAfter: String

    /// 公共前缀
    /// 对应 Bun: common_prefixes: ?std.array_list.Managed([]const u8)
    public var commonPrefixes: ArrayList<String>

    /// 内容列表
    /// 对应 Bun: contents: ?std.array_list.Managed(S3ListObjectsContents)
    public var contents: ArrayList<S3ListObjectsContents>

    public init() {
        name = ""
        prefix = ""
        keyCount = 0
        maxKeys = 0
        delimiter = ""
        encodingType = ""
        isTruncated = false
        continuationToken = ""
        nextContinuationToken = ""
        startAfter = ""
        commonPrefixes = ArrayList<String>()
        contents = ArrayList<S3ListObjectsContents>()
    }

    // ========================================================================
    // deinit - 释放资源
    // 严格翻译自: pub fn deinit(this: *const @This()) void
    // ========================================================================

    /// 释放资源
    /// 对应 Bun: pub fn deinit(this: *const @This()) void
    public func deinit(): Unit {
        for (i in 0..contents.size) {
            contents[i].deinit()
        }
    }

    // ========================================================================
    // toJS - 转为 JS 对象
    // 严格翻译自: pub fn toJS(this: *const @This(), globalObject) bun.JSError!JSValue
    // ========================================================================

    /// 转为 JS 对象
    /// 对应 Bun: pub fn toJS(this: *const @This(), globalObject: *JSGlobalObject) bun.JSError!JSValue
    /// 将 ListObjectsV2 结果转为 JS 对象，包含所有字段
    public func toJS(globalObject: JsGlobalObject): JsValue {
        let jsResult = JsObject()

        if (name.length > 0) {
            jsResult.set("name", JsValue(BaoString(name)))
        }

        if (prefix.length > 0) {
            jsResult.set("prefix", JsValue(BaoString(prefix)))
        }

        if (delimiter.length > 0) {
            jsResult.set("delimiter", JsValue(BaoString(delimiter)))
        }

        if (startAfter.length > 0) {
            jsResult.set("startAfter", JsValue(BaoString(startAfter)))
        }

        if (encodingType.length > 0) {
            jsResult.set("encodingType", JsValue(BaoString(encodingType)))
        }

        if (continuationToken.length > 0) {
            jsResult.set("continuationToken", JsValue(BaoString(continuationToken)))
        }

        if (nextContinuationToken.length > 0) {
            jsResult.set("nextContinuationToken", JsValue(BaoString(nextContinuationToken)))
        }

        if (isTruncated) {
            jsResult.set("isTruncated", JsValue(true))
        }

        if (keyCount > 0) {
            jsResult.set("keyCount", JsValue(keyCount))
        }

        if (maxKeys > 0) {
            jsResult.set("maxKeys", JsValue(maxKeys))
        }

        if (contents.size > 0) {
            let jsContents = JsArray(contents.size)
            for (i in 0..contents.size) {
                let item = contents[i]
                let objectInfo = JsObject()
                objectInfo.set("key", JsValue(BaoString(item.key)))

                if (item.etag.length > 0) {
                    objectInfo.set("eTag", JsValue(BaoString(item.etag)))
                }

                if (item.checksumAlgorithme.length > 0) {
                    objectInfo.set("checksumAlgorithme", JsValue(BaoString(item.checksumAlgorithme)))
                }

                if (item.checksumType.length > 0) {
                    objectInfo.set("checksumType", JsValue(BaoString(item.checksumType)))
                }

                if (item.lastModified.length > 0) {
                    objectInfo.set("lastModified", JsValue(BaoString(item.lastModified)))
                }

                if (item.objectSize > 0) {
                    objectInfo.set("size", JsValue(item.objectSize))
                }

                if (item.storageClass.length > 0) {
                    objectInfo.set("storageClass", JsValue(BaoString(item.storageClass)))
                }

                match (item.owner) {
                    case Some(owner) => {
                        let jsOwner = JsObject()
                        if (owner.id.length > 0) {
                            jsOwner.set("id", JsValue(BaoString(owner.id)))
                        }
                        if (owner.displayName.length > 0) {
                            jsOwner.set("displayName", JsValue(BaoString(owner.displayName)))
                        }
                        objectInfo.set("owner", JsValue(jsOwner))
                    }
                    case None => ()
                }

                jsContents.setIndex(i, JsValue(objectInfo))
            }
            jsResult.set("contents", JsValue(jsContents))
        }

        if (commonPrefixes.size > 0) {
            let jsCommonPrefixes = JsArray(commonPrefixes.size)
            for (i in 0..commonPrefixes.size) {
                let jsPrefix = JsObject()
                jsPrefix.set("prefix", JsValue(BaoString(commonPrefixes[i])))
                jsCommonPrefixes.setIndex(i, JsValue(jsPrefix))
            }
            jsResult.set("commonPrefixes", JsValue(jsCommonPrefixes))
        }

        return JsValue(jsResult)
    }
}

// ============================================================================
// S3ListObjectsOptions - 列出对象选项
// 严格翻译自: S3ListObjectsOptions struct
// Bun: pub const S3ListObjectsOptions = struct {
//   continuation_token, delimiter, encoding_type, fetch_owner,
//   max_keys, prefix, start_after }
// ============================================================================

/// 列出对象选项
/// 对应 Bun: S3ListObjectsOptions struct
public class S3ListObjectsOptions {
    /// 续 token
    /// 对应 Bun: continuation_token: ?[]const u8
    public var continuationToken: String

    /// 分隔符
    /// 对应 Bun: delimiter: ?[]const u8
    public var delimiter: String

    /// 编码类型
    /// 对应 Bun: encoding_type: ?[]const u8
    public var encodingType: String

    /// 是否获取所有者
    /// 对应 Bun: fetch_owner: ?bool
    public var fetchOwner: Bool

    /// 最大键数
    /// 对应 Bun: max_keys: ?i64
    public var maxKeys: Int64

    /// 前缀
    /// 对应 Bun: prefix: ?[]const u8
    public var prefix: String

    /// 起始之后
    /// 对应 Bun: start_after: ?[]const u8
    public var startAfter: String

    public init() {
        continuationToken = ""
        delimiter = ""
        encodingType = ""
        fetchOwner = false
        maxKeys = 0
        prefix = ""
        startAfter = ""
    }

    // ========================================================================
    // deinit - 释放资源
    // 严格翻译自: pub fn deinit(this: *@This()) void
    // ========================================================================

    /// 释放资源
    /// 对应 Bun: pub fn deinit(this: *@This()) void
    public func deinit(): Unit {
        // 仓颉 GC 管理
    }
}

// ============================================================================
// parseS3ListObjectsResult - 解析 S3 ListObjectsV2 XML 响应
// 严格翻译自: pub fn parseS3ListObjectsResult(xml: []const u8) !S3ListObjectsV2Result
// Bun: pub fn parseS3ListObjectsResult(xml: []const u8) !S3ListObjectsV2Result
// ============================================================================

/// 解析 S3 ListObjectsV2 的 XML 响应
/// 对应 Bun: parseS3ListObjectsResult
/// 解析 XML 格式的 ListBucketResult 响应，提取 Name, Prefix, KeyCount,
/// MaxKeys, Delimiter, EncodingType, IsTruncated, ContinuationToken,
/// NextContinuationToken, StartAfter, Contents, CommonPrefixes 等
public func parseS3ListObjectsResult(xml: String): S3ListObjectsV2Result {
    let result = S3ListObjectsV2Result()
    let contents = ArrayList<S3ListObjectsContents>()
    let commonPrefixes = ArrayList<String>()

    // 查找 <ListBucketResult 标签
    let deleteResultPos = xml.indexOf("<ListBucketResult")
    if (deleteResultPos >= 0) {
        var i: Int64 = 0
        let xmlFromResult = xml.substring(deleteResultPos)

        while (i < xmlFromResult.length) {
            if (xmlFromResult[i] != '<') {
                i += 1
                continue
            }

            // 查找标签名
            let tagNameEnd = xmlFromResult.indexOfFrom(i + 1, ">")
            if (tagNameEnd >= 0) {
                let tagName = xmlFromResult.substring(i + 1, tagNameEnd)
                i = tagNameEnd + 1

                // ----------------------------------------------------------
                // Contents - 对象内容
                // 对应 Bun: strings.eql(tagName, "Contents")
                // ----------------------------------------------------------
                if (tagName == "Contents") {
                    var lookingForEndTag = true

                    var objectKey = ""
                    var lastModified = ""
                    var objectSize: Int64 = 0
                    var storageClass = ""
                    var etag = ""
                    var etagOwned = false
                    var checksumType = ""
                    var checksumAlgorithme = ""
                    var ownerId = ""
                    var ownerDisplayName = ""
                    var isRestoreInProgress: Bool = false
                    var hasIsRestoreInProgress = false
                    var restoreExpiryDate = ""

                    while (lookingForEndTag) {
                        if (i >= xmlFromResult.length) {
                            break
                        }

                        if (xmlFromResult[i] == '<') {
                            let innerEnd = xmlFromResult.indexOfFrom(i + 1, ">")
                            if (innerEnd >= 0) {
                                let innerTagName = xmlFromResult.substring(i + 1, innerEnd)
                                i = innerEnd + 1

                                if (innerTagName == "/Contents") {
                                    lookingForEndTag = false
                                } else if (innerTagName == "Key") {
                                    let tagEnd = xmlFromResult.indexOfFrom(i, "</Key>")
                                    if (tagEnd >= 0) {
                                        objectKey = xmlFromResult.substring(i, tagEnd)
                                        i = tagEnd + 6
                                    }
                                } else if (innerTagName == "LastModified") {
                                    let tagEnd = xmlFromResult.indexOfFrom(i, "</LastModified>")
                                    if (tagEnd >= 0) {
                                        lastModified = xmlFromResult.substring(i, tagEnd)
                                        i = tagEnd + 15
                                    }
                                } else if (innerTagName == "Size") {
                                    let tagEnd = xmlFromResult.indexOfFrom(i, "</Size>")
                                    if (tagEnd >= 0) {
                                        let sizeStr = xmlFromResult.substring(i, tagEnd)
                                        objectSize = Int64.parse(sizeStr)
                                        i = tagEnd + 7
                                    }
                                } else if (innerTagName == "StorageClass") {
                                    let tagEnd = xmlFromResult.indexOfFrom(i, "</StorageClass>")
                                    if (tagEnd >= 0) {
                                        storageClass = xmlFromResult.substring(i, tagEnd)
                                        i = tagEnd + 15
                                    }
                                } else if (innerTagName == "ChecksumType") {
                                    let tagEnd = xmlFromResult.indexOfFrom(i, "</ChecksumType>")
                                    if (tagEnd >= 0) {
                                        checksumType = xmlFromResult.substring(i, tagEnd)
                                        i = tagEnd + 15
                                    }
                                } else if (innerTagName == "ChecksumAlgorithm") {
                                    let tagEnd = xmlFromResult.indexOfFrom(i, "</ChecksumAlgorithm>")
                                    if (tagEnd >= 0) {
                                        checksumAlgorithme = xmlFromResult.substring(i, tagEnd)
                                        i = tagEnd + 20
                                    }
                                } else if (innerTagName == "ETag") {
                                    let tagEnd = xmlFromResult.indexOfFrom(i, "</ETag>")
                                    if (tagEnd >= 0) {
                                        let input = xmlFromResult.substring(i, tagEnd)
                                        // 替换 &quot; 为 "
                                        etag = input.replace("&quot;", "\"")
                                        etagOwned = input.contains("&quot;")
                                        i = tagEnd + 7
                                    }
                                } else if (innerTagName == "Owner") {
                                    let tagEnd = xmlFromResult.indexOfFrom(i, "</Owner>")
                                    if (tagEnd >= 0) {
                                        let owner = xmlFromResult.substring(i, tagEnd)
                                        i = tagEnd + 8

                                        // 解析 <ID>
                                        let idStart = owner.indexOf("<ID>")
                                        if (idStart >= 0) {
                                            let idStartPos = idStart + 4
                                            let idEnd = owner.indexOf("</ID>")
                                            if (idEnd > idStartPos) {
                                                ownerId = owner.substring(idStartPos, idEnd)
                                            }
                                        }

                                        // 解析 <DisplayName>
                                        let dnStart = owner.indexOf("<DisplayName>")
                                        if (dnStart >= 0) {
                                            let dnStartPos = dnStart + 13
                                            let dnEnd = owner.indexOf("</DisplayName>")
                                            if (dnEnd > dnStartPos) {
                                                ownerDisplayName = owner.substring(dnStartPos, dnEnd)
                                            }
                                        }
                                    }
                                } else if (innerTagName == "RestoreStatus") {
                                    let tagEnd = xmlFromResult.indexOfFrom(i, "</RestoreStatus>")
                                    if (tagEnd >= 0) {
                                        let restoreStatus = xmlFromResult.substring(i, tagEnd)
                                        i = tagEnd + 16

                                        // 解析 <IsRestoreInProgress>
                                        let iripStart = restoreStatus.indexOf("<IsRestoreInProgress>")
                                        if (iripStart >= 0) {
                                            let startPos = iripStart + 21
                                            let endPos = restoreStatus.indexOf("</IsRestoreInProgress>")
                                            if (endPos > startPos) {
                                                let val = restoreStatus.substring(startPos, endPos)
                                                if (val == "true") {
                                                    isRestoreInProgress = true
                                                    hasIsRestoreInProgress = true
                                                } else if (val == "false") {
                                                    isRestoreInProgress = false
                                                    hasIsRestoreInProgress = true
                                                }
                                            }
                                        }

                                        // 解析 <RestoreExpiryDate>
                                        let redStart = restoreStatus.indexOf("<RestoreExpiryDate>")
                                        if (redStart >= 0) {
                                            let startPos = redStart + 19
                                            let endPos = restoreStatus.indexOf("</RestoreExpiryDate>")
                                            if (endPos > startPos) {
                                                restoreExpiryDate = restoreStatus.substring(startPos, endPos)
                                            }
                                        }
                                    }
                                }
                            } else {
                                i += 1
                            }
                        } else {
                            i += 1
                        }
                    }

                    // 构建 S3ListObjectsContents
                    if (objectKey.length > 0) {
                        let item = S3ListObjectsContents()
                        item.key = objectKey
                        item.etag = etag
                        item.checksumType = checksumType
                        item.checksumAlgorithme = checksumAlgorithme
                        item.lastModified = lastModified
                        item.objectSize = objectSize
                        item.storageClass = storageClass
                        item.etagOwned = etagOwned

                        // 所有者
                        if (ownerId.length > 0 || ownerDisplayName.length > 0) {
                            item.owner = Some(ObjectOwner(ownerId, ownerDisplayName))
                        }

                        // 恢复状态
                        if (hasIsRestoreInProgress || restoreExpiryDate.length > 0) {
                            item.restoreStatus = Some(ObjectRestoreStatus(isRestoreInProgress, restoreExpiryDate))
                        }

                        contents.append(item)
                    }
                } else if (tagName == "Name") {
                    // ----------------------------------------------------------
                    // Name
                    // 对应 Bun: strings.eql(tagName, "Name")
                    // ----------------------------------------------------------
                    let tagEnd = xmlFromResult.indexOfFrom(i, "</Name>")
                    if (tagEnd >= 0) {
                        result.name = xmlFromResult.substring(i, tagEnd)
                        i = tagEnd
                    }
                } else if (tagName == "Delimiter") {
                    let tagEnd = xmlFromResult.indexOfFrom(i, "</Delimiter>")
                    if (tagEnd >= 0) {
                        result.delimiter = xmlFromResult.substring(i, tagEnd)
                        i = tagEnd
                    }
                } else if (tagName == "NextContinuationToken") {
                    let tagEnd = xmlFromResult.indexOfFrom(i, "</NextContinuationToken>")
                    if (tagEnd >= 0) {
                        result.nextContinuationToken = xmlFromResult.substring(i, tagEnd)
                        i = tagEnd
                    }
                } else if (tagName == "ContinuationToken") {
                    let tagEnd = xmlFromResult.indexOfFrom(i, "</ContinuationToken>")
                    if (tagEnd >= 0) {
                        result.continuationToken = xmlFromResult.substring(i, tagEnd)
                        i = tagEnd
                    }
                } else if (tagName == "StartAfter") {
                    let tagEnd = xmlFromResult.indexOfFrom(i, "</StartAfter>")
                    if (tagEnd >= 0) {
                        result.startAfter = xmlFromResult.substring(i, tagEnd)
                        i = tagEnd
                    }
                } else if (tagName == "EncodingType") {
                    let tagEnd = xmlFromResult.indexOfFrom(i, "</EncodingType>")
                    if (tagEnd >= 0) {
                        result.encodingType = xmlFromResult.substring(i, tagEnd)
                        i = tagEnd
                    }
                } else if (tagName == "KeyCount") {
                    let tagEnd = xmlFromResult.indexOfFrom(i, "</KeyCount>")
                    if (tagEnd >= 0) {
                        let keyCountStr = xmlFromResult.substring(i, tagEnd)
                        result.keyCount = Int64.parse(keyCountStr)
                        i = tagEnd
                    }
                } else if (tagName == "MaxKeys") {
                    let tagEnd = xmlFromResult.indexOfFrom(i, "</MaxKeys>")
                    if (tagEnd >= 0) {
                        let maxKeysStr = xmlFromResult.substring(i, tagEnd)
                        result.maxKeys = Int64.parse(maxKeysStr)
                        i = tagEnd
                    }
                } else if (tagName == "Prefix") {
                    let tagEnd = xmlFromResult.indexOfFrom(i, "</Prefix>")
                    if (tagEnd >= 0) {
                        let prefixStr = xmlFromResult.substring(i, tagEnd)
                        if (prefixStr.length != 0) {
                            result.prefix = prefixStr
                        }
                        i = tagEnd
                    }
                } else if (tagName == "IsTruncated") {
                    let tagEnd = xmlFromResult.indexOfFrom(i, "</IsTruncated>")
                    if (tagEnd >= 0) {
                        let isTruncatedStr = xmlFromResult.substring(i, tagEnd)
                        if (isTruncatedStr == "true") {
                            result.isTruncated = true
                        } else if (isTruncatedStr == "false") {
                            result.isTruncated = false
                        }
                        i = tagEnd
                    }
                } else if (tagName == "CommonPrefixes") {
                    // ----------------------------------------------------------
                    // CommonPrefixes
                    // 对应 Bun: strings.eql(tagName, "CommonPrefixes")
                    // ----------------------------------------------------------
                    let tagEnd = xmlFromResult.indexOfFrom(i, "</CommonPrefixes>")
                    if (tagEnd >= 0) {
                        let commonPrefixesStr = xmlFromResult.substring(i, tagEnd)
                        i = tagEnd

                        var j: Int64 = 0
                        while (j < commonPrefixesStr.length) {
                            let prefixStart = commonPrefixesStr.indexOfFrom(j, "<Prefix>")
                            if (prefixStart >= 0) {
                                j = prefixStart + 8
                                let prefixEnd = commonPrefixesStr.indexOfFrom(j, "</Prefix>")
                                if (prefixEnd >= 0) {
                                    commonPrefixes.append(commonPrefixesStr.substring(j, prefixEnd))
                                    j = prefixEnd
                                }
                            } else {
                                break
                            }
                        }
                    }
                }
            } else {
                i += 1
            }
        }

        // 设置结果
        if (contents.size > 0) {
            result.contents = contents
        }

        if (commonPrefixes.size > 0) {
            result.commonPrefixes = commonPrefixes
        }
    }

    return result
}

// ============================================================================
// getListObjectsOptionsFromJS - 从 JS 对象解析列出对象选项
// 严格翻译自: pub fn getListObjectsOptionsFromJS(globalThis, listOptions) !S3ListObjectsOptions
// Bun: pub fn getListObjectsOptionsFromJS(globalThis: *jsc.JSGlobalObject, listOptions: JSValue) !S3ListObjectsOptions
// ============================================================================

/// 从 JS 对象解析列出对象选项
/// 对应 Bun: getListObjectsOptionsFromJS
/// 从 JS 选项对象中提取 continuationToken, delimiter, encodingType,
/// fetchOwner, maxKeys, prefix, startAfter 等
public func getListObjectsOptionsFromJS(globalThis: JsGlobalObject, listOptions: JsValue): S3ListObjectsOptions {
    let listObjectsOptions = S3ListObjectsOptions()

    if (!listOptions.isObject()) {
        return listObjectsOptions
    }

    // continuationToken
    let ctVal = listOptions.getTruthy("continuationToken")
    match (ctVal) {
        case Some(val) => {
            if (val.isString()) {
                let str = val.toString()
                if (str.length > 0) {
                    listObjectsOptions.continuationToken = str
                }
            }
        }
        case None => ()
    }

    // delimiter
    let delimVal = listOptions.getTruthy("delimiter")
    match (delimVal) {
        case Some(val) => {
            if (val.isString()) {
                let str = val.toString()
                if (str.length > 0) {
                    listObjectsOptions.delimiter = str
                }
            }
        }
        case None => ()
    }

    // encodingType
    let etVal = listOptions.getTruthy("encodingType")
    match (etVal) {
        case Some(val) => {
            if (val.isString()) {
                let str = val.toString()
                if (str.length > 0) {
                    listObjectsOptions.encodingType = str
                }
            }
        }
        case None => ()
    }

    // fetchOwner
    let foVal = listOptions.getBooleanLoose("fetchOwner")
    match (foVal) {
        case Some(val) => listObjectsOptions.fetchOwner = val
        case None => ()
    }

    // maxKeys
    let mkVal = listOptions.getTruthy("maxKeys")
    match (mkVal) {
        case Some(val) => {
            if (val.isNumber()) {
                listObjectsOptions.maxKeys = val.toInt32()
            }
        }
        case None => ()
    }

    // prefix
    let prefixVal = listOptions.getTruthy("prefix")
    match (prefixVal) {
        case Some(val) => {
            if (val.isString()) {
                let str = val.toString()
                if (str.length > 0) {
                    listObjectsOptions.prefix = str
                }
            }
        }
        case None => ()
    }

    // startAfter
    let saVal = listOptions.getTruthy("startAfter")
    match (saVal) {
        case Some(val) => {
            if (val.isString()) {
                let str = val.toString()
                if (str.length > 0) {
                    listObjectsOptions.startAfter = str
                }
            }
        }
        case None => ()
    }

    return listObjectsOptions
}
