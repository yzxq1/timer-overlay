#!/bin/zsh
# 编译 倒计时悬浮窗（同时兼容 Apple 芯片和 Intel）
set -e
cd "$(dirname "$0")"
swiftc -O 倒计时悬浮窗.swift -target arm64-apple-macosx13.0 -o /tmp/倒计时悬浮窗-arm64
swiftc -O 倒计时悬浮窗.swift -target x86_64-apple-macosx13.0 -o /tmp/倒计时悬浮窗-x86_64
lipo -create /tmp/倒计时悬浮窗-arm64 /tmp/倒计时悬浮窗-x86_64 -output 倒计时悬浮窗
rm -f /tmp/倒计时悬浮窗-arm64 /tmp/倒计时悬浮窗-x86_64
echo "已生成 $(pwd)/倒计时悬浮窗（$(lipo -archs 倒计时悬浮窗)）"
