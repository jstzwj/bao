// 严格翻译自: src/md/entity.zig
// HTML 命名实体查找表
package bao_md

import std.collection.*

/// HTML 实体模块
public class EntityModule {

    /// 实体条目
    static class EntityEntry {
        let name: String
        let codepoints: Array<UInt32>
        init(name: String, codepoints: Array<UInt32>) {
            this.name = name
            this.codepoints = codepoints
        }
    }

    /// 排序的实体查找表（部分，按名称排序）
    static let entity_map: Array<EntityEntry> = [
        EntityEntry("&AElig;", [198, 0]),
        EntityEntry("&AMP;", [38, 0]),
        EntityEntry("&Aacute;", [193, 0]),
        EntityEntry("&Acirc;", [194, 0]),
        EntityEntry("&Agrave;", [192, 0]),
        EntityEntry("&Alpha;", [913, 0]),
        EntityEntry("&Aring;", [197, 0]),
        EntityEntry("&Atilde;", [195, 0]),
        EntityEntry("&Auml;", [196, 0]),
        EntityEntry("&Beta;", [914, 0]),
        EntityEntry("&COPY;", [169, 0]),
        EntityEntry("&Ccedil;", [199, 0]),
        EntityEntry("&Chi;", [935, 0]),
        EntityEntry("&Dagger;", [8225, 0]),
        EntityEntry("&Delta;", [916, 0]),
        EntityEntry("&ETH;", [208, 0]),
        EntityEntry("&Eacute;", [201, 0]),
        EntityEntry("&Ecirc;", [202, 0]),
        EntityEntry("&Egrave;", [200, 0]),
        EntityEntry("&Epsilon;", [917, 0]),
        EntityEntry("&Eta;", [919, 0]),
        EntityEntry("&Euml;", [203, 0]),
        EntityEntry("&Gamma;", [915, 0]),
        EntityEntry("&Iacute;", [205, 0]),
        EntityEntry("&Icirc;", [206, 0]),
        EntityEntry("&Igrave;", [204, 0]),
        EntityEntry("&Iota;", [921, 0]),
        EntityEntry("&Iuml;", [207, 0]),
        EntityEntry("&Kappa;", [922, 0]),
        EntityEntry("&Lambda;", [923, 0]),
        EntityEntry("&Mu;", [924, 0]),
        EntityEntry("&Ntilde;", [209, 0]),
        EntityEntry("&Nu;", [925, 0]),
        EntityEntry("&OElig;", [338, 0]),
        EntityEntry("&Oacute;", [211, 0]),
        EntityEntry("&Ocirc;", [212, 0]),
        EntityEntry("&Ograve;", [210, 0]),
        EntityEntry("&Omega;", [937, 0]),
        EntityEntry("&Omicron;", [927, 0]),
        EntityEntry("&Oslash;", [216, 0]),
        EntityEntry("&Otilde;", [213, 0]),
        EntityEntry("&Ouml;", [214, 0]),
        EntityEntry("&Phi;", [934, 0]),
        EntityEntry("&Pi;", [928, 0]),
        EntityEntry("&Prime;", [8243, 0]),
        EntityEntry("&Psi;", [936, 0]),
        EntityEntry("&Rho;", [929, 0]),
        EntityEntry("&Scaron;", [352, 0]),
        EntityEntry("&Sigma;", [931, 0]),
        EntityEntry("&THORN;", [222, 0]),
        EntityEntry("&Tau;", [932, 0]),
        EntityEntry("&Theta;", [920, 0]),
        EntityEntry("&Uacute;", [218, 0]),
        EntityEntry("&Ucirc;", [219, 0]),
        EntityEntry("&Ugrave;", [217, 0]),
        EntityEntry("&Upsilon;", [933, 0]),
        EntityEntry("&Uuml;", [220, 0]),
        EntityEntry("&Xi;", [926, 0]),
        EntityEntry("&Yacute;", [221, 0]),
        EntityEntry("&Yuml;", [376, 0]),
        EntityEntry("&Zeta;", [918, 0]),
        EntityEntry("&aacute;", [225, 0]),
        EntityEntry("&acirc;", [226, 0]),
        EntityEntry("&acute;", [180, 0]),
        EntityEntry("&aelig;", [230, 0]),
        EntityEntry("&agrave;", [224, 0]),
        EntityEntry("&amp;", [38, 0]),
        EntityEntry("&ang;", [8736, 0]),
        EntityEntry("&apos;", [39, 0]),
        EntityEntry("&aring;", [229, 0]),
        EntityEntry("&atilde;", [227, 0]),
        EntityEntry("&auml;", [228, 0]),
        EntityEntry("&bdquo;", [8222, 0]),
        EntityEntry("&brvbar;", [166, 0]),
        EntityEntry("&ccedil;", [231, 0]),
        EntityEntry("&cedil;", [184, 0]),
        EntityEntry("&cent;", [162, 0]),
        EntityEntry("&circ;", [710, 0]),
        EntityEntry("&copy;", [169, 0]),
        EntityEntry("&curren;", [164, 0]),
        EntityEntry("&dagger;", [8224, 0]),
        EntityEntry("&deg;", [176, 0]),
        EntityEntry("&delta;", [948, 0]),
        EntityEntry("&divide;", [247, 0]),
        EntityEntry("&eacute;", [233, 0]),
        EntityEntry("&ecirc;", [234, 0]),
        EntityEntry("&egrave;", [232, 0]),
        EntityEntry("&empty;", [8709, 0]),
        EntityEntry("&emsp;", [8195, 0]),
        EntityEntry("&ensp;", [8194, 0]),
        EntityEntry("&epsilon;", [949, 0]),
        EntityEntry("&equiv;", [8801, 0]),
        EntityEntry("&eta;", [951, 0]),
        EntityEntry("&eth;", [240, 0]),
        EntityEntry("&euml;", [235, 0]),
        EntityEntry("&euro;", [8364, 0]),
        EntityEntry("&exist;", [8707, 0]),
        EntityEntry("&fnof;", [402, 0]),
        EntityEntry("&forall;", [8704, 0]),
        EntityEntry("&frac12;", [189, 0]),
        EntityEntry("&frac14;", [188, 0]),
        EntityEntry("&frac34;", [190, 0]),
        EntityEntry("&gamma;", [947, 0]),
        EntityEntry("&ge;", [8805, 0]),
        EntityEntry("&gt;", [62, 0]),
        EntityEntry("&harr;", [8596, 0]),
        EntityEntry("&hearts;", [9829, 0]),
        EntityEntry("&hellip;", [8230, 0]),
        EntityEntry("&iacute;", [237, 0]),
        EntityEntry("&icirc;", [238, 0]),
        EntityEntry("&iexcl;", [161, 0]),
        EntityEntry("&igrave;", [236, 0]),
        EntityEntry("&image;", [8465, 0]),
        EntityEntry("&infin;", [8734, 0]),
        EntityEntry("&int;", [8747, 0]),
        EntityEntry("&iota;", [953, 0]),
        EntityEntry("&iquest;", [191, 0]),
        EntityEntry("&isin;", [8712, 0]),
        EntityEntry("&iuml;", [239, 0]),
        EntityEntry("&kappa;", [954, 0]),
        EntityEntry("&lambda;", [955, 0]),
        EntityEntry("&laquo;", [171, 0]),
        EntityEntry("&larr;", [8592, 0]),
        EntityEntry("&lceil;", [8968, 0]),
        EntityEntry("&ldquo;", [8220, 0]),
        EntityEntry("&le;", [8804, 0]),
        EntityEntry("&lfloor;", [8970, 0]),
        EntityEntry("&lowast;", [8727, 0]),
        EntityEntry("&loz;", [9674, 0]),
        EntityEntry("&lrm;", [8206, 0]),
        EntityEntry("&lsaquo;", [8249, 0]),
        EntityEntry("&lsquo;", [8216, 0]),
        EntityEntry("&lt;", [60, 0]),
        EntityEntry("&macr;", [175, 0]),
        EntityEntry("&mdash;", [8212, 0]),
        EntityEntry("&micro;", [181, 0]),
        EntityEntry("&middot;", [183, 0]),
        EntityEntry("&mu;", [956, 0]),
        EntityEntry("&nabla;", [8711, 0]),
        EntityEntry("&nbsp;", [160, 0]),
        EntityEntry("&ndash;", [8211, 0]),
        EntityEntry("&ne;", [8800, 0]),
        EntityEntry("&ni;", [8715, 0]),
        EntityEntry("&not;", [172, 0]),
        EntityEntry("&notin;", [8713, 0]),
        EntityEntry("&nsub;", [8836, 0]),
        EntityEntry("&ntilde;", [241, 0]),
        EntityEntry("&nu;", [957, 0]),
        EntityEntry("&oacute;", [243, 0]),
        EntityEntry("&ocirc;", [244, 0]),
        EntityEntry("&oelig;", [339, 0]),
        EntityEntry("&ograve;", [242, 0]),
        EntityEntry("&oline;", [8254, 0]),
        EntityEntry("&omega;", [969, 0]),
        EntityEntry("&omicron;", [959, 0]),
        EntityEntry("&oplus;", [8853, 0]),
        EntityEntry("&or;", [8744, 0]),
        EntityEntry("&ordf;", [170, 0]),
        EntityEntry("&ordm;", [186, 0]),
        EntityEntry("&oslash;", [248, 0]),
        EntityEntry("&otilde;", [245, 0]),
        EntityEntry("&otimes;", [8855, 0]),
        EntityEntry("&ouml;", [246, 0]),
        EntityEntry("&para;", [182, 0]),
        EntityEntry("&part;", [8706, 0]),
        EntityEntry("&permil;", [8240, 0]),
        EntityEntry("&perp;", [8869, 0]),
        EntityEntry("&phi;", [966, 0]),
        EntityEntry("&pi;", [960, 0]),
        EntityEntry("&piv;", [982, 0]),
        EntityEntry("&plusmn;", [177, 0]),
        EntityEntry("&pound;", [163, 0]),
        EntityEntry("&prime;", [8242, 0]),
        EntityEntry("&prod;", [8719, 0]),
        EntityEntry("&prop;", [8733, 0]),
        EntityEntry("&psi;", [968, 0]),
        EntityEntry("&quot;", [34, 0]),
        EntityEntry("&rArr;", [8658, 0]),
        EntityEntry("&radic;", [8730, 0]),
        EntityEntry("&rang;", [9002, 0]),
        EntityEntry("&raquo;", [187, 0]),
        EntityEntry("&rarr;", [8594, 0]),
        EntityEntry("&rceil;", [8969, 0]),
        EntityEntry("&rdquo;", [8221, 0]),
        EntityEntry("&real;", [8476, 0]),
        EntityEntry("&reg;", [174, 0]),
        EntityEntry("&rfloor;", [8971, 0]),
        EntityEntry("&rho;", [961, 0]),
        EntityEntry("&rlm;", [8207, 0]),
        EntityEntry("&rsaquo;", [8250, 0]),
        EntityEntry("&rsquo;", [8217, 0]),
        EntityEntry("&sbquo;", [8218, 0]),
        EntityEntry("&scaron;", [353, 0]),
        EntityEntry("&sdot;", [8901, 0]),
        EntityEntry("&sect;", [167, 0]),
        EntityEntry("&shy;", [173, 0]),
        EntityEntry("&sigma;", [963, 0]),
        EntityEntry("&sigmaf;", [962, 0]),
        EntityEntry("&sim;", [8764, 0]),
        EntityEntry("&spades;", [9824, 0]),
        EntityEntry("&sub;", [8834, 0]),
        EntityEntry("&sube;", [8838, 0]),
        EntityEntry("&sum;", [8721, 0]),
        EntityEntry("&sup;", [8835, 0]),
        EntityEntry("&sup1;", [185, 0]),
        EntityEntry("&sup2;", [178, 0]),
        EntityEntry("&sup3;", [179, 0]),
        EntityEntry("&supe;", [8839, 0]),
        EntityEntry("&szlig;", [223, 0]),
        EntityEntry("&tau;", [964, 0]),
        EntityEntry("&there4;", [8756, 0]),
        EntityEntry("&theta;", [952, 0]),
        EntityEntry("&thetasym;", [977, 0]),
        EntityEntry("&thinsp;", [8201, 0]),
        EntityEntry("&thorn;", [254, 0]),
        EntityEntry("&tilde;", [732, 0]),
        EntityEntry("&times;", [215, 0]),
        EntityEntry("&trade;", [8482, 0]),
        EntityEntry("&uArr;", [8657, 0]),
        EntityEntry("&uacute;", [250, 0]),
        EntityEntry("&uarr;", [8593, 0]),
        EntityEntry("&ucirc;", [251, 0]),
        EntityEntry("&ugrave;", [249, 0]),
        EntityEntry("&uml;", [168, 0]),
        EntityEntry("&upsih;", [978, 0]),
        EntityEntry("&upsilon;", [965, 0]),
        EntityEntry("&uuml;", [252, 0]),
        EntityEntry("&weierp;", [8472, 0]),
        EntityEntry("&xi;", [958, 0]),
        EntityEntry("&yacute;", [253, 0]),
        EntityEntry("&yen;", [165, 0]),
        EntityEntry("&yuml;", [255, 0]),
        EntityEntry("&zeta;", [950, 0]),
        EntityEntry("&zwj;", [8205, 0]),
        EntityEntry("&zwnj;", [8204, 0]),
    ]

    /// 通过名称查找 HTML 实体（包括 & 前缀和 ; 后缀）。
    /// 使用二分查找。
    public static func lookup(name: String): ?Array<UInt32> {
        var low: Int64 = 0
        var high: Int64 = entity_map.size
        while (low < high) {
            let mid = low + (high - low) / 2
            let cmp = orderStrings(entity_map[Int64(mid)].name, name)
            if (cmp < 0) {
                low = mid + 1
            } else if (cmp > 0) {
                high = mid
            } else {
                return entity_map[Int64(mid)].codepoints
            }
        }
        return None
    }

    static func orderStrings(a: String, b: String): Int64 {
        let len = if (a.size < b.size) { a.size } else { b.size }
        for (i in 0..len) {
            let ca = UInt8(a[i])
            let cb = UInt8(b[i])
            if (ca < cb) {
                return -1
            }
            if (ca > cb) {
                return 1
            }
        }
        if (a.size < b.size) {
            return -1
        }
        if (a.size > b.size) {
            return 1
        }
        return 0
    }
}
