#!/bin/bash
# PROTOTYPE — 编译并运行菜单栏 B 方案 demo（只需命令行工具，不需要 Xcode 工程）。
# 用法：prototypes/menubar-b/run.sh [shape=pill|notchRounded|notchExtended] [material=glass|blur|black]
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
mkdir -p "$DIR/.build"
xcrun swiftc -O -parse-as-library -target "$(uname -m)-apple-macos26.0" \
    "$DIR/MenuBarPrototype.swift" -o "$DIR/.build/MenuBarPrototype"
exec "$DIR/.build/MenuBarPrototype" "$@"
