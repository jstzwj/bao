#!/bin/bash
# Build bao_jsc_worker — linked with Bun's prebuilt WebKit
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
# WebKit libs may be in worktree or main repo
WEBKIT_LIB="$PROJECT_DIR/native_libs/webkit/bun-webkit-nolto/bun-webkit/lib"
if [ ! -d "$WEBKIT_LIB" ]; then
    # Try main repo (worktrees are under .claude/worktrees/)
    MAIN_REPO="$(cd "$PROJECT_DIR/../../.." 2>/dev/null && pwd)"
    if [ -d "$MAIN_REPO/native_libs/webkit/bun-webkit-nolto/bun-webkit/lib" ]; then
        WEBKIT_LIB="$MAIN_REPO/native_libs/webkit/bun-webkit-nolto/bun-webkit/lib"
    fi
fi
OUTPUT="$PROJECT_DIR/target/release/bin/bao_jsc_worker"

mkdir -p "$PROJECT_DIR/target/release/bin"

# Compile sanitizer stubs (bmalloc needs asan/tsan symbols)
cc -c -O2 -o /tmp/bao_sanitizer_stubs.o "$SCRIPT_DIR/sanitizer_stubs.c"

# Compile Node.js compatibility module
cc -c -O2 -I"$SCRIPT_DIR" -o /tmp/bao_jsc_node_compat.o "$SCRIPT_DIR/jsc_node_compat.c"

# Link worker with Bun's static WebKit
cc -o "$OUTPUT" \
  "$SCRIPT_DIR/jsc_worker.c" \
  /tmp/bao_sanitizer_stubs.o \
  /tmp/bao_jsc_node_compat.o \
  "$WEBKIT_LIB/libJavaScriptCore.a" \
  "$WEBKIT_LIB/libWTF.a" \
  "$WEBKIT_LIB/libbmalloc.a" \
  "$WEBKIT_LIB/libicui18n.a" \
  "$WEBKIT_LIB/libicuuc.a" \
  "$WEBKIT_LIB/libicutu.a" \
  "$WEBKIT_LIB/libicudata.a" \
  -lm -lcurl -lssl -lcrypto -luv -lz -lbrotlienc -lbrotlidec -lzstd \
  -lpthread -ldl -lrt -lstdc++ \
  /usr/lib/x86_64-linux-gnu/libatomic.so.1

strip "$OUTPUT"
echo "Built: $OUTPUT ($(du -h "$OUTPUT" | cut -f1))"
