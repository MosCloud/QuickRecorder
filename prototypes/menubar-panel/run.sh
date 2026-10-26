#!/bin/bash
# PROTOTYPE — 编译并运行菜单栏弹窗的两种方案对比（#46；只需命令行工具，不需要 Xcode 工程）。
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
mkdir -p "$DIR/.build"
xcrun swiftc -O -parse-as-library -target "$(uname -m)-apple-macos26.0" \
    "$DIR/MenuBarPanelPrototype.swift" -o "$DIR/.build/MenuBarPanelPrototype"
exec "$DIR/.build/MenuBarPanelPrototype" "$@"
