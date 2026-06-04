#!/bin/bash
# Build bao_jsc_worker — linked with Bun's prebuilt WebKit
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
WEBKIT_LIB="$PROJECT_DIR/native_libs/webkit/bun-webkit-nolto/bun-webkit/lib"
OUTPUT="$PROJECT_DIR/target/release/bin/bao_jsc_worker"

# Compile sanitizer stubs (bmalloc needs asan/tsan symbols)
cc -c -O2 -o /tmp/bao_sanitizer_stubs.o "$SCRIPT_DIR/sanitizer_stubs.c"

# Link worker with Bun's static WebKit
cc -o "$OUTPUT" \
  "$SCRIPT_DIR/jsc_worker.c" \
  /tmp/bao_sanitizer_stubs.o \
  "$WEBKIT_LIB/libJavaScriptCore.a" \
  "$WEBKIT_LIB/libWTF.a" \
  "$WEBKIT_LIB/libbmalloc.a" \
  "$WEBKIT_LIB/libicui18n.a" \
  "$WEBKIT_LIB/libicuuc.a" \
  "$WEBKIT_LIB/libicutu.a" \
  "$WEBKIT_LIB/libicudata.a" \
  -lm -lssl -lcrypto -luv -lz -lbrotlienc -lbrotlidec -lzstd \
  -lpthread -ldl -lrt -lstdc++ \
  /usr/lib/x86_64-linux-gnu/libatomic.so.1

strip "$OUTPUT"
echo "Built: $OUTPUT ($(du -h "$OUTPUT" | cut -f1))"
