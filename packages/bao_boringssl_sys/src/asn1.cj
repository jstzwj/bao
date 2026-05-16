// 严格翻译自: src/boringssl_sys/boringssl.zig
package bao_boringssl_sys

// ============================================================================
// BoringSSL ASN1, d2i/i2d 序列化 FFI 函数声明
// 严格翻译自: boringssl.zig 中 ASN1_*, d2i_*, i2d_*, NETSCAPE_*, c2i_*, i2a_*, i2c_* 函数
// ============================================================================

// --- ASN1 基础函数 ---
foreign func ASN1_tag2bit(tag: Int32): UInt64
foreign func ASN1_tag2str(tag: Int32): CString
foreign func ASN1_item_new(it: CPointer<Unit>): CPointer<Unit>
foreign func ASN1_item_free(val: CPointer<Unit>, it: CPointer<Unit>): Unit
foreign func ASN1_item_d2i(out: CPointer<CPointer<Unit>>, inp: CPointer<CPointer<UInt8>>, len: Int64, it: CPointer<Unit>): CPointer<Unit>
foreign func ASN1_item_i2d(val: CPointer<Unit>, outp: CPointer<CPointer<UInt8>>, it: CPointer<Unit>): Int32
foreign func ASN1_item_dup(it: CPointer<Unit>, x: CPointer<Unit>): CPointer<Unit>
foreign func ASN1_item_d2i_bio(it: CPointer<Unit>, in_: CPointer<Unit>, out: CPointer<Unit>): CPointer<Unit>
foreign func ASN1_item_i2d_bio(it: CPointer<Unit>, out: CPointer<Unit>, in_: CPointer<Unit>): Int32
foreign func ASN1_item_unpack(oct: CPointer<Asn1StringSt>, it: CPointer<Unit>): CPointer<Unit>
foreign func ASN1_item_pack(obj: CPointer<Unit>, it: CPointer<Unit>, out: CPointer<CPointer<Asn1StringSt>>): CPointer<Asn1StringSt>
foreign func ASN1_item_digest(it: CPointer<Unit>, type_: CPointer<Unit>, data: CPointer<Unit>, md: CPointer<UInt8>, len: CPointer<UInt32>): Int32
foreign func ASN1_item_verify(it: CPointer<Unit>, algor1: CPointer<X509Algor>, signature: CPointer<Asn1StringSt>, data: CPointer<Unit>, pkey: CPointer<EvpPkeySt>): Int32
foreign func ASN1_item_sign(it: CPointer<Unit>, algor1: CPointer<X509Algor>, algor2: CPointer<X509Algor>, signature: CPointer<Asn1StringSt>, data: CPointer<Unit>, pkey: CPointer<EvpPkeySt>, type_: CPointer<Unit>): Int32
foreign func ASN1_item_sign_ctx(it: CPointer<Unit>, algor1: CPointer<X509Algor>, algor2: CPointer<X509Algor>, signature: CPointer<Asn1StringSt>, asn: CPointer<Unit>, ctx: CPointer<Unit>): Int32

// --- ASN1_STRING ---
foreign func ASN1_STRING_type_new(type_: Int32): CPointer<Asn1StringSt>
foreign func ASN1_STRING_new(): CPointer<Asn1StringSt>
foreign func ASN1_STRING_free(str: CPointer<Asn1StringSt>): Unit
foreign func ASN1_STRING_copy(dst: CPointer<Asn1StringSt>, str: CPointer<Asn1StringSt>): Int32
foreign func ASN1_STRING_dup(str: CPointer<Asn1StringSt>): CPointer<Asn1StringSt>
foreign func ASN1_STRING_type(str: CPointer<Asn1StringSt>): Int32
foreign func ASN1_STRING_get0_data(str: CPointer<Asn1StringSt>): CPointer<UInt8>
foreign func ASN1_STRING_data(str: CPointer<Asn1StringSt>): CPointer<UInt8>
foreign func ASN1_STRING_length(str: CPointer<Asn1StringSt>): Int32
foreign func ASN1_STRING_cmp(a: CPointer<Asn1StringSt>, b: CPointer<Asn1StringSt>): Int32
foreign func ASN1_STRING_to_UTF8(out: CPointer<CPointer<UInt8>>, in_: CPointer<Asn1StringSt>): Int32
foreign func ASN1_STRING_print(out: CPointer<Unit>, str: CPointer<Asn1StringSt>): Int32
foreign func ASN1_STRING_print_ex(out: CPointer<Unit>, str: CPointer<Asn1StringSt>, flags: UInt64): Int32
foreign func ASN1_STRING_set_default_mask(mask: UInt64): Unit
foreign func ASN1_STRING_set_default_mask_asc(p: CString): Int32
foreign func ASN1_STRING_get_default_mask(): UInt64
foreign func ASN1_STRING_TABLE_cleanup(): Unit
foreign func ASN1_STRING_set_by_NID(out: CPointer<CPointer<Asn1StringSt>>, in_: CPointer<UInt8>, len: Int32, inform: Int32, nid: Int32): CPointer<Asn1StringSt>
foreign func ASN1_STRING_TABLE_add(nid: Int32, minsize: Int64, maxsize: Int64, mask: UInt64, flags: UInt64): Int32
foreign func ASN1_mbstring_copy(out: CPointer<CPointer<Asn1StringSt>>, in_: CPointer<UInt8>, len: Int32, inform: Int32, mask: UInt64): Int32
foreign func ASN1_mbstring_ncopy(out: CPointer<CPointer<Asn1StringSt>>, in_: CPointer<UInt8>, len: Int32, inform: Int32, mask: UInt64, minsize: Int64, maxsize: Int64): Int32

