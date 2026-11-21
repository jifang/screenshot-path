#!/bin/bash
# 编译并做 ad-hoc 签名（固定 identifier，便于 TCC 记住授权）
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p build
swiftc -O -o build/screenshot-path Sources/main.swift
codesign --force --sign - --identifier com.jifang.screenshot-path build/screenshot-path
echo "built: $(pwd)/build/screenshot-path"
