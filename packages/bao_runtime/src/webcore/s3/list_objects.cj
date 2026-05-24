// 严格翻译自: src/runtime/webcore/s3/list_objects.zig
// S3 ListObjectsV2 - 列出 S3 对象的实现
// 包括 XML 解析、JS 选项解析和结果转换
package bao_runtime.webcore.s3

import bao_core.*
import bao_collections.*
import bao_jsc.*

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
    public var hasObjectSize: Bool

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
        hasObjectSize = false
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
    public var hasKeyCount: Bool

    /// 最大键数
    /// 对应 Bun: max_keys: ?i64
    public var maxKeys: Int64
    public var hasMaxKeys: Bool

    /// 分隔符
    /// 对应 Bun: delimiter: ?[]const u8
    public var delimiter: String

    /// 编码类型
    /// 对应 Bun: encoding_type: ?[]const u8
    public var encodingType: String

    /// 是否截断
    /// 对应 Bun: is_truncated: ?bool
    public var isTruncated: Bool
    public var hasIsTruncated: Bool

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
        hasKeyCount = false
        maxKeys = 0
        hasMaxKeys = false
        delimiter = ""
        encodingType = ""
        isTruncated = false
        hasIsTruncated = false
        continuationToken = ""
        nextContinuationToken = ""
        startAfter = ""
        commonPrefixes = ArrayList<String>()
        contents = ArrayList<S3ListObjectsContents>()
    }

    // ========================================================================
    // deinit - 释放资源
    // 严格翻译自: pub fn deinit(`this`: *const @This()) void
    // ========================================================================

    /// 释放资源
    /// 对应 Bun: pub fn deinit(`this`: *const @This()) void
    public func deinit(): Unit {
        for (i in 0..contents.size) {
            contents[i].deinit()
        }
    }

    // ========================================================================
    // toJS - 转为 JS 对象
    // 严格翻译自: pub fn toJS(`this`: *const @This(), globalObject) bun.JSError!JsValue
    // ========================================================================

    /// 转为 JS 对象
    /// 对应 Bun: pub fn toJS(`this`: *const @This(), globalObject: *JSGlobalObject) bun.JSError!JsValue
    /// 将 ListObjectsV2 结果转为 JS 对象，包含所有字段
    public func toJS(globalObject: JsGlobalObject): JsValue {
        let jsResult = JsObject()

        if (name.size > 0) {
            jsResult.set("name", JsValue(name))
        }

        if (prefix.size > 0) {
            jsResult.set("prefix", JsValue(prefix))
        }

        if (delimiter.size > 0) {
            jsResult.set("delimiter", JsValue(delimiter))
        }

        if (startAfter.size > 0) {
            jsResult.set("startAfter", JsValue(startAfter))
        }

        if (encodingType.size > 0) {
            jsResult.set("encodingType", JsValue(encodingType))
        }

        if (continuationToken.size > 0) {
            jsResult.set("continuationToken", JsValue(continuationToken))
        }

        if (nextContinuationToken.size > 0) {
            jsResult.set("nextContinuationToken", JsValue(nextContinuationToken))
        }

        if (hasIsTruncated) {
            jsResult.set("isTruncated", JsValue(isTruncated))
        }

        if (hasKeyCount) {
            jsResult.set("keyCount", JsValue(keyCount))
        }

        if (hasMaxKeys) {
            jsResult.set("maxKeys", JsValue(maxKeys))
        }

        if (contents.size > 0) {
            var contentItems = ArrayList<JsValue>()
            for (i in 0..contents.size) {
                let item = contents[i]
                let objectInfo = JsObject()
                objectInfo.set("key", JsValue(item.key.toString()))

                if (item.etag.size > 0) {
                    objectInfo.set("eTag", JsValue(item.etag.toString()))
                }

                if (item.checksumAlgorithme.size > 0) {
                    objectInfo.set("checksumAlgorithme", JsValue(item.checksumAlgorithme.toString()))
                }

                if (item.checksumType.size > 0) {
                    objectInfo.set("checksumType", JsValue(item.checksumType.toString()))
                }

                if (item.lastModified.size > 0) {
                    objectInfo.set("lastModified", JsValue(item.lastModified.toString()))
                }

                if (item.hasObjectSize) {
                    objectInfo.set("size", JsValue(item.objectSize))
                }

                if (item.storageClass.size > 0) {
                    objectInfo.set("storageClass", JsValue(item.storageClass.toString()))
                }

                match (item.owner) {
                    case Some(owner) =>
                        let jsOwner = JsObject()
                        if (owner.id.size > 0) {
                            jsOwner.set("id", JsValue(owner.id.toString()))
                        }
                        if (owner.displayName.size > 0) {
                            jsOwner.set("displayName", JsValue(owner.displayName.toString()))
                        }
                        objectInfo.set("owner", JsValue(jsOwner))
                    case None => ()
                }

                contentItems.append(JsValue(objectInfo))
            }
            let contentsArr = JsObject.make()
            contentsArr.className = "Array"
            let contentsStorage = contentItems.toOwnedSlice()
            contentsArr.arrayStorage = contentsStorage
            contentsArr.set("length", JsValue(Int64(contentItems.size)))
            jsResult.set("contents", JsValue(contentsArr))
        }

        if (commonPrefixes.size > 0) {
            var prefixItems = ArrayList<JsValue>()
            for (i in 0..commonPrefixes.size) {
                let jsPrefix = JsObject()
                jsPrefix.set("prefix", JsValue(commonPrefixes[i].toString()))
                prefixItems.append(JsValue(jsPrefix))
            }
            let prefixArr = JsObject.make()
            prefixArr.className = "Array"
            let prefixStorage = prefixItems.toOwnedSlice()
            prefixArr.arrayStorage = prefixStorage
            prefixArr.set("length", JsValue(Int64(prefixItems.size)))
            jsResult.set("commonPrefixes", JsValue(prefixArr))
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
    public var hasFetchOwner: Bool

    /// 最大键数
    /// 对应 Bun: max_keys: ?i64
    public var maxKeys: Int64
    public var hasMaxKeys: Bool

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
        hasFetchOwner = false
        maxKeys = 0
        hasMaxKeys = false
        prefix = ""
        startAfter = ""
    }

    // ========================================================================
    // deinit - 释放资源
    // 严格翻译自: pub fn deinit(`this`: *@This()) void
    // ========================================================================

    /// 释放资源
    /// 对应 Bun: pub fn deinit(`this`: *@This()) void
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
    let rootStartOpt = xml.indexOf("<ListBucketResult")
    if (!rootStartOpt.isSome()) {
        return result
    }

    var i = rootStartOpt.getOrThrow()
    while (i < xml.size) {
        if (xml[i] != UInt8(60)) {
            i += 1
            continue
        }
        let closeOpt = xml[i + 1..].indexOf(">")
        if (!closeOpt.isSome()) {
            i += 1
            continue
        }
        let tagEnd = i + 1 + closeOpt.getOrThrow()
        let tagName = xml[(i + 1)..tagEnd]
        i = tagEnd + 1

        match (tagName) {
            case "Contents" =>
                let endOpt = xml[i..].indexOf("</Contents>")
                if (endOpt.isSome()) {
                    let blockEnd = i + endOpt.getOrThrow()
                    parseContentsBlock(xml[i..blockEnd], result)
                    i = blockEnd + 11
                }
            case "Name" =>
                match (readTagValue(xml, i, "Name")) {
                    case Some(value) =>
                        result.name = value.value
                        i = value.nextIndex
                    case None => ()
                }
            case "Delimiter" =>
                match (readTagValue(xml, i, "Delimiter")) {
                    case Some(value) =>
                        result.delimiter = value.value
                        i = value.nextIndex
                    case None => ()
                }
            case "NextContinuationToken" =>
                match (readTagValue(xml, i, "NextContinuationToken")) {
                    case Some(value) =>
                        result.nextContinuationToken = value.value
                        i = value.nextIndex
                    case None => ()
                }
            case "ContinuationToken" =>
                match (readTagValue(xml, i, "ContinuationToken")) {
                    case Some(value) =>
                        result.continuationToken = value.value
                        i = value.nextIndex
                    case None => ()
                }
            case "StartAfter" =>
                match (readTagValue(xml, i, "StartAfter")) {
                    case Some(value) =>
                        result.startAfter = value.value
                        i = value.nextIndex
                    case None => ()
                }
            case "EncodingType" =>
                match (readTagValue(xml, i, "EncodingType")) {
                    case Some(value) =>
                        result.encodingType = value.value
                        i = value.nextIndex
                    case None => ()
                }
            case "KeyCount" =>
                match (readTagValue(xml, i, "KeyCount")) {
                    case Some(value) =>
                        result.keyCount = parseOptionalInt(value.value)
                        result.hasKeyCount = true
                        i = value.nextIndex
                    case None => ()
                }
            case "MaxKeys" =>
                match (readTagValue(xml, i, "MaxKeys")) {
                    case Some(value) =>
                        result.maxKeys = parseOptionalInt(value.value)
                        result.hasMaxKeys = true
                        i = value.nextIndex
                    case None => ()
                }
            case "Prefix" =>
                match (readTagValue(xml, i, "Prefix")) {
                    case Some(value) =>
                        if (value.value.size > 0) { result.prefix = value.value }
                        i = value.nextIndex
                    case None => ()
                }
            case "IsTruncated" =>
                match (readTagValue(xml, i, "IsTruncated")) {
                    case Some(value) =>
                        if (value.value == "true") {
                            result.isTruncated = true
                            result.hasIsTruncated = true
                        } else if (value.value == "false") {
                            result.isTruncated = false
                            result.hasIsTruncated = true
                        }
                        i = value.nextIndex
                    case None => ()
                }
            case "CommonPrefixes" =>
                let endOpt = xml[i..].indexOf("</CommonPrefixes>")
                if (endOpt.isSome()) {
                    let blockEnd = i + endOpt.getOrThrow()
                    parseCommonPrefixesBlock(xml[i..blockEnd], result)
                    i = blockEnd + 17
                }
            case _ => ()
        }
    }

    return result
}