// --- ASN1 子类型 new/free ---
foreign func ASN1_BMPSTRING_new(): CPointer<Asn1StringSt>
foreign func ASN1_GENERALSTRING_new(): CPointer<Asn1StringSt>
foreign func ASN1_IA5STRING_new(): CPointer<Asn1StringSt>
foreign func ASN1_OCTET_STRING_new(): CPointer<Asn1StringSt>
foreign func ASN1_PRINTABLESTRING_new(): CPointer<Asn1StringSt>
foreign func ASN1_T61STRING_new(): CPointer<Asn1StringSt>
foreign func ASN1_UNIVERSALSTRING_new(): CPointer<Asn1StringSt>
foreign func ASN1_UTF8STRING_new(): CPointer<Asn1StringSt>
foreign func ASN1_VISIBLESTRING_new(): CPointer<Asn1StringSt>
foreign func ASN1_BMPSTRING_free(str: CPointer<Asn1StringSt>): Unit
foreign func ASN1_GENERALSTRING_free(str: CPointer<Asn1StringSt>): Unit
foreign func ASN1_IA5STRING_free(str: CPointer<Asn1StringSt>): Unit
foreign func ASN1_OCTET_STRING_free(str: CPointer<Asn1StringSt>): Unit
foreign func ASN1_PRINTABLESTRING_free(str: CPointer<Asn1StringSt>): Unit
foreign func ASN1_T61STRING_free(str: CPointer<Asn1StringSt>): Unit
foreign func ASN1_UNIVERSALSTRING_free(str: CPointer<Asn1StringSt>): Unit
foreign func ASN1_UTF8STRING_free(str: CPointer<Asn1StringSt>): Unit
foreign func ASN1_VISIBLESTRING_free(str: CPointer<Asn1StringSt>): Unit
foreign func ASN1_PRINTABLE_new(): CPointer<Asn1StringSt>
foreign func ASN1_PRINTABLE_free(str: CPointer<Asn1StringSt>): Unit
foreign func ASN1_OCTET_STRING_dup(a: CPointer<Asn1StringSt>): CPointer<Asn1StringSt>
foreign func ASN1_OCTET_STRING_cmp(a: CPointer<Asn1StringSt>, b: CPointer<Asn1StringSt>): Int32
foreign func ASN1_OCTET_STRING_set(str: CPointer<Asn1StringSt>, data: CPointer<UInt8>, len: Int32): Int32

// --- ASN1_BIT_STRING ---
foreign func ASN1_BIT_STRING_new(): CPointer<Asn1StringSt>
foreign func ASN1_BIT_STRING_free(str: CPointer<Asn1StringSt>): Unit
foreign func ASN1_BIT_STRING_num_bytes(str: CPointer<Asn1StringSt>, out: CPointer<UIntNative>): Int32
foreign func ASN1_BIT_STRING_set_bit(str: CPointer<Asn1StringSt>, n: Int32, value: Int32): Int32
foreign func ASN1_BIT_STRING_get_bit(str: CPointer<Asn1StringSt>, n: Int32): Int32
foreign func ASN1_BIT_STRING_check(str: CPointer<Asn1StringSt>, flags: CPointer<UInt8>, flags_len: Int32): Int32

// --- ASN1_INTEGER ---
foreign func ASN1_INTEGER_new(): CPointer<Asn1StringSt>
foreign func ASN1_INTEGER_free(str: CPointer<Asn1StringSt>): Unit
foreign func ASN1_INTEGER_dup(x: CPointer<Asn1StringSt>): CPointer<Asn1StringSt>
foreign func ASN1_INTEGER_set_uint64(out: CPointer<Asn1StringSt>, v: UInt64): Int32
foreign func ASN1_INTEGER_set_int64(out: CPointer<Asn1StringSt>, v: Int64): Int32
foreign func ASN1_INTEGER_get_uint64(out: CPointer<UInt64>, a: CPointer<Asn1StringSt>): Int32
foreign func ASN1_INTEGER_get_int64(out: CPointer<Int64>, a: CPointer<Asn1StringSt>): Int32
foreign func ASN1_INTEGER_to_BN(ai: CPointer<Asn1StringSt>, bn: CPointer<BigNumSt>): CPointer<BigNumSt>
foreign func ASN1_INTEGER_cmp(x: CPointer<Asn1StringSt>, y: CPointer<Asn1StringSt>): Int32
foreign func ASN1_INTEGER_set(a: CPointer<Asn1StringSt>, v: Int64): Int32
foreign func ASN1_INTEGER_get(a: CPointer<Asn1StringSt>): Int64

// --- ASN1_ENUMERATED ---
foreign func ASN1_ENUMERATED_new(): CPointer<Asn1StringSt>
foreign func ASN1_ENUMERATED_free(str: CPointer<Asn1StringSt>): Unit
foreign func ASN1_ENUMERATED_set_uint64(out: CPointer<Asn1StringSt>, v: UInt64): Int32
foreign func ASN1_ENUMERATED_set_int64(out: CPointer<Asn1StringSt>, v: Int64): Int32
foreign func ASN1_ENUMERATED_get_uint64(out: CPointer<UInt64>, a: CPointer<Asn1StringSt>): Int32
foreign func ASN1_ENUMERATED_get_int64(out: CPointer<Int64>, a: CPointer<Asn1StringSt>): Int32
foreign func ASN1_ENUMERATED_to_BN(ai: CPointer<Asn1StringSt>, bn: CPointer<BigNumSt>): CPointer<BigNumSt>
foreign func ASN1_ENUMERATED_set(a: CPointer<Asn1StringSt>, v: Int64): Int32
foreign func ASN1_ENUMERATED_get(a: CPointer<Asn1StringSt>): Int64

// --- ASN1 时间类型 ---
foreign func ASN1_UTCTIME_new(): CPointer<Asn1StringSt>
foreign func ASN1_UTCTIME_free(str: CPointer<Asn1StringSt>): Unit
foreign func ASN1_UTCTIME_check(a: CPointer<Asn1StringSt>): Int32
foreign func ASN1_UTCTIME_set(s: CPointer<Asn1StringSt>, t: Int64): CPointer<Asn1StringSt>
foreign func ASN1_UTCTIME_adj(s: CPointer<Asn1StringSt>, t: Int64, offset_day: Int32, offset_sec: Int64): CPointer<Asn1StringSt>
foreign func ASN1_UTCTIME_set_string(s: CPointer<Asn1StringSt>, str: CString): Int32
foreign func ASN1_UTCTIME_cmp_time_t(s: CPointer<Asn1StringSt>, t: Int64): Int32
foreign func ASN1_UTCTIME_print(out: CPointer<Unit>, a: CPointer<Asn1StringSt>): Int32

