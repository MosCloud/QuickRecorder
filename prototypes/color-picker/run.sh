#!/bin/bash
# PROTOTYPE — 编译并运行自定义背景色的选色界面对比（只需命令行工具，不需要 Xcode 工程）。
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
mkdir -p "$DIR/.build"
xcrun swiftc -O -parse-as-library -target "$(uname -m)-apple-macos26.0" \
    "$DIR/ColorPickerPrototype.swift" -o "$DIR/.build/ColorPickerPrototype"
exec "$DIR/.build/ColorPickerPrototype" "$@"
