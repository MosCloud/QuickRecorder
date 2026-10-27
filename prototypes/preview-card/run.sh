#!/bin/bash
# PROTOTYPE — 编译并运行预览浮窗的三种布局（#55；只需命令行工具，不需要 Xcode 工程）。
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
mkdir -p "$DIR/.build"
xcrun swiftc -O -parse-as-library -target "$(uname -m)-apple-macos26.0" \
    "$DIR/PreviewCardPrototype.swift" -o "$DIR/.build/PreviewCardPrototype"
exec "$DIR/.build/PreviewCardPrototype" "$@"