foreign func ASN1_GENERALIZEDTIME_new(): CPointer<Asn1StringSt>
foreign func ASN1_GENERALIZEDTIME_free(str: CPointer<Asn1StringSt>): Unit
foreign func ASN1_GENERALIZEDTIME_check(a: CPointer<Asn1StringSt>): Int32
foreign func ASN1_GENERALIZEDTIME_set(s: CPointer<Asn1StringSt>, t: Int64): CPointer<Asn1StringSt>
foreign func ASN1_GENERALIZEDTIME_adj(s: CPointer<Asn1StringSt>, t: Int64, offset_day: Int32, offset_sec: Int64): CPointer<Asn1StringSt>
foreign func ASN1_GENERALIZEDTIME_set_string(s: CPointer<Asn1StringSt>, str: CString): Int32
foreign func ASN1_GENERALIZEDTIME_print(out: CPointer<Unit>, a: CPointer<Asn1StringSt>): Int32

foreign func ASN1_TIME_new(): CPointer<Asn1StringSt>
foreign func ASN1_TIME_free(str: CPointer<Asn1StringSt>): Unit
foreign func ASN1_TIME_diff(out_days: CPointer<Int32>, out_seconds: CPointer<Int32>, from: CPointer<Asn1StringSt>, to: CPointer<Asn1StringSt>): Int32
foreign func ASN1_TIME_set(s: CPointer<Asn1StringSt>, t: Int64): CPointer<Asn1StringSt>
foreign func ASN1_TIME_adj(s: CPointer<Asn1StringSt>, t: Int64, offset_day: Int32, offset_sec: Int64): CPointer<Asn1StringSt>
foreign func ASN1_TIME_check(t: CPointer<Asn1StringSt>): Int32
foreign func ASN1_TIME_to_generalizedtime(t: CPointer<Asn1StringSt>, out: CPointer<CPointer<Asn1StringSt>>): CPointer<Asn1StringSt>
foreign func ASN1_TIME_set_string(s: CPointer<Asn1StringSt>, str: CString): Int32
foreign func ASN1_TIME_to_time_t(t: CPointer<Asn1StringSt>, out: CPointer<Int64>): Int32
foreign func ASN1_TIME_to_posix(t: CPointer<Asn1StringSt>, out: CPointer<Int64>): Int32
foreign func ASN1_TIME_print(out: CPointer<Unit>, a: CPointer<Asn1StringSt>): Int32

// --- ASN1 NULL/OBJECT/TYPE ---
foreign func ASN1_NULL_new(): CPointer<Unit>
foreign func ASN1_NULL_free(null_: CPointer<Unit>): Unit
foreign func ASN1_OBJECT_create(nid: Int32, data: CPointer<UInt8>, len: Int32, sn: CString, ln: CString): CPointer<Unit>
foreign func ASN1_OBJECT_free(a: CPointer<Unit>): Unit
foreign func ASN1_TYPE_new(): CPointer<Asn1TypeSt>
foreign func ASN1_TYPE_free(a: CPointer<Asn1TypeSt>): Unit
foreign func ASN1_TYPE_get(a: CPointer<Asn1TypeSt>): Int32
foreign func ASN1_TYPE_set(a: CPointer<Asn1TypeSt>, type_: Int32, value: CPointer<Unit>): Unit
foreign func ASN1_TYPE_set1(a: CPointer<Asn1TypeSt>, type_: Int32, value: CPointer<Unit>): Int32
foreign func ASN1_TYPE_cmp(a: CPointer<Asn1TypeSt>, b: CPointer<Asn1TypeSt>): Int32

// --- ASN1 编解码 ---
foreign func ASN1_get_object(inp: CPointer<CPointer<UInt8>>, out_length: CPointer<Int64>, out_tag: CPointer<Int32>, out_class: CPointer<Int32>, max_len: Int64): Int32
foreign func ASN1_put_object(outp: CPointer<CPointer<UInt8>>, constructed: Int32, length: Int32, tag: Int32, xclass: Int32): Unit
foreign func ASN1_put_eoc(outp: CPointer<CPointer<UInt8>>): Int32
foreign func ASN1_object_size(constructed: Int32, length: Int32, tag: Int32): Int32
foreign func ASN1_digest(i2d: CPointer<Unit>, type_: CPointer<Unit>, data: CPointer<UInt8>, md: CPointer<UInt8>, len: CPointer<UInt32>): Int32

