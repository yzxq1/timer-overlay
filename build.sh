#!/bin/zsh
# 编译 TimerOverlay（同时兼容 Apple 芯片和 Intel）
set -e
cd "$(dirname "$0")"
swiftc -O TimerOverlay.swift -target arm64-apple-macosx13.0 -o /tmp/TimerOverlay-arm64
swiftc -O TimerOverlay.swift -target x86_64-apple-macosx13.0 -o /tmp/TimerOverlay-x86_64
lipo -create /tmp/TimerOverlay-arm64 /tmp/TimerOverlay-x86_64 -output TimerOverlay
rm -f /tmp/TimerOverlay-arm64 /tmp/TimerOverlay-x86_64
echo "已生成 $(pwd)/TimerOverlay（$(lipo -archs TimerOverlay)）"