private class XmlTagValue {
    public var value: String
    public var nextIndex: Int64

    public init(value: String, nextIndex: Int64) {
        this.value = value
        this.nextIndex = nextIndex
    }
}

private func readTagValue(xml: String, start: Int64, tag: String): ?XmlTagValue {
    let close = "</${tag}>"
    let endOpt = xml[start..].indexOf(close)
    if (!endOpt.isSome()) { return None }
    let end = start + endOpt.getOrThrow()
    return Some(XmlTagValue(xml[start..end], end + close.size))
}

private func parseContentsBlock(block: String, result: S3ListObjectsV2Result): Unit {
    let keyOpt = extractTag(block, "Key")
    if (!keyOpt.isSome()) { return }

    let item = S3ListObjectsContents()
    item.key = keyOpt.getOrThrow()
    item.lastModified = extractTag(block, "LastModified") ?? ""
    item.storageClass = extractTag(block, "StorageClass") ?? ""
    item.checksumType = extractTag(block, "ChecksumType") ?? ""
    item.checksumAlgorithme = extractTag(block, "ChecksumAlgorithm") ?? ""
    match (extractTag(block, "Size")) {
        case Some(sizeValue) =>
            item.objectSize = parseOptionalInt(sizeValue)
            item.hasObjectSize = true
        case None => ()
    }

    match (extractTag(block, "ETag")) {
        case Some(etag) => item.etag = etag.replace("&quot;", "\"")
        case None => ()
    }

    match (extractTag(block, "Owner")) {
        case Some(ownerBlock) =>
            let ownerId = extractTag(ownerBlock, "ID") ?? ""
            let displayName = extractTag(ownerBlock, "DisplayName") ?? ""
            if (ownerId.size > 0 || displayName.size > 0) {
                item.owner = Some(ObjectOwner(ownerId, displayName))
            }
        case None => ()
    }

    match (extractTag(block, "RestoreStatus")) {
        case Some(restoreBlock) =>
            var hasRestore = false
            var isRestoreInProgress = false
            match (extractTag(restoreBlock, "IsRestoreInProgress")) {
                case Some(value) =>
                    if (value == "true") {
                        isRestoreInProgress = true
                        hasRestore = true
                    } else if (value == "false") {
                        isRestoreInProgress = false
                        hasRestore = true
                    }
                case None => ()
            }
            let expiry = extractTag(restoreBlock, "RestoreExpiryDate") ?? ""
            if (expiry.size > 0) { hasRestore = true }
            if (hasRestore) {
                item.restoreStatus = Some(ObjectRestoreStatus(isRestoreInProgress, expiry))
            }
        case None => ()
    }

    result.contents.append(item)
}