// --- d2i (反序列化) 函数 ---
foreign func d2i_ASN1_BIT_STRING(a: CPointer<CPointer<Asn1StringSt>>, pp: CPointer<CPointer<UInt8>>, length: Int64): CPointer<Asn1StringSt>
foreign func d2i_ASN1_BMPSTRING(a: CPointer<CPointer<Asn1StringSt>>, pp: CPointer<CPointer<UInt8>>, length: Int64): CPointer<Asn1StringSt>
foreign func d2i_ASN1_BOOLEAN(a: CPointer<Int32>, pp: CPointer<CPointer<UInt8>>, length: Int64): Int32
foreign func d2i_ASN1_ENUMERATED(a: CPointer<CPointer<Asn1StringSt>>, pp: CPointer<CPointer<UInt8>>, length: Int64): CPointer<Asn1StringSt>
foreign func d2i_ASN1_GENERALIZEDTIME(a: CPointer<CPointer<Asn1StringSt>>, pp: CPointer<CPointer<UInt8>>, length: Int64): CPointer<Asn1StringSt>
foreign func d2i_ASN1_GENERALSTRING(a: CPointer<CPointer<Asn1StringSt>>, pp: CPointer<CPointer<UInt8>>, length: Int64): CPointer<Asn1StringSt>
foreign func d2i_ASN1_IA5STRING(a: CPointer<CPointer<Asn1StringSt>>, pp: CPointer<CPointer<UInt8>>, length: Int64): CPointer<Asn1StringSt>
foreign func d2i_ASN1_INTEGER(a: CPointer<CPointer<Asn1StringSt>>, pp: CPointer<CPointer<UInt8>>, length: Int64): CPointer<Asn1StringSt>
foreign func d2i_ASN1_NULL(a: CPointer<CPointer<Unit>>, pp: CPointer<CPointer<UInt8>>, length: Int64): CPointer<Unit>
foreign func d2i_ASN1_OBJECT(a: CPointer<CPointer<Unit>>, pp: CPointer<CPointer<UInt8>>, length: Int64): CPointer<Unit>
foreign func d2i_ASN1_OCTET_STRING(a: CPointer<CPointer<Asn1StringSt>>, pp: CPointer<CPointer<UInt8>>, length: Int64): CPointer<Asn1StringSt>
foreign func d2i_ASN1_PRINTABLE(a: CPointer<CPointer<Asn1StringSt>>, pp: CPointer<CPointer<UInt8>>, length: Int64): CPointer<Asn1StringSt>
foreign func d2i_ASN1_PRINTABLESTRING(a: CPointer<CPointer<Asn1StringSt>>, pp: CPointer<CPointer<UInt8>>, length: Int64): CPointer<Asn1StringSt>
foreign func d2i_ASN1_SEQUENCE_ANY(a: CPointer<CPointer<Unit>>, pp: CPointer<CPointer<UInt8>>, length: Int64): CPointer<Unit>
foreign func d2i_ASN1_SET_ANY(a: CPointer<CPointer<Unit>>, pp: CPointer<CPointer<UInt8>>, length: Int64): CPointer<Unit>
foreign func d2i_ASN1_T61STRING(a: CPointer<CPointer<Asn1StringSt>>, pp: CPointer<CPointer<UInt8>>, length: Int64): CPointer<Asn1StringSt>
foreign func d2i_ASN1_TIME(a: CPointer<CPointer<Asn1StringSt>>, pp: CPointer<CPointer<UInt8>>, length: Int64): CPointer<Asn1StringSt>
foreign func d2i_ASN1_TYPE(a: CPointer<CPointer<Asn1TypeSt>>, pp: CPointer<CPointer<UInt8>>, length: Int64): CPointer<Asn1TypeSt>
foreign func d2i_ASN1_UNIVERSALSTRING(a: CPointer<CPointer<Asn1StringSt>>, pp: CPointer<CPointer<UInt8>>, length: Int64): CPointer<Asn1StringSt>
foreign func d2i_ASN1_UTCTIME(a: CPointer<CPointer<Asn1StringSt>>, pp: CPointer<CPointer<UInt8>>, length: Int64): CPointer<Asn1StringSt>
foreign func d2i_ASN1_UTF8STRING(a: CPointer<CPointer<Asn1StringSt>>, pp: CPointer<CPointer<UInt8>>, length: Int64): CPointer<Asn1StringSt>
foreign func d2i_ASN1_VISIBLESTRING(a: CPointer<CPointer<Asn1StringSt>>, pp: CPointer<CPointer<UInt8>>, length: Int64): CPointer<Asn1StringSt>
foreign func c2i_ASN1_BIT_STRING(a: CPointer<CPointer<Asn1StringSt>>, pp: CPointer<CPointer<UInt8>>, length: Int64): CPointer<Asn1StringSt>
foreign func c2i_ASN1_INTEGER(a: CPointer<CPointer<Asn1StringSt>>, pp: CPointer<CPointer<UInt8>>, length: Int64): CPointer<Asn1StringSt>
foreign func c2i_ASN1_OBJECT(a: CPointer<CPointer<Unit>>, pp: CPointer<CPointer<UInt8>>, length: Int64): CPointer<Unit>

