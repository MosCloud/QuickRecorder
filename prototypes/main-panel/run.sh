#!/bin/bash
# PROTOTYPE — 编译并运行主面板的新布局和三种材质（#48；只需命令行工具，不需要 Xcode 工程）。
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
mkdir -p "$DIR/.build"
xcrun swiftc -O -parse-as-library -target "$(uname -m)-apple-macos26.0" \
    "$DIR/MainPanelPrototype.swift" -o "$DIR/.build/MainPanelPrototype"
exec "$DIR/.build/MainPanelPrototype" "$@"