private func parseCommonPrefixesBlock(block: String, result: S3ListObjectsV2Result): Unit {
    var i: Int64 = 0
    while (i < block.size) {
        let startOpt = block[i..].indexOf("<Prefix>")
        if (!startOpt.isSome()) { break }
        let valueStart = i + startOpt.getOrThrow() + 8
        let endOpt = block[valueStart..].indexOf("</Prefix>")
        if (!endOpt.isSome()) { break }
        let valueEnd = valueStart + endOpt.getOrThrow()
        result.commonPrefixes.append(block[valueStart..valueEnd])
        i = valueEnd + 9
    }
}

private func extractTag(xml: String, tag: String): ?String {
    let open = "<${tag}>"
    let startOpt = xml.indexOf(open)
    if (!startOpt.isSome()) { return None }
    let valueStart = startOpt.getOrThrow() + open.size
    let close = "</${tag}>"
    let endOpt = xml[valueStart..].indexOf(close)
    if (!endOpt.isSome()) { return None }
    let valueEnd = valueStart + endOpt.getOrThrow()
    return Some(xml[valueStart..valueEnd])
}

private func parseOptionalInt(value: String): Int64 {
    if (value.size == 0) { return 0 }
    return Int64.parse(value) ?? 0
}


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
    let ctVal = listOptions.getTruthy(globalThis.globalThis, "continuationToken")
    match (ctVal) {
        case Some(val) =>
            if (val.isString()) {
                let str = val.toString()
                if (str.size > 0) {
                    listObjectsOptions.continuationToken = str
                }
            }
        case None => ()
    }

    // delimiter
    let delimVal = listOptions.getTruthy(globalThis.globalThis, "delimiter")
    match (delimVal) {
        case Some(val) =>
            if (val.isString()) {
                let str = val.toString()
                if (str.size > 0) {
                    listObjectsOptions.delimiter = str
                }
            }
        case None => ()
    }

    // encodingType
    let etVal = listOptions.getTruthy(globalThis.globalThis, "encodingType")
    match (etVal) {
        case Some(val) =>
            if (val.isString()) {
                let str = val.toString()
                if (str.size > 0) {
                    listObjectsOptions.encodingType = str
                }
            }
        case None => ()
    }

    // fetchOwner
    let foVal = listOptions.getBooleanLoose(globalThis.globalThis, "fetchOwner")
    match (foVal) {
        case Some(val) =>
            listObjectsOptions.fetchOwner = val
            listObjectsOptions.hasFetchOwner = true
        case None => ()
    }

    // maxKeys
    let mkVal = listOptions.getTruthy(globalThis.globalThis, "maxKeys")
    match (mkVal) {
        case Some(val) =>
            if (val.isNumber()) {
                listObjectsOptions.maxKeys = val.toInt64()
                listObjectsOptions.hasMaxKeys = true
            }
        case None => ()
    }

    // prefix
    let prefixVal = listOptions.getTruthy(globalThis.globalThis, "prefix")
    match (prefixVal) {
        case Some(val) =>
            if (val.isString()) {
                let str = val.toString()
                if (str.size > 0) {
                    listObjectsOptions.prefix = str
                }
            }
        case None => ()
    }

    // startAfter
    let saVal = listOptions.getTruthy(globalThis.globalThis, "startAfter")
    match (saVal) {
        case Some(val) =>
            if (val.isString()) {
                let str = val.toString()
                if (str.size > 0) {
                    listObjectsOptions.startAfter = str
                }
            }
        case None => ()
    }

    return listObjectsOptions
}