// --- i2d (序列化) 函数 ---
foreign func i2d_ASN1_BIT_STRING(a: CPointer<Asn1StringSt>, out: CPointer<CPointer<UInt8>>): Int32
foreign func i2d_ASN1_BMPSTRING(a: CPointer<Asn1StringSt>, out: CPointer<CPointer<UInt8>>): Int32
foreign func i2d_ASN1_BOOLEAN(a: CPointer<Int32>, out: CPointer<CPointer<UInt8>>): Int32
foreign func i2d_ASN1_ENUMERATED(a: CPointer<Asn1StringSt>, out: CPointer<CPointer<UInt8>>): Int32
foreign func i2d_ASN1_GENERALIZEDTIME(a: CPointer<Asn1StringSt>, out: CPointer<CPointer<UInt8>>): Int32
foreign func i2d_ASN1_GENERALSTRING(a: CPointer<Asn1StringSt>, out: CPointer<CPointer<UInt8>>): Int32
foreign func i2d_ASN1_IA5STRING(a: CPointer<Asn1StringSt>, out: CPointer<CPointer<UInt8>>): Int32
foreign func i2d_ASN1_INTEGER(a: CPointer<Asn1StringSt>, out: CPointer<CPointer<UInt8>>): Int32
foreign func i2d_ASN1_NULL(a: CPointer<Unit>, out: CPointer<CPointer<UInt8>>): Int32
foreign func i2d_ASN1_OBJECT(a: CPointer<Unit>, out: CPointer<CPointer<UInt8>>): Int32
foreign func i2d_ASN1_OCTET_STRING(a: CPointer<Asn1StringSt>, out: CPointer<CPointer<UInt8>>): Int32
foreign func i2d_ASN1_PRINTABLE(a: CPointer<Asn1StringSt>, out: CPointer<CPointer<UInt8>>): Int32
foreign func i2d_ASN1_PRINTABLESTRING(a: CPointer<Asn1StringSt>, out: CPointer<CPointer<UInt8>>): Int32
foreign func i2d_ASN1_SEQUENCE_ANY(a: CPointer<Unit>, out: CPointer<CPointer<UInt8>>): Int32
foreign func i2d_ASN1_SET_ANY(a: CPointer<Unit>, out: CPointer<CPointer<UInt8>>): Int32
foreign func i2d_ASN1_T61STRING(a: CPointer<Asn1StringSt>, out: CPointer<CPointer<UInt8>>): Int32
foreign func i2d_ASN1_TIME(a: CPointer<Asn1StringSt>, out: CPointer<CPointer<UInt8>>): Int32
foreign func i2d_ASN1_TYPE(a: CPointer<Asn1TypeSt>, out: CPointer<CPointer<UInt8>>): Int32
foreign func i2d_ASN1_UNIVERSALSTRING(a: CPointer<Asn1StringSt>, out: CPointer<CPointer<UInt8>>): Int32
foreign func i2d_ASN1_UTCTIME(a: CPointer<Asn1StringSt>, out: CPointer<CPointer<UInt8>>): Int32
foreign func i2d_ASN1_UTF8STRING(a: CPointer<Asn1StringSt>, out: CPointer<CPointer<UInt8>>): Int32
foreign func i2d_ASN1_VISIBLESTRING(a: CPointer<Asn1StringSt>, out: CPointer<CPointer<UInt8>>): Int32
foreign func i2a_ASN1_ENUMERATED(bio: CPointer<Unit>, a: CPointer<Asn1StringSt>): Int32
foreign func i2a_ASN1_INTEGER(bio: CPointer<Unit>, a: CPointer<Asn1StringSt>): Int32
foreign func i2a_ASN1_OBJECT(bio: CPointer<Unit>, a: CPointer<Unit>): Int32
foreign func i2a_ASN1_STRING(bio: CPointer<Unit>, str: CPointer<Asn1StringSt>, type_: Int32): Int32
foreign func i2c_ASN1_BIT_STRING(a: CPointer<Asn1StringSt>, pp: CPointer<CPointer<UInt8>>): Int32
foreign func i2c_ASN1_INTEGER(a: CPointer<Asn1StringSt>, pp: CPointer<CPointer<UInt8>>): Int32

// --- d2i/i2d X509 系列 ---
foreign func d2i_X509_AUX(a: CPointer<CPointer<Unit>>, pp: CPointer<CPointer<UInt8>>, length: Int64): CPointer<Unit>
foreign func i2d_X509_AUX(x: CPointer<Unit>, out: CPointer<CPointer<UInt8>>): Int32
foreign func i2d_X509_tbs(x: CPointer<Unit>, pp: CPointer<CPointer<UInt8>>): Int32
foreign func i2d_re_X509_tbs(x: CPointer<Unit>, pp: CPointer<CPointer<UInt8>>): Int32
foreign func d2i_X509_ALGOR(a: CPointer<CPointer<X509Algor>>, pp: CPointer<CPointer<UInt8>>, length: Int64): CPointer<X509Algor>
foreign func i2d_X509_ALGOR(a: CPointer<X509Algor>, out: CPointer<CPointer<UInt8>>): Int32
foreign func d2i_X509_ATTRIBUTE(a: CPointer<CPointer<Unit>>, pp: CPointer<CPointer<UInt8>>, length: Int64): CPointer<Unit>
foreign func i2d_X509_ATTRIBUTE(a: CPointer<Unit>, out: CPointer<CPointer<UInt8>>): Int32
foreign func d2i_X509_EXTENSION(a: CPointer<CPointer<Unit>>, pp: CPointer<CPointer<UInt8>>, length: Int64): CPointer<Unit>
foreign func i2d_X509_EXTENSION(a: CPointer<Unit>, out: CPointer<CPointer<UInt8>>): Int32
foreign func d2i_X509_EXTENSIONS(a: CPointer<CPointer<Unit>>, pp: CPointer<CPointer<UInt8>>, length: Int64): CPointer<Unit>
foreign func i2d_X509_EXTENSIONS(a: CPointer<Unit>, out: CPointer<CPointer<UInt8>>): Int32
foreign func d2i_X509_NAME(a: CPointer<CPointer<Unit>>, pp: CPointer<CPointer<UInt8>>, length: Int64): CPointer<Unit>
foreign func i2d_X509_NAME(a: CPointer<Unit>, out: CPointer<CPointer<UInt8>>): Int32
foreign func d2i_X509_NAME_ENTRY(a: CPointer<CPointer<Unit>>, pp: CPointer<CPointer<UInt8>>, length: Int64): CPointer<Unit>
foreign func i2d_X509_NAME_ENTRY(a: CPointer<Unit>, out: CPointer<CPointer<UInt8>>): Int32
foreign func d2i_X509_PUBKEY(a: CPointer<CPointer<Unit>>, pp: CPointer<CPointer<UInt8>>, length: Int64): CPointer<Unit>
foreign func i2d_X509_PUBKEY(a: CPointer<Unit>, out: CPointer<CPointer<UInt8>>): Int32
foreign func d2i_X509_REQ(a: CPointer<CPointer<Unit>>, pp: CPointer<CPointer<UInt8>>, length: Int64): CPointer<Unit>
foreign func i2d_X509_REQ(a: CPointer<Unit>, out: CPointer<CPointer<UInt8>>): Int32
foreign func i2d_re_X509_REQ_tbs(a: CPointer<Unit>, out: CPointer<CPointer<UInt8>>): Int32
foreign func d2i_X509_REVOKED(a: CPointer<CPointer<Unit>>, pp: CPointer<CPointer<UInt8>>, length: Int64): CPointer<Unit>
foreign func i2d_X509_REVOKED(a: CPointer<Unit>, out: CPointer<CPointer<UInt8>>): Int32
foreign func d2i_X509_SIG(a: CPointer<CPointer<Unit>>, pp: CPointer<CPointer<UInt8>>, length: Int64): CPointer<Unit>
foreign func i2d_X509_SIG(a: CPointer<Unit>, out: CPointer<CPointer<UInt8>>): Int32
foreign func d2i_X509_CRL(a: CPointer<CPointer<Unit>>, pp: CPointer<CPointer<UInt8>>, length: Int64): CPointer<Unit>
foreign func i2d_X509_CRL(a: CPointer<Unit>, out: CPointer<CPointer<UInt8>>): Int32
foreign func i2d_X509_CRL_tbs(a: CPointer<Unit>, out: CPointer<CPointer<UInt8>>): Int32
foreign func i2d_re_X509_CRL_tbs(a: CPointer<Unit>, out: CPointer<CPointer<UInt8>>): Int32
foreign func d2i_X509_CRL_bio(bio: CPointer<Unit>, x: CPointer<CPointer<Unit>>): CPointer<Unit>
foreign func i2d_X509_CRL_bio(bio: CPointer<Unit>, x: CPointer<Unit>): Int32

// --- d2i/i2d RSA/DSA/DH/EC ---
foreign func d2i_RSAPrivateKey(a: CPointer<CPointer<Unit>>, pp: CPointer<CPointer<UInt8>>, length: Int64): CPointer<Unit>
foreign func i2d_RSAPrivateKey(a: CPointer<Unit>, out: CPointer<CPointer<UInt8>>): Int32
foreign func d2i_RSAPrivateKey_bio(bio: CPointer<Unit>, x: CPointer<CPointer<Unit>>): CPointer<Unit>
foreign func i2d_RSAPrivateKey_bio(bio: CPointer<Unit>, x: CPointer<Unit>): Int32
foreign func d2i_RSAPublicKey(a: CPointer<CPointer<Unit>>, pp: CPointer<CPointer<UInt8>>, length: Int64): CPointer<Unit>
foreign func i2d_RSAPublicKey(a: CPointer<Unit>, out: CPointer<CPointer<UInt8>>): Int32
foreign func d2i_RSAPublicKey_bio(bio: CPointer<Unit>, x: CPointer<CPointer<Unit>>): CPointer<Unit>
foreign func i2d_RSAPublicKey_bio(bio: CPointer<Unit>, x: CPointer<Unit>): Int32
foreign func d2i_RSA_PSS_PARAMS(a: CPointer<CPointer<RsaPssParams>>, pp: CPointer<CPointer<UInt8>>, length: Int64): CPointer<RsaPssParams>
foreign func i2d_RSA_PSS_PARAMS(a: CPointer<RsaPssParams>, out: CPointer<CPointer<UInt8>>): Int32
foreign func d2i_RSA_PUBKEY(a: CPointer<CPointer<Unit>>, pp: CPointer<CPointer<UInt8>>, length: Int64): CPointer<Unit>
foreign func i2d_RSA_PUBKEY(a: CPointer<Unit>, out: CPointer<CPointer<UInt8>>): Int32
foreign func d2i_RSA_PUBKEY_bio(bio: CPointer<Unit>, x: CPointer<CPointer<Unit>>): CPointer<Unit>
foreign func i2d_RSA_PUBKEY_bio(bio: CPointer<Unit>, x: CPointer<Unit>): Int32
foreign func d2i_DHparams(a: CPointer<CPointer<Unit>>, pp: CPointer<CPointer<UInt8>>, length: Int64): CPointer<Unit>
foreign func i2d_DHparams(a: CPointer<Unit>, out: CPointer<CPointer<UInt8>>): Int32
foreign func d2i_DHparams_bio(bio: CPointer<Unit>, x: CPointer<CPointer<Unit>>): CPointer<Unit>
foreign func i2d_DHparams_bio(bio: CPointer<Unit>, x: CPointer<Unit>): Int32
foreign func d2i_DSAparams(a: CPointer<CPointer<Unit>>, pp: CPointer<CPointer<UInt8>>, length: Int64): CPointer<Unit>
foreign func i2d_DSAparams(a: CPointer<Unit>, out: CPointer<CPointer<UInt8>>): Int32
foreign func d2i_DSAPrivateKey(a: CPointer<CPointer<Unit>>, pp: CPointer<CPointer<UInt8>>, length: Int64): CPointer<Unit>
foreign func i2d_DSAPrivateKey(a: CPointer<Unit>, out: CPointer<CPointer<UInt8>>): Int32
foreign func d2i_DSAPrivateKey_bio(bio: CPointer<Unit>, x: CPointer<CPointer<Unit>>): CPointer<Unit>
foreign func i2d_DSAPrivateKey_bio(bio: CPointer<Unit>, x: CPointer<Unit>): Int32
foreign func d2i_DSAPublicKey(a: CPointer<CPointer<Unit>>, pp: CPointer<CPointer<UInt8>>, length: Int64): CPointer<Unit>
foreign func i2d_DSAPublicKey(a: CPointer<Unit>, out: CPointer<CPointer<UInt8>>): Int32
foreign func d2i_DSA_PUBKEY(a: CPointer<CPointer<Unit>>, pp: CPointer<CPointer<UInt8>>, length: Int64): CPointer<Unit>
foreign func i2d_DSA_PUBKEY(a: CPointer<Unit>, out: CPointer<CPointer<UInt8>>): Int32
foreign func d2i_DSA_PUBKEY_bio(bio: CPointer<Unit>, x: CPointer<CPointer<Unit>>): CPointer<Unit>
foreign func i2d_DSA_PUBKEY_bio(bio: CPointer<Unit>, x: CPointer<Unit>): Int32
foreign func d2i_DSA_SIG(a: CPointer<CPointer<DsaSigSt>>, pp: CPointer<CPointer<UInt8>>, length: Int64): CPointer<DsaSigSt>
foreign func i2d_DSA_SIG(a: CPointer<DsaSigSt>, out: CPointer<CPointer<UInt8>>): Int32
foreign func d2i_ECDSA_SIG(a: CPointer<CPointer<EcdsaSig>>, pp: CPointer<CPointer<UInt8>>, length: Int64): CPointer<EcdsaSig>
foreign func i2d_ECDSA_SIG(a: CPointer<EcdsaSig>, out: CPointer<CPointer<UInt8>>): Int32
foreign func d2i_ECParameters(a: CPointer<CPointer<Unit>>, pp: CPointer<CPointer<UInt8>>, length: Int64): CPointer<Unit>
foreign func i2d_ECParameters(key: CPointer<Unit>, out: CPointer<CPointer<UInt8>>): Int32
foreign func d2i_ECPrivateKey(a: CPointer<CPointer<Unit>>, pp: CPointer<CPointer<UInt8>>, length: Int64): CPointer<Unit>
foreign func i2d_ECPrivateKey(key: CPointer<Unit>, out: CPointer<CPointer<UInt8>>): Int32
foreign func d2i_ECPrivateKey_bio(bio: CPointer<Unit>, x: CPointer<CPointer<Unit>>): CPointer<Unit>
foreign func i2d_ECPrivateKey_bio(bio: CPointer<Unit>, x: CPointer<Unit>): Int32
foreign func d2i_EC_PUBKEY(a: CPointer<CPointer<Unit>>, pp: CPointer<CPointer<UInt8>>, length: Int64): CPointer<Unit>
foreign func i2d_EC_PUBKEY(ec_key: CPointer<Unit>, outp: CPointer<CPointer<UInt8>>): Int32
foreign func d2i_EC_PUBKEY_bio(bio: CPointer<Unit>, x: CPointer<CPointer<Unit>>): CPointer<Unit>
foreign func i2d_EC_PUBKEY_bio(bio: CPointer<Unit>, x: CPointer<Unit>): Int32

// --- d2i/i2d PKCS 系列 ---
foreign func d2i_PKCS7(a: CPointer<CPointer<Unit>>, pp: CPointer<CPointer<UInt8>>, length: Int64): CPointer<Unit>
foreign func i2d_PKCS7(a: CPointer<Unit>, out: CPointer<CPointer<UInt8>>): Int32
foreign func d2i_PKCS7_bio(bio: CPointer<Unit>, x: CPointer<CPointer<Unit>>): CPointer<Unit>
foreign func i2d_PKCS7_bio(bio: CPointer<Unit>, x: CPointer<Unit>): Int32
foreign func d2i_PKCS8_bio(bio: CPointer<Unit>, x: CPointer<CPointer<EvpPkeySt>>): CPointer<EvpPkeySt>
foreign func i2d_PKCS8_bio(bio: CPointer<Unit>, x: CPointer<EvpPkeySt>): Int32
foreign func d2i_PKCS8PrivateKey_bio(bio: CPointer<Unit>, x: CPointer<CPointer<EvpPkeySt>>): CPointer<EvpPkeySt>
foreign func i2d_PKCS8PrivateKey_bio(bio: CPointer<Unit>, x: CPointer<EvpPkeySt>): Int32
foreign func i2d_PKCS8PrivateKeyInfo_bio(bio: CPointer<Unit>, x: CPointer<Unit>): Int32
foreign func i2d_PKCS8PrivateKey_nid_bio(bio: CPointer<Unit>, x: CPointer<EvpPkeySt>): Int32
foreign func d2i_PKCS8_PRIV_KEY_INFO(a: CPointer<CPointer<Unit>>, pp: CPointer<CPointer<UInt8>>, length: Int64): CPointer<Unit>
foreign func i2d_PKCS8_PRIV_KEY_INFO(a: CPointer<Unit>, out: CPointer<CPointer<UInt8>>): Int32
foreign func d2i_PKCS8_PRIV_KEY_INFO_bio(bio: CPointer<Unit>, x: CPointer<CPointer<Unit>>): CPointer<Unit>
foreign func i2d_PKCS8_PRIV_KEY_INFO_bio(bio: CPointer<Unit>, x: CPointer<Unit>): Int32

// --- d2i/i2d 通用密钥 ---
foreign func d2i_PrivateKey(bio: CPointer<Unit>, x: CPointer<CPointer<EvpPkeySt>>): CPointer<EvpPkeySt>
foreign func i2d_PrivateKey(a: CPointer<EvpPkeySt>, pp: CPointer<CPointer<UInt8>>): Int32
foreign func d2i_AutoPrivateKey(a: CPointer<CPointer<EvpPkeySt>>, pp: CPointer<CPointer<UInt8>>, length: Int64): CPointer<EvpPkeySt>
foreign func d2i_PUBKEY(a: CPointer<CPointer<EvpPkeySt>>, pp: CPointer<CPointer<UInt8>>, length: Int64): CPointer<EvpPkeySt>
foreign func i2d_PUBKEY(a: CPointer<EvpPkeySt>, pp: CPointer<CPointer<UInt8>>): Int32
foreign func d2i_PublicKey(type_: Int32, x: CPointer<CPointer<EvpPkeySt>>, pp: CPointer<CPointer<UInt8>>, length: Int64): CPointer<EvpPkeySt>
foreign func i2d_PublicKey(a: CPointer<EvpPkeySt>, pp: CPointer<CPointer<UInt8>>): Int32

// --- d2i/i2d NETSCAPE ---
foreign func d2i_NETSCAPE_SPKAC(a: CPointer<CPointer<NETSCAPE_SPKAC>>, pp: CPointer<CPointer<UInt8>>, length: Int64): CPointer<NETSCAPE_SPKAC>
foreign func i2d_NETSCAPE_SPKAC(a: CPointer<NETSCAPE_SPKAC>, out: CPointer<CPointer<UInt8>>): Int32
foreign func d2i_NETSCAPE_SPKI(a: CPointer<CPointer<NETSCAPE_SPKI>>, pp: CPointer<CPointer<UInt8>>, length: Int64): CPointer<NETSCAPE_SPKI>
foreign func i2d_NETSCAPE_SPKI(a: CPointer<NETSCAPE_SPKI>, out: CPointer<CPointer<UInt8>>): Int32

// --- d2i/i2d DISPLAYTEXT/DIRECTORYSTRING ---
foreign func d2i_DIRECTORYSTRING(a: CPointer<CPointer<Asn1StringSt>>, pp: CPointer<CPointer<UInt8>>, length: Int64): CPointer<Asn1StringSt>
foreign func i2d_DIRECTORYSTRING(a: CPointer<Asn1StringSt>, out: CPointer<CPointer<UInt8>>): Int32
foreign func d2i_DISPLAYTEXT(a: CPointer<CPointer<Asn1StringSt>>, pp: CPointer<CPointer<UInt8>>, length: Int64): CPointer<Asn1StringSt>
foreign func i2d_DISPLAYTEXT(a: CPointer<Asn1StringSt>, out: CPointer<CPointer<UInt8>>): Int32
foreign func DISPLAYTEXT_new(): CPointer<Asn1StringSt>
foreign func DISPLAYTEXT_free(a: CPointer<Asn1StringSt>): Unit

// --- NETSCAPE 函数 ---
foreign func NETSCAPE_SPKAC_new(): CPointer<NETSCAPE_SPKAC>
foreign func NETSCAPE_SPKAC_free(a: CPointer<NETSCAPE_SPKAC>): Unit
foreign func NETSCAPE_SPKI_new(): CPointer<NETSCAPE_SPKI>
foreign func NETSCAPE_SPKI_free(a: CPointer<NETSCAPE_SPKI>): Unit
foreign func NETSCAPE_SPKI_b64_decode(str: CString): CPointer<NETSCAPE_SPKI>
foreign func NETSCAPE_SPKI_b64_encode(x: CPointer<NETSCAPE_SPKI>): CPointer<UInt8>
foreign func NETSCAPE_SPKI_get_pubkey(x: CPointer<NETSCAPE_SPKI>): CPointer<EvpPkeySt>
foreign func NETSCAPE_SPKI_set_pubkey(x: CPointer<NETSCAPE_SPKI>, pkey: CPointer<EvpPkeySt>): Int32
foreign func NETSCAPE_SPKI_sign(x: CPointer<NETSCAPE_SPKI>, pkey: CPointer<EvpPkeySt>, md: CPointer<Unit>): Int32
foreign func NETSCAPE_SPKI_verify(x: CPointer<NETSCAPE_SPKI>, pkey: CPointer<EvpPkeySt>): Int32

// --- ASN1 常量 (extern const) ---
foreign func ASN1_BOOLEAN_it(): CPointer<Unit>
foreign func ASN1_TBOOLEAN_it(): CPointer<Unit>
foreign func ASN1_FBOOLEAN_it(): CPointer<Unit>
foreign func ASN1_SEQUENCE_ANY_it(): CPointer<Unit>
foreign func ASN1_SET_ANY_it(): CPointer<Unit>
foreign func ASN1_ANY_it(): CPointer<Unit>
foreign func ASN1_BIT_STRING_it(): CPointer<Unit>
foreign func ASN1_BMPSTRING_it(): CPointer<Unit>
foreign func ASN1_ENUMERATED_it(): CPointer<Unit>
foreign func ASN1_GENERALIZEDTIME_it(): CPointer<Unit>
foreign func ASN1_GENERALSTRING_it(): CPointer<Unit>
foreign func ASN1_IA5STRING_it(): CPointer<Unit>
foreign func ASN1_INTEGER_it(): CPointer<Unit>
foreign func ASN1_NULL_it(): CPointer<Unit>
foreign func ASN1_OBJECT_it(): CPointer<Unit>
foreign func ASN1_OCTET_STRING_it(): CPointer<Unit>
foreign func ASN1_PRINTABLE_it(): CPointer<Unit>
foreign func ASN1_PRINTABLESTRING_it(): CPointer<Unit>
foreign func ASN1_T61STRING_it(): CPointer<Unit>
foreign func ASN1_TIME_it(): CPointer<Unit>
foreign func ASN1_UNIVERSALSTRING_it(): CPointer<Unit>
foreign func ASN1_UTCTIME_it(): CPointer<Unit>
foreign func ASN1_UTF8STRING_it(): CPointer<Unit>
foreign func ASN1_VISIBLESTRING_it(): CPointer<Unit>
foreign func DIRECTORYSTRING_it(): CPointer<Unit>
foreign func DISPLAYTEXT_it(): CPointer<Unit>
foreign func X509_it(): CPointer<Unit>
foreign func X509_CRL_it(): CPointer<Unit>
foreign func X509_REQ_it(): CPointer<Unit>
foreign func X509_NAME_it(): CPointer<Unit>
foreign func X509_NAME_ENTRY_it(): CPointer<Unit>
foreign func X509_EXTENSION_it(): CPointer<Unit>
foreign func X509_EXTENSIONS_it(): CPointer<Unit>
foreign func X509_ALGOR_it(): CPointer<Unit>
foreign func X509_PUBKEY_it(): CPointer<Unit>
foreign func X509_SIG_it(): CPointer<Unit>
foreign func X509_ATTRIBUTE_it(): CPointer<Unit>
foreign func X509_REVOKED_it(): CPointer<Unit>
foreign func NETSCAPE_SPKI_it(): CPointer<Unit>
foreign func NETSCAPE_SPKAC_it(): CPointer<Unit>
foreign func PKCS8_PRIV_KEY_INFO_it(): CPointer<Unit>
foreign func RSA_PSS_PARAMS_it(): CPointer<Unit>
foreign func DIRECTORYSTRING_new(): CPointer<Asn1StringSt>
foreign func DIRECTORYSTRING_free(a: CPointer<Asn1StringSt>): Unit
foreign func i2t_ASN1_OBJECT(buf: CPointer<UInt8>, buf_len: Int32, a: CPointer<Unit>): Int32
